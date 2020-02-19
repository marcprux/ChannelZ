//
//  Receptors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import Dispatch
import Foundation

// Atomic increment/decrement is deprecated and there is currently no replacement for Swift

//public typealias Counter = Int64
//
//@discardableResult
//func channelZIncrement64(_ value: UnsafeMutablePointer<Counter>) -> Int64 {
//    return OSAtomicIncrement64(value)
//}
//
//@discardableResult
//func channelZDecrement64(_ value: UnsafeMutablePointer<Counter>) -> Int64 {
//    return OSAtomicDecrement64(value)
//}
//
//public final class Counter : ExpressibleByIntegerLiteral {
//    private var value: Int64 = 0
//    
//    public init(integerLiteral: Int) {
//        self.value = Int64(integerLiteral)
//    }
//
//    public func set(_ v: Int64) {
//        value = v
//    }
//    
//    public func current() -> Int64 {
//        return value
//    }
//    
//    @discardableResult
//    public func increment() -> Int64 {
//        return OSAtomicIncrement64(&value)
//    }
//    
//    @discardableResult
//    public func decrement() -> Int64 {
//        return OSAtomicDecrement64(&value)
//    }
//}

public final class Counter : ExpressibleByIntegerLiteral {
    private var value: Int64 = 0
    private let queue = DispatchQueue(label: "ChannelZCounter")
    
    public init(integerLiteral: Int) {
        self.value = Int64(integerLiteral)
    }
    
    public func set(_ v: Int64) {
        queue.sync {
            value = v
        }
    }
    
    private func change(_ offset: Int64) -> Int64 {
        var v: Int64 = 0
        queue.sync {
            value += offset
            v = value
        }
        return v
    }

    public func get() -> Int64 {
        return change(0)
    }
    
    @discardableResult
    public func increment() -> Int64 {
        return change(+1)
    }
    
    @discardableResult
    public func decrement() -> Int64 {
        return change(-1)
    }
}


/// An `Receipt` is the result of `receive`ing to a Observable or Channel
public protocol Receipt {

    /// Whether the receipt is cancelled or not
    var isCancelled: Bool { get }

    /// Disconnects this receptor from the source
    func cancel()
    
    func makeIterator() -> CollectionOfOne<Receipt>.Iterator

}

public extension Receipt {
    /// Creates an iterator of receipts
    func makeIterator() -> CollectionOfOne<Receipt>.Iterator {
        return CollectionOfOne(self).makeIterator()
    }
}

// A receipt implementation
open class ReceiptOf: Receipt {
    open var isCancelled: Bool { return cancelCounter.get() > 0 }
    fileprivate let cancelCounter: Counter = 0

    let canceler: () -> ()

    public init(canceler: @escaping () -> () = { }) {
        self.canceler = canceler
    }

    /// Disconnects this receipt from the source observable
    open func cancel() {
        // only cancel the first time
        if cancelCounter.increment() == 1 {
            canceler()
        }
    }
}

// A thread-safe multi-receipt implementation
open class MultiReceipt: Receipt {
    private let queue = DispatchQueue(label: "ReceiptOfQueue", attributes: .concurrent)
    private var receipts: [Receipt] = []

    /// Creates a Receipt backed by one or more other Receipts
    public init(receipts: [Receipt]) {
        addReceipts(receipts)
    }

    /// Creates a Receipt backed by another Receipt
    public convenience init(receipt: Receipt) {
        self.init(receipts: [receipt])
    }

    /// Creates an empty cancelled Receipt
    public convenience init() {
        self.init(receipts: [])
    }

    public func addReceipts(_ receipts: [Receipt]) {
        queue.async(flags: .barrier) { self.receipts.append(contentsOf: receipts) }
    }

    /// Disconnects this receipt from the source observable
    open func cancel() {
        queue.sync {
            for receipt in self.receipts {
                receipt.cancel()
            }
        }
    }

    public var isCancelled: Bool {
        var cancelled: Bool = true
        queue.sync {
            cancelled = self.receipts.filter({ $0.isCancelled == false }).isEmpty
        }
        return cancelled

    }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

/// Global number of times a reentrant invocation was made
public let ChannelZReentrantReceptions: Counter = 0

/// A ReceiverQueue manages a list of receivers and handles dispatching pulses to all the receivers
public final class ReceiverQueue<T> : ReceiverType {
    public typealias Receptor = (T) -> ()
    public let maxdepth: Int

    var receivers: ContiguousArray<(index: Int64, receptor: Receptor)> = []
    let entrancy: Counter = 0
    let receptorIndex: Counter = 0

    public var count: Int { return receivers.count }

    // os_unfair_lock would probably be faster (albeit unfair), but it seems to crash on forked processes (like when XCode unit tests in parallel; https://forums.developer.apple.com/thread/60622)
    // let lock = UnfairLock()
    let lock = ReentrantLock()

    public init(maxdepth: Int? = nil) {
        self.maxdepth = maxdepth ?? ChannelZReentrancyLimit
    }

    public func receive(_ element: T) {
        lock.lock()
        defer { lock.unlock() }

        let currentEntrancy = entrancy.increment()
        defer { entrancy.decrement() }
        if currentEntrancy > Int64(maxdepth + 1) {
            reentrantChannelReception(element)
        } else {
            for (_, receiver) in receivers {
                receiver(element)
            }
        }
    }

    public func reentrantChannelReception(_ element: Any) {
        #if DEBUG_CHANNELZ
            //print("ChannelZ reentrant channel short-circuit; break on \(#function) to debug", type(of: element))
            ChannelZReentrantReceptions.increment()
        #endif
    }

    /// Adds a receiver that will return a receipt that simply removes itself from the list
    public func addReceipt(_ receptor: @escaping Receptor) -> Receipt {
        let token = addReceiver(receptor)
        return ReceiptOf(canceler: { self.removeReceptor(token) })
    }

    /// Adds a custom receiver block and returns a token that can later be used to remove the receiver
    public func addReceiver(_ receptor: @escaping Receptor) -> Int64 {
        precondition(entrancy.get() == 0, "cannot add to receivers while they are flowing")
        let index = receptorIndex.increment()
        receivers.append((index, receptor))
        return index
    }

    public func removeReceptor(_ index: Int64) {
        receivers = receivers.filter { $0.index != index }
    }

    /// Clear all the receivers
    public func clear() {
        receivers = []
    }
}

open class ReceiverQueueSource<T> {
    let receivers = ReceiverQueue<T>()
}

/// A Lock used for synchronizing access to the receiver queue
protocol Lock {
    init()
    func lock()
    func unlock()
    func withLock<T>(_ f: () throws -> T) rethrows -> T
    var isReentrant: Bool { get }
}

/// A no-op `Lock` implementation
final class NoLock : Lock {
    init() {
    }

    func lock() {
    }

    func unlock() {
    }

    func withLock<T>(_ f: () throws -> T) rethrows -> T {
        return try f()
    }

    var isReentrant: Bool { return true }
}

/// A `Lock` implementation that uses a `pthread_mutex_t`
final class ReentrantLock : Lock {
    var mutex = pthread_mutex_t()
    var mutexAttr = pthread_mutexattr_t()

    #if os(Linux)
    typealias PTHREAD_ATTR_TYPE = Int
    #else
    typealias PTHREAD_ATTR_TYPE = Int32
    #endif

    convenience init() {
        self.init(attr: PTHREAD_MUTEX_RECURSIVE)
    }

    var isReentrant: Bool {
        var attr: Int32 = 0
        assertSuccess(pthread_mutexattr_gettype(&mutexAttr, &attr))
        return attr == PTHREAD_MUTEX_RECURSIVE
    }

    init(attr: PTHREAD_ATTR_TYPE = PTHREAD_MUTEX_RECURSIVE) {
        assertSuccess(pthread_mutexattr_init(&mutexAttr))
        assertSuccess(pthread_mutexattr_settype(&mutexAttr, Int32(attr)))
        assertSuccess(pthread_mutex_init(&mutex, &mutexAttr))
    }

    deinit {
        assertSuccess(pthread_mutex_destroy(&mutex))
        assertSuccess(pthread_mutexattr_destroy(&mutexAttr))
    }

    func lock() {
        assertSuccess(pthread_mutex_lock(&self.mutex))
    }

    func unlock() {
        assertSuccess(pthread_mutex_unlock(&self.mutex))
    }

    func withLock<T>(_ f: () throws -> T) rethrows -> T {
        assertSuccess(pthread_mutex_lock(&self.mutex))
        defer { assertSuccess(pthread_mutex_unlock(&self.mutex)) }
        return try f()
    }

    func assertSuccess(_ f: @autoclosure () -> Int32) {
        let success = f()
        assert(success == 0, "critical error – pthread call failed \(success)")
    }
}

#if !(os(Linux))
/// A `Lock` implementation that uses an `os_unfair_lock`
@available(macOS 10.12, iOS 10.0, *)
final class UnfairLock : Lock {
    var unfairLock = os_unfair_lock_s()

    init() {
    }

    var isReentrant: Bool {
        return false
    }

    func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

    func withLock<T>(_ f: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return try f()
    }

    func tryLock<T>(_ f: () throws -> T) rethrows -> T? {
        if !os_unfair_lock_trylock(&unfairLock) { return nil }
        defer { os_unfair_lock_unlock(&unfairLock) }
        return try f()
    }
}
#endif


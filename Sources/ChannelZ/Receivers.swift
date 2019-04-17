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

    fileprivate var receivers: ContiguousArray<(index: Int64, receptor: Receptor)> = []
    fileprivate let entrancy: Counter = 0
    fileprivate let receptorIndex: Counter = 0

    public var count: Int { return receivers.count }
    fileprivate let lock: Lock

    public init(maxdepth: Int? = nil, lock: Lock = ReentrantLock()) {
        self.maxdepth = maxdepth ?? ChannelZReentrancyLimit
        self.lock = lock
    }

    public func receive(_ element: T) {
        lock.withLock {
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
    @usableFromInline let receivers = ReceiverQueue<T>()
}

/// A Lock used for synchronizing access to the receiver queue
public protocol Lock {
    init()
    func lock()
    func unlock()
    func withLock<T>(_ f: () throws -> T) rethrows -> T
    var isReentrant: Bool { get }
}

/// A no-op `Lock` implementation
public final class NoLock : Lock {
    public init() {
    }

    public func lock() {
    }

    public func unlock() {
    }

    public func withLock<T>(_ f: () throws -> T) rethrows -> T {
        return try f()
    }

    public var isReentrant: Bool { return true }
}

/// A `Lock` implementation that uses a `pthread_mutex_t`
public final class ReentrantLock : Lock {
    fileprivate var mutex = pthread_mutex_t()
    fileprivate var mutexAttr = pthread_mutexattr_t()

    #if os(Linux)
    public typealias PTHREAD_ATTR_TYPE = Int
    #else
    public typealias PTHREAD_ATTR_TYPE = Int32
    #endif

    public convenience init() {
        self.init(attr: PTHREAD_MUTEX_RECURSIVE)
    }

    public var isReentrant: Bool {
        // pthread_mutexattr_gettype(<#T##UnsafePointer<pthread_mutexattr_t>#>, <#T##UnsafeMutablePointer<Int32>#>)
        return true
    }

    public init(attr: PTHREAD_ATTR_TYPE = PTHREAD_MUTEX_RECURSIVE) {
        pthread_mutexattr_init(&mutexAttr)
        pthread_mutexattr_settype(&mutexAttr, Int32(attr))
        pthread_mutex_init(&mutex, &mutexAttr)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
        pthread_mutexattr_destroy(&mutexAttr)
    }

    public func lock() {
        pthread_mutex_lock(&self.mutex)
    }

    public func unlock() {
        pthread_mutex_unlock(&self.mutex)
    }

    public func withLock<T>(_ f: () throws -> T) rethrows -> T {
        pthread_mutex_lock(&self.mutex)
        defer { pthread_mutex_unlock(&self.mutex) }
        return try f()
    }
}

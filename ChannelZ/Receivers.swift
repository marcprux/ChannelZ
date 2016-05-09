//
//  Receptors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import Darwin // for OSAtomicIncrement64

/// An `Receipt` is the result of `receive`ing to a Observable or Channel
public protocol Receipt : class {

    /// Whether the receipt is cancelled or not
    var cancelled: Bool { get }

    /// Disconnects this receptor from the source
    func cancel()
}

// A receipt implementation
public class ReceiptOf: Receipt {
    public var cancelled: Bool { return cancelCounter > 0 }
    private var cancelCounter: Int64 = 0

    let canceler: () -> ()

    public init(canceler: () -> ()) {
        self.canceler = canceler
    }

    /// Creates a Receipt backed by one or more other Receipts
    public init(receipts: [Receipt]) {
        // no receipts means that it is cancelled already
        if receipts.count == 0 { cancelCounter = 1 }
        self.canceler = { for s in receipts { s.cancel() } }
    }

    /// Creates a Receipt backed by another Receipt
    public convenience init(receipt: Receipt) {
        self.init(receipts: [receipt])
    }

    /// Creates an empty cancelled Receipt
    public convenience init() {
        self.init(receipts: [])
    }

    /// Disconnects this receipt from the source observable
    public func cancel() {
        // only cancel the first time
        if OSAtomicIncrement64(&cancelCounter) == 1 {
            canceler()
        }
    }
}

/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

#if DEBUG_CHANNELZ
    /// Global number of times a reentrant invocation was made
    public var ChannelZReentrantReceptions = Int64(0)
#endif

/// A ReceiverQueue manages a list of receivers and handles dispatching pulses to all the receivers
public final class ReceiverQueue<T> : ReceiverType {
    public typealias Receptor = T -> ()
    public let maxdepth: Int

    private var receivers: [(index: Int64, receptor: Receptor)] = []
    private var entrancy: Int64 = 0
    private var receptorIndex: Int64 = 0

    public var count: Int { return receivers.count }
    private let lock: Lock

    public init(maxdepth: Int? = nil, lock: Lock = ReentrantLock()) {
        self.maxdepth = maxdepth ?? ChannelZReentrancyLimit
        self.lock = lock
    }

    public func receive(element: T) {
        lock.withLock {
            let currentEntrancy = OSAtomicIncrement64(&entrancy)
            defer { OSAtomicDecrement64(&entrancy) }
            if currentEntrancy > maxdepth + 1 {
                reentrantChannelReception(element)
            } else {
                for (_, receiver) in receivers {
                    receiver(element)
                }
            }
        }
    }

    public func reentrantChannelReception(element: Any) {
        #if DEBUG_CHANNELZ
            print("ChannelZ reentrant channel short-circuit; break on \(#function) to debug", element.dynamicType)
            OSAtomicIncrement64(&ChannelZReentrantReceptions)
        #endif
    }

    /// Adds a receiver that will return a receipt that simply removes itself from the list
    public func addReceipt(receptor: Receptor) -> Receipt {
        let token = addReceiver(receptor)
        return ReceiptOf(canceler: { self.removeReceptor(token) })
    }

    /// Adds a custom receiver block and returns a token that can later be used to remove the receiver
    public func addReceiver(receptor: Receptor) -> Int64 {
        precondition(entrancy == 0, "cannot add to receivers while they are flowing")
        let index = OSAtomicIncrement64(&receptorIndex)
        receivers.append((index, receptor))
        return index
    }

    public func removeReceptor(index: Int64) {
        receivers = receivers.filter { $0.index != index }
    }

    /// Clear all the receivers
    public func clear() {
        receivers = []
    }
}

public class ReceiverQueueSource<T> {
    let receivers = ReceiverQueue<T>()
}

/// A Lock used for synchronizing access to the receiver queue
public protocol Lock {
    func lock()
    func unlock()
    func withLock<T>(@noescape f: () throws -> T) rethrows -> T
}

/// A no-op `Lock` implementation
public final class NoLock : Lock {
    public func lock() {
    }

    public func unlock() {
    }

    public func withLock<T>(@noescape f: () throws -> T) rethrows -> T {
        return try f()
    }
}

/// A `Lock` implementation that uses an `OSSpinLock`
public final class SpinLock : Lock {
    var spinLock: OSSpinLock = OS_SPINLOCK_INIT

    public func lock() {
        OSSpinLockLock(&spinLock)
    }

    public func unlock() {
        OSSpinLockUnlock(&spinLock)
    }

    public func withLock<T>(@noescape f: () throws -> T) rethrows -> T {
        OSSpinLockLock(&spinLock)
        defer { OSSpinLockUnlock(&spinLock) }
        return try f()
    }

    public func tryLock<T>(@noescape f: () throws -> T) rethrows -> T? {
        if !OSSpinLockTry(&spinLock) { return nil }
        defer { OSSpinLockUnlock(&spinLock) }
        return try f()
    }
}

/// A `Lock` implementation that uses a `pthread_mutex_t`
public final class ReentrantLock : Lock {
    private var mutex = pthread_mutex_t()
    private var mutexAttr = pthread_mutexattr_t()

    public init(attr: Int32 = PTHREAD_MUTEX_RECURSIVE) {
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

    public func withLock<T>(@noescape f: () throws -> T) rethrows -> T {
        pthread_mutex_lock(&self.mutex)
        defer { pthread_mutex_unlock(&self.mutex) }
        return try f()
    }
}

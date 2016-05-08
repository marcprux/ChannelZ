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

    public init(maxdepth: Int? = nil) {
        self.maxdepth = maxdepth ?? ChannelZReentrancyLimit
    }

    public func receive(element: T) {
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

private protocol Lock {
    func lock()
    func unlock()
    func withLock<T>(f: () throws -> T) rethrows -> T
    func tryLock<T>(f: () throws -> T) rethrows -> T?
}

private final class SpinLock : Lock {
    var spinLock: OSSpinLock = OS_SPINLOCK_INIT

    func lock() {
        OSSpinLockLock(&spinLock)
    }

    func unlock() {
        OSSpinLockUnlock(&spinLock)
    }

    func withLock<T>(f: () throws -> T) rethrows -> T {
        OSSpinLockLock(&spinLock)
        defer { OSSpinLockUnlock(&spinLock) }
        return try f()
    }

    func tryLock<T>(f: () throws -> T) rethrows -> T? {
        if !OSSpinLockTry(&spinLock) { return nil }
        defer { OSSpinLockUnlock(&spinLock) }
        return try f()
    }
}

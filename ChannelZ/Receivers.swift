//
//  Receptors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import Dispatch

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

///// A no-op receipt that warns that an attempt was made to receive to a deallocated weak target
//struct DeallocatedTargetReceptor : Receptor {
//    func cancel() { }
//    func request() { }
//}


/// A simple GCD-based locking scheme
struct QueueLock {
    let lock: dispatch_queue_t

    init(name: String) {
        lock = dispatch_queue_create(name, nil)
    }

    func lock<T>(f: () -> T) -> T {
        var value: T?
        dispatch_sync(lock) {
            value = f()
        }
        return value!
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
    private let lockQueue = dispatch_queue_create("io.Glimpse.ReceiverQueue.LockQueue", DISPATCH_QUEUE_CONCURRENT)

    public var count: Int { return receivers.count }

    public init(maxdepth: Int = ChannelZReentrancyLimit) {
        self.maxdepth = maxdepth
    }

//    private func synchronized<X>(lockObj: AnyObject, closure: () -> X) -> X {
//        var retVal: X?
//        dispatch_sync(lockQueue) {
//            retVal = closure()
//        }
//        return retVal!
//    }

    private func synchronized<X>(lockObj: AnyObject, @noescape closure: () throws -> X) rethrows -> X {
        objc_sync_enter(lockObj)
        defer { objc_sync_exit(lockObj) }
        return try closure()
    }

    public func receive(element: T) {
        synchronized(self) {
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

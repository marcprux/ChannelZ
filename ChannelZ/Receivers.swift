//
//  Receptors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import ObjectiveC // uses for synchronizing ReceiverList with objc_sync_enter

/// An `Receipt` is the result of `receive`ing to a Observable or Channel
public protocol Receipt {

    /// Whether the receipt is cancelled or not
    var cancelled: Bool { get }

    /// Disconnects this receptor from the source
    func cancel()
}

// A receipt implementation
public class ReceiptOf: Receipt {
    public private(set) var cancelled: Bool = false
    let canceler: ()->()

    public init(canceler: ()->()) {
        self.canceler = canceler
    }

    /// Creates a Receipt backed by one or more other Receipts
    public init(receipts: [Receipt]) {
        self.cancelled = receipts.count == 0 // no receipts means that it is cancelled already
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
        if !cancelled { canceler() }
        cancelled = true
    }
}

///// A no-op receipt that warns that an attempt was made to receive to a deallocated weak target
//struct DeallocatedTargetReceptor : Receptor {
//    func cancel() { }
//    func request() { }
//}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

public final class ReceiverList<T> {
    public let maxdepth: Int
    private var receivers: [(index: Int, receptor: (T)->())] = []
    internal var entrancy: Int = 0
    private var receptorIndex: Int = 0

    public var count: Int { return receivers.count }

    public init(maxdepth: Int = ChannelZReentrancyLimit) {
        self.maxdepth = maxdepth
    }

    private func synchronized<X>(lockObj: AnyObject, closure: ()->X) -> X {
        if objc_sync_enter(lockObj) == Int32(OBJC_SYNC_SUCCESS) {
            let retVal: X = closure()
            objc_sync_exit(lockObj)
            return retVal
        } else {
            fatalError("Unable to synchronize on ReceiverList")
        }
    }

    public func receive(element: T) {
        synchronized(self) { ()->(Void) in
            if self.entrancy++ > self.maxdepth {
                #if DEBUG_CHANNELZ
//                    println("re-entrant value change limit of \(maxdepth) reached for receivers")
                #endif
            } else {
                for (_, receptor) in self.receivers { receptor(element) }
            }
            self.entrancy--
        }
    }

    /// Adds a receiver that will return a receipt that simply removes itself from the list
    public func addReceipt(receptor: (T)->())->Receipt {
        let token = addReceiver(receptor)
        return ReceiptOf(canceler: { self.removeReceptor(token) })
    }

    /// Adds a custom receiver block and returns a token that can later be used to remove the receiver
    public func addReceiver(receptor: (T)->())->Int {
        return synchronized(self) {
            let index = self.receptorIndex++
            precondition(self.entrancy == 0, "cannot add to receivers while they are flowing")
            self.receivers += [(index, receptor)]
            return index
        }
    }

    public func removeReceptor(index: Int) {
        synchronized(self) {
            self.receivers = self.receivers.filter { $0.index != index }
        }
    }

    /// Clear all the receivers
    public func clear() {
        synchronized(self) {
            self.receivers = []
        }
    }
}

/// A TrapReceipt is a receptor to a channel that retains a number of values (default 1) when they are sent by the source
public class TrapReceipt<C where C: ChannelType>: Receipt {
    public var cancelled: Bool = false
    public let channel: C

    /// Returns the last value to be added to this trap
    public var value: C.Element? { return values.last }

    /// All the values currently held in the trap
    public var values: [C.Element]

    public let capacity: Int

    private var receipt: Receipt?

    public init(channel: C, capacity: Int) {
        self.channel = channel
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let receipt = channel.receive({ [weak self] (value) -> Void in
            let _ = self?.receive(value)
        })
        self.receipt = receipt
    }

    deinit { receipt?.cancel() }
    public func cancel() { receipt?.cancel() }

    public func receive(value: C.Element) {
        while values.count >= capacity {
            values.removeAtIndex(0)
        }

        values.append(value)
    }
}

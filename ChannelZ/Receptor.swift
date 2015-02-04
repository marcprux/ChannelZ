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

    /// Requests that the source issue an element to this receptor; note that priming does not guarantee that the receptor will be received since the underlying source may be push-only source or the element may be blocked by an intermediate filter
    func request()
}

/// A type-erased receipt.
///
/// Forwards operations to an arbitrary underlying receipt with the same
/// `Element` type, hiding the specifics of the underlying receipt.
public class ReceiptOf: Receipt {
    public private(set) var cancelled: Bool = false
    let requester: ()->()
    let canceller: ()->()

    internal init(requester: ()->(), canceller: ()->()) {
        self.requester = requester
        self.canceller = canceller
    }

    /// Creates a Receipt backed by one or more other Receipts
    public init(receipts: [Receipt]) {
        self.cancelled = receipts.count == 0 // no receipts means that it is cancelled already
        self.requester = { for s in receipts { s.request() } }
        self.canceller = { for s in receipts { s.cancel() } }
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
        if !cancelled { canceller() }
        cancelled = true
    }

    public func request() {
        if !cancelled { requester() }
    }
}

///// A no-op receipt that warns that an attempt was made to receive to a deallocated weak target
//struct DeallocatedTargetReceptor : Receptor {
//    func cancel() { }
//    func request() { }
//}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

final class ReceiverList<T> {
    private var receivers: [(index: Int, receptor: (T)->())] = []
    internal var entrancy: Int = 0
    private var receptorIndex: Int = 0

    var count: Int { return receivers.count }

    private func synchronized<X>(lockObj: AnyObject!, closure: ()->X) -> X {
        if objc_sync_enter(lockObj) == Int32(OBJC_SYNC_SUCCESS) {
            var retVal: X = closure()
            objc_sync_exit(lockObj)
            return retVal
        } else {
            fatalError("Unable to synchronize on ReceiverList")
        }
    }

    func receive(element: T) {
        synchronized(self) { ()->(Void) in
            if self.entrancy++ > ChannelZReentrancyLimit {
                #if DEBUG_CHANNELZ
                    println("re-entrant value change limit of \(ChannelZReentrancyLimit) reached for receivers")
                #endif
            } else {
                for (index, receptor) in self.receivers { receptor(element) }
            }
            self.entrancy--
        }
    }

    func addReceipt(receptor: (T)->(), requestor: ()->(T?))->Receipt {
        let token = addReceiver(receptor)
        return ReceiptOf(requester: { if let x = requestor() { self.receive(x) } }, canceller: { self.removeReceptor(token) })
    }

    func addReceiver(receptor: (T)->())->Int {
        return synchronized(self) {
            let index = self.receptorIndex++
            precondition(self.entrancy == 0, "cannot add to receivers while they are flowing")
            self.receivers += [(index, receptor)]
            return index
        }
    }

    func removeReceptor(index: Int) {
        synchronized(self) {
            self.receivers = self.receivers.filter { $0.index != index }
        }
    }

    /// Clear all the receivers
    func clear() {
        synchronized(self) {
            self.receivers = []
        }
    }
}

/// Requests the receptor and returns the receptor itself
internal func request(receipt: Receipt) -> Receipt {
    receipt.request()
    return receipt
}


/// A TrapReceipt is a receptor to a observable that retains a number of values (default 1) when they are sent by the source
public class TrapReceipt<S, T>: Receipt {
    public var cancelled: Bool = false
    public let source: Channel<S, T>

    /// Returns the last value to be added to this trap
    public var value: T? { return values.last }

    /// All the values currently held in the trap
    public var values: [T]

    public let capacity: Int

    private var receipt: Receipt?

    public init(source: Channel<S, T>, capacity: Int) {
        self.source = source
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let receipt = source.receive({ [weak self] (value) -> Void in
            let _ = self?.receive(value)
        })
        self.receipt = receipt
    }

    deinit { receipt?.cancel() }
    public func cancel() { receipt?.cancel() }
    public func request() { receipt?.request() }

    public func receive(value: T) {
        while values.count >= capacity {
            values.removeAtIndex(0)
        }

        values.append(value)
    }
}

/// Creates a trap for the last `capacity` (default 1) events of the `source` observable
public func trap<S, T>(source: Channel<S, T>, capacity: Int = 1) -> TrapReceipt<S, T> {
    return TrapReceipt(source: source, capacity: capacity)
}

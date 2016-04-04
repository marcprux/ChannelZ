//
//  Stream.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 4/3/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//


/// A StreamType emits elements to receivers added via the `receive` function.
public protocol StreamType {
    associatedtype Element

    /// Adds the given receiver block to be executed with the pulses that pass through this stream.
    ///
    /// - Parameter receiver: the block to be executed whenever this Stream pulses an item
    ///
    /// - Returns: A `Receipt`, which can be used to later `cancel` reception
    func receive(receiver: Element -> Void) -> Receipt

    /// Creates a new form of this stream type with the given reception
    @warn_unused_result func phase(reception: (Self.Element -> Void) -> Receipt) -> Self
}


/// Utilites for creating the special trap receipt (useful for testing)
public extension StreamType {
    /// Adds a receiver that will retain a certain number of values
    public func trap(capacity: Int = 1) -> TrapReceipt<Self> {
        return TrapReceipt(stream: self, capacity: capacity)
    }
}

/// A TrapReceipt is a receptor to a stream that retains a number of values (default 1) when they are sent by the source
public class TrapReceipt<C where C: StreamType>: Receipt {
    public var cancelled: Bool = false
    public let stream: C

    /// Returns the last value to be added to this trap
    public var value: C.Element? { return values.last }

    /// All the values currently held in the trap
    public var values: [C.Element]

    public let capacity: Int

    private var receipt: Receipt?

    public init(stream: C, capacity: Int) {
        self.stream = stream
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let receipt = stream.receive({ [weak self] (value) -> Void in
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


public extension StreamType {

    /// Lifts a function to the current Stream and returns a new phase that when received to will pass
    /// the values of the current stream through the Operator function.
    ///
    /// - Parameter receptor: The functon that transforms one receiver to another
    ///
    /// - Returns: The new stream
    @warn_unused_result private func luft(receptor: (Element -> Void) -> (Element -> Void)) -> Self {
        return phase { receiver in self.receive(receptor(receiver)) }
    }

    /// Adds a stream phase which only emits those pulses for which a given predicate holds.
    ///
    /// - Parameter predicate: a function that evaluates the pulses emitted by the source stream,
    ///   returning `true` if they pass the filter
    ///
    /// - Returns: A stateless stream that emits only those pulses in the original stream that the filter evaluates as `true`
    @warn_unused_result public func filter(predicate: Element -> Bool) -> Self {
        return luft { receive in { item in if predicate(item) { receive(item) } } }
    }

    /// Adds a stream phase that drops any pulses that are immediately emitted upon a receiver being added but
    /// passes any pulses that are emitted after the receiver is added.
    /// In ReactiveX parlance, this convert this `observable` stream from `cold` to `hot`
    ///
    /// - Returns: A stream that drops any elements that are emitted upon a receiver being added
    @warn_unused_result public func subsequent() -> Self {
        return phase { receiver in
            var immediate = true
            let receipt = self.receive { item in if !immediate { receiver(item) } }
            immediate = false
            return receipt
        }
    }

    /// Adds a stream phase that will cease sending pulses once the terminator predicate is satisfied.
    ///
    /// - Parameter terminator: A predicate function that will result in cancellation of all receipts when it evaluates to `true`
    /// - Parameter includeFinal: Whether to send the final pulse to receivers before terminating (defaults to `false`)
    /// - Parameter terminus: An optional final sentinal closure that will be sent once after the `terminator` evaluates to `true`
    ///
    /// - Returns: A stateful stream that emits pulses until the `terminator` evaluates to true
    @warn_unused_result public func terminate(terminator: Element -> Bool, includeFinal: Bool = false, terminus: (() -> Element)? = nil) -> Self {
        var receipts: [Receipt] = []
        var terminated = false

        return phase { receiver in
            let receipt = self.receive { item in
                if terminated { return }
                if terminator(item) {
                    if includeFinal {
                        receiver(item)
                    }

                    terminated = true
                    if let terminus = terminus {
                        receiver(terminus())
                    }
                    for r in receipts { r.cancel() }
                } else {
                    receiver(item)
                }
            }
            receipts += [receipt]
            return receipt
        }
    }

    /// Adds a stream phase that will terminate receipt after the given number of pulses have been received
    @warn_unused_result public func take(count: Int = 1) -> Self {
        var c = count
        return terminate({ _ in c -= 1; return c < 0 })
    }

    /// Adds a stream phase that spits the stream in two, where the first stream accepts elements that
    /// fail the given predicate filter, and the second stream emits the elements that pass the predicate
    /// (mnemonic: "right" also means "correct").
    ///
    /// Note that the predicate will be evaluated exactly twice for each emitted item
    ///
    /// - Parameter predicate: a function that evaluates the pulses emitted by the source stream,
    ///   returning `true` if they pass the filter
    ///
    /// - Returns: A stateless stream pair that passes elements depending on whether they pass or fail the predicate, respectively
    public func split(predicate: Element -> Bool) -> (unfiltered: Self, filtered: Self) {
        return (filter({ !predicate($0) }), filter(predicate))
    }
}

/// A IndexedPulse is a pulse that is able to provide a unique per-emission token,
/// which can be used for intermediate stream phases that need to track some sort of state.
/// For example, if a `filter` phase needs to permit only a certain number pulses to pass through,
/// this would need to store a `stateCount`, but since the entire stream phase pipeline
/// is re-evaluated for each receiver, the `stateCount` would wind up being M*N, where
/// M is the number of pulses received and N is the number or receivers. The `index` token
/// can be used to only update the state when new pulse has been received.
public protocol IndexedPulseType {
    associatedtype Index : ForwardIndexType
    var index: Index { get }
}

/// An enumerated pulse with a single `ForwardIndexType` index and an item of the underlying type
public protocol EnumeratedPulseType : IndexedPulseType {
    associatedtype Element
    associatedtype Index : ForwardIndexType

    var item: Element { get }
    var index: Index  { get }
}

/// An indexed pulse with a single index, which is an `Int` (just as `EnumerateGenerator` has an `Int` index)
public struct EnumeratedPulse<Element> : EnumeratedPulseType {
    public let item: Element
    public let index: Int

    public init(index: Int, item: Element) {
        self.index = index
        self.item = item
    }
}

public extension StreamType where Element : IndexedPulseType {

    /// A function that executes the given closure only if the pulse is a new distinct pulse.
    /// It can be used as a wrapper for state management of indexed pulses, such as
    /// mapping over a distinct value for pulse issuance.
    @warn_unused_result public func pulsar<T>(f: Element -> T) -> Element -> T? {
        var lastPulseIndex: Element.Index? = nil

        func isNewPulse(value: Element) -> Bool {
            let index = value.index
            if lastPulseIndex == nil || lastPulseIndex! != index {
                lastPulseIndex = index
                return true
            } else {
                return false
            }
        }

        return { isNewPulse($0) ? f($0) : nil }
    }
}

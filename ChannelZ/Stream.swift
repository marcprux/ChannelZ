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

    /// Adds a stream phase that drops the first `count` elements.
    ///
    /// Analogous to `CollectionType.dropFirst`
    ///
    /// - Parameter count: the number of elements to skip before emitting pulses
    ///
    /// - Returns: A stateful Channel that drops the first `count` elements.
    @warn_unused_result func dropFirst(count: Int) -> Self

    /// Adds a stream phase that will send only the specified number of pulses.
    ///
    /// Analogous to `CollectionType.prefix`
    ///
    /// - Parameter count: the number of elements to skip before emitting pulses
    ///
    /// - Returns: A stateful Channel that drops the first `count` elements.
    @warn_unused_result func prefix(count: Int) -> Self
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
    @warn_unused_result private func lift(receptor: (Element -> Void) -> (Element -> Void)) -> Self {
        return phase { self.receive(receptor($0)) }
    }

    /// Adds a stream phase which only emits those pulses for which a given predicate holds.
    ///
    /// - Parameter predicate: a function that evaluates the pulses emitted by the source stream,
    ///   returning `true` if they pass the filter
    ///
    /// - Returns: A stateless stream that emits only those pulses in the original stream that the filter evaluates as `true`
    @warn_unused_result public func filter(predicate: Element -> Bool) -> Self {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
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
}

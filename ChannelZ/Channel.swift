//
//  Channel.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

// MARK: Channel Basics

/// A StreamType is a sourceless stream that emits elements
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

/// A ChannelType is a StreamType with the addition of a Source
public protocol ChannelType : StreamType {
    associatedtype Source

    /// The underlying unconstrained source of this `Channel`
    var source: Source { get }

    /// Derives a new channel with the given source
    @warn_unused_result func resource<X>(newsource: Source -> X) -> Channel<X, Element>
}

/// A Channel is a passive multi-phase receiver of items of a given type: `pulses`. It is a push-based version
/// of Swift's pull-based `Generator` type. Channels can add phases that transform, filter, merge
/// and aggregate pulses that are passed through the channel. They are well-suited to handling
/// asynchronous stream of events such as networking and UI interactions.
///
/// To listen for pulses, call the `receive` function with a closure that accepts the Channel's element type.
/// This will return a `Receipt`, which can later be used to cancel reception.  A `Channel` can have multiple
/// receivers active, and receivers can be added to different phases of the Channel without interfering with each other.
///
/// A `Channel` is roughly analogous to the `Observable` in the ReactiveX pattern, as described at:
/// http://reactivex.io/documentation/observable.html
/// The primary differences are that a `Channel` keeps a reference to its source which allows `conduit`s
/// to be created, and that a `Channel` doesn't have any `onError` or `onCompletion`
/// signal handlers, which means that a `Channel` is effectively infinite.
/// Error and completion handling should be implemented at a higher level, where, for example, they
/// might be supported by having the Channel's Element type be a Swift enum with cases for
/// `.Value(T)`, `.Error(X)`, and `.Completion`, and by adding a `terminate` phase to the `Channel`
public struct Channel<S, T> : ChannelType {
    public typealias Source = S
    public typealias Element = T

    public let source: S

    /// The closure that will be performed whenever a pulse is emitted; analogous to ReactiveX's `onNext`
    public typealias Receiver = T -> Void

    /// The closure to be executed whenever a receiver is added, where all the receiver logic is performed
    private let reception: Receiver -> Receipt

    public init(source: S, reception: Receiver -> Receipt) {
        self.source = source
        self.reception = reception
    }

    @warn_unused_result public func phase(reception: (Element -> Void) -> Receipt) -> Channel {
        return Channel(source: self.source, reception: reception)
    }

    /// Adds a receiver block that will accept the output pulses of the channel
    public func receive(receiver: T -> Void) -> Receipt {
        return reception(receiver)
    }

    /// Derives a new channel with the given source
    @warn_unused_result public func resource<X>(newsource: S -> X) -> Channel<X, T> {
        return Channel<X, T>(source: newsource(source), reception: reception)
    }

    /// Erases the source type from this `Channel` to `Void`, which can be useful for simplyfying the signature
    /// for functions that don't care about the source's type or for channel phases that want to ensure the source
    /// cannot be accessed from future phases
    @warn_unused_result public func desource() -> Channel<Void, T> {
        return resource({ _ in Void() })
    }

}

public extension StreamType {

    /// Lifts a function to the current Stream and returns a new channel phase that when received to will pass
    /// the values of the current Channel through the Operator function.
    ///
    /// - Parameter receptor: The functon that transforms one receiver to another
    ///
    /// - Returns: The new Channel
    @warn_unused_result public func lift(receptor: (Element -> Void) -> (Element -> Void)) -> Self {
        return phase { receiver in self.receive(receptor(receiver)) }
    }

    /// Adds a channel phase which only emits those pulses for which a given predicate holds.
    ///
    /// - Parameter predicate: a function that evaluates the pulses emitted by the source Channel,
    ///   returning `true` if they pass the filter
    ///
    /// - Returns: A stateless Channel that emits only those pulses in the original Channel that the filter evaluates as `true`
    @warn_unused_result public func filter(predicate: Element -> Bool) -> Self {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
    }

}

/// MARK: Stateful Channel operations (accumulators, etc.)
public extension StreamType {

    /// Adds a channel phase that drops any pulses that are immediately emitted upon a receiver being added but
    /// passes any pulses that are emitted after the receiver is added.
    /// In ReactiveX parlance, this convert this `observable` Channel from `cold` to `hot`
    ///
    /// - Returns: A Channel that drops any elements that are emitted upon a receiver being added
    @warn_unused_result public func subsequent() -> Self {
        return phase { receiver in
            var immediate = true
            let receipt = self.receive { item in if !immediate { receiver(item) } }
            immediate = false
            return receipt
        }
    }
}

public extension StreamType {

    /// Adds a channel phase that will cease sending pulses once the terminator predicate is satisfied.
    ///
    /// - Parameter terminator: A predicate function that will result in cancellation of all receipts when it evaluates to `true`
    /// - Parameter includeFinal: Whether to send the final pulse to receivers before terminating (defaults to `false`)
    /// - Parameter terminus: An optional final sentinal closure that will be sent once after the `terminator` evaluates to `true`
    ///
    /// - Returns: A stateful Channel that emits pulses until the `terminator` evaluates to true
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

    /// Adds a channel phase that will terminate receipt after the given number of pulses have been received
    @warn_unused_result public func take(count: Int = 1) -> Self {
        var c = count
        return terminate({ _ in c -= 1; return c < 0 })
    }
}

public extension StreamType {
    /// Adds a channel phase that spits the channel in two, where the first channel accepts elements that
    /// fail the given predicate filter, and the second channel emits the elements that pass the predicate
    /// (mnemonic: "right" also means "correct").
    ///
    /// Note that the predicate will be evaluated exactly twice for each emitted item
    ///
    /// - Parameter predicate: a function that evaluates the pulses emitted by the source Channel,
    ///   returning `true` if they pass the filter
    ///
    /// - Returns: A stateless Channel pair that passes elements depending on whether they pass or fail the predicate, respectively
    public func split(predicate: Element -> Bool) -> (unfiltered: Self, filtered: Self) {
        return (filter({ !predicate($0) }), filter(predicate))
    }
}


public extension ChannelType {

    /// Lifts a function to the current Channel and returns a new channel phase that when received to will pass
    /// the values of the current Channel through the Operator function.
    ///
    /// - Parameter receptor: The functon that transforms one receiver to another
    ///
    /// - Returns: The new Channel
    @warn_unused_result public func lift2<Element2>(receptor: (Element2 -> Void) -> (Element -> Void)) -> Channel<Source, Element2> {
        return Channel<Source, Element2>(source: source) { receiver in self.receive(receptor(receiver)) }
    }

    /// Adds a channel phase that applies the given function to each item emitted by a Channel and emits the result.
    ///
    /// - Parameter transform: a function to apply to each item emitted by the Channel
    ///
    /// - Returns: A stateless Channel that emits the pulses from the source Channel, transformed by the given function
    @warn_unused_result public func map<U>(transform: Element -> U) -> Channel<Source, U> {
        return lift2 { receive in { item in receive(transform(item)) } }
    }
}

public extension ChannelType {

    /// Adds a channel phase with the result of repeatedly calling `combine` with an accumulated value
    /// initialized to `initial` and each element of `self`, in turn
    ///
    /// - Parameter initial: the initial accumulated value
    /// - Parameter combine: the accumulator function that will return the accumulation; the final funcation tuple
    ///   element should be called ad a side-effect to cause the accumulation to be pulsed
    @warn_unused_result public func reduce<U>(initial: U, combine: (U, Element, U -> Void) -> U) -> Channel<Source, U> {
        var accumulation = initial
        return lift2 { receive in { item in accumulation = combine(accumulation, item, receive) } }
    }

    /// Accumulate the given pulses into an array until the given predicate is satisifed, and
    /// then flush all the elements of the array.
    ///
    /// - Parameter predicate: that will cause the accumulated elements to be pulsed
    ///
    /// - Returns: A stateful Channel that maintains an accumulation of elements
    @warn_unused_result public func accumulate(predicate: ([Element], Element) -> Bool) -> Channel<Source, [Element]> {
        return reduce([]) { a, x, f in predicate(a, x) ? { f(a+[x]); return [] }() : a+[x] }
    }

    /// Adds a channel phase that buffers emitted pulses such that the receiver will
    /// receive a array of the buffered pulses
    ///
    /// - Parameter count: the size of the buffer
    ///
    /// - Returns: A stateful Channel that buffers its pulses until it the buffer reaches `count`
    @warn_unused_result public func buffer(count: Int) -> Channel<Source, [Element]> {
        // note: a more optimized version of this could append to a single buffer with capacity set the count
        // similar to how Java 8 streams implement their "mutable reduction operation" collect() method
        // http://docs.oracle.com/javase/8/docs/api/java/util/stream/package-summary.html#MutableReduction
        return accumulate { a, x in a.count >= count-1 }
    }

    /// Adds a channel phase that aggregates pulses with the given combine function and then
    /// emits the pulses when the partition predicate is satisified.
    ///
    /// - Parameter initial: the initial accumulated value
    /// - Parameter combine: the combinator function to call with the accumulated value
    /// - Parameter isPartition: the predicate that signifies whether an item should cause the 
    ///   accumulated value to be emitted and cleared
    /// - Parameter withPartitions: if true (the default), then terminator pulses will be included in the accumulation
    /// - Parameter clearAfterPulse: if true (the default), the accumulated value will be cleared after each pulse
    ///
    /// - Returns: A stateful Channel that buffers its accumulated pulses until the terminator predicate passes
    @warn_unused_result public func partition<U>(initial: U, withPartitions: Bool = true, clearAfterPulse: Bool = true, isPartition: (U, Element) -> Bool, combine: (U, Element) -> U) -> Channel<Source, U> {
        return reduce(initial) { (accumulation, item, receive) in
            var acc = accumulation
            if isPartition(acc, item) {
                if withPartitions { acc = combine(acc, item) }
                receive(acc)
                if clearAfterPulse { acc = initial }
            } else {
                acc = combine(acc, item)
            }

            return acc
        }
    }
}


/// A PulseSource provides the notion of a distinct event ID for a current pulse
public protocol DistinctPulseSource {
    var pulseCount: Int64 { get }
}

public extension ChannelType where Source : DistinctPulseSource {

    /// Returns a closure that can be used to determine if the current pulse operation is distinct
    @warn_unused_result internal func distinguishPulse() -> Void -> Bool {
        var lastPulseCount: Int64?
        return {
            let pc = self.source.pulseCount
            if lastPulseCount != pc {
                lastPulseCount = pc
                return true
            } else {
                return false
            }
        }
    }

    /// Adds a channel phase that emits a tuples of pairs (*n*, *x*),
    /// where *n*\ s are consecutive `Int`\ s starting at zero,
    /// and *x*\ s are the elements
    ///
    /// - Returns: A stateful Channel that emits a tuple with the element's index
    @warn_unused_result public func enumerate() -> Channel<Source, (Int, Element)> {
        // since the mapped function will be called for each receiver, we need to ensure that the index is
        // incremented only once per pulse, rather than each time the mapped function is executed
        let isDistinctPulse = distinguishPulse()
        var index: Int = -1

        func pulseIndex(value: Element) -> (Int, Element) {
            if isDistinctPulse() { index += 1 }
            return (index, value)
        }

        return map(pulseIndex)
    }

    /// Adds a channel phase that drops the first `count` elements.
    ///
    /// - Parameter count: the number of elements to skip before emitting pulses
    ///
    /// - Returns: A stateful Channel that drops the first `count` elements.
    @warn_unused_result public func drop(count: Int) -> Channel<Source, Element> {
        return enumerate().filter({ $0.0 >= count }).map({ $0.1 })
    }
}

/// MARK: Muti-Channel combination operations

public extension ChannelType {

    /// Adds a channel phase that flattens two Channels with heterogeneous `Source` and homogeneous `Element`s
    /// into one Channel, without any transformation, so they act like a single Channel. 
    /// 
    /// Note: The resulting Channel's receivers will not be able to distinguish which channel emitted an event;
    /// to access that information, use `either` instead.
    ///
    /// - Parameter with: a Channel to be merged
    ///
    /// - Returns: An stateless Channel that emits pulses from `self` and `with`
    @warn_unused_result public func merge<C2: ChannelType where C2.Element == Element>(with: C2) -> Channel<(Source, C2.Source), Element> {
        return Channel<(Source, C2.Source), Element>(source: (self.source, with.source)) { f in
            return ReceiptOf(receipts: [self.receive(f), with.receive(f)])
        }
    }

    /// Adds a channel phase formed from this Channel and another Channel by combining
    /// corresponding elements in pairs.
    /// The number of receiver invocations of the resulting `Channel<(T, U)>`
    /// is the minumum of the number of invocations of `self` and `with`.
    ///
    /// - Parameter with: the Channel to zip with
    /// - Parameter capacity: (optional) the maximum buffer size for the channels; if either buffer
    ///     exceeds capacity, earlier elements will be dropped silently
    ///
    /// - Returns: A stateful Channel that pairs up values from `self` and `with` Channels.
    @warn_unused_result public func zip<C2: ChannelType>(with: C2, capacity: Int? = nil) -> Channel<(Source, C2.Source), (Element, C2.Element)> {
        return Channel<(Source, C2.Source), (Element, C2.Element)>(source: (self.source, with.source)) { (rcvr: (Element, C2.Element) -> Void) in

            var v1s: [Element] = []
            var v2s: [C2.Element] = []

            let zipper: () -> () = {
                // only send the tuple to the subscription when we have at least one
                while v1s.count > 0 && v2s.count > 0 {
                    rcvr(v1s.removeAtIndex(0), v2s.removeAtIndex(0))
                }

                // trim to capacity if it was specified
                if let capacity = capacity {
                    while v1s.count > capacity {
                        v1s.removeAtIndex(0)
                    }
                    while v2s.count > capacity {
                        v2s.removeAtIndex(0)
                    }
                }
            }

            let rcpt1 = self.receive({ v1 in
                v1s += [v1]
                zipper()
            })

            let rcpt2 = with.receive({ v2 in
                v2s += [v2]
                zipper()
            })
            
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Adds a channel phase that is a combination around `source1` and `source2` that merges elements
    /// into a tuple of the latest vaues that have been received on either channel; note that that 
    /// latest version of each of the channels will be retained, and that no tuples will be emitted
    /// until both the channels have had at least one event. If `source1` emits 2 events followed by
    /// `source` emitting 1 event, only a tuple with `source1`'s second item will be emitted; the first
    /// item will be lost.
    ///
    /// Unlike `zip`, `combine` does not index the values with each other, but instead emits an event
    /// whenever either channel emits an event once it has been primed.
    ///
    /// - Parameter other: the Channel to combine with
    ///
    /// - Returns: A stateful Channel that emits the item of both `self` or `other`.
    @warn_unused_result public func combine<C2: ChannelType>(other: C2) -> Channel<(Source, C2.Source), (Element, C2.Element)> {
        typealias Both = (Element, C2.Element)
        var lasta: Element?
        var lastb: C2.Element?

        return Channel<(Source, C2.Source), Both>(source: (self.source, other.source)) { (rcvr: (Both -> Void)) in
            let rcpt1 = self.receive { a in
                lasta = a
                if let lastb = lastb { rcvr(Both(a, lastb)) }

            }
            let rcpt2 = other.receive { b in
                lastb = b
                if let lasta = lasta { rcvr(Both(lasta, b)) }
            }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Adds a channel phase that is a combination around `source1` and `source2` that merges elements
    /// into a tuple of optionals that will be emitted when either of the elements change.
    /// Unlike `combine`, this phase will begin emitting events immediately upon either of the combined
    /// channels emitting events; previous values are not retained, so this Channel is stateless.
    ///
    /// - Parameter other: the Channel to either with
    ///
    /// - Returns: A stateless Channel that emits the item of either `self` or `other`.
    @warn_unused_result public func either<C2: ChannelType>(other: C2) -> Channel<(Source, C2.Source), (Element?, C2.Element?)> {
        // Note: this should really be a Haskell-style Either enum, but the Swift compiler doesn't yet support them
        typealias Either = (Element?, C2.Element?)
        return Channel<(Source, C2.Source), Either>(source: (self.source, other.source)) { (rcvr: (Either -> Void)) in
            let rcpt1 = self.receive { v1 in rcvr(Either(v1, nil)) }
            let rcpt2 = other.receive { v2 in rcvr(Either(nil, v2)) }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Adds a channel phase that is a combination around `source1` and `source2` that merges elements
    /// into an exclusive enum that will be emitted when either of the elements change.
    /// Unlike `combine`, this phase will begin emitting events immediately upon either of the combined
    /// channels emitting events; previous values are not retained, so this Channel is stateless.
    ///
    /// - Parameter other: the Channel to either with
    ///
    /// - Returns: A stateless Channel that emits the item of either `self` or `other`.
    @warn_unused_result public func oneOf<C2: ChannelType>(other: C2) -> Channel<(Source, C2.Source), OneOf2<Element, C2.Element>> {
        return Channel(source: (self.source, other.source)) { (rcvr: (OneOf2<Element, C2.Element> -> Void)) in
            let rcpt1 = self.receive { v1 in rcvr(OneOf2.V1(v1)) }
            let rcpt2 = other.receive { v2 in rcvr(OneOf2.V2(v2)) }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }
}

public extension ChannelType {

    /// Creates a new channel phase by applying a function that you supply to each item emitted by
    /// the source Channel, where that function returns a Channel, and then merging those
    /// resulting Channels and emitting the results of this merger.
    ///
    /// - Parameter transform: a function that, when applied to an item emitted by the source Channel, returns a Channel
    ///
    /// - Returns: A stateless Channel that emits the result of applying the transformation function to each
    ///         item emitted by the source Channel and merging the results of the Channels
    ///         obtained from this transformation.
    @warn_unused_result public func flatMap<S2, U>(transform: Element -> Channel<S2, U>) -> Channel<(Source, [S2]), U> {
        return flatten(map(transform))
    }
}

public extension Channel {

    @warn_unused_result public func concat(with: Channel<Source, Element>) -> Channel<[Source], (Source, Element)> {
        return concatChannels([self, with])
    }

}

/// Utilites for creating the special trap receipt (useful for testing)
public extension ChannelType {
    /// Adds a receiver that will retain a certain number of values
    public func trap(capacity: Int = 1) -> TrapReceipt<Self> {
        return TrapReceipt(channel: self, capacity: capacity)
    }
}

/// Concatinates multiple channels with the same source and element types into a single channel;
/// note that the source is incuded in a tuple with the element in order to identify which source emitted the pulse
@warn_unused_result public func concatChannels<S, T>(channels: [Channel<S, T>]) -> Channel<[S], (S, T)> {
    return Channel<[S], (S, T)>(source: channels.map({ c in c.source })) { f in
        return ReceiptOf(receipts: channels.map({ c in c.map({ e in (c.source, e) }).receive(f) }))
    }
}

/// Flattens a Channel that emits Channels into a single Channel that emits the pulses emitted by
/// those Channels, without any transformation.
/// Note: this operation does not retain the sub-sources, since it can merge a heterogeneously-sourced series of channels
@warn_unused_result public func flatten<S1, S2, T>(channel: Channel<S1, Channel<S2, T>>) -> Channel<(S1, [S2]), T> {
    // note that the Channel will always be an empty array of S2s; making the source type a closure returning the array would work, but it crashes the compiler
    var s2s: [S2] = []
    return Channel<(S1, [S2]), T>(source: (channel.source, s2s), reception: { (rcv: T -> Void) -> Receipt in
        var rcpts: [Receipt] = []
        let rcpt = channel.receive { (rcvrobv: Channel<S2, T>) in
            s2s += [rcvrobv.source]
            rcpts += [rcvrobv.receive { (item: T) in rcv(item) }]
        }
        rcpts += [rcpt]

        return ReceiptOf(receipts: rcpts)
    })
}

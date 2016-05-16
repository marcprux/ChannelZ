//
//  Channel.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

// MARK: Channel Basics

/// A ChannelType is a StreamType with the addition of a Source
public protocol ChannelType : StreamType {
    associatedtype Source

    /// The underlying unconstrained source of this `Channel`
    var source: Source { get }

    /// Derives a new channel with the given source
    @warn_unused_result func resource<X>(newsource: Source -> X) -> Channel<X, Pulse>
}

/// A Channel is a passive multi-phase receiver of items of a given type: `pulses`. It is a push-based version
/// of Swift's pull-based `Generator` type. Channels can add phases that transform, filter, merge
/// and aggregate pulses that are passed through the channel. They are well-suited to handling
/// asynchronous stream of events such as networking and UI interactions.
///
/// To listen for pulses, call the `receive` function with a closure that accepts the Channel's pulse type.
/// This will return a `Receipt`, which can later be used to cancel reception.  A `Channel` can have multiple
/// receivers active, and receivers can be added to different phases of the Channel without interfering with each other.
///
/// A `Channel` is roughly analogous to the `Observable` in the ReactiveX pattern, as described at:
/// http://reactivex.io/documentation/observable.html
/// The primary differences are that a `Channel` keeps a reference to its source which allows `conduit`s
/// to be created, and that a `Channel` doesn't have any `onError` or `onCompletion`
/// signal handlers, which means that a `Channel` is effectively infinite.
/// Error and completion handling should be implemented at a higher level, where, for example, they
/// might be supported by having the Channel's Pulse type be a Swift enum with cases for
/// `.Value(T)`, `.Error(X)`, and `.Completion`, and by adding a `terminate` phase to the `Channel`
public struct Channel<S, T> : ChannelType {
    public typealias Source = S
    public typealias Pulse = T

    public let source: S

    /// The closure that will be performed whenever a pulse is emitted; analogous to ReactiveX's `onNext`
    public typealias Receiver = T -> Void

    /// The closure to be executed whenever a receiver is added, where all the receiver logic is performed
    private let reception: Receiver -> Receipt

    public init(source: S, reception: Receiver -> Receipt) {
        self.source = source
        self.reception = reception
    }

    @warn_unused_result public func phase(reception: (Pulse -> Void) -> Receipt) -> Channel {
        return Channel(source: self.source, reception: reception)
    }

    /// Adds a receiver item that will accept the output pulses of the channel
    public func receive<R: ReceiverType where R.Pulse == Pulse>(receiver: R) -> Receipt {
        return reception(receiver.receive)
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

public extension ChannelType {

    /// Lifts a function to the current Channel and returns a new channel phase that when received to will pass
    /// the values of the current Channel through the Operator function.
    ///
    /// - Parameter receptor: The functon that transforms one receiver to another
    ///
    /// - Returns: The new Channel
    @warn_unused_result public func lift<Pulse2>(receptor: (Pulse2 -> Void) -> (Pulse -> Void)) -> Channel<Source, Pulse2> {
        return Channel<Source, Pulse2>(source: source) { receiver in self.receive(receptor(receiver)) }
    }

    /// Adds a channel phase that applies the given function to each item emitted by a Channel and emits the result.
    ///
    /// - Parameter transform: a function to apply to each item emitted by the Channel
    ///
    /// - Returns: A stateless Channel that emits the pulses from the source Channel, transformed by the given function
    @warn_unused_result public func map<U>(transform: Pulse -> U) -> Channel<Source, U> {
        return lift { receive in { item in receive(transform(item)) } }
    }
}


/// MARK: Muti-Channel combination operations

public extension ChannelType {

    /// Adds a channel phase that flattens two Channels with heterogeneous `Source` and homogeneous `Pulse`s
    /// into one Channel, without any transformation, so they act like a single Channel. 
    /// 
    /// Note: The resulting Channel's receivers will not be able to distinguish which channel emitted an event;
    /// to access that information, use `either` instead.
    ///
    /// - Parameter with: a Channel to be merged
    ///
    /// - Returns: An stateless Channel that emits pulses from `self` and `with`
    @warn_unused_result public func merge<C2: ChannelType where C2.Pulse == Pulse>(with: C2) -> Channel<(Source, C2.Source), Pulse> {
        return Channel<(Source, C2.Source), Pulse>(source: (self.source, with.source)) { f in
            return ReceiptOf(receipts: [self.receive(f), with.receive(f)])
        }
    }

    /// Adds a channel phase that is a combination around `source1` and `source2` that merges pulses
    /// into a tuple of optionals that will be emitted when either of the pulses change.
    /// Unlike `combine`, this phase will begin emitting events immediately upon either of the combined
    /// channels emitting events; previous values are not retained, so this Channel is stateless.
    ///
    /// - Parameter other: the Channel to either with
    ///
    /// - Returns: A stateless Channel that emits the item of either `self` or `other`.
    @warn_unused_result public func either<C2: ChannelType>(other: C2) -> Channel<(Source, C2.Source), Choose2<Pulse, C2.Pulse>> {
        return Channel<(Source, C2.Source), Choose2<Pulse, C2.Pulse>>(source: (self.source, other.source)) { (rcvr: (Choose2<Pulse, C2.Pulse> -> Void)) in
            let rcpt1 = self.receive { rcvr(.V1($0)) }
            let rcpt2 = other.receive { rcvr(.V2($0)) }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }


    /// Adds a channel phase that is a combination around `source1` and `source2` that merges pulses
    /// into a tuple of the latest vaues that have been received on either channel; note that that
    /// latest version of each of the channels will be retained, and that no tuples will be emitted
    /// until both the channels have had at least one event. If `source1` emits 2 events followed by
    /// `source` emitting 1 event, only a tuple with `source1`'s second item will be emitted; the first
    /// item will be lost.
    ///
    /// Unlike `zip`, `combine` does not index the values with each other, but instead emits an event
    /// whenever either channel emits an event once it has been primed.
    /// Analogous to ReactiveX's `CombineLatest`
    ///
    /// - Parameter other: the Channel to combine with
    ///
    /// - Returns: A stateful Channel that emits the item of both `self` or `other`.
    @warn_unused_result public func combine<C2: ChannelType>(other: C2) -> Channel<(Self.Source, C2.Source), (Pulse, C2.Pulse)> {
        typealias Buffer = (v1: Optional<Pulse>, v2: Optional<C2.Pulse>)

        return either(other)
            .affect(Buffer(nil, nil)) { (prev, pulse) in
                switch pulse {
                case .V1(let v1): return Buffer(v1: v1, v2: prev.1)
                case .V2(let v2): return Buffer(v1: prev.0, v2: v2)
                }
            }
            .map { (prev, _) in prev } // drop the current pulse; it is stored in the state
            .filter { prev in prev.v1 != nil && prev.v2 != nil }
            .map { prev in (prev.v1!, prev.v2!) } // force unwrap: the filter prevents nils
    }

    /// Adds a channel phase formed from this Channel and another Channel by combining
    /// corresponding pulses in pairs.
    /// The number of receiver invocations of the resulting `Channel<(T, U)>`
    /// is the minumum of the number of invocations of `self` and `with`.
    ///
    /// - Parameter with: the Channel to zip with
    /// - Parameter capacity: (optional) the maximum buffer size for the channels; if either buffer
    ///     exceeds capacity, earlier pulses will be dropped silently
    ///
    /// - Returns: A stateful Channel that pairs up values from `self` and `with` Channels.
    @warn_unused_result public func zip<C2: ChannelType>(with: C2, capacity: (Int, Int) = (Int.max, Int.max)) -> Channel<(Self.Source, C2.Source), (Pulse, C2.Pulse)> {
        typealias ZipBuffer = (store: ([Pulse], [C2.Pulse]), flush: (Pulse, C2.Pulse)?)

        return self.either(with)
            .affect(ZipBuffer(([], []), nil)) { (buffer, item) in
                var buf = buffer
                switch item {
                case .V1(let v1): buf.store.0.append(v1)
                case .V2(let v2): buf.store.1.append(v2)
                }

                // if we have a tuple on either side, pop the end
                if buf.store.0.isEmpty || buf.store.1.isEmpty {
                    buf.flush = nil // clear any previous flush
                } else {
                    let f1 = buf.store.0.removeFirst()
                    let f2 = buf.store.1.removeFirst()
                    buf.flush = (f1, f2)
                }

                if capacity.0 != Int.max && capacity.1 != Int.max {
                    let counts = (buf.store.0.count, buf.store.1.count)
                    if counts.0 > capacity.0 { buf.store.0.removeFirst(counts.0 - capacity.0) }
                    if counts.0 > capacity.1 { buf.store.1.removeFirst(counts.1 - capacity.1) }
                }

                return buf
            }
            .map { (buffer, pulse) in
                return buffer.flush
            }
            .some()
    }
}

public extension ChannelType {

    /// Creates a new channel phase by applying a function that you supply to each item emitted by
    /// the source Channel, where that function returns a Channel, and then merging those
    /// resulting Channels and emitting the results of this merger.
    ///
    /// - Parameter transform: a function that, when applied to an item emitted by the source Channel, returns a Channel
    ///
    /// - Returns: An effected Channel that emits the result of applying the transformation function to each
    ///         item emitted by the source Channel and merging the results of the Channels
    ///         obtained from this transformation.
    @warn_unused_result public func flatMap<S2, U>(transform: Pulse -> Channel<S2, U>) -> Channel<Source, U> {
        return flattenZ(map(transform))
    }
}

public extension Channel {

    @warn_unused_result public func concat(with: Channel<Source, Pulse>) -> Channel<[Source], (Source, Pulse)> {
        return concatZ([self, with])
    }

}

/// Concatinates multiple channels with the same source and pulse types into a single channel;
/// note that the source is incuded in a tuple with the pulse in order to identify which source emitted the pulse
@warn_unused_result public func concatZ<S, T>(channels: [Channel<S, T>]) -> Channel<[S], (S, T)> {
    return Channel<[S], (S, T)>(source: channels.map({ c in c.source })) { f in
        return ReceiptOf(receipts: channels.map({ c in c.map({ e in (c.source, e) }).receive(f) }))
    }
}

/// Flattens a Channel that emits Channels into a single Channel that emits the pulses emitted by
/// those Channels, without any transformation.
/// Note: this operation does not retain the sub-sources, since it can merge a heterogeneously-sourced series of channels
@warn_unused_result public func flattenZ<S1, S2, T>(channel: Channel<S1, Channel<S2, T>>) -> Channel<S1, T> {
    return Channel<S1, T>(source: channel.source, reception: { (rcv: T -> Void) -> Receipt in
        var rcpts: [Receipt] = []
        let rcpt = channel.receive { (rcvrobv: Channel<S2, T>) in
            let rcpt = rcvrobv.receive { (item: T) in rcv(item) }
            rcpts.append(rcpt)
        }
        rcpts.append(rcpt)
        return ReceiptOf(receipts: rcpts)
    })
}


// MARK - Effect utilities for channels that need to maintain state

public extension ChannelType {
    /// Performs a side-effect when the channel receives a pulse. 
    /// This can be used to manage some arbitrary and hidden state regardless 
    /// of the number of receivers that are on the channel.
    @warn_unused_result public func affect<T>(seed: T, affector: (T, Pulse) -> T) -> Channel<Source, (store: T, pulse: Pulse)> {

        var state: [Int64: T] = [:] // the captured state, one pulse per receiver
        var stateIndex: Int64 = 0

        return Channel(source: self.source) { receiver in
            stateIndex += 1
            let index = stateIndex
            state[index] = seed

            let rcpt = self.receive { pulse in
                if var stateValue = state[index] {
                    stateValue = affector(stateValue, pulse)
                    state[index] = stateValue
                    receiver(store: stateValue, pulse: pulse)
                }
            }

            return ReceiptOf {
                state[index] = nil // drop the stored state
                rcpt.cancel()
            }
        }
    }

    /// Adds a channel phase with the result of repeatedly calling `combine` with an accumulated value
    /// initialized to `initial` and each pulse of `self`, in turn.
    /// Analogous to `SequenceType.reduce`.
    ///
    /// - Parameter initial: the initial accumulated value
    /// - Parameter combine: the accumulator function that will return the accumulation
    @warn_unused_result public func reduce<T>(initial: T, combine: (T, Pulse) -> T) -> Channel<Source, T> {
        return affect(initial, affector: combine).map { (reduction, _) in reduction }
    }

    /// Adds a channel phase that emits a tuples of pairs (*n*, *x*),
    /// where *n*\ s are consecutive `Int`\ s starting at zero,
    /// and *x*\ s are the pulses.
    ///
    /// Analogous to `SequenceType.enumerate` and `EnumerateGenerator`
    ///
    /// - Returns: A stateful Channel that emits a tuple with the pulse's index
    @warn_unused_result public func enumerate() -> Channel<Source, (index: Int, pulse: Pulse)> {
        return affect(-1) { (index, pulse) in index + 1 }.map { (index: $0, pulse: $1) }
    }

    /// Adds a channel phase that aggregates pulses with the given combine function and then
    /// emits the pulses when the partition predicate is satisified.
    ///
    /// - Parameter initial: the initial accumulated value
    /// - Parameter includePartitions: whether partition pulses should be included in the accumulation (default: true)
    /// - Parameter combine: the combinator function to call with the accumulated value
    /// - Parameter isPartition: the predicate that signifies whether an item should cause the
    ///   accumulated value to be emitted and cleared
    ///
    /// - Returns: A stateful Channel that buffers its accumulated pulses until the terminator predicate passes
    @warn_unused_result public func partition<U>(initial: U, includePartitions: Bool = true, isPartition: (U, Pulse) -> Bool, combine: (U, Pulse) -> U) -> Channel<Source, U> {
        typealias Buffer = (store: U, flush: U?)

        func bufferer(buffer: Buffer, item: Pulse) -> Buffer {
            let store = buffer.store
            if isPartition(store, item) {
                return Buffer(store: initial, flush: includePartitions ? combine(store, item) : store)
            } else {
                return Buffer(store: combine(store, item), flush: nil)
            }
        }

        return reduce(Buffer(store: initial, flush: nil), combine: { buffer, pulse in bufferer(buffer, item: pulse) }).map({ $0.flush }).some()
    }

    /// Accumulate the given pulses into an array until the given predicate is satisifed, and
    /// then flush all the pulses of the array.
    ///
    /// - Parameter predicate: that will cause the accumulated pulses to be pulsed
    ///
    /// - Returns: A stateful Channel that maintains an accumulation of pulses
    @warn_unused_result public func accumulate(includePartitions includePartitions: Bool = true, predicate: ([Pulse], Pulse) -> Bool) -> Channel<Source, [Pulse]> {
        return partition([], includePartitions: includePartitions, isPartition: predicate) { (accumulation, pulse) in accumulation + [pulse] }
    }

    /// Accumulate the given pulses into an array until the given predicate is satisifed, and
    /// then flush all the pulses of the array.
    ///
    /// - Parameter predicate: that will cause the accumulated pulses to be pulsed
    ///
    /// - Returns: A stateful Channel that maintains an accumulation of pulses
    @warn_unused_result public func split(maxSplit: Int = Int.max, allowEmptySlices: Bool = false, isSeparator: Pulse -> Bool) -> Channel<Source, [Pulse]> {
        let channel = accumulate(includePartitions: allowEmptySlices) { (buffer, pulse) in isSeparator(pulse) }
            .filter({ allowEmptySlices || !$0.isEmpty })
            .map({ allowEmptySlices ? $0.filter { !isSeparator($0) } : $0 })

        if maxSplit == Int.max {
            return channel
        } else {
            return channel.prefix(maxSplit)
        }
    }

    /// Adds a channel phase that buffers emitted pulses such that the receiver will
    /// receive a array of the buffered pulses
    ///
    /// - Parameter count: the size of the buffer
    ///
    /// - Returns: A stateful Channel that buffers its pulses until it the buffer reaches `count`
    @warn_unused_result public func buffer(limit: Int) -> Channel<Source, [Pulse]> {
        return accumulate { a, x in a.count >= limit-1 }
    }

    /// Adds a channel phase that drops the first `count` pulses.
    ///
    /// - Parameter count: the number of pulses to skip before emitting pulses
    ///
    /// - Returns: A stateful Channel that drops the first `count` pulses.
    @warn_unused_result public func dropFirst(n: Int = 1) -> Channel<Source, Pulse> {
        return enumerate().filter { $0.index >= n }.map { $0.pulse }
    }

    /// Adds a channel phase that will terminate receipt after the given number of pulses have been received.
    ///
    /// - Parameter count: the number of pulses to skip before emitting pulses
    ///
    /// - Returns: A stateful Channel that drops the first `count` pulses.
    @warn_unused_result public func prefix(maxLength: Int) -> Channel<Source, Pulse> {
        return enumerate().filter { $0.index < maxLength }.map { $0.pulse }
    }
}


/// Utility function for marking code that is yet to be written
@available(*, deprecated, message="Crashes, always")
@noreturn func crash<T>() -> T { fatalError("implementme") }


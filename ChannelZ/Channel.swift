//
//  Channel.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// A Channel is a passive handler of items of a given type. It is a push-based version 
/// of Swift's pull-based `Generator` type. 
///
/// To listen for items, call the `receive` function with the block that accepts the typed item. This will
/// return a `Receptor`, which can later be used to cancel the receipt. A `Channel` can have multiple
/// `Receptors` activate at any time.
///
/// A `Channel` is roughly analogous to an `Observable` in the ReactiveX pattern,
/// as described at: http://reactivex.io/documentation/observable.html
/// The primary differences are that a `Channel` doesn't have any `onError` or `onCompletion`
/// signale handlers, which means that a `Channel` is effectively infinite. Error and completion
/// handling are pushed up into the application domain, where, for example, they could be supported 
/// by having the Channel type be a Swift enum with cases for `.Value(T)`, `.Error(X)`, and `.Completion`.
public struct Channel<S, T> {
    /// The underlying unconstrained source of this `Channel`
    public let source: S

    /// The closure that will be performed whenever an item is emitted; analogous to ReactiveX's `onNext`
    public typealias Receptor = T->Void

    /// The closure to be executed whenever a receptor is added, where all the receiver logic is performed
    private let recipio: Receptor->Receipt

    public init(source: S, recipio: Receptor->Receipt) {
        self.source = source
        self.recipio = recipio
    }

    /// Adds the given receptor block to this Channel's list to receive all items it emits
    ///
    /// :param: `receptor` the block to be executed whenever this Channel emits an item
    ///
    /// :returns: a `Receipt`, which can be used to later `cancel` from receiving items
    public func receive(receptor: T->Void)->Receipt {
        return recipio(receptor)
    }

    /// Adds a receptor that will forward all values to the target `SinkType`
    ///
    /// :param: `sink` the sink that will accept all the items from the Channel
    ///
    /// :returns: a `Receipt` for the pipe
    public func pipe<S2: SinkType where S2.Element == T>(var sink: S2)->Receipt {
        return receive({ sink.put($0) })
    }

    /// Lifts a function to the current Channel and returns a new Channel that when received to will pass
    /// the values of the current Channel through the Operator function.
    public func lift<U>(f: (U->Void)->(T->Void))->Channel<S, U> {
        return Channel<S, U>(source: source) { g in self.receive(f(g)) }
    }

    /// Returns a Channel which only emits those items for which a given predicate holds.
    ///
    /// :param: `predicate` a function that evaluates the items emitted by the source Channel, returning `true` if they pass the filter
    ///
    /// :returns: a stateless Channel that emits only those items in the original Channel that the filter evaluates as `true`
    public func filter(predicate: T->Bool)->Channel<S, T> {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
    }

    /// Returns a Channel that applies the given function to each item emitted by a Channel and emits the result.
    ///
    /// :param: `transform` a function to apply to each item emitted by the Channel
    ///
    /// :returns: a stateless Channel that emits the items from the source Channel, transformed by the given function
    public func map<U>(transform: T->U)->Channel<S, U> {
        return lift { receive in { item in receive(transform(item)) } }
    }

    /// Creates a new Channel by applying a function that you supply to each item emitted by
    /// the source Channel, where that function returns a Channel, and then merging those
    /// resulting Channels and emitting the results of this merger.
    ///
    /// :param: `transform` a function that, when applied to an item emitted by the source Channel, returns a Channel
    ///
    /// :returns: a stateless Channel that emits the result of applying the transformation function to each
    ///         item emitted by the source Channel and merging the results of the Channels
    ///         obtained from this transformation.
    public func flatMap<S2, U>(transform: T->Channel<S2, U>)->Channel<(S, [S2]), U> {
        return flatten(map(transform))
    }

    /// Creates a new Channel that will cease sending items once the terminator predicate is satisfied.
    ///
    /// :param: `terminator` a predicate function that will result in cancellation of all receipts when it evaluates to `true`
    /// :param: `terminus` an optional final sentinal closure that will be sent once after the `terminator` evaluates to `true`
    ///
    /// :returns: a stateful Channel that emits items until the `terminator` evaluates to true
    public func terminate(terminator: T->Bool, terminus: (()->T)? = nil)->Channel<S, T> {
        var receipts: [Receipt] = []
        var terminated = false

        return Channel<S, T>(source: self.source) { f in
            var receipt = self.receive { x in
                if terminated { return }
                if terminator(x) {
                    terminated = true
                    if let terminus = terminus {
                        f(terminus())
                    }
                    receipts.map { $0.cancel() }
                } else {
                    f(x)
                }
            }
            receipts += [receipt]
            return receipt
        }
    }

    /// Creates a Channel that emits items only when the items pass the filter predicate against the most
    /// recent emitted or passed item. 
    ///
    /// For example, to create a filter for distinct equatable items, you would do: `sieve(!=)`
    ///
    /// :param: `predicate` a function that evaluates the current item against the previous item
    /// :param: `lastPassed`    when `false` (the default), the `previous` will always be the most recent item in the sequence
    ///                         when `true`, the `previous` wil be the last item that passed the predicate
    ///
    /// :returns: a stateful Channel that emits the the items that pass the predicate
    ///
    /// **Note:** the most recent value will be retained by the Channel for as long as there are receivers
    public func sieve(predicate: (current: T, previous: T)->Bool, lastPassed: Bool = false)->Channel<S, T> {
        var previous: T?
        return lift { receive in { item in
            if let prev = previous {
                if predicate(current: item, previous: prev) {
                    receive(item)
                    previous = item
                }
            } else {
                receive(item)
                previous = item
            }

            if !lastPassed {
                previous = item
            }
            }
        }
    }

    /// Flattens two Channels with heterogeneous `Source` and homogeneous `Element`s
    /// into one Channel, without any transformation, so they act like a single Channel.
    ///
    /// :param: `with` a Channel to be merged
    ///
    /// :returns: an stateless Channel that emits items from `self` and `with`
    public func merge<S2>(with: Channel<S2, T>)->Channel<(S, S2), T> {
        return Channel<(S, S2), T>(source: (self.source, with.source)) { f in
            return ReceiptOf(receipts: [self.receive(f), with.receive(f)])
        }
    }

    /// Returns a Channel that buffers emitted items such that the receiver will
    /// receive a array of the buffered items
    ///
    /// :param: `count` the size of the buffer
    ///
    /// :returns: a stateful Channel that buffers its items until it the buffer reaches `count`
    public func buffer(count: Int)->Channel<S, [T]> {
        var buffer: [T] = []
        buffer.reserveCapacity(count)

        return lift { receive in { item in
            buffer += [item]
            if buffer.count >= count {
                receive(buffer)
                buffer.removeAll(keepCapacity: true)
            }
        }
        }
    }

    /// Returns a Channel that drops the first `count` elements.
    ///
    /// :param: `count` the number of elements to skip before emitting items
    ///
    /// :returns: a stateful Channel that drops the first `count` elements.
    public func drop(count: Int)->Channel<S, T> {
        var seen = -count
        return filter { _ in seen++ >= 0 }
    }

    /// Returns a Channel that aggregates items with the given combine function and then
    /// emits the items when the terminator predicate is satisified.
    ///
    /// :param: `initial` the initial accumulated value
    /// :param: `combine` the combinator function to call with the accumulated value
    /// :param: `isTerminator` the predicate that signifies whether an item should cause the accumulated value to be emitted and cleared
    /// :param: `includeTerminators` if true (the default), then terminator items will be included in the accumulation
    /// :param: `clearAfterEmission` if true (the default), the accumulated value will be cleared after each emission
    ///
    /// :returns: a stateful Channel that buffers its accumulated items until the terminator predicate passes
    public func reduce<U>(initial: U, combine: (U, T)->U, isTerminator: T->Bool, includeTerminators: Bool = true, clearAfterEmission: Bool = true)->Channel<S, U> {
        var accumulation = initial
        return lift { receive in { item in
            if isTerminator(item) {
                if includeTerminators { accumulation = combine(accumulation, item) }
                receive(accumulation)
                if clearAfterEmission { accumulation = initial }
            } else {
                accumulation = combine(accumulation, item)
            }
        }
        }
    }

    /// Returns a Channel formed from this Channel and another Channel by combining
    /// corresponding elements in pairs.
    /// The number of receiver invocations of the resulting `Channel<(T, U)>`
    /// is the minumum of the number of invocations of `self` and `with`.
    ///
    /// :param: `with` the Channel to zip with
    /// :param: `capacity` (optional) the maximum buffer size for the receivers; if either buffer
    ///     exceeds capacity, earlier elements will be dropped silently
    ///
    /// :returns: a stateful Channel that pairs up values from `self` and `with` Channels.
    public func zip<S2, T2>(with: Channel<S2, T2>, capacity: Int? = nil)->Channel<(S, S2), (T, T2)> {
        return Channel<(S, S2), (T, T2)>(source: (self.source, with.source)) { (sub: (T, T2)->Void) in

            var v1s: [T] = []
            var v2s: [T2] = []

            let zipper: ()->() = {
                // only send the tuple to the subscription when we have at least one
                while v1s.count > 0 && v2s.count > 0 {
                    sub(v1s.removeAtIndex(0), v2s.removeAtIndex(0))
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

    /// Creates a combination around the receivers `source1` and `source2` that merges elements into a tuple of
    /// optionals that will be emitted when either of the elements change
    ///
    /// :param: `other` the Channel to zip with
    ///
    /// :returns: a stateless Channel that emits the item of either `self` or `other`.
    public func either<S2, T2>(other: Channel<S2, T2>)->Channel<(S, S2), (T?, T2?)> {
        typealias Either = (T?, T2?)
        return Channel<(S, S2), (T?, T2?)>(source: (self.source, other.source)) { (sub: (Either->Void)) in
            let rcpt1 = self.receive { v1 in sub(Either(v1, nil)) }
            let rcpt2 = other.receive { v2 in sub(Either(nil, v2)) }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Erases the source type from this `Channel` to `Void`, which can be useful for simplyfying the signature
    /// for functions that don't care about the source or for releasing the source when it isn't needed
    public func void()->Channel<Void, T> {
        return Channel<Void, T>(source: Void(), self.recipio)
    }
}


/// A `Receivable` is a type that is able to generate a `Channel`. It is a push-based version
/// of Swift's pull-based `Sequence` type.
protocol Receivable {
    typealias Source
    typealias Element

    /// Creates a Channel from this Receivable
    func receiver()->Channel<Source, Element>
}

/// A Channel's Receivable implementation merely returns itself
extension Channel : Receivable {
    public typealias Source = S
    public typealias Element = T
    public func receiver()->Channel<S, T> { return self }
}

/// Channel merge operation for two receivers of the same type (operator form of `merge`)
public func +<S1, S2, T>(lhs: Channel<S1, T>, rhs: Channel<S2, T>)->Channel<(S1, S2), T> {
    return lhs.merge(rhs)
}

/// Filters the given `Channel` for distinct items that conform to `Equatable`
public func sieveDistinct<S, T where T: Equatable>(receiver: Channel<S, T>)->Channel<S, T> {
    return receiver.sieve(!=)
}

/// Creates a Channel sourced by a `SinkOf` that will be used to send elements to the receivers
public func receiveSink<T>(type: T.Type)->Channel<SinkOf<T>, T> {
    var subs = ReceptorList<T>()
    let sink = SinkOf { subs.receive($0) }
    return Channel<SinkOf<T>, T>(source: sink) { subs.addReceipt($0, { nil }) }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receptors
public func receiveSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S)->Channel<S, T> {
    var receptors = ReceptorList<T>()
    return Channel(source: from) { sub in
        for item in from { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// Creates a Channel sourced by a `GeneratorType` that will emit all its elements to new receptors
public func receiveGenerator<S, T where S: GeneratorType, S.Element == T>(from: S)->Channel<S, T> {
    var receptors = ReceptorList<T>()
    return Channel(source: from) { sub in
        for item in GeneratorOf(from) { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// Creates a Channel sourced by an optional Closure that will be send all execution results to new receptors until it returns `.None`
public func receiveClosure<T>(from: ()->T?)->Channel<()->T?, T> {
    var receptors = ReceptorList<T>()
    return Channel(source: from) { sub in
        while let item = from() { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// A PropertyChannel can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
public final class PropertyChannel<T>: Receivable, SinkType {
    public typealias Element = T
    public var value: T { didSet { receptors.receive(value) } }
    private let receptors = ReceptorList<T>()
    public init(_ value: T) { self.value = value }
    public func put(x: T) { value = x }

    public func receiver()->Channel<PropertyChannel<Element>, Element> {
        return Channel(source: self) { sub in
            sub(self.value) // immediately issue the original value
            return self.receptors.addReceipt(sub, { self.value })
        }
    }
}


/// Creates a one-way pipe betweek a `Channel` and a `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞-><S1, T, S2: SinkType where T == S2.Element>(r: Channel<S1, T>, s: S2)->Receipt { return r.pipe(s) }
infix operator ∞-> { }


/// Creates a two-way pipe betweek two `Channel`s whose source is a `SinkType`, such that when either side is
/// set, the other side is updated; each source must be a reference type for the `sink` to not be mutative
func conduit<R1, R2 where R1: Receivable, R2: Receivable, R1.Source: SinkType, R2.Source: SinkType, R1.Source.Element == R2.Element, R2.Source.Element == R1.Element>(r1: R1, r2: R2)->Receipt {
    let (rcv1, rcv2) = (r1.receiver(), r2.receiver())
    return ReceiptOf(receipts: [rcv1∞->rcv2.source, rcv2∞->rcv1.source])
}


/// Creates a two-way pipe betweek two `Channel`s whose source is a `SinkType`, such that when either side is
/// set, the other side is updated; each source must be a reference type for the `sink` to not be mutative
/// This is the operator form of `conduit`
public func <-∞-><S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return conduit(r1, r2) }
infix operator <-∞-> { }


/// Creates a one-way pipe betweek a `Channel` and an `Equatable` `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞=><S1, T, S2: SinkType where T == S2.Element, T: Equatable>(r: Channel<S1, T>, s: S2)->Receipt { return r.sieve(!=).pipe(s) }
infix operator ∞=> { }


/// Creates a two-way channel pipe betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func channel<S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt {
    let (rcv1, rcv2) = (r1.receiver(), r2.receiver())
    return ReceiptOf(receipts: [rcv1∞=>rcv2.source, rcv2∞=>rcv1.source])
}

/// Creates a two-way channel pipe betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
/// This is the operator form of `channel`
public func <=∞=><S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return channel(r1, r2) }
infix operator <=∞=> { }


/// Flattens a Channel that emits Channels into a single Channel that emits the items emitted by
/// those Channels, without any transformation.
/// Note: this operation does not retain the sub-sources, since it can merge a heterogeneously-sourced series of receivers
public func flatten<S1, S2, T>(receiver: Channel<S1, Channel<S2, T>>)->Channel<(S1, [S2]), T> {
    // note that the Channel will always be an empty array of S2s; making the source type a closure returning the array would work, but it crashes the compiler
    var s2s: [S2] = []
    return Channel<(S1, [S2]), T>(source: (receiver.source, s2s), recipio: { (rcv: T->Void)->Receipt in
        var rcpts: [Receipt] = []
        let rcpt = receiver.receive { (subobv: Channel<S2, T>) in
            s2s += [subobv.source]
            rcpts += [subobv.receive { (item: T) in rcv(item) }]
        }
        rcpts += [rcpt]

        return ReceiptOf(receipts: rcpts)
    })
}


/// Takes an `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3>(ob: Channel<S, ((T1?, T2?)?, T3?)>)->Channel<S, (T1?, T2?, T3?)> {
    return ob.map { ($0.0?.0, $0.0?.1, $0.1) }
}

/// Takes an `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3, T4>(ob: Channel<S, (((T1?, T2?)?, T3?)?, T4?)>)->Channel<S, (T1?, T2?, T3?, T4?)> {
    return ob.map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1) }
}

/// Channel combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1?, T2?)> {
    return lhs.either(rhs)
}

/// Channel zipping & flattening operation
public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}

/// Channel combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1?, T2?)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1?, T2?, T3?)> {
    return flatOptionalSink(flattenSources(lhs.either(rhs)))
}


// MARK: Tuple-flattening boilerplate follows

public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineElements(lhs.zip(rhs))) }

private func flattenSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, T>(rcvr: Channel<(((S1, S2), S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { return Channel(source: (rcvr.source.0.0.0, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return Channel(source: (rcvr.source.0.0.0.0, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<(((((S1, S2), S3), S4), S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { return Channel(source: (rcvr.source.0.0.0.0.0, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((((((S1, S2), S3), S4), S5), S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<(((((((S1, S2), S3), S4), S5), S6), S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<(((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<(((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(rcvr: Channel<((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(rcvr: Channel<(((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(rcvr: Channel<((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(rcvr: Channel<(((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(rcvr: Channel<((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(rcvr: Channel<(((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(rcvr: Channel<((((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(rcvr: Channel<(((((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { return Channel(source: (rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.0.1, rcvr.source.0.0.0.0.0.1, rcvr.source.0.0.0.0.1, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }

private func combineSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, T>(rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.0.14, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.0.14, rcvr.source.0.15, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.0.14, rcvr.source.0.15, rcvr.source.0.16, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.0.14, rcvr.source.0.15, rcvr.source.0.16, rcvr.source.0.17, rcvr.source.1), rcvr.recipio) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.0.4, rcvr.source.0.5, rcvr.source.0.6, rcvr.source.0.7, rcvr.source.0.8, rcvr.source.0.9, rcvr.source.0.10, rcvr.source.0.11, rcvr.source.0.12, rcvr.source.0.13, rcvr.source.0.14, rcvr.source.0.15, rcvr.source.0.16, rcvr.source.0.17, rcvr.source.0.18, rcvr.source.1), rcvr.recipio) }

private func flattenElements<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4>(rcvr: Channel<S, (((T1, T2), T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((((T1, T2), T3), T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, (((((T1, T2), T3), T4), T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((((((T1, T2), T3), T4), T5), T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0.0.0.0.0, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, (((((((T1, T2), T3), T4), T5), T6), T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, (((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, (((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, (((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, (((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, (((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, (((((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18), T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }

private func combineElements<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func combineElements<S, T1, T2, T3, T4>(rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.0.18, $0.1) } }


//
//  Channel.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// A Channel is a passive multi-phase receiver of items of a given type. It is a push-based version
/// of Swift's pull-based `Generator` type. Channels can add phases that transform, filter, merge
/// and aggregate items that are passed through the channel. They are well-suited to handling
/// an asynchronous stream of events such as networking and UI interactions.
///
/// To listen for items, call the `receive` function with a closure that accepts the Channel's element.
/// This will return a `Receipt`, which can later be used to cancel reception.  A `Channel` can have multiple 
/// receivers active, and receivers can be added to different phases of the Channel without interfering with each other.
///
/// A `Channel` is roughly analogous to the `Observable` in the ReactiveX pattern,
/// as described at: http://reactivex.io/documentation/observable.html
/// The primary differences are that a `Channel` keeps a reference to its source which allows `conduit`s
/// to be created, and that a `Channel` doesn't have any `onError` or `onCompletion`
/// signale handlers, which means that a `Channel` is effectively infinite.
/// Error and completion handling should be implemented at a higher level, where, for example, they 
/// might be supported by having the Channel's Element type be a Swift enum with cases for 
/// `.Value(T)`, `.Error(X)`, and `.Completion`, and by adding a `terminate` phase to the `Channel`
public struct Channel<S, T> {
    /// The underlying unconstrained source of this `Channel`
    public let source: S

    /// The closure that will be performed whenever an item is emitted; analogous to ReactiveX's `onNext`
    public typealias Receiver = T->Void

    /// The closure to be executed whenever a receiver is added, where all the receiver logic is performed
    internal let reception: Receiver->Receipt

    public init(source: S, reception: Receiver->Receipt) {
        self.source = source
        self.reception = reception
    }

    /// Adds the given receiver block to this Channel's list to receive all items it emits
    ///
    /// :param: receiver the block to be executed whenever this Channel emits an item
    ///
    /// :returns: a `Receipt`, which can be used to later `cancel` from receiving items
    public func receive(receiver: T->Void)->Receipt {
        return reception(receiver)
    }

    /// Adds a receiver that will forward all values to the target `SinkType`
    ///
    /// :param: sink the sink that will accept all the items from the Channel
    ///
    /// :returns: a `Receipt` for the pipe
    public func pipe<S2: SinkType where S2.Element == T>(var sink: S2)->Receipt {
        return receive({ sink.put($0) })
    }

    /// Lifts a function to the current Channel and returns a new channel phase that when received to will pass
    /// the values of the current Channel through the Operator function.
    public func lift<U>(f: (U->Void)->(T->Void))->Channel<S, U> {
        return Channel<S, U>(source: source) { g in self.receive(f(g)) }
    }

    /// Adds a channel phase which only emits those items for which a given predicate holds.
    ///
    /// :param: predicate a function that evaluates the items emitted by the source Channel, returning `true` if they pass the filter
    ///
    /// :returns: a stateless Channel that emits only those items in the original Channel that the filter evaluates as `true`
    public func filter(predicate: T->Bool)->Channel<S, T> {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
    }

    /// Adds a channel phase that applies the given function to each item emitted by a Channel and emits the result.
    ///
    /// :param: transform a function to apply to each item emitted by the Channel
    ///
    /// :returns: a stateless Channel that emits the items from the source Channel, transformed by the given function
    public func map<U>(transform: T->U)->Channel<S, U> {
        return lift { receive in { item in receive(transform(item)) } }
    }

    /// Adds a channel phase that spits the channel in two, where the first channel accepts elements that
    /// fail the given predicate filter, and the second channel emits the elements that pass the predicate
    /// (mnemonic: "right" also means "correct").
    ///
    /// Note that the predicate will be evaluated exactly twice for each emitted item
    ///
    /// :param: predicate a function that evaluates the items emitted by the source Channel, returning `true` if they pass the filter
    ///
    /// :returns: a stateless Channel pair that passes elements depending on whether they pass or fail the predicate, respectively
    public func split(predicate: T->Bool)->(Channel<S, T>, Channel<S, T>) {
        return (filter({ !predicate($0) }), filter({ predicate($0) }))
    }

    /// Creates a new channel phase by applying a function that you supply to each item emitted by
    /// the source Channel, where that function returns a Channel, and then merging those
    /// resulting Channels and emitting the results of this merger.
    ///
    /// :param: transform a function that, when applied to an item emitted by the source Channel, returns a Channel
    ///
    /// :returns: a stateless Channel that emits the result of applying the transformation function to each
    ///         item emitted by the source Channel and merging the results of the Channels
    ///         obtained from this transformation.
    public func flatMap<S2, U>(transform: T->Channel<S2, U>)->Channel<(S, [S2]), U> {
        return flatten(map(transform))
    }

    /// Adds a channel phase that will cease sending items once the terminator predicate is satisfied.
    ///
    /// :param: terminator a predicate function that will result in cancellation of all receipts when it evaluates to `true`
    /// :param: terminus an optional final sentinal closure that will be sent once after the `terminator` evaluates to `true`
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

    /// Adds a channel phase that emits items only when the items pass the filter predicate against the most
    /// recent emitted or passed item. 
    ///
    /// For example, to create a filter for distinct equatable items, you would do: `sieve(!=)`
    ///
    /// **Note:** the most recent value will be retained by the Channel for as long as there are receivers
    ///
    /// :param: predicate a function that evaluates the current item against the previous item
    /// :param: lastPassed  when `false` (the default), the `previous` will always be the most recent item in the sequence
    ///                     when `true`, the `previous` wil be the last item that passed the predicate
    ///
    /// :returns: a stateful Channel that emits the the items that pass the predicate
    public func sieve(predicate: (current: T, previous: T)->Bool, lastPassed: Bool = false)->Channel<S, T> {
        var previous: T?
        return lift { receive in { item in
            if let prev = previous {
                if predicate(current: item, previous: prev) {
                    receive(item)
                    previous = item
                }
            } else { // the initial item is always passed
                receive(item)
                previous = item
            }

            if !lastPassed {
                previous = item
            }
            }
        }
    }

    /// Adds a channel phase that flattens two Channels with heterogeneous `Source` and homogeneous `Element`s
    /// into one Channel, without any transformation, so they act like a single Channel.
    ///
    /// :param: with a Channel to be merged
    ///
    /// :returns: an stateless Channel that emits items from `self` and `with`
    public func merge<S2>(with: Channel<S2, T>)->Channel<(S, S2), T> {
        return Channel<(S, S2), T>(source: (self.source, with.source)) { f in
            return ReceiptOf(receipts: [self.receive(f), with.receive(f)])
        }
    }

    /// Adds a channel phase that buffers emitted items such that the receiver will
    /// receive a array of the buffered items
    ///
    /// :param: count the size of the buffer
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

    /// Adds a channel phase that drops the first `count` elements.
    ///
    /// :param: count the number of elements to skip before emitting items
    ///
    /// :returns: a stateful Channel that drops the first `count` elements.
    public func drop(count: Int)->Channel<S, T> {
        return enumerate().filter({ $0.0 >= count }).map({ $0.1 })
    }

    /// Adds a channel phase that emits a tuples of pairs (*n*, *x*), 
    /// where *n*\ s are consecutive `Int`\ s starting at zero, 
    /// and *x*\ s are the elements
    ///
    /// :returns: a stateful Channel that emits a tuple with the element's index
    public func enumerate()->Channel<S, (Int, T)> {
        var index = 0
        return map({ (index++, $0) })
    }

    /// Adds a channel phase that aggregates items with the given combine function and then
    /// emits the items when the terminator predicate is satisified.
    ///
    /// :param: initial the initial accumulated value
    /// :param: combine the combinator function to call with the accumulated value
    /// :param: isTerminator the predicate that signifies whether an item should cause the accumulated value to be emitted and cleared
    /// :param: includeTerminators if true (the default), then terminator items will be included in the accumulation
    /// :param: clearAfterEmission if true (the default), the accumulated value will be cleared after each emission
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

    /// Adds a channel phase formed from this Channel and another Channel by combining
    /// corresponding elements in pairs.
    /// The number of receiver invocations of the resulting `Channel<(T, U)>`
    /// is the minumum of the number of invocations of `self` and `with`.
    ///
    /// :param: with the Channel to zip with
    /// :param: capacity (optional) the maximum buffer size for the channels; if either buffer
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
    /// :param: other the Channel to combine with
    ///
    /// :returns: a stateful Channel that emits the item of both `self` or `other`.
    public func combine<S2, T2>(other: Channel<S2, T2>)->Channel<(S, S2), (T, T2)> {
        typealias Both = (T, T2)
        var lasta: T?
        var lastb: T2?

        return Channel<(S, S2), Both>(source: (self.source, other.source)) { (sub: (Both->Void)) in
            let rcpt1 = self.receive { a in
                lasta = a
                if let lastb = lastb { sub(Both(a, lastb)) }

            }
            let rcpt2 = other.receive { b in
                lastb = b
                if let lasta = lasta { sub(Both(lasta, b)) }
            }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Adds a channel phase that is a combination around `source1` and `source2` that merges elements
    /// into a tuple of optionals that will be emitted when either of the elements change.
    /// Unlike `combine`, this phase will begin emitting events immediately upon either of the combined
    /// channels emitting events; previous values are not retained, so this Channel is stateless.
    ///
    /// :param: other the Channel to either with
    ///
    /// :returns: a stateless Channel that emits the item of either `self` or `other`.
    public func either<S2, T2>(other: Channel<S2, T2>)->Channel<(S, S2), (T?, T2?)> {
        typealias Either = (T?, T2?)
        return Channel<(S, S2), Either>(source: (self.source, other.source)) { (sub: (Either->Void)) in
            let rcpt1 = self.receive { v1 in sub(Either(v1, nil)) }
            let rcpt2 = other.receive { v2 in sub(Either(nil, v2)) }
            return ReceiptOf(receipts: [rcpt1, rcpt2])
        }
    }

    /// Erases the source type from this `Channel` to `Void`, which can be useful for simplyfying the signature
    /// for functions that don't care about the source's type or for channel phases that want to ensure the source
    /// cannot be accessed
    public func void()->Channel<Void, T> {
        return Channel<Void, T>(source: Void(), self.reception)
    }
}


/// A `Receivable` is a type that is able to generate a `Channel`. It is a push-based version
/// of Swift's pull-based `Sequence` type.
protocol Receivable {
    typealias Source
    typealias Element

    /// Creates a Channel from this Receivable
    func channel()->Channel<Source, Element>
}

/// A Channel's Receivable implementation merely returns itself
extension Channel : Receivable {
    public typealias Source = S
    public typealias Element = T
    public func channel()->Channel<S, T> { return self }
}

/// Channel merge operation for two receivers of the same type (operator form of `merge`)
public func +<S1, S2, T>(lhs: Channel<S1, T>, rhs: Channel<S2, T>)->Channel<(S1, S2), T> {
    return lhs.merge(rhs)
}

/// Filters the given `Channel` for distinct items that conform to `Equatable`
public func sieveDistinct<S, T where T: Equatable>(channel: Channel<S, T>)->Channel<S, T> {
    return channel.sieve(!=)
}

/// Creates a Channel sourced by a `SinkOf` that will be used to send elements to the receivers
public func receiveSink<T>(type: T.Type)->Channel<SinkOf<T>, T> {
    var subs = ReceiverList<T>()
    let sink = SinkOf { subs.receive($0) }
    return Channel<SinkOf<T>, T>(source: sink) { subs.addReceipt($0, { nil }) }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
public func channelSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S)->Channel<S, T> {
    var receivers = ReceiverList<T>()
    return Channel(source: from) { sub in
        for item in from { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// Creates a Channel sourced by a `GeneratorType` that will emit all its elements to new receivers
public func receiveGenerator<S, T where S: GeneratorType, S.Element == T>(from: S)->Channel<S, T> {
    var receivers = ReceiverList<T>()
    return Channel(source: from) { sub in
        for item in GeneratorOf(from) { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// Creates a Channel sourced by an optional Closure that will be send all execution results to new receivers until it returns `.None`
public func receiveClosure<T>(from: ()->T?)->Channel<()->T?, T> {
    var receivers = ReceiverList<T>()
    return Channel(source: from) { sub in
        while let item = from() { sub(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more items
    }
}

/// A PropertyChannel can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
public final class PropertyChannel<T>: Receivable, SinkType {
    public typealias Element = T
    public var value: T { didSet { receivers.receive(value) } }
    private let receivers = ReceiverList<T>()
    public init(_ value: T) { self.value = value }
    public func put(x: T) { value = x }

    public func channel()->Channel<PropertyChannel<Element>, Element> {
        return Channel(source: self) { sub in
            sub(self.value) // immediately issue the original value
            return self.receivers.addReceipt(sub, { self.value })
        }
    }
}


/// Creates a one-way pipe betweek a `Channel` and a `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞-><S1, T, S2: SinkType where T == S2.Element>(r: Channel<S1, T>, s: S2)->Receipt { return r.pipe(s) }
infix operator ∞-> { }


/// Creates a one-way pipe betweek a `Channel` and an `Equatable` `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞=><S1, T, S2: SinkType where T == S2.Element, T: Equatable>(r: Channel<S1, T>, s: S2)->Receipt { return r.sieve(!=).pipe(s) }
infix operator ∞=> { }


/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func conduit<S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt {
    let (rcv1, rcv2) = (r1.channel(), r2.channel())
    return ReceiptOf(receipts: [rcv1∞=>rcv2.source, rcv2∞=>rcv1.source])
}

/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
/// This is the operator form of `channel`
public func <=∞=><S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return conduit(r1, r2) }
infix operator <=∞=> { }


/// Flattens a Channel that emits Channels into a single Channel that emits the items emitted by
/// those Channels, without any transformation.
/// Note: this operation does not retain the sub-sources, since it can merge a heterogeneously-sourced series of receivers
public func flatten<S1, S2, T>(channel: Channel<S1, Channel<S2, T>>)->Channel<(S1, [S2]), T> {
    // note that the Channel will always be an empty array of S2s; making the source type a closure returning the array would work, but it crashes the compiler
    var s2s: [S2] = []
    return Channel<(S1, [S2]), T>(source: (channel.source, s2s), reception: { (rcv: T->Void)->Receipt in
        var rcpts: [Receipt] = []
        let rcpt = channel.receive { (subobv: Channel<S2, T>) in
            s2s += [subobv.source]
            rcpts += [subobv.receive { (item: T) in rcv(item) }]
        }
        rcpts += [rcpt]

        return ReceiptOf(receipts: rcpts)
    })
}


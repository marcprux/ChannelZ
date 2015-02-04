//
//  Receiver.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

public protocol Receivable {
    typealias Source
    typealias Element
    var receiver: Receiver<Source, Element> { get }
}

/// A Receiver is a passive handler of items of a given type. It is a push-based version 
/// of Swift's pull-based `Generator` type. 
///
/// To listen for items, call the `receive` function with the block that accepts the typed item. This will
/// return a `Receptor`, which can later be used to cancel the receipt. A `Receiver` can have multiple
/// `Receptors` activate at any time.
///
/// A `Receiver` is roughly analogous to an `Observable` in the ReactiveX pattern,
/// as described at: http://reactivex.io/documentation/observable.html
/// The primary differences are that a `Receiver` doesn't have any `onError` or `onCompletion`
/// signale handlers, which means that a `Receiver` is effectively infinite. Error and completion
/// handling are pushed up into the application domain, where, for example, they could be supported 
/// by having the Receiver type be a Swift enum with cases for `.Value(T)`, `.Error(X)`, and `.Completion`.
public struct Receiver<S, T> {
    public var source: S
    public typealias Receptor = T->Void
    private let addReceptor: Receptor->Receipt

    internal init(source: S, addReceptor: Receptor->Receipt) {
        self.source = source
        self.addReceptor = addReceptor
    }

    /// Adds the given block to this Receivers list of receivers for items
    ///
    /// :param: `subscription` the block to be executed whenever this Receiver emits an item
    ///
    /// :returns: a `Receipt`, which can be used to later `cancel` from receiving items
    public func receive(receiver: T->Void)->Receipt {
        return addReceptor(receiver)
    }

    /// Lifts a function to the current Receiver and returns a new Receiver that when received to will pass
    /// the values of the current Receiver through the Operator function.
    public func lift<U>(f: (U->Void)->(T->Void)) -> Receiver<S, U> {
        return Receiver<S, U>(source: source) { g in self.receive(f(g)) }
    }

    /// Returns a Receiver which only emits those items for which a given predicate holds.
    ///
    /// :param: `predicate` a function that evaluates the items emitted by the source Receiver, returning `true` if they pass the filter
    ///
    /// :returns: a stateless Receiver that emits only those items in the original Receiver that the filter evaluates as `true`
    public func filter(predicate: T->Bool)->Receiver<S, T> {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
    }

    /// Returns a Receiver that applies the given function to each item emitted by a Receiver and emits the result.
    ///
    /// :param: `transform` a function to apply to each item emitted by the Receiver
    ///
    /// :returns: a stateless Receiver that emits the items from the source Receiver, transformed by the given function
    public func map<U>(transform: T->U)->Receiver<S, U> {
        return lift { receive in { item in receive(transform(item)) } }
    }

    /// Creates a new Receiver by applying a function that you supply to each item emitted by
    /// the source Receiver, where that function returns a Receiver, and then merging those
    /// resulting Receivers and emitting the results of this merger.
    ///
    /// :param: `transform` a function that, when applied to an item emitted by the source Receiver, returns a Receiver
    ///
    /// :returns: a stateless Receiver that emits the result of applying the transformation function to each
    ///         item emitted by the source Receiver and merging the results of the Receivers
    ///         obtained from this transformation.
    public func flatMap<V, U>(transform: T->Receiver<V, U>)->Receiver<S, U> {
        return flatten(map(transform))
    }

    /// Creates a new Receiver that will cease sending items once the terminator predicate is satisfied.
    ///
    /// :param: `terminator` a predicate function that will result in cancellation of all receipts when it evaluates to `true`
    /// :param: `terminus` an optional final sentinal closure that will be sent once after the `terminator` evaluates to `true`
    ///
    /// :returns: a stateless Receiver that emits items until the `terminator` evaluates to true
    public func terminate(terminator: T->Bool, terminus: (()->T)? = nil)->Receiver<S, T> {
        var receipts: [Receipt] = []
        var terminated = false

        return Receiver<S, T>(source: self.source) { f in
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

    /// Creates a Receiver that emits items only when the items pass the filter predicate against the most
    /// recent emitted or passed item. 
    ///
    /// For example, to create a filter for distinct equatable items, you would do: `sieve(!=)`
    ///
    /// :param: `predicate` a function that evaluates the current item against the previous item
    /// :param: `lastPassed`    when `false` (the default), the `previous` will always be the most recent item in the sequence
    ///                         when `true`, the `previous` wil be the last item that passed the predicate
    ///
    /// :returns: a stateful Receiver that emits the the items that pass the predicate
    ///
    /// **Note:** the most recent value will be retained by the Receiver for as long as there are receivers
    public func sieve(predicate: (current: T, previous: T)->Bool, lastPassed: Bool = false)->Receiver<S, T> {
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

    /// Flattens two Receivers into one Receiver, without any transformation,
    /// so they act like a single Receiver.
    ///
    /// :param: `with` a Receiver to be merged
    ///
    /// :returns: an stateless Receiver that emits items from `self` and `with`
    public func merge<V>(with: Receiver<V, T>)->Receiver<(S, V), T> {
        return Receiver<(S, V), T>(source: (self.source, with.source)) { f in
            return ReceiptOf(receipts: [self.receive(f), with.receive(f)])
        }
    }

    /// Returns a Receiver that buffers emitted items such that the receiver will
    /// receive a array of the buffered items
    ///
    /// :param: `count` the size of the buffer
    ///
    /// :returns: a stateful Receiver that buffers its items until it the buffer reaches `count`
    public func buffer(count: Int)->Receiver<S, [T]> {
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

    /// Returns a Receiver that drops the first `count` elements.
    ///
    /// :param: `count` the number of elements to skip before emitting items
    ///
    /// :returns: a stateful Receiver that drops the first `count` elements.
    public func drop(count: Int)->Receiver<S, T> {
        var seen = -count
        return filter { _ in seen++ >= 0 }
    }

    /// Returns a Receiver that aggregates items with the given combine function and then
    /// emits the items when the terminator predicate is satisified.
    ///
    /// :param: `initial` the initial accumulated value
    /// :param: `combine` the combinator function to call with the accumulated value
    /// :param: `isTerminator` the predicate that signifies whether an item should cause the accumulated value to be emitted and cleared
    /// :param: `includeTerminators` if true (the default), then terminator items will be included in the accumulation
    /// :param: `clearAfterEmission` if true (the default), the accumulated value will be cleared after each emission
    ///
    /// :returns: a stateful Receiver that buffers its accumulated items until the terminator predicate passes
    public func reduce<U>(initial: U, combine: (U, T) -> U, isTerminator: T->Bool, includeTerminators: Bool = true, clearAfterEmission: Bool = true)->Receiver<S, U> {
        var accumulation = initial
        return lift { receive in { item in
            if isTerminator(item) {
                if includeTerminators {
                    accumulation = combine(accumulation, item)
                }
                receive(accumulation)
                if clearAfterEmission {
                    accumulation = initial
                }
            } else {
                accumulation = combine(accumulation, item)
            }
        }
        }
    }

    /// Returns a Receiver formed from this Receiver and another Receiver by combining
    /// corresponding elements in pairs.
    /// The number of receiver invocations of the resulting `Receiver<(T, U)>`
    /// is the minumum of the number of invocations of `self` and `with`.
    ///
    /// :param: `with` the Receiver to zip with
    /// :param: `capacity` (optional) the maximum buffer size for the receivers; if either buffer
    ///     exceeds capacity, earlier elements will be dropped silently
    ///
    /// :returns: a stateful Receiver that pairs up values from `self` and `with` Receivers.
    public func zip<S2, T2>(with: Receiver<S2, T2>, capacity: Int? = nil)->Receiver<(S, S2), (T, T2)> {
        return Receiver<(S, S2), (T, T2)>(source: (self.source, with.source)) { (sub: (T, T2) -> Void) in

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

            let sk1 = self.receive({ v1 in
                v1s += [v1]
                zipper()
            })

            let sk2 = with.receive({ v2 in
                v2s += [v2]
                zipper()
            })
            
            return ReceiptOf(receipts: [sk1, sk2])
        }
    }

    /// Creates a combination around the receivers `source1` and `source2` that merges elements into a tuple of
    /// optionals that will be emitted when either of the elements change
    ///
    /// :param: `other` the Receiver to zip with
    ///
    /// :returns: a stateless Receiver that emits the item of either `self` or `other`.
    public func either<V, U>(other: Receiver<V, U>)->Receiver<(S, V), (T?, U?)> {
        return Receiver<(S, V), (T?, U?)>(source: (self.source, other.source)) { (sub: ((T?, U?) -> Void)) in
            let sk1 = self.receive({ v1 in sub((v1 as T?, nil as U?)) })
            let sk2 = other.receive({ v2 in sub((nil as T?, v2 as U?)) })
            return ReceiptOf(receipts: [sk1, sk2])
        }
    }

    /// Erases the source type from this `Receiver` to `Void`, which can be useful for simplyfying the signature
    /// for functions that don't care about the source or for releasing the source when it isn't needed
    public func desource()->Receiver<Void, T> {
        return Receiver<Void, T>(source: Void(), self.addReceptor)
    }
}

/// A Receiver's Receivable implementation merely returns itself
extension Receiver : Receivable {
    public typealias Source = S
    public typealias Element = T
    public var receiver: Receiver<S, T> { return self }
}

/// Receiver merge operation for two receivers of the same type (operator form of `merge`)
public func +<S1, S2, T>(lhs: Receiver<S1, T>, rhs: Receiver<S2, T>)->Receiver<(S1, S2), T> {
    return lhs.merge(rhs)
}

/// Filters the given `Receiver` for distinct items that conform to `Equatable`
public func sieveDistinct<S, T where T: Equatable>(receiver: Receiver<S, T>)->Receiver<S, T> {
    return receiver.sieve(!=)
}

public func receiveSink<T>(type: T.Type) -> Receiver<SinkOf<T>, T> {
    var subs = ReceptorList<T>()
    let sink = SinkOf { subs.receive($0) }
    return Receiver<SinkOf<T>, T>(source: sink) { sub in
        let token = subs.addReceptor(sub)
        return ReceiptOf(requester: { }, canceller: { subs.removeReceptor(token) })
    }
}

public func receiveSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S) -> Receiver<S, T> {
    var receptors = ReceptorList<T>()
    return Receiver(source: from) { sub in
        for item in from { sub(item) }
        return ReceiptOf(requester: { }, canceller: { })
    }
}

public func receiveGenerator<S, T where S: GeneratorType, S.Element == T>(from: S) -> Receiver<S, T> {
    var receptors = ReceptorList<T>()
    return Receiver(source: from) { sub in
        for item in GeneratorOf(from) { sub(item) }
        return ReceiptOf(requester: { }, canceller: { })
    }
}

public func receiveClosure<T>(from: ()->T?) -> Receiver<()->T?, T> {
    var receptors = ReceptorList<T>()
    return Receiver(source: from) { sub in
        while let item = from() { sub(item) }
        return ReceiptOf(requester: { }, canceller: { })
    }
}

/// A PropertyReceiver can be used to wrap any Swift or Objective-C type to make it act as a `Receiver`
public final class PropertyReceiver<T>: Receivable, SinkType {
    public typealias Element = T
    public var value: T { didSet { receptors.receive(value) } }
    private let receptors = ReceptorList<T>()
    public init(_ value: T) { self.value = value }
    public func put(x: T) { value = x }

    public var receiver: Receiver<PropertyReceiver<Element>, Element> {
        return Receiver(source: self) { sub in
            sub(self.value) // immediately issue a single value
            let token = self.receptors.addReceptor(sub)
            return ReceiptOf(requester: { self.receptors.receive(self.value) }, canceller: { self.receptors.removeReceptor(token) })
        }
    }
}

infix operator ∞ { }

/// Creates a two-way link betweek two `Receiver`s whose source is a `SinkType`, such that when either side is
/// set, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func channel<R1, R2 where R1: Receivable, R2: Receivable, R1.Source: SinkType, R2.Source: SinkType, R1.Source.Element == R2.Element, R2.Source.Element == R1.Element>(r1: R1, r2: R2)->Receipt {
    let v1 = r1.receiver
    let v2 = r2.receiver
    var s1 = v1.source
    var s2 = v2.source
    let rcv1 = v1.receive { s2.put($0) }
    let rcv2 = v2.receive { s1.put($0) }
    return ReceiptOf(receipts: [rcv1, rcv2])
}

/// Creates a two-way link betweek two `Receiver`s whose source is a `SinkType`, such that when either side is
/// set, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func ∞<S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1: AnyObject, S2: AnyObject, S1.Element == T2, S2.Element == T1>(r1: Receiver<S1, T1>, r2: Receiver<S2, T2>)->Receipt { return channel(r1, r2) }

/// Creates a two-way link betweek two `Receiver`s whose source is a `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func channel<S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1: AnyObject, S2: AnyObject, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Receiver<S1, T1>, r2: Receiver<S2, T2>)->Receipt {
    var s1 = r1.source
    var s2 = r2.source
    let rcv1 = r1.sieve(!=).receive { s2.put($0) }
    let rcv2 = r2.sieve(!=).receive { s1.put($0) }
    return ReceiptOf(receipts: [rcv1, rcv2])
}

public func ∞<S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1: AnyObject, S2: AnyObject, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Receiver<S1, T1>, r2: Receiver<S2, T2>)->Receipt { return channel(r1, r2) }

/// Flattens a Receiver that emits Receivers into a single Receiver that emits the items emitted by
/// those Receivers, without any transformation.
/// Note: this operation does not retain the sub-sources, since it can merge a heterogeneously-sourced series of receivers
public func flatten<S, V, T>(receiver: Receiver<S, Receiver<V, T>>)->Receiver<S, T> {
    return Receiver<S, T>(source: receiver.source, addReceptor: { (rcv: T->Void) -> Receipt in
        var subs: [Receipt] = []
        let sub = receiver.receive { (subobv: Receiver<V, T>) in
            subs += [subobv.receive { (item: T) in rcv(item) }]
        }
        subs += [sub]

        return ReceiptOf(receipts: subs)
    })
}

/// Takes an `Receiver` with a nested tuple of sources and flattens the sources into a single tuple
private func flatSource<S1, S2, S3, T>(ob: Receiver<((S1, S2), S3), T>)->Receiver<(S1, S2, S3), T> {
    return Receiver(source: (ob.source.0.0, ob.source.0.1, ob.source.1), ob.addReceptor)
}

/// Takes an `Receiver` with a nested tuple of sources and flattens the sources into a single tuple
private func flatSource<S1, S2, S3, S4, T>(ob: Receiver<(((S1, S2), S3), S4), T>)->Receiver<(S1, S2, S3, S4), T> {
    return Receiver(source: (ob.source.0.0.0, ob.source.0.0.1, ob.source.0.1, ob.source.1), ob.addReceptor)
}

/// Takes an `Receiver` with a nested tuple of sources and flattens the sources into a single tuple
private func flatSource<S1, S2, S3, S4, S5, T>(ob: Receiver<((((S1, S2), S3), S4), S5), T>)->Receiver<(S1, S2, S3, S4, S5), T> {
    return Receiver(source: (ob.source.0.0.0.0, ob.source.0.0.0.1, ob.source.0.0.1, ob.source.0.1, ob.source.1), ob.addReceptor)
}

/// Takes an `Receiver` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatSink<S, T1, T2, T3>(ob: Receiver<S, ((T1, T2), T3)>)->Receiver<S, (T1, T2, T3)> {
    return ob.map { ($0.0.0, $0.0.1, $0.1) }
}

/// Takes an `Receiver` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatSink<S, T1, T2, T3, T4>(ob: Receiver<S, (((T1, T2), T3), T4)>)->Receiver<S, (T1, T2, T3, T4)> {
    return ob.map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) }
}

/// Takes an `Receiver` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3>(ob: Receiver<S, ((T1?, T2?)?, T3?)>)->Receiver<S, (T1?, T2?, T3?)> {
    return ob.map { ($0.0?.0, $0.0?.1, $0.1) }
}

/// Takes an `Receiver` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3, T4>(ob: Receiver<S, (((T1?, T2?)?, T3?)?, T4?)>)->Receiver<S, (T1?, T2?, T3?, T4?)> {
    return ob.map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1) }
}


/// Receiver zipping & flattening operation
public func &<S1, S2, T1, T2>(lhs: Receiver<S1, T1>, rhs: Receiver<S2, T2>)->Receiver<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}

/// Receiver zipping & flattening operation (operator form of `flatZip`)
public func &<S1, S2, S3, T1, T2, T3>(lhs: Receiver<(S1, S2), (T1, T2)>, rhs: Receiver<S3, T3>)->Receiver<(S1, S2, S3), (T1, T2, T3)> {
    return flatSource(flatSink(lhs.zip(rhs)))
}


/// Receiver combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, T1, T2>(lhs: Receiver<S1, T1>, rhs: Receiver<S2, T2>)->Receiver<(S1, S2), (T1?, T2?)> {
    return lhs.either(rhs)
}

/// Receiver combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, S3, T1, T2, T3>(lhs: Receiver<(S1, S2), (T1?, T2?)>, rhs: Receiver<S3, T3>)->Receiver<(S1, S2, S3), (T1?, T2?, T3?)> {
    return flatOptionalSink(flatSource(lhs.either(rhs)))
}


//infix operator ∞> { }
//infix operator ∞-> { }
//
///// subscription operation
//public func ∞> <T>(lhs: Receiver<T>, rhs: T->Void)->Receptor { return lhs.receive(rhs) }
//
///// subscription operation with priming
//public func ∞-> <T>(lhs: Receiver<T>, rhs: T->Void)->Receptor { return request(lhs.receive(rhs)) }



//internal func filterReceiver<T>(source: Receiver<T>)(predicate: (T)->Bool)->Receiver<T> {
//    return source.receiver().lift({ receive in { item in if predicate(item) { receive(item) } } })
//}
//
///// Creates a filter around the receiver `source` that only passes elements that satisfy the `predicate` function
//public func filter<T>(source: Receiver<T>, predicate: (T)->Bool)->Receiver<T> {
//    return filterReceiver(source)(predicate)
//}
//
///// Filter that skips the first `skipCount` number of elements
//public func skip<T>(source: Receiver<T>, var skipCount: Int = 1)->Receiver<T> {
//    return filterReceiver(source)({ _ in skipCount-- > 0 })
//}
//
///// Internal MappedReceiver curried creation
//internal func mapReceiver<T, U>(source: Receiver<T>)(transform: T->U)->Receiver<U> {
//    return source.receiver().lift({ receive in { item in receive(transform(item)) } })
//}
//
///// Creates a map around the receiver `source` that passes through elements after applying the `transform` function
//public func map<T, U>(source: Receiver<T>, transform: T->U)->Receiver<U> {
//    return mapReceiver(source)(transform)
//}
//
//

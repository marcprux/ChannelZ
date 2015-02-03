//
//  Observable.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// An Observable wraps a type (either a value or a reference) and sends all state operations down to each subscribed subscription
public protocol ObservableType {
    typealias Element

    /// Returns a type-erasing observable wrapper around the current observable, making the source read-only to subsequent pipeline stages
    func observable() -> Observable<Element>

    /// subscribes a subscription to receive change notifications from the state pipeline
    ///
    /// :param: subscription the subscription closure to which items will be sent
    func subscribe(subscription: Element->Void)->Subscription
}

/// The Observable interface that implements the Reactive Pattern.
public struct Observable<T> : ObservableType {
    private let subscriptionHandler: (subscription: T->Void)->Subscription

    public init(subscriptionHandler: (subscription: T->Void) -> Subscription) {
        self.subscriptionHandler = subscriptionHandler
    }

    /// Adds the given block to this Observables list of receivers for items
    ///
    /// :param: `subscription` the block to be executed whenever this Observable emits an item
    ///
    /// :returns: a `Subscription`, which can be used to later `unsubscribe` from receiving items
    public func subscribe(subscription: T->Void)->Subscription {
        return subscriptionHandler(subscription)
    }

    /// Returns a type-erasing observable wrapper around the current observable, making the source read-only to subsequent pipeline stages
    public func observable() -> Observable<T> {
        return self
    }

}

public extension Observable {
    /// Construct this Observable by wrapping another Observable
    public init<G : ObservableType where T == G.Element>(_ base: G) {
        self.init(subscriptionHandler: { base.subscribe($0) })
    }

    public init<G: GeneratorType where T == G.Element>(generator: G) {
        subscriptionHandler = { sub in
            for item in GeneratorOf<T>(generator) { sub(item) }
            return SubscriptionOf(requester: { }, unsubscriber: { })
        }
    }

    public init<S: SequenceType where T == S.Generator.Element>(from: S) {
        subscriptionHandler = { sub in
            for item in GeneratorOf<T>(from.generate()) { sub(item) }
            return SubscriptionOf(requester: { }, unsubscriber: { })
        }
    }

    public init(just: T) {
        self.init(from: [just])
    }

    /// Lifts a function to the current Observable and returns a new Observable that when subscribed to will pass
    /// the values of the current Observable through the Operator function.
    public func lift<U>(f: (U->Void)->(T->Void)) -> Observable<U> {
        return Observable<U> { g in self.subscribe(f(g)) }
    }

    /// Returns an Observable which only emits those items for which a given predicate holds.
    ///
    /// :param: `predicate` a function that evaluates the items emitted by the source Observable, returning `true` if they pass the filter
    ///
    /// :returns: an Observable that emits only those items in the original Observable that the filter evaluates as `true`
    public func filter(predicate: T->Bool)->Observable<T> {
        return lift { receive in { item in if predicate(item) { receive(item) } } }
    }

    /// Returns an Observable that applies the given function to each item emitted by an Observable and emits the result.
    ///
    /// :param: `transform` a function to apply to each item emitted by the Observable
    ///
    /// :returns: an Observable that emits the items from the source Observable, transformed by the given function
    public func map<U>(transform: T->U)->Observable<U> {
        return lift { receive in { item in receive(transform(item)) } }
    }

    /// Creates a new Observable by applying a function that you supply to each item emitted by
    /// the source Observable, where that function returns an Observable, and then merging those
    /// resulting Observables and emitting the results of this merger.
    ///
    /// :param: `transform` a function that, when applied to an item emitted by the source Observable, returns an Observable
    ///
    /// :returns: an Observable that emits the result of applying the transformation function to each
    ///         item emitted by the source Observable and merging the results of the Observables
    ///         obtained from this transformation.
    public func flatMap<U>(transform: T->Observable<U>)->Observable<U> {
        return flatten(map(transform))
    }

    /// Creates an Observable that emits items only when the items pass the filter predicate against the most
    /// recent emitted item. For example, to create a filter for distinct equatable items, you would do:
    /// `filterLast(!=)`
    ///
    /// :param: `predicate` a function that evaluates the current item against the previous item
    ///
    /// :returns: an Observable that emits the the items that pass the predicate
    ///
    /// **Note:** the most recent value will be retained by the Observable for as long as there are subscribers
    public func filterLast(predicate: (T, T)->Bool)->Observable<T> {
        var previous: T?
        return lift { receive in { item in
            if let previous = previous {
                if predicate(previous, item) {
                    receive(item)
                }
            } else {
                receive(item)
            }

            previous = item
            }
        }
    }

    /// Flattens two Observables into one Observable, without any transformation, so they act like a single Observable.
    ///
    /// :param: `with` an Observable to be merged
    ///
    /// :returns: an Observable that emits items from `self` and `with`
    public func merge(with: Observable<T>)->Observable<T> {
        return Observable<T> { f in
            return SubscriptionOf(subscriptions: [self.subscribe(f), with.subscribe(f)])
        }
    }

    /// Returns an Observable formed from this Observable and another Observable by combining
    /// corresponding elements in pairs.
    /// The number of subscriber invocations of the resulting `Observable<(T, U)>`
    /// is the minumum of the number of invications invocations of `self` and `with`.
    ///
    /// :param: `with` the Observable to zip with
    /// :param: `capacity` (optional) the maximum buffer size for the observables; if either buffer 
    ///     exceeds capacity, earlier elements will be dropped silently
    ///
    /// :returns: an Observable that pairs up values from `self` and `with` Observables.
    public func zip<U>(with: Observable<U>, capacity: Int? = nil)->Observable<(T, U)> {
        return Observable<(T, U)> { (sub: (T, U) -> Void) in

            var v1s: [T] = []
            var v2s: [U] = []

            let zipped: ()->() = {
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

            let sk1 = self.subscribe({ v1 in
                v1s += [v1]
                zipped()
            })

            let sk2 = with.subscribe({ v2 in
                v2s += [v2]
                zipped()
            })
            
            return SubscriptionOf(subscriptions: [sk1, sk2])
        }
    }

    /// Creates a combination around the observables `source1` and `source2` that merges elements into a tuple of optionals that will be emitted when either of the elements change
    public func either<U>(other: Observable<U>)->Observable<(T?, U?)> {
        return Observable<(T?, U?)> { (sub: ((T?, U?) -> Void)) in
            let sk1 = self.subscribe({ v1 in sub((v1 as T?, nil as U?)) })
            let sk2 = other.subscribe({ v2 in sub((nil as T?, v2 as U?)) })
            return SubscriptionOf(subscriptions: [sk1, sk2])
        }
    }
}

/// Creates a SinkType that can accept an element as well as an observable for that element; useful for testing
public func sinkObservable<Element>(type: Element.Type) -> (SinkOf<Element>, Observable<Element>) {
    var subscriptions = SubscriptionList<Element>()
    let sink = SinkOf { subscriptions.receive($0) }
    return (sink, subscriptions.observable())
}

internal func filterObservable<T : ObservableType>(source: T)(predicate: (T.Element)->Bool)->Observable<T.Element> {
    return source.observable().lift({ receive in { item in if predicate(item) { receive(item) } } })
}

/// Flattens an Observable that emits Observables into a single Observable that emits the items emitted by
/// those Observables, without any transformation.
public func flatten<T>(observable: Observable<Observable<T>>)->Observable<T> {
    return Observable<T>(subscriptionHandler: { (subscription: T->Void) -> Subscription in
        var subs: [Subscription] = []
        let sub1 = observable.subscribe { (subobv: Observable<T>) in
            let sub2 = subobv.subscribe { (item: T) in
                subscription(item)
            }
            subs += [sub2]
        }
        subs += [sub1]

        return SubscriptionOf(subscriptions: subs)
    })
}

/// Creates a filter around the observable `source` that only passes elements that satisfy the `predicate` function
public func filter<T : ObservableType>(source: T, predicate: (T.Element)->Bool)->Observable<T.Element> {
    return filterObservable(source)(predicate)
}

/// Filter that skips the first `skipCount` number of elements
public func skip<T : ObservableType>(source: T, var skipCount: Int = 1)->Observable<T.Element> {
    return filterObservable(source)({ _ in skipCount-- > 0 })
}

/// Internal MappedObservable curried creation
internal func mapObservable<O : ObservableType, TransformedType>(source: O)(transform: (O.Element)->TransformedType)->Observable<TransformedType> {
    return source.observable().lift({ receive in { item in receive(transform(item)) } })
}

/// Creates a map around the observable `source` that passes through elements after applying the `transform` function
public func map<O : ObservableType, TransformedType>(source: O, transform: (O.Element)->TransformedType)->Observable<TransformedType> {
    return mapObservable(source)(transform)
}

/// Observable merge operation for two observables of the same type (operator form of `concat`)
public func +<T>(lhs: Observable<T>, rhs: Observable<T>)->Observable<T> {
    return lhs.merge(rhs)
}

/// Creates a combination around the observables `source1` and `source2` that merges elements into a tuple of optionals that will be emitted when any of the tuples change
public func any<F1 : ObservableType, F2 : ObservableType>(source1: F1, source2: F2)->Observable<(F1.Element?, F2.Element?)> {
    return source1.observable().either(source2.observable())
}

/// Observable combination & flattening operation
public func flatAny<L : ObservableType, R : ObservableType>(lhs: L, rhs: R)->Observable<(L.Element?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L.Element?, R.Element?) in (a?.0, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L : ObservableType, R : ObservableType>(lhs: L, rhs: R)->Observable<(L.Element?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, R : ObservableType>(lhs: Observable<(L1?, L2?)>, rhs: R)->Observable<(L1?, L2?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, R.Element?) in (a?.0, a?.1, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, R : ObservableType>(lhs: Observable<(L1?, L2?)>, rhs: R)->Observable<(L1?, L2?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?)>, rhs: R)->Observable<(L1?, L2?, L3?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, R.Element?) in (a?.0, a?.1, a?.2, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?)>, rhs: R)->Observable<(L1?, L2?, L3?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, L5, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, L5, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, L5, L6, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, L5, L6, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, L5, L6, L7, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, L5, L6, L7, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, L5, L6, L7, L8, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, L5, L6, L7, L8, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable combination & flattening operation
public func flatAny<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, a?.8, b) })
}

/// Observable combination & flattening operation (operator form of `flatAny`)
public func |<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : ObservableType>(lhs: Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?)>, rhs: R)->Observable<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?)> {
    return flatAny(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L : ObservableType, R : ObservableType>(lhs: L, rhs: R)->Observable<(L.Element, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L.Element, R.Element) in (a.0, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L : ObservableType, R : ObservableType>(lhs: L, rhs: R)->Observable<(L.Element, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, R : ObservableType>(lhs: Observable<(L1, L2)>, rhs: R)->Observable<(L1, L2, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, R.Element) in (a.0, a.1, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, R : ObservableType>(lhs: Observable<(L1, L2)>, rhs: R)->Observable<(L1, L2, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, R : ObservableType>(lhs: Observable<(L1, L2, L3)>, rhs: R)->Observable<(L1, L2, L3, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, R.Element) in (a.0, a.1, a.2, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, R : ObservableType>(lhs: Observable<(L1, L2, L3)>, rhs: R)->Observable<(L1, L2, L3, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4)>, rhs: R)->Observable<(L1, L2, L3, L4, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, R.Element) in (a.0, a.1, a.2, a.3, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4)>, rhs: R)->Observable<(L1, L2, L3, L4, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, L5, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, R.Element) in (a.0, a.1, a.2, a.3, a.4, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, L5, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, R.Element) in (a.0, a.1, a.2, a.3, a.4, b) })
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, L5, L6, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, L5, L6, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, L6, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, b) })
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, L5, L6, L7, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, L5, L6, L7, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, b) })
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, L5, L6, L7, L8, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7, L8)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, L8, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, L5, L6, L7, L8, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7, L8)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, L8, R.Element)> {
    return flatZip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func flatZip<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7, L8, L9)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element)> {
    return mapObservable(lhs.observable().zip(rhs.observable()))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, b) })
}

/// Observable zipping & flattening operation (operator form of `flatZip`)
public func &<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : ObservableType>(lhs: Observable<(L1, L2, L3, L4, L5, L6, L7, L8, L9)>, rhs: R)->Observable<(L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element)> {
    return flatZip(lhs, rhs)
}


infix operator ∞> { }
infix operator ∞-> { }

/// subscription operation
public func ∞> <T : ObservableType>(lhs: T, rhs: T.Element->Void)->Subscription { return lhs.subscribe(rhs) }

/// subscription operation with priming
public func ∞-> <T : ObservableType>(lhs: T, rhs: T.Element->Void)->Subscription { return request(lhs.subscribe(rhs)) }

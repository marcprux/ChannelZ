//
//  Observable.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// An Observable wraps a type (either a value or a reference) and sends all state operations down to each subscribeed outlet
public protocol BaseObservableType {
    typealias Element

    /// Returns a type-erasing observable wrapper around the current observable, making the source read-only to subsequent pipeline stages
    func observable() -> ObservableOf<Element>

    /// subscribes an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    func subscribe(outlet: (Self.Element)->Void)->SubscriptionOf<Self>
}


/// A observable with support for filtering, mapping, etc.
public protocol StreamingObservable : BaseObservableType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredObservable itself implements ObservableType, and so is regarded as a circular protocol declaration)

    /// Returns a filtered observable that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.Element)->Bool)->FilteredObservable<Self>

    /// Returns a mapped observable that transforms the elements before passing them through to the outlets
    func map<TransformedType>(transform: (Self.Element)->TransformedType)->MappedObservable<Self, TransformedType>
}

public protocol ObservableType : BaseObservableType, StreamingObservable {
}


/// A Sink that funnls all elements through to the subscribeed outlets
public struct SinkObservable<Element> : ObservableType, SinkType {

    private var outlets = SubscriptionList<Element>()

    /// Create a SinkObservable with an optional primer callback
    public init() {
    }

    public func subscribe(outlet: (Element)->())->SubscriptionOf<SelfObservable> {
        let index = outlets.addSubscription(outlet)
        return SubscriptionOf(source: self, primer: { }, detacher: {
            self.outlets.removeSubscription(index)
        })
    }

    public func put(x: Element) {
        outlets.receive(x)
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = SinkObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return FilteredObservable(source: self, predicate: predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return MappedObservable(source: self, transform: transform) }
}


/// A type-erased observable.
///
/// Forwards operations to an arbitrary underlying observable with the same
/// `Element` type, hiding the specifics of the underlying observable.
public struct ObservableOf<Element> : ObservableType {
    private let subscribeer: (outlet: (Element) -> Void) -> Subscription

    init<G : BaseObservableType where Element == G.Element>(_ base: G) {
        self.subscribeer = { base.subscribe($0) }
    }

    public func subscribe(outlet: (Element) -> Void) -> SubscriptionOf<SelfObservable> {
        let olet = self.subscribeer(outlet)
        return SubscriptionOf(source: self, primer: { olet.prime() }, detacher: { olet.detach() })
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = ObservableOf
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return FilteredObservable(source: self, predicate: predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return MappedObservable(source: self, transform: transform) }
}

/// A filtered observable that flows only those values that pass the filter predicate
public struct FilteredObservable<S : BaseObservableType> : ObservableType {
    typealias Element = S.Element
    public let source: S
    public let predicate: (S.Element)->Bool

    public init(source: S, predicate: (S.Element)->Bool) {
        self.source = source
        self.predicate = predicate
    }

    /// subscribes an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func subscribe(outlet: (Element)->Void)->SubscriptionOf<SelfObservable> {
        return SubscriptionOf(source: self, outlet: source.subscribe({ if self.predicate($0) { outlet($0) } }))
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = FilteredObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}


/// A GeneratorObservable wraps a SequenceType or GeneratorType and sends all generated elements whenever an subscribement is made
public struct GeneratorObservable<Element>: BaseObservableType {
    public let generator: ()->GeneratorOf<Element>

    public init<G: GeneratorType where Element == G.Element>(_ gen: G) {
        self.generator = { GeneratorOf(gen) }
    }

    public init<S: SequenceType where Element == S.Generator.Element>(_ seq: S) {
        self.generator = { GeneratorOf(seq.generate()) }
    }

    public func subscribe(outlet: (Element) -> Void) -> SubscriptionOf<SelfObservable> {
        for element in generator() {
            outlet(element)
        }

        return SubscriptionOf(source: self, primer: { }, detacher: { })
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = GeneratorObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}

/// A TrapSubscription is an subscribement to a observable that retains a number of values (default 1) when they are sent by the source
public class TrapSubscription<F : BaseObservableType>: SubscriptionType {
    typealias SourceType = F.Element

    public let source: F

    /// Returns the last value to be added to this trap
    public var value: F.Element? { return values.last }

    /// All the values currently held in the trap
    public var values: [F.Element]

    public let capacity: Int

    private var outlet: Subscription?

    public init(source: F, capacity: Int) {
        self.source = source
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let outlet = source.subscribe({ [weak self] (value) -> Void in
            let _ = self?.receive(value)
        })
        self.outlet = outlet
    }

    deinit { outlet?.detach() }
    public func detach() { outlet?.detach() }
    public func prime() { outlet?.prime() }

    public func receive(value: SourceType) {
        while values.count >= capacity {
            values.removeAtIndex(0)
        }

        values.append(value)
    }
}

/// Creates a trap for the last `count` events of the `source` observable
public func trap<F : BaseObservableType>(source: F, capacity: Int = 1) -> TrapSubscription<F> {
    return TrapSubscription(source: source, capacity: capacity)
}

/// Internal FilteredObservable curried creation
internal func filterObservable<T : BaseObservableType>(source: T)(predicate: (T.Element)->Bool)->FilteredObservable<T> {
    return FilteredObservable(source: source, predicate: predicate)
}

/// Creates a filter around the observable `source` that only passes elements that satisfy the `predicate` function
public func filter<T : BaseObservableType>(source: T, predicate: (T.Element)->Bool)->FilteredObservable<T> {
    return filterObservable(source)(predicate)
}

/// Filter that skips the first `skipCount` number of elements
public func skip<T : ObservableType>(source: T, var skipCount: Int = 1)->FilteredObservable<T> {
    return filterObservable(source)({ _ in skipCount-- > 0 })
}


// A mapped observable passes all values through a transformer function before sending them to their subscribeed outlets
public struct MappedObservable<Observable : BaseObservableType, TransformedType> : ObservableType {
    typealias Element = TransformedType

    public let source: Observable
    public let transform: (Observable.Element)->TransformedType

    public init(source: Observable, transform: (Observable.Element)->TransformedType) {
        self.source = source
        self.transform = transform
    }

    /// subscribes an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func subscribe(outlet: (TransformedType)->Void)->SubscriptionOf<SelfObservable> {
        return SubscriptionOf(source: self, outlet: source.subscribe({ outlet(self.transform($0)) }))
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = MappedObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}

/// Internal MappedObservable curried creation
internal func mapObservable<Observable : BaseObservableType, TransformedType>(source: Observable)(transform: (Observable.Element)->TransformedType)->MappedObservable<Observable, TransformedType> {
    return MappedObservable(source: source, transform: transform)
}

/// Creates a map around the observable `source` that passes through elements after applying the `transform` function
public func map<Observable : BaseObservableType, TransformedType>(source: Observable, transform: (Observable.Element)->TransformedType)->MappedObservable<Observable, TransformedType> {
    return mapObservable(source)(transform)
}

/// A ConcatObservable merges two homogeneous observables and delivers signals to the subscribeed outlets when either of the sources emits an event
public struct ConcatObservable<T, F1 : BaseObservableType, F2 : BaseObservableType where F1.Element == T, F2.Element == T> : ObservableType {
    public typealias Element = T
    private var source1: F1
    private var source2: F2

    public init(source1: F1, source2: F2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func subscribe(outlet: Element->Void)->SubscriptionOf<SelfObservable> {
        let sk1 = source1.subscribe({ v1 in outlet(v1) })
        let sk2 = source2.subscribe({ v2 in outlet(v2) })

        let outlet = SubscriptionOf(source: self, primer: {
            sk1.prime()
            sk2.prime()
        }, detacher: {
            sk1.detach()
            sk2.detach()
        })

        return outlet
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = ConcatObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}

/// Observable concatination operation for two observables of the same type
public func concat <T, L : BaseObservableType, R : BaseObservableType where L.Element == T, R.Element == T>(f1: L, f2: R)->ConcatObservable<T, L, R> {
    return ConcatObservable(source1: f1, source2: f2)
}

/// Observable concatination operation for two observables of the same type (operator form of `concat`)
public func + <T, L : BaseObservableType, R : BaseObservableType where L.Element == T, R.Element == T>(lhs: L, rhs: R)->ObservableOf<T> {
    return concat(lhs, rhs).observable()
}

/// A AnyObservable merges two hetergeneous observables and delivers signals as a tuple to the subscribeed outlets when any of the sources emits an event
public struct AnyObservable<F1 : BaseObservableType, F2 : BaseObservableType> : ObservableType {
    public typealias Element = (F1.Element?, F2.Element?)
    private var source1: F1
    private var source2: F2

    public init(source1: F1, source2: F2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func subscribe(outlet: Element->Void)->SubscriptionOf<SelfObservable> {
        let sk1 = source1.subscribe({ v1 in outlet((v1, nil)) })
        let sk2 = source2.subscribe({ v2 in outlet((nil, v2)) })

        let outlet = SubscriptionOf(source: self, primer: {
            sk1.prime()
            sk2.prime()
        }, detacher: {
            sk1.detach()
            sk2.detach()
        })

        return outlet
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = AnyObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}

/// Creates a combination around the observables `source1` and `source2` that merges elements into a tuple
public func any<F1 : BaseObservableType, F2 : BaseObservableType>(source1: F1, source2: F2)->AnyObservable<F1, F2> {
    return AnyObservable(source1: source1, source2: source2)
}


/// Observable combination & flattening operation
public func fany<L : BaseObservableType, R : BaseObservableType>(lhs: L, rhs: R)->ObservableOf<(L.Element?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L.Element?, R.Element?) in (a?.0, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L : BaseObservableType, R : BaseObservableType>(lhs: L, rhs: R)->ObservableOf<(L.Element?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?)>, rhs: R)->ObservableOf<(L1?, L2?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, R.Element?) in (a?.0, a?.1, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?)>, rhs: R)->ObservableOf<(L1?, L2?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, R.Element?) in (a?.0, a?.1, a?.2, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, L5, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, L5, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, L5, L6, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, L5, L6, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, L5, L6, L7, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, L5, L6, L7, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, L5, L6, L7, L8, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, L5, L6, L7, L8, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.Element?)> {
    return fany(lhs, rhs).observable()
}

/// Observable combination & flattening operation
public func fany<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?)> {
    return mapObservable(any(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, a?.8, b) }).observable()
}

/// Observable combination & flattening operation (operator form of `fany`)
public func |<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseObservableType>(lhs: ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?)>, rhs: R)->ObservableOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.Element?)> {
    return fany(lhs, rhs).observable()
}


/// A ZipObservable merges two observables and delivers signals as a tuple to the subscribeed outlets when all of the sources emits an event; note that this is a stateful observable since it needs to remember previous values that it has seen from the sources in order to pass all the non-optional values through
public struct ZipObservable<F1 : BaseObservableType, F2 : BaseObservableType> : ObservableType {
    public typealias Element = (F1.Element, F2.Element)
    private var source1: F1
    private var source2: F2

    public init(source1: F1, source2: F2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func subscribe(outlet: Element->Void)->SubscriptionOf<SelfObservable> {
        var v1s: [F1.Element] = []
        var v2s: [F2.Element] = []

        let outletZipped: ()->() = {
            // only send the tuple to the outlet when we have
            while v1s.count > 0 && v2s.count > 0 {
                outlet((v1s.removeAtIndex(0), v2s.removeAtIndex(0)))
            }
        }
        let sk1 = source1.subscribe({ v1 in
            v1s += [v1]
            outletZipped()
        })

        let sk2 = source2.subscribe({ v2 in
            v2s += [v2]
            outletZipped()
        })

        let outlet = SubscriptionOf(source: self, primer: {
            sk1.prime()
            sk2.prime()
            }, detacher: {
                sk1.detach()
                sk2.detach()
        })

        return outlet
    }

    // Boilerplate observable/filter/map
    public typealias SelfObservable = ZipObservable
    public func observable() -> ObservableOf<Element> { return ObservableOf(self) }
    public func filter(predicate: (Element)->Bool)->FilteredObservable<SelfObservable> { return filterObservable(self)(predicate) }
    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedObservable<SelfObservable, TransformedType> { return mapObservable(self)(transform) }
}

/// Creates a combination around the observables `source1` and `source2` that merges elements into a single tuple
public func zip<F1 : BaseObservableType, F2 : BaseObservableType>(source1: F1, source2: F2)->ZipObservable<F1, F2> {
    return ZipObservable(source1: source1, source2: source2)
}


/// Observable zipping & flattening operation
public func fzip<L : BaseObservableType, R : BaseObservableType>(lhs: L, rhs: R)->ObservableOf<(L.Element, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L.Element, R.Element) in (a.0, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L : BaseObservableType, R : BaseObservableType>(lhs: L, rhs: R)->ObservableOf<(L.Element, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, R : BaseObservableType>(lhs: ObservableOf<(L1, L2)>, rhs: R)->ObservableOf<(L1, L2, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, R.Element) in (a.0, a.1, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, R : BaseObservableType>(lhs: ObservableOf<(L1, L2)>, rhs: R)->ObservableOf<(L1, L2, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3)>, rhs: R)->ObservableOf<(L1, L2, L3, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, R.Element) in (a.0, a.1, a.2, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3)>, rhs: R)->ObservableOf<(L1, L2, L3, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, R.Element) in (a.0, a.1, a.2, a.3, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, L5, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, R.Element) in (a.0, a.1, a.2, a.3, a.4, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, L5, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, R.Element) in (a.0, a.1, a.2, a.3, a.4, b) }).observable()
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, L5, L6, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, L5, L6, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, b) }).observable()
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, L5, L6, L7, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, L5, L6, L7, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, b) }).observable()
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, L5, L6, L7, L8, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, L5, L6, L7, L8, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, R.Element)> {
    return fzip(lhs, rhs)
}

/// Observable zipping & flattening operation
public func fzip<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element)> {
    return mapObservable(zip(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, b) }).observable()
}

/// Observable zipping & flattening operation (operator form of `fzip`)
public func &<L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseObservableType>(lhs: ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9)>, rhs: R)->ObservableOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9, R.Element)> {
    return fzip(lhs, rhs)
}


infix operator ∞> { }
infix operator ∞-> { }

/// subscribement operation
public func ∞> <T : BaseObservableType>(lhs: T, rhs: T.Element->Void)->SubscriptionOf<T> { return lhs.subscribe(rhs) }

/// subscribement operation with priming
public func ∞-> <T : BaseObservableType>(lhs: T, rhs: T.Element->Void)->SubscriptionOf<T> { return prime(lhs.subscribe(rhs)) }



//
//  Funnels.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// An Funnel wraps a type (either a value or a reference) and sends all state operations down to each attached outlet
public protocol BaseFunnelType {
    typealias OutputType

    /// Returns a type-erasing funnel wrapper around the current funnel, making the source read-only to subsequent pipeline stages
    func funnel() -> FunnelOf<OutputType>

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    func attach(outlet: (Self.OutputType)->Void)->Outlet
}


/// A funnel with support for filtering, mapping, etc.
public protocol ExtendedFunnelType : BaseFunnelType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredFunnel itself implements FunnelType, and so is regarded as a circular protocol declaration)

    /// Returns a filtered funnel that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.OutputType)->Bool)->FilteredFunnel<Self>

    /// Returns a mapped funnel that transforms the elements before passing them through to the outlets
    func map<TransformedType>(transform: (Self.OutputType)->TransformedType)->MappedFunnel<Self, TransformedType>
}

public protocol FunnelType : BaseFunnelType, ExtendedFunnelType {
}

/// A Sink that funnls all elements through to the attached outlets
public struct SinkFunnel<Element> : FunnelType, SinkType {
    public typealias OutputType = Element

    private var outlets = OutletList<OutputType>()

    /// Create a SinkFunnel with an optional primer callback
    public init() {
    }

    public func attach(outlet: (OutputType)->())->Outlet {
        return outlets.addOutlet(primer: { }, outlet: outlet)
    }

    public func put(x: Element) {
        outlets.receive(x)
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = SinkFunnel
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return FilteredFunnel(source: self, predicate: predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return MappedFunnel(source: self, transform: transform) }
}


/// A type-erased funnel.
///
/// Forwards operations to an arbitrary underlying funnel with the same
/// `OutputType` type, hiding the specifics of the underlying funnel.
public struct FunnelOf<OutputType> : FunnelType {
    private let attacher: (outlet: (OutputType) -> Void) -> Outlet

    init<G : BaseFunnelType where OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = FunnelOf
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return FilteredFunnel(source: self, predicate: predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return MappedFunnel(source: self, transform: transform) }
}


/// A filtered funnel that flows only those values that pass the filter predicate
public struct FilteredFunnel<S : BaseFunnelType> : FunnelType {
    typealias OutputType = S.OutputType
    private var source: S
    private let predicate: (S.OutputType)->Bool

    public init(source: S, predicate: (S.OutputType)->Bool) {
        self.source = source
        self.predicate = predicate
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->Void)->Outlet {
        return source.attach({ if self.predicate($0) { outlet($0) } })
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = FilteredFunnel
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return mapFunnel(self)(transform) }
}


public class TrapOutlet<F : BaseFunnelType>: OutletType {
    typealias Element = F.OutputType

    public let source: F

    /// Returns the last value to be added to this trap
    public var value: F.OutputType? { return values.last }

    /// All the values currently held in the trap
    public var values: [F.OutputType]

    public let capacity: Int

    private var outlet: Outlet?

    public init(source: F, capacity: Int) {
        self.source = source
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let outlet = source.attach({ [weak self] (value) -> Void in
            let _ = self?.receive(value)
        })
        self.outlet = outlet
    }

    deinit { outlet?.detach() }
    public func detach() { outlet?.detach() }
    public func prime() { outlet?.prime() }

    public func receive(value: Element) {
        while values.count >= capacity {
            values.removeAtIndex(0)
        }

        values.append(value)
    }
}

/// Creates a trap for the last `count` events of the `source` funnel
public func trap<F : BaseFunnelType>(source: F, capacity: Int = 1) -> TrapOutlet<F> {
    return TrapOutlet(source: source, capacity: capacity)
}

/// Internal FilteredFunnel curried creation
internal func filterFunnel<T : BaseFunnelType>(source: T)(predicate: (T.OutputType)->Bool)->FilteredFunnel<T> {
    return FilteredFunnel(source: source, predicate: predicate)
}

/// Creates a filter around the funnel `source` that only passes elements that satisfy the `predicate` function
public func filter<T : BaseFunnelType>(source: T, predicate: (T.OutputType)->Bool)->FilteredFunnel<T> {
    return filterFunnel(source)(predicate)
}

/// Filter that skips the first `skipCount` number of elements
public func skip<T : FunnelType>(source: T, var skipCount: Int = 1)->FilteredFunnel<T> {
    return filterFunnel(source)({ _ in skipCount-- > 0 })
}


// A mapped funnel passes all values through a transformer function before sending them to their attached outlets
public struct MappedFunnel<Source : BaseFunnelType, TransformedType> : FunnelType {
    typealias OutputType = TransformedType

    private var source: Source
    private let transform: (Source.OutputType)->TransformedType

    public init(source: Source, transform: (Source.OutputType)->TransformedType) {
        self.source = source
        self.transform = transform
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (TransformedType)->Void)->Outlet {
        return source.attach({ outlet(self.transform($0)) })
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = MappedFunnel
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return mapFunnel(self)(transform) }
}

/// Internal MappedFunnel curried creation
internal func mapFunnel<Source : BaseFunnelType, TransformedType>(source: Source)(transform: (Source.OutputType)->TransformedType)->MappedFunnel<Source, TransformedType> {
    return MappedFunnel(source: source, transform: transform)
}

/// Creates a map around the funnel `source` that passes through elements after applying the `transform` function
public func map<Source : BaseFunnelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedFunnel<Source, TransformedType> {
    return mapFunnel(source)(transform)
}


/// A CombinedAnyFunnel merges two funnels and delivers signals as a tuple to the attached outlets when any of the sources emits an event
public struct CombinedAnyFunnel<F1 : BaseFunnelType, F2 : BaseFunnelType> : FunnelType {
    public typealias OutputType = (F1.OutputType?, F2.OutputType?)
    private var source1: F1
    private var source2: F2

    public init(source1: F1, source2: F2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func attach(outlet: OutputType->Void)->Outlet {
        let sk1 = source1.attach({ v1 in outlet((v1, nil)) })
        let sk2 = source2.attach({ v2 in outlet((nil, v2)) })

        let outlet = OutletOf<OutputType>(primer: {
            sk1.prime()
            sk2.prime()
        }, detacher: {
            sk1.detach()
            sk2.detach()
        })

        return outlet
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = CombinedAnyFunnel
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return mapFunnel(self)(transform) }
}

/// Creates a combination around the funnels `source1` and `source2` that merges elements into a tuple
private func combineAny<F1 : BaseFunnelType, F2 : BaseFunnelType>(source1: F1, source2: F2)->CombinedAnyFunnel<F1, F2> {
    return CombinedAnyFunnel(source1: source1, source2: source2)
}


/// A CombinedAllFunnel merges two funnels and delivers signals as a tuple to the attached outlets when all of the sources emits an event; note that this is a stateful funnel since it needs to remember previous values that it has seen from the sources in order to pass all the non-optional values through
public struct CombinedAllFunnel<F1 : BaseFunnelType, F2 : BaseFunnelType> : FunnelType {
    public typealias OutputType = (F1.OutputType, F2.OutputType)
    private var source1: F1
    private var source2: F2

    public init(source1: F1, source2: F2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func attach(outlet: OutputType->Void)->Outlet {
        var lastv1: F1.OutputType? = nil
        var lastv2: F2.OutputType? = nil

        let sk1 = source1.attach({ v1 in
            lastv1 = v1
            if let v2 = lastv2 {
                outlet((v1, v2))
            }
        })

        let sk2 = source2.attach({ v2 in
            lastv2 = v2
            if let v1 = lastv1 {
                outlet((v1, v2))
            }
        })

        let outlet = OutletOf<OutputType>(primer: {
            sk1.prime()
            sk2.prime()
        }, detacher: {
            sk1.detach()
            sk2.detach()
        })

        return outlet
    }

    // Boilerplate funnel/filter/map
    public typealias SelfFunnel = CombinedAllFunnel
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return mapFunnel(self)(transform) }
}

/// Creates a combination around the funnels `source1` and `source2` that merges elements into a tuple
private func combineAll<F1 : BaseFunnelType, F2 : BaseFunnelType>(source1: F1, source2: F2)->CombinedAllFunnel<F1, F2> {
    return CombinedAllFunnel(source1: source1, source2: source2)
}


///// Flattens 2 nested CombinedAnyFunnels into a single funnel that passes all the elements as a single tuple of 2 elements
//public func flatten<E1, E2>(funnel: CombinedAnyFunnel<E1, E2>)->FunnelOf<(E1.OutputType?, E2.OutputType?)> {
//    return mapFunnel(funnel)({ ($0.0, $0.1) }).funnel()
//}
//
///// Flattens 3 nested CombinedAnyFunnels into a single funnel that passes all the elements as a single tuple of 3 elements
//public func flatten<E1, E2, E3>(funnel: CombinedAnyFunnel<CombinedAnyFunnel<E1, E2>, E3>)->FunnelOf<(E1.OutputType?, E2.OutputType?, E3.OutputType?)> {
//    return mapFunnel(funnel)({ ($0.0?.0, $0.0?.1, $0.1) }).funnel()
//}
//
///// Flattens 4 nested CombinedAnyFunnels into a single funnel that passes all the elements as a single tuple of 4 elements
//public func flatten<E1, E2, E3, E4>(funnel: CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<E1, E2>, E3>, E4>)->FunnelOf<(E1.OutputType?, E2.OutputType?, E3.OutputType?, E4.OutputType?)> {
//    return mapFunnel(funnel)({ ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1?.0, $0.1?.0.0) }).funnel()
//}
//
///// Flattens 5 nested CombinedAnyFunnels into a single funnel that passes all the elements as a single tuple of 5 elements
//public func flatten<E1, E2, E3, E4, E5>(funnel: CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<E1, E2>, E3>, E4>, E5>)->FunnelOf<(E1.OutputType?, E2.OutputType?, E3.OutputType?, E4.OutputType?, E5.OutputType?)> {
//    return mapFunnel(funnel)({ ($0.0?.0?.0?.0, $0.0?.0?.0?.1, $0.0?.0?.1?.0, $0.0?.1?.0.0, $0.1?.0.0.0) }).funnel()
//}
//
///// Flattens 6 nested CombinedAnyFunnels into a single funnel that passes all the elements as a single tuple of 6 elements
//public func flatten<E1, E2, E3, E4, E5, E6>(funnel: CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<CombinedAnyFunnel<E1, E2>, E3>, E4>, E5>, E6>)->FunnelOf<(E1.OutputType?, E2.OutputType?, E3.OutputType?, E4.OutputType?, E5.OutputType?, E6.OutputType?)> {
//    return mapFunnel(funnel)({ ($0.0?.0?.0?.0?.0, $0.0?.0?.0?.0?.1, $0.0?.0?.0?.1?.0, $0.0?.0?.1?.0.0, $0.0?.1?.0.0.0, $0.1?.0.0.0.0) }).funnel()
//}



/// Funnel combination & flattening operation
public func | <L : BaseFunnelType, R : BaseFunnelType>(lhs: L, rhs: R)->FunnelOf<(L.OutputType?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L.OutputType?, R.OutputType?) in (a?.0, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?)>, rhs: R)->FunnelOf<(L1?, L2?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, R.OutputType?) in (a?.0, a?.1, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, L3, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, R.OutputType?) in (a?.0, a?.1, a?.2, b) }).funnel()
}

///// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, b) }).funnel()
}

///// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, L5, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?, L5?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, L5?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, a?.4, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, L5, L6, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, L5, L6, L7, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, L5, L6, L7, L8, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, b) }).funnel()
}

/// Funnel combination & flattening operation
public func | <L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseFunnelType>(lhs: FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?)>, rhs: R)->FunnelOf<(L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.OutputType?)> {
    return mapFunnel(combineAny(lhs, rhs))({ (a, b) -> (L1?, L2?, L3?, L4?, L5?, L6?, L7?, L8?, L9?, R.OutputType?) in (a?.0, a?.1, a?.2, a?.3, a?.4, a?.5, a?.6, a?.7, a?.8, b) }).funnel()
}


/// Funnel combination & flattening operation
public func & <L : BaseFunnelType, R : BaseFunnelType>(lhs: L, rhs: R)->FunnelOf<(L.OutputType, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L.OutputType, R.OutputType) in (a.0, b) }).funnel()
}

/// Funnel combination & flattening operation
public func & <L1, L2, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2)>, rhs: R)->FunnelOf<(L1, L2, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, R.OutputType) in (a.0, a.1, b) }).funnel()
}

/// Funnel combination & flattening operation
public func & <L1, L2, L3, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3)>, rhs: R)->FunnelOf<(L1, L2, L3, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, R.OutputType) in (a.0, a.1, a.2, b) }).funnel()
}

///// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, R.OutputType) in (a.0, a.1, a.2, a.3, b) }).funnel()
}

///// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, L5, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4, L5)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, L5, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, R.OutputType) in (a.0, a.1, a.2, a.3, a.4, b) }).funnel()
}

/// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, L5, L6, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4, L5, L6)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, L5, L6, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, R.OutputType) in (a.0, a.1, a.2, a.3, a.4, a.5, b) }).funnel()
}

// commented-out because the type inference engine is slow here

/// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, L5, L6, L7, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4, L5, L6, L7)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, L5, L6, L7, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, R.OutputType) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, b) }).funnel()
}

/// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, L5, L6, L7, L8, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4, L5, L6, L7, L8)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, L5, L6, L7, L8, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, R.OutputType) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, b) }).funnel()
}

/// Funnel combination & flattening operation
public func & <L1, L2, L3, L4, L5, L6, L7, L8, L9, R : BaseFunnelType>(lhs: FunnelOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9)>, rhs: R)->FunnelOf<(L1, L2, L3, L4, L5, L6, L7, L8, L9, R.OutputType)> {
    return mapFunnel(combineAll(lhs, rhs))({ (a, b) -> (L1, L2, L3, L4, L5, L6, L7, L8, L9, R.OutputType) in (a.0, a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, b) }).funnel()
}


infix operator ∞> { }
infix operator ∞-> { }

/// Attachment operation
public func ∞> <T : BaseFunnelType>(lhs: T, rhs: T.OutputType->Void)->Outlet { return lhs.attach(rhs) }

/// Attachment operation with priming
public func ∞-> <T : BaseFunnelType>(lhs: T, rhs: T.OutputType->Void)->Outlet { return prime(lhs.attach(rhs)) }



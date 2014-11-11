//
//  Funnels.swift
//  SwiftFlow
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// An Funnel wraps a type (either a value or a reference) and sends all state operations down to each attached outlet
public protocol BaseFunnelType {
    typealias OutputType

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    func attach(outlet: (Self.OutputType)->Void)->Outlet
}


/// A funnel with support for filtering, mapping, etc.
public protocol ExtendedFunnelType : BaseFunnelType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredChannel itself implements ChannelType, and so is regarded as a circular protocol declaration)

    /// Returns a type-erasing funnel wrapper around the current channel, making the channel read-only to subsequent pipeline stages
    var funnelOf: FunnelOf<OutputType> { get }

    /// Returns a filtered funnel that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.OutputType)->Bool)->FilteredFunnel<Self>

    /// Returns a mapped funnel that transforms the elements before passing them through to the outlets
    func map<TransformedType>(transform: (Self.OutputType)->TransformedType)->MappedFunnel<Self, TransformedType>

//    /// Returned a combined funnel where signals from either funnel will be combined into a signal for the combined funnel's receivers
//    func combine<WithFunnel : BaseFunnelType>(channel: WithFunnel)->CombinedFunnel<Self, WithFunnel>

}

public protocol FunnelType : BaseFunnelType, ExtendedFunnelType {

}


///// A type-erased funnel.
/////
///// Forwards operations to an arbitrary underlying funnel with the same
///// `OutputType` type, hiding the specifics of the underlying funnel.
public struct FunnelOf<OutputType> : FunnelType {
    private let attacher: (outlet: (OutputType) -> Void) -> Outlet

    init<G : BaseFunnelType where OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }

    // Boilerplate funnel/filter/map
    private typealias ThisFunnel = FunnelOf
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<ThisFunnel> { return FilteredFunnel(source: self, predicate: predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<ThisFunnel, TransformedType> { return MappedFunnel(source: self, transform: transform) }
    // public func combine<WithFunnel>(funnel: WithFunnel)->CombinedFunnel<ThisFunnel, WithFunnel> { return CombinedFunnel(source1: self, source2: funnel) }

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
    private typealias ThisFunnel = FilteredFunnel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<ThisFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<ThisFunnel, TransformedType> { return mapFunnel(self)(transform) }
    // public func combine<WithFunnel>(funnel: WithFunnel)->CombinedFunnel<ThisFunnel, WithFunnel> { return CombinedFunnel(source1: self, source2: funnel) }
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
    private typealias ThisFunnel = MappedFunnel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<ThisFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<ThisFunnel, TransformedType> { return mapFunnel(self)(transform) }
    // public func combine<WithFunnel>(funnel: WithFunnel)->CombinedFunnel<ThisFunnel, WithFunnel> { return CombinedFunnel(source1: self, source2: funnel) }
}

/// Internal MappedFunnel curried creation
internal func mapFunnel<Source : BaseFunnelType, TransformedType>(source: Source)(transform: (Source.OutputType)->TransformedType)->MappedFunnel<Source, TransformedType> {
    return MappedFunnel(source: source, transform: transform)
}

/// Creates a map around the funnel `source` that passes through elements after applying the `transform` function
public func map<Source : BaseFunnelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedFunnel<Source, TransformedType> {
    return mapFunnel(source)(transform)
}


///// A CombinedFunnel merges two funnels and delivers signals as a tuple to the attached outlets
//public struct CombinedFunnel<S1 : BaseFunnelType, S2 : BaseFunnelType> : FunnelType {
//}

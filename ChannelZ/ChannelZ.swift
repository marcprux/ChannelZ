//
//  Channels.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// A Channel is a funnel that can also receive back source value changes
public protocol BaseChannelType : BaseFunnelType {
    /// The type of element produced by the source of the Funnel
    typealias SourceType

    /// Write `x` back to the source of the channel
    /// Note that we cannot simply have value be settable, since that implicitly makes it a mutable
    /// operation, which isn't needed channels are always eventually rooted in a reference type
    func push(x: SourceType)

    /// Pulls the current source value through the channel pipeline
    func pull()->Self.OutputType

}

/// A DirectChannelType allows direct access to the underlying source value
public protocol DirectChannelType : BaseChannelType {
    /// The current underlying value of the channel source; nonmutating since channels are always rooted in a reference type
    var value: Self.SourceType { get nonmutating set }
}

/// A channel with support for filtering, mapping, etc.
public protocol ExtendedChannelType : BaseChannelType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredChannel itself implements ChannelType, and so is regarded as a circular protocol declaration)

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    var funnelOf: FunnelOf<OutputType> { get }

    /// Returns a type-erasing channel wrapper around the current channel
    var channelOf: ChannelOf<SourceType, OutputType> { get }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.OutputType)->Bool)->FilteredChannel<Self>

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<Self, OutputTransformedType, Self.SourceType>

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<Self, Self.OutputType, SourceTransformedType>

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    func combine<WithChannel : BaseChannelType>(channel: WithChannel)->CombinedChannel<Self, WithChannel>

}

/// A channel combines basic channel functionality (attach/push/pull) with extended functionality (filer/map/combine)
public protocol ChannelType : BaseChannelType, ExtendedChannelType { }


/// A type-erased channel with potentially different source and output types
///
/// Forwards operations to an arbitrary underlying channel with the same 
/// `SourceType` and `OutputType` types, hiding the specifics of the underlying channel type.
public struct ChannelOf<SourceType, OutputType> : ChannelType {
    private let attacher: (outlet: (OutputType) -> (Void)) -> Outlet
    private let pusher: (SourceType) -> ()
    private let puller: () -> (OutputType)
    private let valueGetter: () -> SourceType

    init<G : BaseChannelType where SourceType == G.SourceType, OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
        self.pusher = { base.push($0) }
        self.valueGetter = { base.pull() }
        self.puller = { base.pull() }
    }

    public func push(value: SourceType) {
        pusher(value)
    }

    public func pull() -> OutputType {
        return puller()
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = ChannelOf

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}

/// A type-erased channel with the same source and output types.
public struct ChannelZ<T> : ChannelType, DirectChannelType {
    typealias SourceType = T
    typealias OutputType = T

    private let attacher: (outlet: (T) -> (Void)) -> Outlet
    private let pusher: (T) -> ()
    private let puller: () -> (T)
    private let valueGetter: () -> T

    init<G : BaseChannelType where SourceType == G.SourceType, OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
        self.pusher = { base.push($0) }
        self.valueGetter = { base.pull() }
        self.puller = { base.pull() }
    }

    /// DirectChannelType access to the underlying source value
    public var value : SourceType {
        get { return pull() }
        nonmutating set(v) { push(v) }
    }

    public func push(value: SourceType) {
        pusher(value)
    }

    public func pull() -> OutputType {
        return puller()
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = ChannelZ

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}

/// A Channel around a field, which can be accessed using the value property
/// This is a reference type since the field itself is the shared mutable state and Swift doesn't have any KVO equivalent
public final class FieldChannel<T> : ChannelType {
    public typealias SourceType = T
    public typealias OutputType = StateEvent<T>

    private var outlets = OutletListReference<OutputType>()

    /// The underlying value of the funnel source
    public var value : SourceType {
        didSet(oldValue) {
            outlets.pump(StateEvent(lastValue: oldValue, nextValue: value))
        }
    }

    public init(source v: T) {
        value = v
    }

    public func push(value: SourceType) {
        if outlets.entrancy == 0 {
            self.value = value
        }
    }

    public func pull() -> OutputType {
        return StateEvent(lastValue: value, nextValue: value)
    }

    public func attach(outlet: (OutputType)->())->Outlet { return outlets.addOutlet(outlet) }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = FieldChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// Creates an embedded Funnel field source
public func channelField<T>(source: T)->ChannelZ<T> {
    return ChannelZ(FieldChannel(source: source).map({ $0.nextValue }))
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: T)->ChannelZ<T> {
    return channelStateValues(filterChannel(FieldChannel(source: source))({ $0.nextValue != $0.lastValue }))
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: Optional<T>)->ChannelZ<Optional<T>> {
    let optchan: ChannelOf<Optional<T>, StateEvent<Optional<T>>> = FieldChannel(source: source).channelOf
    return channelOptionalStateChanges(optchan)
}


/// A filtered channel that flows only those values that pass the filter predicate
public struct FilteredChannel<Source : BaseChannelType> : ChannelType {
    public typealias OutputType = Source.OutputType
    public typealias SourceType = Source.SourceType

    private var source: Source
    private let predicate: (Source.OutputType)->Bool

    public init(source: Source, predicate: (Source.OutputType)->Bool) {
        self.source = source
        self.predicate = predicate
    }

    public func push(value: SourceType) {
        return source.push(value)
    }

    public func pull() -> OutputType {
        return source.pull() // FIXME: pull skips the filter; should we return an optional?
    }

    public func attach(outlet: (Source.OutputType)->Void)->Outlet {
        return source.attach({ if self.predicate($0) { outlet($0) } })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = FilteredChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// Internal FilteredChannel curried creation
internal func filterChannel<T : BaseChannelType>(source: T)(predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return FilteredChannel(source: source, predicate: predicate)
}

/// Creates a filter around the channel `source` that only passes elements that satisfy the `predicate` function
public func filter<T : BaseChannelType>(source: T, predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return filterChannel(source)(predicate)
}


/// Filters out optional nils and maps the results to unwrapped values
public func unwrap<T, U>(source: ChannelOf<T, Optional<U>>)->ChannelOf<T, U> {
    return ChannelOf(mapChannel(filterChannel(source)({ $0 != nil }))({ $0! })({ $0 }))
}



/// A mapped channel passes all values through a transformer function before sending them to its attached outlets
public struct MappedChannel<Source : BaseChannelType, OutputTransformedType, SourceTransformedType> : ChannelType {
    public typealias OutputType = OutputTransformedType
    public typealias SourceType = SourceTransformedType

    private var source: Source
    private let outputTransform: (Source.OutputType)->OutputTransformedType
    private let sourceTransform: (SourceTransformedType)->Source.SourceType

    public init(source: Source, outputTransform: (Source.OutputType)->OutputTransformedType, sourceTransform: (SourceTransformedType)->Source.SourceType) {
        self.source = source
        self.outputTransform = outputTransform
        self.sourceTransform = sourceTransform
    }

    public func push(value: SourceType) {
        return source.push(sourceTransform(value))
    }

    public func pull() -> OutputType {
        return outputTransform(source.pull())
    }

    public func attach(outlet: (OutputTransformedType)->Void)->Outlet {
        return source.attach({ outlet(self.outputTransform($0)) })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = MappedChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}

/// Internal MappedChannel curried creation
internal func mapChannel<Source : BaseChannelType, OutputTransformedType, SourceTransformedType>(source: Source)(outputTransform: (Source.OutputType)->OutputTransformedType)(sourceTransform: (SourceTransformedType)->Source.SourceType)->MappedChannel<Source, OutputTransformedType, SourceTransformedType> {
    return MappedChannel(source: source, outputTransform: outputTransform, sourceTransform: sourceTransform)
}

internal func mapOutput<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType, Source.SourceType> {
    return mapChannel(source)(transform)({ $0 })
}

internal func mapSource<Source : BaseChannelType, TransformedType>(source: Source, transform: (TransformedType)->Source.SourceType)->MappedChannel<Source, Source.OutputType, TransformedType> {
    return mapChannel(source)({ $0 })(transform)
}

/// Creates a map around the funnel `source` that passes through elements after applying the `transform` function
public func map<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType, Source.SourceType> {
    return mapOutput(source, transform)
}

/// Creates a reverse map around the channel `source` that sends all source changes up after applying the `transform` function
public func rmap<Source : BaseChannelType, TransformedType>(source: Source, transform: (TransformedType)->Source.SourceType)->MappedChannel<Source, Source.OutputType, TransformedType> {
    return mapSource(source, transform)
}



/// A CombinedChannel merges two channels and delivers signals as a tuple to the attached outlets
public struct CombinedChannel<C1 : BaseChannelType, C2 : BaseChannelType> : ChannelType {
    public typealias OutputType = (C1.OutputType, C2.OutputType)
    public typealias SourceType = (C1.SourceType, C2.SourceType)
    private var channel1: C1
    private var channel2: C2

    public init(channel1: C1, channel2: C2) {
        self.channel1 = channel1
        self.channel2 = channel2
    }

    public func push(value: SourceType) {
        channel1.push(value.0)
        channel2.push(value.1)
    }

    public func pull() -> OutputType {
        return (channel1.pull(), channel2.pull())
    }

    public func attach(outlet: OutputType->Void)->Outlet {
        let sk1 = channel1.attach({ v1 in outlet((v1, self.channel2.pull())) })
        let sk2 = channel2.attach({ v2 in outlet((self.channel1.pull(), v2)) })

        let outlet = OutletOf<OutputType>(pumper: { (v1, v2) in }, detacher: {
            sk1.detach()
            sk2.detach()
        })
        return outlet
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = CombinedChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}

/// Internal CombinedChannel curried creation
internal func combineChannel<C1 : BaseChannelType, C2 : BaseChannelType>(channel1: C1)(channel2: C2)->CombinedChannel<C1, C2> {
    return CombinedChannel(channel1: channel1, channel2: channel2)
}

/// Creates a combination around the channels `channel1` and `channel2` that merges elements into a tuple
internal func combine<C1 : BaseChannelType, C2 : BaseChannelType>(channel1: C1, channel2: C2)->CombinedChannel<C1, C2> {
    return combineChannel(channel1)(channel2: channel2)
}

/// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2>(channel: CombinedChannel<E1, E2>)->ChannelOf<(E1.SourceType, E2.SourceType), (E1.OutputType, E2.OutputType)> {
    return mapChannel(channel)({ ($0.0, $0.1) })({ ($0, $1) }).channelOf
}

/// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3>(channel: CombinedChannel<CombinedChannel<E1, E2>, E3>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType)> {
    return mapChannel(channel)({ ($0.0.0, $0.0.1, $0.1) })({ (($0, $1), $2) }).channelOf
}

/// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4>(channel: CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.1.0.0) })({ ((($0, $1), $2), $3) }).channelOf
}

/// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4, E5>(channel: CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>, E5>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType, E5.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType, E5.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1.0, $0.0.1.0.0, $0.1.0.0.0) })({ (((($0, $1), $2), $3), $4) }).channelOf
}

/// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4, E5, E6>(channel: CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>, E5>, E6>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType, E5.SourceType, E6.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType, E5.OutputType, E6.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1.0, $0.0.0.1.0.0, $0.0.1.0.0.0, $0.1.0.0.0.0) })({ ((((($0, $1), $2), $3), $4), $5) }).channelOf
}



/// Encapsulation of a state event, where `lastValue` was the previous state and `nextValue` will be the current state
public protocol StateEventType {
    typealias Element

    /// The previous value for the state
    var lastValue: Optional<Element> { get }

    /// The new value for the state
    var nextValue: Element { get }
}

/// Encapsulation of a state event, where `lastValue` was the previous state and `nextValue` will be the current state
public struct StateEvent<T> : StateEventType {
    typealias Element = T

    /// The previous value for the state
    public let lastValue: Optional<T>

    /// The new value for the state
    public let nextValue: T
}


/// Channels a StateEventType into just the new values
internal func channelStateValues<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element>(source: T)->ChannelZ<T.SourceType> {
    return ChannelZ(mapOutput(source, { $0.nextValue }))
}

/// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
internal func channelStateChanges<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element, T.OutputType.Element : Equatable>(source: T)->ChannelZ<T.SourceType> {
    return channelStateValues(filterChannel(source)({ $0.nextValue != $0.lastValue }))
}

//public func flattenChannel

internal func channelOptionalStateChanges<T where T : Equatable>(source: ChannelOf<Optional<T>, StateEvent<Optional<T>>>)->ChannelZ<Optional<T>> {
    let filterChanges = source.filter({ (event: StateEvent<Optional<T>>) -> Bool in
        if let lastValue = event.lastValue {
            if let nextValue = event.nextValue {
                return lastValue != nextValue
            }
        }

        return event.lastValue == nil && event.nextValue == nil ? false : true
    })

    return channelStateValues(filterChanges)
}


/// Creates a state pipeline between two channels with equivalent source and output types; changes made to either side will push the transformed value to the the other side.
///
/// Note that the SourceType of either side must be identical to the OutputType of the other side, which is usually accomplished by adding maps and combinations to the pipelines until they achieve parity.
///
/// :param: a one side of the pipeline
/// :param: b the other side of the pipeline
/// :returns: a detachable outlet for the conduit
public func conduit<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.OutputType, B.SourceType == A.OutputType>(var a: A, var b: B) -> Outlet {
    let asink = a.attach({ b.push($0) })
    let bsink = b.attach({ a.push($0) })

    let outlet = OutletOf<(A.OutputType, B.OutputType)>(pumper: { _ in }, detacher: {
        asink.detach()
        bsink.detach()
    })

    return outlet
}


prefix operator ∞ { }
postfix operator ∞ { }

/// Prefix operator for creating a Swift field sieve reference to the underlying equatable type
/// 
/// :param: arg the trailing argument (without a separating space) will be used to initialize a field refence
///
/// :returns: a ChannelZ wrapper for the Swift field
public prefix func ∞ <T : Equatable>(rhs: T)->ChannelZ<T> { return sieveField(rhs) }

/// Prefix operator for creating a Swift field channel reference to the underlying type
///
/// :param: arg the trailing argument (without a separating space) will be used to initialize a field refence
///
/// :returns: a ChannelZ wrapper for the Swift field
public prefix func ∞ <T>(rhs: T)->ChannelZ<T> { return channelField(rhs) }

public postfix func ∞ <T>(lhs: T)->T { return lhs }


/// Operator for setting Channel.value that returns the value itself
infix operator <- {}
public func <-<T : ChannelType>(var lhs: T, rhs: T.SourceType) -> T.SourceType {
    lhs.push(rhs)
    return rhs
}

///// Attachment operation
//public func += <T : BaseFunnelType>(lhs: T, rhs: T.OutputType->Void)->Outlet { return lhs.attach(rhs) }
//
///// Alternate attachment operation
//public func => <T : BaseFunnelType>(lhs: T, rhs: T.OutputType->Void)->Outlet { return lhs.attach(rhs) }
//infix operator => { }

/// Alternate attachment operation
public func -∞> <T : BaseFunnelType>(lhs: T, rhs: T.OutputType->Void)->Outlet { return lhs.attach(rhs) }
infix operator -∞> { }


/// Channel combination & flattening operations
public func + <L : BaseChannelType, R : BaseChannelType>(lhs: L, rhs: R)->ChannelOf<(L.SourceType, R.SourceType), (L.OutputType, R.OutputType)> {
    return flatten(combineChannel(lhs)(channel2: rhs))
}

public func + <E1, E2, C : BaseChannelType>(lhs: CombinedChannel<E1, E2>, rhs: C)->ChannelOf<(E1.SourceType, E2.SourceType, C.SourceType), (E1.OutputType, E2.OutputType, C.OutputType)> {
    return flatten(combineChannel(lhs)(channel2: rhs))
}

/// Conduit creation operators
infix operator <=∞=> { }
infix operator ∞=> { }
infix operator <=∞ { }


/// Bi-directional conduit operator with natural equivalence between two identical types
public func <=∞=><L : ChannelType, R : ChannelType where L.OutputType == R.SourceType, L.SourceType == R.OutputType>(lhs: L, rhs: R)->Outlet {
    return conduit(lhs, rhs)
}


/// One-sided conduit operator with natural equivalence between two identical types
public func ∞=><L : BaseFunnelType, R : ChannelType where L.OutputType == R.SourceType>(lhs: L, rhs: R)->Outlet {
    let lsink = lhs.attach { rhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { lsink.detach() })
}


/// One-sided conduit operator with natural equivalence between two identical types
public func <=∞<L : ChannelType, R : BaseFunnelType where L.SourceType == R.OutputType>(lhs: L, rhs: R)->Outlet {
    let rsink = rhs.attach { lhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { rsink.detach() })
}


/// Conduit conversion operators
infix operator <~∞~> { }
infix operator ∞~> { }
infix operator <~∞ { }


/// Conduit operator that filters out nil values with a custom transformer
public func <~∞~> <L : ChannelType, R : ChannelType>(lhs: (o: L, f: L.OutputType->Optional<R.SourceType>), rhs: (o: R, f: R.OutputType->Optional<L.SourceType>))->Outlet {
    let lhsm = lhs.o.map({ lhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })
    let rhsm = rhs.o.map({ rhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })

    return conduit(lhsm, rhsm)
}


/// Convert (possibly lossily) between two numeric types
public func <~∞~> <L : ChannelType, R : ChannelType where L.SourceType: ConduitNumericCoercible, L.OutputType: ConduitNumericCoercible, R.SourceType: ConduitNumericCoercible, R.OutputType: ConduitNumericCoercible>(lhs: L, rhs: R)->Outlet {
    return conduit(lhs.map({ convertNumericType($0) }), rhs.map({ convertNumericType($0) }))
}


/// Convert (possibly lossily) between two numeric types
public func ∞~> <L : ChannelType, R : ChannelType where L.OutputType: ConduitNumericCoercible, R.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Outlet {
    let lsink = lhs.map({ convertNumericType($0) }).attach { rhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { lsink.detach() })
}

/// Convert (possibly lossily) between two numeric types
public func <~∞ <L : ChannelType, R : ChannelType where R.OutputType: ConduitNumericCoercible, L.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Outlet {
    let rsink = rhs.map({ convertNumericType($0) }).attach { lhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { rsink.detach() })
}



/// Conduit conversion operators
infix operator <?∞?> { }
infix operator ∞?> { }
infix operator <?∞ { }

/// Conduit operator to convert (possibly lossily) between optionally castable types
public func <?∞?><L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { rhs.push($0) }
    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { lhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: {
        rsink.detach()
        lsink.detach()
    })
}

/// Conduit operator to convert (possibly lossily) between optionally castable types
public func ∞?> <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { rhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { lsink.detach() })
}

/// Conduit operator to convert (possibly lossily) between optionally castable types
public func <?∞ <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { lhs.push($0) }
    return OutletOf<(L.OutputType, R.OutputType)>(pumper: { _ in }, detacher: { rsink.detach() })
}


/// Dynamically convert between the given numeric types, getting past Swift's inability to statically cast between numbers
public func convertNumericType<From : ConduitNumericCoercible, To : ConduitNumericCoercible>(from: From) -> To {
    // try both sides of the convertables so this can be extended by other types (such as NSNumber)
    return To.fromConduitNumericCoercible(from) ?? from.toConduitNumericCoercible() ?? from as To
}


/// Implemented by numeric types that can be coerced into other numeric types
public protocol ConduitNumericCoercible {
    class func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Self?
    func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T?
}


extension Bool : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Bool? {
        if let value = value as? Bool { return self.init(value) }
        else if let value = value as? Int8 { return self.init(value != 0) }
        else if let value = value as? UInt8 { return self.init(value != 0) }
        else if let value = value as? Int16 { return self.init(value != 0) }
        else if let value = value as? UInt16 { return self.init(value != 0) }
        else if let value = value as? Int32 { return self.init(value != 0) }
        else if let value = value as? UInt32 { return self.init(value != 0) }
        else if let value = value as? Int { return self.init(value != 0) }
        else if let value = value as? UInt { return self.init(value != 0) }
        else if let value = value as? Int64 { return self.init(value != 0) }
        else if let value = value as? UInt64 { return self.init(value != 0) }
        else if let value = value as? Float { return self.init(value != 0) }
        else if let value = value as? Float80 { return self.init(value != 0) }
        else if let value = value as? Double { return self.init(value != 0) }
        else { return value as? Bool }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self) as? T }
        else if T.self is Int8.Type { return Int8(self ? 1 : 0) as? T }
        else if T.self is UInt8.Type { return UInt8(self ? 1 : 0) as? T }
        else if T.self is Int16.Type { return Int16(self ? 1 : 0) as? T }
        else if T.self is UInt16.Type { return UInt16(self ? 1 : 0) as? T }
        else if T.self is Int32.Type { return Int32(self ? 1 : 0) as? T }
        else if T.self is UInt32.Type { return UInt32(self ? 1 : 0) as? T }
        else if T.self is Int.Type { return Int(self ? 1 : 0) as? T }
        else if T.self is UInt.Type { return UInt(self ? 1 : 0) as? T }
        else if T.self is Int64.Type { return Int64(self ? 1 : 0) as? T }
        else if T.self is UInt64.Type { return UInt64(self ? 1 : 0) as? T }
        else if T.self is Float.Type { return Float(self ? 1 : 0) as? T }
        else if T.self is Float80.Type { return Float80(self ? 1 : 0) as? T }
        else if T.self is Double.Type { return Double(self ? 1 : 0) as? T }
        else { return self as? T }
    }
}


extension Int8 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int8? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int8 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt8 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt8? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Float80 { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt8 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int16 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int16? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int16 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt16 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt16? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Float80 { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt16 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int32 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int32? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int32 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt32 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt32? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Float80 { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt32 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Float80 { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int64 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int64? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int64 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt64 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt64? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Float80 { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt64 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Float : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Float? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Float }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Float80 : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Float80? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Float80 }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Double : ConduitNumericCoercible {
    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Double? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Float80 { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Double }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

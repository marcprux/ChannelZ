//
//  Channels.swift
//  SwiftFlow
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//


/// A Channel is a funnel that can also receive back source value changes
public protocol BaseChannelType : BaseFunnelType {
    /// The type of element produced by the source of the Funnel
    typealias SourceType

    /// The current underlying value of the channel source
    var value: Self.SourceType { get set } // FIXME: add in set; we get some crazy crashes when we do

    /// Write `x` back to the source of the channel
    func push(x: SourceType)
}

/// A channel with support for filtering, mapping, etc.
public protocol ExtendedChannelType : BaseChannelType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredChannel itself implements ChannelType, and so is regarded as a circular protocol declaration)

    /// Returns a type-erasing funnel wrapper around the current channel, making the channel read-only to subsequent pipeline stages
    var funnelOf: FunnelOf<OutputType> { get }

    /// Returns a type-erasing channel wrapper around the current channel
    var channelOf: ChannelOf<SourceType, OutputType> { get }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.OutputType)->Bool)->FilteredChannel<Self>

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    func map<TransformedType>(transform: (Self.OutputType)->TransformedType)->MappedChannel<Self, TransformedType>

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    func combine<WithChannel : BaseChannelType>(channel: WithChannel)->CombinedChannel<Self, WithChannel>

}


public protocol ChannelType : BaseChannelType, ExtendedChannelType {
}


/// A type-erased channel.
///
/// Forwards operations to an arbitrary underlying channel with the same 
/// `SourceType` and `OutputType` types, hiding the specifics of the underlying channel type.
public struct ChannelOf<SourceType, OutputType> : ChannelType {
    private let attacher: (outlet: (OutputType) -> Void) -> Outlet
    private let pusher: (SourceType) -> Void
    private let valueGetter: () -> SourceType

    /// The underlying value of the funnel source
    public var value : SourceType {
        get { return valueGetter() }
        set { pusher(newValue) }
    }

    init<G : BaseChannelType where SourceType == G.SourceType, OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
        self.pusher = { base.push($0) }
        self.valueGetter = { base.value }
    }

    /// Pushes the value back to the source of the channel
    ///
    /// :param: value the value to set in the source of the channel
    public func push(value: SourceType) {
        pusher(value)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }


    // Boilerplate funnel/channel/filter/map
    public typealias ThisChannel = ChannelOf
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<ThisChannel, TransformedType> { return mapChannel(self)(transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(source2: channel) }
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
            outlets.receive(StateEvent(lastValue: oldValue, nextValue: value))
        }
    }

    public init(source v: T) {
        value = v
    }

    /// Pushes the value back to the source of the channel
    ///
    /// :param: value the value to set in the source of the channel
    public func push(value: SourceType) {
        if !outlets.flowing {
            self.value = value
        }
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet { return outlets.addOutlet(outlet) }


    // Boilerplate funnel/channel/filter/map
    public typealias ThisChannel = FieldChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<ThisChannel, TransformedType> { return mapChannel(self)(transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(source2: channel) }
}


/// Creates an embedded Funnel field source
public func channelField<T>(source: T)->ChannelOf<T, T> {
    return FieldChannel(source: source).map({ $0.nextValue }).channelOf
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: T)->ChannelOf<T, T> {
    return channelStateValues(filterChannel(FieldChannel(source: source))({ $0.nextValue != $0.lastValue }))
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: Optional<T>)->ChannelOf<Optional<T>, Optional<T>> {
    let optchan: ChannelOf<Optional<T>, StateEvent<Optional<T>>> = FieldChannel(source: source).channelOf
    return channelOptionalStateChanges(optchan)
}


/// A filtered channel that flows only those values that pass the filter predicate
public struct FilteredChannel<Source : BaseChannelType> : ChannelType {
    typealias OutputType = Source.OutputType
    typealias SourceType = Source.SourceType

    private var source: Source
    private let predicate: (Source.OutputType)->Bool

    public var value: SourceType {
        get { return self.source.value }
        // FIXME: compiler error when trying call setter: “Type '()' does not conform to protocol 'Sink'”
        set(v) { self.push(v) }
    }

    public init(source: Source, predicate: (Source.OutputType)->Bool) {
        self.source = source
        self.predicate = predicate
    }

    /// Pushes the value back to the source of the channel
    ///
    /// :param: value the value to set in the source of the channel
    public func push(value: SourceType) {
        return source.push(value)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (Source.OutputType)->Void)->Outlet {
        return source.attach({ if self.predicate($0) { outlet($0) } })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias ThisChannel = FilteredChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<ThisChannel, TransformedType> { return mapChannel(self)(transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(source2: channel) }
}


/// Internal FilteredChannel curried creation
internal func filterChannel<T : BaseChannelType>(source: T)(predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return FilteredChannel(source: source, predicate: predicate)
}

/// Creates a filter around the channel `source` that only passes elements that satisfy the `predicate` function
public func filter<T : BaseChannelType>(source: T, predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return filterChannel(source)(predicate)
}



/// A mapped channel passes all values through a transformer function before sending them to its attached outlets
public struct MappedChannel<Source : BaseChannelType, TransformedType> : ChannelType {
    typealias OutputType = TransformedType
    typealias SourceType = Source.SourceType

    private var source: Source
    private let transform: (Source.OutputType)->TransformedType

    public var value: SourceType {
        get { return self.source.value }
        set(newValue) { self.push(newValue) }
    }

    public init(source: Source, transform: (Source.OutputType)->TransformedType) {
        self.source = source
        self.transform = transform
    }

    /// Pushes the value back to the source of the channel
    ///
    /// :param: value the value to set in the source of the channel
    public func push(value: SourceType) {
        return source.push(value)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (TransformedType)->Void)->Outlet {
        return source.attach({ outlet(self.transform($0)) })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias ThisChannel = MappedChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<ThisChannel, TransformedType> { return mapChannel(self)(transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(source2: channel) }
}


/// Internal MappedChannel curried creation
internal func mapChannel<Source : BaseChannelType, TransformedType>(source: Source)(transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType> {
    return MappedChannel(source: source, transform: transform)
}

/// Creates a map around the funnel `source` that passes through elements after applying the `transform` function
public func map<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType> {
    return mapChannel(source)(transform)
}

/// A CombinedChannel merges two channels and delivers signals as a tuple to the attached outlets
public struct CombinedChannel<S1 : BaseChannelType, S2 : BaseChannelType> : ChannelType {
    public typealias OutputType = (S1.OutputType, S2.OutputType)
    public typealias SourceType = (S1.SourceType, S2.SourceType)
    private var source1: S1
    private var source2: S2

    public var value: SourceType {
        get { return (source1.value, source2.value) }
        set { push((newValue.0, newValue.1)) }
    }

    public init(source1: S1, source2: S2) {
        self.source1 = source1
        self.source2 = source2
    }

    public func push(value: SourceType) {
        source1.push(value.0)
        source2.push(value.1)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: OutputType->Void)->Outlet {

        var last1: S1.OutputType?
        var last2: S2.OutputType?

        let sk1 = source1.attach({
            last1 = $0
            if let v2 = last2 {
                outlet(($0, v2))
            }
        })

        let sk2 = source2.attach({
            last2 = $0
            if let v1 = last1 {
                outlet((v1, $0))
            }
        })

        // FIXME: we track the last known values of each of the values, but this means that we won't start receiving any events at all until both of the outlets have broadcast state changes, which is not good; we need some way to force the sources to perform a push once we have attached the two outlets
        if false {
            println("#### FIXME")
        }

        // here we are trying to prime the pump, but it will fail if, say, we have an intermediate blocking filter or something
        source1.push(source1.value)
        source2.push(source2.value)

        let outlet = OutletOf<OutputType>(receiver: { _ in }, detacher: {
            sk1.detach()
            sk2.detach()
        })
        return outlet
    }

    // Boilerplate funnel/channel/filter/map
    public typealias ThisChannel = CombinedChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<ThisChannel, TransformedType> { return mapChannel(self)(transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(source2: channel) }
}

/// Internal CombinedChannel curried creation
internal func combineChannel<C1 : BaseChannelType, C2 : BaseChannelType>(source1: C1)(source2: C2)->CombinedChannel<C1, C2> {
    return CombinedChannel(source1: source1, source2: source2)
}

/// Creates a combination around the channels `source1` and `source2` that merges elements into a tuple
internal func combine<C1 : BaseChannelType, C2 : BaseChannelType>(source1: C1, source2: C2)->CombinedChannel<C1, C2> {
    return combineChannel(source1)(source2: source2)
}




/// Encapsulation of a state event, where `oldValue` was the previous state and `newValue` will be the current state
public protocol StateEventType {
    typealias Element

    var lastValue: Element { get }
    var nextValue: Element { get }
}

/// Encapsulation of a state event, where `oldValue` was the previous state and `newValue` will be the current state
public struct StateEvent<T> : StateEventType {
    typealias Element = T

    public let lastValue: T
    public let nextValue: T
}


/// Channels a StateEventType into just the new values
public func channelStateValues<T where T : BaseChannelType, T.OutputType : StateEventType>(source: T)->ChannelOf<T.SourceType, T.OutputType.Element> {
    return mapChannel(source)({ $0.nextValue }).channelOf
}

/// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
public func channelStateChanges<T where T : BaseChannelType, T.OutputType : StateEventType, T.OutputType.Element : Equatable>(source: T)->ChannelOf<T.SourceType, T.OutputType.Element> {
    return channelStateValues(filterChannel(source)({ $0.nextValue != $0.lastValue }))
}

public func channelOptionalStateChanges<T where T : Equatable>(source: ChannelOf<Optional<T>, StateEvent<Optional<T>>>)->ChannelOf<Optional<T>, Optional<T>> {
    let filterChanges = source.filter({ (event: StateEvent<Optional<T>>) -> Bool in
        if let lastValue = event.lastValue {
            if let nextValue = event.nextValue {
                return lastValue != nextValue
            }
        }

        return event.lastValue == nil && event.nextValue == nil ? false : true
    })

    return channelStateValues(filterChanges).channelOf
}


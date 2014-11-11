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
//    var value: Self.SourceType { get set } // FIXME: add in set; we get some crazy crashes when we do

    /// Write `x` back to the source of the channel
    /// Note that we cannot simply have value be settable, since that implicitly makes it a mutable
    /// operation, which isn't needed channels are always eventually rooted in a reference type
    func push(x: SourceType)

    /// Pulls the current source value through the channel pipeline
    func pull()->Self.OutputType
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
    func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<Self, OutputTransformedType, Self.SourceType>

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<Self, Self.OutputType, SourceTransformedType>

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
    public typealias ThisChannel = ChannelOf
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<ThisChannel, OutputTransformedType, ThisChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<ThisChannel, ThisChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
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
    public typealias ThisChannel = FieldChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<ThisChannel, OutputTransformedType, ThisChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<ThisChannel, ThisChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
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
    public typealias ThisChannel = FilteredChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<ThisChannel, OutputTransformedType, ThisChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<ThisChannel, ThisChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
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
/// A mapped channel passes all values through a transformer function before sending them to its attached outlets
public struct MappedChannel<Source : BaseChannelType, OutputTransformedType, SourceTransformedType> : ChannelType {
    typealias OutputType = OutputTransformedType
    typealias SourceType = SourceTransformedType

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
    public typealias ThisChannel = MappedChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<ThisChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<ThisChannel, OutputTransformedType, ThisChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<ThisChannel, ThisChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
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
        let sk1 = channel1.attach({ v1 in
            outlet((v1, self.channel2.pull()))
        })

        let sk2 = channel2.attach({ v2 in
            outlet((self.channel1.pull(), v2))
        })

        let outlet = OutletOf<OutputType>(receiver: { (v1, v2) in }, detacher: {
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
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<ThisChannel, OutputTransformedType, ThisChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<ThisChannel, ThisChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<ThisChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}

/// Internal CombinedChannel curried creation
internal func combineChannel<C1 : BaseChannelType, C2 : BaseChannelType>(channel1: C1)(channel2: C2)->CombinedChannel<C1, C2> {
    return CombinedChannel(channel1: channel1, channel2: channel2)
}

/// Creates a combination around the channels `channel1` and `channel2` that merges elements into a tuple
internal func combine<C1 : BaseChannelType, C2 : BaseChannelType>(channel1: C1, channel2: C2)->CombinedChannel<C1, C2> {
    return combineChannel(channel1)(channel2: channel2)
}

public func flatten<E1, E2, E3>(channel: CombinedChannel<CombinedChannel<E1, E2>, E3>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType)> {
    return channel.map({ ($0.0.0, $0.0.1, $0.1) }).rmap({ (($0, $1), $2) }).channelOf
}

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
//public func flatten<E1, E2, E3>(channel: CombinedChannel<CombinedChannel<E1, E2>, E3>)->ChannelOf<((E1.SourceType, E2.SourceType), E3.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType)> {
//    return channel.map({ ($0.0.0, $0.0.1, $0.1) }).channelOf
//}
//
///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
//public func flatten<E1, E2, E3, E4>(channel: CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>)->ChannelOf<(((E1.SourceType, E2.SourceType), E3.SourceType), E4.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType)> {
//    return channel.map({ ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.1.0.0) }).channelOf
//}


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
    return mapOutput(source, { $0.nextValue }).channelOf
}

/// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
public func channelStateChanges<T where T : BaseChannelType, T.OutputType : StateEventType, T.OutputType.Element : Equatable>(source: T)->ChannelOf<T.SourceType, T.OutputType.Element> {
    return channelStateValues(filterChannel(source)({ $0.nextValue != $0.lastValue }))
}

//public func flattenChannel

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




/// Creates a state pipeline between two channels with equivalent source and output types; changes made to either side will push the transformed value to the the other side
///
/// :param: a one side of the pipeline
/// :param: b the other side of the pipeline
/// :return: a tuple of the connected outlets
public func pipe<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.OutputType, B.SourceType == A.OutputType>(var a: A, var b: B) -> Outlet {
    let asink = a.attach({ b.push($0); return })
    let bsink = b.attach({ a.push($0); return })

    let outlet = OutletOf<(A.OutputType, B.OutputType)>(receiver: { _ in }, detacher: {
        asink.detach()
        bsink.detach()
    })

    return outlet
}



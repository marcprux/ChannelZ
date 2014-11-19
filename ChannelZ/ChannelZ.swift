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
    /// The current underlying value of the channel source
    var value: Self.SourceType { get nonmutating set }
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
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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
    public typealias SelfChannel = FieldChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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

        let outlet = OutletOf<OutputType>(receiver: { (v1, v2) in }, detacher: {
            sk1.detach()
            sk2.detach()
        })
        return outlet
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = CombinedChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
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

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2>(channel: CombinedChannel<E1, E2>)->ChannelOf<(E1.SourceType, E2.SourceType), (E1.OutputType, E2.OutputType)> {
    return mapChannel(channel)({ ($0.0, $0.1) })({ ($0, $1) }).channelOf
}

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3>(channel: CombinedChannel<CombinedChannel<E1, E2>, E3>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType)> {
    return mapChannel(channel)({ ($0.0.0, $0.0.1, $0.1) })({ (($0, $1), $2) }).channelOf
}

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4>(channel: CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.1.0.0) })({ ((($0, $1), $2), $3) }).channelOf
}

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4, E5>(channel: CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>, E5>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType, E5.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType, E5.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1.0, $0.0.1.0.0, $0.1.0.0.0) })({ (((($0, $1), $2), $3), $4) }).channelOf
}

///// Flattens N nested CombinedChannels into a single channel that passes all the elements as a single tuple of N elements
public func flatten<E1, E2, E3, E4, E5, E6>(channel: CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<CombinedChannel<E1, E2>, E3>, E4>, E5>, E6>)->ChannelOf<(E1.SourceType, E2.SourceType, E3.SourceType, E4.SourceType, E5.SourceType, E6.SourceType), (E1.OutputType, E2.OutputType, E3.OutputType, E4.OutputType, E5.OutputType, E6.OutputType)> {
    return mapChannel(channel)({ ($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1.0, $0.0.0.1.0.0, $0.0.1.0.0.0, $0.1.0.0.0.0) })({ ((((($0, $1), $2), $3), $4), $5) }).channelOf
}



/// Encapsulation of a state event, where `lastValue` was the previous state and `nextValue` will be the current state
public protocol StateEventType {
    typealias Element

    var lastValue: Element { get }
    var nextValue: Element { get }
}

/// Encapsulation of a state event, where `lastValue` was the previous state and `nextValue` will be the current state
public struct StateEvent<T> : StateEventType {
    typealias Element = T

    public let lastValue: T
    public let nextValue: T
}


/// Channels a StateEventType into just the new values
public func channelStateValues<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element>(source: T)->ChannelZ<T.SourceType> {
    return ChannelZ(mapOutput(source, { $0.nextValue }))
}

/// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
public func channelStateChanges<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element, T.OutputType.Element : Equatable>(source: T)->ChannelZ<T.SourceType> {
    return channelStateValues(filterChannel(source)({ $0.nextValue != $0.lastValue }))
}

//public func flattenChannel

public func channelOptionalStateChanges<T where T : Equatable>(source: ChannelOf<Optional<T>, StateEvent<Optional<T>>>)->ChannelZ<Optional<T>> {
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




infix operator >∞> { associativity left precedence 120 }

/// Operator for Funnel.outlet
public func >∞><T: FunnelType>(var lhs: T, rhs: (T.OutputType)->Void)->Outlet {
    return lhs.attach(rhs)
}

infix operator <∞< { associativity right precedence 120 }

/// Operator for Funnel.outlet
public func <∞<<T: FunnelType>(lhs: (T.OutputType)->Void, var rhs: T)->Outlet {
    return rhs.attach(lhs)
}


/// Trailing operator for creating a field funnel
public postfix func ∞> <T>(lhs: T)->T {
    return lhs
}
postfix operator ∞> { }

// FIXME: we need to keep this operator in ChannelZ.swift instead of Operators.swift due to compiler crash “While emitting SIL for '<∞' at ChannelZ.swift:37:15”
prefix operator <∞ { }
public prefix func <∞ <T : Equatable>(rhs: T)->ChannelZ<T> {
    return sieveField(rhs)
}


/// Operator for setting Channel.value that returns the value itself
infix operator <- {}
public func <-<T : ChannelType>(var lhs: T, rhs: T.SourceType) -> T.SourceType {
    lhs.push(rhs)
    return rhs
}

/// Conduit operator with natural equivalence between two identical types
infix operator <=∞=> { }
public func <=∞=><T : ChannelType, U : ChannelType where T.OutputType == U.SourceType, T.SourceType == U.OutputType>(lhs: T, rhs: U)->Outlet {
    return pipe(lhs, rhs)
}

/// Conduit operator with checked custom transformer
infix operator <~∞~> { }
public func <~∞~><T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->Optional<U.SourceType>), rhs: (o: U, f: U.OutputType->Optional<T.SourceType>))->Outlet {
    let lhsm = lhs.o.map({ lhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })
    let rhsm = rhs.o.map({ rhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })

    return pipe(lhsm, rhsm)
}

/// Conduit operator with unchecked transformer
infix operator <|∞|> { }
public func <|∞|> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->U.SourceType), rhs: (o: U, f: U.OutputType->T.SourceType))->Outlet {
    let lhsm = lhs.o.map({ lhs.f($0) })
    let rhsm = rhs.o.map({ rhs.f($0) })

    return pipe(lhsm, rhsm)
}

/// Conduit operator with unchecked left transformer and checked right transformer
infix operator <|∞~> { }
public func <|∞~> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->U.SourceType), rhs: (o: U, f: U.OutputType->Optional<T.SourceType>))->Outlet {
    let lhsm = lhs.o.map({ lhs.f($0) as U.SourceType })
    let rhsm = unwrap(rhs.o.map({ rhs.f($0) ?? nil }).channelOf)

    return pipe(lhsm, rhsm)

}

/// Conduit operator with checked left transformer and unchecked right transformer
infix operator <~∞|> { }
public func <~∞|> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->Optional<U.SourceType>), rhs: (o: U, f: U.OutputType->T.SourceType))->Outlet {
    let lhsm = unwrap(lhs.o.map({ lhs.f($0) ?? nil }).channelOf)
    let rhsm = rhs.o.map({ rhs.f($0) })

    return pipe(lhsm, rhsm)

}


/// Conduit operator for optional type coersion
infix operator <?∞?> { }
public func <?∞?><T : ChannelType, U : ChannelType>(lhs: T, rhs: U)->Outlet {
    let lhsm = lhs.map({ $0 as U.SourceType })
    let rhsm = rhs.map({ $0 as T.SourceType })

    return pipe(lhsm, rhsm)
}

/// Conduit operator for coerced left and checked right
infix operator <?∞~> { }
public func <?∞~><T : ChannelType, U : ChannelType>(lhs: T, rhs: (o: U, f: U.OutputType->Optional<T.OutputType>))->Outlet {
    let lhsm = lhs.map({ $0 as U.SourceType })
    let rhsm = rhs.o.map({ rhs.f($0) as T.SourceType })

    return pipe(lhsm, rhsm)
}

/// Conduit operator for checked left and coerced right
infix operator <~∞?> { }
public func <~∞?><T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->Optional<U.OutputType>), rhs: U)->Outlet {
    let lhsm = lhs.o.map({ lhs.f($0) as U.SourceType })
    let rhsm = rhs.map({ $0 as T.SourceType })

    return pipe(lhsm, rhsm)
}



/// Conduit operator for equated left and checked right
infix operator <=∞~> { }
public func <=∞~><T : ChannelType, U : ChannelType where U.SourceType == T.OutputType>(lhs: T, rhs: (o: U, f: U.OutputType->Optional<T.SourceType>))->Outlet {
    let lhsm = lhs.map({ $0 })
    let rhsm = unwrap(rhs.o.map({ rhs.f($0) ?? nil }).channelOf)

    return pipe(lhsm, rhsm)

}

/// Conduit operator for checked left and equated right
infix operator <~∞=> { }
public func <~∞=><T : ChannelType, U : ChannelType where T.SourceType == U.OutputType>(lhs: (o: T, f: T.OutputType->Optional<U.SourceType>), rhs: U)->Outlet {
    let lhsm = unwrap(lhs.o.map({ lhs.f($0) ?? nil }).channelOf)
    let rhsm = rhs.map({ $0 })

    return pipe(lhsm, rhsm)

}


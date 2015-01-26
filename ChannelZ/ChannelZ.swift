//
//  Channels.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// A Channel is a funnel that has direct access to the underlying source value
public protocol BaseChannelType : BaseFunnelType {
    /// The type of element produced by the source of the Funnel
    typealias SourceType

    /// The underlying value of the channel's source
    var value: Self.SourceType { get nonmutating set } // nonmutating because we are always rooted in a reference type

    /// Returns a type-erasing channel wrapper around the current channel
    func channel() -> ChannelOf<SourceType, OutputType>
}

/// A channel with support for filtering, mapping, etc.
public protocol ExtendedChannelType : BaseChannelType {

    /// NOTE: the following methods need to be a separate protocol or else client code cannot reify the types (possibly because FilteredChannel itself implements ChannelType, and so is regarded as a circular protocol declaration)

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    func filter(predicate: (Self.OutputType)->Bool)->FilteredChannel<Self>

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<Self, TransformedType>
}

/// A channel combines basic channel functionality (attach/push/pull) with extended functionality
public protocol ChannelType : BaseChannelType, ExtendedChannelType { }


/// A type-erased channel with potentially different source and output types
///
/// Forwards operations to an arbitrary underlying channel with the same 
/// `SourceType` and `OutputType` types, hiding the specifics of the underlying channel type(s).
///
/// See also: `ChannelZ<T>`.
public struct ChannelOf<SourceType, OutputType> : ChannelType {
    private let attacher: (outlet: (OutputType) -> (Void)) -> Outlet
    private let setter: (SourceType) -> ()
    private let getter: () -> (SourceType)

    public var value : SourceType {
        get { return getter() }
        nonmutating set(newValue) { setter(newValue) }
    }

    init<G : BaseChannelType where SourceType == G.SourceType, OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
        self.setter = { base.value = $0 }
        self.getter = { base.value }
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = ChannelOf

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public func channel() -> ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
}

/// A type-erased channel with identical source and output types.
///
/// Forwards operations to an arbitrary underlying channel with the same,
/// hiding the specifics of the underlying channel type(s).
///
/// See also: `ChannelOf<SourceType, OutputType>`.
public struct ChannelZ<T> : ChannelType {
    typealias SourceType = T
    typealias OutputType = T

    private let attacher: (outlet: (T) -> (Void)) -> Outlet
    private let setter: (T) -> ()
    private let getter: () -> (T)

    public var value : T {
        get { return getter() }
        nonmutating set(newValue) { setter(newValue) }
    }

    init<G : BaseChannelType where SourceType == G.SourceType, OutputType == G.OutputType>(_ base: G) {
        self.attacher = { base.attach($0) }
        self.setter = { base.value = $0 }
        self.getter = { base.value }
    }

    public func attach(outlet: (OutputType) -> Void) -> Outlet {
        return attacher(outlet)
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = ChannelZ

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public func channel() -> ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
}

/// A Channel around a field, which can be accessed using the value property
public final class FieldChannel<T> : ChannelType {
    // Note: this is a reference type since the field itself is the shared mutable state and Swift doesn't have any KVO equivalent

    public typealias SourceType = T
    public typealias OutputType = StateEvent<T>

    private var outlets = OutletList<OutputType>()

    /// The underlying value of the channel source
    private var sourceValue : SourceType

    public var value : SourceType {
        get { return sourceValue }
        set(newValue) {
            if outlets.entrancy == 0 {
                let oldValue = sourceValue
                sourceValue = newValue
                outlets.receive(StateEvent.change(oldValue, value: newValue))
            }
        }
    }

    public init(source v: T) {
        sourceValue = v
    }

    public func attach(outlet: (OutputType)->())->Outlet {
        return outlets.addOutlet(outlet, primer: { [weak self] in
            if let this = self {
                outlet(StateEvent.push(this.value))
            }
        })
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = FieldChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public func channel() -> ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
}

/// Creates an embedded Funnel field source
public func channelField<T>(source: T)->ChannelZ<T> {
    return ChannelZ(FieldChannel(source: source).map({ $0.value }))
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: T)->ChannelZ<T> {
    return channelStateValues(filterChannel(FieldChannel(source: source))({ event in
        switch event.op {
        case .Push: return true
        case .Change(let lastValue): return event.value != lastValue
        }
    }))
}

/// Filter that only passes through state mutations of the underlying equatable element
public func sieveField<T : Equatable>(source: Optional<T>)->ChannelZ<Optional<T>> {
    let optchan: ChannelOf<Optional<T>, StateEvent<Optional<T>>> = FieldChannel(source: source).channel()
    return channelOptionalStateChanges(optchan)
}


/// A filtered channel that flows only those values that pass the filter predicate
public struct FilteredChannel<Source : BaseChannelType> : ChannelType {
    public typealias OutputType = Source.OutputType
    public typealias SourceType = Source.SourceType

    private var source: Source
    private let predicate: (Source.OutputType)->Bool

    public var value : SourceType {
        get { return source.value }
        nonmutating set(newValue) { source.value = newValue }
    }

    public init(source: Source, predicate: (Source.OutputType)->Bool) {
        self.source = source
        self.predicate = predicate
    }

    public func attach(outlet: (Source.OutputType)->Void)->Outlet {
        return source.attach({ if self.predicate($0) { outlet($0) } })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = FilteredChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public func channel() -> ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
}


/// Internal FilteredChannel curried creation
internal func filterChannel<T : BaseChannelType>(source: T)(predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return FilteredChannel(source: source, predicate: predicate)
}

/// Creates a filter around the channel `source` that only passes elements that satisfy the `predicate` function
public func filter<T : BaseChannelType>(source: T, predicate: (T.OutputType)->Bool)->FilteredChannel<T> {
    return filterChannel(source)(predicate)
}

/// Creates a filter wrapper around the `source` channel that skips the first `count` elements
public func skip<T : BaseChannelType>(source: T, count: UInt = 1)->FilteredChannel<T> {
    var num = Int(count)
    return filterChannel(source)({ _ in num-- > 0 })
}


/// A mapped channel passes all values through a transformer function before sending them to its attached outlets
public struct MappedChannel<Source : BaseChannelType, TransformedType> : ChannelType {
    public typealias OutputType = TransformedType
    public typealias SourceType = Source.SourceType

    private var source: Source
    private let outputTransform: (Source.OutputType)->TransformedType

    public var value : SourceType {
        get { return source.value }
        nonmutating set(newValue) { source.value = newValue }
    }

    public init(source: Source, outputTransform: (Source.OutputType)->TransformedType) {
        self.source = source
        self.outputTransform = outputTransform
    }

    public func attach(outlet: (TransformedType)->Void)->Outlet {
        return source.attach({ outlet(self.outputTransform($0)) })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = MappedChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public func funnel() -> FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public func channel() -> ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
}

/// Internal MappedChannel curried creation
internal func mapChannel<Source : BaseChannelType, TransformedType>(source: Source)(outputTransform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType> {
    return MappedChannel(source: source, outputTransform: outputTransform)
}

internal func mapOutput<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType> {
    return mapChannel(source)(transform)
}

/// Creates a map around the funnel `source` that passes through elements after applying the `transform` function
public func map<Source : BaseChannelType, TransformedType>(source: Source, transform: (Source.OutputType)->TransformedType)->MappedChannel<Source, TransformedType> {
    return mapOutput(source, transform)
}


/// Encapsulation of a state event, where `op` is a state operation and `value` is the current state
public protocol StateEventType {
    typealias Element

    /// The previous value for the state
    var op: StateOperation<Element> { get }

    /// The new value for the state
    var value: Element { get }
}


/// Encapsulation of a state event, where `op` is a state operation and `value` is the current state
public struct StateEvent<T> : StateEventType {
    typealias Element = T

    /// The previous value for the state
    public let op: StateOperation<T>

    /// The new value for the state
    public let value: T

    public static func change(from: T, value: T) -> StateEvent<T> {
        return StateEvent(op: .Change(from), value: value)
    }

    public static func push(value: T) -> StateEvent<T> {
        return StateEvent(op: .Push, value: value)
    }
}

/// An operation on state
public enum StateOperation<T> {
    /// A raw state value, such as when the previous state is unknown or uninitialized
    case Push

    /// A state change with the new value
    case Change(T)
}


/// Channels a StateEventType into just the new values
internal func channelStateValues<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element>(source: T)->ChannelZ<T.SourceType> {
    return ChannelZ(mapOutput(source, { $0.value }))
}


/// Channels a StateEventType whose elements are Equatable and passes through only the new values of elements that have changed
internal func channelStateChanges<T where T : BaseChannelType, T.OutputType : StateEventType, T.SourceType == T.OutputType.Element, T.OutputType.Element : Equatable>(source: T)->ChannelZ<T.SourceType> {
    return channelStateValues(filterChannel(source)({ event in
        switch event.op {
        case .Push: return true
        case .Change(let lastValue): return event.value != lastValue
        }
    }))
}

internal func channelOptionalStateChanges<T where T : Equatable>(source: ChannelOf<Optional<T>, StateEvent<Optional<T>>>)->ChannelZ<Optional<T>> {
    let filterChanges = source.filter({ (event: StateEvent<Optional<T>>) -> Bool in
        switch event.op {
        case .Push: return true
        case .Change(let lastValue): return event.value != lastValue
        }
    })

    return channelStateValues(filterChanges)
}


/// Creates a state pipeline between multiple channels with equivalent source and output types; changes made to either side will push the transformed value to the the other side.
///
/// Note that the SourceType of either side must be identical to the OutputType of the other side, which is usually accomplished by adding maps and combinations to the pipelines until they achieve parity.
///
/// :param: source one side of the pipeline
/// :param: prime whether to prime the targets with source's value
/// :param: targets the other side of the pipeline
/// :returns: a detachable outlet for the conduit
public func conduit<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.OutputType, B.SourceType == A.OutputType>(source: A, prime: Bool = false)(targets: [B]) -> OutletOf<(A.OutputType, B.OutputType)> {
    var outlets = [Outlet]()

    outlets += [source.attach({ for target in targets { target.value = $0 } })]

    if prime { // tell the source to prime their initial value to the targets
        outlets.map { $0.prime() }
    }

    for target in targets {
        outlets += [target.attach({ source.value = $0 })]
    }

    let outlet = OutletOf<(A.OutputType, B.OutputType)>(primer: { for outlet in outlets { outlet.prime() } }, detacher: { for outlet in outlets { outlet.detach() } })

    return outlet
}

public func conduit<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.OutputType, B.SourceType == A.OutputType>(source: A, targets: B...) -> Outlet {
    return conduit(source)(targets: targets)
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
    lhs.value = rhs
    return rhs
}


/// Conduit creation operators
infix operator <=∞=> { }
infix operator <=∞=-> { }
infix operator ∞=> { }
infix operator ∞=-> { }
infix operator <=∞ { }
infix operator <-=∞ { }


/// Bi-directional conduit operator with natural equivalence between two identical types
public func <=∞=><L : ChannelType, R : ChannelType where L.OutputType == R.SourceType, L.SourceType == R.OutputType>(lhs: L, rhs: R)->Outlet {
    return conduit(lhs, rhs)
}

/// Bi-directional conduit operator with natural equivalence between two identical types
public func <=∞=><L : ChannelType, R : ChannelType where L.OutputType == R.SourceType, L.SourceType == R.OutputType>(lhs: L, rhs: [R])->Outlet {
    return conduit(lhs)(targets: rhs)
}

/// One-sided conduit operator with natural equivalence between two identical types
public func ∞=><L : BaseFunnelType, R : ChannelType where L.OutputType == R.SourceType>(lhs: L, rhs: R)->Outlet {
    let lsink = lhs.attach { rhs.value = $0 }
    return OutletOf<(L.OutputType, R.OutputType)>(primer: { lsink.prime() }, detacher: { lsink.detach() })
}

/// One-sided conduit operator with natural equivalence between two identical types with priming
public func ∞=-><L : BaseFunnelType, R : ChannelType where L.OutputType == R.SourceType>(lhs: L, rhs: R)->Outlet {
    return prime(lhs ∞=> rhs)
}

// this source compiles, but any source that references it crashes the compiler
/// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
//public func ∞~-><T, L : BaseFunnelType, R : ChannelType where L.OutputType == T, R.SourceType == Optional<T>>(lhs: L, rhs: R)->Outlet {
//    let lsink = lhs.attach { rhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(primer: { lsink.prime() }, detacher: { lsink.detach() })
//}

// limited workaround for the above compiler crash by constraining the RHS to the ChannelZ and ChannelOf implementations

/// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
public func ∞=><T, L : BaseFunnelType where L.OutputType == T>(lhs: L, rhs: ChannelZ<Optional<T>>)->Outlet {
    let lsink = lhs.attach { rhs.value = $0 }
    return OutletOf<T>(primer: { lsink.prime() }, detacher: { lsink.detach() })
}

/// One-sided conduit operator with natural equivalence between two types where the receiver is the optional of the sender
public func ∞=><T, U, L : BaseFunnelType where L.OutputType == T>(lhs: L, rhs: ChannelOf<Optional<T>, U>)->Outlet {
    let lsink = lhs.attach { rhs.value = $0 }
    return OutletOf<T>(primer: { lsink.prime() }, detacher: { lsink.detach() })
}

/// Bi-directional conduit operator with natural equivalence between two identical types where the left side is primed
public func <=∞=-><L : ChannelType, R : ChannelType where L.OutputType == R.SourceType, L.SourceType == R.OutputType>(lhs: L, rhs: R)->Outlet {
    return conduit(lhs, prime: true)(targets: [rhs])
}

/// Bi-directional conduit operator with natural equivalence between two identical types where the left side is primed
public func <=∞=-><L : ChannelType, R : ChannelType where L.OutputType == R.SourceType, L.SourceType == R.OutputType>(lhs: L, rhs: [R])->Outlet {
    return conduit(lhs, prime: true)(targets: rhs)
}

/// Conduit conversion operators
infix operator <~∞~> { }
infix operator ∞~> { }
infix operator ∞~-> { }
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


///// Convert (possibly lossily) between two numeric types
//public func ∞~> <L : ChannelType, R : ChannelType where L.OutputType: ConduitNumericCoercible, R.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Outlet {
//    let lsink = lhs.map({ convertNumericType($0) }).attach { rhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(detacher: { lsink.detach() })
//}
//
///// Convert (possibly lossily) between two numeric types
//public func <~∞ <L : ChannelType, R : ChannelType where R.OutputType: ConduitNumericCoercible, L.SourceType: ConduitNumericCoercible>(lhs: L, rhs: R)->Outlet {
//    let rsink = rhs.map({ convertNumericType($0) }).attach { lhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(detacher: { rsink.detach() })
//}



///// Conduit conversion operators
//infix operator <?∞?> { }
//infix operator ∞?> { }
//infix operator <?∞ { }
//
///// Conduit operator to convert (possibly lossily) between optionally castable types
//public func <?∞?><L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
//    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { rhs.value = $0 }
//    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { lhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(primer: {
//        rsink.prime()
//        lsink.prime()
//    }, detacher: {
//        rsink.detach()
//        lsink.detach()
//    })
//}
//
//
///// Conduit operator to convert (possibly lossily) between optionally castable types
//public func ∞?> <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
//    let lsink = lhs.map({ $0 as? R.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { rhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(primer: { lsink.prime() }, detacher: { lsink.detach() })
//}
//
///// Conduit operator to convert (possibly lossily) between optionally castable types
//public func <?∞ <L : ChannelType, R : ChannelType>(lhs: L, rhs: R)->Outlet {
//    let rsink = rhs.map({ $0 as? L.SourceType }).filter({ $0 != nil }).map({ $0! }).attach { lhs.value = $0 }
//    return OutletOf<(L.OutputType, R.OutputType)>(primer: { rsink.prime() }, detacher: { rsink.detach() })
//}

//
//  State.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 3/29/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

/// A `ValuableType` simply encapsulates a value
public protocol ValuableType {
    associatedtype Element
    var $: Element { get }
}

/// A StatePulseType is an encapsulation of state over time, such that a pulse has
/// an `old` value (optionally none for the initial state pulse) and a `new` value,
/// which is the current value of the state at the time of emission.
///
/// Note that the issuance of a StatePulse does not imply that the state has changed,
/// since there is no equatability requirement for the underlying type.
///
/// - See Also: `Channel.sieve`
public protocol StatePulseType : ValuableType {
    associatedtype Element
    /// The previous value of the state; can be `nil` when it is the initial pulse to be emitted
    var old: Element? { get }
    /// The new value of the state
    var new: Element { get }
}

public extension StatePulseType {
    public var $: Element { return new }
}

/// A StatePulse encapsulates a state change from an old value to a new value
public struct StatePulse<Element> : StatePulseType {
    /// The previous value of the state; can be `nil` when it is the initial pulse to be emitted
    public let old: Element?
    /// The new value of the state
    public let new: Element

    public init(old: Element?, new: Element) {
        self.old = old
        self.new = new
    }
}

/// Abstraction of a source that can create a channel that emits a tuple of old & new state values,
/// and provides readable access to the "current" underlying state.
public protocol StateEmitterType : ValuableType, RawRepresentable {

    /// Creates a Channel from this source that will emit tuples of the old & and state values whenever a state operation occurs
    @warn_unused_result func transceive() -> Channel<Self, StatePulse<Element>>
}

public extension StateEmitterType {
    /// The default RawRepresentable implentation does not permit construction;
    /// concrete implementations may choose to permit initialization
    ///
    /// - See Also: `ValueTransceiver`
    public init?(rawValue: Element) {
        return nil
    }

    public var rawValue: Element { return $ }
}

/// Simple protocol that permits accessing the value of the underlying source type as
/// well as updating it via the `ReceiverType`'s `receive` function.
/// The implementation (or the implementation's underlying source) is assumed to be a reference
/// since changing the value is nonmutating.
public protocol StateReceiverType : ReceiverType {
    // ideally we would have value be set-only, and read/write state would be marked by combining
    // StateEmitterType and StateReceiverType; however, we aren't allowed to declare a protocol has having
    // a set-only property
    //var $: Pulse { set }
}

/// A transceiver is a type that can transmit & receive some `StatePulse` pulses via respective
/// adoption of the `StateEmitterType` and `StateReveiver` protocols.
public protocol TransceiverType : StateEmitterType, StateReceiverType {
    /// The underlying state value of this source; so named because it is an
    /// anonymous parameter, analagous to a closure's anonymous $0, $1, etc. parameters
    var $: Element { get nonmutating set }
}

/// A ValueTransceiver can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
/// The output type is a tuple of (old: T, new: T), where old is the previous value and new is the new value
public final class ValueTransceiver<T>: ReceiverQueueSource<StatePulse<T>>, TransceiverType {
    public typealias State = StatePulse<T>

    /// The underlying value for this tranceiver
    public var $: T {
        didSet(old) {
            receivers.receive(StatePulse(old: old, new: $))
        }
    }

    public init(_ value: T) { self.$ = value }

    /// Initializer for RawRepresentable
    public init(rawValue: T) { self.$ = rawValue }

    public func receive(x: T) { $ = x }

    @warn_unused_result public func transceive() -> Channel<ValueTransceiver<T>, State> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.None, new: self.$))
            return self.receivers.addReceipt(rcvr)
        }
    }
}

/// A type-erased wrapper around some state source whose value changes will emit a `StatePulse`
public struct AnyTransceiver<T> : TransceiverType {
    private let valueget: Void -> T
    private let valueset: T -> Void
    private let channler: Void -> Channel<Void, StatePulse<T>>

    public var $: T {
        get { return valueget() }
        nonmutating set { receive(newValue) }
    }

    public init<S where S: TransceiverType, S.Element == T>(_ source: S) {
        valueget = { source.$ }
        valueset = { source.$ = $0 }
        channler = { source.transceive().desource() }
    }

    public init(get: Void -> T, set: T -> Void, channeler: Void -> Channel<Void, StatePulse<T>>) {
        valueget = get
        valueset = set
        channler = channeler
    }

    public func receive(x: T) {
        valueset(x)
    }

    @warn_unused_result public func transceive() -> Channel<AnyTransceiver<T>, StatePulse<T>> {
        return channler().resource({ _ in self })
    }
}

/// A WrapperType wraps something; is able to map itself through a wrapped optional.
/// This protocol is mostly an artifact of the inability for a protocol extension to be constrained
/// to a concrete generic type, so when we want to constrain a protocol to Optional types,
/// we rely on its implementation of `flatMap`.
///
/// It needs to be public in order for external protocols to conform.
///
/// - See Also: `Optional.flatMap`
public protocol _WrapperType {
    associatedtype Wrapped
    init(_ some: Wrapped)

    /// If `self == nil`, returns `nil`.  Otherwise, returns `f(self!)`.
    /// - See Also: `Optional.map`
    @warn_unused_result
    func map<U>(@noescape f: (Wrapped) throws -> U) rethrows -> U?

    /// Returns `nil` if `self` is `nil`, `f(self!)` otherwise.
    /// - See Also: `Optional.flatMap`
    @warn_unused_result
    func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U?
}

public protocol _OptionalType : _WrapperType, NilLiteralConvertible {
}

extension Optional : _OptionalType { }

extension _WrapperType {
    /// Convert this type to an optional; shorthand for `flatMap({ $0 })`
    func toOptional() -> Wrapped? {
        return self.flatMap({ $0 })
    }
}

// Cute but pointless, and introduces potential confusion by making Bool conform to NilLiteralConvertible
//extension Bool : _OptionalType {
//    public typealias Wrapped = Void
//
//    public init(_ wrapped: Wrapped) {
//        self.init(true: Void())
//    }
//
//    public init(nilLiteral: ()) {
//        self.init(false: Void())
//    }
//
//    public init(true: Void) {
//        self = true
//    }
//
//    public init(false: Void) {
//        self = false
//    }
//
//    /// If `self` is `ErrorType`, returns `nil`.  Otherwise, returns `f(self!)`.
//    /// - See Also: `Optional.map`
//    @warn_unused_result
//    public func map<U>(@noescape f: (Wrapped) throws -> U) rethrows -> U? {
//        if self == false { return nil }
//        return try f()
//    }
//
//    /// Returns `nil` if `self` is `ErrorType`, `f(self!)` otherwise.
//    /// - See Also: `Optional.flatMap`
//    @warn_unused_result
//    public func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U? {
//        if self == false { return nil }
//        return try f()
//    }
//    
//}

///// Compares two optional types by comparing their underlying unwrapped optional values
//func optionalTypeEqual<T : _WrapperType where T.Wrapped : Equatable>(lhs: T, _ rhs: T) -> Bool {
//    return lhs.toOptional() == rhs.toOptional()
//}

/// Compares two optional types by comparing their underlying unwrapped optional values
func optionalTypeNotEqual<T : _WrapperType where T.Wrapped : Equatable>(lhs: T, _ rhs: T) -> Bool {
    return lhs.toOptional() != rhs.toOptional()
}

/// Experimental: creates a channel for a type that is formed of 2 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2>(constructor: (T1, T2) -> T, values: (T1, T2)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyTransceiver(),
        channelZPropertyValue(values.1).anyTransceiver()
    )
    func update(x: Any) { channel.$ = constructor(
        source.0.$,
        source.1.$
        )
    }
    source.0.receive(update)
    source.1.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3>(constructor: (T1, T2, T3) -> T, values: (T1, T2, T3)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>, Channel<AnyTransceiver<T3>, T3>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1,
        values.2
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyTransceiver(),
        channelZPropertyValue(values.1).anyTransceiver(),
        channelZPropertyValue(values.2).anyTransceiver()
    )
    func update(x: Any) { channel.$ = constructor(
        source.0.$,
        source.1.$,
        source.2.$
        )
    }
    source.0.receive(update)
    source.1.receive(update)
    source.2.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3, T4>(constructor: (T1, T2, T3, T4) -> T, values: (T1, T2, T3, T4)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>, Channel<AnyTransceiver<T3>, T3>, Channel<AnyTransceiver<T4>, T4>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1,
        values.2,
        values.3
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyTransceiver(),
        channelZPropertyValue(values.1).anyTransceiver(),
        channelZPropertyValue(values.2).anyTransceiver(),
        channelZPropertyValue(values.3).anyTransceiver()
    )
    func update(x: Any) { channel.$ = constructor(
        source.0.$,
        source.1.$,
        source.2.$,
        source.3.$
        )
    }
    source.0.receive(update)
    source.1.receive(update)
    source.2.receive(update)
    source.3.receive(update)
    
    return channel.resource { _ in source }
}

public extension ChannelType {

    /// Adds a channel phase that retains a previous item and sends it along with 
    /// the current value as an optional tuple element.
    /// This mechanism allows for the simualation of a state Channel that emits a `StatePulse` 
    /// even when the underlying value change mechanics are unavailable.
    ///
    /// - Returns: a state Channel that emits a tuple of an earlier and the current item
    ///
    /// - Note: this phase with retain the previous *two* pulse items
    @warn_unused_result public func precedent() -> Channel<Source, StatePulse<Pulse>> {
        return affect((old: Optional<Pulse>.None, new: Optional<Pulse>.None)) { (state, element) in (old: state.new, new: element) }.map { (state, element) in StatePulse(old: state.old, new: element) }
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `StatePulse` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateful Channel that emits the the pulses that pass the predicate
    ///
    /// - Note: Since `sieve` uses `precedent`, the most recent value will be retained by
    ///   the Channel for as long as there are receivers.
    ///
    @warn_unused_result public func presieve(predicate: (previous: Pulse, current: Pulse) -> Bool) -> Channel<Source, StatePulse<Pulse>> {
        return precedent().sieve(predicate)
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `StatePulse` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateful Channel that emits the the pulses that pass the predicate
    ///
    /// - Note: Since `sieve` uses `precedent`, the most recent value will be retained by 
    ///   the Channel for as long as there are receivers.
    ///
    @warn_unused_result public func changes(predicate: (previous: Pulse, current: Pulse) -> Bool) -> Channel<Source, Pulse> {
        return presieve(predicate).new()
    }
}

public extension ChannelType {

    /// Adds an observer closure to a change in the given equatable property
    public func watch<T>(getter: Pulse -> T, eq: (T, T) -> Bool, receiver: T -> Void) -> Receipt {
        return changes({ eq(getter($0), getter($1)) }).map(getter).receive(receiver)
    }

    /// Adds an observer closure to a change in the given equatable property
    public func observe<T: Equatable>(getter: Pulse -> T, receiver: T -> Void) -> Receipt {
        return watch(getter, eq: !=, receiver: receiver)
    }

    /// Adds an observer closure to a change in the given optional equatable property
    public func observe<T: Equatable>(getter: Pulse -> Optional<T>, receiver: Optional<T> -> Void) -> Receipt {
        return watch(getter, eq: !=, receiver: receiver)
    }
}

public extension StreamType where Pulse : StatePulseType {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func sieve(changed: (Pulse.Element, Pulse.Element) -> Bool) -> Self {
        return filter { state in
            // the initial state assignment is always fresh
            guard let old = state.old else { return true }
            return changed(state.new, old)
        }
    }
}

public extension ChannelType where Pulse : StatePulseType {
    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item. This is an optimization of `Channel.presieve` that uses the underlying
    /// `StatePulseType` rather than retaining the previous elements.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `StatePulse` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateless Channel that emits the the pulses that pass the predicate
    @warn_unused_result public func stateFilter(predicate: (previous: Pulse.Element, current: Pulse.Element) -> Bool) -> Self {
        return sieve(predicate)
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item. This is an optimization of `Channel.presieve` that uses the underlying
    /// `StatePulseType` rather than retaining the previous elements.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `StatePulse` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateless Channel that emits the the pulses that pass the predicate
    @warn_unused_result public func changes(predicate: (previous: Pulse.Element, current: Pulse.Element) -> Bool) -> Channel<Source, Pulse.Element> {
        return stateFilter(predicate).new()
    }

}

public extension StreamType where Pulse : StatePulseType, Pulse.Element : Equatable {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func sieve() -> Self {
        return sieve(!=)
    }
}

public extension ChannelType where Pulse : StatePulseType, Pulse.Element : Equatable {
    /// Adds a channel phase that emits pulses only when the equatable pulses are not equal.
    ///
    /// - See Also: `changes(predicate:)`
    @warn_unused_result public func changes() -> Channel<Source, Pulse.Element> {
        return sieve().new()
    }
}

public extension StateEmitterType where Element : Equatable {
    /// Creates a a channel to all changed values for equatable elements
    @warn_unused_result func transceiveChanges() -> Channel<Self, Element> {
        return transceive().changes()
    }
}

public extension StreamType where Pulse : StatePulseType, Pulse.Element : _WrapperType, Pulse.Element.Wrapped : Equatable {
    /// Filters the channel for only changed optional instances of the underlying `StatePulse`
    @warn_unused_result public func sieve() -> Self {
        return sieve(optionalTypeNotEqual)
    }
}

public extension ChannelType where Pulse : StatePulseType, Pulse.Element : _WrapperType, Pulse.Element.Wrapped : Equatable {
    /// Adds a channel phase that emits pulses only when the optional equatable pulses are not equal.
    ///
    /// - See Also: `changes(predicate:)`
    @warn_unused_result public func changes() -> Channel<Source, Pulse.Element> {
        return sieve().new()
    }
}

public extension StateEmitterType where Element : _WrapperType, Element.Wrapped : Equatable {
    /// Creates a a channel to all changed values for optional equatable elements
    @warn_unused_result func transceiveChanges() -> Channel<Self, Element> {
        return transceive().changes()
    }
}

public extension ChannelType where Pulse : ValuableType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func value() -> Channel<Source, Pulse.Element> {
        return map({ $0.$ })
    }
}

public extension ChannelType where Pulse : StatePulseType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func new() -> Channel<Source, Pulse.Element> {
        return value() // the value of a StatePulseType is the new() field
    }

    /// Maps to the `old` value of the `StatePulse` element
    @warn_unused_result public func old() -> Channel<Source, Pulse.Element?> {
        return map({ $0.old })
    }

}

public extension ChannelType where Pulse : _WrapperType {
    /// Adds phases that filter for `Optional.Some` pulses (i.e., drops `nil`s) and maps to their `flatMap`ped (i.e., unwrapped) values
    @warn_unused_result public func some() -> Channel<Source, Pulse.Wrapped> {
        return map({ opt in opt.toOptional() }).filter({ $0 != nil }).map({ $0! })
    }
}

@noreturn func makeT<T>() -> T { fatalError() }

//public extension ChannelType where Source : StateEmitterType {
//      FIXME: creates an ambiguity with the Source : TransceiverType variant
//    /// A Channel whose source is a `StateEmitterType` can get its value directly
//    public var $ : Source.Element {
//        get { return source.$ }
//    }
//}

public extension ChannelType where Source : TransceiverType {
    /// A Channel whose source is a `TransceiverType` can get and set its value directly without mutating the channel
    public var $ : Source.Element {
        get { return source.$ }
        nonmutating set { source.$ = newValue }
    }

    /// Re-maps a state channel by transforming the source with the given get/set mapping functions
    @warn_unused_result public func stateMap<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyTransceiver<X>, Pulse> {
        return resource { source in AnyTransceiver(get: { get(source.$) }, set: { source.$ = set($0) }, channeler: { source.transceive().desource().map { state in StatePulse(old: state.old.flatMap(get), new: get(state.new)) } }) }
    }
}

public extension ChannelType where Source : TransceiverType {
    /// Creates a type-erased `StateEmitterType` with `AnyTransceiver` for this channel
    @warn_unused_result public func anyTransceiver() -> Channel<AnyTransceiver<Source.Element>, Pulse> {
        return resource(AnyTransceiver.init)
    }

}

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse {
    /// For a channel whose underlying state matches the pulse types, perform a `stateMap` and a `map` with the same `get` transform
    @warn_unused_result public func restate<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyTransceiver<X>, X> {
        return stateMap(get: get, set: set).map(get)
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: _OptionalType, Source.Element == Pulse, Pulse.Wrapped: Hashable {
    @warn_unused_result public func restateMapping<U: Hashable, S: SequenceType where S.Generator.Element == (Pulse, U?)>(mapping: S) -> Channel<AnyTransceiver<U?>, U?> {
        var getMapping: [Pulse.Wrapped: U] = [:]
        var setMapping: [U: Pulse] = [:]

        for (key, value) in mapping {
            if let key = key.toOptional() {
                getMapping[key] = value
            }
            if let value = value {
                setMapping[value] = key
            }
        }

        let get: (Pulse -> U?) = { $0.flatMap({ getMapping[$0] }) ?? nil }
        let set: (U? -> Pulse) = { $0.flatMap({ setMapping[$0] }) ?? nil }

        return restate(get: get, set: set)
    }
}


public extension StreamType {
    /// Creates a one-way pipe between a `Channel`s whose source is a `Sink`, such that when the left
    /// side is changed the right side is updated
    public func conduct<C2 : ChannelType, S : ReceiverType where S.Pulse == Self.Pulse, C2.Source == S>(to: C2) -> Receipt {
        return self.receive(to.source)
    }

}


public extension ChannelType where Source : ReceiverType {
    /// Creates a two-way conduit between two `Channel`s whose source is a `Sink`, such that when either side is
    /// changed, the other side is updated
    ///
    /// - Note: the `to` channel will immediately receive a sync from the `self` channel, making `self` channel's state dominant
    public func conduit<C2: ChannelType where C2.Source : ReceiverType, C2.Source.Pulse == Self.Pulse, C2.Pulse == Self.Source.Pulse>(to: C2) -> Receipt {
        // since self is the dominant channel, ignore any immediate pulses through the right channel
        let rhs = to.subsequent().receive(self.source)
        let lhs = self.receive(to.source)
        return ReceiptOf(receipts: [lhs, rhs])
    }

}

public extension ChannelType where Source : TransceiverType {
    /// Creates a two-way conduit between two `Channel`s whose source is a `TransceiverType`,
    /// such that when either side is changed the other side is updated provided the filter is satisifed
    public func conjoin<C2: ChannelType where C2.Pulse == Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2, filterLeft: (Self.Pulse, C2.Source.Element) -> Bool, filterRight: (Self.Source.Element, Self.Source.Element) -> Bool) -> Receipt {
        let filtered1 = self.filter({ filterLeft($0, to.source.$) })
        let filtered2 = to.filter({ filterRight($0, self.source.$) })

        // return filtered1.conduit(filtered2) // FIXME: types don't line up for some reason
        return filtered1.anyTransceiver().conduit(filtered2.anyTransceiver()) // need to erase state to get them to line up
    }

}

// MARK: Binding variants with pulse output

public extension ChannelType where Source : TransceiverType, Source.Element : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    public func bindPulseToPulse<C2: ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    ///
    /// See Also: `bindPulseToPulse`
    public func bind<C2: ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return bindPulseToPulse(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element : Equatable, Pulse : _WrapperType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func bindPulseToOptionalPulse<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeNotEqual, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindPulseToOptionalPulse`
    public func bind<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return bindPulseToOptionalPulse(to)
    }

}

public extension ChannelType where Source : TransceiverType, Source.Element : _WrapperType, Source.Element.Wrapped : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func bindOptionalPulseToPulse<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindOptionalPulseToPulse`
    public func bind<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return bindOptionalPulseToPulse(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element : _WrapperType, Source.Element.Wrapped : Equatable, Pulse : _WrapperType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func bindOptionalPulseToOptionalPulse<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeNotEqual, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindOptionalPulseToOptionalPulse`
    public func bind<C2 : ChannelType where C2.Pulse == Self.Source.Element, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse>(to: C2) -> Receipt {
        return bindOptionalPulseToOptionalPulse(to)
    }
}


// MARK: Binding variants with StatePulse output

public extension ChannelType where Source : TransceiverType, Source.Element : Equatable, Pulse : StatePulseType, Pulse.Element : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    public func linkStateToState<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return self.changes(!=).conjoin(to.changes(!=), filterLeft: !=, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    ///
    /// See Also: `linkStateToState`
    public func link<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return linkStateToState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element : Equatable, Pulse : StatePulseType, Pulse.Element : _WrapperType, Pulse.Element.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func linkStateToOptionalState<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return self.changes().conjoin(to.changes(!=), filterLeft: optionalTypeNotEqual, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `linkStateToOptionalState`
    public func link<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return linkStateToOptionalState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element : _WrapperType, Source.Element.Wrapped : Equatable, Pulse : StatePulseType, Pulse.Element : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func linkOptionalStateToState<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return self.changes(!=).conjoin(to.changes(), filterLeft: !=, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    /// 
    /// See Also: `linkOptionalStateToState`
    public func link<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return linkOptionalStateToState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element : _WrapperType, Source.Element.Wrapped : Equatable, Pulse : StatePulseType, Pulse.Element : _WrapperType, Pulse.Element.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    public func linkOptionalStateToOptionalState<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return self.changes().conjoin(to.changes(), filterLeft: optionalTypeNotEqual, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `linkOptionalStateToOptionalState`
    public func link<C2 where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.Element == Self.Pulse.Element, C2.Pulse : StatePulseType, C2.Pulse.Element == Self.Source.Element>(to: C2) -> Receipt {
        return linkOptionalStateToOptionalState(to)
    }
}

// MARK: Utilities


/// Creates a state transceiver with the underlying initial value.
///
/// A state transceiver is a channel that can both receive values (thereby setting the underlying state)
/// and emit changes to the state via the `StatePulse` pulse type. State transceivers can
/// also be bound to other state transceivers using the `link` function.
///
/// - See Also: `ValueTransceiver`
/// - See Also: `link`
@warn_unused_result public func transceive<T>(initialValue: T) -> Channel<ValueTransceiver<T>, StatePulse<T>> {
    return ValueTransceiver(rawValue: initialValue).transceive()
}

/// Creates a Channel sourced by a Swift or Objective-C property
@warn_unused_result public func channelZPropertyValue<T>(initialValue: T) -> Channel<ValueTransceiver<T>, T> {
    return ∞initialValue∞
}

/// Creates a Channel sourced by a Swift or Objective-C Equatable property
@warn_unused_result public func channelZPropertyValue<T: Equatable>(initialValue: T) -> Channel<ValueTransceiver<T>, T> {
    return ∞=initialValue=∞
}

/// Creates a Channel sourced by a `AnyReceiver` that will be used to send elements to the receivers
@warn_unused_result public func channelZSink<T>(type: T.Type) -> Channel<AnyReceiver<T>, T> {
    let rcvrs = ReceiverQueue<T>()
    let sink = AnyReceiver<T>({ rcvrs.receive($0) })
    return Channel<AnyReceiver<T>, T>(source: sink) { rcvrs.addReceipt($0) }
}

extension SequenceType {
    /// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
    @warn_unused_result public func channelZSequence() -> Channel<Self, Self.Generator.Element> {
        return Channel(source: self) { rcvr in
            for item in self { rcvr(item) }
            return ReceiptOf() // cancelled receipt since it will never receive more pulses
        }
    }
}

/// Creates a Channel sourced by a `GeneratorType` that will emit all its elements to new receivers
@warn_unused_result public func channelZGenerator<S, T where S: GeneratorType, S.Element == T>(from: S) -> Channel<S, T> {
    return Channel(source: from) { rcvr in
        for item in AnyGenerator(from) { rcvr(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more pulses
    }
}

/// Creates a Channel sourced by an optional Closure that will be send all execution results to new receivers until it returns `.None`
@warn_unused_result public func channelZClosure<T>(from: () -> T?) -> Channel<() -> T?, T> {
    return Channel(source: from) { rcvr in
        while let item = from() { rcvr(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more pulses
    }
}

// MARK: Lens Support


/// A van Laarhoven Lens type
public protocol LensType {
    associatedtype A
    associatedtype B

    @warn_unused_result func set(target: A, _ value: B) -> A

    @warn_unused_result func get(target: A) -> B

}

public extension LensType {
    /// Converts this lens to an optional prism that allows lossy getting/setting of optional values
    ///
    /// - See Also: `ChannelType.prism`
    public var prism : Lens<A?, B?> {
        return Lens<A?, B?>(get: { $0.flatMap(self.get) }) { (whole, part) in
            if let whole = whole, part = part {
                return self.set(whole, part)
            } else {
                return whole
            }
        }
    }
}

/// A lens provides the ability to access and modify a sub-element of an immutable data structure.
/// Optics composition in Swift is somewhat limited due to the lack of Higher Kinded Types, but
/// they can be used to great effect with a state channel in order to provide owner access and
/// conditional creation for complex immutable state structures.
///
/// See Also: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#higher-kinded-types
public struct Lens<A, B> : LensType {
    private let getter: A -> B
    private let setter: (A, B) -> A

    public init(get: A -> B, create: (A, B) -> A) {
        self.getter = get
        self.setter = create
    }

    public init(_ get: A -> B, _ set: (inout A, B) -> ()) {
        self.getter = get
        self.setter = { var copy = $0; set(&copy, $1); return copy }
    }

    @warn_unused_result public func set(target: A, _ value: B) -> A {
        return setter(target, value)
    }

    @warn_unused_result public func get(target: A) -> B {
        return getter(target)
    }
}

public protocol LensSourceType : TransceiverType {
    associatedtype Owner : ChannelType

    /// All lens channels have an owner that is itself a TransceiverType
    var channel: Owner { get }
}

/// A Lens on a state channel, which can be used create a property channel on a specific
/// piece of the source state; a LensSource itself does not manage any receivers, but instead
/// relies on the source of the underlying channel.
/// 
/// The associated lens is used both for getting/setting the source state directly as well
/// as modifying the old/new state pulse values. A lens can be thought of as a 2-way `map` for state values.
public struct LensSource<C: ChannelType, T where C.Source : TransceiverType, C.Pulse : StatePulseType, C.Pulse.Element == C.Source.Element>: LensSourceType {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Element, T>

    public func receive(x: T) {
        self.$ = x
    }

    public var $: T {
        get { return lens.get(channel.$) }
        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
    }

    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
    /// of a subset of a product type.
    @warn_unused_result public func transceive() -> Channel<LensSource, StatePulse<T>> {
        return channel.map({ pulse in
            StatePulse(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

///// A Prism on a state channel, which can be used create a property channel on a specific
///// piece of the source state; a LensSource itself does not manage any receivers, but instead
///// relies on the source of the underlying channel.
//public struct PrismSource<C: ChannelType, T where C.Source : TransceiverType, C.Pulse : StatePulseType, C.Pulse.Element == C.Source.Element>: LensSourceType {
//    public typealias Owner = C
//    public let channel: C
//    public let lens: Lens<C.Source.Element, T>
//
//    public func receive(x: T) {
//        self.$ = x
//    }
//
//    public var $: T {
//        get { return lens.get(channel.$) }
//        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
//    }
//
//    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
//    /// of a subset of a product type.
//    @warn_unused_result public func transceive() -> Channel<PrismSource, StatePulse<T>> {
//        return channel.map({ pulse in
//            StatePulse(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
//        }).resource({ _ in self })
//    }
//}

public extension ChannelType where Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {
    /// A pure channel (whose element is the same as the source) can be lensed such that a derivative
    /// channel can modify sub-elements of a complex data structure
    @warn_unused_result public func focus<X>(lens: Lens<Source.Element, X>) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return LensSource(channel: self, lens: lens).transceive()
    }

    /// Constructs a Lens channel using a getter and an inout setter
    @warn_unused_result public func focus<X>(get: Source.Element -> X, _ set: (inout Source.Element, X) -> ()) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return focus(Lens(get, set))
    }

    /// Constructs a Lens channel using a getter and a tranformation setter
    @warn_unused_result public func focus<X>(get get: Source.Element -> X, create: (Source.Element, X) -> Source.Element) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return focus(Lens(get: get, create: create))
    }
}

public extension ChannelType where Source : LensSourceType {
    /// Simple alias for `source.channel.source`; useful for ascending a lens ownership hierarchy
    public var owner: Source.Owner { return source.channel }
}



// MARK: Jacket Channel extensions for Lens/Prism/Optional access

public extension ChannelType where Source.Element : _WrapperType, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the constructor function
    @warn_unused_result public func coalesce(template: Self -> Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, StatePulse<Source.Element.Wrapped>> {
        return focus(get: { $0.flatMap({ $0 }) ?? template(self) }, create: { (_, value) in Source.Element(value) })
    }

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the value; alias for `coalesce`
    @warn_unused_result public func coalesce(value: Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, StatePulse<Source.Element.Wrapped>> {
        return coalesce({ _ in value })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {

    /// Given two channels that can find and update values based on the specified getters & updaters, create
    /// a `Transceiver` channel that provides access to the underlying merged elements.
    @warn_unused_result public func join<T, Join: ChannelType where Join.Source : StateEmitterType, Join.Pulse : StatePulseType, Join.Pulse.Element == Join.Source.Element>(locator: Join, finder: (Self.Source.Element, Join.Source.Element) -> T, updater: ((Self.Source.Element, Join.Source.Element), T) -> (Self.Source.Element, Join.Source.Element)) -> Channel<LensSource<Self, T>, StatePulse<T>> {

        // the selection lens value is a prism over the current selecton and the current elements
        let lens = Lens<Pulse.Element, T>(get: { elements in
            finder(elements, locator.source.$)
        }) { (elements, values) in
            updater((elements, locator.source.$), values).0
        }

        let sel: Channel<LensSource<Self, T>, StatePulse<T>> = focus(lens)

        return sel.either(locator).resource({ $0.0 }).map {
            switch $0 {
            case .V1(let v): // change in elements
                return v // the raw values are already resolved by the lens
            case .V2(let i): // change in locator; need to perform another lookup
                return StatePulse(old: i.old.flatMap({ finder(self.source.$, $0) }), new: finder(self.source.$, i.new))
            }
        }
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: StatePulseType, Pulse.Element : SequenceType, Pulse.Element : Indexable {

    /// Combines this sequence state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func match<Join: ChannelType where Join.Source : StateEmitterType, Join.Source.Element : SequenceType, Join.Pulse.Element.Generator.Element == Source.Element.Index, Join.Pulse : StatePulseType, Join.Pulse.Element == Join.Source.Element>(locator: Join, setter: (Source.Element, Source.Element.Index, Source.Element.Generator.Element?) -> Source.Element, getter: (Pulse.Element, Pulse.Element.Index) -> Pulse.Element.Generator.Element?) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, StatePulse<[Self.Pulse.Element.Generator.Element]>> {

        typealias Output = [Source.Element.Generator.Element]
        typealias Query = (input: Source.Element, indices: Join.Source.Element)

        func query(query: Query) -> Output {
            var elements = Output()
            elements.reserveCapacity(query.indices.underestimateCount())
            for index in query.indices {
                if let value = getter(query.input, index) {
                    elements.append(value)
                }
            }
            // assert(elements.count == Array(query.indices).count)
            return elements
        }

        func update(query: Query, output: Output) -> Query {
            // assert(output.count == Array(query.indices).count)
            var updated = query.input
            for (index, element) in Swift.zip(query.indices, output) {
                updated = setter(updated, index, element)
            }
            return (updated, query.indices)
        }

        return join(locator, finder: query, updater: update)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: StatePulseType, Pulse.Element : CollectionType {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func find<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Pulse.Element.Generator.Element == Source.Element.Index, C.Pulse : StatePulseType, C.Pulse.Element == C.Source.Element>(locator: C, setter: (Source.Element, Source.Element.Index, Source.Element.Generator.Element?) -> Source.Element)  -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, StatePulse<[Self.Pulse.Element.Generator.Element]>> {

        return match(locator, setter: setter) { collection, index in
            if collection.indices.contains(index) {
                return collection[index]
            } else {
                return nil
            }
        }
    }
}

public extension ChannelType where Source.Element : MutableCollectionType, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    /// Array elements cannot be removed, so updated with a mismatched number of indices will be ignored.
    @warn_unused_result public func fixed<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Source.Element.Generator.Element == Source.Element.Index, C.Pulse : StatePulseType, C.Pulse.Element == C.Source.Element>(indices: C) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, StatePulse<[Self.Pulse.Element.Generator.Element]>> {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if let val = val where seq.indices.contains(idx) {
                seq[idx] = val // FIXME: what to do with missing values?
            }
            return seq
        }
    }
}

public extension ChannelType where Source.Element : KeyIndexed, Source.Element.Key : Hashable, Source.Element : CollectionType, Source.Element.Index : KeyIndexedIndexType, Source.Element.Key == Source.Element.Index.Key, Source.Element.Value == Source.Element.Index.Value, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be represented by nil in the
    /// puled collection; nulling out individual members of existant keys will have no effect.
    @warn_unused_result public func keyed<Join: ChannelType where Join.Source : StateEmitterType, Join.Source.Element : SequenceType, Join.Source.Element.Generator.Element == Source.Element.Key, Join.Pulse : StatePulseType, Join.Pulse.Element == Join.Source.Element>(indices: Join) -> Channel<LensSource<Self, [Self.Pulse.Element.Value?]>, StatePulse<[Self.Pulse.Element.Value?]>> {

        func find(dict: Pulse.Element, keys: Join.Pulse.Element) -> [Pulse.Element.Value?] {

            var values: [Pulse.Element.Value?] = []
            for key in keys {
                values.append(dict[key])
            }
            return values
        }

        func update(vk: (dict: Pulse.Element, keys: Join.Pulse.Element), values: [Pulse.Element.Value?]) -> (Pulse.Element, Join.Pulse.Element) {
            var dict = vk.dict
            for (key, value) in Swift.zip(vk.keys, values) {
                dict[key] = value
            }
            return (dict, vk.keys)
        }

        return join(indices, finder: find, updater: update)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func indexed<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Source.Element.Generator.Element == Source.Element.Index, C.Pulse : StatePulseType, C.Pulse.Element == C.Source.Element>(indices: C) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, StatePulse<[Self.Pulse.Element.Generator.Element]>> {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if seq.indices.contains(idx) {
                seq.replaceRange(idx...idx, with: [val].flatMap({ $0 }))
            }
            return seq
        }
    }


    /// Returns an accessor to the collection's static indices of elements
    @warn_unused_result public func indices(indices: [Source.Element.Index]) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, StatePulse<[Self.Pulse.Element.Generator.Element]>> {
        return indexed(transceive(indices))
    }

    /// Creates a channel to the underlying collection type where the channel creates an optional
    /// to a given index; setting to nil removes the index, and setting to a certain value
    /// sets the index
    ///
    /// - Note: When setting the value of an index outside the current indices, any
    ///         intervening gaps will be filled with the value
    @warn_unused_result public func index(index: Source.Element.Index) -> Channel<LensSource<Self, Source.Element.Generator.Element?>, StatePulse<Source.Element.Generator.Element?>> {

        let lens: Lens<Source.Element, Source.Element.Generator.Element?> = Lens(get: { target in
            target.indices.contains(index) ? target[index] : nil
            }, create: { (target, item) in
            var target = target
            if let item = item {
                while !target.indices.contains(index) {
                    // fill in the gaps
                    target.append(item)
                }
                // set the target index item
                target.replaceRange(index...index, with: [item])
            } else {
                if target.indices.contains(index) {
                    target.removeAtIndex(index)
                }
            }
            return target
        })

        return focus(lens)
    }

    /// Creates a prism lens channel, allowing access to a collection's mapped lens
    @warn_unused_result public func prism<T>(lens: Lens<Source.Element.Generator.Element, T>) -> Channel<LensSource<Self, [T]>, StatePulse<[T]>> {
        let prismLens = Lens<Source.Element, [T]>({ $0.map(lens.get) }) {
            (elements, values) in
            var vals = values.generate()
            for i in elements.startIndex..<elements.endIndex {
                if let val = vals.next() {
                    elements.replaceRange(i...i, with: [lens.set(elements[i], val)])
                }
            }
        }
        return focus(prismLens)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element, Source.Element.SubSequence.Generator.Element == Source.Element.Generator.Element {

    /// Returns an accessor to the collection's range of elements
    @warn_unused_result public func range(range: Range<Source.Element.Index>) -> Channel<LensSource<Self, Source.Element.SubSequence>, StatePulse<Source.Element.SubSequence>> {
        let rangeLens = Lens<Source.Element, Source.Element.SubSequence>({ $0[range] }) {
            (elements, values) in
            elements.replaceRange(range, with: Array(values))
        }
        return focus(rangeLens)
    }
}

/// Bogus protocol since, unlike Array -> CollectionType, Dictionary doesn't have any protocol.
/// Exists merely for the `ChannelType.at` prism.
public protocol KeyIndexed {
    associatedtype Key : Hashable
    associatedtype Value
    subscript (key: Key) -> Value? { get set }
}

extension Dictionary : KeyIndexed {
}

public protocol KeyIndexedIndexType : ForwardIndexType, Comparable {
    associatedtype Key : Hashable
    associatedtype Value

    /// This function is a side-effect of the inability to adopt a protocol and conform
    /// to same-named associatedtypes unless there is a function returning the values.
    func __this() -> DictionaryIndex<Key, Value>
}

extension DictionaryIndex : KeyIndexedIndexType {

    public func __this() -> DictionaryIndex<Key, Value> {
        return self
    }

}

public extension ChannelType where Source.Element : KeyIndexed, Source : TransceiverType, Pulse: StatePulseType, Pulse.Element == Source.Element {
    /// Creates a state channel to the given key in the underlying `KeyIndexed` dictionary
    @warn_unused_result public func at(key: Source.Element.Key) -> Channel<LensSource<Self, Source.Element.Value?>, StatePulse<Source.Element.Value?>> {

        let lens: Lens<Source.Element, Source.Element.Value?> = Lens(get: { target in
            target[key]
            }, create: { (target, item) in
            var target = target
            target[key] = item
            return target
        })

        return focus(lens)
    }
}

//
//  State.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 3/29/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

/// A `ValuableType` simply encapsulates a value
public protocol ValuableType {
    associatedtype T
    var $: T { get }
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
    associatedtype T
    /// The previous value of the state; can be `nil` when it is the initial pulse to be emitted
    var old: T? { get }
    /// The new value of the state
    var new: T { get }
}

/// A StatePulse encapsulates a state change from an old value to a new value
public struct StatePulse<T> : StatePulseType {
    /// The previous value of the state; can be `nil` when it is the initial pulse to be emitted
    public let old: T?
    /// The new value of the state
    public let new: T

    public init(old: T?, new: T) {
        self.old = old
        self.new = new
    }

    public var $: T { return new }
}

/// Abstraction of a source that can create a channel that emits a tuple of old & new state values,
/// and provides readable access to the "current" underlying state.
public protocol StateSource : RawRepresentable {
    associatedtype Element
    associatedtype Source

    /// The underlying state value of this source; so named because it is an
    /// anonymous parameter, analagous to a closure's anonymous $0, $1, etc. parameters
    var $: Element { get }

    /// Creates a Channel from this source that will emit tuples of the old & and state values whenever a state operation occurs
    @warn_unused_result func channelZState() -> Channel<Source, StatePulse<Element>>
}

public extension StateSource {
    /// The default RawRepresentable implentation does not permit construction;
    /// concrete implementations may choose to permit initialization
    ///
    /// - See Also: `PropertySource`
    public init?(rawValue: Element) {
        return nil
    }

    public var rawValue: Element { return $ }
}

/// Simple protocol that permits accessing the value of the underlying source type as
/// well as updating it via the `ReceiverType`'s `receive` function.
/// The implementation (or the implementation's underlying source) is assumed to be a reference
/// since changing the value is nonmutating.
public protocol StateReceiver : ReceiverType {
    // ideally we would have value be set-only, and read/write state would be marked by combining
    // StateSource and StateReceiver; however, we aren't allowed to declare a protocol has having
    // a set-only property
    var $: Pulse { get set }
}

/// A state container is a type that can read & write some state via respective adoption of
/// the `StateSource` and `StateReveiver` protocols.
public protocol StateContainer : StateSource, StateReceiver {
    /// The underlying state value of this source; so named because it is an
    /// anonymous parameter, analagous to a closure's anonymous $0, $1, etc. parameters
    var $: Element { get nonmutating set }
}

/// A PropertySource can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
/// The output type is a tuple of (old: T, new: T), where old is the previous value and new is the new value
public final class PropertySource<T>: StateContainer {
    public typealias State = StatePulse<T>
    private let receivers = ReceiverQueue<State>()

    public var $: T {
        didSet(old) {
            receivers.receive(StatePulse(old: old, new: $))
        }
    }

    public init(_ value: T) { self.$ = value }

    /// Initializer for RawRepresentable
    public init(rawValue: T) {
        self.$ = rawValue
    }

    public func receive(x: T) { $ = x }

    @warn_unused_result public func channelZState() -> Channel<PropertySource<T>, State> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.None, new: self.$))
            return self.receivers.addReceipt(rcvr)
        }
    }
}

/// A type-erased wrapper around some state source whose value changes will emit a `StatePulse`
public struct AnyState<T> : StateContainer {
    private let valueget: Void -> T
    private let valueset: T -> Void
    private let channler: Void -> Channel<Void, StatePulse<T>>

    public var $: T {
        get { return valueget() }
        nonmutating set { receive(newValue) }
    }

    public init<S where S: StateContainer, S.Element == T>(_ source: S) {
        valueget = { source.$ }
        valueset = { source.$ = $0 }
        channler = { source.channelZState().desource() }
    }

    public init(get: Void -> T, set: T -> Void, channeler: Void -> Channel<Void, StatePulse<T>>) {
        valueget = get
        valueset = set
        channler = channeler
    }

    public func receive(x: T) {
        valueset(x)
    }

    @warn_unused_result public func channelZState() -> Channel<AnyState<T>, StatePulse<T>> {
        return channler().resource({ _ in self })
    }
}

/// A WrapperType is able to map itself through a wrapped optional
/// This protocol is an artifact of the inability for a protocol extension to be constrained
/// to a concrete generic type, so when we want to constrain a protocol to Optional types,
/// we rely on its implementation of `flatMap`
/// It needs to be public in order for protocols to conform
public protocol _OptionalType : NilLiteralConvertible {
    associatedtype Wrapped
    init(_ some: Wrapped)
    func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U?
}

extension Optional : _OptionalType { }

extension _OptionalType {
    /// Convert this type to an optional; shorthand for `flatMap({ $0 })`
    func toOptional() -> Wrapped? {
        return self.flatMap({ $0 })
    }
}

/// Compares two optional types by comparing their underlying unwrapped optional values
func optionalTypeEqual<T : _OptionalType where T.Wrapped : Equatable>(lhs: T, _ rhs: T) -> Bool {
    return lhs.toOptional() != rhs.toOptional()
}

/// Experimental: creates a channel for a type that is formed of 2 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2>(constructor: (T1, T2) -> T, values: (T1, T2)) -> Channel<(Channel<AnyState<T1>, T1>, Channel<AnyState<T2>, T2>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyState(),
        channelZPropertyValue(values.1).anyState()
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
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3>(constructor: (T1, T2, T3) -> T, values: (T1, T2, T3)) -> Channel<(Channel<AnyState<T1>, T1>, Channel<AnyState<T2>, T2>, Channel<AnyState<T3>, T3>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1,
        values.2
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyState(),
        channelZPropertyValue(values.1).anyState(),
        channelZPropertyValue(values.2).anyState()
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
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3, T4>(constructor: (T1, T2, T3, T4) -> T, values: (T1, T2, T3, T4)) -> Channel<(Channel<AnyState<T1>, T1>, Channel<AnyState<T2>, T2>, Channel<AnyState<T3>, T3>, Channel<AnyState<T4>, T4>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1,
        values.2,
        values.3
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyState(),
        channelZPropertyValue(values.1).anyState(),
        channelZPropertyValue(values.2).anyState(),
        channelZPropertyValue(values.3).anyState()
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
    @warn_unused_result public func sieve(changed: (Pulse.T, Pulse.T) -> Bool) -> Self {
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
    @warn_unused_result public func stateFilter(predicate: (previous: Pulse.T, current: Pulse.T) -> Bool) -> Self {
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
    @warn_unused_result public func changes(predicate: (previous: Pulse.T, current: Pulse.T) -> Bool) -> Channel<Source, Pulse.T> {
        return stateFilter(predicate).new()
    }

}

public extension StreamType where Pulse : StatePulseType, Pulse.T : Equatable {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func sieve() -> Self {
        return sieve(!=)
    }
}

public extension ChannelType where Pulse : StatePulseType, Pulse.T : Equatable {
    @warn_unused_result public func changes() -> Channel<Source, Pulse.T> {
        return sieve().new()
    }
}

public extension StateSource where Element : Equatable {
    /// Creates a a channel to all changed values for equatable elements
    @warn_unused_result func channelZStateChanges() -> Channel<Source, Element> {
        return channelZState().changes()
    }
}

public extension StreamType where Pulse : StatePulseType, Pulse.T : _OptionalType, Pulse.T.Wrapped : Equatable {
    /// Filters the channel for only changed optional instances of the underlying `StatePulse`
    @warn_unused_result public func sieve() -> Self {
        return sieve(optionalTypeEqual)
    }
}

public extension ChannelType where Pulse : StatePulseType, Pulse.T : _OptionalType, Pulse.T.Wrapped : Equatable {
    @warn_unused_result public func changes() -> Channel<Source, Pulse.T> {
        return sieve().new()
    }
}

public extension StateSource where Element : _OptionalType, Element.Wrapped : Equatable {
    /// Creates a a channel to all changed values for optional equatable elements
    @warn_unused_result func channelZStateChanges() -> Channel<Source, Element> {
        return channelZState().changes()
    }
}

public extension ChannelType where Pulse : ValuableType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func value() -> Channel<Source, Pulse.T> {
        return map({ $0.$ })
    }
}

public extension ChannelType where Pulse : StatePulseType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func new() -> Channel<Source, Pulse.T> {
        return value() // the value of a StatePulseType is the new() field
    }

    /// Maps to the `old` value of the `StatePulse` element
    @warn_unused_result public func old() -> Channel<Source, Pulse.T?> {
        return map({ $0.old })
    }

}

public extension ChannelType where Pulse : _OptionalType {
    /// Adds phases that filter for `Optional.Some` pulses (i.e., drops `nil`s) and maps to their `flatMap`ped (i.e., unwrapped) values
    @warn_unused_result public func some() -> Channel<Source, Pulse.Wrapped> {
        return map({ opt in opt.toOptional() }).filter({ $0 != nil }).map({ $0! })
    }
}

@noreturn func makeT<T>() -> T { fatalError() }

public extension ChannelType where Source : StateContainer {
    /// A Channel whose source is a `StateSource` can get and set its value directly without mutating the channel
    public var $ : Source.Element {
        get { return source.$ }
        nonmutating set { source.$ = newValue }
    }

    /// Re-maps a state channel by transforming the source with the given get/set mapping functions
    @warn_unused_result public func stateMap<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyState<X>, Pulse> {
        return resource { source in AnyState(get: { get(source.$) }, set: { source.$ = set($0) }, channeler: { source.channelZState().desource().map { state in StatePulse(old: state.old.flatMap(get), new: get(state.new)) } }) }
    }
}

public extension ChannelType where Source : StateContainer {
    /// Creates a type-erased `StateSource` with `AnyState` for this channel
    @warn_unused_result public func anyState() -> Channel<AnyState<Source.Element>, Pulse> {
        return resource(AnyState.init)
    }

}

public extension ChannelType where Source : StateContainer, Source.Element == Pulse {
    /// For a channel whose underlying state matches the pulse types, perform a `stateMap` and a `map` with the same `get` transform
    @warn_unused_result public func restate<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyState<X>, X> {
        return stateMap(get: get, set: set).map(get)
    }
}

public extension ChannelType where Source : StateContainer, Pulse: _OptionalType, Source.Element == Pulse, Pulse.Wrapped: Hashable {
    @warn_unused_result public func restateMapping<U: Hashable, S: SequenceType where S.Generator.Element == (Pulse, U?)>(mapping: S) -> Channel<AnyState<U?>, U?> {
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


public extension ChannelType {
    /// Creates a one-way pipe between a `Channel`s whose source is a `Sink`, such that when the left
    /// side is changed the right side is updated
    public func conduct<T, S : ReceiverType where S.Pulse == Self.Pulse>(to: Channel<S, T>) -> Receipt {
        return self.receive(to.source)
    }

}


public extension ChannelType where Source : ReceiverType {
    /// Creates a two-way conduit between two `Channel`s whose source is a `Sink`, such that when either side is
    /// changed, the other side is updated
    ///
    /// - Note: the `to` channel will immediately receive a sync from the `self` channel, making `self` channel's state dominant
    public func conduit<Source2 where Source2 : ReceiverType, Source2.Pulse == Self.Pulse>(to: Channel<Source2, Self.Source.Pulse>) -> Receipt {
        // since self is the dominant channel, ignore any immediate pulses through the right channel
        let rhs = to.subsequent().receive(self.source)
        let lhs = self.receive(to.source)
        return ReceiptOf(receipts: [lhs, rhs])
    }
}

public extension ChannelType where Source : StateContainer {
    /// Creates a two-way conduit between two `Channel`s whose source is a `StateContainer`,
    /// such that when either side is changed the other side is updated provided the filter is satisifed
    public func conjoin<Source2 where Source2 : StateContainer, Source2.Element == Self.Pulse>(to: Channel<Source2, Self.Source.Element>, filterLeft: (Self.Pulse, Source2.Element) -> Bool, filterRight: (Self.Source.Element, Self.Source.Element) -> Bool) -> Receipt {
        let filtered1 = self.filter({ filterLeft($0, to.source.$) })
        let filtered2 = to.filter({ filterRight($0, self.source.$) })

        // return filtered1.conduit(filtered2) // FIXME: compiler crash

        let f1: Channel<AnyState<Self.Source.Element>, Self.Pulse> = filtered1.anyState()
        let f2: Channel<AnyState<Self.Pulse>, Self.Source.Element> = filtered2.anyState()
        return f1.conduit(f2)
    }

}

public extension ChannelType where Source : StateContainer, Source.Element : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not equal
    public func bind<Source2 where Source2 : StateContainer, Source2.Element == Self.Pulse>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: !=)
    }
}

public extension ChannelType where Source : StateContainer, Source.Element : Equatable, Pulse : _OptionalType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateContainer, Source2.Element == Self.Pulse>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeEqual, filterRight: !=)
    }
}

public extension ChannelType where Source : StateContainer, Source.Element : _OptionalType, Source.Element.Wrapped : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateContainer, Source2.Element == Self.Pulse>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: optionalTypeEqual)
    }
}

public extension ChannelType where Source : StateContainer, Source.Element : _OptionalType, Source.Element.Wrapped : Equatable, Pulse : _OptionalType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateContainer, Source2.Element == Self.Pulse>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeEqual, filterRight: optionalTypeEqual)
    }
}

// MARK: Utilities

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

/// Creates a Channel sourced by a Swift or Objective-C property
@warn_unused_result public func channelZPropertyValue<T>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞initialValue∞
}

/// Creates a Channel sourced by a Swift or Objective-C Equatable property
@warn_unused_result public func channelZPropertyValue<T: Equatable>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞=initialValue=∞
}

/// Creates a `PropertySource` channel that emits a `StatePulse` with the values over time.
@warn_unused_result public func channelZPropertyState<T>(initialValue: T) -> Channel<PropertySource<T>, StatePulse<T>> {
    return PropertySource(rawValue: initialValue).channelZState()
}


// MARK: Lens Support


/// A van Laarhoven Lens type
public protocol LensType {
    associatedtype A
    associatedtype B

    @warn_unused_result func set(target: A, _ value: B) -> A

    @warn_unused_result func get(target: A) -> B

}

/// A lens provides the ability to access and modify a sub-element of an immutable data structure
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

public protocol LensSourceType : StateContainer {
    associatedtype Owner : ChannelType

    /// All lens channels have an owner that is itself a StateSource
    var channel: Owner { get }
}

/// A Lens on a state channel, which can be used create a property channel on a specific
/// piece of the source state; a LensSource itself does not manage any receivers, but instead
/// relies on the source of the underlying channel.
public struct LensSource<C: ChannelType, T where C.Source : StateContainer, C.Pulse : StatePulseType, C.Pulse.T == C.Source.Element>: LensSourceType {
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

    @warn_unused_result public func channelZState() -> Channel<LensSource, StatePulse<T>> {
        return channel.map({ pulse in
            StatePulse(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

public extension ChannelType where Source : StateContainer, Pulse: StatePulseType, Pulse.T == Source.Element {
    /// A pure channel (whose element is the same as the source) can be lensed such that a derivative
    /// channel can modify sub-elements of a complex data structure
    @warn_unused_result public func channelZLens<X>(lens: Lens<Source.Element, X>) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return LensSource(channel: self, lens: lens).channelZState()
    }

    /// Constructs a Lens channel using a getter and an inout setter
    @warn_unused_result public func channelZLens<X>(get: Source.Element -> X, _ set: (inout Source.Element, X) -> ()) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return channelZLens(Lens(get, set))
    }

    /// Constructs a Lens channel using a getter and a tranformation setter
    @warn_unused_result public func channelZLens<X>(get get: Source.Element -> X, create: (Source.Element, X) -> Source.Element) -> Channel<LensSource<Self, X>, StatePulse<X>> {
        return channelZLens(Lens(get: get, create: create))
    }
}

public extension ChannelType where Source : LensSourceType {
    /// Simple alias for `source.channel.source`; useful for ascending a lens ownership hierarchy
    public var owner: Source.Owner { return source.channel }
}



// MARK: Jacket Channel extensions for Lens/Prism/Optional access

public extension ChannelType where Source.Element : _OptionalType, Source : StateContainer, Pulse: StatePulseType, Pulse.T == Source.Element {

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the constructor function
    @warn_unused_result public func coalesce(template: Self -> Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, StatePulse<Source.Element.Wrapped>> {
        return channelZLens(get: { $0.flatMap({ $0 }) ?? template(self) }, create: { (_, value) in Source.Element(value) })
    }

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the value; alias for `coalesce`
    @warn_unused_result public func coalesce(value: Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, StatePulse<Source.Element.Wrapped>> {
        return coalesce({ _ in value })
    }
}


public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : StateContainer, Pulse: StatePulseType, Pulse.T == Source.Element {

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

        return channelZLens(lens)
    }
}

/// Bogus protocol since, unlike Array -> CollectionType, Dictionary doesn't have any protocol.
/// Exists merely for the `ChannelType.at` prism.
public protocol KeyIndexed {
    associatedtype Key
    associatedtype Value
    subscript (key: Key) -> Value? { get set }
}

extension Dictionary : KeyIndexed {
}

public extension ChannelType where Source.Element : KeyIndexed, Source : StateContainer, Pulse: StatePulseType, Pulse.T == Source.Element {
    /// Creates a state channel to the given key in the underlying `KeyIndexed` dictionary
    @warn_unused_result public func at(key: Source.Element.Key) -> Channel<LensSource<Self, Source.Element.Value?>, StatePulse<Source.Element.Value?>> {

        let lens: Lens<Source.Element, Source.Element.Value?> = Lens(get: { target in
            target[key]
            }, create: { (target, item) in
            var target = target
            target[key] = item
            return target
        })

        return channelZLens(lens)
    }
}

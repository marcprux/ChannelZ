//
//  State.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 3/29/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

import Darwin

/// A StatePulseType is an representation of a calue change event, such that a pulse has
/// an `old` value (optionally none for the first state pulse) and a `new` value
public protocol StatePulseType : EnumeratedPulseType {
    associatedtype T
    var old: T? { get }
    var new: T { get }
}

/// A StatePulse encapsulates a state change from an old value to a new value with an anonymous `AnyForwardIndex` index yype
public struct StatePulse<T> : StatePulseType {
    public let old: T?
    public let new: T
    public let index: AnyForwardIndex
    public var item: (T?, T) { return (old, new) }

    public init(old: T?, new: T, index: AnyForwardIndex) {
        self.old = old
        self.new = new
        self.index = index
    }
}

/// Abstraction of a source that can create a channel that emits a tuple of old & new state values.
/// The implementation (or the implementation's underlying source) is assumed to be a reference
/// since changing the value is nonmutating.
public protocol StateSource : Sink {
    associatedtype Element
    associatedtype Source

    /// The underlying state value of this source
    var value: Element { get nonmutating set }

    /// Creates a Channel from this source that will emit tuples of the old & and state values whenever a state operation occurs
    @warn_unused_result func channelZState() -> Channel<Source, StatePulse<Element>>
}

/// A PropertySource can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
/// The output type is a tuple of (old: T, new: T), where old is the previous value and new is the new value
public final class PropertySource<T>: StateSink, StateSource {
    public typealias State = StatePulse<T>
    private let receivers = ReceiverList<State>()
    private var pulseIndex: Int64 = 0

    public var value: T {
        didSet(old) {
            receivers.receive(StatePulse(old: old, new: value, index: AnyForwardIndex(OSAtomicIncrement64(&pulseIndex))))
        }
    }
    
    public init(_ value: T) { self.value = value }
    public func put(x: T) { value = x }

    @warn_unused_result public func channelZState() -> Channel<PropertySource<T>, State> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.None, new: self.value, index: AnyForwardIndex(self.pulseIndex)))
            return self.receivers.addReceipt(rcvr)
        }
    }
}

public protocol Sink {
    associatedtype Element
    func put(value: Element)
}

/// Equivalent to SinkOf
public struct SinkTo<Element> : Sink {
    public let op: Element -> Void

    public init(_ op: Element -> Void) {
        self.op = op
    }

    public func put(value: Element) {
        self.op(value)
    }
}

public extension StreamType {

    /// Adds a receiver that will forward all values to the target `Sink`
    ///
    /// - Parameter sink: the sink that will accept all the pulses from the Channel
    ///
    /// - Returns: A `Receipt` for the pipe
    public func pipe<S2: Sink where S2.Element == Element>(sink: S2) -> Receipt {
        return receive { sink.put($0) }
    }
}

/// Simple protocol that permits accessing the underlying source type
public protocol StateSink : Sink {
    var value: Element { get }
    func put(value: Element)
}

/// A type-erased wrapper around some state source whose value changes will emit a `StatePulse`
public struct AnyState<T>: Sink, StateSource {
    private let valueget: Void -> T
    private let valueset: T -> Void
    private let channler: Void -> Channel<Void, StatePulse<T>>

    public var value: T {
        get { return valueget() }
        nonmutating set { put(newValue) }
    }

    public init<S where S: StateSink, S: StateSource, S.Element == T>(_ source: S) {
        valueget = { source.value }
        valueset = { source.value = $0 }
        channler = { source.channelZState().desource() }
    }

    public init(get: Void -> T, set: T -> Void, channeler: Void -> Channel<Void, StatePulse<T>>) {
        valueget = get
        valueset = set
        channler = channeler
    }

    public func put(x: T) {
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
    let channel = channelZProperty(constructor(
        values.0,
        values.1
        )
    )
    let source = (
        channelZProperty(values.0).anyState(),
        channelZProperty(values.1).anyState()
    )
    func update(x: Any) { channel.value = constructor(
        source.0.value,
        source.1.value
        )
    }
    source.0.receive(update)
    source.1.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3>(constructor: (T1, T2, T3) -> T, values: (T1, T2, T3)) -> Channel<(Channel<AnyState<T1>, T1>, Channel<AnyState<T2>, T2>, Channel<AnyState<T3>, T3>), T> {
    let channel = channelZProperty(constructor(
        values.0,
        values.1,
        values.2
        )
    )
    let source = (
        channelZProperty(values.0).anyState(),
        channelZProperty(values.1).anyState(),
        channelZProperty(values.2).anyState()
    )
    func update(x: Any) { channel.value = constructor(
        source.0.value,
        source.1.value,
        source.2.value
        )
    }
    source.0.receive(update)
    source.1.receive(update)
    source.2.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3, T4>(constructor: (T1, T2, T3, T4) -> T, values: (T1, T2, T3, T4)) -> Channel<(Channel<AnyState<T1>, T1>, Channel<AnyState<T2>, T2>, Channel<AnyState<T3>, T3>, Channel<AnyState<T4>, T4>), T> {
    let channel = channelZProperty(constructor(
        values.0,
        values.1,
        values.2,
        values.3
        )
    )
    let source = (
        channelZProperty(values.0).anyState(),
        channelZProperty(values.1).anyState(),
        channelZProperty(values.2).anyState(),
        channelZProperty(values.3).anyState()
    )
    func update(x: Any) { channel.value = constructor(
        source.0.value,
        source.1.value,
        source.2.value,
        source.3.value
        )
    }
    source.0.receive(update)
    source.1.receive(update)
    source.2.receive(update)
    source.3.receive(update)
    
    return channel.resource { _ in source }
}

public extension ChannelType where Element : IndexedPulseType {


    /// Adds a channel phase that retains a previous item and sends it along with 
    /// the current value as an optional tuple element.
    /// This mechanism allows for the simualation of a state Channel that emits a `StatePulse` 
    /// even when the underlying value change mechanics are unavailable.
    ///
    /// - Returns: a state Channel that emits a tuple of an earlier and the current item
    ///
    /// - Note: this phase with retain the previous *two* pulse items
    @warn_unused_result public func precedent() -> Channel<Source, StatePulse<Element>> {
        // bump the antecedent stack whenever we receive a distinct pulse
        var antecedents: (Element?, Element?) = (nil, nil)
        let remember = pulsar { antecedents = ($0, antecedents.0) }

        return lift { receive in
            { item in
                remember(item)
                let pair = StatePulse(old: antecedents.1, new: item, index: AnyForwardIndex(item.index))
                receive(pair)
            }
        }
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `sieve(!=)`
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateful Channel that emits the the pulses that pass the predicate
    ///
    /// - Note: Since `sieve` uses `precedent`, the most recent value will be retained by 
    ///   the Channel for as long as there are receivers.
    ///
    @warn_unused_result public func sieve(predicate: (previous: Element, current: Element) -> Bool) -> Channel<Source, Element> {
        func changed(t: StatePulse<Element>) -> Bool {
            return t.old == nil || predicate(previous: t.old!, current: t.new)
        }
        return precedent().filter(changed).new()
    }
}

public extension ChannelType where Element : IndexedPulseType {

    /// Adds an observer closure to a change in the given equatable property
    public func watch<T>(getter: Element -> T, eq: (T, T) -> Bool, receiver: T -> Void) -> Receipt {
        return sieve({ eq(getter($0), getter($1)) }).map(getter).receive(receiver)
    }

    /// Adds an observer closure to a change in the given equatable property
    public func observe<T: Equatable>(getter: Element -> T, receiver: T -> Void) -> Receipt {
        return watch(getter, eq: !=, receiver: receiver)
    }

    /// Adds an observer closure to a change in the given optional equatable property
    public func observe<T: Equatable>(getter: Element -> Optional<T>, receiver: Optional<T> -> Void) -> Receipt {
        return watch(getter, eq: !=, receiver: receiver)
    }
}

public extension StreamType where Element : StatePulseType {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func changes(changed: (Element.T, Element.T) -> Bool) -> Self {
        return filter({ $0.old == nil || changed($0.old!, $0.new) })
    }
}

public extension StreamType where Element : StatePulseType, Element.T : Equatable {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func changes() -> Self {
        return changes(!=)
    }
}

public extension StreamType where Element : StatePulseType, Element.T : _OptionalType, Element.T.Wrapped : Equatable {
    /// Filters the channel for only changed optional instances of the underlying `StatePulse`
    @warn_unused_result public func changes() -> Self {
        return changes(optionalTypeEqual)
    }
}

public extension ChannelType where Element : StatePulseType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func new() -> Channel<Source, Element.T> {
        return map({ $0.new })
    }

    /// Maps to the `old` value of the `StatePulse` element
    @warn_unused_result public func old() -> Channel<Source, Element.T?> {
        return map({ $0.old })
    }

}

public extension ChannelType where Element : _OptionalType {
    /// Adds phases that filter for `Optional.Some` pulses (i.e., drops `nil`s) and maps to their `flatMap`ped (i.e., unwrapped) values
    @warn_unused_result public func some() -> Channel<Source, Element.Wrapped> {
        return map({ opt in opt.toOptional() }).filter({ $0 != nil }).map({ $0! })
    }
}

@noreturn func makeT<T>() -> T { fatalError() }

public extension ChannelType where Source : StateSource {
    /// A Channel whose source is a `StateSource` can get and set its value directly without mutating the channel
    public var value : Source.Element {
        get { return source.value }
        nonmutating set { source.value = newValue }
    }

    /// Re-maps a state channel by transforming the source with the given get/set mapping functions
    public func stateMap<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyState<X>, Element> {
        return resource { source in AnyState(get: { get(source.value) }, set: { source.value = set($0) }, channeler: { source.channelZState().desource().map { state in StatePulse(old: state.old.flatMap(get), new: get(state.new), index: state.index) } }) }
    }
}

public extension ChannelType where Source : StateSource, Source : StateSink {
    /// Creates a type-erased `StateSource` with `AnyState` for this channel
    public func anyState() -> Channel<AnyState<Source.Element>, Element> {
        return resource(AnyState.init)
    }

}

public extension ChannelType where Source : StateSource, Source.Element == Element {
    /// For a channel whose underlying state matches the pulse types, perform a `stateMap` and a `map` with the same `get` transform
    public func restate<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<AnyState<X>, X> {
        return stateMap(get: get, set: set).map(get)
    }
}

public extension ChannelType where Source : StateSource, Element: _OptionalType, Source.Element == Element, Element.Wrapped: Hashable {
    public func restateMapping<U: Hashable, S: SequenceType where S.Generator.Element == (Element, U?)>(mapping: S) -> Channel<AnyState<U?>, U?> {
        var getMapping: [Element.Wrapped: U] = [:]
        var setMapping: [U: Element] = [:]

        for (key, value) in mapping {
            if let key = key.toOptional() {
                getMapping[key] = value
            }
            if let value = value {
                setMapping[value] = key
            }
        }

        let get: (Element -> U?) = { $0.flatMap({ getMapping[$0] }) ?? nil }
        let set: (U? -> Element) = { $0.flatMap({ setMapping[$0] }) ?? nil }

        return restate(get: get, set: set)
    }
}


public extension ChannelType {
    /// Creates a one-way pipe betweek a `Channel`s whose source is a `Sink`, such that when the left
    /// side is changed the right side is updated
    public func conduct<T, S : Sink where S.Element == Self.Element>(to: Channel<S, T>) -> Receipt {
        return self.pipe(to.source)
    }

}

public extension ChannelType where Source : Sink {
    /// Creates a two-way conduit betweek two `Channel`s whose source is a `Sink`, such that when either side is
    /// changed, the other side is updated
    ///
    /// - Note: the `to` channel will immediately receive a sync from the `this` channel, making `this` channel's state dominant
    public func conduit<Source2 where Source2 : Sink, Source2.Element == Self.Element>(to: Channel<Source2, Source.Element>) -> Receipt {
        // since self is the dominant channel, ignore any immediate pulses through the right channel
        let rhs = to.subsequent().pipe(self.source)
        let lhs = self.pipe(to.source)
        return ReceiptOf(receipts: [lhs, rhs])
    }
}

public extension ChannelType where Source : StateSource {
    /// Creates a two-way conduit betweek two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated provided the filter is satisifed
    public func conjoin<Source2 where Source2 : StateSource, Source2.Element == Self.Element>(to: Channel<Source2, Self.Source.Element>, filterLeft: (Self.Element, Source2.Element) -> Bool, filterRight: (Self.Source.Element, Self.Source.Element) -> Bool) -> Receipt {
        let filtered1 = self.filter({ filterLeft($0, to.source.value) })
        let filtered2 = to.filter({ filterRight($0, self.source.value) })
        return filtered1.conduit(filtered2)
    }
}

public extension ChannelType where Source : StateSource, Source.Element : Equatable, Element : Equatable {
    /// Creates a two-way binding betweek two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not equal
    public func bind<Source2 where Source2 : StateSource, Source2.Element == Self.Element>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: !=)
    }
}

public extension ChannelType where Source : StateSource, Source.Element : Equatable, Element : _OptionalType, Element.Wrapped : Equatable {
    /// Creates a two-way binding betweek two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateSource, Source2.Element == Self.Element>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeEqual, filterRight: !=)
    }
}

public extension ChannelType where Source : StateSource, Source.Element : _OptionalType, Source.Element.Wrapped : Equatable, Element : Equatable {
    /// Creates a two-way binding betweek two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateSource, Source2.Element == Self.Element>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: !=, filterRight: optionalTypeEqual)
    }
}

public extension ChannelType where Source : StateSource, Source.Element : _OptionalType, Source.Element.Wrapped : Equatable, Element : _OptionalType, Element.Wrapped : Equatable {
    /// Creates a two-way binding betweek two `Channel`s whose source is a `StateSource`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal
    public func bind<Source2 where Source2 : StateSource, Source2.Element == Self.Element>(to: Channel<Source2, Self.Source.Element>) -> Receipt {
        return conjoin(to, filterLeft: optionalTypeEqual, filterRight: optionalTypeEqual)
    }
}

// MARK: Utilities

/// Creates a Channel sourced by a `SinkTo` that will be used to send elements to the receivers
@warn_unused_result public func channelZSink<T>(type: T.Type) -> Channel<SinkTo<T>, T> {
    let rcvrs = ReceiverList<T>()
    let sink = SinkTo<T>({ rcvrs.receive($0) })
    return Channel<SinkTo<T>, T>(source: sink) { rcvrs.addReceipt($0) }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
@warn_unused_result public func channelZEnumerate<S, T where S: SequenceType, S.Generator.Element == T>(from: S) -> Channel<S, EnumeratedPulse<T>> {
    return from.channelZEnumerate()
}

public extension ChannelType where Element : EnumeratedPulseType {
    /// Unwraps the underlying item from an enumerated pulse
    @warn_unused_result func items() -> Channel<Source, Element.Element> {
        return map({ $0.item })
    }
}

extension SequenceType {
    /// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
    @warn_unused_result func channelZEnumerate() -> Channel<Self, EnumeratedPulse<Self.Generator.Element>> {
        return Channel(source: self) { rcvr in
            for (i, item) in self.enumerate() { rcvr(EnumeratedPulse(index: i, item: item)) }
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
@warn_unused_result public func channelZProperty<T>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞initialValue∞
}

/// Creates a Channel sourced by a Swift or Objective-C Equatable property
@warn_unused_result public func channelZProperty<T: Equatable>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞=initialValue=∞
}

@warn_unused_result public func channelZPropertyState<T>(initialValue: T) -> Channel<PropertySource<T>, StatePulse<T>> {
    return PropertySource(initialValue).channelZState()
}

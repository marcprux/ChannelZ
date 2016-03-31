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
public protocol StatePulseType {
    associatedtype T
    var old: T? { get }
    var new: T { get }
}

/// A StatePulse encapsulates a state change from an old value to a new value
public struct StatePulse<T> : StatePulseType {
    public let old: T?
    public let new: T

    public init(old: T?, new: T) {
        self.old = old
        self.new = new
    }
}

/// Abstraction of a source that can create a channel that emits a tuple of old & new state values.
public protocol StateSource : DistinctPulseSource {
    associatedtype Element
    associatedtype Source

    var value: Element { get nonmutating set }

    /// Creates a Channel from this source that will emit tuples of the old & and state values whenever a state operation occurs
    @warn_unused_result func channelZState() -> Channel<Source, StatePulse<Element>>
}

/// A PropertySource can be used to wrap any Swift or Objective-C type to make it act as a `Channel`
/// The output type is a tuple of (old: T, new: T), where old is the previous value and new is the new value
public final class PropertySource<T>: StateSink, StateSource {
    public typealias State = StatePulse<T>
    private let receivers = ReceiverList<State>()
    public var value: T { didSet(old) { receivers.receive(StatePulse(old: old, new: value)) } }
    public var pulseCount: Int64 { return receivers.pulseCount }
    
    public init(_ value: T) { self.value = value }
    public func put(x: T) { value = x }

    @warn_unused_result public func channelZState() -> Channel<PropertySource<T>, State> {
        return Channel(source: self) { rcvr in
            rcvr(State(old: Optional<T>.None, new: self.value)) // immediately issue the original value with no previous value
            return self.receivers.addReceipt(rcvr)
        }
    }
}

public protocol Sink {
    associatedtype Element
    mutating func put(value: Element)
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
        var s = sink
        return receive { s.put($0) }
    }
}

/// Simple protocol that permits accessing the underlying source type
public protocol StateSink : Sink {
    var value: Element { get }
    func put(value: Element)
}

/// A type-erased wrapper around some state source whose value changes will emit a `StatePulse`
public struct StateOf<T>: Sink, StateSource {
    private let valueget: Void -> T
    private let valueset: T -> Void
    private let channler: Void -> Channel<Void, StatePulse<T>>
    private let pulseCounter: Void -> Int64

    public var pulseCount: Int64 { return pulseCounter() }

    public var value: T {
        get { return valueget() }
        nonmutating set { put(newValue) }
    }

    public init<S where S: StateSink, S: StateSource, S.Element == T>(_ source: S) {
        valueget = { source.value }
        valueset = { source.value = $0 }
        channler = { source.channelZState().dissolve() }
        pulseCounter = { source.pulseCount }
    }

    public init(get: Void -> T, set: T -> Void, channeler: Void -> Channel<Void, StatePulse<T>>, pulser: Void -> Int64) {
        valueget = get
        valueset = set
        channler = channeler
        pulseCounter = pulser
    }

    public func put(x: T) {
        valueset(x)
    }

    @warn_unused_result public func channelZState() -> Channel<StateOf<T>, StatePulse<T>> {
        return channler().resource({ _ in self })
    }
}

/// A WrapperType is able to map itself through a wrapped optional
public protocol OptionalMappable : NilLiteralConvertible {
    associatedtype Wrapped
    init(_ some: Wrapped)
    func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U?
}

extension Optional : OptionalMappable { }


/// Experimental: creates a channel for a type that is formed of 2 elements
@warn_unused_result public func channelZDecomposedState<T, T1, T2>(constructor: (T1, T2) -> T, values: (T1, T2)) -> Channel<(Channel<StateOf<T1>, T1>, Channel<StateOf<T2>, T2>), T> {
    let channel = channelZProperty(constructor(
        values.0,
        values.1
        )
    )
    let source = (
        channelZProperty(values.0).resource(StateOf.init),
        channelZProperty(values.1).resource(StateOf.init)
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
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3>(constructor: (T1, T2, T3) -> T, values: (T1, T2, T3)) -> Channel<(Channel<StateOf<T1>, T1>, Channel<StateOf<T2>, T2>, Channel<StateOf<T3>, T3>), T> {
    let channel = channelZProperty(constructor(
        values.0,
        values.1,
        values.2
        )
    )
    let source = (
        channelZProperty(values.0).resource(StateOf.init),
        channelZProperty(values.1).resource(StateOf.init),
        channelZProperty(values.2).resource(StateOf.init)
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
@warn_unused_result public func channelZDecomposedState<T, T1, T2, T3, T4>(constructor: (T1, T2, T3, T4) -> T, values: (T1, T2, T3, T4)) -> Channel<(Channel<StateOf<T1>, T1>, Channel<StateOf<T2>, T2>, Channel<StateOf<T3>, T3>, Channel<StateOf<T4>, T4>), T> {
    let channel = channelZProperty(constructor(
        values.0,
        values.1,
        values.2,
        values.3
        )
    )
    let source = (
        channelZProperty(values.0).resource(StateOf.init),
        channelZProperty(values.1).resource(StateOf.init),
        channelZProperty(values.2).resource(StateOf.init),
        channelZProperty(values.3).resource(StateOf.init)
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

public extension ChannelType where Source : DistinctPulseSource {
    /// Adds a channel phase that retains a previous item and sends it along with the current value as an optional tuple element.
    /// This mechanism allows for the simualation of a state Channel that emits a `StatePulse` even when the underlying
    /// value change mechanics are unavailable.
    ///
    /// - Returns: a state Channel that emits a tuple of an earlier and the current item
    ///
    /// - Note: this phase with retain the previous *two* pulse items
    @warn_unused_result public func precedent() -> Channel<Source, StatePulse<Element>> {
        let isDistinctPulse = distinguishPulse()
        var antecedents: (Element?, Element?) = (nil, nil)
        return lift2 { receive in
            { item in
                if isDistinctPulse() {
                    antecedents.1 = antecedents.0 // bump the antecedent stack
                    antecedents.0 = item
                }
                let pair = StatePulse(old: antecedents.1, new: item)
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
        let flt = { (t: StatePulse<Element>) in t.old == nil || predicate(previous: t.old!, current: t.new) }
        return precedent().filter(flt).new()
    }

    /// Adds an observer closure to a change in the given equatable property
    public func observe<T: Equatable>(getter: Element -> T, receiver: T -> Void) -> Receipt {
        return map(getter).sieve(!=).receive(receiver)
    }

    /// Adds an observer closure to a change in the given optional equatable property
    public func observe<T: Equatable>(getter: Element -> Optional<T>, receiver: Optional<T> -> Void) -> Receipt {
        return map(getter).sieve(!=).receive(receiver)
    }
}

public extension ChannelType where Element : StatePulseType {
    /// Maps to the `new` value of the `StatePulse` element
    @warn_unused_result public func new() -> Channel<Source, Element.T> {
        return map({ $0.new })
    }

    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func changes(changed: (Element.T, Element.T) -> Bool) -> Channel<Source, Element.T> {
        return filter({ $0.old == nil || changed($0.old!, $0.new) }).new()
    }

}

public extension ChannelType where Element : StatePulseType, Element.T : Equatable {
    /// Filters the channel for only changed instances of the underlying `StatePulse`
    @warn_unused_result public func changes() -> Channel<Source, Element.T> {
        return changes(!=)
    }
}

public extension ChannelType where Element : StatePulseType, Element.T : OptionalMappable, Element.T.Wrapped : Equatable {
    /// Filters the channel for only changed instances of the underlying `StatePulse` of optional instances
    @warn_unused_result public func changes() -> Channel<Source, Element.T> {
        // OptionalMappable just exists because we can only constrain a protocol extension based on other protocols;
        // it will always be an Optional, but equatablility is only defined for Optional, not OptionalMappable
        return changes({ $0.0.flatMap({ $0 }) != $0.1.flatMap({ $0 }) })
    }
}

public extension ChannelType where Source : StateSource {
    /// A Channel whose source is a `StateSource` can get and set its value directly without mutating the channel
    public var value : Source.Element {
        get { return source.value }
        nonmutating set { source.value = newValue }
    }

    /// Re-maps a state channel by transforming the source with the given get/set mapping functions
    public func stateMap<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<StateOf<X>, Element> {
        return resource { source in StateOf(get: { get(source.value) }, set: { source.value = set($0) }, channeler: { source.channelZState().dissolve().map { state in StatePulse(old: state.old.flatMap(get), new: get(state.new)) } }, pulser: { source.pulseCount }) }
    }
}

public extension ChannelType where Source : StateSource, Source.Element == Element {
    /// For a channel whose underlying state matches the pulse types, perform a `stateMap` and a `map` with the same `get` transform
    public func restate<X>(get get: Source.Element -> X, set: X -> Source.Element) -> Channel<StateOf<X>, X> {
        return stateMap(get: get, set: set).map(get)
    }
}

public extension ChannelType where Source : StateSource, Element: OptionalMappable, Source.Element == Element, Element.Wrapped: Hashable {
    public func restateMapping<U: Hashable, S: SequenceType where S.Generator.Element == (Element, U?)>(mapping: S) -> Channel<StateOf<U?>, U?> {
        var getMapping: [Element.Wrapped: U] = [:]
        var setMapping: [U: Element] = [:]

        for (key, value) in mapping {
            if let key = key.flatMap({ $0 }) {
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


/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `Sink`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
public func conduit<S1, S2, T1, T2 where S1: Sink, S2: Sink, S1.Element == T2, S2.Element == T1>(c1: Channel<S1, T1>, _ c2: Channel<S2, T2>) -> Receipt {
    return ReceiptOf(receipts: [c1.pipe(c2.source), c2.pipe(c1.source)])
}

/// Creates a one-way conduit betweek a `Channel`s whose source is an `Equatable` `Sink`, such that when the left
/// side is changed the right side is updated
public func conduct<S1, S2, T1, T2 where S2: Sink, S2.Element == T1>(c1: Channel<S1, T1>, _ c2: Channel<S2, T2>) -> Receipt {
    return c1∞->c2.source
}

// MARK: Utilities

/// Creates a Channel sourced by a `SinkTo` that will be used to send elements to the receivers
@warn_unused_result public func channelZSink<T>(type: T.Type) -> Channel<SinkTo<T>, T> {
    let rcvrs = ReceiverList<T>()
    let sink = SinkTo<T>({ rcvrs.receive($0) })
    return Channel<SinkTo<T>, T>(source: sink) { rcvrs.addReceipt($0) }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
@warn_unused_result public func channelZSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S) -> Channel<S, T> {
    return from.channelZSequence()
}

extension SequenceType {
    /// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
    @warn_unused_result func channelZSequence() -> Channel<Self, Self.Generator.Element> {
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
@warn_unused_result public func channelZProperty<T>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞initialValue∞
}

/// Creates a Channel sourced by a Swift or Objective-C Equatable property
@warn_unused_result public func channelZProperty<T: Equatable>(initialValue: T) -> Channel<PropertySource<T>, T> {
    return ∞=initialValue=∞
}

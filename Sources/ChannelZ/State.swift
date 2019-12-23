//
//  State.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 3/29/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

#if swift(>=5.1)

/// A ValueTransceiver wraps any type to make it act as a `Channel` where changes to the underlying
/// value can be observed as `Mutatation` pulses (provided that changes are made via the
/// ValueTransceiver's setter).
///
/// This is similar to the `Combine.Published` property wrapper.
@propertyWrapper
public final class Transceiver<T> {
    public typealias State = Mutation<T>
    let receivers = ReceiverQueue<State>()

    /// The underlying value for this tranceiver
    public var wrappedValue: T {
        didSet(old) {
            receivers.receive(Mutation(old: old, new: wrappedValue))
        }
    }

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public func transceive() -> Channel<Transceiver<T>, Mutation<T>> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.none, new: self.wrappedValue))
            return self.receivers.addReceipt(rcvr)
        }
    }
}

extension Transceiver : TransceiverType {
    public var rawValue: T {
        get { return self.wrappedValue }
        set { self.wrappedValue = newValue }
    }

    public func receive(_ value: T) {
        self.rawValue = value
    }
}

extension Transceiver : Equatable where T : Equatable {
    /// Equatability is contingent only upon the value
    public static func == (lhs: Transceiver<T>, rhs: Transceiver<T>) -> Bool {
        return lhs.wrappedValue == rhs.wrappedValue
    }
}

extension Transceiver : Hashable where T : Hashable {
    /// Hashability is contingent only upon the value
    public func hash(into hasher: inout Hasher) {
        self.wrappedValue.hash(into: &hasher)
    }
}

extension Transceiver : Encodable where T : Encodable {
    public func encode(to encoder: Encoder) throws {
        try self.wrappedValue.encode(to: encoder)
    }
}

extension Transceiver : Decodable where T : Decodable {
    public convenience init(from decoder: Decoder) throws {
        self.init(wrappedValue: try T(from: decoder))
    }
}

//#if canImport(Combine)
//import Combine
//
//extension Transceiver : Combine.Publisher {
//    @available(OSXApplicationExtension 10.15, *)
//    public func receive<S>(subscriber: S) where S : Combine.Subscriber, Transceiver.Failure == S.Failure, Transceiver.Output == S.Input {
////        receivers.addReceipt(<#T##receptor: (Mutation<T>) -> ()##(Mutation<T>) -> ()#>)
//    }
//
//    public typealias Output = State
//    public typealias Failure = Never
//
//
//}
//#endif

#endif


/// A `ValuableType` simply encapsulates a value; it is a superset of RawRepresentable, but does not require a constructor
public protocol ValuableType {
    associatedtype RawValue
    var rawValue: RawValue { get }
}

//public typealias ValuableType = RawRepresentable

/// A MutationType is an encapsulation of state over time, such that a pulse has
/// an `old` value (optionally none for the initial state pulse) and a `new` value,
/// which is the current value of the state at the time of emission.
///
/// Note that the issuance of a Mutation does not imply that the state has changed,
/// since there is no equatability requirement for the underlying type.
///
/// - See Also: `Channel.sieve`
public protocol MutationType : ValuableType, RawRepresentable {
    /// The previous value of the state; can be `.None` when there is no previous state (e.g., when it is the initial pulse being emitted)
    var old: RawValue? { get }
    /// The new value of the state
    var new: RawValue { get }
}

public extension MutationType {
    @inlinable var rawValue: RawValue { return new }
}

/// A Mutation encapsulates a state change from an (optional) old value to a (required) new value
public struct Mutation<T> : MutationType {
    public typealias RawValue = T
    
    /// The previous value of the state; can be `.None` when there is no previous state (e.g., when it is the initial pulse being emitted)
    public let old: RawValue?
    /// The new value of the state
    public let new: RawValue

    @inlinable public init(old: RawValue?, new: RawValue) {
        self.old = old
        self.new = new
    }

    public init(rawValue: T) {
        self.init(old: nil, new: rawValue)
    }
}

/// A channel whose source and pulse are both value types and whose types are the same
public protocol TransceiverChannelType : ChannelType where Source : RawRepresentable, Pulse : RawRepresentable, Pulse.RawValue == Source.RawValue {
    associatedtype RawValue = Source.RawValue
}

//extension ChannelType where Source : ValuableType, Pulse : ValuableType, Pulse.Value == Source.Value {
//    /// The value for both the source and the pulse when the channel represent Valuables of the same types
//    // handy, but it crashes the Swift 4.1 compiler when accessed
//    @available(*, deprecated)
//    public typealias Value = Pulse.Value
//}

/// Swift 4.1 TODO: conditional conformance to tranceiver type will allow us to just do "extension TransceiverChannelType" rather than the current "extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Value == Source.Value"
//extension Channel : TransceiverChannelType where Source : ValuableType, Pulse : ValuableType, Pulse.Value == Source.Value {
//}

/// Abstraction of a source that can create a channel that emits a tuple of old & new state values,
/// and provides readable access to the "current" underlying state.
public protocol StateEmitterType : ValuableType {

    /// Creates a Channel from this source that will emit mutations of the old & and state values whenever a state operation occurs
    func transceive() -> Channel<Self, Mutation<RawValue>>
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

/// A transceiver is a type that can transmit & receive some `Mutation` pulses via respective
/// adoption of the `StateEmitterType` and `StateReveiver` protocols.
public protocol TransceiverType : StateEmitterType, StateReceiverType {
    /// The underlying state value of this source
    var rawValue: RawValue { get nonmutating set }
}

/// A ValueTransceiver wraps any type to make it act as a `Channel` where changes to the underlying
/// value can be observed as `Mutatation` pulses (provided that changes are made via the
/// ValueTransceiver's setter).
public final class ValueTransceiver<T>: ReceiverQueueSource<Mutation<T>>, TransceiverType, ValuableType, RawRepresentable {
    public typealias State = Mutation<T>

    // Note: not @inlinable because of a swift compiler crash in Release configuration

    /// The underlying value for this tranceiver
    public var rawValue: T {
        didSet(old) {
            receivers.receive(Mutation(old: old, new: rawValue))
        }
    }

    public init(_ value: T) { self.rawValue = value }

    /// Initializer for RawRepresentable
    public init(rawValue: T) { self.rawValue = rawValue }

    public func receive(_ x: T) { rawValue = x }

    public func transceive() -> TransceiverChannel<T> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.none, new: self.rawValue))
            return self.receivers.addReceipt(rcvr)
        }
    }
}

/// A transceiver channel is a simplified type that permits state mutation on a type
public typealias TransceiverChannel<T> = Channel<ValueTransceiver<T>, Mutation<T>>

/// A type-erased wrapper around some state source whose value changes will emit a `Mutation`
public struct AnyTransceiver<T> : TransceiverType {
    @usableFromInline let valueget: () -> T
    @usableFromInline let valueset: (T) -> Void
    @usableFromInline let channler: () -> Channel<Void, Mutation<T>>

    @inlinable public var rawValue: T {
        get { return valueget() }
        nonmutating set { receive(newValue) }
    }

    @inlinable public init<S>(_ source: S) where S: TransceiverType, S.RawValue == T {
        valueget = { source.rawValue }
        valueset = { source.rawValue = $0 }
        channler = { source.transceive().desource() }
    }

    @inlinable public init(get: @escaping () -> T, set: @escaping (T) -> Void, channeler: @escaping () -> Channel<Void, Mutation<T>>) {
        valueget = get
        valueset = set
        channler = channeler
    }

    @inlinable public func receive(_ x: T) {
        valueset(x)
    }

    @inlinable public func transceive() -> Channel<AnyTransceiver<T>, Mutation<T>> {
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
    func map<U>(_ f: (Wrapped) throws -> U) rethrows -> U?

    /// Returns `nil` if `self` is `nil`, `f(self!)` otherwise.
    /// - See Also: `Optional.flatMap`
    func flatMap<U>(_ f: (Wrapped) throws -> U?) rethrows -> U?

    /// Returns the wrapped instance as an optional value.
    var asOptional: Wrapped? { get }
}

public protocol _OptionalType : _WrapperType, ExpressibleByNilLiteral {
}

extension Optional : _OptionalType {
    @inlinable public var asOptional: Wrapped? { self }
}

extension _WrapperType {
    /// Convert this type to an optional; shorthand for `flatMap({ $0 })`
    @usableFromInline func toOptional() -> Wrapped? {
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
@usableFromInline func optionalTypeNotEqual<T : _WrapperType>(_ lhs: T, _ rhs: T) -> Bool where T.Wrapped : Equatable {
    return lhs.toOptional() != rhs.toOptional()
}

/// Experimental: creates a channel for a type that is formed of 2 elements
@inlinable public func channelZDecomposedState<T, T1, T2>(_ constructor: @escaping (T1, T2) -> T, values: (T1, T2)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>), T> {
    let channel = channelZPropertyValue(constructor(
        values.0,
        values.1
        )
    )
    let source = (
        channelZPropertyValue(values.0).anyTransceiver(),
        channelZPropertyValue(values.1).anyTransceiver()
    )
    func update(_ x: Any) { channel.rawValue = constructor(
        source.0.rawValue,
        source.1.rawValue
        )
    }
    source.0.receive(update)
    source.1.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@inlinable public func channelZDecomposedState<T, T1, T2, T3>(_ constructor: @escaping (T1, T2, T3) -> T, values: (T1, T2, T3)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>, Channel<AnyTransceiver<T3>, T3>), T> {
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
    func update(_ x: Any) { channel.rawValue = constructor(
        source.0.rawValue,
        source.1.rawValue,
        source.2.rawValue
        )
    }
    source.0.receive(update)
    source.1.receive(update)
    source.2.receive(update)

    return channel.resource { _ in source }
}

/// Experimental: creates a channel for a type that is formed of 3 elements
@inlinable public func channelZDecomposedState<T, T1, T2, T3, T4>(_ constructor: @escaping (T1, T2, T3, T4) -> T, values: (T1, T2, T3, T4)) -> Channel<(Channel<AnyTransceiver<T1>, T1>, Channel<AnyTransceiver<T2>, T2>, Channel<AnyTransceiver<T3>, T3>, Channel<AnyTransceiver<T4>, T4>), T> {
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
    func update(_ x: Any) { channel.rawValue = constructor(
        source.0.rawValue,
        source.1.rawValue,
        source.2.rawValue,
        source.3.rawValue
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
    /// This mechanism allows for the simualation of a state Channel that emits a `Mutation` 
    /// even when the underlying value change mechanics are unavailable.
    ///
    /// - Returns: a state Channel that emits a tuple of an earlier and the current item
    ///
    /// - Note: this phase with retain the previous *two* pulse items
    @inlinable func precedent() -> Channel<Source, Mutation<Pulse>> {
        return affect((old: Optional<Pulse>.none, new: Optional<Pulse>.none)) { (state, element) in (old: state.new, new: element) }.map { (state, element) in Mutation(old: state.old, new: element) }
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `Mutation` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateful Channel that emits the the pulses that pass the predicate
    ///
    /// - Note: Since `sieve` uses `precedent`, the most recent value will be retained by
    ///   the Channel for as long as there are receivers.
    ///
    @inlinable func presieve(_ predicate: @escaping (_ previous: Pulse, _ current: Pulse) -> Bool) -> Channel<Source, Mutation<Pulse>> {
        return precedent().sieve(predicate)
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `Mutation` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateful Channel that emits the the pulses that pass the predicate
    ///
    /// - Note: Since `sieve` uses `precedent`, the most recent value will be retained by 
    ///   the Channel for as long as there are receivers.
    ///
    @inlinable func changes(_ predicate: @escaping (_ previous: Pulse, _ current: Pulse) -> Bool) -> Channel<Source, Pulse> {
        return presieve(predicate).new()
    }
}

public extension ChannelType {

    /// Adds an observer closure to a change in the given equatable property
    @discardableResult
    @inlinable func watch<T>(_ getter: @escaping (Pulse) -> T, eq: @escaping (T, T) -> Bool, receiver: @escaping (T) -> Void) -> Receipt {
        return changes({ eq(getter($0), getter($1)) }).map(getter).receive(receiver)
    }

    /// Adds an observer closure to a change in the given equatable property
    @discardableResult
    @inlinable func observe<T: Equatable>(_ getter: @escaping (Pulse) -> T, receiver: @escaping (T) -> Void) -> Receipt {
        return watch(getter, eq: !=, receiver: receiver)
    }

    /// Adds an observer closure to a change in the given optional equatable property
    @discardableResult
    @inlinable func observe<T: Equatable>(_ getter: @escaping (Pulse) -> Optional<T>, receiver: @escaping (Optional<T>) -> Void) -> Receipt {
        return watch(getter, eq: { $0 != $1 }, receiver: receiver)
    }
}

public extension StreamType where Pulse : MutationType {
    /// Filters the channel for only changed instances of the underlying `Mutation`
    @inlinable func sieve(_ changed: @escaping (Pulse.RawValue, Pulse.RawValue) -> Bool) -> Self {
        return filter { state in
            // the initial state assignment is always fresh
            guard let old = state.old else { return true }
            return changed(state.new, old)
        }
    }
}

public extension ChannelType where Pulse : MutationType {
    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item. This is an optimization of `Channel.presieve` that uses the underlying
    /// `MutationType` rather than retaining the previous elements.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `Mutation` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateless Channel that emits the the pulses that pass the predicate
    @inlinable func stateFilter(_ predicate: @escaping (_ previous: Pulse.RawValue, _ current: Pulse.RawValue) -> Bool) -> Self {
        return sieve(predicate)
    }

    /// Adds a channel phase that emits pulses only when the pulses pass the filter predicate against the most
    /// recent emitted or passed item. This is an optimization of `Channel.presieve` that uses the underlying
    /// `MutationType` rather than retaining the previous elements.
    ///
    /// For example, to create a filter for distinct equatable pulses, you would do: `changes(!=)`.
    /// For channels that already emit `Mutation` types, use `Channel.sieve`.
    ///
    /// - Parameter predicate: a function that evaluates the current item against the previous item
    ///
    /// - Returns: A stateless Channel that emits the the pulses that pass the predicate
    @inlinable func changes(_ predicate: @escaping (_ previous: Pulse.RawValue, _ current: Pulse.RawValue) -> Bool) -> Channel<Source, Pulse.RawValue> {
        return stateFilter(predicate).new()
    }

    /// Passes the Mutation through a mapping of the KeyPath
    @inlinable func key<U>(path: KeyPath<Pulse.RawValue, U>) -> Channel<Source, Mutation<U>> {
        return map { pulse in
            Mutation(old: pulse.old?[keyPath: path], new: pulse.new[keyPath: path])
        }
    }

}

public extension StreamType where Pulse : MutationType, Pulse.RawValue : Equatable {
    /// Filters the channel for only changed instances of the underlying `Mutation`
    @inlinable func sieve() -> Self {
        return sieve(!=)
    }
}

public extension ChannelType where Pulse : MutationType, Pulse.RawValue : Equatable {
    /// Adds a channel phase that emits pulses only when the equatable pulses are not equal.
    ///
    /// - See Also: `changes(predicate:)`
    @inlinable func changes() -> Channel<Source, Pulse.RawValue> {
        return sieve().new()
    }
}

public extension StateEmitterType where RawValue : Equatable {
    /// Creates a a channel to all changed values for equatable elements
    @inlinable func transceiveChanges() -> Channel<Self, RawValue> {
        return transceive().changes()
    }
}

public extension StreamType where Pulse : MutationType, Pulse.RawValue : _WrapperType, Pulse.RawValue.Wrapped : Equatable {
    /// Filters the channel for only changed optional instances of the underlying `Mutation`
    @inlinable func sieveCompact() -> Self {
        return sieve(optionalTypeNotEqual)
    }
}

public extension ChannelType where Pulse : MutationType, Pulse.RawValue : _WrapperType, Pulse.RawValue.Wrapped : Equatable {
//    /// Adds a channel phase that emits pulses only when the optional equatable pulses are not equal.
//    ///
//    /// - See Also: `changes(predicate:)`
//    public func changes() -> Channel<Source, Pulse.Value> {
//        return sieveCompact().new()
//    }

    /// Adds a channel phase that emits pulses only when the optional equatable pulses are not equal.
    ///
    /// - See Also: `changes(predicate:)`
    func changesCompact() -> Channel<Source, Pulse.RawValue> {
        return sieveCompact().new()
    }
}

public extension StateEmitterType where RawValue : _WrapperType, RawValue.Wrapped : Equatable {
    /// Creates a a channel to all changed values for optional equatable elements
    func transceiveChanges() -> Channel<Self, RawValue> {
        return transceive().changesCompact()
    }
}

public extension ChannelType where Pulse : ValuableType {
    /// Maps to the `rawValue` value of the `Mutation` element
    @inlinable func raw() -> Channel<Source, Pulse.RawValue> {
        return map({ $0.rawValue })
    }
}

public extension ChannelType where Pulse : MutationType {
    /// Maps to the `new` value of the `Mutation` element
    @inlinable func new() -> Channel<Source, Pulse.RawValue> {
        return raw() // the value of a MutationType is the new() field
    }

    /// Maps to the `old` value of the `Mutation` element
    @inlinable func old() -> Channel<Source, Pulse.RawValue?> {
        return map({ $0.old })
    }

}

public extension ChannelType where Pulse : _WrapperType {
    /// Adds phases that filter for `Optional.Some` pulses (i.e., drops `nil`s) and maps to their `flatMap`ped (i.e., unwrapped) values
    @inlinable func some() -> Channel<Source, Pulse.Wrapped> {
        return map({ opt in opt.toOptional() }).filter({ $0 != nil }).map({ $0! })
    }
}

//public extension ChannelType where Source : StateEmitterType {
//      FIXME: creates an ambiguity with the Source : TransceiverType variant
//    /// A Channel whose source is a `StateEmitterType` can get its value directly
//    public var value : Source.Value {
//        get { return source.value }
//    }
//}

public extension ChannelType where Source : TransceiverType {
    /// A Channel whose source is a `TransceiverType` can get and set its value directly without mutating the channel
    @inlinable var rawValue : Source.RawValue {
        get { return source.rawValue }
        nonmutating set { source.rawValue = newValue }
    }

    /// Re-maps a state channel by transforming the source with the given get/set mapping functions
    @inlinable func stateMap<X>(get: @escaping (Source.RawValue) -> X, set: @escaping (X) -> Source.RawValue) -> Channel<AnyTransceiver<X>, Pulse> {
        return resource { source in AnyTransceiver(get: { get(source.rawValue) }, set: { source.rawValue = set($0) }, channeler: { source.transceive().desource().map { state in Mutation(old: state.old.flatMap(get), new: get(state.new)) } }) }
    }
}

//public extension ChannelType where Source : TransceiverType, Pulse : MutationType {
//}

public extension ChannelType where Source : TransceiverType {
    /// Creates a type-erased `StateEmitterType` with `AnyTransceiver` for this channel
    @inlinable func anyTransceiver() -> Channel<AnyTransceiver<Source.RawValue>, Pulse> {
        return resource(AnyTransceiver.init)
    }

}

public extension ChannelType where Source : TransceiverType, Source.RawValue == Pulse {
    /// For a channel whose underlying state matches the pulse types, perform a `stateMap` and a `map` with the same `get` transform
    @inlinable func restate<X>(get: @escaping (Source.RawValue) -> X, set: @escaping (X) -> Source.RawValue) -> Channel<AnyTransceiver<X>, X> {
        return stateMap(get: get, set: set).map(get)
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: _OptionalType, Source.RawValue == Pulse, Pulse.Wrapped: Hashable {
    @inlinable func restateMapping<U: Hashable, S: Sequence>(_ mapping: S) -> Channel<AnyTransceiver<U?>, U?> where S.Iterator.Element == (Pulse, U?) {
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

        let get: ((Pulse) -> U?) = { $0.flatMap({ getMapping[$0] }) ?? nil }
        let set: ((U?) -> Pulse) = { $0.flatMap({ setMapping[$0] }) ?? nil }

        return restate(get: get, set: set)
    }
}

public extension StreamType {
    /// Creates a one-way pipe between a `Channel`s whose source is a `Sink`, such that when the left
    /// side is changed the right side is updated
    @discardableResult
    @inlinable func conduct<C2 : ChannelType, S : ReceiverType>(_ to: C2) -> Receipt where S.Pulse == Self.Pulse, C2.Source == S {
        return self.receive(to.source)
    }
}

public extension ChannelType where Source : ReceiverType {
    /// Creates a two-way conduit between two `Channel`s whose source is a `Sink`, such that when either side is
    /// changed, the other side is updated
    ///
    /// - Note: the `to` channel will immediately receive a sync from the `self` channel, making `self` channel's state dominant
    @discardableResult
    @inlinable func conduit<C2: ChannelType>(_ to: C2) -> Receipt where C2.Source : ReceiverType, C2.Source.Pulse == Self.Pulse, C2.Pulse == Self.Source.Pulse {
        // since self is the dominant channel, ignore any immediate pulses through the right channel
        let rhs = to.subsequent().receive(self.source)
        let lhs = self.receive(to.source)
        return MultiReceipt(receipts: [lhs, rhs])
    }

}

public extension ChannelType where Source : TransceiverType {
    /// Creates a two-way conduit between two `Channel`s whose source is a `TransceiverType`,
    /// such that when either side is changed the other side is updated provided the filter is satisifed
    @discardableResult
    @inlinable func conjoin<C2: ChannelType>(_ to: C2, filterLeft: @escaping (Self.Pulse, C2.Source.RawValue) -> Bool, filterRight: @escaping (Self.Source.RawValue, Self.Source.RawValue) -> Bool) -> Receipt where C2.Pulse == Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        let filtered1 = self.filter({ filterLeft($0, to.source.rawValue) })
        let filtered2 = to.filter({ filterRight($0, self.source.rawValue) })
        
        // return filtered1.conduit(filtered2) // FIXME: types don't line up for some reason

        let at1: Channel<AnyTransceiver<C2.Pulse>, Self.Pulse> = filtered1.anyTransceiver()
        let at2: Channel<AnyTransceiver<Self.Pulse>, C2.Pulse> = filtered2.anyTransceiver()        
        return at1.conduit(at2) // need to erase state to get them to line up
    }

}

// MARK: Binding variants with pulse output

public extension ChannelType where Source : TransceiverType, Source.RawValue : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    @discardableResult
    @inlinable func bindPulseToPulse<C2: ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return conjoin(to, filterLeft: !=, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    ///
    /// See Also: `bindPulseToPulse`
    @discardableResult
    @inlinable func bind<C2: ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return bindPulseToPulse(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.RawValue : Equatable, Pulse : _WrapperType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func bindPulseToOptionalPulse<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return conjoin(to, filterLeft: optionalTypeNotEqual, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindPulseToOptionalPulse`
    @discardableResult
    @inlinable func bind<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return bindPulseToOptionalPulse(to)
    }

}

public extension ChannelType where Source : TransceiverType, Source.RawValue : _WrapperType, Source.RawValue.Wrapped : Equatable, Pulse : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func bindOptionalPulseToPulse<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return conjoin(to, filterLeft: !=, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindOptionalPulseToPulse`
    @discardableResult
    @inlinable func bind<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return bindOptionalPulseToPulse(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.RawValue : _WrapperType, Source.RawValue.Wrapped : Equatable, Pulse : _WrapperType, Pulse.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func bindOptionalPulseToOptionalPulse<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return conjoin(to, filterLeft: optionalTypeNotEqual, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `bindOptionalPulseToOptionalPulse`
    @discardableResult
    @inlinable func bind<C2 : ChannelType>(_ to: C2) -> Receipt where C2.Pulse == Self.Source.RawValue, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse {
        return bindOptionalPulseToOptionalPulse(to)
    }
}


// MARK: Binding variants with Mutation output

public extension ChannelType where Source : TransceiverType, Source.RawValue : Equatable, Pulse : MutationType, Pulse.RawValue : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    @discardableResult
    @inlinable func linkStateToState<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return self.changes(!=).conjoin(to.changes(!=), filterLeft: !=, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not equal.
    ///
    /// See Also: `linkStateToState`
    @discardableResult
    @inlinable func link<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return linkStateToState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.RawValue : Equatable, Pulse : MutationType, Pulse.RawValue : _WrapperType, Pulse.RawValue.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func linkStateToOptionalState<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return self.changesCompact().conjoin(to.changes(!=), filterLeft: optionalTypeNotEqual, filterRight: !=)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `linkStateToOptionalState`
    @discardableResult
    @inlinable func link<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return linkStateToOptionalState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.RawValue : _WrapperType, Source.RawValue.Wrapped : Equatable, Pulse : MutationType, Pulse.RawValue : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func linkOptionalStateToState<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return self.changes(!=).conjoin(to.changesCompact(), filterLeft: !=, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    /// 
    /// See Also: `linkOptionalStateToState`
    @discardableResult
    @inlinable func link<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return linkOptionalStateToState(to)
    }
}

public extension ChannelType where Source : TransceiverType, Source.RawValue : _WrapperType, Source.RawValue.Wrapped : Equatable, Pulse : MutationType, Pulse.RawValue : _WrapperType, Pulse.RawValue.Wrapped : Equatable {
    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    @discardableResult
    @inlinable func linkOptionalStateToOptionalState<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return self.changesCompact().conjoin(to.changesCompact(), filterLeft: optionalTypeNotEqual, filterRight: optionalTypeNotEqual)
    }

    /// Creates a two-way binding between two `Channel`s whose source is a `StateEmitterType`, such that when either side is
    /// changed, the other side is updated when they are not optionally equal.
    ///
    /// See Also: `linkOptionalStateToOptionalState`
    @discardableResult
    @inlinable func link<C2>(_ to: C2) -> Receipt where C2 : ChannelType, C2.Source : TransceiverType, C2.Source.RawValue == Self.Pulse.RawValue, C2.Pulse : MutationType, C2.Pulse.RawValue == Self.Source.RawValue {
        return linkOptionalStateToOptionalState(to)
    }
}

// MARK: Utilities


/// Creates a state transceiver with the underlying initial value.
///
/// A state transceiver is a channel that can both receive values (thereby setting the underlying state)
/// and emit changes to the state via the `Mutation` pulse type. State transceivers can
/// also be bound to other state transceivers using the `link` function.
///
/// - See Also: `ValueTransceiver`
/// - See Also: `link`
@inlinable public func transceive<T>(_ initialValue: T) -> TransceiverChannel<T> {
    return ValueTransceiver(rawValue: initialValue).transceive()
}

/// Creates a Channel sourced by a Swift or Objective-C property
@inlinable public func channelZPropertyValue<T>(_ initialValue: T) -> Channel<ValueTransceiver<T>, T> {
    return ∞initialValue∞
}

/// Creates a Channel sourced by a Swift or Objective-C Equatable property
@inlinable public func channelZPropertyValue<T: Equatable>(_ initialValue: T) -> Channel<ValueTransceiver<T>, T> {
    return ∞=initialValue=∞
}

/// Creates a Channel sourced by a `AnyReceiver` that will be used to send elements to the receivers
@inlinable public func channelZSink<T>(_ type: T.Type) -> Channel<AnyReceiver<T>, T> {
    let rcvrs = ReceiverQueue<T>()
    let sink = AnyReceiver<T>({ rcvrs.receive($0) })
    return Channel<AnyReceiver<T>, T>(source: sink) { rcvrs.addReceipt($0) }
}

extension Sequence {
    /// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
    @inlinable public func channelZSequence() -> Channel<Self, Self.Iterator.Element> {
        return Channel(source: self) { rcvr in
            for item in self { rcvr(item) }
            return ReceiptOf() // cancelled receipt since it will never receive more pulses
        }
    }
}

/// Creates a Channel sourced by a `GeneratorType` that will emit all its elements to new receivers
@inlinable public func channelZGenerator<S, T>(_ from: S) -> Channel<S, T> where S: IteratorProtocol, S.Element == T {
    return Channel(source: from) { rcvr in
        for item in AnyIterator(from) { rcvr(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more pulses
    }
}

/// Creates a Channel sourced by an optional Closure that will be send all execution results to new receivers until it returns `.None`
@inlinable public func channelZClosure<T>(_ from: @escaping () -> T?) -> Channel<() -> T?, T> {
    return Channel(source: from) { rcvr in
        while let item = from() { rcvr(item) }
        return ReceiptOf() // cancelled receipt since it will never receive more pulses
    }
}

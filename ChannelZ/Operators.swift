//
//  Tuples.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/4/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//


// MARK: Operators

/// Channel merge operation for two channels of the same type (operator form of `merge`)
public func + <S1, S2, T>(lhs: Channel<S1, T>, rhs: Channel<S2, T>)->Channel<(S1, S2), T> {
    return lhs.merge(rhs)
}

/// Channel concat operation for two channels of the same source and element types (operator form of `concat`)
public func + <S, T>(lhs: Channel<S, T>, rhs: Channel<S, T>)->Channel<[S], (S, T)> {
    return lhs.concat(rhs)
}

/// Operator for adding a receiver to the given channel
public func ∞> <S, T>(lhs: Channel<S, T>, rhs: T->Void)->Receipt { return lhs.receive(rhs) }
infix operator ∞> { }

/// Sets the value of a channel's source that is sourced by a `SinkType`
public func ∞= <T, S: SinkType>(lhs: Channel<S, T>, rhs: S.Element)->Void { var src = lhs.source; src.put(rhs) }
infix operator ∞= { }


/// Reads the value from the given channel's source that is sourced by an StateSink implementation
public postfix func ∞? <T, S: StateSink>(c: Channel<S, T>)->S.Element { return c.source.value }
postfix operator ∞? { }


/// Increments the value of the source of the channel; works, but only when we define one of them
//public postfix func ++ <T, S: StateSink where S.Element == Int>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: StateSink where S.Element == Int8>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: StateSink where S.Element == Int16>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: StateSink where S.Element == Float>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + Float(1.0) }


// MARK: Operators that create state channels

prefix operator ∞ { }
prefix operator ∞= { }
prefix operator ∞?= { }

postfix operator =∞ { }
postfix operator ∞ { }

// MARK: Prefix operators 

/// Creates a channel from the given state source such that emits items for every state operation
public prefix func ∞ <S: StateSource, T where S.Element == T>(source: S)->Channel<S, T> {
    return source.channelZState().map({ $0.1 })
}

/// Creates a distinct sieved channel from the given Equatable state source such that only subsequent state changes are emitted
public prefix func ∞= <S: StateSource, T: Equatable where S.Element == T>(source: S)->Channel<S, T> {
    return source.channelZState().filter({ $0.0 != $0.1 }).map({ $0.1 }).subsequent()
}



// FIXME: the prefix ∞= works fine for a generic StateSource except when we want to constrain the type to both Optional & Equatable.
//
// The following crashes the compiler <https://devforums.apple.com/thread/261484>:
// public prefix func ∞= <S: StateSource, T: Equatable where S.Element == Optional<T>>(source: S)->Channel<S, T?> { fatalError("TODO") }
//
// And the following yields the error: “Reference to generic type 'Optional' requires arguments in <...>”
// public prefix func ∞= <S: StateSource, T: Equatable where S.Element == Optional>(source: S)->Channel<S, T?> { fatalError("TODO") }
//
// So we can make a OptionalStateElement which provides access to the Optional's typealiased T fr use in the generic clause
// However, we can't make it public because:
// “'public' modifier cannot be used with extensions that declare protocol conformances”
// And so our function that uses it can't be public because:
// “Operator function cannot be declared public because its generic requirement uses an internal type”
// And so we need to make cover functions for each specific StateSource implementation (KeyValueOptionalSource and PropertySource)
// which just refers to this internal ∞?= implementation. Bummer.

protocol OptionalStateElement {
    typealias WrappedType
    var unwrap: WrappedType? { get }
//    func map<U>(f: (WrappedType) -> U) -> U?
}

extension Optional: OptionalStateElement {
    typealias WrappedType = T
    var unwrap: T? { return map { $0 } }
}

prefix func ∞?=<S: StateSource, T: Equatable where S.Element: OptionalStateElement, S.Element.WrappedType: Equatable, T == S.Element.WrappedType>(source: S)->Channel<S, T?> {

    let wrappedState: Channel<S, (S.Element?, S.Element)> = source.channelZState()

    // each of the three following statements should be equivalent, but they return subtly different results! Only the first is correct.
    let unwrappedState: Channel<S, (T??, T?)> = wrappedState.map({ pair in (pair.0?.unwrap, pair.1.unwrap) })
//    let unwrappedState: Channel<S, (T??, T?)> = wrappedState.map({ pair in (pair.0?.map({$0}), pair.1.map({$0})) })
//    func unwrap(pair: (S.Element?, S.Element))->(T??, T?) { return (pair.0?.unwrap, pair.1.unwrap) }
//    let unwrappedState: Channel<S, (T??, T?)> = wrappedState.map({ pair in unwrap(pair) })

    let notEqual: Channel<S, (T??, T?)> = unwrappedState.filter({ pair in pair.0 == nil || pair.0! != pair.1 })
    let changedState: Channel<S, T?> = notEqual.map({ pair in pair.1 })
    return changedState
}

/// Creates a distinct sieved channel from the given Equatable Optional PropertySource
public prefix func ∞= <T: Equatable>(source: PropertySource<T?>)->Channel<PropertySource<T?>, T?> { return ∞?=source }


// MARK: Postfix operators

/// Creates a source for the given property that will emit state operations
public postfix func ∞ <T>(value: T)->PropertySource<T> { return PropertySource(value) }

/// Creates a source for the given property that will emit state operations
public postfix func =∞ <T: Equatable>(value: T)->PropertySource<T> { return value∞ }

/// Creates a source for the given property that will emit state operations
public postfix func =∞ <T: Equatable>(value: T?)->PropertySource<T?> { return value∞ }


// MARK: Infix operators

/// Creates a one-way pipe betweek a `Channel` and a `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞-> <S1, T, S2: SinkType where T == S2.Element>(r: Channel<S1, T>, s: S2)->Receipt { return r.pipe(s) }
infix operator ∞-> { }


/// Creates a one-way pipe betweek a `Channel` and an `Equatable` `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞=> <S1, S2, T1, T2 where S2: SinkType, S2.Element == T1>(c1: Channel<S1, T1>, c2: Channel<S2, T2>)->Receipt {
    return conduct(c1, c2)
}

infix operator ∞=> { }


/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
/// This is the operator form of `channel`
public func <=∞=> <S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return conduit(r1, r2) }
infix operator <=∞=> { }


/// Lossy conduit conversion operators
infix operator <~∞~> { }

/// Conduit operator that filters out nil values with a custom transformer
public func <~∞~> <S1, S2, T1, T2 where S1: SinkType, S2: SinkType>(lhs: (o: Channel<S1, T1>, f: T1->Optional<S2.Element>), rhs: (o: Channel<S2, T2>, f: T2->Optional<S1.Element>))->Receipt {
    let lhsm: Channel<S1, S2.Element> = lhs.o.map({ lhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })
    let rhsm: Channel<S2, S1.Element> = rhs.o.map({ rhs.f($0) ?? nil }).filter({ $0 != nil }).map({ $0! })
    return conduit(lhsm, rhsm)
}


/// Convert (possibly lossily) between two numeric types
public func <~∞~> <S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element: ConduitNumericCoercible, S2.Element: ConduitNumericCoercible, T1: ConduitNumericCoercible, T2: ConduitNumericCoercible>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Receipt {
    return conduit(lhs.map({ convertNumericType($0) }), rhs.map({ convertNumericType($0) }))
}

/// Convert (possibly lossily) between optional and non-optional types
public func <~∞~> <S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1>(lhs: Channel<S1, Optional<T1>>, rhs: Channel<S2, T2>)->Receipt {
    return conduit(lhs.filter({ $0 != nil }).map({ $0! }), rhs)
}

public func <~∞~> <S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1>(lhs: Channel<S1, T1>, rhs: Channel<S2, Optional<T2>>)->Receipt {
    return conduit(lhs, rhs.filter({ $0 != nil }).map({ $0! }))
}


// MARK: Channel Tuple flatten/combine support

/// Channel combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1?, T2?)> {
    return lhs.either(rhs)
}

/// Channel zipping & flattening operation
public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}

// MARK: Auto-generated boilerplate tuple operations


public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineAll(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineAll(lhs.zip(rhs))) }

public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1?, T2?)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1?, T2?, T3?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1?, T2?, T3?)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1?, T2?, T3?, T4?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1?, T2?, T3?, T4?)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1?, T2?, T3?, T4?, T5?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1?, T2?, T3?, T4?, T5?)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1?, T2?, T3?, T4?, T5?, T6?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1?, T2?, T3?, T4?, T5?, T6?)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1?, T2?, T3?, T4?, T5?, T6?, T7?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1?, T2?, T3?, T4?, T5?, T6?, T7?)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?)> { return combineSources(combineAny(lhs.either(rhs))) }
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?, T20?)> { return combineSources(combineAny(lhs.either(rhs))) }

private func flattenSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, T>(rcvr: Channel<(((S1, S2), S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { let src = rcvr.source; return Channel(source: (src.0.0.0, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<(((((S1, S2), S3), S4), S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((((((S1, S2), S3), S4), S5), S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<(((((((S1, S2), S3), S4), S5), S6), S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<(((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<(((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(rcvr: Channel<((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(rcvr: Channel<(((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(rcvr: Channel<((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(rcvr: Channel<(((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(rcvr: Channel<((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(rcvr: Channel<(((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(rcvr: Channel<((((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(rcvr: Channel<(((((((((((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), S13), S14), S15), S16), S17), S18), S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }

private func combineSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, T>(rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.1), reception: rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.0.18, src.1), reception: rcvr.reception) }

private func flattenElements<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4>(rcvr: Channel<S, (((T1, T2), T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((((T1, T2), T3), T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, (((((T1, T2), T3), T4), T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((((((T1, T2), T3), T4), T5), T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0.0.0.0.0, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, (((((((T1, T2), T3), T4), T5), T6), T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, (((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, (((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, (((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, (((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, (((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }
private func flattenElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, (((((((((((((((((((T1, T2), T3), T4), T5), T6), T7), T8), T9), T10), T11), T12), T13), T14), T15), T16), T17), T18), T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) } }

private func combineAll<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func combineAll<S, T1, T2, T3, T4>(rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.0.18, $0.1) } }

private func combineAny<S, T1, T2, T3>(rcvr: Channel<S, ((T1?, T2?)?, T3?)>)->Channel<S, (T1?, T2?, T3?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.1) } }
private func combineAny<S, T1, T2, T3, T4>(rcvr: Channel<S, ((T1?, T2?, T3?)?, T4?)>)->Channel<S, (T1?, T2?, T3?, T4?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?)?, T5?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?)?, T6?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?)?, T7?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?)?, T8?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?)?, T9?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?)?, T10?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?)?, T11?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?)?, T12?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?)?, T13?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?)?, T14?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?)?, T15?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?)?, T16?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.0?.14, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?)?, T17?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.0?.14, $0.0?.15, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?)?, T18?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.0?.14, $0.0?.15, $0.0?.16, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?)?, T19?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.0?.14, $0.0?.15, $0.0?.16, $0.0?.17, $0.1) } }
private func combineAny<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(rcvr: Channel<S, ((T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?)?, T20?)>)->Channel<S, (T1?, T2?, T3?, T4?, T5?, T6?, T7?, T8?, T9?, T10?, T11?, T12?, T13?, T14?, T15?, T16?, T17?, T18?, T19?, T20?)> { return rcvr.map { ($0.0?.0, $0.0?.1, $0.0?.2, $0.0?.3, $0.0?.4, $0.0?.5, $0.0?.6, $0.0?.7, $0.0?.8, $0.0?.9, $0.0?.10, $0.0?.11, $0.0?.12, $0.0?.13, $0.0?.14, $0.0?.15, $0.0?.16, $0.0?.17, $0.0?.18, $0.1) } }


//
//  Tuples.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/4/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Foundation

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

/// Sets the value of a channel's source that is sourced by a `Sink`
public func ∞= <T, S: ReceiverType>(lhs: Channel<S, T>, rhs: S.Pulse)->Void { lhs.source.receive(rhs) }
infix operator ∞= { }


/// Reads the value from the given channel's source that is sourced by an Sink implementation
public postfix func ∞? <T, S: StateEmitterType>(c: Channel<S, T>)->S.Element { return c.source.$ }
postfix operator ∞? { }


/// Increments the value of the source of the channel; works, but only when we define one of them
//public postfix func ++ <T, S: ReceiverType where S.Element == Int>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: ReceiverType where S.Element == Int8>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: ReceiverType where S.Element == Int16>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + 1 }
//public postfix func ++ <T, S: ReceiverType where S.Element == Float>(channel: Channel<S, T>)->Void { channel ∞= channel∞? + Float(1.0) }


// MARK: Operators that create state channels

prefix operator ∞ { }
prefix operator ∞= { }
prefix operator ∞?= { }

postfix operator =∞ { }
postfix operator ∞ { }

// MARK: Prefix operators 

/// Creates a channel from the given state source such that emits items for every state operation
public prefix func ∞ <S: StateEmitterType, T where S.Element == T>(source: S)->Channel<S, T> {
    return source.transceive().new()
}

/// Creates a distinct sieved channel from the given Equatable state source such that only state changes are emitted
///
/// - See: `Channel.changes`
public prefix func ∞= <S: StateEmitterType, T: Equatable where S.Element == T>(source: S) -> Channel<S, T> {
    return source.transceive().sieve().new()
}

prefix func ∞?=<S: StateEmitterType, T: Equatable where S.Element: _OptionalType, S.Element.Wrapped: Equatable, T == S.Element.Wrapped>(source: S) -> Channel<S, T?> {

    let wrappedState: Channel<S, StatePulse<S.Element>> = source.transceive()

    // each of the three following statements should be equivalent, but they return subtly different results! Only the first is correct.
    let unwrappedState: Channel<S, StatePulse<T?>> = wrappedState.map({ pair in StatePulse(old: pair.old?.toOptional(), new: pair.new.toOptional()) })
//    let unwrappedState: Channel<S, (old: T??, new: T?)> = wrappedState.map({ pair in (pair.old?.map({$0}), pair.new.map({$0})) })
//    func unwrap(pair: (S.Element?, S.Element)) -> (old: T??, new: T?) { return (pair.old?.unwrap, pair.new.unwrap) }
//    let unwrappedState: Channel<S, (old: T??, new: T?)> = wrappedState.map({ pair in unwrap(pair) })

    let notEqual: Channel<S, StatePulse<T?>> = unwrappedState.filter({ pair in pair.old == nil || pair.old! != pair.new })
    let changedState: Channel<S, T?> = notEqual.map({ pair in pair.new })
    return changedState
}

/// Creates a distinct sieved channel from the given Equatable Optional ValueTransceiver
public prefix func ∞= <T: Equatable>(source: ValueTransceiver<T?>) -> Channel<ValueTransceiver<T?>, T?> { return ∞?=source }


// MARK: Postfix operators

/// Creates a source for the given property that will emit state operations
public postfix func ∞ <T>(value: T) -> ValueTransceiver<T> { return ValueTransceiver(value) }

/// Creates a source for the given property that will emit state operations
public postfix func =∞ <T: Equatable>(value: T) -> ValueTransceiver<T> { return ValueTransceiver(value) }

/// Creates a source for the given property that will emit state operations
public postfix func =∞ <T: Equatable>(value: T?) -> ValueTransceiver<T?> { return value∞ }


// MARK: Infix operators

/// Creates a one-way pipe betweek a `Channel` and a `Sink`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞-> <S1, T, S2: ReceiverType where T == S2.Pulse>(r: Channel<S1, T>, s: S2) -> Receipt { return r.receive(s) }
infix operator ∞-> { }


/// Creates a one-way pipe betweek a `Channel` and an `Equatable` `Sink`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞=> <S1, S2, T1, T2 where S2: ReceiverType, S2.Pulse == T1>(c1: Channel<S1, T1>, c2: Channel<S2, T2>) -> Receipt {
    return c1.conduct(c2)
}

infix operator ∞=> { }


/// Creates a two-way binding betweek two `Channel`s whose source is an `Equatable` `Sink`, such that when either side is
/// changed, the other side is updated
/// This is the operator form of `bind`
public func <=∞=> <S1, S2, T1, T2 where S1: TransceiverType, S2: TransceiverType, S1.Element == T2, S2.Element == T1, S1.Element: Equatable, S2.Element: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return r1.bind(r2) }
infix operator <=∞=> { }

/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `Sink`, such that when either side is
/// changed, the other side is updated
/// This is the operator form of `channel`
public func <∞> <S1, S2, T1, T2 where S1: ReceiverType, S2: ReceiverType, S1.Pulse == T2, S2.Pulse == T1>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return r1.conduit(r2) }
infix operator <∞> { }


/// Lossy conduit conversion operators
infix operator <~∞~> { }

///// Conduit operator that filters out nil values with a custom transformer
public func <~∞~> <S1, S2, T1, T2 where S1: ReceiverType, S2: ReceiverType>(lhs: (o: Channel<S1, T1>, f: T1 -> Optional<S2.Pulse>), rhs: (o: Channel<S2, T2>, f: T2 -> Optional<S1.Pulse>)) -> Receipt {
    let lhsf = lhs.f
    let lhsm: Channel<S1, S2.Pulse> = lhs.o.map({ lhsf($0) ?? nil }).some()
    let rhsf = rhs.f
    let rhsm: Channel<S2, S1.Pulse> = rhs.o.map({ rhsf($0) ?? nil }).some()
    return lhsm.conduit(rhsm)
}


/// Convert (possibly lossily) between two numeric types
public func <~∞~> <S1, S2, T1, T2 where S1: ReceiverType, S2: ReceiverType, S1.Pulse: ConduitNumericCoercible, S2.Pulse: ConduitNumericCoercible, T1: ConduitNumericCoercible, T2: ConduitNumericCoercible>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Receipt {
    return lhs.map({ convertNumericType($0) }).conduit(rhs.map({ convertNumericType($0) }))
}

/// Convert (possibly lossily) between optional and non-optional types
public func <~∞~> <S1, S2, T1, T2 where S1: ReceiverType, S2: ReceiverType, S1.Pulse == T2, S2.Pulse == T1>(lhs: Channel<S1, Optional<T1>>, rhs: Channel<S2, T2>) -> Receipt {
    return lhs.some().conduit(rhs)
}

public func <~∞~> <S1, S2, T1, T2 where S1: ReceiverType, S2: ReceiverType, S1.Pulse == T2, S2.Pulse == T1>(lhs: Channel<S1, T1>, rhs: Channel<S2, Optional<T2>>) -> Receipt {
    return lhs.conduit(rhs.some())
}


// MARK: KVO Operators

/// Creates a distinct sieved channel from the given Optional Equatable ValueTransceiver (cover for ∞?=)
public prefix func ∞= <T: Equatable>(source: KeyValueOptionalTransceiver<T>) -> Channel<KeyValueOptionalTransceiver<T>, T?> { return ∞?=source }

/// Creates a source for the given property that will emit state operations
public postfix func ∞ <T>(kvt: KeyValueTarget<T>) -> KeyValueTransceiver<T> {
    return KeyValueTransceiver(target: kvt)
}

/// Creates a source for the given equatable property that will emit state operations
public postfix func =∞ <T: Equatable>(kvt: KeyValueTarget<T>) -> KeyValueTransceiver<T> {
    return KeyValueTransceiver(target: kvt)
}

/// Creates a source for the given optional property that will emit state operations
public postfix func ∞ <T>(kvt: KeyValueTarget<T?>) -> KeyValueOptionalTransceiver<T> {
    return KeyValueOptionalTransceiver(target: kvt)
}

/// Creates a source for the given equatable & optional property that will emit state operations
public postfix func =∞ <T: Equatable>(kvt: KeyValueTarget<T?>) -> KeyValueOptionalTransceiver<T> {
    return KeyValueOptionalTransceiver(target: kvt)
}


// MARK: Infix operators

/// Use the specified accessor to determine the keyPath for the given autoclosure
/// For example, slider§slider.doubleValue will return: (slider, { slider.doubleValue }, "doubleValue")
public func § <T>(object: NSObject, @autoclosure getter: () -> T) -> KeyValueTarget<T> {
    return KeyValueTarget(target: object, initialValue: getter(), keyPath: conjectKeypath(object, getter, true)!)
}

/// Use the specified accessor to manually specify the keyPath for the given autoclosure
public func § <T>(object: NSObject, getkey: (value: T, keyPath: String)) -> KeyValueTarget<T> {
    return KeyValueTarget(target: object, initialValue: getkey.value, keyPath: getkey.keyPath)
}

infix operator § { precedence 255 }


/// Operation to create a channel from an object's keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, @autoclosure getter: () -> T) -> Channel<KeyValueTransceiver<T>, T> {
    return ∞(object§getter)∞
}

/// Operation to create a channel from an object's equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, @autoclosure getter: () -> T) -> Channel<KeyValueTransceiver<T>, T> {
    return ∞=(object§getter)=∞
}

/// Operation to create a channel from an object's optional keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, @autoclosure getter: () -> T?) -> Channel<KeyValueOptionalTransceiver<T>, T?> {
    return ∞(object§getter)∞
}

/// Operation to create a channel from an object's optional equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, @autoclosure getter: () -> T?) -> Channel<KeyValueOptionalTransceiver<T>, T?> {
    return ∞=(object§getter)=∞
}



/// Operation to create a channel from an object's keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, getpath: (value: T, keyPath: String)) -> Channel<KeyValueTransceiver<T>, T> {
    return ∞(object§getpath)∞
}

/// Operation to create a channel from an object's equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, getpath: (value: T, keyPath: String)) -> Channel<KeyValueTransceiver<T>, T> {
    return ∞=(object§getpath)=∞
}

/// Operation to create a channel from an object's optional keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, getpath: (value: T?, keyPath: String)) -> Channel<KeyValueOptionalTransceiver<T>, T?> {
    return ∞(object§getpath)∞
}

/// Operation to create a channel from an object's optional equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, getpath: (value: T?, keyPath: String)) -> Channel<KeyValueOptionalTransceiver<T>, T?> {
    return ∞=(object§getpath)=∞
}


infix operator ∞ { precedence 255 }


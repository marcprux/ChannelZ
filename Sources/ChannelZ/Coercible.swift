//
//  Channels.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import Foundation


/// A defaultable type is a type that can be initialized with no arguments and a default value
public protocol Defaultable {
    init(defaulting: ())
}

public extension _WrapperType {
    /// Returns the wrapped value or the defaulting value if the wrapped value if nil
    public subscript(defaulting constructor: @autoclosure () -> Wrapped) -> Wrapped {
        get { return self.flatMap({ $0 }) ?? constructor() }
        set { self = Self(newValue) }
    }
}

public extension _WrapperType where Wrapped : Defaultable {
    /// Returns the current value of the wrapped instance or, if nul, instantiates a default value
    public var defaulted: Wrapped {
        get { return self[defaulting: .init(defaulting: ())] }
        set { self = Self(newValue) }
    }
}

public extension RangeReplaceableCollection where Element : Defaultable {
    public var defaultedFirst: Element {
        get { return self.first[defaulting: .init(defaulting: ())] }
        set { self = Self([newValue] + dropFirst()) }
    }

    public subscript(defaulted index: Index) -> Element {
        get { return indices.contains(index) ? self[index] : .init(defaulting: ()) }

        set {
            // fill in the intervening indeices with the default value
            while !indices.contains(index) {
                append(.init(defaulting: ()))
            }
            // set the target index item
            replaceSubrange(index...index, with: [newValue])
        }
    }
}

public extension RangeReplaceableCollection where Self : BidirectionalCollection, Element : Defaultable {
    public var defaultedLast: Element {
        get { return self.last[defaulting: .init(defaulting: ())] }
        set { self = Self(dropLast() + [newValue]) }
    }
}

public extension Set where Element : Defaultable {
    public var defaultedAny: Element {
        get { return self.first ?? .init(defaulting: ()) }
        set { self = Set(dropFirst() + [newValue]) }
    }
}

extension ExpressibleByNilLiteral {
    /// An `ExpressibleByNilLiteral` conforms to `Defaultable` by nil initialization
    public init(defaulting: ()) { self.init(nilLiteral: ()) }
}

extension ExpressibleByArrayLiteral {
    /// An `ExpressibleByArrayLiteral` conforms to `Defaultable` by empty array initialization
    public init(defaulting: ()) { self.init() }
}

extension ExpressibleByDictionaryLiteral {
    /// An `ExpressibleByDictionaryLiteral` conforms to `Defaultable` by empty dictionary initialization
    public init(defaulting: ()) { self.init() }
}

extension Optional : Defaultable { } // inherits initializer from ExpressibleByNilLiteral
extension Set : Defaultable { } // inherits initializer from ExpressibleByArrayLiteral
extension Array : Defaultable { } // inherits initializer from ExpressibleByArrayLiteral
extension ContiguousArray : Defaultable { } // inherits initializer from ExpressibleByArrayLiteral
extension Dictionary : Defaultable { } // inherit initializer from ExpressibleByDictionaryLiteral

extension EmptyCollection : Defaultable { public init(defaulting: ()) { self.init() } }

public extension Defaultable where Self : Equatable {
    /// Returns true if this instance is the same as the defaulted value
    public var isDefaultedValue: Bool { return self == Self.init(defaulting: ()) }
}

/// Zips the two sequence together using `zip`, but first pads the shorter of the
/// sequences with the defaultable init so that they are both the same length
@inlinable public func zipWithPadding<Sequence1, Sequence2>(_ sequence1: Sequence1, _ sequence2: Sequence2) -> Zip2Sequence<[Sequence1.Element], [Sequence2.Element]> where Sequence1 : Sequence, Sequence1.Element : Defaultable, Sequence2 : Sequence, Sequence2.Element : Defaultable {
    var s1 = Array(sequence1)
    var s2 = Array(sequence2)
    while s1.count < s2.count { s1.append(.init(defaulting: ())) }
    while s2.count < s1.count { s2.append(.init(defaulting: ())) }
    return zip(s1, s2)
}


/// Dynamically convert between the given numeric types, getting past Swift's inability to statically cast between numbers
@inlinable public func convertNumericType<From : ConduitNumericCoercible, To : ConduitNumericCoercible>(_ from: From) -> To {
    // try both sides of the convertables so this can be extended by other types (such as NSNumber)
    return To.fromConduitNumericCoercible(from) ?? from.toConduitNumericCoercible() ?? from as! To
}

/// Implemented by numeric types that can be coerced into other numeric types
public protocol ConduitNumericCoercible {
    static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Self?
    func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T?
}


extension Bool : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Bool? {
        if let value = value as? Bool { return self.init(value) }
        else if let value = value as? Int8 { return self.init(value != 0) }
        else if let value = value as? UInt8 { return self.init(value != 0) }
        else if let value = value as? Int16 { return self.init(value != 0) }
        else if let value = value as? UInt16 { return self.init(value != 0) }
        else if let value = value as? Int32 { return self.init(value != 0) }
        else if let value = value as? UInt32 { return self.init(value != 0) }
        else if let value = value as? Int { return self.init(value != 0) }
        else if let value = value as? UInt { return self.init(value != 0) }
        else if let value = value as? Int64 { return self.init(value != 0) }
        else if let value = value as? UInt64 { return self.init(value != 0) }
        else if let value = value as? Float { return self.init(value != 0) }
        else if let value = value as? Double { return self.init(value != 0) }
        else { return value as? Bool }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self) as? T }
        else if T.self is Int8.Type { return Int8(self ? 1 : 0) as? T }
        else if T.self is UInt8.Type { return UInt8(self ? 1 : 0) as? T }
        else if T.self is Int16.Type { return Int16(self ? 1 : 0) as? T }
        else if T.self is UInt16.Type { return UInt16(self ? 1 : 0) as? T }
        else if T.self is Int32.Type { return Int32(self ? 1 : 0) as? T }
        else if T.self is UInt32.Type { return UInt32(self ? 1 : 0) as? T }
        else if T.self is Int.Type { return Int(self ? 1 : 0) as? T }
        else if T.self is UInt.Type { return UInt(self ? 1 : 0) as? T }
        else if T.self is Int64.Type { return Int64(self ? 1 : 0) as? T }
        else if T.self is UInt64.Type { return UInt64(self ? 1 : 0) as? T }
        else if T.self is Float.Type { return Float(self ? 1 : 0) as? T }
        else if T.self is Double.Type { return Double(self ? 1 : 0) as? T }
        else { return self as? T }
    }
}


extension Int8 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Int8? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int8 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt8 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> UInt8? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt8 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int16 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Int16? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int16 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt16 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> UInt16? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt16 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int32 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Int32? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int32 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt32 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> UInt32? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt32 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Int? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> UInt? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Int64 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Int64? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Int64 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension UInt64 : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> UInt64? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(abs(value)) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(abs(value)) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(abs(value)) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(abs(value)) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(abs(value)) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(abs(value)) }
        else if let value = value as? Double { return self.init(abs(value)) }
        else { return value as? UInt64 }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Float : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Float? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Float }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

extension Double : ConduitNumericCoercible {
    @inlinable public static func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Double? {
        if let value = value as? Bool { return self.init(value ? 1 : 0) }
        else if let value = value as? Int8 { return self.init(value) }
        else if let value = value as? UInt8 { return self.init(value) }
        else if let value = value as? Int16 { return self.init(value) }
        else if let value = value as? UInt16 { return self.init(value) }
        else if let value = value as? Int32 { return self.init(value) }
        else if let value = value as? UInt32 { return self.init(value) }
        else if let value = value as? Int { return self.init(value) }
        else if let value = value as? UInt { return self.init(value) }
        else if let value = value as? Int64 { return self.init(value) }
        else if let value = value as? UInt64 { return self.init(value) }
        else if let value = value as? Float { return self.init(value) }
        else if let value = value as? Double { return self.init(value) }
        else { return value as? Double }
    }

    @inlinable public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is Bool.Type { return Bool(self != 0) as? T }
        else if T.self is Int8.Type { return Int8(self) as? T }
        else if T.self is UInt8.Type { return UInt8(self) as? T }
        else if T.self is Int16.Type { return Int16(self) as? T }
        else if T.self is UInt16.Type { return UInt16(self) as? T }
        else if T.self is Int32.Type { return Int32(self) as? T }
        else if T.self is UInt32.Type { return UInt32(self) as? T }
        else if T.self is Int.Type { return Int(self) as? T }
        else if T.self is UInt.Type { return UInt(self) as? T }
        else if T.self is Int64.Type { return Int64(self) as? T }
        else if T.self is UInt64.Type { return UInt64(self) as? T }
        else if T.self is Float.Type { return Float(self) as? T }
        else if T.self is Double.Type { return Double(self) as? T }
        else { return self as? T }
    }
}

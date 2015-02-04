////
////  Channels.swift
////  ChannelZ
////
////  Created by Marc Prud'hommeaux <marc@glimpse.io>
////  License: MIT (or whatever)
////
//
//import Foundation
//
//
///// Dynamically convert between the given numeric types, getting past Swift's inability to statically cast between numbers
//public func convertNumericType<From : ConduitNumericCoercible, To : ConduitNumericCoercible>(from: From) -> To {
//    // try both sides of the convertables so this can be extended by other types (such as NSNumber)
//    return To.fromConduitNumericCoercible(from) ?? from.toConduitNumericCoercible() ?? from as To
//}
//
//
///// Implemented by numeric types that can be coerced into other numeric types
//public protocol ConduitNumericCoercible {
//    class func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Self?
//    func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T?
//}
//
//
//extension Bool : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Bool? {
//        if let value = value as? Bool { return self.init(value) }
//        else if let value = value as? Int8 { return self.init(value != 0) }
//        else if let value = value as? UInt8 { return self.init(value != 0) }
//        else if let value = value as? Int16 { return self.init(value != 0) }
//        else if let value = value as? UInt16 { return self.init(value != 0) }
//        else if let value = value as? Int32 { return self.init(value != 0) }
//        else if let value = value as? UInt32 { return self.init(value != 0) }
//        else if let value = value as? Int { return self.init(value != 0) }
//        else if let value = value as? UInt { return self.init(value != 0) }
//        else if let value = value as? Int64 { return self.init(value != 0) }
//        else if let value = value as? UInt64 { return self.init(value != 0) }
//        else if let value = value as? Float { return self.init(value != 0) }
//        else if let value = value as? Double { return self.init(value != 0) }
//        else { return value as? Bool }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self) as? T }
//        else if T.self is Int8.Type { return Int8(self ? 1 : 0) as? T }
//        else if T.self is UInt8.Type { return UInt8(self ? 1 : 0) as? T }
//        else if T.self is Int16.Type { return Int16(self ? 1 : 0) as? T }
//        else if T.self is UInt16.Type { return UInt16(self ? 1 : 0) as? T }
//        else if T.self is Int32.Type { return Int32(self ? 1 : 0) as? T }
//        else if T.self is UInt32.Type { return UInt32(self ? 1 : 0) as? T }
//        else if T.self is Int.Type { return Int(self ? 1 : 0) as? T }
//        else if T.self is UInt.Type { return UInt(self ? 1 : 0) as? T }
//        else if T.self is Int64.Type { return Int64(self ? 1 : 0) as? T }
//        else if T.self is UInt64.Type { return UInt64(self ? 1 : 0) as? T }
//        else if T.self is Float.Type { return Float(self ? 1 : 0) as? T }
//        else if T.self is Double.Type { return Double(self ? 1 : 0) as? T }
//        else { return self as? T }
//    }
//}
//
//
//extension Int8 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int8? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Int8 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension UInt8 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt8? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(abs(value)) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(abs(value)) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(abs(value)) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(abs(value)) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(abs(value)) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(abs(value)) }
//        else if let value = value as? Double { return self.init(abs(value)) }
//        else { return value as? UInt8 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Int16 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int16? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Int16 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension UInt16 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt16? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(abs(value)) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(abs(value)) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(abs(value)) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(abs(value)) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(abs(value)) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(abs(value)) }
//        else if let value = value as? Double { return self.init(abs(value)) }
//        else { return value as? UInt16 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Int32 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int32? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Int32 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension UInt32 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt32? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(abs(value)) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(abs(value)) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(abs(value)) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(abs(value)) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(abs(value)) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(abs(value)) }
//        else if let value = value as? Double { return self.init(abs(value)) }
//        else { return value as? UInt32 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Int : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Int }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension UInt : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(abs(value)) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(abs(value)) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(abs(value)) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(abs(value)) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(abs(value)) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(abs(value)) }
//        else if let value = value as? Double { return self.init(abs(value)) }
//        else { return value as? UInt }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Int64 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Int64? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Int64 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension UInt64 : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> UInt64? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(abs(value)) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(abs(value)) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(abs(value)) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(abs(value)) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(abs(value)) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(abs(value)) }
//        else if let value = value as? Double { return self.init(abs(value)) }
//        else { return value as? UInt64 }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Float : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Float? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Float }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}
//
//extension Double : ConduitNumericCoercible {
//    public static func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Double? {
//        if let value = value as? Bool { return self.init(value ? 1 : 0) }
//        else if let value = value as? Int8 { return self.init(value) }
//        else if let value = value as? UInt8 { return self.init(value) }
//        else if let value = value as? Int16 { return self.init(value) }
//        else if let value = value as? UInt16 { return self.init(value) }
//        else if let value = value as? Int32 { return self.init(value) }
//        else if let value = value as? UInt32 { return self.init(value) }
//        else if let value = value as? Int { return self.init(value) }
//        else if let value = value as? UInt { return self.init(value) }
//        else if let value = value as? Int64 { return self.init(value) }
//        else if let value = value as? UInt64 { return self.init(value) }
//        else if let value = value as? Float { return self.init(value) }
//        else if let value = value as? Double { return self.init(value) }
//        else { return value as? Double }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is Bool.Type { return Bool(self != 0) as? T }
//        else if T.self is Int8.Type { return Int8(self) as? T }
//        else if T.self is UInt8.Type { return UInt8(self) as? T }
//        else if T.self is Int16.Type { return Int16(self) as? T }
//        else if T.self is UInt16.Type { return UInt16(self) as? T }
//        else if T.self is Int32.Type { return Int32(self) as? T }
//        else if T.self is UInt32.Type { return UInt32(self) as? T }
//        else if T.self is Int.Type { return Int(self) as? T }
//        else if T.self is UInt.Type { return UInt(self) as? T }
//        else if T.self is Int64.Type { return Int64(self) as? T }
//        else if T.self is UInt64.Type { return UInt64(self) as? T }
//        else if T.self is Float.Type { return Float(self) as? T }
//        else if T.self is Double.Type { return Double(self) as? T }
//        else { return self as? T }
//    }
//}

//
//  Combinators.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 4/5/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

// Swift 4 TODO: Variadic Generics: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#variadic-generics

/// One of a set number of options; simulates a union of arbitrarity arity
public protocol ChooseNType {
    /// Returns the number of choices
    var arity: Int { get }

    /// The first type in thie choice; also the primary type, in that it will be the subject of `firstMap`
    associatedtype T1
    var v1: T1? { get set }
}

public extension ChooseNType {
    /// Similar to `flatMap`, except it will call the function when the element of this
    /// type is the T1 type, and null if it is any other type (T2, T3, ...)
    public func firstMap<U>(_ f: (T1) throws -> U?) rethrows -> U? {
        if let value = self.v1 {
            return try f(value)
        } else {
            return nil
        }
    }
}

/// One of at least 2 options
public protocol Choose2Type : ChooseNType {
    associatedtype T2
    var v2: T2? { get set }
}

/// An error that indicates that multiple errors occured when decoding the type;
/// Each error should correspond to one of the choices for this type.
public struct ChoiceDecodingError : Error {
    public let errors: [Error]
}


/// One of exactly 2 options
public enum Choose2<T1, T2>: Choose2Type {
    public var arity: Int { return 2 }

    /// First of 2
    case v1(T1)
    /// Second of 2
    case v2(T2)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
        
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

}

public extension Choose2 where T1 == T2 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        }
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose2 /*: Encodable*/ where T1 : Encodable, T2 : Encodable {

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        }
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose2 /*: Decodable*/ where T1 : Decodable, T2 : Decodable {

    public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError(errors: errors)
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose2 /*: Equatable*/ where T1 : Equatable, T2 : Equatable {

    public static func ==(lhs: Choose2<T1, T2>, rhs: Choose2<T1, T2>) -> Bool {
        switch (lhs, rhs) {
        case (.v1(let a), .v1(let b)): return a == b
        case (.v2(let a), .v2(let b)): return a == b
        default: return false
        }
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose2 /*: Hashable*/ where T1 : Hashable, T2 : Hashable { // Swift 4.1 TODO: conditional conformance

    public var hashValue: Int {
        switch self {
        case .v1(let x): return x.hashValue
        case .v2(let x): return x.hashValue
        }
    }
}

/// One of at least 3 options
public protocol Choose3Type : Choose2Type {
    associatedtype T3
    var v3: T3? { get set }
}

/// One of exactly 3 options
public enum Choose3<T1, T2, T3>: Choose3Type {
    public var arity: Int { return 3 }

    /// First of 3
    case v1(T1)
    /// Second of 3
    case v2(T2)
    /// Third of 3
    case v3(T3)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<T1, T2>, T3> {
        switch self {
        case .v1(let v): return .v1(.v1(v))
        case .v2(let v): return .v1(.v2(v))
        case .v3(let v): return .v2(v)
        }
    }
}

public extension Choose3 where T1 == T2, T2 == T3 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        }
    }
}

/// One of at least 4 options
public protocol Choose4Type : Choose3Type {
    associatedtype T4
    var v4: T4? { get set }
}

/// One of exactly 4 options
public enum Choose4<T1, T2, T3, T4>: Choose4Type {
    public var arity: Int { return 4 }

    /// First of 4
    case v1(T1)
    /// Second of 4
    case v2(T2)
    /// Third of 4
    case v3(T3)
    /// Fourth of 4
    case v4(T4)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<T1, T2>, T3>, T4> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(v)))
        case .v2(let v): return .v1(.v1(.v2(v)))
        case .v3(let v): return .v1(.v2(v))
        case .v4(let v): return .v2(v)
        }
    }
}

public extension Choose4 where T1 == T2, T2 == T3, T3 == T4 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        }
    }
}

/// One of at least 5 options
public protocol Choose5Type : Choose4Type {
    associatedtype T5
    var v5: T5? { get set }
}

/// One of exactly 5 options
public enum Choose5<T1, T2, T3, T4, T5>: Choose5Type {
    public var arity: Int { return 5 }

    /// First of 5
    case v1(T1)
    /// Second of 5
    case v2(T2)
    /// Third of 5
    case v3(T3)
    /// Fourth of 5
    case v4(T4)
    /// Fifth of 5
    case v5(T5)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(v))))
        case .v2(let v): return .v1(.v1(.v1(.v2(v))))
        case .v3(let v): return .v1(.v1(.v2(v)))
        case .v4(let v): return .v1(.v2(v))
        case .v5(let v): return .v2(v)
        }
    }
}

public extension Choose5 where T1 == T2, T2 == T3, T3 == T4, T4 == T5 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        }
    }
}

/// One of at least 6 options
public protocol Choose6Type : Choose5Type {
    associatedtype T6
    var v6: T6? { get set }
}

/// One of exactly 6 options
public enum Choose6<T1, T2, T3, T4, T5, T6>: Choose6Type {
    public var arity: Int { return 6 }

    /// First of 6
    case v1(T1)
    /// Second of 6
    case v2(T2)
    /// Third of 6
    case v3(T3)
    /// Fourth of 6
    case v4(T4)
    /// Fifth of 6
    case v5(T5)
    /// Sixth of 6
    case v6(T6)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(v)))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v3(let v): return .v1(.v1(.v1(.v2(v))))
        case .v4(let v): return .v1(.v1(.v2(v)))
        case .v5(let v): return .v1(.v2(v))
        case .v6(let v): return .v2(v)
        }
    }
}

public extension Choose6 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        }
    }
}

/// One of at least 7 options
public protocol Choose7Type : Choose6Type {
    associatedtype T7
    var v7: T7? { get set }
}

/// One of exactly 7 options
public enum Choose7<T1, T2, T3, T4, T5, T6, T7>: Choose7Type {
    public var arity: Int { return 7 }

    /// First of 7
    case v1(T1)
    /// Second of 7
    case v2(T2)
    /// Third of 7
    case v3(T3)
    /// Fourth of 7
    case v4(T4)
    /// Fifth of 7
    case v5(T5)
    /// Sixth of 7
    case v6(T6)
    /// Seventh of 7
    case v7(T7)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(v))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v4(let v): return .v1(.v1(.v1(.v2(v))))
        case .v5(let v): return .v1(.v1(.v2(v)))
        case .v6(let v): return .v1(.v2(v))
        case .v7(let v): return .v2(v)
        }
    }
}

public extension Choose7 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        }
    }
}

/// One of at least 8 options
public protocol Choose8Type : Choose7Type {
    associatedtype T8
    var v8: T8? { get set }
}

/// One of exactly 8 options
public enum Choose8<T1, T2, T3, T4, T5, T6, T7, T8>: Choose8Type {
    public var arity: Int { return 8 }

    /// First of 8
    case v1(T1)
    /// Second of 8
    case v2(T2)
    /// Third of 8
    case v3(T3)
    /// Fourth of 8
    case v4(T4)
    /// Fifth of 8
    case v5(T5)
    /// Sixth of 8
    case v6(T6)
    /// Seventh of 8
    case v7(T7)
    /// Eighth of 8
    case v8(T8)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v5(let v): return .v1(.v1(.v1(.v2(v))))
        case .v6(let v): return .v1(.v1(.v2(v)))
        case .v7(let v): return .v1(.v2(v))
        case .v8(let v): return .v2(v)
        }
    }
}

public extension Choose8 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        }
    }
}

/// One of at least 9 options
public protocol Choose9Type : Choose8Type {
    associatedtype T9
    var v9: T9? { get set }
}

/// One of exactly 9 options
public enum Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>: Choose9Type {
    public var arity: Int { return 9 }

    /// First of 9
    case v1(T1)
    /// Second of 9
    case v2(T2)
    /// Third of 9
    case v3(T3)
    /// Fourth of 9
    case v4(T4)
    /// Fifth of 9
    case v5(T5)
    /// Sixth of 9
    case v6(T6)
    /// Seventh of 9
    case v7(T7)
    /// Eighth of 9
    case v8(T8)
    /// Ninth of 9
    case v9(T9)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v6(let v): return .v1(.v1(.v1(.v2(v))))
        case .v7(let v): return .v1(.v1(.v2(v)))
        case .v8(let v): return .v1(.v2(v))
        case .v9(let v): return .v2(v)
        }
    }
}

public extension Choose9 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        }
    }
}

/// One of at least 10 options
public protocol Choose10Type : Choose9Type {
    associatedtype T10
    var v10: T10? { get set }
}

/// One of exactly 10 options
public enum Choose10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>: Choose10Type {
    public var arity: Int { return 10 }

    /// First of 10
    case v1(T1)
    /// Second of 10
    case v2(T2)
    /// Third of 10
    case v3(T3)
    /// Fourth of 10
    case v4(T4)
    /// Fifth of 10
    case v5(T5)
    /// Sixth of 10
    case v6(T6)
    /// Seventh of 10
    case v7(T7)
    /// Eighth of 10
    case v8(T8)
    /// Ninth of 10
    case v9(T9)
    /// Tenth of 10
    case v10(T10)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v7(let v): return .v1(.v1(.v1(.v2(v))))
        case .v8(let v): return .v1(.v1(.v2(v)))
        case .v9(let v): return .v1(.v2(v))
        case .v10(let v): return .v2(v)
        }
    }
}

public extension Choose10 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        }
    }
}

/// One of at least 11 options
public protocol Choose11Type : Choose10Type {
    associatedtype T11
    var v11: T11? { get set }
}

/// One of exactly 11 options
public enum Choose11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>: Choose11Type {
    public var arity: Int { return 11 }

    /// First of 11
    case v1(T1)
    /// Second of 11
    case v2(T2)
    /// Third of 11
    case v3(T3)
    /// Fourth of 11
    case v4(T4)
    /// Fifth of 11
    case v5(T5)
    /// Sixth of 11
    case v6(T6)
    /// Seventh of 11
    case v7(T7)
    /// Eighth of 11
    case v8(T8)
    /// Ninth of 11
    case v9(T9)
    /// Tenth of 11
    case v10(T10)
    /// Eleventh of 11
    case v11(T11)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v8(let v): return .v1(.v1(.v1(.v2(v))))
        case .v9(let v): return .v1(.v1(.v2(v)))
        case .v10(let v): return .v1(.v2(v))
        case .v11(let v): return .v2(v)
        }
    }
}

public extension Choose11 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        }
    }
}

/// One of at least 12 options
public protocol Choose12Type : Choose11Type {
    associatedtype T12
    var v12: T12? { get set }
}

/// One of exactly 12 options
public enum Choose12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>: Choose12Type {
    public var arity: Int { return 12 }

    /// First of 12
    case v1(T1)
    /// Second of 12
    case v2(T2)
    /// Third of 12
    case v3(T3)
    /// Fourth of 12
    case v4(T4)
    /// Fifth of 12
    case v5(T5)
    /// Sixth of 12
    case v6(T6)
    /// Seventh of 12
    case v7(T7)
    /// Eighth of 12
    case v8(T8)
    /// Ninth of 12
    case v9(T9)
    /// Tenth of 12
    case v10(T10)
    /// Eleventh of 12
    case v11(T11)
    /// Twelfth of 12
    case v12(T12)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v9(let v): return .v1(.v1(.v1(.v2(v))))
        case .v10(let v): return .v1(.v1(.v2(v)))
        case .v11(let v): return .v1(.v2(v))
        case .v12(let v): return .v2(v)
        }
    }
}

public extension Choose12 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        }
    }
}

/// One of at least 13 options
public protocol Choose13Type : Choose12Type {
    associatedtype T13
    var v13: T13? { get set }
}

/// One of exactly 13 options
public enum Choose13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>: Choose13Type {
    public var arity: Int { return 13 }

    /// First of 13
    case v1(T1)
    /// Second of 13
    case v2(T2)
    /// Third of 13
    case v3(T3)
    /// Fourth of 13
    case v4(T4)
    /// Fifth of 13
    case v5(T5)
    /// Sixth of 13
    case v6(T6)
    /// Seventh of 13
    case v7(T7)
    /// Eighth of 13
    case v8(T8)
    /// Ninth of 13
    case v9(T9)
    /// Tenth of 13
    case v10(T10)
    /// Eleventh of 13
    case v11(T11)
    /// Twelfth of 13
    case v12(T12)
    /// Thirteenth of 13
    case v13(T13)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v10(let v): return .v1(.v1(.v1(.v2(v))))
        case .v11(let v): return .v1(.v1(.v2(v)))
        case .v12(let v): return .v1(.v2(v))
        case .v13(let v): return .v2(v)
        }
    }
}

public extension Choose13 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        }
    }
}

/// One of at least 14 options
public protocol Choose14Type : Choose13Type {
    associatedtype T14
    var v14: T14? { get set }
}

/// One of exactly 14 options
public enum Choose14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>: Choose14Type {
    public var arity: Int { return 14 }

    /// First of 14
    case v1(T1)
    /// Second of 14
    case v2(T2)
    /// Third of 14
    case v3(T3)
    /// Fourth of 14
    case v4(T4)
    /// Fifth of 14
    case v5(T5)
    /// Sixth of 14
    case v6(T6)
    /// Seventh of 14
    case v7(T7)
    /// Eighth of 14
    case v8(T8)
    /// Ninth of 14
    case v9(T9)
    /// Tenth of 14
    case v10(T10)
    /// Eleventh of 14
    case v11(T11)
    /// Twelfth of 14
    case v12(T12)
    /// Thirteenth of 14
    case v13(T13)
    /// Fourteenth of 14
    case v14(T14)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v11(let v): return .v1(.v1(.v1(.v2(v))))
        case .v12(let v): return .v1(.v1(.v2(v)))
        case .v13(let v): return .v1(.v2(v))
        case .v14(let v): return .v2(v)
        }
    }
}

public extension Choose14 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        }
    }
}

/// One of at least 15 options
public protocol Choose15Type : Choose14Type {
    associatedtype T15
    var v15: T15? { get set }
}

/// One of exactly 15 options
public enum Choose15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>: Choose15Type {
    public var arity: Int { return 15 }

    /// First of 15
    case v1(T1)
    /// Second of 15
    case v2(T2)
    /// Third of 15
    case v3(T3)
    /// Fourth of 15
    case v4(T4)
    /// Fifth of 15
    case v5(T5)
    /// Sixth of 15
    case v6(T6)
    /// Seventh of 15
    case v7(T7)
    /// Eighth of 15
    case v8(T8)
    /// Ninth of 15
    case v9(T9)
    /// Tenth of 15
    case v10(T10)
    /// Eleventh of 15
    case v11(T11)
    /// Twelfth of 15
    case v12(T12)
    /// Thirteenth of 15
    case v13(T13)
    /// Fourteenth of 15
    case v14(T14)
    /// Fifteenth of 15
    case v15(T15)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v12(let v): return .v1(.v1(.v1(.v2(v))))
        case .v13(let v): return .v1(.v1(.v2(v)))
        case .v14(let v): return .v1(.v2(v))
        case .v15(let v): return .v2(v)
        }
    }
}

public extension Choose15 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        }
    }
}

/// One of at least 16 options
public protocol Choose16Type : Choose15Type {
    associatedtype T16
    var v16: T16? { get set }
}

/// One of exactly 16 options
public enum Choose16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>: Choose16Type {
    public var arity: Int { return 16 }

    /// First of 16
    case v1(T1)
    /// Second of 16
    case v2(T2)
    /// Third of 16
    case v3(T3)
    /// Fourth of 16
    case v4(T4)
    /// Fifth of 16
    case v5(T5)
    /// Sixth of 16
    case v6(T6)
    /// Seventh of 16
    case v7(T7)
    /// Eighth of 16
    case v8(T8)
    /// Ninth of 16
    case v9(T9)
    /// Tenth of 16
    case v10(T10)
    /// Eleventh of 16
    case v11(T11)
    /// Twelfth of 16
    case v12(T12)
    /// Thirteenth of 16
    case v13(T13)
    /// Fourteenth of 16
    case v14(T14)
    /// Fifteenth of 16
    case v15(T15)
    /// Sixteenth of 16
    case v16(T16)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    public init(t16: T16) { self = .v16(t16) }
    public init(_ t16: T16) { self = .v16(t16) }
    
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    public var v16: T16? {
        get { if case .v16(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v16(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v12(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v13(let v): return .v1(.v1(.v1(.v2(v))))
        case .v14(let v): return .v1(.v1(.v2(v)))
        case .v15(let v): return .v1(.v2(v))
        case .v16(let v): return .v2(v)
        }
    }
}

public extension Choose16 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15, T15 == T16 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        case .v16(let x): return x
        }
    }
}

/// One of at least 17 options
public protocol Choose17Type : Choose16Type {
    associatedtype T17
    var v17: T17? { get set }
}

/// One of exactly 17 options
public enum Choose17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>: Choose17Type {
    public var arity: Int { return 17 }

    /// First of 17
    case v1(T1)
    /// Second of 17
    case v2(T2)
    /// Third of 17
    case v3(T3)
    /// Fourth of 17
    case v4(T4)
    /// Fifth of 17
    case v5(T5)
    /// Sixth of 17
    case v6(T6)
    /// Seventh of 17
    case v7(T7)
    /// Eighth of 17
    case v8(T8)
    /// Ninth of 17
    case v9(T9)
    /// Tenth of 17
    case v10(T10)
    /// Eleventh of 17
    case v11(T11)
    /// Twelfth of 17
    case v12(T12)
    /// Thirteenth of 17
    case v13(T13)
    /// Fourteenth of 17
    case v14(T14)
    /// Fifteenth of 17
    case v15(T15)
    /// Sixteenth of 17
    case v16(T16)
    /// Seventeenth of 17
    case v17(T17)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    public init(t16: T16) { self = .v16(t16) }
    public init(_ t16: T16) { self = .v16(t16) }
    
    public init(t17: T17) { self = .v17(t17) }
    public init(_ t17: T17) { self = .v17(t17) }
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    public var v16: T16? {
        get { if case .v16(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v16(x) } }
    }

    public var v17: T17? {
        get { if case .v17(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v17(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v12(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v13(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v14(let v): return .v1(.v1(.v1(.v2(v))))
        case .v15(let v): return .v1(.v1(.v2(v)))
        case .v16(let v): return .v1(.v2(v))
        case .v17(let v): return .v2(v)
        }
    }
}

public extension Choose17 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15, T15 == T16, T16 == T17 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        case .v16(let x): return x
        case .v17(let x): return x
        }
    }
}

/// One of at least 18 options
public protocol Choose18Type : Choose17Type {
    associatedtype T18
    var v18: T18? { get set }
}

/// One of exactly 18 options
public enum Choose18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>: Choose18Type {
    public var arity: Int { return 18 }

    /// First of 18
    case v1(T1)
    /// Second of 18
    case v2(T2)
    /// Third of 18
    case v3(T3)
    /// Fourth of 18
    case v4(T4)
    /// Fifth of 18
    case v5(T5)
    /// Sixth of 18
    case v6(T6)
    /// Seventh of 18
    case v7(T7)
    /// Eighth of 18
    case v8(T8)
    /// Ninth of 18
    case v9(T9)
    /// Tenth of 18
    case v10(T10)
    /// Eleventh of 18
    case v11(T11)
    /// Twelfth of 18
    case v12(T12)
    /// Thirteenth of 18
    case v13(T13)
    /// Fourteenth of 18
    case v14(T14)
    /// Fifteenth of 18
    case v15(T15)
    /// Sixteenth of 18
    case v16(T16)
    /// Seventeenth of 18
    case v17(T17)
    /// Eighteenth of 18
    case v18(T18)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    public init(t16: T16) { self = .v16(t16) }
    public init(_ t16: T16) { self = .v16(t16) }
    
    public init(t17: T17) { self = .v17(t17) }
    public init(_ t17: T17) { self = .v17(t17) }
    
    public init(t18: T18) { self = .v18(t18) }
    public init(_ t18: T18) { self = .v18(t18) }
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    public var v16: T16? {
        get { if case .v16(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v16(x) } }
    }

    public var v17: T17? {
        get { if case .v17(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v17(x) } }
    }

    public var v18: T18? {
        get { if case .v18(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v18(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v12(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v13(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v14(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v15(let v): return .v1(.v1(.v1(.v2(v))))
        case .v16(let v): return .v1(.v1(.v2(v)))
        case .v17(let v): return .v1(.v2(v))
        case .v18(let v): return .v2(v)
        }
    }
}

public extension Choose18 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15, T15 == T16, T16 == T17, T17 == T18 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        case .v16(let x): return x
        case .v17(let x): return x
        case .v18(let x): return x
        }
    }
}

/// One of at least 19 options
public protocol Choose19Type : Choose18Type {
    associatedtype T19
    var v19: T19? { get set }
}

/// One of exactly 19 options
public enum Choose19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>: Choose19Type {
    public var arity: Int { return 19 }

    /// First of 19
    case v1(T1)
    /// Second of 19
    case v2(T2)
    /// Third of 19
    case v3(T3)
    /// Fourth of 19
    case v4(T4)
    /// Fifth of 19
    case v5(T5)
    /// Sixth of 19
    case v6(T6)
    /// Seventh of 19
    case v7(T7)
    /// Eighth of 19
    case v8(T8)
    /// Ninth of 19
    case v9(T9)
    /// Tenth of 19
    case v10(T10)
    /// Eleventh of 19
    case v11(T11)
    /// Twelfth of 19
    case v12(T12)
    /// Thirteenth of 19
    case v13(T13)
    /// Fourteenth of 19
    case v14(T14)
    /// Fifteenth of 19
    case v15(T15)
    /// Sixteenth of 19
    case v16(T16)
    /// Seventeenth of 19
    case v17(T17)
    /// Eighteenth of 19
    case v18(T18)
    /// Nineteenth of 19
    case v19(T19)


    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    public init(t16: T16) { self = .v16(t16) }
    public init(_ t16: T16) { self = .v16(t16) }
    
    public init(t17: T17) { self = .v17(t17) }
    public init(_ t17: T17) { self = .v17(t17) }
    
    public init(t18: T18) { self = .v18(t18) }
    public init(_ t18: T18) { self = .v18(t18) }
    
    public init(t19: T19) { self = .v19(t19) }
    public init(_ t19: T19) { self = .v19(t19) }
    
    
    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    public var v16: T16? {
        get { if case .v16(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v16(x) } }
    }

    public var v17: T17? {
        get { if case .v17(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v17(x) } }
    }

    public var v18: T18? {
        get { if case .v18(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v18(x) } }
    }

    public var v19: T19? {
        get { if case .v19(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v19(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18>, T19> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v))))))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v12(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v13(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v14(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v15(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v16(let v): return .v1(.v1(.v1(.v2(v))))
        case .v17(let v): return .v1(.v1(.v2(v)))
        case .v18(let v): return .v1(.v2(v))
        case .v19(let v): return .v2(v)
        }
    }
}

public extension Choose19 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15, T15 == T16, T16 == T17, T17 == T18, T18 == T19 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        case .v16(let x): return x
        case .v17(let x): return x
        case .v18(let x): return x
        case .v19(let x): return x
        }
    }
}

/// One of at least 20 options
public protocol Choose20Type : Choose19Type {
    associatedtype T20
    var v20: T20? { get set }
}

/// One of exactly 20 options
public enum Choose20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>: Choose20Type {
    public var arity: Int { return 20 }

    /// First of 20
    case v1(T1)
    /// Second of 20
    case v2(T2)
    /// Third of 20
    case v3(T3)
    /// Fourth of 20
    case v4(T4)
    /// Fifth of 20
    case v5(T5)
    /// Sixth of 20
    case v6(T6)
    /// Seventh of 20
    case v7(T7)
    /// Eighth of 20
    case v8(T8)
    /// Ninth of 20
    case v9(T9)
    /// Tenth of 20
    case v10(T10)
    /// Eleventh of 20
    case v11(T11)
    /// Twelfth of 20
    case v12(T12)
    /// Thirteenth of 20
    case v13(T13)
    /// Fourteenth of 20
    case v14(T14)
    /// Fifteenth of 20
    case v15(T15)
    /// Sixteenth of 20
    case v16(T16)
    /// Seventeenth of 20
    case v17(T17)
    /// Eighteenth of 20
    case v18(T18)
    /// Nineteenth of 20
    case v19(T19)
    /// Twentieth of 20
    case v20(T20)

    public init(t1: T1) { self = .v1(t1) }
    public init(_ t1: T1) { self = .v1(t1) }
    
    public init(t2: T2) { self = .v2(t2) }
    public init(_ t2: T2) { self = .v2(t2) }
    
    public init(t3: T3) { self = .v3(t3) }
    public init(_ t3: T3) { self = .v3(t3) }
    
    public init(t4: T4) { self = .v4(t4) }
    public init(_ t4: T4) { self = .v4(t4) }
    
    public init(t5: T5) { self = .v5(t5) }
    public init(_ t5: T5) { self = .v5(t5) }
    
    public init(t6: T6) { self = .v6(t6) }
    public init(_ t6: T6) { self = .v6(t6) }
    
    public init(t7: T7) { self = .v7(t7) }
    public init(_ t7: T7) { self = .v7(t7) }
    
    public init(t8: T8) { self = .v8(t8) }
    public init(_ t8: T8) { self = .v8(t8) }
    
    public init(t9: T9) { self = .v9(t9) }
    public init(_ t9: T9) { self = .v9(t9) }
    
    public init(t10: T10) { self = .v10(t10) }
    public init(_ t10: T10) { self = .v10(t10) }
    
    public init(t11: T11) { self = .v11(t11) }
    public init(_ t11: T11) { self = .v11(t11) }
    
    public init(t12: T12) { self = .v12(t12) }
    public init(_ t12: T12) { self = .v12(t12) }
    
    public init(t13: T13) { self = .v13(t13) }
    public init(_ t13: T13) { self = .v13(t13) }
    
    public init(t14: T14) { self = .v14(t14) }
    public init(_ t14: T14) { self = .v14(t14) }
    
    public init(t15: T15) { self = .v15(t15) }
    public init(_ t15: T15) { self = .v15(t15) }
    
    public init(t16: T16) { self = .v16(t16) }
    public init(_ t16: T16) { self = .v16(t16) }
    
    public init(t17: T17) { self = .v17(t17) }
    public init(_ t17: T17) { self = .v17(t17) }
    
    public init(t18: T18) { self = .v18(t18) }
    public init(_ t18: T18) { self = .v18(t18) }
    
    public init(t19: T19) { self = .v19(t19) }
    public init(_ t19: T19) { self = .v19(t19) }
    
    public init(t20: T20) { self = .v20(t20) }
    public init(_ t20: T20) { self = .v20(t20) }
    

    public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    public var v11: T11? {
        get { if case .v11(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v11(x) } }
    }

    public var v12: T12? {
        get { if case .v12(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v12(x) } }
    }

    public var v13: T13? {
        get { if case .v13(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v13(x) } }
    }

    public var v14: T14? {
        get { if case .v14(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v14(x) } }
    }

    public var v15: T15? {
        get { if case .v15(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v15(x) } }
    }

    public var v16: T16? {
        get { if case .v16(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v16(x) } }
    }

    public var v17: T17? {
        get { if case .v17(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v17(x) } }
    }

    public var v18: T18? {
        get { if case .v18(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v18(x) } }
    }

    public var v19: T19? {
        get { if case .v19(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v19(x) } }
    }

    public var v20: T20? {
        get { if case .v20(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v20(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10>, T11>, T12>, T13>, T14>, T15>, T16>, T17>, T18>, T19>, T20> {
        switch self {
        case .v1(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(v)))))))))))))))))))
        case .v2(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))))))
        case .v3(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))))
        case .v4(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))))
        case .v5(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))))
        case .v6(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))))
        case .v7(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))))
        case .v8(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))))
        case .v9(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))))
        case .v10(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))))
        case .v11(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))))
        case .v12(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))))
        case .v13(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v1(.v2(v))))))))
        case .v14(let v): return .v1(.v1(.v1(.v1(.v1(.v1(.v2(v)))))))
        case .v15(let v): return .v1(.v1(.v1(.v1(.v1(.v2(v))))))
        case .v16(let v): return .v1(.v1(.v1(.v1(.v2(v)))))
        case .v17(let v): return .v1(.v1(.v1(.v2(v))))
        case .v18(let v): return .v1(.v1(.v2(v)))
        case .v19(let v): return .v1(.v2(v))
        case .v20(let v): return .v2(v)
        }
    }
}

public extension Choose20 where T1 == T2, T2 == T3, T3 == T4, T4 == T5, T5 == T6, T6 == T7, T7 == T8, T8 == T9, T9 == T10, T10 == T11, T11 == T12, T12 == T13, T13 == T14, T14 == T15, T15 == T16, T16 == T17, T17 == T18, T18 == T19, T19 == T20 {
    /// When a ChooseN type wraps the same value types, returns the single value
    public var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        case .v6(let x): return x
        case .v7(let x): return x
        case .v8(let x): return x
        case .v9(let x): return x
        case .v10(let x): return x
        case .v11(let x): return x
        case .v12(let x): return x
        case .v13(let x): return x
        case .v14(let x): return x
        case .v15(let x): return x
        case .v16(let x): return x
        case .v17(let x): return x
        case .v18(let x): return x
        case .v19(let x): return x
        case .v20(let x): return x
        }
    }

}

// Swift 4.1 TODO: conditional conformance
extension Choose20 /*: Encodable*/ where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable, T7 : Encodable, T8 : Encodable, T9 : Encodable, T10 : Encodable, T11 : Encodable, T12 : Encodable, T13 : Encodable, T14 : Encodable, T15 : Encodable, T16 : Encodable, T17 : Encodable, T18 : Encodable, T19 : Encodable, T20 : Encodable {

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        case .v5(let x): try x.encode(to: encoder)
        case .v6(let x): try x.encode(to: encoder)
        case .v7(let x): try x.encode(to: encoder)
        case .v8(let x): try x.encode(to: encoder)
        case .v9(let x): try x.encode(to: encoder)
        case .v10(let x): try x.encode(to: encoder)
        case .v11(let x): try x.encode(to: encoder)
        case .v12(let x): try x.encode(to: encoder)
        case .v13(let x): try x.encode(to: encoder)
        case .v14(let x): try x.encode(to: encoder)
        case .v15(let x): try x.encode(to: encoder)
        case .v16(let x): try x.encode(to: encoder)
        case .v17(let x): try x.encode(to: encoder)
        case .v18(let x): try x.encode(to: encoder)
        case .v19(let x): try x.encode(to: encoder)
        case .v20(let x): try x.encode(to: encoder)
        }
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose20 /*: Decodable*/ where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable, T7 : Decodable, T8 : Decodable, T9 : Decodable, T10 : Decodable, T11 : Decodable, T12 : Decodable, T13 : Decodable, T14 : Decodable, T15 : Decodable, T16 : Decodable, T17 : Decodable, T18 : Decodable, T19 : Decodable, T20 : Decodable {

    public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v5(T5(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v6(T6(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v7(T7(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v8(T8(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v9(T9(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v10(T10(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v11(T11(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v12(T12(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v13(T13(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v14(T14(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v15(T15(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v16(T16(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v17(T17(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v18(T18(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v19(T19(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v20(T20(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError(errors: errors)
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose20 /*: Equatable*/ where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable, T7 : Equatable, T8 : Equatable, T9 : Equatable, T10 : Equatable, T11 : Equatable, T12 : Equatable, T13 : Equatable, T14 : Equatable, T15 : Equatable, T16 : Equatable, T17 : Equatable, T18 : Equatable, T19 : Equatable, T20 : Equatable {

    public static func ==(lhs: Choose20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>, rhs: Choose20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>) -> Bool {
        switch (lhs, rhs) {
        case (.v1(let a), .v1(let b)): return a == b
        case (.v2(let a), .v2(let b)): return a == b
        case (.v3(let a), .v3(let b)): return a == b
        case (.v4(let a), .v4(let b)): return a == b
        case (.v5(let a), .v5(let b)): return a == b
        case (.v6(let a), .v6(let b)): return a == b
        case (.v7(let a), .v7(let b)): return a == b
        case (.v8(let a), .v8(let b)): return a == b
        case (.v9(let a), .v9(let b)): return a == b
        case (.v10(let a), .v10(let b)): return a == b
        case (.v11(let a), .v11(let b)): return a == b
        case (.v12(let a), .v12(let b)): return a == b
        case (.v13(let a), .v13(let b)): return a == b
        case (.v14(let a), .v14(let b)): return a == b
        case (.v15(let a), .v15(let b)): return a == b
        case (.v16(let a), .v16(let b)): return a == b
        case (.v17(let a), .v17(let b)): return a == b
        case (.v18(let a), .v18(let b)): return a == b
        case (.v19(let a), .v19(let b)): return a == b
        case (.v20(let a), .v20(let b)): return a == b
        default: return false
        }
    }
}

// Swift 4.1 TODO: conditional conformance
extension Choose20 /*: Hashable*/ where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable, T7 : Hashable, T8 : Hashable, T9 : Hashable, T10 : Hashable, T11 : Hashable, T12 : Hashable, T13 : Hashable, T14 : Hashable, T15 : Hashable, T16 : Hashable, T17 : Hashable, T18 : Hashable, T19 : Hashable, T20 : Hashable { // Swift 4.1 TODO: conditional conformance

    public var hashValue: Int {
        switch self {
        case .v1(let x): return x.hashValue
        case .v2(let x): return x.hashValue
        case .v3(let x): return x.hashValue
        case .v4(let x): return x.hashValue
        case .v5(let x): return x.hashValue
        case .v6(let x): return x.hashValue
        case .v7(let x): return x.hashValue
        case .v8(let x): return x.hashValue
        case .v9(let x): return x.hashValue
        case .v10(let x): return x.hashValue
        case .v11(let x): return x.hashValue
        case .v12(let x): return x.hashValue
        case .v13(let x): return x.hashValue
        case .v14(let x): return x.hashValue
        case .v15(let x): return x.hashValue
        case .v16(let x): return x.hashValue
        case .v17(let x): return x.hashValue
        case .v18(let x): return x.hashValue
        case .v19(let x): return x.hashValue
        case .v20(let x): return x.hashValue
        }
    }
}

// MARK - Channel either with flatten operation: |

/// Channel either & flattening operation
public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), Choose2<T1, T2>> {
    return lhs.either(rhs)
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), Choose2<T1, T2>>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), Choose3<T1, T2, T3>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v2(let x): return .v3(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), Choose3<T1, T2, T3>>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), Choose4<T1, T2, T3, T4>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v2(let x): return .v4(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), Choose4<T1, T2, T3, T4>>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), Choose5<T1, T2, T3, T4, T5>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v2(let x): return .v5(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), Choose5<T1, T2, T3, T4, T5>>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), Choose6<T1, T2, T3, T4, T5, T6>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v2(let x): return .v6(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), Choose6<T1, T2, T3, T4, T5, T6>>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), Choose7<T1, T2, T3, T4, T5, T6, T7>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v2(let x): return .v7(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), Choose7<T1, T2, T3, T4, T5, T6, T7>>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), Choose8<T1, T2, T3, T4, T5, T6, T7, T8>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v2(let x): return .v8(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), Choose8<T1, T2, T3, T4, T5, T6, T7, T8>>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v2(let x): return .v9(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), Choose10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v2(let x): return .v10(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), Choose10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), Choose11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v2(let x): return .v11(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), Choose11<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), Choose12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v2(let x): return .v12(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), Choose12<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), Choose13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v2(let x): return .v13(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), Choose13<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), Choose14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v2(let x): return .v14(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), Choose14<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), Choose15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v2(let x): return .v15(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), Choose15<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), Choose16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v1(.v15(let x)): return .v15(x)
        case .v2(let x): return .v16(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), Choose16<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), Choose17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v1(.v15(let x)): return .v15(x)
        case .v1(.v16(let x)): return .v16(x)
        case .v2(let x): return .v17(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), Choose17<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), Choose18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v1(.v15(let x)): return .v15(x)
        case .v1(.v16(let x)): return .v16(x)
        case .v1(.v17(let x)): return .v17(x)
        case .v2(let x): return .v18(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), Choose18<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), Choose19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v1(.v15(let x)): return .v15(x)
        case .v1(.v16(let x)): return .v16(x)
        case .v1(.v17(let x)): return .v17(x)
        case .v1(.v18(let x)): return .v18(x)
        case .v2(let x): return .v19(x)
        }
    }
}

/// Channel combination & flattening operation
public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), Choose19<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>>, rhs: Channel<S20, T20>) -> Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), Choose20<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v1(.v3(let x)): return .v3(x)
        case .v1(.v4(let x)): return .v4(x)
        case .v1(.v5(let x)): return .v5(x)
        case .v1(.v6(let x)): return .v6(x)
        case .v1(.v7(let x)): return .v7(x)
        case .v1(.v8(let x)): return .v8(x)
        case .v1(.v9(let x)): return .v9(x)
        case .v1(.v10(let x)): return .v10(x)
        case .v1(.v11(let x)): return .v11(x)
        case .v1(.v12(let x)): return .v12(x)
        case .v1(.v13(let x)): return .v13(x)
        case .v1(.v14(let x)): return .v14(x)
        case .v1(.v15(let x)): return .v15(x)
        case .v1(.v16(let x)): return .v16(x)
        case .v1(.v17(let x)): return .v17(x)
        case .v1(.v18(let x)): return .v18(x)
        case .v1(.v19(let x)): return .v19(x)
        case .v2(let x): return .v20(x)
        }
    }
}


// MARK - Channel combine with flatten operation: &

/// Channel `combine` & flattening operation
public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.combine(rhs)
}
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineAll(lhs.combine(rhs))) }


// MARK - Channel zip with flatten operation: ^

/// Channel zipping & flattening operation
public func ^<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)>, rhs: Channel<S13, T13>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)>, rhs: Channel<S14, T14>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)>, rhs: Channel<S15, T15>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)>, rhs: Channel<S16, T16>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)>, rhs: Channel<S17, T17>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)>, rhs: Channel<S18, T18>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)>, rhs: Channel<S19, T19>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)>, rhs: Channel<S20, T20>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return combineSources(combineAll(lhs.zip(rhs))) }


private func combineSources<S1, S2, S3, T>(_ rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.1) } }
private func combineSources<S1, S2, S3, S4, T>(_ rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, T>(_ rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.1) } }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.0.18, src.1) } }

private func combineAll<S, T1, T2, T3>(_ rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func combineAll<S, T1, T2, T3, T4>(_ rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5>(_ rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12), T13)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13), T14)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14), T15)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15), T16)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16), T17)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17), T18)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18), T19)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.1) } }
private func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19), T20)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.0.11, $0.0.12, $0.0.13, $0.0.14, $0.0.15, $0.0.16, $0.0.17, $0.0.18, $0.1) } }

//
//  Combinators.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 4/5/16.
//  Copyright © 2010-2020 glimpse.io. All rights reserved.
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
    @inlinable func firstMap<U>(_ f: (T1) throws -> U?) rethrows -> U? {
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
public struct ChoiceDecodingError<T: ChooseNType> : Error {
    public let errors: [Error]

    public init(errors: [Error]) {
        self.errors = errors
    }
}


/// One of exactly 2 options
public enum Choose2<T1, T2>: Choose2Type {
    public var arity: Int { return 2 }

    /// First of 2
    case v1(T1)
    /// Second of 2
    case v2(T2)


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
        
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

}

public extension Choose2 where T1 == T2 {
    /// When a ChooseN type wraps the same value types, returns the single value
    @inlinable var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        }
    }
}

extension Choose2 : Encodable where T1 : Encodable, T2 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose2 : Decodable where T1 : Decodable, T2 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose2>(errors: errors)
    }
}

extension Choose2 : Equatable where T1 : Equatable, T2 : Equatable { }

extension Choose2 : Hashable where T1 : Hashable, T2 : Hashable { }

/// One of at least 3 options
public protocol Choose3Type : Choose2Type {
    associatedtype T3
    var v3: T3? { get set }
}

/// One of exactly 3 options
public enum Choose3<T1, T2, T3>: Choose3Type {
    @inlinable public var arity: Int { return 3 }

    /// First of 3
    case v1(T1)
    /// Second of 3
    case v2(T2)
    /// Third of 3
    case v3(T3)


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<T1, T2>, T3> {
        switch self {
        case .v1(let v): return .v1(.v1(v))
        case .v2(let v): return .v1(.v2(v))
        case .v3(let v): return .v2(v)
        }
    }
}

public extension Choose3 where T1 == T2, T2 == T3 {
    /// When a ChooseN type wraps the same value types, returns the single value
    @inlinable var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        }
    }
}

extension Choose3 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose3 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose3>(errors: errors)
    }
}

extension Choose3 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable { }

extension Choose3 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable { }

/// One of at least 4 options
public protocol Choose4Type : Choose3Type {
    associatedtype T4
    var v4: T4? { get set }
}

/// One of exactly 4 options
public enum Choose4<T1, T2, T3, T4>: Choose4Type {
    @inlinable public var arity: Int { return 4 }

    /// First of 4
    case v1(T1)
    /// Second of 4
    case v2(T2)
    /// Third of 4
    case v3(T3)
    /// Fourth of 4
    case v4(T4)


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<T1, T2>, T3>, T4> {
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
    @inlinable var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        }
    }
}

extension Choose4 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose4 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose4>(errors: errors)
    }
}

extension Choose4 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable { }

extension Choose4 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable { }

/// One of at least 5 options
public protocol Choose5Type : Choose4Type {
    associatedtype T5
    var v5: T5? { get set }
}

/// One of exactly 5 options
public enum Choose5<T1, T2, T3, T4, T5>: Choose5Type {
    @inlinable public var arity: Int { return 5 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5> {
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
    @inlinable var value: T1 {
        switch self {
        case .v1(let x): return x
        case .v2(let x): return x
        case .v3(let x): return x
        case .v4(let x): return x
        case .v5(let x): return x
        }
    }
}

extension Choose5 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        case .v5(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose5 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v5(T5(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose5>(errors: errors)
    }
}

extension Choose5 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable { }

extension Choose5 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable { }

/// One of at least 6 options
public protocol Choose6Type : Choose5Type {
    associatedtype T6
    var v6: T6? { get set }
}

/// One of exactly 6 options
public enum Choose6<T1, T2, T3, T4, T5, T6>: Choose6Type {
    @inlinable public var arity: Int { return 6 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    @inlinable public init(t6: T6) { self = .v6(t6) }
    @inlinable public init(_ t6: T6) { self = .v6(t6) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    @inlinable public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6> {
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
    var value: T1 {
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

extension Choose6 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        case .v5(let x): try x.encode(to: encoder)
        case .v6(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose6 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v5(T5(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v6(T6(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose6>(errors: errors)
    }
}

extension Choose6 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable { }

extension Choose6 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable { }

/// One of at least 7 options
public protocol Choose7Type : Choose6Type {
    associatedtype T7
    var v7: T7? { get set }
}

/// One of exactly 7 options
public enum Choose7<T1, T2, T3, T4, T5, T6, T7>: Choose7Type {
    @inlinable public var arity: Int { return 7 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    @inlinable public init(t6: T6) { self = .v6(t6) }
    @inlinable public init(_ t6: T6) { self = .v6(t6) }
    
    @inlinable public init(t7: T7) { self = .v7(t7) }
    @inlinable public init(_ t7: T7) { self = .v7(t7) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    @inlinable public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    @inlinable public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7> {
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
    @inlinable var value: T1 {
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

extension Choose7 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable, T7 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        case .v5(let x): try x.encode(to: encoder)
        case .v6(let x): try x.encode(to: encoder)
        case .v7(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose7 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable, T7 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v5(T5(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v6(T6(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v7(T7(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose7>(errors: errors)
    }
}

extension Choose7 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable, T7 : Equatable { }

extension Choose7 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable, T7 : Hashable { }

/// One of at least 8 options
public protocol Choose8Type : Choose7Type {
    associatedtype T8
    var v8: T8? { get set }
}

/// One of exactly 8 options
public enum Choose8<T1, T2, T3, T4, T5, T6, T7, T8>: Choose8Type {
    @inlinable public var arity: Int { return 8 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    @inlinable public init(t6: T6) { self = .v6(t6) }
    @inlinable public init(_ t6: T6) { self = .v6(t6) }
    
    @inlinable public init(t7: T7) { self = .v7(t7) }
    @inlinable public init(_ t7: T7) { self = .v7(t7) }
    
    @inlinable public init(t8: T8) { self = .v8(t8) }
    @inlinable public init(_ t8: T8) { self = .v8(t8) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    @inlinable public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    @inlinable public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    @inlinable public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8> {
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
    @inlinable var value: T1 {
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

extension Choose8 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable, T7 : Encodable, T8 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
        switch self {
        case .v1(let x): try x.encode(to: encoder)
        case .v2(let x): try x.encode(to: encoder)
        case .v3(let x): try x.encode(to: encoder)
        case .v4(let x): try x.encode(to: encoder)
        case .v5(let x): try x.encode(to: encoder)
        case .v6(let x): try x.encode(to: encoder)
        case .v7(let x): try x.encode(to: encoder)
        case .v8(let x): try x.encode(to: encoder)
        }
    }
}

extension Choose8 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable, T7 : Decodable, T8 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
        var errors: [Error] = []
        do { self = try .v1(T1(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v2(T2(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v3(T3(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v4(T4(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v5(T5(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v6(T6(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v7(T7(from: decoder)); return } catch { errors.append(error) }
        do { self = try .v8(T8(from: decoder)); return } catch { errors.append(error) }
        throw ChoiceDecodingError<Choose8>(errors: errors)
    }
}

extension Choose8 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable, T7 : Equatable, T8 : Equatable { }

extension Choose8 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable, T7 : Hashable, T8 : Hashable { }

/// One of at least 9 options
public protocol Choose9Type : Choose8Type {
    associatedtype T9
    var v9: T9? { get set }
}

/// One of exactly 9 options
public enum Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>: Choose9Type {
    @inlinable public var arity: Int { return 9 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    @inlinable public init(t6: T6) { self = .v6(t6) }
    @inlinable public init(_ t6: T6) { self = .v6(t6) }
    
    @inlinable public init(t7: T7) { self = .v7(t7) }
    @inlinable public init(_ t7: T7) { self = .v7(t7) }
    
    @inlinable public init(t8: T8) { self = .v8(t8) }
    @inlinable public init(_ t8: T8) { self = .v8(t8) }
    
    @inlinable public init(t9: T9) { self = .v9(t9) }
    @inlinable public init(_ t9: T9) { self = .v9(t9) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    @inlinable public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    @inlinable public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    @inlinable public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    @inlinable public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9> {
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
    @inlinable var value: T1 {
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

extension Choose9 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable, T7 : Encodable, T8 : Encodable, T9 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
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
        }
    }
}

extension Choose9 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable, T7 : Decodable, T8 : Decodable, T9 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
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
        throw ChoiceDecodingError<Choose9>(errors: errors)
    }
}

extension Choose9 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable, T7 : Equatable, T8 : Equatable, T9 : Equatable { }

extension Choose9 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable, T7 : Hashable, T8 : Hashable, T9 : Hashable { }

/// One of at least 10 options
public protocol Choose10Type : Choose9Type {
    associatedtype T10
    var v10: T10? { get set }
}

/// One of exactly 10 options
public enum Choose10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>: Choose10Type {
    @inlinable public var arity: Int { return 10 }

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


    @inlinable public init(t1: T1) { self = .v1(t1) }
    @inlinable public init(_ t1: T1) { self = .v1(t1) }
    
    @inlinable public init(t2: T2) { self = .v2(t2) }
    @inlinable public init(_ t2: T2) { self = .v2(t2) }
    
    @inlinable public init(t3: T3) { self = .v3(t3) }
    @inlinable public init(_ t3: T3) { self = .v3(t3) }
    
    @inlinable public init(t4: T4) { self = .v4(t4) }
    @inlinable public init(_ t4: T4) { self = .v4(t4) }
    
    @inlinable public init(t5: T5) { self = .v5(t5) }
    @inlinable public init(_ t5: T5) { self = .v5(t5) }
    
    @inlinable public init(t6: T6) { self = .v6(t6) }
    @inlinable public init(_ t6: T6) { self = .v6(t6) }
    
    @inlinable public init(t7: T7) { self = .v7(t7) }
    @inlinable public init(_ t7: T7) { self = .v7(t7) }
    
    @inlinable public init(t8: T8) { self = .v8(t8) }
    @inlinable public init(_ t8: T8) { self = .v8(t8) }
    
    @inlinable public init(t9: T9) { self = .v9(t9) }
    @inlinable public init(_ t9: T9) { self = .v9(t9) }
    
    @inlinable public init(t10: T10) { self = .v10(t10) }
    @inlinable public init(_ t10: T10) { self = .v10(t10) }
    
    
    
    @inlinable public var first: T1? { if case .v1(let x) = self { return x } else { return nil } }

    @inlinable public var v1: T1? {
        get { if case .v1(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v1(x) } }
    }

    @inlinable public var v2: T2? {
        get { if case .v2(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v2(x) } }
    }

    @inlinable public var v3: T3? {
        get { if case .v3(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v3(x) } }
    }

    @inlinable public var v4: T4? {
        get { if case .v4(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v4(x) } }
    }

    @inlinable public var v5: T5? {
        get { if case .v5(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v5(x) } }
    }

    @inlinable public var v6: T6? {
        get { if case .v6(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v6(x) } }
    }

    @inlinable public var v7: T7? {
        get { if case .v7(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v7(x) } }
    }

    @inlinable public var v8: T8? {
        get { if case .v8(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v8(x) } }
    }

    @inlinable public var v9: T9? {
        get { if case .v9(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v9(x) } }
    }

    @inlinable public var v10: T10? {
        get { if case .v10(let x) = self { return x } else { return nil } }
        set(x) { if let x = x { self = .v10(x) } }
    }

    /// Split the tuple into nested Choose2 instances
    @inlinable public func split() -> Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<Choose2<T1, T2>, T3>, T4>, T5>, T6>, T7>, T8>, T9>, T10> {
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
    @inlinable var value: T1 {
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

extension Choose10 : Encodable where T1 : Encodable, T2 : Encodable, T3 : Encodable, T4 : Encodable, T5 : Encodable, T6 : Encodable, T7 : Encodable, T8 : Encodable, T9 : Encodable, T10 : Encodable {

    @inlinable public func encode(to encoder: Encoder) throws {
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
        }
    }
}

extension Choose10 : Decodable where T1 : Decodable, T2 : Decodable, T3 : Decodable, T4 : Decodable, T5 : Decodable, T6 : Decodable, T7 : Decodable, T8 : Decodable, T9 : Decodable, T10 : Decodable {

    @inlinable public init(from decoder: Decoder) throws {
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
        throw ChoiceDecodingError<Choose10>(errors: errors)
    }
}

extension Choose10 : Equatable where T1 : Equatable, T2 : Equatable, T3 : Equatable, T4 : Equatable, T5 : Equatable, T6 : Equatable, T7 : Equatable, T8 : Equatable, T9 : Equatable, T10 : Equatable { }

extension Choose10 : Hashable where T1 : Hashable, T2 : Hashable, T3 : Hashable, T4 : Hashable, T5 : Hashable, T6 : Hashable, T7 : Hashable, T8 : Hashable, T9 : Hashable, T10 : Hashable { }


// MARK - Channel either with flatten operation: |

/// Channel either & flattening operation
@inlinable public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), Choose2<T1, T2>> {
    return lhs.either(rhs)
}

/// Channel combination & flattening operation
@inlinable public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), Choose2<T1, T2>>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), Choose3<T1, T2, T3>> {
    return combineSources(lhs.either(rhs)).map { choice in
        switch choice {
        case .v1(.v1(let x)): return .v1(x)
        case .v1(.v2(let x)): return .v2(x)
        case .v2(let x): return .v3(x)
        }
    }
}

/// Channel combination & flattening operation
@inlinable public func |<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), Choose3<T1, T2, T3>>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), Choose4<T1, T2, T3, T4>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), Choose4<T1, T2, T3, T4>>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), Choose5<T1, T2, T3, T4, T5>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), Choose5<T1, T2, T3, T4, T5>>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), Choose6<T1, T2, T3, T4, T5, T6>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), Choose6<T1, T2, T3, T4, T5, T6>>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), Choose7<T1, T2, T3, T4, T5, T6, T7>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), Choose7<T1, T2, T3, T4, T5, T6, T7>>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), Choose8<T1, T2, T3, T4, T5, T6, T7, T8>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), Choose8<T1, T2, T3, T4, T5, T6, T7, T8>>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>> {
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
@inlinable public func |<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), Choose9<T1, T2, T3, T4, T5, T6, T7, T8, T9>>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), Choose10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>> {
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


// MARK - Channel combine with flatten operation: &

/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.combine(rhs)
}
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.combine(rhs))) }
/// Channel `combine` & flattening operation
@inlinable public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.combine(rhs))) }


// MARK - Channel zip with flatten operation: ^

/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>) -> Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineAll(lhs.zip(rhs))) }
/// Channel zipping & flattening operation
@inlinable public func ^<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineAll(lhs.zip(rhs))) }


@usableFromInline func combineSources<S1, S2, S3, T>(_ rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, T>(_ rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, T>(_ rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), S13), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13), S14), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14), S15), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15), S16), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16), S17), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17), S18), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18), S19), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.1) } }
@usableFromInline func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, T>(_ rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19), S20), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20), T> { return rcvr.resource { src in (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.0.11, src.0.12, src.0.13, src.0.14, src.0.15, src.0.16, src.0.17, src.0.18, src.1) } }

@usableFromInline func combineAll<S, T1, T2, T3>(_ rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4>(_ rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5>(_ rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5, T6>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5, T6, T7>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
@usableFromInline func combineAll<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(_ rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }

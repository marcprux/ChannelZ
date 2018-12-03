//
//  Errors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/9/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

public protocol ResultType : _WrapperType, Choose2Type {
    /// Returns the value for `.success` or nil if this is a `.failure`
    var value: Wrapped? { get }
    
    /// Returns the error for `.failure` or nil if this is a `.success`
    var error: Error? { get }
    
    /// Returns `f(value)` if this is `.success`, otherwise returns `.failure`
    func successMap<U>(_ f: (Wrapped) throws -> U) -> Result<U>

    var choose2: Choose2<Wrapped, Error> { get }
    var result: Result<Wrapped> { get }
    
    /// Must be able to initialize with an error
    init(error: Error)
}

public enum Result<Wrapped> : ResultType {
    case success(Wrapped)
    case failure(Error)

    @inlinable public init(_ some: Wrapped) {
        self = .success(some)
    }

    @inlinable public init(error: Error) {
        self = .failure(error)
    }
    
    @inlinable public var result: Result<Wrapped> {
        return self
    }
    
    /// If `self` is `ErrorType`, returns `nil`.  Otherwise, returns `f(self!)`.
    /// - See Also: `Optional.map`
    @inlinable public func map<U>(_ f: (Wrapped) throws -> U) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }

    /// Returns `nil` if `self` is `ErrorType`, `f(self!)` otherwise.
    /// - See Also: `Optional.flatMap`
    @inlinable public func flatMap<U>(_ f: (Wrapped) throws -> U?) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }
}

extension Result : Choose2Type {

    @inlinable public var choose2: Choose2<Wrapped, Error> {
        switch self {
        case .success(let value): return .v1(value)
        case .failure(let error): return .v2(error)
        }
    }
    
    /// Returns the number of choices
    @inlinable public var arity: Int { return 2 }

    /// The first type in thie OneOf if the `Wrapped` value
    @inlinable public var v1: Wrapped? {
        get {
            return flatMap({ $0 })
        }

        set(x) {
            if let x = x {
                self = .success(x)
            }
        }
    }

    /// The first type in thie OneOf if the `Error` value
    @inlinable public var v2: Error? {
        get {
            switch self {
            case .failure(let x): return x
            case .success: return nil
            }
        }

        set(x) {
            if let x = x {
                self = .failure(x)
            }
        }
    }
}

public extension Result {
    /// Returns the value for `.success` or nil if this is a `.failure`
    @inlinable public var value: Wrapped? { return v1 }

    /// Returns the error for `.failure` or nil if this is a `.success`
    @inlinable public var error: Error? { return v2 }

    /// Returns `f(value)` if this is `.success`, otherwise returns `.failure`
    @inlinable public func successMap<U>(_ f: (Wrapped) throws -> U) -> Result<U> {
        switch self {
        case .success(let v):
            do {
                return try .success(f(v))
            } catch {
                return .failure(error)
            }
        case .failure(let e):
            return .failure(e)
        }
    }
    
    /// Returns `f(value)` if this is `.success`, otherwise returns `.failure`
    /// This is an alias for successMap, which has a different name to disambiguate
    /// from _WrapperType.flatMap's implicit handling of optionals
    @inlinable public func flatMap<U>(f: (Wrapped) throws -> U) -> Result<U> {
        return successMap(f)
    }

    /// Unwraps the given `.success` value or throws the `.failure` error
    @inlinable public func force() throws -> Wrapped {
        switch self {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    /// Constructs a `Result` with `.success` of the function's return, or `.failure` if the function throws
    @inlinable public init(f: () throws -> Wrapped) {
        do {
            self = .success(try f())
        } catch {
            self = .failure(error)
        }
    }
    
    /// Constructs a `Result` with `.success` of the function's return, or `.failure` if the function throws
    @inlinable public init(invoking: @autoclosure () throws -> Wrapped) {
        do {
            self = .success(try invoking())
        } catch {
            self = .failure(error)
        }
    }

}

public extension Result where Wrapped : _WrapperType {
    /// Returns the unwrapped value flatMapped to itself (e.g., converts value of String?? into String?)
    @inlinable public var flatValue: Wrapped.Wrapped? {
        switch self {
        case .success(let x): return x.flatMap({ $0 })
        case .failure: return .none
        }
    }
}

public extension ChannelType {

    /// Adds a channel phase that applies the given function to each item emitted by a Channel and emits
    /// `Result.Success`, or `Result.Failure` if the function threw an error.
    ///
    /// - Parameter transform: a function to apply to each item emitted by the Channel
    ///
    /// - Returns: A stateless Channel that emits the pulses from the source Channel, transformed by the given function
    @inlinable public func map<U>(_ transform: @escaping (Pulse) throws -> U) -> Channel<Source, Result<U>> {
        return lift { receive in
            { item in
                do {
                    receive(.success(try transform(item)))
                } catch {
                    receive(.failure(error))
                }
            }
        }
    }
}


public extension ChannelType {
    /// Calls flatMap on the given channel and then aggregates the results of the two channels.
    /// This can be used to execute an arbitrary sequence of operations on a channel.
    @inlinable public func sequence<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Self.Pulse, Pulse2)> {
        return flatMap { pulse1 in next.map { pulse2 in (pulse1, pulse2) } }
    }
    
}

/// Takes a collection of heterogeneous channels and sequences them together, resulting
/// in a channel that emits a single array with all the values
@inlinable public func sequenceZChannels<S, T>(source: S, channels: [Channel<S, T>]) -> Channel<S, [T]> {
    var seq: Channel<S, [T]> = [[]].channelZSequence().resource({ _ in source })
    for channel in channels {
        seq = seq.sequence(channel).map({ $0.0 + [$0.1] })
    }
    return seq
}

/// an error occurred, so replace the next channel with a channel that does nothing but emit the same error
@usableFromInline func errorChannel<S, E: ResultType>(source: S, error: Error) -> Channel<S, E> {
    return Channel(source: source) { rcvr in
        rcvr(E(error: error))
        return ReceiptOf()
    }
}

public extension ChannelType {
    /// A function that maps from this channel's pulse to another channel type
//    public typealias PulseChannelMap<S, T> = (Self.Pulse) -> Channel<S, T>

    /// Chains one channel to the next only if the result was successful
    @inlinable public func successfully<Source2, Pulse2>(_ next: @escaping (Self.Pulse.Wrapped) -> Channel<Source2, Pulse2>) -> Channel<Self.Source, Pulse2> where Self.Pulse : ResultType, Pulse2 : ResultType {
        return alternate(to: { next($0.value!).anySource() }, unless: { pulse in
            if let error = pulse.error {
                return errorChannel(source: (), error: error)
            } else {
                return .none // continue on to the next channel
            }
        }).map({ $0.0 }) // drop previous successful results, retaining only the error or more recent successful value
    }

    
    /// Chains one channel to the next only if the result was successful
    @inlinable public func then<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse : ResultType, Pulse2 : ResultType {
        return alternate(to: { _ in next }, unless: { pulse in
            if let error = pulse.error {
                return errorChannel(source: next.source, error: error)
            } else {
                return .none // continue on to the next channel
            }
        })
    }

    /// Chains one channel to the next only if the first result element of the pulse tuple was successful
    @inlinable public func then<Source2, Pulse2, R: ResultType, Tuple>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse == (R, Tuple), Pulse2 : ResultType {
        return alternate(to: { _ in next }, unless: { pulse in
            if let error = pulse.0.error {
                return errorChannel(source: next.source, error: error)
            } else {
                return .none // continue on to the next channel
            }
        })
    }

//    /// Chains one channel to the next unconditionally
//    public func sequence<Source2, Pulse2, R: ResultType, Tuple>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse == (R, Tuple) {
//        return alternate(to: { _ in next }, unless: { pulse in .none })
//    }

//    private func alternateError<Source2, Pulse2>(to: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>, err: @escaping (Self.Pulse) -> Error?) -> Channel<(), (Pulse2, Self.Pulse)> where Pulse2 : ResultType {
//        return alternate(to: to, unless: { pulse in
//            if let error = err(pulse) {
//                return errorChannel(source: self.source, error: error)
//            } else {
//                return .none // continue on to the next channel
//            }
//        }).desource()
//    }
    

    /// Proceed to flatMap the given channel unless the condition clause returns a non-null element
    @inlinable public func alternate<Source2, Pulse2>(to: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>, unless: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>?) -> Channel<Self.Source, (Pulse2, Self.Pulse)> {
        let mapper: (Self.Pulse) -> Channel<Source2, (Pulse2, Self.Pulse)> = { (pulse1: Self.Pulse) in
            if let altername = unless(pulse1) {
                return altername.map({ ($0, pulse1 )})
            } else {
                return to(pulse1).map({ ($0, pulse1 )})
            }
        }
        
        return flatMap(mapper)
    }

    /// Proceed to flatMap the given channel unless the condition clause returns a non-null element
    @inlinable public func alternate2<Source2, Source3, Pulse2>(to: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>, unless: @escaping (Self.Pulse) -> Channel<Source3, Pulse2>?) -> Channel<Self.Source, (Pulse2, Self.Pulse)> {
        let mapper: (Self.Pulse) -> Channel<Void, (Pulse2, Self.Pulse)> = { (pulse1: Self.Pulse) in
            if let altername = unless(pulse1) {
                return altername.map({ ($0, pulse1 )}).desource()
            } else {
                return to(pulse1).map({ ($0, pulse1 )}).desource()
            }
        }
        
        return flatMap(mapper)
    }

}


// MARK: Foundation Extensions

import Foundation

/// A very simple codeable wrapper around an error message; coding
/// will lose any custom behavior of the error subclass
private struct CodableError : Error, Codable, Hashable {
    private let errorMessage: String

    init(error: Error) {
        self.errorMessage = (error as NSError).localizedDescription
    }
}

extension Result : Encodable where Wrapped : Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .success(let wrapped): try wrapped.encode(to: encoder)
        case .failure(let error): try CodableError(error: error).encode(to: encoder)
        }
    }
}

extension Result : Decodable where Wrapped : Decodable {
    public init(from decoder: Decoder) throws {
        switch try Choose2<Wrapped, CodableError>(from: decoder) {
        case .v1(let value): self = .success(value)
        case .v2(let error): self = .failure(error)
        }
    }
}

extension Result : Equatable where Wrapped : Equatable {
    public static func == (lhs: Result<Wrapped>, rhs: Result<Wrapped>) -> Bool {
        switch (lhs, rhs) {
        case let (.success(v1), .success(v2)): return v1 == v2
        case let (.failure(e1), .failure(e2)): return (e1 as NSError) == (e2 as NSError)
        default: return false
        }
    }

}

extension Result : Hashable where Wrapped : Hashable {
    public var hashValue: Int {
        switch self {
        case .success(let wrapped): return wrapped.hashValue
        case .failure(let error): return (error as NSError).hashValue
        }
    }
}

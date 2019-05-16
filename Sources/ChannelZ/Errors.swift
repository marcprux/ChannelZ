//
//  Errors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/9/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

/// A result tyoe that can accept any error type
public typealias ResultOf<T> = Result<T, Error>

public protocol ResultType {
    associatedtype Success
    associatedtype Failure : Error

    /// Returns the value for `.success` or nil if this is a `.failure`
    var value: Success? { get }

    /// Returns the error for `.failure` or nil if this is a `.success`
    var error: Failure? { get }

    /// Must be able to initialize with an error
    init(error: Failure)

    /// Convert this type into a concrete result
    var asResult: Result<Success, Failure> { get }

    /// Convert this type into a type-erased error result
    var asErrorResult: ResultOf<Success> { get }
}

extension Result : ResultType {
    public init(_ some: Success) {
        self = .success(some)
    }

    public init(error: Failure) {
        self = .failure(error)
    }

    @inlinable public var value: Success? {
        switch self {
        case .success(let x): return .some(x)
        case .failure: return .none
        }
    }

    @inlinable public var error: Failure? {
        switch self {
        case .success: return .none
        case .failure(let x): return .some(x)
        }
    }

    @inlinable public var asResult: Result<Success, Failure> {
        return self
    }

    @inlinable public var asErrorResult: ResultOf<Success> {
        return self.mapError({ $0 })
    }

    public func mapSuccess<U>(_ f: (Success) throws -> U) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }

    public func flatMapSuccess<U>(_ f: (Success) throws -> U?) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }

}

extension Result : Choose2Type {

    @inlinable public var choose2: Choose2<Success, Failure> {
        switch self {
        case .success(let value): return .v1(value)
        case .failure(let error): return .v2(error)
        }
    }
    
    /// Returns the number of choices
    @inlinable public var arity: Int { return 2 }

    /// The first type in thie OneOf if the `Wrapped` value
    @inlinable public var v1: Success? {
        get {
            return flatMapSuccess({ $0 })
        }

        set(x) {
            if let x = x {
                self = .success(x)
            }
        }
    }

    /// The first type in thie OneOf if the `Error` value
    @inlinable public var v2: Failure? {
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


public extension Result where Success : _WrapperType {
    /// Returns the unwrapped value flatMapped to itself (e.g., converts value of String?? into String?)
    @inlinable var flatValue: Success.Wrapped? {
        switch self {
        case .success(let x): return x.flatMap({ $0 })
        case .failure: return .none
        }
    }
}

public extension Result {
    /// Takes a Result<Result<X, E>, E> and flattens it to a Result<X, E>
    func flatten<T>() -> Result<T, Failure> where Success == Result<T, Failure> {
        switch self {
        case .failure(let x): return .failure(x)
        case .success(.failure(let x)): return .failure(x)
        case .success(.success(let x)): return .success(x)
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
    @inlinable func map<U>(_ transform: @escaping (Pulse) throws -> U) -> Channel<Source, ResultOf<U>> {
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
    @inlinable func sequence<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Self.Pulse, Pulse2)> {
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
@usableFromInline func errorChannel<S, R: ResultType>(source: S, error: R.Failure) -> Channel<S, R> {
    return Channel(source: source) { rcvr in
        rcvr(R(error: error))
        return ReceiptOf()
    }
}

public extension ChannelType {
    /// A function that maps from this channel's pulse to another channel type
//    public typealias PulseChannelMap<S, T> = (Self.Pulse) -> Channel<S, T>

    /// Chains one channel to the next only if the result was successful
    @inlinable func successfully<Source2, Pulse2>(_ next: @escaping (Self.Pulse.Success) -> Channel<Source2, Pulse2>) -> Channel<Self.Source, Pulse2> where Self.Pulse : ResultType, Pulse2 : ResultType, Self.Pulse.Failure == Pulse2.Failure {
        return alternate(to: { next($0.value!).anySource() }, unless: { pulse in
            if let error = pulse.error {
                return errorChannel(source: (), error: error)
            } else {
                return .none // continue on to the next channel
            }
        }).map({ $0.0 }) // drop previous successful results, retaining only the error or more recent successful value
    }

    
    /// Chains one channel to the next only if the result was successful
    @inlinable func then<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse : ResultType, Pulse2 : ResultType, Self.Pulse.Failure == Pulse2.Failure {
        return alternate(to: { _ in next }, unless: { pulse in
            if let error = pulse.error {
                return errorChannel(source: next.source, error: error)
            } else {
                return .none // continue on to the next channel
            }
        })
    }

    /// Chains one channel to the next only if the first result element of the pulse tuple was successful
    @inlinable func then<Source2, Pulse2, R: ResultType, Tuple>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse == (R, Tuple), Pulse2 : ResultType, R.Failure == Pulse2.Failure {
        return alternate(to: { _ in next }, unless: { pulse in
            if let error = pulse.0.error {
                return errorChannel(source: next.source, error: error)
            } else {
                return .none // continue on to the next channel
            }
        })
    }

    /// Proceed to flatMap the given channel unless the condition clause returns a non-null element
    @inlinable func alternate<Source2, Pulse2>(to: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>, unless: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>?) -> Channel<Self.Source, (Pulse2, Self.Pulse)> {
        let mapper: (Self.Pulse) -> Channel<Source2, (Pulse2, Self.Pulse)> = { (pulse1: Self.Pulse) in
            if let altername = unless(pulse1) {
                return altername.map({ ($0, pulse1 )})
            } else {
                return to(pulse1).map({ ($0, pulse1 )})
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

extension Result : Encodable where Success : Encodable, Failure : Encodable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .success(let value): try value.encode(to: encoder)
        case .failure(let error): try error.encode(to: encoder)
        }
    }
}

extension Result : Decodable where Success : Decodable, Failure : Decodable {
    public init(from decoder: Decoder) throws {
        switch try Choose2<Success, Failure>(from: decoder) {
        case .v1(let value): self = .success(value)
        case .v2(let error): self = .failure(error)
        }
    }
}

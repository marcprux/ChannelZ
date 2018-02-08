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
    func flatMapSuccess<U>(f: (Wrapped) throws -> U) -> Result<U>

    var choose2: Choose2<Wrapped, Error> { get }
    var result: Result<Wrapped> { get }
    
    /// Must be able to initialize with an error
    init(error: Error)
}

public enum Result<Wrapped> : ResultType {
    case success(Wrapped)
    case failure(Error)

    public init(_ some: Wrapped) {
        self = .success(some)
    }

    public init(error: Error) {
        self = .failure(error)
    }
    
    public var result: Result<Wrapped> {
        return self
    }
    
    /// If `self` is `ErrorType`, returns `nil`.  Otherwise, returns `f(self!)`.
    /// - See Also: `Optional.map`
    
    public func map<U>(_ f: (Wrapped) throws -> U) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }

    /// Returns `nil` if `self` is `ErrorType`, `f(self!)` otherwise.
    /// - See Also: `Optional.flatMap`
    
    public func flatMap<U>(_ f: (Wrapped) throws -> U?) rethrows -> U? {
        guard case .success(let value) = self else { return nil }
        return try f(value)
    }
}

extension Result : Choose2Type {

    public var choose2: Choose2<Wrapped, Error> {
        switch self {
        case .success(let value): return .v1(value)
        case .failure(let error): return .v2(error)
        }
    }
    
    /// Returns the number of choices
    public var arity: Int { return 2 }

    /// The first type in thie OneOf if the `Wrapped` value
    public var v1: Wrapped? {
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
    public var v2: Error? {
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
    public var value: Wrapped? { return v1 }

    /// Returns the error for `.failure` or nil if this is a `.success`
    public var error: Error? { return v2 }

    /// Returns `f(value)` if this is `.success`, otherwise returns `.failure`
    public func flatMapSuccess<U>(f: (Wrapped) throws -> U) -> Result<U> {
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
    /// This is an alias for flatMapSuccess, which has a different name to disambiguate
    /// from _WrapperType.flatMap's implicit handling of optionals
    public func flatMap<U>(f: (Wrapped) throws -> U) -> Result<U> {
        return flatMapSuccess(f: f)
    }

    /// Unwraps the given `.success` value or throws the `.failure` error
    public func force() throws -> Wrapped {
        switch self {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }

    /// Constructs a `Result` with `.success` of the function's return, or `.failure` if the function throws
    public init(f: () throws -> Wrapped) {
        do {
            self = .success(try f())
        } catch {
            self = .failure(error)
        }
    }
    
    /// Constructs a `Result` with `.success` of the function's return, or `.failure` if the function throws
    public init(invoking: @autoclosure () throws -> Wrapped) {
        do {
            self = .success(try invoking())
        } catch {
            self = .failure(error)
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
    public func map<U>(_ transform: @escaping (Pulse) throws -> U) -> Channel<Source, Result<U>> {
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
    public func sequence<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Self.Pulse, Pulse2)> {
        return flatMap { pulse1 in next.map { pulse2 in (pulse1, pulse2) } }
    }
    
}


public extension ChannelType {
    /// Chains one channel to the next only if the result was successful
    public func then<Source2, Pulse2>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse : ResultType, Pulse2 : ResultType {
        return proceed(to: next, unless: { pulse in
            if let error = pulse.error {
                // an error occurred, so replace the next channel with a channel that does nothing but emit the same error
                return Channel(source: next.source) { rcvr in
                    rcvr(Pulse2(error: error))
                    return ReceiptOf()
                }
            } else {
                return .none // continue on to the next channel
            }
        })
    }

    /// Chains one channel to the next only if the first result element of the pulse tuple was successful
    public func then<Source2, Pulse2, R: ResultType, Tuple>(_ next: Channel<Source2, Pulse2>) -> Channel<Self.Source, (Pulse2, Self.Pulse)> where Self.Pulse == (R, Tuple), Pulse2 : ResultType {
        return proceed(to: next, unless: { pulse in
            if let error = pulse.0.error {
                // an error occurred, so replace the next channel with a channel that does nothing but emit the same error
                return Channel(source: next.source) { rcvr in
                    rcvr(Pulse2(error: error))
                    return ReceiptOf()
                }
            } else {
                return .none // continue on to the next channel
            }
        })
    }

    /// Proceed to flatMap the given channel unless the condition clause returns a non-null element
    public func proceed<Source2, Pulse2>(to: Channel<Source2, Pulse2>, unless: @escaping (Self.Pulse) -> Channel<Source2, Pulse2>?) -> Channel<Self.Source, (Pulse2, Self.Pulse)> {
        let mapper: (Self.Pulse) -> Channel<Source2, (Pulse2, Self.Pulse)> = { (pulse1: Self.Pulse) in
            if let altername = unless(pulse1) {
                return altername.map({ ($0, pulse1 )})
            } else {
                return to.map({ ($0, pulse1 )})
            }
        }
        
        return flatMap(mapper)
    }

}


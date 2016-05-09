//
//  Errors.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/9/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

public enum Result<Wrapped> : _WrapperType {
    case Success(Wrapped)
    case Failure(ErrorType)

    public init(_ some: Wrapped) {
        self = .Success(some)
    }

    /// If `self` is `ErrorType`, returns `nil`.  Otherwise, returns `f(self!)`.
    /// - See Also: `Optional.map`
    @warn_unused_result
    public func map<U>(@noescape f: (Wrapped) throws -> U) rethrows -> U? {
        guard case .Success(let value) = self else { return nil }
        return try f(value)
    }

    /// Returns `nil` if `self` is `ErrorType`, `f(self!)` otherwise.
    /// - See Also: `Optional.flatMap`
    @warn_unused_result
    public func flatMap<U>(@noescape f: (Wrapped) throws -> U?) rethrows -> U? {
        guard case .Success(let value) = self else { return nil }
        return try f(value)
    }
}

extension Result : ChooseN {

    /// Returns the number of choices
    public var arity: Int { return 2 }

    /// The first type in thie OneOf if the `Wrapped` value
    public var first: Wrapped? {
        return flatMap({ $0 })
    }
}

public extension ChannelType {

    /// Adds a channel phase that applies the given function to each item emitted by a Channel and emits
    /// `Result.Success`, or `Result.Failure` if the function threw an error.
    ///
    /// - Parameter transform: a function to apply to each item emitted by the Channel
    ///
    /// - Returns: A stateless Channel that emits the pulses from the source Channel, transformed by the given function
    @warn_unused_result public func map<U>(transform: Pulse throws -> U) -> Channel<Source, Result<U>> {
        return lift { receive in
            { item in
                do {
                    receive(.Success(try transform(item)))
                } catch {
                    receive(.Failure(error))
                }
            }
        }
    }
}

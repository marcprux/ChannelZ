//
//  Tuples.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/4/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//


// MARK: Operators

/// Channel merge operation for two channels of the same type (operator form of `merge`)
public func +<S1, S2, T>(lhs: Channel<S1, T>, rhs: Channel<S2, T>)->Channel<(S1, S2), T> {
    return lhs.merge(rhs)
}

/// Creates a one-way pipe betweek a `Channel` and a `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞-><S1, T, S2: SinkType where T == S2.Element>(r: Channel<S1, T>, s: S2)->Receipt { return r.pipe(s) }
infix operator ∞-> { }


/// Creates a one-way pipe betweek a `Channel` and an `Equatable` `SinkType`, such that all receiver emissions are sent to the sink.
/// This is the operator form of `pipe`
public func ∞=><S1, T, S2: SinkType where T == S2.Element, T: Equatable>(r: Channel<S1, T>, s: S2)->Receipt { return r.sieve(!=).pipe(s) }
infix operator ∞=> { }


/// Creates a two-way conduit betweek two `Channel`s whose source is an `Equatable` `SinkType`, such that when either side is
/// changed, the other side is updated; each source must be a reference type for the `sink` to not be mutative
/// This is the operator form of `channel`
public func <=∞=><S1, S2, T1, T2 where S1: SinkType, S2: SinkType, S1.Element == T2, S2.Element == T1, T1: Equatable, T2: Equatable>(r1: Channel<S1, T1>, r2: Channel<S2, T2>)->Receipt { return conduit(r1, r2) }
infix operator <=∞=> { }




// MARK: Channel Tuple flatten/combine support

/// Takes a `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3>(ob: Channel<S, ((T1?, T2?)?, T3?)>)->Channel<S, (T1?, T2?, T3?)> {
    return ob.map { ($0.0?.0, $0.0?.1, $0.1) }
}

/// Takes a `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
private func flatOptionalSink<S, T1, T2, T3, T4>(ob: Channel<S, (((T1?, T2?)?, T3?)?, T4?)>)->Channel<S, (T1?, T2?, T3?, T4?)> {
    return ob.map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1) }
}

/// Channel combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1?, T2?)> {
    return lhs.either(rhs)
}

/// Channel zipping & flattening operation
public func &<S1, S2, T1, T2>(lhs: Channel<S1, T1>, rhs: Channel<S2, T2>)->Channel<(S1, S2), (T1, T2)> {
    return lhs.zip(rhs)
}

/// Channel combination & flattening operation (operator form of `flatAny`)
public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1?, T2?)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1?, T2?, T3?)> {
    return flatOptionalSink(flattenSources(lhs.either(rhs)))
}

// MARK: Auto-generated boilerplate tuple operations


public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, T1, T2, T3, T4>(lhs: Channel<(S1, S2, S3), (T1, T2, T3)>, rhs: Channel<S4, T4>)->Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, T1, T2, T3, T4, T5>(lhs: Channel<(S1, S2, S3, S4), (T1, T2, T3, T4)>, rhs: Channel<S5, T5>)->Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, T1, T2, T3, T4, T5, T6>(lhs: Channel<(S1, S2, S3, S4, S5), (T1, T2, T3, T4, T5)>, rhs: Channel<S6, T6>)->Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, T1, T2, T3, T4, T5, T6, T7>(lhs: Channel<(S1, S2, S3, S4, S5, S6), (T1, T2, T3, T4, T5, T6)>, rhs: Channel<S7, T7>)->Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, T1, T2, T3, T4, T5, T6, T7, T8>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7), (T1, T2, T3, T4, T5, T6, T7)>, rhs: Channel<S8, T8>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, T1, T2, T3, T4, T5, T6, T7, T8, T9>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8), (T1, T2, T3, T4, T5, T6, T7, T8)>, rhs: Channel<S9, T9>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), (T1, T2, T3, T4, T5, T6, T7, T8, T9)>, rhs: Channel<S10, T10>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)>, rhs: Channel<S11, T11>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return combineSources(combineElements(lhs.zip(rhs))) }
public func &<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(lhs: Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)>, rhs: Channel<S12, T12>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return combineSources(combineElements(lhs.zip(rhs))) }

private func flattenSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, T>(rcvr: Channel<(((S1, S2), S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { let src = rcvr.source; return Channel(source: (src.0.0.0, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<(((((S1, S2), S3), S4), S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((((((S1, S2), S3), S4), S5), S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<(((((((S1, S2), S3), S4), S5), S6), S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<(((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }
private func flattenSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<(((((((((((S1, S2), S3), S4), S5), S6), S7), S8), S9), S10), S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { let src = rcvr.source; return Channel(source: (src.0.0.0.0.0.0.0.0.0.0.0, src.0.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.0.1, src.0.0.0.0.0.0.1, src.0.0.0.0.0.1, src.0.0.0.0.1, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }

private func combineSources<S1, S2, S3, T>(rcvr: Channel<((S1, S2), S3), T>)->Channel<(S1, S2, S3), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, T>(rcvr: Channel<((S1, S2, S3), S4), T>)->Channel<(S1, S2, S3, S4), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, T>(rcvr: Channel<((S1, S2, S3, S4, S5), S6), T>)->Channel<(S1, S2, S3, S4, S5, S6), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6), S7), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7), S8), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8), S9), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9), S10), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10), S11), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.1), rcvr.reception) }
private func combineSources<S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, T>(rcvr: Channel<((S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11), S12), T>)->Channel<(S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12), T> { let src = rcvr.source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.0.4, src.0.5, src.0.6, src.0.7, src.0.8, src.0.9, src.0.10, src.1), rcvr.reception) }

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

private func combineElements<S, T1, T2, T3>(rcvr: Channel<S, ((T1, T2), T3)>)->Channel<S, (T1, T2, T3)> { return rcvr.map { ($0.0.0, $0.0.1, $0.1) } }
private func combineElements<S, T1, T2, T3, T4>(rcvr: Channel<S, ((T1, T2, T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5>(rcvr: Channel<S, ((T1, T2, T3, T4), T5)>)->Channel<S, (T1, T2, T3, T4, T5)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6>(rcvr: Channel<S, ((T1, T2, T3, T4, T5), T6)>)->Channel<S, (T1, T2, T3, T4, T5, T6)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6), T7)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7), T8)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8), T9)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9), T10)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), T11)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.1) } }
private func combineElements<S, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(rcvr: Channel<S, ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), T12)>)->Channel<S, (T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)> { return rcvr.map { ($0.0.0, $0.0.1, $0.0.2, $0.0.3, $0.0.4, $0.0.5, $0.0.6, $0.0.7, $0.0.8, $0.0.9, $0.0.10, $0.1) } }

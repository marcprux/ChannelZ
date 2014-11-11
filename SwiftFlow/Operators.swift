//
//  SwiftFlowZ.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

infix operator >|> { associativity left precedence 120 }

/// Operator for Funnel.outlet
public func >|><T: FunnelType>(var lhs: T, rhs: (T.OutputType)->Void)->Outlet {
    return lhs.attach(rhs)
}

infix operator <|< { associativity right precedence 120 }

/// Operator for Funnel.outlet
public func <|<<T: FunnelType>(lhs: (T.OutputType)->Void, var rhs: T)->Outlet {
    return rhs.attach(lhs)
}



// FIXME: we need to keep this operator in SwiftFlow.swift instead of SwiftFlowZ.swift due to compiler crash “While emitting SIL for '<|' at SwiftFlowZ.swift:37:15”
//prefix operator <| { }
//public prefix func <| <T: Equatable>(rhs: T)->FilteredChannel<FieldChannel<T>> {
//    return sievefield(rhs)
//}


/// Trailing operator for creating a field funnel
public postfix func |> <T>(lhs: T)->T {
    return lhs
}
postfix operator |> { }



/// Operator for setting Channel.value that returns the value itself
infix operator <- {}
public func <-<T : ChannelType>(var lhs: T, rhs: T.SourceType) -> T.SourceType {
    lhs.push(rhs)
    return rhs
}

/// Conduit operator with natural equivalence between two identical types
infix operator <=|=> { }
public func <=|=><T : ChannelType, U : ChannelType where T.OutputType == U.OutputType>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck<T>.natural), rhs: (rhs, FlowCheck<U>.natural))
}

/// Conduit operator with checked custom transformer
infix operator <~|~> { }
public func <~|~><T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>))->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, lhs.f), rhs: (rhs.o, rhs.f))
}

/// Conduit operator with unchecked transformaer
infix operator <|||> { }
public func <|||> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->U.OutputType), rhs: (o: U, f: U.OutputType->T.OutputType))->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, { v in .Flow(lhs.f(v)) }), rhs: (rhs.o, { v in .Flow(rhs.f(v)) }))
}

/// Conduit operator with unchecked left transformaer and checked right transformer
infix operator <||~> { }
public func <||~> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->U.OutputType), rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>))->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, { v in .Flow(lhs.f(v)) }), rhs: (rhs.o, rhs.f))
}

/// Conduit operator with checked left transformaer and unchecked right transformer
infix operator <~||> { }
public func <~||> <T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: (o: U, f: U.OutputType->T.OutputType))->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, lhs.f), rhs: (rhs.o, { v in .Flow(rhs.f(v)) }))
}


/// Conduit operator for optional type coersion
infix operator <?|?> { }
public func <?|?><T : ChannelType, U : ChannelType>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.coerce), rhs: (rhs, FlowCheck.coerce))
}

/// Conduit operator for coerced left and checked right
infix operator <?|~> { }
public func <?|~><T : ChannelType, U : ChannelType>(lhs: T, rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>))->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.coerce), rhs: (rhs.o, rhs.f))
}

/// Conduit operator for checked left and coerced right
infix operator <~|?> { }
public func <~|?><T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, lhs.f), rhs: (rhs, FlowCheck.coerce))
}


/// Conduit operator with unsafe forced type coersion
infix operator <!|!> { }
public func <!|!><T : ChannelType, U : ChannelType where T.OutputType: StringLiteralConvertible, U.OutputType: StringLiteralConvertible>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.force), rhs: (rhs, FlowCheck.force))
}

public func <!|!><T : ChannelType, U : ChannelType where T.OutputType: IntegerLiteralConvertible, U.OutputType: IntegerLiteralConvertible>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.force), rhs: (rhs, FlowCheck.force))
}

public func <!|!><T : ChannelType, U : ChannelType where T.OutputType: FloatLiteralConvertible, U.OutputType: FloatLiteralConvertible>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.force), rhs: (rhs, FlowCheck.force))
}

public func <!|!><T : ChannelType, U : ChannelType, V where T.OutputType: BooleanLiteralConvertible, U.OutputType: BooleanLiteralConvertible, T.OutputType: BooleanType, U.OutputType: BooleanType>(lhs: T, rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.force), rhs: (rhs, FlowCheck.force))
}

/// Conduit operator for forced left and checked right
infix operator <!|~> { }
public func <!|~><T : ChannelType, U : ChannelType>(lhs: T, rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>))->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck.force), rhs: (rhs.o, rhs.f))
}

/// Conduit operator for checked left and forced right
infix operator <~|!> { }
public func <~|!><T : ChannelType, U : ChannelType>(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, lhs.f), rhs: (rhs, FlowCheck.force))
}

/// Conduit operator for equated left and checked right
infix operator <=|~> { }
public func <=|~><T : ChannelType, U : ChannelType where U.OutputType == T.OutputType>(lhs: T, rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>))->Conduit<T, U> {
    return Conduit(lhs: (lhs, FlowCheck<T>.natural), rhs: (rhs.o, rhs.f))
}

/// Conduit operator for checked left and equated right
infix operator <~|=> { }
public func <~|=><T : ChannelType, U : ChannelType where T.OutputType == U.OutputType>(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: U)->Conduit<T, U> {
    return Conduit(lhs: (lhs.o, lhs.f), rhs: (rhs, FlowCheck<U>.natural))
}


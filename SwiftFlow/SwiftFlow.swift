//
//  SwiftFlow.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//



/// Creates a state pipeline between two channels with equivalent source and output types; changes made to either side will push the transformed value to the the other side
///
/// :param: a one side of the pipeline
/// :param: b the other side of the pipeline
/// :return: a tuple of the connected outlets
public func pipe<A : BaseChannelType, B : BaseChannelType where A.SourceType == B.OutputType, B.SourceType == A.OutputType>(var a: A, var b: B) -> Outlet {
    let asink = a.attach({ b.push($0); return })
    let bsink = b.attach({ a.push($0); return })

    let outlet = OutletOf<(A.OutputType, B.OutputType)>(receiver: { _ in }, detacher: {
        asink.detach()
        bsink.detach()
    })

    return outlet
}



/// MARK: ChannelType & Conduit Support

/// A change encapsulates whether a state change can occur to the given type
public enum FlowCheck<T> {
    /// Continue the state change flow
    case Flow(T)

    /// Halt the state change flow
    case Halt

    /// Returns the identity flow
    public static func natural<T>(value: T)->FlowCheck<T> {
        return .Flow(value)
    }

    /// Attempt to coerce one type to another, halting if coercion was not successful
    public static func coerce<U>(value: U)->FlowCheck<T> {
        if let coerced = value as? T {
            return .Flow(coerced)
        } else {
            return .Halt
        }
    }

    /// Unsafe forced coersion
    public static func force<U>(value: U)->FlowCheck<T> {
        return .Flow(value as T)
    }

}

#if DEBUG_SWIFTFLOW
/// Debug counter for testing memory management
public var ConduitCount = 0
#endif


// TODO: old-style; remove

/// A conduit is a bi-directional flow of values between two channels
public class Conduit<T : BaseChannelType, U : BaseChannelType> {
    private var lhso: T
    private var rhso: U
    private var lhsf: T.OutputType->FlowCheck<U.OutputType>
    private var rhsf: U.OutputType->FlowCheck<T.OutputType>
//    private var lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>)
//    private var rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>)
    private var lho: Outlet? = nil
    private var rho: Outlet? = nil

    internal init(lhs: (o: T, f: T.OutputType->FlowCheck<U.OutputType>), rhs: (o: U, f: U.OutputType->FlowCheck<T.OutputType>)) {
        // dbg("creating Conduit from \(_stdlib_getDemangledTypeName(lhs.o.value)) to \(_stdlib_getDemangledTypeName(rhs.o.value))")
        self.lhso = lhs.o
        self.lhsf = lhs.f
        self.rhso = rhs.o
        self.rhsf = rhs.f

        self.rho = rhso.attach { [unowned self] in
            switch self.rhsf($0) {
            case .Flow(let val):
                var o = self.lhso
                o.push(val as T.SourceType)
            case .Halt:
                break
            }
        }

        self.lho = lhso.attach { [unowned self] in
            switch self.lhsf($0) {
            case .Flow(let val):
                var o = self.rhso
                o.push(val as U.SourceType)
            case .Halt:
                break
            }
        }

        #if DEBUG_SWIFTFLOW
        ConduitCount++
        #endif
    }

    deinit {
        detach()

        #if DEBUG_SWIFTFLOW
        ConduitCount--
        #endif
    }

    public func detach() {
        self.rho?.detach()
        self.rho = nil

        self.lho?.detach()
        self.lho = nil
    }

    public func receive(x: T) {
        fatalError("Unimplemented")
    }
}


// FIXME: we need to keep this operator in SwiftFlow.swift instead of SwiftFlowZ.swift due to compiler crash “While emitting SIL for '<|' at SwiftFlowZ.swift:37:15”
prefix operator <| { }
public prefix func <| <T : Equatable>(rhs: T)->ChannelOf<T, T> {
    return sieveField(rhs)
}


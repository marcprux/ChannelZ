//
//  Outlets.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// An `Outlet` is the result of `attach`ing to a Funnel or Channel
public protocol Outlet {
    /// Disconnects this outlet from the source
    func detach()

    /// Requests that the source issue an element to this outlet; note that priming does not guarantee that the outlet will be received since the underlying source may be push-only source or the element may be blocked by an intermediate filter
    func prime()
}

/// An OutletType is a receiver for funneled state operations with the ability to detach itself from the source funnel
public protocol OutletType : Outlet {
    typealias Element

    /// Receives the state element
    func receive(value: Element)
}


/// A type-erased outlet.
///
/// Forwards operations to an arbitrary underlying outlet with the same
/// `Element` type, hiding the specifics of the underlying outlet.
public struct OutletOf<Element> : OutletType {
    let primer: ()->()
    let detacher: ()->()
    let receiver: (Element)->()

//    public init<O : OutletType where Element == O.Element>(_ base: O) {
//        self.primer = { base.prime() }
//        self.detacher = { base.detach() }
//        self.receiver = { base.receive($0) }
//    }
//
//    public init<S : SinkType where Element == S.Element>(sink: S) {
//        self.primer = { }
//        self.detacher = { }
//        self.receiver = { SinkOf(sink).put($0) }
//    }

    public init(primer: ()->(), detacher: ()->(), receiver: (Element)->() = { _ in }) {
        self.primer = primer
        self.detacher = detacher
        self.receiver = receiver
    }


    /// Receives the state element
    public func receive(value: Element) {
        self.receiver(value)
    }

    /// Disconnects this outlet from the source funnel
    public func detach() {
        self.detacher()
    }

    public func prime() {
        self.primer()
    }
}

/// A no-op outlet that warns that an attempt was made to attach to a deallocated weak target
struct DeallocatedTargetOutlet : Outlet {
    func detach() { }
    func prime() { }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: UInt = 1

final class OutletList<T> {
    private var outlets: [(index: UInt, outlet: OutletOf<T>)] = []
    internal var entrancy: UInt = 0
    private var outletIndex: UInt = 0

    func receive(element: T) {
        if entrancy++ > ChannelZReentrancyLimit {
            #if DEBUG_CHANNELZ
                println("re-entrant value change limit of \(ChannelZReentrancyLimit) reached for outlets")
            #endif
        } else {
            for (index, outlet) in outlets {
                outlet.receive(element)
            }
            entrancy--
        }
    }

    func addOutlet(#primer: ()->(), outlet: (T)->())->OutletOf<T> {
        precondition(entrancy == 0, "cannot add to outlets while they are flowing")
        let index: UInt = outletIndex++
        let outlet = OutletOf<T>(primer: primer, detacher: { [weak self] in self?.removeOutlet(index); return }, receiver: outlet)
        self.outlets += [(index, outlet)]
        return outlet
    }

    func removeOutlet(index: UInt) { outlets = outlets.filter { $0.index != index } }

    /// Clear all the outlets
    func clear() { outlets = [] }
}

/// Primes the outlet and returns the outlet itself
internal func prime(outlet: Outlet) -> Outlet {
    outlet.prime()
    return outlet
}

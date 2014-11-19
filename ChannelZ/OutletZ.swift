//
//  Outlets.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

public protocol Outlet {
    /// Disconnects this outlet from the source funnel
    func detach()
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
    let receiver: (Element)->()
    let detacher: ()->()

    public init<O : OutletType where Element == O.Element>(_ base: O) {
        self.receiver = { base.receive($0) }
        self.detacher = { base.detach() }
    }

    public init<S : SinkType where Element == S.Element>(sink: S) {
        self.receiver = { SinkOf(sink).put($0) }
        self.detacher = { }
    }

    public init(receiver: (Element)->(), detacher: ()->()) {
        self.receiver = receiver
        self.detacher = detacher
    }


    /// Receives the state element
    public func receive(value: Element) {
        self.receiver(value)
    }

    /// Disconnects this outlet from the source funnel
    public func detach() {
        self.detacher()
    }
}

/// A no-op outlet that warns that an attempt was made to attach to a deallocated weak target
struct DeallocatedTargetOutlet : Outlet {
    func detach() { }
}


/// How many levels of re-entrancy is permitted when flowing state observations
public var ChannelZOutletReentrancyGuard: UInt = 1

final class OutletListReference<T> {
    private var outlets: [(index: UInt, outlet: OutletOf<T>)] = []
    internal var entrancy: UInt = 0
    private var outletIndex: UInt = 0

    func receive(element: T) {
        if entrancy++ > ChannelZOutletReentrancyGuard {
            #if DEBUG_CHANNELZ
                println("re-entrant value change limit of \(ChannelZOutletReentrancyGuard) reached for outlets")
            #endif
        } else {
            for (index, outlet) in outlets {
                outlet.receive(element)
            }
            entrancy--
        }
    }

    func addOutlet(outlet: (T)->())->Outlet {
        assert(entrancy == 0, "cannot add to outlets while they are flowing")
        let index: UInt = outletIndex++
        let outlet = OutletOf<T>(receiver: outlet, detacher: { [weak self] in self?.removeOutlet(index); return })
        self.outlets += [(index, outlet)]
        return OutletOf(outlet)
    }

    func removeOutlet(index: UInt) { outlets = outlets.filter { $0.index != index } }

    /// Clear all the outlets
    func clear() { outlets = [] }
}


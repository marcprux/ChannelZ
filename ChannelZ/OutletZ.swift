//
//  Outlets.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import ObjectiveC // uses for synchronizing OutletList with objc_sync_enter

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
//    func receive(value: Element)
}


/// A type-erased outlet.
///
/// Forwards operations to an arbitrary underlying outlet with the same
/// `Element` type, hiding the specifics of the underlying outlet.
public struct OutletOf<T> : OutletType {
    let primer: ()->()
    let detacher: ()->()

    public typealias Element = T

    public init(primer: ()->(), detacher: ()->()) {
        self.primer = primer
        self.detacher = detacher
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
public var ChannelZReentrancyLimit: Int = 1

final class OutletList<T> {
    private var outlets: [(index: Int, outlet: (T)->())] = []
    internal var entrancy: Int = 0
    private var outletIndex: Int = 0

    private func synchronized<X>(lockObj: AnyObject!, closure: ()->X) -> X {
        if objc_sync_enter(lockObj) == Int32(OBJC_SYNC_SUCCESS) {
            var retVal: X = closure()
            objc_sync_exit(lockObj)
            return retVal
        } else {
            fatalError("Unable to synchronize on object")
        }
    }

    func receive(element: T) {
        synchronized(self) { ()->(Void) in
            if self.entrancy++ > ChannelZReentrancyLimit {
                #if DEBUG_CHANNELZ
                    println("re-entrant value change limit of \(ChannelZReentrancyLimit) reached for outlets")
                #endif
            } else {
                for (index, outlet) in self.outlets { outlet(element) }
            }
            self.entrancy--
        }
    }

    func addOutlet(outlet: (T)->(), primer: ()->() = { })->OutletOf<T> {
        return synchronized(self) {
            let index = self.outletIndex++
            let olet = OutletOf<T>(primer: primer, detacher: { [weak self] in self?.removeOutlet(index); return })
            precondition(self.entrancy == 0, "cannot add to outlets while they are flowing")
            self.outlets += [(index, outlet)]
            return olet
        }
    }

    func removeOutlet(index: Int) {
        synchronized(self) {
            self.outlets = self.outlets.filter { $0.index != index }
        }
    }

    /// Clear all the outlets
    func clear() {
        synchronized(self) {
            self.outlets = []
        }
    }
}

/// Primes the outlet and returns the outlet itself
internal func prime(outlet: Outlet) -> Outlet {
    outlet.prime()
    return outlet
}

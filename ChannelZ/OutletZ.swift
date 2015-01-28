//
//  Subscriptions.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import ObjectiveC // uses for synchronizing SubscriptionList with objc_sync_enter

/// An `Subscription` is the result of `subscribe`ing to a Observable or Channel
public protocol Subscription {
    /// Disconnects this outlet from the source
    func detach()

    /// Requests that the source issue an element to this outlet; note that priming does not guarantee that the outlet will be received since the underlying source may be push-only source or the element may be blocked by an intermediate filter
    func prime()
}

/// An SubscriptionType is a receiver for observableed state operations with the ability to detach itself from the source observable
public protocol SubscriptionType : Subscription {
    typealias Element

    /// The source of this outlet
    var source: Element { get }
}


/// A type-erased outlet.
///
/// Forwards operations to an arbitrary underlying outlet with the same
/// `Element` type, hiding the specifics of the underlying outlet.
public struct SubscriptionOf<T> : SubscriptionType {
    public typealias Element = T
    
    public let source: Element
    let primer: ()->()
    let detacher: ()->()

    internal init(source: Element, primer: ()->(), detacher: ()->()) {
        self.source = source
        self.primer = primer
        self.detacher = detacher
    }

    public init(source: Element, outlet: Subscription) {
        self.source = source
        self.primer = { outlet.prime() }
        self.detacher = { outlet.detach() }
    }

    /// Disconnects this outlet from the source observable
    public func detach() {
        self.detacher()
    }

    public func prime() {
        self.primer()
    }
}

/// A no-op outlet that warns that an attempt was made to subscribe to a deallocated weak target
struct DeallocatedTargetSubscription : Subscription {
    func detach() { }
    func prime() { }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

final class SubscriptionList<T> {
    private var outlets: [(index: Int, outlet: (T)->())] = []
    internal var entrancy: Int = 0
    private var outletIndex: Int = 0

    private func synchronized<X>(lockObj: AnyObject!, closure: ()->X) -> X {
        if objc_sync_enter(lockObj) == Int32(OBJC_SYNC_SUCCESS) {
            var retVal: X = closure()
            objc_sync_exit(lockObj)
            return retVal
        } else {
            fatalError("Unable to synchronize on SubscriptionList")
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

    func addSubscription(outlet: (T)->(), primer: ()->() = { })->Int {
        return synchronized(self) {
            let index = self.outletIndex++
            precondition(self.entrancy == 0, "cannot add to outlets while they are flowing")
            self.outlets += [(index, outlet)]
            return index
        }
    }

    func removeSubscription(index: Int) {
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
internal func prime<T>(outlet: SubscriptionOf<T>) -> SubscriptionOf<T> {
    outlet.prime()
    return outlet
}

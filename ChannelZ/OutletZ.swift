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
    /// Disconnects this subscription from the source
    func detach()

    /// Requests that the source issue an element to this subscription; note that priming does not guarantee that the subscription will be received since the underlying source may be push-only source or the element may be blocked by an intermediate filter
    func prime()
}

/// An SubscriptionType is a receiver for observableed state operations with the ability to detach itself from the source observable
public protocol SubscriptionType : Subscription {
    typealias Element

    /// The source of this subscription
    var source: Element { get }
}


/// A type-erased subscription.
///
/// Forwards operations to an arbitrary underlying subscription with the same
/// `Element` type, hiding the specifics of the underlying subscription.
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

    public init(source: Element, subscription: Subscription) {
        self.source = source
        self.primer = { subscription.prime() }
        self.detacher = { subscription.detach() }
    }

    /// Disconnects this subscription from the source observable
    public func detach() {
        self.detacher()
    }

    public func prime() {
        self.primer()
    }
}

/// A no-op subscription that warns that an attempt was made to subscribe to a deallocated weak target
struct DeallocatedTargetSubscription : Subscription {
    func detach() { }
    func prime() { }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

final class SubscriptionList<T> {
    private var subscriptions: [(index: Int, subscription: (T)->())] = []
    internal var entrancy: Int = 0
    private var subscriptionIndex: Int = 0

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
                    println("re-entrant value change limit of \(ChannelZReentrancyLimit) reached for subscriptions")
                #endif
            } else {
                for (index, subscription) in self.subscriptions { subscription(element) }
            }
            self.entrancy--
        }
    }

    func addSubscription(subscription: (T)->(), primer: ()->() = { })->Int {
        return synchronized(self) {
            let index = self.subscriptionIndex++
            precondition(self.entrancy == 0, "cannot add to subscriptions while they are flowing")
            self.subscriptions += [(index, subscription)]
            return index
        }
    }

    func removeSubscription(index: Int) {
        synchronized(self) {
            self.subscriptions = self.subscriptions.filter { $0.index != index }
        }
    }

    /// Clear all the subscriptions
    func clear() {
        synchronized(self) {
            self.subscriptions = []
        }
    }
}

/// Primes the subscription and returns the subscription itself
internal func prime<T>(subscription: SubscriptionOf<T>) -> SubscriptionOf<T> {
    subscription.prime()
    return subscription
}

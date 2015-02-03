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
    func unsubscribe()

    /// Requests that the source issue an element to this subscription; note that priming does not guarantee that the subscription will be received since the underlying source may be push-only source or the element may be blocked by an intermediate filter
    func request()
}

/// An SubscriptionType is a receiver for observableed state operations with the ability to unsubscribe itself from the source observable
public protocol SubscriptionType : Subscription {
}


/// A type-erased subscription.
///
/// Forwards operations to an arbitrary underlying subscription with the same
/// `Element` type, hiding the specifics of the underlying subscription.
public struct SubscriptionOf : SubscriptionType {
    let requester: ()->()
    let unsubscriber: ()->()

    internal init(requester: ()->(), unsubscriber: ()->()) {
        self.requester = requester
        self.unsubscriber = unsubscriber
    }

    public init(subscriptions: [Subscription]) {
        self.requester = { for s in subscriptions { s.request() } }
        self.unsubscriber = { for s in subscriptions { s.unsubscribe() } }
    }

    public init(subscription: Subscription) {
        self.init(subscriptions: [subscription])
    }

    /// Disconnects this subscription from the source observable
    public func unsubscribe() {
        self.unsubscriber()
    }

    public func request() {
        self.requester()
    }
}

/// A no-op subscription that warns that an attempt was made to subscribe to a deallocated weak target
struct DeallocatedTargetSubscription : Subscription {
    func unsubscribe() { }
    func request() { }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZReentrancyLimit: Int = 1

final class SubscriptionList<T> {
    private var subscriptions: [(index: Int, subscription: (T)->())] = []
    internal var entrancy: Int = 0
    private var subscriptionIndex: Int = 0

    var count: Int { return subscriptions.count }

    private func synchronized<X>(lockObj: AnyObject!, closure: ()->X) -> X {
        if objc_sync_enter(lockObj) == Int32(OBJC_SYNC_SUCCESS) {
            var retVal: X = closure()
            objc_sync_exit(lockObj)
            return retVal
        } else {
            fatalError("Unable to synchronize on SubscriptionList")
        }
    }

    /// Generates an Observable that will subscribe to this list
    func observable() -> Observable<T> {
        return Observable<T> { sub in
            let index = self.addSubscription(sub)
            return SubscriptionOf(requester: { }, unsubscriber: {
                self.removeSubscription(index)
            })
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

    func addSubscription(subscription: (T)->(), requester: ()->() = { })->Int {
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

/// Requests the subscription and returns the subscription itself
internal func request(subscription: Subscription) -> Subscription {
    subscription.request()
    return subscription
}



/// A TrapSubscription is a subscription to a observable that retains a number of values (default 1) when they are sent by the source
public class TrapSubscription<F : ObservableType>: SubscriptionType {
    typealias SourceType = F.Element
    typealias Element = F.Element

    public let source: F

    /// Returns the last value to be added to this trap
    public var value: F.Element? { return values.last }

    /// All the values currently held in the trap
    public var values: [F.Element]

    public let capacity: Int

    private var subscription: Subscription?

    public init(source: F, capacity: Int) {
        self.source = source
        self.values = []
        self.capacity = capacity
        self.values.reserveCapacity(capacity)

        let subscription = source.subscribe({ [weak self] (value) -> Void in
            let _ = self?.receive(value)
        })
        self.subscription = subscription
    }

    deinit { subscription?.unsubscribe() }
    public func unsubscribe() { subscription?.unsubscribe() }
    public func request() { subscription?.request() }

    public func receive(value: SourceType) {
        while values.count >= capacity {
            values.removeAtIndex(0)
        }

        values.append(value)
    }
}

/// Creates a trap for the last `capacity` (default 1) events of the `source` observable
public func trap<F : ObservableType>(source: F, capacity: Int = 1) -> TrapSubscription<F> {
    return TrapSubscription(source: source, capacity: capacity)
}

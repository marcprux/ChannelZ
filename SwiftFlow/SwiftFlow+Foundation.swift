//
//  SwiftFlow+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

import Foundation


/// A Channel for Cocoa properties that support key-value path observation/coding
public struct KeyValueChannel<T>: ChannelType {
    public typealias SourceType = T
    public typealias OutputType = StateEvent<T>

    private let observed: NSObject
    private let keyPath: String

    public init(receivee: NSObject, keyPath: String, value: T) {
        self.observed = receivee
        self.keyPath = keyPath

        let initialValue: AnyObject? = self.observed.valueForKeyPath(self.keyPath)
        if let initialValueActual: AnyObject = initialValue {
            if let value = value as? NSObject {
                if let eq1 = initialValueActual as? NSObjectProtocol {
                    assert(eq1.isEqual(value), "initial value for keyPath «\(keyPath)» did not match initial value for funnel")
                }
            }
        } else {
            preconditionFailure("non-optional keyPath «\(keyPath)» returned nil")
        }
    }

    public func push(value: SourceType) {
        self.observed.setValue(value as NSObject, forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        let v = self.observed.valueForKeyPath(self.keyPath) as SourceType
        return StateEvent(lastValue: v, nextValue: v)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        return KeyValueOutlet(observee: observed, keyPath: keyPath, handler: { (oldv, newv) in
            outlet(StateEvent(lastValue: oldv as SourceType, nextValue: newv as SourceType))
        })
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = KeyValueChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// A Channel for optional Cocoa properties that support key-value path observation/coding
/// We need separate handling for this because the briding between Swift Optionals and Cocoa has some subtle differences
public struct KeyValueOptionalChannel<T>: ChannelType {
    public typealias SourceType = Optional<T>
    public typealias OutputType = StateEvent<Optional<T>>

    private let observed: NSObject
    private let keyPath: String

    public init(receivee: NSObject, keyPath: String, value v: Optional<T>) {
        self.observed = receivee
        self.keyPath = keyPath

        let cv: AnyObject? = self.observed.valueForKeyPath(self.keyPath)
//        assert(cv === v || cv === nil || v == nil || cv as? T == v, "valueForKeyPath(\(keyPath)): \(cv) did not equal initialized value: \(v)")

        let nsnull = NSNull()
    }

    public func push(newValue: SourceType) {
        self.observed.setValue(newValue is NSNull ? nil : (newValue as? NSObject), forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        let v = self.observed.valueForKeyPath(self.keyPath) as SourceType
        return StateEvent(lastValue: v, nextValue: v)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        return KeyValueOutlet(observee: observed, keyPath: keyPath, handler: { (oldv, newv) in
            outlet(StateEvent(lastValue: oldv as? Optional<T> ?? nil, nextValue: newv as? Optional<T> ?? nil))
        })
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = KeyValueOptionalChannel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// How many levels of re-entrancy is permitted when flowing state observations
public var SwiftFlowKeyValueReentrancyGuard: UInt = 1

#if DEBUG_SWIFTFLOW
    /// Track how many observers we have created and released; useful for ensuring that outlets correctly clean up
    public var SwiftFlowKeyValueObserverCount = 0
#endif

/// outlet for Cocoa KVO changes; cannot be embedded within KeyValueChannel because Objective-C classes cannot use generics
private class KeyValueOutlet: NSObject, Outlet {
    var observee: NSObject
    let keyPath: String
    var attached: Bool = false
    var entrancy: UInt = 0
    typealias HandlerType = ((oldv: AnyObject?, newv: AnyObject?)->Void)
    var handler: HandlerType
    var ctx = UnsafeMutablePointer<Void>()

    init(observee: NSObject, keyPath: String, handler: HandlerType) {
        self.observee = observee
        self.keyPath = keyPath
        self.handler = handler
        super.init()
        attach()
    }

    func attach() {
        if OSAtomicTestAndSet(0, &attached) == false {
            observee.addObserver(self, forKeyPath: keyPath, options: .Old | .New, context: &ctx)
            #if DEBUG_SWIFTFLOW
                SwiftFlowKeyValueObserverCount++
            #endif
        }
    }

    func detach() {
        if OSAtomicTestAndClear(0, &attached) {
            observee.removeObserver(self, forKeyPath: keyPath, context: &ctx)
            #if DEBUG_SWIFTFLOW
                SwiftFlowKeyValueObserverCount--
            #endif
        }
    }

    deinit {
        detach()
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject: AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == &ctx {
            assert(object === observee)

            if entrancy++ > SwiftFlowKeyValueReentrancyGuard {
                #if DEBUG_SWIFTFLOW
                    NSLog("\(__FILE__.lastPathComponent):\(__LINE__): re-entrant value change limit of \(SwiftFlowKeyValueReentrancyGuard) reached for «\(observee).\(keyPath)»")
                #endif
            } else {
                let oldValue: AnyObject? = change[NSKeyValueChangeOldKey]
                let newValue: AnyObject? = change[NSKeyValueChangeNewKey]
                handler(oldv: oldValue, newv: newValue)
                entrancy--
            }

        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

extension NSObject {

    /// Creates a channel for all state operations for the given key-value-coding compliant property
    ///
    /// :param: value the initial value of the property
    /// :param: keyPath the keyPath for the value that will be observed (typically the same name as the property)
    public func channel<T>(value: T, keyPath: String)->ChannelOf<T, T> {
        return unrefinedRequired(self, keyPath, value)
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant property
    ///
    /// :param: value the initial value of the property
    /// :param: keyPath the keyPath for the value that will be observed (typically the same name as the property)
    public func sieve<T : Equatable>(value: T, keyPath: String)->ChannelOf<T, T> {
        return sieveRequired(self, keyPath, value)
    }


    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// :param: value the initial value of the optional property
    /// :param: keyPath the keyPath for the value that will be observed (typically the same name as the property)
    public func channel<T>(value: Optional<T>, keyPath: String)->KeyValueOptionalChannel<T> {
        return channelOptional(self, keyPath, value)
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant optional property
    ///
    /// :param: value the initial value of the optional property
    /// :param: keyPath the keyPath for the value that will be observed (typically the same name as the property)
    public func sieve<T : Equatable>(value: Optional<T>, keyPath: String)->ChannelOf<Optional<T>, Optional<T>> {
        return sieveOptional(self, keyPath, value)
    }
}


internal func channelRequired<T>(receivee: NSObject, keyPath: String, value: T)->KeyValueChannel<T> {
    return KeyValueChannel(receivee: receivee, keyPath: keyPath, value: value)
}

internal func unrefinedRequired<T>(receivee: NSObject, keyPath: String, value: T)->ChannelOf<T, T> {
    return channelRequired(receivee, keyPath, value).map({ $0.nextValue }).channelOf
}

/// Separate function to help the compiler distinguish signatures
public func sieveRequired<T : Equatable>(receivee: NSObject, keyPath: String, value: T)->ChannelOf<T, T> {
    return channelStateChanges(channelRequired(receivee, keyPath, value))
}

public func channelfield<T>(receivee: NSObject, keyPath: String, value: T)->KeyValueChannel<T> {
    return channelRequired(receivee, keyPath, value)
}

internal func channelOptional<T>(receivee: NSObject, keyPath: String, value: Optional<T>)->KeyValueOptionalChannel<T> {
    return KeyValueOptionalChannel(receivee: receivee, keyPath: keyPath, value: value)
}

public func channelfield<T>(receivee: NSObject, keyPath: String, value: Optional<T>)->KeyValueOptionalChannel<T> {
    return channelOptional(receivee, keyPath, value)
}


/// Separate function to help the compiler distinguish signatures
public func sieveOptional<T : Equatable>(receivee: NSObject, keyPath: String, value: Optional<T>)->ChannelOf<Optional<T>, Optional<T>> {
    return channelOptionalStateChanges(channelOptional(receivee, keyPath, value).channelOf)
}



/// A Funnel for events of type Void
public struct EventFunnel<T>: FunnelType {
    public typealias OutputType = T
    internal var dispatchTarget: NSObject? // object to be retained for as long as someone holds the EventFunnel
    internal var outlets = OutletListReference<OutputType>()

    public init(_ dispatchTarget: NSObject?) {
        self.dispatchTarget = dispatchTarget
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet { return outlets.addOutlet(outlet) }

    // Boilerplate funnel/filter/map
    private typealias ThisFunnel = EventFunnel
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<ThisFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<ThisFunnel, TransformedType> { return mapFunnel(self)(transform) }
}



/// A Funnel for NSNotificationCenter events
public struct NotificationFunnel: FunnelType {
    private let center: NSNotificationCenter
    private let receivee: NSObject
    private let name: String

    public typealias OutputType = NSNotification

    private init(center: NSNotificationCenter, receivee: NSObject, name: String) {
        self.center = center
        self.receivee = receivee
        self.name = name
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet the outlet closure to which state will be sent
    public func attach(outlet: (NSNotification)->())->Outlet {
        return NotificationObserver(center: center, observee: receivee, name: name, handler: { outlet($0) })
    }


    // Boilerplate funnel/filter/map
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<NotificationFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<NotificationFunnel, TransformedType> { return mapFunnel(self)(transform) }

}

/// Observer for NSNotification changes; cannot be embedded within KeyValueChannel because Objective-C classes cannot use generics
@objc public class NotificationObserver: NSObject, Outlet {
    let center: NSNotificationCenter
    let observee: NSObject
    let name: String
    var handler: (NSNotification)->(Void)
    var ctx = UnsafeMutablePointer<Void>()
    var attached: Bool = false

    init(center: NSNotificationCenter, observee: NSObject, name: String, handler: (NSNotification)->(Void)) {
        self.center = center
        self.observee = observee
        self.name = name
        self.handler = handler

        super.init()

        center.addObserver(self, selector: Selector("notificationOccurred:"), name: name, object: observee)
        self.attached = true

    }

    func notificationOccurred(note: NSNotification) {
        handler(note)
    }

    public func detach() {
        center.removeObserver(self, name: name, object: observee)
    }

    deinit {
        detach()
    }
}


/// Creates a Funnel on NSNotificationCenter
private func funnelNotification(center: NSNotificationCenter = NSNotificationCenter.defaultCenter(), receivee: NSObject, name: String)->NotificationFunnel {
    return NotificationFunnel(center: center, receivee: receivee, name: name)
}

public func funnel(center: NSNotificationCenter = NSNotificationCenter.defaultCenter(), receivee: NSObject, name: String)->NotificationFunnel {
    return funnelNotification(center: center, receivee, name)
}

extension NSObject {
    public func funnel(name: String, center: NSNotificationCenter = NSNotificationCenter.defaultCenter())->NotificationFunnel {
        return funnelNotification(center: center, self, name)
    }
}

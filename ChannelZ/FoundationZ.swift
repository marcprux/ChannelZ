//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// Support for Foundation channels and funnels, such as KVO-based channels
import Foundation

/// A Channel for Cocoa properties that support key-value path observation/coding
public struct KeyValueChannel<T>: ChannelType, DirectChannelType {
    public typealias SourceType = T
    public typealias OutputType = StateEvent<T>

    private let observed: NSObject
    private let keyPath: String
    private let getter: ()->T

    public init(receivee: NSObject, keyPath: String, value: @autoclosure ()->T) {
        self.observed = receivee
        self.keyPath = keyPath
        self.getter = value

        // validate the keyPath by checking that the initialized value matched the actual key path
        let initialValue: AnyObject? = self.observed.valueForKeyPath(self.keyPath)
        if let initialValueActual: AnyObject = initialValue {
            if let gotten = getter() as? NSObject {
                if let eq1 = initialValueActual as? NSObjectProtocol {
                    // make sure the key path is really returning the specified value
                    assert(eq1.isEqual(gotten), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(gotten)»")
                }
            }
        } else {
            preconditionFailure("valueForKeyPath(\(keyPath)): non-optional keyPath returned nil")
        }
    }

    /// DirectChannelType access to the underlying source value
    public var value : SourceType {
        // get { return pull().nextValue }
        get { return getter() } // this'll be much faster
        set(v) { push(v) }
    }

    public func push(value: SourceType) {
        self.observed.setValue(value as NSObject, forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        // let v = self.observed.valueForKeyPath(self.keyPath) as SourceType
        let v = getter() // much faster
        return StateEvent(lastValue: v, nextValue: v)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
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
public struct KeyValueOptionalChannel<T>: ChannelType, DirectChannelType {
    public typealias SourceType = Optional<T>
    public typealias OutputType = StateEvent<Optional<T>>

    private let observed: NSObject
    private let keyPath: String
    private let getter: ()->Optional<T>

    public init(receivee: NSObject, keyPath: String, value: @autoclosure ()->Optional<T>) {
        self.observed = receivee
        self.keyPath = keyPath
        self.getter = value

        // validate the keyPath by checking that the initialized value matched the actual key path, or at least that they are both nil
        let initialValue: AnyObject? = self.observed.valueForKeyPath(self.keyPath)
        let gotten = getter()
        assert((initialValue === nil && gotten == nil) || ((initialValue as? NSObject) == (gotten as? NSObject)), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(gotten)»")
    }

    /// DirectChannelType access to the underlying source value
    public var value : SourceType {
        get { return getter() }
        set(v) { push(v) }
    }

    public func push(newValue: SourceType) {
        self.observed.setValue(newValue is NSNull ? nil : (newValue as? NSObject), forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        let v = getter()
        return StateEvent(lastValue: v, nextValue: v)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        return KeyValueOutlet(observee: observed, keyPath: keyPath, handler: { (oldv, newv) in
            outlet(StateEvent(lastValue: oldv as? SourceType ?? nil, nextValue: newv as? SourceType ?? nil))
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
public var ChannelZKeyValueReentrancyGuard: UInt = 1

#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that outlets correctly clean up
    public var ChannelZKeyValueObserverCount = 0
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
            #if DEBUG_CHANNELZ
                ChannelZKeyValueObserverCount++
            #endif
        }
    }

    func detach() {
        if OSAtomicTestAndClear(0, &attached) {
            observee.removeObserver(self, forKeyPath: keyPath, context: &ctx)
            #if DEBUG_CHANNELZ
                ChannelZKeyValueObserverCount--
            #endif
        }
    }

    deinit {
        detach()
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject: AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == &ctx {
            assert(object === observee)

            if entrancy++ > ChannelZKeyValueReentrancyGuard {
                #if DEBUG_CHANNELZ
                    NSLog("\(__FILE__.lastPathComponent):\(__LINE__): re-entrant value change limit of \(ChannelZKeyValueReentrancyGuard) reached for «\(observee).\(keyPath)»")
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
    /// :param: getter      an autoclosure getter for the value of the property
    /// :param: keyPath     the keyPath for the value that will be observed (typically the same name as the property)
    public func channel<T>(getter: @autoclosure ()->T, keyPath: String)->ChannelZ<T> {
        return unrefinedRequired(self, keyPath, getter)
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant property
    ///
    /// :param: getter      an autoclosure getter for the value of the property
    /// :param: keyPath     the keyPath for the value that will be observed (typically the same name as the property)
    public func sieve<T : Equatable>(getter: @autoclosure ()->T, keyPath: String)->ChannelZ<T> {
        return sieveRequired(self, keyPath, getter())
    }

//    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant property, whose name is dynamically determined
//    ///
//    /// :param: getter        an autoclosure getter for the value of the object
//    public func sieve<T : NSObject where T : Equatable>(getter: @autoclosure ()->T)->ChannelZ<T> {
//        return sieveRequired(self, determineKeyPathForGetter(self, getter()), getter)
//    }


    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// :param: getter      an autoclosure getter for the value of the optional
    /// :param: keyPath     the keyPath for the value that will be observed (typically the same name as the property)
    public func channel<T>(getter: @autoclosure ()->Optional<T>, keyPath: String)->KeyValueOptionalChannel<T> {
        return channelOptional(self, keyPath, getter)
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant optional property
    ///
    /// :param: getter      an autoclosure getter for the value of the optional
    /// :param: keyPath     the keyPath for the value that will be observed (typically the same name as the property)
    public func sieve<T : Equatable>(getter: @autoclosure ()->Optional<T>, keyPath: String)->ChannelZ<Optional<  T>> {
        return sieveOptional(self, keyPath, getter)
    }

//    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant property, whose name is dynamically determined
//    ///
//    /// :param: getter        an autoclosure getter for the value of the object
//    public func channel<T : NSObject where T : Equatable>(getter: @autoclosure ()->T)->ChannelZ<T> {
//        return unrefinedRequired(self, determineKeyPathForGetter(self, getter()), getter)
//    }

}

/// Based on the given getter, use reflection to determine the keyPath for the instance
internal func determineKeyPathForGetter(ob: NSObject, value: NSObject)->String {
    let obMirror: MirrorType = reflect(ob)
    let count = obMirror.count // crashes randomly!
    for i in 0...count {
        let (propName, propMirror) = obMirror[i]
        let propValue = propMirror.value
        if propValue is NSObject {
            if (propValue as NSObject) === value {
                return propName
            }
        }
    }

    preconditionFailure("could not determine keyPath from initial object value; specify it manually instead")
}

internal func channelRequired<T>(receivee: NSObject, keyPath: String, value: @autoclosure ()->T)->KeyValueChannel<T> {
    return KeyValueChannel(receivee: receivee, keyPath: keyPath, value: value)
}

internal func unrefinedRequired<T>(receivee: NSObject, keyPath: String, value: @autoclosure ()->T)->ChannelZ<T> {
    return ChannelZ(channelRequired(receivee, keyPath, value).map({ $0.nextValue }))
}

/// Separate function to help the compiler distinguish signatures
public func sieveRequired<T : Equatable>(receivee: NSObject, keyPath: String, value: @autoclosure ()->T)->ChannelZ<T> {
    return channelStateChanges(channelRequired(receivee, keyPath, value))
}

public func channelfield<T>(receivee: NSObject, keyPath: String, value: @autoclosure ()->T)->KeyValueChannel<T> {
    return channelRequired(receivee, keyPath, value)
}

internal func channelOptional<T>(receivee: NSObject, keyPath: String, value: @autoclosure ()->Optional<T>)->KeyValueOptionalChannel<T> {
    return KeyValueOptionalChannel(receivee: receivee, keyPath: keyPath, value: value)
}

public func channelfield<T>(receivee: NSObject, keyPath: String, value: @autoclosure ()->Optional<T>)->KeyValueOptionalChannel<T> {
    return channelOptional(receivee, keyPath, value)
}


/// Separate function to help the compiler distinguish signatures
public func sieveOptional<T : Equatable>(receivee: NSObject, keyPath: String, value: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> {
    return ChannelZ(channelOptionalStateChanges(channelOptional(receivee, keyPath, value).channelOf))
}



/// A Funnel for events of a custom type
public struct EventFunnel<T>: FunnelType {
    public typealias OutputType = T
    internal var dispatchTarget: NSObject? // object to be retained for as long as someone holds the EventFunnel
    internal var outlets = OutletListReference<OutputType>()

    public init(_ dispatchTarget: NSObject?) {
        self.dispatchTarget = dispatchTarget
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
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
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: (NSNotification)->())->Outlet {
        return NotificationObserver(center: center, observee: receivee, name: name, handler: { outlet($0) })
    }


    // Boilerplate funnel/filter/map
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
    public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<NotificationFunnel> { return filterFunnel(self)(predicate) }
    public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<NotificationFunnel, TransformedType> { return mapFunnel(self)(transform) }

}

#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that outlets correctly clean up
    public var ChannelZNotificationObserverCount = 0
#endif

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
        #if DEBUG_CHANNELZ
            ChannelZNotificationObserverCount++
        #endif

    }

    func notificationOccurred(note: NSNotification) {
        handler(note)
    }

    public func detach() {
        if self.attached {
            center.removeObserver(self, name: name, object: observee)
            self.attached = false
            #if DEBUG_CHANNELZ
                ChannelZNotificationObserverCount--
            #endif
        }
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

/// Extension for listening to notifications of a given type
extension NSObject {
    /// Registers with the NSNotificationCenter to funnel event notications of the given name for this object
    ///
    /// :param: name    the name of the notification to register
    /// :param: center  the NSNotificationCenter to register with (defaults to defaultCenter())
    public func funnel(name: String, center: NSNotificationCenter = NSNotificationCenter.defaultCenter())->NotificationFunnel {
        return funnelNotification(center: center, self, name)
    }
}


/// Conduit operator with coersion via foundation types

infix operator <!∞!> { }
public func <!∞!><T : ChannelType, U : ChannelType where T.OutputType: StringLiteralConvertible, U.OutputType: StringLiteralConvertible>(lhs: T, rhs: U)->Outlet {
    let lhsm = lhs.map({ $0 as NSString as U.SourceType })
    let rhsm = rhs.map({ $0 as NSString as T.SourceType })

    return pipe(lhsm, rhsm)
}

public func <!∞!><T : ChannelType, U : ChannelType where T.OutputType: IntegerLiteralConvertible, U.OutputType: IntegerLiteralConvertible>(lhs: T, rhs: U)->Outlet {
    let lhsm = lhs.map({ $0 as NSNumber as U.SourceType })
    let rhsm = rhs.map({ $0 as NSNumber as T.SourceType })

    return pipe(lhsm, rhsm)
}

public func <!∞!><T : ChannelType, U : ChannelType where T.OutputType: FloatLiteralConvertible, U.OutputType: FloatLiteralConvertible>(lhs: T, rhs: U)->Outlet {
    let lhsm = lhs.map({ $0 as NSNumber as U.SourceType })
    let rhsm = rhs.map({ $0 as NSNumber as T.SourceType })

    return pipe(lhsm, rhsm)
}

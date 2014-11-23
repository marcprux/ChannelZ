//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// Support for Foundation channels and funnels, such as KVO-based channels and NSNotificationCenter funnels
import Foundation


/// Extension on NSObject that permits creating a channel from a key-value compliant property
extension NSObject {

    /// Creates a channel for all state operations for the given key-value-coding compliant property
    ///
    /// :param: getter      an autoclosure accessor for the value of the property
    /// :param: keyPath     the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func channelz<T>(getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
        return channelRequired(self, getter, keyPath: keyPath)
    }

    /// Creates a sieve for all state changes for the given key-value-coding compliant property
    ///
    /// :param: getter     an autoclosure accessor for the value of the property
    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func sievez<T : Equatable>(getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
        return sieveRequired(self, getter, keyPath: keyPath)
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// :param: getter     an autoclosure accessor for the value of the optional
    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func channelz<T>(getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
        return channelOptional(self, getter, keyPath: keyPath)
    }

    /// Creates a sieve for all state changes for the given key-value-coding compliant optional property
    ///
    /// :param: getter     an autoclosure accessor for the value of the optional
    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func sievez<T : Equatable>(getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
        return sieveOptional(self, getter, keyPath: keyPath)
    }
}

private func channelRequired<T>(target: NSObject, getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
    return ChannelZ(channelRequiredKeyValue(target, keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, getter()).map({ $0.nextValue }))
}

/// Separate function to help the compiler distinguish signatures
private func sieveRequired<T : Equatable>(target: NSObject, getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
    return channelStateChanges(channelRequiredKeyValue(target, keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, getter()))
}

private func channelOptional<T>(target: NSObject, getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
    return ChannelZ(channelStateValues(KeyValueOptionalChannel(target: target, keyPath: keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, value: getter()).channelOf))
}

/// Separate function to help the compiler distinguish signatures
private func sieveOptional<T : Equatable>(target: NSObject, getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
    return ChannelZ(channelOptionalStateChanges(KeyValueOptionalChannel(target: target, keyPath: keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, value: getter()).channelOf))
}


private func channelRequiredKeyValue<T>(target: NSObject, keyPath: String, value: T)->KeyValueRequiredChannel<T> {
    return KeyValueRequiredChannel(target: target, keyPath: keyPath, value: value)
}

/// Root protocol for required and optional key-value-observing channels
public protocol KeyValueChannel: ChannelType, DirectChannelType {
    /// The keyPath for this channel
    var keyPath: String { get }

    /// The target object of this channel
    var target: NSObject? { get }
}

/// A Channel for Cocoa properties that support key-value path observation/coding
public struct KeyValueRequiredChannel<T>: KeyValueChannel {
    public typealias SourceType = T
    public typealias OutputType = StateEvent<T>

    public private(set) weak var target: NSObject?
    public let keyPath: String

    public init(target: NSObject, keyPath: String, value: T) {
        self.target = target
        self.keyPath = keyPath

        // validate the keyPath by checking that the initialized value matched the actual key path
        let initialValue: AnyObject? = target.valueForKeyPath(self.keyPath)
        if let initialValueActual: AnyObject = initialValue {
            if let gotten = value as? NSObject {
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
    public var value: SourceType {
        get { return pull().nextValue }
        nonmutating set(v) { push(v) }
    }

    public func push(value: SourceType) {
        self.target?.setValue(value as NSObject, forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        if let target = target {
            let v = target.valueForKeyPath(self.keyPath) as SourceType
            return StateEvent(lastValue: nil, nextValue: v)
        } else {
            preconditionFailure("attempt to pull from keyPath «\(keyPath)» of a deallocated instance; channels do not retain their targets")
        }
    }

    /// Requests that the channel emit an event
    public func pump()->Void {
        self.target?.willChangeValueForKey(self.keyPath)
        self.target?.didChangeValueForKey(self.keyPath)
    }

    func coerce(ob: AnyObject?) -> SourceType? {
        if let ob = ob as? SourceType {
            return ob
        } else if let ob = ob as? NSNumber {
            // when an NSNumber is sent to an observer that is listening for a particular primitive, try to coerce it
            if SourceType.self is UInt64.Type {
                return ob.unsignedLongLongValue as? SourceType
            } else if SourceType.self is Int64.Type {
                return ob.longLongValue as? SourceType
            } else if SourceType.self is Double.Type {
                return ob.doubleValue as? SourceType
            } else if SourceType.self is Float.Type {
                return ob.floatValue as? SourceType
            } else if SourceType.self is UInt.Type {
                return ob.unsignedLongValue as? SourceType
            } else if SourceType.self is Int.Type {
                return ob.integerValue as? SourceType
            } else if SourceType.self is UInt32.Type {
                return ob.unsignedIntValue as? SourceType
            } else if SourceType.self is Int32.Type {
                return ob.intValue as? SourceType
            } else if SourceType.self is UInt16.Type {
                return ob.unsignedShortValue as? SourceType
            } else if SourceType.self is Int16.Type {
                return ob.shortValue as? SourceType
            } else if SourceType.self is UInt8.Type {
                return ob.unsignedCharValue as? SourceType
            } else if SourceType.self is Int8.Type {
                return ob.charValue as? SourceType
            } else if SourceType.self is Bool.Type {
                return ob.boolValue as? SourceType
            }
        }

        return nil
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        if let target = target {
            let kp = keyPath
            return KeyValueOutlet(target: target, keyPath: keyPath, handler: { (oldv, newv) in
                // for example, we are watching a NSMutableDictionary's key that is set to an NSString and then an NSNumber
                if let newv = self.coerce(newv) {
                    // option type check is because Initial option sends oldValue as nil
                    outlet(StateEvent(lastValue: self.coerce(oldv), nextValue: newv))
                } else {
                    assert(newv is SourceType, "required value for «\(kp)» changed type from \(oldv) to \(newv); use an optional channel if value type can change")
                }
            })
        } else {
            NSLog("ChannelZ warning: attempt to attach to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
            return DeallocatedTargetOutlet()
        }
    }


    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = KeyValueRequiredChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// A Channel for optional Cocoa properties that support key-value path observation/coding
public struct KeyValueOptionalChannel<T>: KeyValueChannel {

    // We need separate handling for optionals because the briding between Swift Optionals and Cocoa has some subtle differences

    public typealias SourceType = Optional<T>
    public typealias OutputType = StateEvent<Optional<T>>

    public private(set) weak var target: NSObject?
    public let keyPath: String

    public init(target: NSObject, keyPath: String, value: Optional<T>) {
        self.target = target
        self.keyPath = keyPath

        // validate the keyPath by checking that the initialized value matched the actual key path, or at least that they are both nil
        let initialValue: AnyObject? = target.valueForKeyPath(self.keyPath)
        assert((initialValue === nil && value == nil) || ((initialValue as? NSObject) == (value as? NSObject)), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(value)»")
    }

    /// DirectChannelType access to the underlying source value
    public var value: SourceType {
        get { return pull().nextValue }
        nonmutating set(v) { push(v) }
    }

    public func push(newValue: SourceType) {
        self.target?.setValue(newValue is NSNull ? nil : (newValue as? NSObject), forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        if let target = target {
            let v = target.valueForKeyPath(self.keyPath) as SourceType
            return StateEvent(lastValue: nil, nextValue: v)
        } else {
            return StateEvent(lastValue: nil, nextValue: nil)
        }
    }

    /// Requests that the channel emit an event
    public func pump()->Void {
        self.target?.willChangeValueForKey(self.keyPath)
        self.target?.didChangeValueForKey(self.keyPath)
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        if let target = target {
            return KeyValueOutlet(target: target, keyPath: keyPath, handler: { (oldv, newv) in
                outlet(StateEvent(lastValue: oldv as? SourceType, nextValue: newv as? SourceType ?? nil))
            })
        } else {
            NSLog("ChannelZ warning: attempt to attach to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
            return DeallocatedTargetOutlet()
        }
    }

    // Boilerplate funnel/channel/filter/map
    public typealias SelfChannel = KeyValueOptionalChannel

    /// Returns a type-erasing funnel around the current channel, making the channel read-only to subsequent pipeline stages
    public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }

    /// Returns a type-erasing channel wrapper around the current channel
    public var channelOf: ChannelOf<SourceType, OutputType> { return ChannelOf(self) }

    /// Returns a filtered channel that only flows elements that pass the predicate through to the outlets
    public func filter(predicate: (OutputType)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }

    /// Returns a mapped channel that transforms the elements before passing them through to the outlets
    public func map<OutputTransformedType>(transform: (OutputType)->OutputTransformedType)->MappedChannel<SelfChannel, OutputTransformedType, SelfChannel.SourceType> { return mapOutput(self, transform) }

    /// Returns a mapped channel that transforms source elements through the given transform before pushing them back to the source
    public func rmap<SourceTransformedType>(transform: (SourceTransformedType)->SourceType)->MappedChannel<SelfChannel, SelfChannel.OutputType, SourceTransformedType> { return mapSource(self, transform) }

    /// Returned a combined channel where signals from either channel will be combined into a signal for the combined channel's receivers
    public func combine<WithChannel>(channel: WithChannel)->CombinedChannel<SelfChannel, WithChannel> { return combineChannel(self)(channel2: channel) }
}


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZKeyValueReentrancyGuard: UInt = 1

#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that outlets are correctly cleaned up
    public var ChannelZKeyValueObserverCount = 0
#endif

/// Optional protocol for target objects to implement when they need to supplement key-value observing with additional events
@objc public protocol KeyValueChannelSupplementing {
    /// Add additional observers for the specified keyPath, returning the detacher for any supplements
    func supplementKeyValueChannel(forKeyPath: String, outlet: (AnyObject?)->()) -> (()->())?
}

/// outlet for Cocoa KVO changes
private struct KeyValueOutlet: Outlet {
    typealias HandlerType = ((oldv: AnyObject?, newv: AnyObject?)->Void)
    weak var observer: TargetAssociatedObserver?
    var supplementaryDetachable: (()->())?

    init(target: NSObject, keyPath: String, handler: HandlerType) {
        var entrancy: UInt = 0

        self.observer = TargetAssociatedObserver(target: target, keyPath: keyPath, kvoptions: NSKeyValueObservingOptions(NSKeyValueObservingOptions.Old.rawValue | NSKeyValueObservingOptions.New.rawValue), callback: { (change: [NSObject : AnyObject]) -> () in

            if entrancy++ > ChannelZKeyValueReentrancyGuard {
                #if DEBUG_CHANNELZ
                    NSLog("\(__FILE__.lastPathComponent):\(__LINE__): re-entrant value change limit of \(ChannelZKeyValueReentrancyGuard) reached for «\(keyPath)»")
                #endif
            } else {
                handler(oldv: change[NSKeyValueChangeOldKey], newv: change[NSKeyValueChangeNewKey])
                entrancy--
            }
        })

        // If the target object supports supplementing the KVO, install their outlets here
        if let supplementable = target as? KeyValueChannelSupplementing {
            supplementaryDetachable = supplementable.supplementKeyValueChannel(keyPath) { value in
                // we don't have access to the previous value here, so send nil to force it to pass any sieves
                handler(oldv: nil, newv: value)
            }
        }

    }

    func detach() {
        observer?.deactivate()
        supplementaryDetachable?()
    }
}

/// Am observer that is stored as an associated object in the target and is automatically removed when the target is deallocated; can be with either for KVO or NSNotificationCenter depending on the constructor arguments
final class TargetAssociatedObserver : NSObject {
    var assocctx = UnsafePointer<Void>()
    var kvoctx = UnsafePointer<Void>()
    var active : UInt32 = 0
    let keyPath: NSString
    let center: NSNotificationCenter?
    let callback: ([NSObject : AnyObject])->()

    weak var target: NSObject?
    let targetPtr: Unmanaged<NSObject>
    var infoPtr: UnsafeMutablePointer<Void>?
    var instrumentedKVO = true

    init(target: NSObject, keyPath: String, kvoptions: NSKeyValueObservingOptions? = nil, center: NSNotificationCenter? = nil, callback: ([NSObject : AnyObject])->()) {
        self.keyPath = keyPath
        self.callback = callback
        self.center = center

        self.target = target
        // since this associated object is deallocated as part of the owning object's dealloc (see objc_destructInstance in <http://opensource.apple.com/source/objc4/objc4-646/runtime/objc-runtime-new.mm>), we can't rely on the weak reference not having been zeroed, so keep around an extra unmanaged pointer to the target object that we can use to remove the observer
        self.targetPtr = Unmanaged.passUnretained(target)

        super.init()

        objc_setAssociatedObject(target, &assocctx, self, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        if !OSAtomicTestAndSet(0, &active) {
            ChannelZKeyValueObserverCount++
            if let center = center {
                center.addObserver(self, selector: Selector("notificationReceived:"), name: keyPath, object: target)
            } else if let kvoptions = kvoptions {
                target.addObserver(self, forKeyPath: keyPath, options: kvoptions, context: &kvoctx)
                self.infoPtr = target.observationInfo
                self.instrumentedKVO = NSStringFromClass(target.dynamicType).hasPrefix(ChannelZKVOSwizzledISAPrefix)
            } else {
                preconditionFailure("either NSKeyValueObservingOptions or NSNotificationCenter must be specified")
            }
        }
    }

    /// Callback when in NSNotificationCenter mode
    func notificationReceived(note: NSNotification) {
        self.callback(note.userInfo ?? [:])
    }

    /// Callback when in Key-Value Observation mode
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        assert(object === target)
        assert(keyPath == self.keyPath)
        self.callback(change)
    }

    /// Removes this object as an observer of the target
    private func deactivate() {
        let this = self
        if OSAtomicTestAndClear(0, &active) {
            let object = (target ?? targetPtr.takeUnretainedValue())
            if let center = center { // NSNotificationCenter mode
                center.removeObserver(this, name: keyPath, object: object)
            } else { // KVO mode
                object.removeObserver(this, forKeyPath: keyPath, context: &kvoctx)
            }
            ChannelZKeyValueObserverCount--
        }
    }

    deinit {
        deactivate()
    }
}

/// The class prefix that Cocoa prepends to the generated subclass that is swizzled in for KVO handling
let ChannelZKVOSwizzledISAPrefix = "NSKVONotifying_"

/// The class prefix that ChannelZ appends to the generated subclass that is swizzled in for automatic keyPath identification
let ChannelZInstrumentorSwizzledISASuffix = "_ChannelZKeyInspection"

/// The shared lock used for swizzling in for instrumentation subclass creation
let ChannelZKeyPathForAutoclosureLock = NSLock()

/// Attempts to determine the properties that are accessed by the given autoclosure; does so by temporarily swizzling the object's isa pointer to a generated subclass that instruments access to all the properties; note that this is not thread-safe in the unlikely event that another method (e.g., KVO swizzling) is being used at the same time for the class on another thread
private func keyPathForAutoclosure<T>(target: NSObject, accessor: ()->T, required: Bool) -> String? {
    var keyPath: String?

    let origclass : AnyClass = object_getClass(target)
    var className = NSStringFromClass(origclass)

    let subclassName = className + ChannelZInstrumentorSwizzledISASuffix // unique subclass name
    let subclass : AnyClass = objc_allocateClassPair(origclass, subclassName, 0)
    var propSelIMPs: [IMP] = []

    let nsobjectclass : AnyClass = object_getClass(NSObject())

    for var propclass : AnyClass = origclass; propclass !== nsobjectclass; propclass = class_getSuperclass(propclass) {

        var propCount : UInt32 = 0
        let propList = class_copyPropertyList(propclass, &propCount)
        // println("instrumenting \(propCount) properties of \(NSStringFromClass(propclass))")

        for i in 0..<propCount {
            let prop = propList[Int(i)]

            let pname = property_getName(prop)
            let propName = String.fromCString(pname)

            // the selector we will implement will be the getter for the property; these often differ with bools (e.g. "enabled" vs. "isEnabled")
            let gname = property_copyAttributeValue(prop, "G") // the getter name
            let getterName = String.fromCString(gname)
            free(gname)

            let ronly = property_copyAttributeValue(prop, "R") // whether the property is read-only
            let readonly = ronly != nil
            free(ronly)

            if let propName = propName {
                if let propSelName = getterName ?? propName {
                    // println("instrumenting \(NSStringFromClass(propclass)).\(propSelName) (prop=\(propName) getter=\(getterName) readonly=\(readonly))")
                    let propSel = Selector(propSelName)

                    let method = class_getInstanceMethod(propclass, propSel)
                    if method == nil { continue }

                    if class_getInstanceMethod(nsobjectclass, propSel) != nil { continue }

                    let typeEncoding = method_getTypeEncoding(method)
                    if typeEncoding == nil { continue }

                    let returnTypePtr = method_copyReturnType(method)
                    let returnType = String.fromCString(returnTypePtr) ?? "@"
                    free(returnTypePtr)

                    let propBlock : @objc_block (AnyObject) -> AnyObject? = { (sself : AnyObject) -> (AnyObject?) in
                        // add the name of the property that was accessed; read-only properties tend to use their getterName as the key path (e.g., NSOperation.isFinished)
                        let keyName = readonly && getterName != nil ? getterName! : propName
                        keyPath = keyName // remember the keyPath for later
                        object_setClass(target, origclass) // immediately swap the isa back to the original
                        return target.valueForKey(keyName) // and defer the invocation to the discovered keyPath (throwing a helpful exception is we are wrong)
                    }

                    let propSelIMP = imp_implementationWithBlock(unsafeBitCast(propBlock, AnyObject.self))
                    if !class_addMethod(subclass, propSel, propSelIMP, typeEncoding) {
                        // ignore errors; sometimes happens with UITextField.inputView or NSView.tag
                        // println("could not add method implementation")
                    }
                    propSelIMPs += [propSelIMP]

                }
            }
        }

        free(propList)
    }

    ChannelZKeyPathForAutoclosureLock.lock()
    objc_registerClassPair(subclass)
    object_setClass(target, subclass)

    accessor() // invoke the accessor to see what instrumented properties are accessed

    // resore the isa if we haven't done already and destroy the instrumenter subclass
    if object_getClass(target) !== origclass {
        object_setClass(target, origclass)
    }

    // clear the implementation blocks
    for propSelIMP in propSelIMPs { imp_removeBlock(propSelIMP) }

    // remove the subclass
    objc_disposeClassPair(subclass)
    ChannelZKeyPathForAutoclosureLock.unlock()

    if required && keyPath == nil {
        fatalError("could not determine autoclosure key path through instrumentation of «\(className)»; ensure that the property is accessed directly in the invocation and that it is key-vaue compliant, or else manually specify the keyPath parameter")
    }

    // println("returning property «\(keyPath)»")
    return keyPath
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
    private weak var target: NSObject?
    private let name: String

    public typealias OutputType = [NSObject : AnyObject]

    private init(center: NSNotificationCenter, target: NSObject, name: String) {
        self.center = center
        self.target = target
        self.name = name
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: ([NSObject : AnyObject])->())->Outlet {
        if let target = target {
            return NotificationObserver(center: center, observee: target, name: name, handler: { outlet($0) })
        } else {
            NSLog("ChannelZ warning: attempt to attach to a deallocated target notification «\(name)»; channels do not retain their targets")
            return DeallocatedTargetOutlet()
        }
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

/// Observer for NSNotification changes; cannot be embedded within KeyValueRequiredChannel because Objective-C classes cannot use generics
public struct NotificationObserver: Outlet {
    private weak var observer : TargetAssociatedObserver?

    init(center: NSNotificationCenter, observee: NSObject, name: String, handler: ([NSObject : AnyObject])->(Void)) {
        self.observer = TargetAssociatedObserver(target: observee, keyPath: name, center: center, callback: { (userInfo: [NSObject : AnyObject]) -> () in
            handler(userInfo)
        })
    }

    public func detach() {
        self.observer?.deactivate()
    }

}


/// Creates a Funnel on NSNotificationCenter
private func funnelNotification(center: NSNotificationCenter = NSNotificationCenter.defaultCenter(), target: NSObject, name: String)->NotificationFunnel {
    return NotificationFunnel(center: center, target: target, name: name)
}

public func funnel(center: NSNotificationCenter = NSNotificationCenter.defaultCenter(), target: NSObject, name: String)->NotificationFunnel {
    return funnelNotification(center: center, target, name)
}

/// Extension for listening to notifications of a given type
extension NSObject {
    /// Registers with the NSNotificationCenter to funnel event notications of the given name for this object
    ///
    /// :param: notificationName    the name of the notification to register
    /// :param: center              the NSNotificationCenter to register with (defaults to defaultCenter())
    public func notifyz(notificationName: String, center: NSNotificationCenter = NSNotificationCenter.defaultCenter())->NotificationFunnel {
        return funnelNotification(center: center, self, notificationName)
    }
}

/// Operator for getting a keypath channel from an NSObject
infix operator ∞ { precedence 255 }

/// Infix operator for creating a channel from an auto-discovered keyPath to a non-optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T>(lhs: NSObject, rhs: @autoclosure ()->T)->ChannelZ<T> { return channelRequired(lhs, rhs) }

/// Infix operator for creating a channel from an auto-discovered keyPath to an equatable non-optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T : Equatable>(lhs: NSObject, rhs: @autoclosure ()->T)->ChannelZ<T> { return sieveRequired(lhs, rhs) }

/// Infix operator for creating a channel from an auto-discovered keyPath to an optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T>(lhs: NSObject, rhs: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> { return channelOptional(lhs, rhs) }

/// Infix operator for creating a channel from an auto-discovered keyPath to an equatable optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T : Equatable>(lhs: NSObject, rhs: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> { return sieveOptional(lhs, rhs) }

/// Infix operator for creating a channel from the specified keyPath to a non-optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T>(lhs: NSObject, rhs: (getter: @autoclosure ()->T, keyPath: String))->ChannelZ<T> { return channelRequired(lhs, rhs.getter, keyPath: rhs.keyPath) }

/// Infix operator for creating a channel from the specified keyPath to an equatable non-optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T : Equatable>(lhs: NSObject, rhs: (getter: @autoclosure ()->T, keyPath: String))->ChannelZ<T> { return sieveRequired(lhs, rhs.getter, keyPath: rhs.keyPath) }

/// Infix operator for creating a channel from the specified keyPath to an optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T>(lhs: NSObject, rhs: (getter: @autoclosure ()->Optional<T>, keyPath: String))->ChannelZ<Optional<T>> { return channelOptional(lhs, rhs.getter, keyPath: rhs.keyPath) }

/// Infix operator for creating a channel from the specified keyPath to an equatable optional property
///
/// :returns: a ChannelZ wrapper for the objects KVO field
public func ∞ <T : Equatable>(lhs: NSObject, rhs: (getter: @autoclosure ()->Optional<T>, keyPath: String))->ChannelZ<Optional<T>> { return sieveOptional(lhs, rhs.getter, keyPath: rhs.keyPath) }


///// Operator for getting an optional keypath channel from an NSObject
//infix operator ∞? { precedence 255 }
//
///// Infix operator for creating a channel from an auto-discovered keyPath to a forced optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞? <T>(lhs: NSObject, rhs: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> { return channelOptional(lhs, rhs) }
//
//


/// Conduit operator with coersion via foundation types
infix operator <~∞~> { }

/// Convert (possibly lossily) between two string types by casting them through NSNumber
public func <~∞~><L : ChannelType, R : ChannelType where L.SourceType: StringLiteralConvertible, L.OutputType: StringLiteralConvertible, R.SourceType: StringLiteralConvertible, R.OutputType: StringLiteralConvertible>(lhs: L, rhs: R)->Outlet {
    let lhsm = lhs.map({ $0 as NSString as R.SourceType })
    let rhsm = rhs.map({ $0 as NSString as L.SourceType })

    return conduit(lhsm, rhsm)
}

/// Convert (possibly lossily) between two numeric types by casting them through NSNumber
public func <~∞~><L : ChannelType, R : ChannelType where L.SourceType: IntegerLiteralConvertible, L.OutputType: IntegerLiteralConvertible, R.SourceType: IntegerLiteralConvertible, R.OutputType: IntegerLiteralConvertible>(lhs: L, rhs: R)->Outlet {
    let lhsm = lhs.map({ $0 as NSNumber as R.SourceType })
    let rhsm = rhs.map({ $0 as NSNumber as L.SourceType })

    return conduit(lhsm, rhsm)
}

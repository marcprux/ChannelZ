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

    private weak var target: NSObject?
    private let keyPath: String

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
    public var value : SourceType {
        get { return pull().nextValue }
        nonmutating set(v) { push(v) }
    }

    public func push(value: SourceType) {
        self.target?.setValue(value as NSObject, forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        if let target = target {
            let v = target.valueForKeyPath(self.keyPath) as SourceType
            return StateEvent(lastValue: v, nextValue: v)
        } else {
            preconditionFailure("attempt to pull from keyPath «\(keyPath)» of a deallocated instance; channels do not retain their targets")
        }
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
        let kp = keyPath
        if let target = target {
            return KeyValueOutlet(target: target, keyPath: keyPath, handler: { (oldv, newv) in
                // for example, we are watching a NSMutableDictionary's key that is set to an NSString and then an NSNumber
                if let newv = self.coerce(newv) {
                    // option type check is because Initial option sends oldValue as nil
                    outlet(StateEvent(lastValue: self.coerce(oldv) ?? newv, nextValue: newv))

                } else {
                    assert(newv is SourceType, "required value for «\(kp)» changed type; use an optional channel if value type can change")
                }
            })
        } else {
            NSLog("ChannelZ warning: attempt to attach to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
            return DeallocatedTargetOutlet()
        }
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

    private weak var target: NSObject?
    private let keyPath: String

    public init(target: NSObject, keyPath: String, value: Optional<T>) {
        self.target = target
        self.keyPath = keyPath

        // validate the keyPath by checking that the initialized value matched the actual key path, or at least that they are both nil
        let initialValue: AnyObject? = target.valueForKeyPath(self.keyPath)
        assert((initialValue === nil && value == nil) || ((initialValue as? NSObject) == (value as? NSObject)), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(value)»")
    }

    /// DirectChannelType access to the underlying source value
    public var value : SourceType {
        get { return pull().nextValue }
        nonmutating set(v) { push(v) }
    }

    public func push(newValue: SourceType) {
        self.target?.setValue(newValue is NSNull ? nil : (newValue as? NSObject), forKeyPath: self.keyPath)
    }

    public func pull() -> OutputType {
        if let target = target {
            let v = target.valueForKeyPath(self.keyPath) as SourceType
            return StateEvent(lastValue: v, nextValue: v)
        } else {
            return StateEvent(lastValue: nil, nextValue: nil)
        }
    }

    /// Attaches an outlet to receive change notifications from the state pipeline
    ///
    /// :param: outlet      the outlet closure to which state will be sent
    public func attach(outlet: (OutputType)->())->Outlet {
        if let target = target {
            return KeyValueOutlet(target: target, keyPath: keyPath, handler: { (oldv, newv) in
                outlet(StateEvent(lastValue: oldv as? SourceType ?? nil, nextValue: newv as? SourceType ?? nil))
            })
        } else {
            NSLog("ChannelZ warning: attempt to attach to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
            return DeallocatedTargetOutlet()
        }
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


/// How many levels of re-entrancy are permitted when flowing state observations
public var ChannelZKeyValueReentrancyGuard: UInt = 1

#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that outlets are correctly cleaned up
    public var ChannelZKeyValueObserverCount = 0
#endif

/// outlet for Cocoa KVO changes
private struct KeyValueOutlet: Outlet {
    typealias HandlerType = ((oldv: AnyObject?, newv: AnyObject?)->Void)
    weak var observer: TargetAssociatedObserver?

    init(target: NSObject, keyPath: String, handler: HandlerType) {
        var entrancy: UInt = 0

        self.observer = TargetAssociatedObserver(target: target, keyPath: keyPath, kvoptions: NSKeyValueObservingOptions(NSKeyValueObservingOptions.Old.rawValue | NSKeyValueObservingOptions.New.rawValue | NSKeyValueObservingOptions.Initial.rawValue), callback: { (change: [NSObject : AnyObject]) -> () in

            if entrancy++ > ChannelZKeyValueReentrancyGuard {
                #if DEBUG_CHANNELZ
                    NSLog("\(__FILE__.lastPathComponent):\(__LINE__): re-entrant value change limit of \(ChannelZKeyValueReentrancyGuard) reached for «\(keyPath)»")
                #endif
            } else {
                let oldValue: AnyObject? = change[NSKeyValueChangeOldKey]
                let newValue: AnyObject? = change[NSKeyValueChangeNewKey]
                handler(oldv: oldValue, newv: newValue)
                entrancy--
            }
        })
    }

    func detach() {
        observer?.deactivate()
    }
}

/// Am observer that is stored as an associated object in the target and is automatically removed when the target is deallocated; can be with either for KVO or NSNotificationCenter depending on the constructor arguments
public class TargetAssociatedObserver : NSObject {
    private var assocctx = UnsafePointer<Void>()
    private var kvoctx = UnsafePointer<Void>()
    public private(set) var active : UInt32 = 0
    public let keyPath: NSString
    private let center: NSNotificationCenter?
    public let callback: ([NSObject : AnyObject])->()

    weak var target: NSObject?
    private let targetPtr: Unmanaged<NSObject>

    public init(target: NSObject, keyPath: String, kvoptions: NSKeyValueObservingOptions? = nil, center: NSNotificationCenter? = nil, callback: ([NSObject : AnyObject])->()) {
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
            } else {
                preconditionFailure("either NSKeyValueObservingOptions or NSNotificationCenter must be specified")
            }
        }
    }

    /// Callback when in NSNotificationCenter mode
    public func notificationReceived(note: NSNotification) {
        self.callback(note.userInfo ?? [:])
    }

    /// Callback when in Key-Value Observation mode
    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        assert(object === target)
        assert(keyPath == self.keyPath)
        self.callback(change)
    }

    /// Removes this object as an observer of the target
    public func deactivate() {
        let this = self
        if OSAtomicTestAndClear(0, &active) {
            let object = (target ?? targetPtr.takeUnretainedValue())
            if let center = center { // NSNotificationCenter mode
                center.removeObserver(this, name: keyPath, object: object)
            } else { // KVO mode

                /** FIXME: we get a crash when there are a lot of observers on a single instance; internet seems to suggest this is a known issue when an object has many observers; one workaround seems to be to just skip the removal of notifications if the class is not the swizzled NSKVONotifying_ subclass, which doesn't seem to trigger the usually dealloc exception.

                #0	0x0000000102951cc9 in CFArrayGetCount ()
                #1	0x00000001022d272c in _NSKeyValueObservationInfoCreateByRemoving ()
                #2	0x00000001022d249e in -[NSObject(NSKeyValueObserverRegistration) _removeObserver:forProperty:] ()
                #3	0x00000001022d230c in -[NSObject(NSKeyValueObserverRegistration) removeObserver:forKeyPath:] ()
                #4	0x00000001022e026b in -[NSObject(NSKeyValueObserverRegistration) removeObserver:forKeyPath:context:] ()
                #5	0x0000000104296daf in ChannelZ.TargetAssociatedObserver.deactivate (ChannelZ.TargetAssociatedObserver)() -> () at /opt/src/impathic/glimpse/ChannelZ/ChannelZ/FoundationZ.swift:283
                #6	0x0000000104296fac in ChannelZ.TargetAssociatedObserver.__deallocating_deinit at /opt/src/impathic/glimpse/ChannelZ/ChannelZ/FoundationZ.swift:290
                #7	0x0000000104297002 in @objc ChannelZ.TargetAssociatedObserver.__deallocating_deinit ()
                #8	0x000000010272828e in objc_object::sidetable_release(bool) ()
                #9	0x0000000102716426 in _object_remove_assocations ()
                #10	0x00000001027209be in objc_destructInstance ()
                #11	0x00000001027209e4 in object_dispose ()
                #12	0x000000010228bd0d in -[NSOperation dealloc] ()
                #13	0x000000010229c6e5 in -[NSBlockOperation dealloc] ()
                #14	0x000000010272828e in objc_object::sidetable_release(bool) ()
                #15	0x0000000106b6cfb7 in ChannelZTests.ChannelZTests.(testManyObservers (ChannelZTests.ChannelZTests) -> () -> ()).(closure #1) at /opt/src/impathic/glimpse/ChannelZ/ChannelZTests/ChannelZTests.swift:1421
                #16	0x00000001043e7f86 in ObjectiveC.autoreleasepool (() -> ()) -> () ()
                #17	0x0000000106b07063 in ChannelZTests.ChannelZTests.testManyObservers (ChannelZTests.ChannelZTests)() -> () at /opt/src/impathic/glimpse/ChannelZ/ChannelZTests/ChannelZTests.swift:1408
                #18	0x0000000106b070a2 in @objc ChannelZTests.ChannelZTests.testManyObservers (ChannelZTests.ChannelZTests)() -> () ()
                */

                let className = NSStringFromClass(object.dynamicType)
                if className.hasPrefix("NSKVONotifying_") {
                    object.removeObserver(this, forKeyPath: keyPath, context: &kvoctx)
                }
            }
            ChannelZKeyValueObserverCount--
        }
    }

    deinit {
        deactivate()
    }
}

extension NSObject {

    /// Creates a channel for all state operations for the given key-value-coding compliant property
    ///
    /// :param: getter      an autoclosure accessor for the value of the property
    /// :param: keyPath     the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func channel<T>(initialValue: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
        return channelRequired(self, keyPath != "" ? keyPath : keyPathForAutoclosure(self, initialValue, true)!, initialValue())
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant property
    ///
    /// :param: initialValue     an autoclosure accessor for the value of the property
    /// :param: keyPath          the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func sieve<T : Equatable>(initialValue: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
        return sieveRequired(self, keyPath != "" ? keyPath : keyPathForAutoclosure(self, initialValue, true)!, initialValue())
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// :param: initialValue     an autoclosure accessor for the value of the optional
    /// :param: keyPath          the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func channel<T>(initialValue: @autoclosure ()->Optional<T>, keyPath: String = "")->KeyValueOptionalChannel<T> {
        return channelOptional(self, keyPath != "" ? keyPath : keyPathForAutoclosure(self, initialValue, true)!, initialValue())
    }

    /// Creates a sieve for all mutating state operations for the given key-value-coding compliant optional property
    ///
    /// :param: initialValue     an autoclosure accessor for the value of the optional
    /// :param: keyPath          the keyPath for the value; if ommitted, auto-discovery will be attempted
    public func sieve<T : Equatable>(initialValue: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<  T>> {
        return sieveOptional(self, keyPath != "" ? keyPath : keyPathForAutoclosure(self, initialValue, true)!, initialValue())
    }
}


let ChannelZKeyPathForAutoclosureLock = NSLock()

/// Attempts to determine the properties that are accessed by the given autoclosure; does so by temporarily swizzling the object's isa pointer to a generated subclass that instruments access to all the properties; note that this is not thread-safe
private func keyPathForAutoclosure<T>(target: NSObject, accessor: ()->T, required: Bool) -> String? {
    var keyPath: String?

    let origclass : AnyClass = object_getClass(target)
    var className = NSStringFromClass(origclass)

    let subclassName = className + "_ChannelZKeyInspection" // unique subclass name
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


internal func channelRequiredKeyValue<T>(target: NSObject, keyPath: String, value: T)->KeyValueChannel<T> {
    return KeyValueChannel(target: target, keyPath: keyPath, value: value)
}

internal func channelRequired<T>(target: NSObject, keyPath: String, value: T)->ChannelZ<T> {
    return ChannelZ(channelRequiredKeyValue(target, keyPath, value).map({ $0.nextValue }))
}

/// Separate function to help the compiler distinguish signatures
public func sieveRequired<T : Equatable>(target: NSObject, keyPath: String, value: T)->ChannelZ<T> {
    return channelStateChanges(channelRequiredKeyValue(target, keyPath, value))
}

public func channelfield<T>(target: NSObject, keyPath: String, value: T)->KeyValueChannel<T> {
    return channelRequiredKeyValue(target, keyPath, value)
}

internal func channelOptional<T>(target: NSObject, keyPath: String, value: Optional<T>)->KeyValueOptionalChannel<T> {
    return KeyValueOptionalChannel(target: target, keyPath: keyPath, value: value)
}

public func channelfield<T>(target: NSObject, keyPath: String, value: Optional<T>)->KeyValueOptionalChannel<T> {
    return channelOptional(target, keyPath, value)
}


/// Separate function to help the compiler distinguish signatures
public func sieveOptional<T : Equatable>(target: NSObject, keyPath: String, value: Optional<T>)->ChannelZ<Optional<T>> {
    return ChannelZ(channelOptionalStateChanges(channelOptional(target, keyPath, value).channelOf))
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

/// Observer for NSNotification changes; cannot be embedded within KeyValueChannel because Objective-C classes cannot use generics
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
    /// :param: name    the name of the notification to register
    /// :param: center  the NSNotificationCenter to register with (defaults to defaultCenter())
    public func notificationFunnel(name: String, center: NSNotificationCenter = NSNotificationCenter.defaultCenter())->NotificationFunnel {
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

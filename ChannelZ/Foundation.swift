//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//
//
/// Support for Foundation channels and observables, such as KVO-based channels and NSNotificationCenter observables
import Foundation

/// Extension on NSObject that permits creating a channel from a key-value compliant property
extension NSObject {

    /// Creates a channel for all state operations for the given key-value-coding property that will emit
    /// a tuple of the previous value (or nil if unavailable) and current state.
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive state transition operations
    public func channelZKeyState<T>(_ accessor: @autoclosure () -> T, keyPath: String? = nil) -> Channel<KeyValueTransceiver<T>, Mutation<T>> {
        return KeyValueTransceiver(target: KeyValueTarget(target: self, accessor: accessor, keyPath: keyPath)).transceive()
    }

    /// Creates a channel for all state operations for the given key-value-coding property that will emit
    /// a tuple of the previous value (or nil if unavailable) and current state.
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive state transition operations
    public func channelZKeyState<T>(_ accessor: @autoclosure () -> T?, keyPath: String? = nil) -> Channel<KeyValueOptionalTransceiver<T>, Mutation<T?>> {
        return KeyValueOptionalTransceiver(target: KeyValueTarget(target: self, accessor: accessor, keyPath: keyPath)).transceive()
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant non-optional property
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    /// 
    /// - Returns a channel backed by the KVO property that will receive items for every time the state is assigned
    public func channelZKey<T>(_ accessor: @autoclosure () -> T, keyPath: String? = nil) -> Channel<KeyValueTransceiver<T>, T> {
        return channelZKeyState(accessor, keyPath: keyPath).new()
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive items for every time the state is assigned
    public func channelZKey<T>(_ accessor: @autoclosure () -> T?, keyPath: String? = nil) -> Channel<KeyValueOptionalTransceiver<T>, T?> {
        return channelZKeyState(accessor, keyPath: keyPath).new()
    }

    // FIXME: channelZKeyArray and channelZKeyOrderedSet are 95% identical and could be unified with a generic but for compiler crashes


    /// Creates a channel for all KVO-compliant NSArray modifications
    ///
    /// - Parameter accessor: an accessor for the NSArray of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive ArrayChange items for mutations
    public func channelZKeyArray(_ accessor: @autoclosure () -> NSArray?, keyPath: String? = nil) -> Channel<NSObject, ArrayChange> {

        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverQueue<ArrayChange>()

        return Channel(source: self) { [unowned self] receiver in
            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new = change[NSKeyValueChangeKey.newKey]
                let old = change[NSKeyValueChangeKey.oldKey]
                let indices = change[NSKeyValueChangeKey.indexesKey] as? IndexSet

                let kind = (change[NSKeyValueChangeKey.kindKey] as? UInt).flatMap(NSKeyValueChange.init(rawValue:)) ?? .setting

                switch kind {
                case .setting: receivers.receive(.assigned(new as? NSArray))
                case .insertion: receivers.receive(.added(indices: indices ?? [], new: new as? NSArray ?? []))
                case .removal: receivers.receive(.removed(indices: indices ?? [], old: old as? NSArray ?? []))
                case .replacement: receivers.receive(.replaced(indices: indices ?? [], old: old as? NSArray ?? [], new: new as? NSArray ?? []))
                }
            }

            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                receivers.removeReceptor(index)
                TargetObserverRegister.get(self).removeObserver(kp, identifier: observer)
            })
        }
    }

    /// Creates a channel for all KVO-compliant NSOrderedSet modifications
    ///
    /// - Parameter accessor: an accessor for the NSOrderedSet of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive OrderedSetChange items for mutations
    public func channelZKeyOrderedSet(_ accessor: @autoclosure () -> NSOrderedSet?, keyPath: String? = nil) -> Channel<NSObject, OrderedSetChange> {
        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverQueue<OrderedSetChange>()

        return Channel(source: self) { [unowned self] receiver in

            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new = change[NSKeyValueChangeKey.newKey]
                let old = change[NSKeyValueChangeKey.oldKey]
                let indices = change[NSKeyValueChangeKey.indexesKey] as? IndexSet

                let kind = (change[NSKeyValueChangeKey.kindKey] as? UInt).flatMap(NSKeyValueChange.init(rawValue:)) ?? .setting

                switch kind {
                case .setting: receivers.receive(.assigned(new as? NSOrderedSet))
                case .insertion: receivers.receive(.added(indices: indices ?? [], new: new as? NSArray ?? []))
                case .removal: receivers.receive(.removed(indices: indices ?? [], old: old as? NSArray ?? []))
                case .replacement: receivers.receive(.replaced(indices: indices ?? [], old: old as? NSArray ?? [], new: new as? NSArray ?? []))
                }
            }

            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                receivers.removeReceptor(index)
                TargetObserverRegister.get(self).removeObserver(kp, identifier: observer)
            })
        }
    }

    /// Creates a channel for all KVO-compliant NSSet modifications
    ///
    /// - Parameter accessor: an accessor for the NSSet of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive SetChange items for mutations
    public func channelZKeySet(_ accessor: @autoclosure () -> NSSet?, keyPath: String? = nil) -> Channel<NSObject, SetChange> {
        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverQueue<SetChange>()

        return Channel(source: self) { [unowned self] receiver in

            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new = change[NSKeyValueChangeKey.newKey]
                let old = change[NSKeyValueChangeKey.oldKey]

                let kind = (change[NSKeyValueChangeKey.kindKey] as? UInt).flatMap(NSKeyValueChange.init(rawValue:)) ?? .setting

                switch kind {
                case .setting: receivers.receive(.assigned(new as? NSSet))
                case .insertion: receivers.receive(.added(new as? NSSet ?? []))
                case .removal: receivers.receive(.removed(old as? NSSet ?? []))
                case .replacement: fatalError("should never happen")
                }
            }

            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                receivers.removeReceptor(index)
                TargetObserverRegister.get(self).removeObserver(kp, identifier: observer)
            })
        }
    }
}

/// Change type for `channelZKeyArray`
public enum ArrayChange {
    case assigned(NSArray?)
    case added(indices: IndexSet, new: NSArray)
    case removed(indices: IndexSet, old: NSArray)
    case replaced(indices: IndexSet, old: NSArray, new: NSArray)
}

/// Change type for `channelZKeyOrderedSet`
public enum OrderedSetChange {
    case assigned(NSOrderedSet?)
    case added(indices: IndexSet, new: NSArray)
    case removed(indices: IndexSet, old: NSArray)
    case replaced(indices: IndexSet, old: NSArray, new: NSArray)
}

/// Change type for `channelZKeySet`
public enum SetChange {
    case assigned(NSSet?)
    case added(NSSet)
    case removed(NSSet)
}


/// A struct that combines the given target NSObject and the accessor closure to determine the keyPath for the accessor
public struct KeyValueTarget<T> {
    public let target: NSObject
    public let initialValue: T
    public let keyPath: String
}

public extension KeyValueTarget {
    public init(target: NSObject, accessor: @autoclosure () -> T, keyPath: String? = nil) {
        self.target = target
        self.initialValue = accessor()
        if let kp = keyPath {
            self.keyPath = kp
        } else {
            self.keyPath = conjectKeypath(target, accessor, true)!
        }
    }
}


public protocol KeyTransceiverType : class, TransceiverType {
    var optional: Bool { get }
    var keyPath: String { get }
    var object: NSObject? { get }
    var queue: ReceiverQueue<Mutation<Element>> { get }

    func get() -> Element
    func createPulse(_ change: NSDictionary) -> Mutation<Element>
}

public extension KeyTransceiverType {
    @discardableResult
    public func set(_ value: Element) -> Bool {
        if let target = self.object {
            setValueForKeyPath(target, keyPath: keyPath, nullable: optional, value: value)
            return true
        } else {
            return false
        }
    }

    /// access to the underlying source value
    public var $: Element {
        get { return get() }
        set(v) { set(v) }
    }

    /// Sets the current value (ReceiverType implementation)
    public func receive(_ value: Element) -> Void {
        set(value)
    }

    fileprivate func validateInitialValue(_ iv: Element) {
        // validate the keyPath by checking that the initialized value matched the actual key path
        let initialValue = object?.value(forKeyPath: self.keyPath)
        if let initialValueActual = initialValue {
            if let gotten = iv as? NSObject {
                if let eq1 = initialValueActual as? NSObjectProtocol {
                    // make sure the key path is really returning the specified value
                    assert(eq1.isEqual(gotten), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(gotten)»")
                }
            }
        }

    }

    fileprivate func registerObserver() {
        guard let target = self.object else {
            preconditionFailure("ChannelZ: cannot add receiver for deallocated instance (channels do not retain their targets)")
        }

        let rcvrs = self.queue
        TargetObserverRegister.get(target).addObserver(keyPath) { change in
            // note: casting lf chage fails in Swift 3.0, and dictionary initialization throws an error
            let dict = NSMutableDictionary()
            for (key, value) in change {
                dict[key] = value
            }
            rcvrs.receive(self.createPulse(dict))
        }
    }

    fileprivate func addReceiver(_ receiver: @escaping (Mutation<Element>) -> Void) -> Receipt {
        // immediately issue the original value with no previous value
        receiver(Mutation<Element>(old: Optional<Element>.none, new: get()))

        let kp = keyPath
        let index = queue.addReceiver(receiver)
        return ReceiptOf(canceler: { [weak self] in
            self?.queue.removeReceptor(index)
            if let target = self?.object {
                TargetObserverRegister.get(target).removeObserver(kp, identifier: index)
            }
        })
    }

    public typealias StateChannel<T> = Channel<Self, Mutation<T>>

    public func transceive() -> StateChannel<Element> {
        return Channel(source: self, reception: addReceiver)
    }
}

/// A Source for Channels of Cocoa properties that support key-value path observation/coding
public final class KeyValueTransceiver<T>: ReceiverQueueSource<Mutation<T>>, KeyTransceiverType {
    public typealias Element = T

    public let keyPath: String
    public let optional = false
    public fileprivate(set) weak var object: NSObject?
    public var queue: ReceiverQueue<Mutation<Element>> { return receivers }

    public init(target: KeyValueTarget<Element>) {
        self.object = target.target
        self.keyPath = target.keyPath
        super.init()
        validateInitialValue(target.initialValue)
        registerObserver()
    }

    public func get() -> T {
        let keyValue = object?.value(forKeyPath: self.keyPath)
        return coerceFoundationType(keyValue)!
    }

    public func createPulse(_ change: NSDictionary) -> Mutation<Element> {
        let newv: Element? = coerceFoundationType(change[NSKeyValueChangeKey.newKey])
        let oldv: Element? = coerceFoundationType(change[NSKeyValueChangeKey.oldKey])
        return Mutation<Element>(old: oldv, new: newv!)
    }

}


/// A Source for Channels of Cocoa properties that support key-value path observation/coding
public final class KeyValueOptionalTransceiver<T>: ReceiverQueueSource<Mutation<T?>>, KeyTransceiverType {
    public typealias Element = T?
    public let keyPath: String
    public let optional = true
    public fileprivate(set) weak var object: NSObject?
    public var queue: ReceiverQueue<Mutation<Element>> { return receivers }

    public init(target: KeyValueTarget<Element>) {
        self.object = target.target
        self.keyPath = target.keyPath
        super.init()
        validateInitialValue(target.initialValue)
        registerObserver()
    }

    public func get() -> T? {
        let keyValue = object?.value(forKeyPath: self.keyPath)
        return keyValue as? T? ?? coerceFoundationType(keyValue)
    }

    public func createPulse(_ change: NSDictionary) -> Mutation<Element> {
        let newv: Element = coerceFoundationType(change[NSKeyValueChangeKey.newKey])
        let oldv: Element = coerceFoundationType(change[NSKeyValueChangeKey.oldKey])
        return Mutation<Element>(old: oldv, new: newv)
    }
}


/// Optional protocol for target objects to implement when they need to supplement key-value observing with additional events
@objc public protocol KeyValueChannelSupplementing {
    /// Add additional observers for the specified keyPath, returning the unsubscriber for any supplements
    func supplementKeyValueChannel(_ forKeyPath: String, subscription: (AnyObject?) -> ()) -> (() -> ())?
}


#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that subscriptions are correctly cleaned up
    public var ChannelZKeyValueObserverCount = Int64(0)
#endif


/// An observer register that is stored as an associated object in the target and is automatically removed when the target is deallocated; can be with either KVO or NSNotificationCenter depending on the constructor arguments
@objc final class TargetObserverRegister : NSObject {
    // note: it would make sense to declare this as TargetObserverRegister<T:NSObject>, but the class won't receive any KVO notifications if it is a generic

    fileprivate struct Context {
        /// Global pointer to the context that will holder the observer list
        fileprivate static var ObserverListAssociatedKey: UnsafeRawPointer? = nil

        /// Global lock for getting/setting the observer
        fileprivate static var RegisterLock = NSLock()

        /// Singleton notification center; we don't currently support multiple NSNotificationCenter observers
        fileprivate static let RegisterNotificationCenter = NotificationCenter.default

        /// Note that we don't use NSKeyValueObservingOptions.Initial because the initial values wind up
        /// being broadcast to *all* receivers, not just the changed one
        fileprivate static let KVOOptions = NSKeyValueObservingOptions(rawValue: NSKeyValueObservingOptions.old.rawValue | NSKeyValueObservingOptions.new.rawValue)
    }

    /// The signature for the callback when a change occurs
    typealias Callback = ([AnyHashable: Any]) -> ()

    typealias Observer = (identifier: Int64, handler: Callback)

    // since this associated object is deallocated as part of the owning object's dealloc (see objc_destructInstance in <http://opensource.apple.com/source/objc4/objc4-646/runtime/objc-runtime-new.mm>), we can't rely on the weak reference not having been zeroed, so use an extra unmanaged pointer to the target object that we can use to remove the observer
    fileprivate let targetPtr: Unmanaged<NSObject>

    fileprivate var target : NSObject { return targetPtr.takeUnretainedValue() }

    fileprivate var keyObservers = [String: [Observer]]()

    fileprivate var noteObservers = [String: [Observer]]()

    /// The internal counter of identifiers
    fileprivate var identifierCounter : Int64 = 0

    class func get(_ target: NSObject) -> TargetObserverRegister {
        Context.RegisterLock.lock()
        if let ob = objc_getAssociatedObject(target, &Context.ObserverListAssociatedKey) as? TargetObserverRegister {
            Context.RegisterLock.unlock()
            return ob
        } else {
            let ob = TargetObserverRegister(targetPtr: Unmanaged.passUnretained(target))
            objc_setAssociatedObject(target, &Context.ObserverListAssociatedKey, ob, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            #if DEBUG_CHANNELZ
                OSAtomicIncrement64(&ChannelZKeyValueObserverCount)
            #endif
            Context.RegisterLock.unlock()
            return ob
        }
    }

    private init(targetPtr: Unmanaged<NSObject>) {
        self.targetPtr = targetPtr
    }

    deinit {
        #if DEBUG_CHANNELZ
            OSAtomicDecrement64(&ChannelZKeyValueObserverCount)
        #endif
        clear()
    }

    @discardableResult
    func addObserver(_ keyPath: String, callback: @escaping Callback) -> Int64 {
        OSAtomicIncrement64(&identifierCounter)
        let observer = Observer(identifier: identifierCounter, handler: callback)

        let observers = keyObservers[keyPath] ?? []
        keyObservers[keyPath] = observers + [observer]

        if observers.count == 0 { // this is the first observer: actually add it to the target
            target.addObserver(self, forKeyPath: keyPath, options: Context.KVOOptions, context: nil)
        }

        return observer.identifier
    }

    @discardableResult
    func addNotification(_ name: String, callback: @escaping Callback) -> Int64 {
        OSAtomicIncrement64(&identifierCounter)
        let observers = noteObservers[name] ?? []
        if observers.count == 0 { // this is the first observer: actually add it to the target
            Context.RegisterNotificationCenter.addObserver(self, selector: #selector(self.notificationReceived), name: NSNotification.Name(rawValue: name), object: target)
        }

        identifierCounter += 1
        let observer = Observer(identifier: identifierCounter, handler: callback)
        noteObservers[name] = observers + [observer]
        return observer.identifier
    }

    /// Removes all the observers and clears the map
    private func clear() {
        let target = self.target // hang on to the target since the accessor won't be valid after we remove the associated object

        let isControllerClass: Bool = {
            let nsobjectclass: AnyClass = object_getClass(NSObject())
            let origclass: AnyClass = object_getClass(target)
            var cls: AnyClass = origclass
            while cls !== nsobjectclass {
                if let className = String(validatingUTF8: class_getName(cls)) {
                    if className == "NSController" {
                        return true
                    }
                }
                cls = class_getSuperclass(cls)
            }

            return false
        }()

        // remove the associated object
        objc_setAssociatedObject(target, &Context.ObserverListAssociatedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        for keyPath in keyObservers.keys {
            // FIXME: random crash with certain classes: -[ChannelZTests.ChannelZTests testOperationChannels] : failed: caught "NSRangeException", "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x1057715e0> for the key path "isFinished" from <NSBlockOperation 0x105769810> because it is not registered as an observer."
            if target is BlockOperation {
                // NSBlockOperation doesn't seem to require observers to be removed?
                // target.addObserver(self, forKeyPath: keyPath, options: Context.KVOOptions, context: nil) // crash
            } else if isControllerClass {
                // NSObjectController: crashes when trying to remove observer in -[NSController _commonRemoveObserver:forKeyPath:] ()
            } else {
                target.removeObserver(self, forKeyPath: keyPath, context: nil)
            }
        }
        keyObservers = [:]

        for name in noteObservers.keys {
            Context.RegisterNotificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: name), object: target)
        }
        noteObservers = [:]
    }

    func removeObserver(_ keyPath: String, identifier: Int64) {
        if let observers = keyObservers[keyPath] {
            let filtered = observers.filter { $0.identifier != identifier }
            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
                // FIXME: random crashes in certain specific observed classes, such as NSBlockOperation:
                // error: -[ChannelZTests.ChannelZTests testOperationChannels] : failed: caught "NSRangeException", "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x109c0daa0> for the key path "isExecuting" from <NSBlockOperation 0x109c07830> because it is not registered as an observer."
                keyObservers.removeValue(forKey: keyPath)
                target.removeObserver(self, forKeyPath: keyPath, context: nil)
            } else {
                keyObservers[keyPath] = filtered
            }
        }
    }

    func removeNotification(_ name: String, identifier: Int64) {
        if let observers = noteObservers[name] {
            let filtered = observers.filter { $0.identifier != identifier }
            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
                noteObservers.removeValue(forKey: name)
                Context.RegisterNotificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: name), object: nil)
            } else {
                noteObservers[name] = filtered
            }
        }
    }

    /// Callback for KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath, let observers = keyObservers[keyPath] {
            for observer in observers {
                observer.handler(change ?? [:])
            }
        }
    }

    /// Callback for in NSNotificationCenter
    func notificationReceived(_ note: Notification) {
        let change = (note as NSNotification).userInfo ?? [:]
        if let observers = noteObservers[note.name.rawValue] {
            for observer in observers {
                observer.handler(change)
            }
        }
    }
}


/// The class prefix that Cocoa prepends to the generated subclass that is swizzled in for KVO handling
let ChannelZKVOSwizzledISAPrefix = "NSKVONotifying_"

/// The class prefix that ChannelZ appends to the generated subclass that is swizzled in for automatic keyPath identification
let ChannelZInstrumentorSwizzledISASuffix = "_ChannelZKeyInspection"

/// The shared lock used for swizzling in for instrumentation subclass creation
let ChannelZKeyPathForAutoclosureLock = NSLock()

/// Attempts to determine the properties that are accessed by the given autoclosure; does so by temporarily swizzling the object's isa pointer to a generated subclass that instruments access to all the properties; note that this is not thread-safe in the unlikely event that another method (e.g., KVO swizzling) is being used at the same time for the class on another thread
func conjectKeypath<T>(_ target: NSObject, _ accessor: @autoclosure () -> T, _ required: Bool) -> String? {
    var keyPath: String?

    let origclass : AnyClass = object_getClass(target)
    let className = NSStringFromClass(origclass)

    let subclassName = className + ChannelZInstrumentorSwizzledISASuffix // unique subclass name
    let subclass : AnyClass = objc_allocateClassPair(origclass, subclassName, 0)
    var propSelIMPs: [IMP] = []

    let nsobjectclass : AnyClass = object_getClass(NSObject())

    var classes: [AnyClass] = []
    var cls: AnyClass = origclass
    while cls !== nsobjectclass {
        classes.append(cls)
        cls = class_getSuperclass(cls)
    }

    for propclass in classes {

        var propCount : UInt32 = 0
        let propList = class_copyPropertyList(propclass, &propCount)
        // println("instrumenting \(propCount) properties of \(NSStringFromClass(propclass))")

        for i in 0..<propCount {
            let prop = propList?[Int(i)]

            // the selector we will implement will be the accessor for the property; these often differ with bools (e.g. "enabled" vs. "isEnabled")
            let gname = property_copyAttributeValue(prop, "G") // the getter name
            let getterName = gname.flatMap({ String(cString:$0) })
            free(gname)

            let ronly = property_copyAttributeValue(prop, "R") // whether the property is read-only
            let readonly = ronly != nil
            free(ronly)

            if let pname = property_getName(prop) {
                let propName = String(cString: pname)
                let propSelName = getterName ?? propName
                
                // println("instrumenting \(NSStringFromClass(propclass)).\(propSelName) (prop=\(propName) getter=\(getterName) readonly=\(readonly))")
                let propSel = Selector(propSelName)

                let method = class_getInstanceMethod(propclass, propSel)
                if method == nil { continue }

                if class_getInstanceMethod(nsobjectclass, propSel) != nil { continue }

                let typeEncoding = method_getTypeEncoding(method)
                if typeEncoding == nil { continue }

                let returnTypePtr = method_copyReturnType(method)
                // let returnType = String.fromCString(returnTypePtr) ?? "@"
                free(returnTypePtr)

                let propBlock : @convention(block) (AnyObject) -> Any? = { (sself : AnyObject) -> (Any?) in
                    // add the name of the property that was accessed; read-only properties tend to use their getterName as the key path (e.g., NSOperation.isFinished)
                    let keyName = readonly && getterName != nil ? getterName! : propName
                    keyPath = keyName // remember the keyPath for later
                    object_setClass(target, origclass) // immediately swap the isa back to the original
                    return target.value(forKey: keyName) // and defer the invocation to the discovered keyPath (throwing a helpful exception is we are wrong)
                }

                if let propSelIMP = imp_implementationWithBlock(unsafeBitCast(propBlock, to: AnyObject.self)) {
                    if !class_addMethod(subclass, propSel, propSelIMP, typeEncoding) {
                        // ignore errors; sometimes happens with UITextField.inputView or NSView.tag
                        // println("could not add method implementation")
                    }
                    propSelIMPs.append(propSelIMP)
                }
            }
        }

        free(propList)
    }

    ChannelZKeyPathForAutoclosureLock.lock()
    objc_registerClassPair(subclass)
    object_setClass(target, subclass)

    _ = accessor() // invoke the accessor to see what instrumented properties are accessed

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

private func setValueForKeyPath<T>(_ target: NSObject, keyPath: String, nullable: Bool, value: T?) {
    if let value = value {
        if nullable && value is NSNull { target.setValue(nil, forKeyPath: keyPath) }
        else if let ob = value as? NSObject { target.setValue(ob, forKeyPath: keyPath) }
            // manual numeric coercion: because only “the following types are automatically bridged to NSNumber: Int, UInt, Float, Double, Bool”
        else if let value = value as? Bool { target.setValue(NSNumber(value: value as Bool), forKeyPath: keyPath) }
        else if let value = value as? Int8 { target.setValue(NSNumber(value: value as Int8), forKeyPath: keyPath) }
        else if let value = value as? UInt8 { target.setValue(NSNumber(value: value as UInt8), forKeyPath: keyPath) }
        else if let value = value as? Int16 { target.setValue(NSNumber(value: value as Int16), forKeyPath: keyPath) }
        else if let value = value as? UInt16 { target.setValue(NSNumber(value: value as UInt16), forKeyPath: keyPath) }
        else if let value = value as? Int32 { target.setValue(NSNumber(value: value as Int32), forKeyPath: keyPath) }
        else if let value = value as? UInt32 { target.setValue(NSNumber(value: value as UInt32), forKeyPath: keyPath) }
        else if let value = value as? Int { target.setValue(NSNumber(value: value as Int), forKeyPath: keyPath) }
        else if let value = value as? UInt { target.setValue(NSNumber(value: value as UInt), forKeyPath: keyPath) }
        else if let value = value as? Int64 { target.setValue(NSNumber(value: value as Int64), forKeyPath: keyPath) }
        else if let value = value as? UInt64 { target.setValue(NSNumber(value: value as UInt64), forKeyPath: keyPath) }
        else if let value = value as? Float { target.setValue(NSNumber(value: value as Float), forKeyPath: keyPath) }
        else if let value = value as? Double { target.setValue(NSNumber(value: value as Double), forKeyPath: keyPath) }
        else {
            target.setValue(nil, forKeyPath: keyPath)
            //            preconditionFailure("unable to coerce value «\(value.dynamicType)» into Foundation type for keyPath «\(keyPath)»")
        }
    } else if nullable {
        target.setValue(nil, forKeyPath: keyPath)
    } else {
        preconditionFailure("unable to coerce value «\(type(of: value))» into Foundation type for non-nullable keyPath «\(keyPath)»")
    }
}

private func coerceFoundationType<SourceType>(_ ob: Any?) -> SourceType? {
    if let ob = ob as? SourceType {
        return ob // always first try to get automatic coercion (e.g., NSString to String)
    } else if let ob = ob as? NSNumber {
        // when an NSNumber is sent to an observer that is listening for a particular primitive, try to coerce it
        if SourceType.self is UInt64.Type {
            return ob.uint64Value as? SourceType
        } else if SourceType.self is Int64.Type {
            return ob.int64Value as? SourceType
        } else if SourceType.self is Double.Type {
            return ob.doubleValue as? SourceType
        } else if SourceType.self is Float.Type {
            return ob.floatValue as? SourceType
        } else if SourceType.self is UInt.Type {
            return ob.uintValue as? SourceType
        } else if SourceType.self is Int.Type {
            return ob.intValue as? SourceType
        } else if SourceType.self is UInt32.Type {
            return ob.uint32Value as? SourceType
        } else if SourceType.self is Int32.Type {
            return ob.int32Value as? SourceType
        } else if SourceType.self is UInt16.Type {
            return ob.uint16Value as? SourceType
        } else if SourceType.self is Int16.Type {
            return ob.int16Value as? SourceType
        } else if SourceType.self is UInt8.Type {
            return ob.uint8Value as? SourceType
        } else if SourceType.self is Int8.Type {
            return ob.int8Value as? SourceType
        } else if SourceType.self is Bool.Type {
            return ob.boolValue as? SourceType
        }
    }

    //print("failed to coerce value «\(ob)» of type \(type(of: ob)) into \(SourceType.self)")
    return nil
}

/// Extension for listening to notifications of a given type
extension NSObject {
    public typealias UserInfo = [AnyHashable: Any]

    /// Registers with the NSNotificationCenter to observable event notications of the given name for this object
    ///
    /// - Parameter notificationName: the name of the notification to register
    /// - Parameter center: the NSNotificationCenter to register with (defaults to defaultCenter())
    public func channelZNotification(_ name: String, center: NotificationCenter = NotificationCenter.default) -> Channel<NotificationCenter, UserInfo> {
        let receivers = ReceiverQueue<UserInfo>()
        return Channel(source: center) { [weak self] (receiver: @escaping (UserInfo) -> Void) -> Receipt in
            var rindex: Int64

            if let target = self {
                rindex = receivers.addReceiver(receiver) // first add the observer so we get the initial notification
                TargetObserverRegister.get(target).addNotification(name) { receivers.receive($0) }
            } else {
                preconditionFailure("cannot add receiver for deallocated instance (channels do not retain their targets)")
            }

            return ReceiptOf(canceler: { [weak self] in
                if let target = self {
                    _ = TargetObserverRegister.get(target) // .removeObserver(kp, identifier: oindex)
                }
                receivers.removeReceptor(rindex)
            })
        }
    }
}

extension NSNumber : ConduitNumericCoercible {
    public class func fromConduitNumericCoercible(_ value: ConduitNumericCoercible) -> Self? {
        if let value = value as? NSNumber, let scalar = UnicodeScalar(UInt32(value.objCType.pointee)) {
            let type = Character(scalar)
            
            if type == "c" { return self.init(value: value.int8Value) }
            else if type == "C" { return self.init(value: value.uint8Value) }
            else if type == "s" { return self.init(value: value.int16Value) }
            else if type == "S" { return self.init(value: value.uint16Value) }
            else if type == "i" { return self.init(value: value.int32Value) }
            else if type == "I" { return self.init(value: value.uint32Value) }
            else if type == "l" { return self.init(value: value.intValue) }
            else if type == "L" { return self.init(value: value.uintValue) }
            else if type == "q" { return self.init(value: value.int64Value) }
            else if type == "Q" { return self.init(value: value.uint64Value) }
            else if type == "f" { return self.init(value: value.floatValue) }
            else if type == "d" { return self.init(value: value.doubleValue) }
            else { return nil }
        }
        else if let value = value as? Bool { return self.init(value: value) }
        else if let value = value as? Int8 { return self.init(value: value) }
        else if let value = value as? UInt8 { return self.init(value: value) }
        else if let value = value as? Int16 { return self.init(value: value) }
        else if let value = value as? UInt16 { return self.init(value: value) }
        else if let value = value as? Int32 { return self.init(value: value) }
        else if let value = value as? UInt32 { return self.init(value: value) }
        else if let value = value as? Int { return self.init(value: value) }
        else if let value = value as? UInt { return self.init(value: value) }
        else if let value = value as? Int64 { return self.init(value: value) }
        else if let value = value as? UInt64 { return self.init(value: value) }
        else if let value = value as? Float { return self.init(value: value) }
//        else if let value = value as? Float80 { return self.init(value: value) }
        else if let value = value as? Double { return self.init(value: value) }
        else { return nil }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is NSDecimalNumber.Type { return NSDecimalNumber(value: self.doubleValue as Double) as? T }
        else if T.self is NSNumber.Type { return self as? T }
        else if T.self is Bool.Type { return Bool(self.boolValue) as? T }
        else if T.self is Int8.Type { return Int8(self.int8Value) as? T }
        else if T.self is UInt8.Type { return UInt8(self.uint8Value) as? T }
        else if T.self is Int16.Type { return Int16(self.int16Value) as? T }
        else if T.self is UInt16.Type { return UInt16(self.uint16Value) as? T }
        else if T.self is Int32.Type { return Int32(self.int32Value) as? T }
        else if T.self is UInt32.Type { return UInt32(self.uint32Value) as? T }
        else if T.self is Int.Type { return Int(self.intValue) as? T }
        else if T.self is UInt.Type { return UInt(self.uintValue) as? T }
        else if T.self is Int64.Type { return Int64(self.int64Value) as? T }
        else if T.self is UInt64.Type { return UInt64(self.uint64Value) as? T }
        else if T.self is Float.Type { return Float(self.floatValue) as? T }
//        else if T.self is Float80.Type { return Float80(self) as? T }
        else if T.self is Double.Type { return Double(self.doubleValue) as? T }
        else { return self as? T }
    }

}


// MARK: ChannelController implementation

/// A strongly-typed KVO-compatible type that contains a single value.
/// 
/// Values are always optional since Foundation always permits nil to exist in place of an object reference.
///
/// Cocoa Key-Value Observing is generally not compatible with Swift generics due to
/// the inability to dynamicly subclass a generic type (observation messages will simply
/// not be received), so the `ChannelController` overrides the KVO management routines
/// in order to handle a strongly-typed values.
public final class ChannelController<T> : NSObject, TransceiverType {
    public static var defaultKey: String { return "value" }

    public typealias State = Mutation<T?>
    private let receivers = ReceiverQueue<State>()
    // map of KVO observers
    private var observers = Dictionary<ChannelControllerObserverKey, [Receipt]>()

    public let key: String
    public var $: T? {
        willSet {
            willChangeValue(forKey: key)
        }

        didSet(old) {
            didChangeValue(forKey: key)
            receivers.receive(Mutation(old: old, new: $))
        }
    }


    public init(value: T?, key: String = "value") {
        self.$ = value
        self.key = key
    }

    public convenience init(rawValue: T) {
        self.init(value: rawValue)
    }

    public func receive(_ x: T?) { $ = x }

    public func transceive() -> Channel<ChannelController<T>, State> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.none, new: self.$))
            return self.receivers.addReceipt(rcvr)
        }
    }

    public override func addObserver(_ observer: NSObject, forKeyPath keyPath: String, options: NSKeyValueObservingOptions, context: UnsafeMutableRawPointer?) {
        if keyPath == self.key, let context = context {
            var channel = transceive()

            if !options.contains(.initial) {
                // only send the initial values if we request it in the options
                channel = channel.subsequent()
            }

            let receipt = channel.receive { [weak self] pulse in
                var change: [NSKeyValueChangeKey : AnyObject] = [
                    NSKeyValueChangeKey.kindKey: NSKeyValueChange.setting.rawValue as AnyObject
                ]

                if options.contains(.new) {
                    change[NSKeyValueChangeKey.newKey] = pulse.new as? NSObject
                }
                if options.contains(.old) {
                    change[NSKeyValueChangeKey.oldKey] = pulse.old as? NSObject
                }

                observer.observeValue(forKeyPath: keyPath, of: self, change: change, context: context)
            }

            // remember the receivers for a given context pointer so we can cancel them later
            let key = ChannelControllerObserverKey(context: context, observer: observer)
            observers[key] = (observers[key] ?? []) + [receipt]
        } else {
            super.addObserver(observer, forKeyPath: keyPath, options: options, context: context)
        }
    }

    public override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String, context: UnsafeMutableRawPointer?) {
        if keyPath == self.key, let context = context {
            let key = ChannelControllerObserverKey(context: context, observer: observer)
            for receipt in observers.removeValue(forKey: key) ?? [] {
                receipt.cancel()
            }
        } else {
            super.removeObserver(observer, forKeyPath: keyPath, context: context)
        }
    }

    public override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {


        // Manual unbinding on `unbind`:
        // ChannelController.removeObserver(NSObject, forKeyPath : String) -> ()
        // @objc ChannelController.removeObserver(NSObject, forKeyPath : String) -> () ()
        // -[NSBinder _updateObservingRegistration:] ()
        // -[NSBinder breakConnection] ()
        // -[NSObject(NSKeyValueBindingCreation) unbind:] ()

        // Automatic unbinding on `dealloc`:
        // ChannelController.removeObserver(NSObject, forKeyPath : String) -> ()
        // @objc ChannelController.removeObserver(NSObject, forKeyPath : String) -> () ()
        // -[NSBinder _updateObservingRegistration:] ()
        // -[NSBinder releaseConnectionWithSynchronizePeerBinders:] ()
        // -[NSValueBinder releaseConnectionWithSynchronizePeerBinders:] ()
        // -[NSObject(_NSBindingAdaptorAccess) _releaseBindingAdaptor] ()
        // -[NSView _releaseBindingAdaptor] ()
        // -[NSView _finalizeWithReferenceCounting] ()
        // -[NSView dealloc] ()
        // -[NSControl dealloc] ()
        // -[NSTextField dealloc] ()


        if keyPath == self.key {
            // no context: need to manually iterate to remove the observer
            for (key, receipts) in observers {
                if key.observer === observer {
                    for receipt in receipts {
                        receipt.cancel()
                    }
                    observers.removeValue(forKey: key)
                }
            }
        } else {
            super.removeObserver(observer, forKeyPath: keyPath)
        }
    }

    public override func willChangeValue(forKey key: String) {
        if key == self.key {
        } else {
            super.willChangeValue(forKey: key)
        }
    }

    public override func didChangeValue(forKey key: String) {
        if key == self.key {
        } else {
            super.didChangeValue(forKey: key)
        }
    }

    public override func value(forKey key: String) -> Any? {
        if key == self.key {
            return self.$ as? NSObject
        } else {
            return super.value(forKey: key)
        }
    }

    public override func value(forKeyPath keyPath: String) -> Any? {
        if keyPath == self.key {
            return self.$ as? NSObject
        } else {
            return super.value(forKeyPath: keyPath)
        }
    }

    public override func setValue(_ value: Any?, forKey key: String) {
        if key == self.key {
            if let value = value as? T {
                self.$ = value
            } else {
                self.$ = nil
            }
        } else {
            super.setValue(value, forKey: key)
        }
    }

    public override func setValue(_ value: Any?, forKeyPath keyPath: String) {
        if keyPath == self.key {
            if let value = value as? T {
                self.$ = value
            } else {
                self.$ = nil
            }
        } else {
            super.setValue(value, forKeyPath: keyPath)
        }
    }
}

/// Key for observer info in ChannelController (cannot nest in generic)
private struct ChannelControllerObserverKey : Hashable {
    var context: UnsafeMutableRawPointer
    weak var observer: NSObject?

    fileprivate var hashValue: Int { return context.hashValue }
}

private func ==(lhs: ChannelControllerObserverKey, rhs: ChannelControllerObserverKey) -> Bool {
    return lhs.context == rhs.context && lhs.observer === rhs.observer
}


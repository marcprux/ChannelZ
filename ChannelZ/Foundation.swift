////
////  ChannelZ+Foundation.swift
////  GlimpseCore
////
////  Created by Marc Prud'hommeaux <marc@glimpse.io>
////  License: MIT (or whatever)
////
//
///// Support for Foundation channels and observables, such as KVO-based channels and NSNotificationCenter observables
//import Foundation
//
//
///// Extension on NSObject that permits creating a channel from a key-value compliant property
//extension NSObject {
//
//    /// Creates a channel for all state operations for the given key-value-coding compliant property
//    ///
//    /// :param: getter      an autoclosure accessor for the value of the property
//    /// :param: keyPath     the keyPath for the value; if ommitted, auto-discovery will be attempted
//    public func channelz<T>(getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
//        return channelRequired(self, getter, keyPath: keyPath)
//    }
//
//    /// Creates a sieve for all state changes for the given key-value-coding compliant property
//    ///
//    /// :param: getter     an autoclosure accessor for the value of the property
//    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
//    public func sievez<T : Equatable>(getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
//        return sieveRequired(self, getter, keyPath: keyPath)
//    }
//
//    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
//    ///
//    /// :param: getter     an autoclosure accessor for the value of the optional
//    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
//    public func channelz<T>(getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
//        return channelOptional(self, getter, keyPath: keyPath)
//    }
//
//    /// Creates a sieve for all state changes for the given key-value-coding compliant optional property
//    ///
//    /// :param: getter     an autoclosure accessor for the value of the optional
//    /// :param: keyPath    the keyPath for the value; if ommitted, auto-discovery will be attempted
//    public func sievez<T : Equatable>(getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
//        return sieveOptional(self, getter, keyPath: keyPath)
//    }
//}
//
//private func channelRequired<T>(target: NSObject, getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
//    return ChannelZ(channelRequiredKeyValue(target, keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, getter()).map({ $0.value }))
//}
//
///// Separate function to help the compiler distinguish signatures
//private func sieveRequired<T : Equatable>(target: NSObject, getter: @autoclosure ()->T, keyPath: String = "")->ChannelZ<T> {
//    return channelStateChanges(channelRequiredKeyValue(target, keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, getter()))
//}
//
//private func channelOptional<T>(target: NSObject, getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
//    return ChannelZ(channelStateValues(KeyValueOptionalChannel(target: target, keyPath: keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, value: getter()).channel()))
//}
//
///// Separate function to help the compiler distinguish signatures
//private func sieveOptional<T : Equatable>(target: NSObject, getter: @autoclosure ()->Optional<T>, keyPath: String = "")->ChannelZ<Optional<T>> {
//    return ChannelZ(channelOptionalStateChanges(KeyValueOptionalChannel(target: target, keyPath: keyPath != "" ? keyPath : keyPathForAutoclosure(target, getter, true)!, value: getter()).channel()))
//}
//
//
//private func channelRequiredKeyValue<T>(target: NSObject, keyPath: String, value: T)->KeyValueRequiredChannel<T> {
//    return KeyValueRequiredChannel(target: target, keyPath: keyPath, value: value)
//}
//
///// Root protocol for required and optional key-value-observing channels
//public protocol KeyValueChannel: ChannelType {
//    /// The keyPath for this channel
//    var keyPath: String { get }
//
//    /// The target object of this channel
//    var target: NSObject? { get }
//}
//
//private func setValueForKeyPath<T>(target: NSObject, keyPath: NSString, nullable: Bool, value: T?) {
//    if nullable && value is NSNull { target.setValue(nil, forKeyPath: keyPath) }
//    else if let ob = value as? NSObject { target.setValue(ob, forKeyPath: keyPath) }
//    // manual numeric coercion: because only “the following types are automatically bridged to NSNumber: Int, UInt, Float, Double, Bool”
//    else if let value = value as? Bool { target.setValue(NSNumber(bool: value), forKeyPath: keyPath) }
//    else if let value = value as? Int8 { target.setValue(NSNumber(char: value), forKeyPath: keyPath) }
//    else if let value = value as? UInt8 { target.setValue(NSNumber(unsignedChar: value), forKeyPath: keyPath) }
//    else if let value = value as? Int16 { target.setValue(NSNumber(short: value), forKeyPath: keyPath) }
//    else if let value = value as? UInt16 { target.setValue(NSNumber(unsignedShort: value), forKeyPath: keyPath) }
//    else if let value = value as? Int32 { target.setValue(NSNumber(int: value), forKeyPath: keyPath) }
//    else if let value = value as? UInt32 { target.setValue(NSNumber(unsignedInt: value), forKeyPath: keyPath) }
//    else if let value = value as? Int { target.setValue(NSNumber(unsignedInteger: value), forKeyPath: keyPath) }
//    else if let value = value as? UInt { target.setValue(NSNumber(unsignedLong: value), forKeyPath: keyPath) }
//    else if let value = value as? Int64 { target.setValue(NSNumber(longLong: value), forKeyPath: keyPath) }
//    else if let value = value as? UInt64 { target.setValue(NSNumber(unsignedLongLong: value), forKeyPath: keyPath) }
//    else if let value = value as? Float { target.setValue(NSNumber(float: value), forKeyPath: keyPath) }
//    // else if let value = value as? Float80 { target.setValue(NSNumber(double: value), forKeyPath: keyPath) }
//    else if let value = value as? Double { target.setValue(NSNumber(double: value), forKeyPath: keyPath) }
//    else if nullable { target.setValue(nil, forKeyPath: keyPath) }
//    else { preconditionFailure("unable to coerce value «\(value.dynamicType)» into Foundation type for non-nullable keyPath «\(keyPath)»") }
//}
//
//private func coerceCocoaType<SourceType>(ob: AnyObject?, type: SourceType.Type) -> SourceType? {
//    if let ob = ob as? SourceType {
//        return ob // always first try to get automatic coercion (e.g., NSString to String)
//    } else if let ob = ob as? NSNumber {
//        // when an NSNumber is sent to an observer that is listening for a particular primitive, try to coerce it
//        if SourceType.self is UInt64.Type {
//            return ob.unsignedLongLongValue as? SourceType
//        } else if SourceType.self is Int64.Type {
//            return ob.longLongValue as? SourceType
//        } else if SourceType.self is Double.Type {
//            return ob.doubleValue as? SourceType
//        } else if SourceType.self is Float.Type {
//            return ob.floatValue as? SourceType
//        } else if SourceType.self is UInt.Type {
//            return ob.unsignedLongValue as? SourceType
//        } else if SourceType.self is Int.Type {
//            return ob.integerValue as? SourceType
//        } else if SourceType.self is UInt32.Type {
//            return ob.unsignedIntValue as? SourceType
//        } else if SourceType.self is Int32.Type {
//            return ob.intValue as? SourceType
//        } else if SourceType.self is UInt16.Type {
//            return ob.unsignedShortValue as? SourceType
//        } else if SourceType.self is Int16.Type {
//            return ob.shortValue as? SourceType
//        } else if SourceType.self is UInt8.Type {
//            return ob.unsignedCharValue as? SourceType
//        } else if SourceType.self is Int8.Type {
//            return ob.charValue as? SourceType
//        } else if SourceType.self is Bool.Type {
//            return ob.boolValue as? SourceType
//        }
//    }
//
//    return nil
//}
//
//
///// A Channel for Cocoa properties that support key-value path observation/coding
//public struct KeyValueRequiredChannel<T>: KeyValueChannel {
//    public typealias SourceType = T
//    public typealias Element = StateEvent<T>
//
//    public private(set) weak var target: NSObject?
//    public let keyPath: String
//
//    public init(target: NSObject, keyPath: String, value: T) {
//        self.target = target
//        self.keyPath = keyPath
//
//        // validate the keyPath by checking that the initialized value matched the actual key path
//        let initialValue: AnyObject? = target.valueForKeyPath(self.keyPath)
//        if let initialValueActual: AnyObject = initialValue {
//            if let gotten = value as? NSObject {
//                if let eq1 = initialValueActual as? NSObjectProtocol {
//                    // make sure the key path is really returning the specified value
//                    assert(eq1.isEqual(gotten), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(gotten)»")
//                }
//            }
//        } else {
//            preconditionFailure("valueForKeyPath(\(keyPath)): non-optional keyPath returned nil")
//        }
//    }
//
//    /// access to the underlying source value
//    public var value: SourceType {
//        get { return get() }
//        nonmutating set(v) { push(v) }
//    }
//
//    public func push(value: SourceType) -> Bool {
//        if let target = self.target {
//            setValueForKeyPath(target, keyPath, false, value)
//            return true
//        } else {
//            return false
//        }
//    }
//
//    private func get() -> SourceType {
//        if let target = target {
//            return target.valueForKeyPath(self.keyPath) as SourceType
//        } else {
//            preconditionFailure("attempt to pull from keyPath «\(keyPath)» of a deallocated instance; channels do not retain their targets")
//        }
//    }
//
//    /// subscribes a subscription to receive change notifications from the state pipeline
//    ///
//    /// :param: subscription      the subscription closure to which state will be sent
//    public func subscribe(subscription: (Element)->())->Receptor {
//        if let target = target {
//            let kp = keyPath
//            let sub = KeyValueReceptor(target: target, keyPath: keyPath, handler: { (oldv, newv) in
//                // for example, we are watching a NSMutableDictionary's key that is set to an NSString and then an NSNumber
//                if let newv = coerceCocoaType(newv, SourceType.self) {
//                    // option type check is because Initial option sends oldValue as nil
//                    if let old = coerceCocoaType(oldv, SourceType.self) {
//                        subscription(StateEvent.change(old, value: newv))
//                    } else {
//                        subscription(StateEvent.push(newv))
//                    }
//                } else {
//                    assert(newv is SourceType, "required value for «\(kp)» changed type from \(oldv) to \(newv); use an optional channel if value type can change")
//                }
//            })
//            return ReceptorOf(subscription: sub)
//        } else {
//            NSLog("ChannelZ warning: attempt to subscribe to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
//            let sub = DeallocatedTargetReceptor()
//            return ReceptorOf(subscription: sub)
//        }
//    }
//
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = KeyValueRequiredChannel
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Observable<Element> { return Observable(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
///// A Channel for optional Cocoa properties that support key-value path observation/coding
//public struct KeyValueOptionalChannel<T>: KeyValueChannel {
//
//    // We need separate handling for optionals because the briding between Swift Optionals and Cocoa has some subtle differences
//
//    public typealias SourceType = Optional<T>
//    public typealias Element = StateEvent<Optional<T>>
//
//    public private(set) weak var target: NSObject?
//    public let keyPath: String
//
//    public init(target: NSObject, keyPath: String, value: Optional<T>) {
//        self.target = target
//        self.keyPath = keyPath
//
//        // validate the keyPath by checking that the initialized value matched the actual key path, or at least that they are both nil
//        let initialValue: AnyObject? = target.valueForKeyPath(self.keyPath)
//        assert((initialValue === nil && value == nil) || ((initialValue as? NSObject) == (value as? NSObject)), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(value)»")
//    }
//
//    /// access to the underlying source value
//    public var value: SourceType {
//        get { return get() }
//        nonmutating set(v) { push(v) }
//    }
//
//    public func push(value: SourceType) -> Bool {
//        if let target = self.target {
//            setValueForKeyPath(target, keyPath, true, value)
//            return true
//        } else {
//            return false
//        }
//    }
//
//    private func get() -> SourceType {
//        if let target = target {
//            return target.valueForKeyPath(self.keyPath) as SourceType
//        } else {
//            return nil
//        }
//    }
//
//    /// subscribes a subscription to receive change notifications from the state pipeline
//    ///
//    /// :param: subscription      the subscription closure to which state will be sent
//    public func subscribe(subscription: (Element)->())->Receptor {
//        if let target = target {
//            let sub = KeyValueReceptor(target: target, keyPath: keyPath, handler: { (oldv, newv) in
//                if let oldv : AnyObject = oldv {
//                    subscription(StateEvent.change(coerceCocoaType(oldv, T.self), value: coerceCocoaType(newv, T.self)))
//                } else {
//                    subscription(StateEvent.push(coerceCocoaType(newv, T.self)))
//                }
//            })
//            return ReceptorOf(subscription: sub)
//        } else {
//            NSLog("ChannelZ warning: attempt to subscribe to a deallocated target keyPath «\(keyPath)»; channels do not retain their targets")
//            let sub = DeallocatedTargetReceptor()
//            return ReceptorOf(subscription: sub)
//        }
//    }
//
//    // Boilerplate observable/channel/filter/map
//    public typealias SelfChannel = KeyValueOptionalChannel
//
//    /// Returns a type-erasing observable around the current channel, making the channel read-only to subsequent pipeline stages
//    public func observable() -> Observable<Element> { return Observable(self) }
//
//    /// Returns a type-erasing channel wrapper around the current channel
//    public func channel() -> ChannelOf<SourceType, Element> { return ChannelOf(self) }
//
//    /// Returns a filtered channel that only flows elements that pass the predicate through to the subscriptions
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//
//    /// Returns a mapped channel that transforms the elements before passing them through to the subscriptions
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapOutput(self, transform) }
//}
//
//
//#if DEBUG_CHANNELZ
//    /// Track how many observers we have created and released; useful for ensuring that subscriptions are correctly cleaned up
//    public var ChannelZKeyValueObserverCount = 0
//#endif
//
///// Optional protocol for target objects to implement when they need to supplement key-value observing with additional events
//@objc public protocol KeyValueChannelSupplementing {
//    /// Add additional observers for the specified keyPath, returning the unsubscriber for any supplements
//    func supplementKeyValueChannel(forKeyPath: String, subscription: (AnyObject?)->()) -> (()->())?
//}
//
///// subscription for Cocoa KVO changes
//private struct KeyValueReceptor: Receptor {
//    typealias HandlerType = ((oldv: AnyObject?, newv: AnyObject?)->Void)
//    let observer: TargetAssociatedObserver
//    let handler: HandlerType
//    var supplementaryDetachable: (()->())?
//
//    init(target: NSObject, keyPath: String, handler: HandlerType) {
//        var entrancy: Int = 0
//
//        self.handler = handler
//        self.observer = TargetAssociatedObserver(target: target, keyPath: keyPath, callback: { (change: [NSObject : AnyObject]) -> () in
//
//            if entrancy++ > ChannelZReentrancyLimit {
//                #if DEBUG_CHANNELZ
//                    NSLog("\(__FILE__.lastPathComponent):\(__LINE__): re-entrant value change limit of \(ChannelZReentrancyLimit) reached for «\(keyPath)»")
//                #endif
//            } else {
//                if let valueChangeType = change[NSKeyValueChangeKindKey] as? NSNumber {
//                    if let valueChange = NSKeyValueChange(rawValue: valueChangeType.unsignedLongValue) {
//                        switch valueChange {
//                        case .Setting:
//                            handler(oldv: change[NSKeyValueChangeOldKey]!, newv: change[NSKeyValueChangeNewKey]!)
//                        case .Insertion, .Removal, .Replacement:
//                            // TODO: handle NSKeyValueChangeKindKey and NSKeyValueChangeIndexesKey keys for collection changes
//                            handler(oldv: change[NSKeyValueChangeOldKey], newv: change[NSKeyValueChangeNewKey])
//                            break
//                        }
//                    }
//                }
//                entrancy--
//            }
//        })
//
//        // If the target object supports supplementing the KVO, install their subscriptions here
//        if let supplementable = target as? KeyValueChannelSupplementing {
//            supplementaryDetachable = supplementable.supplementKeyValueChannel(keyPath) { value in
//                // we don't have access to the previous value here, so send nil to force it to pass any sieves
//                handler(oldv: nil, newv: value)
//            }
//        }
//
//    }
//
//    func unsubscribe() {
//        observer.unsubscribe()
//        supplementaryDetachable?()
//    }
//
//    func request() {
//        if let target = self.observer.target {
//            if let keyPath = self.observer.keyPath {
//                self.handler(oldv: nil, newv: target.valueForKeyPath(keyPath))
//            }
//        }
//    }
//
//}
//
///// An observer register that is stored as an associated object in the target and is automatically removed when the target is deallocated; can be with either KVO or NSNotificationCenter depending on the constructor arguments
//@objc final class TargetObserverRegister : NSObject {
//    // note: it would make sense to declare this as TargetObserverRegister<T:NSObject>, but the class won't receive any KVO notifications if it is a generic
//
//    private struct Context {
//        /// Global pointer to the context that will holder the observer list
//        private static var ObserverListAssociatedKey = UnsafePointer<Void>()
//
//        /// Global lock for getting/setting the observer
//        private static var RegisterLock = NSLock()
//
//        /// Singleton notification center; we don't currently support multiple NSNotificationCenter observers
//        private static let RegisterNotificationCenter = NSNotificationCenter.defaultCenter()
//
//        private static let KVOOptions = NSKeyValueObservingOptions(NSKeyValueObservingOptions.Old.rawValue | NSKeyValueObservingOptions.New.rawValue)
//    }
//
//    /// The signature for the callback when a change occurs
//    typealias Callback = ([NSObject : AnyObject])->()
//
//    typealias Observer = (identifier: Int, handler: Callback)
//
//    /// since this associated object is deallocated as part of the owning object's dealloc (see objc_destructInstance in <http://opensource.apple.com/source/objc4/objc4-646/runtime/objc-runtime-new.mm>), we can't rely on the weak reference not having been zeroed, so use an extra unmanaged pointer to the target object that we can use to remove the observer
//    private let targetPtr: Unmanaged<NSObject>
//
//    private var target : NSObject { return targetPtr.takeUnretainedValue() }
//
//    private var keyObservers = [String: [Observer]]()
//
//    private var noteObservers = [String: [Observer]]()
//
//    /// The internal counter of identifiers
//    private var identifierCounter : Int = 0
//
//    class func get(target: NSObject) -> TargetObserverRegister {
//        Context.RegisterLock.lock()
//        if let ob = objc_getAssociatedObject(target, &Context.ObserverListAssociatedKey) as? TargetObserverRegister {
//            Context.RegisterLock.unlock()
//            return ob
//        } else {
//            let ob = TargetObserverRegister(targetPtr: Unmanaged.passUnretained(target))
//            objc_setAssociatedObject(target, &Context.ObserverListAssociatedKey, ob, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
//            #if DEBUG_CHANNELZ
//                ChannelZKeyValueObserverCount++
//            #endif
//            Context.RegisterLock.unlock()
//            return ob
//        }
//    }
//
//    private init(targetPtr: Unmanaged<NSObject>) {
//        self.targetPtr = targetPtr
//    }
//
//    deinit {
//        #if DEBUG_CHANNELZ
//            ChannelZKeyValueObserverCount--
//        #endif
//        clear()
//    }
//
//    func addObserver(keyPath: String, handler: Callback) -> Int {
//        let observer = Observer(identifier: ++identifierCounter, handler: handler)
//
//        var observers = keyObservers[keyPath] ?? []
//        keyObservers[keyPath] = observers + [observer]
//
//        if observers.count == 0 { // this is the first observer: actually add it to the target
//            target.addObserver(self, forKeyPath: keyPath, options: Context.KVOOptions, context: nil)
//        }
//
//        return observer.identifier
//    }
//
//    func addNotification(name: String, handler: Callback) -> Int {
//        var observers = noteObservers[name] ?? []
//        if observers.count == 0 { // this is the first observer: actually add it to the target
//            Context.RegisterNotificationCenter.addObserver(self, selector: Selector("notificationReceived:"), name: name, object: target)
//        }
//
//        let observer = Observer(identifier: ++identifierCounter, handler: handler)
//        noteObservers[name] = observers + [observer]
//        return observer.identifier
//    }
//    
//    /// Removes all the observers and clears the map
//    private func clear() {
//        let target = self.target // hang on to the target since the getter won't be valid after we remove the associated object
//
//        // remove the associated object
//        objc_setAssociatedObject(target, &Context.ObserverListAssociatedKey, nil, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
//
//        for keyPath in keyObservers.keys {
//            // FIXME: random crash with certain classes: -[ChannelZTests.ChannelZTests testOperationChannels] : failed: caught "NSRangeException", "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x1057715e0> for the key path "isFinished" from <NSBlockOperation 0x105769810> because it is not registered as an observer."
//            if target is NSBlockOperation {
//                // NSBlockOperation doesn't seem to require observers to be removed?
//                // target.addObserver(self, forKeyPath: keyPath, options: Context.KVOOptions, context: nil) // crash
//            } else {
//                target.removeObserver(self, forKeyPath: keyPath, context: nil)
//            }
//        }
//        keyObservers = [:]
//
//        for name in noteObservers.keys {
//            Context.RegisterNotificationCenter.removeObserver(self, name: name, object: target)
//        }
//        noteObservers = [:]
//    }
//
//    func removeObserver(keyPath: String, identifier: Int) {
//        if let observers = keyObservers[keyPath] {
//            var filtered = observers.filter { $0.identifier != identifier }
//            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
//                // FIXME: random crashes in certain specific observed classes, such as NSBlockOperation:
//                // error: -[ChannelZTests.ChannelZTests testOperationChannels] : failed: caught "NSRangeException", "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x109c0daa0> for the key path "isExecuting" from <NSBlockOperation 0x109c07830> because it is not registered as an observer."
//                keyObservers.removeValueForKey(keyPath)
//                target.removeObserver(self, forKeyPath: keyPath, context: nil)
//            } else {
//                keyObservers[keyPath] = filtered
//            }
//        }
//    }
//
//    func removeNotification(name: String, identifier: Int) {
//        if let observers = noteObservers[name] {
//            var filtered = observers.filter { $0.identifier != identifier }
//            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
//                noteObservers.removeValueForKey(name)
//                Context.RegisterNotificationCenter.removeObserver(self, name: name, object: nil)
//            } else {
//                noteObservers[name] = filtered
//            }
//        }
//    }
//
//    /// Callback for KVO
//    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
//        if let observers = keyObservers[keyPath] {
//            for observer in observers {
//                observer.handler(change)
//            }
//        }
//    }
//
//    /// Callback for in NSNotificationCenter
//    func notificationReceived(note: NSNotification) {
//        let change = note.userInfo ?? [:]
//        if let observers = noteObservers[note.name] {
//            for observer in observers {
//                observer.handler(change)
//            }
//        }
//    }
//}
//
//final class TargetAssociatedObserver {
//    let identifier: Int
//    let keyPath: String?
//    let notificationName: String?
//    weak var target: NSObject?
//
//    init(target: NSObject, keyPath: String, callback: ([NSObject : AnyObject])->()) {
//        self.target = target
//        let map = TargetObserverRegister.get(target)
//        self.identifier = map.addObserver(keyPath, handler: callback)
//        self.keyPath = keyPath
//    }
//
//    init(target: NSObject, notificationName: String, callback: ([NSObject : AnyObject])->()) {
//        self.target = target
//        let map = TargetObserverRegister.get(target)
//        self.identifier = map.addNotification(notificationName, handler: callback)
//        self.notificationName = notificationName
//    }
//
//    func unsubscribe() {
//        if let target = target {
//            let map = TargetObserverRegister.get(target)
//            if let keyPath = keyPath {
//                map.removeObserver(keyPath, identifier: identifier)
//            } else if let notificationName = notificationName {
//                map.removeNotification(notificationName, identifier: identifier)
//            }
//
//            self.target = nil // manually clear the target so we don't unsubscribe twice
//        }
//    }
//}
//
//
//    /// The class prefix that Cocoa prepends to the generated subclass that is swizzled in for KVO handling
//let ChannelZKVOSwizzledISAPrefix = "NSKVONotifying_"
//
///// The class prefix that ChannelZ appends to the generated subclass that is swizzled in for automatic keyPath identification
//let ChannelZInstrumentorSwizzledISASuffix = "_ChannelZKeyInspection"
//
///// The shared lock used for swizzling in for instrumentation subclass creation
//let ChannelZKeyPathForAutoclosureLock = NSLock()
//
///// Attempts to determine the properties that are accessed by the given autoclosure; does so by temporarily swizzling the object's isa pointer to a generated subclass that instruments access to all the properties; note that this is not thread-safe in the unlikely event that another method (e.g., KVO swizzling) is being used at the same time for the class on another thread
//private func keyPathForAutoclosure<T>(target: NSObject, accessor: ()->T, required: Bool) -> String? {
//    var keyPath: String?
//
//    let origclass : AnyClass = object_getClass(target)
//    var className = NSStringFromClass(origclass)
//
//    let subclassName = className + ChannelZInstrumentorSwizzledISASuffix // unique subclass name
//    let subclass : AnyClass = objc_allocateClassPair(origclass, subclassName, 0)
//    var propSelIMPs: [IMP] = []
//
//    let nsobjectclass : AnyClass = object_getClass(NSObject())
//
//    for var propclass : AnyClass = origclass; propclass !== nsobjectclass; propclass = class_getSuperclass(propclass) {
//
//        var propCount : UInt32 = 0
//        let propList = class_copyPropertyList(propclass, &propCount)
//        // println("instrumenting \(propCount) properties of \(NSStringFromClass(propclass))")
//
//        for i in 0..<propCount {
//            let prop = propList[Int(i)]
//
//            let pname = property_getName(prop)
//            let propName = String.fromCString(pname)
//
//            // the selector we will implement will be the getter for the property; these often differ with bools (e.g. "enabled" vs. "isEnabled")
//            let gname = property_copyAttributeValue(prop, "G") // the getter name
//            let getterName = String.fromCString(gname)
//            free(gname)
//
//            let ronly = property_copyAttributeValue(prop, "R") // whether the property is read-only
//            let readonly = ronly != nil
//            free(ronly)
//
//            if let propName = propName {
//                if let propSelName = getterName ?? propName {
//                    // println("instrumenting \(NSStringFromClass(propclass)).\(propSelName) (prop=\(propName) getter=\(getterName) readonly=\(readonly))")
//                    let propSel = Selector(propSelName)
//
//                    let method = class_getInstanceMethod(propclass, propSel)
//                    if method == nil { continue }
//
//                    if class_getInstanceMethod(nsobjectclass, propSel) != nil { continue }
//
//                    let typeEncoding = method_getTypeEncoding(method)
//                    if typeEncoding == nil { continue }
//
//                    let returnTypePtr = method_copyReturnType(method)
//                    let returnType = String.fromCString(returnTypePtr) ?? "@"
//                    free(returnTypePtr)
//
//                    let propBlock : @objc_block (AnyObject) -> AnyObject? = { (sself : AnyObject) -> (AnyObject?) in
//                        // add the name of the property that was accessed; read-only properties tend to use their getterName as the key path (e.g., NSOperation.isFinished)
//                        let keyName = readonly && getterName != nil ? getterName! : propName
//                        keyPath = keyName // remember the keyPath for later
//                        object_setClass(target, origclass) // immediately swap the isa back to the original
//                        return target.valueForKey(keyName) // and defer the invocation to the discovered keyPath (throwing a helpful exception is we are wrong)
//                    }
//
//                    let propSelIMP = imp_implementationWithBlock(unsafeBitCast(propBlock, AnyObject.self))
//                    if !class_addMethod(subclass, propSel, propSelIMP, typeEncoding) {
//                        // ignore errors; sometimes happens with UITextField.inputView or NSView.tag
//                        // println("could not add method implementation")
//                    }
//                    propSelIMPs += [propSelIMP]
//
//                }
//            }
//        }
//
//        free(propList)
//    }
//
//    ChannelZKeyPathForAutoclosureLock.lock()
//    objc_registerClassPair(subclass)
//    object_setClass(target, subclass)
//
//    accessor() // invoke the accessor to see what instrumented properties are accessed
//
//    // resore the isa if we haven't done already and destroy the instrumenter subclass
//    if object_getClass(target) !== origclass {
//        object_setClass(target, origclass)
//    }
//
//    // clear the implementation blocks
//    for propSelIMP in propSelIMPs { imp_removeBlock(propSelIMP) }
//
//    // remove the subclass
//    objc_disposeClassPair(subclass)
//    ChannelZKeyPathForAutoclosureLock.unlock()
//
//    if required && keyPath == nil {
//        fatalError("could not determine autoclosure key path through instrumentation of «\(className)»; ensure that the property is accessed directly in the invocation and that it is key-vaue compliant, or else manually specify the keyPath parameter")
//    }
//
//    // println("returning property «\(keyPath)»")
//    return keyPath
//}
//
//
///// A Observable for events of a custom type
//public struct EventObservable<T>: ObservableType {
//    public typealias Element = T
//    internal var dispatchTarget: NSObject? // object to be retained for as long as someone holds the EventObservable
//    internal var subscriptions = ReceptorList<Element>()
//
//    public init(_ dispatchTarget: NSObject?) {
//        self.dispatchTarget = dispatchTarget
//    }
//
//    /// subscribes a subscription to receive change notifications from the state pipeline
//    ///
//    /// :param: subscription      the subscription closure to which state will be sent
//    public func subscribe(subscription: (Element)->())->Receptor {
//        let index = subscriptions.addReceptor(subscription)
//        return ReceptorOf(requester: { }, unsubscriber: { self.subscriptions.removeReceptor(index) })
//    }
//
//    // Boilerplate observable/filter/map
//    private typealias SelfObservable = EventObservable
//    public func observable() -> Observable<Element> { return Observable(self) }
//    public func filter(predicate: (Element)->Bool)->Observable<Element> { return filterObservable(self)(predicate) }
//    public func map<TransformedType>(transform: (Element)->TransformedType)->Observable<TransformedType> { return mapObservable(self)(transform).observable() }
//}
//
//
///// A Observable for NSNotificationCenter events
//public struct NotificationObservable: ObservableType {
//    private weak var target: NSObject?
//    private let name: String
//
//    public typealias Element = [NSObject : AnyObject]
//
//    private init(target: NSObject, name: String) {
//        self.target = target
//        self.name = name
//    }
//
//    /// subscribes a subscription to receive change notifications from the state pipeline
//    ///
//    /// :param: subscription      the subscription closure to which state will be sent
//    public func subscribe(subscription: ([NSObject : AnyObject])->())->Receptor {
//        if let target = target {
//            let sub = NotificationObserver(observee: target, name: name, handler: { subscription($0) })
//            return ReceptorOf(subscription: sub)
//        } else {
//            NSLog("ChannelZ warning: attempt to subscribe to a deallocated target notification «\(name)»; channels do not retain their targets")
//            let sub = DeallocatedTargetReceptor()
//            return ReceptorOf(subscription: sub)
//        }
//    }
//
//
//    // Boilerplate observable/filter/map
//    public typealias SelfObservable = NotificationObservable
//    public func observable() -> Observable<Element> { return Observable(self) }
//    public func filter(predicate: (Element)->Bool)->Observable<Element> { return filterObservable(self)(predicate) }
//    public func map<TransformedType>(transform: (Element)->TransformedType)->Observable<TransformedType> { return mapObservable(self)(transform).observable() }
//}
//
//#if DEBUG_CHANNELZ
//    /// Track how many observers we have created and released; useful for ensuring that subscriptions correctly clean up
//    public var ChannelZNotificationObserverCount = 0
//#endif
//
///// Observer for NSNotification changes
//public struct NotificationObserver: Receptor {
//    private weak var observer : TargetAssociatedObserver?
//
//    init(observee: NSObject, name: String, handler: ([NSObject : AnyObject])->(Void)) {
//        self.observer = TargetAssociatedObserver(target: observee, notificationName: name, callback: { (userInfo: [NSObject : AnyObject]) -> () in
//            handler(userInfo)
//        })
//    }
//
//    public func unsubscribe() {
//        self.observer?.unsubscribe()
//    }
//
//    public func request() {
//        // notification observables are read-only
//    }
//
//}
//
///// Adapter for the ReactiveX pattern of completion handlers accepting a set of next/error/completed values
//public enum NextErrorCompleted<T> {
//    case Next(BoxOf<T>)
//    case Error(NSError)
//    case Completed
//}
//
///// A boxed value used by `NextErrorCompleted`; it is an implementation detail to get around a swift compiler limitation
//public class BoxOf<T> {
//    public let value: T
//    public init(_ value: T) { self.value = value }
//}
//
///// Creates a Observable on NSNotificationCenter
//private func observableNotification(target: NSObject, name: String)->NotificationObservable {
//    return NotificationObservable(target: target, name: name)
//}
//
//public func observable(target: NSObject, name: String)->NotificationObservable {
//    return observableNotification(target, name)
//}
//
///// Extension for listening to notifications of a given type
//extension NSObject {
//    /// Registers with the NSNotificationCenter to observable event notications of the given name for this object
//    ///
//    /// :param: notificationName    the name of the notification to register
//    /// :param: center              the NSNotificationCenter to register with (defaults to defaultCenter())
//    public func notifyz(notificationName: String)->NotificationObservable {
//        return observableNotification(self, notificationName)
//    }
//}
//
//extension NSNumber : ConduitNumericCoercible {
//    public class func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Self? {
//        if let value = value as? NSNumber {
//            let type = value.objCType
//            if type == "c" { return self.init(char: value.charValue) }
//            else if type == "C" { return self.init(unsignedChar: value.unsignedCharValue) }
//            else if type == "s" { return self.init(short: value.shortValue) }
//            else if type == "S" { return self.init(unsignedShort: value.unsignedShortValue) }
//            else if type == "i" { return self.init(int: value.intValue) }
//            else if type == "I" { return self.init(unsignedInt: value.unsignedIntValue) }
//            else if type == "l" { return self.init(long: value.longValue) }
//            else if type == "L" { return self.init(unsignedLong: value.unsignedLongValue) }
//            else if type == "q" { return self.init(longLong: value.longLongValue) }
//            else if type == "Q" { return self.init(unsignedLongLong: value.unsignedLongLongValue) }
//            else if type == "f" { return self.init(float: value.floatValue) }
//            else if type == "d" { return self.init(double: value.doubleValue) }
//            else { return nil }
//        }
//        else if let value = value as? Bool { return self.init(bool: value) }
//        else if let value = value as? Int8 { return self.init(char: value) }
//        else if let value = value as? UInt8 { return self.init(unsignedChar: value) }
//        else if let value = value as? Int16 { return self.init(short: value) }
//        else if let value = value as? UInt16 { return self.init(unsignedShort: value) }
//        else if let value = value as? Int32 { return self.init(int: value) }
//        else if let value = value as? UInt32 { return self.init(unsignedInt: value) }
//        else if let value = value as? Int { return self.init(long: value) }
//        else if let value = value as? UInt { return self.init(unsignedLong: value) }
//        else if let value = value as? Int64 { return self.init(longLong: value) }
//        else if let value = value as? UInt64 { return self.init(unsignedLongLong: value) }
//        else if let value = value as? Float { return self.init(float: value) }
////        else if let value = value as? Float80 { return self.init(double: value) } ?
//        else if let value = value as? Double { return self.init(double: value) }
//        else { return nil }
//    }
//
//    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
//        if T.self is NSDecimalNumber.Type { return NSDecimalNumber(double: self.doubleValue) as? T }
//        else if T.self is NSNumber.Type { return self as? T }
//        else if T.self is Bool.Type { return Bool(self.boolValue) as? T }
//        else if T.self is Int8.Type { return Int8(self.charValue) as? T }
//        else if T.self is UInt8.Type { return UInt8(self.unsignedCharValue) as? T }
//        else if T.self is Int16.Type { return Int16(self.shortValue) as? T }
//        else if T.self is UInt16.Type { return UInt16(self.unsignedShortValue) as? T }
//        else if T.self is Int32.Type { return Int32(self.intValue) as? T }
//        else if T.self is UInt32.Type { return UInt32(self.unsignedIntValue) as? T }
//        else if T.self is Int.Type { return Int(self.longValue) as? T }
//        else if T.self is UInt.Type { return UInt(self.unsignedLongValue) as? T }
//        else if T.self is Int64.Type { return Int64(self.longLongValue) as? T }
//        else if T.self is UInt64.Type { return UInt64(self.unsignedLongLongValue) as? T }
//        else if T.self is Float.Type { return Float(self.floatValue) as? T }
////        else if T.self is Float80.Type { return Float80(self) as? T } ??
//        else if T.self is Double.Type { return Double(self.doubleValue) as? T }
//        else { return self as? T }
//    }
//
//}
//
//
///// Operator for getting a keypath channel from an NSObject
//infix operator ∞ { precedence 255 }
//
///// Infix operator for creating a channel from an auto-discovered keyPath to a non-optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T>(lhs: NSObject, rhs: @autoclosure ()->T)->ChannelZ<T> { return channelRequired(lhs, rhs) }
//
///// Infix operator for creating a channel from an auto-discovered keyPath to an equatable non-optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T : Equatable>(lhs: NSObject, rhs: @autoclosure ()->T)->ChannelZ<T> { return sieveRequired(lhs, rhs) }
//
///// Infix operator for creating a channel from an auto-discovered keyPath to an optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T>(lhs: NSObject, rhs: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> { return channelOptional(lhs, rhs) }
//
///// Infix operator for creating a channel from an auto-discovered keyPath to an equatable optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T : Equatable>(lhs: NSObject, rhs: @autoclosure ()->Optional<T>)->ChannelZ<Optional<T>> { return sieveOptional(lhs, rhs) }
//
///// Infix operator for creating a channel from the specified keyPath to a non-optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T>(lhs: NSObject, rhs: (getter: @autoclosure ()->T, keyPath: String))->ChannelZ<T> { return channelRequired(lhs, rhs.getter, keyPath: rhs.keyPath) }
//
///// Infix operator for creating a channel from the specified keyPath to an equatable non-optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T : Equatable>(lhs: NSObject, rhs: (getter: @autoclosure ()->T, keyPath: String))->ChannelZ<T> { return sieveRequired(lhs, rhs.getter, keyPath: rhs.keyPath) }
//
///// Infix operator for creating a channel from the specified keyPath to an optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T>(lhs: NSObject, rhs: (getter: @autoclosure ()->Optional<T>, keyPath: String))->ChannelZ<Optional<T>> { return channelOptional(lhs, rhs.getter, keyPath: rhs.keyPath) }
//
///// Infix operator for creating a channel from the specified keyPath to an equatable optional property
/////
///// :returns: a ChannelZ wrapper for the objects KVO field
//public func ∞ <T : Equatable>(lhs: NSObject, rhs: (getter: @autoclosure ()->Optional<T>, keyPath: String))->ChannelZ<Optional<T>> { return sieveOptional(lhs, rhs.getter, keyPath: rhs.keyPath) }
//

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
    public func channelZKeyState<T>(@autoclosure accessor: () -> T, keyPath: String? = nil) -> Channel<KeyValueSource<T>, StatePulse<T>> {
        return KeyValueSource(target: KeyValueTarget(target: self, accessor: accessor, keyPath: keyPath)).channelZState()
    }

    /// Creates a channel for all state operations for the given key-value-coding property that will emit
    /// a tuple of the previous value (or nil if unavailable) and current state.
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive state transition operations
    public func channelZKeyState<T>(@autoclosure accessor: () -> T?, keyPath: String? = nil) -> Channel<KeyValueOptionalSource<T>, StatePulse<T?>> {
        return KeyValueOptionalSource(target: KeyValueTarget(target: self, accessor: accessor, keyPath: keyPath)).channelZState()
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant non-optional property
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    /// 
    /// - Returns a channel backed by the KVO property that will receive items for every time the state is assigned
    public func channelZKey<T>(@autoclosure accessor: () -> T, keyPath: String? = nil) -> Channel<KeyValueSource<T>, T> {
        return channelZKeyState(accessor, keyPath: keyPath).new()
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant optional property
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive items for every time the state is assigned
    public func channelZKey<T>(@autoclosure accessor: () -> T?, keyPath: String? = nil) -> Channel<KeyValueOptionalSource<T>, T?> {
        return channelZKeyState(accessor, keyPath: keyPath).new()
    }

    // FIXME: channelZKeyArray and channelZKeyOrderedSet are 95% identical and could be unified with a generic but for compiler crashes


    /// Creates a channel for all KVO-compliant NSArray modifications
    ///
    /// - Parameter accessor: an accessor for the NSArray of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive ArrayChange items for mutations
    public func channelZKeyArray(@autoclosure accessor: () -> NSArray?, keyPath: String? = nil) -> Channel<NSObject, ArrayChange> {

        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverList<ArrayChange>()

        return Channel(source: self) { [unowned self] receiver in

            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new: AnyObject? = change[NSKeyValueChangeNewKey]
                let old: AnyObject? = change[NSKeyValueChangeOldKey]
                let indices = change[NSKeyValueChangeIndexesKey] as? NSIndexSet

                let kind = NSKeyValueChange(rawValue: change[NSKeyValueChangeKindKey] as! UInt)!

                switch kind {
                case .Setting: receivers.receive(.Assigned(new as? NSArray))
                case .Insertion: receivers.receive(.Added(indices: indices!, new: new as! NSArray))
                case .Removal: receivers.receive(.Removed(indices: indices!, old: old as! NSArray))
                case .Replacement: receivers.receive(.Replaced(indices: indices!, old: old as! NSArray, new: new as! NSArray))
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
    public func channelZKeyOrderedSet(@autoclosure accessor: () -> NSOrderedSet?, keyPath: String? = nil) -> Channel<NSObject, OrderedSetChange> {
        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverList<OrderedSetChange>()

        return Channel(source: self) { [unowned self] receiver in

            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new: AnyObject? = change[NSKeyValueChangeNewKey]
                let old: AnyObject? = change[NSKeyValueChangeOldKey]
                let indices = change[NSKeyValueChangeIndexesKey] as? NSIndexSet

                let kind = NSKeyValueChange(rawValue: change[NSKeyValueChangeKindKey] as! UInt)!

                switch kind {
                case .Setting: receivers.receive(.Assigned(new as? NSOrderedSet))
                case .Insertion: receivers.receive(.Added(indices: indices!, new: new as! NSArray))
                case .Removal: receivers.receive(.Removed(indices: indices!, old: old as! NSArray))
                case .Replacement: receivers.receive(.Replaced(indices: indices!, old: old as! NSArray, new: new as! NSArray))
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
    public func channelZKeySet(@autoclosure accessor: () -> NSSet?, keyPath: String? = nil) -> Channel<NSObject, SetChange> {
        let kp = keyPath ?? conjectKeypath(self, accessor, true)!
        let receivers = ReceiverList<SetChange>()

        return Channel(source: self) { [unowned self] receiver in

            let observer = TargetObserverRegister.get(self).addObserver(kp) { change in
                let new: AnyObject? = change[NSKeyValueChangeNewKey]
                let old: AnyObject? = change[NSKeyValueChangeOldKey]

                let kind = NSKeyValueChange(rawValue: change[NSKeyValueChangeKindKey] as! UInt)!

                switch kind {
                case .Setting: receivers.receive(.Assigned(new as? NSSet))
                case .Insertion: receivers.receive(.Added(new as! NSSet))
                case .Removal: receivers.receive(.Removed(old as! NSSet))
                case .Replacement: fatalError("should never happen")
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
    case Assigned(NSArray?)
    case Added(indices: NSIndexSet, new: NSArray)
    case Removed(indices: NSIndexSet, old: NSArray)
    case Replaced(indices: NSIndexSet, old: NSArray, new: NSArray)
}

/// Change type for `channelZKeyOrderedSet`
public enum OrderedSetChange {
    case Assigned(NSOrderedSet?)
    case Added(indices: NSIndexSet, new: NSArray)
    case Removed(indices: NSIndexSet, old: NSArray)
    case Replaced(indices: NSIndexSet, old: NSArray, new: NSArray)
}

/// Change type for `channelZKeySet`
public enum SetChange {
    case Assigned(NSSet?)
    case Added(NSSet)
    case Removed(NSSet)
}


/// A struct that combines the given target NSObject and the accessor closure to determine the keyPath for the accessor
public struct KeyValueTarget<T> {
    public let target: NSObject
    public let initialValue: T
    public let keyPath: String
}

public extension KeyValueTarget {
    public init(target: NSObject, @autoclosure accessor: () -> T, keyPath: String? = nil) {
        self.target = target
        self.initialValue = accessor()
        if let kp = keyPath {
            self.keyPath = kp
        } else {
            self.keyPath = conjectKeypath(target, accessor, true)!
        }
    }
}


// MARK: Operators

/// Creates a distinct sieved channel from the given Optional Equatable PropertySource (cover for ∞?=)
public prefix func ∞= <T: Equatable>(source: KeyValueOptionalSource<T>) -> Channel<KeyValueOptionalSource<T>, T?> { return ∞?=source }

/// Creates a source for the given property that will emit state operations
public postfix func ∞ <T>(kvt: KeyValueTarget<T>) -> KeyValueSource<T> {
    return KeyValueSource(target: kvt)
}

/// Creates a source for the given equatable property that will emit state operations
public postfix func =∞ <T: Equatable>(kvt: KeyValueTarget<T>) -> KeyValueSource<T> {
    return KeyValueSource(target: kvt)
}

/// Creates a source for the given optional property that will emit state operations
public postfix func ∞ <T>(kvt: KeyValueTarget<T?>) -> KeyValueOptionalSource<T> {
    return KeyValueOptionalSource(target: kvt)
}

/// Creates a source for the given equatable & optional property that will emit state operations
public postfix func =∞ <T: Equatable>(kvt: KeyValueTarget<T?>) -> KeyValueOptionalSource<T> {
    return KeyValueOptionalSource(target: kvt)
}


// MARK: Infix operators

/// Use the specified accessor to determine the keyPath for the given autoclosure
/// For example, slider§slider.doubleValue will return: (slider, { slider.doubleValue }, "doubleValue")
public func § <T>(object: NSObject, @autoclosure getter: () -> T) -> KeyValueTarget<T> {
    return KeyValueTarget(target: object, initialValue: getter(), keyPath: conjectKeypath(object, getter, true)!)
}

/// Use the specified accessor to manually specify the keyPath for the given autoclosure
public func § <T>(object: NSObject, getkey: (value: T, keyPath: String)) -> KeyValueTarget<T> {
    return KeyValueTarget(target: object, initialValue: getkey.value, keyPath: getkey.keyPath)
}

infix operator § { precedence 255 }


/// Operation to create a channel from an object's keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, @autoclosure getter: () -> T) -> Channel<KeyValueSource<T>, T> {
    return ∞(object§getter)∞
}

/// Operation to create a channel from an object's equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, @autoclosure getter: () -> T) -> Channel<KeyValueSource<T>, T> {
    return ∞=(object§getter)=∞
}

/// Operation to create a channel from an object's optional keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, @autoclosure getter: () -> T?) -> Channel<KeyValueOptionalSource<T>, T?> {
    return ∞(object§getter)∞
}

/// Operation to create a channel from an object's optional equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, @autoclosure getter: () -> T?) -> Channel<KeyValueOptionalSource<T>, T?> {
    return ∞=(object§getter)=∞
}



/// Operation to create a channel from an object's keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, getpath: (value: T, keyPath: String)) -> Channel<KeyValueSource<T>, T> {
    return ∞(object§getpath)∞
}

/// Operation to create a channel from an object's equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, getpath: (value: T, keyPath: String)) -> Channel<KeyValueSource<T>, T> {
    return ∞=(object§getpath)=∞
}

/// Operation to create a channel from an object's optional keyPath; shorthand for  ∞(object§getter)∞
public func ∞ <T>(object: NSObject, getpath: (value: T?, keyPath: String)) -> Channel<KeyValueOptionalSource<T>, T?> {
    return ∞(object§getpath)∞
}

/// Operation to create a channel from an object's optional equatable keyPath; shorthand for ∞=(object§getter)=∞
public func ∞ <T: Equatable>(object: NSObject, getpath: (value: T?, keyPath: String)) -> Channel<KeyValueOptionalSource<T>, T?> {
    return ∞=(object§getpath)=∞
}


infix operator ∞ { precedence 255 }

public protocol KeyValueSourceType : class, StateSink, StateSource {
    var optional: Bool { get }
    var keyPath: String { get }
    var object: NSObject? { get }
    var receivers: ReceiverList<StatePulse<Element>> { get }
    var pulseIndex: Int64 { get }

    func get() -> Element
    func createPulse(change: NSDictionary) -> StatePulse<Element>
}

public extension KeyValueSourceType {
    public func set(value: Element) -> Bool {
        if let target = self.object {
            setValueForKeyPath(target, keyPath: keyPath, nullable: optional, value: value)
            return true
        } else {
            return false
        }
    }

    /// access to the underlying source value
    public var value: Element {
        get { return get() }
        set(v) { set(v) }
    }

    /// Sets the current value (SinkType implementation)
    public func put(value: Element) -> Void {
        set(value)
    }

    private func validateInitialValue(iv: Element) {
        // validate the keyPath by checking that the initialized value matched the actual key path
        let initialValue: AnyObject? = object?.valueForKeyPath(self.keyPath)
        if let initialValueActual: AnyObject = initialValue {
            if let gotten = iv as? NSObject {
                if let eq1 = initialValueActual as? NSObjectProtocol {
                    // make sure the key path is really returning the specified value
                    assert(eq1.isEqual(gotten), "valueForKeyPath(\(keyPath)): «\(initialValue)» did not equal initialized value: «\(gotten)»")
                }
            }
        }

    }

    private func registerObserver() {
        guard let target = self.object else {
            preconditionFailure("ChannelZ: cannot add receiver for deallocated instance (channels do not retain their targets)")
        }

        let rcvrs = self.receivers
        TargetObserverRegister.get(target).addObserver(keyPath) { change in
            rcvrs.receive(self.createPulse(change))
        }
    }

    private func addReceiver(receiver: StatePulse<Element> -> Void) -> Receipt {
        // immediately issue the original value with no previous value
        receiver(StatePulse<Element>(old: Optional<Element>.None, new: get(), index: AnyForwardIndex(pulseIndex)))

        let kp = keyPath
        let index = receivers.addReceiver(receiver)
        return ReceiptOf(canceler: { [weak self] in
            self?.receivers.removeReceptor(index)
            if let target = self?.object {
                TargetObserverRegister.get(target).removeObserver(kp, identifier: index)
            }
        })
    }

    public func channelZState()->Channel<Self, StatePulse<Element>> {
        return Channel(source: self, reception: addReceiver)
    }
}

/// A Source for Channels of Cocoa properties that support key-value path observation/coding
public final class KeyValueSource<T>: KeyValueSourceType {
    public typealias Element = T

    public let keyPath: String
    public let optional = false
    public private(set) weak var object: NSObject?
    public let receivers = ReceiverList<StatePulse<Element>>()
    public private(set) var pulseIndex: Int64 = 0

    public init(target: KeyValueTarget<Element>) {
        self.object = target.target
        self.keyPath = target.keyPath
        validateInitialValue(target.initialValue)
        registerObserver()
    }

    public func get() -> T {
        let keyValue: AnyObject? = object?.valueForKeyPath(self.keyPath)
        return coerceFoundationType(keyValue)!
    }

    public func createPulse(change: NSDictionary) -> StatePulse<Element> {
        let newv: Element? = coerceFoundationType(change[NSKeyValueChangeNewKey]!)
        let oldv: Element? = coerceFoundationType(change[NSKeyValueChangeOldKey]!)
        return StatePulse<Element>(old: oldv, new: newv!, index: AnyForwardIndex(OSAtomicIncrement64(&pulseIndex)))
    }
}


/// A Source for Channels of Cocoa properties that support key-value path observation/coding
public final class KeyValueOptionalSource<T>: KeyValueSourceType {
    public typealias Element = T?
    public let keyPath: String
    public let optional = true
    public private(set) weak var object: NSObject?
    public let receivers = ReceiverList<StatePulse<Element>>()
    public private(set) var pulseIndex: Int64 = 0

    public init(target: KeyValueTarget<Element>) {
        self.object = target.target
        self.keyPath = target.keyPath
        validateInitialValue(target.initialValue)
        registerObserver()
    }

    public func get() -> T? {
        let keyValue: AnyObject? = object?.valueForKeyPath(self.keyPath)
        return keyValue as? T? ?? coerceFoundationType(keyValue)
    }

    public func createPulse(change: NSDictionary) -> StatePulse<Element> {
        let newv: Element = coerceFoundationType(change[NSKeyValueChangeNewKey]!)
        let oldv: Element = coerceFoundationType(change[NSKeyValueChangeOldKey]!)
        return StatePulse<Element>(old: oldv, new: newv, index: AnyForwardIndex(OSAtomicIncrement64(&pulseIndex)))
    }
}


/// Optional protocol for target objects to implement when they need to supplement key-value observing with additional events
@objc public protocol KeyValueChannelSupplementing {
    /// Add additional observers for the specified keyPath, returning the unsubscriber for any supplements
    func supplementKeyValueChannel(forKeyPath: String, subscription: (AnyObject?) -> ()) -> (() -> ())?
}


#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that subscriptions are correctly cleaned up
    public var ChannelZKeyValueObserverCount = Int64(0)
#endif


/// An observer register that is stored as an associated object in the target and is automatically removed when the target is deallocated; can be with either KVO or NSNotificationCenter depending on the constructor arguments
@objc final class TargetObserverRegister : NSObject {
    // note: it would make sense to declare this as TargetObserverRegister<T:NSObject>, but the class won't receive any KVO notifications if it is a generic

    private struct Context {
        /// Global pointer to the context that will holder the observer list
        private static var ObserverListAssociatedKey: UnsafePointer<Void> = nil

        /// Global lock for getting/setting the observer
        private static var RegisterLock = NSLock()

        /// Singleton notification center; we don't currently support multiple NSNotificationCenter observers
        private static let RegisterNotificationCenter = NSNotificationCenter.defaultCenter()

        /// Note that we don't use NSKeyValueObservingOptions.Initial because the initial values wind up
        /// being broadcast to *all* receivers, not just the changed one
        private static let KVOOptions = NSKeyValueObservingOptions(rawValue: NSKeyValueObservingOptions.Old.rawValue | NSKeyValueObservingOptions.New.rawValue)
    }

    /// The signature for the callback when a change occurs
    typealias Callback = ([NSObject : AnyObject]) -> ()

    typealias Observer = (identifier: Int64, handler: Callback)

    // since this associated object is deallocated as part of the owning object's dealloc (see objc_destructInstance in <http://opensource.apple.com/source/objc4/objc4-646/runtime/objc-runtime-new.mm>), we can't rely on the weak reference not having been zeroed, so use an extra unmanaged pointer to the target object that we can use to remove the observer
    private let targetPtr: Unmanaged<NSObject>

    private var target : NSObject { return targetPtr.takeUnretainedValue() }

    private var keyObservers = [String: [Observer]]()

    private var noteObservers = [String: [Observer]]()

    /// The internal counter of identifiers
    private var identifierCounter : Int64 = 0

    class func get(target: NSObject) -> TargetObserverRegister {
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

    func addObserver(keyPath: String, callback: Callback) -> Int64 {
        OSAtomicIncrement64(&identifierCounter)
        let observer = Observer(identifier: identifierCounter, handler: callback)

        let observers = keyObservers[keyPath] ?? []
        keyObservers[keyPath] = observers + [observer]

        if observers.count == 0 { // this is the first observer: actually add it to the target
            target.addObserver(self, forKeyPath: keyPath, options: Context.KVOOptions, context: nil)
        }

        return observer.identifier
    }

    func addNotification(name: String, callback: Callback) -> Int64 {
        OSAtomicIncrement64(&identifierCounter)
        let observers = noteObservers[name] ?? []
        if observers.count == 0 { // this is the first observer: actually add it to the target
            Context.RegisterNotificationCenter.addObserver(self, selector: #selector(self.notificationReceived), name: name, object: target)
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
                if let className = String.fromCString(class_getName(cls)) {
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
            if target is NSBlockOperation {
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
            Context.RegisterNotificationCenter.removeObserver(self, name: name, object: target)
        }
        noteObservers = [:]
    }

    func removeObserver(keyPath: String, identifier: Int64) {
        if let observers = keyObservers[keyPath] {
            let filtered = observers.filter { $0.identifier != identifier }
            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
                // FIXME: random crashes in certain specific observed classes, such as NSBlockOperation:
                // error: -[ChannelZTests.ChannelZTests testOperationChannels] : failed: caught "NSRangeException", "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x109c0daa0> for the key path "isExecuting" from <NSBlockOperation 0x109c07830> because it is not registered as an observer."
                keyObservers.removeValueForKey(keyPath)
                target.removeObserver(self, forKeyPath: keyPath, context: nil)
            } else {
                keyObservers[keyPath] = filtered
            }
        }
    }

    func removeNotification(name: String, identifier: Int64) {
        if let observers = noteObservers[name] {
            let filtered = observers.filter { $0.identifier != identifier }
            if filtered.count == 0 { // no more observers left: remove ourselves as the observer
                noteObservers.removeValueForKey(name)
                Context.RegisterNotificationCenter.removeObserver(self, name: name, object: nil)
            } else {
                noteObservers[name] = filtered
            }
        }
    }

    /// Callback for KVO
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let keyPath = keyPath, observers = keyObservers[keyPath] {
            for observer in observers {
                observer.handler(change ?? [:])
            }
        }
    }

    /// Callback for in NSNotificationCenter
    func notificationReceived(note: NSNotification) {
        let change = note.userInfo ?? [:]
        if let observers = noteObservers[note.name] {
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
private func conjectKeypath<T>(target: NSObject, @autoclosure _ accessor: () -> T, _ required: Bool) -> String? {
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
            let prop = propList[Int(i)]

            let pname = property_getName(prop)
            let propName = String.fromCString(pname)

            // the selector we will implement will be the accessor for the property; these often differ with bools (e.g. "enabled" vs. "isEnabled")
            let gname = property_copyAttributeValue(prop, "G") // the getter name
            let getterName = String.fromCString(gname)
            free(gname)

            let ronly = property_copyAttributeValue(prop, "R") // whether the property is read-only
            let readonly = ronly != nil
            free(ronly)

            if let propName = propName {
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

                let propBlock : @convention(block) (AnyObject) -> AnyObject? = { (sself : AnyObject) -> (AnyObject?) in
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
                propSelIMPs.append(propSelIMP)
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

private func setValueForKeyPath<T>(target: NSObject, keyPath: String, nullable: Bool, value: T?) {
    if let value = value {
        if nullable && value is NSNull { target.setValue(nil, forKeyPath: keyPath) }
        else if let ob = value as? NSObject { target.setValue(ob, forKeyPath: keyPath) }
            // manual numeric coercion: because only “the following types are automatically bridged to NSNumber: Int, UInt, Float, Double, Bool”
        else if let value = value as? Bool { target.setValue(NSNumber(bool: value), forKeyPath: keyPath) }
        else if let value = value as? Int8 { target.setValue(NSNumber(char: value), forKeyPath: keyPath) }
        else if let value = value as? UInt8 { target.setValue(NSNumber(unsignedChar: value), forKeyPath: keyPath) }
        else if let value = value as? Int16 { target.setValue(NSNumber(short: value), forKeyPath: keyPath) }
        else if let value = value as? UInt16 { target.setValue(NSNumber(unsignedShort: value), forKeyPath: keyPath) }
        else if let value = value as? Int32 { target.setValue(NSNumber(int: value), forKeyPath: keyPath) }
        else if let value = value as? UInt32 { target.setValue(NSNumber(unsignedInt: value), forKeyPath: keyPath) }
        else if let value = value as? Int { target.setValue(NSNumber(integer: value), forKeyPath: keyPath) }
        else if let value = value as? UInt { target.setValue(NSNumber(unsignedLong: value), forKeyPath: keyPath) }
        else if let value = value as? Int64 { target.setValue(NSNumber(longLong: value), forKeyPath: keyPath) }
        else if let value = value as? UInt64 { target.setValue(NSNumber(unsignedLongLong: value), forKeyPath: keyPath) }
        else if let value = value as? Float { target.setValue(NSNumber(float: value), forKeyPath: keyPath) }
        else if let value = value as? Double { target.setValue(NSNumber(double: value), forKeyPath: keyPath) }
        else {
            target.setValue(nil, forKeyPath: keyPath)
            //            preconditionFailure("unable to coerce value «\(value.dynamicType)» into Foundation type for keyPath «\(keyPath)»")
        }
    } else if nullable {
        target.setValue(nil, forKeyPath: keyPath)
    } else {
        preconditionFailure("unable to coerce value «\(value.dynamicType)» into Foundation type for non-nullable keyPath «\(keyPath)»")
    }
}

private func coerceFoundationType<SourceType>(ob: AnyObject?) -> SourceType? {
    if let ob = ob as? SourceType {
        return ob // always first try to get automatic coercion (e.g., NSString to String)
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

//    println("failed to coerce value «\(ob)» of type \(ob?.dynamicType) into \(SourceType.self)")
    return nil
}

/// Extension for listening to notifications of a given type
extension NSObject {
    public typealias UserInfo = [NSObject : AnyObject]

    /// Registers with the NSNotificationCenter to observable event notications of the given name for this object
    ///
    /// - Parameter notificationName: the name of the notification to register
    /// - Parameter center: the NSNotificationCenter to register with (defaults to defaultCenter())
    public func channelZNotification(name: String, center: NSNotificationCenter = NSNotificationCenter.defaultCenter()) -> Channel<NSNotificationCenter, UserInfo> {
        let receivers = ReceiverList<UserInfo>()
        return Channel(source: center) { [weak self] (receiver: UserInfo -> Void) -> Receipt in
            var rindex: Int64

            if let target = self {
                rindex = receivers.addReceiver(receiver) // first add the observer so we get the initial notification
                TargetObserverRegister.get(target).addNotification(name) { receivers.receive($0) }
            } else {
                preconditionFailure("cannot add receiver for deallocated instance (channels do not retain their targets)")
            }

            return ReceiptOf(canceler: { [weak self] in
                if let target = self {
                    TargetObserverRegister.get(target) // .removeObserver(kp, identifier: oindex)
                }
                receivers.removeReceptor(rindex)
            })
        }
    }
}

extension NSNumber : ConduitNumericCoercible {
    @warn_unused_result public class func fromConduitNumericCoercible(value: ConduitNumericCoercible) -> Self? {
        if let value = value as? NSNumber {
            let type = Character(UnicodeScalar(UInt32(value.objCType.memory)))
            
            if type == "c" { return self.init(char: value.charValue) }
            else if type == "C" { return self.init(unsignedChar: value.unsignedCharValue) }
            else if type == "s" { return self.init(short: value.shortValue) }
            else if type == "S" { return self.init(unsignedShort: value.unsignedShortValue) }
            else if type == "i" { return self.init(int: value.intValue) }
            else if type == "I" { return self.init(unsignedInt: value.unsignedIntValue) }
            else if type == "l" { return self.init(long: value.longValue) }
            else if type == "L" { return self.init(unsignedLong: value.unsignedLongValue) }
            else if type == "q" { return self.init(longLong: value.longLongValue) }
            else if type == "Q" { return self.init(unsignedLongLong: value.unsignedLongLongValue) }
            else if type == "f" { return self.init(float: value.floatValue) }
            else if type == "d" { return self.init(double: value.doubleValue) }
            else { return nil }
        }
        else if let value = value as? Bool { return self.init(bool: value) }
        else if let value = value as? Int8 { return self.init(char: value) }
        else if let value = value as? UInt8 { return self.init(unsignedChar: value) }
        else if let value = value as? Int16 { return self.init(short: value) }
        else if let value = value as? UInt16 { return self.init(unsignedShort: value) }
        else if let value = value as? Int32 { return self.init(int: value) }
        else if let value = value as? UInt32 { return self.init(unsignedInt: value) }
        else if let value = value as? Int { return self.init(long: value) }
        else if let value = value as? UInt { return self.init(unsignedLong: value) }
        else if let value = value as? Int64 { return self.init(longLong: value) }
        else if let value = value as? UInt64 { return self.init(unsignedLongLong: value) }
        else if let value = value as? Float { return self.init(float: value) }
//        else if let value = value as? Float80 { return self.init(double: value) } ?
        else if let value = value as? Double { return self.init(double: value) }
        else { return nil }
    }

    public func toConduitNumericCoercible<T : ConduitNumericCoercible>() -> T? {
        if T.self is NSDecimalNumber.Type { return NSDecimalNumber(double: self.doubleValue) as? T }
        else if T.self is NSNumber.Type { return self as? T }
        else if T.self is Bool.Type { return Bool(self.boolValue) as? T }
        else if T.self is Int8.Type { return Int8(self.charValue) as? T }
        else if T.self is UInt8.Type { return UInt8(self.unsignedCharValue) as? T }
        else if T.self is Int16.Type { return Int16(self.shortValue) as? T }
        else if T.self is UInt16.Type { return UInt16(self.unsignedShortValue) as? T }
        else if T.self is Int32.Type { return Int32(self.intValue) as? T }
        else if T.self is UInt32.Type { return UInt32(self.unsignedIntValue) as? T }
        else if T.self is Int.Type { return Int(self.longValue) as? T }
        else if T.self is UInt.Type { return UInt(self.unsignedLongValue) as? T }
        else if T.self is Int64.Type { return Int64(self.longLongValue) as? T }
        else if T.self is UInt64.Type { return UInt64(self.unsignedLongLongValue) as? T }
        else if T.self is Float.Type { return Float(self.floatValue) as? T }
//        else if T.self is Float80.Type { return Float80(self) as? T } ??
        else if T.self is Double.Type { return Double(self.doubleValue) as? T }
        else { return self as? T }
    }

}

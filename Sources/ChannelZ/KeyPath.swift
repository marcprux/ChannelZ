//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//
//
/// Support for Foundation channels and observables, such as KVO-based channels and NSNotificationCenter observables

#if !os(Linux)

import Foundation

fileprivate let KVOOptions: NSKeyValueObservingOptions = [.old, .new]
    
public typealias KeyStateChannel<T: NSObject, U> = Channel<KeyValueTransceiver<T, U>, Mutation<U>>
public typealias KeyValueChannel<T: NSObject, U> = Channel<KeyValueTransceiver<T, U>, U>

extension NSObjectProtocol where Self : NSObject {
    public subscript<T>(channel channel: KeyPath<Self, T>) -> KeyStateChannel<Self, T> {
        get {
            return channelZKeyState(channel)
        }
    }
    /// Creates a channel for all state operations for the given key-value-coding property that will emit
    /// a tuple of the previous value (or nil if unavailable) and current state.
    ///
    /// - Parameter keyPath: the keyPath for the value
    /// - Parameter name: the name of the keyPath; if omitted, it will be inferred
    ///
    /// - Returns a channel backed by the KVO property that will receive state transition operations
    public func channelZKeyState<T>(_ keyPath: KeyPath<Self, T>, path: String? = nil) -> KeyStateChannel<Self, T> {
        return KeyValueTransceiver(target: KeyValueTarget(target: self, keyPath: keyPath, path: path ?? keyPath._kvcKeyPathString!)).transceive()
    }

    /// Creates a channel for all state operations for the given key-value-coding compliant non-optional property
    ///
    /// - Parameter accessor: an accessor for the value of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    /// 
    /// - Returns a channel backed by the KVO property that will receive items for every time the state is assigned
    public func channelZKeyValue<T>(_ keyPath: KeyPath<Self, T>, path: String? = nil) -> KeyValueChannel<Self, T> {
        return channelZKeyState(keyPath, path: path).new()
    }

    /// Creates a channel for all KVO-compliant NSArray/NSSet/NSOrderedSet modifications
    ///
    /// - Parameter accessor: an accessor for the NSArray of the property (autoclosure)
    /// - Parameter keyPath: the keyPath for the value; if ommitted, auto-discovery will be attempted
    ///
    /// - Returns a channel backed by the KVO property that will receive ArrayChange items for mutations
    public func channelZCollection<T: ObservableCollection>(_ keyPath: KeyPath<Self, T>, path: String? = nil) -> Channel<Self, T.MutationType> {
        let receivers = ReceiverQueue<T.MutationType>()
        
        return Channel(source: self) { [unowned self] receiver in
            let observer = self.observe(keyPath, options: KVOOptions, changeHandler: { (ob, value) in
                receivers.receive(T.mutationFromChange(change: value))
            })

            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                observer.invalidate()
                receivers.removeReceptor(index)
            })
        }
    }
}

public protocol ObservableCollection : NSObjectProtocol {
    associatedtype MutationType : ObservableCollectionMutation
    
    static func mutationFromChange<T>(change: NSKeyValueObservedChange<T>) -> MutationType
}
    
public protocol ObservableCollectionMutation {
    
}
    
extension NSArray : ObservableCollection {
    public typealias MutationType = ArrayChange
    
    public static func mutationFromChange<T>(change: NSKeyValueObservedChange<T>) -> MutationType {
        let new = change.newValue
        let old = change.oldValue
        let indices = change.indexes
        
        let kind = change.kind
        
        switch kind {
        case .setting: return (.assigned(new as? NSArray))
        case .insertion: return (.added(indices: indices ?? [], new: new as? NSArray ?? []))
        case .removal: return (.removed(indices: indices ?? [], old: old as? NSArray ?? []))
        case .replacement: return (.replaced(indices: indices ?? [], old: old as? NSArray ?? [], new: new as? NSArray ?? []))
        }
    }

}
    
/// Change type for `channelZKeyArray`
public enum ArrayChange : ObservableCollectionMutation {
    case assigned(NSArray?)
    case added(indices: IndexSet, new: NSArray)
    case removed(indices: IndexSet, old: NSArray)
    case replaced(indices: IndexSet, old: NSArray, new: NSArray)
}

extension NSOrderedSet : ObservableCollection {
    public typealias MutationType = OrderedSetChange
    
    public static func mutationFromChange<T>(change: NSKeyValueObservedChange<T>) -> MutationType {
        let new = change.newValue
        let old = change.oldValue
        let indices = change.indexes
        
        let kind = change.kind
    
        
        switch kind {
        case .setting: return (.assigned(new as? NSOrderedSet))
        case .insertion: return (.added(indices: indices ?? [], new: new as? NSArray ?? []))
        case .removal: return (.removed(indices: indices ?? [], old: old as? NSArray ?? []))
        case .replacement: return (.replaced(indices: indices ?? [], old: old as? NSArray ?? [], new: new as? NSArray ?? []))
        }
    }

}

/// Change type for `channelZKeyOrderedSet`
public enum OrderedSetChange : ObservableCollectionMutation {
    case assigned(NSOrderedSet?)
    case added(indices: IndexSet, new: NSArray)
    case removed(indices: IndexSet, old: NSArray)
    case replaced(indices: IndexSet, old: NSArray, new: NSArray)
}

extension NSSet : ObservableCollection {
    public typealias MutationType = SetChange
    
    public static func mutationFromChange<T>(change: NSKeyValueObservedChange<T>) -> MutationType {
        let new = change.newValue
        let old = change.oldValue
        
        let kind = change.kind
        
        switch kind {
        case .setting: return (.assigned(new as? NSSet))
        case .insertion: return (.added(new as? NSSet ?? []))
        case .removal: return (.removed(old as? NSSet ?? []))
        case .replacement: fatalError("should never happen")
        }
    }

}

/// Change type for `channelZKeySet`
public enum SetChange : ObservableCollectionMutation {
    case assigned(NSSet?)
    case added(NSSet)
    case removed(NSSet)
}

/// A struct that combines the given target NSObject and the accessor closure to determine the keyPath for the accessor
public struct KeyValueTarget<O: NSObject, T> {
    public let target: O
    public let initialValue: T
    public let keyPath: KeyPath<O, T>
    public let path: String
}
    
public extension KeyValueTarget {
    public init(target: O, keyPath: KeyPath<O, T>, path: String? = nil) {
        self.target = target
        self.initialValue = target[keyPath: keyPath]
        self.keyPath = keyPath
        self.path = path ?? keyPath._kvcKeyPathString!
    }
}
    
/// A Source for Channels of Cocoa properties that support key-value path observation/coding
public final class KeyValueTransceiver<O: NSObject, T>: TransceiverType {
    public typealias Element = T
    public typealias ObjectType = O

    public let keyPath: KeyPath<O, T>
    public let optional = false
    public let object: O
    
    public init(target: KeyValueTarget<O, Element>) {
        self.object = target.target
        self.keyPath = target.keyPath

        // we instead create and destroy observers only when adding listeners
//        createObserver()
    }

    
    @discardableResult
    public func set(_ value: Element) -> Bool {
        if let wkp = keyPath as? WritableKeyPath {
            var ob = self.object
            ob[keyPath: wkp] = value
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
    
    /// Sets the current value (ReceiverType implementation)
    public func receive(_ value: Element) -> Void {
        set(value)
    }
    
    
    public typealias StateChannel<T> = Channel<KeyValueTransceiver, Mutation<T>>
    
    public func transceive() -> StateChannel<Element> {
        let receivers = ReceiverQueue<Mutation<Element>>()
        var observation: NSKeyValueObservation? = nil
        let ob = self.object
        let kp = self.keyPath
        
        func addReceiver(_ receiver: @escaping (Mutation<Element>) -> Void) -> Receipt {
            // create an observer only for the first receiver
            observation = observation ?? ob.observe(kp, options: KVOOptions, changeHandler: { (ob, change) in
                if let new = change.newValue {
                    receivers.receive(Mutation(old: change.oldValue, new: new))
                } else {
                    // value was nil, which is possible when the target path is itself optional
                    // it would be better to cast the type of the receiver to queue to optional
                    receivers.receive(Mutation(old: change.oldValue, new: ob[keyPath: kp]))
                }
            })

            // immediately issue the original value with no previous value
            receiver(Mutation<Element>(old: Optional<Element>.none, new: get()))
            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                receivers.removeReceptor(index)
                if receivers.count == 0 {
                    // all receivers removed: clear the observer
                    observation?.invalidate()
                    observation = nil
                }
            })
        }

        return Channel(source: self, reception: addReceiver)
    }

    public func get() -> T {
        return object[keyPath: self.keyPath]
    }
}

/// A receipt implementation; itentical to ReceiptOf, except it extends from NSObject, and so can be used with bindings
open class ReceiptObject: NSObject, Receipt {
    open var isCancelled: Bool { return cancelCounter.get() > 0 }
    fileprivate let cancelCounter: Counter = 0
    
    let canceler: () -> ()
    
    public init(canceler: @escaping () -> ()) {
        self.canceler = canceler
    }
    
    /// Creates a Receipt backed by one or more other Receipts
    public init(receipts: [Receipt]) {
        // no receipts means that it is cancelled already
        if receipts.count == 0 { cancelCounter.set(1) }
        self.canceler = { for s in receipts { s.cancel() } }
    }
    
    /// Creates a Receipt backed by another Receipt
    public convenience init(receipt: Receipt) {
        self.init(receipts: [receipt])
    }
    
    /// Creates an empty cancelled Receipt
    public convenience override init() {
        self.init(receipts: [])
    }
    
    /// Disconnects this receipt from the source observable
    open func cancel() {
        // only cancel the first time
        if cancelCounter.increment() == 1 {
            canceler()
        }
    }
}

/// Optional protocol for target objects to implement when they need to supplement key-value observing with additional events
@objc public protocol KeyValueChannelSupplementing {
    /// Add additional observers for the specified keyPath, returning the unsubscriber for any supplements
    func supplementKeyValueChannel(_ forKeyPath: String, subscription: (AnyObject?) -> ()) -> ReceiptObject?
}


#if DEBUG_CHANNELZ
    /// Track how many observers we have created and released; useful for ensuring that subscriptions are correctly cleaned up
    public let ChannelZKeyValueObserverCount: Counter = 0
#endif



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
    public func channelZNotification(_ name: NSNotification.Name, center: NotificationCenter = NotificationCenter.default) -> Channel<NotificationCenter, UserInfo> {
        let receivers = ReceiverQueue<UserInfo>()
        return Channel(source: center) { [weak self] (receiver: @escaping (UserInfo) -> Void) -> Receipt in
            var rindex: Int64
            var observer: NSObjectProtocol
            
            if let target = self {
                rindex = receivers.addReceiver(receiver) // first add the observer so we get the initial notification
                observer = center.addObserver(forName: name, object: target, queue: nil) { (note) in
                    receivers.receive(note.userInfo ?? [:])
                }
            } else {
                preconditionFailure("cannot add receiver for deallocated instance (channels do not retain their targets)")
            }

            return ReceiptOf(canceler: { [weak self] in
                if let target = self {
                    center.removeObserver(observer, name: name, object: target)
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
    public typealias State = Mutation<T?>
    private let receivers = ReceiverQueue<State>()
    // map of KVO observers
    private var observers = Dictionary<ChannelControllerObserverKey, [Receipt]>()

    public let key: String
    public var value: T? {
        willSet {
            willChangeValue(forKey: key)
        }

        didSet(old) {
            didChangeValue(forKey: key)
            receivers.receive(Mutation(old: old, new: value))
        }
    }


    public init(value: T?, key: String = "value") {
        self.value = value
        self.key = key
    }

    public convenience init(rawValue: T) {
        self.init(value: rawValue)
    }

    public func receive(_ x: T?) { value = x }

    public func transceive() -> Channel<ChannelController<T>, State> {
        return Channel(source: self) { rcvr in
            // immediately issue the original value with no previous value
            rcvr(State(old: Optional<T>.none, new: self.value))
            return self.receivers.addReceipt(rcvr)
        }
    }

//    public func observe<Value>(_ keyPath: KeyPath<ChannelController<T>, Value>, options: NSKeyValueObservingOptions, changeHandler: @escaping (ChannelController<T>, NSKeyValueObservedChange<Value>) -> Void) -> NSKeyValueObservation {
//
//    }

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
            return self.value as? NSObject
        } else {
            return super.value(forKey: key)
        }
    }

    public override func value(forKeyPath keyPath: String) -> Any? {
        if keyPath == self.key {
            return self.value as? NSObject
        } else {
            return super.value(forKeyPath: keyPath)
        }
    }

    public override func setValue(_ value: Any?, forKey key: String) {
        if key == self.key {
            if let value = value as? T {
                self.value = value
            } else {
                self.value = nil
            }
        } else {
            super.setValue(value, forKey: key)
        }
    }

    public override func setValue(_ value: Any?, forKeyPath keyPath: String) {
        if keyPath == self.key {
            if let value = value as? T {
                self.value = value
            } else {
                self.value = nil
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

#endif


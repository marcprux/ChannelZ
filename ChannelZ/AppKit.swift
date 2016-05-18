//
//  Observables+AppKit.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// Support for AppKit UI channels
#if os(iOS)
import Foundation // workaround for compilation bug when compiling on iOS: «@objc attribute used without importing module 'Foundation'»
#endif

#if os(OSX)
import AppKit

public extension NSObjectProtocol where Self : NSController {
    /// Creates a channel for the given controller path, accounting for the `NSObjectController` limitation that
    /// change valus are not provided with KVO observation
    public func channelZControllerPath(keyPath: String) -> Channel<KeyValueOptionalTransceiver<AnyObject>, StatePulse<AnyObject?>> {
        let channel = channelZKeyState(valueForKeyPath(keyPath), keyPath: keyPath)

        // KVO on an object controller drops the value: 
        // “Important: The Cocoa bindings controller classes do not provide change values when sending key-value observing notifications to observers. It is the developer’s responsibility to query the controller to determine the new values.”
        // so we manually pull the latest value out of the object whenever we fire a change so we 
        // maintain the channel contract

        // first map it to placeholders for storing new state
        let wrapped = channel.map({ [weak self] state in
            StatePulse(old: state.old, new: self?.valueForKeyPath(keyPath))
            })

        // now save the old state and return new instances
        let saved = wrapped.precedent().new()
        return saved
    }
}


//public protocol ChannelController: class, NSObjectProtocol, StateEmitterType, StateReceiverType {
//    associatedtype ContentType
//    var value: ContentType { get set }
//}
//
//
/// An NSObject controller that is compatible with a StateEmitterType and StateReceiverType for storing and retrieving `NSObject` values from bindings
// FIXME: disabled because KVO is hopelessly broken on NSController subclasses
//extension NSObjectController : ChannelController {
//    public typealias ContentType = AnyObject? // it would be nice if this were generic, but @objc forbids it
//    public typealias State = StatePulse<ContentType>
//
//    public var value : ContentType {
//        get {
//            return self.content
//        }
//
//        set {
//            self.content = newValue
//        }
//    }
//
//    public func put(value: ContentType) {
//        self.content = value
//    }
//
//    public func transceive() -> Channel<NSObjectController, State> {
//        return channelZControllerPath("content") // "content" is the default key for controllers
//    }
//}

extension NSControl { // : KeyValueChannelSupplementing {

    public func channelZControl() -> Channel<ActionTarget, Void> {
        if self.target != nil && !(self.target is ActionTarget) {
            fatalError("controlz event handling overrides existing target/action for control; if this is really what you want to do, explicitly nil the target & action of the control")
        }

        let target = (self.target as? ActionTarget) ?? ActionTarget(control: self) // use the existing dispatch target if it exists
        self.target = target
        self.action = #selector(ActionTarget.channelEvent)


        return Channel<ActionTarget, Void>(source: target, reception: { target.receivers.addReceipt($0) })
    }

    /// Creates a binding to an intermediate NSObjectController with the given options and returns the bound channel
    public func channelZBinding<T>(value: T?, binding: String = NSValueBinding, controller: ChannelController<T>? = nil, keyPath: String = "content", options: [String : AnyObject] = [:]) -> ChannelController<T> {
        var options = options
        if let nullValue = value as? NSObject {
            options[NSNullPlaceholderBindingOption] = options[NSNullPlaceholderBindingOption] ?? nullValue
        }
        let controller = controller ?? ChannelController(value: value, key: keyPath)
        bind(binding, toObject: controller, withKeyPath: controller.key, options: options)
        return controller
    }

    public func supplementKeyValueChannel(forKeyPath: String, receiver: (AnyObject?) -> ()) -> (() -> ())? {
        // NSControl action events do not trigger KVO notifications, so we manually supplement any subscriptions with control events

        if forKeyPath == "doubleValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.doubleValue) })
            return { receipt.cancel() }
        }

        if forKeyPath == "floatValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.floatValue) })
            return { receipt.cancel() }
        }

        if forKeyPath == "integerValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.integerValue) })
            return { receipt.cancel() }
        }

        if forKeyPath == "stringValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.stringValue) })
            return { receipt.cancel() }
        }

        if forKeyPath == "attributedStringValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.attributedStringValue) })
            return { receipt.cancel() }
        }

        if forKeyPath == "objectValue" {
            let receipt = self.channelZControl().receive({ [weak self] _ in receiver(self?.objectValue) })
            return { receipt.cancel() }
        }

        return nil
    }
}

extension NSMenuItem {

    public func channelZMenu() -> Channel<ActionTarget, Void> {

        if self.target != nil && !(self.target is ActionTarget) {
            fatalError("controlz event handling overrides existing target/action for menu item; if this is really what you want to do, explicitly nil the target & action of the control")
        }

        let target = (self.target as? ActionTarget) ?? ActionTarget(control: self) // use the existing dispatch target if it exists
        self.target = target
        self.action = #selector(ActionTarget.channelEvent)
        return Channel<ActionTarget, Void>(source: target, reception: { target.receivers.addReceipt($0) })
    }
}

/// An ActionTarget is an Objective-C compatible class that can be set as the target
/// object for a target/action pattern, such as with an NSControl or UIControl
@objc public class ActionTarget: NSObject {
    public let control: NSObject
    public let receivers = ReceiverQueue<Void>()
    public init(control: NSObject) { self.control = control }
    public func channelEvent() { receivers.receive(Void()) }
}

#endif

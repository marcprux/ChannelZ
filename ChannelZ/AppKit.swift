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

public protocol ChannelController: class, NSObjectProtocol, StateSource, StateSink {
    associatedtype ContentType
    var value: ContentType { get set }
}

/// An NSObject controller that is compatible with a StateSource and StateSink for storing and retrieving `NSObject` values from bindings
extension NSObjectController : ChannelController {
    public typealias ContentType = AnyObject? // it would be nice if this were generic, but @objc forbids it
    public typealias State = (old: ContentType?, new: ContentType)

    public var value : ContentType {
        get {
            return self.content
        }

        set {
            self.content = newValue
        }
    }

    public func put(value: ContentType) {
        self.content = value
    }

    public func channelZState()->Channel<NSObjectController, State> {
        return channelZControllerPath("content") // "content" is the default key for controllers
    }

    /// Creates a channel for the given controller path, accounting for the `NSObjectController` limitation that
    /// change valus are not provided with KVO observation
    public func channelZControllerPath(keyPath: String)->Channel<NSObjectController, State> {
        let kvt: KeyValueTarget<ContentType> = KeyValueTarget(target: self, initialValue: nil, keyPath: keyPath)
        let channel = KeyValueOptionalSource(target: kvt).channelZState()
        // KVO on an object controlled drops the value: “Important: The Cocoa bindings controller classes do not provide change values when sending key-value observing notifications to observers. It is the developer’s responsibility to query the controller to determine the new values.”
        let resourced = channel.resource({ [unowned self] _ in self })
        let mapped = resourced.map({ [weak self] _ in self?.valueForKeyPath(keyPath) })
        let withState = mapped.precedent()
        return withState
    }

}

extension NSControl { // : KeyValueChannelSupplementing {

    public func channelZControl()->Channel<ActionTarget, Void> {
        if self.target != nil && !(self.target is ActionTarget) {
            fatalError("controlz event handling overrides existing target/action for control; if this is really what you want to do, explicitly nil the target & action of the control")
        }

        let target = (self.target as? ActionTarget) ?? ActionTarget(control: self) // use the existing dispatch target if it exists
        self.target = target
        self.action = #selector(ActionTarget.channelEvent)


        return Channel<ActionTarget, Void>(source: target, reception: target.receivers.addReceipt)
    }

    /// Creates a binding to an intermediate NSObjectController with the given options and returns the bound channel
    public func channelZBinding(binding: String = NSValueBinding, controller: NSObjectController = NSObjectController(content: nil), options: [String : AnyObject] = [:]) -> Channel<NSObjectController, NSObjectController.State> {
        bind(binding, toObject: controller, withKeyPath: "content", options: options)
        return controller.channelZState()
    }

    public func supplementKeyValueChannel(forKeyPath: String, receiver: (AnyObject?)->()) -> (()->())? {
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

    public func channelZMenu()->Channel<ActionTarget, Void> {

        if self.target != nil && !(self.target is ActionTarget) {
            fatalError("controlz event handling overrides existing target/action for menu item; if this is really what you want to do, explicitly nil the target & action of the control")
        }

        let target = (self.target as? ActionTarget) ?? ActionTarget(control: self) // use the existing dispatch target if it exists
        self.target = target
        self.action = #selector(ActionTarget.channelEvent)
        return Channel<ActionTarget, Void>(source: target, reception: target.receivers.addReceipt)
    }
}

/// An ActionTarget is an Objective-C compatible class that can be set as the target
/// object for a target/action pattern, such as with an NSControl or UIControl
@objc public class ActionTarget: NSObject {
    public let control: NSObject
    public let receivers = ReceiverList<Void>()
    public init(control: NSObject) { self.control = control }
    public func channelEvent() { receivers.receive(Void()) }
}

#endif

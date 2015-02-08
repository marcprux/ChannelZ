////
////  Channels+UIKit.swift
////  ChannelZ
////
////  Created by Marc Prud'hommeaux <marc@glimpse.io>
////  License: MIT (or whatever)
////
//
///// Support for UIKit UI channels
//#if os(iOS)
//import UIKit
//
//public extension UIControl {
//    /// Creates a observable for various control event such as button pressed or editing changes
//    public func channelZControl(_ events: UIControlEvents = .AllEvents)-> UIEventChannel {
//        return UIEventChannel(control: self, events: events)
//    }
//}
//
//extension UISlider : KeyValueChannelSupplementing {
//    public func supplementKeyValueChannel(forKeyPath: String, subscription: (AnyObject?)->()) -> (()->())? {
//        if forKeyPath == "value" {
//            // since the slider's "value" field is not completely KVO-compliant, supplement the channel with the value changed contol event
//            let subscription = self.channelZControl(.ValueChanged).subscribe({ [weak self] _ in subscription(self?.value) })
//            return { subscription.unsubscribe() }
//        }
//
//        return nil
//    }
//}
//
//extension UITextField : KeyValueChannelSupplementing {
//    public func supplementKeyValueChannel(forKeyPath: String, subscription: (AnyObject?)->()) -> (()->())? {
//        if forKeyPath == "text" {
//            // since the field's "text" field is not completely KVO-compliant, supplement the channel with the editing changed contol event
//            let subscription = self.channelZControl(.EditingChanged).subscribe({ [weak self] _ in subscription(self?.text) })
//            return { subscription.unsubscribe() }
//        }
//
//        return nil
//    }
//}
//
//@objc public class EventTarget : NSObject {
//    public init(f:(event: UIEvent)->()) { self.action = f }
//    public func execute(event: UIEvent) -> () { action(event) }
//    public let action: (UIEvent) -> ()
//}
//
///// A Channel for UIEvent events
//public struct UIEventChannel: ChannelType {
//    private let control: UIControl
//    private let events: UIControlEvents
//
//    public typealias Element = UIEvent
//
//    private init(control: UIControl, events: UIControlEvents) {
//        self.control = control
//        self.events = events
//    }
//
//    public func subscribe(subscription: (UIEvent)->())->Receptor {
//        let sub = UIEventReceptor(control: control, events: events, handler: { subscription($0) })
//        return ReceptorOf(source: self, subscription: sub)
//    }
//
//    // Boilerplate observable/filter/map
//    public typealias SelfChannel = UIEventChannel
//    public func observable() -> Channel<Element> { return Channel(self) }
//    public func filter(predicate: (Element)->Bool)->FilteredChannel<SelfChannel> { return filterChannel(self)(predicate) }
//    public func map<TransformedType>(transform: (Element)->TransformedType)->MappedChannel<SelfChannel, TransformedType> { return mapChannel(self)(transform) }
//
//}
//
//@objc public class UIEventReceptor: NSObject, Receptor {
//    let control: UIControl
//    let events: UIControlEvents
//    var handler: (UIEvent)->(Void)
//    var ctx = UnsafeMutablePointer<Void>()
//    var subscribed: Bool = false
//
//    init(control: UIControl, events: UIControlEvents, handler: (UIEvent)->(Void)) {
//        self.control = control
//        self.events = events
//        self.handler = handler
//
//        super.init()
//
//        control.addTarget(self, action: Selector("handleControlEvent:"), forControlEvents: events)
//        objc_setAssociatedObject(control, &ctx, self, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
//        self.subscribed = true
//
//    }
//
//    deinit {
//        unsubscribe()
//    }
//
//    public func unsubscribe() {
//        if self.subscribed {
//            control.removeTarget(self, action: Selector("handleControlEvent:"), forControlEvents: events)
//            objc_setAssociatedObject(control, &ctx, nil, objc_AssociationPolicy(OBJC_ASSOCIATION_ASSIGN))
//            self.subscribed = false
//        }
//    }
//
//    public func request() {
//        // no-op, since events are push
//    }
//
//    public func handleControlEvent(event: UIEvent) {
//        handler(event)
//    }
//
//}
//
//#endif

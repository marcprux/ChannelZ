//
//  Funnels+UIKit.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// Support for UIKit UI channels
#if os(iOS)
    import UIKit

    public extension UIControl {
        /// Creates a funnel for various control event such as button pressed or editing changes
        public func controlz(_ events: UIControlEvents = .AllEvents) -> UIEventFunnel {
            return UIEventFunnel(control: self, events: events)
        }
    }

    extension UISlider : KeyValueChannelSupplementing {
        public func supplementKeyValueChannel(forKeyPath: String, outlet: (AnyObject?)->()) -> (()->())? {
            if forKeyPath == "value" {
                // since the slider's "value" field is not completely KVO-compliant, supplement the channel with the value changed contol event
                let outlet = self.controlz(.ValueChanged).attach({ [weak self] _ in outlet(self?.value) })
                return { outlet.detach() }
            }

            return nil
        }
    }

    extension UITextField : KeyValueChannelSupplementing {
        public func supplementKeyValueChannel(forKeyPath: String, outlet: (AnyObject?)->()) -> (()->())? {
            if forKeyPath == "text" {
                // since the field's "text" field is not completely KVO-compliant, supplement the channel with the editing changed contol event
                let outlet = self.controlz(.EditingChanged).attach({ [weak self] _ in outlet(self?.text) })
                return { outlet.detach() }
            }

            return nil
        }
    }

    @objc public class EventTarget : NSObject {
        public init(f:(event: UIEvent)->()) { self.action = f }
        public func execute(event: UIEvent) -> () { action(event) }
        public let action: (UIEvent) -> ()
    }

    /// A Funnel for UIEvent events
    public struct UIEventFunnel: FunnelType {
        private let control: UIControl
        private let events: UIControlEvents

        public typealias OutputType = UIEvent

        private init(control: UIControl, events: UIControlEvents) {
            self.control = control
            self.events = events
        }

        public func attach(outlet: (UIEvent)->())->Outlet {
            return UIEventObserver(control: control, events: events, handler: { outlet($0) })
        }

        // Boilerplate funnel/filter/map
        public typealias SelfFunnel = UIEventFunnel
        public var funnelOf: FunnelOf<OutputType> { return FunnelOf(self) }
        public func filter(predicate: (OutputType)->Bool)->FilteredFunnel<SelfFunnel> { return filterFunnel(self)(predicate) }
        public func map<TransformedType>(transform: (OutputType)->TransformedType)->MappedFunnel<SelfFunnel, TransformedType> { return mapFunnel(self)(transform) }

    }

    @objc public class UIEventObserver: NSObject, Outlet {
        let control: UIControl
        let events: UIControlEvents
        var handler: (UIEvent)->(Void)
        var ctx = UnsafeMutablePointer<Void>()
        var attached: Bool = false

        init(control: UIControl, events: UIControlEvents, handler: (UIEvent)->(Void)) {
            self.control = control
            self.events = events
            self.handler = handler

            super.init()

            control.addTarget(self, action: Selector("handleControlEvent:"), forControlEvents: events)
            objc_setAssociatedObject(control, &ctx, self, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
            self.attached = true

        }

        deinit {
            detach()
        }

        public func detach() {
            if self.attached {
                control.removeTarget(self, action: Selector("handleControlEvent:"), forControlEvents: events)
                objc_setAssociatedObject(control, &ctx, nil, objc_AssociationPolicy(OBJC_ASSOCIATION_ASSIGN))
                self.attached = false
            }
        }

        public func handleControlEvent(event: UIEvent) {
            handler(event)
        }

    }

#endif

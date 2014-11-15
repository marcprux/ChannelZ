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

    public extension UIView {
        public var hiddenZ: ChannelZ<Bool> { return self.sieve(hidden, keyPath: "hidden") }
        public var opaqueZ: ChannelZ<Bool> { return self.sieve(opaque, keyPath: "opaque") }
        public var alphaZ: ChannelZ<CGFloat> { return self.sieve(alpha, keyPath: "alpha") }
        public var tintColorZ: ChannelZ<UIColor> { return self.sieve(tintColor, keyPath: "tintColor") }
    }

    public extension UIControl {
        public var enabledZ: ChannelZ<Bool> { return self.sieve(enabled, keyPath: "enabled") }

        public func funnelControlEvents(events: UIControlEvents = .AllEvents) -> UIEventFunnel {
            return UIEventFunnel(control: self, events: events)
        }
    }

    public extension UISlider {
        public var valueZ: ChannelZ<Float> { return self.sieve(value, keyPath: "value") }
        public var maximumValueZ: ChannelZ<Float> { return self.sieve(maximumValue, keyPath: "maximumValue") }
        public var minimumValueZ: ChannelZ<Float> { return self.sieve(minimumValue, keyPath: "minimumValue") }
    }


    public extension UITextField {
        public var textZ: ChannelZ<String> { return self.sieve(text, keyPath: "text") }
        public var fontZ: ChannelZ<UIFont> { return self.sieve(font, keyPath: "font") }
        public var textColorZ: ChannelZ<UIColor> { return self.sieve(textColor, keyPath: "textColor") }
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
            self.attached = true

        }

        deinit {
            detach()
        }

        public func detach() {
            control.removeTarget(self, action: Selector("handleControlEvent:"), forControlEvents: events)
            self.attached = false
        }

        public func handleControlEvent(event: UIEvent) {
            handler(event)
        }

    }

#endif

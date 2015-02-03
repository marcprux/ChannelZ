//
//  Observables+AppKit.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

/// Support for AppKit UI channels
#if os(OSX)
    import AppKit

    extension NSControl : KeyValueChannelSupplementing {

        public func controlz() -> EventObservable<NSEvent> {

            if self.target != nil && !(self.target is DispatchTarget) {
                fatalError("controlz event handling overrides existing target/action for control; if this is really what you want to do, explicitly nil the target & action of the control")
            }

            let observer = self.target as? DispatchTarget ?? DispatchTarget() // use the existing dispatch target if it exists
            self.target = observer
            self.action = Selector("execute")

            var observable = EventObservable<NSEvent>(nil)
            observable.dispatchTarget = observer // someone needs to retain the dispatch target; NSControl only holds a weak ref
            observer.actions += [{ observable.subscriptions.receive($0) }]

            return observable
        }

        public func supplementKeyValueChannel(forKeyPath: String, subscription: (AnyObject?)->()) -> (()->())? {
            // NSControl action events do not trigger KVO notifications, so we manually supplement any subscriptions with control events

            if forKeyPath == "doubleValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.doubleValue) })
                return { subscription.unsubscribe() }
            }

            if forKeyPath == "floatValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.floatValue) })
                return { subscription.unsubscribe() }
            }

            if forKeyPath == "integerValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.integerValue) })
                return { subscription.unsubscribe() }
            }

            if forKeyPath == "stringValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.stringValue) })
                return { subscription.unsubscribe() }
            }

            if forKeyPath == "attributedStringValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.attributedStringValue) })
                return { subscription.unsubscribe() }
            }

            if forKeyPath == "objectValue" {
                let subscription = self.controlz().subscribe({ [weak self] _ in subscription(self?.objectValue) })
                return { subscription.unsubscribe() }
            }

            return nil
        }

    }

    extension NSMenuItem {

        public func controlz() -> EventObservable<NSEvent> {

            if self.target != nil && !(self.target is DispatchTarget) {
                fatalError("controlz event handling overrides existing target/action for menu item; if this is really what you want to do, explicitly nil the target & action of the control")
            }

            let observer = self.target as? DispatchTarget ?? DispatchTarget() // use the existing dispatch target if it exists
            self.target = observer
            self.action = Selector("execute")

            var observable = EventObservable<NSEvent>(nil)
            observable.dispatchTarget = observer // someone needs to retain the dispatch target; NSControl only holds a weak ref
            observer.actions += [{ observable.subscriptions.receive($0) }]
            
            return observable
        }
    }

    @objc public class DispatchTarget : NSObject {
        public var actions : [(NSEvent)->(Void)] = []

        public func execute() {
            let event = NSApplication.sharedApplication().currentEvent ?? NSEvent()
            for action in actions {
                action(event)
            }
        }
    }


#endif

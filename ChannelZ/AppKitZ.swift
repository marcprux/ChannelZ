//
//  Funnels+AppKit.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

/// Support for AppKit UI channels
#if os(OSX)
    import AppKit

    /// ChannelZ extensions for NSView with convenience channels for commonly-altered keys
    public extension NSView {
        public var hiddenZ: ChannelZ<Bool> { return self.sieve(hidden, keyPath: "hidden") }
    }

    /// ChannelZ extensions for NSControl with convenience channels for commonly-altered keys
    public extension NSControl {

        public func funnelCommand() -> EventFunnel<Void> {
            // FIXME: we currently only support a single action for a control, and calling this method multiple times will clobber the last action; if the control already has an action, we need to make it into an action list that we can modify
            var funnel = EventFunnel<Void>(nil)
            let observer = DispatchTarget({ funnel.outlets.receive() })
            funnel.dispatchTarget = observer // someone needs to retain the dispatch target; NSControl only holds a weak ref
            self.target = observer
            self.action = Selector("execute")
            return funnel
        }

    }

    @objc public class DispatchTarget : NSObject {
        public init(f:()->()) { self.action = f }
        public func execute() -> () { action() }
        public let action: () -> ()
    }


#endif

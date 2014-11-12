//
//  Funnels+AppKit.swift
//  SwiftFlow
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

#if os(OSX)
    import AppKit

    public extension NSControl {

        public var enabledChannel: ChannelOf<Bool, Bool> {
            return self.sieve(enabled, keyPath: "enabled").channelOf
        }

        public var stringValueChannel: ChannelOf<String, String> {
            return self.sieve(stringValue, keyPath: "stringValue").channelOf
        }

        public func funnelCommand() -> EventFunnel<Void> {
            // TODO: if the control already has an action, make it into an action list that we can add/remove to
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

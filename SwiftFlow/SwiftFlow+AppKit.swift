//
//  Funnels+AppKit.swift
//  SwiftFlow
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

#if os(OSX)
    import AppKit

    // FIXME: static reference since targets are not retained
    public var observers : [ClosureDispatch] = []

    public extension NSControl {

        public var enabledChannel: ChannelOf<Bool, Bool> {
            return self.sieve(enabled, keyPath: "enabled").channelOf
        }

        public var stringValueChannel: ChannelOf<String, String> {
            return self.sieve(stringValue, keyPath: "stringValue").channelOf
        }

        public func funnelCommand() -> EventFunnel<Void> {
            let funnel = EventFunnel<Void>()
            let observer = ClosureDispatch({ funnel.outlets.receive() })
            self.target = observer
            self.action = Selector("execute")

            // FIXME: static reference since targets are not retained
            observers += [observer]
            return funnel

            fatalError("FIXME: remove the need to reference observers")
        }

    }


    @objc public class ClosureDispatch : NSObject {
        public init(f:()->()) { self.action = f }
        public func execute() -> () { action() }
        public let action: () -> ()

        deinit {

        }
    }


#endif

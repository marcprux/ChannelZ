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
        public var enabledZ: ChannelZ<Bool> { return self.sieve(enabled, keyPath: "enabled") }
        public var doubleValueZ: ChannelZ<Double> { return self.sieve(doubleValue, keyPath: "doubleValue") }
        public var floatValueZ: ChannelZ<Float> { return self.sieve(floatValue, keyPath: "floatValue") }
        public var intValueZ: ChannelZ<Int32> { return self.sieve(intValue, keyPath: "intValue") }
        public var integerValueZ: ChannelZ<NSInteger> { return self.sieve(integerValue, keyPath: "integerValue") }
        public var objectValueZ: ChannelZ<NSObject?> { return self.sieve(objectValue as NSObject?, keyPath: "objectValue") }
        public var stringValueZ: ChannelZ<NSString> { return self.sieve(stringValue, keyPath: "stringValue") }
        public var attributedStringValueZ: ChannelZ<NSAttributedString> { return self.sieve(attributedStringValue, keyPath: "attributedStringValue") }

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

    /// ChannelZ extensions for NSTextField with convenience channels for commonly-altered keys
    public extension NSTextField {
        public var editableZ: ChannelZ<Bool> { return self.sieve(editable, keyPath: "editable") }
        public var selectableZ: ChannelZ<Bool> { return self.sieve(selectable, keyPath: "selectable") }
        public var placeholderStringZ: ChannelZ<String?> { return self.sieve(placeholderString, keyPath: "placeholderString") }
        public var placeholderAttributedStringZ: ChannelZ<NSAttributedString?> { return self.sieve(placeholderAttributedString, keyPath: "placeholderAttributedString") }
        public var textColorZ: ChannelZ<NSColor?> { return self.sieve(textColor, keyPath: "textColor") }
        public var backgroundColorZ: ChannelZ<NSColor?> { return self.sieve(backgroundColor, keyPath: "backgroundColor") }
    }

    /// ChannelZ extensions for NSSlider with convenience channels for commonly-altered keys
    public extension NSSlider {
        /// valueZ is the same as floatValueZ in order to keep it in sync with UISlider
        public var valueZ: ChannelZ<Float> { return self.floatValueZ }
    }

    /// Extension for funneling tree selection notifications
    extension NSOutlineView {
        /// Funnels notifications of change in the selection
        public var selectionChangedZ: FunnelOf<Void> {
            return self.funnel(NSOutlineViewSelectionDidChangeNotification).map({ _ in }).funnelOf
        }
    }


    @objc public class DispatchTarget : NSObject {
        public init(f:()->()) { self.action = f }
        public func execute() -> () { action() }
        public let action: () -> ()
    }


#endif

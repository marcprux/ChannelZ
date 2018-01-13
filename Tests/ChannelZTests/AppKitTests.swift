//
//  AppKitTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/8/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

#if os(macOS)
import XCTest
import ChannelZ
import CoreData
import ObjectiveC
import WebKit
import AppKit

/// We seem to need to keep around a global window in order to testing AppKit controls to not cause random crashes
private let window: NSWindow = NSWindow()
private let contentView: NSView = window.contentView!

class AppKitTests : ChannelTestCase {

    func decrement(_ x: inout Int) -> Int {
        x -= 1
        return x
    }

    func testCocoaBindings() {
        let objc = NSObjectController(content: NSNumber(value: 1 as Int))
        XCTAssertEqual(1, (objc.content as? NSNumber) ?? -999)

        let state1 = StatefulObject()
        state1.num3 = 0

        XCTAssertEqual(0, state1.num3)
        objc.bind(NSBindingName(rawValue: "content"), to: state1, withKeyPath: "num3", options: nil)
        XCTAssertEqual(0, state1.num3)

        objc.content = 2
        XCTAssertEqual(2, (objc.content as? NSNumber) ?? -999)

        state1.num3 = 3
        XCTAssertEqual(3, (objc.content as? NSNumber) ?? -999)
        XCTAssertEqual(3, state1.num3)


        let state2 = StatefulObject()
        state2.num3 = 0
        state2.bind(NSBindingName(rawValue: "num3"), to: state1, withKeyPath: "num3", options: nil)

        let channel2: KeyValueChannel<StatefulObject, NSNumber> = state2∞(\.num3, "num3")
        let _ = channel2 ∞> { num in
            // println("changing number to: \(num)")
        }
        state1.num3 = 4

        XCTAssertEqual(4, (objc.content as? NSNumber) ?? -999)
        XCTAssertEqual(4, state1.num3)
        XCTAssertEqual(4, state2.num3)

        // need to manually unbind in order to release memory
        objc.unbind(NSBindingName(rawValue: "content"))
        state2.unbind(NSBindingName(rawValue: "num3"))
    }


    func testFoundationExtensions() {
        var counter = 0

        let constraint = NSLayoutConstraint()
        constraint∞\.constant ∞> { _ in counter += 1 }
        constraint∞\.isActive ∞> { _ in counter += 1 }
        counter -= 2

        let undo = UndoManager()
        undo.channelZNotification(NSNotification.Name.NSUndoManagerDidUndoChange) ∞> { _ in counter += 1 }
        undo∞\.canUndo ∞> { _ in counter += 1 }
        undo∞\.canRedo ∞> { _ in counter += 1 }
        undo∞\.levelsOfUndo ∞> { _ in counter += 1 }
        undo∞\.undoActionName ∞> { _ in counter += 1 }
        undo∞\.redoActionName ∞> { _ in counter += 1 }
        counter -= 5
        XCTAssertEqual(0, counter)

        let df = DateFormatter()
        df∞\.dateFormat ∞> { _ in counter += 1 }
        df∞\.locale ∞> { _ in counter += 1 }
        df∞\.timeZone ∞> { _ in counter += 1 }
        df∞\.eraSymbols ∞> { _ in counter += 1 }
        counter -= 4
        XCTAssertEqual(0, counter)

        // NSDateComponents is now a struct
//        var comps = DateComponents()
//        comps∞comps.date ∞> { _ in counter += 1 }
//        comps∞comps.era ∞> { _ in counter += 1 }
//        comps∞comps.year ∞> { _ in counter += 1 }
//        comps∞comps.month ∞> { _ in counter += 1 }
//        comps.year = 2016
//        counter -= 4

        XCTAssertEqual(0, counter)

        let prog = Progress(totalUnitCount: 100)
        prog∞\.totalUnitCount ∞> { _ in counter += 1 }
        prog.totalUnitCount = 200
        counter -= 1
        XCTAssertEqual(0, counter)

        prog∞\.fractionCompleted ∞> { _ in counter += 1 }
        prog.completedUnitCount += 1
        counter -= 1
        XCTAssertEqual(0, counter)
    }
    

    func XXXtestButtonCommand() {
        let button = NSButton()

        // FIXME: button never gets clicked
        
        contentView.addSubview(button) // seems to be needed or else the button won't get clicked
        defer { button.removeFromSuperview() }

        var stateChanges = 0

        button∞\.state ∞> { x in
            stateChanges += 1
//            println("state change: \(x)")
        }

        XCTAssertEqual(stateChanges, 1)

        button.state = NSControl.StateValue.on
        button.state = NSControl.StateValue.off
        button.state = NSControl.StateValue.on
        button.state = NSControl.StateValue.off
        XCTAssertEqual(stateChanges, 5)

        var clicks = 0 // track the number of clicks on the button

        XCTAssertEqual(clicks, 0)

        let cmd = button.channelZControl()
        let subscription = cmd.receive({ _ in
            clicks += 1
        })

        assertRemains(decrement(&clicks), button.performClick(self))
        assertRemains(decrement(&clicks), button.performClick(self))

        subscription.cancel()

        assertRemains(clicks, button.performClick(self))
        assertRemains(clicks, button.performClick(self))
    }

    func testTextFieldProperties() {
        let textField = NSTextField()

        contentView.addSubview(textField) // seems to be needed or else the button won't get clicked
        defer { textField.removeFromSuperview() }

        var text = ""

        //        let textChannel = textField∞(textField.stringValue) // intermittent crashes
        let textChannel = textField.channelZKeyValue(\.stringValue)

        let textReceiver = textChannel.receive({ text = $0 })

        var enabled = true
        let enabledChannel = textField∞\.isEnabled
        let enabledReceiver = enabledChannel.receive({ enabled = $0 })

        textField.stringValue = "ABC"
        XCTAssertEqual("ABC", textField.stringValue)
        XCTAssertEqual("ABC", text)

        textChannel ∞= "XYZ"
        XCTAssertEqual("XYZ", textField.stringValue)
        XCTAssertEqual("XYZ", text)

        textField.isEnabled = false
        XCTAssertEqual(false, textField.isEnabled)
        XCTAssertEqual(false, enabled)

        textField.isEnabled = true
        XCTAssertEqual(true, enabled)

        textReceiver.cancel()

        textField.stringValue = "QRS"
        XCTAssertEqual("XYZ", text)

        enabledReceiver.cancel()

        textField.isEnabled = false
        XCTAssertEqual(true, enabled)
    }

    func testControls() {
        struct ViewModel {
            let amount = ∞(Double(0))∞
            let amountMax = Double(100.0)
        }

        let vm = ViewModel()

        let stepper = NSStepper()

        contentView.addSubview(stepper) // seems to be needed or else the button won't get clicked
        defer { stepper.removeFromSuperview() }

        stepper.maxValue = vm.amountMax
        stepper∞\.doubleValue <=∞=> vm.amount

        let slider = NSSlider()
        slider.maxValue = vm.amountMax
        slider∞\.doubleValue <=∞=> vm.amount

        stepper.doubleValue += 25.0
        XCTAssertEqual(slider.doubleValue, Double(25.0))
        XCTAssertEqual(vm.amount∞?, Double(25.0))

        slider.doubleValue += 30.0
        XCTAssertEqual(stepper.doubleValue, Double(55.0))
        XCTAssertEqual(vm.amount∞?, Double(55.0))


        let progbar = NSProgressIndicator()
        progbar.maxValue = 1.0

        // NSProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value
        vm.amount.map({ Double($0 / vm.amountMax) }) ∞=> (progbar∞\.doubleValue)

        vm.amount ∞= vm.amount∞? + 20.0

        XCTAssertEqual(slider.doubleValue, Double(75.0))
        XCTAssertEqual(stepper.doubleValue, Double(75.0))
        XCTAssertEqual(progbar.doubleValue, Double(0.75))

        let progress = Progress(totalUnitCount: Int64(vm.amountMax))
        vm.amount.map({ Int64($0) }) ∞=> (progress∞\.completedUnitCount)

        // FIXME: memory leak
        // progress∞progress.completedUnitCount ∞> { _ in println("progress: \(progress.localizedDescription)") }

//        let textField = NSTextField()

        // FIXME: crash
        // progress∞progress.localizedDescription ∞=> textField∞textField.stringValue
        
        vm.amount ∞= vm.amount∞? + 15.0

        withExtendedLifetime(slider) { }
        withExtendedLifetime(progress) { }
        withExtendedLifetime(progbar) { }
    }

    // FIXME: not working with new KeyPath syntax
//    func testControllers() {
//        var val: Any? = 0 as Any?
//        let content: NSMutableDictionary = ["x": 12]
//
//        let controller = NSObjectController(content: content)
//        controller.channelZControllerPath(\.content).receive({ val = ($0.new as? NSObject)?.value(forKey: "x") })
//        XCTAssertEqual(val as? NSNumber, NSNumber(value: 12 as Int))
//        content["x"] = 13
//        XCTAssertEqual(val as? NSNumber, NSNumber(value: 13 as Int))
//    }

    func testControllerBinding() {
//        let controller = NSObjectController(content: 0)
//        let channel = controller.channelZKeyState(controller.content)

        let controller = NumericHolderClass()
        let channel = controller.channelZKeyState(\.intField)

        var changes = (0, 0, 0)

        channel.receive { val in changes.0 += 1 }
        channel.receive { val in changes.1 += 1 }
        channel.receive { val in changes.2 += 1 }

        XCTAssertEqual(1, changes.0)
        XCTAssertEqual(1, changes.1)
        XCTAssertEqual(1, changes.2)

        controller.intField = 123

        XCTAssertEqual(2, changes.0)
        XCTAssertEqual(2, changes.1)
        XCTAssertEqual(2, changes.2)
    }

    func testChannelControllerBinding() {
        let stepper = NSStepper()

        contentView.addSubview(stepper) // seems to be needed or else the button won't get clicked
        defer { stepper.removeFromSuperview() }

        do { // bind to double
            let controller = stepper.channelZBinding(value: 0.0)

            controller.value = 3.2
            XCTAssertEqual(3.2, stepper.doubleValue, "stepper should mirror controller binding")

            stepper.performClick(nil) // decrement
            XCTAssertEqual(2.2, controller.value, "stepper decrement should be seen in controller")

            stepper.unbind(NSBindingName.value)

            stepper.performClick(nil) // decrement
            XCTAssertEqual(2.2, controller.value, "control should have been unbound")
        }

        do { // bind to int
            let controller = stepper.channelZBinding(value: 3)

            controller.value = 4
            XCTAssertEqual(4, stepper.integerValue, "stepper should mirror controller binding")

            stepper.performClick(nil) // decrement
            XCTAssertEqual(3, controller.value, "stepper decrement should be seem in controller")

            stepper.unbind(NSBindingName.value)

            stepper.performClick(nil) // decrement
            XCTAssertEqual(3, controller.value, "control should have been unbound")
        }

        do { // bind to int?
            let controller = stepper.channelZBinding(value: 44)

            stepper.maxValue = 88
            controller.value = 4
            XCTAssertEqual(4, stepper.integerValue, "stepper should mirror controller binding")

            controller.value = nil
            XCTAssertEqual(44, stepper.integerValue, "stepper should treat nil as NSNullPlaceholderBindingOption")

            controller.value = 99
            XCTAssertEqual(88, stepper.integerValue, "stepper should pin to max")
            XCTAssertEqual(99, controller.value, "controller should hold set value")

            stepper.performClick(nil) // decrement
            XCTAssertEqual(87, controller.value, "stepper decrement should be seem in controller")

            stepper.unbind(NSBindingName.value)

            stepper.performClick(nil) // decrement
            XCTAssertEqual(87, controller.value, "control should have been unbound")
        }

        do { // bind to string
            let textField = NSTextField()

            contentView.addSubview(textField)
            defer { textField.removeFromSuperview() }

            let controller = textField.channelZBinding(value: "ABC")
            let enabled = textField.channelZBinding(value: true, binding: NSBindingName.enabled)
            let hidden = textField.channelZBinding(value: false, binding: NSBindingName.hidden)

            controller.value = "XYZ"
            XCTAssertEqual("XYZ", textField.stringValue, "text field should mirror controller binding")
            XCTAssertEqual("XYZ" as NSObject, textField.objectValue as? NSObject, "text field should show null binding")
            XCTAssertEqual(nil, textField.placeholderString, "placeholder should not be set unless content is nil")

            controller.value = nil
            XCTAssertEqual(nil, textField.objectValue as? NSObject)
            XCTAssertEqual("", textField.stringValue)
            XCTAssertEqual("ABC", textField.placeholderString, "placeholder should be set when content is nil")

            XCTAssertEqual(true, textField.isEnabled)
            enabled.value = false
            XCTAssertEqual(false, textField.isEnabled)
            enabled.value = true
            XCTAssertEqual(true, textField.isEnabled)

            XCTAssertEqual(false, textField.isHidden)
            hidden.value = true
            XCTAssertEqual(true, textField.isHidden)
            hidden.value = false
            XCTAssertEqual(false, textField.isHidden)

            // now make it so enabled and hidden are bound to opposite valies, so that
            // when the control is disabled it is hidden and when the control is hidden it is disabled
//            enabled.transceiveChanges().map(!).bind(hidden.transceiveChanges().map(!))
            enabled.transceiveChanges().map({ $0.flatMap(!) }).bind(hidden.transceiveChanges().map({ $0.flatMap(!) }))

            enabled.value = false
            XCTAssertEqual(false, textField.isEnabled)
            XCTAssertEqual(true, textField.isHidden)

            enabled.value = true
            XCTAssertEqual(true, textField.isEnabled)
            XCTAssertEqual(false, textField.isHidden)

            hidden.value = true
            XCTAssertEqual(true, textField.isHidden)
            XCTAssertEqual(false, textField.isEnabled)

            hidden.value = false
            XCTAssertEqual(false, textField.isHidden)
            XCTAssertEqual(true, textField.isEnabled)


            // “If you change the value of an item in the user interface programmatically, for example sending an NSTextField a setStringValue: message, the model is not updated with the new value.”
            // “This is the expected behavior. Instead you should change the model object using a key-value-observing compliant manner.”

//            textField.stringValue = "ABC"
//            XCTAssertEqual("ABC", controller.$, "text field should be seem in controller")


//            stepper.unbind(NSValueBinding)
//
//            textField.stringValue = "000"
//            XCTAssertEqual("ABC", controller.$, "text field should have been unbound")
        }

    }

    override func tearDown() {
        super.tearDown()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_CHANNELZ
            XCTAssertEqual(0, ChannelZTests.StatefulObjectCount, "all StatefulObject instances should have been deallocated")
            ChannelZTests.StatefulObjectCount = 0

            XCTAssertEqual(0, ChannelZ.ChannelZKeyValueObserverCount.get(), "KV observers were not cleaned up")
            ChannelZ.ChannelZKeyValueObserverCount.set(0)

            XCTAssertEqual(0, ChannelZ.ChannelZReentrantReceptions.get(), "reentrant receptions detected")
            ChannelZ.ChannelZReentrantReceptions.set(0)

            // XCTAssertEqual(0, ChannelZ.ChannelZNotificationObserverCount, "Notification observers were not cleaned up")
            // ChannelZ.ChannelZNotificationObserverCount = 0

        #else
            XCTFail("Why are you running tests with debugging off?")
        #endif
    }


}
#endif


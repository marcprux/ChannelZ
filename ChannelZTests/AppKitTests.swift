//
//  AppKitTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/8/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

#if os(OSX)
import XCTest
import ChannelZ
import CoreData
import ObjectiveC
import WebKit
import AppKit

public class AppKitTests: XCTestCase {

    public func testCocoaBindings() {
        let objc = NSObjectController(content: NSNumber(integer: 1))
        XCTAssertEqual(1, objc.content as? NSNumber ?? -999)

        let state1 = StatefulObject()
        state1.num3 = 0

        XCTAssertEqual(0, state1.num3)
        objc.bind("content", toObject: state1, withKeyPath: "num3", options: nil)
        XCTAssertEqual(0, state1.num3)

        objc.content = 2
        XCTAssertEqual(2, objc.content as? NSNumber ?? -999)

        state1.num3 = 3
        XCTAssertEqual(3, objc.content as? NSNumber ?? -999)
        XCTAssertEqual(3, state1.num3)


        let state2 = StatefulObject()
        state2.num3 = 0
        state2.bind("num3", toObject: state1, withKeyPath: "num3", options: nil)

        let state2sieve = state2∞(state2.num3, "num3") ∞> { num in
            // println("changing number to: \(num)")
        }
        state1.num3 = 4

        XCTAssertEqual(4, objc.content as? NSNumber ?? -999)
        XCTAssertEqual(4, state1.num3)
        XCTAssertEqual(4, state2.num3)

        // need to manually unbind in order to release memory
        objc.unbind("content")
        state2.unbind("num3")
    }


    public func testFoundationExtensions() {
        var counter = 0

        let constraint = NSLayoutConstraint()
        constraint∞constraint.constant ∞> { _ in counter += 1 }
        constraint∞constraint.active ∞> { _ in counter += 1 }

        let undo = NSUndoManager()
        undo.channelZNotification(NSUndoManagerDidUndoChangeNotification) ∞> { _ in counter += 1 }
        undo∞undo.canUndo ∞> { _ in counter += 1 }
        undo∞undo.canRedo ∞> { _ in counter += 1 }
        undo∞undo.levelsOfUndo ∞> { _ in counter += 1 }
        undo∞undo.undoActionName ∞> { _ in counter += 1 }
        undo∞undo.redoActionName ∞> { _ in counter += 1 }


        let df = NSDateFormatter()
        df∞df.dateFormat ∞> { _ in counter += 1 }
        df∞df.locale ∞> { _ in counter += 1 }
        df∞df.timeZone ∞> { _ in counter += 1 }
        df∞df.eraSymbols ∞> { _ in counter += 1 }

        let comps = NSDateComponents()
        comps∞comps.date ∞> { _ in counter += 1 }
        comps∞comps.era ∞> { _ in counter += 1 }
        comps∞comps.year ∞> { _ in counter += 1 }
        comps∞comps.month ∞> { _ in counter += 1 }
        counter -= 4
        comps.year = 2016
        XCTAssertEqual(0, --counter)

        let prog = NSProgress(totalUnitCount: 100)
        prog∞prog.totalUnitCount ∞> { _ in counter += 1 }
        prog.totalUnitCount = 200
        XCTAssertEqual(0, --counter)

        prog∞prog.fractionCompleted ∞> { _ in counter += 1 }
        prog.completedUnitCount++
        XCTAssertEqual(0, --counter)
    }
    

    
//    func testButtonCommand() {
//        let button = NSButton()
//
//        /// seems to be needed or else the button won't get clicked
//        (NSWindow().contentView as NSView).addSubview(button)
//
//        var stateChanges = 0
//
//        button∞button.state ∞> { x in
//            stateChanges += 1
////            println("state change: \(x)")
//        }
//
//        button.state = NSOnState
//        button.state = NSOffState
//        button.state = NSOnState
//        button.state = NSOffState
//        XCTAssertEqual(stateChanges, 4)
//
//        var clicks = 0 // track the number of clicks on the button
//
//        XCTAssertEqual(clicks, 0)
//
//        let cmd = button.controlz()
//        var subscription = cmd.receive({ _ in clicks += 1 })
//
//        assertRemains(--clicks, button.performClick(self))
//        assertRemains(--clicks, button.performClick(self))
//
//        subscription.cancel()
//
//        assertRemains(clicks, button.performClick(self))
//        assertRemains(clicks, button.performClick(self))
//
//
//    }
//
//    func testTextFieldProperties() {
//        let textField = NSTextField()
//
//        /// seems to be needed or else the button won't get clicked
//        (NSWindow().contentView as NSView).addSubview(textField)
//
//        var text = ""
//
//        let textChannel = textField∞(textField.stringValue)
//        var textReceiver = textChannel.receive({ text = $0 })
//
//        var enabled = true
//        let enabledChannel = textField∞(textField.enabled)
//        var enabledReceiver = enabledChannel.receive({ enabled = $0 })
//
//        textField.stringValue = "ABC"
//        XCTAssertEqual("ABC", textField.stringValue)
//        XCTAssertEqual("ABC", text)
//
//        textChannel ∞= "XYZ"
//        XCTAssertEqual("XYZ", textField.stringValue)
//        XCTAssertEqual("XYZ", text)
//
//        textField.enabled = false
//        XCTAssertEqual(false, textField.enabled)
//        XCTAssertEqual(false, enabled)
//
//        textField.enabled = true
//        XCTAssertEqual(true, enabled)
//
//        textReceiver.cancel()
//
//        textField.stringValue = "QRS"
//        XCTAssertEqual("XYZ", text)
//
//        enabledReceiver.cancel()
//
//        textField.enabled = false
//        XCTAssertEqual(true, enabled)
//
//    }
//
//    func testControls() {
//        struct ViewModel {
//            let amount = ∞(Double(0))∞
//            let amountMax = Double(100.0)
//        }
//
//        let vm = ViewModel()
//
//        let stepper = NSStepper()
//        stepper.maxValue = vm.amountMax
//        stepper∞stepper.doubleValue <=∞=> vm.amount
//
//        let slider = NSSlider()
//        slider.maxValue = vm.amountMax
//        slider∞slider.doubleValue <=∞=> vm.amount
//
//        stepper.doubleValue += 25.0
//        XCTAssertEqual(slider.doubleValue, Double(25.0))
//        XCTAssertEqual(vm.amount∞?, Double(25.0))
//
//        slider.doubleValue += 30.0
//        XCTAssertEqual(stepper.doubleValue, Double(55.0))
//        XCTAssertEqual(vm.amount∞?, Double(55.0))
//
//
//        let progbar = NSProgressIndicator()
//        progbar.maxValue = 1.0
//
//        // NSProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value
//        vm.amount.map({ Double($0 / vm.amountMax) }) ∞=> progbar∞progbar.doubleValue
//
//        vm.amount.value += 20
//
//        XCTAssertEqual(slider.doubleValue, Double(75.0))
//        XCTAssertEqual(stepper.doubleValue, Double(75.0))
//        XCTAssertEqual(progbar.doubleValue, Double(0.75))
//
//        let progress = NSProgress(totalUnitCount: Int64(vm.amountMax))
//        vm.amount.map({ Int64($0) }) ∞=> progress∞progress.completedUnitCount
//
//        // FIXME: memory leak
//        // progress∞progress.completedUnitCount ∞> { _ in println("progress: \(progress.localizedDescription)") }
//
//        let textField = NSTextField()
//
//        // FIXME: crash
//        // progress∞progress.localizedDescription ∞=> textField∞textField.stringValue
//
//        vm.amount.value += 15.0
//    }
//

}
#endif

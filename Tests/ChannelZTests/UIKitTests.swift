//
//  UIKitTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/8/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

#if os(iOS)
import XCTest
import ChannelZ
import CoreData
import ObjectiveC
import WebKit
import UIKit

class UIKitTests : ChannelTestCase {
//    func testButtonCommand() {
//        let button = UIButton()
//
////        var stateChanges = 0
////
//        // TODO: implement proper enum tracking
////        button∞button.state ∞> { x in
////            stateChanges += 1
////        }
////
////        XCTAssertEqual(stateChanges, 1)
////        button.highlighted = true
////        button.selected = true
////        button.enabled = false
////        XCTAssertEqual(stateChanges, 3)
//
//        var selectedChanges = 0
//        button∞button.selected ∞> { x in
//            selectedChanges += 1
//        }
//
//        XCTAssertEqual(selectedChanges, 0)
//        button.selected = true
//        XCTAssertEqual(selectedChanges, 1)
//        button.selected = false
//        XCTAssertEqual(selectedChanges, 2)
//
//        var taps = 0 // track the number of taps on the button
//
//        XCTAssertEqual(taps, 0)
//
//        let eventType: UIControlEvents = .TouchUpInside
//        let cmd = button.controlz(eventType)
//        XCTAssertEqual(0, button.allTargets().count)
//
//        // sadly, this only seems to work when the button is in a running UIApplication
//        // let tap: ()->() = { button.sendActionsForControlEvents(.TouchUpInside) }
//
//        // so we need to fake it by directly invoking the target's action
//        let tap: ()->() = {
//            let event = UIEvent()
//
//            for target in button.allTargets().allObjects as [UIEventReceiver] {
//                // button.sendAction also doesn't work from a test case
//                for action in button.actionsForTarget(target, forControlEvent: eventType) as [String] {
////                    button.sendAction(Selector(action), to: target, forEvent: event)
//                    XCTAssertEqual("handleControlEvent:", action)
//                    target.handleControlEvent(event)
//                }
//            }
//        }
//
//        let buttonTapsHappen = true // false && false // or else compiler warning about blocks never executing
//
//        var subscription1 = cmd.receive({ _ in taps += 1 })
//        XCTAssertEqual(1, button.allTargets().count)
//
//        if buttonTapsHappen {
//            tap(); taps -= 1; XCTAssertEqual(0, taps)
//            tap(); taps -= 1; XCTAssertEqual(0, taps)
//        }
//
//        var subscription2 = cmd.receive({ _ in taps += 1 })
//        XCTAssertEqual(2, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 2; XCTAssertEqual(0, taps)
//            tap(); taps -= 2; XCTAssertEqual(0, taps)
//        }
//
//        subscription1.cancel()
//        XCTAssertEqual(1, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 1; XCTAssertEqual(0, taps)
//            tap(); taps -= 1; XCTAssertEqual(0, taps)
//        }
//
//        subscription2.cancel()
//        XCTAssertEqual(0, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 0; XCTAssertEqual(0, taps)
//            tap(); taps -= 0; XCTAssertEqual(0, taps)
//        }
//    }
//
//    func testTextFieldProperties() {
//        let textField = UITextField()
//
//
//        var text = ""
//        let textReceiver = (textField∞textField.text).map( { $0 } ).receive({ text = $0 })
//
//        var enabled = true
//        let enabledReceiver = textField.channelZKey(textField.enabled).receive({ enabled = $0 })
//
//
//        textField.text = "ABC"
//        XCTAssertEqual("ABC", textField.text)
//        XCTAssertEqual("ABC", text)
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
//        textField.text = "XYZ"
//        XCTAssertEqual("ABC", text)
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
//        let stepper = UIStepper()
//        stepper.maximumValue = vm.amountMax
//        stepper∞stepper.value <=∞=> vm.amount
//
//        let slider = UISlider()
//        slider.maximumValue = Float(vm.amountMax)
//        let subscription = slider∞slider.value <~∞~> vm.amount // FIXME: memory leak
//
//        stepper.value += 25.0
//        XCTAssertEqual(slider.value, Float(25.0))
//        XCTAssertEqual(vm.amount.value, Double(25.0))
//
//        slider.value += 30.0
//        XCTAssertEqual(stepper.value, Double(55.0))
//        XCTAssertEqual(vm.amount.value, Double(55.0))
//
//
//        let progbar = UIProgressView()
//
//        // UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value
//        vm.amount.map({ Float($0 / vm.amountMax) }) ∞=> progbar∞progbar.progress
//
//        vm.amount.value += 20
//
//        XCTAssertEqual(slider.value, Float(75.0))
//        XCTAssertEqual(stepper.value, Double(75.0))
//        XCTAssertEqual(progbar.progress, Float(0.75))
//
//        let progress = NSProgress(totalUnitCount: Int64(vm.amountMax))
//        let pout = vm.amount.map({ Int64($0) }) ∞=> progress∞progress.completedUnitCount
//
////        progress∞progress.localizedDescription ∞> { println("progress: \($0)") }
//
////        let textField = UITextField()
////        progress∞progress.localizedDescription ∞=> textField∞textField.text
//
////        vm.amount.value += 15.0
////
////        //progress.completedUnitCount = 15
////        
////        println("progress: \(textField.text)") // “progress: 15% completed”
//
//        subscription.cancel() // FIXME: memory leak
//        pout.cancel() // FIXME: crash
//    }

}
#endif


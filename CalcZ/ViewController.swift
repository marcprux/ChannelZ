//
//  ViewController.swift
//  CalcZ
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

import UIKit
import ChannelZ

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSliders()
    }

    func loadSliders() {
        let model = ∞(Float(0.0))∞

        let slider = UISlider()
        slider.continuous = true
        slider.maximumValue = 1.0

        let button = UIButton.buttonWithType(.System) as UIButton
        button.setTitle("Reset", forState: .Normal)

        let textField = UITextField()
        textField.borderStyle = .RoundedRect

        let stepper = UIStepper()
        stepper.maximumValue = 1.0
        stepper.stepValue = 0.1
        stepper.wraps = false

        let viewMap = ["slider":slider, "button":button, "textField":textField, "stepper":stepper]
        for control in viewMap.values {
            control.setTranslatesAutoresizingMaskIntoConstraints(false)
            view.addSubview(control)
        }

        for constraints in [
            ("V:|-50-[slider]-[textField(50)]", NSLayoutFormatOptions.AlignAllLeading),
            ("H:|-[slider]-[button]-|", .AlignAllCenterY),
            ("H:|-[textField]-[stepper]-|", .AlignAllCenterY),
            ] {
            NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat(constraints.0, options: constraints.1, metrics: nil, views: viewMap))
        }

        let fmt = NSNumberFormatter()
        fmt.numberStyle = .PercentStyle
        fmt.lenient = true

        slider∞slider.value <=∞=> model // direct conduit to the model since the slider's value is a Float
        stepper∞stepper.value <~∞~> model // coerced conduit to the model since the stepper's value is a Double

        model.attach { textField.text = fmt.stringFromNumber($0) }
        (textField∞textField.text).attach({ model.value = fmt.numberFromString($0 ?? "")?.floatValue ?? 0 })

        button.controlz(.TouchUpInside).attach { event in model.value = 0.0 }
    }
}



import Foundation
import ChannelZ

srand48(Int(arc4random()))
func rnd()->Float { return Float(drand48()) }

struct ColorModel {
    var r = ∞(Float(0.0))∞
    var g = ∞(Float(0.0))∞
    var b = ∞(Float(0.0))∞
    var a = ∞(Float(0.0))∞

    var components: (Float, Float, Float, Float) {
        return (r.pull(), b.pull(), g.pull(), a.pull())
    }

    func randomize(chance: Float = 0.25) {
        if rnd() >= chance { r.push(rnd()) }
        if rnd() >= chance { g.push(rnd()) }
        if rnd() >= chance { b.push(rnd()) }
        if rnd() >= chance { a.push(rnd()) }
    }
}

var model = ColorModel()


import UIKit
import XCPlayground

/// Create a little color swatch that displays the current model color
let swatch = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
XCPShowView("swatch", swatch)

/// Utility function to update individual components to the background swatch
func updateSwatch(red: CGFloat? = nil, green: CGFloat? = nil, blue: CGFloat? = nil, alpha: CGFloat? = nil) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    swatch.backgroundColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
    swatch.backgroundColor = UIColor(red: red ?? r, green: green ?? g, blue: blue ?? b, alpha: alpha ?? a)
}

/// Observable from the model color components to the color of the swatch
model.r += { updateSwatch(red: CGFloat($0)) }
model.g += { updateSwatch(green: CGFloat($0)) }
model.b += { updateSwatch(blue: CGFloat($0)) }
model.a += { updateSwatch(alpha: CGFloat($0)) }


/// Create some sliders that will control the model color
let sliders = (red: UISlider(), green: UISlider(), blue: UISlider(), alpha: UISlider())

for (name, slider) in [ ("red", sliders.red), ("green", sliders.green), ("blue", sliders.blue), ("alpha", sliders.alpha) ] {
    slider.setTranslatesAutoresizingMaskIntoConstraints(false)
    XCPShowView(name, slider)
}


/// Pipe between the slider values and the individual model color components
sliders.red∞sliders.red.value <=∞=> model.r
sliders.green∞sliders.green.value <=∞=> model.g
sliders.blue∞sliders.blue.value <=∞=> model.b
sliders.alpha∞sliders.alpha.value <=∞=> model.a



/// Now continuously update the model values: both the sliders and the swatch will change in accordance
func changeModel(animated: Bool) {
    UIView.animateWithDuration(1, animations: { model.randomize() }, completion: { _ in changeModel(animated) })
}

XCPSetExecutionShouldContinueIndefinitely(continueIndefinitely: true)
changeModel(fal
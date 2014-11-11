
import SwiftFlow

struct ColorModel {
    var r = <|Double(0.0)|>
    var g = <|Double(0.0)|>
    var b = <|Double(0.0)|>
    var a = <|Double(0.0)|>

    var components: (Double, Double, Double, Double) {
        return (r.value, b.value, g.value, a.value)
    }
}

var model = ColorModel()
model.b.value = 0.5


import UIKit
import XCPlayground

let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
XCPShowView("view", view)

combine(combine(combine(model.r, model.g), model.b), model.a)
    .attach({ x in println("model changed") })

// println("combined: \(x.0)")

model.r.attach {
    view.backgroundColor = UIColor(red: CGFloat($0), green: 1, blue: 1, alpha: 1)
}

srand48(Int(arc4random()))

model.r.put(drand48())
model.g.put(drand48())
model.b.put(drand48())
model.a.put(drand48())






let sliders = (red: UISlider(), green: UISlider(), blue: UISlider(), alpha: UISlider())

for (name, slider) in [ "red": sliders.red, "green": sliders.green, "blue": sliders.blue, "alpha": sliders.alpha] {
    slider.setTranslatesAutoresizingMaskIntoConstraints(false)
    XCPShowView(name, slider)
}


//let color = UIColor(red: 0, green: 0, blue: 0, alpha: 0)

var red = sliders.red.channel(sliders.red.value, keyPath: "value")
red.value = 0.9






// FIXME: need to implement
//pipe(&red, &red)

//pipe(&red, &model.r)


//red.value
//
//sliders.red.value = Float(drand48())
//red.value
//
//red.put(0.2)








//var hex = <|"#FFFFFF"|>
//
//
//func toBase(num: UInt, radix: UInt = 16, minlen: Int = 2)->String {
//    if num == 0 { return "" }
//    let basen = map(0..<radix, { String($0, radix: Int(radix), uppercase: true) })
//    var str = toBase(num/radix, radix: radix, minlen: 0) + basen[Int(num%radix)]
//    while countElements(str) < minlen { str = "0" + str }
//    return str
//}
//
//toBase(1234567890)
//
//func fromBase(str: String, radix: UInt = 16)->UInt? {
//    if countElements(str) == 0 { return nil }
//    let basen = map(0..<radix, { String($0, radix: Int(radix), uppercase: true) })
//    let last = str.endIndex.predecessor()
//    if let cur = find(basen, str[last...last]) {
//        if let next = fromBase(str[str.startIndex..<last], radix: radix) {
//            return UInt(cur) + (next * radix)
//        } else {
//            return UInt(cur)
//        }
//    } else {
//        return nil
//    }
//}
//
//fromBase("499602D2")
//
//model.components
//
//
//let x = split("ABCD", { $0 == "B" })
//x
//
//let hex2color = hex
//    .filter({ countElements($0) == 7 && $0.hasPrefix("#") })
//    .map({ Array($0) })
//    .map({ ($0[1...2], $0[3...4], $0[5...6]) })
////    .map({ (fromBase(String($0.0)), fromBase(String($0.1)), fromBase(String($0.2))) })
//    .attach({ println("\($0)") })
//
////    .map({ s in fromBase(s[1...2]) })
//
//hex2color.put("#AABBCC")



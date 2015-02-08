class ObjcIntClass : NSObject {
    dynamic var intField: Int = 0
}

struct SwiftStringClass {
    let stringChannel = ∞("")∞
}

let ojic = ObjcIntClass()
let swsc = SwiftStringClass()

(ojic∞ojic.intField).map({ "\($0)" }) <=∞=> (swsc.stringChannel).map({ $0.toInt() ?? 0 })

ojic.intField += 55
swsc.stringChannel.value // will be "55"

swsc.stringChannel.value = "89"
ojic.intField // will be 89

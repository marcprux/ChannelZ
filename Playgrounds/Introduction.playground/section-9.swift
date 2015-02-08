class StringClass : NSObject {
    dynamic var stringField = ""
}

struct StringStruct {
    let stringChannel = ∞("")∞
}

let scl1 = StringClass()
let sst1 = StringStruct()

scl1∞scl1.stringField <=∞=> sst1.stringChannel


sst1.stringChannel.source.value
scl1.stringField += "ABC"
sst1.stringChannel.source.value

assert(sst1.stringChannel.source.value == scl1.stringField)
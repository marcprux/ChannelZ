eld)
let sc3 = SomeClass()
let sc4 = SomeClass()

let sc3z = sc3.channelz(sc3.intField, keyPath: "intField")
let sc4z = sc4.channelz(sc4.intField, keyPath: "intField")

conduit(sc3z, sc4z)

sc3.intField
sc4.intField += 789
sc3.intField

assert(sc3.intField == sc4.intFi
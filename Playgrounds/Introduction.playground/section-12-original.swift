let scl2 = StringClass()
let sst2 = StringStruct()

scl2∞scl2.stringField ∞=> sst2.stringChannel

scl2.stringField += "XYZ"
assert(sst2.stringChannel.source.value == scl2.stringField, "stringField conduit to stringChannel")

sst2.stringChannel.source.value = "QRS"
assert(sst2.stringChannel.source.value != scl2.stringField, "conduit is unidirectional")

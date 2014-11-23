import ChannelZ

let a1 = ∞(Int(0))∞ // create a field channel
let a2 = ∞(Int(0))∞ // create another field channel

a1 <=∞=> a2 // create a two-way conduit between the properties

println(a1.value) // the underlying value of the field channel is accessed with the `value` property
a2.value = 42 // then changing a2's value…
println(a1.value) // …will automatically set a1 to that same value!

assert(a1.value == 42)
assert(a2.value == 42)
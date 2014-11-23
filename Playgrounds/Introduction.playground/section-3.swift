let b1: ChannelZ<Int> = channelField(Int(0))
let b2: ChannelZ<Int> = channelField(Int(0))

let b1b2: Outlet = conduit(b1, b2)

b1.value
b2.value = 99
b1.value

assert(b1.value == 99)
assert(b2.value == 99)

b1b2.detach() // you can manually disconnect the conduit if you like
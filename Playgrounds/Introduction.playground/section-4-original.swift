let b1: ChannelZ<Int> = channelField(Int(0))
let b2: ChannelZ<Int> = channelField(Int(0))

let b1b2: Receptor = conduit(b1, b2)

b1.source.value
b2.source.value = 99
b1.source.value

assert(b1.source.value == 99)
assert(b2.source.value == 99)

b1b2.unsubscribe() // you can manually disconnect the conduit if you like

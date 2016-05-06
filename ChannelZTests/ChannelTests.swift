//
//  ChannelTests.swift
//  ChannelTests
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import XCTest
import ChannelZ

class ChannelTestCase : XCTestCase {
    override func invokeTest() {
//        return invocation?.selector == #selector(ChannelTests.testThreading) ? super.invokeTest() : print("skipping test", name)
        return super.invokeTest()
    }


    override internal func tearDown() {
        super.tearDown()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_CHANNELZ
            XCTAssertEqual(0, ChannelZ.ChannelZReentrantReceptions, "unexpected reentrant receptions detected")
            ChannelZ.ChannelZReentrantReceptions = 0
        #else
            XCTFail("Why are you running tests with debugging off?")
        #endif
    }
}

extension StreamType {
    /// Test method that receives to the observable and returns any elements that are immediately sent to fresh receivers
    func pullZ() -> [Pulse] {
        var items: [Pulse] = []
        receive({ items += [$0] }).cancel()
        return items
    }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
@warn_unused_result public func channelZSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S) -> Channel<S, S.Generator.Element> {
    return from.channelZSequence()
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
@warn_unused_result public func seqZ<T>(from: T...) -> Channel<[T], T> {
    return from.channelZSequence()
}

// TODO make a spec with each of https://github.com/ReactiveX/RxScala/blob/0.x/examples/src/test/scala/rx/lang/scala/examples/RxScalaDemo.scala


private func feedZ<T, U, S>(input: [T], setup: Channel<PropertySource<T>, T> -> Channel<S, U>) -> [U] {
    let channel = channelZPropertyValue(input[0])
    let transformed = setup(channel)

    // store the output; we store 3 separate outputs just to check that EffectSources work correctly
    var outputs = ([U](), [U](), [U]())
    let r0 = transformed.receive { outputs.0.append($0) }
    defer { r0.cancel() }

    let r1 = transformed.receive { outputs.1.append($0) }
    defer { r2.cancel() }

    let r2 = transformed.receive { outputs.2.append($0) }
    defer { r2.cancel() }

    for value in input.dropFirst() { channel.source.receive(value) }
    switch arc4random_uniform(3) {
    case 0: return outputs.0
    case 1: return outputs.1
    case 2: return outputs.2
    default: fatalError("bad random number")
    }
}

// Just run the function on the static sequence; the immediate form of feedZ
private func feedX<T, U>(seq: [T], f: [T] -> U) -> U {
    return f(seq)
}


class ChannelTests : ChannelTestCase {
    func testLensChannels() {
        let prop = channelZPropertyState((int: 1, dbl: 2.2, str: "Foo", sub: (a: true, b: 22, c: "")))

        let str = prop.channelZLens({ $0.str }, { $0.str = $1 })
        let int = prop.channelZLens({ $0.int }, { $0.int = $1 })
        let dbl = prop.channelZLens({ $0.dbl }, { $0.dbl = $1 })
        let sub = prop.channelZLens({ $0.sub }, { $0.sub = $1 })
        let suba = sub.channelZLens({ $0.a }, { $0.a = $1 })
        let subb = sub.channelZLens({ $0.b }, { $0.b = $1 })
        let subc = sub.channelZLens({ $0.c }, { $0.c = $1 })

        // subc = Channel<LensSource<Channel<LensSource<Channel<PropertySource<X>, StatePulse<X>>, Y>, StatePulse<Y>>, String>, StatePulse<String>>

        str.$ = "Bar"
        int.$ = 2
        dbl.$ = 5.5

        suba.$ = false
        subb.$ = 999
        subc.$ = "x"

        XCTAssertEqual(prop.$.str, "Bar")
        XCTAssertEqual(prop.$.int, 2)
        XCTAssertEqual(prop.$.dbl, 5.5)

        XCTAssertEqual(prop.$.sub.a, false)
        XCTAssertEqual(prop.$.sub.b, 999)
        XCTAssertEqual(prop.$.sub.c, "x")

        // children can affect parent values and it will update state and fire receivers
        var strUpdates = 0
        var strChanges = 0
        str.subsequent().receive({ _ in strUpdates += 1 })
        str.subsequent().sieve(!=).receive({ _ in strChanges += 1 })
        XCTAssertEqual(0, strChanges)

        subc.owner.owner.$.str = "Baz"
        XCTAssertEqual(prop.$.str, "Baz")
        XCTAssertEqual(1, strUpdates)
        XCTAssertEqual(1, strChanges)

        subc.owner.$.b = 7
        XCTAssertEqual(prop.$.sub.b, 7)
        XCTAssertEqual(2, strUpdates) // note that str changes even when a different property changed
        XCTAssertEqual(1, strChanges) // so we sieve for changes

        subc.owner.owner.$.str = "Baz"

        let compound = str.new() & subb.new()
        dump(compound)
        compound.receive { x in dump(x) }

//        dump(compound.$)
//        let MVλ = 1
    }

    /// Verifies that asyncronous Channels and syncronous Sequences behave the same way
    func testAnalogousSequenceFunctions() {
        let nums = [1, 2, 3, 3, 2, -1] // the test set

        XCTAssertEqual(nums, feedZ(nums) { $0 })

        do {
            let xpct = [2, 3, 3, 2]
            XCTAssertEqual(xpct, feedX(nums) { $0.filter({ $0 > 1 }) })
            XCTAssertEqual(xpct, feedZ(nums) { $0.filter({ $0 > 1 }) })
        }

        do {
            let xpct = [-1, -2, -3, -3, -2, 1]
            XCTAssertEqual(xpct, feedX(nums) { $0.map(-) })
            XCTAssertEqual(xpct, feedZ(nums) { $0.map(-) })
        }

        do {
            let xpct = ["1", "2", "3", "3", "2", "-1"]
            XCTAssertEqual(xpct, feedX(nums) { $0.map(String.init) })
            XCTAssertEqual(xpct, feedZ(nums) { $0.map(String.init) })
        }

        do {
            let xpct = 10
            XCTAssertEqual(xpct, feedX(nums) { $0.reduce(0, combine: +) })
            XCTAssertEqual(xpct, feedZ(nums) { $0.reduce(0, combine: +) }.last) // last because reduce provides running reductions
        }

        do {
            XCTAssertEqual([3, 2, -1], feedX(nums) { $0.dropFirst(3) })
            XCTAssertEqual([3, 2, -1], feedZ(nums) { $0.dropFirst(3) })
        }

        do {
            XCTAssertEqual([1, 2, 3, 3, 2], feedX(nums) { $0.prefix(5) })
            XCTAssertEqual([1, 2, 3, 3, 2], feedZ(nums) { $0.prefix(5) })
        }

        do {
            let xpct = [2, 3, 4, 6, 6, 9, 6, 9, 4, 6, -2, -3]
            XCTAssertEqual(xpct, nums.flatMap { [$0 * 2, $0 * 3] })
            XCTAssertEqual(xpct, feedZ(nums) { $0.flatMap { seqZ($0 * 2, $0 * 3) } })
        }

        do {
            let xpct = [1, 4, 9, 9, 4, 1]
            XCTAssertEqual(xpct, zip(nums, nums).map(*))
            XCTAssertEqual(xpct, feedZ(nums) { $0.zip(nums.channelZSequence()).map(*) })
        }

        do {
            let xpct = [2, 6, 9, 6, -2]
            XCTAssertEqual(xpct, zip(nums.dropFirst(), nums).map(*))
            XCTAssertEqual(xpct, feedZ(nums) { $0.dropFirst().zip(nums.channelZSequence()).map(*) })
        }

        do {
            let xpct = [2, 6, 9, 6, -2]
            XCTAssertEqual(xpct, zip(nums, nums.dropFirst()).map(*))
            XCTAssertEqual(xpct, feedZ(nums) { $0.zip(nums.channelZSequence().dropFirst()).map(*) })
        }

        let three = { $0 == 3 }

        do {
            let xpct = [[1, 2], [2, -1]]
            XCTAssertEqual(xpct, feedX(nums + [3]) { $0.split(isSeparator: three) }.map(Array.init))
            XCTAssertEqual([[1, 2], [2, -1]], feedZ(nums + [3]) { $0.split(isSeparator: three) })
        }

        do {
            let xpct = [[1, 2], [], [2, -1]]
            XCTAssertEqual(xpct, nums.split(allowEmptySlices: true, isSeparator: three).map(Array.init))
            XCTAssertEqual(xpct, feedZ(nums + [3]) { $0.split(allowEmptySlices: true, isSeparator: three) })
        }

        XCTAssertEqual([[1, 2], []], nums.split(2, allowEmptySlices: true, isSeparator: three).dropLast().map(Array.init))
        XCTAssertEqual([[1, 2], []], feedZ(nums + [3]) { $0.split(2, allowEmptySlices: true, isSeparator: three) })

        XCTAssertEqual([[1, 2]], nums.split(1, allowEmptySlices: true, isSeparator: three).dropLast().map(Array.init))
        XCTAssertEqual([[1, 2]], feedZ(nums + [3]) { $0.split(1, allowEmptySlices: true, isSeparator: three) })

        XCTAssertEqual([1, 2, -1], feedZ(nums) { $0.changes(<) })

        XCTAssertEqual([1, 2, 3, 2, -1], feedZ(nums) { $0.presieve(!=).new() })

        XCTAssertEqual([[1, 2, 3], [3, 2, -1]], feedZ(nums) { $0.buffer(3) })

        XCTAssertEqual([9, 1], feedZ(nums) { $0.partition(0, isPartition: >, combine: +) })

        XCTAssertEqual([6, 2], feedZ(nums) { $0.partition(0, includePartitions: false, isPartition: >, combine: +) })

        XCTAssertEqual([1, 1, 2, 2, 3, 3, 3, 3, 2, 2, -1, -1], feedZ(nums) { $0.flatMap { seqZ($0) + seqZ($0) } })

//        XCTAssertEqual([1, 1, 4, 4, 9, 9, 9, 9, 4, 4, 1, 1], feedZ(nums) { $0.flatMap { seqZ($0) & seqZ($0) }.map(*) })

        let _ = feedZ(nums) { $0.flatMap { seqZ($0) | seqZ($0).map(String.init) } }

    }

    func XXXtestThreading() {
        // FIXME: dispatch locking doesn't work!

        let prev = ChannelZReentrancyLimit
        ChannelZReentrancyLimit = 999999
        defer { ChannelZReentrancyLimit = prev }

        let count = 999
        var values = Set(0..<count)
        let prop = channelZPropertyValue(0)

        let queue = dispatch_queue_create(#function, DISPATCH_QUEUE_CONCURRENT)
        prop.receive { i in
            dispatch_barrier_sync(queue) {
                values.remove(i)
            }
        }

//        for i in values {
        dispatch_apply(count + 1, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)) { i in
            dispatch_sync(queue) {
                prop.$ = i
            }
        }

        XCTAssertEqual(0, values.count)

    }

    func testZipImplementations() {
        let z1 = channelZPropertyState(1).new()
        let z2 = channelZPropertyState("1").new()
        let z3 = channelZPropertyState(true).new()
        let z4 = channelZPropertyState().new()

        var items: [(index: Int, pulse: (((Int, String), Bool), Void))] = []
        let zz = z1.zip(z2).zip(z3).zip(z4).enumerate()

        zz.receive {
            dump($0.index)
            items.append($0)
        }

        XCTAssertEqual(1, items.count)
        XCTAssertEqual(0, items.last?.index)

        z1.$ = 2
        z2.$ = "2"
        z3.$ = true
        z4.$ = Void()

        XCTAssertEqual(2, items.count)
        XCTAssertEqual(1, items.last?.index)

        z1.$ = 3
        z1.$ = 4

        z4.$ = Void()
        z4.$ = Void()

        z3.$ = true
        z3.$ = true

        z2.$ = "4"
        z2.$ = "5"

        z4.$ = Void()
        z3.$ = true
        z2.$ = "3"

        XCTAssertEqual(4, items.count)
        XCTAssertEqual(3, items.last?.index)

        z1.$ = 5

        XCTAssertEqual(5, items.count)
        XCTAssertEqual(4, items.last?.index) // last enum
    }

    func testEnumerateCount() {
        let z1 = channelZPropertyState(1).new()
        let z2 = channelZPropertyState("1").new()
        let zz = z1.either(z2)
        var counts = (-1, 0, 0, 0)

        zz.enumerate().enumerate().enumerate().receive {
            counts.0 += 1
            counts.1 = $0.index
            counts.2 = $0.pulse.index
            counts.3 = $0.pulse.pulse.index
        }

        XCTAssertEqual(counts.0, counts.1)
        XCTAssertEqual(counts.0, counts.2)
        XCTAssertEqual(counts.0, counts.3)

        z1.$ += 1

        XCTAssertEqual(counts.0, counts.1)
        XCTAssertEqual(counts.0, counts.2)
        XCTAssertEqual(counts.0, counts.3)

        z2.$ += "1"

        XCTAssertEqual(counts.0, counts.1)
        XCTAssertEqual(counts.0, counts.2)
        XCTAssertEqual(counts.0, counts.3)
    }

    func testEnumerations() {
        let z1 = channelZPropertyState(true).new()
        let z2 = channelZPropertyState(1).new()
        typealias Item = (index: Int, pulse: (index: Int, pulse: (index: Int, pulse: OneOf2<Bool, Int>)))

        let enums = z1.either(z2).enumerate().enumerate().enumerate()
//        let enums = enumberate(enumberate(enumberate(z1.either(z2))))
        var elements: [Item] = []

        XCTAssertEqual(0, elements.count)
        enums.receive({ print("receive 1", $0) })
        enums.receive({ print("receive 2", $0) })
        enums.receive({ elements.append($0) })
        XCTAssertEqual(2, elements.count)

        XCTAssertEqual(0, elements.first?.index)
        XCTAssertEqual(0, elements.first?.pulse.index)
        XCTAssertEqual(0, elements.first?.pulse.pulse.index)

        XCTAssertEqual(1, elements.last?.index)
        XCTAssertEqual(1, elements.last?.pulse.index)
        XCTAssertEqual(1, elements.last?.pulse.pulse.index)

        z1.$ = true

        XCTAssertEqual(2, elements.last?.index)
        XCTAssertEqual(2, elements.last?.pulse.index)
        XCTAssertEqual(2, elements.last?.pulse.pulse.index)

        z2.$ = 1

        XCTAssertEqual(3, elements.last?.index)
        XCTAssertEqual(3, elements.last?.pulse.index)
        XCTAssertEqual(3, elements.last?.pulse.pulse.index)
    }

    func testTraps() {
        let channel = ∞=false=∞
        // var src = channel.source
        let bools = channel.trap(10)

        // test that sending capacity distinct values will store those values
        let send = [true, false, true, false, true, false, true, false, true, false]
        for x in send { bools.stream.$ = x }
        XCTAssertEqual(send, bools.values)

        // test that sending some mixed values will sieve and constrain to the capacity
        let mixed = [false, true, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false]
        for x in mixed { bools.stream.$ = x }
        XCTAssertEqual(send, bools.values)
    }

//    func testChannelTraps() {
//        let seq = [1, 2, 3, 4, 5]
//        let seqz = channelZSequence(seq).precedent()
//        let trapz = seqz.trap(10)
//        let values = trapz.values.map({ $0.old != nil ? [$0.old!.item, $0.new.item] : [$0.new.item] })
//        XCTAssertEqual(values, [[1], [1, 2], [2, 3], [3, 4], [4, 5]])
//    }

    func testGenerators() {
        let seq = [true, false, true, false, true]

//        let gfun1 = Channel(from: GeneratorOf(seq.generate())) // GeneratorChannel with generator
//        let trap1 = gfun1.trap(3)
//        XCTAssertEqual(seq[2...4], trap1.values[0...2], "trap should contain the last 3 elements of the sequence generator")

        let gfun2 = channelZSequence(seq) // GeneratorChannel with sequence
        let trap2 = gfun2.trap(3)
        XCTAssertEqual(seq[2...4], trap2.values[0...2], "trap should contain the last 3 elements of the sequence generator")

        let trapped = (channelZSequence(1...5) ^ channelZSequence(6...10)).trap(1000)
        
        XCTAssertEqual(trapped.values.map({ [$0, $1] }), [[1, 6], [2, 7], [3, 8], [4, 9], [5, 10]]) // tupes aren't equatable

        // observable concatenation
        // the equivalent of ReactiveX's Range
        let merged = (channelZSequence(1...3) + channelZSequence(3...5) + channelZSequence(2...6)).trap(1000)
        XCTAssertEqual(merged.values, [1, 2, 3, 3, 4, 5, 2, 3, 4, 5, 6])

        // the equivalent of ReactiveX's Repeat
        XCTAssertEqual(channelZSequence(Repeat(count: 10, repeatedValue: "A")).trap(4).values, ["A", "A", "A", "A"])
        XCTAssertEqual(channelZSequence(Repeat(count: 10, repeatedValue: "A")).subsequent().trap(4).values, [])
    }

    func testMergedUnreceive() {
        func coinFlip() -> Void? {
            if arc4random_uniform(100) > 50 {
                return Void()
            } else {
                return nil
            }
        }

        typealias S1 = Range<Int>
        typealias S2 = AnyReceiver<(Float)>
        typealias S3 = ()->Void?

        let o1: Channel<S1, Int> = channelZSequence(1...3)
        let o2: Channel<S2, Int> = channelZSink(Float).map({ Int($0) })
        let o3: Channel<S3, Void> = channelZClosure(coinFlip)

        let cc: Channel<(((S1, S2), S2), S2), Int> = o1 + o2 + o2 + o2

        // examples of type signatures
        let _: Channel<((S1, S2), (S2, S2)), Int> = (o1 + o2) + (o2 + o2)
        let _: Channel<Void, Int> = cc.desource()
        let _ = o1 | o2 | o1
        let _: Channel<(S1, S2, S3), (Int, Int, Void)> = o1 ^ o2 ^ o3
        let _: Channel<(S1, S2, S3, S2, S1), (Int, Int, Void, Int, Int)> = o1 ^ o2 ^ o3 ^ o2 ^ o1
////        let ccMany: Channel<(S1, S2, S3, S1, S2, S3, S1, S2, S3, S1, S2, S3), (Int, Int, Void, Int, Int, Void, Int, Int, Void, Int, Int, Void)> = o1 ^ o2 ^ o3 ^ o1 ^ o2 ^ o3 ^ o1 ^ o2 ^ o3 ^ o1 ^ o2 ^ o3

        var count = 0
        let sub = cc.receive({ _ in count += 1 })
        XCTAssertEqual(3, count)

        o2.source.receive(4) // put broadcasts to three sources
        XCTAssertEqual(6, count)

        cc.source.0.0.1.receive(5)
        XCTAssertEqual(9, count)

        sub.cancel()
        o2.source.receive(6)

        XCTAssertEqual(9, count)
    }

    func testStreamExtensions() {
        guard let stream = NSInputStream(fileAtPath: #file) else {
            return XCTFail("could not open \(#file)")
        }

        weak var xpc: XCTestExpectation? = expectationWithDescription("input stream")

        let allData = NSMutableData()
        let obv = stream.channelZStream()
        var openCount = 0
        var closeCount = 0
        var count = 0
        let sub = obv.receive { switch $0 {
            case .Opened:
                openCount += 1
            case .Data(let d):
                count += d.count
                allData.appendData(NSData(bytes: d, length: d.count))
            case .Error(let e):
                XCTFail(String(e))
                xpc?.fulfill()
            case .Closed:
                closeCount += 1
                xpc?.fulfill()
            }
        }

        stream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        stream.open()

        waitForExpectationsWithTimeout(1, handler: { _ in })

        XCTAssertEqual(1, openCount)
        XCTAssertEqual(1, closeCount)
        XCTAssertGreaterThan(count, 1000)
        sub.cancel()

        if let str = NSString(data: allData, encoding: NSUTF8StringEncoding) {
            let advice = "Begin at the beginning, and go on till you come to the end: then stop"
            XCTAssertTrue(str.containsString(advice))
        } else {
            XCTFail("could not create string from data in \(#file)")
        }
    }

    func testFilterChannel() {
        let obv = channelZSink(Int)

        var count = 0
        _ = obv.filter({ $0 > 0 }).receive({ _ in count += 1 })

        let numz = -10...3
        for x in numz { obv.source.receive(x) }

        XCTAssertEqual(3, count)
    }

    func testMapChannel() {
        let obv = channelZSink(Int)

        var count = 0

        let isMoreThanOneCharacter: String->Bool = { NSString(string: $0).length >= 2 }

        let chan = obv.map({ "\($0)" })
        let filt = chan.filter(isMoreThanOneCharacter)
        let sub = filt.receive({ _ in count += 1 })

        for _ in 1...10 {
            let numz = -2...11
            for x in numz { obv.source.receive(x) }
            XCTAssertEqual(4, count)
            sub.cancel() // make sure the count is still 4...
        }
    }

    func testSieveDistinct() {
        let numberz = channelZPropertyValue(1)

        var items: [Int] = []
        numberz.changes(!=).receive {
            items.append($0)
        }

        for num in [1, 2, 1, 2, 2, 2, 3, 3, 4] {
            numberz.source.$ = num
        }

        XCTAssertEqual([1, 2, 1, 2, 3, 4], items)
    }

    func testSieveLastIncrementing() {
        let numberz = channelZPropertyValue(1)

        var items: [Int] = []
        numberz.changes(<).receive {
            items.append($0)
        }

        for n in [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3] {
            numberz.source.receive(n)
        }

        XCTAssertEqual([1, 1, 1], items)
    }

    func testReduceImmediate() {
        let numberz = channelZSequence([1, 2, 3, 4, 5, 6, 7])
        let sum = numberz.reduce(0, combine: +)

        var sums: [Int] = []
        sum.receive { x in sums.append(x) }

        XCTAssertEqual(sums, [1, 3, 6, 10, 15, 21, 28])
//        XCTAssertEqual(sums, [28, 28, 28, 28, 28, 28, 28])
    }

    func testReduceMultiple() {
        let numberz = channelZPropertyState(0).new()

        let sum = numberz.reduce(0, combine: +)

        var raws = (Array<Int>(), Array<Int>())
        let r0 = numberz.receive { x in raws.0.append(x) }

        var sums = (Array<Int>(), Array<Int>(), Array<Int>())
        let r1 = sum.receive { x in sums.0.append(x) }
        let r2 = sum.receive { x in sums.1.append(x) }
        let r3 = sum.receive { x in sums.2.append(x) }

        let r4 = numberz.receive { x in raws.1.append(x) }

        for i in 1...7 { numberz.$ = i }

        XCTAssertEqual(raws.0, Array(0...7))
        XCTAssertEqual(sums.0, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(sums.1, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(sums.2, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(raws.1, Array(0...7))

        XCTAssertFalse(r0.cancelled)
        XCTAssertFalse(r1.cancelled)
        XCTAssertFalse(r2.cancelled)
        XCTAssertFalse(r3.cancelled)
        XCTAssertFalse(r4.cancelled)

    }

    func testEnumerateWithMultipleReceivers() {
        let prop = channelZPropertyState("")
        let enumerated = prop.enumerate()

        var counts = (Array<Int>(), Array<Int>(), Array<Int>())
        enumerated.receive({ (i, s) in counts.0.append(i) })
        enumerated.receive({ (i, s) in counts.1.append(i) })
        enumerated.receive({ (i, s) in counts.2.append(i) })

        XCTAssertEqual([0], counts.0)
        XCTAssertEqual([0], counts.1)
        XCTAssertEqual([0], counts.2)

        prop.source.receive("a")
        XCTAssertEqual([0, 1], counts.0)
        XCTAssertEqual([0, 1], counts.1)
        XCTAssertEqual([0, 1], counts.2)

        prop.source.receive("b")
        XCTAssertEqual([0, 1, 2], counts.0)
        XCTAssertEqual([0, 1, 2], counts.1)
        XCTAssertEqual([0, 1, 2], counts.2)
    }

    func testBuffer() {
        let numberz = channelZPropertyValue(0)
        let bufferer = numberz.buffer(3)

        var items: [[Int]] = []
        bufferer.receive { items.append($0) }
        for i in 1...10 { numberz.$ = i }
        // note that 9 & 10 are dropped because they don't satisfy the buffering requirement
        XCTAssertTrue([[0, 1, 2], [3, 4, 5], [6, 7, 8]] == items, "Bad buffered items: \(items)")
    }

//    func testTerminate() {
//        let boolz = channelZSequence([true, true, true, false, true, false, false, true])
//        let finite = boolz.terminate(!)
//        XCTAssertEqual([true, true, true], finite.pullZ())
//
//        let boolz2 = channelZSequence([true, true, true, false, true, false, false, true])
//        let finite2 = boolz2.terminate(!, terminus: { false })
//        XCTAssertEqual([true, true, true, false], finite2.pullZ())
//    }

    func testReduceNumbers() {
        let numberz = channelZPropertyValue(0)
        // computes the running sum of each batch of 7 non-zero numbers
        let bufferer = numberz.partition(0, isPartition: { b,x in x > 0 && x % 7 == 0 }, combine: +)
        var items = (Array<Int>(), Array<Int>(), Array<Int>())
        bufferer.receive { items.0.append($0) }
        bufferer.receive { items.1.append($0) }
        bufferer.receive { items.2.append($0) }

        for i in 1...100 { numberz.$ = i }
        let a1 = 1+2+3+4+5+6+7
        let a2 = 8+9+10+11+12+13+14

        XCTAssertEqual([a1, a2, 126, 175, 224, 273, 322, 371, 420, 469, 518, 567, 616, 665], items.0)
        XCTAssertEqual([a1, a2, 126, 175, 224, 273, 322, 371, 420, 469, 518, 567, 616, 665], items.1)
        XCTAssertEqual([a1, a2, 126, 175, 224, 273, 322, 371, 420, 469, 518, 567, 616, 665], items.2)
    }

    // FIXME: linker error
//    func testReduceRunningAverage() {
//        // index creates an indexed pair of elements, a lazy version of Swift's EnumerateGenerator
//        func index<T>()->(item: T)->(index: Int, item: T) { var index = 0; return { item in return (index += 1, item) } }
//
//        // runningAgerage computes the next average in a sequence given the previous average and the current index
//        func runningAverage(prev: Double, pair: (Int, Double))->Double { return (prev * Double(pair.0) + pair.1) / Double(pair.0+1) }
//
//        // always always returns true
//        func always<T>(_: T)->Bool { return true }
//        
//        var numberz = (1...10).channelZ()
//        let avg1 = numberz.map({ Double($0) }).enumerate().partition(0, withPartitions: true, clearAfterPulse: false, isPartition: always, combine: runningAverage)
//        XCTAssertEqual([1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5], avg1.pullZ())
//
//        let avg2 = numberz.map({ Double($0 * 10) }).map(index()).partition(0, withPartitions: true, clearAfterPulse: false, isPartition: always, combine: runningAverage)
//        XCTAssertEqual([10, 15, 20, 25, 30, 35, 40, 45, 50, 55], avg2.pullZ())
//
//    }

    func channelResults<S: StateReceiver, T>(channel: Channel<S, T>, items: [S.Pulse]) -> [T] {
        var results: [T] = []
        let _ = channel.receive({ results.append($0) })
        for item in items {
            channel.source.receive(item)
        }
        return results
    }

    func testPartitionStrings() {
        func isSpace(buf: String, str: String)->Bool { return str == " " }

        let withPartition = channelResults(channelZPropertyValue("").partition("", isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
        XCTAssertEqual(["1 ", "12 ", "123 ", "1234 ", "12345 ", "123456 ", "1234567 ", "12345678 ", "123456789 "], withPartition)

        let withoutPartition = channelResults(channelZPropertyValue("").partition("", includePartitions: false, isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
        XCTAssertEqual(["1", "12", "123", "1234", "12345", "123456", "1234567", "12345678", "123456789"], withoutPartition)

    }

    func testFlatMapChannel() {
        let numbers = (1...3).channelZSequence()
        
        let multiples = { (n: Int) in [n*2, n*3].channelZSequence() }
        let flatMapped = numbers.flatMap(multiples)
        XCTAssertEqual([2, 3, 4, 6, 6, 9], flatMapped.pullZ())
    }


    func testFlatMapTransformChannel() {
        let numbers = (1...3).channelZSequence()
        let quotients = { (n: Int) in [Double(n)/2.0, Double(n)/4.0].channelZSequence() }
        let multiples = { (n: Double) in [Float(n)*3.0, Float(n)*5.0, Float(n)*7.0].channelZSequence() }
        let flatMapped = numbers.flatMap(quotients).flatMap(multiples)
        XCTAssertEqual([1.5, 2.5, 3.5, 0.75, 1.25, 1.75, 3, 5, 7, 1.5, 2.5, 3.5, 4.5, 7.5, 10.5, 2.25, 3.75, 5.25], flatMapped.pullZ())
    }

    func testPropertyReceivers() {
        class Person {
            let fname = ∞=("")=∞
            let lname = ∞=("")=∞
            var level = ∞(0)∞
        }

        let person = Person()

        let fnamez = person.fname.subsequent().concat(person.lname.subsequent())
        var names: [String] = []
        let rcpt = fnamez.receive { names += [$0.1] }

        person.fname.source.receive("Marc")
        person.lname.$ = "Prud'hommeaux"
        person.fname.$ = "Marc"
        person.fname.$ = "Marc"
        person.lname.$ = "Prud'hommeaux"

        XCTAssertFalse(rcpt.cancelled)
        rcpt.cancel()
        XCTAssertTrue(rcpt.cancelled)

        person.fname.$ = "John"
        person.lname.$ = "Doe"

        XCTAssertEqual(["Marc", "Prud'hommeaux"], names)

//        var levels: [Int] = []
//        _ = person.level.sieve(<).receive({ levels += [$0] })
//        person.level.value = 1
//        person.level.value = 2
//        person.level.value = 2
//        person.level.value = 1
//        person.level.value = 3
//        XCTAssertEqual([0, 1, 2, 3], levels)
    }

    func testPropertySources() {
        let propa = PropertySource("A")
        let propb = PropertySource("B")

        let rcpt = ∞propa <=∞=> ∞propb

        XCTAssertEqual("A", propa.$)
        XCTAssertEqual("A", propb.$)

        propa.$ = "X"
        XCTAssertEqual("X", propa.$)
        XCTAssertEqual("X", propb.$)

        propb.$ = "Y"
        XCTAssertEqual("Y", propa.$)
        XCTAssertEqual("Y", propb.$)

        rcpt.cancel()

        propa.$ = "Z"
        XCTAssertEqual("Z", propa.$)
        XCTAssertEqual("Y", propb.$, "cancelled receiver should not have channeled the value")
    }

    func testConversionChannels() {
        let propa = channelZPropertyValue(0)
        let propb = channelZPropertyValue(0.0)

        let rcpt = propa.map({ Double($0) }) <=∞=> propb.map({ Int($0) })

        XCTAssertEqual(0, propa.source.$)
        XCTAssertEqual(0.0, propb.source.$)

        propa.source.$ += 1
        XCTAssertEqual(1, propa.source.$)
        XCTAssertEqual(1.0, propb.source.$)

        propb.source.$ += 1.2
        XCTAssertEqual(2, propa.source.$)
        XCTAssertEqual(2.0, propb.source.$, "rounded value should have been mapped back")

        rcpt.cancel()

        propa.source.$ -= 1
        XCTAssertEqual(1, propa.source.$)
        XCTAssertEqual(2.0, propb.source.$, "cancelled receiver should not have channeled the value")
    }

    func testUnstableChannels() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions = 0 }

        let _: PropertySource<Int> = 0∞ // just to show the postfix signature
        let propa: Channel<PropertySource<Int>, Int> = ∞0∞
        let propb: Channel<PropertySource<Int>, Int> = ∞0∞

        let rcpt = propb.map({ $0 + 1 }) <=∞=> propa

        XCTAssertEqual(1, propa.source.$)
        XCTAssertEqual(1, propb.source.$)

        // these values are all contingent on the setting of ChannelZReentrancyLimit
        XCTAssertEqual(1, ChannelZReentrancyLimit)

        propa.source.$ += 1
        XCTAssertEqual(4, propa.source.$)
        XCTAssertEqual(3, propb.source.$)

        propb.source.$ += 1
        XCTAssertEqual(6, propa.source.$)
        XCTAssertEqual(6, propb.source.$)

        rcpt.cancel()

        propa.source.$ -= 1
        XCTAssertEqual(5, propa.source.$)
        XCTAssertEqual(6, propb.source.$, "cancelled receiver should not have channeled the value")

    }

    func testEitherOr() {
        let a = ∞=0=∞
        let b = ∞="A"=∞
        let c = ∞=0.0=∞

        var ints = 0
        var strs = 0
        var flts = 0

        a.either(b).either(c).receive { r in
            switch r {
            case .V1(.V1): ints += 1
            case .V1(.V2): strs += 1
            case .V2: flts += 1
            }
        }

        XCTAssertEqual(1, ints)
        XCTAssertEqual(1, strs)

        a.source.$ += 1
        XCTAssertEqual(2, ints)
        XCTAssertEqual(1, strs)

        b.source.$ = "x"
        XCTAssertEqual(2, ints)
        XCTAssertEqual(2, strs)

        struct TwoBigInts {
            let a: Int64
            let b: Int64
        }

        XCTAssertEqual(1, sizeof(Int8))
        XCTAssertEqual(2, sizeof(Int16))
        XCTAssertEqual(4, sizeof(Int32))
        XCTAssertEqual(8, sizeof(Int64))
        XCTAssertEqual(16, sizeof(TwoBigInts))

        XCTAssertEqual(sizeof(Int8) + 1, sizeof(OneOf2<Int8, Int8>))
        XCTAssertEqual(sizeof(Int32) + 1, sizeof(OneOf2<Int16, Int32>))
        XCTAssertEqual(sizeof(Int16) + 1, sizeof(OneOf3<Int16, Int8, Int8>))
        XCTAssertEqual(sizeof(TwoBigInts) + 1, sizeof(OneOf3<TwoBigInts, Int8, Int8>))
    }

    func testPropertyChannel() {
        let xs: Int = 1
        let x = channelZPropertyValue(xs)
        let f: Channel<Void, Int> = x.desource() // read-only observable of channel x

        var changes = 0
        let subscription = f ∞> { _ in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, x.$ = (x.source.$ + 1))
        assertChanges(changes, x.$ = (3))
        assertRemains(changes, x.$ = (3))
        assertChanges(changes, x.$ = (9))

        subscription.cancel()
        assertRemains(changes, x.$ = (-1))
    }

    func testFieldChannelMapObservable() {
        let xs: Bool = true
        let x = channelZPropertyValue(xs)

        let xf: Channel<Void, Bool> = x.desource() // read-only observable of channel x

        _ = xf ∞> { (x: Bool) in return }

        let y = x.map({ "\($0)" })
        let yf: Channel<Void, String> = y.desource() // read-only observable of mapped channel y

        var changes = 0
        let fya: Receipt = yf ∞> { (x: String) in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, x.$ = (!x.source.$))
        assertChanges(changes, x.$ = (true))
        assertRemains(changes, x.$ = (true))
        assertChanges(changes, x.$ = (false))

        fya.cancel()
        assertRemains(changes, x.$ = (true))
    }

    func testFieldSieveChannelMapObservable() {
        let xs: Double = 1

        let x = channelZPropertyValue(xs)
        let xf: Channel<Void, Double> = x.desource() // read-only observable of channel x

        let fxa = xf ∞> { (x: Double) in return }

        let y = x.map({ "\($0)" })
        let yf: Channel<Void, String> = y.desource() // read-only observable of channel y

        var changes = 0
        let fya: Receipt = yf ∞> { (x: String) in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, x.$ = (x.source.$ + 1))
        assertRemains(changes, x.$ = (2))
        assertRemains(changes, x.$ = (2))
        assertChanges(changes, x.$ = (9))

        fxa.cancel()
        fya.cancel()
        assertRemains(changes, x.$ = (-1))
    }

    func testHeterogeneousConduit() {
        let a = ∞(Double(1.0))∞
        let b = ∞(Double(1.0))∞

        let pipeline = a <=∞=> b

        a.$ = 2.0
        XCTAssertEqual(2.0, a∞?)
        XCTAssertEqual(2.0, b∞?)

        b.$ = 3.0
        XCTAssertEqual(3.0, a∞?)
        XCTAssertEqual(3.0, b∞?)

        XCTAssertFalse(pipeline.cancelled)
        pipeline.cancel()
        XCTAssertTrue(pipeline.cancelled)

        // cancelled pipeline shouldn't send state anymore
        a.$ = 8
        b.$ = 9

        XCTAssertEqual(8, a∞?)
        XCTAssertEqual(9, b∞?)
    }

    func testHomogeneousConduit() {
        let a = ∞(Double(1.0))∞
        let b = ∞(UInt(1))∞

        let af = a.filter({ $0 >= Double(UInt.min) && $0 <= Double(UInt.max) }).map({ UInt($0) })
        let bf = b.map({ Double($0) })
        let pipeline = af.bind(bf)

        a.$ = 2.0
        XCTAssertEqual(2.0, a∞?)
        XCTAssertEqual(UInt(2), b∞?)

        b.$ = 3
        XCTAssertEqual(3.0, a∞?)
        XCTAssertEqual(UInt(3), b∞?)

        a.$ = 9.9
        XCTAssertEqual(9.0, a∞?)
        XCTAssertEqual(UInt(9), b∞?)

        a.$ = -5.0
        XCTAssertEqual(-5.0, a∞?)
        XCTAssertEqual(UInt(9), b∞?)

        a.$ = 8.1
        XCTAssertEqual(8.0, a∞?)
        XCTAssertEqual(UInt(8), b∞?)

        XCTAssertFalse(pipeline.cancelled)
        pipeline.cancel()
        XCTAssertTrue(pipeline.cancelled)

        // cancelled pipeline shouldn't send state anymore
        a.$ = 1
        b.$ = 2

        XCTAssertEqual(1, a∞?)
        XCTAssertEqual(UInt(2), b∞?)
    }

    func testUnstableConduit() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions = 0 }

        let a = ∞=(1)=∞
        let b = ∞=(2)=∞

        // this unstable pipe would never achieve equilibrium, and so relies on re-entrancy checks to halt the flow
        let af = a.map({ $0 + 1 })
        _ = af.conduit(b)

        a.$ = 2
        XCTAssertEqual(4, a∞?)
        XCTAssertEqual(4, b∞?)

        // these are all contingent on ChannelZReentrancyLimit

        b.$ = (10)
        XCTAssertEqual(11, a∞?)
        XCTAssertEqual(12, b∞?)

        a.$ = 99
        XCTAssertEqual(101, a∞?)
        XCTAssertEqual(101, b∞?)
    }


    func testAnyCombinations() {
        let a = ∞(Float(3.0))∞
        let b = ∞(UInt(7))∞
        let c = ∞(Bool(false))∞

        let d = c.map { "\($0)" }

        var lastFloat : Float = 0.0
        var lastString : String = ""

        _ = (a | b)
        _ = (a | b | c)

        let combo2: (Channel<(PropertySource<Float>, PropertySource<UInt>, PropertySource<Bool>), OneOf3<Float, UInt, String>>) = (a | b | d)

        combo2.receive { val in
            switch val {
            case .V1: return
            case .V2: return
            case .V3: return
            }
        }

        var changes = 0

        combo2.receive {
            changes += 1
            switch $0 {
            case .V1(let x): lastFloat = x
            case .V2: break
            case .V3(let x): lastString = x
            }
        }

        changes -= 3

        a.$ = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.$ = true
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.$ = false
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)
    }

//    func testList() {
//        func stringsToChars(f: Character->Void) -> String->Void {
//            return { (str: String) in for c in str.characters { f(c) } }
//        }
//
//        let strings: Channel<[String], String> = channelZSequence(["abc"])
//        let chars1 = strings.lift2(stringsToChars)
//        _ = strings.lift2 { (f: Character->Void) in { (str: String) in let _ = str.characters.map(f) } }
//
//        var buf: [Character] = []
//        chars1.receive({ buf += [$0] })
//        XCTAssertEqual(buf, ["a", "b", "c"])
//    }

    func testZippedObservable() {
        let a = ∞(Float(3.0))∞
        let b = ∞(UInt(7))∞
        let c = ∞(Bool(false))∞

        let d = c.map { "\($0)" }

        var lastFloat : Float = 0.0
        var lastString : String = ""

        let zip1 = (a ^ b)
        zip1 ∞> { (floatChange: Float, uintChange: UInt) in }

        let zip2: (Channel<(PropertySource<Float>, PropertySource<UInt>, PropertySource<Bool>), (Float, UInt, String)>) = (a ^ b ^ d)

        var changes = 0

        _ = zip2 ∞> { (floatChange: Float, uintChange: UInt, stringChange: String) in
            changes += 1
            lastFloat = floatChange
            lastString = stringChange
        }

        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(3.0), lastFloat)

        a.$ = a∞? + 1
        b.$ = b∞? + 1
        b.$ = b∞? + 1
        b.$ = b∞? + 1
        b.$ = b∞? + 1
        c.$ = true
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.$ = !c∞?
        c.$ = !c∞?
        c.$ = !c∞?
        c.$ = !c∞?

        a.$ = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(5.0), lastFloat)

        a.$ = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(6.0), lastFloat)

        a.$ = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(7.0), lastFloat)

    }

    func testEither() {
        let s1 = channelZSequence(1...3)
        let s2 = channelZSequence(["a", "b", "c", "d"])
        let channel = s1.either(s2)
        var values = (Array<OneOf2<Int, String>>(), Array<OneOf2<Int, String>>(), Array<OneOf2<Int, String>>())
        channel.receive({ values.0.append($0) })
        channel.receive({ values.1.append($0) })
        channel.receive({ values.2.append($0) })


        for vals in [values.0, values.1, values.2] {
            let msg = "bad values: \(vals)"

            if vals.count != 7 { return XCTFail(msg) }

            guard case .V1(let v0) = vals[0] where v0 == 1 else { return XCTFail(msg) }
            guard case .V1(let v1) = vals[1] where v1 == 2 else { return XCTFail(msg) }
            guard case .V1(let v2) = vals[2] where v2 == 3 else { return XCTFail(msg) }
            guard case .V2(let v3) = vals[3] where v3 == "a" else { return XCTFail(msg) }
            guard case .V2(let v4) = vals[4] where v4 == "b" else { return XCTFail(msg) }
            guard case .V2(let v5) = vals[5] where v5 == "c" else { return XCTFail(msg) }
            guard case .V2(let v6) = vals[6] where v6 == "d" else { return XCTFail(msg) }
        }
    }

    func testZippedGenerators() {
        let range = 1...6
        let nums = channelZSequence(1...3) + channelZSequence(4...5) + channelZSequence([6])
        let strs = channelZSequence(range.map({ NSNumberFormatter.localizedStringFromNumber($0, numberStyle: NSNumberFormatterStyle.SpellOutStyle) }).map({ $0 as String }))
        var numstrs: [(Int, String)] = []
        let zipped: Channel<(((Range<Int>, Range<Int>), [Int]), [String]), (Int, String)> = (nums ^ strs)
        zipped.receive({ numstrs += [$0] })
        XCTAssertEqual(numstrs.map({ $0.0 }), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(numstrs.map({ $0.1 }), ["one", "two", "three", "four", "five", "six"])
    }

//    func testMixedCombinations() {
//        let a = (∞(Int(0.0))∞).subsequent()
//
//        let and: Channel<Void, (Int, Int, Int, Int)> = (a ^ a ^ a ^ a).desource()
//        var andx = 0
//        and.receive({ _ in andx += 1 })
//
//        let or: Channel<Void, OneOf4<Int, Int, Int, Int>> = (a | a | a | a).desource()
//        var orx = 0
//        or.receive({ _ in orx += 1 })
//
//        let andor: Channel<Void, OneOf4<(Int, Int), (Int, Int), (Int, Int), Int>> = (a ^ a | a ^ a | a ^ a | a).desource() // typed due to slow compile
//
//        let o1 = a
//        let o2 = o1 | a
//        let o3 = o2 | a
//        let o4 = o3 | a
//        let o5 = o4 | a
//        let o6 = o5 | a
//        let o7 = o6 | a
//        let o8 = o7 | a
//        let o9 = o8 | a
//        let o10 = o9 | a
//        let o11 = o10 | a
//        let o12 = o11 | a
//        let o13 = o12 | a
//        let o14 = o13 | a
//        let o15 = o14 | a
//        let o16 = o15 | a
//        let o17 = o16 | a
//        let o18 = o17 | a
//        let o19 = o18 | a
//        let o20 = o19 | a
//
//        // statically check the type
//        let _: Channel<Void, OneOf20<Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int>> = o20.desource()
//
//        // too complex
//        // let _: Channel<Void, OneOf20<Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int>> = (a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a).desource()
//
//        var andorx = 0
//        andor.receive({ _ in andorx += 1 })
//
//        XCTAssertEqual(0, andx)
//        XCTAssertEqual(0, orx)
//        XCTAssertEqual(0, andorx)
//
//        a.source.$ += 1
//
//        XCTAssertEqual(1, andx, "last and fires a single and change")
//        XCTAssertEqual(4, orx, "each or four")
//        XCTAssertEqual(4, andorx, "four groups in mixed")
//
//        a.source.$ += 1
//
//        XCTAssertEqual(2, andx)
//        XCTAssertEqual(8, orx)
//        XCTAssertEqual(8, andorx)
//    }

    func testPropertyChannelSieve() {
        let stringz = PropertySource("").channelZState().sieve().new().subsequent()
        var strs: [String] = []

        stringz.receive({ strs.append($0) })

        stringz.$ = "a"
        stringz.$ = "c"
        XCTAssertEqual(2, strs.count)

        stringz.$ = "d"
        XCTAssertEqual(3, strs.count)

        stringz.$ = "d"
        XCTAssertEqual(3, strs.count) // change to self shouldn't up the count
    }

    func testMultipleReceiversOnPropertyChannel() {
        let prop = PropertySource(111).channelZState()

        var counts = (0, 0, 0)
        prop.receive { _ in counts.0 += 1 }
        prop.receive { _ in counts.1 += 1 }
        prop.receive { _ in counts.2 += 1 }

        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(1, counts.2)
        prop.$ = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.$ = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
    }

    func testMultipleReceiversOnSievedPropertyChannel() {
        let prop = PropertySource(111).channelZState().sieve() // also works
//        let prop = PropertySource(111).channelZState().sieve(!=).new()

        var counts = (0, 0, 0)
        prop.receive { _ in counts.0 += 1 }
        prop.receive { _ in counts.1 += 1 }
        prop.receive { _ in counts.2 += 1 }

        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(1, counts.2)
        prop.$ = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.$ = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.$ = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
        prop.$ = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
    }

    func XXXtestDropWithMultipleReceivers() {
        let prop: Channel<PropertySource<Int>, Int> = channelZPropertyValue(0)
        XCTAssertEqual(24, sizeofValue(prop))
        let dropped = prop.dropFirst(3)
        XCTAssertEqual(24, sizeofValue(dropped))

        var values = (Array<Int>(), Array<Int>(), Array<Int>())
        dropped.receive({ values.0.append($0) })
        dropped.receive({ values.1.append($0) })
        dropped.receive({ values.2.append($0) })

        XCTAssertEqual(24, sizeofValue(values))
        for i in 1...9 { prop.$ = i }
        XCTAssertEqual(24, sizeofValue(values))

        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.0)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.1)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.2)
    }
}

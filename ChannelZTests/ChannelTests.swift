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
//        return invocation?.selector == #selector(ChannelTests.testJacket) ? super.invokeTest() : print("skipping test", name)
        return super.invokeTest()
    }


    override internal func tearDown() {
        super.tearDown()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_CHANNELZ
            XCTAssertEqual(0, ChannelZ.ChannelZReentrantReceptions.get(), "unexpected reentrant receptions detected")
            ChannelZ.ChannelZReentrantReceptions.set(0)
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
public func channelZSequence<S, T>(_ from: S) -> Channel<S, S.Iterator.Element> where S: Sequence, S.Iterator.Element == T {
    return from.channelZSequence()
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
public func seqZ<T>(_ from: T...) -> Channel<[T], T> {
    return from.channelZSequence()
}

// TODO make a spec with each of https://github.com/ReactiveX/RxScala/blob/0.x/examples/src/test/scala/rx/lang/scala/examples/RxScalaDemo.scala


private func feedZ<T, U, S>(_ input: [T], setup: (Channel<ValueTransceiver<T>, T>) -> Channel<S, U>) -> [U] {
    let channel = channelZPropertyValue(input[0])
    let transformed = setup(channel)

    // store the output; we store 3 separate outputs just to check that EffectSources work correctly
    var outputs = ([U](), [U](), [U]())
    let r0 = transformed.receive { outputs.0.append($0) }
    defer { r0.cancel() }

    let r1 = transformed.receive { outputs.1.append($0) }
    defer { r1.cancel() }

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
private func feedX<T, U>(_ seq: [T], f: ([T]) -> U) -> U {
    return f(seq)
}


public extension XCTestCase {
    func XCTAssertDeepEqual(_ a1: [[Int]], _ a2: [[Int]], line: UInt = #line) {
        XCTAssertEqual(a1.count, a2.count, line: line)
        for (s1, s2) in zip(a1, a2) {
            XCTAssertEqual(s1, s2, line: line)
        }
    }
}


class ChannelTests : ChannelTestCase {
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
            XCTAssertEqual(xpct, feedX(nums) { $0.reduce(0, +) })
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
            XCTAssertDeepEqual(xpct, feedX(nums + [3]) { $0.split(whereSeparator: three) }.map(Array.init))
            XCTAssertDeepEqual([[1, 2], [2, -1]], feedZ(nums + [3]) { $0.split(isSeparator: three) })
        }

        do {
            let xpct = [[1, 2], [], [2, -1]]
            XCTAssertDeepEqual(xpct, nums.split(omittingEmptySubsequences: false, whereSeparator: three).map(Array.init))
            XCTAssertDeepEqual(xpct, feedZ(nums + [3]) { $0.split(allowEmptySlices: true, isSeparator: three) })
        }

        XCTAssertDeepEqual([[1, 2], []], nums.split(maxSplits: 2, omittingEmptySubsequences: false, whereSeparator: three).dropLast().map(Array.init))
        XCTAssertDeepEqual([[1, 2], []], feedZ(nums + [3]) { $0.split(2, allowEmptySlices: true, isSeparator: three) })

        XCTAssertDeepEqual([[1, 2]], nums.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: three).dropLast().map(Array.init))
        XCTAssertDeepEqual([[1, 2]], feedZ(nums + [3]) { $0.split(1, allowEmptySlices: true, isSeparator: three) })

        XCTAssertEqual([1, 2, -1], feedZ(nums) { $0.changes(<) })

        XCTAssertEqual([1, 2, 3, 2, -1], feedZ(nums) { $0.presieve(!=).new() })

        XCTAssertDeepEqual([[1, 2, 3], [3, 2, -1]], feedZ(nums) { $0.buffer(3) })

        XCTAssertEqual([9, 1], feedZ(nums) { $0.partition(0, isPartition: >, combine: +) })

        XCTAssertEqual([6, 2], feedZ(nums) { $0.partition(0, includePartitions: false, isPartition: >, combine: +) })

        XCTAssertEqual([1, 1, 2, 2, 3, 3, 3, 3, 2, 2, -1, -1], feedZ(nums) { $0.flatMap { seqZ($0) + seqZ($0) } })

//        XCTAssertEqual([1, 1, 4, 4, 9, 9, 9, 9, 4, 4, 1, 1], feedZ(nums) { $0.flatMap { seqZ($0) & seqZ($0) }.map(*) })

        let _ = feedZ(nums) { $0.flatMap { seqZ($0) | seqZ($0).map(String.init) } }

    }

    func testZipImplementations() {
        let z1 = transceive(1).new()
        let z2 = transceive("1").new()
        let z3 = transceive(true).new()
        let z4 = transceive(()).new()

        var items: [(index: Int, pulse: (((Int, String), Bool), Void))] = []
        let zz = z1.zip(z2).zip(z3).zip(z4).enumerate()

        zz.receive {
            items.append($0)
        }

        XCTAssertEqual(1, items.count)
        XCTAssertEqual(0, items.last?.index)

        z1.value = 2
        z2.value = "2"
        z3.value = true
        z4.value = Void()

        XCTAssertEqual(2, items.count)
        XCTAssertEqual(1, items.last?.index)

        z1.value = 3
        z1.value = 4

        z4.value = Void()
        z4.value = Void()

        z3.value = true
        z3.value = true

        z2.value = "4"
        z2.value = "5"

        z4.value = Void()
        z3.value = true
        z2.value = "3"

        XCTAssertEqual(4, items.count)
        XCTAssertEqual(3, items.last?.index)

        z1.value = 5

        XCTAssertEqual(5, items.count)
        XCTAssertEqual(4, items.last?.index) // last enum
    }

    func testEnumerateCount() {
        let z1 = transceive(1).new()
        let z2 = transceive("1").new()
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

        z1.value += 1

        XCTAssertEqual(counts.0, counts.1)
        XCTAssertEqual(counts.0, counts.2)
        XCTAssertEqual(counts.0, counts.3)

        z2.value += "1"

        XCTAssertEqual(counts.0, counts.1)
        XCTAssertEqual(counts.0, counts.2)
        XCTAssertEqual(counts.0, counts.3)
    }

    func testEnumerations() {
        let z1 = transceive(true).new()
        let z2 = transceive(1).new()
        typealias Item = (index: Int, pulse: (index: Int, pulse: (index: Int, pulse: Choose2<Bool, Int>)))

        let enums = z1.either(z2).enumerate().enumerate().enumerate()
//        let enums = enumberate(enumberate(enumberate(z1.either(z2))))
        var elements: [Item] = []

        XCTAssertEqual(0, elements.count)
//        enums.receive({ print("receive 1", $0) })
//        enums.receive({ print("receive 2", $0) })
        enums.receive({ elements.append($0) })
        XCTAssertEqual(2, elements.count)

        XCTAssertEqual(0, elements.first?.index)
        XCTAssertEqual(0, elements.first?.pulse.index)
        XCTAssertEqual(0, elements.first?.pulse.pulse.index)

        XCTAssertEqual(1, elements.last?.index)
        XCTAssertEqual(1, elements.last?.pulse.index)
        XCTAssertEqual(1, elements.last?.pulse.pulse.index)

        z1.value = true

        XCTAssertEqual(2, elements.last?.index)
        XCTAssertEqual(2, elements.last?.pulse.index)
        XCTAssertEqual(2, elements.last?.pulse.pulse.index)

        z2.value = 1

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
        for x in send { bools.stream.value = x }
        XCTAssertEqual(send, bools.caught)

        // test that sending some mixed values will sieve and constrain to the capacity
        let mixed = [false, true, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false]
        for x in mixed { bools.stream.value = x }
        XCTAssertEqual(send, bools.caught)
    }

//    func testChannelTraps() {
//        let seq = [1, 2, 3, 4, 5]
//        let seqz = channelZSequence(seq).precedent()
//        let trapz = seqz.trap(10)
//        let values = trapz.caught.map({ $0.old != nil ? [$0.old!.item, $0.new.item] : [$0.new.item] })
//        XCTAssertEqual(values, [[1], [1, 2], [2, 3], [3, 4], [4, 5]])
//    }

    func testGenerators() {
        let seq = [true, false, true, false, true]

//        let gfun1 = Channel(from: GeneratorOf(seq.generate())) // GeneratorChannel with generator
//        let trap1 = gfun1.trap(3)
//        XCTAssertEqual(seq[2...4], trap1.caught[0...2], "trap should contain the last 3 elements of the sequence generator")

        let gfun2 = channelZSequence(seq) // GeneratorChannel with sequence
        let trap2 = gfun2.trap(3)
        XCTAssertEqual(seq[2...4], trap2.caught[0...2], "trap should contain the last 3 elements of the sequence generator")

        let trapped = (channelZSequence(1...5) ^ channelZSequence(6...10)).trap(1000)
        
        XCTAssertDeepEqual(trapped.caught.map({ [$0, $1] }), [[1, 6], [2, 7], [3, 8], [4, 9], [5, 10]]) // tupes aren't equatable

        // observable concatenation
        // the equivalent of ReactiveX's Range
        let merged = (channelZSequence(1...3) + channelZSequence(3...5) + channelZSequence(2...6)).trap(1000)
        XCTAssertEqual(merged.caught, [1, 2, 3, 3, 4, 5, 2, 3, 4, 5, 6])

        // the equivalent of ReactiveX's Repeat
        XCTAssertEqual(channelZSequence(repeatElement("A", count: 10)).trap(4).caught, ["A", "A", "A", "A"])
        XCTAssertEqual(channelZSequence(repeatElement("A", count: 10)).subsequent().trap(4).caught, [])
    }

    func testMergedUnreceive() {
        func coinFlip() -> Void? {
            if arc4random_uniform(100) > 50 {
                return Void()
            } else {
                return nil
            }
        }

        typealias S1 = CountableClosedRange<Int>
        typealias S2 = AnyReceiver<(Float)>
        typealias S3 = ()->Void?

        let o1: Channel<S1, Int> = channelZSequence(1...3)
        let o2: Channel<S2, Int> = channelZSink(Float.self).map({ Int($0) })
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
        guard let stream = InputStream(fileAtPath: #file) else {
            return XCTFail("could not open \(#file)")
        }

        weak var xpc: XCTestExpectation? = expectation(description: "input stream")

        let allData = NSMutableData()
        let obv = stream.channelZStream()
        var openCount = 0
        var closeCount = 0
        var count = 0
        let sub = obv.receive { switch $0 {
            case .opened:
                openCount += 1
            case .data(let d):
                count += d.count
                allData.append(NSData(bytes: d, length: d.count) as Data)
            case .error(let e):
                XCTFail(String(describing: e))
                xpc?.fulfill()
            case .closed:
                closeCount += 1
                xpc?.fulfill()
            }
        }

        stream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        stream.open()

        waitForExpectations(timeout: 1, handler: { _ in })

        XCTAssertEqual(1, openCount)
        XCTAssertEqual(1, closeCount)
        XCTAssertGreaterThan(count, 1000)
        sub.cancel()

        if let str = NSString(data: allData as Data, encoding: String.Encoding.utf8.rawValue) {
            let advice = "Begin at the beginning, and go on till you come to the end: then stop"
            XCTAssertTrue(str.contains(advice))
        } else {
            XCTFail("could not create string from data in \(#file)")
        }
    }

    func testFilterChannel() {
        let obv = channelZSink(Int.self)

        var count = 0
        _ = obv.filter({ $0 > 0 }).receive({ _ in count += 1 })

        let numz = -10...3
        for x in numz { obv.source.receive(x) }

        XCTAssertEqual(3, count)
    }

    func testMapChannel() {
        let obv = channelZSink(Int.self)

        var count = 0

        let isMoreThanOneCharacter: (String)->Bool = { NSString(string: $0).length >= 2 }

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
            numberz.source.value = num
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
        let numberz = transceive(0).new()

        let sum = numberz.reduce(0, combine: +)

        var raws = (Array<Int>(), Array<Int>())
        let r0 = numberz.receive { x in raws.0.append(x) }

        var sums = (Array<Int>(), Array<Int>(), Array<Int>())
        let r1 = sum.receive { x in sums.0.append(x) }
        let r2 = sum.receive { x in sums.1.append(x) }
        let r3 = sum.receive { x in sums.2.append(x) }

        let r4 = numberz.receive { x in raws.1.append(x) }

        for i in 1...7 { numberz.value = i }

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
        let prop = transceive("")
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
        for i in 1...10 { numberz.value = i }
        // note that 9 & 10 are dropped because they don't satisfy the buffering requirement
        XCTAssertDeepEqual([[0, 1, 2], [3, 4, 5], [6, 7, 8]], items) // , "Bad buffered items: \(items)")
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

        for i in 1...100 { numberz.value = i }
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

    func channelResults<S: StateReceiverType, T>(_ channel: Channel<S, T>, items: [S.Pulse]) -> [T] {
        var results: [T] = []
        let _ = channel.receive({ results.append($0) })
        for item in items {
            channel.source.receive(item)
        }
        return results
    }

//    func testPartitionStrings() {
//        func isSpace(_ buf: String, str: String)->Bool { return str == " " }
//
//        let withPartition = channelResults(channelZPropertyValue("").partition("", isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
//        XCTAssertEqual(["1 ", "12 ", "123 ", "1234 ", "12345 ", "123456 ", "1234567 ", "12345678 ", "123456789 "], withPartition)
//
//        let withoutPartition = channelResults(channelZPropertyValue("").partition("", includePartitions: false, isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
//        XCTAssertEqual(["1", "12", "123", "1234", "12345", "123456", "1234567", "12345678", "123456789"], withoutPartition)
//
//    }

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
        person.lname.value = "Prud'hommeaux"
        person.fname.value = "Marc"
        person.fname.value = "Marc"
        person.lname.value = "Prud'hommeaux"

        XCTAssertFalse(rcpt.cancelled)
        rcpt.cancel()
        XCTAssertTrue(rcpt.cancelled)

        person.fname.value = "John"
        person.lname.value = "Doe"

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

    func testValueTransceivers() {
        let propa = ValueTransceiver("A")
        let propb = ValueTransceiver("B")

        let rcpt = ∞propa <=∞=> ∞propb

        XCTAssertEqual("A", propa.value)
        XCTAssertEqual("A", propb.value)

        propa.value = "X"
        XCTAssertEqual("X", propa.value)
        XCTAssertEqual("X", propb.value)

        propb.value = "Y"
        XCTAssertEqual("Y", propa.value)
        XCTAssertEqual("Y", propb.value)

        rcpt.cancel()

        propa.value = "Z"
        XCTAssertEqual("Z", propa.value)
        XCTAssertEqual("Y", propb.value, "cancelled receiver should not have channeled the value")
    }

    func testConversionChannels() {
        let propa = channelZPropertyValue(0)
        let propb = channelZPropertyValue(0.0)

        let rcpt = propa.map({ Double($0) }) <=∞=> propb.map({ Int($0) })

        XCTAssertEqual(0, propa.source.value)
        XCTAssertEqual(0.0, propb.source.value)

        propa.source.value += 1
        XCTAssertEqual(1, propa.source.value)
        XCTAssertEqual(1.0, propb.source.value)

        propb.source.value += 1.2
        XCTAssertEqual(2, propa.source.value)
        XCTAssertEqual(2.0, propb.source.value, "rounded value should have been mapped back")

        rcpt.cancel()

        propa.source.value -= 1
        XCTAssertEqual(1, propa.source.value)
        XCTAssertEqual(2.0, propb.source.value, "cancelled receiver should not have channeled the value")
    }

    func testUnstableChannels() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let _: ValueTransceiver<Int> = 0∞ // just to show the postfix signature
        let propa: Channel<ValueTransceiver<Int>, Int> = ∞0∞
        let propb: Channel<ValueTransceiver<Int>, Int> = ∞0∞

        let rcpt = propb.map({ $0 + 1 }) <=∞=> propa

        XCTAssertEqual(1, propa.source.value)
        XCTAssertEqual(1, propb.source.value)

        // these values are all contingent on the setting of ChannelZReentrancyLimit
        XCTAssertEqual(1, ChannelZReentrancyLimit)

        propa.source.value += 1
        XCTAssertEqual(4, propa.source.value)
        XCTAssertEqual(3, propb.source.value)

        propb.source.value += 1
        XCTAssertEqual(6, propa.source.value)
        XCTAssertEqual(6, propb.source.value)

        rcpt.cancel()

        propa.source.value -= 1
        XCTAssertEqual(5, propa.source.value)
        XCTAssertEqual(6, propb.source.value, "cancelled receiver should not have channeled the value")

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
            case .v1(.v1): ints += 1
            case .v1(.v2): strs += 1
            case .v2: flts += 1
            }
        }

        XCTAssertEqual(1, ints)
        XCTAssertEqual(1, strs)

        a.source.value += 1
        XCTAssertEqual(2, ints)
        XCTAssertEqual(1, strs)

        b.source.value = "x"
        XCTAssertEqual(2, ints)
        XCTAssertEqual(2, strs)

        struct TwoBigInts {
            let a: Int64
            let b: Int64
        }

        XCTAssertEqual(1, MemoryLayout<Int8>.size)
        XCTAssertEqual(2, MemoryLayout<Int16>.size)
        XCTAssertEqual(4, MemoryLayout<Int32>.size)
        XCTAssertEqual(8, MemoryLayout<Int64>.size)
        XCTAssertEqual(16, MemoryLayout<TwoBigInts>.size)

        XCTAssertEqual(MemoryLayout<Int8>.size + 1, MemoryLayout<Choose2<Int8, Int8>>.size)
        XCTAssertEqual(MemoryLayout<Int32>.size + 1, MemoryLayout<Choose2<Int16, Int32>>.size)
        XCTAssertEqual(MemoryLayout<Int16>.size + 1, MemoryLayout<Choose3<Int16, Int8, Int8>>.size)
        XCTAssertEqual(MemoryLayout<TwoBigInts>.size + 1, MemoryLayout<Choose3<TwoBigInts, Int8, Int8>>.size)
    }

    func testPropertyChannel() {
        let xs: Int = 1
        let x = channelZPropertyValue(xs)
        let f: Channel<Void, Int> = x.desource() // read-only observable of channel x

        var changes = 0
        let subscription = f ∞> { _ in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, x.value = (x.source.value + 1))
        assertChanges(changes, x.value = (3))
        assertRemains(changes, x.value = (3))
        assertChanges(changes, x.value = (9))

        subscription.cancel()
        assertRemains(changes, x.value = (-1))
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
        assertChanges(changes, x.value = (!x.source.value))
        assertChanges(changes, x.value = (true))
        assertRemains(changes, x.value = (true))
        assertChanges(changes, x.value = (false))

        fya.cancel()
        assertRemains(changes, x.value = (true))
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
        assertChanges(changes, x.value = (x.source.value + 1))
        assertRemains(changes, x.value = (2))
        assertRemains(changes, x.value = (2))
        assertChanges(changes, x.value = (9))

        fxa.cancel()
        fya.cancel()
        assertRemains(changes, x.value = (-1))
    }

    func testHeterogeneousConduit() {
        let a = ∞(Double(1.0))∞
        let b = ∞(Double(1.0))∞

        let pipeline = a <=∞=> b

        a.value = 2.0
        XCTAssertEqual(2.0, a∞?)
        XCTAssertEqual(2.0, b∞?)

        b.value = 3.0
        XCTAssertEqual(3.0, a∞?)
        XCTAssertEqual(3.0, b∞?)

        XCTAssertFalse(pipeline.cancelled)
        pipeline.cancel()
        XCTAssertTrue(pipeline.cancelled)

        // cancelled pipeline shouldn't send state anymore
        a.value = 8
        b.value = 9

        XCTAssertEqual(8, a∞?)
        XCTAssertEqual(9, b∞?)
    }

    func testHomogeneousConduit() {
        let a = ∞(Double(1.0))∞
        let b = ∞(UInt(1))∞

        let af = a.filter({ $0 >= Double(UInt.min) && $0 <= Double(UInt.max) }).map({ UInt($0) })
        let bf = b.map({ Double($0) })
        let pipeline = af.bind(bf)

        a.value = 2.0
        XCTAssertEqual(2.0, a∞?)
        XCTAssertEqual(UInt(2), b∞?)

        b.value = 3
        XCTAssertEqual(3.0, a∞?)
        XCTAssertEqual(UInt(3), b∞?)

        a.value = 9.9
        XCTAssertEqual(9.0, a∞?)
        XCTAssertEqual(UInt(9), b∞?)

        a.value = -5.0
        XCTAssertEqual(-5.0, a∞?)
        XCTAssertEqual(UInt(9), b∞?)

        a.value = 8.1
        XCTAssertEqual(8.0, a∞?)
        XCTAssertEqual(UInt(8), b∞?)

        XCTAssertFalse(pipeline.cancelled)
        pipeline.cancel()
        XCTAssertTrue(pipeline.cancelled)

        // cancelled pipeline shouldn't send state anymore
        a.value = 1
        b.value = 2

        XCTAssertEqual(1, a∞?)
        XCTAssertEqual(UInt(2), b∞?)
    }

    /// Explicitly checks the signatures of the `bind` variants.
    func testChannelBindSignatures() {
        do {
            let c1: Channel<ValueTransceiver<String>, Int> = transceive("X").map({ _ in 1 })
            let c2: Channel<ValueTransceiver<Int>, String> = transceive(1).map({ _ in "X" })
            c1.bind(c2)
            c1.bindPulseToPulse(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String>, Int?> = transceive("X").map({ _ in 2 as Int? })
            let c2: Channel<ValueTransceiver<Int?>, String> = transceive(1 as Int?).map({ _ in "X" })
            c1.bind(c2)
            c1.bindPulseToOptionalPulse(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String?>, Int> = transceive("X" as String?).map({ _ in 2 })
            let c2: Channel<ValueTransceiver<Int>, String?> = transceive(1).map({ _ in "X" as String? })
            c1.bind(c2)
            c1.bindOptionalPulseToPulse(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String?>, Int?> = transceive("X" as String?).map({ _ in 2 as Int? })
            let c2: Channel<ValueTransceiver<Int?>, String?> = transceive(1 as Int?).map({ _ in "X" })
            c1.bind(c2)
            c1.bindOptionalPulseToOptionalPulse(c2)
        }
    }

    /// Explicitly checks the signatures of the `link` variants.
    func testChannelLinkSignatures() {
        do {
            let c1: Channel<ValueTransceiver<String>, Mutation<Int>> = transceive("X").map({ _ in Mutation(old: 1, new: 2) })
            let c2: Channel<ValueTransceiver<Int>, Mutation<String>> = transceive(1).map({ _ in Mutation(old: "", new: "X") })
            c1.link(c2)
            c1.linkStateToState(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String>, Mutation<Int?>> = transceive("X").map({ _ in Mutation(old: 1 as Int??, new: 2 as Int?) })
            let c2: Channel<ValueTransceiver<Int?>, Mutation<String>> = transceive(1 as Int?).map({ _ in Mutation(old: "", new: "X") })
            c1.link(c2)
            c1.linkStateToOptionalState(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String?>, Mutation<Int>> = transceive("X" as String?).map({ _ in Mutation(old: 1, new: 2) })
            let c2: Channel<ValueTransceiver<Int>, Mutation<String?>> = transceive(1).map({ _ in Mutation(old: "" as String??, new: "X" as String?) })
            c1.link(c2)
            c1.linkOptionalStateToState(c2)
        }

        do {
            let c1: Channel<ValueTransceiver<String?>, Mutation<Int?>> = transceive("X" as String?).map({ _ in Mutation(old: 1 as Int??, new: 2 as Int?) })
            let c2: Channel<ValueTransceiver<Int?>, Mutation<String?>> = transceive(1 as Int?).map({ _ in Mutation(old: "" as String??, new: "X" as String?) })
            c1.link(c2)
            c1.linkOptionalStateToOptionalState(c2)
        }
    }

    func testUnstableConduit() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let a = ∞=(1)=∞
        let b = ∞=(2)=∞

        // this unstable pipe would never achieve equilibrium, and so relies on re-entrancy checks to halt the flow
        let af = a.map({ $0 + 1 })
        _ = af.conduit(b)

        a.value = 2
        XCTAssertEqual(4, a∞?)
        XCTAssertEqual(4, b∞?)

        // these are all contingent on ChannelZReentrancyLimit

        b.value = (10)
        XCTAssertEqual(11, a∞?)
        XCTAssertEqual(12, b∞?)

        a.value = 99
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

        let combo2: (Channel<(ValueTransceiver<Float>, ValueTransceiver<UInt>, ValueTransceiver<Bool>), Choose3<Float, UInt, String>>) = (a | b | d)

        combo2.receive { val in
            switch val {
            case .v1: return
            case .v2: return
            case .v3: return
            }
        }

        var changes = 0

        combo2.receive {
            changes += 1
            switch $0 {
            case .v1(let x): lastFloat = x
            case .v2: break
            case .v3(let x): lastString = x
            }
        }

        changes -= 3

        a.value = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.value = true
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.value = false
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

        let zip2: (Channel<(ValueTransceiver<Float>, ValueTransceiver<UInt>, ValueTransceiver<Bool>), (Float, UInt, String)>) = (a ^ b ^ d)

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

        a.value = a∞? + 1
        b.value = b∞? + 1
        b.value = b∞? + 1
        b.value = b∞? + 1
        b.value = b∞? + 1
        c.value = true
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(4.0), lastFloat)

        c.value = !c∞?
        c.value = !c∞?
        c.value = !c∞?
        c.value = !c∞?

        a.value = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(5.0), lastFloat)

        a.value = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("true", lastString)
        XCTAssertEqual(Float(6.0), lastFloat)

        a.value = a∞? + 1
        changes = changes - 1
        XCTAssertEqual(0, changes)
        XCTAssertEqual("false", lastString)
        XCTAssertEqual(Float(7.0), lastFloat)

    }

    func testEither() {
        let s1 = channelZSequence(1...3)
        let s2 = channelZSequence(["a", "b", "c", "d"])
        let channel = s1.either(s2)
        var values = (Array<Choose2<Int, String>>(), Array<Choose2<Int, String>>(), Array<Choose2<Int, String>>())
        channel.receive({ values.0.append($0) })
        channel.receive({ values.1.append($0) })
        channel.receive({ values.2.append($0) })


        for vals in [values.0, values.1, values.2] {
            let msg = "bad values: \(vals)"

            if vals.count != 7 { return XCTFail(msg) }

            guard case .v1(let v0) = vals[0] , v0 == 1 else { return XCTFail(msg) }
            guard case .v1(let v1) = vals[1] , v1 == 2 else { return XCTFail(msg) }
            guard case .v1(let v2) = vals[2] , v2 == 3 else { return XCTFail(msg) }
            guard case .v2(let v3) = vals[3] , v3 == "a" else { return XCTFail(msg) }
            guard case .v2(let v4) = vals[4] , v4 == "b" else { return XCTFail(msg) }
            guard case .v2(let v5) = vals[5] , v5 == "c" else { return XCTFail(msg) }
            guard case .v2(let v6) = vals[6] , v6 == "d" else { return XCTFail(msg) }
        }
    }

//    func testZippedGenerators() {
//        let range = 1...6
//        let nums = channelZSequence(1...3) + channelZSequence(4...5) + channelZSequence([6])
//        let strs = channelZSequence(range.map({ NumberFormatter.localizedStringFromNumber(NSNumber($0), numberStyle: NumberFormatter.Style.SpellOutStyle) }).map({ $0 as String }))
//        var numstrs: [(Int, String)] = []
//        let zipped: Channel<(((Range<Int>, Range<Int>), [Int]), [String]), (Int, String)> = (nums ^ strs)
//        zipped.receive({ numstrs += [$0] })
//        XCTAssertEqual(numstrs.map({ $0.0 }), [1, 2, 3, 4, 5, 6])
//        XCTAssertEqual(numstrs.map({ $0.1 }), ["one", "two", "three", "four", "five", "six"])
//    }

//    func testMixedCombinations() {
//        let a = (∞(Int(0.0))∞).subsequent()
//
//        let and: Channel<Void, (Int, Int, Int, Int)> = (a ^ a ^ a ^ a).desource()
//        var andx = 0
//        and.receive({ _ in andx += 1 })
//
//        let or: Channel<Void, Choose4<Int, Int, Int, Int>> = (a | a | a | a).desource()
//        var orx = 0
//        or.receive({ _ in orx += 1 })
//
//        let andor: Channel<Void, Choose4<(Int, Int), (Int, Int), (Int, Int), Int>> = (a ^ a | a ^ a | a ^ a | a).desource() // typed due to slow compile
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
//        let _: Channel<Void, Choose20<Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int>> = o20.desource()
//
//        // too complex
//        // let _: Channel<Void, Choose20<Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int>> = (a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a | a).desource()
//
//        var andorx = 0
//        andor.receive({ _ in andorx += 1 })
//
//        XCTAssertEqual(0, andx)
//        XCTAssertEqual(0, orx)
//        XCTAssertEqual(0, andorx)
//
//        a.source.value += 1
//
//        XCTAssertEqual(1, andx, "last and fires a single and change")
//        XCTAssertEqual(4, orx, "each or four")
//        XCTAssertEqual(4, andorx, "four groups in mixed")
//
//        a.source.value += 1
//
//        XCTAssertEqual(2, andx)
//        XCTAssertEqual(8, orx)
//        XCTAssertEqual(8, andorx)
//    }

    func testPropertyChannelSieve() {
        let stringz = ValueTransceiver("").transceive().sieve().new().subsequent()
        var strs: [String] = []

        stringz.receive({ strs.append($0) })

        stringz.value = "a"
        stringz.value = "c"
        XCTAssertEqual(2, strs.count)

        stringz.value = "d"
        XCTAssertEqual(3, strs.count)

        stringz.value = "d"
        XCTAssertEqual(3, strs.count) // change to self shouldn't up the count
    }

    func testMultipleReceiversOnPropertyChannel() {
        let prop = ValueTransceiver(111).transceive()

        var counts = (0, 0, 0)
        prop.receive { _ in counts.0 += 1 }
        prop.receive { _ in counts.1 += 1 }
        prop.receive { _ in counts.2 += 1 }

        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(1, counts.2)
        prop.value = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.value = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
    }

    func testMultipleReceiversOnSievedPropertyChannel() {
        let prop = ValueTransceiver(111).transceive().sieve() // also works
//        let prop = ValueTransceiver(111).transceive().sieve(!=).new()

        var counts = (0, 0, 0)
        prop.receive { _ in counts.0 += 1 }
        prop.receive { _ in counts.1 += 1 }
        prop.receive { _ in counts.2 += 1 }

        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(1, counts.2)
        prop.value = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.value = 123
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)
        prop.value = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
        prop.value = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
    }

    func testDropWithMultipleReceivers() {
        let prop: Channel<ValueTransceiver<Int>, Int> = channelZPropertyValue(0)
        XCTAssertEqual(24, MemoryLayout.size(ofValue: prop))
        let dropped = prop.dropFirst(3)
        XCTAssertEqual(24, MemoryLayout.size(ofValue: dropped))

        var values = (Array<Int>(), Array<Int>(), Array<Int>())
        dropped.receive({ values.0.append($0) })
        dropped.receive({ values.1.append($0) })
        dropped.receive({ values.2.append($0) })

        XCTAssertEqual(24, MemoryLayout.size(ofValue: values))
        for i in 1...9 { prop.value = i }
        XCTAssertEqual(24, MemoryLayout.size(ofValue: values))

        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.0)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.1)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.2)
    }

    static var allTests = testCase([
        ("testAnalogousSequenceFunctions", testAnalogousSequenceFunctions),
        ("testZipImplementations", testZipImplementations),
        ("testEnumerateCount", testEnumerateCount),
        ("testEnumerations", testEnumerations),
        ("testTraps", testTraps),
        ("testGenerators", testGenerators),
        ("testMergedUnreceive", testMergedUnreceive),
        ("testStreamExtensions", testStreamExtensions),
        ("testFilterChannel", testFilterChannel),
        ("testMapChannel", testMapChannel),
        ("testSieveDistinct", testSieveDistinct),
        ("testSieveLastIncrementing", testSieveLastIncrementing),
        ("testReduceImmediate", testReduceImmediate),
        ("testReduceMultiple", testReduceMultiple),
        ("testEnumerateWithMultipleReceivers", testEnumerateWithMultipleReceivers),
        ("testBuffer", testBuffer),
        ("testReduceNumbers", testReduceNumbers),
        ("testFlatMapChannel", testFlatMapChannel),
        ("testFlatMapTransformChannel", testFlatMapTransformChannel),
        ("testPropertyReceivers", testPropertyReceivers),
        ("testValueTransceivers", testValueTransceivers),
        ("testConversionChannels", testConversionChannels),
        ("testUnstableChannels", testUnstableChannels),
        ("testEitherOr", testEitherOr),
        ("testPropertyChannel", testPropertyChannel),
        ("testFieldChannelMapObservable", testFieldChannelMapObservable),
        ("testFieldSieveChannelMapObservable", testFieldSieveChannelMapObservable),
        ("testHeterogeneousConduit", testHeterogeneousConduit),
        ("testHomogeneousConduit", testHomogeneousConduit),
        ("testChannelBindSignatures", testChannelBindSignatures),
        ("testChannelLinkSignatures", testChannelLinkSignatures),
        ("testUnstableConduit", testUnstableConduit),
        ("testAnyCombinations", testAnyCombinations),
        ("testZippedObservable", testZippedObservable),
        ("testEither", testEither),
        ("testPropertyChannelSieve", testPropertyChannelSieve),
        ("testMultipleReceiversOnPropertyChannel", testMultipleReceiversOnPropertyChannel),
        ("testMultipleReceiversOnSievedPropertyChannel", testMultipleReceiversOnSievedPropertyChannel),
        ("testDropWithMultipleReceivers", testDropWithMultipleReceivers),
        ])

    #if !os(Linux)
    // no-op function on non-Linux platforms
    static func testCase(_ values: Any) { }
    #endif
}

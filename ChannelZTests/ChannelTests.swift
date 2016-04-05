//
//  ChannelTests.swift
//  ChannelTests
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import XCTest
import ChannelZ

private func moreT<T>()->T { fatalError("you can't take less") }

extension StreamType {
    /// Test method that receives to the observable and returns any elements that are immediately sent to fresh receivers
    var immediateItems: [Element] {
        var items: [Element] = []
        receive({ items += [$0] }).cancel()
        return items
    }
}

/// Creates a Channel sourced by a `SequenceType` that will emit all its elements to new receivers
@warn_unused_result public func channelZSequence<S, T where S: SequenceType, S.Generator.Element == T>(from: S) -> Channel<S, S.Generator.Element> {
    return from.channelZSequence()
}

// TODO make a spec with each of https://github.com/ReactiveX/RxScala/blob/0.x/examples/src/test/scala/rx/lang/scala/examples/RxScalaDemo.scala


public class ChannelTests: XCTestCase {

    func testTraps() {
        let channel = ∞=false=∞
        // var src = channel.source
        let bools = channel.trap(10)

        // test that sending capacity distinct values will store those values
        let send = [true, false, true, false, true, false, true, false, true, false]
        for x in send { bools.stream.value = x }
        XCTAssertEqual(send, bools.values)

        // test that sending some mixed values will sieve and constrain to the capacity
        let mixed = [false, true, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false]
        for x in mixed { bools.stream.value = x }
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

        let trapped = (channelZSequence(1...5) & channelZSequence(6...10)).trap(1000)
        
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
        typealias S2 = SinkTo<(Float)>
        typealias S3 = ()->Void?

        let o1: Channel<S1, Int> = channelZSequence(1...3)
        let o2: Channel<S2, Int> = channelZSink(Float).map({ Int($0) })
        let o3: Channel<S3, Void> = channelZClosure(coinFlip)

        let cc: Channel<(((S1, S2), S2), S2), Int> = o1 + o2 + o2 + o2

        return // TODO: re-implement
        // examples of type signatures
        let _: Channel<((S1, S2), (S2, S2)), Int> = (o1 + o2) + (o2 + o2)
        let _: Channel<Void, Int> = cc.desource()
//        let _: Channel<(S1, S2, S1), (Int?, Int?, Int?)> = o1 | o2 | o1
//        let _: Channel<(S1, S2, S3), (Int, Int, Void)> = o1 & o2 & o3
//        let _: Channel<(S1, S2, S3, S2, S1), (Int, Int, Void, Int, Int)> = o1 & o2 & o3 & o2 & o1
////        let ccMany: Channel<(S1, S2, S3, S1, S2, S3, S1, S2, S3, S1, S2, S3), (Int, Int, Void, Int, Int, Void, Int, Int, Void, Int, Int, Void)> = o1 & o2 & o3 & o1 & o2 & o3 & o1 & o2 & o3 & o1 & o2 & o3
//
//        var count = 0
//        let sub = cc.receive({ _ in count += 1 })
//        XCTAssertEqual(3, count)
//
//        o2.source.put(4) // put broadcasts to three sources
//        XCTAssertEqual(6, count)
//
//        cc.source.0.0.1.put(5)
//        XCTAssertEqual(9, count)
//
//        sub.cancel()
//        o2.source.put(6)
//
//        XCTAssertEqual(9, count)
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
        for x in numz { obv.source.put(x) }

        XCTAssertEqual(3, count)
    }

    func testSplitChannel() {
        let obv = channelZSink(Int)

        var count1 = 0, count2 = 0
        let (channel1, channel2) = obv.split({ $0 <= 0 })

        let rcpt1 = channel1.receive({ _ in count1 += 1 })
        let rcpt2 = channel2.receive({ _ in count2 += 1 })

        let numz = -10...3
        for x in numz { obv.source.put(x) }

        XCTAssertEqual(3, count1)
        XCTAssertEqual(11, count2)

        rcpt2.cancel()
        for x in numz { obv.source.put(x) }

        XCTAssertEqual(6, count1)
        XCTAssertEqual(11, count2)

        rcpt1.cancel()
        for x in numz { obv.source.put(x) }

        XCTAssertEqual(6, count1)
        XCTAssertEqual(11, count2)
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
            for x in numz { obv.source.put(x) }
            XCTAssertEqual(4, count)
            sub.cancel() // make sure the count is still 4...
        }
    }

    func testSieveDistinct() {
        let numberz = channelZProperty(1)

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
        let numberz = channelZProperty(1)

        var items: [Int] = []
        numberz.changes(<).receive {
            items.append($0)
        }

        for n in [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3] {
            numberz.source.put(n)
        }

        XCTAssertEqual([1, 2, 2, 3, 4, 3], items)
    }

    func testReduceImmediate() {
        let numberz = channelZSequence([1, 2, 3, 4, 5, 6, 7])
        let sum = numberz.reduce(0, combine: +)

        var sums: [Int] = []
        sum.receive { x in sums.append(x) }

//        XCTAssertEqual(sums, [1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(sums, [28, 28, 28, 28, 28, 28, 28])
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

        sum.unaffect()

        numberz.value = 99

        XCTAssertEqual(raws.0, Array(0...7) + [99])
        XCTAssertEqual(sums.0, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(sums.1, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(sums.2, [0, 1, 3, 6, 10, 15, 21, 28])
        XCTAssertEqual(raws.1, Array(0...7) + [99])

        XCTAssertFalse(r0.cancelled)
        XCTAssertTrue(r1.cancelled)
        XCTAssertTrue(r2.cancelled)
        XCTAssertTrue(r3.cancelled)
        XCTAssertFalse(r4.cancelled)

        withExtendedLifetime((r0, r1, r2, r3, r4)) { }
    }

    func testBuffer() {
        let numberz = channelZProperty(0)
        let bufferer = numberz.buffer(3)

        var items: [[Int]] = []
        bufferer.receive { items.append($0) }
        for i in 1...10 { numberz.value = i }
        // note that 9 & 10 are dropped because they don't satisfy the buffering requirement
        XCTAssertTrue([[0, 1, 2], [3, 4, 5], [6, 7, 8]] == items, "Bad buffered items: \(items)")
    }

//    func testTerminate() {
//        let boolz = channelZSequence([true, true, true, false, true, false, false, true])
//        let finite = boolz.terminate(!)
//        XCTAssertEqual([true, true, true], finite.immediateItems)
//
//        let boolz2 = channelZSequence([true, true, true, false, true, false, false, true])
//        let finite2 = boolz2.terminate(!, terminus: { false })
//        XCTAssertEqual([true, true, true, false], finite2.immediateItems)
//    }

    func testReduceNumbers() {
        let numberz = channelZProperty(0)
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
//        XCTAssertEqual([1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5], avg1.immediateItems)
//
//        let avg2 = numberz.map({ Double($0 * 10) }).map(index()).partition(0, withPartitions: true, clearAfterPulse: false, isPartition: always, combine: runningAverage)
//        XCTAssertEqual([10, 15, 20, 25, 30, 35, 40, 45, 50, 55], avg2.immediateItems)
//
//    }

    func channelResults<S: StateSink, T>(channel: Channel<EffectSource<S>, T>, items: [S.Element]) -> [T] {
        var results: [T] = []
        let _ = channel.receive({ results.append($0) })
        for item in items {
            channel.source.source.put(item)
        }
        return results
    }

    func testPartitionStrings() {
        func isSpace(buf: String, str: String)->Bool { return str == " " }

        let withPartition = channelResults(channelZProperty("").partition("", isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
        XCTAssertEqual(["1 ", "12 ", "123 ", "1234 ", "12345 ", "123456 ", "1234567 ", "12345678 ", "123456789 "], withPartition)

        let withoutPartition = channelResults(channelZProperty("").partition("", includePartitions: false, isPartition: isSpace, combine: +), items: "1 12 123 1234 12345 123456 1234567 12345678 123456789 ".characters.map({ String($0) }))
        XCTAssertEqual(["1", "12", "123", "1234", "12345", "123456", "1234567", "12345678", "123456789"], withoutPartition)

    }

    func testFlatMapChannel() {
        let numbers = (1...3).channelZSequence()
        
        let multiples = { (n: Int) in [n*2, n*3].channelZSequence() }
        let flatMapped: Channel<(Range<Int>, [[Int]]), Int> = numbers.flatMap(multiples)
        XCTAssertEqual([2, 3, 4, 6, 6, 9], flatMapped.immediateItems)
    }


//    func testFlatMapTransformChannel() {
//        let numbers = (1...3).channelZ()
//        let quotients = { (n: Int) in [Double(n)/2.0, Double(n)/4.0].channelZ() }
//        let multiples = { (n: Double) in [Float(n)*3.0, Float(n)*5.0, Float(n)*7.0].channelZ() }
//        let flatMapped = numbers.flatMap(quotients).flatMap(multiples)
//        XCTAssertEqual([1.5, 2.5, 3.5, 0.75, 1.25, 1.75, 3, 5, 7, 1.5, 2.5, 3.5, 4.5, 7.5, 10.5, 2.25, 3.75, 5.25], flatMapped.immediateItems)
//    }

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

        person.fname.source.put("Marc")
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

    func testPropertySources() {
        let propa = PropertySource("A")
        let propb = PropertySource("B")

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
        let propa = channelZProperty(0)
        let propb = channelZProperty(0.0)

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
        defer { ChannelZ.ChannelZReentrantReceptions = 0 }

        let _: PropertySource<Int> = 0∞ // just to show the postfix signature
        let propa: Channel<PropertySource<Int>, Int> = ∞0∞
        let propb: Channel<PropertySource<Int>, Int> = ∞0∞

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

    func testOneOf() {
        let a = ∞=0=∞
        let b = ∞="A"=∞
        let c = ∞=0.0=∞

        var ints = 0
        var strs = 0
        var flts = 0

        a.oneOf(b).oneOf(c).receive { r in
            switch r {
            case .V1(.V1): ints += 1
            case .V1(.V2): strs += 1
            case .V2: flts += 1
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
    }

    /// We use this test to generate the hairy tuple unwrapping code for the Receiver's flatSink, &, and | functions
    func testGenerateTuples() {

        let pname: String = "rcvr"

        /// repeat the given string a certain number of times
        let strs: (String, Int)->String = { s,i in Repeat(count: i, repeatedValue: s).reduce("", combine: +) }

        /// make a type list like T1, T2, T3, T4
        let types: (String, Int)->String = { s,i in (1...i).map({ "\(s)\($0)" }).reduce("", combine: { $0 + ($0.isEmpty ? "" : ", ") + $1 }) }

        let otypes: (String, Int)->String = { s,i in (1...i).map({ "\(s)\($0)?" }).reduce("", combine: { $0 + ($0.isEmpty ? "" : ", ") + $1 }) }


        func flatTuple(count: Int, pre: String, opt: Bool)->String {
            var str = ""
            for i in 1...count {
                if i > 1 { str += ", " }
                str += pre
                for j in i..<count {
                    str += (opt && j > i ? "?" : "") + ".0"
                }
                if i > 1 { str += ".1" }
            }
            return str
        }

        XCTAssertEqual("$0.0.0.0, $0.0.0.1, $0.0.1, $0.1", flatTuple(4, pre: "$0", opt: false))
        //        XCTAssertEqual("$0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1", flatTuple(4, "$0", true))
        XCTAssertEqual("ob.source.0.0.0.0, ob.source.0.0.0.1, ob.source.0.0.1, ob.source.0.1, ob.source.1", flatTuple(5, pre: "ob.source", opt: false))

        let genFlatElement: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func flattenElements<S, " + types("T", n) + ">(\(pname): Channel",
                (2...n).reduce("<S, ", combine: { s,i in s + "(" }),
                (2...n).reduce("T1", combine: { s,i in s + ", T\(i))" }),
                ">)->Channel<S, (" + types("T", n) + ")>",
                " { return \(pname).map { (" + flatTuple(n, pre: "$0", opt: false) + ") } }",
            ]

            return parts.reduce("", combine: +)
        }



        let genFlatSource: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func flattenSources<",
                types("S", n),
                ", T>(\(pname): Channel<",
                strs("(", n-1),
                (2...n).reduce("S1", combine: { s,i in s + ", S\(i)" + ")" }),
                ", T>)->Channel",
                "<(" + types("S", n) + "), T>",
//                " { let src = \(pname).source; return Channel(source: (" + flatTuple(n, pre: "src", opt: false) + "), reception: rcvr.reception) }",
                " { return rcvr.resource { src in (" + flatTuple(n, pre: "src", opt: false) + ") } }",
            ]

            return parts.reduce("", combine: +)
        }



//        let flattenSources5 = "private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = \(pname).source; return Channel(source: (src.0.0.0.0, src.0.0.0.1, src.0.0.1, src.0.1, src.1), reception: rcvr.reception) }"
//        XCTAssert(flattenSources5.hasPrefix(genFlatSource(5)), "\nGEN: \(genFlatSource(5))\nVS.: \(flattenSources5)")
//        XCTAssertEqual(genFlatSource(5), flattenSources5)

        func combineTuple(count: Int, pre: String, opt: Bool)->String {
            if opt {
                return (0..<count-1).reduce("", combine: { s,i in s + pre + ".0?.\(i), " }) + "\(pre).1"
            } else {
                return (0..<count-1).reduce("", combine: { s,i in s + pre + ".0.\(i), " }) + "\(pre).1"
            }
        }

        let genComboSource: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func combineSources<",
                types("S", n),
                ", T>(\(pname): Channel<",
                "((",
                types("S", n-1),
                "), S\(n)), T>)->Channel",
                "<(" + types("S", n) + "), T>",
//                " { let src = \(pname).source; return Channel(source: (" + combineTuple(n, pre: "src", opt: false) + "), reception: rcvr.reception) }",
                " { return rcvr.resource { src in (" + combineTuple(n, pre: "src", opt: false) + ") } }",
            ]

            return parts.reduce("", combine: +)
        }

//        let comboSources5 = "private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = \(pname).source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.1), reception: rcvr.reception) }"
//        XCTAssert(comboSources5.hasPrefix(genComboSource(5)), "\nGEN: \(genComboSource(5))\nVS.: \(comboSources5)")
//        XCTAssertEqual(genComboSource(5), comboSources5)

        let genCombineAll: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func combineAll<S, " + types("T", n) + ">(\(pname): Channel",
                (2...n).reduce("<S, ", combine: { s,i in s }),
                (2...n-1).reduce("((T1", combine: { s,i in s + ", T\(i)" }) + "), T\(n))",
                ">)->Channel<S, (" + types("T", n) + ")>",
                " { return \(pname).map { (" + combineTuple(n, pre: "$0", opt: false) + ") } }",
            ]

            return parts.reduce("", combine: +)
        }



        let genZip: (Int)->String = { n in
            let parts: [String] = [
                "public func &<" + types("S", n) + ", " + types("T", n) + ">",
                "(",
                "lhs: Channel<(" + types("S", n-1) + "), (" + types("T", n-1) + ")>",
                ", ",
                "rhs: Channel<S\(n), T\(n)>",
                ")->",
                "Channel<(" + types("S", n) + "), (" + types("T", n) + ")>",
                " { return combineSources(combineAll(lhs.zip(rhs))) }",
            ]

            return parts.reduce("", combine: +)
        }


        /// Channel zipping & flattening operation (operator form of `flatZip`)
        let flatAny = "public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineAll(lhs.zip(rhs))) }"

        XCTAssert(flatAny.hasPrefix(genZip(3)), "\nGEN: \(genZip(3))\nVS.: \(flatAny)")
        XCTAssertEqual(genZip(3), flatAny)



        let genCombineAny: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func combineAny<S, " + types("T", n) + ">(\(pname): Channel",
                (2...n).reduce("<S, ", combine: { s,i in s }),
                (2...n-1).reduce("((T1?", combine: { s,i in s + ", T\(i)?" }) + ")?, T\(n)?)",
                ">)->Channel<S, (" + otypes("T", n) + ")>",
                " { return \(pname).map { (" + combineTuple(n, pre: "$0", opt: true) + ") } }",
            ]

            return parts.reduce("", combine: +)
        }


        let genOr: (Int)->String = { n in
            let parts: [String] = [
                "public func |<" + types("S", n) + ", " + types("T", n) + ">",
                "(",
                "lhs: Channel<(" + types("S", n-1) + "), (" + otypes("T", n-1) + ")>",
                ", ",
                "rhs: Channel<S\(n), T\(n)>",
                ")->",
                "Channel<(" + types("S", n) + "), (" + otypes("T", n) + ")>",
                " { return combineSources(combineAny(lhs.either(rhs))) }",
            ]

            return parts.reduce("", combine: +)
        }



        /// Channel combination & flattening operation (operator form of `flatAny`)
        let flatOr = "public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1?, T2?)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1?, T2?, T3?)> { return combineSources(combineAny(lhs.either(rhs))) }"
        XCTAssert(flatOr.hasPrefix(genOr(3)), "\nGEN: \(genOr(3))\nVS.: \(flatOr)")
        XCTAssertEqual(genOr(3), flatOr)


        let dumptups: (Int)->(Void) = { max in
            for i in 3...max { print(genZip(i)) }
            print("")
            for i in 3...max { print(genOr(i)) }
            print("")
            for i in 3...max { print(genFlatSource(i)) }
            print("")
            for i in 3...max { print(genComboSource(i)) }
            print("")
            for i in 3...max { print(genFlatElement(i)) }
            print("")
            for i in 3...max { print(genCombineAll(i)) }
            print("")
            for i in 3...max { print(genCombineAny(i)) }
            print("")
            for i in 3...max { print(genCombineAny(i)) }
        }
        
        withExtendedLifetime(dumptups) { } // squash unused warnings
        //dumptups(20)
    }

    func testPropertyChannel() {
        let xs: Int = 1
        let x = channelZProperty(xs)
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
        let x = channelZProperty(xs)

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

        let x = channelZProperty(xs)
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

    func testUnstableConduit() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions = 0 }

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

        let zip1 = (a & b)
        zip1 ∞> { (floatChange: Float, uintChange: UInt) in }

        let zip2 = (a & b & d)

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
        let channel = s1.or(s2)
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
        let zipped = (nums & strs)
        zipped.receive({ numstrs += [$0] })
        XCTAssertEqual(numstrs.map({ $0.0 }), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(numstrs.map({ $0.1 }), ["one", "two", "three", "four", "five", "six"])
    }

    func testMixedCombinations() {
        let a = (∞(Int(0.0))∞).subsequent()

        // FIXME: works, but slow to compile

        let and: Channel<Void, (Int, Int, Int, Int)> = (a & a & a & a).desource()
        var andx = 0
        and.receive({ _ in andx += 1 })

        let or: Channel<Void, OneOf4<Int, Int, Int, Int>> = (a | a | a | a).desource()
        var orx = 0
        or.receive({ _ in orx += 1 })

        let andor: Channel<Void, OneOf4<(Int, Int), (Int, Int), (Int, Int), Int>> = (a & a | a & a | a & a | a).desource() // typed due to slow compile

        var andorx = 0
        andor.receive({ _ in andorx += 1 })

        XCTAssertEqual(0, andx)
        XCTAssertEqual(0, orx)
        XCTAssertEqual(0, andorx)

        a.source.value += 1

        XCTAssertEqual(1, andx, "last and fires a single and change")
        XCTAssertEqual(4, orx, "each or four")
        XCTAssertEqual(4, andorx, "four groups in mixed")

        a.source.value += 1

        XCTAssertEqual(2, andx)
        XCTAssertEqual(8, orx)
        XCTAssertEqual(8, andorx)
    }

    func testPropertyChannelSieve() {
        let stringz = PropertySource("").channelZState().sieve().new().subsequent()
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
        let prop = PropertySource(111).channelZState()

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
        let prop = PropertySource(111).channelZState().sieve() // also works
//        let prop = PropertySource(111).channelZState().sieve(!=).new()

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

        prop.source.put("a")
        XCTAssertEqual([0, 1], counts.0)
        XCTAssertEqual([0, 1], counts.1)
        XCTAssertEqual([0, 1], counts.2)

        prop.source.put("b")
        XCTAssertEqual([0, 1, 2], counts.0)
        XCTAssertEqual([0, 1, 2], counts.1)
        XCTAssertEqual([0, 1, 2], counts.2)
    }

    func testDrpoWithMultipleReceivers() {
        let prop: Channel<PropertySource<Int>, Int> = channelZProperty(0)
        let dropped: Channel<EffectSource<PropertySource<Int>>, Int> = prop.drop(3)

        var values = (Array<Int>(), Array<Int>(), Array<Int>())
        dropped.receive({ values.0.append($0) })
        dropped.receive({ values.1.append($0) })
        dropped.receive({ values.2.append($0) })

        for i in 1...9 { prop.value = i }

        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.0)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.1)
        XCTAssertEqual([3, 4, 5, 6, 7, 8, 9], values.2)
    }

//    func testDeepNestedFilter() {
//        let t = ∞(1.0)∞
//
//        func identity<A>(a: A) -> A { return a }
//        func always<A>(a: A) -> Bool { return true }
//
//        let deepNest = t.desource()
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//
//
//        // FilteredChannel<MappableChannel<....
//        let flatNest = deepNest.desource()
//
//        let deepReceiver = deepNest.receive({ _ in })
//
////        XCTAssertEqual("ChannelZ.FilteredObservable", _stdlib_getDemangledTypeName(deepNest))
//        XCTAssertEqual("ChannelZ.Observable", _stdlib_getDemangledTypeName(flatNest))
//        XCTAssertEqual("ChannelZ.ReceiverOf", _stdlib_getDemangledTypeName(deepReceiver))
//    }
//
//    func testDeepNestedChannel() {
//        let t = ∞(1.0)∞
//
//        func identity<A>(a: A) -> A { return a }
//        func always<A>(a: A) -> Bool { return true }
//
//        let deepNest = t
//            .map(identity).filter(always)
//            .map({"\($0)"}).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//            .map(identity).filter(always)
//
//
//        var changes = 0
//        let deepReceiver = deepNest.receive({ _ in changes += 1 })
//
//        deepNest.value = 12
//        XCTAssertEqual(12, t∞?)
//        XCTAssertEqual(0, --changes)
//
//        deepNest.value--
//        XCTAssertEqual(11, t∞?)
//        XCTAssertEqual(0, --changes)
//
//        XCTAssertEqual("ChannelZ.FilteredChannel", _stdlib_getDemangledTypeName(deepNest))
//        XCTAssertEqual("ChannelZ.ReceiverOf", _stdlib_getDemangledTypeName(deepReceiver))
//
//        // FilteredChannel<MappableChannel<....
//        let flatObservable = deepNest.desource()
//        let flatChannel = deepNest.channel()
//
//        XCTAssertEqual("ChannelZ.Observable", _stdlib_getDemangledTypeName(flatObservable))
//        XCTAssertEqual("ChannelZ.ChannelOf", _stdlib_getDemangledTypeName(flatChannel))
//
//        let flatReceiver = flatChannel.receive({ _ in })
//
//        deepNest.value--
//        XCTAssertEqual(10, t∞?)
//        XCTAssertEqual(0, --changes)
//
//        deepReceiver.request()
//        XCTAssertEqual(0, --changes)
//
//        flatReceiver.request()
////        XCTAssertEqual(0, --changes) // FIXME: prime message is getting lost somehow
//    }
//

    override public func tearDown() {
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

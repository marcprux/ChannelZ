//
//  ChannelTests.swift
//  ChannelTests
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import XCTest
import ChannelZ

extension Channel {
    /// Test method that receives to the observable and returns any elements that are immediately sent to fresh receivers
    var immediateItems: [T] {
        var items: [T] = []
        receive({ items += [$0] }).cancel()
        return items
    }
}

/// Handy extensions to create a sequence from an arrays and ranges
extension Array { func channel()->Channel<Array, T> { return channelZSequence(self) } }
extension Range { func channel()->Channel<Range, T> { return channelZSequence(self) } }


// TODO make a spec with each of https://github.com/ReactiveX/RxScala/blob/0.x/examples/src/test/scala/rx/lang/scala/examples/RxScalaDemo.scala

public class ChannelTests: XCTestCase {

//    func testTraps() {
//        let bools = trap(∞false∞, capacity: 10)
//
//        // test that sending capacity distinct values will store those values
//        var send = [true, false, true, false, true, false, true, false, true, false]
//        send.map { bools.source.value = $0 }
//        XCTAssertEqual(send, bools.values)
//
//        // test that sending some mixed values will sieve and consense to the capacity
//        var mixed = [false, true, true, true, false, true, false, true, false, true, true, false, true, true, false, false, false]
//        mixed.map { bools.source.value = $0 }
//        XCTAssertEqual(send, bools.values)
//    }

//    func testGenerators() {
//        let seq = [true, false, true, false, true]
//
////        let gfun1 = Channel(from: GeneratorOf(seq.generate())) // GeneratorChannel with generator
////        let trap1 = trap(gfun1, capacity: 3)
////        XCTAssertEqual(seq[2...4], trap1.values[0...2], "trap should contain the last 3 elements of the sequence generator")
//
//        let gfun2 = Channel(from: seq) // GeneratorChannel with sequence
//        let trap2 = trap(gfun2, capacity: 3)
//        XCTAssertEqual(seq[2...4], trap2.values[0...2], "trap should contain the last 3 elements of the sequence generator")
//
//        let trapped = trap(Observable(from: 1...5) & Observable(from: 6...10), capacity: 1000)
//        
//        XCTAssertEqual(trapped.values.map({ [$0, $1] }), [[1, 6], [2, 7], [3, 8], [4, 9], [5, 10]]) // tupes aren't equatable
//
//        // observable concatenation
//        // the equivalent of ReactiveX's Range
//        let merged = trap(Observable(from: 1...3) + Observable(from: 3...5) + Observable(from: 2...6), capacity: 1000)
//        XCTAssertEqual(merged.values, [1, 2, 3, 3, 4, 5, 2, 3, 4, 5, 6])
//
//        // the equivalent of ReactiveX's Repeat
//        XCTAssertEqual(trap(Observable(from: Repeat(count: 10, repeatedValue: "A")), capacity: 4).values, ["A", "A", "A", "A"])
//    }

    func testMergedUnreceive() {
        func coinFlip() -> Void? {
            if arc4random_uniform(100) > 50 {
                return Void()
            } else {
                return nil
            }
        }

        typealias S1 = Range<Int>
        typealias S2 = SinkOf<(Float)>
        typealias S3 = ()->Void?

        let o1: Channel<S1, Int> = (1...3).channel()
        let o2: Channel<S2, Int> = channelZSink(Float).map({ Int($0) })
        let o3: Channel<S3, Void> = channelZClosure(coinFlip)

        let cc: Channel<(((S1, S2), S2), S2), Int> = o1 + o2 + o2 + o2

        // examples of type signatures
        let ccSub: Channel<((S1, S2), (S2, S2)), Int> = (o1 + o2) + (o2 + o2)
        let ccVoid: Channel<Void, Int> = cc.void()
        let ccAny: Channel<(S1, S2, S1), (Int?, Int?, Int?)> = o1 | o2 | o1
        let ccZip: Channel<(S1, S2, S3), (Int, Int, Void)> = o1 & o2 & o3
        let ccMany: Channel<(S1, S2, S3, S2, S1), (Int, Int, Void, Int, Int)> = o1 & o2 & o3 & o2 & o1
//        let ccMany: Channel<(S1, S2, S3, S1, S2, S3, S1, S2, S3, S1, S2, S3), (Int, Int, Void, Int, Int, Void, Int, Int, Void, Int, Int, Void)> = o1 & o2 & o3 & o1 & o2 & o3 & o1 & o2 & o3 & o1 & o2 & o3

        var count = 0
        let sub = cc.receive({ _ in count += 1 })
        XCTAssertEqual(3, count)

        o2.source.put(4) // put broadcasts to three sources
        XCTAssertEqual(6, count)

        cc.source.0.0.1.put(5)
        XCTAssertEqual(9, count)

        sub.cancel()
        o2.source.put(6)

        XCTAssertEqual(9, count)
    }

    func testStreamExtensions() {
        if let stream = NSInputStream(fileAtPath: __FILE__) {
            weak var xpc: XCTestExpectation? = expectationWithDescription("input stream")

            let obv = stream.channel()
            var openCount = 0
            var closeCount = 0
            var count = 0
            let sub = obv.receive { switch $0 {
                case .Opened:
                    openCount++
                case .Data(let d):
                    count += d.length
                case .Error(let e):
                    XCTFail(e.description)
                    xpc?.fulfill()
                case .Closed:
                    closeCount++
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
        }
    }
    
    func testFilterChannel() {
        let obv = channelZSink(Int)

        var count = 0
        let sub = obv.filter({ $0 > 0 }).receive({ _ in count += 1 })

        let numz = -10...3
        numz.map { obv.source.put($0) }

        XCTAssertEqual(3, count)
    }

    func testSplitChannel() {
        let obv = channelZSink(Int)

        var count1 = 0, count2 = 0
        let (channel1, channel2) = obv.split({ $0 <= 0 })

        let rcpt1 = channel1.receive({ _ in count1 += 1 })
        let rcpt2 = channel2.receive({ _ in count2 += 1 })

        let numz = -10...3
        numz.map { obv.source.put($0) }

        XCTAssertEqual(3, count1)
        XCTAssertEqual(11, count2)

        rcpt2.cancel()
        numz.map { obv.source.put($0) }

        XCTAssertEqual(6, count1)
        XCTAssertEqual(11, count2)

        rcpt1.cancel()
        numz.map { obv.source.put($0) }

        XCTAssertEqual(6, count1)
        XCTAssertEqual(11, count2)
    }

    func testMapChannel() {
        let obv = channelZSink(Int)

        var count = 0
        let sub = obv.map({ String($0) }).filter({ countElements($0) >= 2 }).receive({ _ in count += 1 })

        for i in 1...10 {
            let numz = -2...11
            numz.map { obv.source.put($0) }
            XCTAssertEqual(4, count)
            sub.cancel() // make sure the count is still 4...
        }
    }

    func XXXtestDispatchChannel() {
        let obv = channelZSink(Int)

        let xpc: XCTestExpectation = expectationWithDescription("queue delay")

        var count = 0
        let sub = obv.filter({ $0 > 0 }).dispatch(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)).receive({ _ in
            XCTAssertFalse(NSThread.isMainThread())
            count += 1
            if count >= 3 {
                xpc.fulfill()
            }
        })

        let numz = -10...3
        numz.map { obv.source.put($0) }

//        XCTAssertNotEqual(3, count, "should have been a delay")
        waitForExpectationsWithTimeout(1, handler: { _ in })
        XCTAssertEqual(3, count)

    }

    private func fib(num: Int) -> Int{
        if(num == 0){
            return 0;
        }
        if(num == 1){
            return 1;
        }
        return fib(num - 1) + fib(num - 2);
    }

    func testDispatchSyncronize() {
        let fibcount = 25
        let obv = channelZSink(Int)

        var fibs: [Int] = []
        let rcpt = obv.sync().map(fib).receive({ fibs += [$0] })

        var source: NSArray = Array(1...fibcount)

        source.enumerateObjectsWithOptions(NSEnumerationOptions.Concurrent, usingBlock: { (ob, index, stop) -> Void in
            obv.source.put(ob as Int)
        })

        XCTAssertEqual(fibcount, fibs.count)
        XCTAssertEqual([1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025], sorted(fibs[0..<25], <))
        rcpt.cancel()
    }

    func testSieveDistinct() {
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4].channel()
        let distinctor = numberz.sieve(!=)
        XCTAssertEqual([1, 2, 1, 2, 3, 4], distinctor.immediateItems)
        XCTAssertEqual(6, distinctor.map({ _ in arc4random() }).immediateItems.count)
    }

    func testSieveLastIncrementing() {
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3].channel()
        let incrementor = numberz.sieve(>)
        XCTAssertEqual([1, 2, 2, 3, 4, 3], incrementor.immediateItems)
    }

    func testSieveLastIncrementingPassed() {
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3].channel()
        let incrementor = numberz.sieve(>, lastPassed: true)
        XCTAssertEqual([1, 2, 3, 4], incrementor.immediateItems)
    }

    func testBuffer() {
        var numberz = [1, 2, 3, 4, 5, 6, 7].channel()
        let bufferer = numberz.buffer(3)
        XCTAssertEqual([[1, 2, 3], [4, 5, 6]], bufferer.immediateItems)
    }

    func testTerminate() {
        var boolz = [true, true, true, false, true, false, false, true].channel()
        let finite = boolz.terminate(!)
        XCTAssertEqual([true, true, true], finite.immediateItems)

        var boolz2 = [true, true, true, false, true, false, false, true].channel()
        let finite2 = boolz2.terminate(~, terminus: { false })
        XCTAssertEqual([true, true, true, false], finite2.immediateItems)
    }

    func testReduceNumbers() {
        var numberz = (1...100).channel()
        let bufferer = numberz.reduce(0, combine: +, isTerminator: { b,x in x % 7 == 0 })
        let a1 = 1+2+3+4+5+6+7
        let a2 = 8+9+10+11+12+13+14
        XCTAssertEqual([a1, a2, 126, 175, 224, 273, 322, 371, 420, 469, 518, 567, 616, 665], bufferer.immediateItems)
    }

    func testReduceRunningAverage() {
        // index creates an indexed pair of elements, a lazy version of Swift's EnumerateGenerator
        func index<T>()->(item: T)->(index: Int, item: T) { var index = 0; return { item in return (index++, item) } }

        // runningAgerage computes the next average in a sequence given the previous average and the current index
        func runningAverage(prev: Double, pair: (Int, Double))->Double { return (prev * Double(pair.0) + pair.1) / Double(pair.0+1) }

        // always always returns true
        func always<T>(_: T)->Bool { return true }
        
        var numberz = (1...10).channel()
        let avg1 = numberz.map({ Double($0) }).enumerate().reduce(0, combine: runningAverage, isTerminator: always, includeTerminators: true, clearAfterEmission: false)
        XCTAssertEqual([1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5], avg1.immediateItems)

        let avg2 = numberz.map({ Double($0 * 10) }).map(index()).reduce(0, combine: runningAverage, isTerminator: always, includeTerminators: true, clearAfterEmission: false)
        XCTAssertEqual([10, 15, 20, 25, 30, 35, 40, 45, 50, 55], avg2.immediateItems)

    }

    func testReduceStrings() {
        func isSpace(buf: String, str: String)->Bool { return str == " " }
        let characters = map("this is a pretty good string!", { String($0) })
        var characterz = characters.channel()
        let reductor = characterz.reduce("", combine: +, isTerminator: isSpace, includeTerminators: false)
        XCTAssertEqual(["this", "is", "a", "pretty", "good"], reductor.immediateItems)
    }

//    func testFilterAs() {
//        let source: [Int?] = [1, nil, 2, nil, 4, nil]
////        let source: [Int] = [1, 2, 4]
//        let numbers = Channel(from: source)
//
//        var nums: [Int] = []
////        let sub1 = numbers.filterType(Int).receive({ nums += [$0] })
//        let sub1 = numbers.filter({ $0 != nil }).map({ $0! }).receive({ nums += [$0] })
////        let sub1 = numbers.map({ $0 as Any as Int? }).filter({ $0 != nil }).map({ $0! }).receive({ nums += [$0] })
//        XCTAssertEqual([1, 2, 4], nums)
//
////        var nsnums: [NSNumber] = []
////        numbers.to(NSNumber).receive({ nsnums += [$0] })
////        XCTAssertEqual([1, 2, 1, 2, 3, 4], nums)
//
//    }

    func testFlatMapChannel() {
        let numbers = (1...3).channel()
        let multiples = { (n: Int) in [n*2, n*3].channel() }
        let flatMapped: Channel<(Range<Int>, [[Int]]), Int> = numbers.flatMap(multiples)
        XCTAssertEqual([2, 3, 4, 6, 6, 9], flatMapped.immediateItems)
    }


    func testFlatMapTransformChannel() {
        let numbers = (1...3).channel()
        let quotients = { (n: Int) in [Double(n)/2.0, Double(n)/4.0].channel() }
        let multiples = { (n: Double) in [Float(n)*3.0, Float(n)*5.0, Float(n)*7.0].channel() }
        let flatMapped = numbers.flatMap(quotients).flatMap(multiples)
        XCTAssertEqual([1.5, 2.5, 3.5, 0.75, 1.25, 1.75, 3, 5, 7, 1.5, 2.5, 3.5, 4.5, 7.5, 10.5, 2.25, 3.75, 5.25], flatMapped.immediateItems)
    }

    func testPropertyReceivers() {
        class Person {
            let fname = PropertyChannel("")
            let lname = PropertyChannel("")
            var level = PropertyChannel(0)
        }

        let person = Person()

        let fnamez = person.fname.channel().sieve(!=).drop(1) + person.lname.channel().sieve(!=).drop(1)
        var names: [String] = []
        let rcpt = fnamez.receive { names += [$0] }

        person.fname.put("Marc")
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

        var levels: [Int] = []
        let rcpt1 = person.level.channel().sieve(>).receive({ levels += [$0] })
        person.level.value = 1
        person.level.value = 2
        person.level.value = 2
        person.level.value = 1
        person.level.value = 3
        XCTAssertEqual([0, 1, 2, 3], levels)
    }

    func testPropertyChannels() {
        let propa = PropertyChannel("A")
        let propb = PropertyChannel("B")

        let rcpt = propa.channel() <=∞=> propb.channel()

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
        let propa = PropertyChannel(0)
        let propb = PropertyChannel(0.0)

        let rcpt = propa.channel().map({ Double($0) }) <=∞=> propb.channel().map({ Int($0) })

        XCTAssertEqual(0, propa.value)
        XCTAssertEqual(0.0, propb.value)

        propa.value++
        XCTAssertEqual(1, propa.value)
        XCTAssertEqual(1.0, propb.value)

        propb.value += 1.2
        XCTAssertEqual(2, propa.value)
        XCTAssertEqual(2.0, propb.value, "rounded value should have been mapped back")

        rcpt.cancel()

        propa.value--
        XCTAssertEqual(1, propa.value)
        XCTAssertEqual(2.0, propb.value, "cancelled receiver should not have channeled the value")
    }

    func testUnstableChannels() {
        let propa = PropertyChannel(0)
        let propb = PropertyChannel(0)

        let rcpt = propa.channel() <=∞=> propb.channel().map({ $0 + 1 })

        XCTAssertEqual(1, propa.value)
        XCTAssertEqual(1, propb.value)

        propa.value++
        XCTAssertEqual(4, propa.value)
        XCTAssertEqual(3, propb.value)

        propb.value++
        XCTAssertEqual(6, propa.value)
        XCTAssertEqual(6, propb.value)

        rcpt.cancel()

        propa.value--
        XCTAssertEqual(5, propa.value)
        XCTAssertEqual(6, propb.value, "cancelled receiver should not have channeled the value")
    }

    /// We use this test to generate the hairy tuple unwrapping code for the Reveicer's flatSink, &, and | functions
    func testGenerateTuples() {

        /// Takes a `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
        let flattenElements4 = "private func flattenElements<S, T1, T2, T3, T4>(rcvr: Channel<S, (((T1, T2), T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) } }"

        /// Takes a `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
        let flatOptionalSink4 = "private func flatOptionalSink<S, T1, T2, T3, T4>(rcvr: Channel<S, (((T1?, T2?)?, T3?)?, T4?)>)->Channel<S, (T1?, T2?, T3?, T4?)> { return rcvr.map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1) } }"


        /// Channel combination & flattening operation (operator form of `flatAny`)
        let flatOr = "public func |<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1?, T2?)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1?, T2?, T3?)> { return flatOptionalSink(flattenSources(lhs.either(rhs))) }"


        let pname: String = "rcvr"

        /// repeat the given string a certain number of times
        let strs: (String, Int)->String = { s,i in join("", Repeat(count: i, repeatedValue: s)) }

        /// make a type list like T1, T2, T3, T4
        let types: (String, Int)->String = { s,i in join(", ", (1...i).map({ "\(s)\($0)" })) }


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

        XCTAssertEqual("$0.0.0.0, $0.0.0.1, $0.0.1, $0.1", flatTuple(4, "$0", false))
//        XCTAssertEqual("$0.0?.0?.0, $0.0?.0?.1, $0.0?.1, $0.1", flatTuple(4, "$0", true))
        XCTAssertEqual("ob.source.0.0.0.0, ob.source.0.0.0.1, ob.source.0.0.1, ob.source.0.1, ob.source.1", flatTuple(5, "ob.source", false))

        let genFlatElement: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func flattenElements<S, " + types("T", n) + ">(\(pname): Channel",
                reduce(2...n, "<S, ", { s,i in s + "(" }),
                reduce(2...n, "T1", { s,i in s + ", T\(i))" }),
                ">)->Channel<S, (" + types("T", n) + ")>",
                " { return \(pname).map { (" + flatTuple(n, "$0", false) + ") } }",
            ]

            return join("", parts)
        }



        let genFlatSource: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func flattenSources<",
                types("S", n),
                ", T>(\(pname): Channel<",
                strs("(", n-1),
                reduce(2...n, "S1", { s,i in s + ", S\(i)" + ")" }),
                ", T>)->Channel",
                "<(" + types("S", n) + "), T>",
                " { let src = \(pname).source; return Channel(source: (" + flatTuple(n, "src", false) + "), rcvr.reception) }",
            ]

            return join("", parts)
        }


        
        let flattenSources5 = "private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = \(pname).source; return Channel(source: (src.0.0.0.0, src.0.0.0.1, src.0.0.1, src.0.1, src.1), rcvr.reception) }"
        XCTAssert(flattenSources5.hasPrefix(genFlatSource(5)), "\nGEN: \(genFlatSource(5))\nVS.: \(flattenSources5)")
        XCTAssertEqual(genFlatSource(5), flattenSources5)

        func combineTuple(count: Int, pre: String, opt: Bool)->String {
            return reduce(0..<count-1, "", { s,i in s + pre + ".0.\(i), " }) + "\(pre).1"
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
                " { let src = \(pname).source; return Channel(source: (" + combineTuple(n, "src", false) + "), rcvr.reception) }",
            ]

            return join("", parts)
        }

        let comboSources5 = "private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { let src = \(pname).source; return Channel(source: (src.0.0, src.0.1, src.0.2, src.0.3, src.1), rcvr.reception) }"
        XCTAssert(comboSources5.hasPrefix(genComboSource(5)), "\nGEN: \(genComboSource(5))\nVS.: \(comboSources5)")
        XCTAssertEqual(genComboSource(5), comboSources5)



        let genComboElement: (Int)->String = { (n: Int) in
            let parts: [String] = [
                "private func combineElements<S, " + types("T", n) + ">(\(pname): Channel",
                reduce(2...n, "<S, ", { s,i in s }),
                reduce(2...n-1, "((T1", { s,i in s + ", T\(i)" }) + "), T\(n))",
                ">)->Channel<S, (" + types("T", n) + ")>",
                " { return \(pname).map { (" + combineTuple(n, "$0", false) + ") } }",
            ]

            return join("", parts)
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
                " { return combineSources(combineElements(lhs.zip(rhs))) }",
            ]

            return join("", parts)
        }


        /// Channel zipping & flattening operation (operator form of `flatZip`)
        let flatAny = "public func &<S1, S2, S3, T1, T2, T3>(lhs: Channel<(S1, S2), (T1, T2)>, rhs: Channel<S3, T3>)->Channel<(S1, S2, S3), (T1, T2, T3)> { return combineSources(combineElements(lhs.zip(rhs))) }"

        XCTAssert(flatAny.hasPrefix(genZip(3)), "\nGEN: \(genZip(3))\nVS.: \(flatAny)")
        XCTAssertEqual(genZip(3), flatAny)
        


        let dumptups: (Int)->(Void) = { max in
            for i in 3...max { println(genZip(i)) }
            println()
            for i in 3...max { println(genFlatSource(i)) }
            println()
            for i in 3...max { println(genComboSource(i)) }
            println()
            for i in 3...max { println(genFlatElement(i)) }
            println()
            for i in 3...max { println(genComboElement(i)) }
        }

//        dumptups(12)
    }
}

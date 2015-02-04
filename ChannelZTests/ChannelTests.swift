//
//  ChannelTests.swift
//  ChannelTests
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import XCTest
import ChannelZ
import CoreData
import ObjectiveC
import WebKit

#if os(OSX)
    import AppKit
#endif

#if os(iOS)
    import UIKit
#endif


extension Channel {
    /// Test method that receives to the observable and returns any elements that are immediately sent to fresh receivers
    var immediateItems: [T] {
        var items: [T] = []
        receive({ items += [$0] }).cancel()
        return items
    }
}

/// Handy extensions to create a sequence from an arrays and ranges
extension Array { func receiver()->Channel<Array, T> { return receiveSequence(self) } }
extension Range { func receiver()->Channel<Range, T> { return receiveSequence(self) } }


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

        let o1: Channel<S1, Int> = (1...3).receiver()
        let o2: Channel<S2, Int> = receiveSink(Float).map({ Int($0) })
        let o3: Channel<S3, Void> = receiveClosure(coinFlip)

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

            let obv = stream.receiver()
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
        let obv = receiveSink(Int)

        var count = 0
        let sub = obv.filter({ $0 > 0 }).receive({ _ in count += 1 })

        let numz = -10...3
        numz.map { obv.source.put($0) }

        XCTAssertEqual(3, count)
    }

    func testMapChannel() {
        let obv = receiveSink(Int)

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
        let obv = receiveSink(Int)

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
        let obv = receiveSink(Int)

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
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4].receiver()
        let distinctor = numberz.sieve(!=)
        XCTAssertEqual([1, 2, 1, 2, 3, 4], distinctor.immediateItems)
        XCTAssertEqual(6, distinctor.map({ _ in arc4random() }).immediateItems.count)
    }

    func testSieveLastIncrementing() {
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3].receiver()
        let incrementor = numberz.sieve(>)
        XCTAssertEqual([1, 2, 2, 3, 4, 3], incrementor.immediateItems)
    }

    func testSieveLastIncrementingPassed() {
        var numberz = [1, 1, 2, 1, 2, 2, 2, 3, 3, 4, 1, 3].receiver()
        let incrementor = numberz.sieve(>, lastPassed: true)
        XCTAssertEqual([1, 2, 3, 4], incrementor.immediateItems)
    }

    func testBuffer() {
        var numberz = [1, 2, 3, 4, 5, 6, 7].receiver()
        let bufferer = numberz.buffer(3)
        XCTAssertEqual([[1, 2, 3], [4, 5, 6]], bufferer.immediateItems)
    }

    func testTerminate() {
        var boolz = [true, true, true, false, true, false, false, true].receiver()
        let finite = boolz.terminate(!)
        XCTAssertEqual([true, true, true], finite.immediateItems)

        var boolz2 = [true, true, true, false, true, false, false, true].receiver()
        let finite2 = boolz2.terminate(~, terminus: { false })
        XCTAssertEqual([true, true, true, false], finite2.immediateItems)
    }

    func testReduceNumbers() {
        var numberz = (1...100).receiver()
        let bufferer = numberz.reduce(0, combine: +, isTerminator: { $0 % 7 == 0 })
        let a1 = 1+2+3+4+5+6+7
        let a2 = 8+9+10+11+12+13+14
        XCTAssertEqual([a1, a2, 126, 175, 224, 273, 322, 371, 420, 469, 518, 567, 616, 665], bufferer.immediateItems)
    }

    func testReduceStrings() {
        func isSpace(str: String)->Bool { return str == " " }
        let characters = map("this is a pretty good string!", { String($0) })
        var characterz = characters.receiver()
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
        let numbers = (1...3).receiver()
        let multiples = { (n: Int) in [n*2, n*3].receiver() }
        let flatMapped: Channel<(Range<Int>, [[Int]]), Int> = numbers.flatMap(multiples)
        XCTAssertEqual([2, 3, 4, 6, 6, 9], flatMapped.immediateItems)
    }


    func testFlatMapTransformChannel() {
        let numbers = (1...3).receiver()
        let quotients = { (n: Int) in [Double(n)/2.0, Double(n)/4.0].receiver() }
        let multiples = { (n: Double) in [Float(n)*3.0, Float(n)*5.0, Float(n)*7.0].receiver() }
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

        let fnamez = person.fname.receiver().sieve(!=).drop(1) + person.lname.receiver().sieve(!=).drop(1)
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
        let rcpt1 = person.level.receiver().sieve(>).receive({ levels += [$0] })
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

        let rcpt = propa.receiver() <=∞=> propb.receiver()

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
        XCTAssertEqual("Y", propb.value, "cancelled receptor should not have channeled the value")
    }

    func testConversionChannels() {
        let propa = PropertyChannel(0)
        let propb = PropertyChannel(0.0)

        let rcpt = propa.receiver().map({ Double($0) }) <=∞=> propb.receiver().map({ Int($0) })

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
        XCTAssertEqual(2.0, propb.value, "cancelled receptor should not have channeled the value")
    }

    func testUnstableChannels() {
        let propa = PropertyChannel(0)
        let propb = PropertyChannel(0)

        let rcpt = propa.receiver() <=∞=> propb.receiver().map({ $0 + 1 })

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
        XCTAssertEqual(6, propb.value, "cancelled receptor should not have channeled the value")
    }

    func memblock<T where T: Equatable>(check: @autoclosure ()->T, code: ()->(), file: String = __FILE__, line: UInt = __LINE__) {
        let start = check()
        autoreleasepool(code)
        let end = check()
        XCTAssertEqual(start, end, "memblock failure", file: file, line: line)
    }

    func testMemory() {
        var strs: [String] = []
        var receipt: Receipt!
        memblock(ChannelThingsInstances, code: {
            let thing = ChannelThing()
            receipt = thing.stringish.receiver().drop(1).sieve(!=).filter({ $0 != nil }).map({ $0! }).receive({ strs += [$0] })
            var strings: [String?] = ["a", "b", nil, "b", "b", "c"]
            strings.map { thing.stringish.put($0) }
            XCTAssertFalse(receipt.cancelled)
        })
//        XCTAssertTrue(receipt.cancelled) // TODO: should receipts clear when sources are cancelled?
        XCTAssertEqual(["a", "b", "b", "c"], strs, "early sieve misses filter")
        receipt.cancel()

    }

    /// We use this test to generate the hairy tuple unwrapping code for the Reveicer's flatSink, &, and | functions
    func testGenerateTuples() {

        /// Takes an `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
        let flattenElements4 = "private func flattenElements<S, T1, T2, T3, T4>(rcvr: Channel<S, (((T1, T2), T3), T4)>)->Channel<S, (T1, T2, T3, T4)> { return rcvr.map { ($0.0.0.0, $0.0.0.1, $0.0.1, $0.1) } }"

        /// Takes an `Channel` with a nested tuple of outputs types and flattens the outputs into a single tuple
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
                " { return Channel(source: (" + flatTuple(n, "\(pname).source", false) + "), rcvr.recipio) }",
            ]

            return join("", parts)
        }


        
        let flattenSources5 = "private func flattenSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((((S1, S2), S3), S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return Channel(source: (rcvr.source.0.0.0.0, rcvr.source.0.0.0.1, rcvr.source.0.0.1, rcvr.source.0.1, rcvr.source.1), rcvr.recipio) }"
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
                " { return Channel(source: (" + combineTuple(n, "\(pname).source", false) + "), rcvr.recipio) }",
            ]

            return join("", parts)
        }

        let comboSources5 = "private func combineSources<S1, S2, S3, S4, S5, T>(rcvr: Channel<((S1, S2, S3, S4), S5), T>)->Channel<(S1, S2, S3, S4, S5), T> { return Channel(source: (rcvr.source.0.0, rcvr.source.0.1, rcvr.source.0.2, rcvr.source.0.3, rcvr.source.1), rcvr.recipio) }"
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

//        dumptups(20)
    }


//    func testChannels() {
//        var observedBool = ∞(false)∞
//        observedBool.value = false
//
//        var changeCount: Int = 0
//
//        let ob1 = observedBool.receive { v in
//            changeCount = changeCount + 1
//        }
//
//        XCTAssertEqual(0, changeCount)
//
//        observedBool <- true
//        XCTAssertEqual(1, changeCount)
//
//        observedBool <- true
//        XCTAssertEqual(1, changeCount)
//
//        observedBool <- false
//        observedBool <- false
//
//
//        XCTAssertEqual(2, changeCount)
//
//        // XCTAssertEqual(test, false)
//
//        var stringFieldChanges: Int = 0
//        var intFieldChanges: Int = 0
//        var doubleFieldChanges: Int = 0
//
//
//        #if DEBUG_CHANNELZ
//        let startObserverCount = ChannelZKeyValueObserverCount
//        #endif
//
//        autoreleasepool {
//            let state = StatefulObject()
//            state.optionalStringField = "sval1"
//
//            state∞state.intField ∞> { _ in intFieldChanges += 1 }
//
//            #if DEBUG_CHANNELZ
//            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1)
//            #endif
//
//            var stringFieldObserver = state∞(state.optionalStringField)
//            stringFieldObserver.receive { _ in stringFieldChanges += 1 }
//
//            state∞state.doubleField ∞> { _ in doubleFieldChanges += 1 }
//
//            XCTAssertEqual("sval1", state.optionalStringField!)
//
//            state.intField++; XCTAssertEqual(0, --intFieldChanges)
//            state.intField = state.intField + 0; XCTAssertEqual(0, intFieldChanges)
//            state.intField = state.intField + 1 - 1; XCTAssertEqual(0, intFieldChanges)
//            state.intField++; XCTAssertEqual(0, --intFieldChanges)
//            state.optionalStringField = state.optionalStringField ?? "" + ""; XCTAssertEqual(0, stringFieldChanges)
//            state.optionalStringField! += "x"; XCTAssertEqual(0, --stringFieldChanges)
//            stringFieldObserver.value = "y"; XCTAssertEqual(0, --stringFieldChanges)
//            state.optionalStringField = nil; XCTAssertEqual(0, --stringFieldChanges)
//            state.optionalStringField = ""; XCTAssertEqual(0, --stringFieldChanges)
//            state.optionalStringField = ""; XCTAssertEqual(0, stringFieldChanges)
//            state.optionalStringField = "foo"; XCTAssertEqual(0, --stringFieldChanges)
//
//            #if DEBUG_CHANNELZ
//            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1, "observers should still be around before cleanup")
//            #endif
//        }
//
//        #if DEBUG_CHANNELZ
//        XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount, "observers should have been cleared after cleanup")
//        #endif
//    }
//
//    func testFilteredChannels() {
//
//        var strlen = 0
//
//        let sv = sieveField("X")
//        sv.filter({ _ in true }).map(countElements)
//        sv.channel().filter({ _ in true }).channel().map(countElements)
//        sv.map(countElements)
//
//        var a = sv.filter({ _ in true }).map(countElements).filter({ $0 % 2 == 1 })
//        var aa = a.receive { strlen = $0 }
//
//        a.value = ("AAA")
//
//        XCTAssertEqual(3, strlen)
//
//        // TODO: need to re-implement .value for FieldChannels, etc.
////        a.value = (a.value + "ZZ")
////        XCTAssertEqual(5, strlen)
////        XCTAssertEqual("AAAZZ", a.value)
////
////        a.value = (a.value + "A")
////        XCTAssertEqual("AAAZZA", a.value)
////        XCTAssertEqual(5, strlen, "even-numbered increment should have been filtered")
////
////        a.value = (a.value + "A")
////        XCTAssertEqual("AAAZZAA", a.value)
////        XCTAssertEqual(7, strlen)
//
//
//        let x = sieveField(1).filter { $0 <= 10 }
//
//        var changeCount: Double = 0
//        var changeLog: String = ""
//
//        // track the number of changes using two separate subscriptions
//        x.receive { _ in changeCount += 0.5 }
//        x.receive { _ in changeCount += 0.5 }
//
//        let xfm = x.map( { String($0) })
//        let xfma = xfm.receive { s in changeLog += (countElements(changeLog) > 0 ? ", " : "") + s } // create a string log of all the changes
//
//
//        XCTAssertEqual(0, changeCount)
//        XCTAssertNotEqual(5, x.value)
//
//        x <- 5
//        XCTAssertEqual(5, x.value)
//        XCTAssertEqual(1, changeCount)
//
//
//        x <- 5
//        XCTAssertEqual(5, x.value)
//        XCTAssertEqual(1, changeCount)
//
//        x <- 6
//        XCTAssertEqual(2, changeCount)
//
//        // now test the filter: only changes to numbers less than or equal to 10 should flow to the receivers
//        x <- 20
//        XCTAssertEqual(2, changeCount, "out of bounds change should not have fired listener")
//
//        x <- 6
//        XCTAssertEqual(3, changeCount, "in-bounds change should have fired listener")
//
//        for i in 1...100 {
//            x <- i
//        }
//        XCTAssertEqual(13, changeCount, "in-bounds change should have fired listener")
//
//        XCTAssertEqual("5, 6, 6, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10", changeLog)
//
//
//        var tc = 0.0
//        let t = ∞(1.0)∞
//
//        t.filter({ $0 % 2 == 0 }).filter({ $0 % 9 == 0 }).receive({ n in tc += n })
////        t.receive({ n in tc += n })
//
//        for i in 1...100 { t <- Double(i) }
//        // FIXME: seems to be getting released somehow
////        XCTAssertEqual(270.0, tc, "sum of all numbers between 1 and 100 divisible by 2 and 9")
//
//        var lastt = ""
//
//        let tv = t.map({ v in v }).filter({ $0 % 2 == 0 }).map(-).map({ "Even: \($0)" })
//        tv.receive({ lastt = $0 })
//
//
//        for i in 1...99 { tv <- Double(i) }
//        XCTAssertEqual("Even: -98.0", lastt)
//    }
//
//    func testStructChannel() {
//        let ob = ∞(SwiftStruct(intField: 1, stringField: "x", enumField: .Yes))∞
//
//        var changes = 0
//
//        // receive is the equivalent of ReactiveX's Subscribe
//        ob.receive({ _ in changes += 1 })
//
//        XCTAssertEqual(changes, 0)
//        ob.value = SwiftStruct(intField: 2, stringField: nil, enumField: .Yes)
//        XCTAssertEqual(changes, 1)
//
//        ob.value = SwiftStruct(intField: 2, stringField: nil, enumField: .Yes)
//        XCTAssertEqual(changes, 2)
//    }
//
//    func testEquatableStructChannel() {
//        let ob = ∞(SwiftEquatableStruct(intField: 1, stringField: "x", enumField: .Yes))∞
//
//        var changes = 0
//        ob.receive({ _ in changes += 1 })
//
//        XCTAssertEqual(changes, 0)
//        ob.value = SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .Yes)
//        XCTAssertEqual(changes, 1)
//
//        ob.value = SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .Yes)
//        XCTAssertEqual(changes, 1)
//
//        ob.value = SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .No)
//        XCTAssertEqual(changes, 2)
//
//        ob.value = SwiftEquatableStruct(intField: 3, stringField: "str", enumField: .Yes)
//        XCTAssertEqual(changes, 3)
//    }
//
//    func testStuctChannels() {
//        let ob = SwiftChannels()
//
//        var stringChanges = 0
//        ob.stringField ∞> { _ in stringChanges += 1 }
//        XCTAssertEqual(0, stringChanges)
//
//        ob.stringField.value = "x"
//        XCTAssertEqual(0, --stringChanges)
//
//        var enumChanges = 0
//        ob.enumField ∞> { _ in enumChanges += 1 }
//        XCTAssertEqual(0, enumChanges)
//
//        ob.enumField.value = .MaybeSo
//        XCTAssertEqual(0, --enumChanges)
//
//        ob.enumField.value = .MaybeSo
//        XCTAssertEqual(0, enumChanges)
//    }
//
//    func testFieldSieve() {
//        var xs: Int = 1
//        var c = sieveField(xs)
//
//        var changes = 0
//        c.receive { _ in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        c.value = (c.value + 1); XCTAssertEqual(0, --changes)
//        c.value = (2); XCTAssertEqual(0, changes)
//        c.value = (2); c.value = (2); XCTAssertEqual(0, changes)
//        c.value = (9); c.value = (9); XCTAssertEqual(0, --changes)
//    }
//
//    func testOptionalFieldSieve() {
//        var xs: Int? = nil
//        var c = sieveField(xs)
//
//        var changes = 0
//        c ∞> { _ in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        c.value = (2); XCTAssertEqual(0, --changes)
//        c.value = (2); c.value = (2); XCTAssertEqual(0, changes)
//        c.value = (nil); XCTAssertEqual(0, --changes)
////        c.value = (nil); XCTAssertEqual(0, --changes) // FIXME: nil to nil is a change?
//        c.value = (1); XCTAssertEqual(0, --changes)
//        c.value = (1); XCTAssertEqual(0, changes)
//        c.value = (2); XCTAssertEqual(0, --changes)
//    }
//
//    func testKeyValueSieve() {
//        var state = StatefulObject()
//        var c = state∞(state.requiredStringField)
//
//        var changes = 0
//        c ∞> { _ in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        c.value = (""); XCTAssertEqual(0, changes, "default to default should not change")
//        c.value = ("A"); XCTAssertEqual(0, --changes, "default to A should change")
//        c.value = ("A"); XCTAssertEqual(0, changes, "A to A should not change")
//        c.value = ("B"); c.value = ("B"); XCTAssertEqual(0, --changes, "A to B should change once")
//    }
//
//    func testKeyValueSieveUnretainedReceptor() {
//        var state = StatefulObject()
//        var c = state∞(state.requiredStringField)
//
//        var changes = 0
//        c ∞> { _ in changes += 1 } // note we do not assign it locally, so it should immediately get cleaned up
//
//        XCTAssertEqual(0, changes)
//        c.value = ("A"); XCTAssertEqual(1, changes, "unretained subscription should still listen")
//        c.value = (""); XCTAssertEqual(2, changes, "unretained subscription should still listen")
//    }
//
//    func testOptionalNSKeyValueSieve() {
//        var state = StatefulObject()
//        var c = state∞(state.optionalNSStringField)
//
//        var changes = 0
//        c ∞> { _ in changes += 1 }
//
//        for _ in 0...5 {
//            XCTAssertEqual(0, changes)
//            c.value = ("A"); XCTAssertEqual(0, --changes, "unset to A should change")
//            c.value = ("A"); c.value = ("A"); XCTAssertEqual(0, changes, "A to A should not change")
//            c.value = (nil); XCTAssertEqual(0, --changes, "A to nil should change")
//            c.value = ("B"); c.value = ("B"); XCTAssertEqual(0, --changes, "nil to B should change once")
//            c.value = (nil); XCTAssertEqual(0, --changes, "B to nil should change")
//
//            // this one is tricky, since with KVC, previous values are often cached as NSNull(), which != nil
//            c.value = (nil); c.value = (nil); XCTAssertEqual(0, changes, "nil to nil should not change")
//        }
//    }
//
//    func testOptionalSwiftSieve() {
//        var state = StatefulObject()
//        var c = state∞(state.optionalStringField)
//
//        var changes = 0
//        c ∞> { _ in changes += 1 }
//
//        for _ in 0...5 {
//            XCTAssertEqual(0, changes)
//            c.value = ("A"); XCTAssertEqual(0, --changes, "unset to A should change")
//            c.value = ("A"); c.value = ("A"); XCTAssertEqual(0, changes, "A to A should not change")
//            c.value = (nil); XCTAssertEqual(0, --changes, "A to nil should change")
//            c.value = ("B"); c.value = ("B"); XCTAssertEqual(0, --changes, "nil to B should change once")
//            c.value = (nil); XCTAssertEqual(0, --changes, "B to nil should change")
//
//            // this one is tricky, since with KVC, previous values are often cached as NSNull(), which != nil
//            c.value = (nil); c.value = (nil); XCTAssertEqual(0, changes, "nil to nil should not change")
//        }
//    }
//
//    func testDictionaryChannels() {
//        let dict = NSMutableDictionary()
//        var fooChanges = 0
//
//        XCTAssertEqual(0, fooChanges)
//
//        dict["foo"] = "bar"
//
//        dict.sievez(dict["foo"] as? NSString, keyPath: "foo") ∞> { _ in fooChanges += 1 }
//        XCTAssertEqual(0, fooChanges)
//
//        dict["foo"] = "bar"
//        XCTAssertEqual(0, fooChanges)
//
//        dict["foo"] = NSNumber(float: 1.234)
//        XCTAssertEqual(0, --fooChanges)
//
//        dict["foo"] = NSNull()
//        XCTAssertEqual(0, fooChanges) // note that setting to null does not pass the sieve
//
//        dict["foo"] = "bar"
//        XCTAssertEqual(0, --fooChanges)
//    }
//
//    func testFieldChannelChannel() {
//        var xs: Int = 1
//        var x = channelField(xs)
//        var f: Channel<Int> = x.observable() // read-only observable of channel x
//
//        var changes = 0
//        var subscription = f ∞> { _ in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        x.value = (x.value + 1); XCTAssertEqual(0, --changes)
//        x.value = (2); XCTAssertEqual(0, --changes)
//        x.value = (2); XCTAssertEqual(0, --changes)
//        x.value = (9);XCTAssertEqual(0, --changes)
//
//        subscription.cancel()
//        x.value = (-1); XCTAssertEqual(0, changes)
//    }
//
//    func testFieldChannelMapObservable() {
//        var xs: Bool = true
//        var x = channelField(xs)
//
//        var xf: Observable<Bool> = x.observable() // read-only observable of channel x
//
//        let fxa = xf ∞> { (x: Bool) in return }
//
//        var y = x.map({ "\($0)" })
//        var yf: Observable<String> = y.observable() // read-only observable of mapped channel y
//
//        var changes = 0
//        var fya: Receptor = yf ∞> { (x: String) in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        x.value = (!x.value); XCTAssertEqual(0, --changes)
//        x.value = (true); XCTAssertEqual(0, --changes)
//        x.value = (true); XCTAssertEqual(0, --changes)
//        x.value = (false); XCTAssertEqual(0, --changes)
//
//        fya.cancel()
//        x.value = (true); XCTAssertEqual(0, changes)
//    }
//
//    func testFieldSieveChannelMapObservable() {
//        var xs: Double = 1
//
//        var x = sieveField(xs)
//        var xf: Observable<Double> = x.observable() // read-only observable of channel x
//
//        var fxa = xf ∞> { (x: Double) in return }
//
//        var y = x.map({ "\($0)" })
//        var yf: Observable<String> = y.observable() // read-only observable of channel y
//
//        var changes = 0
//        var fya: Receptor = yf ∞> { (x: String) in changes += 1 }
//
//        XCTAssertEqual(0, changes)
//        x.value = (x.value + 1); XCTAssertEqual(0, --changes)
//        x.value = (2); XCTAssertEqual(0, changes)
//        x.value = (2); x.value = (2); XCTAssertEqual(0, changes)
//        x.value = (9); x.value = (9); XCTAssertEqual(0, --changes)
//
//        fxa.cancel()
//        fya.cancel()
//        x.value = (-1); XCTAssertEqual(0, changes)
//    }
//
//    func testHeterogeneousConduit() {
//        let a = ∞(Double(1.0))∞
//        let b = ∞(Double(1.0))∞
//
//        let pipeline = a <=∞=> b
//
//        a.value = 2.0
//        XCTAssertEqual(2.0, a.value)
//        XCTAssertEqual(2.0, b.value)
//
//        b.value = 3.0
//        XCTAssertEqual(3.0, a.value)
//        XCTAssertEqual(3.0, b.value)
//    }
//
//    func testHomogeneousConduit() {
//        var a = ∞(Double(1.0))∞
//        var b = ∞(UInt(1))∞
//
//        var af = a.filter({ $0 >= Double(UInt.min) && $0 <= Double(UInt.max) }).map({ UInt($0) })
//        var bf = b.map({ Double($0) })
//        let pipeline = conduit(af, bf)
//
//        a <- 2.0
//        XCTAssertEqual(2.0, a.value)
//        XCTAssertEqual(UInt(2), b.value)
//
//        b <- 3
//        XCTAssertEqual(3.0, a.value)
//        XCTAssertEqual(UInt(3), b.value)
//
//        a <- 9.9
//        XCTAssertEqual(9.9, a.value)
//        XCTAssertEqual(UInt(9), b.value)
//
//        a <- -5.0
//        XCTAssertEqual(-5.0, a.value)
//        XCTAssertEqual(UInt(9), b.value)
//
//        a <- 8.1
//        XCTAssertEqual(8.1, a.value)
//        XCTAssertEqual(UInt(8), b.value)
//    }
//
//    func testUnstableConduit() {
//        var a = ∞(1)∞
//        var b = ∞(2)∞
//
//        // this unstable pipe would never achieve equilibrium, and so relies on re-entrancy checks to halt the flow
//        var af = a.map({ $0 + 1 })
//        let pipeline = conduit(af, b)
//
//        a.value = 2
//        XCTAssertEqual(2, a.value)
//        XCTAssertEqual(3, b.value)
//
//        b.value = (10)
//        XCTAssertEqual(10, a.value)
//        XCTAssertEqual(10, b.value)
//
//        a <- 99
//        XCTAssertEqual(99, a.value)
//        XCTAssertEqual(100, b.value)
//    }
//
//
//    func testAnyCombinations() {
//        let a = ∞(Float(3.0))∞
//        let b = ∞(UInt(7))∞
//        let c = ∞(Bool(false))∞
//
//        let d = c.map { "\($0)" }
//
//        var lastFloat : Float = 0.0
//        var lastString : String = ""
//
//        var combo1 = (a | b)
////        combo1.receive({ (floatChange: Float?, uintChange: UInt?) in })
//
//        var combo2 = (a | b | d)
//
//        var changes = 0
//
//        combo2 ∞> { (floatChange: Float?, uintChange: UInt?, stringChange: String?) in
//            changes++
//            if let float = floatChange {
//                lastFloat = float
//            }
//
//            if let str = stringChange {
//                lastString = str
//            }
//        }
//
//        a.value++
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("", lastString)
//        XCTAssertEqual(Float(4.0), lastFloat)
//
//        c.value = true
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("true", lastString)
//        XCTAssertEqual(Float(4.0), lastFloat)
//
//        c.value = false
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("false", lastString)
//        XCTAssertEqual(Float(4.0), lastFloat)
//
//    }
//
//    func testList() {
//        func stringsToChars(f: Character->Void) -> String->Void {
//            return { (str: String) in for c in str { f(c) } }
//        }
//
//        let strings: Observable<String> = Observable(from: ["abc"]).observable()
//        let chars1 = strings.lift(stringsToChars)
//        let chars2 = strings.lift { (f: Character->Void) in { (str: String) in let _ = map(str, f) } }
//
//        var buf: [Character] = []
//        chars2.receive({ buf += [$0] })
//        XCTAssertEqual(buf, ["a", "b", "c"])
//    }
//
//    func testZippedObservable() {
//        let a = ∞(Float(3.0))∞
//        let b = ∞(UInt(7))∞
//        let c = ∞(Bool(false))∞
//
//        let d = c.map { "\($0)" }
//
//        var lastFloat : Float = 0.0
//        var lastString : String = ""
//
//        var zip1 = (a & b)
//        zip1 ∞> { (floatChange: Float, uintChange: UInt) in }
//
//        var zip2 = (a & b & d)
//
//        var changes = 0
//
//        let subscription = zip2 ∞> { (floatChange: Float, uintChange: UInt, stringChange: String) in
//            changes++
//            lastFloat = floatChange
//            lastString = stringChange
//        }
//
//        XCTAssertEqual(0, changes)
//        XCTAssertEqual("", lastString)
//        XCTAssertEqual(Float(0.0), lastFloat)
//
//        subscription.request()
//
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("false", lastString)
//        XCTAssertEqual(Float(3.0), lastFloat)
//
//        a.value++
//        b.value++
//        b.value++
//        b.value++
//        b.value++
//        c.value = true
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("true", lastString)
//        XCTAssertEqual(Float(4.0), lastFloat)
//
//        c.value = !c.value
//        c.value = !c.value
//        c.value = !c.value
//        c.value = !c.value
//
//        a.value++
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("false", lastString)
//        XCTAssertEqual(Float(5.0), lastFloat)
//
//        a.value++
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("true", lastString)
//        XCTAssertEqual(Float(6.0), lastFloat)
//
//        a.value++
//        XCTAssertEqual(0, --changes)
//        XCTAssertEqual("false", lastString)
//        XCTAssertEqual(Float(7.0), lastFloat)
//
//    }
//
//    func testMixedCombinations() {
//        let a = ∞(Int(0.0))∞
//
//        var and: Observable<(Int, Int, Int, Int)> = a & a & a & a
//        var andx = 0
//        and.receive({ _ in andx += 1 })
//
//        var or: Observable<(Int?, Int?, Int?, Int?)> = a | a | a | a
//        var orx = 0
//        or.receive({ _ in orx += 1 })
//
//        var andor: Observable<((Int, Int)?, (Int, Int)?, (Int, Int)?, Int?)> = a & a | a & a | a & a | a
//        var andorx = 0
//        andor.receive({ _ in andorx += 1 })
//
//        XCTAssertEqual(0, andx)
//        XCTAssertEqual(0, orx)
//        XCTAssertEqual(0, andorx)
//
//        a.value++
//
//        XCTAssertEqual(1, andx, "last and fires a single and change")
//        XCTAssertEqual(4, orx, "each or four")
//        XCTAssertEqual(4, andorx, "four groups in mixed")
//
//        a.value++
//
//        XCTAssertEqual(2, andx)
//        XCTAssertEqual(8, orx)
//        XCTAssertEqual(8, andorx)
//
//    }
//
//    func testZippedGenerators() {
//        let range = 1...6
//        let nums = Observable(from: 1...3) + Observable(from: 4...5) + Observable(just: 6)
//        let strs = Observable(from: range.map({ NSNumberFormatter.localizedStringFromNumber($0, numberStyle: NSNumberFormatterStyle.SpellOutStyle) }).map({ $0 as String }))
//        var numstrs: [(Int, String)] = []
//        let zipped = (nums & strs)
//        zipped.receive({ numstrs += [$0] })
//        XCTAssertEqual(numstrs.map({ $0.0 }), [1, 2, 3, 4, 5, 6])
//        XCTAssertEqual(numstrs.map({ $0.1 }), ["one", "two", "three", "four", "five", "six"])
//    }
//
//    func testDeepNestedFilter() {
//        let t = ∞(1.0)∞
//
//        func identity<A>(a: A) -> A { return a }
//        func always<A>(a: A) -> Bool { return true }
//
//        let deepNest = t.observable()
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
//        let flatNest = deepNest.observable()
//
//        let deepReceptor = deepNest.receive({ _ in })
//
////        XCTAssertEqual("ChannelZ.FilteredObservable", _stdlib_getDemangledTypeName(deepNest))
//        XCTAssertEqual("ChannelZ.Observable", _stdlib_getDemangledTypeName(flatNest))
//        XCTAssertEqual("ChannelZ.ReceptorOf", _stdlib_getDemangledTypeName(deepReceptor))
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
//        let deepReceptor = deepNest.receive({ _ in changes += 1 })
//
//        deepNest.value = 12
//        XCTAssertEqual(12, t.value)
//        XCTAssertEqual(0, --changes)
//
//        deepNest.value--
//        XCTAssertEqual(11, t.value)
//        XCTAssertEqual(0, --changes)
//
//        XCTAssertEqual("ChannelZ.FilteredChannel", _stdlib_getDemangledTypeName(deepNest))
//        XCTAssertEqual("ChannelZ.ReceptorOf", _stdlib_getDemangledTypeName(deepReceptor))
//
//        // FilteredChannel<MappableChannel<....
//        let flatObservable = deepNest.observable()
//        let flatChannel = deepNest.channel()
//
//        XCTAssertEqual("ChannelZ.Observable", _stdlib_getDemangledTypeName(flatObservable))
//        XCTAssertEqual("ChannelZ.ChannelOf", _stdlib_getDemangledTypeName(flatChannel))
//
//        let flatReceptor = flatChannel.receive({ _ in })
//
//        deepNest.value--
//        XCTAssertEqual(10, t.value)
//        XCTAssertEqual(0, --changes)
//
//        deepReceptor.request()
//        XCTAssertEqual(0, --changes)
//
//        flatReceptor.request()
////        XCTAssertEqual(0, --changes) // FIXME: prime message is getting lost somehow
//    }
//
//    func testSimpleConduits() {
//        let n1 = ∞(Int(0))∞
//
//        let state = StatefulObject()
//        let n2 = state∞(state.intField as NSNumber)
//
//        let n3 = ∞(Int(0))∞
//
//        // bindz((n1, identity), (n2, identity))
//        // (n1, { $0 + 1 }) <~∞~> (n2, { $0.integerValue - 1 }) <~∞~> (n3, { $0 + 1 })
//
//        let n1_n2 = n1.map({ NSNumber(int: $0 + 1) }) <=∞=> n2.map({ $0.integerValue - 1 })
//        let n2_n3 = (n2, { .Some($0.integerValue - 1) }) <~∞~> (n3, { .Some($0 + 1) })
//
//        n1 <- 2
//        XCTAssertEqual(2, n1.value)
//        XCTAssertEqual(3, n2.value ?? -1)
//        XCTAssertEqual(2, n3.value)
//
//        n2 <- 5
//        XCTAssertEqual(4, n1.value)
//        XCTAssertEqual(5, n2.value ?? -1)
//        XCTAssertEqual(4, n3.value)
//
//        n3 <- -1
//        XCTAssertEqual(-1, n1.value)
//        XCTAssertEqual(0, n2.value ?? -1)
//        XCTAssertEqual(-1, n3.value)
//
//        // TODO: fix bindings
////        // make sure disconnecting the binding actually disconnects is
////        n1_n2.disconnect()
////        n1 <- 20
////        XCTAssertEqual(20, n1.value)
////        XCTAssertEqual(0, n2.value ?? -1)
////        XCTAssertEqual(-1, n3.value)
//    }
//
//    func testSinkObservables() {
//        let (sink, observable) = sinkObservable(Int)
//
//        sink.put(1)
//        var changes = 0
//        let subscription = observable.receive({ _ in changes += 1 })
//
//        XCTAssertEqual(0, changes)
//
//        sink.put(1)
//        XCTAssertEqual(0, --changes)
//
//        let sinkof = SinkOf(sink)
//        sinkof.put(2)
//        XCTAssertEqual(0, --changes, "sink wrapper around observable should have passed elements through to subscriptions")
//
//        subscription.request()
//        XCTAssertEqual(0, changes, "request() should be a no-op for SinkObservable")
//
//        subscription.cancel()
//        sinkof.put(2)
//        XCTAssertEqual(0, changes, "canceled subscription should not be called")
//    }
//
////    func testTransformableConduits() {
////
////        var num = ∞(0)∞
////        let state = StatefulObject()
////        let strProxy = state∞(state.optionalStringField as String?)
////        let dict = NSMutableDictionary()
////
////        dict["stringKey"] = "foo"
////        let dictProxy = dict.channelz(dict["stringKey"], keyPath: "stringKey")
////
////        // bind the number value to a string equivalent
//////        num ∞> { num in strProxy.value = "\(num)" }
//////        strProxy ∞> { str in num.value = Int((str as NSString).intValue) }
////
////        let num_strProxy = (num, { "\($0)" }) <~∞~> (strProxy, { $0?.toInt() })
////
////        let strProxy_dictProxy = (strProxy, { $0 }) <~∞~> (dictProxy, { $0 as? String? })
////
//////        let binding = bindz((strProxy, identity), (dictProxy, identity))
//////        let binding = (strProxy, identity) <~∞~> (dictProxy, identity)
////
//////        let sval = reflect(str.optionalStringField).value
//////        str.optionalStringField = nil
//////        dump(reflect(str.optionalStringField).value)
////
////        num <- 10
////        XCTAssertEqual("10", state.optionalStringField ?? "<nil>")
////
////        state.optionalStringField = "123"
////        XCTAssertEqual(123, num.value)
////        
////        num <- 456
////        XCTAssertEqual("456", dict["stringKey"] as NSString? ?? "<nil>")
////
////        dict["stringKey"] = "-98"
////        XCTAssertEqual(-98, num.value)
////
////        // tests re-entrancy with inconsistent equivalencies
////        dict["stringKey"] = "ABC"
////        XCTAssertEqual(-98, num.value)
////
////        dict["stringKey"] = "66"
////        XCTAssertEqual(66, num.value)
////
////        /* ###
////        // nullifying should change the proxy
////        dict.removeObjectForKey("stringKey")
////        XCTAssertEqual(0, num.value)
////
////        // no change from num's value, so don't change
////        num <- 0
////        XCTAssertEqual("", dict["stringKey"] as NSString? ?? "<nil>")
////
////        num <- 1
////        XCTAssertEqual("1", dict["stringKey"] as NSString? ?? "<nil>")
////
////        num <- 0
////        XCTAssertEqual("0", dict["stringKey"] as NSString? ?? "<nil>")
////        */
////    }
//
//    func testEquivalenceConduits() {
//
//        /// Test equivalence conduits
//        let state = StatefulObject()
//
//
//        var qn1 = ∞(0)∞
////        let qn2 = (observee: state, keyPath: "intField", value: state.intField as NSNumber)===>
//        let qn2 = state∞(state.intField)
//
//        let qn1_qn2 = qn1 <~∞~> qn2
//
//        qn1.value = (qn1.value + 1)
//        XCTAssertEqual(1, state.intField)
//
//        qn1.value = (qn1.value - 1)
//        XCTAssertEqual(0, state.intField)
//
//        qn1.value = (qn1.value + 1)
//        XCTAssertEqual(1, state.intField)
//
//        state.intField += 10
//        XCTAssertEqual(11, qn1.value)
//
//        qn1.value = (qn1.value + 1)
//        XCTAssertEqual(12, state.intField)
//
//        var qs1 = ∞("")∞
//
//        XCTAssertEqual("", qs1.value)
//
//        let qs2 = state∞(state.optionalStringField)
//
//        // TODO: fix optonal bindings
//        
////        let qsb = qs1 <?∞?> qs2
////
////        qs1.value += "X"
////        XCTAssertEqual("X", state.optionalStringField ?? "<nil>")
////
////        qs1.value += "X"
////        XCTAssertEqual("XX", state.optionalStringField ?? "<nil>")
////
////        /// Test that disconnecting the binding actually removes the observers
////        qsb.cancel()
////        qs1.value += "XYZ"
////        XCTAssertEqual("XX", state.optionalStringField ?? "<nil>")
//    }
//
//    func testOptionalToPrimitiveConduits() {
//        /// Test equivalence bindings
//        let state = StatefulObject()
//
//        let obzn1 = state∞(state.numberField1)
//        let obzn2 = state∞(state.numberField2)
//
//        let obzn1_obzn2 = conduit(obzn1, obzn2)
//
//        state.numberField2 = 44.56
//        XCTAssert(state.numberField1 === state.numberField2, "change the other side")
//        XCTAssertNotNil(state.numberField1)
//        XCTAssertNotNil(state.numberField2)
//
//        state.numberField1 = 1
//        XCTAssert(state.numberField1 === state.numberField2, "change one side")
//        XCTAssertNotNil(state.numberField1)
//        XCTAssertNotNil(state.numberField2)
//
//        state.numberField2 = 12.34567
//        XCTAssert(state.numberField1 === state.numberField2, "change the other side")
//        XCTAssertNotNil(state.numberField1)
//        XCTAssertNotNil(state.numberField2)
//
//        state.numberField1 = 2
//        XCTAssert(state.numberField1 === state.numberField2, "change back the first side")
//        XCTAssertNotNil(state.numberField1)
//        XCTAssertNotNil(state.numberField2)
//
//
//
//        state.numberField1 = nil
//        XCTAssert(state.numberField1 === state.numberField2, "binding to nil")
//        XCTAssertNil(state.numberField2)
//
//        state.numberField1 = NSNumber(unsignedInt: arc4random())
//        XCTAssert(state.numberField1 === state.numberField2, "binding to random")
//        XCTAssertNotNil(state.numberField2)
//
//
//        // binding optional numberField1 to non-optional numberField3
//        let obzn3 = state∞(state.numberField3)
//
//        let bind2 = (obzn3, { $0 as NSNumber? }) <~∞~> (obzn1, { $0 })
//
//        state.numberField1 = 67823
//        XCTAssert(state.numberField1 === state.numberField3)
//        XCTAssertNotNil(state.numberField3)
//
//        state.numberField1 = nil
//        XCTAssertEqual(67823, state.numberField3)
//        XCTAssertNotNil(state.numberField3, "non-optional field should not be nil")
//        XCTAssertNil(state.numberField1)
//
//        let obzd = state∞(state.doubleField)
//
//        // FIXME: crash with the cast
//
////        let bind3 = obzn1 <?∞?> obzd
////
////        state.doubleField = 5
////        XCTAssertEqual(state.doubleField, state.numberField1?.doubleValue ?? -999)
////
////        state.numberField1 = nil
////        XCTAssertEqual(5, state.doubleField, "niling optional field should not alter bound non-optional field")
////
////        state.doubleField++
////        XCTAssertEqual(state.doubleField, state.numberField1?.doubleValue ?? -999)
////
////        state.numberField1 = 9.9
////        XCTAssertEqual(9.9, state.doubleField)
////
////        // ensure that assigning nil to the numberField1 doesn't clobber the doubleField
////        state.numberField1 = nil
////        XCTAssertEqual(9.9, state.doubleField)
////
////        state.doubleField = 9876
////        XCTAssertEqual(9876, state.numberField1?.doubleValue ?? -999)
////
////        state.numberField1 = 123
////        XCTAssertEqual(123, state.doubleField)
////
////        state.numberField2 = 456 // numberField2 <~=~> numberField1 <?=?> doubleField
////        XCTAssertEqual(456, state.doubleField)
//    }
//
//    func testLossyConduits() {
//        let state = StatefulObject()
//
//        // transfet between an int and a double field
//        let obzi = state∞(state.intField)
//        let obzd = state∞(state.doubleField)
//
//        let obzi_obzd = obzi <~∞~> obzd
//
//        state.intField = 1
//        XCTAssertEqual(1, state.intField)
//        XCTAssertEqual(1.0, state.doubleField)
//
//        state.doubleField++
//        XCTAssertEqual(2, state.intField)
//        XCTAssertEqual(2.0, state.doubleField)
//
//        state.doubleField += 0.8
//        XCTAssertEqual(2, state.intField)
//        XCTAssertEqual(2.8, state.doubleField)
//
//        state.intField--
//        XCTAssertEqual(1, state.intField)
//        XCTAssertEqual(1.0, state.doubleField)
//    }
//
////    func testHaltingConduits() {
////        // create a binding from an int to a float; when the float is set to a round number, it changes the int, otherwise it halts
////        typealias T1 = Float
////        typealias T2 = Float
////        var x = ∞(T1(0))∞
////        var y = ∞(T2(0))∞
////
////        let b1 = x <=∞~> (y, { $0 == round($0) ? Optional<T1>.Some(T1($0)) : Optional<T1>.None })
////
////        x <- 2
////        XCTAssertEqual(T1(2), x.value)
////        XCTAssertEqual(T2(2.0), y.value)
////
////        y <- 3
////        XCTAssertEqual(T1(3), x.value)
////        XCTAssertEqual(T2(3.0), y.value)
////
////        y <- 9.9
////        XCTAssertEqual(T1(3), x.value)
////        XCTAssertEqual(T2(9.9), y.value)
////
////        y <- 17
////        XCTAssertEqual(T1(17), x.value)
////        XCTAssertEqual(T2(17.0), y.value)
////
////        x.value = (x.value + 1)
////        XCTAssertEqual(T1(18), x.value)
////        XCTAssertEqual(T2(18.0), y.value)
////
////        y.value = (y.value + 0.5)
////        XCTAssertEqual(T1(18), x.value)
////        XCTAssertEqual(T2(18.5), y.value)
////    }
//
//    func testConversionConduits() {
//        var num = ∞((Double(0.0)))∞
//        num <- 0
//
//        let decimalFormatter = NSNumberFormatter()
//        decimalFormatter.numberStyle = .DecimalStyle
//
//        let toDecimal: (Double)->(String?) = { decimalFormatter.stringFromNumber($0) }
//        let fromDecimal: (String?)->(Double?) = { $0 == nil ? nil : decimalFormatter.numberFromString($0!)?.doubleValue }
//
//        let state1 = StatefulObject()
//        let state1s = state1∞(state1.optionalStringField)
//        let b1 = (num, toDecimal) <~∞~> (state1s, fromDecimal)
//
//
//        let percentFormatter = NSNumberFormatter()
//        percentFormatter.numberStyle = .PercentStyle
//
//        let toPercent: (Double)->(NSString?) = { percentFormatter.stringFromNumber($0) }
//        let fromPercent: (NSString?)->(Double?) = { percentFormatter.numberFromString($0 ?? "AAA")?.doubleValue }
//
//        let state2 = StatefulObject()
//        let state2s = state2∞(state2.optionalNSStringField)
//        let b2 = (num, toPercent) <~∞~> (state2s, fromPercent)
//
//
//        let spellingFormatter = NSNumberFormatter()
//        spellingFormatter.numberStyle = .SpellOutStyle
//
//        let state3 = StatefulObject()
//        let state3s = state3∞(state3.requiredStringField)
//
//        let toSpelled: (Double)->(String?) = { spellingFormatter.stringFromNumber($0) as String? }
//        let fromSpelled: (String)->(Double?) = { spellingFormatter.numberFromString($0)?.doubleValue }
//        let b3 = (num, toSpelled) <~∞~> (state3s, fromSpelled)
//
//        num.value = (num.value + 1)
//        XCTAssertEqual(1, num.value)
//        XCTAssertEqual("1", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("100%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("one", state3.requiredStringField)
//
//        num.value = (num.value + 1)
//        XCTAssertEqual(2, num.value)
//        XCTAssertEqual("2", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("200%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("two", state3.requiredStringField)
//
//        state1.optionalStringField = "3"
//        XCTAssertEqual(3, num.value)
//        XCTAssertEqual("3", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("300%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("three", state3.requiredStringField)
//
//        state2.optionalNSStringField = "400%"
//        XCTAssertEqual(4, num.value)
//        XCTAssertEqual("4", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("400%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("four", state3.requiredStringField)
//
//        state3.requiredStringField = "five"
//        XCTAssertEqual(5, num.value)
//        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("500%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("five", state3.requiredStringField)
//
//        state3.requiredStringField = "gibberish" // won't parse, so numbers should remain unchanged
//        XCTAssertEqual(5, num.value)
//        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("500%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("gibberish", state3.requiredStringField)
//
//        state2.optionalNSStringField = nil
//        XCTAssertEqual(5, num.value)
//        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
//        XCTAssertNil(state2.optionalNSStringField)
//        XCTAssertEqual("gibberish", state3.requiredStringField)
//
//        num <- 5.4321
//        XCTAssertEqual(5.4321, num.value)
//        XCTAssertEqual("5.432", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("543%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("five point four three two one", state3.requiredStringField)
//
//        state2.optionalNSStringField = "18.3%"
//        XCTAssertEqual(0.183, num.value)
//        XCTAssertEqual("0.183", state1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("18%", state2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("zero point one eight three", state3.requiredStringField)
//
//    }
//
//    func testOptionalObservables() {
//        let state = StatefulObject()
//
//        #if DEBUG_CHANNELZ
//        let startObserverCount = ChannelZKeyValueObserverCount
//        #endif
//
//        var requiredNSStringField: NSString = ""
//        // TODO: observable immediately gets deallocated unless we hold on to it
////        let a1a = state.observable(state.requiredNSStringField, keyPath: "requiredNSStringField").receive({ requiredNSStringField = $0 })
//
//        // FIXME: this seems to hold on to an extra allocation
//        // let a1 = sieve(state.observable(state.requiredNSStringField, keyPath: "requiredNSStringField"))
//
//        let a1 = state.channelz(state.requiredNSStringField)
//        var a1a = a1.receive({ requiredNSStringField = $0 })
//
//        #if DEBUG_CHANNELZ
//        XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1, "observer should not have been cleaned up")
//        #endif
//
//        state.requiredNSStringField = "foo"
//        XCTAssert(requiredNSStringField == "foo", "failed: \(requiredNSStringField)")
//
////        let preDetachCount = countElements(a1.subscriptions)
//        a1a.cancel()
////        let postDetachCount = countElements(a1.subscriptions)
////        XCTAssertEqual(postDetachCount, preDetachCount - 1, "canceling the subscription should have removed it from the subscription list")
//
//        state.requiredNSStringField = "foo1"
//        XCTAssertNotEqual(requiredNSStringField, "foo1", "canceled observable should not have fired")
//
//        var optionalNSStringField: NSString?
//        let a2 = state∞(state.optionalNSStringField)
//        a2.receive({ optionalNSStringField = $0 })
//        
//        XCTAssert(optionalNSStringField == nil)
//
//        state.optionalNSStringField = nil
//        XCTAssertNil(optionalNSStringField)
//
//        state.optionalNSStringField = "foo"
//        XCTAssert(optionalNSStringField?.description == "foo", "failed: \(optionalNSStringField)")
//
//        state.optionalNSStringField = nil
//        XCTAssertNil(optionalNSStringField)
//    }
//
//    func testNumericConversion() {
//        let fl: Float = convertNumericType(Double(2.34))
//        XCTAssertEqual(fl, Float(2.34))
//
//        let intN : Int = convertNumericType(Double(2.34))
//        XCTAssertEqual(intN, Int(2))
//
//        let uint64 : UInt64 = convertNumericType(Double(-2.34))
//        XCTAssertEqual(uint64, UInt64(2)) // conversion runs abs()
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.doubleField <=∞=> c∞c.doubleField
//            c.doubleField++
//            XCTAssertEqual(s.doubleField.value, c.doubleField)
//            s.doubleField.value++
//            XCTAssertEqual(s.doubleField.value, c.doubleField)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.floatField <=∞=> c∞c.floatField
//            c.floatField++
//            XCTAssertEqual(s.floatField.value, c.floatField)
//            s.floatField.value++
//            XCTAssertEqual(s.floatField.value, c.floatField)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.intField <=∞=> c∞c.intField
//            c.intField++
//            XCTAssertEqual(s.intField.value, c.intField)
//            s.intField.value++
//            XCTAssertEqual(s.intField.value, c.intField)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.uInt32Field <=∞=> c∞c.uInt32Field
//            c.uInt32Field++
//            XCTAssertEqual(s.uInt32Field.value, c.uInt32Field)
//            s.uInt32Field.value++
//            // FIXME: this fails; maybe the Obj-C conversion is not exact?
//            // XCTAssertEqual(s.uInt32Field.value, c.uInt32Field)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.intField <~∞~> c∞c.numberField
//            c.numberField = c.numberField.integerValue + 1
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//            s.intField.value++
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.numberField <~∞~> c∞c.intField
//            c.intField++
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//            s.numberField.value = s.numberField.value.integerValue + 1
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.numberField <~∞~> c∞c.doubleField
//            c.doubleField++
//            XCTAssertEqual(s.doubleField.value, c.numberField.doubleValue)
//            s.numberField.value = s.numberField.value.doubleValue + 1
//            XCTAssertEqual(s.doubleField.value, c.numberField.doubleValue)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.numberField <~∞~> c∞c.int8Field
//            // FIXME: crash!
////            c.int8Field++
//            XCTAssertEqual(s.int8Field.value, c.numberField.charValue)
////            s.numberField.value = NSNumber(char: s.numberField.value.charValue + 1)
//            XCTAssertEqual(s.int8Field.value, c.numberField.charValue)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.numberField <~∞~> c∞c.intField
//            c.intField++
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//            s.numberField.value = s.numberField.value.integerValue + 1
//            XCTAssertEqual(s.intField.value, c.numberField.integerValue)
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.doubleField <~∞~> c∞c.floatField
//            c.floatField++
//            XCTAssertEqual(s.doubleField.value, Double(c.floatField))
//            s.doubleField.value++
//            XCTAssertEqual(s.doubleField.value, Double(c.floatField))
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.doubleField <~∞~> c∞c.intField
//            c.intField++
//            XCTAssertEqual(s.doubleField.value, Double(c.intField))
//            s.doubleField.value++
//            XCTAssertEqual(s.doubleField.value, Double(c.intField))
//            s.doubleField.value += 0.5
//            XCTAssertNotEqual(s.doubleField.value, Double(c.intField)) // will be rounded
//        }
//
//        autoreleasepool {
//            let s = NumericHolderStruct()
//            let c = NumericHolderClass()
//            s.decimalNumberField <~∞~> c∞c.numberField
//            c.numberField = c.numberField.integerValue + 1
//            XCTAssertEqual(s.decimalNumberField.value, c.numberField)
//            s.decimalNumberField.value = NSDecimalNumber(string: "9e12")
//            XCTAssertEqual(s.decimalNumberField.value, c.numberField)
//        }
//
//        autoreleasepool {
//            let o = NumericHolderOptionalStruct()
//            let c = NumericHolderClass()
//            c∞c.doubleField <=∞=> o.doubleField
//            o.doubleField.value = 12.34
//            XCTAssertEqual(12.34, c.doubleField)
//
//            // FIXME: crash (“could not set nil as the value for the key doubleField”), since NumericHolderClass.doubleField cannot accept optionals; the conduit works because non-optionals are allowed to be cast to optionals
////            o.doubleField.value = nil
//        }
//    }
//
//    func testValueToReference() {
//        let startCount = StatefulObjectCount
//        let countObs: () -> (Int) = { StatefulObjectCount - startCount }
//
//        var holder2: StatefulObjectHolder?
//        autoreleasepool {
//            XCTAssertEqual(0, countObs())
//            let ob = StatefulObject()
//            XCTAssertEqual(1, countObs())
//
//            let holder1 = StatefulObjectHolder(ob: ob)
//            holder2 = StatefulObjectHolder(ob: ob)
//            XCTAssert(holder2 != nil)
//        }
//
//        XCTAssertEqual(1, countObs())
//        XCTAssert(holder2 != nil)
//        holder2 = nil
//        XCTAssertEqual(0, countObs())
//    }
//
//
//    /// Demonstrates using bindings with Core Data
//    func testManagedObjectContext() {
//        autoreleasepool {
//            var error: NSError?
//
//            let attrName = NSAttributeDescription()
//            attrName.name = "fullName"
//            attrName.attributeType = .StringAttributeType
//            attrName.defaultValue = "John Doe"
//            attrName.optional = true
//
//            let attrAge = NSAttributeDescription()
//            attrAge.name = "age"
//            attrAge.attributeType = .Integer16AttributeType
//            attrAge.optional = false
//
//            let personEntity = NSEntityDescription()
//            personEntity.name = "Person"
//            personEntity.properties = [attrName, attrAge]
//            personEntity.managedObjectClassName = NSStringFromClass(CoreDataPerson.self)
//
//            let model = NSManagedObjectModel()
//            model.entities = [personEntity]
//
//            let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
//            let store = psc.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
//
//            let ctx = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
//            ctx.persistentStoreCoordinator = psc
//
//            var saveCount = 0
//            let saveCountReceptor = ctx.notifyz(NSManagedObjectContextDidSaveNotification).receive { _ in saveCount = saveCount + 1 }
//
//
//
//            var inserted = 0
//            ctx.changedInsertedZ.receive { inserted = $0.count }
//
//            var updated = 0
//            ctx.changedUpdatedZ.receive { updated = $0.count }
//
//            var deleted = 0
//            ctx.changedDeletedZ.receive { deleted = $0.count }
//
//            var refreshed = 0
//            ctx.changedRefreshedZ.receive { refreshed = $0.count }
//
//            var invalidated = 0
//            ctx.chagedInvalidatedZ.receive { invalidated = $0.count }
//
//
//            XCTAssertNil(error)
//
//            let ob = NSManagedObject(entity: personEntity, insertIntoManagedObjectContext: ctx)
//
//            // make sure we really created our managed object subclass
//            XCTAssertEqual("ChannelZTests.CoreDataPerson_Person_", NSStringFromClass(ob.dynamicType))
//            let person = ob as CoreDataPerson
//
//            var ageChanges = 0, nameChanges = 0
//            // sadly, automatic keypath identification doesn't yet work for NSManagedObject subclasses
////            person∞person.age ∞> { _ in ageChanges += 1 }
////            person∞person.fullName ∞> { _ in nameChanges += 1 }
//
//            // @NSManaged fields can secretly be nil
//            person∞(person.age as Int16?, "age") ∞> { _ in ageChanges += 1 }
//            person∞(person.fullName, "fullName") ∞> { _ in nameChanges += 1 }
//
//            person.fullName = "Edward Norton"
//
//            // “CoreData: error: Property 'setAge:' is a scalar type on class 'ChannelTests.CoreDataPerson' that does not match its Entity's property's scalar type.  Dynamically generated accessors do not support implicit type coercion.  Cannot generate a setter method for it.”
//            person.age = 65
//
//            // field tracking doesn't work either...
////            XCTAssertEqual(1, nameChanges)
////            XCTAssertEqual(1, ageChanges)
//
////            ob.setValue("Bob Jones", forKey: "fullName")
////            ob.setValue(65 as NSNumber, forKey: "age")
//
//            XCTAssertEqual(0, saveCount)
//
//            ctx.save(&error)
//            XCTAssertNil(error)
//            XCTAssertEqual(1, saveCount)
//            XCTAssertEqual(1, inserted)
//            XCTAssertEqual(0, updated)
//            XCTAssertEqual(0, deleted)
//
////            ob.setValue("Frank Underwood", forKey: "fullName")
//            person.fullName = "Tyler Durden"
//
////            XCTAssertEqual(2, nameChanges)
//
//            ctx.save(&error)
//            XCTAssertNil(error)
//            XCTAssertEqual(2, saveCount)
//            XCTAssertEqual(1, inserted)
//            XCTAssertEqual(0, updated)
//            XCTAssertEqual(0, deleted)
//
//            ctx.deleteObject(ob)
//
//            ctx.save(&error)
//            XCTAssertNil(error)
//            XCTAssertEqual(3, saveCount)
//            XCTAssertEqual(0, inserted)
//            XCTAssertEqual(0, updated)
//            XCTAssertEqual(1, deleted)
//
//            ctx.reset()
//        }
//
//        XCTAssertEqual(0, ChannelZKeyValueObserverCount, "KV observers were not cleaned up")
//    }
//
//    #if os(OSX) // bindings are only available on OSX
//    public func testCocoaBindings() {
//        let objc = NSObjectController(content: NSNumber(integer: 1))
//        XCTAssertEqual(1, objc.content as? NSNumber ?? -999)
//
//        let state1 = StatefulObject()
//        state1.numberField3 = 0
//
//        XCTAssertEqual(0, state1.numberField3)
//        objc.bind("content", toObject: state1, withKeyPath: "numberField3", options: nil)
//        XCTAssertEqual(0, state1.numberField3)
//
//        objc.content = 2
//        XCTAssertEqual(2, objc.content as? NSNumber ?? -999)
//
//        state1.numberField3 = 3
//        XCTAssertEqual(3, objc.content as? NSNumber ?? -999)
//        XCTAssertEqual(3, state1.numberField3)
//
//
//        let state2 = StatefulObject()
//        state2.numberField3 = 0
//        state2.bind("numberField3", toObject: state1, withKeyPath: "numberField3", options: nil)
//
//        let state2sieve = state2∞(state2.numberField3, "numberField3") ∞> { num in
//            // println("changing number to: \(num)")
//        }
//        state1.numberField3 = 4
//
//        XCTAssertEqual(4, objc.content as? NSNumber ?? -999)
//        XCTAssertEqual(4, state1.numberField3)
//        XCTAssertEqual(4, state2.numberField3)
//
//        // need to manually unbind in order to release memory
//        objc.unbind("content")
//        state2.unbind("numberField3")
//    }
//    #endif
//
//
//    public func testDetachedReceptor() {
//        var subscription: Receptor?
//        autoreleasepool {
//            let state = StatefulObject()
//            subscription = state.channelz(state.requiredNSStringField).receive({ _ in })
//            XCTAssertEqual(1, StatefulObjectCount)
//        }
//
//        XCTAssertEqual(0, StatefulObjectCount)
//        subscription!.cancel() // ensure that the subscription doesn't try to access a bad pointer
//    }
//
//    public func teststFieldRemoval() {
//        let startCount = ChannelZKeyValueObserverCount
//        let startObCount = StatefulObjectCount
//        autoreleasepool {
//            var changes = 0
//            let ob = StatefulObject()
//            XCTAssertEqual(0, ob.intField)
//            (ob ∞ ob.intField).receive { _ in changes += 1 }
//            XCTAssertEqual(1, ChannelZKeyValueObserverCount - startCount)
//
//            XCTAssertEqual(0, changes)
//            ob.intField++
//            XCTAssertEqual(1, changes)
//            ob.intField++
//            XCTAssertEqual(2, changes)
//        }
//
//        XCTAssertEqual(0, ChannelZKeyValueObserverCount - startCount)
//        XCTAssertEqual(0, StatefulObjectCount - startObCount)
//    }
//
//    public func testManyKeyReceptors() {
//        let startCount = ChannelZKeyValueObserverCount
//        let startObCount = StatefulObjectCount
//
//        autoreleasepool {
//            let ob = StatefulObject()
//
//            for count in 1...20 {
//                var changes = 0
//
//                for i in 1...count {
//                    // using the keypath name because it is faster than auto-identification
//                    (ob ∞ (ob.intField, "intField")).receive { _ in changes += 1 }
//                }
//                XCTAssertEqual(1, ChannelZKeyValueObserverCount - startCount)
//
//                XCTAssertEqual(0 * count, changes)
//                ob.intField++
//                XCTAssertEqual(1 * count, changes)
//                ob.intField++
//                XCTAssertEqual(2 * count, changes)
//            }
//        }
//
//        XCTAssertEqual(0, ChannelZKeyValueObserverCount - startCount)
//        XCTAssertEqual(0, StatefulObjectCount - startObCount)
//    }
//
//    public func testManyObserversOnBlockOperation() {
//        let state = StatefulObject()
//        XCTAssertEqual("ChannelZTests.StatefulObject", NSStringFromClass(state.dynamicType))
//        state∞state.intField ∞> { _ in }
//        XCTAssertEqual("NSKVONotifying_ChannelZTests.StatefulObject", NSStringFromClass(state.dynamicType))
//
//        let operation = NSOperation()
//        XCTAssertEqual("NSOperation", NSStringFromClass(operation.dynamicType))
//        operation∞operation.cancelled ∞> { _ in }
//        operation∞(operation.cancelled, "cancelled") ∞> { _ in }
//        XCTAssertEqual("NSKVONotifying_NSOperation", NSStringFromClass(operation.dynamicType))
//
//        // progress is not automatically instrumented with NSKVONotifying_ (implying that it handles its own KVO)
//        let progress = NSProgress()
//        XCTAssertEqual("NSProgress", NSStringFromClass(progress.dynamicType))
//        progress∞progress.fractionCompleted ∞> { _ in }
//        progress∞(progress.fractionCompleted, "fractionCompleted") ∞> { _ in }
//        XCTAssertEqual("NSProgress", NSStringFromClass(progress.dynamicType))
//
//        for j in 1...10 {
//            autoreleasepool {
//                let op = NSOperation()
//                let channel = op∞(op.cancelled, "cancelled")
//
//                var subscriptions: [Receptor] = []
//                for i in 1...10 {
//                    let subscription = channel ∞> { _ in }
//                    subscriptions += [subscription as Receptor]
//                }
//
//                // we will crash if we rely on the KVO auto-removal here
//                subscriptions.map { $0.cancel() }
//            }
//        }
//    }
//
//    public func testNSOperationObservers() {
//        for j in 1...10 {
//            autoreleasepool {
//                let op = NSOperation()
//                XCTAssertEqual("NSOperation", NSStringFromClass(op.dynamicType))
//
//                var ptrs: [UnsafeMutablePointer<Void>] = []
//                for i in 1...10 {
//                    let ptr = UnsafeMutablePointer<Void>()
//                    ptrs += [ptr]
//                    op.addObserver(self, forKeyPath: "cancelled", options: .New, context: ptr)
//                }
//                XCTAssertEqual("NSKVONotifying_NSOperation", NSStringFromClass(op.dynamicType))
//                // println("removing from: \(NSStringFromClass(op.dynamicType))")
//                for ptr in ptrs {
//                    XCTAssertEqual("NSKVONotifying_NSOperation", NSStringFromClass(op.dynamicType))
//                    op.removeObserver(self, forKeyPath: "cancelled", context: ptr)
//                }
//                // gets swizzled back to the original class when there are no more observers
//                XCTAssertEqual("NSOperation", NSStringFromClass(op.dynamicType))
//            }
//        }
//
//    }
//
//    let AutoKeypathPerfomanceCount = 10
//    public func testAutoKeypathPerfomanceWithoutName() {
//        let prog = NSProgress()
//        for i in 1...AutoKeypathPerfomanceCount {
//            prog∞prog.totalUnitCount ∞> { _ in }
//        }
//    }
//
//    public func testAutoKeypathPerfomanceWithName() {
//        let prog = NSProgress()
//        for i in 1...AutoKeypathPerfomanceCount {
//            prog∞(prog.totalUnitCount, "totalUnitCount") ∞> { _ in }
//        }
//    }
//
//    public func testFoundationExtensions() {
//        var counter = 0
//
//        let constraint = NSLayoutConstraint()
//        constraint∞constraint.constant ∞> { _ in counter += 1 }
//        constraint∞constraint.active ∞> { _ in counter += 1 }
//
//        let undo = NSUndoManager()
//        undo.notifyz(NSUndoManagerDidUndoChangeNotification) ∞> { _ in counter += 1 }
//        undo∞undo.canUndo ∞> { _ in counter += 1 }
//        undo∞undo.canRedo ∞> { _ in counter += 1 }
//        undo∞undo.levelsOfUndo ∞> { _ in counter += 1 }
//        undo∞undo.undoActionName ∞> { _ in counter += 1 }
//        undo∞undo.redoActionName ∞> { _ in counter += 1 }
//
//
//        let df = NSDateFormatter()
//        df∞df.dateFormat ∞> { _ in counter += 1 }
//        df∞df.locale ∞> { _ in counter += 1 }
//        df∞df.timeZone ∞> { _ in counter += 1 }
//        df∞df.eraSymbols ∞> { _ in counter += 1 }
//
//        let comps = NSDateComponents()
//        comps∞comps.date ∞> { _ in counter += 1 }
//        comps∞comps.era ∞> { _ in counter += 1 }
//        comps∞comps.year ∞> { _ in counter += 1 }
//        comps∞comps.month ∞> { _ in counter += 1 }
//        comps.year = 2016
//        XCTAssertEqual(0, --counter)
//
//        let prog = NSProgress(totalUnitCount: 100)
//        prog∞prog.totalUnitCount ∞> { _ in counter += 1 }
//        prog.totalUnitCount = 200
//        XCTAssertEqual(0, --counter)
//
//        prog∞prog.fractionCompleted ∞> { _ in counter += 1 }
//        prog.completedUnitCount++
//        XCTAssertEqual(0, --counter)
//    }
//
//    public func testPrime() {
//        let c = NumericHolderClass()
//        var count = 0
//        let channel = c∞c.doubleField
//        let subscription = channel ∞> { _ in count += 1 }
//        XCTAssertEqual(0, count)
//
//
//        // ensure that priming the channel actually causes it to send out a value
//        subscription.request()
//        XCTAssertEqual(0.0, channel.value)
//        XCTAssertEqual(1, count)
//
//        subscription.request()
//        XCTAssertEqual(0.0, channel.value)
//        XCTAssertEqual(2, count)
//    }
//
//    public func testPullFiltered() {
//        let intField = ∞(Int(0))∞
//
//        let ch1 = intField.map({ Int32($0) }).map({ Double($0) }).map({ Float($0) })
//
//        let ch2 = intField.map({ Int32($0) }).map({ Double($0) }).map({ Float($0) }).channel()
//
//        let intToUIntChannel = intField.filter({ $0 >= 0 }).map({ UInt($0) })
//        var lastUInt = UInt(0)
//        intToUIntChannel.receive({ lastUInt = $0 })
//
//        intField.value = 10
//        XCTAssertEqual(UInt(10), lastUInt)
//        XCTAssertEqual(Int(10), intToUIntChannel.value)
//
//        intField.value = -1
//        XCTAssertEqual(UInt(10), lastUInt, "changing a filtered value shouldn't pass down")
//
//        XCTAssertEqual(-1, intToUIntChannel.value, "pulling a filtered field should yield nil")
//    }
//
//    public func testChannelSignatures() {
//        let small = ∞(Int8(0))∞
//        let larger: MappedChannel<MappedChannel<MappedChannel<ChannelZ<Int8>, Int16>, Int32>, Int64> = small.map({ Int16($0) }).map({ Int32($0) }).map({ Int64($0) })
//        let largerz: ChannelOf<Int8, Int64> = larger.channel()
//
//        let large = ∞(Int64(0))∞
//        let smallerRaw: MappedChannel<MappedChannel<MappedChannel<ChannelZ<Int64>, Int32>, Int16>, Int8> = large.map({ Int32($0) }).map({ Int16($0) }).map({ Int8($0) })
//        let smallerClamped: MappedChannel<MappedChannel<MappedChannel<ChannelZ<Int64>, Int32>, Int16>, Int8> = large.map({ let ret: Int32 = $0 > Int64(Int32.max) ? Int32.max : $0 < Int64(Int32.min) ? Int32.min : Int32($0); return ret }).map({ let ret: Int16 = $0 > Int32(Int16.max) ? Int16.max : $0 < Int32(Int16.min) ? Int16.min : Int16($0); return ret }).map({ let ret: Int8 = $0 > Int16(Int8.max) ? Int8.max : $0 < Int16(Int8.min) ? Int8.min : Int8($0); return ret })
//
////        let smaller2 = large.filter({ $0 >= Int64(Int32.min) && $0 <= Int64(Int32.max) }).map({ Int32($0) }).filter({ $0 >= Int32(Int16.min) && $0 <= Int32(Int16.max) }).map({ Int16($0) }) // .filter({ $0 >= Int16(Int8.min) && $0 <= Int16(Int8.max) }).map({ Int8($0) })
//        let smallerz: ChannelOf<Int64, Int8> = smallerClamped.channel()
//
//        let link = conduit(largerz, smallerz)
//
//        large.value = 1
//        XCTAssertEqual(large.value, Int64(small.value), "stable conduit")
//
//        large.value = Int64(Int8.max)
//        XCTAssertEqual(large.value, Int64(small.value), "stable conduit")
//
//        large.value = Int64(Int8.max) + 1
//        XCTAssertNotEqual(large.value, Int64(small.value), "unstable conduit")
//
//    }
//
//    public func testObservableCleanup() {
//
//        autoreleasepool {
//            var counter = 0, opened = 0, closed = 0
//
//            let undo = InstanceTrackingUndoManager()
//            undo.beginUndoGrouping()
//
//            XCTAssertEqual(1, InstanceTrackingUndoManagerInstanceCount)
//            undo∞undo.canUndo ∞> { _ in counter += 1 }
//            undo∞undo.canRedo ∞> { _ in counter += 1 }
//            undo∞undo.levelsOfUndo ∞> { _ in counter += 1 }
//            undo∞undo.undoActionName ∞> { _ in counter += 1 }
//            undo∞undo.redoActionName ∞> { _ in counter += 1 }
//            undo.notifyz(NSUndoManagerDidOpenUndoGroupNotification).receive({ _ in opened += 1 })
//            undo.notifyz(NSUndoManagerDidCloseUndoGroupNotification).receive({ _ in closed += 1 })
//
//
//            XCTAssertEqual(0, counter)
//
//            XCTAssertEqual(0, opened)
//
//            undo.beginUndoGrouping()
//            XCTAssertEqual(0, --opened)
//            XCTAssertEqual(0, closed)
//
//            undo.endUndoGrouping()
//            XCTAssertEqual(0, opened)
//            XCTAssertEqual(0, --closed)
//
//            undo.endUndoGrouping()
//            undo.undo() // final undo needed or else the NSUndoManager won't be release (by the run loop?)
//
//            XCTAssertEqual(1, InstanceTrackingUndoManagerInstanceCount)
//        }
//
//        XCTAssertEqual(0, InstanceTrackingUndoManagerInstanceCount)
//    }
//
//    public func testOperationChannels() {
//        // wrap test in an XCTAssert because it will perform a try/catch
//
//        // file:///opt/src/impathic/glimpse/ChannelZ/ChannelTests/ChannelTests.swift: test failure: -[ChannelTests testOperationChannels()] failed: XCTAssertTrue failed: throwing "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x10038d5b0> for the key path "isFinished" from <NSBlockOperation 0x1003854d0> because it is not registered as an observer." -
//        XCTAssert(operationChannelTest())
//    }
//
//    public func operationChannelTest() -> Bool {
//
//        for (doCancel, doStart) in [(true, false), (false, true)] {
//            let op = NSBlockOperation { () -> Void in }
//
//            let cancelChannel = op.channelz(op.cancelled)
//
//            var cancelled: Bool = false
//            op.channelz(op.cancelled).receive { cancelled = $0 }
//            var asynchronous: Bool = false
//            op.channelz(op.asynchronous).receive { asynchronous = $0 }
//            var executing: Bool = false
//
//            op.channelz(op.executing).receive { [unowned op] in
//                executing = $0
//                let str = ("executing=\(executing) op: \(op)")
//            }
//
//            op.channelz(op.executing).map({ !$0 }).filter({ $0 }).receive { [unowned op] in
//                let str = ("executing=\($0) op: \(op)")
//            }
//
//            var finished: Bool = false
//            op.channelz(op.finished).receive { finished = $0 }
//            var ready: Bool = false
//            op.channelz(op.ready).receive { ready = $0 }
//
//
//            XCTAssertEqual(false, cancelled)
//            XCTAssertEqual(false, asynchronous)
//            XCTAssertEqual(false, executing)
//            XCTAssertEqual(false, finished)
//            XCTAssertEqual(false, ready)
//
//            if doCancel {
//                op.cancel()
//            } else if doStart {
//                op.start()
//            }
//
//            XCTAssertEqual(doCancel, cancelled)
//            XCTAssertEqual(false, asynchronous)
//            XCTAssertEqual(false, executing)
//            XCTAssertEqual(doStart, finished)
////            XCTAssertEqual(false, ready) // seems rather indeterminate
//        }
//
//        return true
//    }
//
////    public func testBindingCombinations() {
////        autoreleasepool {
////            XCTAssertEqual(0, StatefulObjectCount)
////
////            let state1 = StatefulObjectSubclass()
////            let state2 = StatefulObject()
////            let state3 = StatefulObjectSubSubclass()
////            let state4 = StatefulObject()
////
//////            let flat2 : ChannelOf<(Int, Int), (Int, Int)> = state1∞state1.intField + state2∞state2.intField
//////
//////            let flat3 : ChannelOf<((Int, Int), Int), ((Int, Int), Int)> = flat2 + state3∞state3.intField
//////
////////            let flat3 : ChannelOf<((Int, Int), Int), ((Int, Int), Int)> = state1∞state1.intField + state2∞state2.intField + state3∞state3.intField
//////
////////            let flat3 : ChannelOf<(Int, Int, Int), (Int, Int, Int)> = state1∞state1.intField + state2∞state2.intField + state3∞state3.intField
//////
//////            let flat4 = state1∞state1.intField + state2∞state2.intField + state3∞state3.intField + state4∞state4.intField
//////
//////            flat4 ∞> { (((i1: Int, i2: Int), i3: Int), i4: Int) in
////////                println("channel change: \(i1) \(i2) \(i3) \(i4)")
//////            }
//////
////            state1∞state1.intField + state2∞state2.intField <=∞=> state4∞state4.intField + state3∞state3.intField
////
////            state1.intField++
////            XCTAssertEqual(state1.intField, 1)
////            XCTAssertEqual(state2.intField, 0)
////            XCTAssertEqual(state3.intField, 0)
////            XCTAssertEqual(state4.intField, 1)
////
////            state2.intField++
////            XCTAssertEqual(state1.intField, 1)
////            XCTAssertEqual(state2.intField, 1)
////            XCTAssertEqual(state3.intField, 1)
////            XCTAssertEqual(state4.intField, 1)
////
////            state3.intField++
////            XCTAssertEqual(state1.intField, 1)
////            XCTAssertEqual(state2.intField, 2)
////            XCTAssertEqual(state3.intField, 2)
////            XCTAssertEqual(state4.intField, 1)
////
////            state4.intField++
////            XCTAssertEqual(state1.intField, 2)
////            XCTAssertEqual(state2.intField, 2)
////            XCTAssertEqual(state3.intField, 2)
////            XCTAssertEqual(state4.intField, 2)
////
////            XCTAssertEqual(4, StatefulObjectCount)
////        }
////        
////        XCTAssertEqual(0, StatefulObjectCount)
////    }
//
//    public func testStraightConduit() {
//        let state1 = StatefulObject()
//        let state2 = StatefulObject()
//
//        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
//        let off = 10
//        state1∞state1.intField <=∞=> state2∞state2.intField
//
//        state1.intField++
//        XCTAssertEqual(state1.intField, 1)
//        XCTAssertEqual(state2.intField, 1)
//
//        state2.intField++
//        XCTAssertEqual(state1.intField, 2)
//        XCTAssertEqual(state2.intField, 2)
//    }
//
//    /// Test reentrancy guards for conduits that would never achieve equilibrium
//    public func testKVOReentrancy() {
//        let state1 = StatefulObject()
//        let state2 = StatefulObject()
//
//        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
//        let off = 10
//        (state1∞state1.intField).map({ $0 + 10 }) <=∞=> state2∞state2.intField
//
//        state1.intField++
//        XCTAssertEqual(state1.intField, 1 + (off * 2))
//        XCTAssertEqual(state2.intField, 1 + (off * 2))
//
//        state2.intField++
//        XCTAssertEqual(state1.intField, 2 + (off * 3))
//        XCTAssertEqual(state2.intField, 2 + (off * 3))
//    }
//
//    /// Test reentrancy guards for conduits that would never achieve equilibrium
//    public func testSwiftReentrancy() {
//        let state1 = ∞Int(0)∞
//        let state2 = ∞Int(0)∞
//        let state3 = ∞Int(0)∞
//
////        ChannelZReentrancyLimit = 0
//
//        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
//        state1.map({ $0 + 1 }) <=∞=> state2
//        state2.map({ $0 + 2 }) <=∞=> state3
//        state3.map({ $0 + 3 }) <=∞=> state1
//        state3.map({ $0 + 4 }) <=∞=> state2
//        state3.map({ $0 + 5 }) <=∞=> state3
//
////        let base = 12 //needed when conduit pumping is enabled
//        let base = 0
//
//        state1.value++
//        XCTAssertEqual(state1.value, base + 1)
//        XCTAssertEqual(state2.value, base + 5)
//        XCTAssertEqual(state3.value, base + 1)
//
//        state2.value++
//        XCTAssertEqual(state1.value, base + 9)
//        XCTAssertEqual(state2.value, base + 6)
//        XCTAssertEqual(state3.value, base + 6)
//
//        state3.value++
//        XCTAssertEqual(state1.value, base + 10)
//        XCTAssertEqual(state2.value, base + 11)
//        XCTAssertEqual(state3.value, base + 7)
//
////        ChannelZReentrancyLimit = 1
//    }
//
//    public func testRequiredToOptional() {
//        let state1 = ∞Int(0)∞
//        let state2 = ∞Optional<Int>()∞
//
//        state1 ∞=> state2
//
//        XCTAssertEqual(0, state1.value)
//        XCTAssertEqual(999, state2.value ?? 999)
//
//        state1.value++
//
//        XCTAssertEqual(1, state1.value)
//        XCTAssertEqual(1, state2.value ?? 999)
//
//    }
//
//    public func testMemory() {
//        autoreleasepool {
//            let md1 = MemoryDemo()
//            let md2 = MemoryDemo()
//            md1∞md1.stringField <=∞=> md2∞md2.stringField
//            md1.stringField += "Hello "
//            md2.stringField += "World"
//            XCTAssertEqual(md1.stringField, "Hello World")
//            XCTAssertEqual(md2.stringField, "Hello World")
//            XCTAssertEqual(2, MemoryDemoCount)
//        }
//        
//        // subscriptions are retained by the channel sources
//        XCTAssertEqual(0, MemoryDemoCount)
//    }
//
//
//    public func testAutoKVOIdentification() {
//        let state = StatefulObjectSubSubclass()
//        var count = 0
//
//        let subscription : Receptor = state.channelz(state.optionalStringField) ∞> { _ in count += 1 }
//        state∞state.requiredStringField ∞> { _ in count += 1 }
//        state∞state.optionalNSStringField ∞> { _ in count += 1 }
//        state∞state.requiredNSStringField ∞> { _ in count += 1 }
//        state∞state.intField ∞> { _ in count += 1 }
//        state∞state.doubleField ∞> { _ in count += 1 }
//        state∞state.numberField1 ∞> { _ in count += 1 }
//        state∞state.numberField2 ∞> { _ in count += 1 }
//        state∞state.numberField3 ∞> { _ in count += 1 }
//        state∞state.numberField3 ∞> { _ in count += 1 }
//        state∞state.requiredObjectField ∞> { _ in count += 1 }
//        state∞state.optionaldObjectField ∞> { _ in count += 1 }
//    }
//
//
//    public func testDeepKeyPath() {
//        let state = StatefulObjectSubSubclass()
//        var count = 0
//
//        state∞(state.state.intField, "state.intField") ∞> { _ in count += 1 }
//
//        XCTAssertEqual(0, count)
//
//        state.state.intField++
//        XCTAssertEqual(0, --count)
//
//        let oldstate = state.state
//
//        state.state = StatefulObject()
//        XCTAssertEqual(0, --count)
//
//        oldstate.intField++
//        XCTAssertEqual(0, count, "should not be watching stale state")
//
//        state.state.intField++
//        XCTAssertEqual(0, --count)
//
//        state.state.intField--
//        XCTAssertEqual(0, --count)
//
//        state.state = StatefulObject()
//        XCTAssertEqual(0, count, "new intermediate with same terminal value should not pass sieve") // or should it?
//    }
//
//    public func testDeepOptionalKeyPath() {
//        let state = StatefulObjectSubSubclass()
//        var count = 0
//
//        state∞(state.optionaldObjectField?.optionaldObjectField?.intField, "optionaldObjectField.optionaldObjectField.intField") ∞> { _ in count += 1 }
//
//        XCTAssertEqual(0, count)
//
//        state.optionaldObjectField = StatefulObjectSubSubclass()
//
//        //        XCTAssertEqual(0, --count)
//
//        state.optionaldObjectField!.optionaldObjectField = StatefulObjectSubSubclass()
//        XCTAssertEqual(0, --count)
//
//        state.optionaldObjectField!.optionaldObjectField!.intField++
//        XCTAssertEqual(0, --count)
//        
//    }
//
//    #if os(OSX)
//    func testButtonCommand() {
//        let button = NSButton()
//
//        /// seems to be needed or else the button won't get clicked
//        (NSWindow().contentView as NSView).addSubview(button)
//
//        var stateChanges = 0
//
//        button∞button.state ∞> { x in
//            stateChanges += 1
////            println("state change: \(x)")
//        }
//
//        button.state = NSOnState
//        button.state = NSOffState
//        button.state = NSOnState
//        button.state = NSOffState
//        XCTAssertEqual(stateChanges, 4)
//
//        var clicks = 0 // track the number of clicks on the button
//
//        XCTAssertEqual(clicks, 0)
//
//        let cmd = button.controlz()
//        var subscription = cmd.receive({ _ in clicks += 1 })
//
//        button.performClick(self); XCTAssertEqual(--clicks, 0)
//        button.performClick(self); XCTAssertEqual(--clicks, 0)
//
//        subscription.cancel()
//
//        button.performClick(self); XCTAssertEqual(clicks, 0)
//        button.performClick(self); XCTAssertEqual(clicks, 0)
//
//
//    }
//
//    func testTextFieldProperties() {
//        let textField = NSTextField()
//
//        /// seems to be needed or else the button won't get clicked
//        (NSWindow().contentView as NSView).addSubview(textField)
//
//        var text = ""
//
//        let textChannel = textField∞(textField.stringValue)
//        var textReceptor = textChannel.receive({ text = $0 })
//
//        var enabled = true
//        let enabledChannel = textField∞(textField.enabled)
//        var enabledReceptor = enabledChannel.receive({ enabled = $0 })
//
//        textField.stringValue = "ABC"
//        XCTAssertEqual("ABC", textField.stringValue)
//        XCTAssertEqual("ABC", text)
//
//        textChannel.value = "XYZ"
//        XCTAssertEqual("XYZ", textField.stringValue)
//        XCTAssertEqual("XYZ", text)
//
//        textField.enabled = false
//        XCTAssertEqual(false, textField.enabled)
//        XCTAssertEqual(false, enabled)
//
//        textField.enabled = true
//        XCTAssertEqual(true, enabled)
//
//        textReceptor.cancel()
//
//        textField.stringValue = "QRS"
//        XCTAssertEqual("XYZ", text)
//
//        enabledReceptor.cancel()
//
//        textField.enabled = false
//        XCTAssertEqual(true, enabled)
//
//    }
//
//    func testControls() {
//        struct ViewModel {
//            let amount = ∞(Double(0))∞
//            let amountMax = Double(100.0)
//        }
//
//        let vm = ViewModel()
//
//        let stepper = NSStepper()
//        stepper.maxValue = vm.amountMax
//        stepper∞stepper.doubleValue <=∞=> vm.amount
//
//        let slider = NSSlider()
//        slider.maxValue = vm.amountMax
//        slider∞slider.doubleValue <=∞=> vm.amount
//
//        stepper.doubleValue += 25.0
//        XCTAssertEqual(slider.doubleValue, Double(25.0))
//        XCTAssertEqual(vm.amount.value, Double(25.0))
//
//        slider.doubleValue += 30.0
//        XCTAssertEqual(stepper.doubleValue, Double(55.0))
//        XCTAssertEqual(vm.amount.value, Double(55.0))
//
//
//        let progbar = NSProgressIndicator()
//        progbar.maxValue = 1.0
//
//        // NSProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value
//        vm.amount.map({ Double($0 / vm.amountMax) }) ∞=> progbar∞progbar.doubleValue
//
//        vm.amount.value += 20
//
//        XCTAssertEqual(slider.doubleValue, Double(75.0))
//        XCTAssertEqual(stepper.doubleValue, Double(75.0))
//        XCTAssertEqual(progbar.doubleValue, Double(0.75))
//
//        let progress = NSProgress(totalUnitCount: Int64(vm.amountMax))
//        vm.amount.map({ Int64($0) }) ∞=> progress∞progress.completedUnitCount
//
//        // FIXME: memory leak
//        // progress∞progress.completedUnitCount ∞> { _ in println("progress: \(progress.localizedDescription)") }
//
//        let textField = NSTextField()
//
//        // FIXME: crash
//        // progress∞progress.localizedDescription ∞=> textField∞textField.stringValue
//
//        vm.amount.value += 15.0
//    }
//
//    #endif
//
//    #if os(iOS)
//    func testButtonCommand() {
//        let button = UIButton()
//
////        var stateChanges = 0
////
//        // TODO: implement proper enum tracking
////        button∞button.state ∞> { x in
////            stateChanges += 1
////        }
////
////        XCTAssertEqual(stateChanges, 1)
////        button.highlighted = true
////        button.selected = true
////        button.enabled = false
////        XCTAssertEqual(stateChanges, 3)
//
//        var selectedChanges = 0
//        button∞button.selected ∞> { x in
//            selectedChanges += 1
//        }
//
//        XCTAssertEqual(selectedChanges, 0)
//        button.selected = true
//        XCTAssertEqual(selectedChanges, 1)
//        button.selected = false
//        XCTAssertEqual(selectedChanges, 2)
//
//        var taps = 0 // track the number of taps on the button
//
//        XCTAssertEqual(taps, 0)
//
//        let eventType: UIControlEvents = .TouchUpInside
//        let cmd = button.controlz(eventType)
//        XCTAssertEqual(0, button.allTargets().count)
//
//        // sadly, this only seems to work when the button is in a running UIApplication
//        // let tap: ()->() = { button.sendActionsForControlEvents(.TouchUpInside) }
//
//        // so we need to fake it by directly invoking the target's action
//        let tap: ()->() = {
//            let event = UIEvent()
//
//            for target in button.allTargets().allObjects as [UIEventReceptor] {
//                // button.sendAction also doesn't work from a test case
//                for action in button.actionsForTarget(target, forControlEvent: eventType) as [String] {
////                    button.sendAction(Selector(action), to: target, forEvent: event)
//                    XCTAssertEqual("handleControlEvent:", action)
//                    target.handleControlEvent(event)
//                }
//            }
//        }
//
//        let buttonTapsHappen = true // false && false // or else compiler warning about blocks never executing
//
//        var subscription1 = cmd.receive({ _ in taps += 1 })
//        XCTAssertEqual(1, button.allTargets().count)
//
//        if buttonTapsHappen {
//            tap(); taps -= 1; XCTAssertEqual(taps, 0)
//            tap(); taps -= 1; XCTAssertEqual(taps, 0)
//        }
//
//        var subscription2 = cmd.receive({ _ in taps += 1 })
//        XCTAssertEqual(2, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 2; XCTAssertEqual(taps, 0)
//            tap(); taps -= 2; XCTAssertEqual(taps, 0)
//        }
//
//        subscription1.cancel()
//        XCTAssertEqual(1, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 1; XCTAssertEqual(taps, 0)
//            tap(); taps -= 1; XCTAssertEqual(taps, 0)
//        }
//
//        subscription2.cancel()
//        XCTAssertEqual(0, button.allTargets().count)
//        if buttonTapsHappen {
//            tap(); taps -= 0; XCTAssertEqual(taps, 0)
//            tap(); taps -= 0; XCTAssertEqual(taps, 0)
//        }
//    }
//
//    func testTextFieldProperties() {
//        let textField = UITextField()
//
//
//        var text = ""
//        let textReceptor = (textField∞textField.text).map( { $0 } ).receive({ text = $0 })
//
//        var enabled = true
//        let enabledReceptor = textField.channelz(textField.enabled).receive({ enabled = $0 })
//
//
//        textField.text = "ABC"
//        XCTAssertEqual("ABC", textField.text)
//        XCTAssertEqual("ABC", text)
//
//        textField.enabled = false
//        XCTAssertEqual(false, textField.enabled)
//        XCTAssertEqual(false, enabled)
//
//        textField.enabled = true
//        XCTAssertEqual(true, enabled)
//
//        textReceptor.cancel()
//
//        textField.text = "XYZ"
//        XCTAssertEqual("ABC", text)
//        
//        enabledReceptor.cancel()
//        
//        textField.enabled = false
//        XCTAssertEqual(true, enabled)
//        
//    }
//
//    func testControls() {
//        struct ViewModel {
//            let amount = ∞(Double(0))∞
//            let amountMax = Double(100.0)
//        }
//
//        let vm = ViewModel()
//
//        let stepper = UIStepper()
//        stepper.maximumValue = vm.amountMax
//        stepper∞stepper.value <=∞=> vm.amount
//
//        let slider = UISlider()
//        slider.maximumValue = Float(vm.amountMax)
//        let subscription = slider∞slider.value <~∞~> vm.amount // FIXME: memory leak
//
//        stepper.value += 25.0
//        XCTAssertEqual(slider.value, Float(25.0))
//        XCTAssertEqual(vm.amount.value, Double(25.0))
//
//        slider.value += 30.0
//        XCTAssertEqual(stepper.value, Double(55.0))
//        XCTAssertEqual(vm.amount.value, Double(55.0))
//
//
//        let progbar = UIProgressView()
//
//        // UIProgressView goes from 0.0-1.0, so map the slider's percentage complete to the progress value
//        vm.amount.map({ Float($0 / vm.amountMax) }) ∞=> progbar∞progbar.progress
//
//        vm.amount.value += 20
//
//        XCTAssertEqual(slider.value, Float(75.0))
//        XCTAssertEqual(stepper.value, Double(75.0))
//        XCTAssertEqual(progbar.progress, Float(0.75))
//
//        let progress = NSProgress(totalUnitCount: Int64(vm.amountMax))
//        let pout = vm.amount.map({ Int64($0) }) ∞=> progress∞progress.completedUnitCount
//
////        progress∞progress.localizedDescription ∞> { println("progress: \($0)") }
//
////        let textField = UITextField()
////        progress∞progress.localizedDescription ∞=> textField∞textField.text
//
////        vm.amount.value += 15.0
////
////        //progress.completedUnitCount = 15
////        
////        println("progress: \(textField.text)") // “progress: 15% completed”
//
//        subscription.cancel() // FIXME: memory leak
//        pout.cancel() // FIXME: crash
//    }
//    #endif
//
//
//    override public func tearDown() {
//        super.tearDown()
//
//        // ensure that all the bindings and observers are properly cleaned up
//        #if DEBUG_CHANNELZ
//            XCTAssertEqual(0, StatefulObjectCount, "all StatefulObject instances should have been deallocated")
//            StatefulObjectCount = 0
//            XCTAssertEqual(0, ChannelZKeyValueObserverCount, "KV observers were not cleaned up")
//            ChannelZKeyValueObserverCount = 0
//            XCTAssertEqual(0, ChannelZNotificationObserverCount, "Notification observers were not cleaned up")
//            ChannelZNotificationObserverCount = 0
//            #else
//            XCTFail("Why are you running tests with debugging off?")
//        #endif
//    }

}

//
//public struct StatefulObjectHolder {
//    let ob: StatefulObject
//}
//
//public enum SomeEnum { case Yes, No, MaybeSo }
//
//public struct SwiftStruct {
//    public var intField: Int
//    public var stringField: String?
//    public var enumField: SomeEnum = .No
//}
//
//public struct SwiftEquatableStruct : Equatable {
//    public var intField: Int
//    public var stringField: String?
//    public var enumField: SomeEnum = .No
//}
//
//public func == (lhs: SwiftEquatableStruct, rhs: SwiftEquatableStruct) -> Bool {
//    return lhs.intField == rhs.intField && lhs.stringField == rhs.stringField && lhs.enumField == rhs.enumField
//}
//
//public struct SwiftObservables {
//    public let stringField: ChannelZ<String> = ∞("")∞
//    public let enumField = ∞(SomeEnum.No)∞
//    public let swiftStruct = ∞(SwiftStruct(intField: 1, stringField: "", enumField: .Yes))∞
//}
//
//
//var StatefulObjectCount = 0
//
//public class StatefulObject : NSObject {
//    dynamic var optionalStringField: String?
//    dynamic var requiredStringField: String = ""
//
//    dynamic var optionalNSStringField: NSString?
//    dynamic var requiredNSStringField: NSString = ""
//
//    // “property cannot be marked as dynamic because its type cannot be represented in Objective-C”
//    // dynamic var optionalIntField: Int?
//
//    dynamic var intField: Int = 0
//    dynamic var doubleField: Double = 0
//    dynamic var numberField1: NSNumber?
//    dynamic var numberField2: NSNumber?
//    dynamic var numberField3: NSNumber = 9
//
//    dynamic var requiredObjectField: NSObject = NSObject()
//    dynamic var optionaldObjectField: StatefulObject? = nil
//
//    public override init() {
//        super.init()
//        StatefulObjectCount++
//    }
//
//    deinit {
//        StatefulObjectCount--
//    }
//}
//
//public class StatefulObjectSubclass : StatefulObject {
//    dynamic var state = StatefulObject()
//}
//
//public final class StatefulObjectSubSubclass : StatefulObjectSubclass { }
//
//var InstanceTrackingUndoManagerInstanceCount = 0
//class InstanceTrackingUndoManager : NSUndoManager {
//    override init() {
//        super.init()
//        InstanceTrackingUndoManagerInstanceCount++
//    }
//
//    deinit {
//        InstanceTrackingUndoManagerInstanceCount--
//    }
//}
//
//public class CoreDataPerson : NSManagedObject {
//    dynamic var fullName: String?
//    @NSManaged var age: Int16
//}
//
//var MemoryDemoCount = 0
//class MemoryDemo : NSObject {
//    dynamic var stringField : String = ""
//
//    // track creates and releases
//    override init() { MemoryDemoCount++ }
//    deinit { MemoryDemoCount-- }
//}
//
//class NumericHolderClass : NSObject {
//    dynamic var numberField: NSNumber = 0
//    dynamic var decimalNumberField: NSDecimalNumber = 0
//    dynamic var doubleField: Double = 0
//    dynamic var floatField: Float = 0
//    dynamic var intField: Int = 0
//    dynamic var uInt64Field: UInt64 = 0
//    dynamic var int64Field: Int64 = 0
//    dynamic var uInt32Field: UInt32 = 0
//    dynamic var int32Field: Int32 = 0
//    dynamic var uInt16Field: UInt16 = 0
//    dynamic var int16Field: Int16 = 0
//    dynamic var uInt8Field: UInt8 = 0
//    dynamic var int8Field: Int8 = 0
//    dynamic var boolField: Bool = false
//}
//
//struct NumericHolderStruct {
//    let numberField = ∞(NSNumber(floatLiteral: 0.0))∞
//    let decimalNumberField = ∞(NSDecimalNumber(floatLiteral: 0.0))∞
//    let doubleField = ∞(Double(0))∞
//    let floatField = ∞(Float(0))∞
//    let intField = ∞(Int(0))∞
//    let uInt64Field = ∞(UInt64(0))∞
//    let int64Field = ∞(Int64(0))∞
//    let uInt32Field = ∞(UInt32(0))∞
//    let int32Field = ∞(Int32(0))∞
//    let uInt16Field = ∞(UInt16(0))∞
//    let int16Field = ∞(Int16(0))∞
//    let uInt8Field = ∞(UInt8(0))∞
//    let int8Field = ∞(Int8(0))∞
//    let boolField = ∞(Bool(false))∞
//}
//
//struct NumericHolderOptionalStruct {
//    let numberField = ∞(nil as NSNumber?)∞
//    let decimalNumberField = ∞(nil as NSDecimalNumber?)∞
//    let doubleField = ∞(nil as Double?)∞
//    let floatField = ∞(nil as Float?)∞
//    let intField = ∞(nil as Int?)∞
//    let uInt64Field = ∞(nil as UInt64?)∞
//    let int64Field = ∞(nil as Int64?)∞
//    let uInt32Field = ∞(nil as UInt32?)∞
//    let int32Field = ∞(nil as Int32?)∞
//    let uInt16Field = ∞(nil as UInt16?)∞
//    let int16Field = ∞(nil as Int16?)∞
//    let uInt8Field = ∞(nil as UInt8?)∞
//    let int8Field = ∞(nil as Int8?)∞
//    let boolField = ∞(nil as Bool?)∞
//}


var ChannelThingsInstances = 0
class ChannelThing: NSObject {
    let int = PropertyChannel(0)
    let double = PropertyChannel(0.0)
    let string = PropertyChannel("")
    let stringish = PropertyChannel(nil as String?)

    override init() { ChannelThingsInstances++ }
    deinit { ChannelThingsInstances-- }
}

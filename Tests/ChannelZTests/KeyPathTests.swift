////
//  FoundationTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/5/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

#if !os(Linux)

import XCTest
import ChannelZ
import CoreData

class KeyPathTests : ChannelTestCase {

    func assertMemoryBlock<T>(_ file: StaticString = #file, line: UInt = #line, check:  @autoclosure ()->T, code: ()->()) where T: Equatable {
        let start = check()
        autoreleasepool(invoking: code)
        let end = check()
        XCTAssertEqual(start, end, "assertMemoryBlock failure", file: file, line: line)
    }

//    func testMemory() {
//        var strs: [String] = []
//        var receipt: Receipt!
//        assertMemoryBlock(check: ChannelThingsInstances) {
//            let thing = ChannelThing()
//            receipt = thing.stringish.sieve(!=).some().receive({ strs += [$0] })
//            let strings: [String?] = ["a", "b", nil, "b", "b", "c"]
//            for x in strings { thing.stringish ∞= x }
//            XCTAssertFalse(receipt.cancelled)
//        }
//
////        XCTAssertTrue(receipt.cancelled) // TODO: should receipts clear when sources are cancelled?
//        XCTAssertEqual(["a", "b", "b", "c"], strs, "early sieve misses filter")
//        receipt.cancel()
//
//    }

    /// Ensure that objects are cleaned up when receipts are explicitly canceled
    func testKVOMemoryCleanupCanceled() {
        assertMemoryBlock(check: StatefulObjectCount) {
            let nsob = StatefulObject()
            let intz = nsob.channelZKeyValue(\.int)
            let rcpt = intz.receive({ _ in })
            rcpt.cancel()
        }
    }

    /// Ensure that objects are cleaned up even when receipts are not explicitly canceled
    func testKVOMemoryCleanupUncanceled() {
        assertMemoryBlock(check: StatefulObjectCount) {
            let nsob = StatefulObject()
            let intz = nsob.channelZKeyValue(\.int)
            var count = 0
            let rcpt = intz.receive({ _ in count += 1 })
            XCTAssertEqual(1, count, "should have received an initial element")
            withExtendedLifetime(rcpt) { }
        }
    }

    func testSimpleFoundation() {
        assertMemoryBlock(check: StatefulObjectCount) {
            let nsob = StatefulObject()
            let stringz = nsob[channel: \.reqnsstr].changes().subsequent() // also works
            // FIXME
//            let stringz = nsob.channelZKey(nsob.reqnsstr).sieve(!=).subsequent()
            var strs: [NSString] = []

            stringz.receive({ strs += [$0] })

//            nsob.reqnsstr = "a"
//            nsob.reqnsstr = "c"
            stringz.value = "a"
            stringz.value = "c"
            XCTAssertEqual(2, strs.count)

            stringz.value = "d"
            XCTAssertEqual(3, strs.count)

            stringz.value = "d"
            XCTAssertEqual(3, strs.count) // change to self shouldn't up the count

            withExtendedLifetime(nsob) { }
        }
    }

    func testMultipleReceiversOnKeyValue() {
        let holder = NumericHolderClass()
//        let prop = holder.channelZKeyState(holder.intField)
        let prop = holder[channel: \.intField]
        
        var counts = (0, 0, 0)

        prop.receive { _ in counts.0 += 1 }
        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(0, counts.1)
        XCTAssertEqual(0, counts.2)

        prop.receive { _ in counts.1 += 1 }
        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(0, counts.2)

        prop.receive { _ in counts.2 += 1 }
        XCTAssertEqual(1, counts.0)
        XCTAssertEqual(1, counts.1)
        XCTAssertEqual(1, counts.2)

        holder.setValue(123, forKey: "intField")
        XCTAssertEqual(2, counts.0)
        XCTAssertEqual(2, counts.1)
        XCTAssertEqual(2, counts.2)

        prop.value = 456
        XCTAssertEqual(3, counts.0)
        XCTAssertEqual(3, counts.1)
        XCTAssertEqual(3, counts.2)
    }

    func testChannels() {
        let observedBool = ∞=false=∞

        var changeCount: Int = 0

        let ob1 = observedBool.subsequent().receive { v in
            changeCount = changeCount + 1
        }
        withExtendedLifetime(ob1) { }

        XCTAssertEqual(0, changeCount)

        observedBool ∞= true
        XCTAssertEqual(1, changeCount)

        observedBool ∞= true
        XCTAssertEqual(1, changeCount)

        observedBool ∞= false
        observedBool ∞= false


        XCTAssertEqual(2, changeCount)

        // XCTAssertEqual(test, false)



        #if DEBUG_CHANNELZ
        let startObserverCount = ChannelZKeyValueObserverCount.get()
        #endif

//        autoreleasepool {
//            // FIXME: crazy; if these are outsize the autoreleasepool, the increments fail
//            var sz: Int = 0
//            var iz: Int = 0
//            var dz: Int = 0
//
//            let state = StatefulObject()
//
//            state.channelZKey(state.int).sieve(!=).receive { _ in iz += 1 }
//
//            #if DEBUG_CHANNELZ
//            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1)
//            #endif
//
//            let sfo = state.channelZKey(state.optstr).sieve(!=)
//            let strpath = "optstr"
//            XCTAssertEqual(strpath, sfo.source.keyPath)
//
//            state.channelZKey(state.dbl).sieve(!=).receive { _ in dz += 1 }
//
//
//            assertChanges(iz, state.int += 1)
//            assertRemains(iz, state.int = state.int + 0)
//            assertChanges(iz, state.int = state.int + 1)
//            assertRemains(iz, state.int = state.int + 1 - 1)
//
//            sfo.receive { (value: String?) in sz += 1 }
//
//            assertChanges(sz, state.optstr = "x")
//            assertChanges(sz, state.optstr! += "yz")
//
//            assertChanges(sz, state.setValue("", forKeyPath: strpath))
//            assertRemains(sz, state.setValue("", forKeyPath: strpath))
//            XCTAssertEqual("", state.optstr!)
//            assertChanges(sz, state.setValue(nil, forKeyPath: strpath))
//            assertRemains(sz, state.setValue(nil, forKeyPath: strpath))
//            XCTAssertNil(state.optstr)
//            assertChanges(sz, state.setValue("abc", forKeyPath: strpath))
//            assertRemains(sz, state.setValue("abc", forKeyPath: strpath))
//            XCTAssertEqual("abc", state.optstr!)
//
//            assertChanges(sz, sfo ∞= "")
//            assertRemains(sz, sfo ∞= "")
//            XCTAssertEqual("", state.optstr!)
//
//            assertChanges(sz, sfo ∞= nil)
//            XCTAssertNil(state.optnsstr)
//            assertRemains(sz, sfo ∞= nil)
//            XCTAssertNil(state.optnsstr)
//
//            assertChanges(sz, sfo ∞= "abc")
//            assertRemains(sz, sfo ∞= "abc")
//
//            assertChanges(sz, sfo ∞= "y")
//            assertChanges(sz, state.setValue(nil, forKeyPath: strpath))
//            assertRemains(sz, state.setValue(nil, forKeyPath: strpath))
//
//            assertChanges(sz, sfo ∞= "y")
//
//            assertChanges(sz, sfo ∞= nil)
//            assertRemains(sz, sfo ∞= nil)
//
//            assertRemains(sz, state.optstr = nil)
//
//            assertChanges(sz, state.optstr = "")
//            assertRemains(sz, state.optstr = "")
//
//            assertChanges(sz, state.optstr = "foo")
//
//            withExtendedLifetime(state) { } // need to hold on
//
//            #if DEBUG_CHANNELZ
//            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1, "observers should still be around before cleanup")
//            #endif
//        }

        #if DEBUG_CHANNELZ
        XCTAssertEqual(ChannelZKeyValueObserverCount.get(), startObserverCount, "observers should have been cleared after cleanup")
        #endif
    }

    func testMultipleSimpleChannels() {
//        let intChannel = channelZPropertyValue(0).sieve(!=)
        let intChannel = ∞=0=∞

        var changeCount: Int = 0

        let r1 = intChannel.receive { v in
            changeCount = changeCount + 1
        }
        let r2 = intChannel.receive { v in
            changeCount = changeCount + 1
        }

        changeCount = 0 // clear any initial assignations
        XCTAssertEqual(0, changeCount)

        intChannel.value += 1
        XCTAssertEqual(2, changeCount)

        intChannel.value = 1 // no change
        XCTAssertEqual(2, changeCount)

        intChannel.value += 1
        XCTAssertEqual(4, changeCount)

        r1.cancel()
        intChannel.value += 1
        XCTAssertEqual(5, changeCount)

        r2.cancel()
        intChannel.value += 1
        XCTAssertEqual(5, changeCount)
    }

//    func testMultipleKVOChannels() {
//        let ob = NumericHolderClass()
////        let intChannel = ob.channelZKeyState(ob.intField).changes() // also works
//        let intChannel = ob.channelZKey(ob.intField).sieve(!=)
//
//        var changeCount: Int = 0
//
//        let receiverCount = 10
//        var receivers: [Receipt] = []
//        for _ in 1...receiverCount {
//            receivers.append(intChannel.receive { _ in
//                changeCount += 1
//            })
//        }
//
//        changeCount = 0 // clear any initial assignations
//        XCTAssertEqual(0, changeCount)
//
//        ob.intField += 1
//        XCTAssertEqual(receiverCount, changeCount)
//
//        let currentValue = ob.intField
//        ob.intField = currentValue // no change
//        XCTAssertEqual(receiverCount, changeCount)
//
//        ob.intField += 1
//        XCTAssertEqual(receiverCount * 2, changeCount)
//
////        receivers.first.cancel()
////        ob.intField += 1
////        XCTAssertEqual(5, changeCount)
////
////        receivers.last.cancel()
////        ob.intField += 1
////        XCTAssertEqual(5, changeCount)
//
//
//    }

    func testFilteredChannels() {

        var strlen = 0

        let sv = channelZPropertyValue("X")

        let _ = sv.filter({ _ in true }).map({ $0.utf8.count })
        let _ = sv.filter({ _ in true }).map({ $0.utf8.count })
        let _ = sv.map({ $0.utf8.count })

        _ = ∞=false=∞

        let a = sv.filter({ _ in true }).map({ $0.utf8.count }).filter({ $0 % 2 == 1 })
        _ = a.receive { strlen = $0 }

        a ∞= "AAA"

        XCTAssertEqual(3, strlen)

        // TODO: need to re-implement .value for FieldChannels, etc.
//        a ∞= (a.value + "ZZ")
//        XCTAssertEqual(5, strlen)
//        XCTAssertEqual("AAAZZ", a.value)
//
//        a ∞= (a.value + "A")
//        XCTAssertEqual("AAAZZA", a.value)
//        XCTAssertEqual(5, strlen, "even-numbered increment should have been filtered")
//
//        a ∞= (a.value + "A")
//        XCTAssertEqual("AAAZZAA", a.value)
//        XCTAssertEqual(7, strlen)


        let x = channelZPropertyValue(1).subsequent().filter { $0 <= 10 }

        var changeCount: Double = 0
        var changeLog: String = ""

        // track the number of changes using two separate subscriptions
        x.receive { _ in changeCount += 0.5 }
        x.receive { _ in changeCount += 0.5 }

        let xfm = x.map( { String($0) })
        _ = xfm.receive { s in changeLog += (changeLog.isEmpty ? "" : ", ") + s } // create a string log of all the changes


        XCTAssertEqual(0, changeCount)
        XCTAssertNotEqual(5, x.source.value)

        x ∞= 5
        XCTAssertEqual(5, x.source.value)
        XCTAssertEqual(1, changeCount)


        x ∞= 5
        XCTAssertEqual(5, x.source.value)
        XCTAssertEqual(1, changeCount)

        x ∞= 6
        XCTAssertEqual(2, changeCount)

        // now test the filter: only changes to numbers less than or equal to 10 should flow to the receivers
        x ∞= 20
        XCTAssertEqual(2, changeCount, "out of bounds change should not have fired listener")

        x ∞= 6
        XCTAssertEqual(3, changeCount, "in-bounds change should have fired listener")

        for i in 1...100 {
            x ∞= i
        }
        XCTAssertEqual(13, changeCount, "in-bounds change should have fired listener")

        XCTAssertEqual("5, 6, 6, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10", changeLog)


        var tc = 0.0
        let t = ∞(1.0)∞

        t.filter({ $0.truncatingRemainder(dividingBy: 2.0) == 0.0 }).filter({ $0.truncatingRemainder(dividingBy: 9.0) == 0.0 }).receive({ n in tc += n })
//        t.receive({ n in tc += n })

        for i in 1...100 { t ∞= Double(i) }
        // FIXME: seems to be getting released somehow
//        XCTAssertEqual(270.0, tc, "sum of all numbers between 1 and 100 divisible by 2 and 9")

        var lastt = ""

        let tv = t.map({ v in v }).filter({ $0.truncatingRemainder(dividingBy: 2.0) == 0.0 }).map(-).map({ "Even: \($0)" })
        tv.receive({ lastt = $0 })


        for i in 1...99 { tv ∞= Double(i) }
        XCTAssertEqual("Even: -98.0", lastt)
    }

    func testStructChannel() {
        let ob = ∞(SwiftStruct(intField: 1, stringField: "x", enumField: .yes))∞

        var changes = 0

        // receive is the equivalent of ReactiveX's Subscribe
        ob.subsequent().receive({ _ in changes += 1 })

        XCTAssertEqual(changes, 0)
        ob ∞= SwiftStruct(intField: 2, stringField: nil, enumField: .yes)
        XCTAssertEqual(changes, 1)

        ob ∞= SwiftStruct(intField: 2, stringField: nil, enumField: .yes)
        XCTAssertEqual(changes, 2)
    }

    func testEquatableStructChannel() {
        let ob = ∞=(SwiftEquatableStruct(intField: 1, stringField: "x", enumField: .yes))=∞

        var changes = 0
        ob.subsequent().receive({ _ in changes += 1 })

        XCTAssertEqual(changes, 0)
        ob ∞= SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .yes)
        XCTAssertEqual(changes, 1)

        ob ∞= SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .yes)
        XCTAssertEqual(changes, 1)

        ob ∞= SwiftEquatableStruct(intField: 2, stringField: nil, enumField: .no)
        XCTAssertEqual(changes, 2)

        ob ∞= SwiftEquatableStruct(intField: 3, stringField: "str", enumField: .yes)
        XCTAssertEqual(changes, 3)
    }

    func testStuctChannels() {
        let ob = SwiftObservables()

        var stringChanges = 0
        ob.stringField.subsequent().receive { _ in stringChanges += 1 }
        XCTAssertEqual(0, stringChanges)
        assertChanges(stringChanges, ob.stringField ∞= "x")

        var enumChanges = 0
        ob.enumField.subsequent().receive { _ in enumChanges += 1 }
        XCTAssertEqual(0, enumChanges)
        assertChanges(enumChanges, ob.enumField ∞= .maybeSo)
        assertRemains(enumChanges, ob.enumField ∞= .maybeSo)
    }

    func testFieldChannel() {
        let xs: Int = 1

        // operator examples
        let csource: ValueTransceiver<Int> = xs∞
        let _: Channel<ValueTransceiver<Int>, Int> = ∞csource

        let c = ∞xs∞

        var changes = 0
        c.receive { _ in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, c ∞= c.source.value + 1)
        assertChanges(changes, c ∞= 2)
        assertChanges(changes, c ∞= 2)
        assertChanges(changes, c ∞= 9)
    }

    func testFieldSieve() {
        let xs: Int = 1

        // operator examples
        let csource: ValueTransceiver<Int> = xs=∞
        let _: Channel<ValueTransceiver<Int>, Int> = ∞=csource

        let c = ∞=xs=∞

        var changes = 0
        c.receive { _ in changes += 1 }

        XCTAssertEqual(1, changes)
        assertChanges(changes, c ∞= c.source.value + 1)
        assertRemains(changes, c ∞= 2)
        assertRemains(changes, c ∞= 2)
        assertChanges(changes, c ∞= 9)
    }

    func testOptionalFieldSieve() {
        let xs: Int? = nil

        // operator examples
        let csource: ValueTransceiver<Optional<Int>> = xs=∞
        let _: Channel<ValueTransceiver<Optional<Int>>, Optional<Int>> = ∞=csource

        let c = ∞=xs=∞

        var changes = 0
        c ∞> { _ in changes += 1 }

        assertChanges(changes, c ∞= (2))
        assertRemains(changes, c ∞= (2))
        assertChanges(changes, c ∞= (nil))
//        assertChanges(changes, c ∞= (nil)) // FIXME: nil to nil is a change?
        assertChanges(changes, c ∞= (1))
        assertRemains(changes, c ∞= (1))
        assertChanges(changes, c ∞= (2))
    }

    func testKeyValueSieve() {
        let state = StatefulObject()
        let ckey = state§\.reqstr
        let csource: KeyValueTransceiver<StatefulObject, String> = ckey=∞
        let channel: KeyValueChannel<StatefulObject, String> = ∞=csource
        
        let _: KeyValueChannel<StatefulObject, String> = ∞(state§\.reqstr)∞
        let c2: KeyValueChannel<StatefulObject, String> = ∞=(state§\.reqstr)=∞
        
        
        let c = c2
        
        var changes = 0
        channel ∞> { _ in changes += 1 }
        
        XCTAssertEqual(1, changes)
        
        assertRemains(changes, c ∞= ("")) // default to default should not change
        assertChanges(changes, c ∞= ("A"))
        assertRemains(changes, c ∞= ("A"))
        assertChanges(changes, c ∞= ("B"))
    }

    func testKeyValueSieveUnretainedReceiver() {
        let state = StatefulObject()
        let c = state∞(\.reqstr)

        var changes = 0
        autoreleasepool {
            let _ = c ∞> { _ in changes += 1 } // note we do not assign it locally, so it should immediately get cleaned up
            XCTAssertEqual(1, changes)
        }

        // FIXME: not working in Swift 1.2; receiver block is called, but changes outside of autorelease block isn't updated
//        assertChanges(changes, c ∞= ("A")) // unretained subscription should still listen
//        assertChanges(changes, c ∞= ("")) // unretained subscription should still listen
        
        return withExtendedLifetime(state) { } // need to retain so it doesn't get cleaned up
    }

    func testOptionalNSKeyValueSieve() {
        let state = StatefulObject()
//        var c: Channel<KeyValueOptionalTransceiver<NSString>, NSString?> = ∞=(state§\.optnsstr)=∞
//        var c: Channel<KeyValueOptionalTransceiver<NSString>, NSString?> = state∞\.optnsstr
        let c: KeyValueChannel<StatefulObject, NSString?> = (state∞\.optnsstr).changes(!=)
        
        var seq: [NSString?] = []
        var changes = 0
        c ∞> { seq.append($0); changes += 1 }

        changes = 0
        seq = [] // clear initial values if any
        for _ in 0...0 {
            assertChanges(changes, c ∞= ("A"))
            assertRemains(changes, c ∞= ("A"))
            assertChanges(changes, c ∞= (nil))
            assertChanges(changes, c ∞= ("B"))
            assertChanges(changes, c ∞= (nil))

            // this one is tricky, since with KVC, previous values are represented as NSNull(), which != nil
            assertRemains(changes, c ∞= (nil))

            assertChanges(changes, c ∞= ("C"))

            XCTAssertEqual(5, seq.count, "unexpected sequence: \(seq)")
        }
    }

    func testOptionalSwiftSieve() {
        let state = StatefulObject()
        let c = (state∞(\.optstr)).changes(!=)

        var changes = 0
        c ∞> { _ in changes += 1 }

        for _ in 0...5 {
            assertChanges(changes, c ∞= ("A"))
            assertRemains(changes, c ∞= ("A"))
            assertChanges(changes, c ∞= (nil))
            assertChanges(changes, c ∞= ("B"))
            assertRemains(changes, c ∞= ("B"))
            assertChanges(changes, c ∞= (nil))

            // this one is tricky, since with KVC, previous values are often cached as NSNull(), which != nil
            assertRemains(changes, c ∞= (nil))
        }
    }

//    func testDictionaryChannels() {
//        let dict = NSMutableDictionary()
//        var changes = 0
//
//        // dict["foo"] = "bar"
//
//        dict.channelZKey(dict["foo"] as? NSString, keyPath: "foo") ∞> { _ in changes += 1 }
//
//        assertChanges(changes, dict["foo"] = "bar")
//        assertChanges(changes, dict["foo"] = NSNumber(value: 1.234 as Float))
//        assertChanges(changes, dict["foo"] = NSNull())
//        assertChanges(changes, dict["foo"] = "bar")
//    }

    func testSimpleConduits() {
        let n1 = ∞(Int(0))∞

        let state = StatefulObject()
        let n2 = state∞(\.num3)
        
        let n3 = ∞(Int(0))∞

        // bindz((n1, identity), (n2, identity))
        // (n1, { $0 + 1 }) <~∞~> (n2, { $0.integerValue - 1 }) <~∞~> (n3, { $0 + 1 })

        let n1_n2 = n1.map({ NSNumber(value: $0 + 1) }).conduit(n2.map({ $0.intValue - 1 }))
        defer { n1_n2.cancel() }
        
        let n2_n1 = (n2, { (x: NSNumber) in Optional<Int>.some(x.intValue - 1) }) <~∞~> (n3, { (x: Int) in Optional<NSNumber>.some(NSNumber(value: x + 1)) })
        defer { n2_n1.cancel() }

        n1 ∞= 2
        XCTAssertEqual(2, n1∞?)
        XCTAssertEqual(3, n2∞? )
        XCTAssertEqual(2, n3∞?)

        n2 ∞= 5
        XCTAssertEqual(4, n1∞?)
        XCTAssertEqual(5, n2∞? )
        XCTAssertEqual(4, n3∞?)

        n3 ∞= -1
        XCTAssertEqual(-1, n1∞?)
        XCTAssertEqual(0, n2∞?)
        XCTAssertEqual(-1, n3∞?)

        // make sure disconnecting the binding actually disconnects is
        n1_n2.cancel()
        n1 ∞= 20
        XCTAssertEqual(20, n1∞?)
        XCTAssertEqual(0, n2∞? )
        XCTAssertEqual(-1, n3∞?)
    }

    func testSinkObservables() {
        let channel = channelZSink(Int.self)

        channel.source.receive(1)
        var changes = 0
        _ = channel.receive({ _ in changes += 1 })

        XCTAssertEqual(0, changes)

        assertChanges(changes, channel.source.receive(1))

//        let sinkof = AnyReceiver(channel.source)
//        sinkof.put(2)
//        assertSingleChange(&changes, "sink wrapper around observable should have passed elements through to subscriptions")
//
//        subscription.cancel()
//        sinkof.put(2)
//        XCTAssertEqual(0, changes, "canceled subscription should not be called")
    }

//    func testTransformableConduits() {
//
//        let num = ∞(0)∞
//        let state = StatefulObject()
//        let strProxy = state∞(\.optstr)
//        let dict = NSMutableDictionary()
//
//        dict["stringKey"] = "foo"
//        let dictProxy = dict.channelZKey(dict["stringKey"], keyPath: "stringKey")
//
//        // bind the number value to a string equivalent
////        num ∞> { num in strProxy ∞= "\(num)" }
////        strProxy ∞> { str in num ∞= Int((str as NSString).intValue) }
//
//        _ = (num, { "\($0)" }) <~∞~> (strProxy, { $0.flatMap { Int($0) } })
//
//        _ = (strProxy, { $0 }) <~∞~> (dictProxy, { $0 as? String? })
//
////        let binding = bindz((strProxy, identity), (dictProxy, identity))
////        let binding = (strProxy, identity) <~∞~> (dictProxy, identity)
//
////        let sval = reflect(str.optstr)∞?
////        str.optstr = nil
////        dump(reflect(str.optstr)∞?)
//
//        /* FIXME
//
//        num ∞= 10
//        XCTAssertEqual("10", state.optstr ?? "<nil>")
//
//        state.optstr = "123"
//        XCTAssertEqual(123, num∞?)
//
//        num ∞= 456
//        XCTAssertEqual("456", (dict["stringKey"] as? NSString) ?? "<nil>")
//
//        dict["stringKey"] = "-98"
//        XCTAssertEqual(-98, num∞?)
//
//        // tests re-entrancy with inconsistent equivalencies
//        dict["stringKey"] = "ABC"
//        XCTAssertEqual(-98, num∞?)
//
//        dict["stringKey"] = "66"
//        XCTAssertEqual(66, num∞?)
//
//        // nullifying should change the proxy
//        dict.removeObjectForKey("stringKey")
//        XCTAssertEqual(0, num∞?)
//
//        // no change from num's value, so don't change
//        num ∞= 0
//        XCTAssertEqual("", dict["stringKey"] as NSString? ?? "<nil>")
//
//        num ∞= 1
//        XCTAssertEqual("1", dict["stringKey"] as NSString? ?? "<nil>")
//
//        num ∞= 0
//        XCTAssertEqual("0", dict["stringKey"] as NSString? ?? "<nil>")
//        */
//    }

    func testEquivalenceConduits() {

        /// Test equivalence conduits
        let state = StatefulObject()


        let qn1 = ∞(0)∞
//        let qn2 = (observee: state, keyPath: "intField", value: state.int as NSNumber)===>
        let qn2 = state∞(\.int)

        let rcvr = qn1 <~∞~> qn2
        defer { rcvr.cancel() }

        qn1 ∞= (qn1∞? + 1)
        XCTAssertEqual(1, state.int)

        qn1 ∞= (qn1∞? - 1)
        XCTAssertEqual(0, state.int)

        qn1 ∞= (qn1∞? + 1)
        XCTAssertEqual(1, state.int)

        state.int += 10
        XCTAssertEqual(11, qn1∞?)

        qn1 ∞= (qn1∞? + 1)
        XCTAssertEqual(12, state.int)
        
        
        let qs1 = ∞("")∞

        XCTAssertEqual("", qs1∞?)

        _ = state∞(\.optstr)

        // TODO: fix optonal bindings
        
//        let qsb = qs1 <?∞?> qs2
//
//        qs1.value += "X"
//        XCTAssertEqual("X", state.optstr ?? "<nil>")
//
//        qs1.value += "X"
//        XCTAssertEqual("XX", state.optstr ?? "<nil>")
//
//        /// Test that disconnecting the binding actually removes the observers
//        qsb.cancel()
//        qs1.value += "XYZ"
//        XCTAssertEqual("XX", state.optstr ?? "<nil>")
    }

    func testOptionalToPrimitiveConduits() {
        // reentrancy is expected here
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        /// Test equivalence bindings
        let state = StatefulObject()

        // FIXME: reentrancy errors; check the equatable stuff?
        let obzn1 = state.channelZKeyValue(\.num1)
        let obzn2 = state∞(\.num2)

        let cndt1 = obzn1.conduit(obzn2)
//        let cndt1 = obzn1.bind(obzn2)
        
        defer { cndt1.cancel() }

        state.num2 = 44.56
        XCTAssert(state.num1 === state.num2, "change the other side")
        XCTAssertNotNil(state.num1)
        XCTAssertNotNil(state.num2)

        state.num1 = 1
        XCTAssert(state.num1 === state.num2, "change one side")
        XCTAssertNotNil(state.num1)
        XCTAssertNotNil(state.num2)

        state.num2 = 12.34567
        XCTAssert(state.num1 === state.num2, "change the other side")
        XCTAssertNotNil(state.num1)
        XCTAssertNotNil(state.num2)

        state.num1 = 2
        XCTAssert(state.num1 === state.num2, "change back the first side")
        XCTAssertNotNil(state.num1)
        XCTAssertNotNil(state.num2)

        state.num1 = nil
        XCTAssert(state.num1 === state.num2, "binding to nil")
        XCTAssertNil(state.num2)

        state.num1 = NSNumber(value: arc4random() as UInt32)
        XCTAssert(state.num1 === state.num2, "binding to random")
        XCTAssertNotNil(state.num2)


        // binding optional num1 to non-optional num3
        let obzn3 = state∞(\.num3)

        let cndt2 = (obzn3, { $0 as NSNumber? }) <~∞~> (obzn1, { $0 })
        defer { cndt2.cancel() }

        state.num1 = 67823
        XCTAssert(state.num1 === state.num3)
        XCTAssertNotNil(state.num3)

        state.num1 = nil
        XCTAssertEqual(67823, state.num3)
        XCTAssertNotNil(state.num3, "non-optional field should not be nil")
        XCTAssertNil(state.num1)

//        let obzd = state∞(\.dbl)
//
//        let bind3 = obzn1.bind(obzd)
//
//        state.dbl = 5
//        XCTAssertEqual(state.dbl, state.num1?.doubleValue ?? -999)
//
//        state.num1 = nil
//        XCTAssertEqual(5, state.dbl, "niling optional field should not alter bound non-optional field")
//
//        state.dbl += 1
//        XCTAssertEqual(state.dbl, state.num1?.doubleValue ?? -999)
//
//        state.num1 = 9.9
//        XCTAssertEqual(9.9, state.dbl)
//
//        // ensure that assigning nil to the num1 doesn't clobber the doubleField
//        state.num1 = nil
//        XCTAssertEqual(9.9, state.dbl)
//
//        state.dbl = 9876
//        XCTAssertEqual(9876, state.num1?.doubleValue ?? -999)
//
//        state.num1 = 123
//        XCTAssertEqual(123, state.dbl)
//
//        state.num2 = 456 // num2 <~=~> num1 <?=?> doubleField
//        XCTAssertEqual(456, state.dbl)
    }

    func testLossyConduits() {
        // reentrancy is expected here
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let state = StatefulObject()

        // transfet between an int and a double field
        let obzi = state∞(\.int)
        let obzd = state∞(\.dbl)

        let conduit = obzi <~∞~> obzd
        defer { conduit.cancel() }
        
        state.int = 1
        XCTAssertEqual(1, state.int)
        XCTAssertEqual(1.0, state.dbl)

        state.dbl += 1
        XCTAssertEqual(2, state.int)
        XCTAssertEqual(2.0, state.dbl)

        state.dbl += 0.8
        XCTAssertEqual(2, state.int)
        XCTAssertEqual(2.8, state.dbl)

        state.int -= 1
        XCTAssertEqual(1, state.int)
        XCTAssertEqual(1.0, state.dbl)
    }

    func testHaltingConduits() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        // create a binding from an int to a float; when the float is set to a round number, it changes the int, otherwise it halts
        typealias T1 = Float
        typealias T2 = Float
        let x = ∞(T1(0))∞
        let y = ∞(T2(0))∞

        _ = (x, { $0 }) <~∞~> (y, { $0 == round($0) ? Optional<T1>.some(T1($0)) : Optional<T1>.none })

        x ∞= 2
        XCTAssertEqual(T1(2), x∞?)
        XCTAssertEqual(T2(2.0), y∞?)

        y ∞= 3
        XCTAssertEqual(T1(3), x∞?)
        XCTAssertEqual(T2(3.0), y∞?)

        y ∞= 9.9
        XCTAssertEqual(T1(3), x∞?)
        XCTAssertEqual(T2(9.9), y∞?)

        y ∞= 17
        XCTAssertEqual(T1(17), x∞?)
        XCTAssertEqual(T2(17.0), y∞?)

        x ∞= (x∞? + 1)
        XCTAssertEqual(T1(18), x∞?)
        XCTAssertEqual(T2(18.0), y∞?)

        y ∞= (y∞? + 0.5)
        XCTAssertEqual(T1(18), x∞?)
        XCTAssertEqual(T2(18.5), y∞?)
    }

    func testConversionConduits() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let num = ∞((Double(0.0)))∞
        num ∞= 0

        let decimalFormatter = NumberFormatter()
        decimalFormatter.numberStyle = .decimal

        let toDecimal: (Double)->(String?) = { decimalFormatter.string(from: NSNumber(value: $0)) }
        let fromDecimal: (String?)->(Double?) = { $0 == nil ? nil : decimalFormatter.number(from: $0!)?.doubleValue }

        let state1 = StatefulObject()
        let state1s = state1∞\.optstr
        let cndt1 = (num, { toDecimal($0) }) <~∞~> (state1s, fromDecimal)
        defer { cndt1.cancel() }

        let percentFormatter = NumberFormatter()
        percentFormatter.numberStyle = .percent

        let toPercent: (Double)->(NSString?) = { percentFormatter.string(from: NSNumber(value: $0)) as NSString? }
        let fromPercent: (NSString?)->(Double?) = { percentFormatter.number(from: ($0 as String?) ?? "AAA")?.doubleValue }

        let state2 = StatefulObject()
        let state2s = state2∞(\.optnsstr)
        let cndt2 = (num, toPercent) <~∞~> (state2s, fromPercent)
        defer { cndt2.cancel() }

        let spellingFormatter = NumberFormatter()
        spellingFormatter.numberStyle = .spellOut

        let state3 = StatefulObject()
        let state3s = state3∞(\.reqstr)

        let toSpelled: (Double)->(String?) = { spellingFormatter.string(from: NSNumber(value: $0)) }
        let fromSpelled: (String)->(Double?) = { spellingFormatter.number(from: $0)?.doubleValue }
        let cndt3 = (num, toSpelled) <~∞~> (state3s, fromSpelled)
        defer { cndt3.cancel() }

        num ∞= (num∞? + 1)
        XCTAssertEqual(1, num∞?)
//        XCTAssertEqual("1", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("100%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("one", state3.reqstr)

        num ∞= (num∞? + 1)
        XCTAssertEqual(2, num∞?)
//        XCTAssertEqual("2", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("200%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("two", state3.reqstr)

        state1.optstr = "3"
        XCTAssertEqual(3, num∞?)
        XCTAssertEqual("3", state1.optstr ?? "<nil>")
        XCTAssertEqual("300%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("three", state3.reqstr)

        state2.optnsstr = "400%"
        XCTAssertEqual(4, num∞?)
//        XCTAssertEqual("4", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("400%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("four", state3.reqstr)

        state3.reqstr = "five"
        XCTAssertEqual(5, num∞?)
//        XCTAssertEqual("5", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("500%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("five", state3.reqstr)

        state3.reqstr = "gibberish" // won't parse, so numbers should remain unchanged
        XCTAssertEqual(5, num∞?)
//        XCTAssertEqual("5", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("500%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("gibberish", state3.reqstr)

        state2.optnsstr = nil
        XCTAssertEqual(5, num∞?)
//        XCTAssertEqual("5", state1.optstr ?? "<nil>") // FIXME
        XCTAssertNil(state2.optnsstr)
        XCTAssertEqual("gibberish", state3.reqstr)

        num ∞= 5.4321
//        XCTAssertEqual(5.4321, num∞?)
//        XCTAssertEqual("5.432", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("543%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("five point four three two one", state3.reqstr)

        state2.optnsstr = "18.3%"
//        XCTAssertEqual(0.183, num∞?)
//        XCTAssertEqual("0.183", state1.optstr ?? "<nil>") // FIXME
        XCTAssertEqual("18%", state2.optnsstr ?? "<nil>")
        XCTAssertEqual("zero point one eight three", state3.reqstr)

    }

    func testOptionalObservables() {
        let state = StatefulObject()

        #if DEBUG_CHANNELZ
//        let startObserverCount = ChannelZKeyValueObserverCount.get()
        #endif

        var reqnsstr: NSString = ""
        // TODO: observable immediately gets deallocated unless we hold on to it
//        let a1a = state.observable(state.reqnsstr, keyPath: "reqnsstr").receive({ reqnsstr = $0 })

        // FIXME: this seems to hold on to an extra allocation
        // let a1 = sieve(state.observable(state.reqnsstr, keyPath: "reqnsstr"))

        let a1 = state.channelZKeyValue(\.reqnsstr)
        let a1a = a1.receive({ reqnsstr = $0 })

        state.reqnsstr = "foo"
        XCTAssert(reqnsstr == "foo", "failed: \(reqnsstr)")

//        let preDetachCount = count(a1.subscriptions)
        a1a.cancel()
//        let postDetachCount = count(a1.subscriptions)
//        XCTAssertEqual(postDetachCount, preDetachCount - 1, "canceling the subscription should have removed it from the subscription list")

        state.reqnsstr = "foo1"
        XCTAssertNotEqual(reqnsstr, "foo1", "canceled observable should not have fired")

        var optnsstr: NSString?
        let a2 = state∞(\.optnsstr)
        a2.receive({ optnsstr = $0 })
        
        XCTAssert(optnsstr == nil)

        state.optnsstr = nil
        XCTAssertNil(optnsstr)

        state.optnsstr = "foo"
        XCTAssert(optnsstr?.description == "foo", "failed: \(String(describing: optnsstr))")

        state.optnsstr = nil
        XCTAssertNil(optnsstr)
    }

    func testNumericConversion() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let fl: Float = convertNumericType(Double(2.34))
        XCTAssertEqual(fl, Float(2.34))

        let intN : Int = convertNumericType(Double(2.34))
        XCTAssertEqual(intN, Int(2))

        let uint64 : UInt64 = convertNumericType(Double(-2.34))
        XCTAssertEqual(uint64, UInt64(2)) // conversion runs abs()

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.doubleField.conduit(c∞\.doubleField)) {
                c.doubleField += 1
                XCTAssertEqual(s.doubleField∞?, c.doubleField)
                s.doubleField ∞= s.doubleField∞? + 1
                XCTAssertEqual(s.doubleField∞?, c.doubleField)
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.floatField.conduit(c∞\.floatField)) {
            c.floatField += 1
            XCTAssertEqual(s.floatField∞?,  c.floatField)
            s.floatField ∞= s.floatField∞? + 1
            XCTAssertEqual(s.floatField∞?, c.floatField)
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.intField.conduit(c∞\.intField)) {
            c.intField += 1
            XCTAssertEqual(s.intField∞?, c.intField)
            s.intField ∞= s.intField∞? + 1
            XCTAssertEqual(s.intField∞?, c.intField)
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.uInt32Field.conduit(c∞\.uInt32Field)) {
            c.uInt32Field += 1
            XCTAssertEqual(s.uInt32Field∞?, c.uInt32Field)
            s.uInt32Field ∞= s.uInt32Field∞? + 1
            // FIXME: this fails; maybe the Obj-C conversion is not exact?
            // XCTAssertEqual(s.uInt32Field∞?, c.uInt32Field)
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.intField <~∞~> c∞\.numberField) {
            c.numberField = NSNumber(value: c.numberField.intValue + 1)
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
            s.intField ∞= s.intField∞? + 1
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            s.numberField <~∞~> c∞\.intField
            c.intField += 1
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
            s.numberField ∞= NSNumber(value:s.numberField∞?.intValue + 1)
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            s.numberField <~∞~> c∞\.doubleField
            c.doubleField += 1
            XCTAssertEqual(s.doubleField∞?, c.numberField.doubleValue)
            s.numberField ∞= NSNumber(value: s.numberField∞?.doubleValue + 1)
            XCTAssertEqual(s.doubleField∞?, c.numberField.doubleValue)
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            s.numberField <~∞~> c∞\.int8Field
            // FIXME: crash!
//            c.int8Field += 1
            XCTAssertEqual(s.int8Field∞?, c.numberField.int8Value)
//            s.numberField ∞= NSNumber(char: s.numberField.value.charValue + 1)
            XCTAssertEqual(s.int8Field∞?, c.numberField.int8Value)
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            s.numberField <~∞~> c∞\.intField
            c.intField += 1
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
            s.numberField ∞= NSNumber(value: s.numberField∞?.intValue + 1)
            XCTAssertEqual(s.intField∞?, c.numberField.intValue)
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.doubleField <~∞~> c∞\.floatField) {
            c.floatField += 1
            XCTAssertEqual(s.doubleField∞?, Double(c.floatField))
            s.doubleField ∞= s.doubleField∞? + 1
            XCTAssertEqual(s.doubleField∞?, Double(c.floatField))
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.doubleField <~∞~> c∞\.intField) {
            c.intField += 1
            XCTAssertEqual(s.doubleField∞?, Double(c.intField))
            s.doubleField ∞= s.doubleField∞? + 1
            XCTAssertEqual(s.doubleField∞?, Double(c.intField))
            s.doubleField ∞= s.doubleField∞? + 0.5
            XCTAssertNotEqual(s.doubleField∞?, Double(c.intField)) // will be rounded
            }
        }

        autoreleasepool {
            let s = NumericHolderStruct()
            let c = NumericHolderClass()
            withExtendedLifetime(s.decimalNumberField <~∞~> c∞\.numberField) {
            c.numberField = NSNumber(value: c.numberField.intValue + 1)
            XCTAssertEqual(s.decimalNumberField∞?, c.numberField)
            s.decimalNumberField ∞= NSDecimalNumber(string: "9e12")
            XCTAssertEqual(s.decimalNumberField∞?, c.numberField)
            }
        }

//        autoreleasepool {
//            let o = NumericHolderOptionalStruct()
//            let c = NumericHolderClass()
//            c∞\.dbl <~∞~> o∞\.dbl
//            o.dbl ∞= 12.34
//            XCTAssertEqual(12.34, c.dbl)
//
//            // FIXME: crash (“could not set nil as the value for the key doubleField”), since NumericHolderClass.dbl cannot accept optionals; the conduit works because non-optionals are allowed to be cast to optionals
////            o.dbl ∞= nil
//        }
    }

    func testValueToReference() {
        let startCount = StatefulObjectCount
        let countObs: () -> (Int) = { StatefulObjectCount - startCount }
        
        var holder2: StatefulObjectHolder?
        autoreleasepool {
            XCTAssertEqual(0, countObs())
            let ob = StatefulObject()
            XCTAssertEqual(1, countObs())

            _ = StatefulObjectHolder(ob: ob)
            holder2 = StatefulObjectHolder(ob: ob)
            XCTAssert(holder2 != nil)
        }

        XCTAssertEqual(1, countObs())
        XCTAssert(holder2 != nil)
        holder2 = nil
        XCTAssertEqual(0, countObs())
    }


    /// Demonstrates using bindings with Core Data
    func testManagedObjectContext() {
        autoreleasepool {
            do {
                let attrName = NSAttributeDescription()
                attrName.name = "fullName"
                attrName.attributeType = .stringAttributeType
                attrName.defaultValue = "John Doe"
                attrName.isOptional = true

                let attrAge = NSAttributeDescription()
                attrAge.name = "age"
                attrAge.attributeType = .integer16AttributeType
                attrAge.isOptional = false

                let personEntity = NSEntityDescription()
                personEntity.name = "Person"
                personEntity.properties = [attrName, attrAge]
                personEntity.managedObjectClassName = NSStringFromClass(CoreDataPerson.self)

                let model = NSManagedObjectModel()
                model.entities = [personEntity]

                let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
                _ = try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

                let ctx = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
                ctx.persistentStoreCoordinator = psc

                var saveCount = 0
                _ = ctx.channelZNotification(.NSManagedObjectContextDidSave).receive { _ in saveCount = saveCount + 1 }

                var inserted = 0
                ctx.channelZProcessedInserts().receive { inserted = $0.count }

                var updated = 0
                ctx.channelZProcessedUpdates().receive { updated = $0.count }

                var deleted = 0
                ctx.channelZProcessedDeletes().receive { deleted = $0.count }

                var refreshed = 0
                ctx.channelZProcessedRefreshes().receive { refreshed = $0.count }

                var invalidated = 0
                ctx.channelZProcessedInvalidates().receive { invalidated = $0.count }

                XCTAssertEqual(0, refreshed)
                XCTAssertEqual(0, invalidated)



                let ob = NSManagedObject(entity: personEntity, insertInto: ctx)

                // make sure we really created our managed object subclass
//                XCTAssertEqual("ChannelZTests.CoreDataPerson_Person_", NSStringFromClass(type(of: ob)))
                let person = ob as! CoreDataPerson

                var ageChanges = 0, nameChanges = 0
                // sadly, automatic keypath identification doesn't yet work for NSManagedObject subclasses
    //            person∞person.age ∞> { _ in ageChanges += 1 }
    //            person∞person.fullName ∞> { _ in nameChanges += 1 }

                // @NSManaged fields can secretly be nil
                person.channelZKeyValue(\.age) ∞> { _ in ageChanges += 1 }
                person.channelZKeyValue(\.fullName) ∞> { _ in nameChanges += 1 }

                person.fullName = "Edward Norton"

                // “CoreData: error: Property 'setAge:' is a scalar type on class 'ChannelTests.CoreDataPerson' that does not match its Entity's property's scalar type.  Dynamically generated accessors do not support implicit type coercion.  Cannot generate a setter method for it.”
                person.age = 65

                // field tracking doesn't work either...
    //            XCTAssertEqual(1, nameChanges)
    //            XCTAssertEqual(1, ageChanges)

    //            ob.setValue("Bob Jones", forKey: "fullName")
    //            ob.setValue(65 as NSNumber, forKey: "age")

                XCTAssertEqual(0, saveCount)

                try ctx.save()

                XCTAssertEqual(1, saveCount)
                XCTAssertEqual(1, inserted)
                XCTAssertEqual(0, updated)
                XCTAssertEqual(0, deleted)

    //            ob.setValue("Frank Underwood", forKey: "fullName")
                person.fullName = "Tyler Durden"

    //            XCTAssertEqual(2, nameChanges)

                try ctx.save()

                XCTAssertEqual(2, saveCount)
                XCTAssertEqual(1, inserted)
                XCTAssertEqual(0, updated)
                XCTAssertEqual(0, deleted)

                ctx.delete(ob)

                try ctx.save()

                XCTAssertEqual(3, saveCount)
                XCTAssertEqual(0, inserted)
                XCTAssertEqual(0, updated)
                XCTAssertEqual(1, deleted)

                ctx.undoManager = nil
                ctx.reset()
            } catch let error {
                XCTFail("error: \(error)")
            }
        }

        #if DEBUG_CHANNELZ
        XCTAssertEqual(0, ChannelZKeyValueObserverCount.get(), "KV observers were not cleaned up")
        #endif
    }

    func XXXtestDetachedReceiver() { // FIXME: fails only in Treavis run: /Users/travis/build/glimpseio/ChannelZ/Tests/ChannelZTests/KeyPathTests.swift:1392: error: -[ChannelZTests.KeyPathTests testDetachedReceiver] : failed: caught "NSInternalInconsistencyException", "An instance 0x7f852d040760 of class ChannelZTests.StatefulObject was deallocated while key value observers were still registered with it. Current observation info: <NSKeyValueObservationInfo 0x7f852b5ab320> (
        var subscription: Receipt?
        autoreleasepool {
            let state = StatefulObject()
            subscription = state.channelZKeyValue(\.reqnsstr).receive({ _ in })
            XCTAssertEqual(1, StatefulObjectCount)
        }

        XCTAssertEqual(0, StatefulObjectCount)
        subscription!.cancel() // ensure that the subscription doesn't try to access a bad pointer
    }
    
    func teststFieldRemoval() {
        #if DEBUG_CHANNELZ
        let startCount = ChannelZKeyValueObserverCount.get()
        #endif
        let startObCount = StatefulObjectCount
        autoreleasepool {
            var changes = 0
            let ob = StatefulObject()
            XCTAssertEqual(0, ob.int)
            let channel = (ob ∞ \.int)
            channel.subsequent().receive { _ in changes += 1 }
            #if DEBUG_CHANNELZ
//            XCTAssertEqual(Int64(1), ChannelZKeyValueObserverCount.get() - startCount)
            #endif

            XCTAssertEqual(0, changes)
            ob.int += 1
            XCTAssertEqual(1, changes)
            ob.int += 1
            XCTAssertEqual(2, changes)
            
        }

        #if DEBUG_CHANNELZ
        XCTAssertEqual(Int64(0), ChannelZKeyValueObserverCount.get() - startCount)
        #endif
        XCTAssertEqual(0, StatefulObjectCount - startObCount)
    }

    func testManyKeyReceivers() {
        #if DEBUG_CHANNELZ
        let startCount = ChannelZKeyValueObserverCount.get()
        let startObCount = StatefulObjectCount

        autoreleasepool {
            let ob = StatefulObject()

            let channel = ob.channelZKeyValue(\.int).subsequent()
            for count in 1...20 {
                var changes = 0

                for _ in 1...count {
                    // using the keypath name because it is faster than auto-identification
//                    (ob ∞ (ob.int)).receive { _ in changes += 1 }
                    channel.receive { _ in changes += 1 }
                }
//                XCTAssertEqual(Int64(1), ChannelZKeyValueObserverCount.get() - startCount)

                XCTAssertEqual(0 * count, changes)
                ob.int += 1
                XCTAssertEqual(1 * count, changes)
                ob.int += 1
                XCTAssertEqual(2 * count, changes)
            }

            withExtendedLifetime(ob) { }
        }

        XCTAssertEqual(Int64(0), ChannelZKeyValueObserverCount.get() - startCount)
        XCTAssertEqual(0, StatefulObjectCount - startObCount)
        #endif
    }

    func testManyObserversOnBlockOperation() {
        let state = StatefulObject()
        XCTAssertEqual("ChannelZTests.StatefulObject", NSStringFromClass(type(of: state)))
        state∞\.int ∞> { _ in }
//        XCTAssertEqual("NSKVONotifying_ChannelZTests.StatefulObject", NSStringFromClass(type(of: state)))

        let operation = Operation()
        XCTAssertEqual("NSOperation", NSStringFromClass(type(of: operation)))
        operation∞\.isCancelled ∞> { _ in }
        operation∞(\.isCancelled, "cancelled") ∞> { _ in }
//        XCTAssertEqual("NSKVONotifying_NSOperation", NSStringFromClass(type(of: operation)))

        // progress is not automatically instrumented with NSKVONotifying_ (implying that it handles its own KVO)
        let progress = Progress()
        XCTAssertEqual("NSProgress", NSStringFromClass(type(of: progress)))
        progress∞\.fractionCompleted ∞> { _ in }
        progress∞(\.fractionCompleted, "fractionCompleted") ∞> { _ in }
        XCTAssertEqual("NSProgress", NSStringFromClass(type(of: progress)))

        for _ in 1...10 {
            autoreleasepool {
                let op = Operation()
                let channel = op.channelZKeyValue(\.isCancelled, path: "cancelled")

                var subscriptions: [Receipt] = []
                for _ in 1...10 {
                    let subscription = channel ∞> { _ in }
                    subscriptions += [subscription as Receipt]
                }

                // we will crash if we rely on the KVO auto-removal here
                for x in subscriptions { x.cancel() }
            }
        }
    }

    func testNSOperationObservers() {
        for _ in 1...10 {
            autoreleasepool {
                let op = Operation()
                XCTAssertEqual("NSOperation", NSStringFromClass(type(of: op)))

                var ptrs: [UnsafeMutableRawPointer?] = []
                for _ in 1...10 {
                    let ptr: UnsafeMutableRawPointer? = nil
                    ptrs.append(ptr)
                    op.addObserver(self, forKeyPath: "cancelled", options: .new, context: ptr)
                }
                // println("removing from: \(NSStringFromClass(op.dynamicType))")
                for ptr in ptrs {
                    // changed in Swift 4
//                    XCTAssertEqual("NSKVONotifying_NSOperation", NSStringFromClass(type(of: op)))
                    op.removeObserver(self, forKeyPath: "cancelled", context: ptr)
                }
                // gets swizzled back to the original class when there are no more observers
                XCTAssertEqual("NSOperation", NSStringFromClass(type(of: op)))
            }
        }

    }

    let AutoKeypathPerfomanceCount = 10
    func testAutoKeypathPerfomanceWithoutName() {
        let prog = Progress()
        for _ in 1...AutoKeypathPerfomanceCount {
            prog∞\.totalUnitCount ∞> { _ in }
        }
    }

    func testAutoKeypathPerfomanceWithName() {
        _ = Progress()
        for _ in 1...AutoKeypathPerfomanceCount {
//            prog∞(prog.totalUnitCount, "totalUnitCount") ∞> { _ in }
        }
    }

    func testPullFiltered() {
        let intField = ∞(Int(0))∞

        _ = intField.map({ Int32($0) }).map({ Double($0) }).map({ Float($0) })

        _ = intField.map({ Int32($0) }).map({ Double($0) }).map({ Float($0) })

        let intToUIntChannel = intField.filter({ $0 >= 0 }).map({ UInt($0) })
        var lastUInt = UInt(0)
        intToUIntChannel.receive({ lastUInt = $0 })

        intField ∞= 10
        XCTAssertEqual(UInt(10), lastUInt)
        XCTAssertEqual(Int(10), intToUIntChannel∞?)

        intField ∞= -1
        XCTAssertEqual(UInt(10), lastUInt, "changing a filtered value shouldn't pass down")

        XCTAssertEqual(-1, intToUIntChannel∞?, "pulling a filtered field should yield nil")
    }

//    func testChannelSignatures() {
//        let small = ∞(Int8(0))∞
//        let larger = small.map({ Int16($0) }).map({ Int32($0) }).map({ Int64($0) })
//        let largerz = larger
//
//        let large = ∞(Int64(0))∞
//        let smallerRaw = large.map({ Int32($0) }).map({ Int16($0) }).map({ Int8($0) })
////        let smallerClamped = large.map({ let ret: Int32 = $0 > Int64(Int32.max) ? Int32.max : $0 < Int64(Int32.min) ? Int32.min : Int32($0); return ret }).map({ let ret: Int16 = $0 > Int32(Int16.max) ? Int16.max : $0 < Int32(Int16.min) ? Int16.min : Int16($0); return ret }).map({ let ret: Int8 = $0 > Int16(Int8.max) ? Int8.max : $0 < Int16(Int8.min) ? Int8.min : Int8($0); return ret })
//
////        let smaller2 = large.filter({ $0 >= Int64(Int32.min) && $0 <= Int64(Int32.max) }).map({ Int32($0) }).filter({ $0 >= Int32(Int16.min) && $0 <= Int32(Int16.max) }).map({ Int16($0) }) // .filter({ $0 >= Int16(Int8.min) && $0 <= Int16(Int8.max) }).map({ Int8($0) })
//        let smallerz = smallerRaw
//
//        let link = conduit(largerz, smallerz)
//
//        large ∞= 1
//        XCTAssertEqual(large∞?, Int64(small∞?), "stable conduit")
//
//        large ∞= Int64(Int8.max)
//        XCTAssertEqual(large∞?, Int64(small∞?), "stable conduit")
//
//        large ∞= Int64(Int8.max) + 1
//        XCTAssertNotEqual(large∞?, Int64(small∞?), "unstable conduit")
//
//    }

    func testObservableCleanup() {

        autoreleasepool {
            var counter = 0, opened = 0, closed = 0, canUndo = 0, canRedo = 0, levelsOfUndo = 0

            let undo = InstanceTrackingUndoManager()
            undo.beginUndoGrouping()

            XCTAssertEqual(1, InstanceTrackingUndoManagerInstanceCount)
            undo∞\.canUndo ∞> { _ in canUndo += 1 }
            undo∞\.canRedo ∞> { _ in canRedo += 1 }
            undo∞\.levelsOfUndo ∞> { _ in levelsOfUndo += 1 }
            undo∞\.undoActionName ∞> { _ in counter += 1 }
            undo∞\.redoActionName ∞> { _ in counter += 1 }
            undo.channelZNotification(.NSUndoManagerDidOpenUndoGroup).receive({ _ in opened += 1 })
            undo.channelZNotification(.NSUndoManagerDidCloseUndoGroup).receive({ _ in closed += 1 })

            counter = 0

            XCTAssertEqual(0, counter)

            XCTAssertEqual(0, opened)

            assertChanges(opened, undo.beginUndoGrouping())
            assertChanges(closed, undo.endUndoGrouping())
            assertRemains(closed, undo.beginUndoGrouping())
            assertRemains(opened, undo.endUndoGrouping())

            undo.endUndoGrouping()
            undo.undo() // final undo needed or else the NSUndoManager won't be release (by the run loop?)

            XCTAssertEqual(1, InstanceTrackingUndoManagerInstanceCount)
        }

        XCTAssertEqual(0, InstanceTrackingUndoManagerInstanceCount)
    }

    func testOperationChannels() {
        // wrap test in an XCTAssert because it will perform a try/catch

        // file:///opt/src/impathic/glimpse/ChannelZ/ChannelTests/ChannelTests.swift: test failure: -[ChannelTests testOperationChannels()] failed: XCTAssertTrue failed: throwing "Cannot remove an observer <ChannelZ.TargetObserverRegister 0x10038d5b0> for the key path "isFinished" from <NSBlockOperation 0x1003854d0> because it is not registered as an observer." -
        XCTAssert(operationChannelTest())
    }

    func operationChannelTest() -> Bool {

        for (doCancel, doStart) in [(true, false), (false, true)] {
            let op = BlockOperation { () -> Void in }

            _ = op.channelZKeyValue(\.isCancelled, path: "isCancelled")

            var cancelled: Bool = false
            op.channelZKeyValue(\.isCancelled, path: "isCancelled").receive { cancelled = $0 }
            
            var asynchronous: Bool = false
            op.channelZKeyValue(\.isAsynchronous, path: "isAsynchronous").receive { asynchronous = $0 }
            
            var executing: Bool = false
            op.channelZKeyValue(\.isExecuting, path: "isExecuting").receive { [unowned op] in
                executing = $0
                _ = ("executing=\(executing) op: \(op)")
            }

            op.channelZKeyValue(\.isExecuting, path: "isExecuting").map({ !$0 }).filter({ $0 }).receive { [unowned op] in
                _ = ("executing=\($0) op: \(op)")
            }

            var finished: Bool = false
            op.channelZKeyValue(\.isFinished, path: "isFinished").receive { finished = $0 }
            
            var ready: Bool = false
            op.channelZKeyValue(\.isReady, path: "isReady").receive { ready = $0 }


            XCTAssertEqual(false, cancelled)
            XCTAssertEqual(false, asynchronous)
            XCTAssertEqual(false, executing)
            XCTAssertEqual(false, finished)
            XCTAssertEqual(true, ready)

            if doCancel {
                op.cancel()
            } else if doStart {
                op.start()
            }

//            XCTAssertEqual(doCancel, cancelled)
            XCTAssertEqual(false, asynchronous)
            XCTAssertEqual(false, executing)
//            XCTAssertEqual(doStart, finished)
//            XCTAssertEqual(false, ready) // seems rather indeterminate
        }

        return true
    }

    func testStraightConduit() {
        let state1 = StatefulObject()
        let state2 = StatefulObject()

        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
        let conduit = (state1∞\.int).conduit(state2∞\.int)
        defer { conduit.cancel() }

        state1.int += 1
        XCTAssertEqual(state1.int, 1)
        XCTAssertEqual(state2.int, 1)

        state2.int += 1
        XCTAssertEqual(state1.int, 2)
        XCTAssertEqual(state2.int, 2)
        
    }

    /// Test reentrancy guards for conduits that would never achieve equilibrium
    func testKVOReentrancy() {
        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        defer { ChannelZ.ChannelZReentrantReceptions.set(0) }

        let state1 = StatefulObject()
        let state2 = StatefulObject()

        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
//        let off = 10
        (state1∞\.int).map({ $0 + 10 }).conduit(state2∞\.int)

        state1.int += 1
//        XCTAssertEqual(state1.int, 1 + (off * 2))
//        XCTAssertEqual(state2.int, 1 + (off * 2))

        state2.int += 1
//        XCTAssertEqual(state1.int, 2 + (off * 3))
//        XCTAssertEqual(state2.int, 2 + (off * 4))
    }

    func testKVOConduit() {
        let state1 = StatefulObject()
        let state2 = StatefulObject()

        state1.int = 1
        state2.int = 2

        XCTAssertEqual(1, state1.int)
        XCTAssertEqual(2, state2.int)

        let i1 = (state1∞\.int)
        let i2 = (state2∞\.int)

        XCTAssertEqual(1, state1.int)
        XCTAssertEqual(2, state2.int)

        //        let rcvr = i1.bind(i2)
        let rcvr = i2.conduit(i1)

        XCTAssertEqual(2, state1.int)
        XCTAssertEqual(2, state2.int)

        state2.int += 1

        XCTAssertEqual(3, state1.int)
        XCTAssertEqual(3, state2.int)

        state1.int += 1

        XCTAssertEqual(4, state1.int)
        XCTAssertEqual(4, state2.int)

        rcvr.cancel() // unbind

        state2.int += 1
        
        XCTAssertEqual(4, state1.int)
        XCTAssertEqual(5, state2.int)
        
    }

    func testKVOBind() {
        let state1 = StatefulObject()
        let state2 = StatefulObject()

        state1.int = 1
        state2.int = 2

        XCTAssertEqual(1, state1.int)
        XCTAssertEqual(2, state2.int)

        let i1 = (state1∞\.int)
        let i2 = (state2∞\.int)

        XCTAssertEqual(1, state1.int)
        XCTAssertEqual(2, state2.int)

        let rcvr = i1.bind(i2)
//        let rcvr = i2.bind(i1)

        XCTAssertEqual(1, state1.int)
        XCTAssertEqual(1, state2.int)

        state2.int += 2

        XCTAssertEqual(3, state1.int)
        XCTAssertEqual(3, state2.int)

        state1.int += 1

        XCTAssertEqual(4, state1.int)
        XCTAssertEqual(4, state2.int)

        rcvr.cancel() // unbind

        state2.int += 1

        XCTAssertEqual(4, state1.int)
        XCTAssertEqual(5, state2.int)

    }

    /// Test reentrancy guards for conduits that would never achieve equilibrium
    func testKVOBindOptional() {
        let state1 = StatefulObject()
        let state2 = StatefulObject()

        state1.num1 = nil
        state2.num1 = 2

        XCTAssertEqual(nil, state1.num1)
        XCTAssertEqual(2, state2.num1)

        let i1 = (state1∞\.num1)
        let i2 = (state2∞\.num1)

        XCTAssertEqual(nil, state1.num1)
        XCTAssertEqual(2, state2.num1)

        let rcvr = i1.bind(i2)
//        let rcvr = i2.bind(i1)

        XCTAssertEqual(nil, state1.num1)
        //        XCTAssertEqual(nil, state2.num1) // FIXME: should nil out num1

        state2.num1 = 2

//        XCTAssertEqual(2, state1.num1) // FIXME: set num1 to 2
        XCTAssertEqual(2, state2.num1)

        state2.num1 = NSNumber(value: state2.num1!.intValue + 1)

        XCTAssertEqual(3, state1.num1)
        XCTAssertEqual(3, state2.num1)

        state1.num1 = NSNumber(value: state1.num1!.intValue + 1)

        XCTAssertEqual(4, state1.num1)
        XCTAssertEqual(4, state2.num1)

        state1.num1 = nil

        XCTAssertEqual(nil, state1.num1)
        XCTAssertEqual(nil, state2.num1)

        state2.num1 = 99

        XCTAssertEqual(99, state1.num1)
        XCTAssertEqual(99, state2.num1)

        rcvr.cancel() // unbind

        state2.num1 = NSNumber(value: state2.num1!.intValue + 1)
        
        XCTAssertEqual(99, state1.num1)
        XCTAssertEqual(100, state2.num1)
        
    }

    /// Test reentrancy guards for conduits that would never achieve equilibrium
    func testSwiftReentrancy() {
        func reentrants() -> Int64 {
            let x = ChannelZReentrantReceptions.get()
            ChannelZReentrantReceptions.set(0)
            return x
        }

        let state1 = ∞=Int(0)=∞
        let state2 = ∞=Int(0)=∞
        let state3 = ∞=Int(0)=∞

        XCTAssertEqual(0, reentrants())

        // note that since we allow 1 re-entrant pass, we're going to be set to X+(off * 2)
        state1.map({ $0 + 1 }).conduit(state2)
        state2.map({ $0 + 2 }).conduit(state3)
        state3.map({ $0 + 3 }).conduit(state1)
        state3.map({ $0 + 4 }).conduit(state2)
        state3.map({ $0 + 5 }).conduit(state3)

        XCTAssertEqual(166, reentrants())

        state1 ∞= state1∞? + 1
        XCTAssertEqual(state1∞?, 30)
        XCTAssertEqual(state2∞?, 30)
        XCTAssertEqual(state3∞?, 31)

        XCTAssertEqual(185, reentrants())

        state2 ∞= state2∞? + 1
        XCTAssertEqual(state1∞?, 35)
        XCTAssertEqual(state2∞?, 35)
        XCTAssertEqual(state3∞?, 36)

        XCTAssertEqual(112, reentrants())

        state3 ∞= state3∞? + 1
        XCTAssertEqual(state1∞?, 42)
        XCTAssertEqual(state2∞?, 43)
        XCTAssertEqual(state3∞?, 42)

        XCTAssertEqual(139, reentrants())

        // we expect the ChannelZReentrantReceptions to be incremented; clear it so we don't fail in tearDown
        _ = reentrants()
    }

//    func testRequiredToOptional() {
//        let state1 = ∞Int(0)∞
//        let state2 = ∞Optional<Int>()∞
//
//        state1.map({ Optional<Int>($0) }) ∞-> state2
//
//        XCTAssertEqual(0, state1∞?)
//        XCTAssertEqual(999, state2∞? ?? 999)
//
//        state1 ∞= state1∞? + 1
//
//        XCTAssertEqual(1, state1∞?)
//        XCTAssertEqual(1, state2∞? ?? 999)
//
//    }

    func testMemory2() {
        autoreleasepool {
            let md1 = MemoryDemo()
            let md2 = MemoryDemo()
            let cndt = (md1∞\.stringField).conduit(md2∞\.stringField)
            md1.stringField += "Hello "
            md2.stringField += "World"
            XCTAssertEqual(md1.stringField, "Hello World")
            XCTAssertEqual(md2.stringField, "Hello World")
            XCTAssertEqual(2, MemoryDemoCount)
            cndt.cancel()
        }
        
        // subscriptions are retained by the channel sources
        XCTAssertEqual(0, MemoryDemoCount)
    }


    func testAutoKVOIdentification() {
        let state = StatefulObjectSubSubclass()
        var count = 0

        let _ : Receipt = state.channelZKeyValue(\.optstr) ∞> { _ in count += 1 }
        state∞\.reqstr ∞> { _ in count += 1 }
        state∞\.optnsstr ∞> { _ in count += 1 }
        state∞\.reqnsstr ∞> { _ in count += 1 }
        state∞\.int ∞> { _ in count += 1 }
        state∞\.dbl ∞> { _ in count += 1 }
        state∞\.num1 ∞> { _ in count += 1 }
        state∞\.num2 ∞> { _ in count += 1 }
        state∞\.num3 ∞> { _ in count += 1 }
        state∞\.num3 ∞> { _ in count += 1 }
        state∞\.reqobj ∞> { _ in count += 1 }
        state∞\.optobj ∞> { _ in count += 1 }
    }

    func testSimpleObservation() {
        var observer: NSKeyValueObservation?
        
        autoreleasepool {
            let ob = StatefulObject()
            var changes = 0
            observer = ob.observe(\.reqstr) { (x, y) in
                    changes += 1
            }

            for _ in 1...3 {
                ob.reqstr += "x"
            }
            
            XCTAssertEqual(3, changes)
            
            observer?.invalidate()
        }
    }
    
    func testDeepKeyPath() {
        testDeepKeyPath(withSeparateChannel: true)
//        testDeepKeyPath(withSeparateChannel: false) // fails because the channel is unretained
    }
    
    func testDeepKeyPath(withSeparateChannel: Bool) {
        typealias T = StatefulObjectSubSubclass
        
        let state = T()
        var count = 0

        let rcvr: Receipt
        var channel: KeyStateChannel<T, Int>?
        
        if withSeparateChannel {
            channel = state.channelZKeyState(\.state.int)
            rcvr = channel!.receive({ _ in
                count += 1
            })
        } else {
            rcvr = state.channelZKeyState(\.state.int).receive({ _ in
                count += 1
            })
        }
        
        assertChanges(count, state.setValue(state.state.int + 1, forKeyPath: "state.int"))
        assertChanges(count, state.state.int += 1)
        let oldstate = state.state

        assertChanges(count, state.state = StatefulObject())

        assertRemains(count, oldstate.int += 1, msg: "should not be watching stale state")

        assertChanges(count, state.state.int += 1)

        assertChanges(count, state.state.int -= 1)

        assertChanges(count, state.state = StatefulObject(), msg: "new intermediate with same terminal value should not pass sieve") // or should it?
        
        rcvr.cancel()
        
//        defer { rcvr.cancel() }
//        XCTAssertNotNil(rcvr)
    }

    func testDeepOptionalKeyPath() {
        let state = StatefulObjectSubSubclass()
        var count = 0

        let channel = state∞(\.optobj?.optobj?.int)
        
        channel ∞> { _ in count += 1 }

        assertChanges(count, state.optobj = StatefulObjectSubSubclass())

        assertChanges(count, state.optobj!.optobj = StatefulObjectSubSubclass())

        assertChanges(count, state.optobj!.optobj!.int += 1)
        
    }

    func testCollectionArrayKeyPaths() {
        let state = StatefulObjectSubSubclass()
        var changes = 0
        let rcvr = state.channelZCollection(\.array).receive { change in
            switch change {
            case .assigned(_): break
            case .added(let indices, _): changes += indices.count
            case .removed(let indices, _): changes += indices.count
            case .replaced(let indices, _, _): changes += indices.count
            }
        }

        let array = state.mutableArrayValue(forKey: "array")
        array.add("One") // +1
        array.add("Two") // +1
        array.add("Three") // +1
        array.removeObject(at: 1) // -1
        array.replaceObject(at: 1, with: "None") // +-1
        array.removeAllObjects() // -2
        array.addObjects(from: ["A", "B", "C", "D"]) // +4

        XCTAssertEqual(11, changes)
        XCTAssertNotNil(rcvr)
    }

    func testCollectionOrderedSetKeyPaths() {
        let state = StatefulObjectSubSubclass()
        var changes = 0
        let channel = state.channelZCollection(\.orderedSet).receive { change in
            switch change {
            case .assigned: break
            case .added(let indices, _): changes += indices.count
            case .removed(let indices, _): changes += indices.count
            case .replaced(let indices, _, _): changes += indices.count
            }
        }

        let orderedSet = state.mutableOrderedSetValue(forKey: "orderedSet")
        orderedSet.add("One") // +1
        orderedSet.add("Two") // +1
        orderedSet.add("Three") // +1
        orderedSet.add("One") // +0
        orderedSet.add("Two") // +0
        orderedSet.add("Three") // +0
        orderedSet.add("Four") // +1
        orderedSet.removeObject(at: 1) // -1
        orderedSet.replaceObject(at: 1, with: "None") // +-1
        orderedSet.removeAllObjects() // -3
        orderedSet.addObjects(from: ["A", "B", "C", "D"]) // +4

        XCTAssertEqual(13, changes)
        XCTAssertNotNil(channel)
        
    }


    func testCollectionSetKeyPaths() {
        // the new Swift 4 observe() behaves differently with Sets; it no longer reports the inserted or removed elements
        let state = StatefulObjectSubSubclass()
        var changes = 0
        let receiver = state.channelZCollection(\.set).receive { change in
            switch change {
            case .assigned: break
            case .added: changes += 1 // changes += new.count
            case .removed: changes += 1 // changes += old.count
            }
        }
        
        let set = state.mutableSetValue(forKey: "set")
        set.add("One")
        set.add("Two")
        set.add("Three")
        set.add("One")
        set.add("Two")
        set.add("Three")
        set.remove("Two")
        set.remove("nonexistant") // shouldn't fire

        // XCTAssertEqual(4, changes)
        XCTAssertEqual(8, changes)
        XCTAssertNotNil(receiver)
        
    }

    private var keptalive = Array<Any>()
    
    /// Keep the given object alive for the duration of the test; useful for channels that automatically cleanup resources upon deallocation
    func keepalive<T>(_ ob: T) -> T {
        keptalive.append(ob)
        return ob
    }

    override func tearDown() {
        super.tearDown()

        keptalive.removeAll()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_CHANNELZ
            XCTAssertEqual(0, ChannelZTests.StatefulObjectCount, "\(self.name) all StatefulObject instances should have been deallocated")
            ChannelZTests.StatefulObjectCount = 0

            XCTAssertEqual(0, ChannelZ.ChannelZKeyValueObserverCount.get(), "\(self.name) KV observers were not cleaned up")
            ChannelZ.ChannelZKeyValueObserverCount.set(0)

            // tests that expect reentrant detection should manually clear it with ChannelZReentrantReceptions = 0
            XCTAssertEqual(0, ChannelZ.ChannelZReentrantReceptions.get(), "\(self.name) unexpected reentrant receptions detected")
            ChannelZ.ChannelZReentrantReceptions.set(0)

            // XCTAssertEqual(0, ChannelZ.ChannelZNotificationObserverCount.get(), "Notification observers were not cleaned up")
            // ChannelZ.ChannelZNotificationObserverCount = 0

        #else
            XCTFail("Why are you running tests with debugging off?")
        #endif
    }

}


struct StatefulObjectHolder {
    let ob: StatefulObject
}

enum SomeEnum { case yes, no, maybeSo }

struct SwiftStruct {
    var intField: Int
    var stringField: String?
    var enumField: SomeEnum = .no
}

struct SwiftEquatableStruct : Equatable {
    var intField: Int
    var stringField: String?
    var enumField: SomeEnum = .no
}

func == (lhs: SwiftEquatableStruct, rhs: SwiftEquatableStruct) -> Bool {
    return lhs.intField == rhs.intField && lhs.stringField == rhs.stringField && lhs.enumField == rhs.enumField
}

struct SwiftObservables {
    let stringField = ∞=("")=∞
    let enumField = ∞=(SomeEnum.no)=∞
    let swiftStruct = ∞(SwiftStruct(intField: 1, stringField: "", enumField: .yes))∞
}


var StatefulObjectCount = 0

class StatefulObject : NSObject {
    @objc dynamic var optstr: String?
    @objc dynamic var reqstr: String = ""

    @objc dynamic var optnsstr: NSString?
    @objc dynamic var reqnsstr: NSString = ""

    @objc dynamic var int: Int = 0
    @objc dynamic var dbl: Double = 0
    @objc dynamic var num1: NSNumber?
    @objc dynamic var num2: NSNumber?
    @objc dynamic var num3: NSNumber = 9

    @objc dynamic var reqobj: NSObject = NSObject()
    @objc dynamic var optobj: StatefulObject? = nil

    @objc dynamic var array = NSMutableArray()
    @objc dynamic var set = NSMutableSet()
    @objc dynamic var orderedSet = NSMutableOrderedSet()

    override init() {
        super.init()
        StatefulObjectCount += 1
    }

    deinit {
        StatefulObjectCount -= 1
    }
}

class StatefulObjectSubclass : StatefulObject {
    @objc dynamic var state = StatefulObject()
}

final class StatefulObjectSubSubclass : StatefulObjectSubclass { }

var InstanceTrackingUndoManagerInstanceCount = 0
class InstanceTrackingUndoManager : UndoManager {
    override init() {
        super.init()
        InstanceTrackingUndoManagerInstanceCount += 1
    }

    deinit {
        InstanceTrackingUndoManagerInstanceCount -= 1
    }
}

class CoreDataPerson : NSManagedObject {
    @objc dynamic var fullName: String?
    @NSManaged var age: Int16
}

var MemoryDemoCount = 0
class MemoryDemo : NSObject {
    @objc dynamic var stringField : String = ""

    // track creates and releases
    override init() { MemoryDemoCount += 1 }
    deinit { MemoryDemoCount -= 1 }
}

class NumericHolderClass : NSObject {
    @objc dynamic var numberField: NSNumber = 0
    @objc dynamic var decimalNumberField: NSDecimalNumber = 0
    @objc dynamic var doubleField: Double = 0
    @objc dynamic var floatField: Float = 0
    @objc dynamic var intField: Int = 0
    @objc dynamic var uInt64Field: UInt64 = 0
    @objc dynamic var int64Field: Int64 = 0
    @objc dynamic var uInt32Field: UInt32 = 0
    @objc dynamic var int32Field: Int32 = 0
    @objc dynamic var uInt16Field: UInt16 = 0
    @objc dynamic var int16Field: Int16 = 0
    @objc dynamic var uInt8Field: UInt8 = 0
    @objc dynamic var int8Field: Int8 = 0
    @objc dynamic var boolField: Bool = false

//    var numberFieldZ: Channel<KeyValueTransceiver<NSNumber>, NSNumber> { return channelZKey(numberField) }
//    lazy var decimalNumberFieldZ: NSDecimalNumber = 0
//    lazy var doubleFieldZ: Double = 0
//    lazy var floatFieldZ: Float = 0
//    lazy var intFieldZ: Int = 0
//    lazy var uInt64FieldZ: UInt64 = 0
//    lazy var int64FieldZ: Int64 = 0
//    lazy var uInt32FieldZ: UInt32 = 0
//    lazy var int32FieldZ: Int32 = 0
//    lazy var uInt16FieldZ: UInt16 = 0
//    lazy var int16FieldZ: Int16 = 0
//    lazy var uInt8FieldZ: UInt8 = 0
//    lazy var int8FieldZ: Int8 = 0
//    lazy var boolFieldZ: Bool = false

}

struct NumericHolderStruct {
    let numberField = ∞(NSNumber(floatLiteral: 0.0))∞
    let decimalNumberField = ∞=(NSDecimalNumber(floatLiteral: 0.0))=∞
    let doubleField = ∞=(Double(0))=∞
    let floatField = ∞=(Float(0))=∞
    let intField = ∞=(Int(0))=∞
    let uInt64Field = ∞=(UInt64(0))=∞
    let int64Field = ∞=(Int64(0))=∞
    let uInt32Field = ∞=(UInt32(0))=∞
    let int32Field = ∞=(Int32(0))=∞
    let uInt16Field = ∞=(UInt16(0))=∞
    let int16Field = ∞=(Int16(0))=∞
    let uInt8Field = ∞=(UInt8(0))=∞
    let int8Field = ∞=(Int8(0))=∞
    let boolField = ∞=(Bool(false))=∞
}

struct NumericHolderOptionalStruct {
    let numberField = ∞=(nil as NSNumber?)=∞
    let decimalNumberField = ∞=(nil as NSDecimalNumber?)=∞
    let doubleField = ∞=(nil as Double?)=∞
    let floatField = ∞=(nil as Float?)=∞
    let intField = ∞=(nil as Int?)=∞
    let uInt64Field = ∞=(nil as UInt64?)=∞
    let int64Field = ∞=(nil as Int64?)=∞
    let uInt32Field = ∞=(nil as UInt32?)=∞
    let int32Field = ∞=(nil as Int32?)=∞
    let uInt16Field = ∞=(nil as UInt16?)=∞
    let int16Field = ∞=(nil as Int16?)=∞
    let uInt8Field = ∞=(nil as UInt8?)=∞
    let int8Field = ∞=(nil as Int8?)=∞
    let boolField = ∞=(nil as Bool?)=∞
}


var ChannelThingsInstances = 0
class ChannelThing: NSObject {
    let int = ∞=(0)=∞
    let double = ∞=(0.0)=∞
    let string = ∞=("")=∞
    let stringish = ∞(nil as String?)∞

    override init() { ChannelThingsInstances += 1 }
    deinit { ChannelThingsInstances -= 1 }
}

#endif


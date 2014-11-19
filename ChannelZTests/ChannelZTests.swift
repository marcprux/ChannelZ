//
//  ChannelZTests.swift
//  ChannelZTests
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

import XCTest
import ChannelZ
import CoreData
import ObjectiveC

#if os(OSX)
    import AppKit
#endif

#if os(iOS)
    import UIKit
#endif


public class ChannelZTests: XCTestCase {
    override public func tearDown() {
        super.tearDown()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_CHANNELZ
        XCTAssertEqual(0, StatefulObjectCount, "all StatefulObject instances should have been deallocated")
        StatefulObjectCount = 0
        XCTAssertEqual(0, ChannelZKeyValueObserverCount, "KV observers were not cleaned up")
        ChannelZKeyValueObserverCount = 0
        XCTAssertEqual(0, ChannelZNotificationObserverCount, "Notification observers were not cleaned up")
        ChannelZNotificationObserverCount = 0
        #else
        XCTFail("Why are you running tests with debugging off?")
        #endif
    }

    func testFunnels() {
        var observedBool = <∞false∞>
        observedBool.value = false

        var changeCount: Int = 0

        let ob1 = observedBool.attach { v in
            changeCount = changeCount + 1
        }

        XCTAssertEqual(0, changeCount)

        observedBool <- true
        XCTAssertEqual(1, changeCount)

        observedBool <- true
        XCTAssertEqual(1, changeCount)

        observedBool <- false
        observedBool <- false


        XCTAssertEqual(2, changeCount)

        // XCTAssertEqual(test, false)

        var stringFieldChanges: Int = 0
        var intFieldChanges: Int = 0
        var doubleFieldChanges: Int = 0


        #if DEBUG_CHANNELZ
        let startObserverCount = ChannelZKeyValueObserverCount
        #endif

        autoreleasepool {
            let state = StatefulObject()
            state.optionalStringField = "sval1"

            state.sieve(state.intField).attach { _ in intFieldChanges += 1 }

            #if DEBUG_CHANNELZ
            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1)
            #endif

            var stringFieldObserver = state.sieve(state.optionalStringField)
            stringFieldObserver.attach { _ in stringFieldChanges += 1 }

            state.sieve(state.doubleField).attach { _ in doubleFieldChanges += 1 }

            XCTAssertEqual(0, --stringFieldChanges) // initial value of optional is primed
            XCTAssertEqual("sval1", state.optionalStringField!)

            state.intField++; XCTAssertEqual(0, --intFieldChanges)
            state.intField = state.intField + 0; XCTAssertEqual(0, intFieldChanges)
            state.intField = state.intField + 1 - 1; XCTAssertEqual(0, intFieldChanges)
            state.intField++; XCTAssertEqual(0, --intFieldChanges)
            state.optionalStringField = state.optionalStringField ?? "" + ""; XCTAssertEqual(0, stringFieldChanges)
            state.optionalStringField! += "x"; XCTAssertEqual(0, --stringFieldChanges)
            stringFieldObserver.value = "y"; XCTAssertEqual(0, --stringFieldChanges)
            state.optionalStringField = nil; XCTAssertEqual(0, --stringFieldChanges)
            state.optionalStringField = ""; XCTAssertEqual(0, --stringFieldChanges)
            state.optionalStringField = ""; XCTAssertEqual(0, stringFieldChanges)
            state.optionalStringField = "foo"; XCTAssertEqual(0, --stringFieldChanges)

            #if DEBUG_CHANNELZ
            XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 3, "observers should still be around before cleanup")
            #endif
        }

        #if DEBUG_CHANNELZ
        XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount, "observers should have been cleared after cleanup")
        #endif
    }

    func testFilteredFunnels() {

        var strlen = 0

        let sv = sieveField("X")
        sv.filter({ _ in true }).map(countElements)
        sv.channelOf.filter({ _ in true }).channelOf.map(countElements)
        sv.map(countElements)

        var a = sv.filter({ _ in true }).map(countElements).filter({ $0 % 2 == 1 })
        var aa = a.attach { strlen = $0 }

        a.push("XXX")

        XCTAssertEqual(3, strlen)

        // TODO: need to re-implement .value for FieldChannels, etc.
//        a.push(a.pull() + "ZZ")
//        XCTAssertEqual(5, strlen)
//        XCTAssertEqual("XXXZZ", a.pull())
//
//        a.push(a.pull() + "A")
//        XCTAssertEqual("XXXZZA", a.pull())
//        XCTAssertEqual(5, strlen, "even-numbered increment should have been filtered")
//
//        a.push(a.pull() + "A")
//        XCTAssertEqual("XXXZZAA", a.pull())
//        XCTAssertEqual(7, strlen)


        let x = sieveField(1).filter { $0 <= 10 }

        var changeCount: Double = 0
        var changeLog: String = ""

        // track the number of changes using two separate attachments
        x.attach { _ in changeCount += 0.5 }
        x.attach { _ in changeCount += 0.5 }

        let xfm = x.map( { String($0) })
        let xfma = xfm.attach { s in changeLog += (countElements(changeLog) > 0 ? ", " : "") + s } // create a string log of all the changes


        XCTAssertEqual(0, changeCount)
        XCTAssertNotEqual(5, x.pull())

        x <- 5
        XCTAssertEqual(5, x.pull())
        XCTAssertEqual(1, changeCount)


        x <- 5
        XCTAssertEqual(5, x.pull())
        XCTAssertEqual(1, changeCount)

        x <- 6
        XCTAssertEqual(2, changeCount)

        // now test the filter: only changes to numbers less than or equal to 10 should flow to the receivers
        x <- 20
        XCTAssertEqual(2, changeCount, "out of bounds change should not have fired listener")

        x <- 6
        XCTAssertEqual(3, changeCount, "in-bounds change should have fired listener")

        for i in 1...100 {
            x <- i
        }
        XCTAssertEqual(13, changeCount, "in-bounds change should have fired listener")

        XCTAssertEqual("5, 6, 6, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10", changeLog)


        var tc = 0.0
        let t = <∞1.0∞>

        t.filter({ $0 % 2 == 0 }).filter({ $0 % 9 == 0 }).attach({ n in tc += n })
//        t.attach({ n in tc += n })

        for i in 1...100 { t <- Double(i) }
        // FIXME: seems to be getting released somehow
//        XCTAssertEqual(270.0, tc, "sum of all numbers between 1 and 100 divisible by 2 and 9")

        var lastt = ""

        let tv = t.map({ v in v }).filter({ $0 % 2 == 0 }).map(-).map({ "Even: \($0)" })
        tv.attach({ lastt = $0 })


        for i in 1...99 { tv <- Double(i) }
        XCTAssertEqual("Even: -98.0", lastt)
    }

    func testFieldSieve() {
        var xs: Int = 1
        var c = sieveField(xs)

        var changes = 0
        c.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        c.push(c.pull() + 1); XCTAssertEqual(0, --changes)
        c.push(2); XCTAssertEqual(0, changes)
        c.push(2); c.push(2); XCTAssertEqual(0, changes)
        c.push(9); c.push(9); XCTAssertEqual(0, --changes)
    }

    func testOptionalFieldSieve() {
        var xs: Int? = nil
        var c = sieveField(xs)

        var changes = 0
        c.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        c.push(2); XCTAssertEqual(0, --changes)
        c.push(2); c.push(2); XCTAssertEqual(0, changes)
        c.push(nil); XCTAssertEqual(0, --changes)
        c.push(nil); XCTAssertEqual(0, changes)
        c.push(1); XCTAssertEqual(0, --changes)
        c.push(1); XCTAssertEqual(0, changes)
        c.push(2); XCTAssertEqual(0, --changes)
    }

    func testKeyValueSieve() {
        var state = StatefulObject()
        var c = state.sieve(state.requiredStringField)

        var changes = 0
        c.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        c.push(""); XCTAssertEqual(0, changes, "default to default should not change")
        c.push("A"); XCTAssertEqual(0, --changes, "default to A should change")
        c.push("A"); XCTAssertEqual(0, changes, "A to A should not change")
        c.push("B"); c.push("B"); XCTAssertEqual(0, --changes, "A to B should change once")
    }

    func testKeyValueSieveUnretainedOutlet() {
        var state = StatefulObject()
        var c = state.sieve(state.requiredStringField)

        var changes = 0
        c.attach { _ in changes += 1 } // note we do not assign it locally, so it should immediately get cleaned up

        XCTAssertEqual(0, changes)
        c.push("A"); XCTAssertEqual(1, changes, "unretained outlet should still listen")
        c.push(""); XCTAssertEqual(2, changes, "unretained outlet should still listen")
    }

    func testOptionalNSKeyValueSieve() {
        var state = StatefulObject()
        var c = state.sieve(state.optionalNSStringField)

        var changes = 0
        c.attach { _ in changes += 1 }

        for _ in 0...5 {
            XCTAssertEqual(0, changes)
            c.push("A"); XCTAssertEqual(0, --changes, "unset to A should change")
            c.push("A"); c.push("A"); XCTAssertEqual(0, changes, "A to A should not change")
            c.push(nil); XCTAssertEqual(0, --changes, "A to nil should change")
            c.push("B"); c.push("B"); XCTAssertEqual(0, --changes, "nil to B should change once")
            c.push(nil); XCTAssertEqual(0, --changes, "B to nil should change")

            // this one is tricky, since with KVC, previous values are often cached as NSNull(), which != nil
            c.push(nil); c.push(nil); XCTAssertEqual(0, changes, "nil to nil should not change")
        }
    }

    func testOptionalSwiftSieve() {
        var state = StatefulObject()
        var c = state.sieve(state.optionalStringField)

        var changes = 0
        c.attach { _ in changes += 1 }

        for _ in 0...5 {
            XCTAssertEqual(0, changes)
            c.push("A"); XCTAssertEqual(0, --changes, "unset to A should change")
            c.push("A"); c.push("A"); XCTAssertEqual(0, changes, "A to A should not change")
            c.push(nil); XCTAssertEqual(0, --changes, "A to nil should change")
            c.push("B"); c.push("B"); XCTAssertEqual(0, --changes, "nil to B should change once")
            c.push(nil); XCTAssertEqual(0, --changes, "B to nil should change")

            // this one is tricky, since with KVC, previous values are often cached as NSNull(), which != nil
            c.push(nil); c.push(nil); XCTAssertEqual(0, changes, "nil to nil should not change")
        }
    }

    func testDictionaryChannels() {
        let dict = NSMutableDictionary()
        var fooChanges = 0

        XCTAssertEqual(0, fooChanges)

        dict["foo"] = "bar"

        dict.sieve(dict["foo"] as? NSString, keyPath: "foo").attach { _ in fooChanges += 1 }
        XCTAssertEqual(0, --fooChanges)

        dict["foo"] = "bar"
        XCTAssertEqual(0, fooChanges)

        dict["foo"] = NSNumber(float: 1.234)
        XCTAssertEqual(0, --fooChanges)

        dict["foo"] = NSNull()
        XCTAssertEqual(0, fooChanges) // note that setting to null does not pass the sieve

        dict["foo"] = "bar"
        XCTAssertEqual(0, --fooChanges)
    }

    func testFieldChannelFunnel() {
        var xs: Int = 1
        var x = channelField(xs)
        var f: FunnelOf<Int> = x.funnelOf // read-only funnel of channel x

        var changes = 0
        var outlet = f.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        x.push(x.pull() + 1); XCTAssertEqual(0, --changes)
        x.push(2); XCTAssertEqual(0, --changes)
        x.push(2); XCTAssertEqual(0, --changes)
        x.push(9);XCTAssertEqual(0, --changes)

        outlet.detach()
        x.push(-1); XCTAssertEqual(0, changes)
    }

    func testFieldChannelMapFunnel() {
        var xs: Bool = true
        var x = channelField(xs)

        var xf: FunnelOf<Bool> = x.funnelOf // read-only funnel of channel x

        let fxa = xf.attach { (x: Bool) in return }

        var y = x.map({ "\($0)" })
        var yf: FunnelOf<String> = y.funnelOf // read-only funnel of mapped channel y

        var changes = 0
        var fya: Outlet = yf.attach { (x: String) in changes += 1 }

        XCTAssertEqual(0, changes)
        x.push(!x.pull()); XCTAssertEqual(0, --changes)
        x.push(true); XCTAssertEqual(0, --changes)
        x.push(true); XCTAssertEqual(0, --changes)
        x.push(false); XCTAssertEqual(0, --changes)

        fya.detach()
        x.push(true); XCTAssertEqual(0, changes)
    }

    func testFieldSieveChannelMapFunnel() {
        var xs: Double = 1

        var x = sieveField(xs)
        var xf: FunnelOf<Double> = x.funnelOf // read-only funnel of channel x

        var fxa = xf.attach { (x: Double) in return }

        var y = x.map({ "\($0)" })
        var yf: FunnelOf<String> = y.funnelOf // read-only funnel of channel y

        var changes = 0
        var fya: Outlet = yf.attach { (x: String) in changes += 1 }

        XCTAssertEqual(0, changes)
        x.push(x.pull() + 1); XCTAssertEqual(0, --changes)
        x.push(2); XCTAssertEqual(0, changes)
        x.push(2); x.push(2); XCTAssertEqual(0, changes)
        x.push(9); x.push(9); XCTAssertEqual(0, --changes)

        fxa.detach()
        fya.detach()
        x.push(-1); XCTAssertEqual(0, changes)
    }

    func testHeterogeneousPipe() {
        var a = <∞Double(1.0)∞>
        var b = <∞Double(1.0)∞>

        let pipeline = pipe(a, b)

        a <- 2.0
        XCTAssertEqual(2.0, a.pull())
        XCTAssertEqual(2.0, b.pull())

        b <- 3.0
        XCTAssertEqual(3.0, a.pull())
        XCTAssertEqual(3.0, b.pull())
    }

    func testHomogeneousPipe() {
        var a = <∞Double(1.0)∞>
        var b = <∞UInt(1)∞>

        // “fatal error: floating point value can not be converted to UInt because it is less than UInt.min”
        var af = a.filter({ $0 >= 0 }).map({ UInt($0) })
        var bf = b.map({ Double($0) })
        let pipeline = pipe(af, bf)

        a <- 2.0
        XCTAssertEqual(2.0, a.pull())
        XCTAssertEqual(UInt(2), b.pull())

        b <- 3
        XCTAssertEqual(3.0, a.pull())
        XCTAssertEqual(UInt(3), b.pull())

        a <- 9.9
        XCTAssertEqual(9.9, a.pull())
        XCTAssertEqual(UInt(9), b.pull())

        a <- -5.0
        XCTAssertEqual(-5.0, a.pull())
        XCTAssertEqual(UInt(9), b.pull())

        a <- 8.1
        XCTAssertEqual(8.1, a.pull())
        XCTAssertEqual(UInt(8), b.pull())
    }

    func testUnstablePipe() {
        var a = <∞1∞>
        var b = <∞2∞>

        // this unstable pipe would never achieve equilibrium, and so relies on re-entrancy checks to halt the flow
        var af = a.map({ $0 + 1 })
        let pipeline = pipe(af, b)
//        let pipeline = af.pipe(b)

        a.value = 2
        XCTAssertEqual(2, a.pull())
        XCTAssertEqual(3, b.pull())

        b.push(10)
        XCTAssertEqual(10, a.pull())
        XCTAssertEqual(10, b.pull())

        a <- 99
        XCTAssertEqual(99, a.pull())
        XCTAssertEqual(100, b.pull())
    }


    func testCombination() {
        // FIXME: combinations don't work if they come after a filter since it has no way pull down state with which to prime itself

//        let a = <∞Float(3.0)∞>
//        let b = <∞UInt(7)∞>
//        let c = <∞Bool(false)∞>

        let a = channelField(Float(3.0))
        let b = channelField(UInt(7))
        let c = channelField(Bool(false))

        let d = c.map { "\($0)" }

        var lastSum = 0.0
        var lastString = ""

        var combo1 = a.combine(b)
        combo1.attach { (floatChange: Float?, uintChange: UInt?) in

        }

        var combo2 = combo1.combine(d)

        combo2.attach({ (firstTuple: (floatChange: Float, uintChange: UInt), stringChange: String) in
            lastString = stringChange
        })

        let flattened = flatten(combo2)

        let outlet2 = flattened.attach { (f, u, s) in
            lastSum = Double(f) + Double(u)
        }

        a <- 12

        XCTAssertEqual(19.0, lastSum)
        XCTAssertEqual("false", lastString)


        a <- 13
        XCTAssertEqual(Float(13), a.pull())
        XCTAssertEqual(UInt(7), b.pull())
        XCTAssertEqual(20.0, lastSum)
        XCTAssertEqual("false", lastString)

        d <- true
        XCTAssertEqual(Float(13), a.pull())
        XCTAssertEqual(UInt(7), b.pull())
        XCTAssertEqual(20.0, lastSum)
        XCTAssertEqual("true", lastString)

        b <- 2
        XCTAssertEqual(15.0, lastSum)
        XCTAssertEqual("true", lastString)

        combo2.push(((1.5, 12), true)) // push a combination back
        XCTAssertEqual(Float(1.5), a.pull())
        XCTAssertEqual(UInt(12), b.pull())
        XCTAssertEqual(true, c.pull())

        XCTAssertEqual(13.5, lastSum)
        XCTAssertEqual("true", lastString)

        b <- 20
        XCTAssertEqual(21.5, lastSum)

        flattened.push(-1, 1, false) // push a flattened combo back
        XCTAssertEqual(Float(-1), a.pull())
        XCTAssertEqual(UInt(1), b.pull())
        XCTAssertEqual(false, c.pull())

        flattened.pull()
        flattened.pull()
    }


    func testDeepNestedFilter() {
        let t = <∞1.0∞>


        func identity<A>(a: A) -> A { return a }
        func always<A>(a: A) -> Bool { return true }

        let deepNest = t.funnelOf
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)


        // FilteredChannel<MappableChannel<....
        let flatNest = deepNest.funnelOf

        let deepOutlet = deepNest.attach({ _ in })

        XCTAssertEqual("ChannelZ.FilteredFunnel", _stdlib_getDemangledTypeName(deepNest))
        XCTAssertEqual("ChannelZ.FunnelOf", _stdlib_getDemangledTypeName(flatNest))
        XCTAssertEqual("ChannelZ.OutletOf", _stdlib_getDemangledTypeName(deepOutlet))
    }

    func testDeepNestedChannel() {
        let t = <∞1.0∞>

        func identity<A>(a: A) -> A { return a }
        func always<A>(a: A) -> Bool { return true }

        let deepNest = t
            .map(identity).filter(always)
            .map({"\($0)"}).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)
            .map(identity).filter(always)


        // FilteredChannel<MappableChannel<....
        let flatFunnel = deepNest.funnelOf
        let flatChannel = deepNest.channelOf

        let deepOutlet = deepNest.attach({ _ in })

        XCTAssertEqual("ChannelZ.FilteredChannel", _stdlib_getDemangledTypeName(deepNest))
        XCTAssertEqual("ChannelZ.FunnelOf", _stdlib_getDemangledTypeName(flatFunnel))
        XCTAssertEqual("ChannelZ.ChannelOf", _stdlib_getDemangledTypeName(flatChannel))
        XCTAssertEqual("ChannelZ.OutletOf", _stdlib_getDemangledTypeName(deepOutlet))
    }

    func testSimpleConduits() {
        let n1 = <∞Int(0)∞>

        let state = StatefulObject()
        let n2 = state.sieve(state.intField as NSNumber)

        let n3 = <∞Int(0)∞>

        // bindz((n1, identity), (n2, identity))
        // (n1, { $0 + 1 }) <~∞~> (n2, { $0.integerValue - 1 }) <~∞~> (n3, { $0 + 1 })

        let n1_n2 = (n1, { ($0 + 1) }) <|∞|> (n2, { ($0.integerValue - 1) })
        let n2_n3 = (n2, { .Some($0.integerValue - 1) }) <~∞~> (n3, { .Some($0 + 1) })

        n1 <- 2
        XCTAssertEqual(2, n1.pull())
        XCTAssertEqual(3, n2.pull() ?? -1)
        XCTAssertEqual(2, n3.pull())

        n2 <- 5
        XCTAssertEqual(4, n1.pull())
        XCTAssertEqual(5, n2.pull() ?? -1)
        XCTAssertEqual(4, n3.pull())

        n3 <- -1
        XCTAssertEqual(-1, n1.pull())
        XCTAssertEqual(0, n2.pull() ?? -1)
        XCTAssertEqual(-1, n3.pull())

        // TODO: fix bindings
//        // make sure disconnecting the binding actually disconnects is
//        n1_n2.disconnect()
//        n1 <- 20
//        XCTAssertEqual(20, n1.pull())
//        XCTAssertEqual(0, n2.pull() ?? -1)
//        XCTAssertEqual(-1, n3.pull())
    }

    func testTransformableConduits() {

        var num = <∞0∞>
        let state = StatefulObject()
        let strProxy = state.sieve(state.optionalStringField as String?)
        let dict = NSMutableDictionary()

        dict["stringKey"] = "foo"
        let dictProxy = dict.channel(dict["stringKey"], keyPath: "stringKey")

        // bind the number value to a string equivalent
//        num += { num in strProxy.value = "\(num)" }
//        strProxy += { str in num.value = Int((str as NSString).intValue) }

        let num_strProxy = (num, { "\($0)" }) <~∞~> (strProxy, { $0?.toInt() })

        // TODO: re-implement bindings
        let strProxy_dictProxy = (strProxy, { $0 }) <~∞~> (dictProxy, { $0.nextValue as? String? })

//        let binding = bindz((strProxy, identity), (dictProxy, identity))
//        let binding = (strProxy, identity) <~∞~> (dictProxy, identity)

//        let sval = reflect(str.optionalStringField).value
//        str.optionalStringField = nil
//        dump(reflect(str.optionalStringField).value)

        num <- 10
        XCTAssertEqual("10", state.optionalStringField ?? "<nil>")

        state.optionalStringField = "123"
        XCTAssertEqual(123, num.pull())
        
        num <- 456
        XCTAssertEqual("456", dict["stringKey"] as NSString? ?? "<nil>")

        dict["stringKey"] = "-98"
        XCTAssertEqual(-98, num.pull())

        // tests re-entrancy with inconsistent equivalencies
        dict["stringKey"] = "ABC"
        XCTAssertEqual(-98, num.pull())

        dict["stringKey"] = "66"
        XCTAssertEqual(66, num.pull())

        /* ###
        // nullifying should change the proxy
        dict.removeObjectForKey("stringKey")
        XCTAssertEqual(0, num.value)

        // no change from num's value, so don't change
        num <- 0
        XCTAssertEqual("", dict["stringKey"] as NSString? ?? "<nil>")

        num <- 1
        XCTAssertEqual("1", dict["stringKey"] as NSString? ?? "<nil>")

        num <- 0
        XCTAssertEqual("0", dict["stringKey"] as NSString? ?? "<nil>")
        */
    }

    func testEquivalenceConduits() {

        /// Test equivalence conduits
        let state = StatefulObject()


        var qn1 = <∞0∞>
//        let qn2 = (observee: state, keyPath: "intField", value: state.intField as NSNumber)===>
        let qn2 = state.sieve(state.intField as NSNumber)

        let qn1_qn2 = qn1 <!∞!> qn2

        qn1.push(qn1.pull() + 1)
        XCTAssertEqual(1, state.intField)

        qn1.push(qn1.pull() - 1)
        XCTAssertEqual(0, state.intField)

        qn1.push(qn1.pull() + 1)
        XCTAssertEqual(1, state.intField)

        state.intField += 10
        XCTAssertEqual(11, qn1.pull())

        qn1.push(qn1.pull() + 1)
        XCTAssertEqual(12, state.intField)

        var qs1 = <∞""∞>

        XCTAssertEqual("", qs1.pull())

        let qs2 = state.sieve(state.optionalStringField)

        // TODO: fix bindings
//        let qsb = qs1 <?∞?> qs2
//
//        qs1.value += "X"
//        XCTAssertEqual("X", state.optionalStringField ?? "<nil>")
//
//        qs1.value += "X"
//        XCTAssertEqual("XX", state.optionalStringField ?? "<nil>")
//
//        /// Test that disconnecting the binding actually removes the observers
//        qsb.disconnect()
//        qs1.value += "XYZ"
//        XCTAssertEqual("XX", state.optionalStringField ?? "<nil>")
    }

    func testOptionalToPrimitiveConduits() {
        /// Test equivalence bindings
        let state = StatefulObject()

        let obzn1 = state.sieve(state.numberField1)
        let obzn2 = state.sieve(state.numberField2)

        let obzn1_obzn2 = pipe(obzn1, obzn2)

        state.numberField2 = 44.56
        XCTAssert(state.numberField1 === state.numberField2, "change the other side")
        XCTAssertNotNil(state.numberField1)
        XCTAssertNotNil(state.numberField2)

        state.numberField1 = 1
        XCTAssert(state.numberField1 === state.numberField2, "change one side")
        XCTAssertNotNil(state.numberField1)
        XCTAssertNotNil(state.numberField2)

        state.numberField2 = 12.34567
        XCTAssert(state.numberField1 === state.numberField2, "change the other side")
        XCTAssertNotNil(state.numberField1)
        XCTAssertNotNil(state.numberField2)

        state.numberField1 = 2
        XCTAssert(state.numberField1 === state.numberField2, "change back the first side")
        XCTAssertNotNil(state.numberField1)
        XCTAssertNotNil(state.numberField2)



        state.numberField1 = nil
        XCTAssert(state.numberField1 === state.numberField2, "binding to nil")
        XCTAssertNil(state.numberField2)

        state.numberField1 = NSNumber(unsignedInt: arc4random())
        XCTAssert(state.numberField1 === state.numberField2, "binding to random")
        XCTAssertNotNil(state.numberField2)


        // binding optional numberField1 to non-optional numberField3
        let obzn3 = state.sieve(state.numberField3)

        let bind2 = (obzn3, { $0 as NSNumber? }) <~∞~> (obzn1, { $0 })

        state.numberField1 = 67823
        XCTAssert(state.numberField1 === state.numberField3)
        XCTAssertNotNil(state.numberField3)

        state.numberField1 = nil
        XCTAssertEqual(67823, state.numberField3)
        XCTAssertNotNil(state.numberField3, "non-optional field should not be nil")
        XCTAssertNil(state.numberField1)

        let obzd = state.sieve(state.doubleField)

        // FIXME: crash with the cast

//        let bind3 = obzn1 <?∞?> obzd
//
//        state.doubleField = 5
//        XCTAssertEqual(state.doubleField, state.numberField1?.doubleValue ?? -999)
//
//        state.numberField1 = nil
//        XCTAssertEqual(5, state.doubleField, "niling optional field should not alter bound non-optional field")
//
//        state.doubleField++
//        XCTAssertEqual(state.doubleField, state.numberField1?.doubleValue ?? -999)
//
//        state.numberField1 = 9.9
//        XCTAssertEqual(9.9, state.doubleField)
//
//        // ensure that assigning nil to the numberField1 doesn't clobber the doubleField
//        state.numberField1 = nil
//        XCTAssertEqual(9.9, state.doubleField)
//
//        state.doubleField = 9876
//        XCTAssertEqual(9876, state.numberField1?.doubleValue ?? -999)
//
//        state.numberField1 = 123
//        XCTAssertEqual(123, state.doubleField)
//
//        state.numberField2 = 456 // numberField2 <~=~> numberField1 <?=?> doubleField
//        XCTAssertEqual(456, state.doubleField)
    }

    func testLossyConduits() {
        let state = StatefulObject()

        let obzi = state.sieve(state.intField)

        let obzd = state.sieve(state.doubleField)

        let obzi_obzd = obzi <!∞!> obzd

        state.intField = 1
        XCTAssertEqual(1, state.intField)
        XCTAssertEqual(1.0, state.doubleField)

        state.doubleField++
        XCTAssertEqual(2, state.intField)
        XCTAssertEqual(2.0, state.doubleField)

        state.doubleField += 0.8
        XCTAssertEqual(2, state.intField)
        XCTAssertEqual(2.8, state.doubleField)

        state.intField--
        XCTAssertEqual(1, state.intField)
        XCTAssertEqual(1.0, state.doubleField)
    }

    func testHaltingConduits() {
        // create a binding from an int to a float; when the float is set to a round number, it changes the int, otherwise it halts
        typealias T1 = Float
        typealias T2 = Float
        var x = <∞T1(0)∞>
        var y = <∞T2(0)∞>

        let b1 = x <=∞~> (y, { $0 == round($0) ? Optional<T1>.Some(T1($0)) : Optional<T1>.None })

        x <- 2
        XCTAssertEqual(T1(2), x.pull())
        XCTAssertEqual(T2(2.0), y.pull())

        y <- 3
        XCTAssertEqual(T1(3), x.pull())
        XCTAssertEqual(T2(3.0), y.pull())

        y <- 9.9
        XCTAssertEqual(T1(3), x.pull())
        XCTAssertEqual(T2(9.9), y.pull())

        y <- 17
        XCTAssertEqual(T1(17), x.pull())
        XCTAssertEqual(T2(17.0), y.pull())

        x.push(x.pull() + 1)
        XCTAssertEqual(T1(18), x.pull())
        XCTAssertEqual(T2(18.0), y.pull())

        y.push(y.pull() + 0.5)
        XCTAssertEqual(T1(18), x.pull())
        XCTAssertEqual(T2(18.5), y.pull())
    }

    func testConversionConduits() {
        var num = <∞(Double(0.0))∞>
        num <- 0

        let decimalFormatter = NSNumberFormatter()
        decimalFormatter.numberStyle = .DecimalStyle

        let toDecimal: (Double)->(String?) = { decimalFormatter.stringFromNumber($0) }
        let fromDecimal: (String?)->(Double?) = { $0 == nil ? nil : decimalFormatter.numberFromString($0!)?.doubleValue }

        let state1 = StatefulObject()
        let state1s = state1.sieve(state1.optionalStringField)
        let b1 = (num, toDecimal) <~∞~> (state1s, fromDecimal)


        let percentFormatter = NSNumberFormatter()
        percentFormatter.numberStyle = .PercentStyle

        let toPercent: (Double)->(NSString?) = { percentFormatter.stringFromNumber($0) }
        let fromPercent: (NSString?)->(Double?) = { percentFormatter.numberFromString($0 ?? "XXX")?.doubleValue }

        let state2 = StatefulObject()
        let state2s = state2.sieve(state2.optionalNSStringField)
        let b2 = (num, toPercent) <~∞~> (state2s, fromPercent)


        let spellingFormatter = NSNumberFormatter()
        spellingFormatter.numberStyle = .SpellOutStyle

        let state3 = StatefulObject()
        let state3s = state3.sieve(state3.requiredStringField)

        let toSpelled: (Double)->(String?) = { spellingFormatter.stringFromNumber($0) as String? }
        let fromSpelled: (String)->(Double?) = { spellingFormatter.numberFromString($0)?.doubleValue }
        let b3 = (num, toSpelled) <~∞~> (state3s, fromSpelled)

        num.push(num.pull() + 1)
        XCTAssertEqual(1, num.pull())
        XCTAssertEqual("1", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("100%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("one", state3.requiredStringField)

        num.push(num.pull() + 1)
        XCTAssertEqual(2, num.pull())
        XCTAssertEqual("2", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("200%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("two", state3.requiredStringField)

        state1.optionalStringField = "3"
        XCTAssertEqual(3, num.pull())
        XCTAssertEqual("3", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("300%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("three", state3.requiredStringField)

        state2.optionalNSStringField = "400%"
        XCTAssertEqual(4, num.pull())
        XCTAssertEqual("4", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("400%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("four", state3.requiredStringField)

        state3.requiredStringField = "five"
        XCTAssertEqual(5, num.pull())
        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("500%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("five", state3.requiredStringField)

        state3.requiredStringField = "gibberish" // won't parse, so numbers should remain unchanged
        XCTAssertEqual(5, num.pull())
        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("500%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("gibberish", state3.requiredStringField)

        state2.optionalNSStringField = nil
        XCTAssertEqual(5, num.pull())
        XCTAssertEqual("5", state1.optionalStringField ?? "<nil>")
        XCTAssertNil(state2.optionalNSStringField)
        XCTAssertEqual("gibberish", state3.requiredStringField)

        num <- 5.4321
        XCTAssertEqual(5.4321, num.pull())
        XCTAssertEqual("5.432", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("543%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("five point four three two one", state3.requiredStringField)

        state2.optionalNSStringField = "18.3%"
        XCTAssertEqual(0.183, num.pull())
        XCTAssertEqual("0.183", state1.optionalStringField ?? "<nil>")
        XCTAssertEqual("18%", state2.optionalNSStringField ?? "<nil>")
        XCTAssertEqual("zero point one eight three", state3.requiredStringField)

    }

    func testOptionalFunnels() {
        let state = StatefulObject()

        #if DEBUG_CHANNELZ
        let startObserverCount = ChannelZKeyValueObserverCount
        #endif

        var requiredNSStringField: NSString = ""
        // TODO: funnel immediately gets deallocated unless we hold on to it
//        let a1a = state.funnel(state.requiredNSStringField, keyPath: "requiredNSStringField").attach({ requiredNSStringField = $0 })

        // FIXME: this seems to hold on to an extra allocation
        // let a1 = sieve(state.funnel(state.requiredNSStringField, keyPath: "requiredNSStringField"))

        let a1 = state.channel(state.requiredNSStringField)
        var a1a = a1.attach({ requiredNSStringField = $0 })

        #if DEBUG_CHANNELZ
        XCTAssertEqual(ChannelZKeyValueObserverCount, startObserverCount + 1, "observer should not have been cleaned up")
        #endif

        state.requiredNSStringField = "foo"
        XCTAssert(requiredNSStringField == "foo", "failed: \(requiredNSStringField)")

//        let preDetachCount = countElements(a1.outlets)
        a1a.detach()
//        let postDetachCount = countElements(a1.outlets)
//        XCTAssertEqual(postDetachCount, preDetachCount - 1, "detaching the outlet should have removed it from the outlet list")

        state.requiredNSStringField = "foo1"
        XCTAssertNotEqual(requiredNSStringField, "foo1", "detached funnel should not have fired")

        var optionalNSStringField: NSString?
        let a2 = state.sieve(state.optionalNSStringField)
        a2.attach({ optionalNSStringField = $0 })
        
        XCTAssert(optionalNSStringField == nil)

        state.optionalNSStringField = nil
        XCTAssertNil(optionalNSStringField)

        state.optionalNSStringField = "foo"
        XCTAssert(optionalNSStringField?.description == "foo", "failed: \(optionalNSStringField)")

        state.optionalNSStringField = nil
        XCTAssertNil(optionalNSStringField)
    }


    #if os(OSX)
    func testButtonCommand() {
        let button = NSButton()

        /// seems to be needed or else the button won't get clicked
        NSWindow().contentView!.addSubview(button)

        var clicks = 0 // track the number of clicks on the button

        XCTAssertEqual(clicks, 0)

        let cmd = button.funnelCommand()
        var outlet = cmd.attach({ _ in clicks += 1 })

        button.performClick(self); XCTAssertEqual(--clicks, 0)
        button.performClick(self); XCTAssertEqual(--clicks, 0)

        outlet.detach()

        button.performClick(self); XCTAssertEqual(clicks, 0)
        button.performClick(self); XCTAssertEqual(clicks, 0)


    }

    func testTextFieldProperties() {
        let textField = NSTextField()

        /// seems to be needed or else the button won't get clicked
        NSWindow().contentView!.addSubview(textField)

        var text = ""

        let textChannel = textField.sieve(textField.stringValue)
        var textOutlet = textChannel.attach({ text = $0 })

        var enabled = true
        let enabledChannel = textField.sieve(textField.enabled)
        var enabledOutlet = enabledChannel.attach({ enabled = $0 })

        textField.stringValue = "ABC"
        XCTAssertEqual("ABC", textField.stringValue)
        XCTAssertEqual("ABC", text)

        textChannel.value = "XYZ"
        XCTAssertEqual("XYZ", textField.stringValue)
        XCTAssertEqual("XYZ", text)

        textField.enabled = false
        XCTAssertEqual(false, textField.enabled)
        XCTAssertEqual(false, enabled)

        textField.enabled = true
        XCTAssertEqual(true, enabled)

        textOutlet.detach()

        textField.stringValue = "QRS"
        XCTAssertEqual("XYZ", text)

        enabledOutlet.detach()

        textField.enabled = false
        XCTAssertEqual(true, enabled)

    }

    #endif

    #if os(iOS)
    func testButtonCommand() {
        let button = UIButton()

        var taps = 0 // track the number of taps on the button

        XCTAssertEqual(taps, 0)

        let eventType: UIControlEvents = .TouchUpInside
        let cmd = button.funnelCommand(events: eventType)
        XCTAssertEqual(0, button.allTargets().count)

        // sadly, this only seems to work when the button is in a running UIApplication
        // let tap: ()->() = { button.sendActionsForControlEvents(.TouchUpInside) }

        // so we need to fake it by directly invoking the target's action
        let tap: ()->() = {
            let event = UIEvent()

            for target in button.allTargets().allObjects as [UIEventObserver] {
                // button.sendAction also doesn't work from a test case
                for action in button.actionsForTarget(target, forControlEvent: eventType) as [String] {
//                    button.sendAction(Selector(action), to: target, forEvent: event)
                    XCTAssertEqual("handleControlEvent:", action)
                    target.handleControlEvent(event)
                }
            }
        }

        let buttonTapsHappen = true // false && false // or else compiler warning about blocks never executing

        var outlet1 = cmd.attach({ _ in taps += 1 })
        XCTAssertEqual(1, button.allTargets().count)

        if buttonTapsHappen {
            tap(); taps -= 1; XCTAssertEqual(taps, 0)
            tap(); taps -= 1; XCTAssertEqual(taps, 0)
        }

        var outlet2 = cmd.attach({ _ in taps += 1 })
        XCTAssertEqual(2, button.allTargets().count)
        if buttonTapsHappen {
            tap(); taps -= 2; XCTAssertEqual(taps, 0)
            tap(); taps -= 2; XCTAssertEqual(taps, 0)
        }

        outlet1.detach()
        XCTAssertEqual(1, button.allTargets().count)
        if buttonTapsHappen {
            tap(); taps -= 1; XCTAssertEqual(taps, 0)
            tap(); taps -= 1; XCTAssertEqual(taps, 0)
        }

        outlet2.detach()
        XCTAssertEqual(0, button.allTargets().count)
        if buttonTapsHappen {
            tap(); taps -= 0; XCTAssertEqual(taps, 0)
            tap(); taps -= 0; XCTAssertEqual(taps, 0)
        }
    }

    func testTextFieldProperties() {
        let textField = UITextField()


        var text = ""
        let textOutlet = textField.sieve(textField.text).map( { $0 } ).attach({ text = $0 })

        var enabled = true
        let enabledOutlet = textField.channel(textField.enabled).attach({ enabled = $0 })


        textField.text = "ABC"
        XCTAssertEqual("ABC", textField.text)
        XCTAssertEqual("ABC", text)

        textField.enabled = false
        XCTAssertEqual(false, textField.enabled)
        XCTAssertEqual(false, enabled)

        textField.enabled = true
        XCTAssertEqual(true, enabled)

        textOutlet.detach()

        textField.text = "XYZ"
        XCTAssertEqual("ABC", text)
        
        enabledOutlet.detach()
        
        textField.enabled = false
        XCTAssertEqual(true, enabled)
        
    }

    #endif

    func testValueToReference() {
        let startCount = StatefulObjectCount
        let countObs: () -> (Int) = { StatefulObjectCount - startCount }

        var holder2: StatefulObjectHolder?
        autoreleasepool {
            XCTAssertEqual(0, countObs())
            let ob = StatefulObject()
            XCTAssertEqual(1, countObs())

            let holder1 = StatefulObjectHolder(ob: ob)
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
            var error: NSError?

            let attrName = NSAttributeDescription()
            attrName.name = "fullName"
            attrName.attributeType = .StringAttributeType
            attrName.defaultValue = "John Doe"
            attrName.optional = true

            let attrAge = NSAttributeDescription()
            attrAge.name = "age"
            attrAge.attributeType = .Integer16AttributeType
            attrAge.optional = false

            let personEntity = NSEntityDescription()
            personEntity.name = "Person"
            personEntity.properties = [attrName, attrAge]

            let model = NSManagedObjectModel()
            model.entities = [personEntity]

            let psc = NSPersistentStoreCoordinator(managedObjectModel: model)
            let store = psc.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)

            let ctx = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
            ctx.persistentStoreCoordinator = psc

            var saveCount = 0
            let saveCountOutlet = ctx.notificationFunnel(NSManagedObjectContextDidSaveNotification).attach { _ in saveCount = saveCount + 1 }



            var inserted = 0
            ctx.changedInsertedZ.attach { inserted = $0.count }

            var updated = 0
            ctx.changedUpdatedZ.attach { updated = $0.count }

            var deleted = 0
            ctx.changedDeletedZ.attach { deleted = $0.count }

            var refreshed = 0
            ctx.changedRefreshedZ.attach { refreshed = $0.count }

            var invalidated = 0
            ctx.chagedInvalidatedZ.attach { invalidated = $0.count }


            XCTAssertNil(error)

            let ob = NSManagedObject(entity: personEntity, insertIntoManagedObjectContext: ctx)
            ob.setValue("Bob Jones", forKey: "fullName")
            ob.setValue(65, forKey: "age")

            XCTAssertEqual(0, saveCount)

            ctx.save(&error)
            XCTAssertNil(error)
            XCTAssertEqual(1, saveCount)
            XCTAssertEqual(1, inserted)
            XCTAssertEqual(0, updated)
            XCTAssertEqual(0, deleted)

            ob.setValue("Frank Underwood", forKey: "fullName")

            ctx.save(&error)
            XCTAssertNil(error)
            XCTAssertEqual(2, saveCount)
            XCTAssertEqual(0, inserted)
            XCTAssertEqual(1, updated)
            XCTAssertEqual(0, deleted)

            ctx.deleteObject(ob)

            ctx.save(&error)
            XCTAssertNil(error)
            XCTAssertEqual(3, saveCount)
            XCTAssertEqual(0, inserted)
            XCTAssertEqual(0, updated)
            XCTAssertEqual(1, deleted)

            ctx.reset()
        }

        XCTAssertEqual(0, ChannelZKeyValueObserverCount, "KV observers were not cleaned up")
    }

    #if os(OSX) // bindings are only available on OSX
    public func testBindings() {
        let objc = NSObjectController(content: NSNumber(integer: 1))
        XCTAssertEqual(1, objc.content as? NSNumber ?? -999)

        let state1 = StatefulObject()
        state1.numberField3 = 0

        XCTAssertEqual(0, state1.numberField3)
        objc.bind("content", toObject: state1, withKeyPath: "numberField3", options: nil)
        XCTAssertEqual(0, state1.numberField3)

        objc.content = 2
        XCTAssertEqual(2, objc.content as? NSNumber ?? -999)

        state1.numberField3 = 3
        XCTAssertEqual(3, objc.content as? NSNumber ?? -999)
        XCTAssertEqual(3, state1.numberField3)


        let state2 = StatefulObject()
        state2.numberField3 = 0
        state2.bind("numberField3", toObject: state1, withKeyPath: "numberField3", options: nil)

        let state2sieve = state2.sieve(state2.numberField3, keyPath: "numberField3").attach { num in
            // println("changing number to: \(num)")
        }
        state1.numberField3 = 4

        XCTAssertEqual(4, objc.content as? NSNumber ?? -999)
        XCTAssertEqual(4, state1.numberField3)
        XCTAssertEqual(4, state2.numberField3)

        // need to manually unbind in order to release memory
        objc.unbind("content")
        state2.unbind("numberField3")
    }
    #endif


    public func testTargetAssociatedObserver() {
        let startCount = ChannelZKeyValueObserverCount
        autoreleasepool {
            let ob = StatefulObject()
            TargetAssociatedObserver(target: ob, keyPath: "optionalStringField", kvoptions: .New, callback: { _ in TargetAssociatedObserverChanges += 1 })

            XCTAssertEqual(1, ChannelZKeyValueObserverCount - startCount)

            XCTAssertEqual(0, TargetAssociatedObserverChanges)
            ob.optionalStringField = "abc"
            XCTAssertEqual(1, TargetAssociatedObserverChanges)
        }

        XCTAssertEqual(0, ChannelZKeyValueObserverCount - startCount)
    }

    public func testDetachedOutlet() {
        var outlet: Outlet?
        autoreleasepool {
            let state = StatefulObject()
            outlet = state.channel(state.requiredNSStringField).attach({ _ in })
            XCTAssertEqual(1, StatefulObjectCount)
        }

        XCTAssertEqual(0, StatefulObjectCount)
        outlet!.detach() // ensure that the outlet doesn't try to access a bad pointer
    }

    public func test1stFieldRemoval() {
        let startCount = ChannelZKeyValueObserverCount
        let startObCount = StatefulObjectCount
        autoreleasepool {
            var changes = 0
            let ob = StatefulObject()
            XCTAssertEqual(0, ob.intField)
            ob.sieve(ob.intField).attach { _ in changes += 1 }
            XCTAssertEqual(1, ChannelZKeyValueObserverCount - startCount)

            XCTAssertEqual(0, changes)
            ob.intField++
            XCTAssertEqual(1, changes)
        }

        XCTAssertEqual(0, ChannelZKeyValueObserverCount - startCount)
        XCTAssertEqual(0, StatefulObjectCount - startObCount)
    }

    public func testManyObservers() {
        for j in 1...10 {
            autoreleasepool {
                let op = NSBlockOperation { () -> Void in
                }

                // crash with many attachments
                for i in 1...10 {
                    let attachment = op.sieve(op.cancelled).attach { _ in }
                }
            }
        }
    }

    public func testFoundationExtensions() {
        var counter = 0

        let prog = NSProgress(totalUnitCount: 100)
        prog.sieve(prog.totalUnitCount).attach({ _ in counter += 1 })
        XCTAssertEqual(0, counter)
        prog.totalUnitCount = 200
        XCTAssertEqual(0, --counter)

        prog.sieve(prog.fractionCompleted).attach({ _ in counter += 1 })
        XCTAssertEqual(0, counter)
        prog.completedUnitCount++
        XCTAssertEqual(0, --counter)


        for (doCancel, doStart) in [(true, false), (false, true)] {
            let op = NSBlockOperation { () -> Void in }
//             let op = NSOperation()

            let cancelChannel = op.channel(op.cancelled)
//            cancelChannel.push(false) // “caught "NSUnknownKeyException", "[<NSBlockOperation 0x100159100> setValue:forUndefinedKey:]: this class is not key value coding-compliant for the key isCancelled."”

            var cancelled: Bool = false
            op.channel(op.cancelled).attach { cancelled = $0 }
            var asynchronous: Bool = false
            op.channel(op.asynchronous).attach { asynchronous = $0 }
            var executing: Bool = false

            op.channel(op.executing).attach { [unowned op] in
                executing = $0
                let str = ("executing=\(executing) op: \(op)")
            }

            op.channel(op.executing).map({ !$0 }).filter({ $0 }).attach { [unowned op] in
                let str = ("executing=\($0) op: \(op)")
            }

            var finished: Bool = false
            op.channel(op.finished).attach { finished = $0 }
            var ready: Bool = false
            op.channel(op.ready).attach { ready = $0 }


//            for i in 1...200 {
//                op.sieve(op.cancelled).attach { _ in }
//                op.sieve(op.executing).attach { _ in }
//                op.sieve(op.asynchronous).attach { _ in }
//                op.sieve(op.finished).attach { _ in }
//                op.sieve(op.ready).attach { _ in }
//            }

            flatten(op.channel(op.cancelled).combine(op.channel(op.asynchronous)).combine(op.channel(op.executing))).attach({
                let str = ("cancelled=\($0) asynchronous=\($1) executing=\($2)")
            })

            flatten(op.channel(op.cancelled).combine(op.channel(op.asynchronous)).combine(op.channel(op.ready))).attach({
                let str = ("cancelled=\($0) asynchronous=\($1) ready=\($2)")
            })

            flatten(op.channel(op.cancelled).combine(op.channel(op.asynchronous)).combine(op.channel(op.ready))).attach({
                let str = ("cancelled=\($0) asynchronous=\($1) ready=\($2)")
            })

            op.channel(op.cancelled).combine(op.channel(op.asynchronous)).combine(op.channel(op.executing)).combine(op.channel(op.finished)).combine(op.channel(op.ready)).attach({
                let str = ("combined: \($0)")
            })

            flatten(op.channel(op.cancelled).combine(op.channel(op.asynchronous)).combine(op.channel(op.executing)).combine(op.channel(op.finished)).combine(op.channel(op.ready))).attach({
                let str = ("cancelled=\($0) asynchronous=\($1) executing=\($2) finished=\($3) ready=\($4)")
            })

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

            XCTAssertEqual(doCancel, cancelled)
            XCTAssertEqual(false, asynchronous)
            XCTAssertEqual(false, executing)
            XCTAssertEqual(doStart, finished)
            XCTAssertEqual(true, ready)
        }
    }

    public func testAutoKVOIdentification() {
        var control = NSProgress(totalUnitCount: 100)
        var count = 0
        control.sieve(control.completedUnitCount).attach { _ in count += 1 }
        control.sieve(control.totalUnitCount).attach { _ in count += 1 }
        control.sieve(control.fractionCompleted).attach { _ in count += 1 }
        XCTAssertEqual(0, count)
        control.completedUnitCount++
        XCTAssertEqual(2, count)

        let state = StatefulObjectSubclass()
        state.channel(state.optionalStringField).attach { _ in count += 1 }
        state.channel(state.requiredStringField).attach { _ in count += 1 }
        state.channel(state.optionalNSStringField).attach { _ in count += 1 }
        state.channel(state.requiredNSStringField).attach { _ in count += 1 }
        state.channel(state.intField).attach { _ in count += 1 }
        state.channel(state.doubleField).attach { _ in count += 1 }
        state.channel(state.numberField1).attach { _ in count += 1 }
        state.channel(state.numberField2).attach { _ in count += 1 }
        state.channel(state.numberField3).attach { _ in count += 1 }
        state.channel(state.numberField3).attach { _ in count += 1 }
        state.channel(state.requiredObjectField).attach { _ in count += 1 }
        state.channel(state.optionaldObjectField).attach { _ in count += 1 }
    }

}


var TargetAssociatedObserverChanges = 0

public struct StatefulObjectHolder {
    let ob: StatefulObject
}


var StatefulObjectCount = 0

public class StatefulObject : NSObject {
    dynamic var optionalStringField: String?
    dynamic var requiredStringField: String = ""

    dynamic var optionalNSStringField: NSString?
    dynamic var requiredNSStringField: NSString = ""

    // “property cannot be marked as dynamic because its type cannot be represented in Objective-C”
    // dynamic var optionalIntField: Int?

    dynamic var intField: Int = 0
    dynamic var doubleField: Double = 0
    dynamic var numberField1: NSNumber?
    dynamic var numberField2: NSNumber?
    dynamic var numberField3: NSNumber = 9

    dynamic var requiredObjectField: NSObject = NSObject()
    dynamic var optionaldObjectField: StatefulObject? = nil

    public override init() {
        super.init()
        StatefulObjectCount++
    }

    deinit {
        StatefulObjectCount--
    }
}

public class StatefulObjectSubclass : StatefulObject {
}


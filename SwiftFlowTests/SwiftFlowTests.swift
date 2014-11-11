//
//  SwiftFlowTests.swift
//  SwiftFlowTests
//
//  Created by Marc Prud'hommeaux <mwp1@cornell.edu>
//  License: MIT (or whatever)
//

import XCTest
import SwiftFlow

#if os(OSX)
    import AppKit
#endif

#if os(iOS)
    import UIKit
#endif

public class SwiftFlowTests: XCTestCase {
    override public func tearDown() {
        super.tearDown()

        // ensure that all the bindings and observers are properly cleaned up
        #if DEBUG_SWIFTFLOW
        XCTAssertEqual(0, ConduitCount, "bindings were not cleaned up")
        XCTAssertEqual(0, SwiftFlowKeyValueObserverCount, "KV observers were not cleaned up")
        #endif
    }

    func testFunnels() {
        var observedBool = <|false|>
        var changeCount: Int = 0

        let ob1 = observedBool.attach { v in
            changeCount = changeCount + 1
        }

        XCTAssertEqual(0, changeCount)

        observedBool.value = true
        XCTAssertEqual(1, changeCount)

        observedBool.value = true
        XCTAssertEqual(1, changeCount)

        observedBool.value = false
        observedBool.value = false


        XCTAssertEqual(2, changeCount)

        // XCTAssertEqual(test, false)

        var stringFieldChanges: Int = 0
        var intFieldChanges: Int = 0
        var doubleFieldChanges: Int = 0

        let cob = StatefulObject()
        cob.optionalStringField = "sval1"

        #if DEBUG_SWIFTFLOW
        let startObserverCount = SwiftFlowKeyValueObserverCount
        #endif

        autoreleasepool {
            let intFieldObserver = cob.sieve(cob.intField, keyPath: "intField")
            let intFieldOutlet = intFieldObserver.attach { _ in intFieldChanges += 1 }

            #if DEBUG_SWIFTFLOW
            XCTAssertEqual(SwiftFlowKeyValueObserverCount, startObserverCount + 1)
            #endif

            var stringFieldObserver = cob.sieve(cob.optionalStringField, keyPath: "optionalStringField")
            let stringFieldOutlet = stringFieldObserver.attach { _ in stringFieldChanges += 1 }

            let doubleFieldObserver = cob.sieve(cob.doubleField, keyPath: "doubleField")

            let doubleFieldOutlet = doubleFieldObserver.attach { _ in doubleFieldChanges += 1 }

            XCTAssertEqual(0, stringFieldChanges)
            XCTAssertEqual("sval1", cob.optionalStringField!)

            cob.intField++
            XCTAssertEqual(1, intFieldChanges)

            cob.intField = cob.intField + 0
            XCTAssertEqual(1, intFieldChanges)

            cob.intField = cob.intField + 1 - 1
            XCTAssertEqual(1, intFieldChanges)

            cob.intField++
            XCTAssertEqual(2, intFieldChanges)

            cob.optionalStringField = cob.optionalStringField ?? "" + ""
            XCTAssertEqual(0, stringFieldChanges)

            cob.optionalStringField! += "x"
            XCTAssertEqual(1, stringFieldChanges)

            stringFieldObserver.push("y")
            XCTAssertEqual(2, stringFieldChanges)

            cob.optionalStringField = nil
            XCTAssertEqual(3, stringFieldChanges)

            cob.optionalStringField = ""
            XCTAssertEqual(4, stringFieldChanges)

            cob.optionalStringField = ""
            XCTAssertEqual(4, stringFieldChanges)

            cob.optionalStringField = "foo"
            XCTAssertEqual(5, stringFieldChanges)

            #if DEBUG_SWIFTFLOW
            XCTAssertEqual(SwiftFlowKeyValueObserverCount, startObserverCount + 3, "observers should still be around before cleanup")
            #endif
        }

        #if DEBUG_SWIFTFLOW
        XCTAssertEqual(SwiftFlowKeyValueObserverCount, startObserverCount, "observers should have been cleared after cleanup")
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

        a.push(a.value + "ZZ")
        XCTAssertEqual(5, strlen)
        XCTAssertEqual("XXXZZ", a.value)

        a.push(a.value + "A")
        XCTAssertEqual("XXXZZA", a.value)
        XCTAssertEqual(5, strlen, "even-numbered increment should have been filtered")

        a.push(a.value + "A")
        XCTAssertEqual("XXXZZAA", a.value)
        XCTAssertEqual(7, strlen)


        let x = sieveField(1).filter { $0 <= 10 }

        var changeCount: Double = 0
        var changeLog: String = ""

        // track the number of changes using two separate attachments
        x.attach { _ in changeCount += 0.5 }
        x.attach { _ in changeCount += 0.5 }

        let xfm = x.map( { String($0) })
        let xfma = xfm.attach { s in changeLog += (countElements(changeLog) > 0 ? ", " : "") + s } // create a string log of all the changes


        XCTAssertEqual(0, changeCount)
        XCTAssertNotEqual(5, x.value)

        x <- 5
        XCTAssertEqual(5, x.value)
        XCTAssertEqual(1, changeCount)


        x <- 5
        XCTAssertEqual(5, x.value)
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
        let t = <|1.0|>

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
        c.push(c.value + 1); XCTAssertEqual(0, --changes)
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
        var xs = StatefulObject()
        var c = xs.sieve(xs.requiredStringField, keyPath: "requiredStringField")

        var changes = 0
        let outlet = c.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        c.push(""); XCTAssertEqual(0, changes, "default to default should not change")
        c.push("A"); XCTAssertEqual(0, --changes, "default to A should change")
        c.push("A"); XCTAssertEqual(0, changes, "A to A should not change")
        c.push("B"); c.push("B"); XCTAssertEqual(0, --changes, "A to B should change once")
    }

    func testKeyValueSieveUnretainedOutlet() {
        var xs = StatefulObject()
        var c = xs.sieve(xs.requiredStringField, keyPath: "requiredStringField")

        var changes = 0
        c.attach { _ in changes += 1 } // note we do not assign it locally, so it should immediately get cleaned up

        XCTAssertEqual(0, changes)
        c.push(""); XCTAssertEqual(0, changes, "freed outlet should not be listening")
        c.push("A"); XCTAssertEqual(0, changes, "freed outlet should not be listening")
    }

    func testOptionalNSKeyValueSieve() {
        var xs = StatefulObject()
        var c = xs.sieve(xs.optionalNSStringField, keyPath: "optionalNSStringField")

        var changes = 0
        var outlet = c.attach { _ in changes += 1 }

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
        var xs = StatefulObject()
        var c = xs.sieve(xs.optionalStringField, keyPath: "optionalStringField")

        var changes = 0
        var outlet = c.attach { _ in changes += 1 }

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

    func testFieldChannelFunnel() {
        var xs: Int = 1
        var x = channelField(xs)
        var f: FunnelOf<Int> = x.funnelOf // read-only funnel of channel x

        var changes = 0
        var outlet = f.attach { _ in changes += 1 }

        XCTAssertEqual(0, changes)
        x.push(x.value + 1); XCTAssertEqual(0, --changes)
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
        x.push(!x.value); XCTAssertEqual(0, --changes)
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
        x.push(x.value + 1); XCTAssertEqual(0, --changes)
        x.push(2); XCTAssertEqual(0, changes)
        x.push(2); x.push(2); XCTAssertEqual(0, changes)
        x.push(9); x.push(9); XCTAssertEqual(0, --changes)

        fxa.detach()
        fya.detach()
        x.push(-1); XCTAssertEqual(0, changes)
    }

    func testHeterogeneousPipe() {
        var a = <|Double(1.0)|>
        var b = <|Double(1.0)|>

        let pipeline = pipe(a, b)

        a <- 2.0
        XCTAssertEqual(2.0, a.value)
        XCTAssertEqual(2.0, b.value)

        b <- 3.0
        XCTAssertEqual(3.0, a.value)
        XCTAssertEqual(3.0, b.value)
    }

    func testHomogeneousPipe() {
        var a = <|Double(1.0)|>
        var b = <|UInt(1)|>

        // “fatal error: floating point value can not be converted to UInt because it is less than UInt.min”
        var af = a.filter({ $0 >= 0 }).map({ UInt($0) })
        var bf = b.map({ Double($0) })
        let pipeline = pipe(af, bf)

        a <- 2.0
        XCTAssertEqual(2.0, a.value)
        XCTAssertEqual(UInt(2), b.value)

        b <- 3
        XCTAssertEqual(3.0, a.value)
        XCTAssertEqual(UInt(3), b.value)

        a <- 9.9
        XCTAssertEqual(9.9, a.value)
        XCTAssertEqual(UInt(9), b.value)

        a <- -5.0
        XCTAssertEqual(-5.0, a.value)
        XCTAssertEqual(UInt(9), b.value)

        a <- 8.1
        XCTAssertEqual(8.1, a.value)
        XCTAssertEqual(UInt(8), b.value)
    }

    func testUnstablePipe() {
        var a = <|1|>
        var b = <|2|>

        // this unstable pipe would never achieve equilibrium, and so relies on re-entrancy checks to halt the flow
        var af = a.map({ $0 + 1 })
        let pipeline = pipe(af, b)
//        let pipeline = af.pipe(b)

        a.value = 2
        XCTAssertEqual(2, a.value)
        XCTAssertEqual(3, b.value)

        b.push(10)
        XCTAssertEqual(10, a.value)
        XCTAssertEqual(10, b.value)

        a <- 99
        XCTAssertEqual(99, a.value)
        XCTAssertEqual(100, b.value)
    }


    func testCombination() {
        let a = <|Float(3.0)|>
        let b = <|UInt(7)|>
        let c = <|Bool(false)|>
        let d = c.map { "\($0)" }

        var lastSum = 0.0
        var lastString = ""

        var combo1 = a.combine(b)
        var combo2 = combo1.combine(d)

        let outlet = combo2.attach({ x in lastSum = Double(x.0.0) + Double(x.0.1); lastString = x.1 })

        return; // FIXME: combinations are broken due to the removal of the previous field; we need some way to force down a state signal

        a <- 12

        XCTAssertEqual(19.0, lastSum)
        XCTAssertEqual("false", lastString)


        a <- 13
        XCTAssertEqual(Float(13), a.value)
        XCTAssertEqual(UInt(7), b.value)
        XCTAssertEqual(20.0, lastSum)
        XCTAssertEqual("false", lastString)

        d <- true
        XCTAssertEqual(Float(13), a.value)
        XCTAssertEqual(UInt(7), b.value)
        XCTAssertEqual(20.0, lastSum)
        XCTAssertEqual("true", lastString)

        b <- 2
        XCTAssertEqual(15.0, lastSum)
        XCTAssertEqual("true", lastString)

        combo2.push(((1.5, 12), true)) // push a combination back
        XCTAssertEqual(Float(1.5), a.value)
        XCTAssertEqual(UInt(12), b.value)
        XCTAssertEqual(true, c.value)

        XCTAssertEqual(13.5, lastSum)
        XCTAssertEqual("true", lastString)

        b <- 20
        XCTAssertEqual(21.5, lastSum)
    }


    func testDeepNestedFilter() {
        let t = <|1.0|>


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

        XCTAssertEqual("SwiftFlow.FilteredFunnel", _stdlib_getDemangledTypeName(deepNest))
        XCTAssertEqual("SwiftFlow.FunnelOf", _stdlib_getDemangledTypeName(flatNest))
        XCTAssertEqual("SwiftFlow.OutletOf", _stdlib_getDemangledTypeName(deepOutlet))
    }

    func testDeepNestedChannel() {
        let t = <|1.0|>

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

        XCTAssertEqual("SwiftFlow.FilteredChannel", _stdlib_getDemangledTypeName(deepNest))
        XCTAssertEqual("SwiftFlow.FunnelOf", _stdlib_getDemangledTypeName(flatFunnel))
        XCTAssertEqual("SwiftFlow.ChannelOf", _stdlib_getDemangledTypeName(flatChannel))
        XCTAssertEqual("SwiftFlow.OutletOf", _stdlib_getDemangledTypeName(deepOutlet))
    }

    func testSimpleConduits() {


        let n1 = <|Int(0)|>

//        let n2 = FieldObzervable(0)
        let n2o = StatefulObject()
        let n2 = n2o.sieve(n2o.intField as NSNumber, keyPath: "intField")

        let n3 = <|Int(0)|>

        // bindz((n1, identity), (n2, identity))
        // (n1, { $0 + 1 }) <~|~> (n2, { $0.integerValue - 1 }) <~|~> (n3, { $0 + 1 })

        let n1_n2 = (n1, { ($0 + 1) }) <|||> (n2, { ($0.integerValue - 1) })
        let n2_n3 = (n2, { .Flow($0.integerValue - 1) }) <~|~> (n3, { .Flow($0 + 1) })

        n1 <- 2
        XCTAssertEqual(2, n1.value)
        XCTAssertEqual(3, n2.value ?? -1)
        XCTAssertEqual(2, n3.value)

        n2 <- 5
        XCTAssertEqual(4, n1.value)
        XCTAssertEqual(5, n2.value ?? -1)
        XCTAssertEqual(4, n3.value)

        n3 <- -1
        XCTAssertEqual(-1, n1.value)
        XCTAssertEqual(0, n2.value ?? -1)
        XCTAssertEqual(-1, n3.value)

        // TODO: fix bindings
//        // make sure disconnecting the binding actually disconnects is
//        n1_n2.disconnect()
//        n1 <- 20
//        XCTAssertEqual(20, n1.value)
//        XCTAssertEqual(0, n2.value ?? -1)
//        XCTAssertEqual(-1, n3.value)
    }

    func testTransformableConduits() {

        var num = <|0|>
        let str = StatefulObject()
        let strProxy = str.sieve(str.optionalStringField as NSString?, keyPath: "optionalStringField")
        let dict = NSMutableDictionary()

        dict["stringKey"] = "foo"
        let dictProxy = dict.sieve(dict["stringKey"] as? NSString, keyPath: "stringKey")

        // bind the number value to a string equivalent
//        num += { num in strProxy.value = "\(num)" }
//        strProxy += { str in num.value = Int((str as NSString).intValue) }

        let num_strProxy = (num, { .Flow("\($0)") }) <~|~> (strProxy, { if let i = $0 { return .Flow(Int(i.intValue)) } else { return .Halt } })

        // TODO: re-implement bindings
//         let strProxy_dictProxy = strProxy <!|!> dictProxy
//
////        let binding = bindz((strProxy, identity), (dictProxy, identity))
////        let binding = (strProxy, identity) <~|~> (dictProxy, identity)
//
////        let sval = reflect(str.optionalStringField).value
////        str.optionalStringField = nil
////        dump(reflect(str.optionalStringField).value)
//
//        num <- 10
//        XCTAssertEqual("10", str.optionalStringField ?? "<nil>")
//
//        str.optionalStringField = "123"
//        XCTAssertEqual(123, num.value)
//        
//        num <- 456
//        XCTAssertEqual("456", dict["stringKey"] as NSString? ?? "<nil>")
//
//        dict["stringKey"] = "-98"
//        XCTAssertEqual(-98, num.value)
//
//        // tests re-entrancy with inconsistent equivalencies
//        dict["stringKey"] = "ABC"
//        XCTAssertEqual(0, num.value)
//
//        dict["stringKey"] = "66"
//        XCTAssertEqual(66, num.value)

        /* ###
        // nullifying should change the proxy
        dict.removeObjectForKey("stringKey")
        XCTAssertEqual(0, num.value)

        // no change from num's value, so don't change
        num.value = 0
        XCTAssertEqual("", dict["stringKey"] as NSString? ?? "<nil>")

        num.value = 1
        XCTAssertEqual("1", dict["stringKey"] as NSString? ?? "<nil>")

        num.value = 0
        XCTAssertEqual("0", dict["stringKey"] as NSString? ?? "<nil>")
        */
    }

    func testEquivalenceConduits() {

        /// Test equivalence conduits
        let qob = StatefulObject()

        var qn1 = <|0|>
//        let qn2 = (observee: qob, keyPath: "intField", value: qob.intField as NSNumber)===>
        let qn2 = qob.sieve(qob.intField as NSNumber, keyPath: "intField")

        let qn1_qn2 = qn1 <!|!> qn2

        qn1.value++
        XCTAssertEqual(1, qob.intField)

        qn1.value--
        XCTAssertEqual(0, qob.intField)

        qn1.value += 1
        XCTAssertEqual(1, qob.intField)

        qob.intField += 10
        XCTAssertEqual(11, qn1.value)

        qn1.value++
        XCTAssertEqual(12, qob.intField)

        var qs1 = <|""|>

        XCTAssertEqual("", qs1.value)

        let qs2 = qob.sieve(qob.optionalStringField, keyPath: "optionalStringField")

        // TODO: fix bindings
//        let qsb = qs1 <?|?> qs2
//
//        qs1.value += "X"
//        XCTAssertEqual("X", qob.optionalStringField ?? "<nil>")
//
//        qs1.value += "X"
//        XCTAssertEqual("XX", qob.optionalStringField ?? "<nil>")
//
//        /// Test that disconnecting the binding actually removes the observers
//        qsb.disconnect()
//        qs1.value += "XYZ"
//        XCTAssertEqual("XX", qob.optionalStringField ?? "<nil>")
    }

    func testOptionalToPrimitiveConduits() {
        /// Test equivalence bindings
        let ob = StatefulObject()

        let obzn1 = ob.sieve(ob.numberField1, keyPath: "numberField1")
        let obzn2 = ob.sieve(ob.numberField2, keyPath: "numberField2")

        let obzn1_obzn2 = pipe(obzn1, obzn2)

        ob.numberField2 = 44.56
        XCTAssert(ob.numberField1 === ob.numberField2, "change the other side")
        XCTAssertNotNil(ob.numberField1)
        XCTAssertNotNil(ob.numberField2)

        ob.numberField1 = 1
        XCTAssert(ob.numberField1 === ob.numberField2, "change one side")
        XCTAssertNotNil(ob.numberField1)
        XCTAssertNotNil(ob.numberField2)

        ob.numberField2 = 12.34567
        XCTAssert(ob.numberField1 === ob.numberField2, "change the other side")
        XCTAssertNotNil(ob.numberField1)
        XCTAssertNotNil(ob.numberField2)

        ob.numberField1 = 2
        XCTAssert(ob.numberField1 === ob.numberField2, "change back the first side")
        XCTAssertNotNil(ob.numberField1)
        XCTAssertNotNil(ob.numberField2)

//        // TODO: re-implement bindings
//
//        ob.numberField1 = nil
//        XCTAssert(ob.numberField1 === ob.numberField2, "binding to nil")
//        XCTAssertNil(ob.numberField2)
//
//        ob.numberField1 = NSNumber(unsignedInt: arc4random())
//        XCTAssert(ob.numberField1 === ob.numberField2, "binding to random")
//        XCTAssertNotNil(ob.numberField2)
//
//
//        // binding optional numberField1 to non-optional numberField3
//        let obzn3 = ob.sieve(ob.numberField3, keyPath: "numberField3")
//
//        let bind2 = obzn3 <=|=> obzn1
//
//        ob.numberField1 = 67823
//        XCTAssert(ob.numberField1 === ob.numberField3)
//        XCTAssertNotNil(ob.numberField3)
//
//        ob.numberField1 = nil
//        XCTAssertEqual(67823, ob.numberField3)
//        XCTAssertNotNil(ob.numberField3, "non-optional field should not be nil")
//        XCTAssertNil(ob.numberField1)
//
//        let obzd = ob.sieve(keyPath: "doubleField", ob.doubleField)
//
//        let bind3 = obzn1 <?|?> obzd
//
//        ob.doubleField = 5
//        XCTAssertEqual(ob.doubleField, ob.numberField1?.doubleValue ?? -999)
//
//        ob.numberField1 = nil
//        XCTAssertEqual(5, ob.doubleField, "niling optional field should not alter bound non-optional field")
//
//        ob.doubleField++
//        XCTAssertEqual(ob.doubleField, ob.numberField1?.doubleValue ?? -999)
//
//        ob.numberField1 = 9.9
//        XCTAssertEqual(9.9, ob.doubleField)
//
//        // ensure that assigning nil to the numberField1 doesn't clobber the doubleField
//        ob.numberField1 = nil
//        XCTAssertEqual(9.9, ob.doubleField)
//
//        ob.doubleField = 9876
//        XCTAssertEqual(9876, ob.numberField1?.doubleValue ?? -999)
//
//        ob.numberField1 = 123
//        XCTAssertEqual(123, ob.doubleField)
//
//        ob.numberField2 = 456 // numberField2 <~=~> numberField1 <?=?> doubleField
//        XCTAssertEqual(456, ob.doubleField)
    }

//    func testLossyConduits() {
//        let ob = StatefulObject()
//
//        let obzi = ob.sieve(ob.intField, keyPath: "intField")
//
//        let obzd = ob.sieve(ob.doubleField, keyPath: "doubleField")
//
//        let obzi_obzd = obzi <=|=> obzd
//
//        ob.intField = 1
//        XCTAssertEqual(1, ob.intField)
//        XCTAssertEqual(1.0, ob.doubleField)
//
//        ob.doubleField++
//        XCTAssertEqual(2, ob.intField)
//        XCTAssertEqual(2.0, ob.doubleField)
//
//        ob.doubleField += 0.8
//        XCTAssertEqual(2, ob.intField)
//        XCTAssertEqual(2.8, ob.doubleField)
//
//        ob.intField--
//        XCTAssertEqual(1, ob.intField)
//        XCTAssertEqual(1.0, ob.doubleField)
//    }

    func testHaltingConduits() {
        // create a binding from an int to a float; when the float is set to a round number, it changes the int, otherwise it halts
        typealias T1 = Float
        typealias T2 = Float
        var x = <|T1(0)|>
        var y = <|T2(0)|>

//        let b1 = x <?|?> y
//        let b1 = (x, { .Flow(Float($0)) }) <~|~> (y, { $0 == round($0) ? .Flow(Float($0)) : .Halt })

//        let b1 = x <?|~> (y, { $0 == round($0) ? .Flow(Float($0)) : .Halt })
//        let b1 = (y, { $0 == round($0) ? .Flow(Float($0)) : .Halt }) <~|?> x
//        let b1 = x <!|~> (y, { $0 == round($0) ? .Flow(Float($0)) : .Halt })
        let b1 = x <=|~> (y, { $0 == round($0) ? FlowCheck<T1>.Flow(T1($0)) : FlowCheck<T1>.Halt })

        x.value = 2
        XCTAssertEqual(T1(2), x.value)
        XCTAssertEqual(T2(2.0), y.value)

        y.value = 3
        XCTAssertEqual(T1(3), x.value)
        XCTAssertEqual(T2(3.0), y.value)

        y.value = 9.9
        XCTAssertEqual(T1(3), x.value)
        XCTAssertEqual(T2(9.9), y.value)

        y.value = 17
        XCTAssertEqual(T1(17), x.value)
        XCTAssertEqual(T2(17.0), y.value)

        x.value++
        XCTAssertEqual(T1(18), x.value)
        XCTAssertEqual(T2(18.0), y.value)

        y.value += 0.5
        XCTAssertEqual(T1(18), x.value)
        XCTAssertEqual(T2(18.5), y.value)

    }

//    func testConversionConduits() {
//        var num = <|(Double(0.0))|>
//        num.value = 0
//
//        let decimalFormatter = NSNumberFormatter()
//        decimalFormatter.numberStyle = .DecimalStyle
//        let toDecimal: (NSNumber)->String? = decimalFormatter.stringFromNumber
//        let fromDecimal: (String)->NSNumber? = decimalFormatter.numberFromString
//
//        let ob1 = StatefulObject()
//        let ob1s = ob1.sieve(ob1.optionalStringField, keyPath: "optionalStringField")
//        // ob1s <?|?> num
//        let b1 = (num, { toDecimal($0) ?? "" }) <|||> (ob1s, { Double(fromDecimal($0 as NSString)?.intValue ?? 0) })
//        // let b1 = (num, { FlowCheck<String>.coerce(toDecimal($0 as Double) as String) }) <~|~> (ob1s, { FlowCheck<Double>.coerce(fromDecimal($0 as String) as Double) })
////        let b1a = ob1.funnel(ob1.optionalStringField, keyPath: "optionalStringField").unwrap
////            .map({ x in
////            let str: NSString = x
////            let num: NSNumber = decimalFormatter.numberFromString(str)
////            return num
////        })
//
//        let percentFormatter = NSNumberFormatter()
//        percentFormatter.numberStyle = .PercentStyle
//        let toPercent = percentFormatter.stringFromNumber
//        let fromPercent = percentFormatter.numberFromString
//
//        let ob2 = StatefulObject()
//        let ob2s = ob2.sieve(ob2.optionalNSStringField, keyPath: "optionalNSStringField")
//        // ob2s <?|?> num
//        let b2 = (num, { toPercent($0) ?? "" }) <|||> (ob2s, { Double(fromPercent($0!)?.intValue ?? 0) })
//
//
//        let spellingFormatter = NSNumberFormatter()
//        spellingFormatter.numberStyle = .SpellOutStyle
//        let toSpelled = spellingFormatter.stringFromNumber
//        let fromSpelled = spellingFormatter.numberFromString
//
//        let ob3 = StatefulObject()
//        let ob3s = ob3.sieve(ob3.requiredStringField, keyPath: "requiredStringField")
//        // ob3s <?|?> num
//        let b3 = (num, { toSpelled($0) ?? "" }) <|||> (ob3s, { Double(fromSpelled($0 as NSString)?.intValue ?? 0) })
//
//
//
//        num.value++
//        XCTAssertEqual(1, num.value)
//        XCTAssertEqual("1", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("100%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("one", ob3.requiredStringField)
//
//        num.value++
//        XCTAssertEqual(2, num.value)
//        XCTAssertEqual("2", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("200%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("two", ob3.requiredStringField)
//
//        ob1.optionalStringField = "3"
//        XCTAssertEqual(3, num.value)
//        XCTAssertEqual("3", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("300%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("three", ob3.requiredStringField)
//
//        ob2.optionalNSStringField = "400%"
//        XCTAssertEqual(4, num.value)
//        XCTAssertEqual("4", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("400%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("four", ob3.requiredStringField)
//
//        ob3.requiredStringField = "five"
//        XCTAssertEqual(5, num.value)
//        XCTAssertEqual("5", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("500%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("five", ob3.requiredStringField)
//
//        // TODO: handle one-sided optionals
//        ob3.requiredStringField = "gibberish" // won't parse, so numbers should remain unchanged
////        XCTAssertEqual(5, num.value)
////        XCTAssertEqual("5", ob1.optionalStringField ?? "<nil>")
////        XCTAssertEqual("500%", ob2.optionalNSStringField ?? "<nil>")
////        XCTAssertEqual("five", ob3.requiredStringField)
//
//
//        // TODO: cash from sending NSNull through bindings
////        ob2.optionalNSStringField = nil
////        XCTAssertEqual(5, num.value)
////        XCTAssertEqual("5", ob1.optionalStringField ?? "<nil>")
////        XCTAssertEqual("500%", ob2.optionalNSStringField ?? "<nil>")
////        XCTAssertEqual("five", ob3.requiredStringField)
//
//        num.value = 5.4321
//        // TODO: the number is getiing changes back from under us by the bindings
////        XCTAssertEqual(5.432, num.value)
//        XCTAssertEqual("5.432", ob1.optionalStringField ?? "<nil>")
//        XCTAssertEqual("543%", ob2.optionalNSStringField ?? "<nil>")
//        XCTAssertEqual("five point four three two one", ob3.requiredStringField)
//
//        ob3.optionalNSStringField = "18%"
//        // FIXME: not working at all!
////        XCTAssertEqual(0.183, num.value)
////        XCTAssertEqual("18.3", ob1.optionalStringField ?? "<nil>")
////        XCTAssertEqual("18.3%", ob2.optionalNSStringField ?? "<nil>")
////        XCTAssertEqual("Eighteen Point Threee", ob3.requiredStringField)
//
//    }

//    func testOptionalFunnels() {
//        let ob = StatefulObject()
//
//        #if DEBUG_SWIFTFLOW
//        let startObserverCount = SwiftFlowKeyValueObserverCount
//        #endif
//
//        var requiredNSStringField: NSString = ""
//        // TODO: funnel immediately gets deallocated unless we hold on to it
////        let a1a = ob.funnel(ob.requiredNSStringField, keyPath: "requiredNSStringField").attach({ requiredNSStringField = $0 })
//
//        // FIXME: this seems to hold on to an extra allocation
//        // let a1 = sieve(ob.funnel(ob.requiredNSStringField, keyPath: "requiredNSStringField"))
//
//        let a1 = ob.channel(ob.requiredNSStringField, keyPath: "requiredNSStringField")
//        var a1a = a1.attach({ requiredNSStringField = $0 })
//
//        #if DEBUG_SWIFTFLOW
//        XCTAssertEqual(SwiftFlowKeyValueObserverCount, startObserverCount + 1, "observer should not have been cleaned up")
//        #endif
//
//        ob.requiredNSStringField = "foo"
//        XCTAssert(requiredNSStringField == "foo", "failed: \(requiredNSStringField)")
//
////        let preDetachCount = countElements(a1.outlets)
//        a1a.detach()
////        let postDetachCount = countElements(a1.outlets)
////        XCTAssertEqual(postDetachCount, preDetachCount - 1, "detaching the outlet should have removed it from the outlet list")
//
//        ob.requiredNSStringField = "foo1"
//        XCTAssertNotEqual(requiredNSStringField, "foo1", "detached funnel should not have fired")
//
//        var optionalNSStringField: NSString?
//        let a2 = ob.channel(ob.optionalNSStringField, keyPath: "optionalNSStringField")
//        a2.attach({
//            var ob: NSObject? = $0
////            var cname = ob?.className
////            assert(ob == nil || (ob! is NSString), "bad object type: \(ob):\(cname)")
//            optionalNSStringField = $0
//        })
//        
//        XCTAssert(optionalNSStringField == nil)
//
//        ob.optionalNSStringField = nil
//        XCTAssertNil(optionalNSStringField)
//
//        ob.optionalNSStringField = "foo"
//        XCTAssert(optionalNSStringField?.description == "foo", "failed: \(optionalNSStringField)")
//
//        ob.optionalNSStringField = nil
//        XCTAssertNil(optionalNSStringField)
//    }


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
        if false {
            return // FIXME: if we don't hold on to textChannel then it gets cleaned up
        }

        let textChannel = textField.stringValueChannel.map( { $0 } )
        var textOutlet = textChannel.attach({ text = $0 })
//        let textOutlet = textField.stringValueChannel.attach({ text = $0 })

        var enabled = true
        let enabledChannel = textField.enabledChannel
        var enabledOutlet = enabledChannel.attach({ enabled = $0 })

        textField.stringValue = "ABC"
        XCTAssertEqual("ABC", textField.stringValue)
        XCTAssertEqual("ABC", text)

        textField.enabled = false
        XCTAssertEqual(false, textField.enabled)
        XCTAssertEqual(false, enabled)

        textField.enabled = true
        XCTAssertEqual(true, enabled)

        textOutlet.detach()

        textField.stringValue = "XYZ"
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
}

public struct StatefulObjectHolder {
    let ob: StatefulObject
}

var StatefulObjectCount = 0

public class StatefulObject : NSObject {
    dynamic var optionalStringField: String?
    dynamic var requiredStringField: String = ""

    dynamic var optionalNSStringField: NSString?
    dynamic var requiredNSStringField: NSString = ""

    // “property cannot be marked as dynamic because its type cannoy be represented in Objective-C”
    // dynamic var optionalIntField: Int?

    dynamic var intField: Int = 0
    dynamic var doubleField: Double = 0
    dynamic var numberField1: NSNumber?
    dynamic var numberField2: NSNumber?
    dynamic var numberField3: NSNumber = 9

    public override init() {
        super.init()
        StatefulObjectCount++
    }

    deinit {
        StatefulObjectCount--
    }
}


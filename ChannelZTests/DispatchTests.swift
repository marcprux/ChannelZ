//
//  DispatchTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 10/13/15.
//  Copyright © 2015 glimpse.io. All rights reserved.
//

import XCTest
import ChannelZ
import Dispatch

/// Creates an asynchronous trickle of events for the given generator
func trickleZ<G: GeneratorType>(fromx: G, _ interval: NSTimeInterval, queue: dispatch_queue_t = dispatch_get_main_queue()) -> Channel<G, G.Element> {
    var from = fromx
    var receivers = ReceiverQueue<G.Element>()
    let delay = Int64(interval * NSTimeInterval(NSEC_PER_SEC))
    func tick() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), queue) {
            if receivers.count > 0 { // i.e., they haven't all been cancelled
                if let next = from.next() {
                    receivers.receive(next)
                    tick()
                }
            }
        }
    }

    tick()
    return Channel(source: from) { rcvr in receivers.addReceipt(rcvr) }
}

@warn_unused_result public func channelZSinkSingleReceiver<T>(type: T.Type) -> Channel<AnyReceiver<T>, T> {
    var receive: T -> Void = { _ in }
    let sink = AnyReceiver<T>({ receive($0) })
    return Channel<AnyReceiver<T>, T>(source: sink) { receive = $0; return ReceiptOf(canceler: { _ in }) }
}

class DispatchTests : ChannelTestCase {

    func testThreadsafeReception() {
        let count = 999
        var values = Dictionary<Int, Int>()
        for i in 0..<count {
            values[i] = i
        }

        let channel = channelZSinkSingleReceiver(Int)

        channel.receive { i in
            values.removeValueForKey(i)
        }

        //        for i in values {
        dispatch_apply(count + 1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { i in
            channel.source.receive(i)
        }

        //        XCTAssertEqual(0, values.count) // FIXME
    }
    

    func testSyncReceive() {
        let count = 999
        var values = Set(0..<count)
        let queue = dispatch_queue_create(#function, DISPATCH_QUEUE_SERIAL)

        // FIXME: the receiverlist itself if not locked, so we can't use anything that uses the ReceiverQueue
        // not sure how to fix this without resoring to RevceiverQueue depending on dispatch
        let channel = channelZSinkSingleReceiver(Int)

        channel.sync(queue).receive { i in
            values.remove(i)
        }

//        for i in values {
        dispatch_apply(count + 1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { i in
            channel.source.receive(i)
        }

        XCTAssertEqual(0, values.count)
    }

    func testSyncSource() {
        let count = 999
        var values = Set(0..<count)
        let queue = dispatch_queue_create(#function, DISPATCH_QUEUE_SERIAL)
        let channel = channelZPropertyValue(0).syncSource(queue)

        channel.receive { i in
            values.remove(i)
        }

//        for i in values {
        dispatch_apply(count + 1, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) { i in
            channel.source.receive(i)
        }

        XCTAssertEqual(0, values.count)
        
    }

    func testTrickle() {
        var tricklets: [Int] = []
        let count = 10
        let channel = trickleZ((1...10).generate(), 0.001)
        weak var xpc = expectationWithDescription("testTrickle")
        channel.receive {
            tricklets += [$0]
            if tricklets.count >= count { xpc?.fulfill() }
        }

        waitForExpectationsWithTimeout(5, handler: { err in })
        XCTAssertEqual(count, tricklets.count)
    }

    func testTrickleZip() {
        var tricklets: [(Int, Int)] = []
        let count = 10
        let channel1 = trickleZ((1...50).generate(), 0.001)
        let channel2 = trickleZ((11...20).generate(), 0.005) // slower; channel1 will be buffered by zip()
        weak var xpc = expectationWithDescription("testTrickleZip")
        channel1.zip(channel2).receive {
            tricklets += [$0]
            if tricklets.count >= count { xpc?.fulfill() }
        }

        waitForExpectationsWithTimeout(5, handler: { err in })
        XCTAssertEqual(count, tricklets.count)
        
    }

    func XXXtestDispatchChannel() {
        let obv = channelZSink(Int)

        let xpc: XCTestExpectation = expectationWithDescription("queue delay")

        var count = 0
        _ = obv.filter({ $0 > 0 }).dispatch(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)).receive({ _ in
            XCTAssertFalse(NSThread.isMainThread())
            count += 1
            if count >= 3 {
                xpc.fulfill()
            }
        })

        let numz = -10...3
        for x in numz { obv.source.receive(x) }

//        XCTAssertNotEqual(3, count, "should have been a delay")
        waitForExpectationsWithTimeout(1, handler: { _ in })
        XCTAssertEqual(3, count)

    }

    func testDispatchSyncronize() {

        let channelCount = 10
        let fibcount = 25

        var fibs: [Int] = [] // the shared mutable data structure; this is why we need sync()

        // this is the queue we will use to synchronize access to fibs
        let lock = dispatch_queue_create("testDispatchSyncronize.synker", DISPATCH_QUEUE_SERIAL)

        func fib(num: Int) -> Int{
            if(num == 0){
                return 0;
            }
            if(num == 1){
                return 1;
            }
            return fib(num - 1) + fib(num - 2);
        }

        let opq = NSOperationQueue()
        for _ in 1...channelCount {
            let obv = channelZSink(Int)
            let rcpt = obv.map(fib).sync(lock).receive({ fibs += [$0] })
            var source: NSArray = Array(1...fibcount)

            opq.addOperationWithBlock({ () -> Void in
                source.enumerateObjectsWithOptions(NSEnumerationOptions.Concurrent, usingBlock: { (ob, index, stop) -> Void in
                    obv.source.receive(ob as! Int)
                })
            })
        }

        // we wouldn't need to sync() when we receive through a single source because ReceiptList is itself synchronized...
        // for op in ops { op() }

        // but when mutliple source are simultaneously accessing a single mutable structure, we need the sync phase
        opq.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(fibcount * channelCount, fibs.count)

        func dedupe<S: SequenceType, T: Equatable where T == S.Generator.Element>(seq: S) -> Array<T> {
            let reduced = seq.reduce(Array<T>()) { (array, item) in
                return array + (item == array.last ? [] : [item])
            }
            return reduced
        }

        let distinctAll = dedupe(fibs.sort())
        let distinct24 = Array(distinctAll[0..<24])

        XCTAssertEqual([1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025], distinct24)
    }

    func testDelay() {
        let channel = channelZSink(Void)

        weak var xpc = expectationWithDescription("testDebounce")

        let vcount = 4

        var pulses = 0
        let interval = 0.1
        _ = dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC)))
        _ = channel.dispatch(dispatch_get_main_queue(), delay: interval).receive { void in
            pulses += 1
            if pulses >= vcount { xpc?.fulfill() }
        }

        for _ in 1...vcount { channel.source.receive() }

        waitForExpectationsWithTimeout(5, handler: { err in })
        XCTAssertEqual(vcount, pulses) // make sure the pulse contained all the items
    }

//    func testThrottle() {
//        let channel = channelZSink(Void)
//
//        weak var xpc = expectationWithDescription("testDebounce")
//
//        var pulses = 0, items = 0
//        _ = 0.1
////        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC)))
////        let receiver2: Channel<AnyReceiver<(Bool)>, [(Bool)]> = channel.buffer(1)
////        let receiver3: Channel<SinkOf<(Bool)>, [(Bool)]> = channel.throttle(1)
////        let receiver: Channel<SinkOf<(Bool)>, [(Bool)]> = channel.debounce(1.0, queue: dispatch_get_main_queue())
//
//        let vcount = 4
//
//        let receiver = channel.throttle(1.0, queue: dispatch_get_main_queue()).receive { voids in
//            pulses += 1
//            items += voids.count
//            if items >= vcount { xpc?.fulfill() }
//        }
//        XCTAssertTrue(receiver.dynamicType == receiver.dynamicType, "avoid compiler warnings")
//
//        for _ in 1...vcount { channel.source.put() }
//
//        waitForExpectationsWithTimeout(5, handler: { err in })
//        XCTAssertEqual(1, pulses) // make sure the items were aggregated into a single pulse
//        XCTAssertEqual(vcount, items) // make sure the pulse contained all the items
//    }

    /// Disabled only because it fails on TravisCI
    func XXXtestDispatchFile() {
        weak var xpc = expectationWithDescription(#function)

        let file = #file
        var view = String.UnicodeScalarView()

        channelZFile(file, high: Int(arc4random_uniform(1024)) + 1).receive { event in
            switch event {
            case .opened:
                break
            case .data(let dat):
                var encoding = UTF8()
                encoding.decodeScalars(dat) { view.append($0) }
            case .error(let err):
                XCTFail(String(err))
                xpc?.fulfill()
            case .closed:
                xpc?.fulfill()
            }
        }
        waitForExpectationsWithTimeout(30, handler: { err in })

        let swstr = String(view)
        let nsstr = (try? NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding)) ?? "XXX"

        XCTAssertTrue(nsstr == swstr, "file contents did not match: \(swstr.utf16.count) vs. \(nsstr.length)")
    }

}

private extension UnicodeCodecType {
    /// Helper function to decode the sequence of scalars into a string
    private mutating func decodeScalars<S: SequenceType where S.Generator.Element == CodeUnit>(scalars: S, f: UnicodeScalar->Void) {
        var g = scalars.generate()
        while true {
            switch decode(&g) {
            case .Result(let us): f(us)
            case .EmptyInput: return
            case .Error: fatalError("decoding error")
            }
        }
    }
}

enum InputStreamError : ErrorType {
    case openError(POSIXError?, String)
}

func channelZFile(path: String, queue: dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), low: Int? = nil, high: Int? = nil, interval: UInt64? = nil, strict: Bool = false) -> Channel<dispatch_io_t, InputStreamEvent> {
    let receivers = ReceiverQueue<InputStreamEvent>()

    let dchan = path.withCString {
        dispatch_io_create_with_path(DISPATCH_IO_STREAM, $0, O_RDONLY, 0, queue) { error in
            // any open errors will also be sent through dispatch_io_read, so don't handle them here
            receivers.clear()
        }
    }

    if let low = low { dispatch_io_set_low_water(dchan, low) }
    if let high = high { dispatch_io_set_high_water(dchan, high) }
    if let interval = interval { dispatch_io_set_interval(dchan, interval, strict ? DISPATCH_IO_STRICT_INTERVAL : 0) }

    dispatch_io_read(dchan, 0, Int.max, queue) { (done, data, error) -> Void in
        if error != 0 {
            let perr = POSIXError(rawValue: error)
            let errs = String.fromCString(strerror(error)) ?? "Unknown Error"
            receivers.receive(InputStreamEvent.error(InputStreamError.openError(perr, errs)))
        } else if done == true {
            dispatch_io_close(dchan, 0)
            receivers.receive(.closed)
        } else if data != nil {
            dispatch_data_apply(data, { (region, offset, buffer, size) -> Bool in
                let ptr = UnsafePointer<UInt8>(buffer)
                let buf = UnsafeBufferPointer<UInt8>(start: ptr, count: size)
                receivers.receive(.data(Array(buf)))
                return true
            })
        }
    }

    return Channel<dispatch_io_t, InputStreamEvent>(source: dchan) { receiver in
        let index = receivers.addReceiver(receiver)
        return ReceiptOf(canceler: {
            receivers.removeReceptor(index)
            if receivers.count == 0 {
                dispatch_io_close(dchan, DISPATCH_IO_STOP)
            }
        })
    }
}

//func channelZSocket(aqueue: dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), rqueue: dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), low: Int? = nil, high: Int? = nil, interval: UInt64? = nil, strict: Bool = false) {
//
//    let nativeSocket = socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP)
//    var sin = sockaddr_in()
////    sin.sin_len = sizeof(sin)
////    sin.sin_family = AF_INET6
////    sin.sin_port = htons(port)
////    sin.sin_addr.s_addr= INADDR_ANY
//
////    let err = bind(nativeSocket, sin, sizeof(sin))
//
////    NSCAssert(0 <= err, @"")
//
//    let dchan = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(nativeSocket), 0, aqueue)
//
//    dispatch_source_set_event_handler(dchan) {
////        typedef union socketAddress {
////            struct sockaddr sa
////            struct sockaddr_in sin
////            struct sockaddr_in6 sin6
////        } socketAddressUnion
////
////        socketAddressUnion rsa // remote socket address
////        socklen_t len = sizeof(rsa)
//        var sa: UnsafeMutablePointer<sockaddr> = nil
//        var len: UnsafeMutablePointer<socklen_t> = nil
//        let native = accept(nativeSocket, sa, len)
//
////        if (native == -1) {
////            // Error. Ignore.
////            return nil
////        }
////
////        _remoteAddress = rsa
////        _channel = dispatch_io_create(DISPATCH_IO_STREAM, native, rqueue, ^(int error) {
////            NSLog(@"An error occured while listening on socket: %d", error)
////        })
////
////        //dispatch_io_set_high_water(_channel, 8 * 1024)
////        dispatch_io_set_low_water(_channel, 1)
////        dispatch_io_set_interval(_channel, NSEC_PER_MSEC * 10, DISPATCH_IO_STRICT_INTERVAL)
////        
////        socketAddressUnion lsa // remote socket address
////        socklen_t len = sizeof(rsa)
////        getsockname(native, &lsa.sa, &len)
////        _localAddress = lsa
////
////        dispatch_io_read(_channel, 0, SIZE_MAX, _isolation, ^(bool done, dispatch_data_t data, int error){
////            if (data != NULL) {
////                if (_data == NULL) {
////                    _data = data
////                } else {
////                    _data = dispatch_data_create_concat(_data, data)
////                }
////                [self processData]
////            }
////        })
//    }
//}
//
//
//extension ChannelType {
//
//}


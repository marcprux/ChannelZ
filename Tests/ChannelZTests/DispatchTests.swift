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
import Foundation

let NSEC_PER_SEC = 1000000000

/// Creates an asynchronous trickle of events for the given generator
func trickleZ<G: IteratorProtocol>(_ fromx: G, _ interval: TimeInterval, queue: DispatchQueue = DispatchQueue.main) -> Channel<G, G.Element> {
    var from = fromx
    var receivers = ReceiverQueue<G.Element>()
    let delay = Int64(interval * TimeInterval(NSEC_PER_SEC))
    func tick() {
        queue.asyncAfter(deadline: DispatchTime.now() + Double(delay) / Double(NSEC_PER_SEC)) {
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

public func channelZSinkSingleReceiver<T>(_ type: T.Type) -> Channel<AnyReceiver<T>, T> {
    var receive: (T) -> Void = { _ in }
    let sink = AnyReceiver<T>({ receive($0) })
    return Channel<AnyReceiver<T>, T>(source: sink) { receive = $0; return ReceiptOf(canceler: {  }) }
}

class DispatchTests : ChannelTestCase {
    public static var allTests = [
        ("testThreadsafeReception", testThreadsafeReception),
        ("testSyncReceive", testSyncReceive),
        ("testSyncSource", testSyncSource),
        ("testTrickle", testTrickle),
        ("testTrickleZip", testTrickleZip),
        ("testDispatchSyncronize", testDispatchSyncronize),
        ("testDelay", testDelay),
        ("testDispatchFile", testDispatchFile),
        ]

    func testThreadsafeReception() {
        let count = 999
        var values = Dictionary<Int, Int>()
        let dictq = DispatchQueue(label: "dictq")
        for i in 0..<count {
            values[i] = i
        }

        let channel = channelZSinkSingleReceiver(Int.self)

        channel.receive { i in
            dictq.sync {
                values.removeValue(forKey: i)
            }
        }

        //        for i in values {
        DispatchQueue.concurrentPerform(iterations: count + 1) { i in
            channel.source.receive(i)
        }

        //        XCTAssertEqual(0, values.count) // FIXME
    }
    

    func testSyncReceive() {
        let count = 999
        var values = Set(0..<count)
        let queue = DispatchQueue(label: #function, attributes: [])

        // FIXME: the receiverlist itself if not locked, so we can't use anything that uses the ReceiverQueue
        // not sure how to fix this without resoring to RevceiverQueue depending on dispatch
        let channel = channelZSinkSingleReceiver(Int.self)

        channel.sync(queue).receive { i in
            values.remove(i)
        }

//        for i in values {
        DispatchQueue.concurrentPerform(iterations: count + 1) { i in
            channel.source.receive(i)
        }

        XCTAssertEqual(0, values.count)
    }

    func testSyncSource() {
        let count = 999
        var values = Set(0..<count)
        let queue = DispatchQueue(label: #function, attributes: [])
        let channel = channelZPropertyValue(0).syncSource(queue)

        channel.receive { i in
            values.remove(i)
        }

//        for i in values {
        DispatchQueue.concurrentPerform(iterations: count + 1) { i in
            channel.source.receive(i)
        }

        XCTAssertEqual(0, values.count)
        
    }

    func testTrickle() {
        var tricklets: [Int] = []
        let count = 10
        let channel = trickleZ((1...10).makeIterator(), 0.001)
        weak var xpc = expectation(description: "testTrickle")
        channel.receive {
            tricklets += [$0]
            if tricklets.count >= count { xpc?.fulfill() }
        }

        waitForExpectations(timeout: 5, handler: { err in })
        XCTAssertEqual(count, tricklets.count)
    }

    func testTrickleZip() {
        var tricklets: [(Int, Int)] = []
        let count = 10
        let channel1 = trickleZ((1...50).makeIterator(), 0.001)
        let channel2 = trickleZ((11...20).makeIterator(), 0.005) // slower; channel1 will be buffered by zip()
        weak var xpc = expectation(description: "testTrickleZip")
        channel1.zip(channel2).receive {
            tricklets += [$0]
            if tricklets.count >= count { xpc?.fulfill() }
        }

        waitForExpectations(timeout: 5, handler: { err in })
        XCTAssertEqual(count, tricklets.count)
        
    }

//    func XXXtestDispatchChannel() {
//        let obv = channelZSink(Int.self)
//
//        let xpc: XCTestExpectation = expectation(description: "queue delay")
//
//        var count = 0
//        _ = obv.filter({ $0 > 0 }).dispatch(dispatch_get_global_queue(DispatchQoS.QoSClass.default, 0)).receive({ _ in
//            XCTAssertFalse(NSThread.isMainThread())
//            count += 1
//            if count >= 3 {
//                xpc.fulfill()
//            }
//        })
//
//        let numz = -10...3
//        for x in numz { obv.source.receive(x) }
//
////        XCTAssertNotEqual(3, count, "should have been a delay")
//        waitForExpectations(timeout: 1, handler: { _ in })
//        XCTAssertEqual(3, count)
//
//    }

    func testDispatchSyncronize() {
#if os(Linux)
        // "fatal error: _enumerateWithOptions(_:range:paramType:returnType:block:) is not yet implemented: file Foundation/NSIndexSet.swift, line 381"
        return
#endif
        let channelCount = 10
        let fibcount = 25

        var fibs: [Int] = [] // the shared mutable data structure; this is why we need sync()

        // this is the queue we will use to synchronize access to fibs
        let lock = DispatchQueue(label: "testDispatchSyncronize.synker", attributes: [])

        func fib(_ num: Int) -> Int{
            if(num == 0){
                return 0;
            }
            if(num == 1){
                return 1;
            }
            return fib(num - 1) + fib(num - 2);
        }

        let opq = OperationQueue()
        for _ in 1...channelCount {
            let obv = channelZSink(Int.self)
            let rcpt = obv.map(fib).sync(lock).receive({ fibs += [$0] })
            var source = NSArray(array: Array(1...fibcount))

            opq.addOperation({ () -> Void in
                source.enumerateObjects(options: NSEnumerationOptions.concurrent, using: { (ob, index, stop) -> Void in
                    obv.source.receive(ob as! Int)
                })
            })
        }

        // we wouldn't need to sync() when we receive through a single source because ReceiptList is itself synchronized...
        // for op in ops { op() }

        // but when mutliple source are simultaneously accessing a single mutable structure, we need the sync phase
        opq.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(fibcount * channelCount, fibs.count)

        func dedupe<S: Sequence, T: Equatable>(_ seq: S) -> Array<T> where T == S.Iterator.Element {
            let reduced = seq.reduce(Array<T>()) { (array, item) in
                return array + (item == array.last ? [] : [item])
            }
            return reduced
        }

        let distinctAll = dedupe(fibs.sorted())
        let distinct24 = Array(distinctAll[0..<24])

        XCTAssertEqual([1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025], distinct24)
    }

    func testDelay() {
        let channel = channelZSink(Void.self)

        weak var xpc = expectation(description: "testDebounce")

        let vcount = 4

        var pulses = 0
        let interval = 0.1
        _ = DispatchTime.now() + Double(Int64(interval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        _ = channel.dispatch(DispatchQueue.main, delay: interval).receive { void in
            pulses += 1
            if pulses >= vcount { xpc?.fulfill() }
        }

        for _ in 1...vcount { channel.source.receive(()) }

        waitForExpectations(timeout: 5, handler: { err in })
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

    func rnd(_ i: UInt32) -> UInt32 {
        #if os(Linux)
            srandom(UInt32(time(nil)))
            let rnd = UInt32(random() % Int(i))
        #else
            let rnd = arc4random_uniform(i)
        #endif
    
        return rnd
    }

    func testDispatchFile() {
        
        weak var xpc = expectation(description: #function)

        let file = #file
        var view = String.UnicodeScalarView()
            var encoding = UTF8()

        let high = Int(rnd(1024)) + 10
            // high=2 => decoding error
        channelZFile(file, high: high).receive { event in
            switch event {
            case .opened:
                break
            case .data(let dat):
                encoding.decodeScalars(dat) { view.append($0) }
            case .error(let err):
                XCTFail(String(describing: err))
                xpc?.fulfill()
            case .closed:
                xpc?.fulfill()
            }
        }
        waitForExpectations(timeout: 30, handler: { err in })

        let swstr = String(view)
        let nsstr = (try? NSString(contentsOfFile: file, encoding: String.Encoding.utf8.rawValue)) ?? "XXX"

        XCTAssertTrue(String(describing: nsstr) == swstr, "file contents did not match: \(swstr.utf16.count) vs. \(nsstr.length)")
    }
}

private extension UnicodeCodec {
    /// Helper function to decode the sequence of scalars into a string
    mutating func decodeScalars<S: Sequence>(_ scalars: S, f: (UnicodeScalar)->Void) where S.Iterator.Element == CodeUnit {
        var g = scalars.makeIterator()
        while true {
            switch decode(&g) {
            case .scalarValue(let us): f(us)
            case .emptyInput: return
            case .error: fatalError("decoding error")
            }
        }
    }
}

enum InputStreamError : Error {
    case openError(Int32, String)
}

func channelZFile(_ path: String, queue: DispatchQueue = DispatchQueue.global(qos: .default), low: Int? = nil, high: Int? = nil, interval: DispatchTimeInterval? = nil, strict: Bool = false) -> Channel<DispatchIO, InputStreamEvent> {
    let receivers = ReceiverQueue<InputStreamEvent>()

    let dchan = path.withCString {
        DispatchIO(type: DispatchIO.StreamType.stream, path: $0, oflag: O_RDONLY, mode: 0, queue: queue) { error in
            // any open errors will also be sent through dispatch_io_read, so don't handle them here
            receivers.clear()
        }
    }

    if let low = low { dchan?.setLimit(lowWater: low) }
    if let high = high { dchan?.setLimit(highWater: high) }

    if let interval = interval {
        if strict {
            dchan?.setInterval(interval: interval, flags: .strictInterval)
        } else {
            dchan?.setInterval(interval: interval)
        }
    }

    dchan?.read(offset: 0, length: Int.max, queue: queue) { (done, data, error) -> Void in
        if error != 0 {
            let errs = String(cString: strerror(error))
            receivers.receive(InputStreamEvent.error(InputStreamError.openError(error, errs)))
        } else if done == true {
            dchan?.close()
            receivers.receive(.closed)
        } else if data != nil {
            data?.enumerateBytes(block: { (buffer, offset, stop) in
                receivers.receive(.data(Array(buffer)))
            })
        }
    }

    return Channel<DispatchIO, InputStreamEvent>(source: dchan!) { receiver in
        let index = receivers.addReceiver(receiver)
        return ReceiptOf(canceler: {
            receivers.removeReceptor(index)
            if receivers.count == 0 {
                dchan?.close(flags: .stop)
            }
        })
    }
}

//func channelZSocket(aqueue: dispatch_queue_t = DispatchQueue.global(qos: .default), rqueue: dispatch_queue_t = DispatchQueue.global(qos: .default), low: Int? = nil, high: Int? = nil, interval: UInt64? = nil, strict: Bool = false) {
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


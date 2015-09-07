//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

public extension ChannelType {

    /// Adds a phase that aggregates all pulses into an array and only pulse the aggregated array once the
    /// specified timespan has passed without it receiving another item. In ReativeX parlance, this is known as `debounce`.
    ///
    /// :param: interval the number of seconds to wait the determine if the aggregation should be pulsed
    /// :queue: the queue on which to dispatch the pulses
    /// :bgq: the serial queue on which the perform event aggregation, defaulting to a shared global serial default queue
    public func throttle(interval: Double, queue: dispatch_queue_t, bgq: dispatch_queue_t = channelZSharedSyncQueue)->Channel<Source, [Element]> {
        var pending: Int64 = 0 // the number of outstanding dispatches
        return map({ x in OSAtomicIncrement64(&pending); return x }).dispatch(bgq, delay: interval).accumulate { _ in OSAtomicDecrement64(&pending) <= 0 }.dispatch(queue)
    }

    /// Adds a phase that coalesces all pulses into an array and only pulses the aggregated array once the
    /// specified timespan has passed
    ///
    /// :param: interval the number of seconds to wait the determine if the aggregation should be pulsed
    /// :queue: the queue on which to dispatch the pulses
    /// :bgq: the serial queue on which the perform event aggregation, defaulting to a shared global serial default queue
    public func coalesce(interval: Double, queue: dispatch_queue_t, bgq: dispatch_queue_t = channelZSharedSyncQueue)->Channel<Source, [Element]> {
        let future: (Int64)->dispatch_time_t = { dispatch_time(DISPATCH_TIME_NOW, $0) }
        let delay = Int64(interval * Double(NSEC_PER_SEC))
        var nextPulse = future(delay)

        return dispatch(bgq, delay: interval)
            .accumulate { _ in future(0) >= nextPulse ? { nextPulse = future(delay); return true }() : false }
            .dispatch(queue)
    }

    /// Adds a phase that emits just the last element that was received within the given interval
    ///
    /// :param: interval the number of seconds to wait the determine if the aggregation should be pulsed
    /// :queue: the queue on which to dispatch the pulses
    /// :bgq: the serial queue on which the perform event aggregation, defaulting to a shared global serial default queue
    public func sample(interval: Double, queue: dispatch_queue_t, bgq: dispatch_queue_t = channelZSharedSyncQueue)->Channel<Source, Element> {
        // TODO: dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)()
        return coalesce(interval, queue: queue, bgq: bgq).map({ $0.last }).filter({ $0 != nil }).map({ $0! })
    }
    
}

/// Channel extension that provides dispatch queue support for scheduling the delivery of events on specific queues
public extension ChannelType {

    /// Instructs the observable to emit its items on the specified `queue` with an optional `time` delay and write `barrier`
    public func dispatch(queue: dispatch_queue_t, delay: Double? = 0.0, barrier: Bool = false)->Channel<Source, Element> {
        return lift2 { receive in { event in
            let rcvr = { receive(event) }
             if let delay = delay {
                let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
                if time == DISPATCH_TIME_NOW { // optimize now to be async
                    if barrier {
                        dispatch_barrier_async(queue, rcvr)
                    } else {
                        dispatch_async(queue, rcvr)
                    }
                } else {
                    dispatch_after(time, queue, rcvr)
                }
            } else { // nil delay means execute synchronously
                if barrier {
                    dispatch_barrier_sync(queue, rcvr)
                } else {
                    dispatch_sync(queue, rcvr)
                }
            }
            }
        }
    }
    

    /// Instructs the observable to synchronize on the specified `lockQueue` when emitting items
    ///
    /// :param: lockQueue The GDC queue to synchronize on; if nil, a queue named "io.glimpse.Channel.sync" will be created and used
    public func sync(lockQueue: dispatch_queue_t = channelZSharedSyncQueue)->Channel<Source, Element> {
        return lift2 { receive in { event in dispatch_sync(lockQueue) { receive(event) } } }
    }
}


/// The shared global serial default queue for `throttle`, `coalesce`, and `sample` phases named "io.glimpse.Channel.sync"
public var channelZSharedSyncQueue: dispatch_queue_t {
    let queueAttrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0)
    let queue = dispatch_queue_create("io.glimpse.Channel.sync", queueAttrs)
    return queue
}

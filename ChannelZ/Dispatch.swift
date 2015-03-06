//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

/// Channel extension that provides dispatch queue support for scheduling the delivery of events on specific queues
public extension Channel {

    /// Instructs the observable to emit its items on the specified `queue` with an optional `time` delay and write `barrier`
    public func dispatch(queue: dispatch_queue_t, delay: Double? = 0.0, barrier: Bool = false)->Channel<S, T> {
        return lift { receive in { event in
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
    public func sync(_ lockQueue: dispatch_queue_t = channelZSharedSyncQueue)->Channel<S, T> {
        return lift { receive in { event in dispatch_sync(lockQueue) { receive(event) } } }
    }
}


/// The shared global serial default queue for `throttle`, `coalesce`, and `sample` phases named "io.glimpse.Channel.sync"
public var channelZSharedSyncQueue: dispatch_queue_t {
    let queueAttrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0)
    let queue = dispatch_queue_create("io.glimpse.Channel.sync", queueAttrs)
    return queue
}

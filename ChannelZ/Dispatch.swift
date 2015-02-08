//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

/// Channel extension that provides dispatch queue support for scheduling the delivery of events on specific queues
extension Channel {

    /// Instructs the observable to emit its items on the specified `queue` with an optional `time` delay and write `barrier`
    public func dispatch(queue: dispatch_queue_t, time: dispatch_time_t? = DISPATCH_TIME_NOW, barrier: Bool = false)->Channel<S, T> {
        return lift { receive in { event in
            let rcvr = { receive(event) }
             if let time = time {
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
    public func sync(_ lockQueue: dispatch_queue_t = dispatch_queue_create("io.glimpse.Channel.sync", DISPATCH_QUEUE_SERIAL))->Channel<S, T> {
        return lift { receive in { event in dispatch_sync(lockQueue) { receive(event) } } }
    }
}

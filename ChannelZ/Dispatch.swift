//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

/// Receiver extension that provides dispatch queue support for scheduling the delivery of events on specific queues
extension Receiver {

    /// Instructs the observable to emit its items on the specified `queue` with an optional `time` delay and write `barrier`
    public func dispatch(queue: dispatch_queue_t, time: dispatch_time_t? = DISPATCH_TIME_NOW, barrier: Bool = false)->Receiver<S, T> {
        return lift { emit in { event in
            let block = { emit(event) }
             if let time = time {
                if time == DISPATCH_TIME_NOW { // optimize now to be async
                    if barrier {
                        dispatch_barrier_async(queue, block)
                    } else {
                        dispatch_async(queue, block)
                    }
                } else {
                    dispatch_after(time, queue, block)
                }
            } else { // nil delay means execute synchronously
                if barrier {
                    dispatch_barrier_sync(queue, block)
                } else {
                    dispatch_sync(queue, block)
                }
            }
            }
        }
    }

    /// Instructs the observable to synchronize on the specified `lockQueue`
    public func sync(lockQueue: dispatch_queue_t = dispatch_queue_create("io.glimpse.Receiver.sync", DISPATCH_QUEUE_SERIAL))->Receiver<S, T> {
        return lift { emit in { event in dispatch_sync(lockQueue, { emit(event) }) } }
    }
}

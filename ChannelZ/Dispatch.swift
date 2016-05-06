//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

public extension StreamType {
    /// Instructs the observable to emit its items on the specified `queue` with an optional `time` delay and write `barrier`
    ///
    /// - Parameter queue: the queue on which to execute
    /// - Parameter delay: the amount of time to delay in seconds, or if nil (the default) execute synchronously
    /// - Parameter barrier: whether to dispatch with a barrier
    @warn_unused_result public func dispatch(queue: dispatch_queue_t, delay: Double? = 0.0, barrier: Bool = false) -> Self {
        return lifts { receive in { event in
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
    /// - Parameter lockQueue: The GDC queue to synchronize on; if nil, a queue named "io.glimpse.Channel.sync" 
    ///   will be created and used
    @warn_unused_result public func sync(lockQueue: dispatch_queue_t) -> Self {
        return lifts { receive in
            { event in
                dispatch_sync(lockQueue) {
                    receive(event)
                }
            }
        }
    }
}

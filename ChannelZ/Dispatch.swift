//
//  Dispatch.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Dispatch

/// Observable extension that provides dispatch queue support for scheduling the delivery of events on specific queues
extension Observable {

    /// Instructs the observable to emit elements on the specified `queue` with an optional `time` and `barrier`
    public func dispatch(queue: dispatch_queue_t, time: dispatch_time_t? = DISPATCH_TIME_NOW, barrier: Bool = false)->Observable<T> {
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
    
}

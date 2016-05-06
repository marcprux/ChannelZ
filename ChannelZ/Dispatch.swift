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
    /// - Parameter queue: The GDC queue to synchronize on
    @warn_unused_result public func sync(queue: dispatch_queue_t) -> Self {
        return lifts { receive in
            { event in
                dispatch_sync(queue) {
                    receive(event)
                }
            }
        }
    }
}

/// A source over a ReceiverType that synchonizes on a queue before receiving
public struct DispatchSource<S: ReceiverType> : ReceiverType {
    public let source: S
    public let queue: dispatch_queue_t

    public init(source: S, queue: dispatch_queue_t) {
        self.source = source
        self.queue = queue
    }

    public func receive(value: S.Pulse) {
        dispatch_sync(queue) {
            self.source.receive(value)
        }
    }
}

public extension ChannelType where Source : ReceiverType {

    /// Instructs the observable to synchronize on the specified `lockQueue` when emitting items as well
    /// as replacing the receiver source with a locked receiver source.
    ///
    /// - Parameter queue: The GDC queue to synchronize on
    @warn_unused_result public func syncSource(queue: dispatch_queue_t) -> Channel<DispatchSource<Source>, Pulse> {
        return resource({ DispatchSource(source: $0, queue: queue) })
    }
}

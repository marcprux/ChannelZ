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
    public func dispatch(_ queue: DispatchQueue, delay: Double? = 0.0, barrier: Bool = false) -> Self {
        return lifts { receive in { event in
            let rcvr = { receive(event) }
            if let delay = delay {
		let nsecPerSec = 1000000000
                let time = DispatchTime.now() + Double(Int64(delay * Double(nsecPerSec))) / Double(nsecPerSec)
                if time == DispatchTime.now() { // optimize now to be async
                    if barrier {
                        queue.async(flags: .barrier, execute: rcvr)
                    } else {
                        queue.async(execute: rcvr)
                    }
                } else {
                    queue.asyncAfter(deadline: time, execute: rcvr)
                }
            } else { // nil delay means execute synchronously
                if barrier {
                    queue.sync(flags: .barrier, execute: rcvr)
                } else {
                    queue.sync(execute: rcvr)
                }
            }
            }
        }
    }

    /// Instructs the observable to synchronize on the specified `lockQueue` when emitting items
    ///
    /// - Parameter queue: The GDC queue to synchronize on
    public func sync(_ queue: DispatchQueue) -> Self {
        return lifts { receive in
            { event in
                queue.sync {
                    receive(event)
                }
            }
        }
    }
}

/// A source over a ReceiverType that synchonizes on a queue before receiving
public struct DispatchSource<S: ReceiverType> : ReceiverType {
    public let source: S
    public let queue: DispatchQueue

    public init(source: S, queue: DispatchQueue) {
        self.source = source
        self.queue = queue
    }

    public func receive(_ value: S.Pulse) {
        queue.sync {
            self.source.receive(value)
        }
    }
}

public extension ChannelType where Source : ReceiverType {

    /// Instructs the observable to synchronize on the specified `lockQueue` when emitting items as well
    /// as replacing the receiver source with a locked receiver source.
    ///
    /// - Parameter queue: The GDC queue to synchronize on
    public func syncSource(_ queue: DispatchQueue) -> Channel<DispatchSource<Source>, Pulse> {
        return resource({ DispatchSource(source: $0, queue: queue) })
    }
}

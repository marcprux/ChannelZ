//
//  Network.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Foundation

public extension InputStream {

    /// Creates a Channel for the stream and assigns it to handle `NSStreamDelegate` delegate callbacks
    /// for stream events
    ///
    /// - Parameter bufferLength: The maximum size of the buffer that will be filled
    public func channelZStream(_ bufferLength: Int = 1024) -> Channel<ChannelStreamDelegate, InputStreamEvent> {
        precondition(bufferLength > 0, "buffer size must be greater than zero")
        let receivers = ReceiverQueue<InputStreamEvent>()

        let delegate = ChannelStreamDelegate(stream: self) { event in
            switch event.rawValue {
            case Stream.Event().rawValue:
                break
            case Stream.Event.openCompleted.rawValue:
                receivers.receive(.opened)
                break
            case Stream.Event.hasBytesAvailable.rawValue:
                var buffer = Array<UInt8>(repeating: 0, count: bufferLength)
                while true {
                    let readlen = self.read(&buffer, maxLength: bufferLength)
                    if readlen <= 0 {
                        break
                    } else {
                        let slice: ArraySlice<UInt8> = buffer[0..<readlen]
                        receivers.receive(.data(Array(slice)))
                    }
                }
                break
            case Stream.Event.hasSpaceAvailable.rawValue:
                break
            case Stream.Event.errorOccurred.rawValue:
                receivers.receive(.error(self.streamError ?? NSError(domain: "Network", code: 0, userInfo: [:])))
                break
            case Stream.Event.endEncountered.rawValue:
                receivers.receive(.closed)
                break
            default:
                break
            }
        }

        return Channel(source: delegate) { receiver in
            self.delegate = delegate
            let index = receivers.addReceiver(receiver)
            return ReceiptOf(canceler: {
                receivers.removeReceptor(index)
                if receivers.count == 0 {
                    self.delegate = nil
                }
            })
        }
    }

}

public enum InputStreamEvent {
    /// Event indicating that the stream opened the connection successfully
    case opened
    /// Event indicating that some data was received on the stream
    case data([UInt8])
    /// Event indicating that an errors occurred on the stream
    case error(Error)
    /// Event indicating that the stream was closed
    case closed
}

@objc open class ChannelStreamDelegate: NSObject, StreamDelegate {
    let stream: InputStream
    let handler: (Stream.Event)->Void

    init(stream: InputStream, handler: @escaping (Stream.Event)->Void) {
        self.stream = stream
        self.handler = handler
    }

    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        handler(eventCode)
    }
}


//
//  Network.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Foundation

public extension NSInputStream {

    /// Creates a Channel for the stream and assigns it to handle `NSStreamDelegate` delegate callbacks
    /// for stream events
    ///
    /// - Parameter bufferLength: The maximum size of the buffer that will be filled
    public func channelZStream(bufferLength: Int = 1024) -> Channel<ChannelStreamDelegate, InputStreamEvent> {
        precondition(bufferLength > 0, "buffer size must be greater than zero")
        let receivers = ReceiverList<InputStreamEvent>()

        let delegate = ChannelStreamDelegate(stream: self) { event in
            switch event.rawValue {
            case NSStreamEvent.None.rawValue:
                break
            case NSStreamEvent.OpenCompleted.rawValue:
                receivers.receive(.Opened)
                break
            case NSStreamEvent.HasBytesAvailable.rawValue:
                var buffer = Array<UInt8>(count: bufferLength, repeatedValue: 0)
                while true {
                    let readlen = self.read(&buffer, maxLength: bufferLength)
                    if readlen <= 0 {
                        break
                    } else {
                        let slice: ArraySlice<UInt8> = buffer[0..<readlen]
                        receivers.receive(.Data(Array(slice)))
                    }
                }
                break
            case NSStreamEvent.HasSpaceAvailable.rawValue:
                break
            case NSStreamEvent.ErrorOccurred.rawValue:
                receivers.receive(.Error(self.streamError ?? NSError(domain: "Network", code: 0, userInfo: [:])))
                break
            case NSStreamEvent.EndEncountered.rawValue:
                receivers.receive(.Closed)
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
    case Opened
    /// Event indicating that some data was received on the stream
    case Data([UInt8])
    /// Event indicating that an errors occurred on the stream
    case Error(ErrorType)
    /// Event indicating that the stream was closed
    case Closed
}

@objc public class ChannelStreamDelegate: NSObject, NSStreamDelegate {
    let stream: NSInputStream
    let handler: NSStreamEvent->Void

    init(stream: NSInputStream, handler: NSStreamEvent->Void) {
        self.stream = stream
        self.handler = handler
    }

    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        handler(eventCode)
    }
}


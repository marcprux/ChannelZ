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
    public func channel(bufferLength: Int = 1024) -> Channel<NSInputStream, InputStreamEvent> {
        var receivers = ReceiverList<InputStreamEvent>()

        let delegate = ChannelStreamDelegate { event in
            switch event.rawValue {
            case NSStreamEvent.None.rawValue:
                break
            case NSStreamEvent.OpenCompleted.rawValue:
                receivers.receive(.Opened)
                break
            case NSStreamEvent.HasBytesAvailable.rawValue:
                var buffer = UnsafeMutablePointer<UInt8>.alloc(bufferLength)
                while true {
                    let readlen = self.read(buffer, maxLength: bufferLength)
                    if readlen <= 0 {
                        buffer.destroy()
                        break
                    } else {
                        receivers.receive(.Data(NSData(bytes: buffer, length: readlen)))
                    }
                }
                break
            case NSStreamEvent.HasSpaceAvailable.rawValue:
                break
            case NSStreamEvent.ErrorOccurred.rawValue:
                receivers.receive(.Error(self.streamError ?? NSError()))
                break
            case NSStreamEvent.EndEncountered.rawValue:
                receivers.receive(.Closed)
                break
            default:
                break
            }
        }

        return Channel(source: self) { receiver in
            self.delegate = delegate
            let index = receivers.addReceiver(receiver)
            return ReceiptOf(requester: { }, canceller: {
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
    case Data(NSData)
    /// Event indicating that an errors occurred on the stream
    case Error(NSError)
    /// Event indicating that the stream was closed
    case Closed
}

@objc private class ChannelStreamDelegate: NSObject, NSStreamDelegate {
    let handler: NSStreamEvent->Void
    init(handler: NSStreamEvent->Void) { self.handler = handler }
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) { handler(eventCode) }
}


//
//  Network.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 2/2/15.
//  Copyright (c) 2015 glimpse.io. All rights reserved.
//

import Foundation

public extension NSInputStream {

    /// Creates a Receiver for the stream and assigns it to handle `NSStreamDelegate` delegate callbacks
    /// for stream events
    public func receive(bufferLength: Int = 1024) -> Receiver<NSInputStream, InputStreamEvent> {
        var subscriptions = ReceptorList<InputStreamEvent>()

        let delegate = ReceiverStreamDelegate { event in
            switch event.rawValue {
            case NSStreamEvent.None.rawValue:
                break
            case NSStreamEvent.OpenCompleted.rawValue:
                subscriptions.receive(.Opened)
                break
            case NSStreamEvent.HasBytesAvailable.rawValue:
                var buffer = UnsafeMutablePointer<UInt8>.alloc(bufferLength)
                while true {
                    let readlen = self.read(buffer, maxLength: bufferLength)
                    if readlen <= 0 {
                        buffer.destroy()
                        break
                    } else {
                        subscriptions.receive(.Data(NSData(bytes: buffer, length: readlen)))
                    }
                }
                break
            case NSStreamEvent.HasSpaceAvailable.rawValue:
                break
            case NSStreamEvent.ErrorOccurred.rawValue:
                subscriptions.receive(.Error(self.streamError ?? NSError()))
                break
            case NSStreamEvent.EndEncountered.rawValue:
                subscriptions.receive(.Closed)
                break
            default:
                break
            }
        }

        return Receiver(source: self) { sub in
            self.delegate = delegate
            let index = subscriptions.addReceptor(sub)
            return ReceiptOf(requester: { }, canceller: {
                subscriptions.removeReceptor(index)
                if subscriptions.count == 0 {
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

@objc private class ReceiverStreamDelegate: NSObject, NSStreamDelegate {
    let handler: NSStreamEvent->Void
    init(handler: NSStreamEvent->Void) { self.handler = handler }
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) { handler(eventCode) }
}


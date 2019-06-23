//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

#if canImport(CoreData)
import CoreData

/// Extension for observableing notications for various Core Data events
extension NSManagedObjectContext {
    fileprivate class func mobs4key(_ note: [AnyHashable: Any], keys: [String]) -> [NSManagedObject] {
        var mobs = [NSManagedObject]()
        for key in keys {
            if let set = note[key] as? NSSet {
                if let setobs = set.allObjects as? [NSManagedObject] {
                    mobs += setobs
                }
            }
        }
        return mobs
    }

    fileprivate func typeChangeChannel(_ noteType: NSNotification.Name, changeTypes: String...)->Channel<NotificationCenter, [NSManagedObject]> {
        return self.channelZNotification(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }
    }

    /// Channels notifications of inserted objects after the changes have been processed in the context
    public func channelZProcessedInserts()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSInsertedObjectsKey)
    }

    /// Channels notifications of updated objects after the changes have been processed in the context
    public func channelZProcessedUpdates()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSUpdatedObjectsKey)
    }

    /// Channels notifications of deleted objects after the changes have been processed in the context
    public func channelZProcessedDeletes()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSDeletedObjectsKey)
    }

    /// Channels notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
    public func channelZProcessedAlters()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Channels notifications of refreshed objects after the changes have been processed in the context
    public func channelZProcessedRefreshes()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSRefreshedObjectsKey)
    }

    /// Channels notifications of invalidated objects after the changes have been processed in the context
    public func channelZProcessedInvalidates()->Channel<NotificationCenter, [NSManagedObject]> {
        return typeChangeChannel(NSNotification.Name.NSManagedObjectContextObjectsDidChange, changeTypes: NSInvalidatedObjectsKey)
    }



//    /// Channels notifications of inserted objects before they are being saved in the context
//    public var savingInsertedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Channels notifications of updated objects before they are being saved in the context
//    public var savingUpdatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Channels notifications of deleted objects before they are being saved in the context
//    public var savingDeletedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of changed (updated/inserted/deleted) objects before they are being saved in the context
//    public var savingAlteredZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of refreshed objects before they are being saved in the context
//    public var savingRefreshedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Channels notifications of invalidated objects before they are being saved in the context
//    public var savingInvalidatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInvalidatedObjectsKey)
//    }
//
//
//
//    /// Channels notifications of inserted objects after they have been saved in the context
//    public var savedInsertedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Channels notifications of updated objects after they have been saved in the context
//    public var savedUpdatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Channels notifications of deleted objects after they have been saved in the context
//    public var savedDeletedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of changed (updated/inserted/deleted) objects after they have been saved in the context
//    public var savedAlteredZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of refreshed objects after they have been saved in the context
//    public var savedRefreshedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Channels notifications of invalidated objects after they have been saved in the context
//    public var savedInvalidatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInvalidatedObjectsKey)
//    }

}
#endif

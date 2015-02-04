////
////  ChannelZ+Foundation.swift
////  GlimpseCore
////
////  Created by Marc Prud'hommeaux <marc@glimpse.io>
////  License: MIT (or whatever)
////
//
//import CoreData
//
///// Extension for observableing notications for various Core Data events
//extension NSManagedObjectContext {
//    private class func mobs4key(note: [NSObject : AnyObject], keys: [NSString]) -> [NSManagedObject] {
//        var mobs = [NSManagedObject]()
//        for key in keys {
//            mobs += (note[key] as? NSSet)?.allObjects as? [NSManagedObject] ?? []
//        }
//        return mobs
//    }
//
//    private func typeChangeChannel(noteType: NSString, changeTypes: NSString...) -> Channel<[NSManagedObject]> {
//        return self.notifyz(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }.observable()
//    }
//
//    /// Channels notifications of inserted objects after the changes have been processed in the context
//    public var changedInsertedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Channels notifications of updated objects after the changes have been processed in the context
//    public var changedUpdatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Channels notifications of deleted objects after the changes have been processed in the context
//    public var changedDeletedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
//    public var changedAlteredZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Channels notifications of refreshed objects after the changes have been processed in the context
//    public var changedRefreshedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Channels notifications of invalidated objects after the changes have been processed in the context
//    public var chagedInvalidatedZ: Channel<[NSManagedObject]> {
//        return typeChangeChannel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInvalidatedObjectsKey)
//    }
//
//
//
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
//    
//}

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
//    private func typeChangeReceiver(noteType: NSString, changeTypes: NSString...) -> Receiver<[NSManagedObject]> {
//        return self.notifyz(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }.observable()
//    }
//
//    /// Receivers notifications of inserted objects after the changes have been processed in the context
//    public var changedInsertedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Receivers notifications of updated objects after the changes have been processed in the context
//    public var changedUpdatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Receivers notifications of deleted objects after the changes have been processed in the context
//    public var changedDeletedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
//    public var changedAlteredZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of refreshed objects after the changes have been processed in the context
//    public var changedRefreshedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Receivers notifications of invalidated objects after the changes have been processed in the context
//    public var chagedInvalidatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInvalidatedObjectsKey)
//    }
//
//
//
//    /// Receivers notifications of inserted objects before they are being saved in the context
//    public var savingInsertedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Receivers notifications of updated objects before they are being saved in the context
//    public var savingUpdatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Receivers notifications of deleted objects before they are being saved in the context
//    public var savingDeletedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of changed (updated/inserted/deleted) objects before they are being saved in the context
//    public var savingAlteredZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of refreshed objects before they are being saved in the context
//    public var savingRefreshedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Receivers notifications of invalidated objects before they are being saved in the context
//    public var savingInvalidatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextWillSaveNotification, changeTypes: NSInvalidatedObjectsKey)
//    }
//
//
//
//    /// Receivers notifications of inserted objects after they have been saved in the context
//    public var savedInsertedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey)
//    }
//
//    /// Receivers notifications of updated objects after they have been saved in the context
//    public var savedUpdatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSUpdatedObjectsKey)
//    }
//
//    /// Receivers notifications of deleted objects after they have been saved in the context
//    public var savedDeletedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of changed (updated/inserted/deleted) objects after they have been saved in the context
//    public var savedAlteredZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
//    }
//
//    /// Receivers notifications of refreshed objects after they have been saved in the context
//    public var savedRefreshedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSRefreshedObjectsKey)
//    }
//
//    /// Receivers notifications of invalidated objects after they have been saved in the context
//    public var savedInvalidatedZ: Receiver<[NSManagedObject]> {
//        return typeChangeReceiver(NSManagedObjectContextDidSaveNotification, changeTypes: NSInvalidatedObjectsKey)
//    }
//    
//}

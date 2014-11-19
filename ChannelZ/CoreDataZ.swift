//
//  CoreDataZ.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 11/13/14.
//  Copyright (c) 2014 glimpse.io. All rights reserved.
//

import CoreData

/// Extension for funneling notications for various Core Data events
extension NSManagedObjectContext {
    private class func mobs4key(note: [NSObject : AnyObject], keys: [NSString]) -> [NSManagedObject] {
        var mobs = [NSManagedObject]()
        for key in keys {
            mobs += (note[key] as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        }
        return mobs
    }

    private func typeChangeFunnel(noteType: NSString, changeTypes: NSString...) -> FunnelOf<[NSManagedObject]> {
        return self.notificationFunnel(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }.funnelOf
    }

    /// Funnels notifications of inserted objects after the changes have been processed in the context
    public var changedInsertedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Funnels notifications of updated objects after the changes have been processed in the context
    public var changedUpdatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Funnels notifications of deleted objects after the changes have been processed in the context
    public var changedDeletedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Funnels notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
    public var changedAlteredZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Funnels notifications of refreshed objects after the changes have been processed in the context
    public var changedRefreshedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Funnels notifications of invalidated objects after the changes have been processed in the context
    public var chagedInvalidatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Funnels notifications of inserted objects before they are being saved in the context
    public var savingInsertedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Funnels notifications of updated objects before they are being saved in the context
    public var savingUpdatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Funnels notifications of deleted objects before they are being saved in the context
    public var savingDeletedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Funnels notifications of changed (updated/inserted/deleted) objects before they are being saved in the context
    public var savingAlteredZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Funnels notifications of refreshed objects before they are being saved in the context
    public var savingRefreshedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Funnels notifications of invalidated objects before they are being saved in the context
    public var savingInvalidatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextWillSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Funnels notifications of inserted objects after they have been saved in the context
    public var savedInsertedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Funnels notifications of updated objects after they have been saved in the context
    public var savedUpdatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Funnels notifications of deleted objects after they have been saved in the context
    public var savedDeletedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Funnels notifications of changed (updated/inserted/deleted) objects after they have been saved in the context
    public var savedAlteredZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Funnels notifications of refreshed objects after they have been saved in the context
    public var savedRefreshedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Funnels notifications of invalidated objects after they have been saved in the context
    public var savedInvalidatedZ: FunnelOf<[NSManagedObject]> {
        return typeChangeFunnel(NSManagedObjectContextDidSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }
    
}

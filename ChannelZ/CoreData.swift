//
//  ChannelZ+Foundation.swift
//  GlimpseCore
//
//  Created by Marc Prud'hommeaux <marc@glimpse.io>
//  License: MIT (or whatever)
//

import CoreData

/// Extension for observableing notications for various Core Data events
extension NSManagedObjectContext {
    private class func mobs4key(note: [NSObject : AnyObject], keys: [NSString]) -> [NSManagedObject] {
        var mobs = [NSManagedObject]()
        for key in keys {
            mobs += (note[key] as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        }
        return mobs
    }

    private func typeChangeObservable(noteType: NSString, changeTypes: NSString...) -> Observable<[NSManagedObject]> {
        return self.notifyz(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }.observable()
    }

    /// Observables notifications of inserted objects after the changes have been processed in the context
    public var changedInsertedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects after the changes have been processed in the context
    public var changedUpdatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects after the changes have been processed in the context
    public var changedDeletedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
    public var changedAlteredZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects after the changes have been processed in the context
    public var changedRefreshedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects after the changes have been processed in the context
    public var chagedInvalidatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Observables notifications of inserted objects before they are being saved in the context
    public var savingInsertedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects before they are being saved in the context
    public var savingUpdatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects before they are being saved in the context
    public var savingDeletedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects before they are being saved in the context
    public var savingAlteredZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects before they are being saved in the context
    public var savingRefreshedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects before they are being saved in the context
    public var savingInvalidatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Observables notifications of inserted objects after they have been saved in the context
    public var savedInsertedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects after they have been saved in the context
    public var savedUpdatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects after they have been saved in the context
    public var savedDeletedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects after they have been saved in the context
    public var savedAlteredZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects after they have been saved in the context
    public var savedRefreshedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects after they have been saved in the context
    public var savedInvalidatedZ: Observable<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }
    
}

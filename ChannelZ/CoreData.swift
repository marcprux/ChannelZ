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

    private func typeChangeObservable(noteType: NSString, changeTypes: NSString...) -> ObservableOf<[NSManagedObject]> {
        return self.notifyz(noteType).map { NSManagedObjectContext.mobs4key($0, keys: changeTypes) }.observable()
    }

    /// Observables notifications of inserted objects after the changes have been processed in the context
    public var changedInsertedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects after the changes have been processed in the context
    public var changedUpdatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects after the changes have been processed in the context
    public var changedDeletedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects after the changes have been processed in the context
    public var changedAlteredZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects after the changes have been processed in the context
    public var changedRefreshedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects after the changes have been processed in the context
    public var chagedInvalidatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextObjectsDidChangeNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Observables notifications of inserted objects before they are being saved in the context
    public var savingInsertedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects before they are being saved in the context
    public var savingUpdatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects before they are being saved in the context
    public var savingDeletedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects before they are being saved in the context
    public var savingAlteredZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects before they are being saved in the context
    public var savingRefreshedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects before they are being saved in the context
    public var savingInvalidatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextWillSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }



    /// Observables notifications of inserted objects after they have been saved in the context
    public var savedInsertedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey)
    }

    /// Observables notifications of updated objects after they have been saved in the context
    public var savedUpdatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSUpdatedObjectsKey)
    }

    /// Observables notifications of deleted objects after they have been saved in the context
    public var savedDeletedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSDeletedObjectsKey)
    }

    /// Observables notifications of changed (updated/inserted/deleted) objects after they have been saved in the context
    public var savedAlteredZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey)
    }

    /// Observables notifications of refreshed objects after they have been saved in the context
    public var savedRefreshedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSRefreshedObjectsKey)
    }

    /// Observables notifications of invalidated objects after they have been saved in the context
    public var savedInvalidatedZ: ObservableOf<[NSManagedObject]> {
        return typeChangeObservable(NSManagedObjectContextDidSaveNotification, changeTypes: NSInvalidatedObjectsKey)
    }
    
}

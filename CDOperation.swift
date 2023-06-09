//
//  CDOperation.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2016-09-24.
//  Copyright © 2016 Patrick Miron. All rights reserved.
//

import Foundation
import CoreData

class CDOperation {
    class func countObjectsForEntity(managedObjectType : NSManagedObject.Type, moc : NSManagedObjectContext) -> Int? {
        let request = managedObjectType.fetchRequest()
        do
        {
            let count = try moc.count(for: request)
            return count
        } catch {
            print("\(#function) Error: \(error.localizedDescription)")
        }
        return nil
    }
    
    class func getObjectsFor(Entity : NSManagedObject.Type, moc : NSManagedObjectContext, filter : NSPredicate?, sort : [NSSortDescriptor]?) -> [AnyObject]? {
        let request = Entity.fetchRequest()
        request.predicate = filter
        request.sortDescriptors = sort
        do {
            return try request.execute()
        } catch {
            print("\(#function) FAILED to fetch objects for \(Entity) entity")
            return nil
        }
    }
    
    class func objectDeletionsIsValidFor(entity: NSManagedObject) -> Bool {
        do {
            try entity.validateForDelete()
            return true
        } catch {
            print("\(entity.description) cannot be deleted.")
            return false
        }
    }
    
    class func getNotSetObjectFor(entity: NSManagedObject.Type, moc: NSManagedObjectContext, withAttribute: String) ->NSManagedObject?
    {
        let predicate = NSPredicate(format: "%K == %@", withAttribute, "NotSet") //Make NotSet a structure in all of software
        let objects = CDOperation.getObjectsFor(Entity: entity, moc: moc, filter: predicate, sort: nil)
        if let object = objects?.first as? NSManagedObject {
            return object
        }
        return nil
    }
}

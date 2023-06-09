//
//  CoreDataHelper.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2016-09-20.
//  Copyright © 2016 Patrick Miron. All rights reserved.
//
/**
    Core Data Helper with singleton shared context from container.viewContext
    includes core data helper functions
 */

import Foundation
import CoreData
import UIKit
import CloudKit

private let _sharedCoreDataManager = CoreDataManager()

class CoreDataManager : NSObject {
    //MARK:- SETUP
    required override init() {
        super.init()
        self.setupCoreData()
    }
    //This function starts assigning the lazy variables in CDHelper and is called by the convenience
    // ovverided default initializer above.
    func setupCoreData() {
        _ = self.context
    }
    //MARK:- TO IMPLEMENT
    //MARK:- MIGRATION
    /* //To implement before app store publishing.
     if let _localStoreURL = self.localStoreURL {
        CDMigration.shared.migrateStoreIfNecessary(_localStoreURL, destinationModel : self.model)
     }
    See location 1996 in Learning CoreData For iOS with Swift book.
     */
    //MARK:- SHARED INSTANCE
    class var shared : CoreDataManager {
        return _sharedCoreDataManager
    }
    //MARK:- CONTEXT CONTAINERS
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "ElderSoft")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Failed to load the Core Data stack: \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    lazy var persistentContainerForCloudKit: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "ElderSoft")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Failed to load the Core Data stack: \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    //MARK: CONTEXT
    lazy var context : NSManagedObjectContext = {
        let _context = self.persistentContainer.viewContext
        _context.automaticallyMergesChangesFromParent = true
        return _context
    }()
    //MARK:- SAVING
    // to do whenever context is saved.
    //Call this function after each field changes. This increases traffic but minizes conflicts
    class func save(_ moc : NSManagedObjectContext) {
        if moc.hasChanges {
            
            let _ = SaveCoreDataManagedObectsThenSyncToCloudKitOperation(context: moc) { (result) in
                if let parentContext = moc.parent {
                    save(parentContext)
                }		
            }
        }
    }
    class func saveSharedContext() {
            save(shared.context)
    }
    //TO BE MOVED TO CORE DATA OPERATIONS
    func saveWithoutModifiyingCloudKitObjects(_ moc: NSManagedObjectContext) {
        moc.performAndWait {
            if moc.hasChanges {
                do {
                    try moc.save()
//                    print("SAVED context \(moc.description)")
                } catch {
                    //TODO: IMPLEMENT ERROR HANDLER FOR CORE DATA MANAGER
                    print("ERROR saving context \(moc.description) - \(error)")
                }
            } else {
//                print("SKIPPED saving context \(moc.description) because there are no changes")
            }
            if let parentContext = moc.parent {
                saveWithoutModifiyingCloudKitObjects(parentContext)
            }
        }
    }
    //TO BE MOVED TO CORE DATA OPERATIONS
    //MARK: Fetching Objects
    func fetchCloudKitManagedObject(ckRecord: CKRecord, context: NSManagedObjectContext) -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: ckRecord.recordType)
        fetchRequest.predicate = NSPredicate(format: "ckRecordName == %@", ckRecord.recordID.recordName )
        do {
            let results = try context.fetch(fetchRequest)
            if let result = results.first {
                return result
            }
        }
        catch {
            //TODO: IMPLEMENT ERROR HANDLER FOR CORE DATA MANAGER
            print("Unable to fetch CloudKitMangedObjects for recordType \(ckRecord.recordType)")
        }
        return nil
    }
//TO BE MOVED TO CORE DATA OPERATIONS
    func fetchCloudKitManagedObject(recordType: String, ckRecordID: CKRecord.ID, context: NSManagedObjectContext) -> NSManagedObject? {
        let predicate = NSPredicate(format: "ckRecordName == %@", ckRecordID.recordName )
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: recordType)
        fetchRequest.predicate = predicate
        var cloudKitManagedObject : NSManagedObject?
        do {
            let records = try context.fetch(fetchRequest)
            if let record = records.first as? NSManagedObject {
                cloudKitManagedObject = record
            }
        } catch {
            //TODO: IMPLEMENT ERROR HANDLER FOR CORE DATA MANAGER
            print("Unable to fetch CloudKitMangedObjects for recordType \(recordType)")
        }
        return cloudKitManagedObject
    }
}
    //MARK:- END OF FILE

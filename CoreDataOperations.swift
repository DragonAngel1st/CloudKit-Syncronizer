//
//  CoreDataOperations.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2018-07-06.
//  Copyright © 2018 Patrick Miron. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

private let _sharedCloudKitOperationQueue = CloudKitOperationsManager()

class CloudKitOperationsManager: NSObject {
    required override init() {
        super.init()
        self.setupQueue()
    }
    
    func setupQueue() {
        //Once CloudKitOperationsManager can be dealocated and save to disk (permanent record), create an sequence to retrieve those queue and continue processing the operations that was not completed
        internalQueue.name = "CloudKitOperationsManager.SharedQueue"
        internalQueue.qualityOfService = .userInitiated
        //internalQueue.maxConcurrentOperationCount = 1
    }
    class var shared: CloudKitOperationsManager {
        return _sharedCloudKitOperationQueue
    }
    
    public func add(operationGroup: GroupOperation) {
        internalQueue.isSuspended = true
        lastOperation?.addDependency(operationGroup.internalQueue.operations.first!)
        for operation in operationGroup.internalQueue.operations {
            self.internalQueue.addOperation(operation)
            lastOperation = operation
        }
        internalQueue.isSuspended = false
    }
    private var lastOperation: Operation?
    lazy var internalQueue = OperationQueue()
}



//MARK:- SAVE COREDATA MANAGEDOBJECTS THEN SYNC TO CLOUKIT - GROUP OPERATION
class SaveCoreDataManagedObectsThenSyncToCloudKitOperation: GroupOperation {
    // VARIABLES
    private var _context: NSManagedObjectContext
    private var _managedObjectsToSaveAndSyncToCloudKit: [NSManagedObject]?
    private var _ckRecordIDsDeleted: [CKRecord.ID]?
    private var _ckDatabase: CKDatabase?
    private var _successfullySaveCKRecords: [CKRecord]?
    private var _zoneID = UserSettings.shared.currentZoneID

    // Class Initiation
    init(context: NSManagedObjectContext, completionHandler: ((SuccessResult)->())?) {
        self._context = context
//        self._managedObjectsToSaveAndSyncToCloudKit = Array(Set( _context.updatedObjects.compactMap { ($0) } + _context.insertedObjects.compactMap { ($0) }))
//        self._ckRecordIDsDeleted = _context.deletedObjects.compactMap { $0.getCKRecord()?.recordID }
        self._ckDatabase = UserSettings.shared.currentUserDB

        super.init(completionHandler: completionHandler)
        self.name = "SaveCoreDataManagedObectsThenSyncToCloudKitGroupOperationGroup"
        let saveManagedObjectsOp = SaveManagedObjectsToCoreDataOperation(context: context, zoneID: _zoneID) { (result) in
            //CompletionHandler
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            if result == .succeeded {
//                DispatchQueue.main.async {
//                    print(self.operationsInProgress.debugDescription)
//                    print(":: SaveManagedObjectsToCoreDataOperation :: Succeeded")
//                }
            } else {
//                DispatchQueue.main.async {
//                    print(":: SaveManagedObjectsToCoreDataOperation :: Failed")
//                }
                self.cancel()  // CANCEL ALL OPERATIONS if result is anything but .succeeded
            }
        }
        self.add(operation: saveManagedObjectsOp)
        guard let zoneID = _zoneID else { return }
        let modifyCloudKitRecordsOp = ModifyCloudKitRecordsOperation(zoneID: zoneID, ckDatabase: _ckDatabase) { (result) in
            //CompletionHandler
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            if result == .succeeded {
//                DispatchQueue.main.async {
//                    print(":: ModifyCloudKitRecordsOperation :: Succeeded")
//                }
            } else {
//                DispatchQueue.main.async {
//                    print(":: ModifyCloudKitRecordsOperation :: Failed")
//                }
                self.cancel() // CANCEL ALL OPERATIONS if result is anything but .succeeded
            }

        }
        modifyCloudKitRecordsOp.addDependency(saveManagedObjectsOp)

        self.add(operation: modifyCloudKitRecordsOp)

        let updateCoreDataObjectsWithEncodedSystemsFieldsOp = SaveCKEncodedSystemFieldsFromCKRecordsOperation(context: context) { (result) in
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            switch result {
            case .failed :
                DispatchQueue.main.async {
                    print(":: SaveCKEncodedSystemFieldsFromCKRecordsOperation :: Failed")
                }
                self.cancel()  // CANCEL ALL OPERATIONS if result is anything but .succeeded
            case .succeeded, .completedWithNoChanges :
                DispatchQueue.main.async {
                    print(":: SaveCKEncodedSystemFieldsFromCKRecordsOperation :: Succeeded")
                }
                //self.result = result
                
            case .inProgress:
                DispatchQueue.main.async {
                    print(":: WTF :: THIS SHOULD NEVER HAPPEN ::: !!!!!!!!!!!!!!!!!!!")
                }
            }
        }
        updateCoreDataObjectsWithEncodedSystemsFieldsOp.addDependency(modifyCloudKitRecordsOp)
        self.add(operation: updateCoreDataObjectsWithEncodedSystemsFieldsOp)
        let pushToWebServerPublicDataOp = PushCloudKitManagedObjectChangesToWebServerOperation(context: context, webServerType: UserSettings.shared.webServerType) { (result) in
            if result == .failed {
                DispatchQueue.main.async {
                    print("The PushCloudKitManagedObjectChangesToWebServerOperation failed.")
                }
            } else {
                self.finishQueue()
            }
        }
        pushToWebServerPublicDataOp.addDependency(updateCoreDataObjectsWithEncodedSystemsFieldsOp)
        pushToWebServerPublicDataOp.addDependency(saveManagedObjectsOp)
        self.add(operation: pushToWebServerPublicDataOp)
        //self.internalQueue.isSuspended = false
        //main()
    }
    // Always include required init
    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }
}

protocol DeletedPublicManagedObjectsProvider {
    var publicWebSiteRecordsToBeDeleted: PublicWebSiteRecords? { get }
}

protocol DeletedCloudKitMangedObjectCKRecordIDsToBeDeletedProvider {
    var ckRecordIDsToBeDeleted: [CKRecord.ID]? { get }
}

protocol SavedManagedObjectsProvider {
    var managedObjectsToSaveAndSyncToCloudKit: [NSManagedObject]? { get }
}

extension SaveManagedObjectsToCoreDataOperation: SavedManagedObjectsProvider, DeletedCloudKitMangedObjectCKRecordIDsToBeDeletedProvider, DeletedPublicManagedObjectsProvider {
    var ckRecordIDsToBeDeleted: [CKRecord.ID]? { return _ckRecordIDsToBeDeleted }
    var managedObjectsToSaveAndSyncToCloudKit: [NSManagedObject]? { return _insertedOrModifiedManagedObjects }
    var publicWebSiteRecordsToBeDeleted: PublicWebSiteRecords? { return _publicWebSiteRecordsToBeDeleted }
}



//MARK:- SAVE MANAGED OBJECTS TO COREDATA - OPERATION
class SaveManagedObjectsToCoreDataOperation : OperationWithResult {
    // VARIABLES
    private let _context: NSManagedObjectContext
    private let _zoneID: CKRecordZone.ID?
    private var _insertedOrModifiedManagedObjects = [NSManagedObject]()
    private var _ckRecordIDsToBeDeleted: [CKRecord.ID]?
    private var _publicWebSiteRecordsToBeDeleted = PublicWebSiteRecords()
    // Class Initialization
    init(context: NSManagedObjectContext, zoneID: CKRecordZone.ID?, completionHandler: ((SuccessResult)->())?) {
        self._context = context
        self._zoneID = zoneID
        //Since there is no transformation to be done on deleted managed objects. Set the ckRecordIDsToDelete the current contexts objects.
        _ckRecordIDsToBeDeleted = _context.deletedObjects.compactMap { $0.getCKRecord()?.recordID }
        super.init(completionHandler: completionHandler)
        self.name = "SaveManagedObjectsToCoreDataOperation"

    }
    // Always include required init
    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }
    // Operation Main function
    override func main() {
        super.main()
//        DispatchQueue.main.async {
//            print("The function main() from SaveManagedObjectsToCoreDataOperation was called")
//            print()
//        }
        //Call main work to be done. Set self.result and self.complete() when work is completed successfully
        _context.performAndWait {
//            DispatchQueue.main.async {
//                print("SaveManagedObjectsToCoreDataOperation.context.performAndWait was called")
//                print()
//            }
            do {
                
                guard !self.isCancelled else {
                    self.result = .completedWithNoChanges
                    self.cancel()
                    return
                }
                for updatedObject in _context.updatedObjects {
                    updatedObject.modifiedOn = NSDate()
                    _insertedOrModifiedManagedObjects.append(updatedObject)
                }
                for managedObject in _context.insertedObjects {
                    guard !self.isCancelled else {
                        self.result = .completedWithNoChanges
                        self.cancel()
                        return
                    }
                    managedObject.modifiedOn = NSDate()
                    if managedObject.getCKRecord() == nil {
                       _ = managedObject.createCKRecord(zoneID: _zoneID!)
                    }
                    _insertedOrModifiedManagedObjects.append(managedObject)
                }
                for managedObject in _context.deletedObjects {
                    guard !self.isCancelled else {
                        self.result = .completedWithNoChanges
                        self.cancel()
                        return
                    }
                    if let publicManagedObject = managedObject as? WebsiteDataExtensionsForNSManagedObject, let ckRecordName = managedObject.ckRecordName {
                        if publicManagedObject.hasPublicAttributes == true {
                            _publicWebSiteRecordsToBeDeleted.append((ckRecordName, publicManagedObject.webServerSyncPageName))
                        }
                    }
                }
                try self._context.save()
            } catch {
//TOFIX: :: TO IMPLEMENT :: Error Handler for CoreDataManager here.
                //handle error with CoreDataMager error handler to be implemented
                print()
                print("TO BE IMPLEMENTED: CORE DATA MANAGER has detected an error trying to save data. ERROR: \(error.localizedDescription)")
                print()
                self.result = .failed
                self.cancel()
            }
        }
        guard !self.isCancelled else {
            self.result = .completedWithNoChanges
            self.cancel()
            return
        }
        self.result = .succeeded
        finishOperation()
    }
}
//MARK:- SAVE CKRECORDS TO COREDATA - OPERATION
class SaveCKRecordsToCoreDataOperation : OperationWithResult {
    // VARIABLES
    private let context: NSManagedObjectContext = CoreDataManager.shared.context
    private var _ckRecordsToSyncWithManagedObjects: [CKRecord]?
    private var _ckRecordIDsDeletedToDeletedManagedObjects: [(CKRecord.ID, String)]?
    private var _changeZoneTokensByZoneID: [(CKRecordZone.ID, CKServerChangeToken?)]?
    private var _changedDatabaseToken: CKServerChangeToken?
    private var _ckDatabase: CKDatabase!
    // Class Initialization
    init(ckRecordsWithChanges: [CKRecord]?, ckRecordIDsDeleted: [(CKRecord.ID, String)]?, completionHandler: ((SuccessResult)->())?) {
//        self._ckRecordsToSyncWithManagedObjects = ckRecordsWithChanges
//        self._ckRecordIDsDeletedToDeletedManagedObjects = ckRecordIDsDeleted
        super.init(completionHandler: completionHandler)
        self.name = "SaveCKRecordsToCoreDataOperation"
    }
    // Always include required init
    init(ckDatabase: CKDatabase, completionHandler: ((SuccessResult) -> ())?) {
        super.init(completionHandler: completionHandler)
        self._ckDatabase = ckDatabase
        self.name = "SaveCKRecordsToCoreDataOperation"
    }

    required init(completionHandler: ((SuccessResult) -> Void)?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    // Operation Main function
    override func main() {
        super.main()
        func modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: [CKRecord], context: NSManagedObjectContext) {
            for ckRecord in ckRecordsWithChanges {
                //MARK:TOFIX
                //  -- If CKAsset has changed is a LargeImage do not download it. Leave it on server. Will be retreived only if user clicks on thumbnail

                // modify existing CloudKitManagedObject or create new CloudKitManagedObject from ckRecord
                // call selfFunction with parentRecord
                let _managedObject = fetchCloudKitManagedObject(ckRecord: ckRecord, context: context) ?? createManagedObjectFrom(ckRecord: ckRecord, context: context)
                for key in ckRecord.allKeys() {
                    if let parentCKReference = ckRecord[key] as? CKRecord.Reference {
                        if let parentCKRecord = ckRecordsWithChanges.first(where: { $0.recordID == parentCKReference.recordID  }) {
                            var parentCloudKitManagedObject = fetchCloudKitManagedObject(ckRecord: parentCKRecord, context: context)
                            if parentCloudKitManagedObject == nil {
                                modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: [parentCKRecord], context: context)
                                parentCloudKitManagedObject = fetchCloudKitManagedObject(ckRecord: parentCKRecord, context: context)
                            }
                            _managedObject.setValue(parentCloudKitManagedObject, forKey: key)
                        }
                    } else if let ckAsset = ckRecord[key] as? CKAsset, let data = NSData(contentsOf: ckAsset.fileURL!) {
                        _managedObject.setValue(data, forKey: key)
                    } else {
                        //Record key is not a CKReference, just assign its value for key
                        _managedObject.setValue(ckRecord.value(forKey: key), forKey: key)
                    }
                }
                _managedObject.ckRecordName = ckRecord.recordID.recordName
                _managedObject.setCKRecordFrom(ckRecord)
            }
        }
        func deletedManagedObjectsFrom(ckRecordIDToCKRecordTypePairsDeleted: [(CKRecord.ID, String)], context: NSManagedObjectContext) {
            for (ckRecordID, recordType) in ckRecordIDToCKRecordTypePairsDeleted {
                if let objectToDelete = fetchManagedObject(recordType: recordType, ckRecordID: ckRecordID, context: context) {
                    context.delete(objectToDelete)
                }
            }
        }
        //Guard to cancel op if cancel was called from operation group
        guard isCancelled == false
            else {
                //self.result = .failed
                self.cancel()
                return
        }
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        backgroundContext.performAndWait {
            guard let dependencyChangedDatabaseTokenProvider = self.dependencies.filter({ $0 is ChangedDatabaseTokenProvider}).first as? ChangedDatabaseTokenProvider, let dependencyChangedZoneTokenProvider = self.dependencies.filter({ $0 is ChangedCKZoneTokenProvider}).first as? ChangedCKZoneTokenProvider else {
                self.result = .failed
                self.cancel()
                return
            }
            self._changedDatabaseToken = dependencyChangedDatabaseTokenProvider.changedDatabaseToken
            self._changeZoneTokensByZoneID = dependencyChangedZoneTokenProvider.changedCKZoneTokensByZoneID

            if let dependencyChangedCKRecordsProvider = self.dependencies.filter({ $0 is ChangedCKRecordsProvider}).first as? ChangedCKRecordsProvider {
                self._ckRecordsToSyncWithManagedObjects = dependencyChangedCKRecordsProvider.ckRecordsChanged
                self._ckRecordIDsDeletedToDeletedManagedObjects = dependencyChangedCKRecordsProvider.ckRecordIDToCKRecordTypePairsDeleted
                if let _ckRecordsWithChange = self._ckRecordsToSyncWithManagedObjects {
                    modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: _ckRecordsWithChange, context: backgroundContext)
                }
                if let _ckRecordIDsToDelete = self._ckRecordIDsDeletedToDeletedManagedObjects {
                    deletedManagedObjectsFrom(ckRecordIDToCKRecordTypePairsDeleted: _ckRecordIDsToDelete, context: backgroundContext)
                }
                do {
                    try backgroundContext.save()
                    self.context.performAndWait {
                        do {
                            try self.context.save()
                        } catch {
                            //TOFIX: Impletment CoreDataErrorHandler
                            print("ERROR saving context \(backgroundContext.description) - \(error)")
                            self.result = .failed
                            self.cancel()
                        }
                    }
                } catch {
                    print("ERROR saving context \(backgroundContext.description) - \(error)")
                    self.result = .failed
                    self.cancel()
                }
            } else {
                self.result = .failed
                self.cancel()
            }
        }
        saveChangedTokenFor(ckDatabase: self._ckDatabase, changedZoneTokensByID: self._changeZoneTokensByZoneID)
        saveChangeTokenFor(ckDatabase: self._ckDatabase, changeToken: self._changedDatabaseToken)
        self.result = .succeeded
        self.finishOperation()
    }
}

private func saveChangedTokenFor(ckDatabase: CKDatabase, changedZoneTokensByID : [(CKRecordZone.ID, CKServerChangeToken?)]?) {
    guard let changedZoneTokensByID = changedZoneTokensByID else { return }
    for (zoneID, token) in changedZoneTokensByID {
        guard let token = token else { return }
        //TOFIX: FOR FUTURE VERSION IF ADDING ZONE CHANGE THIS CODE
        if zoneID == UserSettings.shared.currentZoneID {
            switch ckDatabase.databaseScope {
            case .private:
                UserSettings.shared.localPrivateDatabaseZoneChangeToken = token
            case .shared:
                UserSettings.shared.localSharedDatabaseZoneChangeToken = token
            case .public:
                UserSettings.shared.localPublicDatabaseZoneChangeToken = token
            @unknown default:
                fatalError()
            }
        }
    }
}

private func saveChangeTokenFor(ckDatabase: CKDatabase, changeToken: CKServerChangeToken?) {
    switch ckDatabase.databaseScope {
    case .private:
        UserSettings.shared.localPrivateDatabaseChangeToken = changeToken
    case .shared:
        UserSettings.shared.localSharedDatabaseChangeToken = changeToken
    case .public:
        UserSettings.shared.localPublicDatabaseChangeToken = changeToken
    @unknown default:
        fatalError()
    }
}

// Make this class be a provider of sucessufuly updated CloudkitManagedObject
protocol SuccessfullySavedPublicManagedObjectsProvider {
    var publicManagedObjects: [WebsiteDataExtensionsForNSManagedObject]? { get }
}

extension SaveCKEncodedSystemFieldsFromCKRecordsOperation: SuccessfullySavedPublicManagedObjectsProvider {
    var publicManagedObjects: [WebsiteDataExtensionsForNSManagedObject]? { return _publicManagedObjects }
}

class SaveCKEncodedSystemFieldsFromCKRecordsOperation : OperationWithResult {
    // VARIABLES
    private var _context: NSManagedObjectContext
    private var _ckRecords: [CKRecord]?
    private var _publicManagedObjects = [WebsiteDataExtensionsForNSManagedObject]()
    // Class Initiation
    init(context: NSManagedObjectContext, completionHandler: ((SuccessResult)->())?) {
        self._context = context
        super.init(completionHandler: completionHandler)
        self.name = "SaveCKEncodedSystemFieldsFromCKRecordsOperation"
    }
    // Always include required init
    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    // Operation Main function
    override func main() {
        super.main()

        //Guard to cancel op if cancel was called from operation group
        guard isCancelled == false
            else {
                //self.result = .failed
                self.cancel()
                return
        }
        //Call main work to be done. Set self.result and self.complete() when work is completed successfully
        if let dependencySavedCKRecordsProvider = dependencies.filter({ $0 is SuccessfullySavedCKRecordsProvider}).first as? SuccessfullySavedCKRecordsProvider, _ckRecords == .none {
            _ckRecords = dependencySavedCKRecordsProvider.successfullySavedCKRecords
        }

        guard _ckRecords != nil else {
            //self.result = .failed
            self.cancel()
            return
        }
        for ckRecord in _ckRecords! {
            guard isCancelled == false else {
                //self.result = .failed
                self.cancel()
                return
            }
            if let cloudKitManagedObject = fetchCloudKitManagedObject(ckRecord: ckRecord, context: _context) {
                cloudKitManagedObject.setCKRecordFrom(ckRecord)
                if let publicRecord = cloudKitManagedObject as? WebsiteDataExtensionsForNSManagedObject {
                    _publicManagedObjects.append(publicRecord)
                }
            } else {
                self.result = .failed
                self.cancel()
            }
        }
        _context.performAndWait {
            saveContextWithoutSyncingCloudKitObjects(context: _context)
        }

        self.result = .succeeded
        self.finishOperation()
    }
}
//Helper Functions
private func fetchCloudKitManagedObject(ckRecord: CKRecord, context: NSManagedObjectContext) -> NSManagedObject? {
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: ckRecord.recordType)
    fetchRequest.predicate = NSPredicate(format: "ckRecordName == %@", ckRecord.recordID.recordName )
    do {
        let results = try context.fetch(fetchRequest)
        if let result = results.first {
            return result
        }
    } catch {
        //TOFIX: IMPLEMENT CoreDataErrorHandler here.
        // may have to rethrow an error here is not because an object was not returned.
        // investigate further
        //print("Unable to fetch CloudKitMangedObjects for recordType \(ckRecord.recordType)")
    }
    return nil
}
private func fetchManagedObject(recordType: String, ckRecordID: CKRecord.ID, context: NSManagedObjectContext) -> NSManagedObject? {
    let predicate = NSPredicate(format: "ckRecordName == %@", ckRecordID.recordName )
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: recordType)
    fetchRequest.predicate = predicate
    do {
        let records = try context.fetch(fetchRequest)
        if let record = records.first as? NSManagedObject {
            return record
        }
    } catch {
        //TOFIX: Implement CoreDataErrorHandler here
        print("Unable to fetch CloudKitMangedObjects for recordType \(recordType)")
    }
    return nil
}
private func fetchManagedObject(recordType: String, ckRecordName: String, context: NSManagedObjectContext) -> NSManagedObject? {
    let predicate = NSPredicate(format: "ckRecordName == %@", ckRecordName )
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: recordType)
    fetchRequest.predicate = predicate
    do {
        let records = try context.fetch(fetchRequest)
        if let record = records.first as? NSManagedObject {
            return record
        }
    } catch {
        print("Unable to fetch CloudKitMangedObjects for recordType \(recordType)")
    }
    return nil
}
private func saveContextWithoutSyncingCloudKitObjects(context moc: NSManagedObjectContext) {
    moc.performAndWait {
        if moc.hasChanges {
            do {
                try moc.save()
                //print("SAVED context \(moc.description)")
            } catch {
                //TOFIX: Implement CoreDataErrorHandler here
                print("ERROR saving context \(moc.description) - \(error)")
            }
        } else {
            print("SKIPPED saving context \(moc.description) because there are no changes")
        }
        if let parentContext = moc.parent {
            saveContextWithoutSyncingCloudKitObjects(context: parentContext)
        }
    }
}
private func createManagedObjectFrom(ckRecord: CKRecord, context: NSManagedObjectContext) -> NSManagedObject {
    let newCloudKitManagedObject = NSEntityDescription.insertNewObject(forEntityName: ckRecord.recordType, into: context)
    newCloudKitManagedObject.setCKRecordFrom(ckRecord)
    return newCloudKitManagedObject
}
//MARK:- MODIFY OR CREATE MANAGED OBJECTS OPERATION
class ModifyOrCreateManagedObjectsOperation : OperationWithResult {
    private var _ckRecordsWithChange: [CKRecord]?
    private var _ckRecordIDsToDelete: [(CKRecord.ID, String)]?
    private var _context: NSManagedObjectContext
    init(ckRecordsWithChanges: [CKRecord]?, ckRecordIDsToDelete: [(CKRecord.ID, String)]?, context: NSManagedObjectContext, completionHandler: ((SuccessResult)->())?) {
        self._ckRecordsWithChange = ckRecordsWithChanges
        self._ckRecordIDsToDelete = ckRecordIDsToDelete
        self._context = context
        super.init(completionHandler: completionHandler)
    }
    required init(completionHandler: ((SuccessResult) -> Void)?) {
        fatalError("init(completionHandler:) has not been implemented")
    }
    // Operation Main function
    override func main() {
        super.main()
        func modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: [CKRecord], context: NSManagedObjectContext) {
                for ckRecord in ckRecordsWithChanges {
                    guard isCancelled == false else {
                        //self.result = .failed
                        self.cancel()
                        return
                    }
                    // modify existing CloudKitManagedObject or create new CloudKitManagedObject from ckRecord
                    // call selfFunction with parentRecord

                    //TOFIX: Intercept all CKRecords that are CKAssets and verify if they are just stored online if not store them locally in a managedObject.
                    let _managedObject = fetchCloudKitManagedObject(ckRecord: ckRecord, context: context) ?? createManagedObjectFrom(ckRecord: ckRecord, context: context)
                    for key in ckRecord.allKeys() {
                        guard isCancelled == false else {
                            //self.result = .failed
                            self.cancel()
                            return
                        }
                        if let parentCKReference = ckRecord[key] as? CKRecord.Reference {
                            if let parentCKRecord = ckRecordsWithChanges.first(where: { $0.recordID == parentCKReference.recordID  }) {
                                var parentCloudKitManagedObject = fetchCloudKitManagedObject(ckRecord: parentCKRecord, context: context)
                                if parentCloudKitManagedObject == nil {
                                    modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: [parentCKRecord], context: context)
                                    parentCloudKitManagedObject = fetchCloudKitManagedObject(ckRecord: parentCKRecord, context: context)
                                }
                                _managedObject.setValue(parentCloudKitManagedObject, forKey: key)
                            }
                        } else {
                            //Record key is not a CKReference, just assign its value for key
                            _managedObject.setValue(ckRecord.value(forKey: key), forKey: key)
                        }
                    }
                    _managedObject.ckRecordName = ckRecord.recordID.recordName
                    _managedObject.setCKRecordFrom(ckRecord)
                }
        }
        func deletedManagedObjectsFrom(ckRecordIDToCKRecordTypePairsDeleted: [(CKRecord.ID, String)], context: NSManagedObjectContext) {
            for (ckRecordID, recordType) in ckRecordIDToCKRecordTypePairsDeleted {
                guard isCancelled == false else {
                    //self.result = .failed
                    self.cancel()
                    return
                }
                if let objectToDelete = fetchManagedObject(recordType: recordType, ckRecordID: ckRecordID, context: context) {
                    context.delete(objectToDelete)
                }
            }
        }
        if let _ckRecordsWithChange = self._ckRecordsWithChange {
            modifyOrCreateManagedObjectsFrom(ckRecordsWithChanges: _ckRecordsWithChange, context: self._context)
        }
        if let _ckRecordIDsToDelete = self._ckRecordIDsToDelete {
            deletedManagedObjectsFrom(ckRecordIDToCKRecordTypePairsDeleted: _ckRecordIDsToDelete, context: self._context)
        }
        _context.performAndWait {
            guard isCancelled == false else {
                //self.result = .failed
                self.cancel()
                return
            }
            saveContextWithoutSyncingCloudKitObjects(context: self._context)
        }
        self.result = .succeeded
        finishOperation()
    }
}

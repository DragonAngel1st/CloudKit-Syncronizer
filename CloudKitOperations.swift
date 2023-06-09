//
//  CloudKitOperations.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2018-04-12.
//  Copyright © 2018 Patrick Miron. All rights reserved.
//

import UIKit
import CloudKit
import CoreData


//MARK:- Verify that user is logged in to Icloud operation
class ICloudUserAccountStatusOperation : OperationWithResult {
    private var _verificationTries = 0
    private var ckAccountStatus: CKAccountStatus?

    final override func main() {
        super.main()
        self.name = "ICloudUserAccountStatusOperation"
        guard isCancelled == false
            else {
                //self.result = .failed
                self.cancel()
                return
        }

        CKContainer.default().accountStatus() { (ckAccountStatus, error) in
            guard ckAccountStatus == .available
                else {
                    _ = CloudKitError.shared.handle(error: error, operation: CloudKitError.Operation.accountStatus, affectedObjects: [ckAccountStatus], alert: true)
                    //self.result = .failed
                    self.cancel()
                    return
            }
            self.ckAccountStatus = ckAccountStatus
            self.result = .succeeded
            self.finishOperation()
        }
    }
}
class FetchIcloudUserRecordIDOperation : OperationWithResult {
    private var _verificationTries = 0
    private var ckAccountStatus: CKAccountStatus?

    final override func main() {
        super.main()
        self.name = "FetchIcloudUserRecordIDOperation"
        guard isCancelled == false
            else {
                //self.result = .failed
                self.cancel()
                return
        }
        CKContainer.default().fetchUserRecordID() { (ckUserRecordID, error) in
            guard error == nil else {
                _ = CloudKitError.shared.handle(error: error, operation: .accountStatus)
                //self.result = .failed
                self.cancel()
                return
            }
            if UserSettings.shared.userEmail == nil || UserSettings.shared.userEmail == "" {
                //Set the CloudKitSetting for the ckUserRecordName to match user's cloudkit userRecord.
                UserSettings.shared.userEmail = ckUserRecordID?.recordName
            } else if UserSettings.shared.userEmail == ckUserRecordID?.recordName {
                // Just continue, this is what is normal
            } else {
                // CloudKit Username and record name no longer is the same. Implement database cleanup if database is of type shared.
            }
            self.result = .succeeded
            self.finishOperation()
        }
    }
}
//MARK:- Custom Zone Setup Operation
// Create custom zone where most data will be store if it does not exist
class CreateCustomZoneOperation: OperationWithResult {
    private let _zoneID: CKRecordZone.ID?
    private let _ckDatabase: CKDatabase
    init(withZoneId zoneID: CKRecordZone.ID, ckDatabse: CKDatabase, completionHandler: ((SuccessResult)->())?) {
        self._zoneID = zoneID
        self._ckDatabase = ckDatabse
        super.init(completionHandler: completionHandler)
        self.name = "CreateCustomZoneOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
//        DispatchQueue.main.async {
//            print("CreateCustomZoneOperation.main was called")
//            print("")
//        }
        guard isCancelled == false else {
//            DispatchQueue.main.async {
//                print("CreateCustomZoneOperation isCancelled")
//                print("")
//            }
            //self.result = .failed
            self.cancel()
            return
        }

        guard _zoneID != nil else {
//            DispatchQueue.main.async {
//                print("CreateCustomZoneOperation's zoneID is nil")
//                print("")
//            }
            self.result = .failed
            self.cancel()
            return
        }
        let customZone = CKRecordZone(zoneID: _zoneID!)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [])
        createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
            if error != nil {
                //TOFIX: Implement CloudKitErrorHandler here.
                DispatchQueue.main.async {
                    print("::::::: ZONE CREATION ERROR ::::::: \(String(describing: error?.localizedDescription))")
                    self.result = .failed
                    self.cancel()
                }
            }
            self.result = .succeeded
            self.finishOperation()
        }
        //createZoneOperation.qualityOfService = .userInitiated
        _ckDatabase.add(createZoneOperation)
    }
}

//MARK:- Create Top Level CKShare Parents records
class CreateTopAccessLevelCKShareParentsOperation: OperationWithResult {
    private let _zoneID: CKRecordZone.ID?
    private let _ckDatabase: CKDatabase
    private let _context: NSManagedObjectContext = CoreDataManager.shared.persistentContainer.newBackgroundContext()
    init(withZoneId zoneID: CKRecordZone.ID, ckDatabse: CKDatabase, completionHandler: ((SuccessResult)->())?) {
        self._zoneID = zoneID
        self._ckDatabase = ckDatabse
        super.init(completionHandler: completionHandler)
        self.name = "CreateTopAccessLevelCKShareParentsOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
        guard _zoneID != nil else {
            self.result = .failed
            self.cancel()
            return
        }
        let newAccessLevel = AccessLevel(context: _context)
        let newAccountingAccess = AccountingAccessLevel(context: _context)
        let newWebAccess = WebAccessLevel(context: _context)
        let newAdminAccess = AdministrationAccessLevel(context: _context)
        let newEmployeeAccess = EmployeeAccessLevel(context: _context)
        let newAccessType = AccessType(context: _context)
        newAccessLevel.accountingAccess = newAccountingAccess
        newAccessLevel.admininistrationAccess = newAdminAccess
        newAccessLevel.employeeAccess = newEmployeeAccess
        newAccessLevel.webAccess = newWebAccess
        newAccessLevel.type = newAccessType
        newAccessType.name = "CKShare Access Type"
        
        let customZone = CKRecordZone(zoneID: _zoneID!)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: [])
        createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
            guard CloudKitError.shared.handle(error: error, operation: .modifyZones, alert: true) == nil
                else {
                    self.result = .failed
                    self.cancel()
                    return
            }
            UserSettings.shared.currentZoneID = self._zoneID!
            UserDefaults.standard.synchronize()
            self.result = .succeeded
            self.finishOperation()
        }
        createZoneOperation.qualityOfService = .userInitiated
        _ckDatabase.add(createZoneOperation)
    }
}

protocol SuccessfullySavedCKRecordsProvider {
    var successfullySavedCKRecords: [CKRecord]? { get }
}

protocol SuccessFullyDeletedCKRecordIDsProvider {
    var successFullyDeletedCKRecordsIDs: [CKRecord.ID]? { get }
}

extension ModifyCloudKitRecordsOperation: SuccessfullySavedCKRecordsProvider, SuccessFullyDeletedCKRecordIDsProvider {
    var successFullyDeletedCKRecordsIDs: [CKRecord.ID]? { return _ckRecordIDsSuccessfullyDeleted }
    var successfullySavedCKRecords: [CKRecord]? { return _ckRecordsSuccessfullySaved }
}

//MARK:-
class ModifyCloudKitRecordsOperation: OperationWithResult {

    private let _ckDatabase: CKDatabase?
    private var _ckRecordsToSaveToCKDatabase : [CKRecord]?
    private var _ckRecordsSuccessfullySaved = [CKRecord]()
    private var _cloudKitManagedOjbects: [NSManagedObject]?
    private var _ckRecordsToDeleteWithRecordIDs: [CKRecord.ID]?
    private var _zoneID: CKRecordZone.ID?
    private var _ckRecordsWithManagedObjectPairs: [(CKRecord, NSManagedObject)]?
    private var _ckRecordIDsSuccessfullyDeleted: [CKRecord.ID]?

    init(zoneID: CKRecordZone.ID?, ckDatabase: CKDatabase?, completionHandler: ((SuccessResult)->())?) {
        self._ckDatabase = ckDatabase
        self._zoneID = zoneID
        super.init(completionHandler: completionHandler)
        self.name = "ModifyCloudKitRecordsOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
//        DispatchQueue.main.async {
//            print("....The function main() from ModifyCloudKitRecordsOperation was called")
//            print(" $$ :: TOTAL CKRecords to be Modified before function findAllCKRecordsToBeModifiedFrom : \(self._cloudKitManagedOjbects!.count) :: $$")
//        }
        guard isCancelled == false, _zoneID != nil, _ckDatabase != nil else {
//            DispatchQueue.main.async {
//                print("ModifyCloudKitRecordsOperation isCancelled")
//            }
            self.result = .failed
            self.cancel()
            return
        }
        guard let dependencyCKRecordIDsToBeDeletedProvider = self.dependencies.filter({ $0 is DeletedCloudKitMangedObjectCKRecordIDsToBeDeletedProvider}).first as? DeletedCloudKitMangedObjectCKRecordIDsToBeDeletedProvider, let dependencySavedManagedObjectsProvider = self.dependencies.filter({ $0 is SavedManagedObjectsProvider}).first as? SavedManagedObjectsProvider else { return
        }
        self._ckRecordsToDeleteWithRecordIDs = dependencyCKRecordIDsToBeDeletedProvider.ckRecordIDsToBeDeleted
        self._cloudKitManagedOjbects = dependencySavedManagedObjectsProvider.managedObjectsToSaveAndSyncToCloudKit
        
        func findAllCKRecordsToBeModifiedFrom(cloudKitManagedObjects: [NSManagedObject]) -> [(CKRecord, NSManagedObject)]! {
            var _indexedCKRecordManagedObjectPairsByCKRecordID = [CKRecord.ID : Any ]()
            for cloudKitManagedObject in cloudKitManagedObjects {
                let _privateCKRecord = (cloudKitManagedObject.getCKRecord() ?? cloudKitManagedObject.createCKRecord(zoneID: _zoneID!))
                for (key, relationshipDescription) in cloudKitManagedObject.entity.relationshipsByName {
                    if !relationshipDescription.isToMany {
                        var deleteAction = CKRecord_Reference_Action.none
                        if relationshipDescription.deleteRule == .cascadeDeleteRule {
                            deleteAction = .deleteSelf
                        }
                        if let objectID = cloudKitManagedObject.objectIDs(forRelationshipNamed: key).first {
                            if let parentObject = cloudKitManagedObject.managedObjectContext?.object(with: objectID) {
                                let _parentCKRecord = (parentObject.getCKRecord() ?? parentObject.createCKRecord(zoneID: _zoneID!))
                                switch key {
                                case "accessParent":
                                    // Set the parent cloudkit object to maintain hiearchy of shared records.
                                    // Only the top records are saved and created before user can insert data and then each
                                    // these are asigned as parent records for all entities/tables that are parents themselfves.
                                    // There is only one parent per table/entity

                                    _privateCKRecord.setParent(_parentCKRecord)
                                    //                                    _privateCKRecord[key] = CKReference(record: _parentCKRecord, action: .none)
                                default:
                                    //Core Data Relationships are saved as CKReference in CloudKit Containers
                                    //_privateCKRecord.setObject(_parentCKRecord.recordID.recordName as CKRecordValue, forKey: key)
                                    
                                    _privateCKRecord[key] = CKRecord.Reference(record: _parentCKRecord, action: deleteAction)
                                }
                                    //_indexedCKRecordManagedObjectPairsByCKRecordID[_parentCKRecord.recordID] = (_parentCKRecord, cloudKitManagedObject)
                            }
                        }
                    }
                }
                    _indexedCKRecordManagedObjectPairsByCKRecordID[_privateCKRecord.recordID] = (_privateCKRecord, cloudKitManagedObject)
            }
//            DispatchQueue.main.async {
//                print(" $$ :: TOTAL CKRecords to be Modified after function findAllCKRecordsToBeModifiedFrom : \(_indexedCKRecordManagedObjectPairsByCKRecordID.count) :: $$")
//            }
            return _indexedCKRecordManagedObjectPairsByCKRecordID.compactMap({ ($0.value) as? (CKRecord, NSManagedObject) })
        }
        func modifyCKRecordAttributes(ckRecordNSManagedObjectPairs : [(CKRecord, NSManagedObject)]) -> [CKRecord]{
            var _ckRecords = [CKRecord]()
            for (ckRecord, cloudKitManagedObject) in ckRecordNSManagedObjectPairs {
                for (key, attributeDescription) in cloudKitManagedObject.entity.attributesByName {
                    if key != "ckRecordName" && key != "ckEncodedSystemFields" {
                        if let value = cloudKitManagedObject.value(forKey: key) {
                            switch attributeDescription.attributeType {
                            case NSAttributeType.binaryDataAttributeType:
                                //create a CKAsset and save the data as a CKAsset
                                //learn to create a CKAsset
                                if let data = value as? Data {
                                    do {
                                        let ckAsset = try CKAsset(data: data)
                                        ckRecord.setObject(ckAsset, forKey: key)
                                    } catch {
                                        print(" :: ERROR :: Error found while trying to create a CKAsset from binary data. Error description: \(error) ... \(error.localizedDescription)")
                                    }
                                }

                            default:
                                ckRecord.setObject((value as? CKRecordValue), forKey: key)
                            }
                        }
                    }
                }
                _ckRecords.append(ckRecord)
            }
//            DispatchQueue.main.async {
//                print(" $$ :: TOTAL CKRecords to be Modified after modifyCKRecordAttributes : \(_ckRecords.count) :: $$")
//            }
            return _ckRecords
        }
        if let _cloudKitManagedOjbects = _cloudKitManagedOjbects {
            _ckRecordsWithManagedObjectPairs = findAllCKRecordsToBeModifiedFrom(cloudKitManagedObjects: _cloudKitManagedOjbects)
            _ckRecordsToSaveToCKDatabase = modifyCKRecordAttributes(ckRecordNSManagedObjectPairs: _ckRecordsWithManagedObjectPairs!)
        }
        let modifyPrivateRecordsOperation = CKModifyRecordsOperation(recordsToSave: _ckRecordsToSaveToCKDatabase, recordIDsToDelete: _ckRecordsToDeleteWithRecordIDs)
        //Allways use the ifServerRecordUnchanged Policy until per record error handling is done with user interaction
        modifyPrivateRecordsOperation.savePolicy = .ifServerRecordUnchanged
        modifyPrivateRecordsOperation.perRecordCompletionBlock = { (ckRecord: CKRecord, error: Error?) in
            if error != nil {
                //Log error here
//                DispatchQueue.main.async {
//                    print("modifyPrivateRecordsOperation.perRecordCompletionBlock :: ERROR :: \(String(describing: error?.localizedDescription), ckRecord.recordType) ")
//                }
                if let error = error as? CKError {
                    //TODO: MUST IMPLEMENT FUNCTION THAT WILL TRY TO SAVE CHANGED KEYS ONTO NEWER RECORD BY PRESENTING USER WITH A SIDE BY SIDE TABLE SO THEY CAN CHOOSE WHICH FIELD/ATTRIBUTES TO UPDATE OR COMPLETELY OVERWRITE CLOUDKIT RECORD
                   // _ = CloudKitError.shared.handle(error: error, operation: .modifyRecords, affectedObjects: [ckRecord])
                    DispatchQueue.main.async {
                        print("Some error occured while trying to modify records online")
                    }
                    switch error.code {
                    case .serverRecordChanged:
                        // CKRecordChangedErrorAncestorRecordKey:
                        // Key to the original CKRecord that you used as the basis for making your changes.
                        // let ancestorRecord = error.userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord

                        if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord, let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord {
                            print("ERROR: Server record was changed by another process while trying to save changes to cloudKit.")
                            // CKRecordChangedErrorServerRecordKey:
                            // Key to the CKRecord that was found on the server. Use this record as the basis for merging your changes.
                            //var serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as CKRecord
                            // CKRecordChangedErrorClientRecordKey:
                            // Key to the CKRecord that you tried to save.
                            // This record is based on the record in the CKRecordChangedErrorAncestorRecordKey key but contains the additional changes you made.
                            //var clientRecord: CKRecord? = error.userInfo[CKRecordChangedErrorClientRecordKey]
                            //                            assert(ancestorRecord != nil || serverRecord != nil || clientRecord != nil, "Error CKModifyRecordsOperation, can't obtain ancestor, server or client records to resolve conflict.")
                            // important to use the server's record as a basis for our changes,
                            // apply our current record to the server's version
                            //

                            // try to set the values on the current server record with my clientRecord
                            //TODO: TO IMPLEMENT An interactive Notification to ask if the newer server record should be overwritten with the changes of the user. If user does not have the rights to do so, then give the user the option to ask for overwritting the records with user's changes. If the user is the owner of the record, then it shoudl not have to ask but simply overwrite the changes he asks with a warning saying what will be done.
                            //  until the above is implemented, try to overwrite the changes asked on the new record.
                            print("Trying to overwrite the changes on the new record returned.")
                            for key in clientRecord.allKeys() {
                                serverRecord.setObject(clientRecord[key], forKey: key)
                            }
                            // save the newer record
                            //privateRecordsFailedToSave.append(serverRecord)
                        }
                    default:
                        //TOFIX: Implement CloudKitErrorHandler here.
                        //_ = CloudKitError.shared.handle(error: error, operation: .modifyRecords, affectedObjects: [ckRecord], alert: true)
                        print("This record failed to save. \(ckRecord.recordID.recordName)")
                        print("...ERROR : \(error.localizedDescription)")
                        print("ERROR CODE = \(error.code)")
                    }
                }
            } else {
                //WARNING DO NOT USE THESE RESULTS FOR THE RECORDS -> The returned CKRecords here can be modified, created or deleted ckRecords.
                // WRONG //save successfully cloudkit saved records to array that will be the operations output ckrecords to be processed by depending operation.
                // WRONG //self._ckRecordsSuccessfullySaved.append(ckRecord)
            }
        }
        modifyPrivateRecordsOperation.modifyRecordsCompletionBlock = { (ckRecords, deletedCKRecordIDs, error) in
            if error != nil {
                //TOFIX: Implement CloudKitErrorHandler here.
                DispatchQueue.main.async {
                    print("modifyPrivateRecordsOperation.modifyRecordsCompletionBlock :: ERROR :: \(String(describing: error?.localizedDescription)) :: \(String(describing: error.debugDescription))")
                    for record in ckRecords! {
                        print(record.recordID)
                    }
                    self.result = .failed
                    self.cancel()
                }
                //_ = CloudKitError.shared.handle(error: error, operation: .modifyRecords)
            } else {
                if let savedCKRecords = ckRecords {
                    self._ckRecordsSuccessfullySaved = savedCKRecords
                }
                if let deletedCKRecordIDs = deletedCKRecordIDs {
                    self._ckRecordIDsSuccessfullyDeleted = deletedCKRecordIDs
                }
                self.result = .succeeded 
                self.finishOperation()
            }
        }
        self._ckDatabase!.add(modifyPrivateRecordsOperation)
    }
}

//User Sign-in operation to get username and make sure the credential have been properly installed.
class CloudKitSignInOperation: GroupOperation {
    required init(completionHandler: ((SuccessResult) -> ())?) {
        super.init(completionHandler: completionHandler)
        let accountStatusOp = ICloudUserAccountStatusOperation(completionHandler: nil)
        self.add(operation: accountStatusOp)
        let fetchUserIDOp = FetchIcloudUserRecordIDOperation(completionHandler: nil)
        self.add(operation: fetchUserIDOp)
        fetchUserIDOp.addDependency(accountStatusOp)
        self.name = "CloudKitSignInGroupOperation"
    } 
}

//Subscribe to Changes in CloudKit database operation.
class SubscribeToDatabaseChangesOperation: OperationWithResult {
    private let _ckDatabase: CKDatabase
    private var _subscriptionID: String?

    init(ckDatabase: CKDatabase, completionHandler:((SuccessResult) -> ())?) {
        self._ckDatabase = ckDatabase
        super.init(completionHandler: completionHandler)
        self.name = "SubscribeToDatabaseChangesOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    override func main() {
        super.main()
        guard !isCancelled else {
            self.result = .failed
            self.cancel()
            return
        }
        switch _ckDatabase.databaseScope {
        case .private:
            _subscriptionID = "privateSubscription"
        case .shared:
            _subscriptionID = "sharedSubscription"
        default:
            _subscriptionID = "publicSubscription"
        }
        let subscription = CKDatabaseSubscription.init(subscriptionID: _subscriptionID!)

        let notificationInfo = CKSubscription.NotificationInfo()

        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let createSubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        createSubscriptionOperation.qualityOfService = .utility
        createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deleteIds, error) in
            guard CloudKitError.shared.handle(error: error, operation: .modifySubscriptions, alert: true) == nil
                else {
                    self.result = .failed
                    self.cancel()
                    return
            }
            DispatchQueue.main.async {
                print(":: CREATED SUBSCRIPTION :: Subscribed using ID:\(String(describing: self._subscriptionID))")
            }
            self.result = .succeeded
            self.finishOperation()
        }
        _ckDatabase.add(createSubscriptionOperation)
    }
}
//MARK: - FETCH CHANGES OPERATIONS
//To implement "Deleted Zone" tracker later, currently the zones are not cached localy and not used in the core data database. (Only one zone is used)
//Protocol to pass data between database changes operations
protocol ChangedCKZonesProvider {
    var changedZoneIDs: [CKRecordZone.ID]? { get }
}
protocol ChangedDatabaseTokenProvider {
    var changedDatabaseToken: CKServerChangeToken? { get }
}
extension FetchDatabaseChangesOperation: ChangedCKZonesProvider, ChangedDatabaseTokenProvider {
    var changedZoneIDs: [CKRecordZone.ID]? { return _changedZoneIDs }
    var changedDatabaseToken: CKServerChangeToken? { return _changedDatabaseToken }
}

class FetchDatabaseChangesOperation: OperationWithResult {
    private let _ckDatabase: CKDatabase
    private var _changedDatabaseToken: CKServerChangeToken?
    private var _subscriptionID: String?
    private var _previousChangeToken: CKServerChangeToken?
    private var _changedZoneIDs: [CKRecordZone.ID] = []
    private var _deletedZoneIDs: [CKRecordZone.ID] = []

    init(ckDatabase: CKDatabase, completionHandler:((SuccessResult) -> ())?) {
        self._ckDatabase = ckDatabase
        super.init(completionHandler: completionHandler)
        self.name = "FetchDatabaseChangesOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
        guard !isCancelled else {
            //self.result = .failed
            self.cancel()
            return
        }
        switch _ckDatabase.databaseScope {
        case .private:
            _subscriptionID = "privateSubscription"
            _previousChangeToken = UserSettings.shared.localPrivateDatabaseChangeToken
        default:
            _subscriptionID = "sharedSubscription"
            _previousChangeToken = UserSettings.shared.localSharedDatabaseChangeToken
        }
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: _previousChangeToken)

        operation.recordZoneWithIDChangedBlock = { (zoneID) in
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            self._changedZoneIDs.append(zoneID)
            //print("--- recordZoneWithIDChangedBlock called.---")
            //print("Write this zone has changed to memory: \(currentZoneID)")
            //FIXME: IMPLEMENT A ZONE SYNC FOR POSIBLE FUTURE USE.
            //UserSettings.shared.currentZoneID = zoneID
        }
        operation.recordZoneWithIDWasDeletedBlock = { (zoneID) in
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            //print("--- recordZoneWithIDWasDeletedBlock called.---")
            //print("Write this zone: \(currentZoneID) deletion to memory")
            self._deletedZoneIDs.append(zoneID)
        }
        // Do this operation(changeTokenUpdatedBlock) or the next(fetchDatabaseChangesCompletionBlock)
        // Both do the samething differently.
        /*
         operation.changeTokenUpdatedBlock = { (token) in
         print("--- changeTokenUpdatedBlock called.---")
         print("changeTokenUpdatedBlock...Flush deletions for the database: \(database.databaseScope) to CoreData")
         print("changeTokenUpdatedBlock...Write this new database change token: \(token) to memory")
         newChangeToken = token
         }
         */

        //There should not be any zone changes once production is set. At the moment, the only zone will be same as company name.
        operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            if let error = error {
                _ = CloudKitError.shared.handle(error: error, operation: .fetchChanges)
                self.result = .failed
                self.cancel()
                return
            } else {
                //saveChangeTokenFor(ckDatabase: self._ckDatabase, changeToken: token)
                self._changedDatabaseToken = token
                if self._changedZoneIDs.isEmpty && self._deletedZoneIDs.isEmpty {
                    self.result = .completedWithNoChanges
                    self.finishOperation()
                } else {
                    self.result = .succeeded
                    self.finishOperation()
                }
            }
            if moreComing {
                print("*****--- moreComing ---> \(moreComing) ----*****")
            }
        }
        _ckDatabase.add(operation)
    }
}
//MARK:- FETCH ZONE CHANGES (CHANGED RECORDS PER ZONE)
//Protocol to pass data between database changes operations
protocol ChangedCKRecordsProvider {
    var ckRecordsChanged: [CKRecord]? { get }
    var ckRecordIDToCKRecordTypePairsDeleted: [(CKRecord.ID, String)]? { get }
}
protocol ChangedCKZoneTokenProvider {
    var changedCKZoneTokensByZoneID: [(CKRecordZone.ID, CKServerChangeToken?)]? { get }
}

extension FetchZoneChangesOperation: ChangedCKRecordsProvider, ChangedCKZoneTokenProvider {
    var ckRecordsChanged: [CKRecord]? { return _ckRecordsChanged }
    var ckRecordIDToCKRecordTypePairsDeleted: [(CKRecord.ID, String)]? { return _ckRecordIDToCKRecordTypePairsDeleted }
    var changedCKZoneTokensByZoneID: [(CKRecordZone.ID, CKServerChangeToken?)]? { return _changedCKZonesAndTokens }
}

class FetchZoneChangesOperation: OperationWithResult {
    private var _zoneID: CKRecordZone.ID
    private var _changedZoneIDs: [CKRecordZone.ID]?
    private var _changedCKZonesAndTokens = [(CKRecordZone.ID, CKServerChangeToken?)]()
    private var _ckRecordsChanged = [CKRecord]()
    private var _ckRecordIDToCKRecordTypePairsDeleted = [(CKRecord.ID, String)]()
    private let _ckDatabase: CKDatabase
    private var _zoneIDsWithRecordChanges = [CKRecordZone.ID]()
    private var _recordZoneFetchCompletionBlockCompleted: Bool = false
    private var _fetchRecordZoneChangesCompletionBlockCompleted: Bool = false
    //private var _recordZoneChangeTokensUpdatedBlockCompleted: Bool = false
    private var _localChangeToken: CKServerChangeToken?
    //FIXME: MUST FIX THIS FUNCTION TO ENABLE OTHER ZONE CHANGES
    func getLocalChangeTokenForZoneID(_ recordZoneID: CKRecordZone.ID, ckDatabase: CKDatabase) -> CKServerChangeToken? {
        switch ckDatabase.databaseScope {
        case .private:
            return UserSettings.shared.localPrivateDatabaseZoneChangeToken
        case .public:
            return UserSettings.shared.localPublicDatabaseZoneChangeToken
        case .shared:
            return UserSettings.shared.localSharedDatabaseZoneChangeToken
        @unknown default:
            fatalError()
        }
    }

    init(ckDatabase: CKDatabase, zoneID: CKRecordZone.ID, completionHandler:((SuccessResult) -> ())?) {
        self._ckDatabase = ckDatabase
        self._zoneID = zoneID
        super.init(completionHandler: completionHandler)
        self.name = "FetchZoneChangesOperation"
        self._zoneIDsWithRecordChanges.append(zoneID)
        //TOFIX: FIX THIS ASSIGNMENT IF MULTIPLE ZONE ARE ADDED IN FUTURE VERSION
        self._localChangeToken = getLocalChangeTokenForZoneID(_zoneID, ckDatabase: _ckDatabase)
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }
    override func finishOperation() {

        self.result = .succeeded
        super.finishOperation()
    }
    final override func main() {
        super.main()
        guard !isCancelled else {
            self.cancel()
            return
        }
        //FIXME: MUST IMPLEMENT THE NEXT FUNCTIONS TO ENABLE MULTIPLE ZONE CREATION, CHANGES AND DELETIONS NOT PLANNED UNTIL VERSION 3.0
        if let dependencyZonesChangedProvider = dependencies.filter({ $0 is ChangedCKZonesProvider}).first as? ChangedCKZonesProvider {
            self._changedZoneIDs = dependencyZonesChangedProvider.changedZoneIDs
//            DispatchQueue.main.async {
//                print("_changedZoneIDs: \(String(describing: self._changedZoneIDs))")
//            }
        } else {
            self.result = .failed
            self.cancel()
        }
        guard let _changedZoneIDs = _changedZoneIDs, !_changedZoneIDs.isEmpty else {
            self.result = .failed
            self.cancel()
            return
        }
        var operation = CKFetchRecordZoneChangesOperation()

        if #available(iOS 12.0, *) {
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            var configurationsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
            for zoneID in _changedZoneIDs {
                guard !self.isCancelled else {
                    //self.result = .failed
                    self.cancel()
                    return
                }

                let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                configuration.previousServerChangeToken = getLocalChangeTokenForZoneID(zoneID, ckDatabase: _ckDatabase)
                // append configuration to configurationsByRecordZoneID
                configurationsByRecordZoneID[zoneID] = configuration
            }
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: _changedZoneIDs, configurationsByRecordZoneID: configurationsByRecordZoneID)
            //operation.configurationsByRecordZoneID = configurationsByRecordZoneID

            //operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: _changedZoneIDs!, configurationsByRecordZoneID: [_configurationsByRecordZoneID])
            //            DispatchQueue.main.async {
            //                print("The previous local change token for zoneID \(self._zoneID.zoneName) is: \(String(describing: UserSettings.shared.localPrivateDatabaseZoneChangeToken))")
            //            }
        } else {
            var _optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()
            for zoneID in _changedZoneIDs {
                guard !self.isCancelled else {
                    //self.result = .failed
                    self.cancel()
                    return
                }
                let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
                options.previousServerChangeToken = getLocalChangeTokenForZoneID(zoneID, ckDatabase: _ckDatabase)
                _optionsByRecordZoneID[zoneID] = options
                operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: _zoneIDsWithRecordChanges, optionsByRecordZoneID: _optionsByRecordZoneID)

            }
        }

        operation.fetchAllChanges = true
        operation.recordChangedBlock = { (record) in
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            if record.recordType == "cloudkit.share" {
            //FIXME: add support to notify that the share records were accepted.
            } else {
                self._ckRecordsChanged.append(record)
//                DispatchQueue.main.async {
//                    print("A record was changed on CloudKit Server: ",record)
//                }

            }
        }

        operation.recordWithIDWasDeletedBlock = { (recordId, recordType) in
            //Write this record deletion to memory
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            self._ckRecordIDToCKRecordTypePairsDeleted.append((recordId, recordType))
        }
        // Only do .recordZoneChangeTokensUpdatedBlock or .recordZoneFetchCompletionBlock.
        // Both operations do the same thing.

//        operation.recordZoneChangeTokensUpdatedBlock = { (currentZoneID, newChangeToken, data) in
//            guard !self.isCancelled else {
//                //self.result = .failed
//                self.cancel()
//                return
//            }
//            //Save Zone Change Tokens to memory
//            saveChangeTokenFor(ckDatabase: self._ckDatabase, changedZoneID: currentZoneID, newChangeToken: newChangeToken)
//            DispatchQueue.main.async {
//                print("...recordZoneChangeTokensUpdatedBlock was called...")
//            }
//            //self._recordZoneChangeTokensUpdatedBlockCompleted = true
//            self.finishOperation()
//
//        }
        operation.recordZoneFetchCompletionBlock = { (zoneID, newChangeToken, _, _, error) in
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            //print("--- recordZoneFetchCompletionBlock was called. ---")
            if let error = error {
                _ = CloudKitError.shared.handle(error: error, operation: .fetchZones)
                self.result = .failed
                self.cancel()
                return
            }
            self._changedCKZonesAndTokens.append((zoneID, newChangeToken))
        }
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            if let error = error {
                guard !self.isCancelled else {
                    self.result = .failed
                    self.cancel()
                    return
                }
                _ = CloudKitError.shared.handle(error: error, operation: .fetchRecords)
                self.cancel()
                return
            }
//            DispatchQueue.main.async {
//                print("...fetchRecordZoneChangesCompletionBlock was called...")
//            }
            self.result = .succeeded
            self.finishOperation()
        }
        _ckDatabase.add(operation)
    }
}


//class AddAnyExistingSubcriptionFromiCloudToThisDeviceOperation: GroupOperation {
//    init(_ completionHandler: ((SuccessResult) -> ())?) {
//        //init super private variables here
//        super.init(completionHandler: completionHandler)
//        self.name = "SetupCloudKitOperation"
//        let lookforSubscriptionOp = VerifyIfAnySubscriptionExistOniCloudOperation { (result) in
//            if result == .succeeded {
//                //Completion Handler for this op
//                DispatchQueue.main.async {
//                    print()
//                    print(":: AddAnyExistingSubcriptionFromiCloudToThisDeviceOperation :: Succeeded")
//                    print()
//                }
//            } else {
//                DispatchQueue.main.async {
//                    print()
//                    print(":: AddAnyExistingSubcriptionFromiCloudToThisDeviceOperation :: Failed")
//                    print()
//                }
//                self.cancel()
//            }
//        }
//        self.add(operation: lookforSubscriptionOp)
//        let fetchAllCKDatabaseChangesOp = CloudKitFetchAllCKDatabaseChangesOperation { (result) in
//            if result == .succeeded {
//                //Completion Handler for this op
//                DispatchQueue.main.async {
//                    print()
//                    print(":: FetchDatabaseChangesOperation :: Succeeded")
//                    print()
//                }
//            } else {
//                DispatchQueue.main.async {
//                    print()
//                    print(":: FetchDatabaseChangesOperation :: Failed")
//                    print()
//                }
//                self.cancel()
//            }
//        }
//        fetchAllCKDatabaseChangesOp.addDependency(lookforSubscriptionOp)
//        self.add(operation: fetchAllCKDatabaseChangesOp)
//        self.internalQueue.isSuspended = false
//        main()
//    }
//
//    required init(completionHandler: ((SuccessResult) -> ())?) {
//        fatalError("init(completionHandler:) has not been implemented")
//    }
//}

//MARK:- FETCH ALL CLOUDKIT DATABASE CHANGES GROUP OPERATION (CALLS OTHER OPS)
class CloudKitFetchAllCKDatabaseChangesGroupOperation: GroupOperation {
    private var _ckDatabase: CKDatabase!
    private var _zoneID: CKRecordZone.ID!
    /// WARNING:: If this convenience init is used, SELF must have a DatabaseInfoProvider as a dependency.
//    required init(completionHandler: ((SuccessResult) -> ())?) {
//         super.init(completionHandler: completionHandler)
//         if let dependencyDatabaseInfoProvider = dependencies.filter({ $0 is VerifyIfAnySubscriptionExistOniCloudOperation}).first as? DatabaseInfoProvider {
//
//            guard let _ckDatabase = dependencyDatabaseInfoProvider.ckDatabase, let _zoneID = dependencyDatabaseInfoProvider.zoneID else {
//
//                self.result = .failed
//                self.cancel()
//                return
//            }
//            self._ckDatabase = _ckDatabase
//            self._zoneID = _zoneID
//            //call addOperations
//            addOperations()
//        }
//    }

    required init(ckDatabase: CKDatabase, zoneID: CKRecordZone.ID, completionHandler: ((SuccessResult) -> ())?) {
        self._ckDatabase = ckDatabase
        self._zoneID = zoneID
        super.init(completionHandler: completionHandler)
        self.name = "CloudKitFetchAllCKDatabaseChangesGroupOperation"
//        DispatchQueue.main.async {
//            print("CREATING : CloudKitFetchAllCKDatabaseChangesGroupOperation QUEUE...")
//        }
        addOperations()
    }
    private func addOperations() {
        let fetchDatabaseChangesOp = FetchDatabaseChangesOperation(ckDatabase: self._ckDatabase) { (result) in
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            switch result {
            case .succeeded:
//                DispatchQueue.main.async {
//                    print("::-- FetchDatabaseChangesOperation :: Succeeded")
//                }
                break
            case .completedWithNoChanges:
//                DispatchQueue.main.async {
//                    print("::-- FetchDatabaseChangesOperation :: Completed With No Changes")
//                }
                break
            default:
//                DispatchQueue.main.async {
//                    print("::-- FetchDatabaseChangesOperation :: Failed")
//                }
                self.cancel() // CANCEL ALL OPERATIONS if result is anything but .succeeded
            }
        }
        self.add(operation: fetchDatabaseChangesOp)

        let fetchZoneChangesOp = FetchZoneChangesOperation(ckDatabase: _ckDatabase, zoneID: _zoneID) { (result) in
            guard !self.isCancelled else {
                //self.result = .failed
                self.cancel()
                return
            }
            if result == .failed {
//                DispatchQueue.main.async {
//                    print("::-- ERROR :: FetchZoneChangesOperation was canceled." )
//                }
                self.cancel() // CANCEL ALL OPERATIONS if result is anything but .succeeded
            } else if result == .completedWithNoChanges {
//                DispatchQueue.main.async {
//                    print("::-- FetchZoneChangesOperation :: Completed with no zone changes" )
//                }
            } else {
//                DispatchQueue.main.async {
//                    print("::-- FetchZoneChangesOperation :: Succeeded")
//                }
            }
            //self.remove(operationName: self.name!)
        }
        fetchZoneChangesOp.addDependency(fetchDatabaseChangesOp)
        self.add(operation: fetchZoneChangesOp)

        let saveCKRecordsToCoreDataOp = SaveCKRecordsToCoreDataOperation(ckDatabase: _ckDatabase) { result in
            guard !self.isCancelled else {
                self.result = .failed
                self.cancel()
                return
            }
            if result == .succeeded {
//                DispatchQueue.main.async {
//                    print("::-- SaveCKRecordsToCoreDataOperation :: Succeeded")
//                }
                self.result = .succeeded
                self.finishQueue()
            }
            else if result == .completedWithNoChanges {
//                DispatchQueue.main.async {
//                    print("::-- SaveCKRecordsToCoreDataOperation :: Completed with no zone changes" )
//                }
                self.result = .succeeded
                self.finishQueue()
            }
            else {
//                DispatchQueue.main.async {
//                    print("::-- SaveCKRecordsToCoreDataOperation :: Failed")
//                }
                self.result = .failed
                self.cancel() // CANCEL ALL OPERATIONS if result is anything but .succeeded
            }
            //self.remove(operationName: self.name!)
        }
        saveCKRecordsToCoreDataOp.addDependency(fetchDatabaseChangesOp)
        saveCKRecordsToCoreDataOp.addDependency(fetchZoneChangesOp)

        self.add(operation: saveCKRecordsToCoreDataOp)
        self.internalQueue.isSuspended = false
        main()
    }
    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }
}
//MARK:- FETCH ALL SUBSCRIPTIONS ON CLOUDKIT PER DATABASE
// Fetch All Subscriptions on Cloudkit for the selected database
class FetchAllSubscriptionsForDatabaseOperation: OperationWithResult {
    private var _ckDatabase: CKDatabase
    init(_ ckDatabase : CKDatabase, completionHandler: ((SuccessResult)->())?) {
        self._ckDatabase = ckDatabase
        super.init(completionHandler: completionHandler)
        self.name = "CreateCustomZoneOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
        let fetchAllSubscriptions = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        fetchAllSubscriptions.fetchSubscriptionCompletionBlock = { subscriptionInfos, error in
            if let subscriptionInfos = subscriptionInfos {
                if subscriptionInfos["privateSubscription"] != nil {
                    UserSettings.shared.companyProfileCreated = true
//                    Settings.shared.createdCustomZone = true
//                    Settings.shared.createdTopSharedAccessRecords = true
                    UserSettings.shared.subscribedToPrivateChanges = true
                }
                if subscriptionInfos["sharedSubscription"] != nil {
                    UserSettings.shared.subscribedToSharedChanges = true
                }
            }
            //self.result = .succeeded
            self.operationCompletionHandler()
        }
        _ckDatabase.add(fetchAllSubscriptions)
    }
}

//MARK:- VERIFY EXISTANCE OF SUBSCRIPTION ON CLOUD KIT CURRENT DATABASE
// PROTOCOL & EXTENSION: To transfer data between operations
protocol DatabaseInfoProvider {
    var ckDatabase: CKDatabase? { get }
    var zoneID: CKRecordZone.ID? { get }
}

extension VerifyIfAnySubscriptionExistOniCloudOperation: DatabaseInfoProvider {
    var ckDatabase: CKDatabase? { return _ckDatabase }
    var zoneID: CKRecordZone.ID? { return _zoneID }
}
// Fetch Specific Subscription for Specifiy database.
class VerifyIfAnySubscriptionExistOniCloudOperation: OperationWithResult {
    private var _ckDatabase: CKDatabase?
    private var _zoneID: CKRecordZone.ID?
    required init(completionHandler: ((SuccessResult)->())?) {
        super.init(completionHandler: completionHandler)
        self.name = "VerifyIfAnySubExistOperation"
    }

//    required init(completionHandler: ((SuccessResult) -> ())?) {
//        fatalError("init(completionHandler:) has not been implemented")
//    }

    final override func main() {
        super.main()
        UserSettings.shared.currentUserDB.fetch(withSubscriptionID: "sharedSubscription") { (ckSubscription, error) in
            //IGNORE CLOUDKIT ERROR :: We are searching for specific subscription if they exist and we are not interested in any result if this fails.
            if ckSubscription != nil {
                UserSettings.shared.subscribedToSharedChanges = true
                UserSettings.shared.databaseOwnership = DatabaseOwnership.participant
//                DispatchQueue.main.async {
//                    print()
//                    print(":: SUBSCRIPTION FOUND :: Shared Database Subscription Exist")
//                    print()
//                }
                let fetchExistingZonesOp = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
                fetchExistingZonesOp.fetchRecordZonesCompletionBlock = { ckRecordZoneInfos, error in
                    if let ckRecordZoneInfos = ckRecordZoneInfos {
                        for (ckZoneID, _) in ckRecordZoneInfos {
                            guard self.isCancelled == false else {
                                self.cancel()
                                return
                            }
                            if ckZoneID.zoneName != CKRecordZone.ID.defaultZoneName {
                                UserSettings.shared.currentZoneID = ckZoneID
                                return
                            }
                        }
                    }
                }
                UserSettings.shared.currentUserDB.add(fetchExistingZonesOp)
            } else {
                UserSettings.shared.currentUserDB.fetch(withSubscriptionID: "privateSubscription", completionHandler: { (ckSubscription, error) in
                    if ckSubscription != nil {
                        UserSettings.shared.subscribedToPrivateChanges = true
                        UserSettings.shared.databaseOwnership = DatabaseOwnership.owner
                        UserSettings.shared.customZoneCreated = true
//                        DispatchQueue.main.async {
//                            print()
//                            print(":: SUBSCRIPTION FOUND :: Private Database Subscription Exist")
//                            print()
//                        }
                        let fetchExistingZonesOp = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
                        fetchExistingZonesOp.fetchRecordZonesCompletionBlock = { ckRecordZoneInfos, error in
                            if let ckRecordZoneInfos = ckRecordZoneInfos {
                                for (ckZoneID, _) in ckRecordZoneInfos {
                                    guard self.isCancelled == false else {
                                        self.cancel()
                                        return
                                    }
                                    if ckZoneID.zoneName != CKRecordZone.ID.defaultZoneName {
                                        UserSettings.shared.currentZoneID = ckZoneID
                                        UserSettings.shared.topSharedAccessRecordsCreated = true
                                        UserSettings.shared.companyProfileCreated = true
                                        UserSettings.shared.devicelsCompletelySetupForCloudKitSync = true
                                        self.result = .succeeded
                                        self.finishOperation()
                                        return
                                    }
                                }
                            }
                        }
                        UserSettings.shared.currentUserDB.add(fetchExistingZonesOp)
                    } else {
                        self.result = .failed
                        self.cancel()
                    }
                })
            }
            UserSettings.shared.settingsNeedsUpdate()
        }
    }
}

//MARK:- FETCH ALL EXISTING ZONEIDs FOR CURRENT DATABASE
// Fetch All ZoneID's for Specifiy database.
class FetchZonesForDatabaseOperation: OperationWithResult {
    private var _ckDatabase: CKDatabase
    init(ckDatabase: CKDatabase, completionHandler: ((SuccessResult)->())?) {

        self._ckDatabase = ckDatabase
        super.init(completionHandler: completionHandler)
        self.name = "CreateCustomZoneOperation"
    }

    required init(completionHandler: ((SuccessResult) -> ())?) {
        fatalError("init(completionHandler:) has not been implemented")
    }

    final override func main() {
        super.main()
        _ckDatabase.fetchAllRecordZones { (ckRecordZones, error) in
            if error != nil {
                //TODO: Implement cloudkit error handler
                print(":: CLOUDKIT ERROR :: \(String(describing: error?.localizedDescription)) :: MUST IMPLEMENT ERROR HANDLER")
                self.cancel()
            } else {
                if let ckRecordZones = ckRecordZones {
                    for zone in ckRecordZones {
                        let zoneName = zone.zoneID.zoneName
                        if zoneName != "_defaultZone" {
                            //TODO: Implement multiple zone options for possible future use.
                            UserSettings.shared.currentZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
                            return
                        }
                    }
                }
                self.operationCompletionHandler()
            }
        }
    }
}

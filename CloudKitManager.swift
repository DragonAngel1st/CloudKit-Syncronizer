	//
//  CloudKitConfiguration.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2017-08-02.
//  Copyright © 2017 Patrick Miron. All rights reserved.
//

import CloudKit
import CoreData
import UIKit

//MARK:- CloudKitManager Enums
enum DatabaseOwnership: String, Codable {
    case owner = "owner"
    case participant = "participant"
    case unowned = "unowned"
}

//MARK:- private instance of cloudkitmanager.
private let _cloudKitManager = CloudKitManager()

//MARK:- CloudKitManager Class
    class CloudKitManager: NSObject {
        //MARK:- SHARED INSTANCE
        class var shared : CloudKitManager {
            return _cloudKitManager
        }
        var currentZoneID = UserSettings.shared.currentZoneID
        var currentUserDB = UserSettings.shared.currentUserDB
        let demoZone = CKRecordZone.ID(zoneName: "demoZone", ownerName: CKCurrentUserDefaultName)

        override init() {
            super.init()
            //        Settings.shared.delegate = self
            //      signInToCloudKit()
        }

        func setupCompanyProfile(companyName: String, locationName: String) {
//            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
//            context.parent = CoreDataManager.shared.context
            let context = CoreDataManager.shared.context
            let newZoneID = CKRecordZone.ID(zoneName: companyName, ownerName: CKCurrentUserDefaultName)
            print(":: NEW ZONE OPERATION :: zoneID WILL BE: \(newZoneID) with ZoneName: \(newZoneID.zoneName) ::")
            let ckDatabase = CKContainer.default().privateCloudDatabase
            UserSettings.shared.currentUserDB = ckDatabase
            let newQueue = OperationQueue.main
            newQueue.isSuspended = true
            newQueue.maxConcurrentOperationCount = 1
            newQueue.qualityOfService = .userInitiated

            //        let newCloudKitOperationGroup = GroupOperation { (result) in
            //            //CompletionHandler
            //        }
            //        newCloudKitOperationGroup.internalQueue.maxConcurrentOperationCount = 1

            //        let loginOp = CloudKitSignInOperation { (result) in
            //            //completionHandler
            //            if result == .succeeded {
            //                DispatchQueue.main.async {
            //                    print()
            //                    print("CloudKitSignInOperation succeeded")
            //                    print()
            //                }
            //            } else {
            //                newQueue.cancelAllOperations()
            //            }
            //        }
            //        newQueue.addOperation(loginOp)

            let createNewCompanyZoneOp = CreateCustomZoneOperation(withZoneId: newZoneID, ckDatabse: ckDatabase) { (result) in
                //CompletionHandler for this op
                if result == SuccessResult.succeeded {
                    UserSettings.shared.customZoneCreated = true
                    UserSettings.shared.currentZoneID = newZoneID
                    UserSettings.shared.databaseOwnership = .owner
                } else {
                    newQueue.cancelAllOperations()
                }
            }

            //Create CKShare access pyramid for share parents
            let newAccessLevel = AccessLevel(context: context)
            let newAccountingAccess = AccountingAccessLevel(context: context)
            let newWebAccess = WebAccessLevel(context: context)
            let newAdminAccess = AdministrationAccessLevel(context: context)
            let newEmployeeAccess = EmployeeAccessLevel(context: context)
            let newAccessType = AccessType(context:  context)
            newAccessLevel.accountingAccess = newAccountingAccess
            newAccessLevel.admininistrationAccess = newAdminAccess
            newAccessLevel.employeeAccess = newEmployeeAccess
            newAccessLevel.webAccess = newWebAccess
            newAccessLevel.type = newAccessType
            newAccessType.name = "CKShare Access Type"
            //Create New Company records
            let newCompany = Company(context: context)
            let newLocation = BusinessLocation(context: context)
            newLocation.accessParent = newCompany
            newCompany.name = companyName
            newCompany.accessParent = newAccountingAccess
            newLocation.name = locationName

            //Save to Core Data then Sync to the Cloud
//            let managedObjectWithCKRecordsToModify = Array(Set( context.updatedObjects.compactMap { ($0) } + context.insertedObjects.compactMap { ($0) }))
//            let managedObjectWithCKRecordsToDelete = context.deletedObjects.compactMap { $0.getCKRecord()?.recordID }
            let saveManagedObjectsOp = SaveManagedObjectsToCoreDataOperation(context: context, zoneID: newZoneID) { (result) in
                //CompletionHandler
                if result == .succeeded {

                } else {
                    newQueue.cancelAllOperations()
                }
            }
            saveManagedObjectsOp.addDependency(createNewCompanyZoneOp)
            //        newQueue.addOperation(saveManagedObjectsOp)

            let modifyCloudKitRecordsOp = ModifyCloudKitRecordsOperation(zoneID: newZoneID, ckDatabase: ckDatabase) { (result) in
                //CompletionHandler
                if result == .succeeded {

                } else {
                    newQueue.cancelAllOperations()
                }
            }

            modifyCloudKitRecordsOp.addDependency(saveManagedObjectsOp)
            //       newQueue.addOperation(modifyCloudKitRecordsOp)

            let updateCoreDataObjectsWithEncodedSystemsFieldsOp = SaveCKEncodedSystemFieldsFromCKRecordsOperation(context: context) { (result) in
                //CompletionHandler
                if result == .succeeded {
                    UserSettings.shared.topSharedAccessRecordsCreated = true
                } else {
                    newQueue.cancelAllOperations()
                }
            }
            updateCoreDataObjectsWithEncodedSystemsFieldsOp.addDependency(modifyCloudKitRecordsOp)

            let subscribeToPrivateDatabaseChangesOp = SubscribeToDatabaseChangesOperation(ckDatabase: ckDatabase) { (result) in
                //CompletionHandler for this op
                if result == .succeeded {
                    UserSettings.shared.subscribedToPrivateChanges = true
                } else {
                    newQueue.cancelAllOperations()
                }

            }
            subscribeToPrivateDatabaseChangesOp.addDependency(updateCoreDataObjectsWithEncodedSystemsFieldsOp)
            newQueue.addOperations([createNewCompanyZoneOp,saveManagedObjectsOp,modifyCloudKitRecordsOp,updateCoreDataObjectsWithEncodedSystemsFieldsOp,subscribeToPrivateDatabaseChangesOp], waitUntilFinished: false)
            newQueue.isSuspended = false
        }
        func fetchChangesForCurrentCKDatabase(database: CKDatabase, completionHandler: ((SuccessResult) -> ())?) {
            let _ = CloudKitFetchAllCKDatabaseChangesGroupOperation(ckDatabase: database, zoneID: UserSettings.shared.currentZoneID!) { (result) in
                if result == .succeeded {
//                    DispatchQueue.main.async {
//                        print()
//                        print(":: CloudKitFetchAllCKDatabaseChangesOperation :: Succeeded")
//                        print()
//
//                    }
                } else {
//                    DispatchQueue.main.async {
//                        print()
//                        print(":: CloudKitFetchAllCKDatabaseChangesOperation :: Failed")
//                        print()
//
//                    }
                }
            }
        }
    }
/*MARK:- NO LONGER USED FUNCTIONS - USED THE OPERATIONS in CloudKitOperations and CoreDataOperations.
// Async Fetch Functions
//Help on implementing cloudkit error handler -> errorHandling for CloudKitManager for all operations. See https://developer.apple.com/library/content/samplecode/CloudKitShare/Listings/CloudShares_CloudKitError_swift.html
    //Fetch database changes switching on scope.
    func fetchChangesIn(databaseScope: CKDatabaseScope, completion: @escaping () -> Void) {
        switch databaseScope {
        case .private:
            fetchDatabaseChanges(ckDatabase: self.privateDB, localChangeToken: CloudKitSettings.shared.localPrivateDatabaseChangeToken , completion: completion)
        case .shared:
//            print("trying to fetch changes in sharedDB")
            fetchDatabaseChanges(ckDatabase: self.sharedDB, localChangeToken: CloudKitSettings.shared.localSharedDatabaseChangeToken, completion: completion)
        case .public:
            fatalError("ELDERSOFT_ERROR Fetch: Database Changes for a Pubic database is not implemented. Public database will only be used for web services public data at the moment")
        }
    }

    func fetchDatabaseChanges(ckDatabase: CKDatabase, localChangeToken: CKServerChangeToken?, completion: @escaping () -> Void) {
        var changedZoneIDs: [CKRecordZoneID] = []
        var deletedZoneIDs: [CKRecordZoneID] = []
        var localChangeToken: CKServerChangeToken? = localChangeToken
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: localChangeToken)

        operation.recordZoneWithIDChangedBlock = { (zoneID) in
            changedZoneIDs.append(zoneID)
            //print("--- recordZoneWithIDChangedBlock called.---")
            //print("Write this zone has changed to memory: \(currentZoneID)")
        }
        operation.recordZoneWithIDWasDeletedBlock = { (zoneID) in
            //print("--- recordZoneWithIDWasDeletedBlock called.---")
            //print("Write this zone: \(currentZoneID) deletion to memory")
            deletedZoneIDs.append(zoneID)
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

        //There should not be any zone changes once production is set. At the moment, the only zone will be MainZone.
        operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
            if let error = error {
                _ = CloudKitError.shared.handle(error: error, operation: .fetchChanges)
                completion()
                return
            }
            if !changedZoneIDs.isEmpty {
                saveChangeTokenFor(ckDatabase: ckDatabase, changeToken: token)
                self.fetchZoneChanges(ckDatabase: ckDatabase, zoneIDs: changedZoneIDs) {
                    print("...Flush in-memory database change token to disk")
                    saveChangeTokenFor(ckDatabase: ckDatabase, changeToken: token)
                }
            }
            completion()
            if moreComing {
                            print("*****--- moreComing ---> \(moreComing) ----*****")
            }
        }
        ckDatabase.add(operation)
        func saveChangeTokenFor(ckDatabase: CKDatabase, changeToken: CKServerChangeToken?) {
            switch ckDatabase.databaseScope {
            case .private:
                CloudKitSettings.shared.localPrivateDatabaseChangeToken = changeToken
                print("PRIVATE database token was updated")
            case .shared:
                CloudKitSettings.shared.localSharedDatabaseChangeToken = changeToken
                                print("SHARED database token was updated")
            case .public:
                CloudKitSettings.shared.localPublicDatabaseChangeToken = changeToken
                                print("PUBLIC database token was updated")
            }
        }
    }

    func fetchZoneChanges(ckDatabase: CKDatabase, zoneIDs: [CKRecordZoneID], completionHandler: @escaping () -> Void) {
        var ckRecordsChanged: [CKRecord] = []
        var ckRecordIDsDeleted: [(CKRecordID, String)] = []
        var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs, optionsByRecordZoneID: optionsByRecordZoneID)

        for zoneID in zoneIDs {
            let options = CKFetchRecordZoneChangesOptions()
            let _localChangeToken = getLocalChangeTokenForZoneID(zoneID)
            options.previousServerChangeToken = _localChangeToken
            optionsByRecordZoneID[zoneID] = options
        }
        operation.recordChangedBlock = { (record) in
            ckRecordsChanged.append(record)
        }

        operation.recordWithIDWasDeletedBlock = { (recordId, recordType) in
//            print("Some string is also reported by recordWithIDWasDeletedBlock: \(recordType)")
            //Write this record deletion to memory
            ckRecordIDsDeleted.append((recordId, recordType))
        }
        // Only do .recordZoneChangeTokensUpdatedBlock or .recordZoneFetchCompletionBlock.
        // Both operations do the same thing.
        /*
        operation.recordZoneChangeTokensUpdatedBlock = { (currentZoneID, newChangeToken, data) in
            print("--- recordZoneChangeTokensUpdatedBlock was called. ---")
            //Flush all records to memory
            for recordID in recordIDsDeleted {
                print("This record is to be deleted: \(recordID)")
            }
            for record in recordsChanged {
                print("This records is to be updated: \(record.recordID) with recordType: \(record.recordType)")
            }
            //Write new zone token change to disk
            print("Here is the new zone token change to be written to disk: \(String(describing: newChangeToken))")
            print("")
            saveLocalChangeTokenForZoneID(currentZoneID, newChangeToken: newChangeToken)
        }
        */
        operation.recordZoneFetchCompletionBlock = { (zoneID, newChangeToken, _, _, error) in
            //print("--- recordZoneFetchCompletionBlock was called. ---")
            if let error = error {
                    _ = CloudKitError.shared.handle(error: error, operation: .fetchZones)
                return
            }
            //Flush record changes and deletions for this zone to disk
            //MARK: TO IMPLEMENT
            //  have this function call throw an error if it does not succeed to prevent the changeToken to be updated.
            if !ckRecordsChanged.isEmpty || !ckRecordIDsDeleted.isEmpty {
                let modifyOrCreateManagedObjectsOp = SaveCKRecordsToCoreDataOperation(ckRecordsWithChanges: ckRecordsChanged, ckRecordIDsDeleted: ckRecordIDsDeleted, completionHandler: { (result) in
                    saveLocalChangeTokenFor(zoneID, newChangeToken: newChangeToken)
                })
            }
        }
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            if let error = error {
                _ = CloudKitError.shared.handle(error: error, operation: .fetchRecords)
                return
            }
            completionHandler()
        }
        ckDatabase.add(operation)

        func saveLocalChangeTokenFor(_ recordZoneID: CKRecordZoneID, newChangeToken: CKServerChangeToken?) {
            if let currentZoneID = currentZoneID {
                switch currentZoneID.zoneName {
                case "MainZone":
                    CloudKitSettings.shared.localPrivateDatabaseZoneChangeToken = newChangeToken
                default:
                    CloudKitSettings.shared.localSharedDatabaseZoneChangeToken = newChangeToken
                }
            }
        }
    }

    func getLocalChangeTokenForZoneID(_ recordZoneID: CKRecordZoneID) -> CKServerChangeToken? {
        if let currentZoneID = currentZoneID {
            switch currentZoneID.zoneName {
            case "MainZone":
                return CloudKitSettings.shared.localPrivateDatabaseZoneChangeToken
            default:
                return CloudKitSettings.shared.localSharedDatabaseZoneChangeToken
            }
        }
        return nil
    }

    //MARK:- SUBSCRIBING TO CHANGES
    func subcribeToChangesOf(database: CKDatabase, subscriptionID: String, completionHandler: @escaping () -> Void) {
        let createSubscriptionOperation = self.createDatabaseSubscriptionOperation(subscriptionID: subscriptionID)
        createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deleteIds, error) in
            guard CloudKitError.shared.handle(error: error, operation: .modifySubscriptions, alert: true) == nil
            else {
                return
            }
        database.add(createSubscriptionOperation)
        }
    }

    func subcribeToChangesOf(completionHandler: @escaping () -> Void) {
        switch CloudKitSettings.shared.databaseOwnership {
        case .owner:
            subcribeToChangesOf(database: self.privateDB, subscriptionID: "privateDBSubscription", completionHandler: completionHandler)
        case .participant:
            subcribeToChangesOf(database: self.sharedDB, subscriptionID: "sharedDBSubscription", completionHandler: completionHandler)
        case .unowned:
            //MARK:- TO IMPLEMENT
            return
        }
    }

    func createDatabaseSubscriptionOperation(subscriptionID: String) -> CKModifySubscriptionsOperation {
        print("Creating a CKModifisubscriptionsOperations")
        let subscription = CKDatabaseSubscription.init(subscriptionID: subscriptionID)

        let notificationInfo = CKNotificationInfo()

        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        operation.qualityOfService = .utility

        return operation

    }

//    //Call this func before segueing (after each page changes)
//    class func saveToCloudKit() {
////        if !CloudKitManager.shared.cloudKitManagedObjectsToModify.isEmpty || !CloudKitManager.shared.ckRecordIDsToDelete.isEmpty {
////            CloudKitManager.shared.modifyCloudKitCKRecordsWith(modifiedCloudKitManagedObjects: CloudKitManager.shared.cloudKitManagedObjectsToModify, ckRecordIDsToDelete: CloudKitManager.shared.ckRecordIDsToDelete) {
////                //Completion block
////                CloudKitManager.shared.ckRecordIDsToDelete.removeAll()
////                CloudKitManager.shared.cloudKitManagedObjectsToModify.removeAll()
////            }
////        }
//    }
     */

    //MARK:- END OF LINE
//END OF FILE

////
////  CloudKitSettings.swift
////  ElderSoft
////
////  Created by Patrick Miron on 2018-07-13.
////  Copyright © 2018 Patrick Miron. All rights reserved.
////
//
//import UIKit
//import CloudKit
//
//
////MARK:- CloudKitSettings CLASS
//private let _cloudKitSettings = CloudKitSettings()
//
////MARK: delegate protocol for CloudKitSettings
//protocol CloudKitSettingsDelegate {
//    func cloudKitSettingsChanged()
//}
//
//class CloudKitSettings: NSObject {
//
//    //MARK: Variables
//    internal class var shared : CloudKitSettings {
//        return _cloudKitSettings
//    }
//    var delegate: CloudKitSettingsDelegate?
//
//    private let cloudKitSettingsKey = "cloudKitSettings"
//    private let defaultCloudKitSettings: Dictionary  = [
//        //"newKey" : "newValue",
//        "localPublicDatabaseChangeToken" : "",
//        "localPrivateDatabaseChangeToken" : "",
//        "localSharedDatabaseChangeToken" : "",
//        "localPrivateDatabaseZoneChangeToken" : "",
//        "localSharedDatabaseZoneChangeToken" : "",
//        "localPublicDatabaseZoneChangeToken" : "",
//        "createdCustomZone" : false,
////        "currentZoneID": "",
//        "devicelsCompletelySetupForCloudKitSync" : false,
//        "subscribedToSharedChanges" : false,
//        "subscribedToPrivateChanges" : false,
//        "ckUserRecordID" : "",
//        "databaseOwnership" : "unowned",
//        "createdCompanyProfile" : false,
//        "createdTopSharedAccessRecords" : false
//        ] as [String : Any]
//
//    private var userCloudKitSettings: Dictionary<String, Any> {
//        get {
//            if let _cloudSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return _cloudSettings
//            } else {
//                UserDefaults.standard.set(defaultCloudKitSettings, forKey: cloudKitSettingsKey)
//                return UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey)!
//            }
//        }
//        set {
//            UserDefaults.standard.set(newValue, forKey: cloudKitSettingsKey)
//            UserDefaults.standard.synchronize()
//        }
//    }
//
//    //MARK: INIT
//    override init() {
//        // Check to see if UserDefaults has an object for cloudKitSettings
//        if var userCloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//            // Verify that UserDefaults cloudKitSetting dictionary contains each key in the defaultCloudKitSettings,
//            //    if not insert it in the UserDefaults cloudKittSetting.
//            for settingKey in defaultCloudKitSettings.keys {
//                //if the setting is not in userDefaultsCloudKitSettings, then create a key with its default value
//                if !userCloudKitSettings.contains(where: { $0.key == settingKey}) {
//                    userCloudKitSettings[settingKey] = defaultCloudKitSettings[settingKey]
//                }
//            }
//            //Clean up key that are no longer used in UserDefaults
//            for settingKey in userCloudKitSettings.keys {
//                if !defaultCloudKitSettings.contains(where: { $0.key == settingKey}) {
//                    userCloudKitSettings.removeValue(forKey: settingKey)
//                }
//            }
//            UserDefaults.standard.set(userCloudKitSettings, forKey: cloudKitSettingsKey)
//        }
//        else {
//            UserDefaults.standard.set(defaultCloudKitSettings, forKey: cloudKitSettingsKey)
//        }
//        UserDefaults.standard.synchronize()
//        super.init()
//    }
//
//    //MARK: UserDefaults for CloudKit Dictionary access
//    var createdCustomZone: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["createdCustomZone"] as! Bool)
//            }
//            return false
//        }
//        set {
//
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "createdCustomZone")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                print(" &&& Changing CLOUDKITSETTINGS createdCostomZone to:\(newValue) &&&")
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//    var createdCompanyProfile: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["createdCompanyProfile"] as! Bool)
//            }
//            return false
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "createdCompanyProfile")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                print(" &&& Changing CLOUDKITSETTINGS createdCompanyProfile to:\(newValue) &&&")
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//
////    var createdInitialLoginZone: Bool {
////        get {
////            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
////                return (cloudKitSettings["createdInitialLoginZone"] as! Bool)
////            }
////            return false
////        }
////        set {
////            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
////                cloudKitSettings.updateValue(newValue, forKey: "createdInitialLoginZone")
////                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
////                UserDefaults.standard.synchronize()
////            }
////        }
////    }
//
// //        get {
////            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
////                if let myZoneIDString = cloudKitSettings["currentZoneID"] as? String {
////                    return CKRecordZoneID(zoneName: myZoneIDString, ownerName: CKCurrentUserDefaultName)
////                }
////            }
////            //Set the default Record Zone to be "demoZone" as to reduce security risk
////            return CKRecordZoneID(zoneName: "demoZone", ownerName: CKCurrentUserDefaultName)
////        }
////        set {
////            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
////                cloudKitSettings.updateValue(newValue.zoneName, forKey: "currentZoneID")
////                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
////                print(" &&& Changing CLOUDKITSETTINGS currentZoneID to:\(newValue) &&&")
////                UserDefaults.standard.synchronize()
////            }
////        }
////    }
//
//
//    var subscribedToSharedChanges: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["subscribedToSharedChanges"] as! Bool)
//            }
//            return false
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "subscribedToSharedChanges")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//
//            }
//        }
//    }
//
//    var subscribedToPrivateChanges: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["subscribedToPrivateChanges"] as! Bool)
//            }
//            return false
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "subscribedToPrivateChanges")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//
//            }
//        }
//    }
//    var localPublicDatabaseChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localPublicDatabaseChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localPublicDatabaseChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//
//            }
//        }
//    }
//
//    var localPrivateDatabaseChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localPrivateDatabaseChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localPrivateDatabaseChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//
//            }
//        }
//    }
//
//    var localSharedDatabaseChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localSharedDatabaseChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localSharedDatabaseChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//    var localPublicDatabaseZoneChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localPublicDatabaseZoneChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localPublicDatabaseZoneChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//
//
//    var localPrivateDatabaseZoneChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localPrivateDatabaseZoneChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localPrivateDatabaseZoneChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//
//    var localSharedDatabaseZoneChangeToken: CKServerChangeToken? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let encodedObjectData = (cloudKitSettings["localSharedDatabaseZoneChangeToken"]) as? Data {
//                    return NSKeyedUnarchiver.unarchiveObject(with: encodedObjectData as Data) as? CKServerChangeToken
//                }
//            }
//            return nil
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(NSKeyedArchiver.archivedData(withRootObject: newValue!), forKey: "localSharedDatabaseZoneChangeToken")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//
//    var databaseOwnership: DatabaseOwnership {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let databaseOwnershipRawValue = (cloudKitSettings["databaseOwnership"] as? String) {
//                    if let databaseOwnership = DatabaseOwnership(rawValue: databaseOwnershipRawValue) {
//                        return databaseOwnership
//                    }
//                }
//            }
//            // Default to .unowned
//            return DatabaseOwnership.unowned
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue.rawValue, forKey: "databaseOwnership")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//                delegate?.cloudKitSettingsChanged()
//            }
//        }
//    }
//    var ckUserRecordName: String? {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let ckUserRecordID = cloudKitSettings["ckUserRecordID"] as? String {
//                    return ckUserRecordID
//                }
//            }
//            //Set the default Record Zone to be "initialLoginZone" as to reduce security risk
//            return ""
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                if let newValue = newValue {
//                    cloudKitSettings.updateValue(newValue, forKey: "ckUserRecordID")
//                    UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                    UserDefaults.standard.synchronize()
//                    delegate?.cloudKitSettingsChanged()
//                }
//            }
//        }
//    }
//
//    var createdTopSharedAccessRecords: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["createdTopSharedAccessRecords"] as! Bool)
//            }
//            return false
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "createdTopSharedAccessRecords")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//                delegate?.cloudKitSettingsChanged()
//            }
//        }
//    }
//    var devicelsCompletelySetupForCloudKitSync: Bool {
//        get {
//            if let cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                return (cloudKitSettings["devicelsCompletelySetupForCloudKitSync"] as! Bool)
//            }
//            return false
//        }
//        set {
//            if var cloudKitSettings = UserDefaults.standard.dictionary(forKey: cloudKitSettingsKey) {
//                cloudKitSettings.updateValue(newValue, forKey: "devicelsCompletelySetupForCloudKitSync")
//                UserDefaults.standard.set(cloudKitSettings, forKey: cloudKitSettingsKey)
//                UserDefaults.standard.synchronize()
//            }
//        }
//    }
//    //    func userSettingsChanged(objectName: String) {
//    //        switch objectName {
//    //        case "zoneName":
//    //            currentZoneID = CKRecordZoneID(zoneName: UserSettingsManager.shared.zoneName, ownerName: CKCurrentUserDefaultName)
//    //        case "databaseOwnership":
//    //            databaseOwnership = UserSettingsManager.shared.databaseOwnership
//    //        default:
//    //            return
//    //        }
//    //    }
//}
////END OF LINE
////END OF FILE
//

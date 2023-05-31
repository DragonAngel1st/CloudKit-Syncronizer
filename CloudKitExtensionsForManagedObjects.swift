//
//  CloudKitExtensionsForManagedObjects.swift
//  ElderSoft
//
//  Created by Patrick Miron on 2018-07-13.
//  Copyright © 2018 Patrick Miron. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

// All NSManagedObjects are extended with CloutKit extensions.
extension NSManagedObject: CloudKitExtensionsForNSManagedObjects {
    @NSManaged public var ckRecordName: String?
    @NSManaged public var ckEncodedSystemFields: NSData?
}

//MARK:- PROTOCOL CloudKitExtgensionsForNSManagedObjects
//    for all NSManagedObjects that will be synced to cloudkit
protocol CloudKitExtensionsForNSManagedObjects {
    var ckEncodedSystemFields: NSData? { get set }
    var ckRecordName: String? { get set }
}

//MARK:- CLOUDKIT MANAGED OBJECT
extension CloudKitExtensionsForNSManagedObjects where Self : NSManagedObject {
    func getCKRecord() -> CKRecord? {
        if self.ckEncodedSystemFields != nil {
            do {
                let decoder = try NSKeyedUnarchiver(forReadingFrom: (self.ckEncodedSystemFields! as Data))
            decoder.requiresSecureCoding = true
            let _ckRecord = CKRecord(coder: decoder)
            decoder.finishDecoding()
//            print("... CKRecord: \(String(describing: _ckRecord?.recordID.recordName))")
                return _ckRecord! }
            catch {
                print("Unable to get CKRecord ckEncodedSystemFielsd from NSManagedOjbect: ", self as NSManagedObject)
            }
        }
        return nil
    }

    func createCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordType = String(describing: self.entity.managedObjectClassName!)
        let ckRecord = CKRecord(recordType: recordType, zoneID: zoneID)
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        coder.requiresSecureCoding = true
        ckRecord.encodeSystemFields(with: coder)
        coder.finishEncoding()
        ckEncodedSystemFields = coder.encodedData as NSData
        ckRecordName = ckRecord.recordID.recordName
        return ckRecord
    }

    func setCKRecordFrom(_ ckRecord: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        ckRecord.encodeSystemFields(with: coder)
        coder.finishEncoding()
        ckEncodedSystemFields = coder.encodedData as NSData
        ckRecordName = ckRecord.recordID.recordName
    }
}

extension NSManagedObject {
    @NSManaged public var modifiedOn: NSDate?
}

import CoreData
import CloudKit

// Protocol for mapping between CoreData and CloudKit
protocol CloudKitRepresentable {
    var recordID: String? { get set }
    func toCKRecord() -> CKRecord
    static func fromCKRecord(_ record: CKRecord, context: NSManagedObjectContext) -> Self?
}

// Extension for UserEntity CloudKit mapping
extension UserEntity: CloudKitRepresentable {
    var recordID: String? {
        get { return self.recordIDValue }
        set { self.recordIDValue = newValue }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordIDValue ?? UUID().uuidString)
        let record = CKRecord(recordType: "UserEntity", recordID: recordID)
        
        record["email"] = self.email as CKRecordValue?
        record["displayName"] = self.displayName as CKRecordValue?
        record["timezone"] = self.timezone as CKRecordValue?
        
        // Handle avatar images
        if let avatarFullData = self.avatarFull {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? avatarFullData.write(to: url)
            record["avatarFull"] = CKAsset(fileURL: url)
        }
        
        if let avatarThumbData = self.avatarThumb {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? avatarThumbData.write(to: url)
            record["avatarThumb"] = CKAsset(fileURL: url)
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord, context: NSManagedObjectContext) -> Self? {
        guard let entity = UserEntity(context: context) as? Self else { return nil }
        (entity as UserEntity).recordIDValue = record.recordID.recordName
        (entity as UserEntity).email = record["email"] as? String
        (entity as UserEntity).displayName = record["displayName"] as? String
        (entity as UserEntity).timezone = record["timezone"] as? String
        
        // Handle avatar assets
        if let avatarFullAsset = record["avatarFull"] as? CKAsset, let url = avatarFullAsset.fileURL {
            entity.avatarFull = try? Data(contentsOf: url)
        }
        
        if let avatarThumbAsset = record["avatarThumb"] as? CKAsset, let url = avatarThumbAsset.fileURL {
            entity.avatarThumb = try? Data(contentsOf: url)
        }
        
        return entity
    }
}


// Extension for EventEntity CloudKit mapping
extension EventEntity: CloudKitRepresentable {
    var recordID: String? {
        get { return self.recordIDValue }
        set { self.recordIDValue = newValue }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordIDValue ?? UUID().uuidString)
        let record = CKRecord(recordType: "EventEntity", recordID: recordID)
        
        record["title"] = self.title as CKRecordValue?
        record["startDate"] = self.startDate as CKRecordValue?
        record["endDate"] = self.endDate as CKRecordValue?
        record["eventType"] = self.eventType as CKRecordValue?
        record["location"] = self.location as CKRecordValue?
        record["eventDescription"] = self.eventDescription as CKRecordValue?
        record["dayMask"] = self.dayMask as NSNumber
        
        // Set up reference to user
        if let userRecordID = self.userRef?.recordIDValue {
            let reference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: userRecordID),
                action: .deleteSelf
            )
            record["userRef"] = reference
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord, context: NSManagedObjectContext) -> Self? {
        guard let entity = EventEntity(context: context) as? Self else { return nil }
        (entity as EventEntity).recordIDValue = record.recordID.recordName
        (entity as EventEntity).title = record["title"] as? String
        (entity as EventEntity).startDate = record["startDate"] as? Date
        (entity as EventEntity).endDate = record["endDate"] as? Date
        (entity as EventEntity).eventType = record["eventType"] as? String
        (entity as EventEntity).location = record["location"] as? String
        (entity as EventEntity).eventDescription = record["eventDescription"] as? String
        (entity as EventEntity).dayMask = record["dayMask"] as? Int16 ?? 0
            
        
        // Handle user reference
        if let reference = record["userRef"] as? CKRecord.Reference {
            // Fetch or create user
            let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", reference.recordID.recordName)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let user = results.first {
                    (entity as EventEntity).userRef = user
                }
            } catch {
                print("Error fetching referenced user: \(error)")
            }
        }
        
        return entity
    }
}

// Extension for ReminderConfigEntity CloudKit mapping
extension ReminderConfigEntity: CloudKitRepresentable {
    var recordID: String? {
        get { return self.recordIDValue }
        set { self.recordIDValue = newValue }
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordIDValue ?? UUID().uuidString)
        let record = CKRecord(recordType: "ReminderConfigEntity", recordID: recordID)
        
        record["offsetMinutes"] = self.offsetMinutes as NSNumber
        record["mode"] = self.mode as CKRecordValue?
        
        // Set up reference to event
        if let eventRecordID = self.eventRef?.recordIDValue {
            let reference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: eventRecordID),
                action: .deleteSelf
            )
            record["eventRef"] = reference
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord, context: NSManagedObjectContext) -> Self? {
        guard let entity = ReminderConfigEntity(context: context) as? Self else { return nil }
        (entity as ReminderConfigEntity).recordIDValue = record.recordID.recordName
        (entity as ReminderConfigEntity).offsetMinutes = record["offsetMinutes"] as? Int16 ?? 0
        (entity as ReminderConfigEntity).mode = record["mode"] as? String
        
        // Handle event reference
        if let reference = record["eventRef"] as? CKRecord.Reference {
            // Fetch or create event
            let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", reference.recordID.recordName)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let event = results.first {
                    (entity as ReminderConfigEntity).eventRef = event
                }
            } catch {
                print("Error fetching referenced event: \(error)")
            }
        }
        
        return entity
    }
}

import CloudKit
import CoreData
import Combine
import UIKit

class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    
    private let container = CKContainer(identifier: "iCloud.com.MazharElstub.WeekendView")
    private var cancellables = Set<AnyCancellable>()
    
    // Authentication state
    private(set) var isAuthenticated = CurrentValueSubject<Bool, Never>(false)
    private(set) var currentUser = CurrentValueSubject<UserEntity?, Never>(nil)
    
    init() {
        checkCloudKitAvailability()
        fetchCurrentUser()
    }
    
    // Check if CloudKit is available
    private func checkCloudKitAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isAuthenticated.send(true)
                    self?.fetchUserRecord()
                default:
                    self?.isAuthenticated.send(false)
                }
            }
        }
    }
    
    // Fetch current user from CloudKit
    private func fetchUserRecord() {
        container.fetchUserRecordID { [weak self] recordID, error in
            guard let recordID = recordID, error == nil else {
                print("Error fetching user record ID: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let operation = CKFetchRecordsOperation(recordIDs: [recordID])
            operation.perRecordResultBlock = { recordID, result in
                switch result {
                case .success(let record):
                    DispatchQueue.main.async {
                        self?.createOrUpdateUserEntity(with: record)
                    }
                case .failure(let error):
                    print("Error fetching user record: \(error.localizedDescription)")
                }
            }
            
            operation.fetchRecordsResultBlock = { result in
                if case .failure(let error) = result {
                    print("Error in fetch operation: \(error.localizedDescription)")
                }
            }
            
            self?.container.privateCloudDatabase.add(operation)
        }
    }
    
    // Create or update user entity in CoreData
    private func createOrUpdateUserEntity(with record: CKRecord) {
        let context = PersistenceController.shared.container.viewContext
        
        // Check if user already exists
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", record.recordID.recordName)
        
        do {
            let results = try context.fetch(fetchRequest)
            let user: UserEntity
            
            if let existingUser = results.first {
                user = existingUser
            } else {
                user = UserEntity(context: context)
                user.recordIDValue = record.recordID.recordName
            }
            
            // Update user properties from record if needed
            if user.email == nil || user.displayName == nil {
                
                if user.email == nil {
                    user.email = "user@example.com" // Default placeholder
                }
                
                if user.displayName == nil {
                    user.displayName = "User" // Default placeholder
                }
                
                if user.timezone == nil {
                    user.timezone = TimeZone.current.identifier
                }
                
                try? context.save()
                self.currentUser.send(user)
            } else {
                self.currentUser.send(user)
            }
        } catch {
            print("Error creating/updating user entity: \(error)")
        }
    }
    
    // Fetch current user from CoreData
    private func fetchCurrentUser() {
        self.currentUser.send(PersistenceController.shared.fetchCurrentUser())
    }
    
    // Save user profile
    func saveUserProfile(displayName: String, avatar: UIImage?) {
        let context = PersistenceController.shared.newBackgroundContext()
        
        context.perform {
            guard let user = self.currentUser.value else { return }
            
            // Fetch the user entity in the background context
            let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", user.recordIDValue ?? "")
            
            do {
                let results = try context.fetch(fetchRequest)
                guard let userInContext = results.first else { return }
                
                // Update user properties
                userInContext.displayName = displayName
                
                // Process avatar if provided
                if let avatar = avatar {
                    // Create full-size avatar (1024x1024)
                    if let fullImage = avatar.resized(to: CGSize(width: 1024, height: 1024)),
                       let fullData = fullImage.jpegData(compressionQuality: 0.8) {
                        userInContext.avatarFull = fullData
                    }
                    
                    // Create thumbnail (100x100)
                    if let thumbImage = avatar.resized(to: CGSize(width: 100, height: 100)),
                       let thumbData = thumbImage.jpegData(compressionQuality: 0.7) {
                        userInContext.avatarThumb = thumbData
                    }
                }
                
                try context.save()
                
                // Sync to CloudKit
                self.syncUserToCloudKit(userInContext)
                
                // Update the published value on main thread
                DispatchQueue.main.async {
                    self.fetchCurrentUser()
                }
            } catch {
                print("Error saving user profile: \(error)")
            }
        }
    }
    
    // MARK: - Event Operations
    
    // Fetch events for a specific weekend
    func fetchEvents(forWeekend startDate: Date, endDate: Date) -> AnyPublisher<[EventEntity], Error> {
        let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        
        // Events that overlap with the weekend
        fetchRequest.predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", 
                                            endDate as NSDate, 
                                            startDate as NSDate)
        
        return Future<[EventEntity], Error> { promise in
            let context = PersistenceController.shared.container.viewContext
            
            do {
                let events = try context.fetch(fetchRequest)
                promise(.success(events))
                
                // Also sync from CloudKit
                self.syncEventsFromCloudKit(startDate: startDate, endDate: endDate)
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Create a new event
    func createEvent(title: String, startDate: Date, endDate: Date, 
                    eventType: String, location: String, 
                    description: String, dayMask: Int16,
                    reminderOffset: Int16?, reminderMode: String?) -> AnyPublisher<EventEntity, Error> {
        
        return Future<EventEntity, Error> { promise in
            let context = PersistenceController.shared.newBackgroundContext()
            
            context.perform {
                guard let user = self.currentUser.value else {
                    promise(.failure(NSError(domain: "CloudKitSyncManager", code: 100, userInfo: [NSLocalizedDescriptionKey: "No current user"])))
                    return
                }
                
                // Fetch the user entity in the background context
                let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", user.recordIDValue ?? "")
                
                do {
                    let results = try context.fetch(fetchRequest)
                    guard let userInContext = results.first else {
                        throw NSError(domain: "CloudKitSyncManager", code: 101, userInfo: [NSLocalizedDescriptionKey: "User not found in context"])
                    }
                    
                    // Create new event
                    let event = EventEntity(context: context)
                    event.recordIDValue = UUID().uuidString
                    event.title = title
                    event.startDate = startDate
                    event.endDate = endDate
                    event.eventType = eventType
                    event.location = location
                    event.eventDescription = description
                    event.dayMask = dayMask
                    event.userRef = userInContext
                    
                    // Create reminder configuration if needed
                    if let reminderOffset = reminderOffset, let reminderMode = reminderMode {
                        let reminder = ReminderConfigEntity(context: context)
                        reminder.recordIDValue = UUID().uuidString
                        reminder.offsetMinutes = reminderOffset
                        reminder.mode = reminderMode
                        reminder.eventRef = event
                    }
                    
                    try context.save()
                    
                    // Sync to CloudKit
                    self.syncEventToCloudKit(event)
                    
                    // Return the created event on the main thread
                    DispatchQueue.main.async {
                        // Fetch the created event in the main context
                        let mainContext = PersistenceController.shared.container.viewContext
                        let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", event.recordIDValue ?? "")
                        
                        do {
                            let results = try mainContext.fetch(fetchRequest)
                            if let mainContextEvent = results.first {
                                promise(.success(mainContextEvent))
                            } else {
                                throw NSError(domain: "CloudKitSyncManager", code: 102, userInfo: [NSLocalizedDescriptionKey: "Event not found in main context"])
                            }
                        } catch {
                            promise(.failure(error))
                        }
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - CloudKit Sync Operations
    
    // Sync user to CloudKit
    private func syncUserToCloudKit(_ user: UserEntity) {
        guard let record = (user as CloudKitRepresentable).toCKRecord() else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                print("Successfully saved user record to CloudKit")
            case .failure(let error):
                print("Error saving user record to CloudKit: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
    
    // Sync event to CloudKit
    private func syncEventToCloudKit(_ event: EventEntity) {
        guard let record = (event as CloudKitRepresentable).toCKRecord() else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                print("Successfully saved event record to CloudKit")
                
                // If event has a reminder config, sync that too
                if let reminderConfig = event.reminderConfig, 
                   let reminderRecord = (reminderConfig as CloudKitRepresentable).toCKRecord() {
                    self.syncReminderConfigToCloudKit(reminderConfig)
                }
            case .failure(let error):
                print("Error saving event record to CloudKit: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
    
    // Sync reminder config to CloudKit
    private func syncReminderConfigToCloudKit(_ reminderConfig: ReminderConfigEntity) {
        guard let record = (reminderConfig as CloudKitRepresentable).toCKRecord() else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                print("Successfully saved reminder config record to CloudKit")
            case .failure(let error):
                print("Error saving reminder config record to CloudKit: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
    
    // Sync weekend to CloudKit
    private func syncWeekendToCloudKit(_ weekend: WeekendEntity) {
        guard let record = (weekend as CloudKitRepresentable).toCKRecord() else { return }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                print("Successfully saved weekend record to CloudKit")
            case .failure(let error):
                print("Error saving weekend record to CloudKit: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
    
    // Sync from CloudKit for events
    private func syncEventsFromCloudKit(startDate: Date, endDate: Date) {
        let predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", 
                                   endDate as NSDate, 
                                   startDate as NSDate)
        
        let query = CKQuery(recordType: "Event", predicate: predicate)
        
        let operation = CKQueryOperation(query: query)
        
        var fetchedRecords = [CKRecord]()
        
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                print("Error fetching record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.importCloudKitRecords(fetchedRecords)
                }
            case .failure(let error):
                print("Error performing query: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
    
    // Import CloudKit records to Core Data
    private func importCloudKitRecords(_ records: [CKRecord]) {
        let context = PersistenceController.shared.newBackgroundContext()
        
        context.perform {
            for record in records {
                switch record.recordType {
                case "Event":
                    self.importEventRecord(record, context: context)
                case "UserProfile":
                    self.importUserProfileRecord(record, context: context)
                case "Users":
                    self.importUsersRecord(record, context: context)
                case "Weekend":
                    self.importWeekendRecord(record, context: context)
                default:
                    break
                }
            }
            
            try? context.save()
        }
    }
    
    private func importEventRecord(_ record: CKRecord, context: NSManagedObjectContext) {
        // Check if event already exists
        let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", record.recordID.recordName)
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let existingEvent = results.first {
                // Update existing event
                if let updatedEvent = EventEntity.fromCKRecord(record, context: context) {
                    // Copy properties from updated event to existing event
                    existingEvent.title = updatedEvent.title
                    existingEvent.startDate = updatedEvent.startDate
                    existingEvent.endDate = updatedEvent.endDate
                    existingEvent.eventType = updatedEvent.eventType
                    existingEvent.location = updatedEvent.location
                    existingEvent.eventDescription = updatedEvent.eventDescription
                    existingEvent.dayMask = updatedEvent.dayMask
                    
                    // Delete the temporary updated event
                    context.delete(updatedEvent)
                }
            } else {
                // Create new event
                _ = EventEntity.fromCKRecord(record, context: context)
            }
        } catch {
            print("Error importing event record: \(error)")
        }
    }
    
    private func importUserProfileRecord(_ record: CKRecord, context: NSManagedObjectContext) {
        // Implement user profile import
        // This would be similar to the event import method above
    }
    
    private func importUsersRecord(_ record: CKRecord, context: NSManagedObjectContext) {
        // Implement users import
    }
    
    private func importWeekendRecord(_ record: CKRecord, context: NSManagedObjectContext) {
        // Implement weekend import
    }
    
    // MARK: - Helper Methods
    
    // Function to manually trigger sync
    func performFullSync() {
        // Sync all local data to CloudKit
        syncAllLocalDataToCloudKit()
        
        // Fetch all data from CloudKit
        fetchAllDataFromCloudKit()
    }
    
    private func syncAllLocalDataToCloudKit() {
        let context = PersistenceController.shared.container.viewContext
        
        // Sync all users
        let userFetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        if let users = try? context.fetch(userFetchRequest) {
            for user in users {
                syncUserToCloudKit(user)
            }
        }
        
        // Sync all events
        let eventFetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        if let events = try? context.fetch(eventFetchRequest) {
            for event in events {
                syncEventToCloudKit(event)
            }
        }
        
        // Sync all weekends
        let weekendFetchRequest: NSFetchRequest<WeekendEntity> = WeekendEntity.fetchRequest()
        if let weekends = try? context.fetch(weekendFetchRequest) {
            for weekend in weekends {
                syncWeekendToCloudKit(weekend)
            }
        }
    }
    
    private func fetchAllDataFromCloudKit() {
        // Fetch all record types from CloudKit
        fetchRecordsOfType("Event")
        fetchRecordsOfType("UserProfile")
        fetchRecordsOfType("Users")
        fetchRecordsOfType("Weekend")
    }
    
    private func fetchRecordsOfType(_ recordType: String) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        
        var fetchedRecords = [CKRecord]()
        
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                print("Error fetching \(recordType) record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.importCloudKitRecords(fetchedRecords)
                }
            case .failure(let error):
                print("Error performing \(recordType) query: \(error.localizedDescription)")
            }
        }
        
        container.privateCloudDatabase.add(operation)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

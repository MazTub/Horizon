import CloudKit
import CoreData
import Combine
import UIKit

class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    
    private let container = CKContainer(identifier: "iCloud.com.yourcompany.weekendplanner")
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
    
    // Update an existing event
    func updateEvent(event: EventEntity, title: String, startDate: Date, endDate: Date,
                     eventType: String, location: String, description: String, 
                     dayMask: Int16) -> AnyPublisher<EventEntity, Error> {
        
        return Future<EventEntity, Error> { promise in
            let context = PersistenceController.shared.newBackgroundContext()
            
            context.perform {
                // Fetch the event entity in the background context
                let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", event.recordIDValue ?? "")
                
                do {
                    let results = try context.fetch(fetchRequest)
                    guard let eventInContext = results.first else {
                        throw NSError(domain: "CloudKitSyncManager", code: 103, userInfo: [NSLocalizedDescriptionKey: "Event not found in context"])
                    }
                    
                    // Update event properties
                    eventInContext.title = title
                    eventInContext.startDate = startDate
                    eventInContext.endDate = endDate
                    eventInContext.eventType = eventType
                    eventInContext.location = location
                    eventInContext.eventDescription = description
                    eventInContext.dayMask = dayMask
                    
                    try context.save()
                    
                    // Return the updated event on the main thread
                    DispatchQueue.main.async {
                        // Fetch the updated event in the main context
                        let mainContext = PersistenceController.shared.container.viewContext
                        let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", event.recordIDValue ?? "")
                        
                        do {
                            let results = try mainContext.fetch(fetchRequest)
                            if let mainContextEvent = results.first {
                                promise(.success(mainContextEvent))
                            } else {
                                throw NSError(domain: "CloudKitSyncManager", code: 104, userInfo: [NSLocalizedDescriptionKey: "Updated event not found in main context"])
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
    
    // Delete an event
    func deleteEvent(event: EventEntity) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            let context = PersistenceController.shared.newBackgroundContext()
            
            context.perform {
                // Fetch the event entity in the background context
                let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", event.recordIDValue ?? "")
                
                do {
                    let results = try context.fetch(fetchRequest)
                    if let eventInContext = results.first {
                        context.delete(eventInContext)
                    }
                    
                    try context.save()
                    promise(.success(true))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Reminder Configuration
    
    // Update reminder configuration
    func updateReminderConfig(for event: EventEntity, offsetMinutes: Int16, mode: String) -> AnyPublisher<ReminderConfigEntity, Error> {
        return Future<ReminderConfigEntity, Error> { promise in
            let context = PersistenceController.shared.newBackgroundContext()
            
            context.perform {
                // Fetch the event entity in the background context
                let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", event.recordIDValue ?? "")
                
                do {
                    let results = try context.fetch(fetchRequest)
                    guard let eventInContext = results.first else {
                        throw NSError(domain: "CloudKitSyncManager", code: 105, userInfo: [NSLocalizedDescriptionKey: "Event not found in context"])
                    }
                    
                    // Check if reminder config exists
                    let reminderConfig: ReminderConfigEntity
                    
                    if let existingConfig = eventInContext.reminderConfig {
                        reminderConfig = existingConfig
                    } else {
                        reminderConfig = ReminderConfigEntity(context: context)
                        reminderConfig.recordIDValue = UUID().uuidString
                        reminderConfig.eventRef = eventInContext
                    }
                    
                    // Update reminder config properties
                    reminderConfig.offsetMinutes = offsetMinutes
                    reminderConfig.mode = mode
                    
                    try context.save()
                    
                    // Return the updated reminder config on the main thread
                    DispatchQueue.main.async {
                        // Fetch the updated reminder config in the main context
                        let mainContext = PersistenceController.shared.container.viewContext
                        let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "recordIDValue == %@", eventInContext.recordIDValue ?? "")
                        
                        do {
                            let results = try mainContext.fetch(fetchRequest)
                            if let mainContextEvent = results.first, let mainContextReminder = mainContextEvent.reminderConfig {
                                promise(.success(mainContextReminder))
                            } else {
                                throw NSError(domain: "CloudKitSyncManager", code: 106, userInfo: [NSLocalizedDescriptionKey: "Updated reminder config not found in main context"])
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
    
    // MARK: - Weekend Status Helpers
    
    // Fetch weekend status for all months of the year
    func fetchYearlyWeekendStatus(year: Int) -> AnyPublisher<[Date: String], Error> {
        return Future<[Date: String], Error> { promise in
            let context = PersistenceController.shared.container.viewContext
            
            // Create calendar to work with weekends
            let calendar = Calendar.current
            var weekendStatusMap = [Date: String]()
            
            // Start from January 1st
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            
            guard let startDate = calendar.date(from: components) else {
                promise(.failure(NSError(domain: "CloudKitSyncManager", code: 107, userInfo: [NSLocalizedDescriptionKey: "Invalid date components"])))
                return
            }
            
            // Find all weekends in the year
            var currentDate = startDate
            let oneYearLater = calendar.date(byAdding: .year, value: 1, to: startDate)!
            
            // Find first weekend
            while !calendar.isDateInWeekend(currentDate) && currentDate < oneYearLater {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // For each weekend, check if there are any events
            while currentDate < oneYearLater {
                // Get weekend start (Saturday)
                let weekendStart = currentDate
                
                // Get weekend end (Sunday)
                var weekendEnd = weekendStart
                if calendar.component(.weekday, from: weekendStart) == 1 { // Sunday
                    weekendEnd = weekendStart
                } else { // Saturday
                    weekendEnd = calendar.date(byAdding: .day, value: 1, to: weekendStart)!
                }
                
                // Adjust to end of day
                let endOfWeekend = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekendEnd)!
                
                // Fetch events for this weekend
                let fetchRequest: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", 
                                                    endOfWeekend as NSDate, 
                                                    weekendStart as NSDate)
                
                do {
                    let events = try context.fetch(fetchRequest)
                    
                    // Determine weekend status based on events
                    if !events.isEmpty {
                        // Check if there are travel events
                        let travelEvents = events.filter { $0.eventType == "travel" }
                        if !travelEvents.isEmpty {
                            weekendStatusMap[weekendStart] = "travel"
                        } else {
                            weekendStatusMap[weekendStart] = "plan"
                        }
                    } else {
                        weekendStatusMap[weekendStart] = "free"
                    }
                } catch {
                    print("Error fetching events for weekend: \(error)")
                    weekendStatusMap[weekendStart] = "free" // Default to free on error
                }
                
                // Move to next weekend
                currentDate = calendar.date(byAdding: .day, value: 6, to: weekendEnd)!
                while !calendar.isDateInWeekend(currentDate) && currentDate < oneYearLater {
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                }
            }
            
            promise(.success(weekendStatusMap))
        }.eraseToAnyPublisher()
    }
    
    // Fetch weekends for a specific month
    func fetchWeekendsForMonth(year: Int, month: Int) -> AnyPublisher<[Date], Error> {
        return Future<[Date], Error> { promise in
            // Create calendar to work with weekends
            let calendar = Calendar.current
            var weekends = [Date]()
            
            // Start from first day of month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            
            guard let startDate = calendar.date(from: components) else {
                promise(.failure(NSError(domain: "CloudKitSyncManager", code: 108, userInfo: [NSLocalizedDescriptionKey: "Invalid date components"])))
                return
            }
            
            // Get first day of next month
            let nextMonth = month == 12 ? 1 : month + 1
            let nextMonthYear = month == 12 ? year + 1 : year
            
            components.year = nextMonthYear
            components.month = nextMonth
            components.day = 1
            
            guard let endDate = calendar.date(from: components) else {
                promise(.failure(NSError(domain: "CloudKitSyncManager", code: 109, userInfo: [NSLocalizedDescriptionKey: "Invalid date components"])))
                return
            }
            
            // Find all weekends in the month
            var currentDate = startDate
            
            // Find first weekend
            while !calendar.isDateInWeekend(currentDate) && currentDate < endDate {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // For each weekend, store the start date
            while currentDate < endDate {
                // Get weekend start (Saturday)
                let weekendStart: Date
                
                if calendar.component(.weekday, from: currentDate) == 1 { // Sunday
                    // If we found a Sunday first, go back one day to get the Saturday
                    weekendStart = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                } else { // Saturday
                    weekendStart = currentDate
                }
                
                // Reset time components to midnight
                let startOfWeekend = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: weekendStart)!
                
                weekends.append(startOfWeekend)
                
                // Move to next weekend (add 6 days to get to next Friday, then find next weekend day)
                currentDate = calendar.date(byAdding: .day, value: 6, to: weekendStart)!
                while !calendar.isDateInWeekend(currentDate) && currentDate < endDate {
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                }
            }
            
            promise(.success(weekends))
        }.eraseToAnyPublisher()
    }

    func fetchWeekendStatuses(from startDate: Date, to endDate: Date) -> AnyPublisher<[Date: String], Error> {
        // Use "saturdayDate" as the field for querying the date range
        let predicate = NSPredicate(format: "saturdayDate >= %@ AND saturdayDate <= %@", startDate as NSDate, endDate as NSDate)
        
        let query = CKQuery(recordType: "Weekend", predicate: predicate)
        
        // Optionally, specify desired keys for efficiency.
        // "saturdayDate" and "status" are the relevant fields.
        query.desiredKeys = ["saturdayDate", "status"]

        let database = CKContainer.default().publicCloudDatabase // Or .privateCloudDatabase if that's where "Weekend" records are stored

        return Future<[Date: String], Error> { promise in
            database.perform(query, inZoneWith: nil) { records, error in
                if let error = error {
                    print("CloudKit error in fetchWeekendStatuses: \(error.localizedDescription)")
                    promise(.failure(error))
                    return
                }

                var statusMap = [Date: String]()
                guard let fetchedRecords = records else {
                    promise(.success([:])) // No records, return empty map
                    return
                }

                for record in fetchedRecords {
                    // Use "saturdayDate" to get the date
                    guard let weekendDate = record["saturdayDate"] as? Date else {
                        print("Warning: Could not cast 'saturdayDate' field from CloudKit record: \(record.recordID.recordName)")
                        continue 
                    }
                    
                    // "status" field for the status string (already correct in your file)
                    guard let statusString = record["status"] as? String else {
                        print("Warning: Could not cast 'status' field from CloudKit record: \(record.recordID.recordName)")
                        continue
                    }
                    
                    // Normalize the date to the start of the day to ensure consistent dictionary keys.
                    // This is important if your date fields might have time components.
                    let normalizedDate = Calendar.current.startOfDay(for: weekendDate)
                    statusMap[normalizedDate] = statusString
                }
                promise(.success(statusMap))
            }
        }
        .eraseToAnyPublisher()
    }
}

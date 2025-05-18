import CoreData
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        // Use a regular NSPersistentContainer instead of CloudKit
        container = NSPersistentContainer(name: "WeekendPlanner")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Print out the store URL for debugging
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            print("Core Data store URL: \(storeURL.absoluteString)")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // Log the error but don't crash
                let nsError = error as NSError
                print("Core Data loading error: \(error.localizedDescription)")
                print("Error details: \(nsError.userInfo)")
                
                // Try to recover by deleting the store file if it exists
                self.recreateStoreIfNeeded()
            } else {
                print("Core Data store loaded successfully")
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Try to recover from Core Data errors by resetting the store
    private func recreateStoreIfNeeded() {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            print("Could not find store URL")
            return
        }
        
        print("Attempting to delete and recreate the store at \(storeURL)")
        
        do {
            try FileManager.default.removeItem(at: storeURL)
            
            // Also remove SQLite auxiliary files
            let sqliteWalURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-wal")
            let sqliteShmURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + "-shm")
            
            try? FileManager.default.removeItem(at: sqliteWalURL)
            try? FileManager.default.removeItem(at: sqliteShmURL)
            
            // Try loading again
            container.loadPersistentStores { description, error in
                if let error = error {
                    print("Still could not load store after deletion: \(error.localizedDescription)")
                } else {
                    print("Successfully recreated Core Data store")
                }
            }
        } catch {
            print("Could not delete Core Data store: \(error.localizedDescription)")
        }
    }
    
    // Create a background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Fetch user entity
    func fetchCurrentUser() -> UserEntity? {
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        do {
            let users = try container.viewContext.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching current user: \(error)")
            return nil
        }
    }
    
    // Enhanced error handling for CoreData operations
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // Add graceful error handling to avoid app crashes
    func handleCoreDataError(_ error: Error, operation: String) {
        print("CoreData error during \(operation): \(error.localizedDescription)")
        // Log the error or present an alert to the user
    }
}

// Keep this extension for future CloudKit implementation
extension Notification.Name {
    static let cloudKitDataDidChange = Notification.Name("cloudKitDataDidChange")
}

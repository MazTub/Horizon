import SwiftUI
import Combine
import UserNotifications

class ProfileViewModel: ObservableObject {
    // Published properties
    @Published var displayName = ""
    @Published var email = ""
    @Published var timezone = ""
    @Published var avatarImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Notification settings
    @Published var notificationsEnabled = false
    @Published var defaultReminderOffset = 60 // Default 60 minutes before
    @Published var defaultReminderMode = "inApp" // Default to in-app notifications
    
    // CloudKit manager
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to current user changes
        cloudKitManager.currentUser
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.displayName = user.displayName ?? ""
                self?.email = user.email ?? ""
                self?.timezone = user.timezone ?? TimeZone.current.identifier
                
                // Load avatar if available
                if let thumbData = user.avatarThumb {
                    self?.avatarImage = UIImage(data: thumbData)
                }
            }
            .store(in: &cancellables)
        
        // Check notification authorization status
        checkNotificationStatus()
        
        // Load default notification settings from UserDefaults
        loadNotificationSettings()
    }
    
    // MARK: - Profile Management
    
    func saveProfile() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        cloudKitManager.saveUserProfile(displayName: displayName, avatar: avatarImage)
        
        // Save notification settings to UserDefaults
        saveNotificationSettings()
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
            self?.successMessage = "Profile updated successfully"
        }
    }
    
    func selectProfileImage() {
        // This will be handled by the view, as it requires a UIImagePickerController
        // The selected image will be set to avatarImage
    }
    
    // MARK: - Notification Management
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.notificationsEnabled = true
                    self?.successMessage = "Notification permissions granted"
                } else {
                    self?.errorMessage = "Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }
    
    // MARK: - UserDefaults for Notification Settings
    
    private func loadNotificationSettings() {
        let defaults = UserDefaults.standard
        defaultReminderOffset = defaults.integer(forKey: "defaultReminderOffset")
        if defaultReminderOffset == 0 {
            // If not set yet, use default of 60 minutes
            defaultReminderOffset = 60
        }
        
        defaultReminderMode = defaults.string(forKey: "defaultReminderMode") ?? "inApp"
    }
    
    private func saveNotificationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(defaultReminderOffset, forKey: "defaultReminderOffset")
        defaults.set(defaultReminderMode, forKey: "defaultReminderMode")
    }
    
    // MARK: - Helper Methods
    
    // Get available timezones
    func availableTimezones() -> [String] {
        return TimeZone.knownTimeZoneIdentifiers.sorted()
    }
    
    // Get formatted reminder time
    func formattedReminderTime() -> String {
        if defaultReminderOffset < 60 {
            return "\(defaultReminderOffset) minutes before"
        } else if defaultReminderOffset == 60 {
            return "1 hour before"
        } else {
            let hours = defaultReminderOffset / 60
            let minutes = defaultReminderOffset % 60
            
            if minutes == 0 {
                return "\(hours) hours before"
            } else {
                return "\(hours) hours \(minutes) minutes before"
            }
        }
    }
}

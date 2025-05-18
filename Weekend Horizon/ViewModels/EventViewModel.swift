import Foundation
import Combine
import SwiftUI

class EventViewModel: ObservableObject {
    // Published properties for form data
    @Published var title = ""
    @Published var eventType = "plan" // Default to "plan"
    @Published var location = ""
    @Published var eventDescription = ""
    @Published var startDate = Date()
    @Published var endDate = Date()
    @Published var selectedDays: Set<Int> = [1, 2] // Default to both days (Sat = 1, Sun = 2)
    
    // Reminder configuration
    @Published var reminderEnabled = false
    @Published var reminderOffset = 60 // Default 60 minutes before
    @Published var reminderMode = "inApp" // Default to in-app notification
    
    // State management
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Editing mode
    private(set) var isEditing = false
    private(set) var eventBeingEdited: EventEntity?
    
    // CloudKit manager
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Validation flags
    private let maxTitleLength = 100
    private let maxLocationLength = 150
    private let maxDescriptionLength = 1000
    
    // Weekend start/end dates
    private var weekendStart: Date
    private var weekendEnd: Date
    
    init(weekendDate: Date) {
        // Set up weekend dates
        let calendar = Calendar.current
        self.weekendStart = weekendDate
        self.weekendEnd = calendar.date(byAdding: .day, value: 1, to: weekendDate)!
        
        // Set default start/end dates within the weekend
        self.startDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: weekendStart)!
        self.endDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: weekendStart)!
    }
    
    // Initialize for editing an existing event
    init(event: EventEntity) {
        self.isEditing = true
        self.eventBeingEdited = event
        
        // Set up weekend dates based on event
        let calendar = Calendar.current
        
        // Determine weekend start (Saturday) from event start date
        if calendar.component(.weekday, from: event.startDate!) == 1 { // Sunday
            self.weekendStart = calendar.date(byAdding: .day, value: -1, to: event.startDate!)!
        } else {
            self.weekendStart = calendar.date(
                from: calendar.dateComponents([.year, .month, .day], from: event.startDate!)
            )!
        }
        
        self.weekendEnd = calendar.date(byAdding: .day, value: 1, to: weekendStart)!
        
        // Populate form data
        self.title = event.title ?? ""
        self.eventType = event.eventType ?? "plan"
        self.location = event.location ?? ""
        self.eventDescription = event.eventDescription ?? ""
        self.startDate = event.startDate ?? Date()
        self.endDate = event.endDate ?? Date()
        
        // Set selected days based on dayMask
        let dayMask = Int(event.dayMask) // Direct conversion, not a cast
        self.selectedDays = []
        if dayMask & 1 != 0 { self.selectedDays.insert(1) } // Saturday
        if dayMask & 2 != 0 { self.selectedDays.insert(2) } // Sunday
        
        // Set reminder configuration if it exists
        if let reminder = event.reminderConfig {
            self.reminderEnabled = true
            self.reminderOffset = Int(reminder.offsetMinutes)
            self.reminderMode = reminder.mode ?? "inApp"
        }
    }
    
    // MARK: - Validation
    
    func validateInput() -> Bool {
        // Reset error message
        errorMessage = nil
        
        // Check for empty title
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Title cannot be empty"
            return false
        }
        
        // Check title length
        if title.count > maxTitleLength {
            errorMessage = "Title cannot exceed \(maxTitleLength) characters"
            return false
        }
        
        // Check location length
        if location.count > maxLocationLength {
            errorMessage = "Location cannot exceed \(maxLocationLength) characters"
            return false
        }
        
        // Check description length
        if eventDescription.count > maxDescriptionLength {
            errorMessage = "Description cannot exceed \(maxDescriptionLength) characters"
            return false
        }
        
        // Check if at least one day is selected
        if selectedDays.isEmpty {
            errorMessage = "Please select at least one day"
            return false
        }
        
        // Check if start date is before end date
        if startDate >= endDate {
            errorMessage = "Start time must be before end time"
            return false
        }
        
        // Check if dates are within the weekend
        let calendar = Calendar.current
        let weekendEndTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekendEnd)!
        
        if startDate < weekendStart || endDate > weekendEndTime {
            errorMessage = "Event must be within the selected weekend"
            return false
        }
        
        return true
    }
    
    // MARK: - Save Event
    
    func saveEvent() {
        // Validate input
        guard validateInput() else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // Calculate day mask from selected days
        let dayMask = selectedDays.reduce(0) { result, day in
            result | (1 << (day - 1))
        }
        
        if isEditing, let event = eventBeingEdited {
            // Update existing event
            cloudKitManager.updateEvent(
                event: event,
                title: title,
                startDate: startDate,
                endDate: endDate,
                eventType: eventType,
                location: location,
                description: eventDescription,
                dayMask: Int16(dayMask)
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to update event: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] updatedEvent in
                guard let self = self else { return }
                
                // Handle reminder if enabled
                if self.reminderEnabled {
                    self.cloudKitManager.updateReminderConfig(
                        for: updatedEvent,
                        offsetMinutes: Int16(self.reminderOffset),
                        mode: self.reminderMode
                    )
                    .sink { completion in
                        if case .failure(let error) = completion {
                            print("Failed to update reminder: \(error)")
                        }
                    } receiveValue: { _ in }
                    .store(in: &self.cancellables)
                }
                
                self.successMessage = "Event updated successfully"
                
                // Schedule local notification if necessary
                if self.reminderEnabled && self.reminderMode == "push" {
                    self.scheduleNotification(for: updatedEvent)
                }
            }
            .store(in: &cancellables)
        } else {
            // Create new event
            cloudKitManager.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                eventType: eventType,
                location: location,
                description: eventDescription,
                dayMask: Int16(dayMask),
                reminderOffset: reminderEnabled ? Int16(reminderOffset) : nil,
                reminderMode: reminderEnabled ? reminderMode : nil
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to create event: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] createdEvent in
                guard let self = self else { return }
                self.successMessage = "Event created successfully"
                
                // Schedule local notification if necessary
                if self.reminderEnabled && self.reminderMode == "push" {
                    self.scheduleNotification(for: createdEvent)
                }
            }
            .store(in: &cancellables)
        }
    }
    
    // MARK: - Delete Event
    
    func deleteEvent() {
        guard isEditing, let event = eventBeingEdited else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Cancel any existing notifications
        if let reminder = event.reminderConfig, reminder.mode == "push" {
            cancelNotification(for: event)
        }
        
        cloudKitManager.deleteEvent(event: event)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to delete event: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] success in
                if success {
                    self?.successMessage = "Event deleted successfully"
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Management
    
    private func scheduleNotification(for event: EventEntity) {
        guard let title = event.title,
              let startDate = event.startDate,
              let reminderConfig = event.reminderConfig,
              reminderConfig.mode == "push" else {
            return
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Request permission
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted, error == nil else {
                print("Notification permission denied or error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Calculate trigger time
            let triggerDate = startDate.addingTimeInterval(-Double(reminderConfig.offsetMinutes) * 60)
            
            // Check if the trigger date is in the future
            if triggerDate > Date() {
                // Create notification content
                let content = UNMutableNotificationContent()
                content.title = "Weekend Planner"
                content.body = "Reminder: \(title) starting soon"
                content.sound = .default
                
                // Create trigger
                let triggerComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                
                // Create request with a unique identifier
                let requestIdentifier = event.recordIDValue ?? UUID().uuidString
                let request = UNNotificationRequest(
                    identifier: requestIdentifier,
                    content: content,
                    trigger: trigger
                )
                
                // Schedule notification
                notificationCenter.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error)")
                    }
                }
            }
        }
    }
    
    private func cancelNotification(for event: EventEntity) {
        guard let identifier = event.recordIDValue else { return }
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - Helper Methods
    
    // Get day name from index
    func dayName(for index: Int) -> String {
        switch index {
        case 1:
            return "Saturday"
        case 2:
            return "Sunday"
        default:
            return ""
        }
    }
    
    // Check if a day is selected
    func isDaySelected(_ day: Int) -> Bool {
        return selectedDays.contains(day)
    }
    
    // Toggle day selection
    func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    // Get formatted reminder time
    func formattedReminderTime() -> String {
        if reminderOffset < 60 {
            return "\(reminderOffset) minutes before"
        } else if reminderOffset == 60 {
            return "1 hour before"
        } else {
            let hours = reminderOffset / 60
            let minutes = reminderOffset % 60
            
            if minutes == 0 {
                return "\(hours) hours before"
            } else {
                return "\(hours) hours \(minutes) minutes before"
            }
        }
    }
}

import Foundation
import UserNotifications
import SwiftUI
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Authorization Management
    
    // Request notification authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
            
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
        }
    }
    
    // Check notification authorization status
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    // Schedule event reminder notification with customization options
    func scheduleEventReminder(
        for event: EventEntity,
        minutesBefore: Int,
        title: String? = nil,
        body: String? = nil,
        sound: UNNotificationSound = .default,
        badge: NSNumber? = nil,
        userInfo: [AnyHashable: Any]? = nil,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let eventTitle = event.title,
              let startDate = event.startDate,
              let eventId = event.recordIDValue else {
            completion(false, NSError(domain: "NotificationManager", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid event data"]))
            return
        }
        
        // Calculate trigger time
        let triggerDate = startDate.addingTimeInterval(-Double(minutesBefore * 60))
        
        // Check if the trigger date is in the future
        guard triggerDate > Date() else {
            completion(false, NSError(domain: "NotificationManager", code: 101, userInfo: [NSLocalizedDescriptionKey: "Reminder time is in the past"]))
            return
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title ?? "Weekend Planner"
        content.body = body ?? "Reminder: \(eventTitle) starting soon"
        content.sound = sound
        
        // Add badge if provided
        if let badge = badge {
            content.badge = badge
        }
        
        // Add userInfo if provided (for deep linking)
        if let userInfo = userInfo {
            content.userInfo = userInfo
        } else {
            // Set default userInfo with event details for navigation
            content.userInfo = [
                "eventId": eventId,
                "type": "eventReminder",
                "eventType": event.eventType ?? "plan"
            ]
        }
        
        // Create trigger
        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        // Create request with a unique identifier
        let request = UNNotificationRequest(
            identifier: "event_\(eventId)_\(minutesBefore)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil, error)
            }
        }
    }
    
    // Schedule a simple notification with a time interval
    func scheduleSimpleNotification(
        title: String,
        body: String,
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString,
        repeats: Bool = false,
        completion: @escaping (Bool) -> Void
    ) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    // MARK: - Notification Management
    
    // Cancel reminder notification for event
    func cancelReminder(for eventId: String) {
        // Use prefix matching to catch all notifications for the event
        let identifier = "event_\(eventId)"
        
        // Get all pending requests
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Filter requests that match the event ID prefix
            let matchingIdentifiers = requests.filter { $0.identifier.hasPrefix(identifier) }.map { $0.identifier }
            
            // Remove matching requests
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: matchingIdentifiers)
        }
    }
    
    // Cancel all pending notifications
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // Get all pending notifications
    func getPendingReminders(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
    
    // Get pending reminders for a specific event
    func getPendingRemindersForEvent(eventId: String, completion: @escaping ([UNNotificationRequest]) -> Void) {
        let identifier = "event_\(eventId)"
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Filter requests that match the event ID prefix
            let matchingRequests = requests.filter { $0.identifier.hasPrefix(identifier) }
            
            DispatchQueue.main.async {
                completion(matchingRequests)
            }
        }
    }
    
    // MARK: - Badge Management
    
    // Reset application badge
    func resetBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("Error resetting badge: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Set application badge
    func setBadge(count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("Error setting badge count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Get current badge count
    func getBadgeCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Use the proper way to get badge count in iOS 17+
                UNUserNotificationCenter.current().getBadgeCount { count in
                    completion(count)
                }
            }
        }
    }
    
    // MARK: - Notification Categories and Actions
    
    // Register custom notification categories with actions
    func registerNotificationCategories() {
        // Create "Event Reminder" category with actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_EVENT",
            title: "View Event",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_15",
            title: "Snooze 15 Minutes",
            options: .authenticationRequired
        )
        
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([eventCategory])
    }
    
    // Handle notification action responses
    func handleNotificationAction(response: UNNotificationResponse, completion: @escaping () -> Void) {
        let identifier = response.actionIdentifier
        let notification = response.notification
        let userInfo = notification.request.content.userInfo
        
        switch identifier {
        case "VIEW_EVENT":
            // Navigate to event
            if let eventId = userInfo["eventId"] as? String {
                NotificationCenter.default.post(name: .navigateToEvent, object: eventId)
            }
            
        case "SNOOZE_15":
            // Reschedule notification for 15 minutes later
            if let eventId = userInfo["eventId"] as? String {
                // Create a new notification for 15 minutes later
                let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
                
                let newRequest = UNNotificationRequest(
                    identifier: "snooze_\(eventId)_\(Date().timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )
                
                UNUserNotificationCenter.current().add(newRequest)
            }
            
        default:
            break
        }
        
        completion()
    }
}

// MARK: - In-App Notification System

extension NotificationManager {
    // Show in-app banner notification
    func showInAppNotification(title: String, message: String, in viewController: UIViewController) {
        let banner = InAppNotificationBanner(title: title, message: message)
        
        // Add banner to view controller's view
        viewController.view.addSubview(banner)
        
        // Position banner at the top of the screen, off-screen initially
        banner.frame = CGRect(x: 0, y: -banner.frame.height, width: viewController.view.frame.width, height: banner.frame.height)
        
        // Animate banner sliding down
        UIView.animate(withDuration: 0.3, animations: {
            banner.frame.origin.y = 0
        })
        
        // After a delay, animate banner sliding back up
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.3, animations: {
                banner.frame.origin.y = -banner.frame.height
            }, completion: { _ in
                banner.removeFromSuperview()
            })
        }
    }
    
    // Publish an in-app notification via NotificationCenter for SwiftUI views
    func publishInAppNotification(title: String, message: String) {
        NotificationCenter.default.post(
            name: .inAppNotification,
            object: nil,
            userInfo: ["title": title, "message": message]
        )
    }
}

// UIView for in-app notification banner
class InAppNotificationBanner: UIView {
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
    init(title: String, message: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 80))
        
        // Configure banner appearance
        backgroundColor = UIColor.systemBlue
        layer.cornerRadius = 0
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 5
        
        // Configure title label
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        // Configure message label
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.numberOfLines = 2
        
        // Add labels to banner
        addSubview(titleLabel)
        addSubview(messageLabel)
        
        // Position labels
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - SwiftUI Integration

// SwiftUI Wrapper for In-App Notification
struct InAppNotification: View {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue)
        .cornerRadius(0, corners: [.bottomLeft, .bottomRight])
        .shadow(radius: 5)
        .transition(.move(edge: .top))
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

// Helper view modifier to show in-app notification
struct InAppNotificationModifier: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if isPresented {
                InAppNotification(title: title, message: message, isPresented: $isPresented)
            }
        }
    }
}

extension View {
    func inAppNotification(title: String, message: String, isPresented: Binding<Bool>) -> some View {
        self.modifier(InAppNotificationModifier(title: title, message: message, isPresented: isPresented))
    }
}

// MARK: - Notification Observer Helper for SwiftUI

class NotificationObserver: ObservableObject {
    @Published var notificationTitle: String = ""
    @Published var notificationMessage: String = ""
    @Published var showNotification: Bool = false
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInAppNotification),
            name: .inAppNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleInAppNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let title = userInfo["title"] as? String,
              let message = userInfo["message"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            self.notificationTitle = title
            self.notificationMessage = message
            self.showNotification = true
        }
    }
}

// Extension to implement getBadgeCount on UNUserNotificationCenter
extension UNUserNotificationCenter {
    func getBadgeCount(_ completion: @escaping (Int) -> Void) {
        // Get pending notification requests to count badges
        getPendingNotificationRequests { requests in
            var badgeCount = 0
            
            // Some apps may want to count number of pending notifications
            // Here we'll just return the current badge count
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                if let notification = notifications.first, 
                   let badge = notification.request.content.badge as? Int {
                    badgeCount = badge
                }
                
                DispatchQueue.main.async {
                    completion(badgeCount)
                }
            }
        }
    }
}

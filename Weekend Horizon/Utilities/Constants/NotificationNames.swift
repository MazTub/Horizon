import Foundation

extension Notification.Name {
    // For showing the event creation form
    static let showEventForm = Notification.Name("showEventForm")

    // For navigating to a specific month in the calendar
    static let navigateToMonth = Notification.Name("navigateToMonth")

    // For indicating that CloudKit data has changed
    static let cloudKitDataDidChange = Notification.Name("cloudKitDataDidChange")

    // For displaying an in-app notification message
    static let inAppNotification = Notification.Name("inAppNotification")

    // For navigating to a specific event, often from a push notification
    static let navigateToEvent = Notification.Name("navigateToEvent")
} 
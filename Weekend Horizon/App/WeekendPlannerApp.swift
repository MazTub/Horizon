import SwiftUI

@main
struct WeekendPlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let persistenceController = PersistenceController.shared
    @State private var isShowingEventForm = false
    @State private var selectedWeekendDate: Date?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: .showEventForm)) { notification in
                    if let weekendDate = notification.object as? Date {
                        selectedWeekendDate = weekendDate
                        isShowingEventForm = true
                    }
                }
                .sheet(isPresented: $isShowingEventForm) {
                    if let weekendDate = selectedWeekendDate {
                        EventFormSheet(weekendDate: weekendDate)
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        
        // Parse identifier to get event ID
        // Then navigate to the event
        NotificationCenter.default.post(name: .navigateToEvent, object: identifier)
        
        completionHandler()
    }
}

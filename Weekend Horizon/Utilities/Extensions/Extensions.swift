import SwiftUI
import UIKit

// MARK: - Date Extensions

extension Date {
    // Get the start of the day (midnight)
    func startOfDay() -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: self)!
    }
    
    // Get the end of the day (23:59:59)
    func endOfDay() -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: self)!
    }
    
    // Check if date is a weekend
    var isWeekend: Bool {
        let calendar = Calendar.current
        return calendar.isDateInWeekend(self)
    }
    
    // Get the weekend start (Saturday) for any date
    func startOfWeekend() -> Date {
        let calendar = Calendar.current
        
        // If already on weekend, normalize to Saturday
        if self.isWeekend {
            if calendar.component(.weekday, from: self) == 1 { // Sunday
                // Move back one day to get to Saturday
                return calendar.date(byAdding: .day, value: -1, to: self)!.startOfDay()
            } else { // Saturday
                return self.startOfDay()
            }
        } else {
            // Find next Saturday
            var nextWeekendComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
            nextWeekendComponents.weekday = 7 // Saturday
            
            if let nextSaturday = calendar.date(from: nextWeekendComponents),
               nextSaturday > self {
                return nextSaturday.startOfDay()
            } else {
                // If we can't find the next Saturday in this week, get next week's Saturday
                nextWeekendComponents.weekOfYear! += 1
                guard let nextWeekSaturday = calendar.date(from: nextWeekendComponents) else {
                    // Fallback to just adding days until we find a Saturday
                    var current = self
                    while calendar.component(.weekday, from: current) != 7 {
                        current = calendar.date(byAdding: .day, value: 1, to: current)!
                    }
                    return current.startOfDay()
                }
                return nextWeekSaturday.startOfDay()
            }
        }
    }
    
    // Get the weekend end (Sunday) for any date
    func endOfWeekend() -> Date {
        let calendar = Calendar.current
        
        // Get the Saturday of this weekend
        let saturday = self.startOfWeekend()
        
        // Move to Sunday
        return calendar.date(byAdding: .day, value: 1, to: saturday)!.endOfDay()
    }
    
    // Format date as "Month Day" (e.g., "Jan 1")
    var formattedMonthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    // Format date as "Day of Week, Month Day" (e.g., "Monday, Jan 1")
    var formattedDayOfWeekMonthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: self)
    }
    
    // Format time as "h:mm a" (e.g., "3:30 PM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    // Resize image to specific size
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // Create thumbnail version of image
    func thumbnail(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage? {
        return resized(to: size)
    }
}

// MARK: - Color Extensions

extension Color {
    // Convert UIColor to SwiftUI Color
    init(uiColor: UIColor) {
        self.init(red: Double(uiColor.cgColor.components?[0] ?? 0),
                  green: Double(uiColor.cgColor.components?[1] ?? 0),
                  blue: Double(uiColor.cgColor.components?[2] ?? 0),
                  opacity: Double(uiColor.cgColor.components?[3] ?? 0))
    }
    
    // Define custom colors for the app
    static let accentPrimary = Color("AccentPrimary")
    static let accentSecondary = Color("AccentSecondary")
}

// MARK: - View Extensions

extension View {
    // Add rounded corners to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // Add shadow with custom parameters
    func customShadow(radius: CGFloat = 3, offset: CGPoint = .zero, opacity: Double = 0.2) -> some View {
        self.shadow(color: Color.black.opacity(opacity), radius: radius, x: offset.x, y: offset.y)
    }
}

// Helper shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - String Extensions

extension String {
    // Truncate string with ellipsis
    func truncated(to length: Int, addEllipsis: Bool = true) -> String {
        if self.count <= length {
            return self
        }
        
        let truncated = self.prefix(length)
        return addEllipsis ? "\(truncated)..." : String(truncated)
    }
}

// MARK: - Notification Center Extensions

extension NotificationCenter {
    // Post notification with data
    func postWithData(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        self.post(name: name, object: object, userInfo: userInfo)
    }
}

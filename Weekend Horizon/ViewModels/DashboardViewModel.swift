import Foundation
import Combine
import SwiftUI

enum DashboardViewMode {
    case twelveMonth
    case upcoming
}

class DashboardViewModel: ObservableObject {
    // Published properties
    @Published var viewMode: DashboardViewMode = .twelveMonth
    @Published var yearlyWeekendStatus = [Date: String]()
    @Published var upcomingWeekends = [Date]()
    @Published var weekendEvents = [Date: [EventEntity]]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // CloudKit manager
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
        
        // Initial data load
        loadData()
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        // Load 12-month view data
        loadYearlyWeekendStatus()
        
        // Load upcoming weekends
        loadUpcomingWeekends()
    }
    
    private func loadYearlyWeekendStatus() {
        let calendar = Calendar.current
        let today = Date()
        
        guard let twelveMonthsLater = calendar.date(byAdding: .month, value: 12, to: today),
              let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: twelveMonthsLater)) else {
            self.errorMessage = "Could not calculate date range for 12-month view."
            self.isLoading = false
            return
        }
        
        // We need to determine the actual end day of the 11th month from the startDate
        // For example, if startDate is Nov 1, 2023, we want data up to Oct 31, 2024.
        guard let actualEndDate = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 12, to: startDate)!) else {
            self.errorMessage = "Could not calculate end date for 12-month view."
            self.isLoading = false
            return
        }

        // Conceptual: CloudKitManager needs a method to fetch for a date range or a series of months.
        // For this example, let's assume a new method fetchWeekendStatuses(from: Date, to: Date)
        // You would need to implement this in CloudKitSyncManager.shared
        cloudKitManager.fetchWeekendStatuses(from: startDate, to: actualEndDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load weekend status: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] statusMap in
                self?.yearlyWeekendStatus = statusMap
            }
            .store(in: &cancellables)
    }
    
    private func loadUpcomingWeekends() {
        // Find the next 4 weekends from today
        let calendar = Calendar.current
        let today = Date()
        
        // Start with the current or next weekend
        var currentDate = today
        
        // If today is not a weekend, find the next weekend
        if !calendar.isDateInWeekend(today) {
            // Find the next Saturday
            var nextWeekendComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            nextWeekendComponents.weekday = 7 // Saturday
            
            if let nextSaturday = calendar.date(from: nextWeekendComponents),
               nextSaturday > today {
                currentDate = nextSaturday
            } else {
                // If we can't find the next Saturday in this week, get next week's Saturday
                nextWeekendComponents.weekOfYear! += 1
                if let nextWeekSaturday = calendar.date(from: nextWeekendComponents) {
                    currentDate = nextWeekSaturday
                }
            }
        } else {
            // If today is a weekend, normalize to the start of the weekend (Saturday)
            if calendar.component(.weekday, from: today) == 1 { // Sunday
                currentDate = calendar.date(byAdding: .day, value: -1, to: today)! // Get Saturday
            }
        }
        
        // Reset time components to midnight
        currentDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: currentDate)!
        
        // Get 4 consecutive weekends
        var weekendStarts = [Date]()
        weekendStarts.append(currentDate)
        
        for i in 1..<4 {
            if let nextWeekend = calendar.date(byAdding: .day, value: 7*i, to: currentDate) {
                weekendStarts.append(nextWeekend)
            }
        }
        
        self.upcomingWeekends = weekendStarts
        
        // For each weekend, fetch events
        for weekendStart in weekendStarts {
            let weekendEnd = calendar.date(byAdding: .day, value: 1, to: weekendStart)!
            let endOfWeekend = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekendEnd)!
            
            cloudKitManager.fetchEvents(forWeekend: weekendStart, endDate: endOfWeekend)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        print("Error fetching events for weekend \(weekendStart): \(error)")
                    }
                } receiveValue: { [weak self] events in
                    self?.weekendEvents[weekendStart] = events
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Helper Methods
    
    // Get month name from date
    func monthName(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: date)
    }
    
    // Get weekend dates as string
    func weekendDateString(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!
        
        return "\(dateFormatter.string(from: date)) - \(dateFormatter.string(from: endDate))"
    }
    
    // Get formatted weekend date range
    func formattedWeekendRange(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!
        
        return "Saturday, \(dateFormatter.string(from: date)) - Sunday, \(dateFormatter.string(from: endDate))"
    }
    
    // Get weekends grouped by month
    func weekendsByMonth() -> [String: [Date]] {
        var result = [String: [Date]]()
        
        for (date, _) in yearlyWeekendStatus {
            let monthName = self.monthName(for: date)
            if result[monthName] == nil {
                result[monthName] = [date]
            } else {
                result[monthName]?.append(date)
            }
        }
        
        return result
    }
    
    // Get status color for a weekend
    func statusColor(for date: Date) -> Color {
        guard let status = yearlyWeekendStatus[date] else {
            return .green // Default to free
        }
        
        switch status {
        case "free":
            return .green
        case "plan":
            return .purple
        case "travel":
            return .red
        default:
            return .green
        }
    }
    
    // Get status name for a weekend
    func statusName(for date: Date) -> String {
        guard let status = yearlyWeekendStatus[date] else {
            return "Free"
        }
        
        switch status {
        case "free":
            return "Free"
        case "plan":
            return "Plans"
        case "travel":
            return "Travel"
        default:
            return "Free"
        }
    }
    
    // Navigate to specific month in calendar
    func navigateToMonth(with date: Date) {
        // This will be implemented by the parent view to handle navigation
    }
}

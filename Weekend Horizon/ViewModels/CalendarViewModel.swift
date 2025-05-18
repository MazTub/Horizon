import Foundation
import Combine
import SwiftUI

class CalendarViewModel: ObservableObject {
    // Published properties
    @Published var currentMonth: Date = Date()
    @Published var weekends: [Date] = []
    @Published var weekendEvents = [Date: [EventEntity]]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPastWeekends = false
    
    // Selected weekend for detail view
    @Published var selectedWeekend: Date?
    @Published var isShowingWeekendDetail = false
    
    // CloudKit manager
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .sink { [weak self] _ in
                self?.loadWeekends(for: self?.currentMonth ?? Date())
            }
            .store(in: &cancellables)
        
        // Initial data load
        loadCurrentMonth()
    }
    
    func loadCurrentMonth() {
        // Set to first day of current month
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = 1
        
        if let firstDayOfMonth = calendar.date(from: components) {
            self.currentMonth = firstDayOfMonth
            loadWeekends(for: firstDayOfMonth)
        }
    }
    
    func goToPreviousMonth() {
        let calendar = Calendar.current
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = previousMonth
            loadWeekends(for: previousMonth)
        }
    }
    
    func goToNextMonth() {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = nextMonth
            loadWeekends(for: nextMonth)
        }
    }
    
    func goToMonth(_ date: Date) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 1
        
        if let firstDayOfMonth = calendar.date(from: components) {
            currentMonth = firstDayOfMonth
            loadWeekends(for: firstDayOfMonth)
        }
    }
    
    private func loadWeekends(for date: Date) {
        isLoading = true
        errorMessage = nil
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        cloudKitManager.fetchWeekendsForMonth(year: year, month: month)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load weekends: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] weekends in
                guard let self = self else { return }
                
                // Filter past weekends if necessary
                if self.showPastWeekends {
                    self.weekends = weekends
                } else {
                    let today = Date()
                    self.weekends = weekends.filter { $0 >= today }
                }
                
                // For each weekend, fetch events
                for weekendStart in self.weekends {
                    self.loadEventsForWeekend(weekendStart)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadEventsForWeekend(_ date: Date) {
        let calendar = Calendar.current
        let weekendEnd = calendar.date(byAdding: .day, value: 1, to: date)!
        let endOfWeekend = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekendEnd)!
        
        cloudKitManager.fetchEvents(forWeekend: date, endDate: endOfWeekend)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Error fetching events for weekend \(date): \(error)")
                }
            } receiveValue: { [weak self] events in
                self?.weekendEvents[date] = events
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    // Get month name and year
    func monthYearString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: currentMonth)
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
    
    // Get status for a weekend based on events
    func weekendStatus(for date: Date) -> String {
        guard let events = weekendEvents[date], !events.isEmpty else {
            return "free"
        }
        
        // Check if there are travel events
        let travelEvents = events.filter { $0.eventType == "travel" }
        if !travelEvents.isEmpty {
            return "travel"
        } else {
            return "plan"
        }
    }
    
    // Get status color for a weekend
    func statusColor(for date: Date) -> Color {
        let status = weekendStatus(for: date)
        
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
        let status = weekendStatus(for: date)
        
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
    
    // Select a weekend for detail view
    func selectWeekend(_ date: Date) {
        selectedWeekend = date
        loadEventsForWeekend(date) // Refresh events for this weekend
        isShowingWeekendDetail = true
    }
    
    // Toggle showing past weekends
    func toggleShowPastWeekends() {
        showPastWeekends.toggle()
        loadWeekends(for: currentMonth)
    }
}

import SwiftUI
import Combine

struct WeekendDetailSheet: View {
    let weekendDate: Date
    
    @StateObject private var viewModel: WeekendDetailViewModel
    @State private var isAddingEvent = false
    @State private var editingEvent: EventEntity? = nil
    
    init(weekendDate: Date) {
        self.weekendDate = weekendDate
        self._viewModel = StateObject(wrappedValue: WeekendDetailViewModel(weekendDate: weekendDate))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage, retryAction: {
                        viewModel.loadEvents()
                    })
                } else {
                    content
                }
            }
            .navigationTitle(viewModel.weekendDateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isAddingEvent = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEvent) {
                EventFormSheet(weekendDate: weekendDate)
            }
            .sheet(item: $editingEvent) { event in
                EventFormSheet(event: event)
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Weekend header
                weekendHeader
                
                // Events list
                if viewModel.events.isEmpty {
                    emptyStateView
                } else {
                    eventsList
                }
            }
            .padding()
        }
    }
    
    private var weekendHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.fullWeekendDateString)
                .font(.headline)
            
            HStack {
                StatusBadge(status: viewModel.weekendStatus)
                
                Spacer()
                
                Text("\(viewModel.events.count) events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.vertical, 5)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Events Planned")
                .font(.headline)
            
            Text("This weekend is free! Tap the + button to add an event.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                isAddingEvent = true
            }) {
                Text("Add Event")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Events")
                .font(.headline)
                .padding(.vertical, 5)
            
            ForEach(viewModel.sortedEvents, id: \.recordIDValue) { event in
                EventDetailCard(
                    event: event,
                    onEdit: {
                        editingEvent = event
                    }
                )
                .padding(.vertical, 5)
            }
        }
    }
}

struct EventDetailCard: View {
    let event: EventEntity
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 10) {
                // Event header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(timeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Event type badge
                    Text(eventTypeLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(eventTypeColor.opacity(0.2))
                        .foregroundColor(eventTypeColor)
                        .cornerRadius(4)
                }
                
                // Location if available
                if let location = event.location, !location.isEmpty {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Description if available
                if let description = event.eventDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
                
                // Reminder if available
                if let reminder = event.reminderConfig {
                    HStack {
                        Image(systemName: "bell")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(reminderText(for: reminder))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                // Day indicator
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dayIndicator)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var timeString: String {
        guard let startDate = event.startDate, let endDate = event.endDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private var eventTypeColor: Color {
        switch event.eventType {
        case "travel":
            return .red
        case "plan":
            return .purple
        default:
            return .blue
        }
    }
    
    private var eventTypeLabel: String {
        switch event.eventType {
        case "travel":
            return "Travel"
        case "plan":
            return "Plans"
        default:
            return "Event"
        }
    }
    
    private var dayIndicator: String {
        let dayMask = event.dayMask
        
        if dayMask & 1 != 0 && dayMask & 2 != 0 {
            return "Saturday & Sunday"
        } else if dayMask & 1 != 0 {
            return "Saturday only"
        } else if dayMask & 2 != 0 {
            return "Sunday only"
        } else {
            return "Unknown"
        }
    }
    
    private func reminderText(for reminder: ReminderConfigEntity) -> String {
        let offsetMinutes = reminder.offsetMinutes
        let mode = reminder.mode == "push" ? "Push notification" : "In-app reminder"
        
        if offsetMinutes < 60 {
            return "\(mode) \(offsetMinutes) minutes before"
        } else if offsetMinutes == 60 {
            return "\(mode) 1 hour before"
        } else {
            let hours = offsetMinutes / 60
            let minutes = offsetMinutes % 60
            
            if minutes == 0 {
                return "\(mode) \(hours) hours before"
            } else {
                return "\(mode) \(hours) hours \(minutes) minutes before"
            }
        }
    }
}

class WeekendDetailViewModel: ObservableObject {
    // Published properties
    @Published var events: [EventEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dismissSheet = false
    
    // Weekend date
    private let weekendDate: Date
    
    // CloudKit manager
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(weekendDate: Date) {
        self.weekendDate = weekendDate
        
        // Load events
        loadEvents()
        
        // Subscribe to CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataDidChange)
            .sink { [weak self] _ in
                self?.loadEvents()
            }
            .store(in: &cancellables)
    }
    
    func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        let calendar = Calendar.current
        let weekendEnd = calendar.date(byAdding: .day, value: 1, to: weekendDate)!
        let endOfWeekend = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekendEnd)!
        
        cloudKitManager.fetchEvents(forWeekend: weekendDate, endDate: endOfWeekend)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to load events: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] events in
                self?.events = events
            }
            .store(in: &cancellables)
    }
    
    func dismiss() {
        dismissSheet = true
    }
    
    // MARK: - Helper Methods
    
    var weekendDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: weekendDate)!
        
        return "\(formatter.string(from: weekendDate)) - \(formatter.string(from: endDate))"
    }
    
    var fullWeekendDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: weekendDate)!
        
        return "Saturday, \(formatter.string(from: weekendDate)) - Sunday, \(formatter.string(from: endDate))"
    }
    
    var weekendStatus: String {
        if events.isEmpty {
            return "free"
        }
        
        // Check if there are any travel events
        let travelEvents = events.filter { $0.eventType == "travel" }
        if !travelEvents.isEmpty {
            return "travel"
        }
        
        return "plan"
    }
    
    var sortedEvents: [EventEntity] {
        return events.sorted { 
            ($0.startDate ?? Date()) < ($1.startDate ?? Date())
        }
    }
}

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedWeekend: Date?
    @State private var showWeekendDetail = false
    @State private var eventIdForNavigation: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode segmented control
                viewModeSegmentedControl
                
                // Content based on view mode
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage, retryAction: { viewModel.loadData() })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        if viewModel.viewMode == .twelveMonth {
                            TwelveMonthView(
                                weekendStatusMap: viewModel.yearlyWeekendStatus,
                                onMonthSelected: { date in
                                    // Navigate to month in calendar tab
                                    NotificationCenter.default.post(
                                        name: .navigateToMonth,
                                        object: date
                                    )
                                }
                            )
                        } else {
                            UpcomingView(
                                weekends: viewModel.upcomingWeekends,
                                weekendEvents: viewModel.weekendEvents,
                                onWeekendSelected: { date in
                                    selectedWeekend = date
                                    showWeekendDetail = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showWeekendDetail, onDismiss: {
                viewModel.loadData() // Refresh data when detail sheet is dismissed
            }) {
                if let weekend = selectedWeekend {
                    WeekendDetailSheet(weekendDate: weekend)
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitDataDidChange)) { _ in
                viewModel.loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToEvent)) { notification in
                if let eventId = notification.object as? String {
                    // TODO: We need to ensure the Dashboard tab is active.
                    // This might require communication up to MainTabView.
                    // For now, assume Dashboard is visible or becomes visible.
                    print("DashboardView received navigateToEvent for ID: \\(eventId)")
                    self.navigateToEventScreen(with: eventId)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var viewModeSegmentedControl: some View {
        Picker("View Mode", selection: $viewModel.viewMode) {
            Text("12-Month View").tag(DashboardViewMode.twelveMonth)
            Text("Upcoming").tag(DashboardViewMode.upcoming)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private func navigateToEventScreen(with eventId: String) {
        // TODO: Implement actual navigation to the event detail view
        // 1. ViewModel fetches event by ID.
        // 2. If event found, determine its weekendDate.
        // 3. Set selectedWeekend = event.weekendDate
        // 4. Set showWeekendDetail = true (or a new state for a specific event detail view)
        // For now, we'll just store the ID. A more robust solution is needed.
        self.eventIdForNavigation = eventId 
        print("Attempting to navigate to event with ID: \\(eventId). Further implementation needed.")
        // As a placeholder, if we can get the weekend date from the eventId (e.g. via viewModel),
        // we could do:
        // if let event = viewModel.fetchEvent(byId: eventId), let weekend = event.weekendDate {
        //     self.selectedWeekend = weekend
        //     self.showWeekendDetail = true
        // }
    }
}

// MARK: - Subviews

struct TwelveMonthView: View {
    let weekendStatusMap: [Date: String]
    let onMonthSelected: (Date) -> Void
    
    var body: some View {
        let monthGroups = groupByMonth()
        
        VStack(spacing: 20) {
            // Color legend
            HStack(spacing: 15) {
                legendItem(color: .green, label: "Free")
                legendItem(color: .purple, label: "Plans")
                legendItem(color: .red, label: "Travel")
            }
            .padding(.vertical)
            
            // Month cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(monthGroups.sorted(by: { $0.key < $1.key }), id: \.key) { month, weekends in
                    MonthCardView(
                        month: month,
                        weekends: weekends,
                        weekendStatusMap: weekendStatusMap,
                        onTap: { onMonthSelected(weekends.first!) }
                    )
                }
            }
            .padding(.horizontal)
            
            // Stats at bottom
            countView
                .padding()
        }
        .padding(.bottom)
    }
    
    private func groupByMonth() -> [Date: [Date]] {
        var result = [Date: [Date]]()
        
        // Group weekend dates by month
        for (date, _) in weekendStatusMap {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: date)
            
            // Create a key date for the month (first day of month)
            if let monthDate = calendar.date(from: components) {
                if result[monthDate] == nil {
                    result[monthDate] = [date]
                } else {
                    result[monthDate]?.append(date)
                }
            }
        }
        
        return result
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
        }
    }
    
    private var countView: some View {
        let totalWeekends = weekendStatusMap.count
        
        return HStack {
            Spacer()
            Text("\(totalWeekends)")
                .font(.title)
                .fontWeight(.bold)
        }
    }
}

struct MonthCardView: View {
    let month: Date
    let weekends: [Date]
    let weekendStatusMap: [Date: String]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .center, spacing: 10) {
                Text(monthName)
                    .font(.headline)
                    .padding(.top, 5)
                
                HStack(spacing: 15) {
                    ForEach(weekends.sorted(), id: \.self) { weekend in
                        WeekendStatusDot(status: weekendStatusMap[weekend] ?? "free")
                    }
                }
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: month)
    }
}

struct WeekendStatusDot: View {
    let status: String
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 15, height: 15)
    }
    
    private var statusColor: Color {
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
}

struct UpcomingView: View {
    let weekends: [Date]
    let weekendEvents: [Date: [EventEntity]]
    let onWeekendSelected: (Date) -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            ForEach(weekends, id: \.self) { weekend in
                WeekendCardView(
                    weekend: weekend,
                    events: weekendEvents[weekend] ?? [],
                    onTap: { onWeekendSelected(weekend) }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct WeekendCardView: View {
    let weekend: Date
    let events: [EventEntity]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(weekendDateString)
                        .font(.headline)
                    
                    Spacer()
                    
                    StatusBadge(status: weekendStatus)
                }
                
                Divider()
                
                if events.isEmpty {
                    Text("No events planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(events, id: \.recordIDValue) { event in
                        EventListItemView(event: event)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var weekendDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: weekend)!
        
        return "\(formatter.string(from: weekend)) - \(formatter.string(from: endDate))"
    }
    
    private var weekendStatus: String {
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
}

struct EventListItemView: View {
    let event: EventEntity
    
    var body: some View {
        HStack {
            // Event type indicator
            Circle()
                .fill(eventTypeColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Time
            Text(formattedTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
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
    
    private var formattedTime: String {
        guard let startDate = event.startDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        return formatter.string(from: startDate)
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusLabel)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
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
    
    private var statusLabel: String {
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
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Retry") {
                retryAction()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - Extensions
// Extension for Notification.Name was moved to Utilities/Constants/NotificationNames.swift


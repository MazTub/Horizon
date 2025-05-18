import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month header with navigation
                monthNavigationHeader
                
                // Past toggle
                Toggle("Show Past", isOn: $viewModel.showPastWeekends)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Weekend list
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage, retryAction: {
                        viewModel.loadCurrentMonth()
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.weekends.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.weekends, id: \.self) { weekend in
                                WeekendCalendarCard(
                                    weekend: weekend,
                                    events: viewModel.weekendEvents[weekend] ?? [],
                                    onTap: {
                                        viewModel.selectWeekend(weekend)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("Calendar")
            .sheet(isPresented: $viewModel.isShowingWeekendDetail) {
                if let selectedWeekend = viewModel.selectedWeekend {
                    WeekendDetailSheet(weekendDate: selectedWeekend)
                }
            }
            .onAppear {
                viewModel.loadCurrentMonth()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToMonth)) { notification in
                if let date = notification.object as? Date {
                    viewModel.goToMonth(date)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var monthNavigationHeader: some View {
        HStack {
            Button(action: viewModel.goToPreviousMonth) {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .padding()
            
            Spacer()
            
            Text(viewModel.monthYearString())
                .font(.headline)
            
            Spacer()
            
            Button(action: viewModel.goToNextMonth) {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .padding()
        }
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Weekends to Show")
                .font(.headline)
            
            Text(viewModel.showPastWeekends 
                 ? "There are no weekends in this month."
                 : "There are no upcoming weekends in this month. Enable 'Show Past' to see past weekends.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WeekendCalendarCard: View {
    let weekend: Date
    let events: [EventEntity]
    let onTap: () -> Void
    
    private var isPastWeekend: Bool {
        weekend < Date()
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Weekend header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekendDateString)
                            .font(.headline)
                        
                        Text(weekendDetailString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: weekendStatus)
                }
                
                Divider()
                
                // Event list
                if events.isEmpty {
                    Text("No events planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(events.sorted(by: { $0.startDate ?? Date() < $1.startDate ?? Date() }), id: \.recordIDValue) { event in
                            EventCalendarItemView(event: event)
                        }
                    }
                }
            }
            .padding()
            .background(isPastWeekend ? Color(.systemBackground) : Color(.secondarySystemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
            .opacity(isPastWeekend ? 0.8 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPastWeekend ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
            )
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
    
    private var weekendDetailString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        
        let calendar = Calendar.current
        _ = calendar.date(byAdding: .day, value: 1, to: weekend)!
        
        return "Saturday - Sunday"
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

struct EventCalendarItemView: View {
    let event: EventEntity
    
    var body: some View {
        HStack(alignment: .top) {
            // Time column
            VStack(alignment: .leading) {
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if showsDuration, let durationText = durationText {
                    Text(durationText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Type indicator
            Circle()
                .fill(eventTypeColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
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
                
                if let description = event.eventDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
    }
    
    private var timeString: String {
        guard let startDate = event.startDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        return formatter.string(from: startDate)
    }
    
    private var showsDuration: Bool {
        guard let startDate = event.startDate, let endDate = event.endDate else { return false }
        
        let calendar = Calendar.current
        let duration = calendar.dateComponents([.hour, .minute], from: startDate, to: endDate)
        
        return duration.hour! > 0 || duration.minute! > 0
    }
    
    private var durationText: String? {
        guard let startDate = event.startDate, let endDate = event.endDate else { return nil }
        
        let calendar = Calendar.current
        let duration = calendar.dateComponents([.hour, .minute], from: startDate, to: endDate)
        
        if duration.hour! > 0 {
            if duration.minute! > 0 {
                return "\(duration.hour!)h \(duration.minute!)m"
            } else {
                return "\(duration.hour!)h"
            }
        } else {
            return "\(duration.minute!)m"
        }
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
}

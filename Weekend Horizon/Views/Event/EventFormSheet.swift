import SwiftUI

struct EventFormSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var viewModel: EventViewModel
    
    @State private var showingDeleteConfirmation = false
    
    // Initialize for creating a new event
    init(weekendDate: Date) {
        self._viewModel = StateObject(wrappedValue: EventViewModel(weekendDate: weekendDate))
    }
    
    // Initialize for editing an existing event
    init(event: EventEntity) {
        self._viewModel = StateObject(wrappedValue: EventViewModel(event: event))
    }
    
    var body: some View {
        NavigationView {
            Form {
                EventDetailsSection(viewModel: viewModel)
                DateTimeSection(viewModel: viewModel)
                ReminderSection(viewModel: viewModel)
                
                // Delete button (only for editing)
                if viewModel.eventBeingEdited != nil {
                    Section {
                        Button("Delete Event") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(viewModel.eventBeingEdited != nil ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveEvent()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
            .overlay(LoadingOverlay(isLoading: viewModel.isLoading))
            .alert(item: alertItem) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK")) {
                        if item.isSuccess {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
            .actionSheet(isPresented: $showingDeleteConfirmation) {
                ActionSheet(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event? This action cannot be undone."),
                    buttons: [
                        .destructive(Text("Delete")) {
                            viewModel.deleteEvent()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private var alertItem: AlertItem? {
        if let errorMessage = viewModel.errorMessage {
            return AlertItem(
                title: "Error",
                message: errorMessage,
                isSuccess: false
            )
        } else if let successMessage = viewModel.successMessage {
            return AlertItem(
                title: "Success",
                message: successMessage,
                isSuccess: true
            )
        }
        
        return nil
    }
}

// MARK: - Subviews

struct EventDetailsSection: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        Section(header: Text("Event Details")) {
            TextField("Title", text: $viewModel.title)
                .textContentType(.none)
                .autocapitalization(.words)
            
            Picker("Type", selection: $viewModel.eventType) {
                Text("Plans").tag("plan")
                Text("Travel").tag("travel")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Location", text: $viewModel.location)
                .textContentType(.fullStreetAddress)
            
            DescriptionEditor(description: $viewModel.eventDescription)
        }
    }
}

struct DescriptionEditor: View {
    @Binding var description: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if description.isEmpty {
                Text("Description")
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            
            TextEditor(text: $description)
                .frame(minHeight: 100)
        }
    }
}

struct DateTimeSection: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        Section(header: Text("Date & Time")) {
            DatePicker("Start", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
            
            DatePicker("End", selection: $viewModel.endDate, displayedComponents: [.date, .hourAndMinute])
            
            DaySelectionView(viewModel: viewModel)
        }
    }
}

struct DaySelectionView: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach([1, 2], id: \.self) { day in
                    DaySelectionButton(
                        day: day,
                        isSelected: viewModel.isDaySelected(day),
                        onToggle: {
                            viewModel.toggleDay(day)
                        }
                    )
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReminderSection: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        Section(header: Text("Reminder")) {
            Toggle("Remind me", isOn: $viewModel.reminderEnabled)
            
            if viewModel.reminderEnabled {
                ReminderOptions(viewModel: viewModel)
            }
        }
    }
}

struct ReminderOptions: View {
    @ObservedObject var viewModel: EventViewModel
    
    var body: some View {
        HStack {
            Text("Time Before")
            
            Spacer()
            
            Picker("Time Before", selection: $viewModel.reminderOffset) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
                Text("2 hours").tag(120)
                Text("1 day").tag(1440)
            }
            .pickerStyle(MenuPickerStyle())
        }
        
        Picker("Notification Type", selection: $viewModel.reminderMode) {
            Text("In-App").tag("inApp")
            Text("Push Notification").tag("push")
        }
        .pickerStyle(SegmentedPickerStyle())
    }
}

struct LoadingOverlay: View {
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }
}

struct DaySelectionButton: View {
    let day: Int
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack {
                Text(dayName)
                    .font(.headline)
                
                Text(dayInitial)
                    .font(.subheadline)
            }
            .frame(width: 70, height: 50)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
    }
    
    private var dayName: String {
        switch day {
        case 1:
            return "Sat"
        case 2:
            return "Sun"
        default:
            return ""
        }
    }
    
    private var dayInitial: String {
        switch day {
        case 1:
            return "S"
        case 2:
            return "S"
        default:
            return ""
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isSuccess: Bool
}

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
            } else if !authViewModel.isAuthenticated {
                AuthenticationView()
                    .environmentObject(authViewModel)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            authViewModel.checkAuthStatus()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Dashboard")
                }
                .tag(0)
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .tag(1)
            
            AddEventTabView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
                .tag(3)
        }
    }
}

struct AddEventTabView: View {
    @State private var isShowingAddSheet = false

    var body: some View {
        // Provide a clear UI for the Add tab
        NavigationView { // Add NavigationView for a title
            VStack {
                Spacer()
                Text("Plan a New Weekend Event")
                    .font(.title2)
                    .padding(.bottom)
                Button(action: {
                    isShowingAddSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Event")
                    }
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                Spacer()
                Spacer()
            }
            .navigationTitle("New Event") // Title for the tab view
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationView { // This NavigationView is for AddEventLandingView
                    AddEventLandingView(isShowingSheet: $isShowingAddSheet)
                        .navigationTitle("Select Weekend Date") // More specific title
                        .navigationBarItems(trailing: Button("Cancel") { // Changed from Close to Cancel
                            isShowingAddSheet = false
                        })
                }
                // It might be good to inject the environment(\.managedObjectContext) here 
                // if AddEventLandingView or EventFormSheet need it, 
                // though EventFormSheet might get it from its new presenter.
            }
        }
    }
}

struct AddEventLandingView: View {
    @Binding var isShowingSheet: Bool
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    @State private var showEventFormSheet = false
    @State private var weekendDateForForm: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Weekend")
                .font(.headline)
            
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Text(selectedDate, style: .date)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if showingDatePicker {
                DatePicker("Select a date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Button("Done") {
                    showingDatePicker = false
                }
                .padding()
            }
            
            Button(action: {
                // Find nearest weekend if not already on weekend
                let calendar = Calendar.current
                let weekendDate = calendar.weekendStartDate(for: selectedDate)
                
                // Show event form directly
                self.weekendDateForForm = weekendDate
                self.showEventFormSheet = true
            }) {
                Text("Create Event")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(.top, 20)
        .sheet(isPresented: $showEventFormSheet) {
            if let date = weekendDateForForm {
                EventFormSheet(weekendDate: date)
            }
        }
    }
}

// Helper extension for Calendar
extension Calendar {
    func weekendStartDate(for date: Date) -> Date {
        var weekendDate = date
        // Determine if selected date is a weekend
        if !self.isDateInWeekend(date) {
            // Find next Saturday
            var nextWeekendComponents = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            nextWeekendComponents.weekday = 7 // Saturday (assuming Sunday is 1, Saturday is 7)
            if let nextSaturday = self.date(from: nextWeekendComponents) {
                weekendDate = nextSaturday
            }
        } else if self.component(.weekday, from: date) == 1 { // Sunday
            // Move back to the Saturday of this weekend
            if let saturdayBefore = self.date(byAdding: .day, value: -1, to: date) {
                 weekendDate = saturdayBefore
            }
        }
        // Reset time components to midnight
        return self.date(bySettingHour: 0, minute: 0, second: 0, of: weekendDate) ?? weekendDate
    }
}

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            image: "calendar.badge.clock",
            title: "Plan Your Weekends",
            description: "Easily manage and track your weekend activities in one place."
        ),
        OnboardingPage(
            image: "bell.badge",
            title: "Stay Notified",
            description: "Get reminders for upcoming weekend plans."
        ),
        OnboardingPage(
            image: "icloud",
            title: "Sync Across Devices",
            description: "Your weekend plans stay in sync across all your devices with iCloud."
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                if currentPage == pages.count - 1 {
                    isCompleted = true
                } else {
                    currentPage += 1
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 50)
            
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Extensions
// Extension for Notification.Name was moved to Utilities/Constants/NotificationNames.swift


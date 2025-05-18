import SwiftUI
import Combine
import CloudKit


// Authentication View
struct AuthenticationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 50)
            
            Text("Weekend Planner")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Keep track of your weekend plans")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            
            if viewModel.isLoading {
                ProgressView("Checking iCloud account...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.headline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                Button("Sign in to iCloud") {
                    openSettings()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal, 20)
            } else {
                Button("Sign in with iCloud") {
                    viewModel.checkAuthStatus()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("This app requires an iCloud account")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your data will be securely stored and synced across your devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    // Helper function to open Settings app
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

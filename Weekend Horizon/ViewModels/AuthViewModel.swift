import SwiftUI
import Combine
import CloudKit

// AuthViewModel
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to authentication changes
        cloudKitManager.isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
    }
    
    func checkAuthStatus() {
        isLoading = true
        errorMessage = nil
        
        // Check iCloud account status
        let container = CKContainer(identifier: "iCloud.com.yourcompany.weekendplanner")
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to check iCloud account: \(error.localizedDescription)"
                    self?.isAuthenticated = false
                    return
                }
                
                switch status {
                case .available:
                    self?.isAuthenticated = true
                case .noAccount:
                    self?.errorMessage = "No iCloud account found. Please sign in to iCloud in Settings."
                    self?.isAuthenticated = false
                case .restricted:
                    self?.errorMessage = "Your iCloud account is restricted."
                    self?.isAuthenticated = false
                case .couldNotDetermine:
                    self?.errorMessage = "Could not determine iCloud account status."
                    self?.isAuthenticated = false
                case .temporarilyUnavailable:
                    self?.errorMessage = "iCloud account is temporarily unavailable."
                    self?.isAuthenticated = false
                @unknown default:
                    self?.errorMessage = "Unknown iCloud account status."
                    self?.isAuthenticated = false
                }
            }
        }
    }
}

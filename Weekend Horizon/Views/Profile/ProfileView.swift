import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingImagePicker = false
    @State private var activeAlert: AlertItem?

    
    var body: some View {
        NavigationView {
            Form {
                // Profile header with avatar
                Section {
                    HStack {
                        Spacer()
                        
                        AvatarView(
                            image: viewModel.avatarImage,
                            onTap: {
                                showingImagePicker = true
                            }
                        )
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    TextField("Display Name", text: $viewModel.displayName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                }
                
                // User details
                Section(header: Text("Account Details")) {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(viewModel.email)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Timezone", selection: $viewModel.timezone) {
                        ForEach(viewModel.availableTimezones(), id: \.self) { timezone in
                            Text(timezone).tag(timezone)
                        }
                    }
                }
                
                // Notification settings
                Section(header: Text("Notification Settings")) {
                    if !viewModel.notificationsEnabled {
                        Button("Enable Notifications") {
                            viewModel.requestNotificationPermission()
                        }
                    } else {
                        Toggle("Notifications Enabled", isOn: .constant(true))
                            .disabled(true)
                        
                        HStack {
                            Text("Default Reminder Time")
                            
                            Spacer()
                            
                            Picker("Default Reminder Time", selection: $viewModel.defaultReminderOffset) {
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                                Text("1 hour").tag(60)
                                Text("2 hours").tag(120)
                                Text("1 day").tag(1440)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        Picker("Default Notification Type", selection: $viewModel.defaultReminderMode) {
                            Text("In-App").tag("inApp")
                            Text("Push").tag("push")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                // App info
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy (would be implemented in a real app)
                    }
                    
                    Button("Terms of Service") {
                        // Open terms of service (would be implemented in a real app)
                    }
                }
                
                // Save button
                Section {
                    Button("Save Changes") {
                        viewModel.saveProfile()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Profile")
            .disabled(viewModel.isLoading)
            .overlay(
                ZStack {
                    if viewModel.isLoading {
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                        
                        ProgressView("Saving...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }
                }
            )
            .sheet(isPresented: $showingImagePicker) {
                PhotoPicker(image: $viewModel.avatarImage)
            }
            .alert(item: $activeAlert) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: viewModel.errorMessage) { oldValue, newValue in
                if let errorMessage = newValue {
                    activeAlert = AlertItem(
                        title: "Error",
                        message: errorMessage,
                        isSuccess: false
                    )
                }
            }
            .onChange(of: viewModel.errorMessage) { oldValue, newValue in
                if let successMessage = newValue {
                    activeAlert = AlertItem(
                        title: "Success",
                        message: successMessage,
                        isSuccess: true
                    )
                }
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

struct AvatarView: View {
    let image: UIImage?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.secondary)
                    .overlay(
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white))
                            .offset(x: 30, y: 30)
                    )
            }
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        guard let image = image as? UIImage else { return }
                        self?.parent.image = image
                    }
                }
            }
        }
    }
}

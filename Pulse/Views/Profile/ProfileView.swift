//
//  ProfileView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SafariServices

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingThemeSheet = false
    @State private var showingEditNameSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showingFeedbackSheet = false
    @State private var showingLanguageSheet = false
    @State private var showingChangeEmailSheet = false
    @State private var showingSubscriptionSheet = false
    @State private var showingTimezoneSheet = false
    @State private var showingUnitSheet = false
    @State private var safariURL: URL?
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var unitManager: UnitManager
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Profile Section
                            VStack(spacing: 16) {
                                // Profile Picture (Initials)
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    
                                    Text(getUserInitials())
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.appAccent)
                                }
                                .padding(.top, 30)
                                
                                // User Full Name
                                Text("\(viewModel.profile?.firstName ?? "") \(viewModel.profile?.lastName ?? "")")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.appText)
                                
                                // User Email
                                Text(viewModel.profile?.email ?? "")
                                    .font(.body)
                                    .foregroundStyle(Color.appText.opacity(0.6))
                                
                                // Edit Profile Button
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingEditNameSheet = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Edit Profile")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.appAccent)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            // Subscription Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Subscription")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingSubscriptionSheet = true
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "star.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.appAccent)
                                                .frame(width: 24)
                                            
                                            Text("Plan")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Text(subscriptionManager.isProUser ? "Pro" : "Free")
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.3))
                                        }
                                        .padding()
                                    }
                                }
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top, 20)
                            
                            // Settings Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Settings")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    // Appearance
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingThemeSheet = true
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "paintbrush.fill")
                                                .font(.title3)
                                                .foregroundStyle(Color.appAccent)
                                                .frame(width: 24)
                                            
                                            Text("Appearance")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Text(themeManager.selectedTheme.rawValue)
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.3))
                                        }
                                        .padding()
                                    }
                                    
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    // Language
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingLanguageSheet = true
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "globe")
                                                .font(.title3)
                                                .foregroundStyle(Color.appAccent)
                                                .frame(width: 24)
                                            
                                            Text("Language")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Text(LanguageManager.shared.getCurrentLanguageName())
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.3))
                                        }
                                        .padding()
                                    }
                                    
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    // Units
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingUnitSheet = true
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "ruler")
                                                .font(.title3)
                                                .foregroundStyle(Color.appAccent)
                                                .frame(width: 24)
                                            
                                            Text("Units")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Text(unitManager.unitSystem.displayName)
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.3))
                                        }
                                        .padding()
                                    }
                                    
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    // Timezone
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingTimezoneSheet = true
                                    } label: {
                                        HStack(spacing: 16) {
                                            Image(systemName: "clock.badge.checkmark")
                                                .font(.title3)
                                                .foregroundStyle(Color.appAccent)
                                                .frame(width: 24)
                                            
                                            Text("Timezone")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Text(viewModel.profile?.timezone ?? TimeZone.current.identifier)
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                                .lineLimit(1)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0.3))
                                        }
                                        .padding()
                                    }
                                    
                                    if healthKitManager.isAvailable {
                                        Divider()
                                            .background(Color.appText.opacity(0.1))
                                            .padding(.leading, 56)
                                        
                                        // Apple Health
                                        Button {
                                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                                            impactLight.impactOccurred()
                                            if healthKitManager.isSyncEnabled {
                                                if let url = URL(string: "x-apple-health://") {
                                                    UIApplication.shared.open(url)
                                                }
                                            } else {
                                                Task {
                                                    await healthKitManager.requestAuthorization()
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.appAccent)
                                                    .frame(width: 24)
                                                
                                                Text("Apple Health")
                                                    .font(.body)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                if healthKitManager.isSyncEnabled {
                                                    Text("Connected")
                                                        .font(.body)
                                                        .foregroundStyle(Color.appText.opacity(0.6))
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundStyle(Color.appText.opacity(0.3))
                                                } else {
                                                    Text("Connect")
                                                        .font(.body.weight(.medium))
                                                        .foregroundStyle(Color.appAccent)
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundStyle(Color.appText.opacity(0))
                                                }
                                            }
                                            .padding()
                                        }
                                    }
                                    
                                    // Apple Watch
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    HStack(spacing: 16) {
                                        Image(systemName: "applewatch")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.appAccent)
                                            .frame(width: 24)
                                        
                                        Text("Apple Watch")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        if WorkoutSyncManager.shared.isPaired == true {
                                            Text("Connected")
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0))
                                        } else {
                                            Text("Not Connected")
                                                .font(.body)
                                                .foregroundStyle(Color.appText.opacity(0.6))
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.appText.opacity(0))
                                        }
                                    }
                                    .padding()
                                }
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top, 20)
                            
                            // Support Section
                            VStack(spacing: 0) {
                                // Send Feedback
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingFeedbackSheet = true
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                            .font(.title3)
                                            .foregroundStyle(Color.appAccent)
                                            .frame(width: 24)
                                        
                                        Text("Send Feedback")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.3))
                                    }
                                    .padding()
                                }
                                
                                Divider()
                                    .background(Color.appText.opacity(0.1))
                                    .padding(.leading, 56)
                                
                                // Help & Support
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    openSupportEmail()
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "questionmark.circle")
                                            .font(.title3)
                                            .foregroundStyle(Color.appAccent)
                                            .frame(width: 24)
                                        
                                        Text("Help & Support")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "envelope")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.3))
                                    }
                                    .padding()
                                }
                            }
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            
                            // Sign Out Button
                            Button {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.warning)
                                showingSignOutAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(Color.red)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            // Delete Account Button
                            Button {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.warning)
                                showingDeleteAccountAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    if isDeletingAccount {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    } else {
                                        Image(systemName: "trash")
                                        Text("Delete Account")
                                            .font(.headline)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(Color.red)
                                .cornerRadius(12)
                            }
                            .disabled(isDeletingAccount)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 25)
                        // Terms & Privacy
                        HStack(spacing: 16) {
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/terms-app.html")
                            }) {
                                Text("Terms of Service")
                                    .font(.caption)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                            
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.7))
                            
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/privacy-app.html")
                            }) {
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                        }
                        .padding(.bottom, 10)
                        
                        VStack(spacing: 8) {
                            Text(appVersion)
                                .font(.caption)
                                .foregroundStyle(Color.appText.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } message: {
                Text("Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be removed.")
            }
            .sheet(isPresented: $showingDeleteConfirmation) {
                DeleteAccountConfirmationSheet(
                    isDeletingAccount: $isDeletingAccount,
                    authViewModel: authViewModel
                )
            }
            .sheet(isPresented: $showingEditNameSheet) {
                EditNameSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFeedbackSheet) {
                FeedbackSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingLanguageSheet) {
                LanguageSelectionSheet()
            }
            .sheet(isPresented: $showingChangeEmailSheet) {
                ChangeEmailSheet(
                        authViewModel: authViewModel,
                        onEmailChanged: {
                            Task {
                                await viewModel.loadProfile()
                            }
                        }
                    )
                }
            .sheet(isPresented: $showingThemeSheet) {
                ThemeSelectionSheet()
            }
            .sheet(isPresented: $showingUnitSheet) {
                UnitSelectionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingTimezoneSheet) {
                TimezoneSelectionSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSubscriptionSheet) {
                SubscriptionView()
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            .alert("Apple Health Access", isPresented: $healthKitManager.showDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Workout sharing was not enabled. To allow this later, go to the Health app → Sharing → Apps and grant access to Pulse.")
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    
    private func openSupportEmail() {
        let subject = "Pulse Support Request"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:support@pulsefitness.io?subject=\(encodedSubject)") {
            UIApplication.shared.open(url)
        }
    }
    
    // Helper function to get user initials
    func getUserInitials() -> String {
        let firstName = viewModel.profile?.firstName ?? ""
        let lastName = viewModel.profile?.lastName ?? ""
        
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        
        if firstInitial.isEmpty && lastInitial.isEmpty {
            return "?"
        }
        
        return "\(firstInitial)\(lastInitial)"
    }
}


// MARK: - Profile Row
struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.appText.opacity(0.6))
                
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.appText)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Edit Name Sheet
struct EditNameSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingEditFirstNameSheet = false
    @State private var showingEditLastNameSheet = false
    @State private var showingChangeEmailSheet = false
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        _firstName = State(initialValue: viewModel.profile?.firstName ?? "")
        _lastName = State(initialValue: viewModel.profile?.lastName ?? "")
        _email = State(initialValue: viewModel.profile?.email ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile Initials Circle
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Text(getUserInitials())
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.top, 20)
                        
                        // User Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Account Details")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                // First Name Row
                                HStack(spacing: 16) {
                                    Image(systemName: "person.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.appAccent)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First Name")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.6))
                                        
                                        Text(viewModel.profile?.firstName ?? "Not set")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        showingEditFirstNameSheet = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.callout)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding()
                                
                                Divider()
                                    .background(Color.appText.opacity(0.1))
                                    .padding(.leading, 56)
                                
                                // Last Name Row
                                HStack(spacing: 16) {
                                    Image(systemName: "person.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.appAccent)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last Name")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.6))
                                        
                                        Text(viewModel.profile?.lastName ?? "Not set")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        showingEditLastNameSheet = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.callout)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding()
                                
                                Divider()
                                    .background(Color.appText.opacity(0.1))
                                    .padding(.leading, 56)
                                
                                // Email Row
                                HStack(spacing: 16) {
                                    Image(systemName: "envelope")
                                        .font(.title3)
                                        .foregroundStyle(Color.appAccent)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Email")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.6))
                                        
                                        Text(viewModel.profile?.email ?? "Not set")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        showingChangeEmailSheet = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.callout)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding()
                            }
                            .background(Color.appSurface)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .sheet(isPresented: $showingEditFirstNameSheet) {
            EditFieldSheet(
                title: "First Name",
                value: viewModel.profile?.firstName ?? "",
                placeholder: "First Name",
                onSave: { newValue in
                    Task {
                        await viewModel.updateProfile(
                            firstName: newValue,
                            lastName: viewModel.profile?.lastName ?? ""
                        )
                    }
                }
            )
        }
        .sheet(isPresented: $showingEditLastNameSheet) {
            EditFieldSheet(
                title: "Last Name",
                value: viewModel.profile?.lastName ?? "",
                placeholder: "Last Name",
                onSave: { newValue in
                    Task {
                        await viewModel.updateProfile(
                            firstName: viewModel.profile?.firstName ?? "",
                            lastName: newValue
                        )
                    }
                }
            )
        }
        .sheet(isPresented: $showingChangeEmailSheet) {
            ChangeEmailSheet(
                authViewModel: authViewModel,
                onEmailChanged: {
                    Task {
                        await viewModel.loadProfile()
                    }
                }
            )
        }
    }
    
    func getUserInitials() -> String {
        let firstName = viewModel.profile?.firstName ?? ""
        let lastName = viewModel.profile?.lastName ?? ""
        
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        
        if firstInitial.isEmpty && lastInitial.isEmpty {
            return "?"
        }
        
        return "\(firstInitial)\(lastInitial)"
    }
}

// MARK: - Edit Field Sheet
struct EditFieldSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let title: String
    let value: String
    let placeholder: String
    let onSave: (String) -> Void
    
    @State private var editedValue: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(title: String, value: String, placeholder: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.onSave = onSave
        _editedValue = State(initialValue: value)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    // Error message
                    if showError {
                        Text(errorMessage)
                            .foregroundStyle(Color.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    // Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField(placeholder, text: $editedValue)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if editedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                            errorMessage = "\(title) cannot be empty"
                            showError = true
                        } else {
                            onSave(editedValue)
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Feedback
struct FeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    var viewModel: ProfileViewModel
    @State private var feedbackType: FeedbackType = .feature
    @State private var title = ""
    @State private var description = ""
    @State private var isChecked = false
    
    enum FeedbackType: String, CaseIterable {
        case feature = "Feature Request"
        case bug = "Bug Report"
        case other = "Other"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        Menu {
                            ForEach(FeedbackType.allCases, id: \.self) { type in
                                Button(type.rawValue) {
                                    feedbackType = type
                                }
                            }
                        } label: {
                            HStack {
                                Text(feedbackType.rawValue)
                                    .foregroundStyle(Color.appText)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(Color.appText.opacity(0.6))
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("Title", text: $title)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $description)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .cornerRadius(12)
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        Toggle("I would like to receive updates on my feedback", isOn: $isChecked)
                            .foregroundStyle(Color.appText)
                            .tint(Color.appAccent)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
                
                // Loading overlay
                if viewModel.isSubmittingFeedback {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Submitting feedback...")
                            .foregroundStyle(Color.appText)
                            .font(.headline)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            let success = await viewModel.submitFeedback(
                                type: feedbackType.rawValue,
                                title: title,
                                description: description,
                                isChecked: isChecked
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .foregroundStyle(title.isEmpty || description.isEmpty ? Color.appText.opacity(0.3) : Color.appAccent)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}
// MARK: - Language
struct LanguageSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: String
    @State private var showingRestartAlert = false
    
    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.blue)
                        
                        Text("App will restart to apply language change")
                            .font(.caption)
                            .foregroundStyle(Color.appText.opacity(0.8))
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Language options
                    VStack(spacing: 0) {
                        ForEach(languageManager.supportedLanguages, id: \.0) { code, name in
                            Button {
                                selectedLanguage = code
                            } label: {
                                HStack(spacing: 16) {
                                    Text(name)
                                        .foregroundStyle(Color.appText)
                                        .padding(.leading, 15)
                                    
                                    Spacer()
                                    
                                    if selectedLanguage == code {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding()
                            }
                            
                            if code != languageManager.supportedLanguages.last?.0 {
                                Divider()
                                    .background(Color.appText.opacity(0.1))
                            }
                        }
                        .padding(.trailing, 15)
                    }
                    .background(Color.appSurface)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if selectedLanguage != languageManager.currentLanguage {
                            languageManager.setLanguage(selectedLanguage)
                            showingRestartAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                }
            }
            .alert("Restart Required", isPresented: $showingRestartAlert) {
                Button("OK") {
                    dismiss()
                    // Force restart
                    exit(0)
                }
            } message: {
                Text("The app will now restart to apply the language change.")
            }
        }
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Change Email Sheet
struct ChangeEmailSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    let onEmailChanged: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if showSuccess {
                    // Success view
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.green)
                        
                        Text("Verification Email Sent")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a confirmation email to")
                            .font(.body)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        Text(newEmail)
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Please confirm the change by clicking the link in your inbox. You will be signed out now.")
                            .font(.body)
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("OK") {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                        .foregroundStyle(Color.appText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .cornerRadius(12)
                        .padding(.top, 20)
                    }
                    .padding()
                } else {
                    // Form view
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Change Email Address")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("Enter your new email address and current password to confirm the change. You will be signed out and need to sign back in after confirming.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Email")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            TextField("New Email", text: $newEmail)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(Color.appText)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            SecureField("Current Password", text: $password)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.appText)
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(12)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.red)
                        }
                        
                        Button {
                            Task {
                                await changeEmail()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Change Email")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(isValidForm ? Color.appAccent : Color.appAccent)
                        .cornerRadius(12)
                        .disabled(!isValidForm || isLoading)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(Color.appText)
                    }
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .interactiveDismissDisabled(showSuccess)
    }
    
    var isValidForm: Bool {
        !newEmail.isEmpty &&
        newEmail.contains("@") &&
        !password.isEmpty &&
        password.count >= 6
    }
    
    func changeEmail() async {
        isLoading = true
        errorMessage = nil
        
        let success = await authViewModel.changeEmail(newEmail: newEmail, password: password)
        
        isLoading = false
        
        if success {
            onEmailChanged()
            showSuccess = true
        } else {
            errorMessage = authViewModel.errorMessage ?? "Failed to change email"
        }
    }
}
// MARK: - Delete Account Confirmation Sheet
struct DeleteAccountConfirmationSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isDeletingAccount: Bool
    @ObservedObject var authViewModel: AuthViewModel
    @State private var confirmationText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var isDeleteEnabled: Bool {
        confirmationText == "DELETE"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                        .padding(.top, 20)
                    
                    Text("This action is irreversible")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appText)
                    
                    Text("Your account and all associated data will be permanently deleted.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type DELETE to confirm")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        TextField("DELETE", text: $confirmationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.appText.opacity(0.1), lineWidth: 1)
                            )
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal)
                    
                    Button {
                        isDeletingAccount = true
                        Task {
                            let success = await authViewModel.deleteAccount()
                            isDeletingAccount = false
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Delete Account")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(isDeleteEnabled ? Color.red : Color.red.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isDeleteEnabled || isDeletingAccount)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appText)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.appBackground)
    }
}


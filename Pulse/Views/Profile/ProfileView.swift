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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.appAccent)
                        Text("Loading profile…")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile Header
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appAccentSubtle)
                                        .frame(width: 96, height: 96)
                                    
                                    Text(getUserInitials())
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.appAccent)
                                }
                                .padding(.top, 24)
                                
                                Text("\(viewModel.profile?.firstName ?? "") \(viewModel.profile?.lastName ?? "")")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Text(viewModel.profile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingEditNameSheet = true
                                } label: {
                                    Text("Edit Profile")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appAccent)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(Color.appAccentSubtle)
                                        )
                                }
                                .buttonStyle(ScalePressStyle())
                                .padding(.top, 4)
                            }
                            
                            // Subscription Section
                            VStack(alignment: .leading, spacing: 10) {
                                DashboardSectionHeader(title: "Subscription")
                                    .padding(.horizontal)
                                
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingSubscriptionSheet = true
                                } label: {
                                    HStack(spacing: 14) {
                                        IconBadge(systemName: "star.fill", size: 32)
                                        
                                        Text("Plan")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        Text(subscriptionManager.isProUser ? "Pro" : "Free")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appSecondaryText)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.appTertiaryText)
                                    }
                                    .padding(14)
                                    .background(Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .profileCardShadow(colorScheme: colorScheme)
                                }
                                .buttonStyle(ScalePressStyle())
                                .padding(.horizontal)
                            }
                            
                            // Settings Section
                            VStack(alignment: .leading, spacing: 10) {
                                DashboardSectionHeader(title: "Settings")
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    // Appearance
                                    ProfileSettingsRow(icon: "paintbrush.fill", title: "Appearance", value: themeManager.selectedTheme.rawValue) {
                                        showingThemeSheet = true
                                    }
                                    
                                    ProfileDivider()
                                    
                                    // Language
                                    ProfileSettingsRow(icon: "globe", title: "Language", value: LanguageManager.shared.getCurrentLanguageName()) {
                                        showingLanguageSheet = true
                                    }
                                    
                                    ProfileDivider()
                                    
                                    // Units
                                    ProfileSettingsRow(icon: "ruler", title: "Units", value: unitManager.unitSystem.displayName) {
                                        showingUnitSheet = true
                                    }
                                    
                                    ProfileDivider()
                                    
                                    // Timezone
                                    ProfileSettingsRow(icon: "clock.badge.checkmark", title: "Timezone", value: viewModel.profile?.timezone ?? TimeZone.current.identifier, lineLimit: 1) {
                                        showingTimezoneSheet = true
                                    }
                                    
                                    if healthKitManager.isAvailable {
                                        ProfileDivider()
                                        
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
                                            HStack(spacing: 14) {
                                                IconBadge(systemName: "heart.fill", color: .pink, size: 32)
                                                
                                                Text("Apple Health")
                                                    .font(.body)
                                                    .foregroundStyle(Color.appText)
                                                
                                                Spacer()
                                                
                                                if healthKitManager.isSyncEnabled {
                                                    Text("Connected")
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundStyle(.green)
                                                } else {
                                                    Text("Connect")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundStyle(Color.appAccent)
                                                }
                                            }
                                            .padding(14)
                                        }
                                    }
                                    
                                    ProfileDivider()
                                    
                                    // Apple Watch
                                    HStack(spacing: 14) {
                                        IconBadge(systemName: "applewatch", size: 32)
                                        
                                        Text("Apple Watch")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        Text(WorkoutSyncManager.shared.isPaired == true ? "Connected" : "Not Connected")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(WorkoutSyncManager.shared.isPaired == true ? .green : Color.appSecondaryText)
                                    }
                                    .padding(14)
                                }
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .profileCardShadow(colorScheme: colorScheme)
                                .padding(.horizontal)
                            }
                            
                            // Support Section
                            VStack(alignment: .leading, spacing: 10) {
                                DashboardSectionHeader(title: "Support")
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    // Send Feedback
                                    ProfileSettingsRow(icon: "bubble.left.and.exclamationmark.bubble.right", title: "Send Feedback") {
                                        showingFeedbackSheet = true
                                    }
                                    
                                    ProfileDivider()
                                    
                                    // Help & Support
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        openSupportEmail()
                                    } label: {
                                        HStack(spacing: 14) {
                                            IconBadge(systemName: "questionmark.circle", size: 32)
                                            
                                            Text("Help & Support")
                                                .font(.body)
                                                .foregroundStyle(Color.appText)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "envelope")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.appTertiaryText)
                                        }
                                        .padding(14)
                                    }
                                }
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .profileCardShadow(colorScheme: colorScheme)
                                .padding(.horizontal)
                            }
                            
                            // Sign Out Button
                            Button {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.warning)
                                showingSignOutAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Sign Out")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(ScalePressStyle())
                            .padding(.horizontal)
                            
                            // Delete Account Button
                            Button {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.warning)
                                showingDeleteAccountAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .tint(.red)
                                    } else {
                                        Image(systemName: "trash")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Delete Account")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .foregroundStyle(.red.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(ScalePressStyle())
                            .disabled(isDeletingAccount)
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        
                        // Terms & Privacy
                        HStack(spacing: 16) {
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/terms-app.html")
                            }) {
                                Text("Terms of Service")
                                    .font(.caption)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                            
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color.appTertiaryText)
                            
                            Button(action: {
                                safariURL = URL(string: "https://pulsefitness.io/privacy-app.html")
                            }) {
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        Text(appVersion)
                            .font(.caption2)
                            .foregroundStyle(Color.appTertiaryText)
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


// MARK: - Profile Helpers

private struct ProfileSettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var lineLimit: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button {
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, size: 32)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.appText)
                
                Spacer()
                
                if let value {
                    Text(value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appSecondaryText)
                        .lineLimit(lineLimit)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTertiaryText)
            }
            .padding(14)
        }
    }
}

private struct ProfileDivider: View {
    var body: some View {
        Divider()
            .background(Color.appText.opacity(0.06))
            .padding(.leading, 60)
    }
}

private struct ProfileCardShadowModifier: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                radius: 16, x: 0, y: 6
            )
    }
}

private extension View {
    func profileCardShadow(colorScheme: ColorScheme) -> some View {
        modifier(ProfileCardShadowModifier(colorScheme: colorScheme))
    }
}

// MARK: - Edit Name Sheet
struct EditNameSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Header
                        IconBadge(systemName: "person.crop.circle.fill", size: 52)
                            .padding(.top, 24)
                        
                        Text("Edit Profile")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Manage your account details")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Account Details Card
                        VStack(spacing: 0) {
                            // First Name Row
                            EditNameRow(icon: "person.fill", label: "First Name", value: viewModel.profile?.firstName ?? "Not set") {
                                showingEditFirstNameSheet = true
                            }
                            
                            ProfileDivider()
                            
                            // Last Name Row
                            EditNameRow(icon: "person.fill", label: "Last Name", value: viewModel.profile?.lastName ?? "Not set") {
                                showingEditLastNameSheet = true
                            }
                            
                            ProfileDivider()
                            
                            // Email Row
                            EditNameRow(icon: "envelope.fill", label: "Email", value: viewModel.profile?.email ?? "Not set") {
                                showingChangeEmailSheet = true
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .profileCardShadow(colorScheme: colorScheme)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
}

private struct EditNameRow: View {
    let icon: String
    let label: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    Text(value)
                        .font(.body)
                        .foregroundStyle(Color.appText)
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appAccent)
                    .padding(8)
                    .background(Color.appAccentSubtle)
                    .clipShape(Circle())
            }
            .padding(14)
        }
    }
}

// MARK: - Edit Field Sheet
struct EditFieldSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    IconBadge(systemName: "pencil.circle.fill", size: 48)
                        .padding(.top, 24)
                    
                    Text("Edit \(title)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    // Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)
                            .textCase(.uppercase)
                        
                        TextField(placeholder, text: $editedValue)
                            .textInputAutocapitalization(.words)
                            .focused($isFocused)
                            .padding(14)
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isFocused ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                            )
                            .submitLabel(.done)
                            .onSubmit { save() }
                    }
                    .padding(.horizontal)
                    
                    if showError {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    PrimaryCTAButton("Save", icon: "checkmark") {
                        save()
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appSecondaryText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .onAppear { isFocused = true }
    }
    
    private func save() {
        if editedValue.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "\(title) cannot be empty"
            showError = true
        } else {
            onSave(editedValue)
            dismiss()
        }
    }
}

// MARK: - Feedback
struct FeedbackSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var viewModel: ProfileViewModel
    @State private var feedbackType: FeedbackType = .feature
    @State private var title = ""
    @State private var description = ""
    @State private var isChecked = false
    @FocusState private var focusedField: FeedbackField?
    
    enum FeedbackType: String, CaseIterable {
        case feature = "Feature Request"
        case bug = "Bug Report"
        case other = "Other"
    }
    
    private enum FeedbackField {
        case title, description
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        IconBadge(systemName: "bubble.left.and.exclamationmark.bubble.right.fill", size: 48)
                            .padding(.top, 24)
                        
                        Text("Send Feedback")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Help us improve Pulse")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TYPE")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                            
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
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(Color.appSecondaryText)
                                        .font(.caption)
                                }
                                .padding(14)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITLE")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                            
                            TextField("Brief summary", text: $title)
                                .focused($focusedField, equals: .title)
                                .padding(14)
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(focusedField == .title ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                            
                            TextEditor(text: $description)
                                .focused($focusedField, equals: .description)
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(Color.appSurface)
                                .foregroundStyle(Color.appText)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(focusedField == .description ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                )
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.horizontal)
                        
                        Toggle(isOn: $isChecked) {
                            Text("Receive updates on my feedback")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText)
                        }
                        .tint(Color.appAccent)
                        .padding(.horizontal)
                        
                        PrimaryCTAButton("Submit Feedback", icon: "paperplane.fill") {
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
                        .opacity(isFormValid ? 1 : 0.5)
                        .disabled(!isFormValid)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
                
                // Loading overlay
                if viewModel.isSubmittingFeedback {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        
                        Text("Submitting…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appSecondaryText)
                }
            }
        }
        .presentationBackground(Color.appBackground)
    }
}
// MARK: - Language
struct LanguageSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: String
    @State private var showingRestartAlert = false
    
    init() {
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    IconBadge(systemName: "globe", size: 48)
                        .padding(.top, 24)
                    
                    Text("Language")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Choose your preferred language")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    // Info banner
                    Label("App will restart to apply language change", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                    
                    // Language options
                    VStack(spacing: 0) {
                        ForEach(languageManager.supportedLanguages, id: \.0) { code, name in
                            Button {
                                selectedLanguage = code
                                if selectedLanguage != languageManager.currentLanguage {
                                    languageManager.setLanguage(selectedLanguage)
                                    showingRestartAlert = true
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(systemName: iconForLanguage(code), size: 32)
                                    
                                    Text(name)
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if selectedLanguage == code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appAccent)
                                    }
                                }
                                .padding(14)
                            }
                            
                            if code != languageManager.supportedLanguages.last?.0 {
                                Divider()
                                    .background(Color.appText.opacity(0.06))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: colorScheme == .light ? Color.black.opacity(0.08) : Color.clear,
                        radius: 16, x: 0, y: 6
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
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
    
    private func iconForLanguage(_ code: String) -> String {
        switch code {
        case "sv": return "textformat.abc"
        case "en": return "textformat.abc"
        default: return "character.textbox"
        }
    }
}

// MARK: - Change Email Sheet
struct ChangeEmailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: EmailField?
    let onEmailChanged: () -> Void
    
    private enum EmailField {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                if showSuccess {
                    // Success view
                    VStack(spacing: 20) {
                        IconBadge(systemName: "checkmark.circle.fill", color: .green, size: 56)
                            .padding(.top, 40)
                        
                        Text("Verification Email Sent")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a confirmation email to")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        Text(newEmail)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Please confirm the change by clicking the link in your inbox. You will be signed out now.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        PrimaryCTAButton("OK") {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                } else {
                    // Form view
                    ScrollView {
                        VStack(spacing: 20) {
                            IconBadge(systemName: "envelope.circle.fill", size: 48)
                                .padding(.top, 24)
                            
                            Text("Change Email")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)
                            
                            Text("Enter your new email and current password. You will be signed out after confirming.")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NEW EMAIL")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                TextField("email@example.com", text: $newEmail)
                                    .textFieldStyle(.plain)
                                    .textInputAutocapitalization(.never)
                                    .foregroundStyle(Color.appText)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .padding(14)
                                    .background(Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(focusedField == .email ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT PASSWORD")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Color.appText)
                                    .focused($focusedField, equals: .password)
                                    .padding(14)
                                    .background(Color.appSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(focusedField == .password ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal)
                            
                            if let error = errorMessage {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                            
                            PrimaryCTAButton(isLoading ? "Changing…" : "Change Email", icon: "envelope.badge") {
                                Task {
                                    await changeEmail()
                                }
                            }
                            .opacity(isValidForm ? 1 : 0.5)
                            .disabled(!isValidForm || isLoading)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .interactiveDismissDisabled(showSuccess)
        .onAppear { focusedField = .email }
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
    @Environment(\.colorScheme) private var colorScheme
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
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    IconBadge(systemName: "exclamationmark.triangle.fill", color: .red, size: 48)
                        .padding(.top, 24)
                    
                    Text("This action is irreversible")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Your account and all associated data will be permanently deleted.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPE DELETE TO CONFIRM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)
                        
                        TextField("DELETE", text: $confirmationText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isTextFieldFocused ? Color.red : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
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
                        HStack(spacing: 8) {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.subheadline.weight(.semibold))
                                Text("Delete Account")
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isDeleteEnabled ? [.red, .red.opacity(0.8)] : [.red.opacity(0.3), .red.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScalePressStyle())
                    .disabled(!isDeleteEnabled || isDeletingAccount)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appSecondaryText)
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


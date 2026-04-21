//
//  ProfileView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SafariServices

struct ProfileView: View {
    @ObservedObject var progressViewModel: ProgressStatsViewModel
    @ObservedObject var milestoneViewModel: MilestoneViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var unitManager: UnitManager
    @State private var showingEditNameSheet = false
    @State private var sectionAnimationId = UUID()
    @Environment(\.tabBarBottomInset) private var tabBarBottomInset
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.splashDismissed) private var splashDismissed
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    if splashDismissed {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.appAccent)
                            Text("Loading profile…", comment: "Loading state")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Settings button top-right
                            HStack {
                                Spacer()
                                NavigationLink {
                                    SettingsView()
                                        .hidesTabBar()
                                } label: {
                                    Image("settings")
                                        .font(.body)
                                        .foregroundStyle(Color.appSecondaryText)
                                        .padding(10)
                                        .background(Color.appSurface)
                                        .clipShape(Circle())
                                }
                                .accessibilityIdentifier("profileSettingsButton")
                                .spotlightTarget("settingsButton")
                                .padding(.trailing, 16)
                            }
                            
                            // Profile Header
                            StaggeredItem(delay: 0.05, animate: true) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.appAccentSubtle)
                                            .frame(width: 96, height: 96)
                                        
                                        Text(getUserInitials())
                                            .font(.system(size: 34, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    
                                    if let displayName = profileDisplayName {
                                        Text(displayName)
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(Color.appText)
                                        
                                        if let email = displayEmail {
                                            Text(email)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appSecondaryText)
                                        }
                                    } else if let email = displayEmail {
                                        Text(email)
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(Color.appText)
                                    } else {
                                        Text("Pulse Member", comment: "Default profile name")
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(Color.appText)
                                    }
                                    
                                    Button {
                                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                                        impactLight.impactOccurred()
                                        showingEditNameSheet = true
                                    } label: {
                                        Text(profileDisplayName == nil ? String(localized: "Add Name") : String(localized: "Edit Profile"))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appAccent)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(Color.appAccentSubtle)
                                            )
                                    }
                                    .accessibilityIdentifier("profileEditButton")
                                    .buttonStyle(ScalePressStyle())
                                    .padding(.top, 4)
                                }
                            }
                            .id("header-\(sectionAnimationId)")
                            
                            // Milestones
                            StaggeredItem(delay: 0.12, animate: true) {
                                MilestonesSection(viewModel: milestoneViewModel)
                            }
                            .id("milestones-\(sectionAnimationId)")
                            
                            // My Exercises
                            StaggeredItem(delay: 0.19, animate: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("My Custom Exercises", comment: "Section header")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if !viewModel.customExercises.isEmpty {
                                        NavigationLink(destination: AllCustomExercisesView(viewModel: viewModel).hidesTabBar()) {
                                            Text("See All", comment: "Navigation link")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.appAccent)
                                        }
                                        .accessibilityIdentifier("customExercisesSeeAll")
                                    }
                                }
                                .padding(.horizontal)
                                
                                if viewModel.customExercises.isEmpty {
                                    VStack(spacing: 14) {
                                        IconBadge(assetName: "clipboard-text", size: 48)
                                        
                                        Text("No custom exercises yet", comment: "Empty state")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appText)
                                        
                                        Text("Create custom exercises when adding to a routine", comment: "Empty state hint")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(28)
                                    .background {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.appSurface)
                                            .modifier(CardShadowModifier())
                                    }
                                    .padding(.horizontal)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(viewModel.customExercises.prefix(3)) { exercise in
                                            CustomExerciseCard(exercise: exercise)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("profileCustomExercisesSection")
                            .id("exercises-\(sectionAnimationId)")
                            
                            // Completed Workouts
                            StaggeredItem(delay: 0.26, animate: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Completed Workouts", comment: "Section header")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if !progressViewModel.recentSessions.isEmpty {
                                        NavigationLink(destination: AllRecentWorkoutsView().hidesTabBar()) {
                                            Text("See All", comment: "Navigation link")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.appAccent)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                if progressViewModel.recentSessions.isEmpty {
                                    VStack(spacing: 14) {
                                        IconBadge(assetName: "clock", size: 48)
                                        
                                        Text("No workout history yet", comment: "Empty state")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appText)
                                        
                                        Text("Complete your first workout to see it here", comment: "Empty state hint")
                                            .font(.caption)
                                            .foregroundStyle(Color.appSecondaryText)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(28)
                                    .background {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.appSurface)
                                            .modifier(CardShadowModifier())
                                    }
                                    .padding(.horizontal)
                                } else {
                                    ForEach(progressViewModel.recentSessions.prefix(3)) { session in
                                        RecentWorkoutCard(
                                            session: session,
                                            viewModel: progressViewModel
                                        )
                                    }
                                }
                            }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("profileCompletedWorkoutsSection")
                            .id("workouts-\(sectionAnimationId)")
                            
                            // Lifetime Stats
                            StaggeredItem(delay: 0.33, animate: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                DashboardSectionHeader(title: "Lifetime Stats")

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    LifetimeStatCard(
                                        title: String(localized: "Total Workouts"),
                                        value: "\(progressViewModel.lifetimeWorkouts)",
                                        icon: "workout"
                                    )

                                    LifetimeStatCard(
                                        title: String(localized: "Total Volume"),
                                        value: "\(Int(unitManager.displayWeight(Double(progressViewModel.lifetimeVolume))))\(unitManager.weightUnit)",
                                        icon: "volume"
                                    )

                                    LifetimeStatCard(
                                        title: String(localized: "Time Trained"),
                                        value: "\(progressViewModel.lifetimeHours)h",
                                        icon: "clock"
                                    )

                                    LifetimeStatCard(
                                        title: String(localized: "Longest Streak"),
                                        value: "\(progressViewModel.bestStreak) \(progressViewModel.bestStreak == 1 ? String(localized: "day") : String(localized: "days"))",
                                        icon: "flame"
                                    )
                                }
                                .padding(.horizontal)
                            }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("profileLifetimeStatsSection")
                            .id("stats-\(sectionAnimationId)")
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20 + tabBarBottomInset)
                    }
                }
            }
            .sentryScreen("Profile")
            .toolbarBackground(LinearGradient.dashboardBackground, for: .navigationBar)
            .sheet(isPresented: $showingEditNameSheet) {
                EditNameSheet(viewModel: viewModel)
                    .sheetContentTransition()
            }
            .onAppear {
                sectionAnimationId = UUID()
            }
            .task {
                await viewModel.loadProfile()
            }
        }
        }
    
    // Whether the email is an Apple private relay address
    private var isPrivateRelayEmail: Bool {
        viewModel.profile?.email?.contains("privaterelay.appleid.com") == true
    }
    
    // Email to display — nil when it's a private relay address
    private var displayEmail: String? {
        guard let email = viewModel.profile?.email, !isPrivateRelayEmail else { return nil }
        return email
    }
    
    // Formatted display name, nil when both first and last are empty
    private var profileDisplayName: String? {
        let first = viewModel.profile?.firstName ?? ""
        let last = viewModel.profile?.lastName ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? nil : combined
    }
    
    // Helper function to get user initials
    func getUserInitials() -> String {
        let firstName = viewModel.profile?.firstName ?? ""
        let lastName = viewModel.profile?.lastName ?? ""
        
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        
        if firstInitial.isEmpty && lastInitial.isEmpty {
            // Fall back to the first letter of the email, but not for private relay
            if let email = displayEmail, let initial = email.first?.uppercased() {
                return initial
            }
            return "?"
        }
        
        return "\(firstInitial)\(lastInitial)"
    }
}


// MARK: - Profile Helpers

struct ProfileSettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    var value: String? = nil
    var lineLimit: Int? = nil
    var isSystemImage: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button {
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                if isSystemImage {
                    IconBadge(systemName: icon, size: 32)
                } else {
                    IconBadge(assetName: icon, size: 32)
                }
                
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
                
                Image("chevron-right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.appTertiaryText)
            }
            .padding(14)
        }
    }
}

struct ProfileDivider: View {
    var body: some View {
        Divider()
            .background(Color.appText.opacity(0.06))
            .padding(.leading, 60)
    }
}

struct ProfileCardShadowModifier: ViewModifier {
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

extension View {
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
    @State private var isSaving = false
    
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
                        IconBadge(assetName: "profile", size: 52)
                            .padding(.top, 24)
                        
                        Text("Edit Profile", comment: "Sheet title")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Manage your account details", comment: "Sheet subtitle")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Account Details Card
                        VStack(spacing: 0) {
                            // First Name Row
                            EditNameRow(icon: "profile", label: String(localized: "First Name"), value: (viewModel.profile?.firstName?.isEmpty == false ? viewModel.profile?.firstName : nil) ?? String(localized: "Not set")) {
                                showingEditFirstNameSheet = true
                            }
                            .accessibilityIdentifier("editFirstNameRow")
                            
                            ProfileDivider()
                            
                            // Last Name Row
                            EditNameRow(icon: "profile", label: String(localized: "Last Name"), value: (viewModel.profile?.lastName?.isEmpty == false ? viewModel.profile?.lastName : nil) ?? String(localized: "Not set")) {
                                showingEditLastNameSheet = true
                            }
                            .accessibilityIdentifier("editLastNameRow")
                            
                            if let email = viewModel.profile?.email {
                                ProfileDivider()
                                
                                if authViewModel.isAppleUser {
                                    // Read-only display for Apple Sign-In users
                                    HStack(spacing: 14) {
                                        IconBadge(assetName: "envelope", size: 32)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Email", comment: "Field label")
                                                .font(.caption)
                                                .foregroundStyle(Color.appSecondaryText)
                                            
                                            Text(email)
                                                .font(.body)
                                                .foregroundStyle(Color.appSecondaryText)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(14)
                                } else {
                                    // Editable for email/password users
                                    EditNameRow(icon: "envelope", label: String(localized: "Email"), value: email) {
                                        showingChangeEmailSheet = true
                                    }
                                }
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .profileCardShadow(colorScheme: colorScheme)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .opacity(isSaving ? 0.3 : 1)
                
                if isSaving {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.appAccent)
                        Text("Saving…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSaving)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationBackground(Color.appBackground)
        .sheet(isPresented: $showingEditFirstNameSheet) {
            EditFieldSheet(
                title: String(localized: "First Name"),
                value: viewModel.profile?.firstName ?? "",
                placeholder: String(localized: "First Name"),
                onSave: { newValue in
                    let currentLastName = viewModel.profile?.lastName ?? ""
                    isSaving = true
                    Task {
                        await viewModel.updateProfile(
                            firstName: newValue,
                            lastName: currentLastName
                        )
                        isSaving = false
                    }
                }
            )
            .sheetContentTransition()
        }
        .sheet(isPresented: $showingEditLastNameSheet) {
            EditFieldSheet(
                title: String(localized: "Last Name"),
                value: viewModel.profile?.lastName ?? "",
                placeholder: String(localized: "Last Name"),
                onSave: { newValue in
                    let currentFirstName = viewModel.profile?.firstName ?? ""
                    isSaving = true
                    Task {
                        await viewModel.updateProfile(
                            firstName: currentFirstName,
                            lastName: newValue
                        )
                        isSaving = false
                    }
                }
            )
            .sheetContentTransition()
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
            .sheetContentTransition()
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
                IconBadge(assetName: icon, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    Text(value)
                        .font(.body)
                        .foregroundStyle(Color.appText)
                }
                
                Spacer()
                
                Image("pencil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
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
    let maxLength: Int
    let onSave: (String) -> Void
    
    @State private var editedValue: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    /// Threshold at which the character counter becomes visible
    private var counterVisibleThreshold: Int { maxLength - 10 }
    
    init(title: String, value: String, placeholder: String, maxLength: Int = 50, onSave: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.onSave = onSave
        _editedValue = State(initialValue: value)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    IconBadge(assetName: "pencil", size: 48)
                        .padding(.top, 24)
                    
                    Text("Edit \(title)", comment: "Edit field sheet title")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    // Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)
                            .textCase(.uppercase)
                        
                        HStack {
                            TextField(placeholder, text: $editedValue)
                                .textInputAutocapitalization(.words)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .foregroundStyle(Color.appText)
                                .submitLabel(.done)
                                .onSubmit { save() }
                                .onChange(of: editedValue) { _, newValue in
                                    editedValue = sanitizeInput(newValue, maxLength: maxLength)
                                }
                        }
                        .padding(14)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isFocused ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                        )
                        .onTapGesture { isFocused = true }
                        
                        // Character counter (visible when close to limit)
                        if editedValue.count >= counterVisibleThreshold {
                            HStack {
                                Spacer()
                                Text("\(editedValue.count)/\(maxLength)")
                                    .font(.caption2)
                                    .foregroundStyle(editedValue.count >= maxLength ? .red : Color.appSecondaryText)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: editedValue.count >= counterVisibleThreshold)
                    
                    if showError {
                        HStack(spacing: 4) {
                            Image("error")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text(errorMessage)
                        }
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                    
                    PrimaryCTAButton("Save", icon: "check") {
                        save()
                    }
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
        }
        .presentationBackground(Color.appBackground)
        .onAppear { isFocused = true }
    }
    
    private func save() {
        let trimmed = editedValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            errorMessage = "\(title) cannot be empty"
            showError = true
        } else {
            onSave(trimmed)
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
    @State private var showSuccess = false
    @FocusState private var focusedField: FeedbackField?
    
    enum FeedbackType: String, CaseIterable {
        case feature = "Feature Request"
        case bug = "Bug Report"
        case other = "Other"

        var displayName: String {
            switch self {
            case .feature: String(localized: "Feature Request")
            case .bug: String(localized: "Bug Report")
            case .other: String(localized: "Other")
            }
        }
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
                        IconBadge(assetName: "clipboard-text", size: 48)
                            .padding(.top, 24)
                        
                        Text("Send Feedback", comment: "Sheet title")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Help us improve Pulse", comment: "Sheet subtitle")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TYPE")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appSecondaryText)
                            
                            Menu {
                                ForEach(FeedbackType.allCases, id: \.self) { type in
                                    Button(type.displayName) {
                                        feedbackType = type
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(feedbackType.displayName)
                                        .foregroundStyle(Color.appText)
                                    Spacer()
                                    Image("updown")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
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
                            
                            HStack {
                                TextField("Brief summary", text: $title)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .title)
                                    .foregroundStyle(Color.appText)
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(focusedField == .title ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                            )
                            .onTapGesture { focusedField = .title }
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
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(Color.appText)
                                .padding(10)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(focusedField == .description ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                )
                                .onTapGesture { focusedField = .description }
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Receive updates on my feedback?", comment: "Feedback preference")
                                .font(.subheadline)
                                .foregroundStyle(Color.appText)
                            
                            HStack(spacing: 10) {
                                Button {
                                    isChecked = true
                                } label: {
                                    Text("Yes")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(isChecked ? .white : Color.appText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isChecked ? Color.appAccent : Color.appSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(isChecked ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    isChecked = false
                                } label: {
                                    Text("No")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(!isChecked ? .white : Color.appText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(!isChecked ? Color.appAccent : Color.appSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(!isChecked ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        PrimaryCTAButton("Submit Feedback", icon: "send") {
                            Task {
                                let success = await viewModel.submitFeedback(
                                    type: feedbackType.rawValue,
                                    title: title,
                                    description: description,
                                    isChecked: isChecked
                                )
                                if success {
                                    let notificationFeedback = UINotificationFeedbackGenerator()
                                    notificationFeedback.notificationOccurred(.success)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showSuccess = true
                                    }
                                    try? await Task.sleep(for: .seconds(1.5))
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
                
                // Success confirmation overlay
                if showSuccess {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image("check-circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Feedback Sent!", comment: "Success message")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)

                        Text("Thanks for helping us improve Pulse", comment: "Success subtitle")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .padding(.horizontal, 40)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .sentryScreen("Feedback")
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
// MARK: - Change Email Sheet
struct ChangeEmailSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.signOutAction) private var signOutAction
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var newEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var isDismissing = false
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
                        IconBadge(assetName: "check-circle", color: .green, size: 56)
                            .padding(.top, 40)
                        
                        Text("Verification Email Sent", comment: "Email change success")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a confirmation email to", comment: "Email change info")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        Text(newEmail)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Please confirm the change by clicking the link in your inbox. You will be signed out now.", comment: "Email change instructions")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        PrimaryCTAButton("OK") {
                            isDismissing = true
                            Task {
                                // Wait for the fade-out animation to finish
                                try? await Task.sleep(for: .milliseconds(350))
                                await signOutAction()
                            }
                        }
                        .disabled(isDismissing)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    // Form view
                    ScrollView {
                        VStack(spacing: 20) {
                            IconBadge(assetName: "envelope", size: 48)
                                .padding(.top, 24)
                            
                            Text("Change Email", comment: "Sheet title")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)

                            Text("Enter your new email and current password. You will be signed out after confirming.", comment: "Sheet instructions")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NEW EMAIL")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                HStack {
                                TextField("Enter new email", text: $newEmail)
                                    .textFieldStyle(.plain)
                                    .textInputAutocapitalization(.never)
                                    .foregroundStyle(Color.appText)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .onChange(of: newEmail) { _, newValue in
                                        newEmail = sanitizeInput(newValue, maxLength: 254)
                                    }
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(focusedField == .email ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                            )
                            .onTapGesture { focusedField = .email }
                                
                                // Character counter (visible when close to limit)
                                if newEmail.count >= 244 {
                                    HStack {
                                        Spacer()
                                        Text("\(newEmail.count)/254")
                                            .font(.caption2)
                                            .foregroundStyle(newEmail.count >= 254 ? .red : Color.appSecondaryText)
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: newEmail.count >= 244)
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CURRENT PASSWORD")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                HStack {
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(Color.appText)
                                        .focused($focusedField, equals: .password)
                                }
                                .padding(14)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(focusedField == .password ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear), lineWidth: 1)
                                )
                                .onTapGesture { focusedField = .password }
                            }
                            .padding(.horizontal)
                            
                            if let error = errorMessage {
                                HStack(spacing: 4) {
                                    Image("error")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                    Text(error)
                                }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                            
                            PrimaryCTAButton(isLoading ? "Changing…" : "Change Email", icon: "check") {
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
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            .overlay {
                if isDismissing {
                    Color.appBackground
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.appAccent)
                                Text("Signing out…")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: isDismissing)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showSuccess && !isDismissing {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
        }
        .presentationBackground(Color.appBackground)
        .interactiveDismissDisabled(showSuccess || isDismissing)
        .onAppear { focusedField = .email }
    }
    
    var isValidForm: Bool {
        !newEmail.isEmpty &&
        newEmail.contains("@") &&
        !password.isEmpty &&
        password.count >= 6
    }
    
    func changeEmail() async {
        focusedField = nil // Dismiss keyboard before transition
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
    @Environment(\.deleteAccountAction) private var deleteAccountAction
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
                    IconBadge(assetName: "error", color: .red, size: 48)
                        .padding(.top, 24)
                    
                    Text("This action is irreversible", comment: "Delete account warning")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.appText)
                    
                    Text("Your account and all associated data will be permanently deleted.", comment: "Delete account warning detail")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "TYPE DELETE TO CONFIRM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appSecondaryText)

                        TextField(text: $confirmationText) { Text(verbatim: "DELETE") }
                            .textInputAutocapitalization(.characters)
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
                            dismiss()
                            let success = await deleteAccountAction()
                            isDeletingAccount = false
                            if !success {
                                // If deletion failed, the overlay won't dismiss
                                // because isAuthenticated didn't change
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image("trash")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
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
            .sentryScreen("DeleteAccountConfirmation")
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

// MARK: - Custom Exercise Card

struct CustomExerciseCard: View {
    let exercise: Exercise
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                assetName: exercise.exerciseType?.lowercased() == "cardio" ? "cardio" : "musclegroup",
                color: .appAccent,
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
                
                if let muscleGroup = exercise.muscleGroup {
                    Text(muscleGroup.capitalized)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                } else if let exerciseType = exercise.exerciseType {
                    Text(exerciseType.capitalized)
                        .font(.caption)
                        .foregroundStyle(Color.appSecondaryText)
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appSurface)
                .overlay {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    }
                }
                .shadow(
                    color: colorScheme == .light
                        ? Color.black.opacity(0.06)
                        : Color.clear,
                    radius: 10,
                    x: 0,
                    y: 4
                )
        }
    }
}

// MARK: - All Custom Exercises View

struct AllCustomExercisesView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var exerciseToDelete: Exercise?
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    StaggeredList(items: viewModel.customExercises, id: \.id) { exercise in
                        HStack(spacing: 12) {
                            IconBadge(
                                assetName: exercise.exerciseType?.lowercased() == "cardio" ? "cardio" : "musclegroup",
                                color: .appAccent,
                                size: 40
                            )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                if let muscleGroup = exercise.muscleGroup {
                                    Text(muscleGroup.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                } else if let exerciseType = exercise.exerciseType {
                                    Text(exerciseType.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            Menu {
                                Button(role: .destructive) {
                                    let notificationFeedback = UINotificationFeedbackGenerator()
                                    notificationFeedback.notificationOccurred(.warning)
                                    exerciseToDelete = exercise
                                } label: {
                                    Label { Text("Delete Exercise", comment: "Menu action") } icon: { Image("trash").resizable().scaledToFit().frame(width: 16, height: 16) }
                                }
                            } label: {
                                Image("ellipsis-horizontal")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 17, height: 17)
                                    .foregroundStyle(Color.appTertiaryText)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityIdentifier("customExerciseMenu")
                        }
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.appSurface)
                                .overlay {
                                    if colorScheme == .dark {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                    }
                                }
                                .shadow(
                                    color: colorScheme == .light
                                        ? Color.black.opacity(0.06)
                                        : Color.clear,
                                    radius: 10,
                                    x: 0,
                                    y: 4
                                )
                        }
                    }
                }
                .padding()
            }
        }
        .sentryScreen("AllCustomExercises")
        .navigationTitle("My Custom Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .alert("Delete Exercise", isPresented: Binding(
            get: { exerciseToDelete != nil },
            set: { if !$0 { exerciseToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    Task {
                        await viewModel.deleteCustomExercise(exercise)
                    }
                }
                exerciseToDelete = nil
            }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to delete '\(exercise.name)'? This will remove the exercise from routines, stats and all past workouts. This action cannot be undone.")
            }
        }
    }
}

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
    
    var body: some View {
        NavigationStack {
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
                                    Text("My Custom Exercises")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if !viewModel.customExercises.isEmpty {
                                        NavigationLink(destination: AllCustomExercisesView(viewModel: viewModel).hidesTabBar()) {
                                            Text("See All")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.appAccent)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                if viewModel.customExercises.isEmpty {
                                    VStack(spacing: 14) {
                                        IconBadge(assetName: "clipboard-text", size: 48)
                                        
                                        Text("No custom exercises yet")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appText)
                                        
                                        Text("Create custom exercises when adding to a routine")
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
                            .id("exercises-\(sectionAnimationId)")
                            
                            // Completed Workouts
                            StaggeredItem(delay: 0.26, animate: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Completed Workouts")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if !progressViewModel.recentSessions.isEmpty {
                                        NavigationLink(destination: AllRecentWorkoutsView().hidesTabBar()) {
                                            Text("See All")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.appAccent)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                if progressViewModel.recentSessions.isEmpty {
                                    VStack(spacing: 14) {
                                        IconBadge(assetName: "clock", size: 48)
                                        
                                        Text("No workout history yet")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appText)
                                        
                                        Text("Complete your first workout to see it here")
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
                                        title: "Total Workouts",
                                        value: "\(progressViewModel.lifetimeWorkouts)",
                                        icon: "workout"
                                    )
                                    
                                    LifetimeStatCard(
                                        title: "Total Volume",
                                        value: "\(Int(unitManager.displayWeight(Double(progressViewModel.lifetimeVolume))))\(unitManager.weightUnit)",
                                        icon: "volume"
                                    )
                                    
                                    LifetimeStatCard(
                                        title: "Time Trained",
                                        value: "\(progressViewModel.lifetimeHours)h",
                                        icon: "clock"
                                    )
                                    
                                    LifetimeStatCard(
                                        title: "Longest Streak",
                                        value: "\(progressViewModel.bestStreak) \(progressViewModel.bestStreak == 1 ? "day" : "days")",
                                        icon: "flame"
                                    )
                                }
                                .padding(.horizontal)
                            }
                            }
                            .id("stats-\(sectionAnimationId)")
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20 + tabBarBottomInset)
                    }
                }
            }
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

struct ProfileSettingsRow: View {
    let icon: String
    let title: String
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
                        
                        Text("Edit Profile")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Manage your account details")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        // Account Details Card
                        VStack(spacing: 0) {
                            // First Name Row
                            EditNameRow(icon: "profile", label: "First Name", value: viewModel.profile?.firstName ?? "Not set") {
                                showingEditFirstNameSheet = true
                            }
                            
                            ProfileDivider()
                            
                            // Last Name Row
                            EditNameRow(icon: "profile", label: "Last Name", value: viewModel.profile?.lastName ?? "Not set") {
                                showingEditLastNameSheet = true
                            }
                            
                            ProfileDivider()
                            
                            // Email Row
                            EditNameRow(icon: "envelope", label: "Email", value: viewModel.profile?.email ?? "Not set") {
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
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
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
            .sheetContentTransition()
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
                    IconBadge(assetName: "pencil", size: 48)
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
    @State private var showSuccess = false
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
                        IconBadge(assetName: "clipboard-text", size: 48)
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
                        
                        Text("Feedback Sent!")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("Thanks for helping us improve Pulse")
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
                        IconBadge(assetName: "check-circle", color: .green, size: 56)
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
                            IconBadge(assetName: "envelope", size: 48)
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
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
                    IconBadge(assetName: "error", color: .red, size: 48)
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
                                    Label { Text("Delete Exercise") } icon: { Image("trash").resizable().scaledToFit().frame(width: 16, height: 16) }
                                }
                            } label: {
                                Image("ellipsis-horizontal")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 17, height: 17)
                                    .foregroundStyle(Color.appTertiaryText)
                                    .frame(width: 44, height: 44)
                            }
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
                Text("Are you sure you want to delete '\(exercise.name)'? This action cannot be undone.")
            }
        }
    }
}

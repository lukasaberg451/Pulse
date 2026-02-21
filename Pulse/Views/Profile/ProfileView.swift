//
//  ProfileView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingThemeSheet = false
    @State private var showingEditSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingFeedbackSheet = false
    @State private var showingLanguageSheet = false
    @State private var showingChangeEmailSheet = false
    
    var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Account Details Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Account Details")
                                    .font(.headline)
                                    .foregroundStyle(Color.appText)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ProfileRow(
                                        icon: "person.fill",
                                        title: "First Name",
                                        value: viewModel.profile?.firstName ?? "Not set"
                                    )
                                    
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    ProfileRow(
                                        icon: "person.fill",
                                        title: "Last Name",
                                        value: viewModel.profile?.lastName ?? "Not set"
                                    )
                                    
                                    Divider()
                                        .background(Color.appText.opacity(0.1))
                                        .padding(.leading, 56)
                                    
                                    // Make email tappable to change
                                    Button {
                                        showingChangeEmailSheet = true
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "envelope")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.appAccent)
                                                    .frame(width: 24)
                                                            
                                                Text("Email")
                                                    .font(.body)
                                                    .foregroundStyle(Color.appText)
                                                            
                                                Spacer()
                                                            
                                                Text(viewModel.profile?.email ?? "")
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
                                .cornerRadius(10)
                                .padding(.horizontal)
                                
                                Button {
                                    showingEditSheet = true
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
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                //Theme setting
                                Button {
                                    showingThemeSheet = true
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "paintbrush.fill")
                                            .font(.system(size: 20))
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
                                .padding(.horizontal)
                                
                                // Language Row
                                        Button {
                                            showingLanguageSheet = true
                                        } label: {
                                            HStack(spacing: 16) {
                                                Image(systemName: "globe")
                                                    .font(.system(size: 20))
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
                                .padding(.horizontal)
                            }
                            VStack(spacing: 0) {
                                Button {
                                    showingFeedbackSheet = true
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                            .font(.system(size: 20))
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
                            
                            // Buy me a coffee
                                Button {
                                    if let url = URL(string: "https://www.google.com/") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color.appAccent)
                                            .frame(width: 24)
                                        
                                        Text("Buy me a coffee")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.3))
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                            
                            // Sign Out Button
                            Button {
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
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
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
            .sheet(isPresented: $showingEditSheet) {
                EditProfileSheet(viewModel: viewModel)
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
            .task {
                await viewModel.loadProfile()
            }
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
                .font(.system(size: 20))
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

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        _firstName = State(initialValue: viewModel.profile?.firstName ?? "")
        _lastName = State(initialValue: viewModel.profile?.lastName ?? "")
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
                    
                    // First Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $firstName)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Last Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $lastName)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Edit Profile")
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
                        if firstName.isEmpty || lastName.isEmpty {
                            errorMessage = "First name and last name are required"
                            showError = true
                        } else {
                            Task {
                                await viewModel.updateProfile(
                                    firstName: firstName,
                                    lastName: lastName
                                )
                                dismiss()
                            }
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
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundStyle(Color.appText)
                        
                        TextField("", text: $title)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(10)
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
                                .cornerRadius(10)
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        Toggle("I would like to receive updates on my feedback", isOn: $isChecked)
                            .foregroundStyle(Color.appText)
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
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
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
                    .cornerRadius(10)
                    .padding()
                    
                    // Language options
                    List {
                        ForEach(languageManager.supportedLanguages, id: \.0) { code, name, icon in
                            Button {
                                selectedLanguage = code
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.appAccent)
                                        .frame(width: 32)
                                    
                                    Text(name)
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if selectedLanguage == code {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.appAccent)
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.appSurface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
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
                        
                        Text("We've sent a confirmation email to:")
                            .font(.body)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        Text(newEmail)
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Check your inbox and click the link to confirm your new email address.")
                            .font(.body)
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(Color.appText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .cornerRadius(10)
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
                        
                        Text("Enter your new email address and current password to confirm the change.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Email")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            TextField("", text: $newEmail)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(Color.appText)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(10)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.caption)
                                .foregroundStyle(Color.appText)
                            
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Color.appText)
                                .padding()
                                .background(Color.appSurface)
                                .cornerRadius(10)
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
                        .cornerRadius(10)
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

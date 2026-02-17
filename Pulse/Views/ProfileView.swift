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
    @State private var showingEditSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingFeedbackSheet = false
    
    var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Profile Header
                            VStack(spacing: 12) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(Color.appSurface)
                                        .frame(width: 100, height: 100)
                                    
                                    Text(viewModel.initials)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.appAccent)
                                }
                                
                                // Name
                                if let profile = viewModel.profile {
                                    Text("\(profile.firstName ?? "") \(profile.lastName ?? "")")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.appText)
                                    
                                    Text(profile.email ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.appText.opacity(0.6))
                                }
                            }
                            .padding(.top, 20)
                            
                            // Account Details Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Account Details")
                                    .font(.headline)
                                    .foregroundColor(.appText)
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
                                    
                                    ProfileRow(
                                        icon: "envelope.fill",
                                        title: "Email",
                                        value: viewModel.profile?.email ?? "Not set"
                                    )
                                }
                                .background(Color.appSurface)
                                .cornerRadius(12)
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
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
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
                                .foregroundColor(.red)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
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
                .foregroundColor(.appAccent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.appText)
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
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    // First Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.headline)
                            .foregroundColor(.appText)
                        
                        TextField("", text: $firstName)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Last Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.headline)
                            .foregroundColor(.appText)
                        
                        TextField("", text: $lastName)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appText)
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
                    .foregroundColor(.appAccent)
                    .fontWeight(.semibold)
                }
            }
        }
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
                            .foregroundColor(.appText)
                        
                        Menu {
                            ForEach(FeedbackType.allCases, id: \.self) { type in
                                Button(type.rawValue) {
                                    feedbackType = type
                                }
                            }
                        } label: {
                            HStack {
                                Text(feedbackType.rawValue)
                                    .foregroundColor(.appText)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.appText.opacity(0.6))
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.appSurface)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.appText)
                        
                        TextField("", text: $title)
                            .padding()
                            .background(Color.appSurface)
                            .foregroundColor(.appText)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.appText)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $description)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.appSurface)
                                .foregroundColor(.appText)
                                .cornerRadius(8)
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
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appText)
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
                    .foregroundColor(title.isEmpty || description.isEmpty ? .appText.opacity(0.3) : .appAccent)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

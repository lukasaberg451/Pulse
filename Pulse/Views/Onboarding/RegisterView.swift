//
//  RegisterView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignUp: Bool
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if authViewModel.registrationSuccess {
                    // Success View
                    VStack(spacing: 24) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.green)
                        
                        Text("Check Your Email")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a verification link to")
                            .foregroundStyle(Color.appText.opacity(0.7))
                        
                        Text(email)
                            .foregroundStyle(Color.appAccent)
                            .fontWeight(.semibold)
                        
                        Text("Please verify your email before signing in")
                            .foregroundStyle(Color.appText.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            authViewModel.registrationSuccess = false
                            showingSignUp = false
                        }) {
                            Text("Back to Login")
                                .font(.headline)
                                .foregroundStyle(Color.appText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                } else {
                    // Registration Form
                    VStack(spacing: 0) {
                        // Logo section
                        VStack {
                            Image(.logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 80)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 50)
                        
                        // Form section
                        VStack(alignment: .leading, spacing: 20) {
                            // Error message
                            VStack {
                                if showError {
                                    Text(errorMessage)
                                        .foregroundStyle(Color.red)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text(" ")
                                        .font(.caption)
                                }
                            }
                            .frame(minHeight: 20)
                            
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .foregroundStyle(Color.appText)
                                    .font(.headline)
                                    .bold()
                                
                                TextField("", text: $firstName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(Color.appSurface)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(10)
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .foregroundStyle(Color.appText)
                                    .font(.headline)
                                    .bold()
                                
                                TextField("", text: $lastName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(Color.appSurface)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(10)
                            }
                            
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .foregroundStyle(Color.appText)
                                    .font(.headline)
                                    .bold()
                                
                                TextField("", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .padding()
                                    .background(Color.appSurface)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(10)
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .foregroundStyle(Color.appText)
                                    .font(.headline)
                                    .bold()
                                
                                SecureField("", text: $password)
                                    .padding()
                                    .background(Color.appSurface)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(10)
                            }
                            
                            // Sign up button
                            Button(action: {
                                if firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty {
                                    errorMessage = "Please enter First Name, Last Name, Email and password"
                                    showError = true
                                } else if !isValidEmail(email) {
                                    errorMessage = "Please enter a valid email address"
                                    showError = true
                                } else {
                                    showError = false
                                    errorMessage = ""
                                    Task {
                                        await authViewModel.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Sign Up")
                                    Spacer()
                                }
                                .font(.headline)
                                .padding()
                                .background(Color.appAccent)
                                .foregroundStyle(Color.appText)
                                .cornerRadius(10)
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                }
                
                // Fullscreen loading overlay
                if authViewModel.isRegistering {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appText))
                            .scaleEffect(1.5)
                        
                        Text("Creating account...")
                            .foregroundStyle(Color.appText)
                            .font(.headline)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: authViewModel.isRegistering)
            .animation(.easeInOut, value: authViewModel.registrationSuccess)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSignUp = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundStyle(Color.appText)
                    }
                }
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
    }
}

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
    @Binding var showingSignIn: Bool
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var agreedToTerms = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func passwordStrength(_ password: String) -> (strength: String, color: Color) {
        if password.isEmpty {
            return ("", .clear)
        }
        
        var strength = 0
        
        // Length check
        if password.count >= 8 { strength += 1 }
        if password.count >= 12 { strength += 1 }
        
        // Character variety
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { strength += 1 }
        
        switch strength {
        case 0...2:
            return ("Weak", .red)
        case 3...4:
            return ("Fair", .orange)
        case 5:
            return ("Good", .yellow)
        default:
            return ("Strong", .green)
        }
    }
    
    var isValidPassword: Bool {
        password.count >= 8 &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
    
    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(email) &&
        isValidPassword &&
        passwordsMatch
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
                        
                        NavigationLink {
                            LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                        } label: {
                            Text("Go to Login")
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
                    ScrollView {
                        VStack(spacing: 0) {
                            // Logo section
                            VStack {
                                Image(.logo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 40)
                            }
                            .padding(.top, 20)
                            
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
                                
                                // Password strength indicator
                                if !password.isEmpty {
                                    HStack(spacing: 8) {
                                        let strength = passwordStrength(password)
                                        
                                        Text(strength.strength)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(strength.color)
                                        
                                        // Strength bars
                                        HStack(spacing: 4) {
                                            ForEach(0..<4) { index in
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(index < strength.strength.count / 2 ? strength.color : Color.appText.opacity(0.2))
                                                    .frame(height: 4)
                                            }
                                        }
                                        .frame(maxWidth: 100)
                                    }
                                    
                                    Text("Must be at least 8 characters with uppercase, lowercase, and number")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appText.opacity(0.6))
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .foregroundStyle(Color.appText)
                                    .font(.headline)
                                    .bold()
                                
                                SecureField("", text: $confirmPassword)
                                    .padding()
                                    .background(Color.appSurface)
                                    .foregroundStyle(Color.appText)
                                    .cornerRadius(10)
                                
                                // Password match indicator
                                if !confirmPassword.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(passwordsMatch ? .green : .red)
                                            .font(.caption)
                                        
                                        Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                            .font(.caption)
                                            .foregroundStyle(passwordsMatch ? .green : .red)
                                    }
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Button(action: {
                                    agreedToTerms.toggle()
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(agreedToTerms ? Color.appAccent : Color.appText.opacity(0.3))
                                        .font(.title3)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text("I agree to the")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.7))
                                        
                                        Button(action: {
                                            showingTerms = true
                                        }) {
                                            Text("Terms & Conditions")
                                                .font(.caption)
                                                .foregroundStyle(Color.appAccent)
                                                .underline()
                                        }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text("and")
                                            .font(.caption)
                                            .foregroundStyle(Color.appText.opacity(0.7))
                                        
                                        Button(action: {
                                            showingPrivacy = true
                                        }) {
                                            Text("Privacy Policy")
                                                .font(.caption)
                                                .foregroundStyle(Color.appAccent)
                                                .underline()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
    
                            // Sign up button
                            Button(action: {
                                if firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty {
                                    errorMessage = "Please fill in all fields"
                                    showError = true
                                } else if !isValidEmail(email) {
                                    errorMessage = "Please enter a valid email address"
                                    showError = true
                                } else if !isValidPassword {
                                    errorMessage = "Password must be at least 8 characters with uppercase, lowercase, and number"
                                    showError = true
                                } else if !passwordsMatch {
                                    errorMessage = "Passwords do not match"
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
                                .background(isValid && agreedToTerms ? Color.appAccent : Color.appAccent.opacity(0.5))
                                .foregroundStyle(Color.appText)
                                .cornerRadius(10)
                            }
                            .disabled(!isValid || !agreedToTerms)
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40) // Extra padding at bottom for keyboard
                    }
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
            .sheet(isPresented: $showingTerms) {
                TermsAndConditionsView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyPolicyView()
            }
            .animation(.easeInOut, value: authViewModel.isRegistering)
            .animation(.easeInOut, value: authViewModel.registrationSuccess)
            .navigationBarBackButtonHidden(false)
            .toolbar {
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
    }
}

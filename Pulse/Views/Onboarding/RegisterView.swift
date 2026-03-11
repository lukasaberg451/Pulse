//
//  RegisterView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SafariServices

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
    @State private var safariURL: URL?
    
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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                if authViewModel.registrationSuccess {
                    // Success View
                    VStack(spacing: 20) {
                        IconBadge(assetName: "envelope", color: .green, size: 64)
                        
                        Text("Check Your Email")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a verification link to")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        Text(email)
                            .font(.subheadline.weight(.semibold))

                        
                        Text("Please verify your email before signing in")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        PrimaryCTALink("Go to Login") {
                            LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
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
                            if showError {
                                HStack(spacing: 8) {
                                    Image("exclamation-circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.red)
                                    Text(errorMessage)
                                        .foregroundStyle(.red)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                TextField("First Name", text: $firstName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .foregroundStyle(Color.appText)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                    }
                            }
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                TextField("Last Name", text: $lastName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .foregroundStyle(Color.appText)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                    }
                            }
                            
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                TextField("Email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .padding()
                                    .foregroundStyle(Color.appText)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                    }
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                SecureField("Password", text: $password)
                                    .padding()
                                    .foregroundStyle(Color.appText)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                    }
                                
                                // Password strength indicator
                                if !password.isEmpty {
                                    HStack(spacing: 8) {
                                        let strength = passwordStrength(password)
                                        
                                        Text(strength.strength)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(strength.color)
                                        
                                        // Strength bars
                                        HStack(spacing: 4) {
                                            ForEach(0..<4) { index in
                                                Capsule()
                                                    .fill(index < strength.strength.count / 2 ? strength.color : Color.appText.opacity(0.12))
                                                    .frame(height: 4)
                                            }
                                        }
                                        .frame(maxWidth: 100)
                                    }
                                    
                                    Text("Must be at least 8 characters with uppercase, lowercase, and number")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appTertiaryText)
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .padding()
                                    .foregroundStyle(Color.appText)
                                    .background {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.appSurface)
                                            .overlay {
                                                if colorScheme == .dark {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                            }
                                    }
                                
                                // Password match indicator
                                if !confirmPassword.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(passwordsMatch ? "check-circle" : "x-mark")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(passwordsMatch ? .green : .red)
                                        
                                        Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(passwordsMatch ? .green : .red)
                                    }
                                }
                            }
                            
                                HStack(alignment: .center, spacing: 8) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        agreedToTerms.toggle()
                                    }
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(agreedToTerms ? Color.appAccent : Color.appTertiaryText)
                                        .font(.title3)
                                }
                                
                                HStack(spacing: 4) {
                                    Text("I agree to the")
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Button(action: {
                                        safariURL = URL(string: "https://pulsefitness.io/terms-app.html")
                                    }) {
                                        Text("Terms of Service")
                                            .font(.caption)
                                            .foregroundStyle(Color.appAccent)
                                            .underline()
                                    }
                                    
                                    Text("&")
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Button(action: {
                                        safariURL = URL(string: "https://pulsefitness.io/privacy-app.html")
                                    }) {
                                        Text("Privacy Policy")
                                            .font(.caption)
                                            .foregroundStyle(Color.appAccent)
                                            .underline()
                                    }
                                }
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 24)
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
                                Text(authViewModel.rateLimitSecondsRemaining > 0
                                    ? "Wait \(authViewModel.rateLimitSecondsRemaining)s"
                                    : "Sign Up")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        LinearGradient.accentGradient.opacity(isValid && agreedToTerms && authViewModel.rateLimitSecondsRemaining == 0 ? 1 : 0.5),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                            }
                            .buttonStyle(ScalePressStyle())
                            .disabled(!isValid || !agreedToTerms || authViewModel.rateLimitSecondsRemaining > 0)
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
                
                // Fullscreen loading overlay
                if authViewModel.isRegistering {
                    ZStack {
                        Color.appBackground
                            .ignoresSafeArea()
                        
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Color.appAccent)
                    }
                    .transition(.opacity)
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
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

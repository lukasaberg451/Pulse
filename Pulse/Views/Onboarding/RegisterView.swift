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
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var agreedToTerms = false
    @State private var safariURL: URL?
    @FocusState private var focusedField: RegisterField?
    
    private enum RegisterField {
        case firstName, lastName, email, password
    }
    
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
            return (String(localized: "Weak"), .red)
        case 3...4:
            return (String(localized: "Fair"), .orange)
        case 5:
            return (String(localized: "Good"), .yellow)
        default:
            return (String(localized: "Strong"), .green)
        }
    }
    
    var isValidPassword: Bool {
        password.count >= 8 &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(email) &&
        isValidPassword
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
                        
                        Text("Check Your Email", comment: "Registration success title prompting user to check email")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.appText)
                        
                        Text("We've sent a verification link to", comment: "Registration success subtitle before email address")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                        
                        Text(email)
                            .font(.subheadline.weight(.semibold))

                        
                        Text("Please verify your email before signing in", comment: "Registration success instruction to verify email")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        PrimaryCTALink("Go to Login") {
                            LoginView(authViewModel: authViewModel, showingSignIn: $showingSignIn)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        
                        Button {
                            authViewModel.registrationSuccess = false
                        } label: {
                            Text("Use a different email", comment: "Button to go back and use a different email for registration")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // Registration Form
                    ScrollView {
                        VStack(spacing: 0) {
                            // Logo section
                            VStack {
                                Image("LoadingLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 180, height: 100)
                            }
                            //.padding(.top, 15)
                            .padding(.bottom, 15)
                            
                            // Form section
                            VStack(alignment: .leading, spacing: 20) {
                            // Error message
                            if showError {
                                HStack(spacing: 8) {
                                    Image("error")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(.red)
                                    Text(errorMessage)
                                        .foregroundStyle(.red)
                                        .font(.caption.weight(.medium))
                                        .accessibilityIdentifier("registerErrorText")
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityIdentifier("registerErrorBox")
                            }
                            
                            // First Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name", comment: "First name field label on registration form")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)

                                HStack {
                                    TextField(String(localized: "First Name"), text: $firstName)
                                        .textFieldStyle(.plain)
                                        .textContentType(.givenName)
                                        .textInputAutocapitalization(.words)
                                        .focused($focusedField, equals: .firstName)
                                        .foregroundStyle(Color.appText)
                                        .accessibilityIdentifier("registerFirstNameField")
                                        .onChange(of: firstName) { _, newValue in
                                            firstName = sanitizeInput(newValue, maxLength: 50)
                                        }
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .firstName }
                                .appTextFieldStyle(isFocused: focusedField == .firstName)

                                if firstName.count >= 40 {
                                    HStack {
                                        Spacer()
                                        Text("\(firstName.count)/50")
                                            .font(.caption2)
                                            .foregroundStyle(firstName.count >= 50 ? .red : Color.appSecondaryText)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: firstName.count >= 40)
                            
                            // Last Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name", comment: "Last name field label on registration form")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)

                                HStack {
                                    TextField(String(localized: "Last Name"), text: $lastName)
                                        .textFieldStyle(.plain)
                                        .textContentType(.familyName)
                                        .textInputAutocapitalization(.words)
                                        .focused($focusedField, equals: .lastName)
                                        .foregroundStyle(Color.appText)
                                        .accessibilityIdentifier("registerLastNameField")
                                        .onChange(of: lastName) { _, newValue in
                                            lastName = sanitizeInput(newValue, maxLength: 50)
                                        }
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .lastName }
                                .appTextFieldStyle(isFocused: focusedField == .lastName)

                                if lastName.count >= 40 {
                                    HStack {
                                        Spacer()
                                        Text("\(lastName.count)/50")
                                            .font(.caption2)
                                            .foregroundStyle(lastName.count >= 50 ? .red : Color.appSecondaryText)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: lastName.count >= 40)
                            
                            // Email
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email", comment: "Email field label on registration form")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)

                                HStack {
                                    TextField(String(localized: "Email"), text: $email)
                                        .textFieldStyle(.plain)
                                        .textContentType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .foregroundStyle(Color.appText)
                                        .accessibilityIdentifier("registerEmailField")
                                        .onChange(of: email) { _, newValue in
                                            email = sanitizeInput(newValue, maxLength: 254)
                                        }
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .email }
                                .appTextFieldStyle(isFocused: focusedField == .email)

                                if email.count >= 244 {
                                    HStack {
                                        Spacer()
                                        Text("\(email.count)/254")
                                            .font(.caption2)
                                            .foregroundStyle(email.count >= 254 ? .red : Color.appSecondaryText)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: email.count >= 244)
                            
                            // Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password", comment: "Password field label on registration form")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appText)
                                
                                HStack {
                                    if showPassword {
                                        TextField(String(localized: "Password"), text: $password)
                                            .textFieldStyle(.plain)
                                            .textContentType(.newPassword)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .password)
                                            .foregroundStyle(Color.appText)
                                            .accessibilityIdentifier("registerPasswordField")
                                    } else {
                                        SecureField(String(localized: "Password"), text: $password)
                                            .textFieldStyle(.plain)
                                            .textContentType(.newPassword)
                                            .focused($focusedField, equals: .password)
                                            .foregroundStyle(Color.appText)
                                            .accessibilityIdentifier("registerPasswordField")
                                    }

                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(Color.appTertiaryText)
                                            .font(.body)
                                            .frame(width: 24, height: 24)
                                            .contentTransition(.symbolEffect(.replace))
                                    }
                                }
                                .padding()
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .password }
                                .appTextFieldStyle(isFocused: focusedField == .password)
                                .onChange(of: password) { _, newValue in
                                    password = sanitizeInput(newValue, maxLength: 72)
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
                                    
                                    Text("Must be at least 8 characters with uppercase, lowercase, and number", comment: "Password requirements hint on registration form")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appTertiaryText)
                                }
                                
                                if password.count >= 62 {
                                    HStack {
                                        Spacer()
                                        Text("\(password.count)/72")
                                            .font(.caption2)
                                            .foregroundStyle(password.count >= 72 ? .red : Color.appSecondaryText)
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: password.count >= 62)
                            
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
                                .accessibilityIdentifier("termsCheckbox")
                                
                                HStack(spacing: 4) {
                                    Text("I agree to the", comment: "Terms agreement prefix on registration form")
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Button(action: {
                                        safariURL = Constants.URLs.termsOfService
                                    }) {
                                        Text("Terms of Service", comment: "Terms of service link on registration form")
                                            .font(.caption)
                                            .foregroundStyle(Color.appAccent)
                                            .underline()
                                    }
                                    
                                    Text("&", comment: "Conjunction between Terms of Service and Privacy Policy links")
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondaryText)
                                    
                                    Button(action: {
                                        safariURL = Constants.URLs.privacyPolicy
                                    }) {
                                        Text("Privacy Policy", comment: "Privacy policy link on registration form")
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
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                if firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty {
                                    errorMessage = String(localized: "Please fill in all fields")
                                    showError = true
                                } else if !isValidEmail(email) {
                                    errorMessage = String(localized: "Please enter a valid email address")
                                    showError = true
                                } else if !isValidPassword {
                                    errorMessage = String(localized: "Password must be at least 8 characters with uppercase, lowercase, and number")
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
                                    ? String(localized: "Wait \(authViewModel.rateLimitSecondsRemaining)s")
                                    : String(localized: "Sign Up"))
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
                            .accessibilityIdentifier("registerButton")
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
                
            }
            .fullScreenCover(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            .animation(.easeInOut, value: authViewModel.registrationSuccess)
            .navigationBarBackButtonHidden(false)
            .toolbar {
            }
            .sentryScreen("Register")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
    }
}

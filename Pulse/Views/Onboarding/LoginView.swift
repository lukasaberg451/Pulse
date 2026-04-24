//
//  LoginView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import Supabase
import AuthenticationServices
import SafariServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var showingSignIn: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showingForgotPassword = false
    @State private var safariURL: URL?
    @FocusState private var focusedField: LoginField?
    @Environment(\.colorScheme) private var colorScheme
    
    private enum LoginField {
        case email, password
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo section
                    VStack {
                        Image("LoadingLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 100)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 50)
                    
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
                                    .accessibilityIdentifier("loginErrorText")
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("loginErrorBox")
                        }
                        
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email", comment: "Email field label on login screen")
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
                                    .accessibilityIdentifier("loginEmailField")
                                    .onChange(of: email) {
                                        showError = false
                                    }
                            }
                            .padding()
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

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password", comment: "Password field label on login screen")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appText)

                            HStack {
                                SecureField(String(localized: "Password"), text: $password)
                                    .textFieldStyle(.plain)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .foregroundStyle(Color.appText)
                                    .accessibilityIdentifier("loginPasswordField")
                                    .onChange(of: password) {
                                        showError = false
                                    }
                            }
                            .padding()
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

                        // Forgot password
                        HStack {
                            Spacer()
                            Button(String(localized: "Forgot Password?")) {
                                showingForgotPassword = true
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appAccent)
                            .accessibilityIdentifier("forgotPasswordButton")
                        }
                        
                        // Sign in button
                        PrimaryCTAButton(authViewModel.rateLimitSecondsRemaining > 0
                            ? "Wait \(authViewModel.rateLimitSecondsRemaining)s"
                            : "Sign In"
                        ) {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                errorMessage = String(localized: "Email is required")
                                showError = true
                            } else if !isValidEmail(email) {
                                errorMessage = String(localized: "Please enter a valid email address")
                                showError = true
                            } else if password.isEmpty {
                                errorMessage = String(localized: "Password is required")
                                showError = true
                            } else {
                                showError = false
                                errorMessage = ""
                                Task {
                                    await authViewModel.signIn(email: email, password: password)
                                    
                                    // Check for auth errors after sign in attempt
                                    if let authError = authViewModel.errorMessage {
                                        errorMessage = authError
                                        showError = true
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("loginButton")
                        .disabled(authViewModel.rateLimitSecondsRemaining > 0)
                        .padding(.top, 4)
                        
                        // Divider with "or"
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.appTertiaryText)
                                .frame(height: 1)
                            Text("or", comment: "Divider between sign-in methods on login screen")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appTertiaryText)
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.appTertiaryText)
                                .frame(height: 1)
                        }
                        .padding(.top, 16)
                        
                        // Sign in with Apple button
                        SignInWithAppleButton(.continue) { request in
                            let nonce = authViewModel.generateNonce()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authViewModel.sha256(nonce)
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task {
                                    await authViewModel.signInWithApple(authorization: authorization)
                                }
                            case .failure(let error):
                                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                                    errorMessage = String(localized: "Sign in with Apple failed.")
                                    showError = true
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Terms & Privacy note
                        HStack(spacing: 4) {
                            Text("By continuing, you agree to the", comment: "Terms agreement prefix on login screen")
                                .font(.caption2)
                                .foregroundStyle(Color.appTertiaryText)
                            
                            Button(action: {
                                safariURL = Constants.URLs.termsOfService
                            }) {
                                Text("Terms of Service", comment: "Terms of Service link on login screen")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                            
                            Text("&", comment: "Conjunction between Terms of Service and Privacy Policy links")
                                .font(.caption2)
                                .foregroundStyle(Color.appTertiaryText)
                            
                            Button(action: {
                                safariURL = Constants.URLs.privacyPolicy
                            }) {
                                Text("Privacy Policy", comment: "Privacy Policy link on login screen")
                                    .font(.caption2)
                                    .foregroundStyle(Color.appAccent)
                                    .underline()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                
            }
            .fullScreenCover(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
            .navigationBarBackButtonHidden(authViewModel.isLoading)
            .toolbar {
            }
            .toolbar(authViewModel.isLoading ? .hidden : .automatic, for: .navigationBar)
            .sentryScreen("Login")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .presentationDragIndicator(.visible)
                    .sheetContentTransition()
            }
        }
        .overlay(content: {
            if authViewModel.isLoading {
                ZStack {
                    Color.appBackground
                    LinearGradient.dashboardBackground

                    Image("LoadingLogo")
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        })
        .animation(.easeInOut, value: authViewModel.isLoading)
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PwResetViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedResetField: ResetField?
    
    private enum ResetField {
        case email, newPassword, confirmPassword
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func passwordStrength(_ password: String) -> (label: String, color: Color, level: Int) {
        if password.isEmpty { return ("", .clear, 0) }
        
        var strength = 0
        if password.count >= 8 { strength += 1 }
        if password.count >= 12 { strength += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { strength += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { strength += 1 }
        
        switch strength {
        case 0...2: return (String(localized: "Weak"), .red, 1)
        case 3...4: return (String(localized: "Fair"), .orange, 2)
        case 5:     return (String(localized: "Good"), .yellow, 3)
        default:    return (String(localized: "Strong"), .green, 4)
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            switch viewModel.step {
            case .enterEmail:
                emailStepView
            case .enterOTP:
                otpStepView
            case .setNewPassword:
                newPasswordStepView
            case .success:
                successView
            }
            
            if viewModel.isLoading {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                    Image("LoadingLogo")
                }
                .transition(.opacity)
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
        .animation(.easeInOut, value: viewModel.isLoading)
        .animation(.easeInOut, value: viewModel.step)
        .onDisappear {
            viewModel.reset()
        }
    }
    
    // MARK: - Step 1: Enter Email
    
    private var emailStepView: some View {
        VStack(spacing: 0) {
            VStack {
                Image("LoadingLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 100)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 100)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reset Password", comment: "Title for forgot password email step")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.appText)

                    Text("Enter your email to receive a verification code", comment: "Subtitle for forgot password email step")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                }
                .padding(.bottom, 10)
                
                errorBox
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email", comment: "Email field label on forgot password screen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appText)

                    HStack {
                        TextField(String(localized: "Email"), text: $viewModel.email)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($focusedResetField, equals: .email)
                            .foregroundStyle(Color.appText)
                            .accessibilityIdentifier("forgotPasswordEmailField")
                            .onChange(of: viewModel.email) {
                                viewModel.showError = false
                            }
                    }
                    .padding()
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

                PrimaryCTAButton("Send Code") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    let trimmed = viewModel.email.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        viewModel.errorMessage = String(localized: "Email is required")
                        viewModel.showError = true
                    } else if !isValidEmail(trimmed) {
                        viewModel.errorMessage = String(localized: "Please enter a valid email address")
                        viewModel.showError = true
                    } else {
                        Task {
                            await viewModel.sendOTP()
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Enter OTP
    
    private var otpStepView: some View {
        VStack(spacing: 0) {
            VStack {
                Image("LoadingLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 100)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 100)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Code", comment: "Title for OTP verification step")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.appText)

                    Text("We sent an 8-digit code to", comment: "Subtitle before email on OTP step")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryText)
                    
                    Text(viewModel.email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .padding(.bottom, 10)
                
                errorBox
                
                // OTP input: hidden TextField with visual digit boxes
                OTPInputView(code: $viewModel.otpCode)
                    .padding(.vertical, 4)
                
                PrimaryCTAButton("Verify Code") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task {
                        await viewModel.verifyOTP()
                    }
                }
                .opacity(viewModel.otpCode.count == 8 ? 1 : 0.5)
                .disabled(viewModel.otpCode.count != 8)
                .padding(.top, 4)
                
                // Resend code
                HStack {
                    Spacer()
                    if viewModel.resendCooldown > 0 {
                        Text("Resend code in \(viewModel.resendCooldown)s", comment: "Cooldown timer for resending OTP code")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.appTertiaryText)
                    } else {
                        Button(String(localized: "Resend Code")) {
                            Task {
                                await viewModel.resendOTP()
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appAccent)
                    }
                    Spacer()
                }
                .padding(.top, 4)
                
                // Back button
                HStack {
                    Spacer()
                    Button(String(localized: "Use a different email")) {
                        viewModel.otpCode = ""
                        viewModel.showError = false
                        viewModel.step = .enterEmail
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appSecondaryText)
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Set New Password
    
    private var newPasswordStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set New Password", comment: "Title for new password step")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appText)

                Text("Enter your new password below", comment: "Subtitle for new password step")
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
            }
            
            errorBox
            
            VStack(alignment: .leading, spacing: 8) {
                Text("New Password", comment: "New password field label on reset password screen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                HStack {
                    SecureField(String(localized: "New Password"), text: $viewModel.newPassword)
                        .textFieldStyle(.plain)
                        .focused($focusedResetField, equals: .newPassword)
                        .foregroundStyle(Color.appText)
                        .textContentType(.newPassword)
                }
                .padding()
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
                .onChange(of: viewModel.newPassword) { _, newValue in
                    viewModel.newPassword = sanitizeInput(newValue, maxLength: 72)
                }
                
                // Password strength indicator
                if !viewModel.newPassword.isEmpty {
                    HStack(spacing: 8) {
                        let strength = passwordStrength(viewModel.newPassword)
                        
                        Text(strength.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(strength.color)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<4) { index in
                                Capsule()
                                    .fill(index < strength.level ? strength.color : Color.appText.opacity(0.12))
                                    .frame(height: 4)
                            }
                        }
                        .frame(maxWidth: 100)
                    }
                }
                
                if viewModel.newPassword.count >= 62 {
                    HStack {
                        Spacer()
                        Text("\(viewModel.newPassword.count)/72")
                            .font(.caption2)
                            .foregroundStyle(viewModel.newPassword.count >= 72 ? .red : Color.appSecondaryText)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.newPassword.count >= 62)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password", comment: "Confirm password field label on reset password screen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)

                HStack {
                    SecureField(String(localized: "Confirm Password"), text: $viewModel.confirmPassword)
                        .textFieldStyle(.plain)
                        .focused($focusedResetField, equals: .confirmPassword)
                        .foregroundStyle(Color.appText)
                        .textContentType(.newPassword)
                }
                .padding()
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
                .onChange(of: viewModel.confirmPassword) { _, newValue in
                    viewModel.confirmPassword = sanitizeInput(newValue, maxLength: 72)
                }
                
                // Password match indicator
                if !viewModel.confirmPassword.isEmpty {
                    HStack(spacing: 6) {
                        Image(viewModel.passwordsMatch ? "check-circle" : "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(viewModel.passwordsMatch ? .green : .red)
                        
                        Text(viewModel.passwordsMatch ? String(localized: "Passwords match") : String(localized: "Passwords don't match"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(viewModel.passwordsMatch ? .green : .red)
                    }
                }
                
                if viewModel.confirmPassword.count >= 62 {
                    HStack {
                        Spacer()
                        Text("\(viewModel.confirmPassword.count)/72")
                            .font(.caption2)
                            .foregroundStyle(viewModel.confirmPassword.count >= 72 ? .red : Color.appSecondaryText)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.confirmPassword.count >= 62)
            
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task {
                    await viewModel.updatePassword()
                }
            } label: {
                Text("Reset Password", comment: "Reset password submit button label")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient.accentGradient.opacity(viewModel.canSetPassword ? 1 : 0.5),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .buttonStyle(ScalePressStyle())
            .disabled(!viewModel.canSetPassword || viewModel.isLoading)
            .padding(.top, 4)
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Success
    
    private var successView: some View {
        VStack(spacing: 20) {
            IconBadge(assetName: "check-circle", color: .green, size: 64)
            
            Text("Password Reset!", comment: "Success title after password reset")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.appText)

            Text("You can now sign in with your new password.", comment: "Success message after password reset")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
                .multilineTextAlignment(.center)

            PrimaryCTAButton("Go to Login") {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Error Box
    
    @ViewBuilder
    private var errorBox: some View {
        if viewModel.showError {
            HStack(spacing: 8) {
                Image("error")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.red)
                Text(viewModel.errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .accessibilityIdentifier("forgotPasswordErrorText")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("forgotPasswordErrorBox")
        }
    }
}

// MARK: - OTP Input View

private struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let digitCount = 8
    
    var body: some View {
        ZStack {
            // Hidden TextField that captures all keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: code) {
                    // Filter to digits only, cap at digitCount
                    let filtered = String(code.filter { $0.isNumber }.prefix(digitCount))
                    if code != filtered {
                        code = filtered
                    }
                }
            
            // Visual digit boxes
            HStack(spacing: 8) {
                ForEach(0..<digitCount, id: \.self) { index in
                    let isFilled = index < code.count
                    let isCursor = index == code.count && isFocused
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.appSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        isCursor ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.clear),
                                        lineWidth: isCursor ? 2 : 1
                                    )
                            }
                        
                        if isFilled {
                            let digitIndex = code.index(code.startIndex, offsetBy: index)
                            Text(String(code[digitIndex]))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appText)
                        }
                    }
                    .frame(width: 38, height: 48)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .sentryScreen("OTPInput")
        .onAppear {
            isFocused = true
        }
    }
}

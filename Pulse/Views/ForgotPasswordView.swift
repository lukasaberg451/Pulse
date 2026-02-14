//
//  ForgotPasswordView.swift
//  Pulse
//
//  Created by lukasaberg on 2/6/26.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var resetSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if resetSuccess {
                // Success View
                VStack(spacing: 24) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.appAccent)
                    
                    Text("Check Your Email")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)
                    
                    Text("We've sent a password reset link to")
                        .foregroundColor(.appText.opacity(0.7))
                    
                    Text(email)
                        .foregroundColor(.appAccent)
                        .fontWeight(.semibold)
                    
                    Text("Please check your email and follow the instructions to reset your password")
                        .foregroundColor(.appText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        resetSuccess = false
                        dismiss()
                    }) {
                        Text("Back to Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                }
            } else {
                // Reset Password Form
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.appText)
                        .font(.system(size: 60))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)
                
                VStack(alignment: .leading) {
                    VStack {
                        if showError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(" ")
                                .font(.caption)
                        }
                    }
                    .frame(minHeight: 40)
                    .padding(.bottom, 10)
                    
                    Text("Email")
                        .foregroundStyle(Color.appText)
                        .font(.headline)
                        .bold()
                        .padding(.leading, 40)
                        .padding(.bottom, 0)
                    TextField("", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .cornerRadius(5)
                        .padding(.leading, 40)
                        .padding(.trailing, 40)
                        .onChange(of: email) {
                            showError = false
                        }
                    
                    VStack {
                        Button(action: {
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                errorMessage = "Email is required"
                                showError = true
                            } else if !isValidEmail(email) {
                                errorMessage = "Please enter a valid email address"
                                showError = true
                            } else {
                                showError = false
                                errorMessage = ""
                                Task {
                                    isLoading = true
                                    do {
                                        try await sendPasswordReset(email: email)
                                        resetSuccess = true
                                    } catch {
                                        errorMessage = "Failed to send reset email: \(error.localizedDescription)"
                                        showError = true
                                    }
                                    isLoading = false
                                }
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Reset Password")
                                Spacer()
                            }
                            .padding()
                            .font(.headline)
                            .background(Color.appAccent)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(5)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.top, 10)
                    .padding(.leading, 40)
                    .padding(.trailing, 40)
                }
            }
            
            // Fullscreen loading overlay
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Sending reset link...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isLoading)
        .animation(.easeInOut, value: resetSuccess)
    }
}

#Preview {
    ForgotPasswordView()
}

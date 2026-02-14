//
//  RegisterView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @Environment(\.dismiss) var dismiss
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if authViewModel.registrationSuccess {
                // Success View
                VStack(spacing: 24) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.appAccent)
                    
                    Text("Check Your Email")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)
                    
                    Text("We've sent a verification link to")
                        .foregroundColor(.appText.opacity(0.7))
                    
                    Text(email)
                        .foregroundColor(.appAccent)
                        .fontWeight(.semibold)
                    
                    Text("Please verify your email before signing in")
                        .foregroundColor(.appText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        authViewModel.registrationSuccess = false
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
                // Registration Form
                VStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.appText)
                        .font(.system(size: 60))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 50)
                
                VStack(alignment: .leading) {
                    Text("First Name")
                        .foregroundStyle(Color.appText)
                        .font(.headline)
                        .bold()
                        .padding(.leading, 40)
                        .padding(.bottom, 0)
                    TextField("", text: $firstName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .cornerRadius(5)
                        .padding(.leading, 40)
                        .padding(.trailing, 40)
                        .padding(.bottom, 10)
                    
                    Text("Last Name")
                        .foregroundStyle(Color.appText)
                        .font(.headline)
                        .bold()
                        .padding(.leading, 40)
                        .padding(.bottom, 0)
                    TextField("", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .cornerRadius(5)
                        .padding(.leading, 40)
                        .padding(.trailing, 40)
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
                        .padding(.bottom, 10)
                    
                    Text("Password")
                        .foregroundStyle(Color.appText)
                        .font(.headline)
                        .bold()
                        .padding(.leading, 40)
                    SecureField("", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .cornerRadius(5)
                        .padding(.leading, 40)
                        .padding(.trailing, 40)
                    
                    HStack {
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
                            .cornerRadius(5)
                        }
                        .disabled(authViewModel.isRegistering)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
                    .padding(.leading, 40)
                    .padding(.trailing, 40)
                    
                    VStack {
                        if showError {
                            Text(errorMessage)
                                .foregroundStyle(Color.red)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(" ")
                                .font(.caption)
                        }
                    }
                    .frame(height: 20)
                    .padding(.top, 20)
                }
            }
            
            // Fullscreen loading overlay
            if authViewModel.isRegistering {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Creating account...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authViewModel.isRegistering)
        .animation(.easeInOut, value: authViewModel.registrationSuccess)
    }
}

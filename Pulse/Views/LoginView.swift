//
//  LoginView.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack{
            ZStack{
                Color.appBackground
                    .ignoresSafeArea()
                VStack{
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.appText)
                        .font(.system(size: 60))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 50)
                VStack(alignment: .leading){
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
                        .foregroundStyle(Color.black)
                    HStack{
                        NavigationLink("Forgot Password?", destination: ForgotPasswordView())
                            .foregroundStyle(Color.appText)
                            .font(.headline)
                    }
                    .padding(.leading, 40)
                    .padding(.top, 10)
                    HStack{
                        Button(action: {
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                errorMessage = "Email and password is required"
                                showError = true
                            } else if !isValidEmail(email) {
                                errorMessage = "Please enter a valid email address"
                                showError = true
                            } else if password.isEmpty {
                                errorMessage = "Email and password is required"
                                showError = true
                            } else {
                                showError = false
                                errorMessage = ""
                            Task {
                                await authViewModel.signIn(email: email, password: password)
                            }
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Sign In")
                                Spacer()
                            }
                            .padding()
                            .font(.headline)
                            .background(Color.appAccent)
                            .foregroundStyle(Color.appText)
                            .cornerRadius(5)
                        }
                    }
                    .frame(alignment: .center)
                    .padding(.top, 10)
                    .padding(.leading, 40)
                    .padding(.trailing, 40)
                    VStack{
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
                if authViewModel.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Signing in...")
                            .foregroundStyle(Color.white)
                            .font(.headline)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: authViewModel.isLoading)
        }
    }
}

//#Preview {
  //  LoginView()
//}

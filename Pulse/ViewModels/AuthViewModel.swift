//
//  AuthViewModel.swift
//  Pulse
//
//  Created by lukasaberg on 2/5/26.
//

import SwiftUI
import Supabase
import Combine

@MainActor
class AuthViewModel: ObservableObject{
    @Published var session: Session?
    @Published var isAuthenticated = false
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var isRegistering = false
    @Published var registrationSuccess = false
    @Published var errorMessage: String?
    @Published var showRecoveryPrompt = false
    
    private let supabase = SupabaseManager.shared.client
    
    init() {
            // Restore session on init
            Task {
                await restoreSession()
                
                if UserDefaults.standard.bool(forKey: "pendingPasswordReset") {
                            UserDefaults.standard.removeObject(forKey: "pendingPasswordReset")
                            DispatchQueue.main.async {
                                self.showRecoveryPrompt = true
                            }
                        }
                    }
                }
    
    private func restoreSession() async {
            do {
                // Try to get existing session
                let session = try await supabase.auth.session
                
                // Check if session is expired
                if session.isExpired {
                    print("⚠️ Session is expired, signing out")
                    self.session = nil
                    self.isAuthenticated = false
                    try? await supabase.auth.signOut()
                    return
                }
                
                self.session = session
                self.isAuthenticated = true
                await fetchUserProfile()
            } catch {
                print("❌ No existing session: \(error.localizedDescription)")
                self.isAuthenticated = false
            }
        }
    
    func getInitialSession() async {
        do {
            let current = try await supabase.auth.session
            
            // Check if session is expired
            if current.isExpired {
                print("⚠️ Session is expired")
                self.session = nil
                self.isAuthenticated = false
                return
            }
            
            self.session = current
            self.isAuthenticated = true
        } catch {
            print("No active session: \(error.localizedDescription)")
            self.session = nil
            self.isAuthenticated = false
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        
        isRegistering = true
        registrationSuccess = false
        
        do {
            
            let result = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "full_name": .string("\(firstName) \(lastName)"),
                    "first_name": .string(firstName),
                    "last_name": .string(lastName)
                ]
            )
            
            self.session = result.session
            registrationSuccess = true
            
        } catch let error as AuthError {
            
            errorMessage = error.localizedDescription
            registrationSuccess = false
        } catch {
    
            errorMessage = "Registration failed: \(error.localizedDescription)"
            registrationSuccess = false
        }
        
        isRegistering = false
    }
    
    func signIn(email: String, password: String) async{
        isLoading = true
        do{
            let result = try await supabase.auth.signIn(email: email, password: password)
            self.session = result
            self.isAuthenticated = self.session != nil
            
            await fetchUserProfile()
        } catch{
            print("Sign Up failed: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    func signOut() async{
        do{
            try await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
            self.userProfile = nil
        } catch{
            print("Sign-out failed: \(error.localizedDescription)")
        }
    }
    
    func fetchUserProfile()async {
        guard let userId = session?.user.id else { return }
        do{
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            self.userProfile = profile
        } catch {
            print("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
    var firstName: String {
        guard let fullName = userProfile?.fullName else { return "" }
        return fullName.components(separatedBy: " ").first ?? ""
    }
    
    func changeEmail(newEmail: String, password: String) async -> Bool {
        do {
            try await supabase.auth.update(
                user: UserAttributes(email: newEmail)
            )
            
            return true
        } catch {
            errorMessage = "Failed to change email: \(error.localizedDescription)"
            return false
        }
    }
    
    func resetPassword(email: String) async -> Bool {
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            return true
        } catch {
            errorMessage = "Failed to send reset email: \(error.localizedDescription)"
            return false
        }
    }
}

struct UserProfile : Codable {
    let id: UUID
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username = "username"
        case avatarUrl = "avatar_url"
    }
}

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
    
    private let supabase = SupabaseManager.shared.client
    
    func getInitialSession() async {
        do{
            let current = try await supabase.auth.session
            self.session = current
            self .isAuthenticated = true
        } catch{
            print("No active session: \(error.localizedDescription)")
        }
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        isRegistering = true
        registrationSuccess = false
        
        do {
            let result = try await supabase.auth.signUp(email: email, password: password, data: [ "full_name": .string("\(firstName) \(lastName)")])
            self.session = result.session
            self.isAuthenticated = self.session != nil
            registrationSuccess = true
        } catch let error as AuthError {
             if error.localizedDescription.contains("password") ||
                        error.localizedDescription.contains("compromised") {
                errorMessage = "This password has been exposed in a data breach. Please choose a different password."
            } else {
                errorMessage = "Registration failed:  \(error.localizedDescription)"
            }
            registrationSuccess = false
        } catch {
            errorMessage = "Registration failed: \(error.localizedDescription)"
            registrationSuccess = false
        }
        registrationSuccess = true
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

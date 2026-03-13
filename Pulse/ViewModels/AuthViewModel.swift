//
//  AuthViewModel.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import Supabase
import Combine
import PostHog
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject{
    @Published var session: Session?
    @Published var isAuthenticated = false
    @Published var isInitializing = true
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var isRegistering = false
    @Published var registrationSuccess = false
    @Published var errorMessage: String?
    @Published var rateLimitSecondsRemaining: Int = 0
    
    private let supabase = SupabaseManager.shared.client
    private var failedAttempts = 0
    private var lockedUntil: Date?
    private var rateLimitTimer: Task<Void, Never>?
    
    init() {
            // Restore session on init
            Task {
                await restoreSession()
                self.isInitializing = false
            }
        }
    
    private func restoreSession() async {
            do {
                // Try to get existing session
                let session = try await supabase.auth.session
                
                // Check if session is expired
                if session.isExpired {
                    debugLog("⚠️ Session is expired, signing out")
                    self.session = nil
                    self.isAuthenticated = false
                    try? await supabase.auth.signOut()
                    return
                }
                
                self.session = session
                self.isAuthenticated = true
                await fetchUserProfile()
            } catch {
                debugLog("❌ No existing session: \(error.localizedDescription)")
                self.isAuthenticated = false
            }
        }
    
    func getInitialSession() async {
        do {
            let current = try await supabase.auth.session
            
            // Check if session is expired
            if current.isExpired {
                debugLog("⚠️ Session is expired")
                self.session = nil
                self.isAuthenticated = false
                return
            }
            
            self.session = current
            self.isAuthenticated = true
        } catch {
            debugLog("No active session: \(error.localizedDescription)")
            self.session = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Rate Limiting
    
    /// Returns true if the user is currently locked out due to too many failed attempts.
    var isRateLimited: Bool {
        if let lockedUntil, Date() < lockedUntil {
            return true
        }
        return false
    }
    
    /// Call after a failed auth attempt to enforce progressive backoff.
    private func recordFailedAttempt() {
        failedAttempts += 1
        // Backoff: 2s, 4s, 8s, 16s, capped at 30s
        let delay = min(Int(pow(2.0, Double(failedAttempts))), 30)
        lockedUntil = Date().addingTimeInterval(TimeInterval(delay))
        rateLimitSecondsRemaining = delay
        
        rateLimitTimer?.cancel()
        rateLimitTimer = Task { @MainActor in
            while rateLimitSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                rateLimitSecondsRemaining -= 1
            }
            lockedUntil = nil
        }
    }
    
    /// Call after a successful auth to reset the counter.
    private func resetRateLimit() {
        failedAttempts = 0
        lockedUntil = nil
        rateLimitSecondsRemaining = 0
        rateLimitTimer?.cancel()
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        guard !isRateLimited else {
            errorMessage = "Too many attempts. Please wait \(rateLimitSecondsRemaining)s."
            return
        }
        
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
            resetRateLimit()
            
            // Track successful sign-up with PostHog
            PostHogSDK.shared.capture("sign_up_successful", properties: [
                "user_id": result.user.id.uuidString as Any,
                "timestamp": Date().ISO8601Format() as Any
            ])
            PostHogSDK.shared.identify(result.user.id.uuidString)
            
        } catch let error as AuthError {
            recordFailedAttempt()
            errorMessage = error.localizedDescription
            registrationSuccess = false
        } catch {
            recordFailedAttempt()
            errorMessage = "Registration failed: \(error.localizedDescription)"
            registrationSuccess = false
        }
        
        isRegistering = false
    }
    
    func signIn(email: String, password: String) async {
        guard !isRateLimited else {
            errorMessage = "Too many attempts. Please wait \(rateLimitSecondsRemaining)s."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await supabase.auth.signIn(email: email, password: password)
            
            // Check if email is verified
            guard result.user.emailConfirmedAt != nil else {
                self.session = nil
                self.isAuthenticated = false
                self.errorMessage = "Please verify your email before signing in. Check your inbox for the verification link."
                try? await supabase.auth.signOut()
                isLoading = false
                return
            }
            
            self.session = result
            self.isAuthenticated = true
            resetRateLimit()
            
            // Sync RevenueCat user identity
            await SubscriptionManager.shared.syncUser()
            
            // Track successful sign-in with PostHog
            PostHogSDK.shared.capture("sign_in_successful", properties: [
                "user_id": result.user.id.uuidString as Any,
                "timestamp": Date().ISO8601Format() as Any
            ])
            PostHogSDK.shared.identify(result.user.id.uuidString)
            
            await fetchUserProfile()
        } catch let error as AuthError {
            recordFailedAttempt()
            // Generic error message to prevent email enumeration
            self.errorMessage = "Invalid email or password. Please try again."
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in failed: \(error.localizedDescription)")
        } catch {
            recordFailedAttempt()
            self.errorMessage = "An error occurred. Please try again."
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func signOut() async{
        do{
            try await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
            self.userProfile = nil
            ExerciseRepository.shared.clearCache()
        } catch{
            debugLog("Sign-out failed: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() async -> Bool {
        do {
            try await supabase.rpc("delete_user_account").execute()
            try await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
            self.userProfile = nil
            return true
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            debugLog("Account deletion failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func fetchUserProfile() async {
        guard let userId = session?.user.id else { return }
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            self.userProfile = profile
            
            // Sync email from auth to profiles table if it changed
            if let authEmail = session?.user.email,
               profile.email != authEmail {
                struct UpdateEmail: Encodable {
                    let email: String
                }
                try await supabase
                    .from("profiles")
                    .update(UpdateEmail(email: authEmail))
                    .eq("id", value: userId.uuidString)
                    .execute()
            }
        } catch {
            debugLog("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
    var firstName: String {
        guard let fullName = userProfile?.fullName else { return "" }
        return fullName.components(separatedBy: " ").first ?? ""
    }
    
    func changeEmail(newEmail: String, password: String) async -> Bool {
        do {
            // Re-authenticate with current password before allowing email change
            guard let currentEmail = session?.user.email else {
                errorMessage = "Unable to verify current session."
                return false
            }
            _ = try await supabase.auth.signIn(email: currentEmail, password: password)
            
            try await supabase.auth.update(
                user: UserAttributes(email: newEmail)
            )
            
            return true
        } catch {
            errorMessage = "Incorrect password or failed to change email."
            return false
        }
    }
    

    
    // MARK: - Sign in with Apple
    
    /// The current nonce used for Sign in with Apple. Must be set before starting the flow.
    var currentNonce: String?
    
    /// Generates a cryptographically random nonce and stores it for later verification.
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }
    
    func signInWithApple(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Unable to get Apple ID credential."
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "Unable to retrieve identity token."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: currentNonce
                )
            )
            
            self.session = session
            self.isAuthenticated = true
            
            // Sync RevenueCat user identity
            await SubscriptionManager.shared.syncUser()
            
            // Update user metadata with full name if Apple provided it (first sign-in only)
            if let fullName = appleIDCredential.fullName {
                let firstName = fullName.givenName ?? ""
                let lastName = fullName.familyName ?? ""
                if !firstName.isEmpty || !lastName.isEmpty {
                    let displayName = [firstName, lastName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    _ = try? await supabase.auth.update(
                        user: UserAttributes(
                            data: [
                                "full_name": .string(displayName),
                                "first_name": .string(firstName),
                                "last_name": .string(lastName)
                            ]
                        )
                    )
                }
            }
            
            // Track sign-in with PostHog
            PostHogSDK.shared.capture("sign_in_with_apple_successful", properties: [
                "user_id": session.user.id.uuidString as Any,
                "timestamp": Date().ISO8601Format() as Any
            ])
            PostHogSDK.shared.identify(session.user.id.uuidString)
            
            await fetchUserProfile()
        } catch {
            self.errorMessage = "Sign in with Apple failed. Please try again."
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in with Apple failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Generates a random string for use as a nonce.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    /// Returns the SHA256 hash of the input string.
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

struct UserProfile : Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case username = "username"
        case avatarUrl = "avatar_url"
    }
}

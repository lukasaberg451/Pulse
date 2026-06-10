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
    private var cancellables = Set<AnyCancellable>()
    
    init() {
            NotificationCenter.default.publisher(for: .profileUpdated)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.fetchUserProfile()
                    }
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: .networkRestored)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.refreshAfterNetworkRestored()
                    }
                }
                .store(in: &cancellables)
            
            let args = ProcessInfo.processInfo.arguments

            if args.contains("--reset-auth") {
                // Force sign-out so login tests start from unauthenticated state
                Task {
                    try? await supabase.auth.signOut()
                    self.isInitializing = false
                }
                return
            }

            if args.contains("--skip-auth-free") {
                // Sign in with the free test account so UI tests can
                // verify paywall and subscription-gated behaviour.
                Task {
                    await signInWithFreeTestCredentials()
                    self.isInitializing = false
                }
                return
            }

            if args.contains("--skip-auth") {
                // Programmatically sign in with test credentials so UI tests
                // land on the home screen without touching the login UI.
                Task {
                    await signInWithTestCredentials()
                    self.isInitializing = false
                }
                return
            }

            // Restore session on init
            Task {
                await restoreSession()
                self.isInitializing = false
            }
        }
    
    private func restoreSession() async {
            do {
                // Try to get existing session from Keychain.
                // This may auto-refresh an expired token, which can throw
                // a network error when offline.
                let session = try await supabase.auth.session

                // Validate session server-side by refreshing it.
                // Keychain tokens persist across app reinstalls, so a deleted
                // user would still have a local token. Refreshing will fail if
                // the user no longer exists, preventing a ghost login.
                do {
                    let refreshedSession = try await supabase.auth.refreshSession()
                    self.session = refreshedSession
                    self.isAuthenticated = true
                    await fetchUserProfile()
                } catch where Self.isNetworkError(error) {
                    // Network error - we're offline. Trust the local session
                    // so the user can continue using the app in offline mode.
                    debugLog("⚠️ Offline: could not refresh session (\(error.localizedDescription)), using local session")
                    self.session = session
                    self.isAuthenticated = true
                } catch {
                    // Auth error (e.g. user deleted, token revoked) - clear session
                    debugLog("❌ Session refresh failed: \(error.localizedDescription)")
                    self.session = nil
                    self.isAuthenticated = false
                    try? await supabase.auth.signOut()
                }
            } catch where Self.isNetworkError(error) {
                // The session getter failed due to a network error (e.g. it
                // tried to auto-refresh an expired token while offline).
                // Fall back to the locally cached session so the user can
                // continue using the app in offline mode.
                if let cachedSession = supabase.auth.currentSession {
                    debugLog("⚠️ Offline: session getter failed, using cached session")
                    self.session = cachedSession
                    self.isAuthenticated = true
                } else {
                    debugLog("❌ Offline with no cached session")
                    self.session = nil
                    self.isAuthenticated = false
                }
            } catch {
                debugLog("❌ No existing session: \(error.localizedDescription)")
                self.session = nil
                self.isAuthenticated = false
                // Clear any stale Keychain tokens
                try? await supabase.auth.signOut()
            }
        }
    
    /// Signs in with test credentials read from Info.plist (UITEST_EMAIL / UITEST_PASSWORD).
    /// Falls back to restoring an existing session if the credentials are missing or sign-in fails.
    private func signInWithTestCredentials() async {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "UITEST_EMAIL") as? String,
              let password = Bundle.main.object(forInfoDictionaryKey: "UITEST_PASSWORD") as? String,
              !email.isEmpty, !password.isEmpty else {
            debugLog("⚠️ --skip-auth: no test credentials in Info.plist, falling back to session restore")
            await restoreSession()
            return
        }

        do {
            let result = try await supabase.auth.signIn(email: email, password: password)
            self.session = result
            self.isAuthenticated = true
        } catch {
            debugLog("⚠️ --skip-auth sign-in failed: \(error.localizedDescription), falling back to session restore")
            await restoreSession()
        }
    }

    /// Signs in with the free test account read from Info.plist (UITEST_FREE_EMAIL / UITEST_FREE_PASSWORD).
    /// Falls back to restoring an existing session if the credentials are missing or sign-in fails.
    private func signInWithFreeTestCredentials() async {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "UITEST_FREE_EMAIL") as? String,
              let password = Bundle.main.object(forInfoDictionaryKey: "UITEST_FREE_PASSWORD") as? String,
              !email.isEmpty, !password.isEmpty else {
            debugLog("⚠️ --skip-auth-free: no free test credentials in Info.plist, falling back to session restore")
            await restoreSession()
            return
        }

        do {
            let result = try await supabase.auth.signIn(email: email, password: password)
            self.session = result
            self.isAuthenticated = true
        } catch {
            debugLog("⚠️ --skip-auth-free sign-in failed: \(error.localizedDescription), falling back to session restore")
            await restoreSession()
        }
    }

    /// Called when the network comes back after being offline. If the session
    /// was restored from a cached token while offline, it was never validated
    /// against the server and `userProfile` may be nil. Refresh both.
    private func refreshAfterNetworkRestored() async {
        guard isAuthenticated else { return }

        do {
            let refreshedSession = try await supabase.auth.refreshSession()
            self.session = refreshedSession
        } catch where Self.isNetworkError(error) {
            debugLog("⚠️ Network restored notification fired but refresh still failed: \(error.localizedDescription)")
            return
        } catch {
            debugLog("❌ Session refresh failed after network restored: \(error.localizedDescription)")
            self.session = nil
            self.isAuthenticated = false
            self.userProfile = nil
            try? await supabase.auth.signOut()
            return
        }

        await fetchUserProfile()
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
    
    private static func isNetworkError(_ error: Error) -> Bool {
        if error is URLError { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        // Check wrapped errors (e.g. Supabase wrapping a URLError)
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isNetworkError(underlying)
        }
        return false
    }

    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        guard !isRateLimited else {
            errorMessage = String(localized: "Too many attempts. Please wait \(rateLimitSecondsRemaining)s.")
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
            errorMessage = String(localized: "Registration failed: \(error.localizedDescription)")
            registrationSuccess = false
        }
        
        isRegistering = false
    }
    
    func signIn(email: String, password: String) async {
        guard !isRateLimited else {
            errorMessage = String(localized: "Too many attempts. Please wait \(rateLimitSecondsRemaining)s.")
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
                self.errorMessage = String(localized: "Please verify your email before signing in. Check your inbox for the verification link.")
                try? await supabase.auth.signOut()
                isLoading = false
                return
            }
            
            self.session = result
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
            
            // Set isAuthenticated last - isLoading stays true so the
            // LoginView loading overlay covers the view-tree swap until
            // PulseApp's PostLoginLoadingView takes over.
            self.isAuthenticated = true
        } catch let error as AuthError {
            recordFailedAttempt()
            // Generic error message to prevent email enumeration
            self.errorMessage = String(localized: "Invalid email or password. Please try again.")
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in failed: \(error.localizedDescription)")
            isLoading = false
        } catch {
            recordFailedAttempt()
            self.errorMessage = String(localized: "An error occurred. Please try again.")
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in failed: \(error.localizedDescription)")
            isLoading = false
        }
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
            // Sign out to clear Keychain tokens. Use try? because the server
            // may reject the call if the auth user was already removed by the
            // RPC - but we still need local cleanup to happen.
            try? await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
            self.userProfile = nil
            ExerciseRepository.shared.clearCache()
            return true
        } catch {
            errorMessage = String(localized: "Failed to delete account: \(error.localizedDescription)")
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
    
    /// Whether the current user signed in with Apple (cannot change email via password flow).
    var isAppleUser: Bool {
        if case .string(let provider) = session?.user.appMetadata["provider"] {
            return provider == "apple"
        }
        return false
    }
    
    func changeEmail(newEmail: String, password: String) async -> Bool {
        do {
            // Re-authenticate with current password before allowing email change
            guard let currentEmail = session?.user.email else {
                errorMessage = String(localized: "Unable to verify current session.")
                return false
            }
            _ = try await supabase.auth.signIn(email: currentEmail, password: password)
            
            try await supabase.auth.update(
                user: UserAttributes(email: newEmail)
            )
            
            return true
        } catch {
            errorMessage = String(localized: "Incorrect password or failed to change email.")
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
            errorMessage = String(localized: "Unable to get Apple ID credential.")
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = String(localized: "Unable to retrieve identity token.")
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
            
            // Sync RevenueCat user identity
            await SubscriptionManager.shared.syncUser()
            
            // Update user metadata and profile with full name if Apple provided it (first sign-in only)
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
                    
                    // Sync name to profiles table (the DB trigger created
                    // the row before the metadata was available)
                    struct UpdateAppleProfile: Encodable {
                        let first_name: String
                        let last_name: String
                        let full_name: String
                        let email: String?
                    }
                    _ = try? await supabase
                        .from("profiles")
                        .update(UpdateAppleProfile(
                            first_name: firstName,
                            last_name: lastName,
                            full_name: displayName,
                            email: session.user.email
                        ))
                        .eq("id", value: session.user.id.uuidString)
                        .execute()
                }
            }
            
            // Track sign-in with PostHog
            PostHogSDK.shared.capture("sign_in_with_apple_successful", properties: [
                "user_id": session.user.id.uuidString as Any,
                "timestamp": Date().ISO8601Format() as Any
            ])
            PostHogSDK.shared.identify(session.user.id.uuidString)
            
            await fetchUserProfile()
            
            // Set isAuthenticated last - isLoading stays true so the
            // loading overlay covers the view-tree swap.
            self.isAuthenticated = true
        } catch {
            self.errorMessage = String(localized: "Sign in with Apple failed. Please try again.")
            self.session = nil
            self.isAuthenticated = false
            debugLog("Sign in with Apple failed: \(error.localizedDescription)")
            isLoading = false
        }
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

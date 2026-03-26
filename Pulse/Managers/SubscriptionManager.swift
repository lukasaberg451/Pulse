//
//  SubscriptionManager.swift
//  Pulse
//
//  Created by Lukas Åberg on 3/1/26.
//

import SwiftUI
import Combine
import RevenueCat
import Supabase

@MainActor
class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isProUser = false
    @Published var currentOffering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var trialEligible = false
    
    static let freeRoutineLimit = 3
    private static let entitlementID = "pulse_pro"
    
    private override init() { super.init() }
    
    // MARK: - Configuration
    
    /// Call this once at app launch (e.g. in AppDelegate)
    func configure() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String else {
            fatalError("Missing RevenueCat configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        
        // Try to get the existing Supabase user ID so RevenueCat starts identified
        if let userId = SupabaseManager.shared.client.auth.currentSession?.user.id.uuidString {
            Purchases.configure(withAPIKey: apiKey, appUserID: userId)
        } else {
            Purchases.configure(withAPIKey: apiKey)
        }
        
        // Listen for real-time subscription status changes (expiration, renewal, revocation)
        Purchases.shared.delegate = self
    }
    
    /// Sync the current Supabase user with RevenueCat
    func syncUser() async {
        do {
            Purchases.shared.invalidateCustomerInfoCache()
            let session = try await SupabaseManager.shared.client.auth.session
            let userID = session.user.id.uuidString
            debugLog("RevenueCat syncing user: \(userID)")
            let (customerInfo, _) = try await Purchases.shared.logIn(userID)
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
        } catch {
            debugLog("RevenueCat login error: \(error.localizedDescription)")
        }
    }
    
    /// Clear user on sign out
    func logout() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
        } catch {
            debugLog("RevenueCat logout error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Offerings
    
    func fetchOfferings() async {
        isLoading = true
        errorMessage = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            
            if let product = offerings.current?.availablePackages.first?.storeProduct {
                let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
                trialEligible = eligibility == .eligible
            }
        } catch {
            errorMessage = error.localizedDescription
            debugLog("Error fetching offerings: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // MARK: - Purchases
    
    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            self.customerInfo = result.customerInfo
            updateProStatus(from: result.customerInfo)
            isLoading = false
            return !result.userCancelled
        } catch {
            errorMessage = error.localizedDescription
            debugLog("Purchase error: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
        } catch {
            errorMessage = error.localizedDescription
            debugLog("Restore error: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    // MARK: - Entitlement Check
    
    func refreshStatus() async {
        do {
            // Invalidate cache so RevenueCat makes a fresh network request
            // (the default customerInfo() returns cached data which won't reflect server-side expiration)
            Purchases.shared.invalidateCustomerInfoCache()
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
        } catch {
            debugLog("Error fetching customer info: \(error.localizedDescription)")
        }
    }
    
    private func updateProStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[Self.entitlementID]
        let newStatus = entitlement?.isActive == true
        debugLog("RevenueCat status — user: \(customerInfo.originalAppUserId), entitlement: \(entitlement != nil ? "found" : "nil"), isActive: \(entitlement?.isActive ?? false), expiresDate: \(entitlement?.expirationDate?.description ?? "nil"), isProUser: \(isProUser) → \(newStatus)")
        isProUser = newStatus
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    /// Called by RevenueCat whenever customer info changes (e.g. subscription expires, renews, or is revoked).
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateProStatus(from: customerInfo)
        }
    }
}

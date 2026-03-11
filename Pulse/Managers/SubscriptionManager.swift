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
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isProUser = false
    @Published var currentOffering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var trialEligible = false
    
    static let freeRoutineLimit = 3
    private static let entitlementID = "pulse_pro"
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Call this once at app launch (e.g. in AppDelegate)
    func configure() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String else {
            fatalError("Missing RevenueCat configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }
        Purchases.logLevel = .debug
        
        // Try to get the existing Supabase user ID so RevenueCat starts identified
        if let userId = SupabaseManager.shared.client.auth.currentSession?.user.id.uuidString {
            Purchases.configure(withAPIKey: apiKey, appUserID: userId)
        } else {
            Purchases.configure(withAPIKey: apiKey)
        }
    }
    
    /// Sync the current Supabase user with RevenueCat
    func syncUser() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userID = session.user.id.uuidString
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
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            updateProStatus(from: customerInfo)
        } catch {
            debugLog("Error fetching customer info: \(error.localizedDescription)")
        }
    }
    
    private func updateProStatus(from customerInfo: CustomerInfo) {
        isProUser = customerInfo.entitlements[Self.entitlementID]?.isActive == true
    }
}

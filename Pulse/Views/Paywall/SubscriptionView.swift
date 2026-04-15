//
//  SubscriptionView.swift
//  Pulse
//
//  Created by Lukas Åberg on 3/1/26.
//

import SwiftUI
import RevenueCat

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isPurchasing = false
    @State private var safariURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.dashboardBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero section
                        VStack(spacing: 16) {
                            ZStack {
                                Image(.pulseProLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 140, height: 80)
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                            
                            if subscriptionManager.isProUser {
                                Text("Pulse Pro")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Text("You're a Pro subscriber")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            } else {
                                Text("Upgrade to Pro")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Color.appText)
                                
                                Text("Take your training to the next level")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSecondaryText)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        
                        // Features
                        VStack(spacing: 0) {
                            SubscriptionFeatureRow(
                                icon: "progressup",
                                title: "Analytics",
                                subtitle: "Detailed progress insights and trends"
                            )
                            
                            Divider()
                                .padding(.leading, 68)
                            
                            SubscriptionFeatureRow(
                                icon: "list",
                                title: "Unlimited Routines",
                                subtitle: "Create and track your own routines"
                            )
                            
                            Divider()
                                .padding(.leading, 68)
                            
                            SubscriptionFeatureRow(
                                icon: "watch",
                                title: "Apple Watch",
                                subtitle: "Log workouts straight from your wrist"
                            )
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appSurface)
                                .overlay {
                                    if colorScheme == .dark {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    }
                                }
                                .shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 12, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        if subscriptionManager.isProUser {
                            // Active subscriber section
                            VStack(spacing: 16) {
                                Text("To cancel your subscription, go to your Apple ID subscription settings.")
                                    .font(.caption)
                                    .foregroundStyle(Color.appTertiaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                                
                                PrimaryCTAButton("Manage Subscription") {
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 24)
                            .padding(.bottom, 30)
                        } else {
                            // Pricing & CTA
                            VStack(spacing: 14) {
                                if subscriptionManager.isLoading && !isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                                        .padding(.vertical, 30)
                                } else if let package = subscriptionManager.currentOffering?.availablePackages.first {
                                    if subscriptionManager.trialEligible,
                                       let intro = package.storeProduct.introductoryDiscount {
                                        Text("\(intro.subscriptionPeriod.trialDescription) free, then \(package.localizedPriceString)/month")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appText)
                                    } else {
                                        Text("Unlock Pro for \(package.localizedPriceString)/month")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appText)
                                    }
                                    
                                    Button {
                                        isPurchasing = true
                                        Task {
                                            let success = await subscriptionManager.purchase(package)
                                            isPurchasing = false
                                            if success {
                                                dismiss()
                                            }
                                        }
                                    } label: {
                                        if isPurchasing {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 52)
                                                .background(LinearGradient.accentGradient.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        } else {
                                            Text(subscriptionManager.trialEligible ? String(localized: "Start Free Trial") : String(localized: "Continue"))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 52)
                                                .background(LinearGradient.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                    }
                                    .buttonStyle(ScalePressStyle())
                                    .disabled(isPurchasing)
                                    
                                    if subscriptionManager.trialEligible {
                                        Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appTertiaryText)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 4)
                                    } else {
                                        Text("Subscription automatically renews unless canceled.")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appTertiaryText)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 28)
                            
                            // Error
                            if let error = subscriptionManager.errorMessage {
                                HStack(spacing: 8) {
                                    Image("error")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .foregroundStyle(.red)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.top, 8)
                                .padding(.horizontal)
                            }
                            
                            // Restore
                            Button {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                    if subscriptionManager.isProUser {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appAccent)
                            }
                            .padding(.top, 16)
                            
                            // Legal
                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    safariURL = Constants.URLs.termsOfService
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                                
                                Text("·")
                                    .foregroundStyle(Color.appTertiaryText)
                                
                                Button("Privacy Policy") {
                                    safariURL = Constants.URLs.privacyPolicy
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .sentryScreen("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image("xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            }
            .task {
                await subscriptionManager.fetchOfferings()
            }
            .fullScreenCover(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .presentationBackground(LinearGradient.dashboardBackground)
    }
}

// MARK: - Feature Row

private struct SubscriptionFeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var isSystemImage: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            if isSystemImage {
                IconBadge(systemName: icon, size: 40)
            } else {
                IconBadge(assetName: icon, size: 40)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
            
            Spacer()
            
            Image("check-circle")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Trial Period Formatting

private extension SubscriptionPeriod {
    var trialDescription: String {
        switch unit {
        case .day:
            return value == 1 ? "1 day" : "\(value) days"
        case .week:
            return value == 1 ? "7 days" : "\(value) weeks"
        case .month:
            return value == 1 ? "1 month" : "\(value) months"
        case .year:
            return value == 1 ? "1 year" : "\(value) years"
        }
    }
}

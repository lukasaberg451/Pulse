//
//  SettingsView.swift
//  Pulse
//
//  Created by Lukas Åberg on 2026-03-12.
//

import SwiftUI
import SafariServices
import StoreKit

struct SettingsView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var unitManager: UnitManager
    
    @State private var showingThemeSheet = false
    @State private var showingUnitSheet = false
    @State private var showingTimezoneSheet = false
    @State private var showingSubscriptionSheet = false
    @State private var showingFeedbackSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var safariURL: URL?
    @State private var isTestBuild = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.signOutAction) private var signOutAction
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        if isTestBuild {
            return "Version \(version) (\(build))"
        } else {
            return "Version \(version)"
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient.dashboardBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Subscription Section
                    VStack(alignment: .leading, spacing: 10) {
                        DashboardSectionHeader(title: "Subscription")
                            .padding(.horizontal)
                        
                        Button {
                            let impactLight = UIImpactFeedbackGenerator(style: .light)
                            impactLight.impactOccurred()
                            showingSubscriptionSheet = true
                        } label: {
                            HStack(spacing: 14) {
                                IconBadge(assetName: "starshine", size: 32)
                                
                                Text("Plan", comment: "Subscription plan label")
                                    .font(.body)
                                    .foregroundStyle(Color.appText)
                                
                                Spacer()
                                
                                Text(subscriptionManager.isProUser ? String(localized: "Pro") : String(localized: "Free"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appSecondaryText)
                                
                                Image("chevron-right")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 13, height: 13)
                                    .foregroundStyle(Color.appTertiaryText)
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .profileCardShadow(colorScheme: colorScheme)
                        }
                        .accessibilityIdentifier("settingsPlanButton")
                        .buttonStyle(ScalePressStyle())
                        .padding(.horizontal)
                    }
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 10) {
                        DashboardSectionHeader(title: "General")
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Appearance
                            ProfileSettingsRow(icon: "brush", title: "Appearance", value: themeManager.selectedTheme.displayName) {
                                showingThemeSheet = true
                            }
                            .accessibilityIdentifier("settingsAppearanceRow")
                            
                            ProfileDivider()
                            
                            // Units
                            ProfileSettingsRow(icon: "ruler", title: "Units", value: unitManager.unitSystem.displayName) {
                                showingUnitSheet = true
                            }
                            .accessibilityIdentifier("settingsUnitsRow")
                            
                            ProfileDivider()
                            
                            // Timezone
                            ProfileSettingsRow(icon: "clock", title: "Time Zone", value: viewModel.profile?.timezone ?? TimeZone.current.identifier, lineLimit: 1) {
                                showingTimezoneSheet = true
                            }
                            .accessibilityIdentifier("settingsTimezoneRow")
                            
                            if healthKitManager.isAvailable {
                                ProfileDivider()
                                
                                // Apple Health
                                Button {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    if healthKitManager.isSyncEnabled {
                                        if let url = URL(string: "x-apple-health://") {
                                            UIApplication.shared.open(url)
                                        }
                                    } else {
                                        Task {
                                            await healthKitManager.requestAuthorization()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        IconBadge(assetName: "heart", color: .pink, size: 32)
                                        
                                        Text("Apple Health")
                                            .font(.body)
                                            .foregroundStyle(Color.appText)
                                        
                                        Spacer()
                                        
                                        if healthKitManager.isSyncEnabled {
                                            Text("Connected", comment: "Health connection status")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.green)
                                        } else {
                                            Text("Connect", comment: "Health connection action")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.appAccent)
                                        }
                                    }
                                    .padding(14)
                                }
                            }
                            
                            ProfileDivider()
                            
                            // Apple Watch
                            Button {
                                if !subscriptionManager.isProUser {
                                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                                    impactLight.impactOccurred()
                                    showingSubscriptionSheet = true
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(assetName: "watch", size: 32)
                                    
                                    Text("Apple Watch")
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    if subscriptionManager.isProUser {
                                        Text(WorkoutSyncManager.shared.isPaired == true ? String(localized: "Connected") : String(localized: "Not Connected"))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(WorkoutSyncManager.shared.isPaired == true ? .green : Color.appSecondaryText)
                                    } else {
                                        Text("Upgrade to Pro", comment: "Upsell label")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appAccent)
                                        
                                        Image("chevron-right")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 13, height: 13)
                                            .foregroundStyle(Color.appTertiaryText)
                                    }
                                }
                                .padding(14)
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .profileCardShadow(colorScheme: colorScheme)
                        .padding(.horizontal)
                    }
                    
                    // Rate Pulse
                    Button {
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                        if let url = URL(string: "itms-apps://apps.apple.com/app/id6759346770") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            IconBadge(assetName: "star", size: 32)
                            
                            Text("Enjoying Pulse? Rate us!", comment: "Rate app prompt")
                                .font(.body)
                                .foregroundStyle(Color.appText)
                            
                            Spacer()
                            
                            Image("arrow-angular-top-right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 11, height: 11)
                                .foregroundStyle(Color.appTertiaryText)
                        }
                        .padding(14)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .profileCardShadow(colorScheme: colorScheme)
                    .padding(.horizontal)
                    
                    // Support Section
                    VStack(alignment: .leading, spacing: 10) {
                        DashboardSectionHeader(title: "Support")
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Send Feedback
                            ProfileSettingsRow(icon: "clipboard-text", title: "Send Feedback") {
                                showingFeedbackSheet = true
                            }
                            .accessibilityIdentifier("settingsFeedbackRow")
                            
                            ProfileDivider()
                            
                            // Help & Support
                            Button {
                                let impactLight = UIImpactFeedbackGenerator(style: .light)
                                impactLight.impactOccurred()
                                if let url = URL(string: "https://pulsefitness.io/support/") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(assetName: "question-mark-circle", size: 32)
                                    
                                    Text("Help & Support", comment: "Settings row")
                                        .font(.body)
                                        .foregroundStyle(Color.appText)
                                    
                                    Spacer()
                                    
                                    Image("arrow-angular-top-right")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 11, height: 11)
                                        .foregroundStyle(Color.appTertiaryText)
                                }
                                .padding(14)
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .profileCardShadow(colorScheme: colorScheme)
                        .padding(.horizontal)
                    }
                    
                    // Sign Out Button
                    Button {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.warning)
                        showingSignOutAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Sign Out", comment: "Settings action")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityIdentifier("settingsSignOutButton")
                    .buttonStyle(ScalePressStyle())
                    .padding(.horizontal)
                    
                    // Delete Account Button
                    Button {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.warning)
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image("trash")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .font(.subheadline.weight(.semibold))
                                Text("Delete Account", comment: "Settings action")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityIdentifier("settingsDeleteAccountButton")
                    .buttonStyle(ScalePressStyle())
                    .disabled(isDeletingAccount)
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Terms & Privacy
                HStack(spacing: 16) {
                    Button(action: {
                        safariURL = Constants.URLs.termsOfService
                    }) {
                        Text("Terms of Service", comment: "Legal link")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.appTertiaryText)

                    Button(action: {
                        safariURL = Constants.URLs.privacyPolicy
                    }) {
                        Text("Privacy Policy", comment: "Legal link")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                
                Text(appVersion)
                    .font(.caption2)
                    .foregroundStyle(Color.appTertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
        }
        .sentryScreen("Settings")
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .alert(String(localized: "Sign Out"), isPresented: $showingSignOutAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Sign Out"), role: .destructive) {
                Task {
                    await signOutAction()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?", comment: "Sign out confirmation")
        }
        .alert(String(localized: "Delete Account"), isPresented: $showingDeleteAccountAlert) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Continue"), role: .destructive) {
                showingDeleteConfirmation = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be removed.", comment: "Delete account confirmation")
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteAccountConfirmationSheet(
                isDeletingAccount: $isDeletingAccount,
                authViewModel: authViewModel
            )
            .sheetContentTransition()
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            FeedbackSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingThemeSheet) {
            ThemeSelectionSheet()
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingUnitSheet) {
            UnitSelectionSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingTimezoneSheet) {
            TimezoneSelectionSheet(viewModel: viewModel)
                .sheetContentTransition()
        }
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionView()
                .sheetContentTransition()
        }
        .fullScreenCover(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .alert("Apple Health Access", isPresented: $healthKitManager.showDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Workout sharing was not enabled. To allow this later, go to the Health app → Sharing → Apps and grant access to Pulse.")
        }
        .task {
            await viewModel.loadProfile()
            #if DEBUG
            isTestBuild = true
            #else
            if let result = try? await AppTransaction.shared,
               case .verified(let appTransaction) = result {
                isTestBuild = appTransaction.environment != .production
            }
            #endif
        }
    }
    

}

//
//  PulseApp.swift
//  Pulse
//
//  Created by Lukas Åberg on 2/5/26.
//

import SwiftUI
import SwiftData
import PostHog
import UIKit
import RevenueCat
import Sentry

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard let posthogAPIKey = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
              let posthogHost = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String else {
            fatalError("Missing PostHog configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }

        let config = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        PostHogSDK.shared.setup(config)

        // Configure RevenueCat
        SubscriptionManager.shared.configure()

        // Configure Sentry
        if let sentryDSN = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String {
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.debug = false
                options.tracesSampleRate = 0.2
                options.attachScreenshot = false
                options.attachViewHierarchy = false
            }
        }

        return true
    }
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct DismissAllSheetsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var dismissAllSheets: () -> Void {
        get { self[DismissAllSheetsKey.self] }
        set { self[DismissAllSheetsKey.self] = newValue }
    }
}

@main
struct PulseApp: App {
    // Connect the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("hasCompletedFirstLaunchGuide") private var hasCompletedFirstLaunchGuide = false
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var syncService = WorkoutSyncService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var unitManager = UnitManager.shared

    @State private var showPasswordReset = false
    @State private var recoveryCode: IdentifiableString?
    @State private var showPostSignInGuide = false
    @State private var showPostLoginLoading = false
    @State private var showPostLogoutLoading = false
    @State private var showSplash = true
    @State private var selectedTab: HomeTab = .dashboard
    
    // SwiftData model container for offline support
    let modelContainer: ModelContainer
    
    init() {
        // Initialize SwiftData model container for offline support
        // Only store user-created data: workout sessions, sets, routines, and routine exercises
        // Exercise browsing requires online connectivity
        do {
            let schema = Schema([
                // Workout models - user-created data
                LocalWorkoutSession.self,
                LocalWorkoutSet.self,
                // Routine models - user's routines only
                LocalRoutine.self,
                LocalRoutineExercise.self,
                // Exercise cache - only exercises used in user's routines
                LocalExercise.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        // Initialize WatchConnectivity
        _ = WorkoutSyncManager.shared
        
        // Navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.appText)]
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.appText)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.appAccent)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeView(authViewModel: authViewModel, selectedTab: $selectedTab)
                        .environmentObject(authViewModel)
                        .overlay {
                            if showPostSignInGuide {
                                PostSignInGuideView(isPresented: $showPostSignInGuide, selectedTab: $selectedTab)
                            }
                        }
                        .overlay {
                            if showPostLoginLoading {
                                PostLoginLoadingView(isVisible: $showPostLoginLoading)
                            }
                        }
                        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
                            // Show guide ONLY on first launch after user authenticates
                            if newValue && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showPostSignInGuide = true
                                }
                            }
                        }
                        .onAppear {
                            // Also check on appear in case already authenticated
                            if authViewModel.isAuthenticated && !hasCompletedFirstLaunchGuide {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showPostSignInGuide = true
                                }
                            }
                        }
                } else {
                    AuthSelectionView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                        .overlay {
                            if showPostLogoutLoading {
                                PostLoginLoadingView(isVisible: $showPostLogoutLoading)
                            }
                        }
                }
            }
            .id(authViewModel.isAuthenticated)
            .environmentObject(themeManager)
            .environmentObject(syncService)
            .environmentObject(subscriptionManager)
            .environmentObject(healthKitManager)
            .environmentObject(unitManager)
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
            .overlay {
                if showSplash {
                    SplashOverlay(
                        isInitializing: authViewModel.isInitializing,
                        isVisible: $showSplash
                    )
                    .ignoresSafeArea()
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { oldValue, isAuthenticated in
                if !authViewModel.isInitializing {
                    if isAuthenticated && !oldValue {
                        // User just signed in
                        selectedTab = .dashboard
                        showPostLoginLoading = true
                    } else if !isAuthenticated && oldValue {
                        // User just signed out
                        showPostLogoutLoading = true
                    }
                }
                Task {
                    if isAuthenticated {
                        await subscriptionManager.syncUser()
                    } else {
                        await subscriptionManager.logout()
                    }
                    WorkoutSyncManager.shared.syncProStatus(subscriptionManager.isProUser)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(item: $recoveryCode) { codeWrapper in
                        ResetPasswordInAppView(recoveryCode: codeWrapper.value)
                            .onAppear {
                                // Clear the flag since the reset flow is now being handled
                                UserDefaults.standard.removeObject(forKey: "pendingPasswordReset")
                            }
            }
            .sheet(isPresented: $authViewModel.showRecoveryPrompt) {
                ResetPasswordInAppView(recoveryCode: nil)
            }
        }
        .modelContainer(modelContainer)
    }
    
    func handleDeepLink(_ url: URL) {
        // Only process deep links from the expected host
        guard url.host == "pulsefitness.io" || url.scheme == "Pulse" else { return }
        
        if url.path.contains("reset-password") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
               !code.isEmpty,
               code.count <= 256,
               code.range(of: "^[A-Za-z0-9_\\-]+$", options: .regularExpression) != nil {
                
                // Mark that we're in recovery mode
                UserDefaults.standard.set(true, forKey: "pendingPasswordReset")
                
                recoveryCode = IdentifiableString(value: code)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    rootViewController.dismiss(animated: false)
                }
                
                showPasswordReset = true
            }
        }
    }
}

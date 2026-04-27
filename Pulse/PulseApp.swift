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
        #if !DEBUG
        guard let posthogAPIKey = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
              let posthogHost = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String else {
            fatalError("Missing PostHog configuration in Info.plist. Ensure Secrets.xcconfig is set up correctly.")
        }

        let config = PostHogConfig(apiKey: posthogAPIKey, host: posthogHost)
        PostHogSDK.shared.setup(config)
        #endif

        // Configure RevenueCat
        SubscriptionManager.shared.configure()

        // Configure Sentry
        #if DEBUG
        let sentryKey = "DEV_SENTRY_DSN"
        #else
        let sentryKey = "PROD_SENTRY_DSN"
        #endif
        if let sentryDSN = Bundle.main.object(forInfoDictionaryKey: sentryKey) as? String {
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.debug = false
                options.tracesSampleRate = 0.2
                options.attachScreenshot = true
                options.attachViewHierarchy = false
                options.enableAppHangTracking = true
                options.appHangTimeoutInterval = 2
            }
        }

        return true
    }
}



struct DismissAllSheetsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct SignOutActionKey: EnvironmentKey {
    static let defaultValue: () async -> Void = {}
}

private struct DeleteAccountActionKey: EnvironmentKey {
    static let defaultValue: () async -> Bool = { false }
}

private struct SplashDismissedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var dismissAllSheets: () -> Void {
        get { self[DismissAllSheetsKey.self] }
        set { self[DismissAllSheetsKey.self] = newValue }
    }

    var splashDismissed: Bool {
        get { self[SplashDismissedKey.self] }
        set { self[SplashDismissedKey.self] = newValue }
    }
    
    var signOutAction: () async -> Void {
        get { self[SignOutActionKey.self] }
        set { self[SignOutActionKey.self] = newValue }
    }
    
    var deleteAccountAction: () async -> Bool {
        get { self[DeleteAccountActionKey.self] }
        set { self[DeleteAccountActionKey.self] = newValue }
    }
}

@main
struct PulseApp: App {
    // Connect the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("hasCompletedFirstLaunchGuide") private var hasCompletedFirstLaunchGuide = false
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var syncService = WorkoutSyncService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var unitManager = UnitManager.shared
    @StateObject private var tourManager = OnboardingTourManager()

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    @State private var showPostLoginLoading = false
    @State private var showPostLogoutLoading = false
    @State private var showSplash = !PulseApp.isUITesting
    @State private var selectedTab: HomeTab = .dashboard
    @State private var appUpdateStatus: AppUpdateStatus = .upToDate
    
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
                        .environmentObject(tourManager)
                        .onChange(of: authViewModel.isAuthenticated) { _, newValue in
                            // Start spotlight tour on first launch after user authenticates
                            if newValue && !hasCompletedFirstLaunchGuide && !PulseApp.isUITesting {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    hasCompletedFirstLaunchGuide = true
                                    tourManager.start()
                                }
                            }
                        }
                        .onAppear {
                            if authViewModel.isAuthenticated && !hasCompletedFirstLaunchGuide && !PulseApp.isUITesting {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    hasCompletedFirstLaunchGuide = true
                                    tourManager.start()
                                }
                            }
                        }
                } else {
                    AuthSelectionView(authViewModel: authViewModel)
                        .environmentObject(authViewModel)
                }
            }
            .id(authViewModel.isAuthenticated)
            .environmentObject(themeManager)
            .environmentObject(syncService)
            .environmentObject(subscriptionManager)
            .environmentObject(healthKitManager)
            .environmentObject(unitManager)
            .onAppear { themeManager.applyToAllWindows() }
            .environment(\.splashDismissed, !showSplash && !showPostLoginLoading && !authViewModel.isLoading)
            .environment(\.signOutAction, { @MainActor in
                // Show the loading overlay first, then sign out after the fade-in
                // completes so the user never sees the view tree swap underneath.
                showPostLogoutLoading = true
                try? await Task.sleep(for: .milliseconds(400))
                await authViewModel.signOut()
            })
            .environment(\.deleteAccountAction, { @MainActor in
                showPostLogoutLoading = true
                try? await Task.sleep(for: .milliseconds(400))
                let success = await authViewModel.deleteAccount()
                if !success {
                    // Deletion failed — hide the overlay since we're still signed in
                    showPostLogoutLoading = false
                }
                return success
            })
            .overlay {
                // Bridging overlay: covers the view tree swap while
                // isLoading is still true but PostLoginLoadingView
                // hasn't been activated yet (prevents dashboard flash).
                if authViewModel.isLoading && !showPostLoginLoading {
                    ZStack {
                        Color.appBackground
                        LinearGradient.dashboardBackground
                        Image("LoadingLogo")
                    }
                    .ignoresSafeArea()
                }
            }
            .overlay {
                if showPostLoginLoading {
                    PostLoginLoadingView(isVisible: $showPostLoginLoading)
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if showPostLogoutLoading {
                    PostLoginLoadingView(isVisible: $showPostLogoutLoading)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .animation(.easeIn(duration: 0.35), value: showPostLogoutLoading)
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
                if !authViewModel.isInitializing && !PulseApp.isUITesting {
                    if isAuthenticated && !oldValue {
                        // User just signed in — show the post-login overlay and
                        // clear isLoading so the auth view model state is clean.
                        selectedTab = .dashboard
                        showPostLoginLoading = true
                        authViewModel.isLoading = false
                    } else if !isAuthenticated && oldValue && !showPostLogoutLoading {
                        // Signed out via another path (e.g. account deletion)
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                guard authViewModel.isAuthenticated else { return }
                Task {
                    await subscriptionManager.refreshStatus()
                }
            }
            .onChange(of: subscriptionManager.isProUser) { _, newValue in
                WorkoutSyncManager.shared.syncProStatus(newValue)
            }
            .onChange(of: showSplash) { _, splashVisible in
                guard !splashVisible else { return }
                checkForAppUpdate()
            }
            .onChange(of: showPostLoginLoading) { _, loading in
                guard !loading && !showSplash else { return }
                checkForAppUpdate()
            }
            .sheet(isPresented: Binding(
                get: { appUpdateStatus != .upToDate },
                set: { if !$0 { appUpdateStatus = .upToDate } }
            )) {
                switch appUpdateStatus {
                case .forceUpdate(let version):
                    AppUpdateSheet(latestVersion: version, isForced: true)
                case .softUpdate(let version):
                    AppUpdateSheet(latestVersion: version, isForced: false)
                        .onAppear {
                            AppUpdateChecker.shared.recordSoftSheetShown()
                        }
                case .upToDate:
                    EmptyView()
                }
            }

        }
        .modelContainer(modelContainer)
    }

    private func checkForAppUpdate() {
        Task {
            let status = await AppUpdateChecker.shared.checkUpdate()
            switch status {
            case .forceUpdate:
                appUpdateStatus = status
            case .softUpdate:
                if !AppUpdateChecker.shared.wasSoftSheetShownToday {
                    appUpdateStatus = status
                }
            case .upToDate:
                break
            }
        }
    }
}

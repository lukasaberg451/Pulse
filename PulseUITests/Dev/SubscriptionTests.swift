//
//  SubscriptionTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

// MARK: - Free User Subscription Tests

final class FreeUserSubscriptionTests: FreeUserUITestBaseCase {

    // MARK: - Helpers

    private func navigateToProgress() {
        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()
        _ = app.otherElements["progressPaywallPrompt"].waitForExistence(timeout: 10)
    }

    // MARK: - Test: Progress Tab Shows Paywall for Free User

    /// Verifies that a free user sees the paywall prompt instead of analytics
    /// when navigating to the Progress tab.
    func testProgressTabShowsPaywallForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertTrue(paywallPrompt.waitForExistence(timeout: 10), "Paywall prompt not found on Progress tab for free user")

        let unlockText = app.staticTexts["Unlock Progress Tracking"]
        XCTAssertTrue(unlockText.exists, "'Unlock Progress Tracking' text not found")

        let upgradeButton = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Upgrade to Pulse Pro'")).firstMatch
        XCTAssertTrue(upgradeButton.exists, "'Upgrade to Pulse Pro' button not found")
    }

    // MARK: - Test: Progress Tab Does Not Show Analytics for Free User

    /// Verifies that the Activity section and analytics cards are NOT visible
    /// for a free user on the Progress tab.
    func testProgressTabHidesAnalyticsForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertTrue(paywallPrompt.waitForExistence(timeout: 10), "Paywall prompt should be visible for free user")

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertFalse(activityHeader.exists, "Activity section should NOT be visible for free user")

        let streakCard = app.otherElements["progressStreakCard"]
        XCTAssertFalse(streakCard.exists, "Streak card should NOT be visible for free user")
    }

    // MARK: - Test: Settings Shows Free Plan Label

    /// Verifies the Plan button in Settings displays "Free" for a free user.
    func testSettingsShowsFreePlanLabel() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")

        let freeLabel = app.staticTexts["Free"]
        XCTAssertTrue(freeLabel.exists, "Plan button should show 'Free' for a free user")
    }

    // MARK: - Test: Settings Apple Watch Shows Upgrade to Pro

    /// Verifies the Apple Watch row shows "Upgrade to Pro" for a free user.
    func testAppleWatchShowsUpgradeForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let watchText = app.staticTexts["Apple Watch"]
        XCTAssertTrue(watchText.waitForExistence(timeout: 10), "Apple Watch row not found")

        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(upgradeToPro.exists, "Apple Watch row should show 'Upgrade to Pro' for free user")
    }

    // MARK: - Test: Subscription Sheet Shows Upgrade Content for Free User

    /// Taps the Plan button and verifies the subscription sheet shows
    /// upgrade content (not active subscriber content).
    func testSubscriptionSheetShowsUpgradeForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")
        planButton.tap()
        waitForAnimation()

        let upgradeTitle = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(upgradeTitle.waitForExistence(timeout: 5), "'Upgrade to Pro' title not found in subscription sheet")

        let subtitle = app.staticTexts["Take your training to the next level"]
        XCTAssertTrue(subtitle.exists, "Subscription sheet subtitle not found for free user")
    }

    // MARK: - Test: Subscription Sheet Shows Feature List

    /// Verifies the subscription sheet displays the three pro features.
    func testSubscriptionSheetShowsFeatureList() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")
        planButton.tap()
        waitForAnimation()

        let analyticsFeature = app.staticTexts["Analytics"]
        XCTAssertTrue(analyticsFeature.waitForExistence(timeout: 5), "'Analytics' feature not found")

        let unlimitedRoutines = app.staticTexts["Unlimited Routines"]
        XCTAssertTrue(unlimitedRoutines.exists, "'Unlimited Routines' feature not found")

        let appleWatch = app.staticTexts["Apple Watch"]
        XCTAssertTrue(appleWatch.exists, "'Apple Watch' feature not found")
    }

    // MARK: - Test: Progress Paywall Upgrade Button Opens Subscription Sheet

    /// Taps the upgrade button on the Progress tab paywall and verifies
    /// the subscription sheet appears.
    func testProgressPaywallOpensSubscriptionSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertTrue(paywallPrompt.waitForExistence(timeout: 10), "Paywall prompt not found")

        let upgradeButton = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Upgrade to Pulse Pro'")).firstMatch
        XCTAssertTrue(upgradeButton.exists, "Upgrade button not found on paywall")
        upgradeButton.tap()
        waitForAnimation()

        // Verify subscription sheet appeared with feature content
        let analyticsFeature = app.staticTexts["Analytics"]
        XCTAssertTrue(analyticsFeature.waitForExistence(timeout: 5), "Subscription sheet did not appear after tapping upgrade on paywall")
    }

    // MARK: - Test: Apple Watch Row Taps Opens Subscription Sheet for Free User

    /// Taps the Apple Watch row and verifies it opens the subscription sheet
    /// for a free user (since the feature is gated).
    func testAppleWatchRowOpensSubscriptionForFreeUser() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let watchText = app.staticTexts["Apple Watch"]
        XCTAssertTrue(watchText.waitForExistence(timeout: 10), "Apple Watch row not found")

        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(upgradeToPro.exists, "'Upgrade to Pro' should be visible")
        upgradeToPro.tap()
        waitForAnimation()

        let upgradeTitle = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(upgradeTitle.waitForExistence(timeout: 5), "Subscription sheet should open when free user taps Apple Watch row")
    }
}

// MARK: - Pro User Subscription Tests

final class ProUserSubscriptionTests: UITestBaseCase {

    // MARK: - Helpers

    private func navigateToProgress() {
        let progressTab = app.buttons["Progress"]
        assertExists(progressTab, timeout: 15, "Progress tab not found")
        progressTab.tap()
        _ = app.staticTexts["Activity"].waitForExistence(timeout: 10)
    }

    // MARK: - Test: Progress Tab Shows Analytics for Pro User

    /// Verifies that a pro user sees actual analytics content (Activity section,
    /// streak card) instead of the paywall prompt.
    func testProgressTabShowsAnalyticsForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "'Activity' section should be visible for pro user")

        let streakCard = app.otherElements["progressStreakCard"]
        XCTAssertTrue(streakCard.waitForExistence(timeout: 5), "Streak card should be visible for pro user")
    }

    // MARK: - Test: Progress Tab Does Not Show Paywall for Pro User

    /// Verifies the paywall prompt is NOT displayed for a pro user.
    func testProgressTabHidesPaywallForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        // Wait for content to load
        let activityHeader = app.staticTexts["Activity"]
        XCTAssertTrue(activityHeader.waitForExistence(timeout: 10), "Activity section should load for pro user")

        let paywallPrompt = app.otherElements["progressPaywallPrompt"]
        XCTAssertFalse(paywallPrompt.exists, "Paywall prompt should NOT be visible for pro user")
    }

    // MARK: - Test: Settings Shows Pro Plan Label

    /// Verifies the Plan button in Settings displays "Pro" for a pro user.
    func testSettingsShowsProPlanLabel() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")

        let proLabel = app.staticTexts["Pro"]
        XCTAssertTrue(proLabel.exists, "Plan button should show 'Pro' for a pro user")
    }

    // MARK: - Test: Apple Watch Does Not Show Upgrade for Pro User

    /// Verifies the Apple Watch row does NOT show "Upgrade to Pro" for a pro user.
    /// Instead it should show "Connected" or "Not Connected".
    func testAppleWatchDoesNotShowUpgradeForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let watchText = app.staticTexts["Apple Watch"]
        XCTAssertTrue(watchText.waitForExistence(timeout: 10), "Apple Watch row not found")

        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertFalse(upgradeToPro.exists, "Apple Watch row should NOT show 'Upgrade to Pro' for pro user")

        let connected = app.staticTexts["Connected"]
        let notConnected = app.staticTexts["Not Connected"]
        XCTAssertTrue(connected.exists || notConnected.exists, "Apple Watch row should show 'Connected' or 'Not Connected' for pro user")
    }

    // MARK: - Test: Subscription Sheet Shows Active Subscriber for Pro User

    /// Taps the Plan button and verifies the subscription sheet shows
    /// active subscriber content.
    func testSubscriptionSheetShowsActiveSubscriberForProUser() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")
        planButton.tap()
        waitForAnimation()

        let proTitle = app.staticTexts["Pulse Pro"]
        XCTAssertTrue(proTitle.waitForExistence(timeout: 5), "'Pulse Pro' title not found in subscription sheet")

        let subscriberText = app.staticTexts["You're a Pro subscriber"]
        XCTAssertTrue(subscriberText.exists, "'You're a Pro subscriber' text not found for pro user")
    }

    // MARK: - Test: Pro User Can See Workouts Card on Progress Tab

    /// Verifies the total workouts card is visible for a pro user.
    func testProUserSeesWorkoutsCard() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let workoutsCard = app.otherElements["progressWorkoutsCard"]
        XCTAssertTrue(workoutsCard.waitForExistence(timeout: 10), "Workouts card should be visible for pro user")
    }

    // MARK: - Test: Pro User Can See Volume Card on Progress Tab

    /// Verifies the volume lifted card is visible for a pro user.
    func testProUserSeesVolumeCard() throws {
        dismissResumeAlertIfPresent()
        navigateToProgress()

        let volumeCard = app.otherElements["progressVolumeCard"]
        XCTAssertTrue(volumeCard.waitForExistence(timeout: 10), "Volume card should be visible for pro user")
    }
}

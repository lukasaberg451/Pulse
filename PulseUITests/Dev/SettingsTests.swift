//
//  SettingsTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

final class SettingsTests: UITestBaseCase {

    // MARK: - Test: Sign Out Cancel Keeps User on Settings

    /// Taps Sign Out, cancels the alert, and verifies the user stays on Settings.
    func testSignOutCancelStaysOnSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5), "Sign Out button not found")
        signOutButton.tap()

        let alert = app.alerts["Sign Out"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Sign Out alert not found")
        alert.buttons["Cancel"].tap()

        // Verify we're still on Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Should remain on Settings after cancelling Sign Out")

        // Verify key elements are still present
        let generalHeader = app.staticTexts["General"]
        XCTAssertTrue(generalHeader.exists, "General section should still be visible after cancelling sign out")
    }

    // MARK: - Test: Delete Account Cancel Keeps User on Settings

    /// Taps Delete Account, cancels the alert, and verifies the user stays on Settings.
    func testDeleteAccountCancelStaysOnSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let deleteButton = app.buttons["settingsDeleteAccountButton"]
        if !deleteButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete Account button not found")
        deleteButton.tap()

        let alert = app.alerts["Delete Account"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete Account alert not found")
        alert.buttons["Cancel"].tap()

        // Verify we're still on Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Should remain on Settings after cancelling Delete Account")
    }

    // MARK: - Test: Subscription Plan Button Opens Sheet

    /// Taps the Plan button and verifies the subscription sheet appears.
    func testPlanButtonOpensSubscriptionSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found")
        planButton.tap()

        // The subscription sheet should be presented - look for common subscription UI
        let subscriptionContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Pro' OR label CONTAINS[c] 'Upgrade' OR label CONTAINS[c] 'Subscribe' OR label CONTAINS[c] 'Pulse Pro'")).firstMatch
        XCTAssertTrue(subscriptionContent.waitForExistence(timeout: 5), "Subscription sheet content not found after tapping Plan button")
    }

    // MARK: - Test: Apple Watch Row Is Visible

    /// Verifies the Apple Watch row is visible in the General section.
    func testAppleWatchRowVisible() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let watchText = app.staticTexts["Apple Watch"]
        XCTAssertTrue(watchText.waitForExistence(timeout: 10), "Apple Watch row not found in Settings")
    }

    // MARK: - Test: Apple Watch Row Shows Status

    /// Verifies the Apple Watch row shows either "Connected", "Not Connected", or "Upgrade to Pro".
    func testAppleWatchRowShowsStatus() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let watchText = app.staticTexts["Apple Watch"]
        XCTAssertTrue(watchText.waitForExistence(timeout: 10), "Apple Watch row not found")

        let connected = app.staticTexts["Connected"]
        let notConnected = app.staticTexts["Not Connected"]
        let upgradeToPro = app.staticTexts["Upgrade to Pro"]
        XCTAssertTrue(
            connected.exists || notConnected.exists || upgradeToPro.exists,
            "Apple Watch row should show 'Connected', 'Not Connected', or 'Upgrade to Pro'"
        )
    }

    // MARK: - Test: Theme Selection Changes Appearance Value

    /// Opens the Appearance sheet, selects Dark theme, and verifies the row updates.
    func testThemeSelectionUpdatesRow() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 10), "Appearance row not found")
        appearanceRow.tap()

        // Select "Dark" theme - use the button in the sheet, not staticTexts (avoids ambiguity with settings row)
        let darkOption = app.buttons.matching(NSPredicate(format: "label == 'Dark'")).firstMatch
        XCTAssertTrue(darkOption.waitForExistence(timeout: 5), "'Dark' option not found")
        darkOption.tap()
        waitForAnimation()

        // Dismiss the sheet
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found")
        doneButton.tap()

        // Verify the Appearance row now shows "Dark"
        let darkValue = app.staticTexts["Dark"]
        XCTAssertTrue(darkValue.waitForExistence(timeout: 5), "Appearance row should show 'Dark' after selection")

        // Reset to System
        appearanceRow.tap()
        let systemOption = app.buttons.matching(NSPredicate(format: "label == 'System'")).firstMatch
        XCTAssertTrue(systemOption.waitForExistence(timeout: 5), "'System' option not found")
        systemOption.tap()
        waitForAnimation()
        app.buttons["Done"].tap()
        waitForAnimation()
    }

    // MARK: - Test: Units Selection Shows Subtitles

    /// Opens the Units sheet and verifies the options include subtitles (kg/lbs descriptions).
    func testUnitsSheetShowsSubtitles() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.waitForExistence(timeout: 10), "Units row not found")
        unitsRow.tap()

        // Verify Metric option with subtitle
        let metricOption = app.staticTexts["Metric"]
        XCTAssertTrue(metricOption.waitForExistence(timeout: 5), "'Metric' option not found")

        // Verify Imperial option with subtitle
        let imperialOption = app.staticTexts["Imperial"]
        XCTAssertTrue(imperialOption.exists, "'Imperial' option not found")

        // Verify one of the subtitle descriptions is present (kg or lbs)
        let kgSubtitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'kg'")).firstMatch
        let lbsSubtitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'lbs'")).firstMatch
        XCTAssertTrue(kgSubtitle.exists || lbsSubtitle.exists, "Unit system subtitles (kg/lbs) not found")

        // Dismiss
        app.buttons["Done"].tap()
        waitForAnimation()
    }

    // MARK: - Test: Timezone Sheet Has Search

    /// Opens the Timezone sheet and verifies the search functionality is present.
    func testTimezoneSheetHasSearch() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        XCTAssertTrue(timezoneRow.waitForExistence(timeout: 10), "Time Zone row not found")
        timezoneRow.tap()

        // Verify search field is present
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field not found in Timezone sheet")

        // Dismiss
        app.buttons["Done"].tap()
        waitForAnimation()
    }

    // MARK: - Test: Feedback Sheet Has All Required Fields

    /// Opens the Feedback sheet and verifies all form elements are present and interactable.
    func testFeedbackSheetFormElements() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let feedbackRow = app.buttons["settingsFeedbackRow"]
        if !feedbackRow.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(feedbackRow.waitForExistence(timeout: 5), "Feedback row not found")
        feedbackRow.tap()

        // Verify TYPE section and selector
        let typeLabel = app.staticTexts["TYPE"]
        XCTAssertTrue(typeLabel.waitForExistence(timeout: 5), "'TYPE' label not found")

        // Verify TITLE section
        let titleLabel = app.staticTexts["TITLE"]
        XCTAssertTrue(titleLabel.exists, "'TITLE' label not found")

        // Verify DESCRIPTION section
        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.exists, "'DESCRIPTION' label not found")

        // Verify Submit button
        let submitButton = app.buttons["Submit Feedback"]
        XCTAssertTrue(submitButton.exists, "Submit Feedback button not found")

        // Verify Cancel button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found")

        // Dismiss
        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Delete Account Confirmation Sheet Can Be Cancelled

    /// Opens the Delete Account flow all the way to the confirmation sheet,
    /// then cancels and verifies return to Settings.
    func testDeleteAccountConfirmationSheetCancel() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let deleteButton = app.buttons["settingsDeleteAccountButton"]
        if !deleteButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete Account button not found")
        deleteButton.tap()

        // Tap Continue on the first alert
        let alert = app.alerts["Delete Account"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete Account alert not found")
        alert.buttons["Continue"].tap()

        // Verify the confirmation sheet appeared
        let confirmTitle = app.staticTexts["This action is irreversible"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: 5), "Delete confirmation sheet not found")

        // Cancel the confirmation sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on confirmation sheet")
        cancelButton.tap()

        // Verify we're back on Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Should return to Settings after cancelling delete confirmation")
    }

    // MARK: - Test: All Settings Sections Reachable via Scroll

    /// Verifies that all major sections of Settings are reachable by scrolling.
    func testAllSettingsSectionsReachable() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Subscription section (visible without scroll)
        let subscriptionHeader = app.staticTexts["Subscription"]
        XCTAssertTrue(subscriptionHeader.waitForExistence(timeout: 5), "'Subscription' section not found")

        // General section
        let generalHeader = app.staticTexts["General"]
        XCTAssertTrue(generalHeader.waitForExistence(timeout: 5), "'General' section not found")

        // Support section (may need scroll)
        let supportHeader = app.staticTexts["Support"]
        if !supportHeader.exists {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(supportHeader.waitForExistence(timeout: 5), "'Support' section not found")

        // Sign Out button
        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.exists {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5), "Sign Out button not found")

        // Delete Account button
        let deleteButton = app.buttons["settingsDeleteAccountButton"]
        if !deleteButton.exists {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete Account button not found")

        // Terms and Privacy links
        scrollToBottom()
        let termsButton = app.buttons["Terms of Service"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5), "'Terms of Service' link not found")

        let privacyButton = app.buttons["Privacy Policy"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5), "'Privacy Policy' link not found")

        // Version info
        let versionText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Version'")).firstMatch
        XCTAssertTrue(versionText.waitForExistence(timeout: 5), "Version info not found")
    }

    // MARK: - Test: Settings Shows Help & Support Row

    /// Verifies the Help & Support row is visible in the Support section.
    func testSettingsShowsHelpAndSupportRow() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let helpText = app.staticTexts["Help & Support"]
        if !helpText.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(helpText.waitForExistence(timeout: 5), "'Help & Support' row not found in Settings")
    }

    // MARK: - Test: Settings Shows Send Feedback Row

    /// Verifies the Send Feedback row is visible in the Support section.
    func testSettingsShowsSendFeedbackRow() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let feedbackText = app.staticTexts["Send Feedback"]
        if !feedbackText.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(feedbackText.waitForExistence(timeout: 5), "'Send Feedback' row not found in Settings")
    }

    // MARK: - Test: Appearance Sheet Dismiss via Done

    /// Opens the Appearance sheet and dismisses it via Done, verifying Settings reappears.
    func testAppearanceSheetDismissViaDone() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 10), "Appearance row not found")
        appearanceRow.tap()

        // Verify sheet appeared
        let sheetTitle = app.staticTexts["Choose your preferred theme"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Theme sheet not found")

        // Dismiss via Done
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found")
        doneButton.tap()

        // Verify we're back on Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Settings should be visible after dismissing Appearance sheet")
    }

    // MARK: - Test: Units Sheet Dismiss via Done

    /// Opens the Units sheet and dismisses it via Done, verifying Settings reappears.
    func testUnitsSheetDismissViaDone() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.waitForExistence(timeout: 10), "Units row not found")
        unitsRow.tap()

        // Verify sheet appeared
        let sheetTitle = app.staticTexts["Choose your measurement system"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Units sheet not found")

        // Dismiss via Done
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found")
        doneButton.tap()

        // Verify we're back on Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Settings should be visible after dismissing Units sheet")
    }

    // MARK: - Test: Timezone Row Shows Current Timezone Value

    /// Verifies the Time Zone row displays a timezone value.
    func testTimezoneRowShowsValue() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        XCTAssertTrue(timezoneRow.waitForExistence(timeout: 10), "Time Zone row not found")

        // The timezone value should contain a "/" (e.g., "America/New_York", "Europe/Stockholm")
        let timezoneValue = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/'")).firstMatch
        XCTAssertTrue(timezoneValue.waitForExistence(timeout: 5), "No timezone value containing '/' found on Time Zone row")
    }

    // MARK: - Test: Units Row Shows Current Unit System

    /// Verifies the Units row displays either "Metric" or "Imperial".
    func testUnitsRowShowsCurrentSystem() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.waitForExistence(timeout: 10), "Units row not found")

        let metricLabel = app.staticTexts["Metric"]
        let imperialLabel = app.staticTexts["Imperial"]
        XCTAssertTrue(metricLabel.exists || imperialLabel.exists, "Units row should display 'Metric' or 'Imperial'")
    }
}

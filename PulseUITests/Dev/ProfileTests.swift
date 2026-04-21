//
//  ProfileTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

final class ProfileTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-auth"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Dismiss any leftover "Resume Workout?" alert.
    private func dismissResumeAlertIfPresent() {
        let resumeAlert = app.alerts["Resume Workout?"]
        if resumeAlert.waitForExistence(timeout: 5) {
            resumeAlert.buttons["Discard"].tap()
            sleep(1)
        }
    }

    /// Navigate to the Profile tab.
    private func navigateToProfile() {
        let profileTab = app.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15), "Profile tab not found")
        profileTab.tap()
        sleep(3)
    }

    /// Navigate to Settings from the Profile tab.
    private func navigateToSettings() {
        navigateToProfile()

        let settingsButton = app.buttons["profileSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button not found on Profile")
        settingsButton.tap()
        sleep(2)
    }

    // MARK: - Test: Profile Tab Shows Header

    /// Verifies the profile header is visible with the Edit Profile / Add Name button.
    func testProfileShowsHeader() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Profile / Add Name button not found")
    }

    // MARK: - Test: Profile Tab Shows Milestones Section

    /// Verifies the Milestones section header is visible on the profile.
    func testProfileShowsMilestonesSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let milestonesHeader = app.staticTexts["Milestones"]
        XCTAssertTrue(milestonesHeader.waitForExistence(timeout: 10), "'Milestones' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Custom Exercises Section

    /// Verifies the My Custom Exercises section is visible.
    func testProfileShowsCustomExercisesSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileCustomExercisesSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        let exercisesHeader = app.staticTexts["My Custom Exercises"]
        XCTAssertTrue(exercisesHeader.waitForExistence(timeout: 5), "'My Custom Exercises' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Completed Workouts Section

    /// Verifies the Completed Workouts section is visible.
    func testProfileShowsCompletedWorkoutsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileCompletedWorkoutsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }

        let workoutsHeader = app.staticTexts["Completed Workouts"]
        XCTAssertTrue(workoutsHeader.waitForExistence(timeout: 5), "'Completed Workouts' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Lifetime Stats Section

    /// Verifies the Lifetime Stats section is visible with all four stat cards.
    func testProfileShowsLifetimeStatsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileLifetimeStatsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
            if !section.waitForExistence(timeout: 3) {
                app.swipeUp()
                sleep(1)
            }
        }
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Lifetime Stats section not found")

        let lifetimeStatsHeader = app.staticTexts["Lifetime Stats"]
        XCTAssertTrue(lifetimeStatsHeader.exists, "'Lifetime Stats' header not found")

        let totalWorkouts = app.staticTexts["Total Workouts"]
        XCTAssertTrue(totalWorkouts.exists, "'Total Workouts' stat card not found")

        let totalVolume = app.staticTexts["Total Volume"]
        XCTAssertTrue(totalVolume.exists, "'Total Volume' stat card not found")

        let timeTrained = app.staticTexts["Time Trained"]
        XCTAssertTrue(timeTrained.exists, "'Time Trained' stat card not found")

        let longestStreak = app.staticTexts["Longest Streak"]
        XCTAssertTrue(longestStreak.exists, "'Longest Streak' stat card not found")
    }

    // MARK: - Test: Open Edit Profile Sheet

    /// Taps the Edit Profile button and verifies the Edit Profile sheet appears.
    func testOpenEditProfileSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Profile button not found")
        editButton.tap()
        sleep(2)

        let sheetTitle = app.staticTexts["Edit Profile"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Edit Profile sheet title not found")

        let subtitle = app.staticTexts["Manage your account details"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Sheet subtitle not found")

        // Verify First Name and Last Name rows
        let firstNameLabel = app.staticTexts["First Name"]
        XCTAssertTrue(firstNameLabel.waitForExistence(timeout: 5), "'First Name' label not found in Edit Profile sheet")

        let lastNameLabel = app.staticTexts["Last Name"]
        XCTAssertTrue(lastNameLabel.waitForExistence(timeout: 5), "'Last Name' label not found in Edit Profile sheet")

        // Verify Done button exists
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Edit Profile sheet")

        // Dismiss
        doneButton.tap()
        sleep(1)
    }

    // MARK: - Test: Edit First Name Flow

    /// Opens the Edit Profile sheet, taps the First Name row,
    /// and verifies the Edit First Name sheet appears.
    func testEditFirstNameSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Profile button not found")
        editButton.tap()
        sleep(2)

        // Tap the First Name row
        let firstNameRow = app.buttons["editFirstNameRow"]
        XCTAssertTrue(firstNameRow.waitForExistence(timeout: 5), "First Name row not found")
        firstNameRow.tap()
        sleep(2)

        // Verify the Edit First Name sheet appeared
        let editTitle = app.staticTexts["Edit First Name"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5), "Edit First Name sheet title not found")

        // Verify Save and Cancel buttons
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found on Edit First Name sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found")

        // Dismiss
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Edit Last Name Flow

    /// Opens the Edit Profile sheet, taps the Last Name row,
    /// and verifies the Edit Last Name sheet appears.
    func testEditLastNameSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Edit Profile button not found")
        editButton.tap()
        sleep(2)

        // Tap the Last Name row
        let lastNameRow = app.buttons["editLastNameRow"]
        XCTAssertTrue(lastNameRow.waitForExistence(timeout: 5), "Last Name row not found")
        lastNameRow.tap()
        sleep(2)

        // Verify the Edit Last Name sheet appeared
        let editTitle = app.staticTexts["Edit Last Name"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5), "Edit Last Name sheet title not found")

        // Verify Save and Cancel buttons
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button not found on Edit Last Name sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found")

        // Dismiss
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Navigate to Settings

    /// Taps the settings button on the Profile tab and verifies the Settings view appears.
    func testNavigateToSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Settings navigation title not found")

        // Verify key sections
        let subscriptionHeader = app.staticTexts["Subscription"]
        XCTAssertTrue(subscriptionHeader.waitForExistence(timeout: 5), "'Subscription' section not found")

        let generalHeader = app.staticTexts["General"]
        XCTAssertTrue(generalHeader.waitForExistence(timeout: 5), "'General' section not found")

        let supportHeader = app.staticTexts["Support"]
        XCTAssertTrue(supportHeader.waitForExistence(timeout: 5), "'Support' section not found")
    }

    // MARK: - Test: Settings Shows Subscription Plan

    /// Verifies the subscription plan row is visible and shows either "Pro" or "Free".
    func testSettingsShowsSubscriptionPlan() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "Plan button not found in Settings")

        let planText = app.staticTexts["Plan"]
        XCTAssertTrue(planText.exists, "'Plan' label not found")

        // Either "Pro" or "Free" should be shown
        let proLabel = app.staticTexts["Pro"]
        let freeLabel = app.staticTexts["Free"]
        XCTAssertTrue(proLabel.exists || freeLabel.exists, "Neither 'Pro' nor 'Free' plan label found")
    }

    // MARK: - Test: Settings Shows Appearance Row

    /// Verifies the Appearance row is visible and shows the current theme.
    func testSettingsShowsAppearanceRow() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 10), "Appearance row not found in Settings")

        let appearanceLabel = app.staticTexts["Appearance"]
        XCTAssertTrue(appearanceLabel.exists, "'Appearance' label not found")

        // The current theme value should be visible (System, Light, or Dark)
        let systemTheme = app.staticTexts["System"]
        let lightTheme = app.staticTexts["Light"]
        let darkTheme = app.staticTexts["Dark"]
        XCTAssertTrue(systemTheme.exists || lightTheme.exists || darkTheme.exists, "No theme value found on Appearance row")
    }

    // MARK: - Test: Open Appearance Sheet

    /// Taps the Appearance row and verifies the theme selection sheet appears.
    func testOpenAppearanceSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 10), "Appearance row not found")
        appearanceRow.tap()
        sleep(2)

        // Verify the sheet appeared (check subtitle to avoid ambiguity with settings row label)
        let subtitle = app.staticTexts["Choose your preferred theme"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Theme sheet subtitle not found")

        // Verify all three theme options are present (use buttons to avoid ambiguity with settings row values)
        let systemOption = app.buttons.matching(NSPredicate(format: "label == 'System'")).firstMatch
        XCTAssertTrue(systemOption.waitForExistence(timeout: 5), "'System' theme option not found")

        let lightOption = app.buttons.matching(NSPredicate(format: "label == 'Light'")).firstMatch
        XCTAssertTrue(lightOption.exists, "'Light' theme option not found")

        let darkOption = app.buttons.matching(NSPredicate(format: "label == 'Dark'")).firstMatch
        XCTAssertTrue(darkOption.exists, "'Dark' theme option not found")

        // Verify Done button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Appearance sheet")

        // Dismiss
        doneButton.tap()
        sleep(1)
    }

    // MARK: - Test: Open Units Sheet

    /// Taps the Units row and verifies the unit selection sheet appears.
    func testOpenUnitsSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.waitForExistence(timeout: 10), "Units row not found")
        unitsRow.tap()
        sleep(2)

        // Verify the sheet appeared (check subtitle to avoid ambiguity with settings row label)
        let subtitle = app.staticTexts["Choose your measurement system"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Units sheet subtitle not found")

        // Verify both unit system options are present (use buttons to avoid ambiguity with settings row values)
        let metricOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Metric'")).firstMatch
        XCTAssertTrue(metricOption.waitForExistence(timeout: 5), "'Metric' option not found")

        let imperialOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Imperial'")).firstMatch
        XCTAssertTrue(imperialOption.exists, "'Imperial' option not found")

        // Verify Done button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Units sheet")

        // Dismiss
        doneButton.tap()
        sleep(1)
    }

    // MARK: - Test: Open Timezone Sheet

    /// Taps the Time Zone row and verifies the timezone selection sheet appears.
    func testOpenTimezoneSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        XCTAssertTrue(timezoneRow.waitForExistence(timeout: 10), "Time Zone row not found")
        timezoneRow.tap()
        sleep(2)

        // Verify the sheet appeared with the navigation title
        let navTitle = app.navigationBars["Time Zone"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Time Zone sheet navigation title not found")

        // Verify sections
        // Section headers may be uppercased by the system, so search case-insensitively
        let currentSection = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Current'")).firstMatch
        XCTAssertTrue(currentSection.waitForExistence(timeout: 5), "'Current' section not found")

        let allTimezonesSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'time zone'")).firstMatch
        XCTAssertTrue(allTimezonesSection.waitForExistence(timeout: 5), "'All Time Zones' section not found")

        // Verify Done button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Timezone sheet")

        // Dismiss
        doneButton.tap()
        sleep(1)
    }

    // MARK: - Test: Open Feedback Sheet

    /// Taps the Send Feedback row and verifies the feedback sheet appears.
    func testOpenFeedbackSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll down to find the feedback row
        let feedbackRow = app.buttons["settingsFeedbackRow"]
        if !feedbackRow.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(feedbackRow.waitForExistence(timeout: 5), "Send Feedback row not found")
        feedbackRow.tap()
        sleep(2)

        // Verify the sheet appeared (check subtitle to avoid ambiguity with settings row label)
        let subtitle = app.staticTexts["Help us improve Pulse"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Feedback sheet subtitle not found")

        // Verify form fields
        let typeLabel = app.staticTexts["TYPE"]
        XCTAssertTrue(typeLabel.waitForExistence(timeout: 5), "'TYPE' label not found")

        let titleLabel = app.staticTexts["TITLE"]
        XCTAssertTrue(titleLabel.exists, "'TITLE' label not found")

        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.exists, "'DESCRIPTION' label not found")

        // Verify submit button exists
        let submitButton = app.buttons["Submit Feedback"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5), "Submit Feedback button not found")

        // Verify Cancel button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on Feedback sheet")

        // Dismiss
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Sign Out Alert Appears

    /// Taps the Sign Out button and verifies the confirmation alert appears.
    func testSignOutAlertAppears() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll down to find the Sign Out button
        let signOutButton = app.buttons["settingsSignOutButton"]
        if !signOutButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5), "Sign Out button not found")
        signOutButton.tap()
        sleep(1)

        // Verify the alert appeared
        let alert = app.alerts["Sign Out"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Sign Out confirmation alert not found")

        let alertMessage = app.staticTexts["Are you sure you want to sign out?"]
        XCTAssertTrue(alertMessage.exists, "Sign Out alert message not found")

        // Verify Cancel and Sign Out buttons in alert
        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Sign Out alert")

        let confirmButton = alert.buttons["Sign Out"]
        XCTAssertTrue(confirmButton.exists, "Sign Out button not found in alert")

        // Dismiss by cancelling
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Delete Account Alert Appears

    /// Taps the Delete Account button and verifies the confirmation alert appears.
    func testDeleteAccountAlertAppears() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll down to find the Delete Account button
        let deleteButton = app.buttons["settingsDeleteAccountButton"]
        if !deleteButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete Account button not found")
        deleteButton.tap()
        sleep(1)

        // Verify the alert appeared
        let alert = app.alerts["Delete Account"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete Account confirmation alert not found")

        let alertMessage = app.staticTexts["Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be removed."]
        XCTAssertTrue(alertMessage.exists, "Delete Account alert message not found")

        // Verify Cancel and Continue buttons in alert
        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Delete Account alert")

        let continueButton = alert.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button not found in Delete Account alert")

        // Dismiss by cancelling
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Delete Account Confirmation Sheet

    /// Taps Delete Account, confirms in the alert, and verifies the
    /// "type DELETE" confirmation sheet appears.
    func testDeleteAccountConfirmationSheetAppears() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll down to find the Delete Account button
        let deleteButton = app.buttons["settingsDeleteAccountButton"]
        if !deleteButton.waitForExistence(timeout: 5) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete Account button not found")
        deleteButton.tap()
        sleep(1)

        // Tap Continue on the first alert
        let alert = app.alerts["Delete Account"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete Account alert not found")
        alert.buttons["Continue"].tap()
        sleep(2)

        // Verify the confirmation sheet appeared
        let confirmTitle = app.staticTexts["This action is irreversible"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: 5), "Delete confirmation sheet title not found")

        let typeLabel = app.staticTexts["TYPE DELETE TO CONFIRM"]
        XCTAssertTrue(typeLabel.exists, "'TYPE DELETE TO CONFIRM' label not found")

        // Verify Cancel button on the confirmation sheet
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on delete confirmation sheet")

        // Dismiss
        cancelButton.tap()
        sleep(1)
    }

    // MARK: - Test: Settings Shows Version Info

    /// Verifies that version information is visible at the bottom of Settings.
    func testSettingsShowsVersionInfo() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll to the bottom
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        // Verify version text is present (matches "Version X.Y" or "Version X.Y (Build)")
        let versionText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Version'")).firstMatch
        XCTAssertTrue(versionText.waitForExistence(timeout: 5), "Version information not found at bottom of Settings")
    }

    // MARK: - Test: Settings Shows Terms and Privacy Links

    /// Verifies that Terms of Service and Privacy Policy links are visible in Settings.
    func testSettingsShowsTermsAndPrivacyLinks() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Scroll to the bottom
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        let termsButton = app.buttons["Terms of Service"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5), "'Terms of Service' link not found")

        let privacyButton = app.buttons["Privacy Policy"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5), "'Privacy Policy' link not found")
    }

    // MARK: - Test: Settings Shows General Options

    /// Verifies that Appearance, Units, and Time Zone rows are all visible in Settings.
    func testSettingsShowsGeneralOptions() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 10), "Appearance row not found")

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.exists, "Units row not found")

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        XCTAssertTrue(timezoneRow.exists, "Time Zone row not found")
    }

    // MARK: - Test: Navigate Back From Settings

    /// Navigates to Settings and back, verifying the Profile tab reappears.
    func testNavigateBackFromSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        // Verify we're in Settings
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Settings navigation title not found")

        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button not found in Settings")
        backButton.tap()
        sleep(2)

        // Verify we're back on the Profile tab
        let editButton = app.buttons["profileEditButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Profile view not visible after navigating back from Settings")
    }
}

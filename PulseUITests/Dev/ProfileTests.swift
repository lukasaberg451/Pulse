//
//  ProfileTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-22.
//

import XCTest

final class ProfileTests: UITestBaseCase {

    // MARK: - Test: Profile Tab Shows Header

    func testProfileShowsHeader() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        assertExists(editButton, "Edit Profile / Add Name button not found")
    }

    // MARK: - Test: Profile Tab Shows Milestones Section

    func testProfileShowsMilestonesSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let milestonesHeader = app.staticTexts["Milestones"]
        assertExists(milestonesHeader, "'Milestones' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Custom Exercises Section

    func testProfileShowsCustomExercisesSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileCustomExercisesSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        let exercisesHeader = app.staticTexts["My Custom Exercises"]
        assertExists(exercisesHeader, "'My Custom Exercises' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Completed Workouts Section

    func testProfileShowsCompletedWorkoutsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let section = app.otherElements["profileCompletedWorkoutsSection"]
        if !section.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }

        let workoutsHeader = app.staticTexts["Completed Workouts"]
        assertExists(workoutsHeader, "'Completed Workouts' section header not found")
    }

    // MARK: - Test: Profile Tab Shows Lifetime Stats Section

    func testProfileShowsLifetimeStatsSection() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        // Scroll to the bottom of the profile to find Lifetime Stats
        for _ in 0..<5 {
            let totalWorkouts = app.staticTexts["Total Workouts"]
            if totalWorkouts.exists { break }
            app.swipeUp()
            waitForAnimation()
        }

        let lifetimeStatsHeader = app.staticTexts["Lifetime Stats"]
        assertExists(lifetimeStatsHeader, "'Lifetime Stats' header not found")

        let totalWorkouts = app.staticTexts["Total Workouts"]
        assertExists(totalWorkouts, "'Total Workouts' stat card not found")

        let totalVolume = app.staticTexts["Total Volume"]
        assertExists(totalVolume, "'Total Volume' stat card not found")

        let timeTrained = app.staticTexts["Time Trained"]
        assertExists(timeTrained, "'Time Trained' stat card not found")

        let longestStreak = app.staticTexts["Longest Streak"]
        assertExists(longestStreak, "'Longest Streak' stat card not found")
    }

    // MARK: - Test: Open Edit Profile Sheet

    func testOpenEditProfileSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        assertExists(editButton, "Edit Profile button not found")
        editButton.tap()

        let sheetTitle = app.staticTexts["Edit Profile"]
        assertExists(sheetTitle, "Edit Profile sheet title not found")

        let subtitle = app.staticTexts["Manage your account details"]
        assertExists(subtitle, "Sheet subtitle not found")

        let firstNameLabel = app.staticTexts["First Name"]
        assertExists(firstNameLabel, "'First Name' label not found in Edit Profile sheet")

        let lastNameLabel = app.staticTexts["Last Name"]
        assertExists(lastNameLabel, "'Last Name' label not found in Edit Profile sheet")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Edit Profile sheet")

        doneButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Edit First Name Flow

    func testEditFirstNameSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        assertExists(editButton, "Edit Profile button not found")
        editButton.tap()

        let firstNameRow = app.buttons["editFirstNameRow"]
        assertExists(firstNameRow, "First Name row not found")
        firstNameRow.tap()

        let editTitle = app.staticTexts["Edit First Name"]
        assertExists(editTitle, "Edit First Name sheet title not found")

        let saveButton = app.buttons["Save"]
        assertExists(saveButton, "Save button not found on Edit First Name sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Edit Last Name Flow

    func testEditLastNameSheetOpens() throws {
        dismissResumeAlertIfPresent()
        navigateToProfile()

        let editButton = app.buttons["profileEditButton"]
        assertExists(editButton, "Edit Profile button not found")
        editButton.tap()

        let lastNameRow = app.buttons["editLastNameRow"]
        assertExists(lastNameRow, "Last Name row not found")
        lastNameRow.tap()

        let editTitle = app.staticTexts["Edit Last Name"]
        assertExists(editTitle, "Edit Last Name sheet title not found")

        let saveButton = app.buttons["Save"]
        assertExists(saveButton, "Save button not found on Edit Last Name sheet")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Navigate to Settings

    func testNavigateToSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let navTitle = app.navigationBars["Settings"]
        assertExists(navTitle, "Settings navigation title not found")

        let subscriptionHeader = app.staticTexts["Subscription"]
        assertExists(subscriptionHeader, "'Subscription' section not found")

        let generalHeader = app.staticTexts["General"]
        assertExists(generalHeader, "'General' section not found")

        let supportHeader = app.staticTexts["Support"]
        assertExists(supportHeader, "'Support' section not found")
    }

    // MARK: - Test: Settings Shows Subscription Plan

    func testSettingsShowsSubscriptionPlan() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let planButton = app.buttons["settingsPlanButton"]
        assertExists(planButton, "Plan button not found in Settings")

        let planText = app.staticTexts["Plan"]
        XCTAssertTrue(planText.exists, "'Plan' label not found")

        let proLabel = app.staticTexts["Pro"]
        let freeLabel = app.staticTexts["Free"]
        XCTAssertTrue(proLabel.exists || freeLabel.exists, "Neither 'Pro' nor 'Free' plan label found")
    }

    // MARK: - Test: Settings Shows Appearance Row

    func testSettingsShowsAppearanceRow() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        assertExists(appearanceRow, "Appearance row not found in Settings")

        let appearanceLabel = app.staticTexts["Appearance"]
        XCTAssertTrue(appearanceLabel.exists, "'Appearance' label not found")

        let systemTheme = app.staticTexts["System"]
        let lightTheme = app.staticTexts["Light"]
        let darkTheme = app.staticTexts["Dark"]
        XCTAssertTrue(systemTheme.exists || lightTheme.exists || darkTheme.exists, "No theme value found on Appearance row")
    }

    // MARK: - Test: Open Appearance Sheet

    func testOpenAppearanceSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        assertExists(appearanceRow, "Appearance row not found")
        appearanceRow.tap()

        let subtitle = app.staticTexts["Choose your preferred theme"]
        assertExists(subtitle, "Theme sheet subtitle not found")

        let systemOption = app.buttons.matching(NSPredicate(format: "label == 'System'")).firstMatch
        assertExists(systemOption, "'System' theme option not found")

        let lightOption = app.buttons.matching(NSPredicate(format: "label == 'Light'")).firstMatch
        XCTAssertTrue(lightOption.exists, "'Light' theme option not found")

        let darkOption = app.buttons.matching(NSPredicate(format: "label == 'Dark'")).firstMatch
        XCTAssertTrue(darkOption.exists, "'Dark' theme option not found")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Appearance sheet")

        doneButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Open Units Sheet

    func testOpenUnitsSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let unitsRow = app.buttons["settingsUnitsRow"]
        assertExists(unitsRow, "Units row not found")
        unitsRow.tap()

        let subtitle = app.staticTexts["Choose your measurement system"]
        assertExists(subtitle, "Units sheet subtitle not found")

        let metricOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Metric'")).firstMatch
        assertExists(metricOption, "'Metric' option not found")

        let imperialOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Imperial'")).firstMatch
        XCTAssertTrue(imperialOption.exists, "'Imperial' option not found")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Units sheet")

        doneButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Open Timezone Sheet

    func testOpenTimezoneSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        assertExists(timezoneRow, "Time Zone row not found")
        timezoneRow.tap()

        let navTitle = app.navigationBars["Time Zone"]
        assertExists(navTitle, "Time Zone sheet navigation title not found")

        let currentSection = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Current'")).firstMatch
        assertExists(currentSection, "'Current' section not found")

        let allTimezonesSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'time zone'")).firstMatch
        assertExists(allTimezonesSection, "'All Time Zones' section not found")

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists, "Done button not found on Timezone sheet")

        doneButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Open Feedback Sheet

    func testOpenFeedbackSheet() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let feedbackRow = app.buttons["settingsFeedbackRow"]
        if !feedbackRow.waitForExistence(timeout: 5) {
            app.swipeUp()
            waitForAnimation()
        }
        XCTAssertTrue(feedbackRow.waitForExistence(timeout: 5), "Send Feedback row not found")
        feedbackRow.tap()

        let subtitle = app.staticTexts["Help us improve Pulse"]
        assertExists(subtitle, "Feedback sheet subtitle not found")

        let typeLabel = app.staticTexts["TYPE"]
        assertExists(typeLabel, "'TYPE' label not found")

        let titleLabel = app.staticTexts["TITLE"]
        XCTAssertTrue(titleLabel.exists, "'TITLE' label not found")

        let descriptionLabel = app.staticTexts["DESCRIPTION"]
        XCTAssertTrue(descriptionLabel.exists, "'DESCRIPTION' label not found")

        let submitButton = app.buttons["Submit Feedback"]
        assertExists(submitButton, "Submit Feedback button not found")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on Feedback sheet")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Sign Out Alert Appears

    func testSignOutAlertAppears() throws {
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
        assertExists(alert, "Sign Out confirmation alert not found")

        let alertMessage = app.staticTexts["Are you sure you want to sign out?"]
        XCTAssertTrue(alertMessage.exists, "Sign Out alert message not found")

        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Sign Out alert")

        let confirmButton = alert.buttons["Sign Out"]
        XCTAssertTrue(confirmButton.exists, "Sign Out button not found in alert")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Delete Account Alert Appears

    func testDeleteAccountAlertAppears() throws {
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
        assertExists(alert, "Delete Account confirmation alert not found")

        let alertMessage = app.staticTexts["Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be removed."]
        XCTAssertTrue(alertMessage.exists, "Delete Account alert message not found")

        let cancelButton = alert.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found in Delete Account alert")

        let continueButton = alert.buttons["Continue"]
        XCTAssertTrue(continueButton.exists, "Continue button not found in Delete Account alert")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Delete Account Confirmation Sheet

    func testDeleteAccountConfirmationSheetAppears() throws {
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
        assertExists(alert, "Delete Account alert not found")
        alert.buttons["Continue"].tap()

        let confirmTitle = app.staticTexts["This action is irreversible"]
        assertExists(confirmTitle, "Delete confirmation sheet title not found")

        let typeLabel = app.staticTexts["TYPE DELETE TO CONFIRM"]
        XCTAssertTrue(typeLabel.exists, "'TYPE DELETE TO CONFIRM' label not found")

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button not found on delete confirmation sheet")

        cancelButton.tap()
        waitForAnimation()
    }

    // MARK: - Test: Settings Shows Version Info

    func testSettingsShowsVersionInfo() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        scrollToBottom()
        
        let versionText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Version'")).firstMatch
        assertExists(versionText, "Version information not found at bottom of Settings")
    }

    // MARK: - Test: Settings Shows Terms and Privacy Links

    func testSettingsShowsTermsAndPrivacyLinks() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        scrollToBottom()

        let termsButton = app.buttons["Terms of Service"]
        assertExists(termsButton, "'Terms of Service' link not found")

        let privacyButton = app.buttons["Privacy Policy"]
        assertExists(privacyButton, "'Privacy Policy' link not found")
    }

    // MARK: - Test: Settings Shows General Options

    func testSettingsShowsGeneralOptions() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let appearanceRow = app.buttons["settingsAppearanceRow"]
        assertExists(appearanceRow, "Appearance row not found")

        let unitsRow = app.buttons["settingsUnitsRow"]
        XCTAssertTrue(unitsRow.exists, "Units row not found")

        let timezoneRow = app.buttons["settingsTimezoneRow"]
        XCTAssertTrue(timezoneRow.exists, "Time Zone row not found")
    }

    // MARK: - Test: Navigate Back From Settings

    func testNavigateBackFromSettings() throws {
        dismissResumeAlertIfPresent()
        navigateToSettings()

        let navTitle = app.navigationBars["Settings"]
        assertExists(navTitle, "Settings navigation title not found")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        assertExists(backButton, "Back button not found in Settings")
        backButton.tap()

        let editButton = app.buttons["profileEditButton"]
        assertExists(editButton, "Profile view not visible after navigating back from Settings")
    }
}

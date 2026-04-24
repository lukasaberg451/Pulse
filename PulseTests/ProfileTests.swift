//
//  ProfileTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class ProfileTests: XCTestCase {

    private func makeProfile(
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        timezone: String? = nil,
        weeklyGoalMinutes: Int? = nil
    ) -> Profile {
        return Profile(
            id: UUID(),
            email: "test@test.com",
            firstName: "Test",
            lastName: "User",
            fullName: "Test User",
            weeklyGoalMinutes: weeklyGoalMinutes,
            createdAt: Date(),
            termsAcceptedAt: nil,
            weightKg: weightKg,
            heightCm: heightCm,
            timezone: timezone,
            unitSystem: "metric",
            targetWeightKg: nil
        )
    }

    // MARK: - BMI Calculation

    func testBmiCalculation() {
        let profile = makeProfile(weightKg: 80, heightCm: 180)
        // BMI = 80 / (1.8 * 1.8) = 24.69
        XCTAssertNotNil(profile.bmi)
        XCTAssertEqual(profile.bmi!, 24.69, accuracy: 0.01)
    }

    func testBmiNilWhenNoWeight() {
        let profile = makeProfile(weightKg: nil, heightCm: 180)
        XCTAssertNil(profile.bmi)
    }

    func testBmiNilWhenNoHeight() {
        let profile = makeProfile(weightKg: 80, heightCm: nil)
        XCTAssertNil(profile.bmi)
    }

    func testBmiNilWhenHeightZero() {
        let profile = makeProfile(weightKg: 80, heightCm: 0)
        XCTAssertNil(profile.bmi)
    }

    // MARK: - BMI Categories

    func testBmiCategoryUnderweight() {
        // BMI < 18.5: e.g. 50kg, 180cm -> BMI = 15.43
        let profile = makeProfile(weightKg: 50, heightCm: 180)
        XCTAssertEqual(profile.bmiCategory, "underweight")
        XCTAssertEqual(profile.bmiCategoryDisplayName, "Underweight")
    }

    func testBmiCategoryNormal() {
        // BMI 18.5-24.9: e.g. 70kg, 175cm -> BMI = 22.86
        let profile = makeProfile(weightKg: 70, heightCm: 175)
        XCTAssertEqual(profile.bmiCategory, "normal")
        XCTAssertEqual(profile.bmiCategoryDisplayName, "Normal")
    }

    func testBmiCategoryOverweight() {
        // BMI 25-29.9: e.g. 90kg, 175cm -> BMI = 29.39
        let profile = makeProfile(weightKg: 90, heightCm: 175)
        XCTAssertEqual(profile.bmiCategory, "overweight")
        XCTAssertEqual(profile.bmiCategoryDisplayName, "Overweight")
    }

    func testBmiCategoryObese() {
        // BMI >= 30: e.g. 120kg, 175cm -> BMI = 39.18
        let profile = makeProfile(weightKg: 120, heightCm: 175)
        XCTAssertEqual(profile.bmiCategory, "obese")
        XCTAssertEqual(profile.bmiCategoryDisplayName, "Obese")
    }

    func testBmiCategoryNilWhenNoBmi() {
        let profile = makeProfile(weightKg: nil, heightCm: nil)
        XCTAssertNil(profile.bmiCategory)
        XCTAssertNil(profile.bmiCategoryDisplayName)
    }

    // MARK: - Timezone & Calendar

    func testResolvedTimeZoneWithValidIdentifier() {
        let profile = makeProfile(timezone: "Europe/Stockholm")
        XCTAssertEqual(profile.resolvedTimeZone.identifier, "Europe/Stockholm")
    }

    func testResolvedTimeZoneFallsBackToCurrent() {
        let profile = makeProfile(timezone: nil)
        XCTAssertEqual(profile.resolvedTimeZone, TimeZone.current)
    }

    func testResolvedTimeZoneFallsBackForInvalidIdentifier() {
        let profile = makeProfile(timezone: "Invalid/Zone")
        XCTAssertEqual(profile.resolvedTimeZone, TimeZone.current)
    }

    func testUserCalendarUsesResolvedTimeZone() {
        let profile = makeProfile(timezone: "America/New_York")
        let cal = profile.userCalendar
        XCTAssertEqual(cal.timeZone.identifier, "America/New_York")
    }

    // MARK: - BMI Boundary Values

    func testBmiBoundaryAt18_5() {
        // Exactly 18.5: weight = 18.5 * (1.7^2) = 53.465 kg at 170 cm
        let profile = makeProfile(weightKg: 53.465, heightCm: 170)
        XCTAssertEqual(profile.bmiCategory, "normal") // 18.5 is in normal range
    }

    func testBmiBoundaryAt25() {
        // Exactly 25: weight = 25 * (1.7^2) = 72.25 kg at 170 cm
        let profile = makeProfile(weightKg: 72.25, heightCm: 170)
        XCTAssertEqual(profile.bmiCategory, "overweight") // 25 is in overweight range
    }

    func testBmiBoundaryAt30() {
        // Exactly 30: weight = 30 * (1.7^2) = 86.7 kg at 170 cm
        let profile = makeProfile(weightKg: 86.7, heightCm: 170)
        XCTAssertEqual(profile.bmiCategory, "obese") // 30 is in obese range
    }
}

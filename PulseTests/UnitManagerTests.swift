//
//  UnitManagerTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class UnitManagerTests: XCTestCase {

    // MARK: - Metric Mode

    func testMetricWeightUnit() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.weightUnit, "kg")
    }

    func testMetricHeightUnit() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.heightUnit, "cm")
    }

    func testMetricDisplayWeightPassthrough() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.displayWeight(100), 100)
    }

    func testMetricDisplayHeightPassthrough() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.displayHeight(180), 180)
    }

    func testMetricToKgPassthrough() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.toKg(80), 80)
    }

    func testMetricToCmPassthrough() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.toCm(180), 180)
    }

    func testMetricDisplayHeightFormatted() {
        let manager = UnitManager(unitSystem: .metric)
        XCTAssertEqual(manager.displayHeightFormatted(180), "180")
    }

    // MARK: - Imperial Mode

    func testImperialWeightUnit() {
        let manager = UnitManager(unitSystem: .imperial)
        XCTAssertEqual(manager.weightUnit, "lb")
    }

    func testImperialHeightUnit() {
        let manager = UnitManager(unitSystem: .imperial)
        XCTAssertEqual(manager.heightUnit, "ft")
    }

    func testImperialDisplayWeightConverts() {
        let manager = UnitManager(unitSystem: .imperial)
        let result = manager.displayWeight(100) // 100 kg -> ~220.462 lb
        XCTAssertEqual(result, 220.462, accuracy: 0.01)
    }

    func testImperialToKgConverts() {
        let manager = UnitManager(unitSystem: .imperial)
        let result = manager.toKg(220.462) // 220.462 lb -> ~100 kg
        XCTAssertEqual(result, 100, accuracy: 0.01)
    }

    func testImperialDisplayHeightFormatted() {
        let manager = UnitManager(unitSystem: .imperial)
        // 180 cm = ~70.87 inches = 5'11"
        let result = manager.displayHeightFormatted(180)
        XCTAssertEqual(result, "5'11\"")
    }

    func testImperialFeetFromCm() {
        let manager = UnitManager(unitSystem: .imperial)
        XCTAssertEqual(manager.feetFromCm(180), 5) // 70.87 inches / 12 = 5 feet
    }

    func testImperialInchesFromCm() {
        let manager = UnitManager(unitSystem: .imperial)
        XCTAssertEqual(manager.inchesFromCm(180), 11) // remainder ~11 inches
    }

    // MARK: - Round-trip Conversions

    func testWeightRoundTripMetric() {
        let manager = UnitManager(unitSystem: .metric)
        let original = 75.5
        let displayed = manager.displayWeight(original)
        let back = manager.toKg(displayed)
        XCTAssertEqual(back, original, accuracy: 0.001)
    }

    func testWeightRoundTripImperial() {
        let manager = UnitManager(unitSystem: .imperial)
        let original = 75.5
        let displayed = manager.displayWeight(original)
        let back = manager.toKg(displayed)
        XCTAssertEqual(back, original, accuracy: 0.001)
    }

    func testFeetInchesToCmRoundTrip() {
        let manager = UnitManager(unitSystem: .imperial)
        let cm = manager.toCmFromFeetInches(feet: 6, inches: 0) // 6'0" -> ~182.88 cm
        XCTAssertEqual(cm, 182.88, accuracy: 0.1)
    }

    // MARK: - UnitSystem Enum

    func testUnitSystemDisplayNames() {
        XCTAssertEqual(UnitSystem.metric.displayName, "Metric")
        XCTAssertEqual(UnitSystem.imperial.displayName, "Imperial")
    }

    func testUnitSystemSubtitles() {
        XCTAssertEqual(UnitSystem.metric.subtitle, "kg / cm")
        XCTAssertEqual(UnitSystem.imperial.subtitle, "lb / ft, in")
    }

    func testUnitSystemRawValues() {
        XCTAssertEqual(UnitSystem.metric.rawValue, "metric")
        XCTAssertEqual(UnitSystem.imperial.rawValue, "imperial")
    }
}

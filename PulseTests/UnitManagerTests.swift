//
//  UnitManagerTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class UnitManagerTests: XCTestCase {

    private var manager: UnitManager!

    override func setUp() {
        super.setUp()
        manager = UnitManager.shared
    }

    override func tearDown() {
        // Restore to metric after each test
        manager.unitSystem = .metric
        super.tearDown()
    }

    // MARK: - Metric Mode

    func testMetricWeightUnit() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.weightUnit, "kg")
    }

    func testMetricHeightUnit() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.heightUnit, "cm")
    }

    func testMetricDisplayWeightPassthrough() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.displayWeight(100), 100)
    }

    func testMetricDisplayHeightPassthrough() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.displayHeight(180), 180)
    }

    func testMetricToKgPassthrough() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.toKg(80), 80)
    }

    func testMetricToCmPassthrough() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.toCm(180), 180)
    }

    func testMetricDisplayHeightFormatted() {
        manager.unitSystem = .metric
        XCTAssertEqual(manager.displayHeightFormatted(180), "180")
    }

    // MARK: - Imperial Mode

    func testImperialWeightUnit() {
        manager.unitSystem = .imperial
        XCTAssertEqual(manager.weightUnit, "lb")
    }

    func testImperialHeightUnit() {
        manager.unitSystem = .imperial
        XCTAssertEqual(manager.heightUnit, "ft")
    }

    func testImperialDisplayWeightConverts() {
        manager.unitSystem = .imperial
        let result = manager.displayWeight(100) // 100 kg -> ~220.462 lb
        XCTAssertEqual(result, 220.462, accuracy: 0.01)
    }

    func testImperialToKgConverts() {
        manager.unitSystem = .imperial
        let result = manager.toKg(220.462) // 220.462 lb -> ~100 kg
        XCTAssertEqual(result, 100, accuracy: 0.01)
    }

    func testImperialDisplayHeightFormatted() {
        manager.unitSystem = .imperial
        // 180 cm = ~70.87 inches = 5'11"
        let result = manager.displayHeightFormatted(180)
        XCTAssertEqual(result, "5'11\"")
    }

    func testImperialFeetFromCm() {
        manager.unitSystem = .imperial
        XCTAssertEqual(manager.feetFromCm(180), 5) // 70.87 inches / 12 = 5 feet
    }

    func testImperialInchesFromCm() {
        manager.unitSystem = .imperial
        XCTAssertEqual(manager.inchesFromCm(180), 11) // remainder ~11 inches
    }

    // MARK: - Round-trip Conversions

    func testWeightRoundTripMetric() {
        manager.unitSystem = .metric
        let original = 75.5
        let displayed = manager.displayWeight(original)
        let back = manager.toKg(displayed)
        XCTAssertEqual(back, original, accuracy: 0.001)
    }

    func testWeightRoundTripImperial() {
        manager.unitSystem = .imperial
        let original = 75.5
        let displayed = manager.displayWeight(original)
        let back = manager.toKg(displayed)
        XCTAssertEqual(back, original, accuracy: 0.001)
    }

    func testFeetInchesToCmRoundTrip() {
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

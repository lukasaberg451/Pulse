//
//  InputSanitizationTests.swift
//  PulseTests
//

import XCTest
@testable import Pulse

final class InputSanitizationTests: XCTestCase {

    // MARK: - sanitizeInput

    func testPlainTextPassesThrough() {
        XCTAssertEqual(sanitizeInput("Hello World", maxLength: 50), "Hello World")
    }

    func testStripsEmoji() {
        XCTAssertEqual(sanitizeInput("Leg Day 🔥💪", maxLength: 50), "Leg Day ")
    }

    func testTruncatesToMaxLength() {
        let long = String(repeating: "a", count: 100)
        let result = sanitizeInput(long, maxLength: 20)
        XCTAssertEqual(result.count, 20)
    }

    func testStripsEmojiBeforeTruncating() {
        // "A😀B" -> strip emoji -> "AB" (length 2), maxLength 1 -> "A"
        let result = sanitizeInput("A😀B", maxLength: 1)
        XCTAssertEqual(result, "A")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(sanitizeInput("", maxLength: 10), "")
    }

    func testAllEmojiReturnsEmpty() {
        XCTAssertEqual(sanitizeInput("😀🎉🔥", maxLength: 50), "")
    }

    func testNumbersAndSymbolsPreserved() {
        XCTAssertEqual(sanitizeInput("100kg @ 5x5", maxLength: 50), "100kg @ 5x5")
    }

    func testMaxLengthZero() {
        XCTAssertEqual(sanitizeInput("Hello", maxLength: 0), "")
    }

    func testExactMaxLength() {
        XCTAssertEqual(sanitizeInput("Hello", maxLength: 5), "Hello")
    }

    // MARK: - Character.isEmoji

    func testVisualEmojiDetected() {
        XCTAssertTrue(Character("😀").isEmoji)
        XCTAssertTrue(Character("🔥").isEmoji)
        XCTAssertTrue(Character("💪").isEmoji)
    }

    func testPlainDigitsNotEmoji() {
        XCTAssertFalse(Character("5").isEmoji)
        XCTAssertFalse(Character("0").isEmoji)
    }

    func testPlainLettersNotEmoji() {
        XCTAssertFalse(Character("A").isEmoji)
        XCTAssertFalse(Character("z").isEmoji)
    }

    func testPunctuationNotEmoji() {
        XCTAssertFalse(Character("@").isEmoji)
        XCTAssertFalse(Character("#").isEmoji)
    }
}

//
//  SmokeTests.swift
//  PulseUITests
//
//  Created by Lukas Åberg on 2026-03-20.
//

import XCTest

final class SmokeTests: XCTestCase {

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
}

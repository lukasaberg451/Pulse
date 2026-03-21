//
//  TestSecrets.swift
//  PulseUITests
//

import Foundation

/// Reads key-value pairs from the Secrets.xcconfig file so UI tests
/// can reference credentials without hardcoding them.
enum TestSecrets {

    private static let values: [String: String] = {
        // #filePath resolves to the source location on the build machine.
        // Secrets.xcconfig lives at the project root (Pulse/).
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile
            .deletingLastPathComponent()  // PulseUITests/
            .deletingLastPathComponent()  // Pulse/ (workspace root)
        let url = projectRoot.appendingPathComponent("Secrets.xcconfig")

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Could not read Secrets.xcconfig at \(url.path)")
        }

        var dict: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("//") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            dict[key] = value
        }
        return dict
    }()

    static var uitestEmail: String {
        guard let value = values["UITEST_EMAIL"] else {
            fatalError("UITEST_EMAIL not found in Secrets.xcconfig")
        }
        return value
    }

    static var uitestPassword: String {
        guard let value = values["UITEST_PASSWORD"] else {
            fatalError("UITEST_PASSWORD not found in Secrets.xcconfig")
        }
        return value
    }
}

//
//  InputSanitization.swift
//  Pulse
//

import Foundation

/// Strips emoji characters and enforces a max length on the input string.
func sanitizeInput(_ value: String, maxLength: Int) -> String {
    let stripped = String(value.filter { !$0.isEmoji })
    if stripped.count > maxLength {
        return String(stripped.prefix(maxLength))
    }
    return stripped
}

extension Character {
    /// Returns true if the character is a visual emoji (not plain text digits/symbols).
    var isEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        // Multi-scalar characters that include emoji presentation or modifiers
        if unicodeScalars.count > 1 {
            return unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmojiModifier }
                || firstScalar.properties.isEmojiPresentation
        }
        // Single-scalar: only treat it as emoji if it defaults to emoji presentation
        return firstScalar.properties.isEmojiPresentation
    }
}

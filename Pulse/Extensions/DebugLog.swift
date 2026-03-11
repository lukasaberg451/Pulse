//
//  DebugLog.swift
//  Pulse
//

import Foundation

/// A debug-only logging function that compiles to a no-op in release builds.
/// Use this instead of `print()` to prevent leaking data in production.
@inline(__always)
nonisolated func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

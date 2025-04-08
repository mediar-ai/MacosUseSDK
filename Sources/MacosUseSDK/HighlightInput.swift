import Foundation
import CoreGraphics
import AppKit // For DispatchQueue, showVisualFeedback

// --- Public Functions Combining Input Simulation and Visualization ---

/// Simulates a left mouse click at the specified coordinates and shows visual feedback.
/// - Parameters:
///   - point: The `CGPoint` where the click should occur.
///   - duration: How long the visual feedback should last (in seconds). Default is 0.5s.
/// - Throws: `MacosUseSDKError` if simulation or visualization fails.
public func clickMouseAndVisualize(at point: CGPoint, duration: Double = 0.5) throws {
    fputs("log: simulating left click AND visualize at: (\(point.x), \(point.y)), duration: \(duration)s\n", stderr)
    // Call the original input function
    try clickMouse(at: point)
    // Schedule visualization on the main thread using function from DrawBoxes.swift
    DispatchQueue.main.async {
        // Note: showVisualFeedback requires @MainActor, but calling it within
        // DispatchQueue.main.async satisfies this requirement.
        showVisualFeedback(at: point, type: .circle, duration: duration)
    }
    fputs("log: left click simulation and visualization dispatched.\n", stderr)
}

/// Simulates a left mouse double click at the specified coordinates and shows visual feedback.
/// - Parameters:
///   - point: The `CGPoint` where the double click should occur.
///   - duration: How long the visual feedback should last (in seconds). Default is 0.5s.
/// - Throws: `MacosUseSDKError` if simulation or visualization fails.
public func doubleClickMouseAndVisualize(at point: CGPoint, duration: Double = 0.5) throws {
    fputs("log: simulating double-click AND visualize at: (\(point.x), \(point.y)), duration: \(duration)s\n", stderr)
    // Call the original input function
    try doubleClickMouse(at: point)
    // Schedule visualization on the main thread
    DispatchQueue.main.async {
        showVisualFeedback(at: point, type: .circle, duration: duration)
    }
    fputs("log: double-click simulation and visualization dispatched.\n", stderr)
}

/// Simulates a right mouse click at the specified coordinates and shows visual feedback.
/// - Parameters:
///   - point: The `CGPoint` where the right click should occur.
///   - duration: How long the visual feedback should last (in seconds). Default is 0.5s.
/// - Throws: `MacosUseSDKError` if simulation or visualization fails.
public func rightClickMouseAndVisualize(at point: CGPoint, duration: Double = 0.5) throws {
     fputs("log: simulating right-click AND visualize at: (\(point.x), \(point.y)), duration: \(duration)s\n", stderr)
     // Call the original input function
    try rightClickMouse(at: point)
    // Schedule visualization on the main thread
    DispatchQueue.main.async {
        showVisualFeedback(at: point, type: .circle, duration: duration)
    }
     fputs("log: right-click simulation and visualization dispatched.\n", stderr)
}

/// Moves the mouse cursor to the specified coordinates and shows brief visual feedback at the destination.
/// - Parameters:
///   - point: The `CGPoint` to move the cursor to.
///   - duration: How long the visual feedback should last (in seconds). Default is 0.5s.
/// - Throws: `MacosUseSDKError` if simulation or visualization fails.
public func moveMouseAndVisualize(to point: CGPoint, duration: Double = 0.5) throws {
     fputs("log: moving mouse AND visualize to: (\(point.x), \(point.y)), duration: \(duration)s\n", stderr)
     // Call the original input function
    try moveMouse(to: point)
    // Schedule visualization on the main thread
    DispatchQueue.main.async {
        showVisualFeedback(at: point, type: .circle, duration: duration)
    }
     fputs("log: mouse move simulation and visualization dispatched.\n", stderr)
}

/// Simulates pressing and releasing a key with optional modifiers. (Visualization NOT YET IMPLEMENTED)
/// - Parameters:
///   - keyCode: The `CGKeyCode` of the key to press.
///   - flags: The modifier flags (`CGEventFlags`).
///   - duration: How long the visual feedback *would* last (currently ignored).
/// - Throws: `MacosUseSDKError` if simulation fails.
public func pressKeyAndVisualize(keyCode: CGKeyCode, flags: CGEventFlags = [], duration: Double = 0.5) throws {
    fputs("log: simulating key press AND visualize (VISUALIZATION SKIPPED): (code: \(keyCode), flags: \(flags.rawValue)), duration: \(duration)s\n", stderr)
    // Call the original input function
    try pressKey(keyCode: keyCode, flags: flags)
    // TODO: Implement visualization for key presses (challenging to get location)
    fputs("log: key press simulation complete (visualization skipped).\n", stderr)
}

/// Simulates typing a string of text. (Visualization NOT YET IMPLEMENTED)
/// - Parameters:
///   - text: The `String` to type.
///   - duration: How long the visual feedback *would* last (currently ignored).
/// - Throws: `MacosUseSDKError` if simulation fails.
public func writeTextAndVisualize(_ text: String, duration: Double = 0.5) throws {
    fputs("log: simulating text writing AND visualize (VISUALIZATION SKIPPED): \"\(text)\", duration: \(duration)s\n", stderr)
    // Call the original input function
    try writeText(text)
    // TODO: Implement visualization for text writing (challenging to get location)
    fputs("log: text writing simulation complete (visualization skipped).\n", stderr)
}

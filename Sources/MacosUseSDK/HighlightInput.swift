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

    // Restore the correct async dispatch:
    DispatchQueue.main.async {
        Task { @MainActor in
            // Ensure FeedbackType is used if it's public/internal enum
            showVisualFeedback(at: point, type: FeedbackType.circle, duration: duration)
        }
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
        Task { @MainActor in
             showVisualFeedback(at: point, type: FeedbackType.circle, duration: duration)
        }
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
        Task { @MainActor in
            showVisualFeedback(at: point, type: FeedbackType.circle, duration: duration)
        }
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
         Task { @MainActor in
            showVisualFeedback(at: point, type: FeedbackType.circle, duration: duration)
         }
    }
     fputs("log: mouse move simulation and visualization dispatched.\n", stderr)
}

/// Simulates pressing and releasing a key with optional modifiers. Shows a caption at screen center.
/// - Parameters:
///   - keyCode: The `CGKeyCode` of the key to press.
///   - flags: The modifier flags (`CGEventFlags`).
///   - duration: How long the visual feedback should last (in seconds). Default is 0.8s.
/// - Throws: `MacosUseSDKError` if simulation fails.
public func pressKeyAndVisualize(keyCode: CGKeyCode, flags: CGEventFlags = [], duration: Double = 0.8) throws {
    // Define caption constants
    let captionText = "[KEY PRESS]"
    let captionSize = CGSize(width: 250, height: 80) // Size for the key press caption

    fputs("log: simulating key press (code: \(keyCode), flags: \(flags.rawValue)) AND visualizing caption '\(captionText)', duration: \(duration)s\n", stderr)
    // Call the original input function first
    try pressKey(keyCode: keyCode, flags: flags)

    // Always dispatch caption visualization to the main thread at screen center
    DispatchQueue.main.async {
        Task { @MainActor in
            // Get screen center for caption placement
            if let screenCenter = getMainScreenCenter() {
                fputs("log: [Main Thread] Displaying key press caption at screen center: \(screenCenter).\n", stderr)
                // Show the caption feedback
                showVisualFeedback(
                    at: screenCenter,
                    type: .caption(text: captionText),
                    size: captionSize,
                    duration: duration
                )
            } else {
                fputs("warning: [Main Thread] could not get main screen center for key press caption visualization.\n", stderr)
            }
        }
    }
    fputs("log: key press simulation complete, caption visualization dispatched.\n", stderr)
}

/// Simulates typing a string of text. Shows a caption of the text at screen center.
/// - Parameters:
///   - text: The `String` to type.
///   - duration: How long the visual feedback should last (in seconds). Default is calculated or 1.0s min.
/// - Throws: `MacosUseSDKError` if simulation fails.
public func writeTextAndVisualize(_ text: String, duration: Double? = nil) throws {
    // Define caption constants
    let defaultDuration = 1.0 // Minimum duration
    // Optional: Calculate duration based on text length, e.g., 0.5s + 0.05s per char
    let calculatedDuration = max(defaultDuration, 0.5 + Double(text.count) * 0.05)
    let finalDuration = duration ?? calculatedDuration
    let captionSize = CGSize(width: 450, height: 100) // Adjust size as needed, maybe make dynamic later

    fputs("log: simulating text writing AND visualizing caption: \"\(text)\", duration: \(finalDuration)s\n", stderr)
    // Call the original input function first
    try writeText(text)

    // Always dispatch caption visualization to the main thread at screen center
    DispatchQueue.main.async {
        Task { @MainActor in
            // Get screen center for caption placement
            if let screenCenter = getMainScreenCenter() {
                 fputs("log: [Main Thread] Displaying text writing caption at screen center: \(screenCenter).\n", stderr)
                 // Show the caption feedback with the typed text
                 showVisualFeedback(
                     at: screenCenter,
                     type: .caption(text: text), // Pass the actual text here
                     size: captionSize,
                     duration: finalDuration
                 )
            } else {
                fputs("warning: [Main Thread] could not get main screen center for text writing caption visualization.\n", stderr)
            }
        }
    }
     fputs("log: text writing simulation complete, caption visualization dispatched.\n", stderr)
}

// --- Helper Function to Get Main Screen Center ---
// REMOVED: Entire fileprivate getMainScreenCenter() function definition.
// The internal version in DrawVisuals.swift will be used instead.

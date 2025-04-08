import Foundation // Needed for fputs, etc.
import CoreGraphics // Needed for CGPoint, CGKeyCode, CGEventFlags

/// Represents the difference between two accessibility traversals.
/// Currently focuses on elements added or removed. Detecting modifications
/// to existing elements is complex without stable identifiers.
public struct TraversalDiff: Codable {
    public let added: [ElementData]
    public let removed: [ElementData]
    // Future potential: public let modified: [ (before: ElementData, after: ElementData) ]
}

/// Holds the results of an action performed between two accessibility traversals,
/// including the state before, the state after, and the calculated difference.
public struct ActionDiffResult: Codable {
    public let afterAction: ResponseData
    public let diff: TraversalDiff
}

/// Defines combined, higher-level actions using the SDK's core functionalities.
public enum CombinedActions {

    /// Opens or activates an application and then immediately traverses its accessibility tree.
    ///
    /// This combines the functionality of `openApplication` and `traverseAccessibilityTree`.
    /// Logs detailed steps to stderr.
    ///
    /// - Parameters:
    ///   - identifier: The application name (e.g., "Calculator"), bundle ID (e.g., "com.apple.calculator"), or full path (e.g., "/System/Applications/Calculator.app").
    ///   - onlyVisibleElements: If true, the traversal only collects elements with valid position and size. Defaults to false.
    /// - Returns: A `ResponseData` struct containing the collected elements, statistics, and timing information from the traversal.
    /// - Throws: `MacosUseSDKError` if either the application opening/activation or the accessibility traversal fails.
    @MainActor // Ensures UI-related parts like activation happen on the main thread
    public static func openAndTraverseApp(identifier: String, onlyVisibleElements: Bool = false) async throws -> ResponseData {
        fputs("info: starting combined action 'openAndTraverseApp' for identifier: '\(identifier)'\n", stderr)

        // Step 1: Open or Activate the Application
        fputs("info: calling openApplication...\n", stderr)
        let openResult = try await MacosUseSDK.openApplication(identifier: identifier)
        fputs("info: openApplication completed successfully. PID: \(openResult.pid), App Name: \(openResult.appName)\n", stderr)

        // Step 2: Traverse the Accessibility Tree of the opened/activated application
        fputs("info: calling traverseAccessibilityTree for PID \(openResult.pid) (Visible Only: \(onlyVisibleElements))...\n", stderr)
        let traversalResult = try MacosUseSDK.traverseAccessibilityTree(pid: openResult.pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traverseAccessibilityTree completed successfully.\n", stderr)

        // Step 3: Return the traversal result
        fputs("info: combined action 'openAndTraverseApp' finished.\n", stderr)
        return traversalResult
    }

    // --- Input Action followed by Traversal ---

    /// Simulates a left mouse click at the specified coordinates, then traverses the accessibility tree of the target application.
    ///
    /// - Parameters:
    ///   - point: The `CGPoint` where the click should occur (screen coordinates).
    ///   - pid: The Process ID (PID) of the application to traverse after the click.
    ///   - onlyVisibleElements: If true, the traversal only collects elements with valid position and size. Defaults to false.
    /// - Returns: A `ResponseData` struct containing the collected elements, statistics, and timing information from the traversal.
    /// - Throws: `MacosUseSDKError` if the click simulation or the accessibility traversal fails.
    @MainActor // Added for consistency, although core CGEvent might not strictly require it
    public static func clickAndTraverseApp(point: CGPoint, pid: Int32, onlyVisibleElements: Bool = false) async throws -> ResponseData {
        fputs("info: starting combined action 'clickAndTraverseApp' at (\(point.x), \(point.y)) for PID \(pid)\n", stderr)

        // Step 1: Perform the click
        fputs("info: calling clickMouse...\n", stderr)
        try MacosUseSDK.clickMouse(at: point)
        fputs("info: clickMouse completed successfully.\n", stderr)

        // Add a small delay to allow UI to potentially update after the click
        try await Task.sleep(nanoseconds: 100_000_000) // 100 milliseconds

        // Step 2: Traverse the Accessibility Tree
        fputs("info: calling traverseAccessibilityTree for PID \(pid) (Visible Only: \(onlyVisibleElements))...\n", stderr)
        let traversalResult = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traverseAccessibilityTree completed successfully.\n", stderr)

        // Step 3: Return the traversal result
        fputs("info: combined action 'clickAndTraverseApp' finished.\n", stderr)
        return traversalResult
    }

    /// Simulates pressing a key with optional modifiers, then traverses the accessibility tree of the target application.
    ///
    /// - Parameters:
    ///   - keyCode: The `CGKeyCode` of the key to press.
    ///   - flags: The modifier flags (`CGEventFlags`) to apply.
    ///   - pid: The Process ID (PID) of the application to traverse after the key press.
    ///   - onlyVisibleElements: If true, the traversal only collects elements with valid position and size. Defaults to false.
    /// - Returns: A `ResponseData` struct containing the collected elements, statistics, and timing information from the traversal.
    /// - Throws: `MacosUseSDKError` if the key press simulation or the accessibility traversal fails.
    @MainActor
    public static func pressKeyAndTraverseApp(keyCode: CGKeyCode, flags: CGEventFlags = [], pid: Int32, onlyVisibleElements: Bool = false) async throws -> ResponseData {
         fputs("info: starting combined action 'pressKeyAndTraverseApp' (key: \(keyCode), flags: \(flags.rawValue)) for PID \(pid)\n", stderr)

         // Step 1: Perform the key press
         fputs("info: calling pressKey...\n", stderr)
         try MacosUseSDK.pressKey(keyCode: keyCode, flags: flags)
         fputs("info: pressKey completed successfully.\n", stderr)

         // Add a small delay
         try await Task.sleep(nanoseconds: 100_000_000) // 100 milliseconds

         // Step 2: Traverse the Accessibility Tree
         fputs("info: calling traverseAccessibilityTree for PID \(pid) (Visible Only: \(onlyVisibleElements))...\n", stderr)
         let traversalResult = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
         fputs("info: traverseAccessibilityTree completed successfully.\n", stderr)

         // Step 3: Return the traversal result
         fputs("info: combined action 'pressKeyAndTraverseApp' finished.\n", stderr)
         return traversalResult
    }

    /// Simulates typing text, then traverses the accessibility tree of the target application.
    ///
    /// - Parameters:
    ///   - text: The `String` to type.
    ///   - pid: The Process ID (PID) of the application to traverse after typing the text.
    ///   - onlyVisibleElements: If true, the traversal only collects elements with valid position and size. Defaults to false.
    /// - Returns: A `ResponseData` struct containing the collected elements, statistics, and timing information from the traversal.
    /// - Throws: `MacosUseSDKError` if the text writing simulation or the accessibility traversal fails.
    @MainActor
    public static func writeTextAndTraverseApp(text: String, pid: Int32, onlyVisibleElements: Bool = false) async throws -> ResponseData {
        fputs("info: starting combined action 'writeTextAndTraverseApp' (text: \"\(text)\") for PID \(pid)\n", stderr)

        // Step 1: Perform the text writing
        fputs("info: calling writeText...\n", stderr)
        try MacosUseSDK.writeText(text)
        fputs("info: writeText completed successfully.\n", stderr)

        // Add a small delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100 milliseconds

        // Step 2: Traverse the Accessibility Tree
        fputs("info: calling traverseAccessibilityTree for PID \(pid) (Visible Only: \(onlyVisibleElements))...\n", stderr)
        let traversalResult = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traverseAccessibilityTree completed successfully.\n", stderr)

        // Step 3: Return the traversal result
        fputs("info: combined action 'writeTextAndTraverseApp' finished.\n", stderr)
        return traversalResult
    }

     // You can add similar functions for doubleClick, rightClick, moveMouse etc. if needed

    // --- Helper Function for Diffing ---

    /// Calculates the difference between two sets of ElementData based on set operations.
    /// - Parameters:
    ///   - beforeElements: The list of elements from the first traversal.
    ///   - afterElements: The list of elements from the second traversal.
    /// - Returns: A `TraversalDiff` struct containing added and removed elements.
    private static func calculateDiff(beforeElements: [ElementData], afterElements: [ElementData]) -> TraversalDiff {
        fputs("debug: calculating diff between \(beforeElements.count) (before) and \(afterElements.count) (after) elements.\n", stderr)
        // Convert arrays to Sets for efficient comparison. Relies on ElementData being Hashable.
        let beforeSet = Set(beforeElements)
        let afterSet = Set(afterElements)

        // Elements present in 'after' but not in 'before' are added.
        let addedElements = Array(afterSet.subtracting(beforeSet))
        fputs("debug: diff calculation - found \(addedElements.count) added elements.\n", stderr)

        // Elements present in 'before' but not in 'after' are removed.
        let removedElements = Array(beforeSet.subtracting(afterSet))
        fputs("debug: diff calculation - found \(removedElements.count) removed elements.\n", stderr)

        // Sort results for consistent output (optional, but helpful)
        let sortedAdded = addedElements.sorted(by: elementSortPredicate)
        let sortedRemoved = removedElements.sorted(by: elementSortPredicate)


        return TraversalDiff(added: sortedAdded, removed: sortedRemoved)
    }

    // Helper sorting predicate (consistent with AccessibilityTraversalOperation)
    private static var elementSortPredicate: (ElementData, ElementData) -> Bool {
        return { e1, e2 in
            let y1 = e1.y ?? Double.greatestFiniteMagnitude
            let y2 = e2.y ?? Double.greatestFiniteMagnitude
            if y1 != y2 { return y1 < y2 }
            let x1 = e1.x ?? Double.greatestFiniteMagnitude
            let x2 = e2.x ?? Double.greatestFiniteMagnitude
            return x1 < x2
        }
    }


    // --- Combined Actions with Diffing ---

    /// Performs a left mouse click, bracketed by accessibility traversals, and returns the diff.
    ///
    /// - Parameters:
    ///   - point: The `CGPoint` where the click should occur (screen coordinates).
    ///   - pid: The Process ID (PID) of the application to traverse.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Defaults to false.
    ///   - delayAfterActionNano: Nanoseconds to wait after the action before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing traversals before/after the click and the diff.
    /// - Throws: `MacosUseSDKError` if any step (traversal, click) fails.
    @MainActor
    public static func clickWithDiff(
        point: CGPoint,
        pid: Int32,
        onlyVisibleElements: Bool = false,
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
        fputs("info: starting combined action 'clickWithDiff' at (\(point.x), \(point.y)) for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2: Perform the Click
        fputs("info: calling clickMouse...\n", stderr)
        try MacosUseSDK.clickMouse(at: point)
        fputs("info: clickMouse completed successfully.\n", stderr)

        // Step 3: Wait for UI to Update
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Prepare and Return Result
        let result = ActionDiffResult(
            afterAction: afterTraversal,
            diff: diff
        )
        fputs("info: combined action 'clickWithDiff' finished.\n", stderr)
        return result
    }

    /// Presses a key, bracketed by accessibility traversals, and returns the diff.
    ///
    /// - Parameters:
    ///   - keyCode: The `CGKeyCode` of the key to press.
    ///   - flags: The modifier flags (`CGEventFlags`).
    ///   - pid: The Process ID (PID) of the application to traverse.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Defaults to false.
    ///   - delayAfterActionNano: Nanoseconds to wait after the action before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing traversals before/after the key press and the diff.
    /// - Throws: `MacosUseSDKError` if any step fails.
    @MainActor
    public static func pressKeyWithDiff(
        keyCode: CGKeyCode,
        flags: CGEventFlags = [],
        pid: Int32,
        onlyVisibleElements: Bool = false,
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
         fputs("info: starting combined action 'pressKeyWithDiff' (key: \(keyCode), flags: \(flags.rawValue)) for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2: Perform the Key Press
        fputs("info: calling pressKey...\n", stderr)
        try MacosUseSDK.pressKey(keyCode: keyCode, flags: flags)
        fputs("info: pressKey completed successfully.\n", stderr)

        // Step 3: Wait for UI to Update
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Prepare and Return Result
        let result = ActionDiffResult(
            afterAction: afterTraversal,
            diff: diff
        )
         fputs("info: combined action 'pressKeyWithDiff' finished.\n", stderr)
        return result
    }

    /// Types text, bracketed by accessibility traversals, and returns the diff.
    ///
    /// - Parameters:
    ///   - text: The `String` to type.
    ///   - pid: The Process ID (PID) of the application to traverse.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Defaults to false.
    ///   - delayAfterActionNano: Nanoseconds to wait after the action before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing traversals before/after typing and the diff.
    /// - Throws: `MacosUseSDKError` if any step fails.
    @MainActor
    public static func writeTextWithDiff(
        text: String,
        pid: Int32,
        onlyVisibleElements: Bool = false,
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
         fputs("info: starting combined action 'writeTextWithDiff' (text: \"\(text)\") for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2: Perform the Text Writing
        fputs("info: calling writeText...\n", stderr)
        try MacosUseSDK.writeText(text)
        fputs("info: writeText completed successfully.\n", stderr)

        // Step 3: Wait for UI to Update
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Prepare and Return Result
        let result = ActionDiffResult(
            afterAction: afterTraversal,
            diff: diff
        )
         fputs("info: combined action 'writeTextWithDiff' finished.\n", stderr)
        return result
    }

     // Add similar '...WithDiff' functions for doubleClick, rightClick, etc. as needed


    // --- NEW: Combined Actions with Action Visualization AND Traversal Highlighting ---

    /// Performs a left click with visual feedback, bracketed by traversals (before action, after action),
    /// highlights the elements from the second traversal, and returns the diff.
    ///
    /// - Parameters:
    ///   - point: The `CGPoint` where the click should occur.
    ///   - pid: The Process ID (PID) of the application.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Default false.
    ///   - actionHighlightDuration: Duration (seconds) for the click's visual feedback pulse. Default 0.5s.
    ///   - traversalHighlightDuration: Duration (seconds) for highlighting elements found in the second traversal. Default 3.0s.
    ///   - delayAfterActionNano: Nanoseconds to wait after the click before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing the second traversal's data and the diff.
    /// - Throws: `MacosUseSDKError` if any step fails.
    @MainActor
    public static func clickWithActionAndTraversalHighlight(
        point: CGPoint,
        pid: Int32,
        onlyVisibleElements: Bool = false,
        actionHighlightDuration: Double = 0.5, // Duration for the click pulse
        traversalHighlightDuration: Double = 3.0, // Duration for highlighting elements
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
        fputs("info: starting combined action 'clickWithActionAndTraversalHighlight' at (\(point.x), \(point.y)) for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2a: Perform the Click (Input Simulation Only)
        fputs("info: calling clickMouse...\n", stderr)
        try MacosUseSDK.clickMouse(at: point)
        fputs("info: clickMouse completed successfully.\n", stderr)

        // Step 2b: Dispatch Click Visualization
        fputs("info: dispatching showVisualFeedback for click (duration: \(actionHighlightDuration)s)...\n", stderr)
        // Use Task to ensure it runs on MainActor, respecting showVisualFeedback's requirement
        Task { @MainActor in
            MacosUseSDK.showVisualFeedback(at: point, type: .circle, duration: actionHighlightDuration)
        }
        fputs("info: showVisualFeedback for click dispatched.\n", stderr)


        // Step 3: Wait for UI to Update (after action, before second traversal)
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action (Standard Traversal)
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff using data from the two traversals
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Dispatch Highlighting of the "After" Elements
        fputs("info: calling drawHighlightBoxes (duration: \(traversalHighlightDuration)s) for afterTraversal elements...\n", stderr)
        // This call returns immediately after dispatching the UI work.
        // It uses the @MainActor function drawHighlightBoxes.
        drawHighlightBoxes(for: afterTraversal.elements, duration: traversalHighlightDuration)
        fputs("info: drawHighlightBoxes dispatched highlight drawing.\n", stderr)

        // Step 7: Prepare and Return Result (using data from the *second* traversal)
        let result = ActionDiffResult(
            afterAction: afterTraversal, // Contains data from the second traversal
            diff: diff
        )
        fputs("info: combined action 'clickWithActionAndTraversalHighlight' finished returning result.\n", stderr)
        // IMPORTANT: Highlighting cleanup happens asynchronously later.
        return result
    }


    /// Presses a key with visual feedback (caption), bracketed by traversals (before action, after action),
    /// highlights the elements from the second traversal, and returns the diff.
    ///
    /// - Parameters:
    ///   - keyCode: The `CGKeyCode` of the key to press.
    ///   - flags: The modifier flags (`CGEventFlags`).
    ///   - pid: The Process ID (PID) of the application.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Default false.
    ///   - actionHighlightDuration: Duration (seconds) for the key press visual feedback caption. Default 0.8s.
    ///   - traversalHighlightDuration: Duration (seconds) for highlighting elements found in the second traversal. Default 3.0s.
    ///   - delayAfterActionNano: Nanoseconds to wait after the key press before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing the second traversal's data and the diff.
    /// - Throws: `MacosUseSDKError` if any step fails.
    @MainActor
    public static func pressKeyWithActionAndTraversalHighlight(
        keyCode: CGKeyCode,
        flags: CGEventFlags = [],
        pid: Int32,
        onlyVisibleElements: Bool = false,
        actionHighlightDuration: Double = 0.8, // Duration for visualization caption
        traversalHighlightDuration: Double = 3.0, // Duration for highlighting elements
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
         fputs("info: starting combined action 'pressKeyWithActionAndTraversalHighlight' (key: \(keyCode), flags: \(flags.rawValue)) for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2a: Perform the Key Press (Input Simulation Only)
        fputs("info: calling pressKey (key: \(keyCode), flags: \(flags.rawValue))...\n", stderr)
        try MacosUseSDK.pressKey(keyCode: keyCode, flags: flags)
        fputs("info: pressKey completed successfully.\n", stderr)

        // Step 2b: Dispatch Key Press Visualization (Caption)
        let captionText = "[KEY PRESS]"
        let captionSize = CGSize(width: 250, height: 80) // Keep caption size definition here or centralize
        fputs("info: dispatching showVisualFeedback for key press (duration: \(actionHighlightDuration)s)...\n", stderr)
        Task { @MainActor in
            // Use the internal top-level function directly
            if let screenCenter = getMainScreenCenter() {
                MacosUseSDK.showVisualFeedback(
                    at: screenCenter,
                    type: .caption(text: captionText),
                    size: captionSize,
                    duration: actionHighlightDuration
                )
            } else {
                 fputs("warning: [\(#function)] could not get screen center for key press caption.\n", stderr)
            }
        }
        fputs("info: showVisualFeedback for key press dispatched.\n", stderr)


        // Step 3: Wait for UI to Update
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Dispatch Highlighting of the "After" Elements
        fputs("info: calling drawHighlightBoxes (duration: \(traversalHighlightDuration)s) for afterTraversal elements...\n", stderr)
        drawHighlightBoxes(for: afterTraversal.elements, duration: traversalHighlightDuration)
        fputs("info: drawHighlightBoxes dispatched highlight drawing.\n", stderr)


        // Step 7: Prepare and Return Result
        let result = ActionDiffResult(
            afterAction: afterTraversal,
            diff: diff
        )
         fputs("info: combined action 'pressKeyWithActionAndTraversalHighlight' finished returning result.\n", stderr)
         // IMPORTANT: Highlighting cleanup happens asynchronously later.
        return result
    }

    /// Types text with visual feedback (caption), bracketed by traversals (before action, after action),
    /// highlights the elements from the second traversal, and returns the diff.
    ///
    /// - Parameters:
    ///   - text: The `String` to type.
    ///   - pid: The Process ID (PID) of the application.
    ///   - onlyVisibleElements: If true, traversals only collect elements with valid position/size. Default false.
    ///   - actionHighlightDuration: Duration (seconds) for the text input visual feedback caption. Default calculated or 1.0s.
    ///   - traversalHighlightDuration: Duration (seconds) for highlighting elements found in the second traversal. Default 3.0s.
    ///   - delayAfterActionNano: Nanoseconds to wait after typing before the second traversal. Default 100ms.
    /// - Returns: An `ActionDiffResult` containing the second traversal's data and the diff.
    /// - Throws: `MacosUseSDKError` if any step fails.
    @MainActor
    public static func writeTextWithActionAndTraversalHighlight(
        text: String,
        pid: Int32,
        onlyVisibleElements: Bool = false,
        actionHighlightDuration: Double? = nil, // Duration for visualization caption (optional, calculated if nil)
        traversalHighlightDuration: Double = 3.0, // Duration for highlighting elements
        delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default
    ) async throws -> ActionDiffResult {
         fputs("info: starting combined action 'writeTextWithActionAndTraversalHighlight' (text: \"\(text)\") for PID \(pid)\n", stderr)

        // Step 1: Traverse Before Action
        fputs("info: calling traverseAccessibilityTree (before action)...\n", stderr)
        let beforeTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (before action) completed.\n", stderr)

        // Step 2a: Perform the Text Writing (Input Simulation Only)
        fputs("info: calling writeText (\"\(text)\")...\n", stderr)
        try MacosUseSDK.writeText(text)
        fputs("info: writeText completed successfully.\n", stderr)

        // Step 2b: Dispatch Text Writing Visualization (Caption)
        let defaultDuration = 1.0
        let calculatedDuration = max(defaultDuration, 0.5 + Double(text.count) * 0.05)
        let finalDuration = actionHighlightDuration ?? calculatedDuration // Use provided or calculated duration
        let captionSize = CGSize(width: 450, height: 100) // Keep caption size definition here or centralize
        fputs("info: dispatching showVisualFeedback for write text (duration: \(finalDuration)s)...\n", stderr)
        Task { @MainActor in
             // Use the internal top-level function directly
             if let screenCenter = getMainScreenCenter() {
                 MacosUseSDK.showVisualFeedback(
                     at: screenCenter,
                     type: .caption(text: text), // Show the actual typed text
                     size: captionSize,
                     duration: finalDuration
                 )
             } else {
                 fputs("warning: [\(#function)] could not get screen center for write text caption.\n", stderr)
             }
        }
        fputs("info: showVisualFeedback for write text dispatched.\n", stderr)


        // Step 3: Wait for UI to Update
        fputs("info: waiting \(Double(delayAfterActionNano) / 1_000_000_000.0) seconds after action...\n", stderr)
        try await Task.sleep(nanoseconds: delayAfterActionNano)

        // Step 4: Traverse After Action
        fputs("info: calling traverseAccessibilityTree (after action)...\n", stderr)
        let afterTraversal = try MacosUseSDK.traverseAccessibilityTree(pid: pid, onlyVisibleElements: onlyVisibleElements)
        fputs("info: traversal (after action) completed.\n", stderr)

        // Step 5: Calculate Diff
        fputs("info: calculating traversal diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: diff calculation completed.\n", stderr)

        // Step 6: Dispatch Highlighting of the "After" Elements
        fputs("info: calling drawHighlightBoxes (duration: \(traversalHighlightDuration)s) for afterTraversal elements...\n", stderr)
        drawHighlightBoxes(for: afterTraversal.elements, duration: traversalHighlightDuration)
        fputs("info: drawHighlightBoxes dispatched highlight drawing.\n", stderr)

        // Step 7: Prepare and Return Result
        let result = ActionDiffResult(
            afterAction: afterTraversal,
            diff: diff
        )
         fputs("info: combined action 'writeTextWithActionAndTraversalHighlight' finished returning result.\n", stderr)
         // IMPORTANT: Highlighting cleanup happens asynchronously later.
        return result
    }

}

import XCTest
@testable import MacosUseSDK // Use @testable to access internal stuff if needed, otherwise just import
import AppKit // For NSWorkspace, NSRunningApplication

final class CombinedActionsDiffTests: XCTestCase {

    var calculatorPID: pid_t?
    var calculatorApp: NSRunningApplication?

    // Launch Calculator before each test
    override func setUp() async throws {
        // Ensure accessibility is granted (cannot check programmatically easily, user must pre-authorize)
        fputs("info: Test setup - Launching Calculator...\n", stderr)
        // Note: Using NSWorkspace directly here to avoid SDK dependency loop if openApplication fails
        let calcURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        // Configuration to activate it
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        calculatorApp = try await NSWorkspace.shared.openApplication(at: calcURL, configuration: config)
        calculatorPID = calculatorApp?.processIdentifier
        XCTAssertNotNil(calculatorPID, "Failed to get Calculator PID")
        fputs("info: Test setup - Calculator launched with PID \(calculatorPID!)\n", stderr)
        // Give it a moment to fully launch and settle
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }

    // Quit Calculator after each test
    override func tearDown() async throws {
        fputs("info: Test teardown - Terminating Calculator (PID: \(calculatorPID ?? -1))...\n", stderr)
        calculatorApp?.terminate()
        // Give it more time to terminate AND for async UI cleanup (esp. traversal highlights) to hopefully settle
        fputs("info: Test teardown - Waiting 1.5 seconds for app termination and UI cleanup...\n", stderr) // Log clarity added
        // Increased delay from 0.5s to 1.5s to allow more time for async window closing operations.
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        calculatorApp = nil
        calculatorPID = nil
        fputs("info: Test teardown - Finished.\n", stderr)
    }

    // Test: Type '2*3=' with action viz + traversal highlight and print the diff
    @MainActor
    func testCalculatorMultiplyWithActionAndTraversalHighlight() async throws {
        guard let pid = calculatorPID else {
            XCTFail("Calculator PID not available")
            return
        }

        fputs("\ninfo: === Starting testCalculatorMultiplyWithActionAndTraversalHighlight ===\n", stderr)

        // --- Define durations for test ---
        let testActionHighlightDuration: Double = 0.4
        let testTraversalHighlightDuration: Double = 2.0 // Duration passed to SDK function
        let testDelayNano: UInt64 = 150_000_000

        // --- Action Sequence with Highlighting ---
        fputs("info: Test run - Calling writeTextWithActionAndTraversalHighlight for '2*3='...\n", stderr)
        let result = try await CombinedActions.writeTextWithActionAndTraversalHighlight(
            text: "2*3=",
            pid: pid,
            onlyVisibleElements: true,
            actionHighlightDuration: testActionHighlightDuration,
            traversalHighlightDuration: testTraversalHighlightDuration, // Pass 2.0s duration
            delayAfterActionNano: testDelayNano
        )
        fputs("info: Test run - writeTextWithActionAndTraversalHighlight returned (highlighting may start appearing).\n", stderr)

        // --- Print Diff ---
        fputs("info: --- Traversal Diff Results (Highlighted) ---\n", stderr)

        fputs("info: Added Elements (\(result.diff.added.count)):\n", stderr)
        if result.diff.added.isEmpty {
            fputs("info:   (None)\n", stderr)
        } else {
            for element in result.diff.added {
                fputs("info:   + Role: \(element.role), Text: \(element.text ?? "nil"), Pos: (\(element.x ?? -1), \(element.y ?? -1)), Size: (\(element.width ?? -1) x \(element.height ?? -1))\n", stderr)
            }
        }

        fputs("info: Removed Elements (\(result.diff.removed.count)):\n", stderr)
        if result.diff.removed.isEmpty {
             fputs("info:   (None)\n", stderr)
        } else {
            for element in result.diff.removed {
                 fputs("info:   - Role: \(element.role), Text: \(element.text ?? "nil"), Pos: (\(element.x ?? -1), \(element.y ?? -1)), Size: (\(element.width ?? -1) x \(element.height ?? -1))\n", stderr)
            }
        }
        fputs("info: --- End Diff Results (Highlighted) ---\n", stderr)

        // --- Wait for Traversal Highlighting Cleanup BEFORE Test Ends ---
        // Wait slightly longer than the traversal highlight duration (2.0s)
        // to ensure its async cleanup task (closing the 36 overlay windows)
        // has executed before tearDown terminates the Calculator app.
        let highlightCompletionWaitSeconds = testTraversalHighlightDuration + 0.2 // Wait 2.2 seconds total
        fputs("info: Test run - Waiting \(highlightCompletionWaitSeconds) seconds specifically for traversal highlighting cleanup to complete...\n", stderr)
        try await Task.sleep(nanoseconds: UInt64(highlightCompletionWaitSeconds * 1_000_000_000))
        fputs("info: Test run - Traversal highlight cleanup wait finished. Proceeding to finish test function.\n", stderr)
        // --- END WAIT ---

        fputs("info: === Finished testCalculatorMultiplyWithActionAndTraversalHighlight ===\n", stderr)
        // Teardown (which terminates the app) runs AFTER this function returns.
        // The 1.5s delay in tearDown remains as a final safety net.
    }
    // --- END TEST ---

    // Add more test methods for clickWithDiff, pressKeyWithDiff etc.
    // You can add similar tests for clickWithActionAndTraversalHighlight and pressKeyWithActionAndTraversalHighlight
    // For click tests, you might need to first traverse to find the coordinates of a button
    // (e.g., the '5' button) and then pass those coordinates to the click function.
}

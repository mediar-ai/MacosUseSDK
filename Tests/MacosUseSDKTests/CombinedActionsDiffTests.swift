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
        // Give it time to terminate
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        calculatorApp = nil
        calculatorPID = nil
    }

    // Example test: Type '2*3=' and print the diff
    @MainActor
    func testCalculatorMultiplyWithDiff() async throws {
        guard let pid = calculatorPID else {
            XCTFail("Calculator PID not available")
            return
        }

        // --- Action Sequence ---
        // Note: In a real test, you might find the button coords dynamically first.
        // For simplicity, assume we know where '2', '*', '3', '=' are approximately.
        // Or, better, use writeTextWithDiff if applicable.

        // Example using writeTextWithDiff
        fputs("info: Test run - Calling writeTextWithDiff for '2*3=' (using default delay)...\n", stderr)
        let result = try await CombinedActions.writeTextWithDiff(
            text: "2*3=", // Calculator understands keystrokes like this
            pid: pid,
            onlyVisibleElements: true // Usually want visible for tests
        )
        fputs("info: Test run - writeTextWithDiff completed.\n", stderr)

        // --- Print Diff ---
        fputs("info: --- Traversal Diff Results ---\n", stderr)

        fputs("info: Added Elements (\(result.diff.added.count)):\n", stderr)
        if result.diff.added.isEmpty {
            fputs("info:   (None)\n", stderr)
        } else {
            for element in result.diff.added {
                // Print relevant info for each added element
                fputs("info:   + Role: \(element.role), Text: \(element.text ?? "nil"), Pos: (\(element.x ?? -1), \(element.y ?? -1)), Size: (\(element.width ?? -1) x \(element.height ?? -1))\n", stderr)
            }
        }

        fputs("info: Removed Elements (\(result.diff.removed.count)):\n", stderr)
        if result.diff.removed.isEmpty {
             fputs("info:   (None)\n", stderr)
        } else {
            for element in result.diff.removed {
                 // Print relevant info for each removed element
                 fputs("info:   - Role: \(element.role), Text: \(element.text ?? "nil"), Pos: (\(element.x ?? -1), \(element.y ?? -1)), Size: (\(element.width ?? -1) x \(element.height ?? -1))\n", stderr)
            }
        }
        fputs("info: --- End Diff Results ---\n", stderr)

        fputs("info: Test run - Diff printed.\n", stderr)
    }

    // Add more test methods for clickWithDiff, pressKeyWithDiff etc.
}

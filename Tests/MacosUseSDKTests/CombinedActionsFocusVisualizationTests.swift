import XCTest
@testable import MacosUseSDK
import AppKit

final class CombinedActionsFocusVisualizationTests: XCTestCase {

    var textEditPID: pid_t?
    var textEditApp: NSRunningApplication?
    var temporaryFileURL: URL?

    // Launch TextEdit before each test, opening a temporary file
    override func setUp() async throws {
        // Create a temporary file URL
        temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("testFocus_\(UUID().uuidString).txt") // Unique name

        guard let fileURL = temporaryFileURL else {
            XCTFail("Failed to create temporary file URL")
            return
        }

        // Create an empty file
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            fputs("info: Focus Test Setup - Created temporary file at: \(fileURL.path)\n", stderr)
        } catch {
            XCTFail("Failed to create temporary file: \(error)")
            return
        }

        // Ensure accessibility is granted (user must pre-authorize)
        fputs("info: Focus Test Setup - Launching TextEdit to open temporary file...\n", stderr)

        let textEditAppURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true // Ensure it comes to the front and likely grabs focus

        // Open the temporary file with TextEdit
        textEditApp = try await NSWorkspace.shared.open(
            [fileURL], // Pass the URL of the file to open in an array
            withApplicationAt: textEditAppURL,
            configuration: config
        )

        textEditPID = textEditApp?.processIdentifier
        XCTAssertNotNil(textEditPID, "Failed to get TextEdit PID")
        fputs("info: Focus Test Setup - TextEdit launched with PID \(textEditPID!) opening \(fileURL.lastPathComponent)\n", stderr)

        // Give it time to fully launch, open the file, and potentially set initial focus
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
    }

    // Quit TextEdit and delete the temporary file after each test
    override func tearDown() async throws {
        fputs("info: Focus Test Teardown - Terminating TextEdit (PID: \(textEditPID ?? -1)) and cleaning up file...\n", stderr)

        // --- Close TextEdit Document (AppleScript part remains the same) ---
        if let pid = textEditPID {
            let script = """
            tell application "System Events"
                tell process id \(pid)
                    try
                        # Get the front window (document)
                        set frontWindow to first window

                        # Check if it's the document window we opened
                        # This might need adjustment based on exact window naming
                        if name of frontWindow contains "testFocus_" then
                           # Perform close action (Command-W)
                           keystroke "w" using {command down}
                           delay 0.2 # Small delay

                           # Check if a "Don't Save" sheet appeared (unlikely for empty/unchanged file)
                           if exists sheet 1 of frontWindow then
                               key code 36 # Return key code (usually selects default like "Don't Save")
                               delay 0.2
                           end if
                        end if
                    end try
                end tell
            end tell
            tell application "TextEdit" to if it is running then quit saving no # Add 'saving no' for clarity
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            do {
                try process.run()
                process.waitUntilExit()
                 fputs("info: Focus Test Teardown - Attempted clean close via AppleScript (Status: \(process.terminationStatus))\n", stderr)
            } catch {
                 fputs("error: Focus Test Teardown - AppleScript execution failed: \(error)\n", stderr)
            }
        }

        // Fallback or alternative: Force terminate if still running
        if textEditApp?.isTerminated == false {
            fputs("info: Focus Test Teardown - Forcing termination...\n", stderr)
            textEditApp?.forceTerminate()
            // Add a small delay after force termination
             try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }

        // --- Delete the temporary file ---
        if let fileURL = temporaryFileURL {
            do {
                try FileManager.default.removeItem(at: fileURL)
                fputs("info: Focus Test Teardown - Successfully deleted temporary file: \(fileURL.path)\n", stderr)
            } catch {
                // Log error but don't fail the test teardown for this
                fputs("warning: Focus Test Teardown - Could not delete temporary file: \(error)\n", stderr)
            }
            temporaryFileURL = nil // Clear the reference
        }

        // Give it time to terminate completely
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds (adjusted from 0.5)
        textEditApp = nil
        textEditPID = nil
        fputs("info: Focus Test Teardown - Finished.\n", stderr)
    }

    // Test: Write text to TextEdit, expecting focus to be on the text area
    // Verify by checking logs for the "successfully found focused element center" message.
    @MainActor
    func testTextEditFocusAndWriteVisualization() async throws {
        guard let pid = textEditPID else {
            XCTFail("TextEdit PID not available")
            return
        }

        fputs("\ninfo: === Starting testTextEditFocusAndWriteVisualization ===\n", stderr)

        // --- Define durations ---
        let testActionHighlightDuration: Double = 0.6
        let testTraversalHighlightDuration: Double = 1.5 // Shorter for this test
        let testDelayNano: UInt64 = 200_000_000 // 0.2s
        let observationDelaySeconds: Double = 1.0 // Time to observe action visualization

        // --- Action Sequence ---
        // We expect TextEdit's main text view to have focus after activation in setUp.
        fputs("info: Test run - Calling writeTextWithActionAndTraversalHighlight for 'Hello TextEdit!'...\n", stderr)
        let result = try await CombinedActions.writeTextWithActionAndTraversalHighlight(
            text: "Hello TextEdit!",
            pid: pid,
            onlyVisibleElements: true, // Doesn't affect focus check, but standard for combined action
            actionHighlightDuration: testActionHighlightDuration,
            traversalHighlightDuration: testTraversalHighlightDuration,
            delayAfterActionNano: testDelayNano
        )
        fputs("info: Test run - writeTextWithActionAndTraversalHighlight returned.\n", stderr)
        fputs("info: Test run - Check logs above for 'successfully found focused element center' from writeTextAndVisualize.\n", stderr)
        // You can examine result.diff if needed, but the focus is on the visualization attempt.

        // --- Short Wait for Visual Observation ---
        fputs("info: Test run - Waiting \(observationDelaySeconds) seconds for visual observation...\n", stderr)
        try await Task.sleep(nanoseconds: UInt64(observationDelaySeconds * 1_000_000_000))
        fputs("info: Test run - Observation wait finished.\n", stderr)

        fputs("info: === Finished testTextEditFocusAndWriteVisualization ===\n", stderr)
        // Teardown will handle closing TextEdit.
    }
}

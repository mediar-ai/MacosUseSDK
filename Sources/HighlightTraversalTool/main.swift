import Foundation
import AppKit // Required for NSApplication and RunLoop
import MacosUseSDK // Your library

// --- Helper Function for Argument Parsing ---
// Simple parser for "--duration <value>" and PID
func parseArguments() -> (pid: Int32?, duration: Double?) {
    var pid: Int32? = nil
    var duration: Double? = nil
    var waitingForDurationValue = false

    // Skip the executable path
    for arg in CommandLine.arguments.dropFirst() {
        if waitingForDurationValue {
            if let durationValue = Double(arg), durationValue > 0 {
                duration = durationValue
            } else {
                fputs("error: Invalid value provided after --duration.\n", stderr)
                return (nil, nil) // Indicate parsing error
            }
            waitingForDurationValue = false
        } else if arg == "--duration" {
            waitingForDurationValue = true
        } else if pid == nil, let pidValue = Int32(arg) {
            pid = pidValue
        } else {
            fputs("error: Unexpected argument '\(arg)'.\n", stderr)
            return (nil, nil) // Indicate parsing error
        }
    }

    // Check if duration flag was seen but value is missing
    if waitingForDurationValue {
        fputs("error: Missing value after --duration flag.\n", stderr)
        return (nil, nil)
    }

    // Check if PID was found
    if pid == nil {
        fputs("error: Missing required PID argument.\n", stderr)
        return (nil, nil)
    }

    return (pid, duration)
}

// --- Main Execution Logic ---

// 1. Parse Arguments
let (parsedPID, parsedDuration) = parseArguments()

guard let targetPID = parsedPID else {
    // Error messages printed by parser
    fputs("\nusage: HighlightTool <PID> [--duration <seconds>]\n", stderr)
    fputs("  <PID>: Process ID of the application to highlight.\n", stderr)
    fputs("  --duration <seconds>: How long the highlights should stay visible (default: 3.0).\n", stderr)
    fputs("\nexample: HighlightTool 14154 --duration 5\n", stderr)
    exit(1)
}

// Use provided duration or default
let highlightDuration = parsedDuration ?? 3.0

fputs("info: Target PID: \(targetPID), Highlight Duration: \(highlightDuration) seconds.\n", stderr)

// 2. Call the Library Function
do {
    fputs("info: Calling highlightVisibleElements...\n", stderr)
    // Call the highlight function from your library
    try MacosUseSDK.highlightVisibleElements(pid: targetPID, duration: highlightDuration)

    fputs("info: highlightVisibleElements call dispatched successfully.\n", stderr)
    fputs("      Overlays appear/disappear asynchronously on the main thread.\n", stderr)
    fputs("      Keeping the tool alive for \(highlightDuration + 1.0) seconds to allow UI updates...\n", stderr)

    // 3. Keep the Main Thread Alive
    // IMPORTANT: Since highlightVisibleElements uses DispatchQueue.main.async and asyncAfter
    // for UI updates, this command-line tool needs to keep the main run loop
    // running long enough for those updates to occur. A GUI app wouldn't need this.
    // We run it slightly longer than the highlight duration.
    RunLoop.main.run(until: Date(timeIntervalSinceNow: highlightDuration + 1.0))

    fputs("info: Run loop finished. Tool exiting normally.\n", stderr)
    exit(0) // Success

} catch let error as MacosUseSDKError {
    fputs("❌ Error from MacosUseSDK: \(error.localizedDescription)\n", stderr)
    exit(1)
} catch {
    // Catch other potential errors
    fputs("❌ An unexpected error occurred: \(error.localizedDescription)\n", stderr)
    exit(1)
}

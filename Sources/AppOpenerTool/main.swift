// // main.swift for AppOpenerTool
// // Script to open or activate a specified macOS application by name or path.
// // Reliably outputs the PID on success (launch or activation) and processing time to stderr.

// import AppKit // Needed for NSWorkspace, NSApplication, NSRunningApplication
// import Foundation
// import MacosUseSDK // Import the library

// // Encapsulate logic in a @main struct isolated to the MainActor
// @main
// @MainActor
// struct AppOpenerTool {

//     // Make timers static properties of the struct
//     static let startTime = Date()
//     static var stepStartTime = startTime // Initialize step timer

//     // --- Helper function for step timing (now a static method) ---
//     static func logStepCompletion(_ stepDescription: String) {
//         let endTime = Date()
//         // Accessing static stepStartTime is now safe within @MainActor context
//         let duration = endTime.timeIntervalSince(stepStartTime)
//         let durationStr = String(format: "%.3f", duration) // Use 3 decimal places for steps
//         fputs("info: [\(durationStr)s] finished '\(stepDescription)'\n", stderr)
//         // Mutating static stepStartTime is also safe
//         stepStartTime = endTime // Reset start time for the next step
//     }

//     // The main function now needs to be async to call the async library function
//     static func main() async {
//         // --- Argument Parsing ---
//         guard CommandLine.arguments.count == 2 else {
//             let scriptName = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
//             fputs("usage: \(scriptName) <Application Name, Bundle ID, or Path>\n", stderr)
//             fputs("example (name): \(scriptName) Calculator\n", stderr)
//             fputs("example (path): \(scriptName) /System/Applications/Utilities/Terminal.app\n", stderr)
//             fputs("example (bundleID): \(scriptName) com.apple.Terminal\n", stderr)
//             exit(1)
//         }
//         let appIdentifier = CommandLine.arguments[1]

//         // --- Call Library Function ---
//         fputs("info: calling MacosUseSDK.openApplication for identifier: '\(appIdentifier)'\n", stderr)
//         do {
//             // Use await to call the async function
//             let result = try await MacosUseSDK.openApplication(identifier: appIdentifier)

//             // --- Output PID on Success ---
//             // Success/Timing logs are already printed by the library function to stderr
//             // Print only the PID to stdout as the primary output
//             print(result.pid)
//             exit(0) // Exit successfully

//         } catch let error as MacosUseSDKError.AppOpenerError {
//             // Specific errors from the AppOpener module
//             fputs("❌ Error (AppOpener): \(error.localizedDescription)\n", stderr)
//             exit(1)
//         } catch let error as MacosUseSDKError {
//              // Other potential errors from the SDK (though less likely here)
//              fputs("❌ Error (MacosUseSDK): \(error.localizedDescription)\n", stderr)
//              exit(1)
//         } catch {
//             // Catch any other unexpected errors
//             fputs("❌ An unexpected error occurred: \(error.localizedDescription)\n", stderr)
//             exit(1)
//         }
//     }
// } // End of struct AppOpenerTool

// /*
// swift run AppOpenerTool Messages
// */
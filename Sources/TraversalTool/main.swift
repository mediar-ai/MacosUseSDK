// import Foundation
// import MacosUseSDK // Import your library

// // --- Main Execution Logic ---

// // 1. Argument Parsing
// var arguments = CommandLine.arguments
// var onlyVisible = false
// var pidString: String? = nil

// // Remove the executable name
// arguments.removeFirst()

// // Check for the flag and remove it if found
// if let flagIndex = arguments.firstIndex(of: "--visible-only") {
//     onlyVisible = true
//     arguments.remove(at: flagIndex)
//     fputs("info: '--visible-only' flag detected.\n", stderr)
// }

// // The remaining argument should be the PID
// if arguments.count == 1 {
//     pidString = arguments[0]
// }

// guard let pidStr = pidString, let appPID = Int32(pidStr) else {
//     fputs("usage: TraversalTool [--visible-only] <PID>\n", stderr)
//     fputs("error: expected a valid process id (pid) as the argument.\n", stderr)
//     fputs("example (all elements): TraversalTool 14154\n", stderr)
//     fputs("example (visible only): TraversalTool --visible-only 14154\n", stderr)
//     exit(1)
// }

// // 2. Call the Library Function
// do {
//     fputs("info: calling traverseAccessibilityTree for pid \(appPID) (Visible Only: \(onlyVisible))...\n", stderr)
//     // MODIFIED: Pass the parsed 'onlyVisible' flag to the library function
//     let responseData = try MacosUseSDK.traverseAccessibilityTree(pid: appPID, onlyVisibleElements: onlyVisible)
//     fputs("info: successfully received response from traverseAccessibilityTree.\n", stderr)

//     // 3. Encode the result to JSON
//     let encoder = JSONEncoder()
//     encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

//     let jsonData = try encoder.encode(responseData)

//     // 4. Print JSON to standard output
//     if let jsonString = String(data: jsonData, encoding: .utf8) {
//         print(jsonString)
//         exit(0) // Success
//     } else {
//         fputs("error: failed to convert response data to json string.\n", stderr)
//         exit(1)
//     }

// } catch let error as MacosUseSDKError {
//     fputs("❌ Error from MacosUseSDK: \(error.localizedDescription)\n", stderr)
//     exit(1)
// } catch {
//     fputs("❌ An unexpected error occurred: \(error.localizedDescription)\n", stderr)
//     exit(1)
// }

// /*
// # Example: Get visible elements from Messages app
// swift run TraversalTool --visible-only $(swift run AppOpenerTool Messages)
// */ 
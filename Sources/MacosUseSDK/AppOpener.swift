import AppKit
import Foundation

// Define potential errors during app opening
public extension MacosUseSDKError {
    // Ensure this enum is correctly defined within the extension
    enum AppOpenerError: Error, LocalizedError {
        case appNotFound(identifier: String)
        case invalidPath(path: String)
        case activationFailed(identifier: String, underlyingError: Error?)
        case pidLookupFailed(identifier: String)
        case unexpectedNilURL

        public var errorDescription: String? {
            switch self {
            case .appNotFound(let id):
                return "Application not found for identifier: '\(id)'"
            case .invalidPath(let path):
                return "Provided path does not appear to be a valid application bundle: '\(path)'"
            case .activationFailed(let id, let err):
                let base = "Failed to open/activate application '\(id)'"
                if let err = err {
                    return "\(base): \(err.localizedDescription)"
                }
                return base
            case .pidLookupFailed(let id):
                return "Could not determine PID for application '\(id)' after activation attempt."
            case .unexpectedNilURL:
                 return "Internal error: Application URL became nil unexpectedly."
            }
        }
    }
}

// Define the structure for the successful result
public struct AppOpenerResult: Codable, Sendable {
    public let pid: pid_t
    public let appName: String
    public let processingTimeSeconds: String
}

// --- Private Helper Class for State Management ---
// Using a class instance allows managing state like stepStartTime across async calls
@MainActor
private class AppOpenerOperation {
    let appIdentifier: String
    let overallStartTime: Date = Date()
    var stepStartTime: Date

    init(identifier: String) {
        self.appIdentifier = identifier
        self.stepStartTime = overallStartTime // Initialize step timer
        fputs("info: starting AppOpenerOperation for: \(identifier)\n", stderr)
    }

    // Helper to log step completion times (Method definition)
    func logStepCompletion(_ stepDescription: String) {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(stepStartTime)
        let durationStr = String(format: "%.3f", duration)
        fputs("info: [\(durationStr)s] finished '\(stepDescription)'\n", stderr)
        stepStartTime = endTime // Reset for next step
    }

    // Main logic function using async/await (Method definition)
    func execute() async throws -> AppOpenerResult {
        // --- All the application discovery, PID finding, and activation logic goes *inside* this method ---
        let workspace = NSWorkspace.shared // Define workspace locally within the method
        var appURL: URL?
        var foundPID: pid_t?
        var bundleIdentifier: String?
        var finalAppName: String?

        // --- 1. Application Discovery ---
        // (Path checking logic...)
        if appIdentifier.hasSuffix(".app") && appIdentifier.contains("/") {
             fputs("info: interpreting '\(appIdentifier)' as a path.\n", stderr)
             let potentialURL = URL(fileURLWithPath: appIdentifier)
             var isDirectory: ObjCBool = false
             if FileManager.default.fileExists(atPath: potentialURL.path, isDirectory: &isDirectory)
                 && isDirectory.boolValue && potentialURL.pathExtension == "app"
             {
                 appURL = potentialURL
                 fputs("info: path confirmed as valid application bundle: \(potentialURL.path)\n", stderr)
                 if let bundle = Bundle(url: potentialURL) {
                     bundleIdentifier = bundle.bundleIdentifier
                     finalAppName = bundle.localizedInfoDictionary?["CFBundleName"] as? String ?? bundle.bundleIdentifier
                     fputs("info: derived bundleID: \(bundleIdentifier ?? "nil"), name: \(finalAppName ?? "nil") from path\n", stderr)
                 }
             } else {
                  fputs("warning: provided path does not appear to be a valid application bundle: \(appIdentifier). Will try as name/bundleID.\n", stderr)
             }
         }

        // (Name/BundleID search logic...)
         if appURL == nil {
             fputs("info: interpreting '\(appIdentifier)' as an application name or bundleID, searching...\n", stderr)
              if let foundURL = workspace.urlForApplication(withBundleIdentifier: appIdentifier) {
                  appURL = foundURL
                  bundleIdentifier = appIdentifier
                  fputs("info: found application url via bundleID '\(appIdentifier)': \(foundURL.path)\n", stderr)
                  if let bundle = Bundle(url: foundURL) {
                     finalAppName = bundle.localizedInfoDictionary?["CFBundleName"] as? String ?? bundle.bundleIdentifier
                  }
              } else if let foundURLByName = workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(appIdentifier).app")) ??
                                             workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/\(appIdentifier).app")) ??
                                             workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/Utilities/\(appIdentifier).app"))
              {
                  appURL = foundURLByName
                  fputs("info: found application url via name search '\(appIdentifier)': \(foundURLByName.path)\n", stderr)
                  if let bundle = Bundle(url: foundURLByName) {
                      bundleIdentifier = bundle.bundleIdentifier
                      finalAppName = bundle.localizedInfoDictionary?["CFBundleName"] as? String ?? bundle.bundleIdentifier
                      fputs("info: derived bundleID: \(bundleIdentifier ?? "nil"), name: \(finalAppName ?? "nil") from found URL\n", stderr)
                  }
              } else {
                  logStepCompletion("application discovery (failed)") // Call method
                  throw MacosUseSDKError.AppOpenerError.appNotFound(identifier: appIdentifier)
              }
         }
        logStepCompletion("application discovery (url: \(appURL?.path ?? "nil"), bundleID: \(bundleIdentifier ?? "nil"))") // Call method

        // (Guard statement logic...)
        guard let finalAppURL = appURL else {
             fputs("error: unexpected error - application url is nil before launch attempt.\n", stderr)
            throw MacosUseSDKError.AppOpenerError.unexpectedNilURL
        }
        // (Final app name determination...)
         if finalAppName == nil {
              if let bundle = Bundle(url: finalAppURL) {
                   finalAppName = bundle.localizedInfoDictionary?["CFBundleName"] as? String ?? bundle.bundleIdentifier
              }
              finalAppName = finalAppName ?? appIdentifier
         }


        // --- 2. Pre-find PID if running ---
        // (PID finding logic...)
        if let bID = bundleIdentifier {
             fputs("info: checking running applications for bundle id: \(bID)\n", stderr)
             if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bID).first {
                 foundPID = runningApp.processIdentifier
                 fputs("info: found running instance with pid \(foundPID!) for bundle id \(bID).\n", stderr)
             } else {
                 fputs("info: no running instance found for bundle id \(bID) before activation attempt.\n", stderr)
             }
         } else {
             fputs("warning: no bundle identifier, attempting lookup by URL: \(finalAppURL.path)\n", stderr)
             for app in workspace.runningApplications {
                 if app.bundleURL?.standardizedFileURL == finalAppURL.standardizedFileURL || app.executableURL?.standardizedFileURL == finalAppURL.standardizedFileURL {
                     foundPID = app.processIdentifier
                     fputs("info: found running instance with pid \(foundPID!) matching URL.\n", stderr)
                     break
                 }
             }
             if foundPID == nil {
                 fputs("info: no running instance found by URL before activation attempt.\n", stderr)
             }
         }
        logStepCompletion("pre-finding existing process (pid: \(foundPID.map(String.init) ?? "none found"))") // Call method

        // --- 3. Open/Activate Application ---
        // (Activation logic...)
        fputs("info: attempting to open/activate application: \(finalAppName ?? appIdentifier)\n", stderr)
        let configuration = NSWorkspace.OpenConfiguration() // Define configuration locally

        do {
            // Await the async call AND extract the PID within an explicit MainActor context
            let pidAfterOpen = try await MainActor.run {
                fputs("info: [MainActor.run] executing workspace.openApplication...\n", stderr)
                let runningApp = try await workspace.openApplication(at: finalAppURL, configuration: configuration)
                let pid = runningApp.processIdentifier
                fputs("info: [MainActor.run] got pid \(pid) from NSRunningApplication.\n", stderr)
                return pid
            }

            logStepCompletion("opening/activating application async call completed")

             // --- 4. Determine Final PID ---
             var finalPID: pid_t? = nil

             if let pid = foundPID {
                 finalPID = pid
                 fputs("info: using pre-found pid \(pid).\n", stderr)
             } else {
                 // Use the PID extracted immediately after the await
                 finalPID = pidAfterOpen
                 fputs("info: using pid \(finalPID!) from newly launched/activated application instance.\n", stderr)
                 foundPID = finalPID // Update foundPID if it was initially nil
             }
             logStepCompletion("determining final pid (using \(finalPID!))") // Call method

             // --- 5. Prepare Result ---
             let endTime = Date()
             let processingTime = endTime.timeIntervalSince(overallStartTime)
             let formattedTime = String(format: "%.3f", processingTime)

             fputs("success: application '\(finalAppName ?? appIdentifier)' active (pid: \(finalPID!)).\n", stderr)
             fputs("info: total processing time: \(formattedTime) seconds\n", stderr)

             return AppOpenerResult(
                 pid: finalPID!,
                 appName: finalAppName ?? appIdentifier,
                 processingTimeSeconds: formattedTime
             )

        } catch {
             logStepCompletion("opening/activating application (failed)") // Call method
             fputs("error: activation call failed: \(error.localizedDescription)\n", stderr)

             if let pid = foundPID {
                 fputs("warning: activation failed, but PID \(pid) was found beforehand. Assuming it's running.\n", stderr)
                 let endTime = Date()
                 let processingTime = endTime.timeIntervalSince(overallStartTime)
                 let formattedTime = String(format: "%.3f", processingTime)
                 fputs("info: total processing time: \(formattedTime) seconds\n", stderr)
                 return AppOpenerResult(
                     pid: pid,
                     appName: finalAppName ?? appIdentifier,
                     processingTimeSeconds: formattedTime
                 )
             } else {
                 fputs("error: PID could not be determined after activation failure.\n", stderr)
                  let endTime = Date()
                  let processingTime = endTime.timeIntervalSince(overallStartTime)
                  let formattedTime = String(format: "%.3f", processingTime)
                  fputs("info: total processing time (on failure): \(formattedTime) seconds\n", stderr)
                 throw MacosUseSDKError.AppOpenerError.activationFailed(identifier: appIdentifier, underlyingError: error)
             }
        }
        // --- End of logic inside execute method ---
    } // End of execute() method
} // End of AppOpenerOperation class


/// Opens or activates a macOS application identified by its name, bundle ID, or full path.
/// Outputs detailed logs to stderr.
///
/// - Parameter identifier: The application name (e.g., "Calculator"), bundle ID (e.g., "com.apple.calculator"), or full path (e.g., "/System/Applications/Calculator.app").
/// - Returns: An `AppOpenerResult` containing the PID, application name, and processing time on success.
/// - Throws: `MacosUseSDKError.AppOpenerError` if the application cannot be found, activated, or its PID determined.
@MainActor
public func openApplication(identifier: String) async throws -> AppOpenerResult {
    // Input validation
    guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw MacosUseSDKError.AppOpenerError.appNotFound(identifier: "(empty)")
    }

    // Create an instance of the helper class and execute its logic
    let operation = AppOpenerOperation(identifier: identifier)
    return try await operation.execute()
}

// --- IMPORTANT: Ensure no other executable code (like the old script lines) exists below this line in the file ---
// --- Remove any leftover 'if', 'guard', 'logStepCompletion', 'workspace.openApplication', 'RunLoop.main.run' calls from the top level ---

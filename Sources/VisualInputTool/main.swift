import Foundation
import CoreGraphics // For CGPoint, CGEventFlags
import MacosUseSDK // Import the library
import AppKit // Required for RunLoop, NSScreen

// --- Start Time ---
let startTime = Date() // Record start time for the tool's execution

// --- Tool-specific Logging ---
func log(_ message: String) {
    fputs("VisualInputTool: \(message)\n", stderr)
}

// --- Tool-specific Exiting ---
func finish(success: Bool, message: String? = nil) {
    if let msg = message {
        log(success ? "✅ Success: \(msg)" : "❌ Error: \(msg)")
    }
    let endTime = Date()
    let processingTime = endTime.timeIntervalSince(startTime)
    let formattedTime = String(format: "%.3f", processingTime)
    fputs("VisualInputTool: total execution time (before wait): \(formattedTime) seconds\n", stderr)
    // Don't exit immediately, let RunLoop finish
}

// --- Argument Parsing Helper ---
// Parses standard input actions AND an optional --duration flag
func parseArguments() -> (action: String?, args: [String], duration: Double) {
    var action: String? = nil
    var actionArgs: [String] = []
    var duration: Double = 0.5 // Default duration for visualization
    var waitingForDurationValue = false
    let allArgs = CommandLine.arguments.dropFirst() // Skip executable path

    for arg in allArgs {
        if waitingForDurationValue {
            if let durationValue = Double(arg), durationValue > 0 {
                duration = durationValue
                log("Parsed duration: \(duration) seconds")
            } else {
                fputs("error: Invalid value provided after --duration.\n", stderr)
                // Return error indication or default? Let's keep default and log error.
            }
            waitingForDurationValue = false
        } else if arg == "--duration" {
            waitingForDurationValue = true
        } else if action == nil {
            action = arg.lowercased()
            log("Parsed action: \(action!)")
        } else {
            actionArgs.append(arg)
        }
    }

    if waitingForDurationValue {
        fputs("error: Missing value after --duration flag. Using default \(duration)s.\n", stderr)
    }
    if action == nil {
         fputs("error: No action specified.\n", stderr)
    }

    log("Parsed action arguments: \(actionArgs)")
    return (action, actionArgs, duration)
}


// --- Main Logic ---
let scriptName = CommandLine.arguments.first ?? "VisualInputTool"
let usage = """
usage: \(scriptName) <action> [options...] [--duration <seconds>]

actions:
  keypress <key_name_or_code>[+modifier...]   Simulate key press AND show caption visualization.
  click <x> <y>                 Simulate left click AND show circle visualization.
  doubleclick <x> <y>           Simulate double-click AND show circle visualization.
  rightclick <x> <y>            Simulate right click AND show circle visualization.
  mousemove <x> <y>             Move mouse AND show circle visualization at destination.
  writetext <text_to_type>      Simulate typing text AND show caption visualization.

options:
  --duration <seconds>          How long the visual effect should last (default: 0.5s for mouse, 0.8s for keypress, calculated for writetext).

Examples:
  \(scriptName) click 100 250
  \(scriptName) click 500 500 --duration 1.5
  \(scriptName) keypress cmd+shift+4 --duration 1.0
  \(scriptName) writetext "Hello There"
"""

let (action, actionArgs, parsedDuration) = parseArguments()

guard let action = action else {
    fputs(usage, stderr)
    exit(1)
}

// --- Action Handling ---
var success = false
var message: String? = nil
var requiresRunLoopWait = true // Default to true, as all actions now have visualization

// Variable to hold the actual duration used for visualization
var visualizationDuration: Double = 0.5 // Default fallback

// Use a Task for the main logic to easily call async/await and @MainActor functions
Task {
    do {
        switch action {
        case "keypress":
            guard actionArgs.count == 1 else {
                throw MacosUseSDKError.inputInvalidArgument("'keypress' requires exactly one argument: <key_name_or_code_with_modifiers>\n\(usage)")
            }
            let keyCombo = actionArgs[0]
            log("Processing key combo: '\(keyCombo)'")
            // (Parsing logic copied from InputControllerTool)
            var keyCode: CGKeyCode?
            var flags: CGEventFlags = []
            let parts = keyCombo.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard let keyPart = parts.last else {
                throw MacosUseSDKError.inputInvalidArgument("Invalid key combination format: '\(keyCombo)'")
            }
            keyCode = MacosUseSDK.mapKeyNameToKeyCode(keyPart)
            if parts.count > 1 {
                log("Parsing modifiers: \(parts.dropLast().joined(separator: ", "))")
                for i in 0..<(parts.count - 1) {
                    switch parts[i] {
                        case "cmd", "command": flags.insert(.maskCommand)
                        case "shift": flags.insert(.maskShift)
                        case "opt", "option", "alt": flags.insert(.maskAlternate)
                        case "ctrl", "control": flags.insert(.maskControl)
                        case "fn", "function": flags.insert(.maskSecondaryFn)
                        default: throw MacosUseSDKError.inputInvalidArgument("Unknown modifier: '\(parts[i])' in '\(keyCombo)'")
                    }
                }
            }
            guard let finalKeyCode = keyCode else {
                throw MacosUseSDKError.inputInvalidArgument("Unknown key name or invalid key code: '\(keyPart)' in '\(keyCombo)'")
            }

            visualizationDuration = parsedDuration > 0 ? parsedDuration : 0.8 // Use parsed or default 0.8s

            log("Calling pressKey library function...")
            try MacosUseSDK.pressKey(keyCode: finalKeyCode, flags: flags) // Input simulation

            log("Dispatching showVisualFeedback for keypress...")
            // Dispatch visualization separately (@MainActor is handled by showVisualFeedback)
            let captionText = "[KEY PRESS]"
            let captionSize = CGSize(width: 250, height: 80)
            if let screenCenter = MacosUseSDK.getMainScreenCenter() {
                MacosUseSDK.showVisualFeedback(
                    at: screenCenter,
                    type: .caption(text: captionText),
                    size: captionSize,
                    duration: visualizationDuration
                )
            } else {
                fputs("warning: could not get screen center for key press caption.\n", stderr)
                requiresRunLoopWait = false // Don't wait if viz failed
            }

            success = true
            message = "Key press '\(keyCombo)' simulated with visualization."

        case "click", "doubleclick", "rightclick", "mousemove":
            guard actionArgs.count == 2 else {
                throw MacosUseSDKError.inputInvalidArgument("'\(action)' requires exactly two arguments: <x> <y>\n\(usage)")
            }
            guard let x = Double(actionArgs[0]), let y = Double(actionArgs[1]) else {
                throw MacosUseSDKError.inputInvalidArgument("Invalid coordinates for '\(action)'. x and y must be numbers.")
            }
            let point = CGPoint(x: x, y: y)
            log("Coordinates: (\(x), \(y))")

            visualizationDuration = parsedDuration > 0 ? parsedDuration : 0.5 // Use parsed or default 0.5s

            log("Calling \(action) library function...") // Now refers to the input-only function
            switch action {
                case "click":       try MacosUseSDK.clickMouse(at: point)
                case "doubleclick": try MacosUseSDK.doubleClickMouse(at: point)
                case "rightclick":  try MacosUseSDK.rightClickMouse(at: point)
                case "mousemove":   try MacosUseSDK.moveMouse(to: point)
                default: break // Should not happen
            }

            log("Dispatching showVisualFeedback for \(action)...")
            // Dispatch visualization separately
            MacosUseSDK.showVisualFeedback(at: point, type: .circle, duration: visualizationDuration)

            success = true
            message = "\(action) simulated at (\(x), \(y)) with visualization."


        case "writetext":
            guard actionArgs.count == 1 else {
                throw MacosUseSDKError.inputInvalidArgument("'writetext' requires exactly one argument: <text_to_type>\n\(usage)")
            }
            let text = actionArgs[0]
            log("Text Argument: \"\(text)\"")

            // Calculate duration if not specified
            let defaultDuration = 1.0
            let calculatedDuration = max(defaultDuration, 0.5 + Double(text.count) * 0.05)
            visualizationDuration = parsedDuration > 0 ? parsedDuration : calculatedDuration // Use parsed or calculated

            log("Calling writeText library function...")
            try MacosUseSDK.writeText(text) // Input simulation

            log("Dispatching showVisualFeedback for writetext...")
            // Dispatch visualization separately
            let captionSize = CGSize(width: 450, height: 100)
            if let screenCenter = MacosUseSDK.getMainScreenCenter() {
                MacosUseSDK.showVisualFeedback(
                    at: screenCenter,
                    type: .caption(text: text), // Show actual text
                    size: captionSize,
                    duration: visualizationDuration
                )
            } else {
                fputs("warning: could not get screen center for write text caption.\n", stderr)
                requiresRunLoopWait = false // Don't wait if viz failed
            }

            success = true
            message = "Text writing simulated with visualization."

        default:
            fputs(usage, stderr)
            throw MacosUseSDKError.inputInvalidArgument("Unknown action '\(action)'")
        }

        // --- Log final status before potentially waiting ---
        finish(success: success, message: message)

        // --- Keep Main Thread Alive for Visualization (if needed) ---
        if requiresRunLoopWait {
            let waitTime = visualizationDuration + 0.5 // Wait slightly longer
            log("Waiting for \(waitTime) seconds for visualization to complete...")
            // Use RunLoop directly since we are in a Task that might not be on the main thread initially
            DispatchQueue.main.async {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: waitTime))
                log("Run loop finished. Exiting.")
                exit(0) // Exit normally after waiting
            }
            // Keep the task alive until the run loop finishes
            try await Task.sleep(nanoseconds: UInt64((waitTime + 0.1) * 1_000_000_000))
            // Fallback exit if the run loop mechanism doesn't exit
            exit(0)

        } else {
            log("No visualization triggered or viz failed, exiting immediately.")
            exit(0) // Exit normally without waiting
        }

    } catch let error as MacosUseSDKError {
        finish(success: false, message: "MacosUseSDK Error: \(error.localizedDescription)")
        exit(1) // Exit with error
    } catch {
        finish(success: false, message: "An unexpected error occurred: \(error.localizedDescription)")
        exit(1) // Exit with error
    }
}

// Keep the main thread running to allow the Task to execute
RunLoop.main.run()

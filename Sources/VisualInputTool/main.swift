import Foundation
import CoreGraphics // For CGPoint, CGEventFlags
import MacosUseSDK // Import the library
import AppKit // Required for RunLoop

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
  keypress <key_name_or_code>[+modifier...]   Simulate key press (NO visualization yet).
  click <x> <y>                 Simulate left click with visualization.
  doubleclick <x> <y>           Simulate double-click with visualization.
  rightclick <x> <y>            Simulate right click with visualization.
  mousemove <x> <y>             Move mouse with visualization at destination.
  writetext <text_to_type>      Simulate typing text (NO visualization yet).

options:
  --duration <seconds>          How long the visual effect should last (default: 0.5).

Examples:
  \(scriptName) click 100 250
  \(scriptName) click 500 500 --duration 1.5
  \(scriptName) keypress cmd+shift+4
  \(scriptName) writetext "Hello"
"""

let (action, actionArgs, duration) = parseArguments()

guard let action = action else {
    fputs(usage, stderr)
    exit(1)
}

// --- Action Handling ---
var success = false
var message: String? = nil
var requiresRunLoopWait = false // Flag if visualization was triggered

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

        log("Calling pressKeyAndVisualize library function...")
        try MacosUseSDK.pressKeyAndVisualize(keyCode: finalKeyCode, flags: flags, duration: duration)
        // No visualization yet, so no RunLoop wait needed for this action
        success = true
        message = "Key press '\(keyCombo)' simulated (no visualization)."

    case "click", "doubleclick", "rightclick", "mousemove":
        guard actionArgs.count == 2 else {
             throw MacosUseSDKError.inputInvalidArgument("'\(action)' requires exactly two arguments: <x> <y>\n\(usage)")
        }
        guard let x = Double(actionArgs[0]), let y = Double(actionArgs[1]) else {
            throw MacosUseSDKError.inputInvalidArgument("Invalid coordinates for '\(action)'. x and y must be numbers.")
        }
        let point = CGPoint(x: x, y: y)
        log("Coordinates: (\(x), \(y))")

        log("Calling \(action)AndVisualize library function...")
        switch action {
            case "click":       try MacosUseSDK.clickMouseAndVisualize(at: point, duration: duration)
            case "doubleclick": try MacosUseSDK.doubleClickMouseAndVisualize(at: point, duration: duration)
            case "rightclick":  try MacosUseSDK.rightClickMouseAndVisualize(at: point, duration: duration)
            case "mousemove":   try MacosUseSDK.moveMouseAndVisualize(to: point, duration: duration)
            default: break // Should not happen
        }
        requiresRunLoopWait = true // Visualization was triggered
        success = true
        message = "\(action) simulated at (\(x), \(y)) with visualization."


    case "writetext":
         guard actionArgs.count == 1 else {
            throw MacosUseSDKError.inputInvalidArgument("'writetext' requires exactly one argument: <text_to_type>\n\(usage)")
        }
        let text = actionArgs[0]
        log("Text Argument: \"\(text)\"")
        log("Calling writeTextAndVisualize library function...")
        try MacosUseSDK.writeTextAndVisualize(text, duration: duration)
        // No visualization yet, so no RunLoop wait needed for this action
        success = true
        message = "Text writing simulated (no visualization)."

    default:
        fputs(usage, stderr)
        throw MacosUseSDKError.inputInvalidArgument("Unknown action '\(action)'")
    }

    // --- Log final status before potentially waiting ---
    finish(success: success, message: message)

    // --- Keep Main Thread Alive for Visualization (if needed) ---
    if requiresRunLoopWait {
        let waitTime = duration + 0.5 // Wait slightly longer than the effect duration
        log("Waiting for \(waitTime) seconds for visualization to complete...")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: waitTime))
        log("Run loop finished. Exiting.")
        exit(0) // Exit normally after waiting
    } else {
        log("No visualization triggered, exiting immediately.")
        exit(0) // Exit normally without waiting
    }

} catch let error as MacosUseSDKError {
    finish(success: false, message: "MacosUseSDK Error: \(error.localizedDescription)")
    exit(1) // Exit with error
} catch {
     finish(success: false, message: "An unexpected error occurred: \(error.localizedDescription)")
     exit(1) // Exit with error
}

// Should not be reached
exit(1)

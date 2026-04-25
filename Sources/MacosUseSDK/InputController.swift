// #!/usr/bin/swift - Don't need this when it's part of a library

import Foundation
import CoreGraphics
import AppKit // Needed for Process and potentially other things later

// --- Add new Error Cases for Input Control ---
public extension MacosUseSDKError {
    // Add specific error cases relevant to InputController
    static func inputInvalidArgument(_ message: String) -> MacosUseSDKError {
        .internalError("Input Argument Error: \(message)") // Reuse internalError or create specific types
    }
    static func inputSimulationFailed(_ message: String) -> MacosUseSDKError {
        .internalError("Input Simulation Failed: \(message)")
    }
     static func osascriptExecutionFailed(status: Int32, message: String = "") -> MacosUseSDKError {
        .internalError("osascript execution failed with status \(status). \(message)")
    }
}


// --- Constants for Key Codes ---
// These match the constants used in the Rust macos.rs code for consistency
public let KEY_RETURN: CGKeyCode = 36
public let KEY_TAB: CGKeyCode = 48
public let KEY_SPACE: CGKeyCode = 49
public let KEY_DELETE: CGKeyCode = 51 // Matches 'delete' (backspace on many keyboards)
public let KEY_ESCAPE: CGKeyCode = 53
public let KEY_ARROW_LEFT: CGKeyCode = 123
public let KEY_ARROW_RIGHT: CGKeyCode = 124
public let KEY_ARROW_DOWN: CGKeyCode = 125
public let KEY_ARROW_UP: CGKeyCode = 126
public let KEY_PAGE_UP: CGKeyCode = 116
public let KEY_PAGE_DOWN: CGKeyCode = 121
public let KEY_HOME: CGKeyCode = 115
public let KEY_END: CGKeyCode = 119
public let KEY_FORWARD_DELETE: CGKeyCode = 117
// Add other key codes as needed (consider making them public if the tool needs direct access)

// --- Helper Functions (Internal or Fileprivate) ---

// Logs messages to stderr for debugging/status - keep internal or remove if tool handles logging
// fileprivate func log(_ message: String) { // Make fileprivate or remove
//     fputs("log: \(message)\n", stderr)
// }

// Creates a CGEventSource or throws
fileprivate func createEventSource() throws -> CGEventSource {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        throw MacosUseSDKError.inputSimulationFailed("failed to create event source")
    }
    return source
}

// Posts a CGEvent or throws
fileprivate func postEvent(_ event: CGEvent?, actionDescription: String) throws {
    guard let event = event else {
        throw MacosUseSDKError.inputSimulationFailed("failed to create \(actionDescription) event")
    }
    event.post(tap: .cghidEventTap)
    // Add a small delay after posting, crucial for some applications
    usleep(15_000) // 15 milliseconds, slightly increased from 10ms
}

// --- Public Input Simulation Functions ---

/// Simulates pressing and releasing a key with optional modifier flags.
/// - Parameters:
///   - keyCode: The `CGKeyCode` of the key to press.
///   - flags: The modifier flags (`CGEventFlags`) to apply (e.g., `.maskCommand`, `.maskShift`).
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func pressKey(keyCode: CGKeyCode, flags: CGEventFlags = []) throws {
    fputs("log: simulating key press: (code: \(keyCode), flags: \(flags.rawValue))\n", stderr) // Log action
    let source = try createEventSource()

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
    keyDown?.flags = flags // Apply modifier flags
    try postEvent(keyDown, actionDescription: "key down (code: \(keyCode), flags: \(flags.rawValue))")

    // Short delay between key down and key up is often necessary
    // usleep(10_000) // Delay moved into postEvent

    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    keyUp?.flags = flags // Apply modifier flags for key up as well
    try postEvent(keyUp, actionDescription: "key up (code: \(keyCode), flags: \(flags.rawValue))")
    fputs("log: key press simulation complete.\n", stderr)
}

// Builds a CGEvent for a mouse action by going through NSEvent first, so that
// Catalyst, Electron, and other UIKit-bridged apps treat it as a trusted event;
// raw CGEvent mouse synthesis is silently ignored by some of those apps.
// The location override at the end keeps top-left CGPoint semantics, since
// NSEvent uses bottom-left Cocoa coordinates which would otherwise flip y.
fileprivate func buildMouseEvent(type: NSEvent.EventType, at point: CGPoint, clickCount: Int) throws -> CGEvent {
    let isUp = (type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp)
    let nsEvent = NSEvent.mouseEvent(
        with: type,
        location: .zero,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: clickCount,
        pressure: isUp ? 0.0 : 1.0
    )
    guard let cg = nsEvent?.cgEvent else {
        throw MacosUseSDKError.inputSimulationFailed("failed to build NSEvent->CGEvent for type \(type.rawValue)")
    }
    cg.location = point
    return cg
}

/// Simulates a left mouse click at the specified screen coordinates.
/// Does not move the cursor first. Call `moveMouse` beforehand if needed.
/// - Parameter point: The `CGPoint` where the click should occur.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func clickMouse(at point: CGPoint) throws {
    fputs("log: simulating left click at: (\(point.x), \(point.y))\n", stderr)

    let down = try buildMouseEvent(type: .leftMouseDown, at: point, clickCount: 1)
    try postEvent(down, actionDescription: "mouse down at (\(point.x), \(point.y))")

    let up = try buildMouseEvent(type: .leftMouseUp, at: point, clickCount: 1)
    try postEvent(up, actionDescription: "mouse up at (\(point.x), \(point.y))")
    fputs("log: left click simulation complete.\n", stderr)
}

/// Simulates a left mouse double click at the specified screen coordinates.
/// Does not move the cursor first. Call `moveMouse` beforehand if needed.
/// - Parameter point: The `CGPoint` where the double click should occur.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func doubleClickMouse(at point: CGPoint) throws {
    fputs("log: simulating double-click at: (\(point.x), \(point.y))\n", stderr)

    let down = try buildMouseEvent(type: .leftMouseDown, at: point, clickCount: 2)
    try postEvent(down, actionDescription: "double click down at (\(point.x), \(point.y))")

    let up = try buildMouseEvent(type: .leftMouseUp, at: point, clickCount: 2)
    try postEvent(up, actionDescription: "double click up at (\(point.x), \(point.y))")
    fputs("log: double-click simulation complete.\n", stderr)
}

// Simulates a right mouse click at the specified coordinates
/// Simulates a right mouse click at the specified screen coordinates.
/// Does not move the cursor first. Call `moveMouse` beforehand if needed.
/// - Parameter point: The `CGPoint` where the right click should occur.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func rightClickMouse(at point: CGPoint) throws {
    fputs("log: simulating right-click at: (\(point.x), \(point.y))\n", stderr)

    let down = try buildMouseEvent(type: .rightMouseDown, at: point, clickCount: 1)
    try postEvent(down, actionDescription: "right mouse down at (\(point.x), \(point.y))")

    let up = try buildMouseEvent(type: .rightMouseUp, at: point, clickCount: 1)
    try postEvent(up, actionDescription: "right mouse up at (\(point.x), \(point.y))")
    fputs("log: right-click simulation complete.\n", stderr)
}

/// Moves the mouse cursor to the specified screen coordinates.
/// - Parameter point: The `CGPoint` to move the cursor to.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func moveMouse(to point: CGPoint) throws {
     fputs("log: moving mouse to: (\(point.x), \(point.y))\n", stderr) // Log action
    let source = try createEventSource()

    // .mouseMoved type doesn't require a button state
    let mouseMove = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) // Button doesn't matter for move
    try postEvent(mouseMove, actionDescription: "mouse move to (\(point.x), \(point.y))")
    fputs("log: mouse move simulation complete.\n", stderr)
}

/// Simulates a scroll wheel event at the specified screen coordinates.
/// - Parameters:
///   - point: The `CGPoint` where the scroll should occur.
///   - deltaY: Vertical scroll amount. Negative = scroll up, positive = scroll down.
///   - deltaX: Horizontal scroll amount. Negative = scroll left, positive = scroll right.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or the event cannot be posted.
public func scrollWheel(at point: CGPoint, deltaY: Int32, deltaX: Int32 = 0) throws {
    fputs("log: simulating scroll wheel at: (\(point.x), \(point.y)), deltaY: \(deltaY), deltaX: \(deltaX)\n", stderr)
    let source = try createEventSource()

    // Move cursor to the scroll target first so the scroll lands in the right view
    let mouseMove = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
    try postEvent(mouseMove, actionDescription: "mouse move for scroll to (\(point.x), \(point.y))")

    guard let scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else {
        throw MacosUseSDKError.inputSimulationFailed("failed to create scroll wheel event")
    }
    scrollEvent.location = point
    scrollEvent.post(tap: .cghidEventTap)
    usleep(15_000)
    fputs("log: scroll wheel simulation complete.\n", stderr)
}

/// Simulates typing a string of text by posting CGEvents whose unicode payload
/// is set via `CGEventKeyboardSetUnicodeString`. Unlike the previous AppleScript
/// implementation, this works in sandboxed processes, requires no Script Editor
/// consent, and does not fork-exec per call.
/// - Parameter text: The `String` to type.
/// - Throws: `MacosUseSDKError` if the event source cannot be created or events
///   cannot be posted.
public func writeText(_ text: String) throws {
    fputs("log: simulating text writing: \"\(text)\" (CGEventKeyboardSetUnicodeString)\n", stderr)
    guard !text.isEmpty else {
        fputs("log: text writing skipped (empty string).\n", stderr)
        return
    }

    let source = try createEventSource()

    // Post one keyDown/keyUp pair per scalar so each character lands as a
    // distinct event. Some text fields collapse multi-char unicode payloads
    // into a single keystroke, which breaks IME/auto-complete behavior.
    for scalar in text.unicodeScalars {
        let utf16 = Array(String(scalar).utf16)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            throw MacosUseSDKError.inputSimulationFailed("failed to create keyboard down event")
        }
        utf16.withUnsafeBufferPointer { buf in
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buf.baseAddress)
        }
        try postEvent(keyDown, actionDescription: "key down for scalar U+\(String(scalar.value, radix: 16))")

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw MacosUseSDKError.inputSimulationFailed("failed to create keyboard up event")
        }
        utf16.withUnsafeBufferPointer { buf in
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buf.baseAddress)
        }
        try postEvent(keyUp, actionDescription: "key up for scalar U+\(String(scalar.value, radix: 16))")
    }

    fputs("log: text writing simulation complete.\n", stderr)
}


// Maps common key names (case-insensitive) to their CGKeyCode. Public for potential use by the tool.
/// Maps common key names (case-insensitive) or a numeric string to their `CGKeyCode`.
/// - Parameter keyName: The name of the key (e.g., "return", "a", "esc") or a string representation of the key code number.
/// - Returns: The corresponding `CGKeyCode` or `nil` if the name is not recognized and cannot be parsed as a number.
public func mapKeyNameToKeyCode(_ keyName: String) -> CGKeyCode? {
    switch keyName.lowercased() {
        // Special Keys
        case "return", "enter": return KEY_RETURN
        case "tab": return KEY_TAB
        case "space": return KEY_SPACE
        case "delete", "backspace": return KEY_DELETE
        case "escape", "esc": return KEY_ESCAPE
        case "left", "arrowleft": return KEY_ARROW_LEFT
        case "right", "arrowright": return KEY_ARROW_RIGHT
        case "down", "arrowdown": return KEY_ARROW_DOWN
        case "up", "arrowup": return KEY_ARROW_UP
        case "pageup", "page_up", "pgup": return KEY_PAGE_UP
        case "pagedown", "page_down", "pgdn": return KEY_PAGE_DOWN
        case "home": return KEY_HOME
        case "end": return KEY_END
        case "forwarddelete", "forward_delete", "fwddelete": return KEY_FORWARD_DELETE

        // Letters (Standard US QWERTY Layout Key Codes) - Assuming US QWERTY. Might need adjustments for others.
        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "f": return 3
        case "g": return 5
        case "h": return 4
        case "i": return 34
        case "j": return 38
        case "k": return 40
        case "l": return 37
        case "m": return 46
        case "n": return 45
        case "o": return 31
        case "p": return 35
        case "q": return 12
        case "r": return 15
        case "s": return 1
        case "t": return 17
        case "u": return 32
        case "v": return 9
        case "w": return 13
        case "x": return 7
        case "y": return 16
        case "z": return 6

        // Numbers (Main Keyboard Row)
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25
        case "0": return 29

        // Symbols (Common - May vary significantly by layout)
        case "-": return 27
        case "=": return 24
        case "[": return 33
        case "]": return 30
        case "\\": return 42 // Backslash
        case ";": return 41
        case "'": return 39 // Quote
        case ",": return 43
        case ".": return 47
        case "/": return 44
        case "`": return 50 // Grave accent / Tilde

        // Function Keys
        case "f1": return 122
        case "f2": return 120
        case "f3": return 99
        case "f4": return 118
        case "f5": return 96
        case "f6": return 97
        case "f7": return 98
        case "f8": return 100
        case "f9": return 101
        case "f10": return 109
        case "f11": return 103
        case "f12": return 111
        // Add F13-F20 if needed

        default:
            // If not a known name, attempt to interpret it as a raw key code number
            fputs("log: key '\(keyName)' not explicitly mapped, attempting conversion to CGKeyCode number.\n", stderr)
            return CGKeyCode(keyName) // Returns nil if conversion fails
    }
}

// --- Removed Main Script Logic ---
// The argument parsing, switch statement, fail(), completeSuccessfully(), startTime
// and related logic have been removed from this file. They will be handled by the
// InputControllerTool executable's main.swift.

// --- Retained Helper Structures/Functions if needed by public API ---
// (e.g., mapKeyNameToKeyCode is now public)
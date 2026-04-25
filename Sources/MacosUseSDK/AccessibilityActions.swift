import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

// AX-driven write/press paths. These bypass the input event tap entirely and
// talk to the target app via the Accessibility API instead. Two cases where
// this is the only thing that works:
//   1) Catalyst right-pane controls that swallow synthetic mouse events.
//   2) Sandboxed/secure-input contexts where the HID tap is filtered.
// Both functions hit-test by point against the application's AXUIElement tree
// and operate on the deepest element under the coordinate.

fileprivate func axElement(at point: CGPoint, pid: Int32) throws -> AXUIElement {
    let appElement = AXUIElementCreateApplication(pid)
    var hit: AXUIElement?
    let err = AXUIElementCopyElementAtPosition(appElement, Float(point.x), Float(point.y), &hit)
    guard err == .success, let element = hit else {
        throw MacosUseSDKError.inputSimulationFailed(
            "no AX element at (\(point.x), \(point.y)) for pid \(pid) — AXError \(err.rawValue)"
        )
    }
    return element
}

/// Sets `kAXValueAttribute` on the AX element under `point` for the given pid.
/// Useful for filling text fields without simulating key events — works in
/// Catalyst/secure-input contexts where typing is filtered.
/// - Parameters:
///   - pid: Target application's process id.
///   - point: Top-left CGPoint of the element to target. Use coordinates from
///     a recent traversal.
///   - value: New string value to write.
/// - Throws: `MacosUseSDKError` if hit-test fails or the AX set call rejects.
public func setAccessibilityValue(pid: Int32, at point: CGPoint, value: String) throws {
    fputs("log: AX set value at (\(point.x), \(point.y)) for pid \(pid): \"\(value)\"\n", stderr)
    let element = try axElement(at: point, pid: pid)
    let err = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFString)
    guard err == .success else {
        throw MacosUseSDKError.inputSimulationFailed(
            "AXUIElementSetAttributeValue(kAXValueAttribute) failed at (\(point.x), \(point.y)) — AXError \(err.rawValue)"
        )
    }
    fputs("log: AX set value complete.\n", stderr)
}

/// Performs `kAXPressAction` on the AX element under `point` for the given
/// pid. Replaces a synthetic click for buttons, menu items, and other
/// pressable controls. Often the only thing that works for Catalyst
/// right-pane controls.
/// - Parameters:
///   - pid: Target application's process id.
///   - point: Top-left CGPoint of the element to press.
/// - Throws: `MacosUseSDKError` if hit-test fails or the action is unsupported.
public func pressAccessibilityElement(pid: Int32, at point: CGPoint) throws {
    fputs("log: AX press at (\(point.x), \(point.y)) for pid \(pid)\n", stderr)
    let element = try axElement(at: point, pid: pid)
    let err = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard err == .success else {
        throw MacosUseSDKError.inputSimulationFailed(
            "AXUIElementPerformAction(kAXPressAction) failed at (\(point.x), \(point.y)) — AXError \(err.rawValue)"
        )
    }
    fputs("log: AX press complete.\n", stderr)
}

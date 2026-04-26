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

// Reads the screen-space frame (origin top-left) of an AX element.
fileprivate func axFrame(of element: AXUIElement) -> CGRect? {
    var posVal: AnyObject?
    var sizeVal: AnyObject?
    let pErr = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal)
    let sErr = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal)
    guard pErr == .success, sErr == .success,
          let p = posVal, let s = sizeVal,
          CFGetTypeID(p) == AXValueGetTypeID(),
          CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &origin)
    AXValueGetValue(s as! AXValue, .cgSize, &size)
    return CGRect(origin: origin, size: size)
}

// Walks the application's AX tree breadth-first looking for the smallest
// element whose frame contains `point` and whose role is in `preferredRoles`
// (when provided). Falls back to the smallest containing element of any role.
//
// This exists because `AXUIElementCopyElementAtPosition` does not reliably
// penetrate into table rows in Catalyst apps; the rows are reachable by
// walking the tree but not by hit-test.
fileprivate func findAXElement(in app: AXUIElement, at point: CGPoint, preferredRoles: Set<String>, maxNodes: Int = 4000) -> AXUIElement? {
    var bestPreferred: (element: AXUIElement, area: CGFloat)? = nil
    var bestAny: (element: AXUIElement, area: CGFloat)? = nil
    var queue: [AXUIElement] = [app]
    var visited = 0
    while let current = queue.first, visited < maxNodes {
        queue.removeFirst()
        visited += 1
        if let frame = axFrame(of: current), frame.contains(point) {
            let area = frame.width * frame.height
            if let role = axRole(of: current), preferredRoles.contains(role) {
                if bestPreferred == nil || area < bestPreferred!.area {
                    bestPreferred = (current, area)
                }
            }
            if bestAny == nil || area < bestAny!.area {
                bestAny = (current, area)
            }
        }
        // Enqueue children
        var children: AnyObject?
        let cErr = AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &children)
        if cErr == .success, let arr = children as? [AXUIElement] {
            queue.append(contentsOf: arr)
        }
    }
    return bestPreferred?.element ?? bestAny?.element
}

// Returns the role of an AX element, or nil if unavailable.
fileprivate func axRole(of element: AXUIElement) -> String? {
    var role: AnyObject?
    let err = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
    guard err == .success else { return nil }
    return role as? String
}

// Walks up the AX parent chain (depth-capped) and returns the first ancestor
// whose role matches one of `targetRoles`. If none match, returns the original
// element so callers can fall back to the deepest hit.
//
// Catalyst hit-tests typically return an AXCell or AXStaticText inside a row,
// but the selectable element is the parent AXRow. This walks up to find it.
fileprivate func axAncestor(of element: AXUIElement, matching targetRoles: Set<String>, maxDepth: Int = 12) -> AXUIElement {
    if let r = axRole(of: element), targetRoles.contains(r) { return element }
    var current = element
    for _ in 0..<maxDepth {
        var parent: AnyObject?
        let err = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
        guard err == .success, let parentRef = parent, CFGetTypeID(parentRef) == AXUIElementGetTypeID() else {
            break
        }
        let parentEl = parentRef as! AXUIElement
        if let r = axRole(of: parentEl), targetRoles.contains(r) { return parentEl }
        current = parentEl
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
    // Tree-walk finder: hit-test does not penetrate into Catalyst app controls.
    let app = AXUIElementCreateApplication(pid)
    let preferredRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
    guard let element = findAXElement(in: app, at: point, preferredRoles: preferredRoles) else {
        throw MacosUseSDKError.inputSimulationFailed(
            "no value-bearing AX element found at (\(point.x), \(point.y)) for pid \(pid)"
        )
    }
    let targetRole = axRole(of: element) ?? "<unknown>"
    fputs("log: AX set value target role=\(targetRole)\n", stderr)
    let err = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFString)
    guard err == .success else {
        throw MacosUseSDKError.inputSimulationFailed(
            "AXUIElementSetAttributeValue(kAXValueAttribute) on \(targetRole) failed at (\(point.x), \(point.y)) — AXError \(err.rawValue)"
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
    // Tree-walk finder: hit-test does not penetrate into Catalyst app controls.
    let app = AXUIElementCreateApplication(pid)
    let preferredRoles: Set<String> = [
        "AXButton", "AXMenuItem", "AXRadioButton", "AXCheckBox",
        "AXMenuButton", "AXPopUpButton"
    ]
    guard let element = findAXElement(in: app, at: point, preferredRoles: preferredRoles) else {
        throw MacosUseSDKError.inputSimulationFailed(
            "no pressable AX element found at (\(point.x), \(point.y)) for pid \(pid)"
        )
    }
    let targetRole = axRole(of: element) ?? "<unknown>"
    fputs("log: AX press target role=\(targetRole)\n", stderr)
    let err = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard err == .success else {
        throw MacosUseSDKError.inputSimulationFailed(
            "AXUIElementPerformAction(kAXPressAction) on \(targetRole) failed at (\(point.x), \(point.y)) — AXError \(err.rawValue)"
        )
    }
    fputs("log: AX press complete.\n", stderr)
}

/// Sets `kAXSelectedAttribute` on the AX element under `point`. The right
/// primitive for selecting table rows, list items, sidebar entries, and
/// other selection-bearing controls in Catalyst apps where rows expose the
/// `AXSelected` attribute but no `AXPress` action.
///
/// In single-selection tables, setting this attribute typically deselects
/// any prior selection automatically; the host app reconciles the parent
/// table's `kAXSelectedRowsAttribute` in response.
/// - Parameters:
///   - pid: Target application's process id.
///   - point: Top-left CGPoint of the element to (de)select.
///   - selected: True to select, false to deselect.
/// - Throws: `MacosUseSDKError` if hit-test fails or the AX set call rejects.
public func setAccessibilitySelected(pid: Int32, at point: CGPoint, selected: Bool) throws {
    fputs("log: AX set selected=\(selected) at (\(point.x), \(point.y)) for pid \(pid)\n", stderr)
    // Catalyst hit-test is unreliable for table rows (returns the window-level
    // AXGroup, not the row). Walk the tree from the app root to find an
    // AXRow/AXOutlineRow/AXListItem whose frame contains the point.
    let app = AXUIElementCreateApplication(pid)
    let preferredRoles: Set<String> = ["AXRow", "AXOutlineRow", "AXListItem"]
    guard let target = findAXElement(in: app, at: point, preferredRoles: preferredRoles) else {
        throw MacosUseSDKError.inputSimulationFailed(
            "no selectable AX element found at (\(point.x), \(point.y)) for pid \(pid)"
        )
    }
    let targetRole = axRole(of: target) ?? "<unknown>"
    fputs("log: AX set selected target role=\(targetRole)\n", stderr)
    let value: CFBoolean = selected ? kCFBooleanTrue : kCFBooleanFalse
    let err = AXUIElementSetAttributeValue(target, kAXSelectedAttribute as CFString, value)
    guard err == .success else {
        throw MacosUseSDKError.inputSimulationFailed(
            "AXUIElementSetAttributeValue(kAXSelectedAttribute=\(selected)) on \(targetRole) failed at (\(point.x), \(point.y)) — AXError \(err.rawValue)"
        )
    }
    fputs("log: AX set selected complete.\n", stderr)
}

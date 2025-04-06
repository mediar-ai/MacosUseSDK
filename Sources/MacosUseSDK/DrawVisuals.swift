// REMOVED: #!/usr/bin/env swift
// REMOVED: import Cocoa
import AppKit
import Foundation

// Define types of visual feedback
public enum FeedbackType {
    case box(text: String) // Existing box with optional text
    case circle           // New simple circle
}

// Define a custom view that draws the rectangle and text with truncation
internal class OverlayView: NSView {
    var feedbackType: FeedbackType = .box(text: "") // Property to hold the type and data

    // Constants for drawing
    let padding: CGFloat = 3
    let frameLineWidth: CGFloat = 2
    let circleRadius: CGFloat = 15 // Radius for the circle feedback

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        switch feedbackType {
        case .box(let displayText):
            drawBox(with: displayText)
        case .circle:
            drawCircle()
        }
    }

    private func drawCircle() {
        // fputs("debug: OverlayView drawing circle\n", stderr)
        fputs("debug: Setting circle stroke color to green.\n", stderr)
        NSColor.green.setStroke()
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        // Ensure the circle fits within the bounds if bounds are smaller than diameter
        let effectiveRadius = min(circleRadius, bounds.width / 2.0, bounds.height / 2.0)
        guard effectiveRadius > 0 else { return } // Don't draw if too small

        let circleRect = NSRect(x: center.x - effectiveRadius, y: center.y - effectiveRadius,
                                width: effectiveRadius * 2, height: effectiveRadius * 2)
        let path = NSBezierPath(ovalIn: circleRect)
        path.lineWidth = frameLineWidth
        path.stroke()
    }

    private func drawBox(with displayText: String) {
        // --- Frame Drawing ---
        NSColor.red.setStroke()
        let frameInset = frameLineWidth / 2.0
        let frameRect = bounds.insetBy(dx: frameInset, dy: frameInset)
        let path = NSBezierPath(rect: frameRect)
        path.lineWidth = frameLineWidth
        path.stroke()
        // fputs("debug: OverlayView drew frame at \(frameRect)\n", stderr)

        // --- Text Drawing with Truncation ---
        if !displayText.isEmpty {
            // Define text attributes
            let textColor = NSColor.red
            // Slightly smaller font for potentially many overlays
            let textFont = NSFont.systemFont(ofSize: 10.0) // NSFont.smallSystemFontSize)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: textColor
            ]

            // Calculate available width for text (bounds - frame lines - padding on both sides)
            let availableWidth = max(0, bounds.width - (frameLineWidth * 2.0) - (padding * 2.0))
            var stringToDraw = displayText
            var textSize = stringToDraw.size(withAttributes: textAttributes)

            // Check if truncation is needed
            if textSize.width > availableWidth && availableWidth > 0 {
                 // fputs("debug: OverlayView truncating text '\(stringToDraw)' (\(textSize.width)) > available \(availableWidth)\n", stderr)
                 let ellipsis = "…" // Use ellipsis character
                 let ellipsisSize = ellipsis.size(withAttributes: textAttributes)

                 // Keep removing characters until text + ellipsis fits
                 while !stringToDraw.isEmpty && (stringToDraw.size(withAttributes: textAttributes).width + ellipsisSize.width > availableWidth) {
                     stringToDraw.removeLast()
                 }
                 stringToDraw += ellipsis
                 textSize = stringToDraw.size(withAttributes: textAttributes) // Recalculate size
                 // fputs("debug: OverlayView truncated to '\(stringToDraw)' (\(textSize.width))\n", stderr)
            }

            // Ensure text doesn't exceed available height (though less likely for small font)
            let availableHeight = max(0, bounds.height - (frameLineWidth * 2.0) - (padding * 2.0))
             if textSize.height > availableHeight {
                 // fputs("debug: OverlayView text height (\(textSize.height)) > available \(availableHeight)\n", stderr)
                 // Simple vertical clipping will occur naturally if too tall
             }

            // Calculate position to center the (potentially truncated) text
            // X: Add frame line width + padding
            // Y: Center vertically within the available height area
            let textX = frameLineWidth + padding
            let textY = frameLineWidth + padding + (availableHeight - textSize.height) // Top align
            let textPoint = NSPoint(x: textX, y: textY)

            // Draw the text string
            // fputs("debug: OverlayView drawing text '\(stringToDraw)' at \(textPoint)\n", stderr)
            (stringToDraw as NSString).draw(at: textPoint, withAttributes: textAttributes)
        } else {
             // fputs("debug: OverlayView no text to draw.\n", stderr)
        }
    }

    // Update initializer to accept FeedbackType
    init(frame frameRect: NSRect, type: FeedbackType) {
        self.feedbackType = type
        super.init(frame: frameRect)
        // fputs("debug: OverlayView initialized with frame \(frameRect) type \(type)\n", stderr)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// --- REMOVED AppDelegate Class Definition ---

// --- REMOVED Top-Level Application Entry Point Code (app creation, delegate, argument parsing, app.run) ---


// --- Internal Window Creation Helper ---
// Creates a configured, borderless overlay window but does not show it.
// ADDED: @MainActor annotation to ensure UI operations run on the main thread
@MainActor
internal func createOverlayWindow(frame: NSRect, type: FeedbackType) -> NSWindow {
    // fputs("debug: Creating overlay window with frame: \(frame), type: \(type)'\n", stderr)
    // Now safe to call NSWindow initializer and set properties from here
    let window = NSWindow(
        contentRect: frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )

    // Configuration for transparent, floating overlay
    window.isOpaque = false
    window.backgroundColor = .clear // Transparent background
    window.hasShadow = false        // No window shadow
    window.level = .floating        // Keep above normal windows
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle] // Visible on all spaces
    window.isMovableByWindowBackground = false // Prevent accidental dragging

    // Create and set the custom view
    let overlayFrame = window.contentView?.bounds ?? NSRect(origin: .zero, size: frame.size)
    let overlayView = OverlayView(frame: overlayFrame, type: type)
    window.contentView = overlayView
    // fputs("debug: Set OverlayView with frame \(overlayFrame) for window.\n", stderr)

    return window
}

// --- New Public Function for Simple Visual Feedback ---
/// Displays a temporary visual indicator (e.g., a circle) at specified screen coordinates.
/// This version includes a pulsing/fading animation.
/// - Parameters:
///   - point: The center point (`CGPoint`) in screen coordinates for the visual feedback.
///   - type: The type of feedback to display (currently only `.circle` is animated).
///   - size: The desired initial size (width/height) of the overlay window.
///   - duration: How long the feedback animation should run and the window remain visible, in seconds.
@MainActor // Ensure this runs on the main thread
public func showVisualFeedback(at point: CGPoint, type: FeedbackType = .circle, size: CGSize = CGSize(width: 30, height: 30), duration: Double = 0.5) {
    // Requires main thread for UI work
    guard Thread.isMainThread else {
        DispatchQueue.main.async {
            showVisualFeedback(at: point, type: type, size: size, duration: duration)
        }
        return
    }

    fputs("info: showVisualFeedback called for point \(point), type \(type), duration \(duration)s.\n", stderr)

    // --- Coordinate Conversion (same as before) ---
    let screenHeight = NSScreen.main?.frame.height ?? 0
    if screenHeight == 0 {
        fputs("warning: Could not get main screen height, coordinates might be incorrect.\n", stderr)
    }
    let originX = point.x - (size.width / 2.0)
    let originY = screenHeight - point.y - (size.height / 2.0)
    let frame = NSRect(x: originX, y: originY, width: size.width, height: size.height)
    fputs("debug: Creating feedback window with AppKit frame: \(frame)\n", stderr)

    // --- Create Window (same as before) ---
    let window = createOverlayWindow(frame: frame, type: type)

    // --- Make Window Visible (same as before) ---
    window.makeKeyAndOrderFront(nil)

    // --- Apply Animation (New Part) ---
    if let overlayView = window.contentView as? OverlayView, case .circle = type {
        fputs("debug: Applying pulse/fade animation to overlay layer.\n", stderr)
        overlayView.wantsLayer = true // Ensure the view has a layer for animation

        // Define the animations
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.7 // Start slightly smaller
        scaleAnimation.toValue = 1.8   // Expand larger than final size
        scaleAnimation.duration = duration // Use the feedback duration for the animation

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8 // Start mostly opaque
        opacityAnimation.toValue = 0.0   // Fade out completely
        opacityAnimation.duration = duration // Use the same duration

        // Group the animations to run simultaneously
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = duration
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut) // Makes the animation slow down towards the end
        // Keep the final state (fully transparent and scaled) until the window closes
        animationGroup.fillMode = .forwards
        animationGroup.isRemovedOnCompletion = false

        // Add the animation to the view's layer
        overlayView.layer?.add(animationGroup, forKey: "pulseFadeEffect")
    } else {
         fputs("debug: Animation skipped (not a circle or view issue).\n", stderr)
    }


    // --- Schedule Cleanup (same as before) ---
    // This now also serves to remove the window after the animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        fputs("debug: Closing feedback window after \(duration)s animation/duration.\n", stderr)
        window.close() // Closing the window removes the layer and stops the effect
    }
}

// --- Public API Function ---
/// Highlights visible accessibility elements of a target application by drawing temporary overlay windows.
///
/// This function first traverses the accessibility tree to find visible elements,
/// then creates and displays overlay windows for each element found.
/// The overlays automatically disappear after the specified duration.
///
/// - Important: This function schedules UI work on the main dispatch queue.
///              It should be called from a context where the main run loop is active (e.g., a macOS Application).
///              The function itself returns quickly with the traversal data; the overlays appear and disappear asynchronously.
///
/// - Parameter pid: The Process ID (PID) of the target application.
/// - Parameter duration: The time in seconds for which the overlay windows should be visible. Defaults to 3.0 seconds.
/// - Throws: `MacosUseSDKError` if accessibility traversal fails (e.g., permission denied, app not found).
/// - Returns: The `ResponseData` from the accessibility traversal, containing the elements that will be highlighted.
public func highlightVisibleElements(pid: Int32, duration: Double = 3.0) throws -> ResponseData {
    fputs("info: highlightVisibleElements called for PID \(pid), duration \(duration)s.\n", stderr)

    // 1. Perform Traversal to get only visible elements
    // This call is synchronous and might throw an error.
    fputs("info: Starting accessibility traversal (visible only)...\n", stderr)
    let response = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: true)
    fputs("info: Accessibility traversal completed. Found \(response.elements.count) total elements initially.\n", stderr)

    // 2. Filter elements that have geometry needed for highlighting
    let elementsToHighlight = response.elements.filter {
        $0.x != nil && $0.y != nil &&
        $0.width != nil && $0.width! > 0 &&
        $0.height != nil && $0.height! > 0
    }

    // 3. Check if there's anything to highlight
    if elementsToHighlight.isEmpty {
        fputs("info: No visible elements with valid geometry found to highlight for PID \(pid).\n", stderr)
        // Still return the response data, even if no highlights will appear.
        return response
    }

    fputs("info: Found \(elementsToHighlight.count) visible elements with geometry to highlight.\n", stderr)

    // 4. Dispatch UI work to the main thread asynchronously
    // This block will execute later on the main thread.
    DispatchQueue.main.async { // This block executes on the main actor
        var overlayWindows: [NSWindow] = []

        // Log message moved inside the async block to reflect when window creation actually starts
        fputs("info: [Main Thread] Creating \(elementsToHighlight.count) overlay windows...\n", stderr)

        // Get the main screen height for coordinate conversion
        let screenHeight = NSScreen.main?.frame.height ?? 0
        if screenHeight == 0 {
             fputs("warning: [Main Thread] Could not get main screen height, coordinates might be incorrect.\n", stderr)
        } else {
            fputs("debug: [Main Thread] Main screen height for coordinate conversion: \(screenHeight)\n", stderr)
        }


        for element in elementsToHighlight {
            // Extract coordinates and size (safe due to filter above)
            let originalX = element.x!
            let originalY = element.y!
            let elementWidth = element.width!
            let elementHeight = element.height!

            // Convert Y coordinate from top-left (Accessibility) to bottom-left (AppKit)
            let convertedY = screenHeight - originalY - elementHeight

            // Create the frame using the converted Y coordinate
            let frame = NSRect(x: originalX, y: convertedY, width: elementWidth, height: elementHeight)

            let textToShow = (element.text?.isEmpty ?? true) ? element.role : element.text!
            let feedbackType: FeedbackType = .box(text: textToShow) // Use the box type here

            // Create and store the window (requires @MainActor context)
            let window = createOverlayWindow(frame: frame, type: feedbackType) // createOverlayWindow is @MainActor
            overlayWindows.append(window)

            // Make the window visible (requires @MainActor context)
            window.makeKeyAndOrderFront(nil)
        }

        fputs("info: [Main Thread] Displaying \(overlayWindows.count) overlays for \(duration) seconds.\n", stderr)

        // 3. Schedule cleanup on the main thread after the duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            fputs("info: [Main Thread] Closing \(overlayWindows.count) overlay windows after \(duration)s duration.\n", stderr)
            for window in overlayWindows {
                window.close()
            }
        }
    } // End of DispatchQueue.main.async block

    // 5. Return the traversal response immediately after dispatching UI work
    fputs("info: highlightVisibleElements finished synchronous part, returning traversal data. UI updates dispatched.\n", stderr)
    return response
}
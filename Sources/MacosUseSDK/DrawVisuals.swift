// REMOVED: #!/usr/bin/env swift
// REMOVED: import Cocoa
import AppKit
import Foundation

// Define types of visual feedback
public enum FeedbackType {
    case box(text: String) // Existing box with optional text
    case circle           // New simple circle
    case caption(text: String) // New type for large screen-center text
}

// Define a custom view that draws the rectangle and text with truncation
internal class OverlayView: NSView {
    var feedbackType: FeedbackType = .box(text: "") // Property to hold the type and data

    // Constants for drawing
    let padding: CGFloat = 10 // Increased padding for caption
    let frameLineWidth: CGFloat = 2
    let circleRadius: CGFloat = 15 // Radius for the circle feedback
    let captionFontSize: CGFloat = 36 // Font size for caption
    let captionBackgroundColor = NSColor.black.withAlphaComponent(0.6) // Semi-transparent black background
    let captionTextColor = NSColor.white

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        switch feedbackType {
        case .box(let displayText):
            drawBox(with: displayText)
        case .circle:
            drawCircle()
        case .caption(let captionText):
            drawCaption(with: captionText) // Call the new drawing method
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

    // New method to draw the caption
    private func drawCaption(with text: String) {
        fputs("debug: OverlayView drawing caption: '\(text)'\n", stderr)

        // Draw background
        captionBackgroundColor.setFill()
        let backgroundRect = bounds.insetBy(dx: frameLineWidth / 2.0, dy: frameLineWidth / 2.0) // Adjust for potential border line width if we add one later
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 8, yRadius: 8) // Rounded corners
        backgroundPath.fill()

        // --- Text Drawing ---
        if !text.isEmpty {
            // Define text attributes
            let textFont = NSFont.systemFont(ofSize: captionFontSize, weight: .medium)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center // Center align text

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: captionTextColor,
                .paragraphStyle: paragraphStyle
            ]

            // Calculate available area for text (bounds - padding)
            let availableRect = bounds.insetBy(dx: padding, dy: padding)
            var stringToDraw = text
            var textSize = stringToDraw.size(withAttributes: textAttributes)

            // Basic truncation if text wider than available space (though less likely for centered captions)
             if textSize.width > availableRect.width && availableRect.width > 0 {
                 fputs("warning: Caption text '\(stringToDraw)' (\(textSize.width)) wider than available \(availableRect.width), may clip.\n", stderr)
                 // Simple clipping will occur, could implement more complex truncation if needed
             }
             if textSize.height > availableRect.height {
                  fputs("warning: Caption text '\(stringToDraw)' (\(textSize.height)) taller than available \(availableRect.height), may clip.\n", stderr)
             }

            // Calculate position to center the text vertically and horizontally within the available rect
             let textX = availableRect.origin.x
             let textY = availableRect.origin.y + (availableRect.height - textSize.height) / 2.0 // Center vertically
             let textRect = NSRect(x: textX, y: textY, width: availableRect.width, height: textSize.height)


            // Draw the text string centered
            fputs("debug: OverlayView drawing caption text '\(stringToDraw)' in rect \(textRect)\n", stderr)
            (stringToDraw as NSString).draw(in: textRect, withAttributes: textAttributes)
        } else {
             fputs("debug: OverlayView no caption text to draw.\n", stderr)
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
    fputs("debug: Creating overlay window with frame: \(frame), type: \(type)\n", stderr) // Log includes type now
    // Now safe to call NSWindow initializer and set properties from here
    let window = NSWindow(
        contentRect: frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )

    // Configuration for transparent, floating overlay
    window.isOpaque = false
    // Make background clear ONLY if not a caption (caption view draws its own background)
    if case .caption = type {
        window.backgroundColor = .clear // View draws background
    } else {
        window.backgroundColor = .clear // Original behavior
    }
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
/// Displays a temporary visual indicator (e.g., a circle, a caption) at specified screen coordinates.
/// This version includes a pulsing/fading animation for circles. Captions simply appear and disappear.
/// - Parameters:
///   - point: The center point (`CGPoint`) in screen coordinates for the visual feedback. For captions, this is usually the screen center.
///   - type: The type of feedback to display (`FeedbackType`).
///   - size: The desired size (width/height) of the overlay window. Defaults work for circle, consider larger for captions.
///   - duration: How long the feedback should remain visible, in seconds.
@MainActor // Ensure this runs on the main thread
public func showVisualFeedback(at point: CGPoint, type: FeedbackType, size: CGSize = CGSize(width: 30, height: 30), duration: Double = 0.5) {
    // Requires main thread for UI work
    guard Thread.isMainThread else {
        fputs("warning: showVisualFeedback called off main thread, dispatching. Point: \(point), Type: \(type)\n", stderr)
        DispatchQueue.main.async {
            showVisualFeedback(at: point, type: type, size: size, duration: duration)
        }
        return
    }

    fputs("info: showVisualFeedback called for point \(point), type \(type), size \(size), duration \(duration)s.\n", stderr)

    // --- Coordinate Conversion (Using AppKit bottom-left origin) ---
    // Screen height is needed to convert the Y coordinate.
    let screenHeight = NSScreen.main?.frame.height ?? 0
    if screenHeight == 0 {
        fputs("warning: Could not get main screen height, coordinates might be incorrect.\n", stderr)
    }
    // Calculate origin based on the center point provided
    let originX = point.x - (size.width / 2.0)
    let originY = screenHeight - point.y - (size.height / 2.0) // Convert Y from top-left to bottom-left
    let frame = NSRect(x: originX, y: originY, width: size.width, height: size.height)
    fputs("debug: Creating feedback window with AppKit frame: \(frame)\n", stderr)

    // --- Create Window ---
    let window = createOverlayWindow(frame: frame, type: type)

    // --- Make Window Visible ---
    window.makeKeyAndOrderFront(nil)

    // --- Apply Animation (Only for Circle or Caption Type) ---
    if let overlayView = window.contentView as? OverlayView {
        overlayView.wantsLayer = true // Ensure the view has a layer for animation

        if case .circle = type {
            fputs("debug: Applying pulse/fade animation to circle overlay layer.\n", stderr)
            // --- Circle Pulse/Fade Animation ---
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.7
            scaleAnimation.toValue = 1.8
            scaleAnimation.duration = duration

            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.8
            opacityAnimation.toValue = 0.0
            opacityAnimation.duration = duration

            let animationGroup = CAAnimationGroup()
            animationGroup.animations = [scaleAnimation, opacityAnimation]
            animationGroup.duration = duration
            animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animationGroup.fillMode = .forwards
            animationGroup.isRemovedOnCompletion = false
            overlayView.layer?.add(animationGroup, forKey: "pulseFadeEffect")

        } else if case .caption = type {
             fputs("debug: Applying entrance and fade-out animations to caption overlay layer.\n", stderr)

             // --- Caption Entrance Animation (Scale Up & Fade In) ---
             let entranceDuration = 0.2 // Duration for the entrance effect
             let scaleInAnimation = CABasicAnimation(keyPath: "transform.scale")
             scaleInAnimation.fromValue = 0.7 // Start slightly smaller
             scaleInAnimation.toValue = 1.0   // Scale to normal size
             scaleInAnimation.duration = entranceDuration

             let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
             fadeInAnimation.fromValue = 0.0 // Start fully transparent
             fadeInAnimation.toValue = 1.0   // Fade to fully opaque
             fadeInAnimation.duration = entranceDuration

             let entranceGroup = CAAnimationGroup()
             entranceGroup.animations = [scaleInAnimation, fadeInAnimation]
             entranceGroup.duration = entranceDuration
             entranceGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
             // `fillMode = .backwards` ensures the initial state (small, transparent) is applied *before* the animation starts
             entranceGroup.fillMode = .backwards
             // `isRemovedOnCompletion = true` (default) is fine here, we want the layer's normal state after entrance.
             overlayView.layer?.add(entranceGroup, forKey: "captionEntranceEffect")


             // --- Caption Fade-Out Animation (Starts near the end) ---
             let fadeOutDuration = 0.3 // Duration of the fade-out
             // Ensure fade-out doesn't start before entrance completes if total duration is very short
             let fadeOutStartTime = max(entranceDuration, duration - fadeOutDuration)

             let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
             fadeOutAnimation.fromValue = 1.0 // Start opaque
             fadeOutAnimation.toValue = 0.0   // Fade to transparent
             fadeOutAnimation.duration = fadeOutDuration
             // Use CACurrentMediaTime() + delay to schedule the start
             fadeOutAnimation.beginTime = CACurrentMediaTime() + fadeOutStartTime
             fadeOutAnimation.fillMode = .forwards // Keep final state (transparent)
             fadeOutAnimation.isRemovedOnCompletion = false // Don't remove until window closes
             overlayView.layer?.add(fadeOutAnimation, forKey: "captionFadeOut")

        } else {
            // Log if a type is added that doesn't have specific animation handling
            fputs("debug: Animation skipped (unhandled FeedbackType or view issue).\n", stderr)
        }
    } else {
        // Log if contentView isn't the expected OverlayView or is nil
         fputs("warning: Could not get OverlayView from window content for animation.\n", stderr)
    }


    // --- Schedule Cleanup ---
    // Closes the window after the specified duration.
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        // Check if the window still exists before trying to close it
        // (Could potentially be closed manually or by other means, though unlikely here)
        if window.isVisible {
             fputs("debug: Closing feedback window after \(duration)s duration. Type: \(type)\n", stderr)
             window.close() // Closing the window removes the layer and stops any running animations implicitly.
        } else {
             fputs("debug: Feedback window already closed before cleanup timer fired. Type: \(type)\n", stderr)
        }
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
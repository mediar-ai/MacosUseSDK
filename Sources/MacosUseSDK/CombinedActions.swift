import Foundation // Needed for fputs, etc.
import CoreGraphics // Needed for CGPoint, CGKeyCode, CGEventFlags
import AppKit // For AXUIElement related constants potentially used indirectly, MainActor

/// Represents the difference between two accessibility traversals.
/// Currently focuses on elements added or removed. Detecting modifications
/// to existing elements is complex without stable identifiers.
public struct TraversalDiff: Codable {
    public let added: [ElementData]
    public let removed: [ElementData]
    // Future potential: public let modified: [ (before: ElementData, after: ElementData) ]
}

/// Holds the results of an action performed between two accessibility traversals,
/// including the state before, the state after, and the calculated difference.
public struct ActionDiffResult: Codable {
    public let beforeAction: ResponseData
    public let afterAction: ResponseData
    public let diff: TraversalDiff
}

/// Result type for `open(...).executeAndTraverse()`.
public struct OpenAndTraverseResult: Codable {
    public let openResult: AppOpenerResult
    public let traversalResult: ResponseData
}

/// Shared configuration options for action builders.
internal struct ActionBuilderConfig {
    var pid: Int32? = nil // PID is often needed, but not always set initially (e.g., for Open)
    var onlyVisibleElements: Bool = false
    var visualizeAction: Bool = false
    var actionVisualizationDuration: Double = 0.5 // Default duration for action pulse
    var highlightTraversalResults: Bool = false
    var traversalHighlightDuration: Double = 3.0 // Default duration for highlighting elements
    var delayAfterActionNano: UInt64 = 100_000_000 // 100 ms default

    // Method to potentially update PID if discovered later (e.g., after open)
    mutating func updatePID(_ newPID: Int32) {
        if self.pid == nil {
            self.pid = newPID
            fputs("debug: ActionBuilderConfig updated PID to \(newPID)\n", stderr)
        } else if self.pid != newPID {
             fputs("warning: ActionBuilderConfig ignoring attempt to overwrite existing PID \(self.pid!) with \(newPID)\n", stderr)
        }
    }
}

// --- Click Action ---
@MainActor // Builders initiating UI work should be on main actor
public struct ClickActionBuilder {
    private let point: CGPoint
    private var config: ActionBuilderConfig

    internal init(point: CGPoint, pid: Int32) {
        self.point = point
        self.config = ActionBuilderConfig(pid: pid)
        fputs("info: ClickActionBuilder initialized for PID \(pid) at (\(point.x), \(point.y))\n", stderr)
    }

    // --- Configuration Methods ---
    public func visualizeAction(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.visualizeAction = true
        if let duration = duration {
            newBuilder.config.actionVisualizationDuration = duration
        }
        fputs("debug: ClickActionBuilder configured visualizeAction=true (duration: \(newBuilder.config.actionVisualizationDuration)s)\n", stderr)
        return newBuilder
    }

    public func visibleElementsOnly() -> Self {
        var newBuilder = self
        newBuilder.config.onlyVisibleElements = true
        fputs("debug: ClickActionBuilder configured onlyVisibleElements=true\n", stderr)
        return newBuilder
    }

    public func highlightResults(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.highlightTraversalResults = true
        if let duration = duration {
            newBuilder.config.traversalHighlightDuration = duration
        }
        fputs("debug: ClickActionBuilder configured highlightResults=true (duration: \(newBuilder.config.traversalHighlightDuration)s)\n", stderr)
        return newBuilder
    }

     public func delayAfterAction(nanoseconds: UInt64) -> Self {
        var newBuilder = self
        newBuilder.config.delayAfterActionNano = nanoseconds
        fputs("debug: ClickActionBuilder configured delayAfterActionNano=\(nanoseconds)\n", stderr)
        return newBuilder
    }

    // --- Execution Methods ---

    /// Executes the click action only.
    public func execute() async throws {
        guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for click execution") } // Should be set by init
        fputs("info: ClickActionBuilder executing click (visualize: \(config.visualizeAction)) for PID \(pid) at (\(point.x), \(point.y))\n", stderr)

        if config.visualizeAction {
            try clickMouseAndVisualize(at: point, duration: config.actionVisualizationDuration)
            // Small delay often needed after visualization dispatch
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        } else {
            try clickMouse(at: point)
        }
         fputs("info: ClickActionBuilder execute finished.\n", stderr)
    }

    /// Executes the click action, waits, then performs a traversal.
    public func executeAndTraverse() async throws -> ResponseData {
        guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for click+traverse execution") }
         fputs("info: ClickActionBuilder executing click, then traversing (visualize: \(config.visualizeAction), highlight: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)

        // 1. Perform Action
        try await execute() // Use the simple execute method first

        // 2. Wait
        fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after click...\n", stderr)
        try await Task.sleep(nanoseconds: config.delayAfterActionNano)

        // 3. Perform Traversal (potentially with highlight)
        fputs("info: ClickActionBuilder initiating traversal (highlight: \(config.highlightTraversalResults))...\n", stderr)
        let traversalResult: ResponseData
        if config.highlightTraversalResults {
            // highlightVisibleElements inherently uses onlyVisibleElements=true, matching the name.
            // If flexibility needed later, highlightVisibleElements might need an 'onlyVisible' param.
             if !config.onlyVisibleElements {
                 fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr)
             }
            traversalResult = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
        } else {
            traversalResult = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
        }
        fputs("info: ClickActionBuilder executeAndTraverse finished.\n", stderr)
        return traversalResult
    }

    /// Executes a traversal, the click action, waits, then performs a second traversal and returns the diff.
    public func executeAndDiff() async throws -> ActionDiffResult {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for click+diff execution") }
         fputs("info: ClickActionBuilder executing diff (visualize: \(config.visualizeAction), highlightAfter: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)

        // 1. Traverse Before
        fputs("info: ClickActionBuilder traversing before action...\n", stderr)
        let beforeTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
        fputs("info: ClickActionBuilder traversal before completed.\n", stderr)

        // 2. Perform Action
        try await execute() // Use the simple execute method

        // 3. Wait
        fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after click...\n", stderr)
        try await Task.sleep(nanoseconds: config.delayAfterActionNano)

        // 4. Traverse After (potentially with highlight)
        fputs("info: ClickActionBuilder initiating traversal after action (highlight: \(config.highlightTraversalResults))...\n", stderr)
        let afterTraversal: ResponseData
        if config.highlightTraversalResults {
             if !config.onlyVisibleElements {
                 fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr)
             }
            afterTraversal = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
        } else {
            afterTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
        }
        fputs("info: ClickActionBuilder traversal after completed.\n", stderr)

        // 5. Calculate Diff
        fputs("info: ClickActionBuilder calculating diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: ClickActionBuilder diff calculation finished.\n", stderr)

        // 6. Return Result
        let result = ActionDiffResult(
            beforeAction: beforeTraversal, // Include before state
            afterAction: afterTraversal,
            diff: diff
        )
        fputs("info: ClickActionBuilder executeAndDiff finished.\n", stderr)
        return result
    }
}

// --- Type Action Builder (Similar Structure) ---
@MainActor
public struct TypeActionBuilder {
    private let text: String
    private var config: ActionBuilderConfig

    internal init(text: String, pid: Int32) {
        self.text = text
        self.config = ActionBuilderConfig(pid: pid)
        fputs("info: TypeActionBuilder initialized for PID \(pid) with text \"\(text)\"\n", stderr)
    }

    // --- Configuration Methods (visualize, visibleOnly, highlight, delay) ---
    // Example:
    public func visualizeAction(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.visualizeAction = true
        if let duration = duration {
            newBuilder.config.actionVisualizationDuration = duration
        }
         fputs("debug: TypeActionBuilder configured visualizeAction=true (duration: \(newBuilder.config.actionVisualizationDuration)s)\n", stderr)
        // Currently writeTextAndVisualize has no visual effect, but we keep the option
        return newBuilder
    }
     public func visibleElementsOnly() -> Self {
        var newBuilder = self
        newBuilder.config.onlyVisibleElements = true
        fputs("debug: TypeActionBuilder configured onlyVisibleElements=true\n", stderr)
        return newBuilder
    }
     public func highlightResults(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.highlightTraversalResults = true
        if let duration = duration {
            newBuilder.config.traversalHighlightDuration = duration
        }
        fputs("debug: TypeActionBuilder configured highlightResults=true (duration: \(newBuilder.config.traversalHighlightDuration)s)\n", stderr)
        return newBuilder
    }
      public func delayAfterAction(nanoseconds: UInt64) -> Self {
        var newBuilder = self
        newBuilder.config.delayAfterActionNano = nanoseconds
        fputs("debug: TypeActionBuilder configured delayAfterActionNano=\(nanoseconds)\n", stderr)
        return newBuilder
    }
    // Add visibleElementsOnly, highlightResults, delayAfterAction...

    // --- Execution Methods ---
    public func execute() async throws {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for type execution") }
         fputs("info: TypeActionBuilder executing type (visualize: \(config.visualizeAction)) for PID \(pid)\n", stderr)
        if config.visualizeAction {
            try writeTextAndVisualize(text, duration: config.actionVisualizationDuration) // Visualize call, even if no-op visually
        } else {
            try writeText(text)
        }
         fputs("info: TypeActionBuilder execute finished.\n", stderr)
    }

    public func executeAndTraverse() async throws -> ResponseData {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for type+traverse execution") }
         fputs("info: TypeActionBuilder executing type, then traversing (visualize: \(config.visualizeAction), highlight: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
        try await execute()
        fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after type...\n", stderr)
        try await Task.sleep(nanoseconds: config.delayAfterActionNano)
        fputs("info: TypeActionBuilder initiating traversal (highlight: \(config.highlightTraversalResults))...\n", stderr)
         let traversalResult: ResponseData
        if config.highlightTraversalResults {
             if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
            traversalResult = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
        } else {
            traversalResult = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
        }
         fputs("info: TypeActionBuilder executeAndTraverse finished.\n", stderr)
        return traversalResult
    }

    public func executeAndDiff() async throws -> ActionDiffResult {
        guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for type+diff execution") }
        fputs("info: TypeActionBuilder executing diff (visualize: \(config.visualizeAction), highlightAfter: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
        fputs("info: TypeActionBuilder traversing before action...\n", stderr)
        let beforeTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
        fputs("info: TypeActionBuilder traversal before completed.\n", stderr)
        try await execute()
        fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after type...\n", stderr)
        try await Task.sleep(nanoseconds: config.delayAfterActionNano)
        fputs("info: TypeActionBuilder initiating traversal after action (highlight: \(config.highlightTraversalResults))...\n", stderr)
         let afterTraversal: ResponseData
         if config.highlightTraversalResults {
              if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
             afterTraversal = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
         } else {
             afterTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
         }
         fputs("info: TypeActionBuilder traversal after completed.\n", stderr)
         fputs("info: TypeActionBuilder calculating diff...\n", stderr)
        let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
        fputs("info: TypeActionBuilder diff calculation finished.\n", stderr)
        let result = ActionDiffResult(beforeAction: beforeTraversal, afterAction: afterTraversal, diff: diff)
        fputs("info: TypeActionBuilder executeAndDiff finished.\n", stderr)
        return result
    }
}

// --- PressKey Action Builder (Similar Structure) ---
    @MainActor
public struct PressKeyActionBuilder {
    private let keyCode: CGKeyCode
    private let flags: CGEventFlags
    private var config: ActionBuilderConfig

     internal init(keyCode: CGKeyCode, flags: CGEventFlags = [], pid: Int32) {
        self.keyCode = keyCode
        self.flags = flags
        self.config = ActionBuilderConfig(pid: pid)
        fputs("info: PressKeyActionBuilder initialized for PID \(pid) (key: \(keyCode), flags: \(flags.rawValue))\n", stderr)
    }

    // --- Configuration Methods (visualize, visibleOnly, highlight, delay) ---
     public func visualizeAction(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.visualizeAction = true
        if let duration = duration {
            newBuilder.config.actionVisualizationDuration = duration
        }
         fputs("debug: PressKeyActionBuilder configured visualizeAction=true (duration: \(newBuilder.config.actionVisualizationDuration)s)\n", stderr)
         // Currently pressKeyAndVisualize has no visual effect
        return newBuilder
    }
      public func visibleElementsOnly() -> Self {
        var newBuilder = self
        newBuilder.config.onlyVisibleElements = true
        fputs("debug: PressKeyActionBuilder configured onlyVisibleElements=true\n", stderr)
        return newBuilder
    }
       public func highlightResults(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.highlightTraversalResults = true
        if let duration = duration {
            newBuilder.config.traversalHighlightDuration = duration
        }
        fputs("debug: PressKeyActionBuilder configured highlightResults=true (duration: \(newBuilder.config.traversalHighlightDuration)s)\n", stderr)
        return newBuilder
    }
        public func delayAfterAction(nanoseconds: UInt64) -> Self {
        var newBuilder = self
        newBuilder.config.delayAfterActionNano = nanoseconds
        fputs("debug: PressKeyActionBuilder configured delayAfterActionNano=\(nanoseconds)\n", stderr)
        return newBuilder
    }
    // ...

    // --- Execution Methods (execute, executeAndTraverse, executeAndDiff) ---
    public func execute() async throws {
         fputs("info: PressKeyActionBuilder executing pressKey (visualize: \(config.visualizeAction))\n", stderr)
        if config.visualizeAction {
            try pressKeyAndVisualize(keyCode: keyCode, flags: flags, duration: config.actionVisualizationDuration)
        } else {
            try pressKey(keyCode: keyCode, flags: flags)
        }
         fputs("info: PressKeyActionBuilder execute finished.\n", stderr)
    }

     public func executeAndTraverse() async throws -> ResponseData {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for pressKey+traverse execution") }
         fputs("info: PressKeyActionBuilder executing pressKey, then traversing (visualize: \(config.visualizeAction), highlight: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
         try await execute()
         fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after pressKey...\n", stderr)
         try await Task.sleep(nanoseconds: config.delayAfterActionNano)
         fputs("info: PressKeyActionBuilder initiating traversal (highlight: \(config.highlightTraversalResults))...\n", stderr)
         let traversalResult: ResponseData
         if config.highlightTraversalResults {
              if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
             traversalResult = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
         } else {
             traversalResult = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
         }
          fputs("info: PressKeyActionBuilder executeAndTraverse finished.\n", stderr)
         return traversalResult
    }

     public func executeAndDiff() async throws -> ActionDiffResult {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for pressKey+diff execution") }
         fputs("info: PressKeyActionBuilder executing diff (visualize: \(config.visualizeAction), highlightAfter: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
         fputs("info: PressKeyActionBuilder traversing before action...\n", stderr)
         let beforeTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
         fputs("info: PressKeyActionBuilder traversal before completed.\n", stderr)
         try await execute()
         fputs("info: Waiting \(Double(config.delayAfterActionNano) / 1_000_000_000.0) seconds after pressKey...\n", stderr)
         try await Task.sleep(nanoseconds: config.delayAfterActionNano)
         fputs("info: PressKeyActionBuilder initiating traversal after action (highlight: \(config.highlightTraversalResults))...\n", stderr)
          let afterTraversal: ResponseData
          if config.highlightTraversalResults {
               if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
              afterTraversal = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
          } else {
              afterTraversal = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
          }
          fputs("info: PressKeyActionBuilder traversal after completed.\n", stderr)
          fputs("info: PressKeyActionBuilder calculating diff...\n", stderr)
         let diff = calculateDiff(beforeElements: beforeTraversal.elements, afterElements: afterTraversal.elements)
         fputs("info: PressKeyActionBuilder diff calculation finished.\n", stderr)
         let result = ActionDiffResult(beforeAction: beforeTraversal, afterAction: afterTraversal, diff: diff)
         fputs("info: PressKeyActionBuilder executeAndDiff finished.\n", stderr)
         return result
    }
    // ...
}

// --- Open Action Builder ---
@MainActor
public struct OpenActionBuilder {
    private let identifier: String
    private var config: ActionBuilderConfig // PID is initially nil

     internal init(identifier: String) {
        self.identifier = identifier
        self.config = ActionBuilderConfig() // PID starts nil
        fputs("info: OpenActionBuilder initialized for identifier \"\(identifier)\"\n", stderr)
    }

    // --- Configuration Methods (visibleOnly, highlight, delay) ---
    // Note: visualizeAction doesn't apply to 'open' itself.
      public func visibleElementsOnly() -> Self {
        var newBuilder = self
        newBuilder.config.onlyVisibleElements = true
        fputs("debug: OpenActionBuilder configured onlyVisibleElements=true\n", stderr)
        return newBuilder
    }
       public func highlightResults(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.highlightTraversalResults = true
        if let duration = duration {
            newBuilder.config.traversalHighlightDuration = duration
        }
        fputs("debug: OpenActionBuilder configured highlightResults=true (duration: \(newBuilder.config.traversalHighlightDuration)s)\n", stderr)
        return newBuilder
    }
     // Delay doesn't make sense *before* execute, maybe after if needed, but less common for 'open'.

    // --- Execution Methods ---
    public func execute() async throws -> AppOpenerResult {
         fputs("info: OpenActionBuilder executing open for \"\(identifier)\"...\n", stderr)
        let result = try await openApplication(identifier: identifier)
        // Update config PID *after* opening, in case it's used by subsequent chained methods (though less common for open)
        // config.updatePID(result.pid) // Modifying self requires mutating func, builder pattern usually returns new instances. Less critical here.
        fputs("info: OpenActionBuilder execute finished (PID: \(result.pid)).\n", stderr)
        return result
    }

    public func executeAndTraverse() async throws -> OpenAndTraverseResult {
         fputs("info: OpenActionBuilder executing open, then traversing (highlight: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
         // 1. Open App
        let openResult = try await execute() // Use simple execute first
        let pid = openResult.pid // Get the PID

        // 2. Wait (Optional small delay after activation)
        try await Task.sleep(nanoseconds: config.delayAfterActionNano) // Use the standard delay

        // 3. Traverse
         fputs("info: OpenActionBuilder initiating traversal for PID \(pid) (highlight: \(config.highlightTraversalResults))...\n", stderr)
         let traversalResult: ResponseData
         if config.highlightTraversalResults {
              if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
             traversalResult = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
         } else {
             traversalResult = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
         }
         fputs("info: OpenActionBuilder traversal finished.\n", stderr)

        // 4. Return Combined Result
         let combinedResult = OpenAndTraverseResult(openResult: openResult, traversalResult: traversalResult)
         fputs("info: OpenActionBuilder executeAndTraverse finished.\n", stderr)
        return combinedResult
    }
     // executeAndDiff doesn't make sense for 'open' as there's no state *before* the app is open.
}

// --- Traverse Action Builder ---
@MainActor
public struct TraverseActionBuilder {
    private var config: ActionBuilderConfig

     internal init(pid: Int32) {
        self.config = ActionBuilderConfig(pid: pid)
        fputs("info: TraverseActionBuilder initialized for PID \(pid)\n", stderr)
    }

    // --- Configuration Methods ---
      public func visibleElementsOnly() -> Self {
        var newBuilder = self
        newBuilder.config.onlyVisibleElements = true
         fputs("debug: TraverseActionBuilder configured onlyVisibleElements=true\n", stderr)
        return newBuilder
    }
       public func highlightResults(duration: Double? = nil) -> Self {
        var newBuilder = self
        newBuilder.config.highlightTraversalResults = true
        if let duration = duration {
            newBuilder.config.traversalHighlightDuration = duration
        }
        fputs("debug: TraverseActionBuilder configured highlightResults=true (duration: \(newBuilder.config.traversalHighlightDuration)s)\n", stderr)
        return newBuilder
    }
    // No visualizeAction or delayAfterAction for simple traversal

    // --- Execution Method ---
    public func execute() throws -> ResponseData {
         guard let pid = config.pid else { throw MacosUseSDKError.internalError("PID missing for traverse execution") }
         fputs("info: TraverseActionBuilder executing traversal (highlight: \(config.highlightTraversalResults), visibleOnly: \(config.onlyVisibleElements))\n", stderr)
         let traversalResult: ResponseData
         if config.highlightTraversalResults {
              if !config.onlyVisibleElements { fputs("warning: highlightResults=true forces visibleElementsOnly=true for highlighting.\n", stderr) }
             traversalResult = try highlightVisibleElements(pid: pid, duration: config.traversalHighlightDuration)
         } else {
             // NOTE: traverseAccessibilityTree is NOT async, so the `throws` is sufficient
             traversalResult = try traverseAccessibilityTree(pid: pid, onlyVisibleElements: config.onlyVisibleElements)
         }
         fputs("info: TraverseActionBuilder execute finished.\n", stderr)
         return traversalResult
    }
}

// --- Define the Namespace Enum ---
// This MUST come BEFORE the extension below.
public enum MacosUseSDK {
    // This enum exists purely to provide a namespace for the static functions.
}

// --- Static Entry Points Extension ---
// Now this extension can find the MacosUseSDK enum defined above.
public extension MacosUseSDK {
    /// Initiates a click action builder.
    @MainActor
    static func click(at point: CGPoint, pid: Int32) -> ClickActionBuilder {
        return ClickActionBuilder(point: point, pid: pid)
    }

    /// Initiates a type action builder.
    @MainActor
    static func type(_ text: String, pid: Int32) -> TypeActionBuilder {
        return TypeActionBuilder(text: text, pid: pid)
    }

    /// Initiates a key press action builder.
    @MainActor
    static func pressKey(keyCode: CGKeyCode, flags: CGEventFlags = [], pid: Int32) -> PressKeyActionBuilder {
        return PressKeyActionBuilder(keyCode: keyCode, flags: flags, pid: pid)
    }

    /// Initiates an application open/activate action builder.
    @MainActor
    static func open(_ identifier: String) -> OpenActionBuilder {
        return OpenActionBuilder(identifier: identifier)
    }

    /// Initiates an accessibility traversal action builder.
    @MainActor
    static func traverse(pid: Int32) -> TraverseActionBuilder {
        return TraverseActionBuilder(pid: pid)
    }
}

    /// Calculates the difference between two sets of ElementData based on set operations.
    /// - Parameters:
    ///   - beforeElements: The list of elements from the first traversal.
    ///   - afterElements: The list of elements from the second traversal.
    /// - Returns: A `TraversalDiff` struct containing added and removed elements.
fileprivate func calculateDiff(beforeElements: [ElementData], afterElements: [ElementData]) -> TraversalDiff {
        fputs("debug: calculating diff between \(beforeElements.count) (before) and \(afterElements.count) (after) elements.\n", stderr)
        // Convert arrays to Sets for efficient comparison. Relies on ElementData being Hashable.
        let beforeSet = Set(beforeElements)
        let afterSet = Set(afterElements)

        // Elements present in 'after' but not in 'before' are added.
        let addedElements = Array(afterSet.subtracting(beforeSet))
        fputs("debug: diff calculation - found \(addedElements.count) added elements.\n", stderr)

        // Elements present in 'before' but not in 'after' are removed.
        let removedElements = Array(beforeSet.subtracting(afterSet))
        fputs("debug: diff calculation - found \(removedElements.count) removed elements.\n", stderr)

        // Sort results for consistent output (optional, but helpful)
        let sortedAdded = addedElements.sorted(by: elementSortPredicate)
        let sortedRemoved = removedElements.sorted(by: elementSortPredicate)


        return TraversalDiff(added: sortedAdded, removed: sortedRemoved)
    }

    // Helper sorting predicate (consistent with AccessibilityTraversalOperation)
fileprivate var elementSortPredicate: (ElementData, ElementData) -> Bool {
        return { e1, e2 in
            let y1 = e1.y ?? Double.greatestFiniteMagnitude
            let y2 = e2.y ?? Double.greatestFiniteMagnitude
            if y1 != y2 { return y1 < y2 }
            let x1 = e1.x ?? Double.greatestFiniteMagnitude
            let x2 = e2.x ?? Double.greatestFiniteMagnitude
            return x1 < x2
        }
}

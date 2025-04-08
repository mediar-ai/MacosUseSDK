import MacosUseSDK
import Foundation // For exit, FileHandle
import CoreGraphics // For CGPoint, CGEventFlags

// Use @main struct for async top-level code
@main
struct ActionTool {

    static func main() async {
        fputs("info: ActionTool started.\n", stderr)

        // --- Example 1: Open Messages, Type, Traverse with Diff ---
        let textEditAction = PrimaryAction.open(identifier: "Messages") // Changed to TextEdit for typing example

        let openOptions = ActionOptions(
            traverseBefore: true, // Keep true for diff
            traverseAfter: true,  // Keep true for diff
            showDiff: false,      // Set to false for open, true for type
            onlyVisibleElements: true,
            showAnimation: false, // Use the consolidated flag
            delayAfterAction: 0.0 // No extra delay needed immediately after open, before next step
        )

        fputs("\n--- Running Example 1: Open TextEdit ---\n", stderr)
        let openResult = await performAction(action: textEditAction, optionsInput: openOptions)

        if let pid = openResult.openResult?.pid, openResult.primaryActionError == nil {
            fputs("info: TextEdit opened/activated (PID: \(pid)). Now preparing to type...\n", stderr)

            // --- Options for TYPE Action ---
            let typeAction = PrimaryAction.input(action: .type(text: "Hello world from ActionTool!"))
            let typeOptions = ActionOptions(
                traverseBefore: true,        // Need before state for diff
                traverseAfter: true,         // Need after state for diff
                showDiff: true,              // Calculate the diff after typing
                onlyVisibleElements: true,
                showAnimation: true,         // Use the consolidated flag
                animationDuration: 0.8,      // Duration for animation/highlight
                pidForTraversal: pid,        // <<-- IMPORTANT: Use the PID from the open result
                delayAfterAction: 0.0        // Delay *after* typing, *before* the 'traverseAfter' step, good if we need to wait for application to render updated UI, first try without it
            )

            fputs("\n--- Running Example 1: Type into TextEdit (with Diff & Animation) ---\n", stderr)
            let typeResult = await performAction(action: typeAction, optionsInput: typeOptions)

            print("\n--- TextEdit Type Result (including Diff) ---")
            printResult(typeResult)

        } else {
            fputs("error: Failed to open TextEdit or get PID. Aborting typing.\n", stderr)
            print("\n--- TextEdit Open Result (Failed) ---")
            printResult(openResult) // Print the result even on failure
        }

        // --- Example 2 (Commented out) ---
        // ...

        // #########################################################################
        // #                                                                       #
        // #          !!! CRITICAL WAIT FOR ASYNCHRONOUS VISUALIZATIONS !!!        #
        // #                                                                       #
        // #########################################################################
        //
        // WHY THIS WAIT IS NECESSARY:
        // --------------------------
        // Functions like `showVisualFeedback` and `drawHighlightBoxes` in the SDK
        // use `DispatchQueue.main.async` to schedule UI work (drawing windows,
        // showing animations like captions or highlights) on the main thread.
        // This dispatching happens ASYNCHRONOUSLY, meaning the SDK functions
        // return *immediately* after *scheduling* the work, not after it's done.
        //
        // THE PROBLEM:
        // -----------
        // If this command-line tool calls `exit(0)` immediately after the main
        // `performAction` calls finish, the entire process can terminate *before*
        // the main thread gets a chance to actually execute the scheduled UI tasks
        // or before the animations (which also run asynchronously) complete.
        //
        // CONSEQUENCE:
        // -----------
        // Without this `Task.sleep`, visual feedback might:
        //   - Not appear at all.
        //   - Be cut off mid-animation.
        //
        // THE SOLUTION:
        // ------------
        // This `Task.sleep` introduces a deliberate pause *at the end* of the
        // main program logic. It keeps the process alive long enough for the
        // asynchronous UI tasks dispatched earlier to run and be visually perceived.
        // Adjust the duration (currently 1 second) if animations seem consistently
        // cut short or if you want to reduce the final wait time.
        //
        // NOTE: We are intentionally *not* closing the overlay windows explicitly
        // in the SDK anymore, as doing so near `exit(0)` caused crashes. We rely
        // on the operating system to clean up the windows when the process exits.
        //
        fputs("info: Main logic complete. Pausing to allow async animations to complete before exiting...\n", stderr); // Emphasized log message
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second (adjust if needed)
        // #########################################################################

        fputs("\ninfo: ActionTool finished.\n", stderr)
        exit(0) // Exit cleanly
    }

    // Helper to print the ActionResult (only prints diff if available)
    static func printResult(_ result: ActionResult) {
        // Check if the traversalDiff exists
        if let diff = result.traversalDiff {
            print("\n--- Traversal Diff ---")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            do {
                let jsonData = try encoder.encode(diff)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                } else {
                    fputs("error: Failed to convert diff JSON data to string.\n", stderr)
                }
            } catch {
                fputs("error: Failed to encode TraversalDiff to JSON: \(error)\n", stderr)
                // Fallback: Print manually
                print("  Added (\(diff.added.count))")
                print("  Removed (\(diff.removed.count))")
                print("  Modified (\(diff.modified.count))")
                 diff.modified.forEach { mod in
                     print("    - Role: \(mod.before.role)")
                     mod.changes.forEach { change in
                         if change.attributeName == "text" {
                            // Print simple diff first if available
                            if let added = change.addedText {
                                print("      - text added: \"\(added)\"")
                            } else if let removed = change.removedText { // Use else if to avoid printing both potentially
                                print("      - text removed: \"\(removed)\"")
                            } else {
                                // If no simple diff, print a generic message instead of old/new values
                                print("      - text changed (complex)")
                            }
                         } else {
                             // Print standard old -> new for other attributes
                             print("      - \(change.attributeName): \(change.oldValue ?? "nil") -> \(change.newValue ?? "nil")")
                         }
                     }
                 }
            }
        } else {
            print("\n--- Traversal Diff ---")
            print("  (No diff calculated or available in this result object)")
            if let err = result.traversalBeforeError { print("  Traversal Before Error: \(err)") }
            if let err = result.traversalAfterError { print("  Traversal After Error: \(err)") }
            if let err = result.primaryActionError { print("  Primary Action Error: \(err)") }
        }
        fflush(stdout)
    }
}

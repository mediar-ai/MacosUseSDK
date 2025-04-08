import Foundation
import ArgumentParser
import MacosUseSDK // Import your library
import CoreGraphics // For CGKeyCode, CGPoint, CGEventFlags
import AppKit

// Define the main structure for the command-line tool
@main
struct SDKTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A tool to interact with macOS applications using MacosUseSDK.",
        subcommands: [PressKey.self, TypeText.self, Visualize.self /*, Click.self, OpenApp.self, Traverse.self ... add others here */ ]
        // defaultSubcommand: // Optional: Define a default action if no subcommand is given
    )
}

// Define a subcommand for the 'press-key' action
extension SDKTool {
    struct PressKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "press-key",
            abstract: "Simulates pressing a key."
        )

        // --- Arguments and Options for 'press-key' ---

        @Option(name: [.short, .long], help: "The key name (e.g., 'k', 'return', 'esc') or numeric key code.")
        var key: String

        @Option(name: .long, help: "The process ID (PID) of the target application.")
        var pid: Int32

        // Flags for modifiers (Example)
        @Flag(name: .long, help: "Hold Command key.")
        var command: Bool = false
        @Flag(name: .long, help: "Hold Shift key.")
        var shift: Bool = false
        @Flag(name: .long, help: "Hold Option key.")
        var option: Bool = false
        @Flag(name: .long, help: "Hold Control key.")
        var control: Bool = false

        // Flags for configurations
        @Flag(name: .long, help: "Visualize the key press action.")
        var visualize: Bool = false

        @Option(name: .long, help: "Duration for visualization effect (seconds).")
        var duration: Double? // Optional duration for visualization

        @Option(name: .long, help: "Nanoseconds to wait after the action before proceeding (e.g., for traverse/diff). Default 100ms.")
        var delayNs: UInt64? // Optional delay

        // --- Execution Logic ---

        // Use 'async throws' because SDK functions can be async and throw
        func run() async throws {
            fputs("info: Received 'press-key' command.\n", stderr)
            fputs("info: Key: \(key), PID: \(pid), Visualize: \(visualize)\n", stderr)

            // 1. Map key name/code
            guard let keyCode = mapKeyNameToKeyCode(key) else {
                fputs("❌ Error: Invalid key name or code: '\(key)'\n", stderr)
                // Use ArgumentParser's way to exit for validation errors
                throw ValidationError("Invalid key name or code: '\(key)'")
            }
            fputs("info: Mapped key '\(key)' to keyCode \(keyCode)\n", stderr)

            // 2. Construct modifier flags
            var flags: CGEventFlags = []
            if command { flags.insert(.maskCommand) }
            if shift { flags.insert(.maskShift) }
            if option { flags.insert(.maskAlternate) } // Note: Option key maps to maskAlternate
            if control { flags.insert(.maskControl) }
            fputs("info: Using modifier flags: \(flags.rawValue)\n", stderr)


            // 3. Build the action using the SDK
            // Start building the pressKey action targeting the PID
            var actionBuilder = await MacosUseSDK.pressKey(keyCode: keyCode, flags: flags, pid: pid)

            // Apply configurations based on flags
            if visualize {
                actionBuilder = await actionBuilder.visualizeAction(duration: duration) // Pass optional duration
                fputs("info: Visualization enabled (duration specified: \(duration != nil ? String(duration!) : "default"))s).\n", stderr)
            }
            if let delay = delayNs {
                 actionBuilder = await actionBuilder.delayAfterAction(nanoseconds: delay)
                 fputs("info: Delay after action set to \(delay) ns.\n", stderr)
             }
             // Add other configurations like .visibleElementsOnly(), .highlightResults() if needed for traverse/diff variants


            // 4. Execute the action
            // For now, we only call .execute(). To support --diff or --traverse,
            // you'd add more flags and call .executeAndDiff() or .executeAndTraverse() instead.
            fputs("info: Executing action...\n", stderr)
            try await actionBuilder.execute() // Await the async execution

            fputs("info: 'press-key' command finished successfully.\n", stderr)

            // If this command needed to output something (like a PID or JSON),
            // you would print it to stdout here. 'pressKey.execute()' doesn't return anything.
        }
    }
}

// --- ADD TypeText Subcommand ---
extension SDKTool {
    struct TypeText: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "type-text", // Command name in terminal
            abstract: "Simulates typing text into an application."
        )

        // --- Arguments and Options ---
        @Option(name: [.short, .long], help: "The text string to type.")
        var text: String

        @Option(name: .long, help: "The process ID (PID) of the target application.")
        var pid: Int32

        @Flag(name: .long, help: "Visualize the text typing action with a caption.")
        var visualize: Bool = false

        @Option(name: .long, help: "Duration for visualization effect (seconds). Default calculated based on text length.")
        var duration: Double? // Optional duration for visualization

        @Option(name: .long, help: "Nanoseconds to wait after the action before proceeding. Default 100ms.")
        var delayNs: UInt64? // Optional delay

        // --- Execution Logic ---
        func run() async throws {
            fputs("info: Received 'type-text' command.\n", stderr)
            fputs("info: Text: \"\(text)\", PID: \(pid), Visualize: \(visualize)\n", stderr)

            // 1. Build the action using the SDK
            var actionBuilder = await MacosUseSDK.type(text, pid: pid)

            // 2. Apply configurations
            if visualize {
                actionBuilder = await actionBuilder.visualizeAction(duration: duration)
                fputs("info: Visualization enabled (duration specified: \(duration != nil ? String(duration!) : "default"))s).\n", stderr)
            }
             if let delay = delayNs {
                 actionBuilder = await actionBuilder.delayAfterAction(nanoseconds: delay)
                 fputs("info: Delay after action set to \(delay) ns.\n", stderr)
             }
            // Add .visibleElementsOnly(), .highlightResults() later if supporting traverse/diff variants

            // 3. Execute the action
            fputs("info: Executing action...\n", stderr)
            try await actionBuilder.execute() // Await the async execution

            fputs("info: 'type-text' command finished successfully.\n", stderr)
            // Like pressKey, this execute() doesn't return specific output to print to stdout
        }
    }
}

// --- Placeholder for other subcommands (Click, OpenApp, Traverse) ---
/*
extension SDKTool {
    struct Click: AsyncParsableCommand {
        static var configuration = CommandConfiguration(commandName: "click", abstract: "Simulates a mouse click.")
        @Option(help: "X coordinate.") var x: Double
        @Option(help: "Y coordinate.") var y: Double
        @Option(help: "Target application PID.") var pid: Int32
        @Flag(help: "Visualize the click.") var visualize: Bool = false
        @Flag(help: "Perform traversal before/after and show diff.") var diff: Bool = false
        // ... other options ...

        func run() async throws {
            let point = CGPoint(x: x, y: y)
            var builder = MacosUseSDK.click(at: point, pid: pid)
            if visualize { builder = builder.visualizeAction() }
            // ... apply other configs ...

            if diff {
                let result = try await builder.executeAndDiff()
                // TODO: Encode result to JSON and print to stdout
                print("Diff result...") // Placeholder
            } else {
                try await builder.execute()
            }
            fputs("info: 'click' command finished.\n", stderr)
        }
    }
    // ... Add TypeText, OpenApp, Traverse structs similarly ...
}
*/

// --- NEW: Visualize Subcommand Definition ---
struct Visualize: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "visualize",
        abstract: "Show visual feedback on screen without simulating input.",
        subcommands: [Caption.self /*, Circle.self */]
    )
}

// --- NEW: Caption Subcommand ---
extension Visualize {
    struct Caption: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "caption",
            abstract: "Display a text caption centered on the screen."
        )

        @Argument(help: "The text to display in the caption.")
        var text: String

        @Option(name: .shortAndLong, help: "Duration to show the caption (seconds). Default: 1.5")
        var duration: Double = 1.5

        @Option(name: [.customShort("w"), .long], help: "Width of the caption overlay. Default: 400")
        var width: Double = 400

        @Option(name: [.customShort("h"), .long], help: "Height of the caption overlay. Default: 100")
        var height: Double = 100

        func run() throws {
            fputs("SDKTool: Action=visualize caption, Text='\(text)', Duration=\(duration)s, Size=\(width)x\(height)\n", stderr)

            // Get main screen dimensions to calculate center
            guard let mainScreen = NSScreen.main else {
                fputs("Error: Could not get main screen information.\n", stderr)
                throw ExitCode.failure
            }
            let screenRect = mainScreen.frame
            let centerPoint = CGPoint(x: screenRect.midX, y: screenRect.midY)
            let overlaySize = CGSize(width: width, height: height)

            fputs("Debug: Screen rect: \(screenRect), Calculated center: \(centerPoint)\n", stderr)

            DispatchQueue.main.async {
                showVisualFeedback(
                    at: centerPoint,
                    type: FeedbackType.caption(text: text),
                    size: overlaySize,
                    duration: duration
                )
                fputs("Debug: showVisualFeedback dispatched to main thread.\n", stderr)
            }

            // --- Wait for Visualization ---
            // The visualization runs asynchronously. The command-line tool needs
            // to stay alive long enough for the animation and fade-out to complete.
            // Add a small buffer to the duration.
            let waitTime = duration + 0.5
            fputs("Info: Waiting \(waitTime) seconds for visualization to complete...\n", stderr)
            // Use RunLoop to keep the main thread alive without busy-waiting
            RunLoop.main.run(until: Date(timeIntervalSinceNow: waitTime))
            fputs("Info: Wait finished. Exiting.\n", stderr)

            // No explicit success message needed, lack of error implies success.
            // ArgumentParser handles exit.
        }
    }

    // You could add a 'Circle' subcommand here similarly if needed:
    // struct Circle: ParsableCommand { ... }
}

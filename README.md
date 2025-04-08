# MacosUseSDK

Library and command-line tools to traverse the macOS accessibility tree and simulate user input actions. Allows interaction with UI elements of other applications.


https://github.com/user-attachments/assets/d8dc75ba-5b15-492c-bb40-d2bc5b65483e

Highlight whatever is happening on the computer: text elements, clicks, typing
![Image](https://github.com/user-attachments/assets/9e182bbc-bd30-4285-984a-207a58b32bc0)

Listen to changes in the UI, elements changed, text changed
![Image](https://github.com/user-attachments/assets/4a972dfa-ce4d-4b1a-9781-43379375b313)

## Building the Tools

To build the command-line tools provided by this package, navigate to the root directory (`MacosUseSDK`) in your terminal and run:

```bash
swift build
```

This will compile the tools and place the executables in the `.build/debug/` directory (or `.build/release/` if you use `swift build -c release`). You can run them directly from there (e.g., `.build/debug/TraversalTool`) or use `swift run <ToolName>`.

## Available Tools

All tools output informational logs and timing data to `stderr`. Primary output (like PIDs or JSON data) is sent to `stdout`.

### AppOpenerTool

*   **Purpose:** Opens or activates a macOS application by its name, bundle ID, or full path. Outputs the application's PID on success.
*   **Usage:** `AppOpenerTool <Application Name | Bundle ID | Path>`
*   **Examples:**
    ```bash
    # Open by name
    swift run AppOpenerTool Calculator
    # Open by bundle ID
    swift run AppOpenerTool com.apple.Terminal
    # Open by path
    swift run AppOpenerTool /System/Applications/Utilities/Terminal.app
    # Example output (stdout)
    # 54321 
    ```

### TraversalTool

*   **Purpose:** Traverses the accessibility tree of a running application (specified by PID) and outputs a JSON representation of the UI elements to `stdout`.
*   **Usage:** `TraversalTool [--visible-only] <PID>`
*   **Options:**
    *   `--visible-only`: Only include elements that have a position and size (are geometrically visible).
*   **Examples:**
    ```bash
    # Get only visible elements for Messages app
    swift run TraversalTool --visible-only $(swift run AppOpenerTool Messages)
    ```

### HighlightTraversalTool

*   **Purpose:** Traverses the accessibility tree of a running application (specified by PID) and draws temporary red boxes around all visible UI elements. Also outputs traversal data (JSON) to `stdout`. Useful for debugging accessibility structures.
*   **Usage:** `HighlightTraversalTool <PID> [--duration <seconds>]`
*   **Options:**
    *   `--duration <seconds>`: Specifies how long the highlights remain visible (default: 3.0 seconds).
*   **Examples:**
    ```bash
    # Combine with AppOpenerTool to open Messages and highlight it
    swift run HighlightTraversalTool $(swift run AppOpenerTool Messages) --duration 5
    ```
    *Note: This tool needs to keep running for the duration specified to manage the highlights.*

### InputControllerTool

*   **Purpose:** Simulates keyboard and mouse input events without visual feedback.
*   **Usage:** See `swift run InputControllerTool --help` (or just run without args) for actions.
*   **Examples:**
    ```bash
    # Press the Enter key
    swift run InputControllerTool keypress enter
    # Simulate Cmd+C (Copy)
    swift run InputControllerTool keypress cmd+c
    # Simulate Shift+Tab
    swift run InputControllerTool keypress shift+tab
    # Left click at screen coordinates (100, 250)
    swift run InputControllerTool click 100 250
    # Double click at screen coordinates (150, 300)
    swift run InputControllerTool doubleclick 150 300
    # Right click at screen coordinates (200, 350)
    swift run InputControllerTool rightclick 200 350
    # Move mouse cursor to (500, 500)
    swift run InputControllerTool mousemove 500 500
    # Type the text "Hello World!"
    swift run InputControllerTool writetext "Hello World!"
    ```

### VisualInputTool

*   **Purpose:** Simulates keyboard and mouse input events *with* visual feedback (currently a pulsing green circle for mouse actions).
*   **Usage:** Similar to `InputControllerTool`, but adds a `--duration` option for the visual effect. See `swift run VisualInputTool --help`.
*   **Options:**
    *   `--duration <seconds>`: How long the visual feedback effect lasts (default: 0.5 seconds).
*   **Examples:**
    ```bash
    # Left click at (100, 250) with default 0.5s feedback
    swift run VisualInputTool click 100 250
    # Right click at (800, 400) with 2 second feedback
    swift run VisualInputTool rightclick 800 400 --duration 2.0
    # Move mouse to (500, 500) with 1 second feedback
    swift run VisualInputTool mousemove 500 500 --duration 1.0
    # Keypress and writetext (currently NO visualization implemented)
    swift run VisualInputTool keypress cmd+c
    swift run VisualInputTool writetext "Testing"
    ```
    *Note: This tool needs to keep running for the duration specified to display the visual feedback.*

### Running Tests

Run only specific tests or test classes, use the --filter option.
Run a specific test method: Provide the full identifier TestClassName/testMethodName

```bash
# Example: Run only the multiply test in CombinedActionsDiffTests
swift test --filter CombinedActionsDiffTests/testCalculatorMultiplyWithActionAndTraversalHighlight
# Example: Run all tests in CombinedActionsFocusVisualizationTests
swift test --filter CombinedActionsFocusVisualizationTests
```



*Note: on Test Output: When running tests you might occasionally see errors or signals in the console output (e.g., error: Exited with unexpected signal code 11). These are often related to the timing of animations and do not impact execution itself


## Using the Library

You can also use `MacosUseSDK` as a dependency in your own Swift projects. Add it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "/* path or URL to your MacosUseSDK repo */", from: "1.0.0"),
]
```

And add `MacosUseSDK` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["MacosUseSDK"]),
```

Then import and use the public functions:

```swift
import MacosUseSDK
import Foundation // For Dispatch etc.

// Example: Get elements from Calculator app
Task {
    do {
        // Find Calculator PID (replace with actual logic or use AppOpenerTool output)
        // let calcPID: Int32 = ... 
        // let response = try MacosUseSDK.traverseAccessibilityTree(pid: calcPID, onlyVisibleElements: true)
        // print("Found \(response.elements.count) visible elements.")

        // Example: Click at a point
        let point = CGPoint(x: 100, y: 200)
        try MacosUseSDK.clickMouse(at: point)

        // Example: Click with visual feedback (needs main thread for UI)
        DispatchQueue.main.async {
            do {
                 try MacosUseSDK.clickMouseAndVisualize(at: point, duration: 1.0)
            } catch {
                 print("Visualization error: \(error)")
            }
        }

    } catch {
        print("MacosUseSDK Error: \(error)")
    }
}

// Remember to keep the run loop active if using async UI functions like highlightVisibleElements or *AndVisualize
// RunLoop.main.run() // Or use within an @main Application structure
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

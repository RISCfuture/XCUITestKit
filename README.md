# XCUITestKit

[![CI](https://github.com/RISCfuture/XCUITestKit/actions/workflows/ci.yml/badge.svg)](https://github.com/RISCfuture/XCUITestKit/actions/workflows/ci.yml)

A shared XCUITest robustness toolkit for iOS, macOS, watchOS, and visionOS UI
tests. It consolidates the wait / tap / text-entry / page-object helpers that
several apps had each reinvented, and adds the one mitigation they were all
missing: recovery from the accessibility-server failures that dominate slow-CI
flakes.

## Requirements

- A UI-test target on iOS 17+, macOS 14+, watchOS 10+, or visionOS 1+.
- Built with Xcode's toolchain — the XCUI automation types ship with Xcode's
  XCTest, not the open-source swift.org toolchain.

The platform-agnostic core (timeouts, waits, asserts, frame-stability taps,
scrolling, retry/recovery) works on all four platforms. The soft-keyboard,
SpringBoard, and tab-bar helpers (`clearAndType`, `dismissKeyboardStable`,
`scrollToTop`, `tabButton`/`tapTab`, `SystemAlert.dismiss` / `SystemAlert.springboard`,
and `addSystemAlertMonitor`) are iOS-only.
tvOS is unsupported: it has no coordinate/touch/swipe XCUITest surface (it is
`XCUIRemote` focus-driven), so the interaction helpers cannot apply.

## Installation

Add the package to your project and link it from your **UI-test target only**:

```swift
.package(url: "https://github.com/RISCfuture/XCUITestKit", from: "1.0.0")
```

```swift
.testTarget(
  name: "MyAppUITests",
  dependencies: [.product(name: "XCUITestKit", package: "XCUITestKit")]
)
```

## What's inside

| Type | Purpose |
|------|---------|
| `ScaledTimeouts` | CI-scalable timeouts. Reads a multiplier from `XCUITEST_TIMEOUT_MULTIPLIER` (positive `Double`); defaults to `1` locally. Exposes `element` / `short` / `slowElement` / `launch`. |
| `XCUIElement` waits | `wait`, `wait(scaledSeconds:)`, `waitFor(_:)`, `waitUntilHittable`, and asserting variants `assertExists` / `assertHidden` / `assertNeverAppears` (each takes an optional leading `message` appended to the kit's auto-generated failure text). |
| `XCUIElement` interaction | `forceTap`, `tapStable` / `coordinateTapWhenFrameStable` (frame-stability polling to dodge "Activation point invalid" and Liquid Glass hittability), `isVisible`, `makeVisible` (reveal an element inside a known scroll container), `commitByMovingFocus` (end editing on a Return-less `numberPad`/`decimalPad` field by focusing a sibling). |
| `XCUIElement.clearAndType(_:app:perCharacter:)` _(iOS)_ | Clears and types text, **asserting the soft keyboard surfaced before typing** (kills the "Neither element nor any descendant has keyboard focus" flake) and clearing by reading the value back. `perCharacter` types one character at a time for self-canonicalizing formatter fields where a single burst races the format round-trip. |
| `XCUIApplication` helpers | `scrollToElement(_:direction:maxSwipes:)` (whole-screen directional scroll with a home-indicator-safe buffer; complements `makeVisible`), `launchAndWaitUntilReady` (foreground wait scaled by the multiplier; disables `os_log` stderr mirroring). iOS-only: `tabButton` / `tapTab` (iPhone tab bar vs iPad floating tabs), `dismissKeyboardStable(doneButtonIdentifier:)` (taps a Done button by identifier first, then nav-bar/swipe fallbacks), `scrollToTop`. |
| `AXRecovery` | `run(maxAttempts:isHealthy:relaunch:action:)` — do → probe health → terminate+relaunch → retry. The in-test complement to a CI "retry on a fresh simulator" pass; targets `kAXErrorServerNotFound`. |

## Usage

```swift
import XCTest
import XCUITestKit

final class AboutTests: XCTestCase {
  @MainActor
  func testAboutScreen() {
    let app = XCUIApplication()
    app.launchAndWaitUntilReady(readyElement: { $0.tabBars.firstMatch })

    app.tapTab("About")
    app.navigationBars["About"].assertExists()

    let nameField = app.textFields["fullName"]
    nameField.clearAndType("Ada Lovelace", app: app)
  }
}
```

Set the CI multiplier in your UI-test plan's environment variables, e.g.
`XCUITEST_TIMEOUT_MULTIPLIER = 3`, so every wait scales up on slow runners
without touching test code.

## CI: hardened simulator setup

`ci-templates/setup-ios-simulator/action.yml` is a composite action that captures
the simulator-setup boilerplate (disable services → select Xcode → ensure
runtime → create → boot → configure → **settle**), including a
LaunchServices-migration settle gate so install/launch does not race a
half-booted device. Reference it from a consuming app's workflow:

```yaml
- id: sim
  uses: RISCfuture/XCUITestKit/ci-templates/setup-ios-simulator@main
  with:
    device: "iPhone 17 Pro"
    device-type: com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro
    raise-pty-cap: "true"
- run: xcodebuild test-without-building -destination "platform=iOS Simulator,id=${{ steps.sim.outputs.udid }}" ...
```

The broader UI-test CI standard these helpers support: a per-job
`timeout-minutes`, dropping unstable older-iOS UI legs (covering them via
build + unit), and an `xcresult` retry gate that counts a test as failed only if
every iteration failed.

## License

MIT — see [LICENSE.md](LICENSE.md).

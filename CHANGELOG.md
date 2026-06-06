# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **watchOS and visionOS support.** The platform-agnostic core (timeouts, waits, asserts, frame-stability taps, scrolling, retry/recovery) now builds for watchOS 10+ and visionOS 1+ alongside iOS 17+ and macOS 14+. The soft-keyboard, SpringBoard, and tab-bar helpers remain iOS-only (see **Changed**). tvOS is intentionally unsupported: it has no coordinate/touch/swipe XCUITest surface (it is `XCUIRemote` focus-driven), so the kit's interaction helpers cannot apply.
- `XCUIApplication.scrollToElement(_:direction:maxSwipes:)`: scrolls the whole screen in a given direction until the element's center clears a home-indicator-safe buffer and is hittable. Complements `makeVisible(element:)` (which reveals an element inside a known scroll container); use `scrollToElement` for whole-screen scrolling, scrolling *down*, or when the next action is a center-coordinate tap near the bottom safe area.
- Optional leading `message` on `assertExists` / `assertHidden` / `assertNeverAppears`, appended to the kit's auto-generated failure text (which already names the element and timeout).
- `clearAndType(_:app:perCharacter:doneButtonIdentifier:)`: a `perCharacter` flag types one character at a time, for fields backed by a self-canonicalizing formatter (e.g. a fractional/decimal-shift `TextField(value:format:)`) where a single `typeText` burst can race the format round-trip and corrupt the buffer; `doneButtonIdentifier` is forwarded to the closing keyboard dismissal so `numberPad`/`decimalPad` fields dismiss deterministically.
- `dismissKeyboardStable(doneButtonIdentifier:)`: an optional identifier taps a keyboard-accessory Done button first (deterministic, synchronous focus resignation — the only reliable dismissal for a `.decimalPad` with no Return key) before falling back to the nav-bar tap and swipe.
- `XCUIApplication.disableLogStderrMirroring()`: sets `OS_ACTIVITY_MODE=disable` for the launch so `os_log`'s stderr mirroring can't block the app's main thread on a full capture pipe during accessibility snapshots. `launchAndWaitUntilReady` applies it by default via a new `disablingLogStderrMirroring` parameter.
- `XCUIElement.commitByMovingFocus(to:)`: commits a `TextField(value:format:)` (whose binding only writes on editing-end) by moving first responder to a sibling element — for `numberPad`/`decimalPad` fields that have no Return key and can't be dismissed when the form fits onscreen. Available on every supported platform.

### Changed

- The soft-keyboard, SpringBoard, and tab-bar helpers — `clearAndType`, `dismissKeyboardStable`, `scrollToTop`, `tabButton`/`tapTab`, `SystemAlert.dismiss` / `SystemAlert.springboard`, and `XCTestCase.addSystemAlertMonitor` — are now compiled `#if os(iOS)`, because they depend on a soft keyboard, SpringBoard, or the UIKit tab-bar idiom that the other platforms lack. (`SystemAlert.dismiss`/`springboard` were already iOS-gated; the rest are newly scoped.) `commitByMovingFocus` moved to its own file so it stays available everywhere.

- **Breaking:** `ScaledTimeouts` now reads only the generic `XCUITEST_TIMEOUT_MULTIPLIER` environment variable. The legacy per-app fallbacks (`FART_UI_TIMEOUT_MULTIPLIER`, `SF50_UI_TEST_TIMEOUT_MULTIPLIER`) have been removed; rename them to `XCUITEST_TIMEOUT_MULTIPLIER` in consuming test plans. The `multiplierEnvVarNames` array is replaced by the singular `multiplierEnvironmentVariableName` constant.
- **Breaking:** `maxAttempts` parameters (`AXRecovery.run`, `Retry.untilVerified`, `XCUIElement.tap(untilExists:)`, `XCUIElement.makeVisible`) are now `UInt` instead of `Int`. Integer literals are unaffected; callers passing an `Int` variable must convert it.
- A present-but-malformed `XCUITEST_TIMEOUT_MULTIPLIER` (non-numeric, zero, or negative) now triggers an `assertionFailure` instead of silently disabling scaling. An unset variable still defaults to `1×`.

## [1.0.0] - 2026-05-29

### Added

- Initial release of XCUITestKit
- `ScaledTimeouts`: CI-scalable UI-test timeouts driven by an environment-variable multiplier
- `XCUIElement` wait helpers: `wait`, `waitFor`, `waitUntilHittable`, `assertExists`, `assertHidden`, `assertNeverAppears`
- `XCUIElement` interaction helpers: `forceTap`, `tapStable`, `coordinateTapWhenFrameStable`, `isVisible`, `makeVisible`
- `XCUIElement.clearAndType`: clears and types text, asserting the soft keyboard surfaced first, with an iPad Cmd+A select-all fallback
- `XCUIApplication` helpers: `tabButton`, `tapTab`, `dismissKeyboardStable`, `scrollToTop`, `launchAndWaitUntilReady`
- `AXRecovery`: do → probe → relaunch → retry recovery for accessibility-server failures (`kAXErrorServerNotFound`)
- `setup-ios-simulator` composite action for hardened simulator setup in CI
- Swift 6 concurrency support

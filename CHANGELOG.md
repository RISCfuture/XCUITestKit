# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

import XCTest

@MainActor
extension XCUIApplication {
  /// Find a tab button by label, checking both the standard tab bar (iPhone)
  /// and the floating tab bar (iPad), which does not expose a `TabBar` element.
  public func tabButton(_ label: String) -> XCUIElement {
    let tabBarButton = tabBars.buttons[label]
    if tabBarButton.exists { return tabBarButton }
    return buttons[label].firstMatch
  }

  /// Tap a tab by label on either idiom. Falls back to a coordinate tap for the
  /// iOS 26 "Liquid Glass" overlay where the button reports not-hittable.
  public func tapTab(_ label: String) {
    tabButton(label).forceTap()
  }

  /// Scroll to the top by tapping the status bar, falling back to a coordinate
  /// tap near the top edge when SpringBoard exposes no status bar.
  public func scrollToTop() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let statusBars = springboard.statusBars.allElementsBoundByIndex
    if let first = statusBars.first {
      first.tap()
    } else {
      coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()
    }
  }

  /// Resign first responder, then wait for the keyboard window to leave the
  /// hierarchy. Prefers tapping a nav-bar element; falls back to a gentle
  /// upward swipe (SwiftUI Forms auto-dismiss the keyboard on scroll).
  public func dismissKeyboardStable() {
    let keyboard = keyboards.firstMatch
    guard keyboard.exists else { return }

    let navBar = navigationBars.firstMatch
    if navBar.exists, navBar.isHittable {
      navBar.tap()
      if keyboard.waitForNonExistence(timeout: ScaledTimeouts.element) { return }
    }

    let deadline = Date().addingTimeInterval(ScaledTimeouts.element)
    while keyboard.exists, Date() < deadline {
      let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
      let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
      start.press(forDuration: 0.05, thenDragTo: end)
      _ = keyboard.waitForNonExistence(timeout: 1)
    }
  }

  /// Launch the app and wait until it is foreground and a `readyElement`
  /// (a known root element of the first screen) is queryable.
  ///
  /// The foreground wait is scaled by ``ScaledTimeouts`` rather than a hard
  /// constant, because a slow CI simulator can take far longer than a fixed 10s
  /// to reach `.runningForeground` — returning early there is a common source
  /// of the first accessibility query failing.
  public func launchAndWaitUntilReady(
    readyElement: (XCUIApplication) -> XCUIElement,
    foregroundTimeout: TimeInterval = ScaledTimeouts.launch
  ) {
    launch()
    _ = wait(for: .runningForeground, timeout: foregroundTimeout)
    _ = readyElement(self).waitForExistence(timeout: ScaledTimeouts.slowElement)
  }
}

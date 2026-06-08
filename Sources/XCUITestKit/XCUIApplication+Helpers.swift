import XCTest

@MainActor
extension XCUIApplication {
  private static let homeIndicatorBufferPt: CGFloat = 30
  private static let scrollSwipeDuration: TimeInterval = 0.05
  private static let scrollUpStartDY: CGFloat = 0.7
  private static let scrollUpEndDY: CGFloat = 0.3
  private static let scrollDownStartDY: CGFloat = 0.3
  private static let scrollDownEndDY: CGFloat = 0.7

  /**
   Disable `os_log`'s stderr mirroring for this launch.

   Under XCTest, `os_log` mirrors to stderr; on CI the app's stderr is a
   captured pipe, and when it fills, the app's `writev` blocks the main thread
   during accessibility snapshots — stalling wait-for-idle until the test times
   out. Call before ``launch()``, or use
   ``launchAndWaitUntilReady(readyElement:foregroundTimeout:disablingLogStderrMirroring:)``,
   which applies it automatically.
   */
  public func disableLogStderrMirroring() {
    launchEnvironment["OS_ACTIVITY_MODE"] = "disable"
  }

  /**
   Launch the app and wait until it is foreground and a `readyElement`
   (a known root element of the first screen) is queryable.

   The foreground wait is scaled by ``ScaledTimeouts`` rather than a hard
   constant, because a slow CI simulator can take far longer than a fixed 10s
   to reach `.runningForeground` — returning early there is a common source
   of the first accessibility query failing.

   When `disablingLogStderrMirroring` is `true` (the default),
   ``disableLogStderrMirroring()`` is applied before launch so the app's main
   thread cannot block on a full stderr pipe during accessibility snapshots.
   */
  public func launchAndWaitUntilReady(
    readyElement: (XCUIApplication) -> XCUIElement,
    foregroundTimeout: TimeInterval = ScaledTimeouts.launch,
    disablingLogStderrMirroring: Bool = true
  ) {
    if disablingLogStderrMirroring { disableLogStderrMirroring() }
    launch()
    _ = wait(for: .runningForeground, timeout: foregroundTimeout)
    _ = readyElement(self).waitForExistence(timeout: ScaledTimeouts.slowElement)
  }

  /**
   Scroll in `direction` until `element`'s center is fully on-screen (with a
   home-indicator-safe buffer) and the element is hittable, or `maxSwipes` is
   reached.

   `isHittable` alone is true when *any* part of the element intersects the
   screen, so an element whose center sits past the bottom edge can pass while a
   subsequent center-coordinate tap lands off-screen and is silently dropped.
   Requiring the midpoint inside the buffered safe area fixes that.

   This swipes the whole screen toward a tap target and supports scrolling
   *down*; for revealing an element inside a known scroll container, use
   ``XCUIElement/makeVisible(element:maxAttempts:)`` instead.
   */
  public func scrollToElement(
    _ element: XCUIElement,
    direction: ScrollDirection = .up,
    maxSwipes: UInt = 20
  ) {
    var swipes: UInt = 0
    while !isCenterOnscreen(element), swipes < maxSwipes {
      gentleSwipe(direction)
      swipes += 1
    }
  }

  private func isCenterOnscreen(_ element: XCUIElement) -> Bool {
    guard element.isHittable, element.frame.width > 0, element.frame.height > 0
    else { return false }
    let visibleMaxY = frame.maxY - Self.homeIndicatorBufferPt
    return element.frame.midY >= frame.minY && element.frame.midY <= visibleMaxY
  }

  private func gentleSwipe(_ direction: ScrollDirection) {
    let (startDY, endDY): (CGFloat, CGFloat) =
      switch direction {
        case .up: (Self.scrollUpStartDY, Self.scrollUpEndDY)
        case .down: (Self.scrollDownStartDY, Self.scrollDownEndDY)
      }
    let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startDY))
    let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endDY))
    start.press(forDuration: Self.scrollSwipeDuration, thenDragTo: end)
  }

  /// Direction a ``scrollToElement(_:direction:maxSwipes:)`` gesture moves content.
  public enum ScrollDirection {
    /// Swipe content upward to reveal items further down.
    case up
    /// Swipe content downward to reveal items further up.
    case down
  }
}

#if os(iOS)
  @MainActor
  extension XCUIApplication {
    private static let topEdgeOffset = CGVector(dx: 0.5, dy: 0.02)
    private static let dismissSwipeStart = CGVector(dx: 0.5, dy: 0.35)
    private static let dismissSwipeEnd = CGVector(dx: 0.5, dy: 0.15)
    private static let dismissSwipeDuration: TimeInterval = 0.05
    private static let keyboardDismissPollSeconds: TimeInterval = 1

    /**
     Find a tab button by label, checking both the standard tab bar (iPhone)
     and the floating tab bar (iPad), which does not expose a `TabBar` element.
     */
    public func tabButton(_ label: String) -> XCUIElement {
      let tabBarButton = tabBars.buttons[label]
      if tabBarButton.exists { return tabBarButton }
      return buttons[label].firstMatch
    }

    /**
     Tap a tab by label on either idiom. Falls back to a coordinate tap for the
     iOS 26 "Liquid Glass" overlay where the button reports not-hittable.
     */
    public func tapTab(_ label: String) {
      tabButton(label).forceTap()
    }

    /**
     Scroll to the top by tapping the status bar, falling back to a coordinate
     tap near the top edge when SpringBoard exposes no status bar.
     */
    public func scrollToTop() {
      let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      let statusBars = springboard.statusBars.allElementsBoundByIndex
      if let first = statusBars.first {
        first.tap()
      } else {
        coordinate(withNormalizedOffset: Self.topEdgeOffset).tap()
      }
    }

    /**
     Resign first responder, then wait for the keyboard window to leave the
     hierarchy.

     Dismissal strategy, in order of preference:
     1. If `doneButtonIdentifier` is given and a hittable keyboard-accessory
        button with that identifier exists, tap it and return. This is the
        deterministic path — SwiftUI resigns focus synchronously — and the only
        reliable dismissal for a `.decimalPad` keyboard that has no Return key.
        A hittable Done button is authoritative, so the fallbacks below are not
        attempted (which avoids an extra nav-bar tap when the dismiss animation
        merely outlasts the wait).
     2. Otherwise tap the nav bar (moves focus off the field).
     3. Fall back to a gentle upward swipe (SwiftUI Forms auto-dismiss the
        keyboard on scroll), re-attempting until the keyboard window leaves.

     Only fires when a keyboard is actually present.
     */
    public func dismissKeyboardStable(doneButtonIdentifier: String? = nil) {
      let keyboard = keyboards.firstMatch
      guard keyboard.exists else { return }

      if let doneButtonIdentifier {
        let doneButton = buttons[doneButtonIdentifier].firstMatch
        if doneButton.exists, doneButton.isHittable {
          doneButton.tap()
          _ = keyboard.waitForNonExistence(timeout: ScaledTimeouts.element)
          return
        }
      }

      let navBar = navigationBars.firstMatch
      if navBar.exists, navBar.isHittable {
        navBar.tap()
        if keyboard.waitForNonExistence(timeout: ScaledTimeouts.element) { return }
      }

      let deadline = Date().addingTimeInterval(ScaledTimeouts.element)
      while keyboard.exists, Date() < deadline {
        let start = coordinate(withNormalizedOffset: Self.dismissSwipeStart)
        let end = coordinate(withNormalizedOffset: Self.dismissSwipeEnd)
        start.press(forDuration: Self.dismissSwipeDuration, thenDragTo: end)
        _ = keyboard.waitForNonExistence(
          timeout: ScaledTimeouts.scaled(Self.keyboardDismissPollSeconds)
        )
      }
    }
  }
#endif

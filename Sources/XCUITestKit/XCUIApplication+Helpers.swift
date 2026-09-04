public import XCTest

@MainActor
extension XCUIApplication {
  private static let homeIndicatorBufferPt: CGFloat = 30
  private static let scrollSwipeDuration: TimeInterval = 0.05
  private static let scrollUpStartDY: CGFloat = 0.7
  private static let scrollUpEndDY: CGFloat = 0.3
  private static let scrollDownStartDY: CGFloat = 0.3
  private static let scrollDownEndDY: CGFloat = 0.7
  private static let safeBandNudgeDuration: TimeInterval = 0.01
  private static let safeBandNudgeDownStart = CGVector(dx: 0.5, dy: 0.25)
  private static let safeBandNudgeDownEnd = CGVector(dx: 0.5, dy: 0.5)
  private static let safeBandNudgeUpStart = CGVector(dx: 0.5, dy: 0.6)
  private static let safeBandNudgeUpEnd = CGVector(dx: 0.5, dy: 0.35)

  /**
   Disable `os_log`'s stderr mirroring for this launch.

   Under XCTest, `os_log` mirrors to stderr; on CI the app's stderr is a
   captured pipe, and when it fills, the app's `writev` blocks the main thread
   during accessibility snapshots — stalling wait-for-idle until the test times
   out. Call before `launch()`, or use
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

  /**
   Nudge `element` into a vertical band clear of translucent floating bars — the iOS 26
   "Liquid Glass" navigation bar and floating tab bar, which report an element underlapping
   them as `isHittable` yet swallow a tap that lands on the bar.

   Scrolls `container` by the element's *frame position* rather than trusting `isHittable`:
   while the element's top sits above `topFraction` of the window it drags content down, while
   its bottom sits below `bottomFraction` it drags content up, and it returns once the element
   is inside the band (or `maxAttempts` is reached). A no-op when the element is already
   in-band, does not exist, or no scroll container is present.

   A band edge can lie outside what the container can reach — the first rows of a form sit
   above `topFraction` with the list already at its top, and no amount of dragging moves them
   down. A nudge that leaves the element's frame where it was therefore ends the attempts: the
   element stays where it is (still hittable, just underlapping a bar), and the caller is spared
   a full budget of gestures that cannot help. Those gestures are not free — each one is a
   synthesized drag, and on a loaded runner the event synthesis they queue up is what makes a
   later tap time out.

   Unlike ``scrollToElement(_:direction:maxSwipes:)`` (which swipes the whole screen until the
   element's center clears only the *bottom* home-indicator buffer), this dodges **both** the
   top and bottom floating bars, so a center-coordinate tap afterwards is not eaten by a bar.

   - Parameters:
     - element: The element to bring into the safe band.
     - container: The scroll view to drag. Defaults to the first collection view.
     - topFraction: Fraction of the window height below which the element's top must sit.
     - bottomFraction: Fraction of the window height above which the element's bottom must sit.
     - maxAttempts: Maximum nudge gestures before giving up.
   */
  public func scrollIntoSafeBand(
    _ element: XCUIElement,
    in container: XCUIElement? = nil,
    topFraction: CGFloat = 0.20,
    bottomFraction: CGFloat = 0.66,
    maxAttempts: UInt = 5
  ) {
    guard element.exists else { return }
    let scroller = container ?? collectionViews.firstMatch
    guard scroller.exists else { return }
    let windowHeight = windows.firstMatch.frame.height
    guard windowHeight > 0 else { return }

    for _ in 0..<maxAttempts {
      let frameBeforeNudge = element.frame

      if frameBeforeNudge.minY < windowHeight * topFraction {
        nudge(scroller, from: Self.safeBandNudgeDownStart, to: Self.safeBandNudgeDownEnd)
      } else if frameBeforeNudge.maxY > windowHeight * bottomFraction {
        nudge(scroller, from: Self.safeBandNudgeUpStart, to: Self.safeBandNudgeUpEnd)
      } else {
        return
      }

      guard element.exists else { return }
      if element.frame == frameBeforeNudge { return }
    }
  }

  private func nudge(_ scroller: XCUIElement, from start: CGVector, to end: CGVector) {
    scroller.coordinate(withNormalizedOffset: start)
      .press(
        forDuration: Self.safeBandNudgeDuration,
        thenDragTo: scroller.coordinate(withNormalizedOffset: end)
      )
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

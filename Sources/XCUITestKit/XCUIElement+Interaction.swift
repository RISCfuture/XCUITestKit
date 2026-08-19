import XCTest

@MainActor
extension XCUIElement {
  private static let centerOffset = CGVector(dx: 0.5, dy: 0.5)
  private static let requiredStableFrameReads: UInt = 2

  /// How often the frame-stability waits re-read an element's frame, in seconds.
  public static let framePollInterval: TimeInterval = 0.1

  /**
   How long a synthesized tap holds the touch down, in seconds.

   An iOS 26 SwiftUI control — a `Toggle` especially — drops a touch that goes down and up in
   the same instant: the gesture reports success and the control keeps its old value, so a test
   carries on against a screen that no longer says what it thinks it does. Holding briefly lands
   the touch while staying well under the half second that would make it a long press.

   Pass `0` to any tap taking a `holdFor` argument for an instantaneous tap instead.
   */
  public static let tapHoldDuration: TimeInterval = 0.1

  /**
   Whether the element exists, has a non-empty frame, and lies within the
   app's first window.
   */
  public var isVisible: Bool {
    guard exists, !frame.isEmpty else { return false }
    let app = XCUIApplication()
    guard let firstWindow = app.windows.allElementsBoundByIndex.first else { return false }
    return firstWindow.frame.contains(frame)
  }

  /**
   Whether a toggle-like control (a `Switch`, checkbox, or SwiftUI `Toggle`) reads as on.

   XCUITest bridges the control's boolean state into `value` inconsistently across platforms
   and control kinds — sometimes an `Int` `1`/`0`, sometimes the string `"1"`/`"0"`, sometimes
   a `Bool` — so a raw `value as? Bool` check is unreliable. This normalizes all three.
   */
  public var isOn: Bool {
    value as? Bool == true || value as? Int == 1 || value as? String == "1"
  }

  /**
   Tap if hittable, otherwise tap the element's center coordinate — which
   skips activation-point hit-testing that iOS 26 "Liquid Glass" overlays and
   iPad SwiftUI cells often fail.

   - Parameter holdDuration: How long to hold the touch down. See ``tapHoldDuration``.
   */
  public func forceTap(holdFor holdDuration: TimeInterval = XCUIElement.tapHoldDuration) {
    if isHittable {
      press(holdingFor: holdDuration)
    } else {
      coordinate(withNormalizedOffset: Self.centerOffset).press(holdingFor: holdDuration)
    }
  }

  /// Touches down and up again, holding for `duration` unless it is zero.
  func press(holdingFor duration: TimeInterval) {
    if duration > 0 {
      press(forDuration: duration)
    } else {
      tap()
    }
  }

  /**
   Tap via center coordinate after waiting for the element's frame to settle.

   Under simulator load, SwiftUI Form/List views can be mid-relayout when
   XCUITest computes an activation point — the system then refuses the tap
   with "Activation point invalid and no suggested hit points." Polling for
   consecutive identical frame reads guarantees a settled target, and tapping
   via the center coordinate skips activation-point resolution entirely.

   - Parameters:
     - timeout: How long to wait for the frame to settle. Defaults to `ScaledTimeouts.element`.
     - holdDuration: How long to hold the touch down. See ``tapHoldDuration``.
     - file: Source file to attribute a failure to. Defaults to the caller's.
     - line: Source line to attribute a failure to. Defaults to the caller's.
   */
  @discardableResult
  public func tapStable(
    timeout: TimeInterval = ScaledTimeouts.element,
    holdFor holdDuration: TimeInterval = XCUIElement.tapHoldDuration,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> Self {
    await waitForFrameStability(requireHittable: true, timeout: timeout, file: file, line: line)
    coordinate(withNormalizedOffset: Self.centerOffset).press(holdingFor: holdDuration)
    return self
  }

  /**
   Like ``tapStable(timeout:holdFor:file:line:)`` but does not require `isHittable`.

   Use for SwiftUI controls (e.g. `.pickerStyle(.navigationLink)` rows) whose
   backing element can report `isHittable == false` for the entire wait
   window while still being visibly tappable.

   - Parameters:
     - timeout: How long to wait for the frame to settle. Defaults to `ScaledTimeouts.element`.
     - holdDuration: How long to hold the touch down. See ``tapHoldDuration``.
     - file: Source file to attribute a failure to. Defaults to the caller's.
     - line: Source line to attribute a failure to. Defaults to the caller's.
   */
  @discardableResult
  public func coordinateTapWhenFrameStable(
    timeout: TimeInterval = ScaledTimeouts.element,
    holdFor holdDuration: TimeInterval = XCUIElement.tapHoldDuration,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> Self {
    await waitForFrameStability(requireHittable: false, timeout: timeout, file: file, line: line)
    coordinate(withNormalizedOffset: Self.centerOffset).press(holdingFor: holdDuration)
    return self
  }

  /**
   Poll until this element's frame stops moving, returning whether it settled before `timeout`.

   The synchronous, non-asserting counterpart to the wait inside ``tapStable(timeout:holdFor:file:line:)``.
   Scrolling a row into place leaves the list decelerating, and a tap issued into a moving list
   lands on whichever row slides under it — the tap reports success and the wrong element receives
   it. Use this from a synchronous test path that wants a settled target but can carry on without
   one.
   */
  @discardableResult
  public func waitUntilFrameStable(
    timeout: TimeInterval = ScaledTimeouts.short,
    pollInterval: TimeInterval = XCUIElement.framePollInterval
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame: CGRect = .null
    var stableHits: UInt = 0

    while Date() < deadline {
      let current = frame
      if current == lastFrame {
        stableHits += 1
        if stableHits >= Self.requiredStableFrameReads { return true }
      } else {
        stableHits = 0
        lastFrame = current
      }
      Thread.sleep(forTimeInterval: pollInterval)
    }

    return false
  }

  private func waitForFrameStability(
    requireHittable: Bool,
    timeout: TimeInterval,
    file: StaticString,
    line: UInt
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame: CGRect = .null
    var stableHits: UInt = 0
    while Date() < deadline {
      let frameOK = !frame.isEmpty
      let hittableOK = !requireHittable || isHittable
      if !exists || !frameOK || !hittableOK {
        try? await Task.sleep(for: .seconds(Self.framePollInterval))
        continue
      }
      if frame == lastFrame {
        stableHits += 1
        if stableHits >= Self.requiredStableFrameReads { return }
      } else {
        stableHits = 0
        lastFrame = frame
      }
      try? await Task.sleep(for: .seconds(Self.framePollInterval))
    }
    let hittableOK = !requireHittable || isHittable
    XCTAssertTrue(
      exists && !frame.isEmpty && hittableOK,
      "Element not stable for tap within \(timeout)s (frame=\(frame), hittable=\(isHittable))",
      file: file,
      line: line
    )
  }
}

@MainActor
extension XCUICoordinate {
  /// Touches down and up again at this coordinate, holding for `duration` unless it is zero.
  func press(holdingFor duration: TimeInterval) {
    if duration > 0 {
      press(forDuration: duration)
    } else {
      tap()
    }
  }
}

@MainActor
extension XCUIElement {
  private static let scrollDragStart = CGVector(dx: 0.5, dy: 0.8)
  private static let scrollDragEnd = CGVector(dx: 0.5, dy: 0.2)
  private static let scrollGestureDuration: TimeInterval = 0.01

  /**
   Scroll/swipe this scrollable container until `element` becomes visible.
   Returns the element if it was made visible, otherwise `nil`.
   */
  @discardableResult
  public func makeVisible(element: XCUIElement, maxAttempts: UInt = 10) -> XCUIElement? {
    if elementType == .scrollView || elementType == .collectionView || elementType == .table {
      let visible =
        scroll(toward: element, maxAttempts: maxAttempts)
        || swipe(toward: element, maxAttempts: maxAttempts)
      return visible ? element : nil
    }
    return swipe(toward: element, maxAttempts: maxAttempts) ? element : nil
  }

  private func scroll(toward element: XCUIElement, maxAttempts: UInt) -> Bool {
    var attempts: UInt = 0
    while !element.isVisible, attempts < maxAttempts {
      let start = coordinate(withNormalizedOffset: Self.scrollDragStart)
      let end = coordinate(withNormalizedOffset: Self.scrollDragEnd)
      start.press(forDuration: Self.scrollGestureDuration, thenDragTo: end)
      attempts += 1
    }
    return element.isVisible
  }

  private func swipe(toward element: XCUIElement, maxAttempts: UInt) -> Bool {
    var attempts: UInt = 0
    while !element.isVisible, attempts < maxAttempts {
      swipeUp()
      attempts += 1
    }
    return element.isVisible
  }
}

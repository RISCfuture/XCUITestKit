import XCTest

@MainActor
extension XCUIElement {
  /// Whether the element exists, has a non-empty frame, and lies within the
  /// app's first window.
  public var isVisible: Bool {
    guard exists, !frame.isEmpty else { return false }
    let app = XCUIApplication()
    guard let firstWindow = app.windows.allElementsBoundByIndex.first else { return false }
    return firstWindow.frame.contains(frame)
  }

  /// Tap if hittable, otherwise tap the element's center coordinate — which
  /// skips activation-point hit-testing that iOS 26 "Liquid Glass" overlays and
  /// iPad SwiftUI cells often fail.
  public func forceTap() {
    if isHittable {
      tap()
    } else {
      coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
  }

  /// Tap via center coordinate after waiting for the element's frame to settle.
  ///
  /// Under simulator load, SwiftUI Form/List views can be mid-relayout when
  /// XCUITest computes an activation point — the system then refuses the tap
  /// with "Activation point invalid and no suggested hit points." Polling for
  /// consecutive identical frame reads guarantees a settled target, and tapping
  /// via the center coordinate skips activation-point resolution entirely.
  @discardableResult
  public func tapStable(
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    waitForFrameStability(requireHittable: true, timeout: timeout, file: file, line: line)
    coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    return self
  }

  /// Like ``tapStable(timeout:file:line:)`` but does not require `isHittable`.
  ///
  /// Use for SwiftUI controls (e.g. `.pickerStyle(.navigationLink)` rows) whose
  /// backing element can report `isHittable == false` for the entire wait
  /// window while still being visibly tappable.
  @discardableResult
  public func coordinateTapWhenFrameStable(
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    waitForFrameStability(requireHittable: false, timeout: timeout, file: file, line: line)
    coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    return self
  }

  private func waitForFrameStability(
    requireHittable: Bool,
    timeout: TimeInterval,
    file: StaticString,
    line: UInt
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    var lastFrame: CGRect = .null
    var stableHits = 0
    while Date() < deadline {
      let frameOK = !frame.isEmpty
      let hittableOK = !requireHittable || isHittable
      if !exists || !frameOK || !hittableOK {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        continue
      }
      if frame == lastFrame {
        stableHits += 1
        if stableHits >= 2 { return }
      } else {
        stableHits = 0
        lastFrame = frame
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
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
extension XCUIElement {
  /// Scroll/swipe this scrollable container until `element` becomes visible.
  /// Returns the element if it was made visible, otherwise `nil`.
  @discardableResult
  public func makeVisible(element: XCUIElement, maxAttempts: Int = 10) -> XCUIElement? {
    if elementType == .scrollView || elementType == .collectionView || elementType == .table {
      let visible =
        scroll(toward: element, maxAttempts: maxAttempts)
        || swipe(toward: element, maxAttempts: maxAttempts)
      return visible ? element : nil
    }
    return swipe(toward: element, maxAttempts: maxAttempts) ? element : nil
  }

  private func scroll(toward element: XCUIElement, maxAttempts: Int) -> Bool {
    var attempts = 0
    while !element.isVisible, attempts < maxAttempts {
      let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      start.press(forDuration: 0.01, thenDragTo: end)
      attempts += 1
    }
    return element.isVisible
  }

  private func swipe(toward element: XCUIElement, maxAttempts: Int) -> Bool {
    var attempts = 0
    while !element.isVisible, attempts < maxAttempts {
      swipeUp()
      attempts += 1
    }
    return element.isVisible
  }
}

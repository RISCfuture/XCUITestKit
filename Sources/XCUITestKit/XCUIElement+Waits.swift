import XCTest

@MainActor
extension XCUIElement {
  /// Wait for the element to exist within the project-wide default timeout.
  /// Returns whether it appeared (does not assert).
  @discardableResult
  public func wait(timeout: TimeInterval = ScaledTimeouts.element) -> Bool {
    waitForExistence(timeout: timeout)
  }

  /// Short-window existence probe. Pass the *base* seconds; the CI multiplier
  /// is applied automatically.
  @discardableResult
  public func wait(scaledSeconds seconds: TimeInterval) -> Bool {
    waitForExistence(timeout: ScaledTimeouts.scaled(seconds))
  }

  /// Wait for a predicate to evaluate true on this element. Returns whether the
  /// predicate was satisfied within the timeout (does not assert).
  public func waitFor(
    _ predicate: NSPredicate,
    timeout: TimeInterval = ScaledTimeouts.element
  ) -> Bool {
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }

  /// Wait for the element to become hittable. Returns whether it did.
  @discardableResult
  public func waitUntilHittable(timeout: TimeInterval = ScaledTimeouts.short) -> Bool {
    waitFor(NSPredicate(format: "isHittable == true"), timeout: timeout)
  }

  /// Wait for the element to appear and fail the test if it does not.
  @discardableResult
  public func assertExists(
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if !waitForExistence(timeout: timeout) {
      XCTFail("Element did not appear within \(timeout)s: \(self)", file: file, line: line)
    }
    return self
  }

  /// Wait for the element to no longer exist. Fails the test if it remains.
  @discardableResult
  public func assertHidden(
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if exists, !waitForNonExistence(timeout: timeout) {
      XCTFail("Element did not disappear within \(timeout)s: \(self)", file: file, line: line)
    }
    return self
  }

  /// Assert that the element never appears within the given window.
  ///
  /// Guards against state that surfaces a beat after the trigger that produced
  /// it: `waitForExistence` returning false covers the whole window rather than
  /// a single instant like `XCTAssertFalse(exists)`.
  @discardableResult
  public func assertNeverAppears(
    within window: TimeInterval = ScaledTimeouts.short,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if waitForExistence(timeout: window) {
      XCTFail("Element unexpectedly appeared within \(window)s: \(self)", file: file, line: line)
    }
    return self
  }
}

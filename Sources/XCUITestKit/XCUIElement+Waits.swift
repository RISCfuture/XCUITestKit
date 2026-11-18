public import XCTest

// Waits that return as soon as their condition holds.
//
// XCTest's own waits — `waitForExistence(timeout:)`, `waitForNonExistence(timeout:)`, and an
// `XCTWaiter` over an `XCTNSPredicateExpectation` — take about a second to report a condition that
// already holds, against a few milliseconds for reading `exists`. An XCUITest action waits for the
// app to go idle before it returns, so most waits that follow one are already satisfied. Each wait
// here checks the condition once before handing over to XCTest, and pays for XCTest's wait only
// when there is something to wait for.
//
// Returning at once means a wait can be answered by the screen being left. A control that the
// outgoing and incoming screens share, or a row a deletion is still animating away, satisfies
// the wait before the transition has happened. After an action that replaces what is on screen,
// first wait for something the old state shows to go (`waitUntilGone(timeout:)`) or for a
// value that only the new state has, such as a progress label reading the next card.
@MainActor
extension XCUIElement {
  /**
   Wait for the element to exist within the project-wide default timeout.
   Returns whether it appeared (does not assert).

   Returns at once when the element already exists.
   */
  @discardableResult
  public func wait(timeout: TimeInterval = ScaledTimeouts.element) -> Bool {
    exists || waitForExistence(timeout: timeout)
  }

  /**
   Short-window existence probe. Pass the *base* seconds; the CI multiplier
   is applied automatically.

   Returns at once when the element already exists.
   */
  @discardableResult
  public func wait(scaledSeconds seconds: TimeInterval) -> Bool {
    wait(timeout: ScaledTimeouts.scaled(seconds))
  }

  /**
   Wait for the element to stop existing. Returns whether it was gone within
   the timeout (does not assert).

   Returns at once when the element is already gone. To check that an
   element is absent from a screen that has settled, read `!exists` instead;
   this is for one that may still be on its way out, such as a dismissing
   sheet or keyboard.
   */
  @discardableResult
  public func waitUntilGone(timeout: TimeInterval = ScaledTimeouts.element) -> Bool {
    !exists || waitForNonExistence(timeout: timeout)
  }

  /**
   Wait for a predicate to evaluate true on this element. Returns whether the
   predicate was satisfied within the timeout (does not assert).

   Returns at once when the element exists and already satisfies the
   predicate. The predicate is evaluated against the element itself, as
   `XCTNSPredicateExpectation` evaluates it.
   */
  public func waitFor(
    _ predicate: NSPredicate,
    timeout: TimeInterval = ScaledTimeouts.element
  ) -> Bool {
    if exists, predicate.evaluate(with: self) { return true }
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
    return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
  }

  /**
   Wait for the element to become hittable. Returns whether it did.

   Returns at once when the element is already hittable.
   */
  @discardableResult
  public func waitUntilHittable(timeout: TimeInterval = ScaledTimeouts.short) -> Bool {
    waitFor(NSPredicate(format: "isHittable == true"), timeout: timeout)
  }

  /**
   Wait for the element to appear and fail the test if it does not.

   An optional `message` is appended to the kit's auto-generated failure text
   (which already names the element and timeout), so callers get both.
   */
  @discardableResult
  public func assertExists(
    _ message: @autoclosure () -> String = "",
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if !wait(timeout: timeout) {
      XCTFail(
        "Element did not appear within \(timeout)s: \(self)\(detailSuffix(message()))",
        file: file,
        line: line
      )
    }
    return self
  }

  /**
   Wait for the element to no longer exist. Fails the test if it remains.

   Returns at once when the element is already gone.
   */
  @discardableResult
  public func assertHidden(
    _ message: @autoclosure () -> String = "",
    timeout: TimeInterval = ScaledTimeouts.element,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if !waitUntilGone(timeout: timeout) {
      XCTFail(
        "Element did not disappear within \(timeout)s: \(self)\(detailSuffix(message()))",
        file: file,
        line: line
      )
    }
    return self
  }

  /**
   Assert that the element never appears within the given window.

   Guards against state that surfaces a beat after the trigger that produced
   it: `waitForExistence` returning false covers the whole window rather than
   a single instant like `XCTAssertFalse(exists)`. An element that is
   already present fails at once rather than after XCTest's own wait.
   */
  @discardableResult
  public func assertNeverAppears(
    _ message: @autoclosure () -> String = "",
    within window: TimeInterval = ScaledTimeouts.short,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> Self {
    if wait(timeout: window) {
      XCTFail(
        "Element unexpectedly appeared within \(window)s: \(self)\(detailSuffix(message()))",
        file: file,
        line: line
      )
    }
    return self
  }

  private func detailSuffix(_ message: String) -> String {
    message.isEmpty ? "" : " — \(message)"
  }
}

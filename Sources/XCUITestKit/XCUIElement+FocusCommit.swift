public import XCTest

@MainActor
extension XCUIElement {
  /**
   Commit this field by moving first responder to another focusable element.

   A `TextField(value:format:)` only writes to its binding when editing ends.
   A `numberPad` / `decimalPad` has no Return key, and when the form fits
   onscreen the keyboard can't be dismissed by scroll or tap-away — so the only
   reliable way to end editing is to move focus to another field. Pass a sibling
   `other` element (already scrolled into view by the caller); this taps it to
   take first responder, committing `self`.

   Unlike the keyboard-centric text-entry helpers this lives outside any
   soft-keyboard assumption — it only taps a sibling — so it is available on
   every platform.
   */
  public func commitByMovingFocus(
    to other: XCUIElement,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      other.waitForExistence(timeout: ScaledTimeouts.element),
      "Sibling field for focus-commit never appeared",
      file: file,
      line: line
    )
    other.forceTap()
  }
}

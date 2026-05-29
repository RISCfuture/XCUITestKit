import XCTest

@MainActor
extension XCUIElement {
  /// Clear any existing text in this field and type `text`.
  ///
  /// Hardening, consolidated from three apps' independent fixes:
  ///
  /// 1. Dismisses an iPad keyboard popover if one is covering the field.
  /// 2. Taps the field and waits for the soft keyboard to surface, retrying up
  ///    to three times. Under CI load the first tap can land before the field
  ///    is ready to accept focus; without a hardware keyboard the soft keyboard
  ///    appearing is a reliable focus signal.
  /// 3. **Asserts** the keyboard actually surfaced before typing. Otherwise
  ///    `typeText` dispatches into a window with no first responder and fails
  ///    deep in the run with the opaque "Neither element nor any descendant has
  ///    keyboard focus." Failing here is attributable, and a genuine transient
  ///    is re-run by the CI `-retry-tests-on-failure` pass.
  /// 4. Selects existing text via triple-tap, falling back to hardware Cmd+A on
  ///    iPad where iOS 26 "Liquid Glass" reports the field as not-hittable and
  ///    the triple-tap is interpreted as word selection.
  public func clearAndType(
    _ text: String,
    app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    if app.otherElements["PopoverDismissRegion"].exists {
      app.otherElements["PopoverDismissRegion"].tap()
    }

    let keyboard = app.keyboards.firstMatch
    var keyboardDidSurface = false
    for _ in 0..<3 {
      forceTap()
      if keyboard.waitForExistence(timeout: ScaledTimeouts.scaled(2)) {
        keyboardDidSurface = true
        break
      }
    }
    XCTAssertTrue(
      keyboardDidSurface,
      "Keyboard never surfaced for text field after 3 taps; aborting before typing into \(self)",
      file: file,
      line: line
    )

    #if os(iOS)
      if isHittable {
        tap(withNumberOfTaps: 3, numberOfTouches: 1)
      } else {
        typeKey("a", modifierFlags: .command)
      }
    #else
      typeKey("a", modifierFlags: .command)
    #endif

    if let currentValue = value as? String, !currentValue.isEmpty {
      let deletion = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
      typeText(deletion)
    }
    typeText(text)
  }
}

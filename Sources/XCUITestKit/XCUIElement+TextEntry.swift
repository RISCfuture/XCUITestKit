import XCTest

#if os(iOS)
  @MainActor
  extension XCUIElement {
    private static let keyboardSurfaceAttempts: UInt = 3
    private static let clearAttempts: UInt = 5
    private static let keyboardSurfaceTimeout: TimeInterval = 2
    private static let deleteSlack = 2
    private static let fieldEndOffset = CGVector(dx: 0.95, dy: 0.5)

    /**
     Clear any existing text in this field, type `text`, then dismiss the
     keyboard.

     Hardening for iPad / iOS 26 text-field focus and clearing:

     1. Dismisses an iPad keyboard popover if one is covering the field.
     2. Taps the field (center, via ``forceTap()``) and waits for the soft
        keyboard, retrying up to ``keyboardSurfaceAttempts`` times. Under CI
        load the first tap can land before the field is ready to accept focus;
        without a hardware keyboard the soft keyboard appearing is a reliable
        focus signal.
     3. **Asserts** the keyboard surfaced before typing. Otherwise `typeText`
        dispatches into a window with no first responder and fails deep in the
        run with the opaque "Neither element nor any descendant has keyboard
        focus." Failing here is attributable, and a genuine transient is re-run
        by the CI `-retry-tests-on-failure` pass.
     4. **Clears completely, verifying by reading the value back.** Triple-tap
        select-all is unreliable on iPad iOS 26 — it registers as word selection
        or fails as "not hittable", leaving text the new value is *prepended*
        to. Instead the caret is moved to the end of the text and the value is
        deleted backwards, looping until the field reads empty (an empty field
        reports its placeholder as `value`).
     5. **Dismisses the keyboard.** `TextField(value:format:)` only writes to
        its binding when editing ends, and a keyboard left up covers the
        controls a test taps next. ``XCUIApplication/dismissKeyboardStable(doneButtonIdentifier:)``
        resigns first responder and waits for the keyboard window to leave.

     - Parameter perCharacter: Type one character at a time instead of a single
       `typeText` burst. Set this for fields backed by a self-canonicalizing
       formatter (e.g. a fractional/decimal-shift `TextField(value:format:)`)
       where a single burst can race the format round-trip and corrupt the
       buffer (typing `2.4` can land `0.24`). XCUITest waits for app-idle
       between per-character calls, giving the canonical sync time to settle.
     - Parameter doneButtonIdentifier: Forwarded to the final
       ``XCUIApplication/dismissKeyboardStable(doneButtonIdentifier:)``. Pass a
       keyboard-accessory Done button's identifier for `numberPad`/`decimalPad`
       fields that have no Return key, so dismissal is deterministic rather than
       relying on the nav-bar/swipe fallbacks.
     */
    public func clearAndType(
      _ text: String,
      app: XCUIApplication,
      perCharacter: Bool = false,
      doneButtonIdentifier: String? = nil,
      file: StaticString = #filePath,
      line: UInt = #line
    ) {
      dismissCoveringPopover(in: app)

      XCTAssertTrue(
        focusAndSurfaceKeyboard(in: app),
        "Keyboard never surfaced for text field after \(Self.keyboardSurfaceAttempts) taps; "
          + "aborting before typing into \(self)",
        file: file,
        line: line
      )

      clearExistingText()
      type(text, perCharacter: perCharacter)
      app.dismissKeyboardStable(doneButtonIdentifier: doneButtonIdentifier)
    }

    private func type(_ text: String, perCharacter: Bool) {
      if perCharacter {
        for character in text { typeText(String(character)) }
      } else {
        typeText(text)
      }
    }

    private func dismissCoveringPopover(in app: XCUIApplication) {
      let popover = app.otherElements["PopoverDismissRegion"]
      if popover.exists { popover.tap() }
    }

    private func focusAndSurfaceKeyboard(in app: XCUIApplication) -> Bool {
      let keyboard = app.keyboards.firstMatch
      for _ in 0..<Self.keyboardSurfaceAttempts {
        forceTap()
        if keyboard.waitForExistence(timeout: ScaledTimeouts.scaled(Self.keyboardSurfaceTimeout)) {
          return true
        }
      }
      return false
    }

    private func clearExistingText() {
      let placeholder = placeholderValue ?? ""
      for _ in 0..<Self.clearAttempts {
        let current = (value as? String) ?? ""
        guard !current.isEmpty, current != placeholder else { return }
        // Position the caret at the end of the existing text (the field is already
        // focused, so this tap lands) and delete backwards. Triple-tap select-all
        // is unreliable on iPad iOS 26 — it registers as word selection or fails
        // as "not hittable" — so clear with backspaces instead. A couple of extra
        // deletes cover any caret-position slack and no-op on an empty field.
        coordinate(withNormalizedOffset: Self.fieldEndOffset).tap()
        typeText(
          String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: current.count + Self.deleteSlack
          )
        )
      }
    }
  }
#endif

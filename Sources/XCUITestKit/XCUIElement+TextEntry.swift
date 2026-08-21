import XCTest

#if os(iOS)
  @MainActor
  extension XCUIElement {
    private static let keyboardSurfaceAttempts: UInt = 3
    private static let clearAttempts: UInt = 5
    private static let entryAttempts: UInt = 3
    private static let keyboardSurfaceTimeout: TimeInterval = 2
    private static let deleteSlack = 2
    private static let caretSettleSeconds: TimeInterval = 0.5
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
     4. **Empties the field before typing, unless asked to type over its
        selection** (`replacingSelection`). Triple-tap
        select-all is unreliable on iPad iOS 26 — it registers as word selection
        or fails as "not hittable", leaving text the new value is *prepended*
        to. Instead the caret is moved to the end of the text and the value is
        deleted backwards, looping until the field reads empty (an empty field
        reports its placeholder as `value`).
     5. **Dismisses the keyboard.** `TextField(value:format:)` only writes to
        its binding when editing ends, and a keyboard left up covers the
        controls a test taps next. ``XCUIApplication/dismissKeyboardStable(doneButtonIdentifier:)``
        resigns first responder and waits for the keyboard window to leave.
     6. **Reads the value back and retries the entry, when asked to.** Opt in
        with `verifying`, and only for a field whose display can be compared to
        what was typed — see that parameter.

     - Parameter perCharacter: Type one character at a time instead of a single
       `typeText` burst. Set this for fields backed by a self-canonicalizing
       formatter (e.g. a fractional/decimal-shift `TextField(value:format:)`)
       where a single burst can race the format round-trip and corrupt the
       buffer (typing `2.4` can land `0.24`). XCUITest waits for app-idle
       between per-character calls, giving the canonical sync time to settle.
     - Parameter replacingSelection: Type over the field's on-focus selection
       instead of emptying it first. Set this for a `.selectAllOnFocus()` field,
       whose value arrives selected so the typed text replaces it — clearing one
       of those first is what leaves a digit of the old value behind for the new
       one to land against. Left off, the field is emptied before typing, which
       is what a field with no on-focus selection needs: typing into it simply
       appends. A retry clears regardless, for the field whose selection a pass
       raced.
     - Parameter verifying: Read the value back and retry the whole entry, up to
       ``entryAttempts`` times, when it does not reflect `text` — each retry
       escalating to per-character typing so a self-canonicalizing formatter
       settles. Set this for a field that can take an entry silently wrong (a
       `.decimalPad` `TextField(value:format:)` whose binding never wrote, or a
       burst that raced the formatter), where the cost of carrying on with the
       wrong number is a test that fails somewhere unrelated.

       **Off by default, because a read-back is only evidence for a field that
       displays what was typed.** A field converting units or otherwise
       reformatting shows something a comparison cannot reconcile with the typed
       text — `5` entered into a distance field bound through
       `.converted(to:)` reads back as the same distance in another unit — and
       verification then judges a good entry failed and retries, clearing the
       value that had just committed. Leave it off there; the entry is fine, only
       the checking is not.
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
      replacingSelection: Bool = false,
      verifying: Bool = false,
      doneButtonIdentifier: String? = nil,
      file: StaticString = #filePath,
      line: UInt = #line
    ) {
      dismissCoveringPopover(in: app)

      let attempts = verifying ? Self.entryAttempts : 1
      for attempt in 1...attempts {
        let isLastAttempt = attempt == attempts

        guard focusAndSurfaceKeyboard() else {
          if isLastAttempt {
            XCTFail(
              "Keyboard never surfaced for text field after \(Self.keyboardSurfaceAttempts) taps; "
                + "aborting before typing into \(self)",
              file: file,
              line: line
            )
          }
          continue
        }

        // A `.selectAllOnFocus()` field arrives with its value selected, and typing
        // over that selection replaces it — clearing such a field first is what
        // corrupts it. A retry clears anyway, for the pass whose selection raced.
        if !replacingSelection || attempt > 1 { clearExistingText() }
        type(text, perCharacter: perCharacter || attempt > 1)
        app.dismissKeyboardStable(doneButtonIdentifier: doneButtonIdentifier)

        guard verifying else { return }
        if committed(text) { return }

        if isLastAttempt {
          XCTFail(
            "Field did not accept “\(text)” after \(attempts) attempts; reads "
              + "“\((value as? String) ?? "")”. A TextField(value:format:) binding may not be "
              + "committing on keyboard dismissal.",
            file: file,
            line: line
          )
        }
      }
    }

    /// Whether the field's committed value reflects `text`.
    private func committed(_ text: String) -> Bool {
      EnteredValue.matches(typed: text, readBack: (value as? String) ?? "")
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

    private func focusAndSurfaceKeyboard() -> Bool {
      for _ in 0..<Self.keyboardSurfaceAttempts {
        forceTap()
        if waitForKeyboardFocus(timeout: ScaledTimeouts.scaled(Self.keyboardSurfaceTimeout)) {
          return true
        }
      }
      return false
    }

    /// Whether *this* field holds keyboard focus, waiting up to `timeout`.
    ///
    /// Confirming `self.hasKeyboardFocus` — that this element is first responder —
    /// rather than that `app.keyboards.firstMatch` merely exists is what makes
    /// back-to-back field entry reliable. On iPad iOS 26 the previous field's
    /// keyboard lingers, so a keyboard-existence check is already satisfied
    /// before the tap focuses this field; the focusing tap is then taken as a
    /// no-op "success" and the following `typeText` dispatches into a window
    /// whose first responder is the wrong field (or none), failing with the
    /// opaque "Neither element nor any descendant has keyboard focus." Requiring
    /// this element to be first responder forces the tap to retry until it
    /// actually takes.
    private func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
      let focused = NSPredicate(format: "hasKeyboardFocus == true")
      let expectation = XCTNSPredicateExpectation(predicate: focused, object: self)
      return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Put the caret after the field's last character, keeping first responder.
    ///
    /// The right-edge tap is what makes the backspaces below delete from the end
    /// rather than from wherever focus happened to leave the caret. It can also
    /// land outside the editable area — on a unit label or a stepper sharing the
    /// row — which resigns first responder, and the `typeText` that follows then
    /// dispatches into a window that has none, failing the test outright with
    /// "Neither element nor any descendant has keyboard focus". Re-focusing when
    /// that happens keeps the clear going on a field the tap missed.
    private func moveCaretToEnd() {
      coordinate(withNormalizedOffset: Self.fieldEndOffset).tap()
      guard !waitForKeyboardFocus(timeout: ScaledTimeouts.scaled(Self.caretSettleSeconds)) else {
        return
      }
      _ = focusAndSurfaceKeyboard()
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
        moveCaretToEnd()
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

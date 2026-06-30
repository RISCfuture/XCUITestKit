import XCTest

#if os(iOS)
  import UIKit

  @MainActor
  extension XCUIElement {
    private static let keyboardSurfaceAttempts: UInt = 3
    private static let clearAttempts: UInt = 5
    private static let entryAttempts: UInt = 3
    private static let keyboardSurfaceTimeout: TimeInterval = 2
    private static let deleteSlack = 2
    private static let fieldEndOffset = CGVector(dx: 0.95, dy: 0.5)

    /// How to clear the field on a given attempt. The first attempt types over
    /// the field's on-focus selection — the reliable path for a
    /// `.selectAllOnFocus()` field, where the typed value replaces the whole
    /// selection. If that does not commit (a field with no on-focus selection,
    /// or one whose selection a pass raced), later attempts empty the field
    /// first — caret to the end, then delete backward — and type into it.
    ///
    /// The first-attempt replace relies on the selection being *stable* once the
    /// keyboard is driven. A `.selectAllOnFocus()` that calls `selectAll`
    /// synchronously inside `textDidBeginEditing` is undone by SwiftUI's focus
    /// re-render of a value-formatted field — it deselects and parks the caret at
    /// the end, so the typed value appends or prepends instead of replacing.
    /// Defer the selection one run loop in the app so it survives; the
    /// empty-then-type fallback recovers the entry if it does not.
    private static func clearStrategy(attempt: UInt) -> ClearStrategy {
      attempt == 1 ? .replaceSelection : .caretToEndThenDelete
    }

    /**
     Clear any existing text in this field, type `text`, then dismiss the
     keyboard.

     Hardening for iOS 26 text-field focus and clearing:

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
     4. **Clears the field, escalating if a pass does not take.** The first
        attempt types over the field's on-focus selection: a
        `.selectAllOnFocus()` field has its value selected, so the typed text
        replaces it. If that does not commit (a field with no on-focus
        selection, or one whose selection raced), later attempts empty the field
        first — caret to the end (a right-edge tap), then delete backward — and
        type into a clean field. Triple-tap select-all is avoided throughout: on
        iPad iOS 26 it registers as word selection or fails "not hittable".
     5. **Dismisses the keyboard.** `TextField(value:format:)` only writes to
        its binding when editing ends, and a keyboard left up covers the
        controls a test taps next. ``XCUIApplication/dismissKeyboardStable(doneButtonIdentifier:)``
        resigns first responder and waits for the keyboard window to leave.
     6. **Verifies the value committed, retrying the whole entry if not.** A
        `.decimalPad` `TextField(value:format:)` can read back empty (the
        dismissal failed to end editing) or corrupted (a burst raced the
        formatter), neither of which a single pass detects. Each retry escalates
        to per-character typing so a self-canonicalizing formatter settles.

     For a `.selectAllOnFocus()` field the first-attempt replace only works if
     the selection is stable once the keyboard is driven; see
     ``clearStrategy(attempt:)``.

     - Parameter perCharacter: Type one character at a time instead of a single
       `typeText` burst. Set this for fields backed by a self-canonicalizing
       formatter (e.g. a fractional/decimal-shift `TextField(value:format:)`)
       where a single burst can race the format round-trip and corrupt the
       buffer (typing `2.4` can land `0.24`). XCUITest waits for app-idle
       between per-character calls, giving the canonical sync time to settle.
       A retry escalates to per-character typing automatically, so passing
       `true` only front-loads it on the first attempt.
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

      for attempt in 1...Self.entryAttempts {
        let isLastAttempt = attempt == Self.entryAttempts

        guard focusAndSurfaceKeyboard() else {
          if isLastAttempt {
            XCTFail(
              "Keyboard never surfaced for text field after \(Self.keyboardSurfaceAttempts) taps; "
                + "aborting before typing into \(self)",
              file: file,
              line: line
            )
            return
          }
          continue
        }

        clearExistingText(using: Self.clearStrategy(attempt: attempt))
        type(text, perCharacter: perCharacter || attempt > 1)
        app.dismissKeyboardStable(doneButtonIdentifier: doneButtonIdentifier)

        if committed(text) { return }

        if isLastAttempt {
          XCTFail(
            "Field did not accept “\(text)” after \(Self.entryAttempts) attempts; "
              + "reads “\((value as? String) ?? "")”. A TextField(value:format:) binding "
              + "may not be committing on keyboard dismissal.",
            file: file,
            line: line
          )
        }
      }
    }

    /// Whether the field's value reflects `text` after a commit.
    ///
    /// Compared numerically when both the typed text and the read-back value
    /// parse as numbers, so a field that drops a trailing zero (`"1.0"` → `"1"`)
    /// or regroups and suffixes units (`"4550"` → `"4,550 lb"`) still matches,
    /// while a genuinely wrong value (typed `"4000"`, read back `"40.0"`) is
    /// still rejected. A `text` with no digits is matched by substring; a
    /// read-back that doesn't parse as a number falls back to a digit comparison.
    private func committed(_ text: String) -> Bool {
      let numerals: (String) -> String = { $0.filter { $0.isNumber || $0 == "." } }
      let current = (value as? String) ?? ""
      let expected = numerals(text)
      if expected.isEmpty { return current.contains(text) }
      if let expectedValue = Double(expected), let currentValue = Double(numerals(current)) {
        return expectedValue == currentValue
      }
      return numerals(current) == expected
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

    private func clearExistingText(using strategy: ClearStrategy) {
      // A `.selectAllOnFocus()` field has its text selected on focus, so the type
      // that follows replaces it — don't clear. This is the first-attempt path;
      // a later attempt empties the field instead (see `clearStrategy(attempt:)`).
      if strategy == .replaceSelection { return }

      let placeholder = placeholderValue ?? ""
      for _ in 0..<Self.clearAttempts {
        let current = (value as? String) ?? ""
        guard !current.isEmpty, current != placeholder else { return }
        // Move the caret to the end and delete backward. Triple-tap select-all is
        // unreliable on iPad iOS 26 — it registers as word selection or fails as
        // "not hittable" — so clear with backspaces. A couple of extra deletes
        // cover caret-position slack and no-op on an empty field.
        coordinate(withNormalizedOffset: Self.fieldEndOffset).tap()
        typeText(
          String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: current.count + Self.deleteSlack
          )
        )
      }
    }

    /// How to clear the field before typing, by attempt.
    private enum ClearStrategy {
      /// Empty the field first: move the caret to the end (right-edge tap), then
      /// delete backward. The fallback for a field with no on-focus selection.
      case caretToEndThenDelete
      /// Don't clear: rely on the field's on-focus selection so the typed value
      /// replaces it. The first-attempt path for a `.selectAllOnFocus()` field.
      case replaceSelection
    }
  }
#endif

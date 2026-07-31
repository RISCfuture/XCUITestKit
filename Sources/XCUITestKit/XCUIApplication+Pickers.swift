#if os(iOS)
  import XCTest

  @MainActor
  extension XCUIApplication {
    /**
     Choose an option from a menu-style SwiftUI `Picker`: open `picker`, then tap `option` beneath it.

     The iOS counterpart to ``clickMenuItem(_:in:timeout:file:line:)``. A `Picker` in a `Form`
     renders as a pop-up button whose options exist only while the menu is open, so both halves
     have to happen in one helper — the option cannot be queried beforehand.

     Both the picker and its options are matched by accessibility identifier. A `Picker`'s
     options keep the identifiers their content carries, so a `Text("IFR").tag(…)` marked
     `.accessibilityIdentifier("ratingIFR")` is reachable as `ratingIFR` once the menu is open.

     A picker far enough down a form may not be in the element tree at all until the list is
     scrolled, so this scrolls to bring it in before opening it, then clears it of the floating
     bars that report a control as hittable while swallowing its taps.

     - Parameters:
       - option: The accessibility identifier of the option to choose.
       - picker: The accessibility identifier of the picker to open.
       - timeout: How long to wait for the picker and then the option. Defaults to
         ``ScaledTimeouts/element``.
     - Returns: The option element (already tapped), or `nil` if the picker or option never
       appeared, having failed the test.
     */
    @discardableResult
    public func selectPickerOption(
      _ option: String,
      in picker: String,
      timeout: TimeInterval = ScaledTimeouts.element,
      file: StaticString = #filePath,
      line: UInt = #line
    ) -> XCUIElement? {
      guard openPicker(picker, timeout: timeout, file: file, line: line) else { return nil }

      let item = buttons[option]
      guard item.waitForExistence(timeout: timeout) else {
        XCTFail(
          "Could not find option \"\(option)\" in picker \"\(picker)\"",
          file: file,
          line: line
        )
        return nil
      }
      item.forceTap()
      return item
    }

    /// Scrolls a picker into reach, clears it of the floating bars, and opens its menu.
    ///
    /// ``makeVisible(element:)`` scrolls toward the picker from wherever the form currently
    /// sits; one it cannot reach that way is looked for again from the top.
    private func openPicker(
      _ picker: String,
      timeout: TimeInterval,
      file: StaticString,
      line: UInt
    ) -> Bool {
      let control = buttons[picker]
      let container = collectionViews.firstMatch

      if container.exists, container.makeVisible(element: control) == nil {
        scrollToTop()
        _ = container.makeVisible(element: control)
      }

      guard control.waitForExistence(timeout: timeout) else {
        XCTFail("Could not find picker \"\(picker)\"", file: file, line: line)
        return false
      }

      scrollIntoSafeBand(control)
      control.forceTap()
      return true
    }
  }
#endif

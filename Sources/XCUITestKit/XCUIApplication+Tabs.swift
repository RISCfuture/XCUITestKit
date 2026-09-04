#if os(macOS)
  public import XCTest

  @MainActor
  extension XCUIApplication {
    /// The stable accessibility identifier AppKit gives a SwiftUI `Settings` scene's
    /// window. The window's *title* tracks the selected tab, so it changes as tabs are
    /// switched while this identifier stays put.
    public static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"

    /**
     Select a SwiftUI `TabView` tab by its label — the macOS counterpart to iOS `tapTab`.

     macOS renders a `TabView`'s `tabItem`s as a row of `Button`s whose **`title`** carries
     the tab name (their `label` is empty), which is why a plain `buttons[name]` subscript —
     matching identifier or label — misses them. This matches `title` or `label` and clicks
     the tab.

     For a `Settings` scene, prefer `selectSettingsTab(_:)`, which additionally confirms the
     switch landed. In an ordinary window a `TabView` gives no comparable signal, so this
     returns after the click without confirming.

     - Parameters:
       - title: The tab's label, as given to its `tabItem`.
       - timeout: How long to wait for the tab control. Defaults to `ScaledTimeouts.element`.
       - file: Source file to attribute a failure to. Defaults to the caller's.
       - line: Source line to attribute a failure to. Defaults to the caller's.
     - Returns: the tab button element (already clicked).
     */
    @discardableResult
    public func selectTab(
      _ title: String,
      timeout: TimeInterval = ScaledTimeouts.element,
      file: StaticString = #filePath,
      line: UInt = #line
    ) -> XCUIElement {
      let tab = buttons.matching(NSPredicate(format: "title == %@ OR label == %@", title, title))
        .firstMatch
      if !tab.waitForExistence(timeout: timeout) {
        XCTFail("Tab “\(title)” not found within \(timeout)s", file: file, line: line)
      }
      tab.click()
      return tab
    }

    /**
     Open the app's `Settings` scene (⌘,) and return its window.

     - Parameter timeout: How long to wait for the window. Defaults to `ScaledTimeouts.element`.
     - Returns: the settings window element, whether or not it appeared within `timeout`.
     */
    @discardableResult
    public func openSettings(timeout: TimeInterval = ScaledTimeouts.element) -> XCUIElement {
      typeKey(",", modifierFlags: .command)
      let window = windows.matching(identifier: Self.settingsWindowIdentifier).firstMatch
      _ = window.waitForExistence(timeout: timeout)
      return window
    }

    /**
     Select a `Settings` scene tab and confirm the switch landed.

     Clicks the tab (see `selectTab(_:)`) and then waits for the settings window's **title**
     to become `title` — the reliable signal that the selected tab actually changed, since a
     `Settings` window retitles to its active tab. Asserting a tab-specific control appeared
     is unreliable: a menu-style `Picker`'s identifier does not surface to the accessibility
     tree at all, so the window title is the dependable confirmation.

     Call `openSettings()` first (or otherwise open Settings) so the window exists.

     - Parameters:
       - title: The tab's label, as given to its `tabItem`.
       - timeout: How long to wait for the switch. Defaults to `ScaledTimeouts.element`.
       - file: Source file to attribute a failure to. Defaults to the caller's.
       - line: Source line to attribute a failure to. Defaults to the caller's.
     - Returns: the settings window element.
     */
    @discardableResult
    public func selectSettingsTab(
      _ title: String,
      timeout: TimeInterval = ScaledTimeouts.element,
      file: StaticString = #filePath,
      line: UInt = #line
    ) -> XCUIElement {
      selectTab(title, timeout: timeout, file: file, line: line)
      let window = windows.matching(identifier: Self.settingsWindowIdentifier).firstMatch
      if !window.waitFor(NSPredicate(format: "title == %@", title), timeout: timeout) {
        XCTFail(
          "Settings did not switch to the “\(title)” tab within \(timeout)s",
          file: file,
          line: line
        )
      }
      return window
    }
  }
#endif

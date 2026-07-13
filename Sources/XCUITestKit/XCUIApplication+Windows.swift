#if os(macOS)
  import XCTest

  @MainActor
  extension XCUIApplication {
    /**
     Bring a macOS window forward and give it keyboard focus, opening it first when a
     scene shortcut is supplied. The macOS counterpart to iOS `tapTab` — the verb a page
     object uses to reach the window a flow runs in.

     Pass `openingWith` a `Window`/`WindowGroup` scene's `keyboardShortcut` key and the
     shortcut is **always re-sent**, whether or not the window is already open. This is the
     crucial part: with window restoration on, a multi-window app relaunches with several
     feature windows open and overlapping, and `XCUIElement.click()` *raises* a window
     without giving it keyboard focus — so focus stays on whichever window came up first and
     a later coordinate tap lands on the wrong (occluding) window. Re-sending the scene
     shortcut opens the window if it is closed and raises **and focuses** it if it is open,
     which `click()` cannot guarantee.

     With no `openingWith` key the window must already be open; it is raised with `click()`
     as a best effort. Supply the shortcut whenever the scene declares one — it is the only
     mechanism that reliably transfers keyboard focus across overlapping windows.

     - Parameters:
       - title: The window's title, as given to its `Window`/`WindowGroup` scene.
       - key: The character of the scene's `keyboardShortcut` (e.g. `"1"`), or `nil` to
         raise an already-open window without a shortcut.
       - modifiers: The shortcut's modifier flags. Defaults to `.command`.
       - timeout: How long to wait for the window to appear. Defaults to
         `ScaledTimeouts.element`.
     - Returns: the window element, whether or not it appeared within `timeout`.
     */
    @discardableResult
    public func focusWindow(
      _ title: String,
      openingWith key: String? = nil,
      modifiers: XCUIElement.KeyModifierFlags = .command,
      timeout: TimeInterval = ScaledTimeouts.element
    ) -> XCUIElement {
      let window = windows[title]
      if let key {
        typeKey(key, modifierFlags: modifiers)
      } else if window.waitForExistence(timeout: timeout) {
        window.click()
      }
      _ = window.waitForExistence(timeout: timeout)
      return window
    }
  }
#endif

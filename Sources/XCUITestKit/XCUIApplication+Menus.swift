#if os(macOS)
  import XCTest

  @MainActor
  extension XCUIApplication {
    /**
     Invoke a menu-bar command: open the top-level `menu` and click `item` beneath it.

     The macOS way to reach a command that has no keyboard shortcut — the counterpart to
     `focusWindow` and iOS `tapTab` for menu-driven flows. A page object uses it to drive
     the commands a window's toolbar duplicates only partially (rename, delete, "clear
     completed", the app's About item, and so on).

     `item` is matched by accessibility **identifier or title**, so a `Button` in a
     `CommandGroup`/`CommandMenu` is reachable whether or not it carries an explicit
     identifier — its visible title (including a trailing ellipsis, e.g. `"Rename…"`) works.
     The lookup waits for the item, since the menu populates a beat after the top-level menu
     opens, and takes the first match so a title that also appears in another menu (a context
     menu, a duplicated command) does not throw.

     - Parameters:
       - menu: The top-level menu's title as it appears in the menu bar (e.g. `"File"`).
       - item: The command's accessibility identifier or visible title.
       - timeout: How long to wait for the item to appear. Defaults to `ScaledTimeouts.element`.
     - Returns: the menu-item element (already clicked).
     */
    @discardableResult
    public func clickMenuItem(
      _ item: String,
      in menu: String,
      timeout: TimeInterval = ScaledTimeouts.element,
      file: StaticString = #filePath,
      line: UInt = #line
    ) -> XCUIElement {
      let bar = menuBars.firstMatch
      bar.menuBarItems[menu].click()
      let entry = bar.menuItems.matching(
        NSPredicate(format: "identifier == %@ OR title == %@", item, item)
      ).firstMatch
      if !entry.waitForExistence(timeout: timeout) {
        XCTFail("Menu item “\(item)” not found under “\(menu)” within \(timeout)s", file: file, line: line)
      }
      entry.click()
      return entry
    }
  }
#endif

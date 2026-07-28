import XCTest

@MainActor
extension XCUIApplication {
  /**
   Resolve a descendant by accessibility identifier.

   Wraps the `descendants(matching: .any).matching(identifier:).firstMatch`
   pattern that page objects otherwise repeat. The `.any` match is the broad,
   always-correct lookup; when an element's type is stable and known, prefer a
   type-scoped query (e.g. `otherElements[id]`, `collectionViews[id]`), which
   is cheaper and more robust than a full-tree scan under a busy accessibility
   tree.
   */
  public func descendant(id: String) -> XCUIElement {
    descendants(matching: .any).matching(identifier: id).firstMatch
  }

  /**
   Resolve a static text by the string it displays.

   SwiftUI surfaces a `Text`'s string as the element's **`value`**, not its `label` (which
   is empty), so a table/list cell or a status line is found by value, not label. The query
   is scoped to `staticTexts` deliberately: an unscoped `.any` `value`-predicate walks the
   whole accessibility tree and is pathologically slow under a busy UI, and coerces
   non-string values along the way.

   Pair it with an identifier for an exact cell — e.g. matching both
   `identifier == "queue.cell.name"` and `value == name` — when several cells share a value.

   - Parameter value: The exact displayed string.
   - Returns: the first matching static-text element.
   */
  public func staticText(value: String) -> XCUIElement {
    staticTexts.matching(NSPredicate(format: "value == %@", value)).firstMatch
  }
}

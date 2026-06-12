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
}

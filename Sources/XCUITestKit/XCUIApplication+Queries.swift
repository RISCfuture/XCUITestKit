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
   A compact summary of identifiable elements currently on screen, for
   attaching to assertion-failure messages so a wait timeout is triageable from
   the log without reproducing the run.

   Best-effort and only worth calling on the failure path: it enumerates the
   accessibility tree, which is itself slow (and occasionally unavailable) on
   the degraded simulators where these timeouts occur.
   */
  public func onscreenSummary(limit: Int = 30) -> String {
    let groups: [(label: String, query: XCUIElementQuery)] = [
      ("button", buttons),
      ("staticText", staticTexts),
      ("other", otherElements),
      ("cell", cells)
    ]
    var entries: [String] = []
    for group in groups {
      for element in group.query.allElementsBoundByIndex where element.exists {
        let identifier = element.identifier
        let token = identifier.isEmpty ? element.label : identifier
        guard !token.isEmpty else { continue }
        entries.append("\(group.label)[\(token)]")
        if entries.count >= limit {
          return entries.joined(separator: ", ") + " …"
        }
      }
    }
    return entries.isEmpty
      ? "(no identifiable elements on screen)"
      : entries.joined(separator: ", ")
  }
}

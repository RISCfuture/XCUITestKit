import Foundation

/**
 Whether a field's read-back value reflects the text a test typed into it.

 The rule a text-entry pass is verified by, kept apart from the entry itself so
 it can be exercised without a running app. Lives outside the iOS-only text-entry
 helpers for that reason.
 */
enum EnteredValue {

  /**
   Whether `readBack` is the value `typed` produced.

   Compared numerically when both sides carry a number, so a field that regroups
   and suffixes units (`"4550"` → `"4,550 lb"`) or drops a trailing zero
   (`"1.0"` → `"1"`) still matches, while a genuinely wrong value (typed
   `"4000"`, read back `"40.0"`) does not.

   Everything else is compared whole. Matching digit-free text by *substring*
   is what let a failed replace pass as a success: typing `"BackNav"` into a
   field still holding `"New Target"` reads back `"New TargetBackNav"`, which
   contains the typed text and so looked committed — leaving the escalating
   clear that exists for exactly that case unused.
   */
  static func matches(typed: String, readBack: String) -> Bool {
    if let typedNumber = number(in: typed), let readBackNumber = number(in: readBack) {
      return typedNumber == readBackNumber
    }
    return trimmed(readBack) == trimmed(typed)
  }

  /// The number a field's displayed value carries, ignoring grouping separators and units.
  private static func number(in string: String) -> Double? {
    Double(string.filter { $0.isNumber || $0 == "." })
  }

  private static func trimmed(_ string: String) -> String {
    string.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

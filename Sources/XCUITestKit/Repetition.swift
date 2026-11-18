/// Repeats a gesture for as long as it changes what it acts on.
enum Repetition {
  /**
   Perform `gesture` until `reading` returns after it what it returned before it, making at most
   `limit` gestures.

   - Parameters:
     - limit: The most gestures to make.
     - reading: Observes whatever the gesture should change, such as an element's frame.
     - gesture: The gesture to repeat.
   - Returns: Whether a gesture left the reading unchanged before the limit ran out.
   */
  static func untilUnchanged<Reading: Equatable>(
    limit: UInt,
    reading: () -> Reading,
    gesture: () -> Void
  ) -> Bool {
    var before = reading()
    for _ in 0..<limit {
      gesture()
      let after = reading()
      if after == before { return true }
      before = after
    }
    return false
  }
}

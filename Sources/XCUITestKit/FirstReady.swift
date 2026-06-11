import XCTest

/**
 Wait for the first of several conditions to hold — the building block for
 resolving a screen that can settle into one of multiple terminal states
 (loaded vs. empty vs. error) instead of blindly waiting for a single element.

 A plain `waitForExistence` on the loaded-state element times out the full
 window when the screen legitimately reached its empty or error state; callers
 that wait on *all* plausible states instead can react to whichever one
 actually appeared — and fail fast (rather than after the timeout) when it is
 the error state.

 The core ``firstIndex(ofExisting:timeout:pollInterval:)`` polls plain
 closures, so its ordering and deadline logic are unit-testable without a
 running app. ``XCUIApplication/firstExisting(of:timeout:)`` is the
 element-oriented convenience.
 */
@MainActor
public enum FirstReady {
  /// Default cadence between polls. Kept short so a state that appears mid-window
  /// is detected promptly; the per-poll accessibility snapshot dominates cost.
  public static let defaultPollInterval: TimeInterval = 0.25

  /**
   Poll `probes` in order, repeatedly, until one returns `true` or `timeout`
   elapses. Returns the index of the first satisfied probe, or `nil` on timeout.

   At least one full pass runs even when `timeout` is `0`.
   */
  @discardableResult
  public static func firstIndex(
    ofExisting probes: [() -> Bool],
    timeout: TimeInterval = ScaledTimeouts.slowElement,
    pollInterval: TimeInterval = defaultPollInterval
  ) -> Int? {
    firstIndex(
      ofExisting: probes,
      timeout: timeout,
      pollInterval: pollInterval,
      now: Date.init,
      sleep: Self.runLoopSleep
    )
  }

  /// Testable core: `now` and `sleep` are injected so the polling loop runs
  /// deterministically and instantly under unit test.
  static func firstIndex(
    ofExisting probes: [() -> Bool],
    timeout: TimeInterval,
    pollInterval: TimeInterval,
    now: () -> Date,
    sleep: (TimeInterval) -> Void
  ) -> Int? {
    let deadline = now().addingTimeInterval(max(0, timeout))
    while true {
      for (index, probe) in probes.enumerated() where probe() { return index }
      if now() >= deadline { return nil }
      sleep(pollInterval)
    }
  }

  private static func runLoopSleep(_ interval: TimeInterval) {
    guard interval > 0 else { return }
    RunLoop.current.run(until: Date().addingTimeInterval(interval))
  }
}

@MainActor
extension XCUIApplication {
  /**
   Wait for the first of `elements` to exist, returning its index and the
   element itself, or `nil` if none appeared within `timeout`.

   Use when a screen can settle into one of several terminal states — e.g.
   `firstExisting(of: [loadedList, emptyState, errorState])` — so the caller
   reacts to whichever appeared instead of waiting out the timeout on the
   loaded-state element when the screen actually reached empty or error.

   Defaults to ``ScaledTimeouts/slowElement`` because the canonical use is a
   heavy screen settling after navigation.
   */
  @discardableResult
  public func firstExisting(
    of elements: [XCUIElement],
    timeout: TimeInterval = ScaledTimeouts.slowElement
  ) -> (index: Int, element: XCUIElement)? {
    let probes = elements.map { element in { element.exists } }
    guard let index = FirstReady.firstIndex(ofExisting: probes, timeout: timeout)
    else { return nil }
    return (index, elements[index])
  }
}

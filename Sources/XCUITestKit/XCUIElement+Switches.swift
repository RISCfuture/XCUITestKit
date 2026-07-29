import XCTest

@MainActor
extension XCUIElement {
  /// How long each successive press holds the touch down, in seconds.
  ///
  /// The opening hold is the one that matters: an iOS 26 SwiftUI toggle registers a fifth of a
  /// second every time, but drops a tenth of a second about a third of the time. Every entry
  /// stays under the half second that would make the gesture a long press.
  private static let switchHoldDurations: [TimeInterval] = [0.2, 0.35, 0.45, 0.45]

  /// How long to hold the touch down on a given attempt, lengthening with each retry.
  private static func holdDuration(forAttempt attempt: UInt) -> TimeInterval {
    switchHoldDurations[min(Int(attempt), switchHoldDurations.count - 1)]
  }

  /**
   Set a `Switch`, checkbox, or SwiftUI `Toggle` on or off, returning whether it ended up in the
   wanted state.

   Three things make a toggle harder to drive than it looks, and this handles all of them.

   A SwiftUI toggle publishes the state it is *leaving* as a child element, so that child
   disappearing — not a read of `value` — is what proves the gesture registered; reading the
   value straight back races the update. On platforms that expose no such child the element
   itself is pressed and ``isOn`` is consulted instead.

   The row may sit under a translucent iOS 26 navigation or tab bar, which reports it as
   hittable while swallowing its taps, so each attempt first nudges the row into the clear and
   waits for the list to stop moving.

   Finally, the touch has to be held long enough to register at all, and the threshold is
   sharper than it looks: a fifth of a second lands every time where a tenth is dropped about a
   third of the time. The first press therefore opens above that cliff rather than climbing to
   it, because a dropped press is not free — it costs a full ``ScaledTimeouts/short`` before the
   retry. Each retry holds longer still, staying under the half second that would make the
   gesture a long press.

   - Parameters:
     - value: The state to leave the control in.
     - app: The application whose scroll container should be nudged. Defaults to the current one.
     - maxAttempts: How many times to press before giving up.
   - Returns: Whether the control ended up in the wanted state.
   */
  @discardableResult
  public func setSwitch(
    to value: Bool,
    in app: XCUIApplication = XCUIApplication(),
    maxAttempts: UInt = 5
  ) -> Bool {
    let leaving = value ? "0" : "1"
    let wanted = NSPredicate(format: "value == %@", value ? "1" : "0")

    for attempt in 0..<maxAttempts {
      let leavingChild = switches[leaving]
      guard leavingChild.exists || isOn != value else { return true }

      app.scrollIntoSafeBand(self)
      waitUntilFrameStable()

      let control = leavingChild.exists ? leavingChild.firstMatch : self
      control.press(holdingFor: Self.holdDuration(forAttempt: attempt))

      if waitFor(wanted, timeout: ScaledTimeouts.short) { return true }
    }

    return isOn == value
  }
}

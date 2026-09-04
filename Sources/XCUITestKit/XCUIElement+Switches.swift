public import XCTest

@MainActor
extension XCUIElement {
  /**
   How long each successive press holds the touch down, in seconds.

   A control inside a `List` or `Form` sits inside a scroll view, and a scroll view does not hand
   a touch straight to its content: it holds the touch down while it decides whether the finger is
   about to scroll, and only forwards it once that has been ruled out. A press whose finger lifts
   before then is consumed whole — the switch never sees it, however precisely it was aimed.

   That window is short on a developer's machine and long on a loaded CI runner, which is what
   made this look like flakiness rather than arithmetic. Measured across 1,950 presses on a CI
   iPad simulator, a fifth of a second lost 82% of them, a half second lost 27%, and nine tenths
   lost none at all — while a pause before the press, a drag across the switch, and a press
   aimed elsewhere all lost around 85%, which is what rules out timing, motion, and aim as the
   thing that mattered.

   So the opening hold clears the window rather than probing for it, and each retry lengthens.
   These are long enough to read as a long press, which a `Switch` has no gesture for; a caller
   whose control also answers a long press wants ``forceTap(holdFor:)`` instead.
   */
  private static let switchHoldDurations: [TimeInterval] = [0.9, 1.2, 1.5, 1.5]

  /// How far in from the trailing edge the switch itself is expected to lie, in points.
  ///
  /// Comfortably inside the half-inch a `UISwitch` occupies, and halved for any control narrower
  /// than that so the point stays within a bare switch or a checkbox rather than falling off it.
  private static let switchInsetFromTrailingEdge: CGFloat = 25

  /// How long to hold the touch down on a given attempt, lengthening with each retry.
  private static func holdDuration(forAttempt attempt: UInt) -> TimeInterval {
    switchHoldDurations[min(Int(attempt), switchHoldDurations.count - 1)]
  }

  /**
   Press the switch rather than the middle of whatever carries it.

   A SwiftUI `Toggle` in a `Form` publishes one accessibility element spanning the entire row, so
   its centre — where a plain press lands — is over the label, which is not hit-testable: the touch
   is delivered and nothing happens, however long it is held and however often it is repeated. Only
   the switch at the trailing edge answers.

   Insetting from that edge finds it without assuming a width, and collapses to the centre for a
   control no wider than the inset, which is what a bare `Switch` or a checkbox is.
   */
  private func pressWhereTheSwitchIs(holdingFor duration: TimeInterval) {
    let inset = min(Self.switchInsetFromTrailingEdge, frame.width / 2)
    coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
      .withOffset(CGVector(dx: -inset, dy: 0))
      .press(forDuration: duration)
  }

  /**
   Set a `Switch`, checkbox, or SwiftUI `Toggle` on or off, returning whether it ended up in the
   wanted state.

   Three things make a toggle harder to drive than it looks, and this handles all of them.

   A SwiftUI toggle publishes the state it is *leaving* as a child element, so that child
   disappearing — not a read of `value` — is what proves the gesture registered; reading the
   value straight back races the update. Where no such child is published, ``isOn`` is consulted
   instead and the press has to find the switch on its own, because the element standing in for a
   `Toggle` in a `Form` spans the whole row and its middle is over the label, which no touch
   activates.

   The row may sit under a translucent iOS 26 navigation or tab bar, which reports it as
   hittable while swallowing its taps, so each attempt first nudges the row into the clear and
   waits for the list to stop moving.

   Finally — and this is what actually loses presses — the scroll view carrying the row delays
   the touch while it decides whether the finger is scrolling, so a press that lifts too early is
   swallowed before the switch sees it. See `switchHoldDurations` for the measurements; the
   opening press clears that window rather than probing for it, because a swallowed press is not
   free: it costs a full ``ScaledTimeouts/short`` before the retry.

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

      let hold = Self.holdDuration(forAttempt: attempt)
      if leavingChild.exists {
        leavingChild.firstMatch.press(holdingFor: hold)
      } else {
        pressWhereTheSwitchIs(holdingFor: hold)
      }

      if waitFor(wanted, timeout: ScaledTimeouts.short) { return true }
    }

    return isOn == value
  }
}

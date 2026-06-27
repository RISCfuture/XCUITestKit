import XCTest

/**
 Generic retry for flaky UI interactions: perform an action, verify the
 expected outcome, and repeat the action if the outcome did not occur.

 This is the action-and-confirm complement to ``AXRecovery``: where
 ``AXRecovery`` relaunches the app to recover the accessibility server, this
 simply re-performs an action whose first attempt was swallowed — a tap that
 landed mid-animation, a gesture that did not register.
 */
@MainActor
public enum Retry {
  /**
   Run `action`, then evaluate `condition`. If it is `false`, retry `action`
   up to `maxAttempts` total times, pausing `interval` (scaled by
   ``ScaledTimeouts``) between attempts. Returns whether `condition`
   ultimately held.

   ```swift
   await Retry.untilVerified(
     action: { nextButton.forceTap() },
     until: { detailScreen.waitForExistence(timeout: ScaledTimeouts.element) }
   )
   ```
   */
  @discardableResult
  public static func untilVerified(
    maxAttempts: UInt = 3,
    interval: TimeInterval = 0.5,
    action: () async -> Void,
    until condition: () async -> Bool
  ) async -> Bool {
    let attempts = max(1, maxAttempts)
    for attempt in 1...attempts {
      await action()
      if await condition() { return true }
      if attempt < attempts {
        try? await Task.sleep(for: .seconds(ScaledTimeouts.scaled(interval)))
      }
    }
    return await condition()
  }
}

@MainActor
extension XCUIElement {
  /**
   Tap this element, then wait for `confirmation` to appear; if it does not,
   retry the tap. Returns whether `confirmation` ultimately appeared.

   Generalizes the page-object "tap a control, confirm the next screen
   rendered, retry the tap if it didn't" pattern, which a single
   `tap()` + `waitForExistence` cannot recover from when the first tap is
   dropped. Taps via ``forceTap()`` so it also survives not-hittable controls.
   */
  @discardableResult
  public func tap(
    untilExists confirmation: XCUIElement,
    maxAttempts: UInt = 3,
    timeout: TimeInterval = ScaledTimeouts.element
  ) async -> Bool {
    await Retry.untilVerified(
      maxAttempts: maxAttempts,
      interval: 0,
      action: { self.forceTap() },
      until: { confirmation.waitForExistence(timeout: timeout) }
    )
  }

  /**
   Tap this element, then evaluate `condition`; if it does not hold, retry the
   tap up to `maxAttempts` times. Returns whether `condition` ultimately held.

   The closure-based companion to ``tap(untilExists:maxAttempts:timeout:)`` for
   controls confirmed by something other than another element appearing — a
   keypad key that swaps the keypad out (the key itself becomes non-hittable),
   a control that dismisses itself. Taps via ``forceTap()`` so it also survives
   not-hittable controls, and recovers when the first tap is dropped
   mid-animation.

   Pass a `condition` that waits — e.g. ``waitFor(_:timeout:)`` — rather than
   one that samples instantaneously, so a tap that has registered but not yet
   taken visible effect is not re-issued into the post-tap UI.
   */
  @discardableResult
  public func tap(
    until condition: () async -> Bool,
    maxAttempts: UInt = 3,
    interval: TimeInterval = 0
  ) async -> Bool {
    await Retry.untilVerified(
      maxAttempts: maxAttempts,
      interval: interval,
      action: { self.forceTap() },
      until: condition
    )
  }
}

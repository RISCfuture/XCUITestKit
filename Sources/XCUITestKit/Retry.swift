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
   dropped. Taps via ``forceTap(holdFor:)`` so it also survives not-hittable controls.
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
   a control that dismisses itself. Taps via ``forceTap(holdFor:)`` so it also survives
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

  /**
   Tap this element with escalating strategies until `confirmation` appears, returning
   whether it ultimately appeared.

   Where ``tap(untilExists:maxAttempts:timeout:)`` re-issues the same ``forceTap(holdFor:)`` every
   attempt, this cycles a list of progressively more forceful tap techniques — a plain
   activation, then a long press, then an off-center press — which an iOS 26 "Liquid Glass"
   nav/tab bar is decreasingly able to swallow. Each attempt waits up to `timeout` for
   `confirmation` before escalating to the next strategy.

   It also stops early if `self` ceases to exist mid-sequence (the tap already navigated away,
   so the source control is gone), and after exhausting the strategies it grants a final,
   doubled wait for a destination that renders slower than `timeout` under simulator load.

   - Parameters:
     - confirmation: The element whose appearance confirms the tap took effect.
     - strategies: The tap techniques to try, in escalating order — typically
       ``TapStrategy/escalating``.
     - timeout: Per-strategy wait for `confirmation` (scaled — pass a ``ScaledTimeouts`` value).
   */
  @discardableResult
  public func tap(
    untilExists confirmation: XCUIElement,
    using strategies: [TapStrategy],
    timeout: TimeInterval = ScaledTimeouts.element
  ) -> Bool {
    for strategy in strategies {
      if confirmation.exists { return true }
      // Once the source element is gone the tap has already navigated; stop tapping and fall
      // through to the final wait so a slow-rendering destination is not abandoned mid-transition.
      guard exists else { break }
      strategy.apply(to: self)
      if confirmation.waitForExistence(timeout: timeout) { return true }
    }
    return confirmation.waitForExistence(timeout: timeout * 2)
  }

  /// A single tap technique tried by ``tap(untilExists:using:timeout:)``.
  public enum TapStrategy: Sendable {
    /// ``forceTap(holdFor:)`` — a normal tap, or a center-coordinate tap when the element is not hittable.
    case activate
    /// A long press of the given duration, which dislodges a control a quick tap glanced off.
    case longPress(TimeInterval)
    /// A press at a normalized offset within the element, sidestepping activation-point hit-testing.
    case pressOffset(CGVector, duration: TimeInterval)

    /// The default escalation: an activation, then a long press, then an off-center press —
    /// each less likely than the last to be swallowed by an iOS 26 Liquid Glass bar.
    public static let escalating: [Self] = [
      .activate,
      .longPress(0.3),
      .pressOffset(CGVector(dx: 0.3, dy: 0.5), duration: 0.3)
    ]

    @MainActor
    func apply(to element: XCUIElement) {
      switch self {
        case .activate:
          element.forceTap()
        case let .longPress(duration):
          element.press(forDuration: duration)
        case let .pressOffset(offset, duration):
          element.coordinate(withNormalizedOffset: offset).press(forDuration: duration)
      }
    }
  }
}

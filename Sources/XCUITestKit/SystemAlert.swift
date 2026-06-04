import XCTest

/// Handling of system alerts — permission prompts ("… would like to use your
/// location"), confirmation dialogs, and similar — which are presented by
/// SpringBoard rather than the app under test.
///
/// XCUITest's built-in ``XCTestCase/addUIInterruptionMonitor(withDescription:handler:)``
/// is fragile: its handler only fires when the test *next* interacts with the
/// app, so an alert that blocks that very interaction is never dismissed. The
/// preferred entry point here is ``dismiss(accepting:labels:timeout:)``, which
/// taps the alert button on SpringBoard directly at a known point in the flow
/// and needs no follow-up interaction. ``XCTestCase/addSystemAlertMonitor(description:buttonLabels:)``
/// remains available for alerts whose timing you cannot predict.
public enum SystemAlert {
  /// Button labels that grant or confirm a system prompt, tried in this order.
  /// Ordered most- to least-permissive so a one-shot "while using" grant is
  /// preferred over a blanket "always".
  public static let acceptButtonLabels = [
    "Allow While Using App",
    "Allow Once",
    "Allow",
    "Always Allow",
    "OK",
    "Continue"
  ]

  /// Button labels that decline or dismiss a system prompt, tried in this order.
  public static let dismissButtonLabels = [
    "Don’t Allow",
    "Don't Allow",
    "Cancel",
    "Not Now",
    "Dismiss"
  ]

  #if os(iOS)
    /// The SpringBoard application, which hosts system alert UI.
    public static var springboard: XCUIApplication {
      XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    /// Dismiss a system alert if one is presented, by tapping the first button
    /// whose label matches, in order. Returns whether a button was tapped.
    ///
    /// Polls SpringBoard until `timeout` so it tolerates the alert appearing a
    /// beat after the action that triggered it; returns `false` (without
    /// failing) if no matching button surfaces, so it is safe to call
    /// defensively when an alert may or may not appear.
    ///
    /// - Parameters:
    ///   - accepting: When `true` (default) taps an ``acceptButtonLabels``
    ///     button; when `false` taps a ``dismissButtonLabels`` button.
    ///   - labels: Explicit button labels to try, overriding `accepting`.
    ///   - timeout: How long to wait for a matching button to appear.
    @MainActor
    @discardableResult
    public static func dismiss(
      accepting: Bool = true,
      labels: [String]? = nil,
      timeout: TimeInterval = ScaledTimeouts.short
    ) -> Bool {
      let candidates = labels ?? (accepting ? acceptButtonLabels : dismissButtonLabels)
      let springboard = Self.springboard
      let deadline = Date().addingTimeInterval(timeout)
      repeat {
        for label in candidates {
          let button = springboard.buttons[label]
          if button.exists, button.isHittable {
            button.tap()
            return true
          }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
      } while Date() < deadline
      return false
    }
  #endif
}

@MainActor
extension XCTestCase {
  /// Register an interruption monitor that auto-dismisses a system alert by
  /// tapping the first button whose label matches `buttonLabels`, in order.
  ///
  /// `addUIInterruptionMonitor`'s handler only runs when the test next
  /// interacts with the app under test, so after an action that may raise an
  /// alert you must still touch the app (e.g. `app.tap()`) for this to fire.
  /// When you know where in the flow the alert appears, prefer
  /// ``SystemAlert/dismiss(accepting:labels:timeout:)`` instead — it does not
  /// depend on a follow-up interaction.
  ///
  /// Remove the returned token with `removeUIInterruptionMonitor` once the
  /// alert is no longer expected.
  @discardableResult
  public func addSystemAlertMonitor(
    description: String = "System alert",
    buttonLabels: [String] = SystemAlert.acceptButtonLabels
  ) -> NSObjectProtocol {
    addUIInterruptionMonitor(withDescription: description) { alert in
      for label in buttonLabels {
        let button = alert.buttons[label]
        if button.exists {
          button.tap()
          return true
        }
      }
      return false
    }
  }
}

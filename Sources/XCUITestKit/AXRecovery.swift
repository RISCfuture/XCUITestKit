import XCTest

/// In-test recovery for the accessibility-server failures that dominate slow-CI
/// XCUITest flakes — most visibly "Failed to get matching snapshots: Error
/// getting main window kAXErrorServerNotFound", where the app stops vending an
/// accessibility snapshot and every subsequent query fails.
///
/// XCUITest surfaces that condition as a recorded test failure rather than a
/// catchable Swift error, so this helper cannot intercept the error directly.
/// Instead it runs an action, probes whether the UI is queryable again, and on
/// failure terminates + relaunches the app before retrying — the in-test
/// complement to the CI-level "retry on a fresh simulator" strategy.
///
/// Use it around the first query on a screen that is prone to the failure
/// (e.g. immediately after launch, or entering a heavy screen):
///
/// ```swift
/// AXRecovery.run(
///   isHealthy: { app.navigationBars["About"].waitForExistence(timeout: ScaledTimeouts.element) },
///   relaunch: { app.terminate(); app.launch() },
///   action: { aboutPage.openAboutTab() }
/// )
/// ```
@MainActor
public enum AXRecovery {
  /// Run `action`, then check `isHealthy`. If unhealthy, `relaunch` the app and
  /// retry, up to `maxAttempts` times. Returns the final health state.
  @discardableResult
  public static func run(
    maxAttempts: Int = 2,
    isHealthy: () -> Bool,
    relaunch: () -> Void,
    action: () -> Void
  ) -> Bool {
    let attempts = max(1, maxAttempts)
    for attempt in 1...attempts {
      action()
      if isHealthy() { return true }
      if attempt < attempts { relaunch() }
    }
    return isHealthy()
  }
}

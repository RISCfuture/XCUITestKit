import Foundation

/// Centralized, CI-scalable timeouts for UI tests.
///
/// CI machines run UI tests far slower than a developer laptop, so every wait
/// is multiplied by a factor read from the environment. Set the multiplier in
/// the test plan's environment variables (e.g. `3`) on CI and leave it unset
/// locally (defaults to `1`).
///
/// The multiplier is read from ``multiplierEnvVarName``; a missing, non-numeric,
/// or non-positive value falls back to `1`.
public enum ScaledTimeouts {
  /// Environment variable read for the timeout multiplier.
  public static let multiplierEnvVarName = "XCUITEST_TIMEOUT_MULTIPLIER"

  /// The active multiplier, resolved once from the process environment.
  public static let multiplier = resolveMultiplier(from: ProcessInfo.processInfo.environment)

  /// Default wait for an element to appear.
  public static var element: TimeInterval { scaled(5) }

  /// Short probe — transient overlays, menus opening/closing.
  public static var short: TimeInterval { scaled(3) }

  /// Longer wait — heavy screens, list rendering, cross-screen navigation.
  public static var slowElement: TimeInterval { scaled(15) }

  /// App launch / first-render wait.
  public static var launch: TimeInterval { scaled(30) }

  /// Resolve the multiplier from an environment dictionary. ``multiplierEnvVarName``
  /// must hold a positive `Double`; anything missing, non-numeric, or non-positive
  /// falls through to `1`.
  static func resolveMultiplier(from environment: [String: String]) -> Double {
    guard let raw = environment[multiplierEnvVarName], let value = Double(raw), value > 0 else {
      return 1
    }
    return value
  }

  /// Multiply a base interval (in seconds) by the active multiplier.
  public static func scaled(_ base: TimeInterval) -> TimeInterval { base * multiplier }
}

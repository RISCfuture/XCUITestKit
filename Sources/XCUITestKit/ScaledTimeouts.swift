import Foundation

/// Centralized, CI-scalable timeouts for UI tests.
///
/// CI machines run UI tests far slower than a developer laptop, so every wait
/// is multiplied by a factor read from the environment. Set the multiplier in
/// the test plan's environment variables (e.g. `3`) on CI and leave it unset
/// locally (defaults to `1`).
///
/// The first variable in ``multiplierEnvVarNames`` that holds a positive number
/// wins. The generic `XCUITEST_TIMEOUT_MULTIPLIER` is preferred; the per-app
/// names are honored too so existing test plans keep working while each app
/// migrates to the shared name.
public enum ScaledTimeouts {
  /// Environment variable names checked, in order, for the timeout multiplier.
  public static let multiplierEnvVarNames = [
    "XCUITEST_TIMEOUT_MULTIPLIER",
    "FART_UI_TIMEOUT_MULTIPLIER",
    "SF50_UI_TEST_TIMEOUT_MULTIPLIER"
  ]

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

  /// Resolve the multiplier from an environment dictionary. The first name in
  /// ``multiplierEnvVarNames`` that holds a positive `Double` wins; anything
  /// missing, non-numeric, or non-positive is ignored, falling through to `1`.
  static func resolveMultiplier(from environment: [String: String]) -> Double {
    for name in multiplierEnvVarNames {
      if let raw = environment[name], let value = Double(raw), value > 0 {
        return value
      }
    }
    return 1
  }

  /// Multiply a base interval (in seconds) by the active multiplier.
  public static func scaled(_ base: TimeInterval) -> TimeInterval { base * multiplier }
}

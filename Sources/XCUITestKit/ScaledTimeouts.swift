import Foundation

/**
 Centralized, CI-scalable timeouts for UI tests.

 CI machines run UI tests far slower than a developer laptop, so every wait
 is multiplied by a factor read from the environment. Set the multiplier in
 the test plan's environment variables (e.g. `3`) on CI and leave it unset
 locally (defaults to `1`).

 The multiplier is read from ``multiplierEnvironmentVariableName``. A missing
 variable falls back to `1`; a present but non-numeric or non-positive value is
 treated as misconfiguration and trapped via `assertionFailure` before falling
 back to `1`.
 */
public enum ScaledTimeouts {
  /// Environment variable read for the timeout multiplier.
  public static let multiplierEnvironmentVariableName = "XCUITEST_TIMEOUT_MULTIPLIER"

  /// The active multiplier, resolved once from the process environment.
  public static let multiplier = activeMultiplier(from: ProcessInfo.processInfo.environment)

  /// Default wait for an element to appear.
  public static var element: TimeInterval { scaled(5) }

  /// Short probe — transient overlays, menus opening/closing.
  public static var short: TimeInterval { scaled(3) }

  /// Longer wait — heavy screens, list rendering, cross-screen navigation.
  public static var slowElement: TimeInterval { scaled(15) }

  /// App launch / first-render wait.
  public static var launch: TimeInterval { scaled(30) }

  /// Resolve the active multiplier: `1` for an unset variable, the parsed value
  /// for a valid one, and `1` (after an `assertionFailure`) for a malformed one.
  static func activeMultiplier(from environment: [String: String]) -> Double {
    switch resolveMultiplier(from: environment) {
      case .unset:
        return 1
      case let .valid(value):
        return value
      case let .malformed(raw):
        assertionFailure(
          "\(multiplierEnvironmentVariableName)=\(raw) is not a positive number; "
            + "falling back to no scaling. Set it to a positive Double or leave it unset."
        )
        return 1
    }
  }

  /**
   Classify the multiplier environment variable. An absent variable is
   ``MultiplierResolution/unset``, a parseable positive value is
   ``MultiplierResolution/valid(_:)``, and anything else (non-numeric, zero, or
   negative) is ``MultiplierResolution/malformed(_:)``.
   */
  static func resolveMultiplier(from environment: [String: String]) -> MultiplierResolution {
    guard let raw = environment[multiplierEnvironmentVariableName] else { return .unset }
    guard let value = Double(raw), value > 0 else { return .malformed(raw) }
    return .valid(value)
  }

  /// Multiply a base interval (in seconds) by the active multiplier.
  public static func scaled(_ base: TimeInterval) -> TimeInterval { base * multiplier }

  /// The outcome of reading the timeout multiplier from the environment.
  enum MultiplierResolution: Equatable {
    case unset
    case valid(Double)
    case malformed(String)
  }
}

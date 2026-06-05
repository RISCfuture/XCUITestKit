import XCTest

@testable import XCUITestKit

@MainActor
final class AXRecoveryTests: XCTestCase {
  func testRunsActionOnceWhenImmediatelyHealthy() {
    var actionCount = 0
    var relaunchCount = 0
    let result = AXRecovery.run(
      isHealthy: { true },
      relaunch: { relaunchCount += 1 },
      action: { actionCount += 1 }
    )
    XCTAssertTrue(result)
    XCTAssertEqual(actionCount, 1)
    XCTAssertEqual(relaunchCount, 0)
  }

  func testRelaunchesOnceThenSucceeds() {
    var actionCount = 0
    var relaunchCount = 0
    var healthChecks = 0
    let result = AXRecovery.run(
      maxAttempts: 2,
      isHealthy: {
        healthChecks += 1
        return healthChecks >= 2
      },
      relaunch: { relaunchCount += 1 },
      action: { actionCount += 1 }
    )
    XCTAssertTrue(result)
    XCTAssertEqual(actionCount, 2)
    XCTAssertEqual(relaunchCount, 1)
  }

  func testReturnsFalseAndRelaunchesBetweenAttempts() {
    var actionCount = 0
    var relaunchCount = 0
    let result = AXRecovery.run(
      maxAttempts: 3,
      isHealthy: { false },
      relaunch: { relaunchCount += 1 },
      action: { actionCount += 1 }
    )
    XCTAssertFalse(result)
    XCTAssertEqual(actionCount, 3)
    XCTAssertEqual(relaunchCount, 2)
  }

  func testClampsAttemptsToAtLeastOne() {
    var actionCount = 0
    var relaunchCount = 0
    let result = AXRecovery.run(
      maxAttempts: 0,
      isHealthy: { false },
      relaunch: { relaunchCount += 1 },
      action: { actionCount += 1 }
    )
    XCTAssertFalse(result)
    XCTAssertEqual(actionCount, 1)
    XCTAssertEqual(relaunchCount, 0)
  }
}

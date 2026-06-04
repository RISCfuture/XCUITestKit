import XCTest

@testable import XCUITestKit

@MainActor
final class RetryTests: XCTestCase {
  func testRunsActionOnceWhenConditionHoldsImmediately() {
    var actionCount = 0
    let result = Retry.untilVerified(
      maxAttempts: 3,
      interval: 0,
      action: { actionCount += 1 },
      until: { true }
    )
    XCTAssertTrue(result)
    XCTAssertEqual(actionCount, 1)
  }

  func testRetriesUntilConditionHolds() {
    var actionCount = 0
    let result = Retry.untilVerified(
      maxAttempts: 5,
      interval: 0,
      action: { actionCount += 1 },
      until: { actionCount >= 3 }
    )
    XCTAssertTrue(result)
    XCTAssertEqual(actionCount, 3)
  }

  func testReturnsFalseAfterExhaustingAttempts() {
    var actionCount = 0
    let result = Retry.untilVerified(
      maxAttempts: 4,
      interval: 0,
      action: { actionCount += 1 },
      until: { false }
    )
    XCTAssertFalse(result)
    XCTAssertEqual(actionCount, 4)
  }

  func testClampsAttemptsToAtLeastOne() {
    var actionCount = 0
    let result = Retry.untilVerified(
      maxAttempts: 0,
      interval: 0,
      action: { actionCount += 1 },
      until: { false }
    )
    XCTAssertFalse(result)
    XCTAssertEqual(actionCount, 1)
  }
}

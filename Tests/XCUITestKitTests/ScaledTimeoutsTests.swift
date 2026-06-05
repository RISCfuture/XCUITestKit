import XCTest

@testable import XCUITestKit

final class ScaledTimeoutsTests: XCTestCase {
  func testReadsPositiveValue() {
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "3"]),
      3
    )
  }

  func testDefaultsToOneWhenUnset() {
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: [:]), 1)
  }

  func testIgnoresNonPositiveAndNonNumericValues() {
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "0"]), 1)
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "-2"]), 1)
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "abc"]),
      1
    )
  }
}

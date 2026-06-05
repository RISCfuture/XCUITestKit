import XCTest

@testable import XCUITestKit

final class ScaledTimeoutsTests: XCTestCase {
  func testResolvesPositiveValue() {
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "3"]),
      .valid(3)
    )
  }

  func testReportsUnsetWhenMissing() {
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: [:]), .unset)
  }

  func testReportsMalformedForNonPositiveAndNonNumericValues() {
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "0"]),
      .malformed("0")
    )
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "-2"]),
      .malformed("-2")
    )
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "abc"]),
      .malformed("abc")
    )
  }

  func testActiveMultiplierDefaultsToOneWhenUnset() {
    XCTAssertEqual(ScaledTimeouts.activeMultiplier(from: [:]), 1)
  }

  func testActiveMultiplierUsesPositiveValue() {
    XCTAssertEqual(
      ScaledTimeouts.activeMultiplier(from: ["XCUITEST_TIMEOUT_MULTIPLIER": "4"]),
      4
    )
  }
}

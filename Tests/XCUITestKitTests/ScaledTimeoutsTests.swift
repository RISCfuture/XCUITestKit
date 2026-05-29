import XCTest

@testable import XCUITestKit

final class ScaledTimeoutsTests: XCTestCase {
  func testGenericNameTakesPrecedenceOverPerAppNames() {
    let environment = [
      "SF50_UI_TEST_TIMEOUT_MULTIPLIER": "2",
      "FART_UI_TIMEOUT_MULTIPLIER": "5",
      "XCUITEST_TIMEOUT_MULTIPLIER": "3"
    ]
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: environment), 3)
  }

  func testFallsBackToPerAppNameWhenGenericUnset() {
    XCTAssertEqual(
      ScaledTimeouts.resolveMultiplier(from: ["FART_UI_TIMEOUT_MULTIPLIER": "4"]),
      4
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

  func testSkipsInvalidGenericValueAndUsesNextValidName() {
    let environment = [
      "XCUITEST_TIMEOUT_MULTIPLIER": "not-a-number",
      "SF50_UI_TEST_TIMEOUT_MULTIPLIER": "2"
    ]
    XCTAssertEqual(ScaledTimeouts.resolveMultiplier(from: environment), 2)
  }
}

import XCTest

@testable import XCUITestKit

final class EnteredValueTests: XCTestCase {
  func testAcceptsAValueTypedIntoAnEmptyField() {
    XCTAssertTrue(EnteredValue.matches(typed: "Alpha", readBack: "Alpha"))
  }

  func testRejectsTypedTextAppendedToWhatTheFieldHeld() {
    XCTAssertFalse(EnteredValue.matches(typed: "BackNav", readBack: "New TargetBackNav"))
  }

  func testRejectsTypedTextPrependedToWhatTheFieldHeld() {
    XCTAssertFalse(EnteredValue.matches(typed: "BackNav", readBack: "BackNavNew Target"))
  }

  func testAcceptsANumberTheFieldRegroupedAndSuffixedWithAUnit() {
    XCTAssertTrue(EnteredValue.matches(typed: "4550", readBack: "4,550 lb"))
  }

  func testAcceptsANumberTheFieldDroppedATrailingZeroFrom() {
    XCTAssertTrue(EnteredValue.matches(typed: "1.0", readBack: "1"))
  }

  func testRejectsANumberTheFieldMisplacedTheDecimalPointIn() {
    XCTAssertFalse(EnteredValue.matches(typed: "4000", readBack: "40.0"))
  }

  func testRejectsANumberTypedOnTopOfDigitsTheFieldStillHeld() {
    XCTAssertFalse(EnteredValue.matches(typed: "5", readBack: "5,554"))
  }

  func testIgnoresSurroundingWhitespace() {
    XCTAssertTrue(EnteredValue.matches(typed: "Alpha", readBack: " Alpha "))
  }
}

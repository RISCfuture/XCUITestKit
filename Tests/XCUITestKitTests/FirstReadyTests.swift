import XCTest

@testable import XCUITestKit

@MainActor
final class FirstReadyTests: XCTestCase {
  private let farFuture: () -> Date = { Date.distantFuture }
  private let noSleep: (TimeInterval) -> Void = { _ in }

  func testReturnsIndexOfFirstSatisfiedProbeOnFirstPass() {
    let index = FirstReady.firstIndex(
      ofExisting: [{ false }, { true }, { true }],
      timeout: 10,
      pollInterval: 0,
      now: { Date() },
      sleep: noSleep
    )
    XCTAssertEqual(index, 1)
  }

  func testPollsUntilAProbeBecomesSatisfied() {
    var ticks = 0
    let index = FirstReady.firstIndex(
      ofExisting: [{ ticks >= 3 }],
      timeout: 10,
      pollInterval: 0,
      now: { Date() },
      sleep: { _ in ticks += 1 }
    )
    XCTAssertEqual(index, 0)
    XCTAssertEqual(ticks, 3)
  }

  func testReturnsNilWhenNoProbeIsSatisfiedBeforeDeadline() {
    // `now` advances past the deadline on the second read, so exactly one
    // poll pass runs before the timeout check fails.
    var reads = 0
    let index = FirstReady.firstIndex(
      ofExisting: [{ false }, { false }],
      timeout: 5,
      pollInterval: 0,
      now: {
        defer { reads += 1 }
        return reads == 0 ? Date(timeIntervalSince1970: 0) : Date.distantFuture
      },
      sleep: noSleep
    )
    XCTAssertNil(index)
  }

  func testRunsAtLeastOnePassWhenTimeoutIsZero() {
    var probed = false
    let index = FirstReady.firstIndex(
      ofExisting: [
        {
          probed = true; return true
        }
      ],
      timeout: 0,
      pollInterval: 0,
      now: { Date() },
      sleep: noSleep
    )
    XCTAssertEqual(index, 0)
    XCTAssertTrue(probed)
  }

  func testReturnsNilForEmptyProbeList() {
    let index = FirstReady.firstIndex(
      ofExisting: [],
      timeout: 0,
      pollInterval: 0,
      now: { Date(timeIntervalSince1970: 0) },
      sleep: noSleep
    )
    XCTAssertNil(index)
  }
}

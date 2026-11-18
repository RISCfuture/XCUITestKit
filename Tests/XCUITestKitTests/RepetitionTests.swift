import Testing

@testable import XCUITestKit

struct `Repeating a gesture until unchanged` {
  /// Repeats a gesture against `positions`, where the reading after `n` gestures is `positions[n]`.
  private func gestureCount(over positions: [Int], limit: UInt) -> (settled: Bool, gestures: Int) {
    var gestures = 0
    let settled = Repetition.untilUnchanged(
      limit: limit,
      reading: { positions[min(gestures, positions.count - 1)] },
      gesture: { gestures += 1 }
    )
    return (settled, gestures)
  }

  @Test(arguments: [
    ([0, 0], 1),
    ([0, 4, 8, 8], 3),
    ([0, 4, 4, 9], 2)
  ])
  func `stops at the first gesture that leaves the reading where it was`(
    positions: [Int],
    expectedGestures: Int
  ) {
    let outcome = gestureCount(over: positions, limit: 10)
    #expect(outcome.settled)
    #expect(outcome.gestures == expectedGestures)
  }

  @Test
  func `gives up after the limit when every gesture changes the reading`() {
    let outcome = gestureCount(over: Array(0...10), limit: 4)
    #expect(!outcome.settled)
    #expect(outcome.gestures == 4)
  }
}

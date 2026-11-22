import XCTest
@testable import SuiviAuto

final class DueStatusTests: XCTestCase {
    let now = T.date("2026-01-01", hour: 15)

    func status(days: Int?, km: Int?) -> DueStatus {
        let due = days.map { T.calendar.date(byAdding: .day, value: $0, to: T.date("2026-01-01"))! }
        return DueStatusEvaluator.status(dueDate: due, remainingKm: km, now: now, calendar: T.calendar)
    }

    func testDateThresholds() {
        XCTAssertEqual(status(days: 61, km: nil), .ok)
        XCTAssertEqual(status(days: 60, km: nil), .soon)
        XCTAssertEqual(status(days: 0, km: nil), .soon)
        XCTAssertEqual(status(days: -1, km: nil), .overdue)
    }

    func testKmThresholds() {
        XCTAssertEqual(status(days: nil, km: 1_001), .ok)
        XCTAssertEqual(status(days: nil, km: 1_000), .soon)
        XCTAssertEqual(status(days: nil, km: 0), .soon)
        XCTAssertEqual(status(days: nil, km: -1), .overdue)
    }

    func testWorstCriterionWins() {
        XCTAssertEqual(status(days: 300, km: 500), .soon)
        XCTAssertEqual(status(days: 30, km: -10), .overdue)
        XCTAssertEqual(status(days: -5, km: 50_000), .overdue)
    }

    func testNothingKnownIsOk() {
        XCTAssertEqual(status(days: nil, km: nil), .ok)
    }

    func testOrdering() {
        XCTAssertEqual([DueStatus.soon, .overdue, .ok].max(), .overdue)
    }
}

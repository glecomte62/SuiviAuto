import XCTest
@testable import SuiviAuto

final class MaintenanceSchedulerTests: XCTestCase {
    func estimator(_ pts: [(String, Int)], now: String) -> MileageEstimator {
        MileageEstimator(points: pts.map { MileagePoint(date: T.date($0.0), km: $0.1) }, now: T.date(now), calendar: T.calendar)
    }

    func due(_ rule: RuleSpec, last: (String, Int)?, firstReg: String = "2020-01-01",
             pts: [(String, Int)] = [], now: String) -> MaintenanceDue {
        MaintenanceScheduler.due(rule: rule,
                                 lastDone: last.map { MileagePoint(date: T.date($0.0), km: $0.1) },
                                 firstRegistration: T.date(firstReg),
                                 estimator: estimator(pts, now: now),
                                 now: T.date(now), calendar: T.calendar)
    }

    func testTimeOnlyRuleOk() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 12), last: ("2026-01-10", 30_000), now: "2026-02-01")
        XCTAssertEqual(d.dueDate, T.date("2027-01-10"))
        XCTAssertNil(d.dueKm)
        XCTAssertNil(d.remainingKm)
        XCTAssertEqual(d.status, .ok)
    }

    func testTimeOnlyRuleSoon() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 12), last: ("2025-03-01", 30_000), now: "2026-01-15")
        XCTAssertEqual(d.dueDate, T.date("2026-03-01"))
        XCTAssertEqual(d.status, .soon)
    }

    func testKmReachedBeforeDate() {
        let d = due(RuleSpec(label: "Vidange", intervalKm: 15_000, intervalMonths: 12),
                    last: ("2026-01-01", 10_000),
                    pts: [("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        XCTAssertEqual(d.dueKm, 25_000)
        XCTAssertEqual(d.remainingKm, 14_000)
        XCTAssertEqual(d.dueDate, T.date("2026-05-31"))
        XCTAssertEqual(d.status, .ok)
    }

    func testKmOverdue() {
        let d = due(RuleSpec(label: "Courroie", intervalKm: 30_000, intervalMonths: nil),
                    last: nil, firstReg: "2025-01-01",
                    pts: [("2025-01-01", 0), ("2026-01-01", 36_500)], now: "2026-01-01")
        XCTAssertEqual(d.remainingKm, -6_500)
        XCTAssertEqual(d.status, .overdue)
    }

    func testKmSoon() {
        let d = due(RuleSpec(label: "Vidange", intervalKm: 1_800, intervalMonths: 120),
                    last: ("2026-01-01", 0),
                    pts: [("2026-01-01", 0), ("2026-01-11", 1_000)], now: "2026-01-11")
        XCTAssertEqual(d.remainingKm, 800)
        XCTAssertEqual(d.status, .soon)
    }

    func testWithoutPreviousDoneStartsAtFirstRegistration() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 24), last: nil, firstReg: "2024-06-01", now: "2026-07-01")
        XCTAssertEqual(d.dueDate, T.date("2026-06-01"))
        XCTAssertEqual(d.status, .overdue)
    }
}

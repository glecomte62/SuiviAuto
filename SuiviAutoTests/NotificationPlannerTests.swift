import XCTest
@testable import SuiviAuto

final class NotificationPlannerTests: XCTestCase {
    func item(_ id: String, due: String?) -> DueItem {
        DueItem(id: id, carName: "Clio", carColorHex: "#000000", label: "Vidange", detail: nil,
                dueDate: due.map { T.date($0) }, dueKm: nil, status: .ok, source: .rule("vidange"))
    }

    func testPlansThirtyAndSevenDaysBeforeAtNine() {
        let plans = NotificationPlanner.plan(items: [item("a", due: "2026-03-01")], now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(plans.map(\.id), ["a-J30", "a-J7"])
        XCTAssertEqual(plans.map(\.fireDate), [T.date("2026-01-30", hour: 9), T.date("2026-02-22", hour: 9)])
        XCTAssertEqual(plans[0].title, "Clio : Vidange")
    }

    func testSkipsPastFireDates() {
        let plans = NotificationPlanner.plan(items: [item("a", due: "2026-03-01")], now: T.date("2026-02-10"), calendar: T.calendar)
        XCTAssertEqual(plans.map(\.id), ["a-J7"])
    }

    func testNoDateNoNotification() {
        XCTAssertTrue(NotificationPlanner.plan(items: [item("a", due: nil)], now: T.date("2026-01-01"), calendar: T.calendar).isEmpty)
    }

    func testLimitKeepsSoonest() {
        let items = (1...40).map { item("i\($0)", due: "2027-01-\(String(format: "%02d", min($0, 28)))") }
        let plans = NotificationPlanner.plan(items: items, now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(plans.count, NotificationPlanner.maxPending)
        XCTAssertEqual(plans, plans.sorted { $0.fireDate < $1.fireDate })
    }
}

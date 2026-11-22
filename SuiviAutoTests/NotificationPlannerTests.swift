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
        // éléments fournis du plus lointain au plus proche
        let items = (1...40).reversed().map { item("i\($0)", due: "2027-01-\(String(format: "%02d", min($0, 28)))") }
        let now = T.date("2026-01-01")
        let uncapped = NotificationPlanner.plan(items: items, now: now, calendar: T.calendar, maxPending: .max)
        XCTAssertEqual(uncapped.count, 80)
        let capped = NotificationPlanner.plan(items: items, now: now, calendar: T.calendar, maxPending: 10)
        XCTAssertEqual(capped.count, 10)
        XCTAssertEqual(capped, Array(uncapped.prefix(10)))
        XCTAssertEqual(Set(capped.map(\.id)), Set(uncapped.sorted { $0.fireDate < $1.fireDate }.prefix(10).map(\.id)))
        XCTAssertLessThanOrEqual(capped.last!.fireDate, uncapped[10].fireDate)
        XCTAssertEqual(NotificationPlanner.plan(items: items, now: now, calendar: T.calendar).count, NotificationPlanner.maxPending)
    }

    func testKmRuleWithCalendarDateIsNotLabelledEstimated() {
        let i = DueItem(id: "a", carName: "Clio", carColorHex: "#000000", label: "Vidange", detail: nil,
                        dueDate: T.date("2026-03-01"), dueKm: 60_000, status: .ok, source: .rule("vidange"))
        let plans = NotificationPlanner.plan(items: [i], now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertFalse(plans.isEmpty)
        XCTAssertTrue(plans.allSatisfy { !$0.body.contains("estimée") })
    }

    func testKmDeadlineSaysEstimatedDateAndMileage() {
        let i = DueItem(id: "d", carName: "Clio", carColorHex: "#000000", label: "Pneus", detail: nil,
                        dueDate: T.date("2026-03-01"), dueKm: 90_000, status: .ok, source: .deadline)
        let plans = NotificationPlanner.plan(items: [i], now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(plans.map(\.id), ["d-J30", "d-J7"])
        XCTAssertEqual(plans.map(\.fireDate), [T.date("2026-01-30", hour: 9), T.date("2026-02-22", hour: 9)])
        let expected = "Échéance estimée le \(Fmt.date(T.date("2026-03-01"))) (à \(Fmt.km(90_000)))."
        XCTAssertEqual(plans.map(\.body), [expected, expected])
    }
}

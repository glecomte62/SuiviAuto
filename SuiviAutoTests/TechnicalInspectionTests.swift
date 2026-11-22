import XCTest
@testable import SuiviAuto

final class TechnicalInspectionTests: XCTestCase {
    let firstReg = T.date("2020-03-15")

    func due(_ records: [CTRecord]) -> CTDue {
        TechnicalInspectionCalculator.nextDue(firstRegistration: firstReg, records: records, calendar: T.calendar)
    }

    func testFirstInspectionAtFourYears() {
        XCTAssertEqual(due([]), CTDue(dueDate: T.date("2024-03-15"), isCounterVisit: false, drivingForbidden: false))
    }

    func testFavorableAddsTwoYears() {
        XCTAssertEqual(due([CTRecord(date: T.date("2024-03-10"), result: .favorable)]).dueDate, T.date("2026-03-10"))
    }

    func testUnfavorableRequiresCounterVisitWithinTwoMonths() {
        let d = due([CTRecord(date: T.date("2024-03-10"), result: .defavorable)])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2024-05-10"), isCounterVisit: true, drivingForbidden: false))
    }

    func testCriticalForbidsDriving() {
        let d = due([CTRecord(date: T.date("2024-03-10"), result: .critique)])
        XCTAssertEqual(d.dueDate, T.date("2024-05-10"))
        XCTAssertTrue(d.isCounterVisit)
        XCTAssertTrue(d.drivingForbidden)
    }

    func testFavorableCounterVisitExtendsFromInitialInspection() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-04-01"), result: .favorable),
        ])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testCounterVisitWindowComparesCalendarDays() {
        // contre-visite le dernier jour de la fenêtre, plus tard dans la journée que le CT initial
        let d = due([
            CTRecord(date: T.date("2024-03-10", hour: 8), result: .defavorable),
            CTRecord(date: T.date("2024-05-10", hour: 18), result: .favorable),
        ])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testSameDayOrderingIgnoresTimeOfDay() {
        // même jour : l'échec passe avant le favorable, même saisi avec une heure plus tardive
        let d = due([
            CTRecord(date: T.date("2024-03-10", hour: 8), result: .favorable),
            CTRecord(date: T.date("2024-03-10", hour: 18), result: .defavorable),
        ])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testLateCounterVisitCountsAsNewInspection() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-06-15"), result: .favorable),
        ])
        XCTAssertEqual(d.dueDate, T.date("2026-06-15"))
    }

    func testRecordsAreSortedByDate() {
        let d = due([
            CTRecord(date: T.date("2026-03-01"), result: .favorable),
            CTRecord(date: T.date("2024-03-01"), result: .favorable),
        ])
        XCTAssertEqual(d.dueDate, T.date("2028-03-01"))
    }

    func testStaleFailureDoesNotAnchorLaterCycle() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-09-10"), result: .defavorable),
            CTRecord(date: T.date("2024-10-01"), result: .favorable),
        ])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-09-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testFailedCounterVisitKeepsInitialAnchor() {
        let fails = [
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-04-01"), result: .critique),
        ]
        XCTAssertEqual(due(fails), CTDue(dueDate: T.date("2024-05-10"), isCounterVisit: true, drivingForbidden: true))
        let d = due(fails + [CTRecord(date: T.date("2024-05-01"), result: .favorable)])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testCounterVisitExactlyTwoMonthsLater() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-05-10"), result: .favorable),
        ])
        XCTAssertEqual(d.dueDate, T.date("2026-03-10"))
    }

    func testSameDayFailureThenFavorableInAnyOrder() {
        let fail = CTRecord(date: T.date("2024-03-10"), result: .defavorable)
        let ok = CTRecord(date: T.date("2024-03-10"), result: .favorable)
        let expected = CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false)
        XCTAssertEqual(due([fail, ok]), expected)
        XCTAssertEqual(due([ok, fail]), expected)
    }
}

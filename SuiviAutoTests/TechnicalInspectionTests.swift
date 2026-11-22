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
}

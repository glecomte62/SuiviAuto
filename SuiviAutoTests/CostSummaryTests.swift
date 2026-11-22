import XCTest
@testable import SuiviAuto

final class CostSummaryTests: XCTestCase {
    let entries = [
        CostEntry(carName: "Clio", date: T.date("2025-03-01"), kind: .entretien, amountCents: 20_000, status: .facture),
        CostEntry(carName: "Clio", date: T.date("2026-02-01"), kind: .pneus, amountCents: 40_000, status: .facture),
        CostEntry(carName: "Clio", date: T.date("2026-05-01"), kind: .reparation, amountCents: 99_999, status: .devis),
        CostEntry(carName: "C3", date: T.date("2026-04-01"), kind: .entretien, amountCents: 15_000, status: .facture),
    ]

    func testByYearExcludesQuotes() {
        XCTAssertEqual(CostSummary.byYear(entries, calendar: T.calendar), [2025: 20_000, 2026: 55_000])
    }

    func testByCarAndYear() {
        let r = CostSummary.byCarAndYear(entries, calendar: T.calendar)
        XCTAssertEqual(r[YearCar(year: 2026, carName: "Clio")], 40_000)
        XCTAssertEqual(r[YearCar(year: 2026, carName: "C3")], 15_000)
        XCTAssertEqual(r[YearCar(year: 2025, carName: "Clio")], 20_000)
        XCTAssertEqual(r.count, 3)
    }

    func testByKindForYear() {
        XCTAssertEqual(CostSummary.byKind(entries, year: 2026, calendar: T.calendar), [.pneus: 40_000, .entretien: 15_000])
    }

    func testTotalForYear() {
        XCTAssertEqual(CostSummary.total(entries, year: 2026, calendar: T.calendar), 55_000)
        XCTAssertEqual(CostSummary.total(entries, year: 2024, calendar: T.calendar), 0)
    }
}

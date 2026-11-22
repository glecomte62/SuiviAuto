import XCTest
@testable import SuiviAuto

final class CostSummaryTests: XCTestCase {
    let entries = [
        CostEntry(carID: "clio", carName: "Clio", date: T.date("2025-03-01"), kind: .entretien, amountCents: 20_000, status: .facture),
        CostEntry(carID: "clio", carName: "Clio", date: T.date("2026-02-01"), kind: .pneus, amountCents: 40_000, status: .facture),
        CostEntry(carID: "clio", carName: "Clio", date: T.date("2026-05-01"), kind: .reparation, amountCents: 99_999, status: .devis),
        CostEntry(carID: "c3", carName: "C3", date: T.date("2026-04-01"), kind: .entretien, amountCents: 15_000, status: .facture),
    ]

    func testByYearExcludesQuotes() {
        XCTAssertEqual(CostSummary.byYear(entries, calendar: T.calendar), [2025: 20_000, 2026: 55_000])
    }

    func testByCarAndYear() {
        let r = CostSummary.byCarAndYear(entries, calendar: T.calendar)
        XCTAssertEqual(r[YearCar(year: 2026, carID: "clio", carName: "Clio")], 40_000)
        XCTAssertEqual(r[YearCar(year: 2026, carID: "c3", carName: "C3")], 15_000)
        XCTAssertEqual(r[YearCar(year: 2025, carID: "clio", carName: "Clio")], 20_000)
        XCTAssertEqual(r.count, 3)
    }

    func testCarsWithSameNameStaySeparate() {
        let twins = [
            CostEntry(carID: "a", carName: "Clio", date: T.date("2026-01-01"), kind: .entretien, amountCents: 100, status: .facture),
            CostEntry(carID: "b", carName: "Clio", date: T.date("2026-02-01"), kind: .entretien, amountCents: 200, status: .facture),
        ]
        let r = CostSummary.byCarAndYear(twins, calendar: T.calendar)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[YearCar(year: 2026, carID: "a", carName: "Clio")], 100)
        XCTAssertEqual(r[YearCar(year: 2026, carID: "b", carName: "Clio")], 200)
        // carName est purement descriptif : l'identité repose sur year + carID
        XCTAssertEqual(YearCar(year: 2026, carID: "a", carName: "X"), YearCar(year: 2026, carID: "a", carName: "Y"))
    }

    func testByKindForYear() {
        XCTAssertEqual(CostSummary.byKind(entries, year: 2026, calendar: T.calendar), [.pneus: 40_000, .entretien: 15_000])
    }

    func testTotalForYear() {
        XCTAssertEqual(CostSummary.total(entries, year: 2026, calendar: T.calendar), 55_000)
        XCTAssertEqual(CostSummary.total(entries, year: 2024, calendar: T.calendar), 0)
    }
}

import XCTest
@testable import SuiviAuto

final class MileageEstimatorTests: XCTestCase {
    func make(_ pts: [(String, Int)], now: String) -> MileageEstimator {
        MileageEstimator(points: pts.map { MileagePoint(date: T.date($0.0), km: $0.1) },
                         now: T.date(now), calendar: T.calendar)
    }

    func testNoPoints() {
        let e = make([], now: "2026-01-01")
        XCTAssertNil(e.latest)
        XCTAssertNil(e.kmPerDay)
        XCTAssertNil(e.estimatedCurrentMileage)
        XCTAssertNil(e.estimatedDate(forMileage: 1000))
    }

    func testLatestOnSameDayIsHighestMileageRegardlessOfTime() {
        let e = MileageEstimator(points: [MileagePoint(date: T.date("2025-06-01", hour: 8), km: 42_100),
                                          MileagePoint(date: T.date("2025-06-01", hour: 18), km: 42_000)],
                                 now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(e.latest?.km, 42_100)
    }

    func testSameDayPointsGiveNoRate() {
        // deux relevés le même jour à 10 h d'écart : pas de moyenne absurde (240 km/j)
        let e = MileageEstimator(points: [MileagePoint(date: T.date("2025-06-01", hour: 8), km: 42_000),
                                          MileagePoint(date: T.date("2025-06-01", hour: 18), km: 42_100)],
                                 now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertNil(e.kmPerDay)
        XCTAssertEqual(e.estimatedCurrentMileage, 42_100)
    }

    func testSinglePoint() {
        let e = make([("2025-06-01", 42_000)], now: "2026-01-01")
        XCTAssertNil(e.kmPerDay)
        XCTAssertEqual(e.estimatedCurrentMileage, 42_000)
        XCTAssertNil(e.estimatedDate(forMileage: 50_000))
        XCTAssertEqual(e.estimatedDate(forMileage: 40_000), T.date("2025-06-01"))
    }

    func testExtrapolatesFromAllHistoryWhenFewRecentPoints() {
        // une seule mesure dans les 12 derniers mois -> on utilise tout l'historique
        let e = make([("2025-01-01", 10_000), ("2026-01-01", 25_000)], now: "2026-07-02")
        XCTAssertEqual(e.kmPerDay!, 15_000.0 / 365.0, accuracy: 0.0001)
        XCTAssertEqual(e.estimatedCurrentMileage, 32_479) // 25000 + 15000*182/365
    }

    func testUsesLastTwelveMonthsWhenEnoughPoints() {
        let e = make([("2020-01-01", 0), ("2025-08-01", 50_000), ("2026-06-01", 60_000)], now: "2026-07-01")
        XCTAssertEqual(e.kmPerDay!, 10_000.0 / 304.0, accuracy: 0.0001)
    }

    func testEstimatedDateForMileage() {
        let e = make([("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        XCTAssertEqual(e.estimatedDate(forMileage: 12_000), T.date("2026-01-21"))
        XCTAssertEqual(e.estimatedDate(forMileage: 5_000), T.date("2026-01-11"))
    }

    func testDecreasingMileageGivesNoProjection() {
        let e = make([("2026-01-01", 10_000), ("2026-01-11", 9_000)], now: "2026-02-01")
        XCTAssertEqual(e.estimatedCurrentMileage, 9_000)
        XCTAssertNil(e.estimatedDate(forMileage: 20_000))
    }

    func testUnsortedInput() {
        let e = make([("2026-01-11", 11_000), ("2026-01-01", 10_000)], now: "2026-01-11")
        XCTAssertEqual(e.latest, MileagePoint(date: T.date("2026-01-11"), km: 11_000))
        XCTAssertEqual(e.kmPerDay!, 100, accuracy: 0.0001)
    }

    func testSameDayRecentReadingsFallBackToFullHistory() {
        // deux relevés le même jour dans les 12 derniers mois : fenêtre inexploitable -> tout l'historique
        let e = make([("2024-01-01", 0), ("2026-06-01", 30_000), ("2026-06-01", 30_100)], now: "2026-07-01")
        XCTAssertEqual(e.kmPerDay!, 30_100.0 / 882.0, accuracy: 0.0001)
    }

    func testEstimatedDateAcrossDSTIsLocalMidnight() {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        func d(_ day: Int, _ month: Int) -> Date { paris.date(from: DateComponents(year: 2026, month: month, day: day))! }
        let e = MileageEstimator(points: [MileagePoint(date: d(15, 10), km: 10_000), MileagePoint(date: d(20, 10), km: 10_500)],
                                 now: d(20, 10), calendar: paris)
        // 100 km/jour : 1 000 km après le 20/10 -> 30/10, après le changement d'heure du 25/10
        XCTAssertEqual(e.estimatedDate(forMileage: 11_500), d(30, 10))
    }
}

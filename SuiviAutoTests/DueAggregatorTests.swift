import XCTest
import SwiftData
@testable import SuiviAuto

final class DueAggregatorTests: XCTestCase {
    var ctx: ModelContext!
    var car: Car!
    let now = T.date("2026-01-10")

    override func setUpWithError() throws {
        ctx = try T.makeContext()
        car = Car(name: "Clio", firstRegistrationDate: T.date("2022-05-01"))
        ctx.insert(car)
        car.addDefaultRules(in: ctx)
        try ctx.save()
    }

    @discardableResult
    func addIntervention(_ date: String, km: Int, kind: InterventionKind, status: InterventionStatus = .facture,
                         ruleKey: String? = nil, ct: CTResult? = nil, cents: Int? = nil) -> Intervention {
        let i = Intervention(date: T.date(date), mileage: km, kind: kind, status: status)
        i.ruleKey = ruleKey
        i.ctResult = ct
        i.amountCents = cents
        ctx.insert(i); i.car = car
        return i
    }

    func addReading(_ date: String, km: Int) {
        let r = OdometerReading(date: T.date(date), mileage: km)
        ctx.insert(r); r.car = car
    }

    func items() -> [DueItem] { DueAggregator.items(for: car, now: now, calendar: T.calendar) }

    func testScenarioFromSpec() throws {
        addIntervention("2025-03-01", km: 40_000, kind: .entretien, ruleKey: "vidange")
        addReading("2026-01-01", km: 52_000)
        try ctx.save()

        let list = items()
        XCTAssertEqual(list.map(\.label), ["Liquide de frein", "Vidange moteur", "Contrôle technique", "Courroie de distribution"])

        let vidange = list.first { $0.label == "Vidange moteur" }!
        XCTAssertEqual(vidange.dueKm, 55_000)
        XCTAssertEqual(vidange.dueDate, T.date("2026-03-01"))
        XCTAssertEqual(vidange.status, .soon)

        let ct = list.first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.dueDate, T.date("2026-05-01"))
        XCTAssertEqual(ct.status, .ok)

        XCTAssertEqual(list.first!.status, .overdue)
        XCTAssertEqual(DueAggregator.worstStatus(for: car, now: now, calendar: T.calendar), .overdue)
        XCTAssertEqual(CarAnalytics.estimator(for: car, now: now, calendar: T.calendar).estimatedCurrentMileage, 52_353)
    }

    func testQuotesAreIgnored() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .controleTechnique, ct: .favorable)
        addIntervention("2026-01-08", km: 50_100, kind: .controleTechnique, status: .devis, ct: .defavorable)
        addIntervention("2026-01-08", km: 99_999, kind: .entretien, status: .devis, ruleKey: "vidange")
        try ctx.save()

        let ct = items().first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.dueDate, T.date("2028-01-05"))
        let vidange = items().first { $0.source == .rule("vidange") }!
        XCTAssertEqual(vidange.dueKm, 15_000)
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: now), 50_000)
    }

    func testCriticalCTIsOverdueWithDetail() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .controleTechnique, ct: .critique)
        try ctx.save()
        let ct = items().first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.label, "Contre-visite")
        XCTAssertEqual(ct.status, .overdue)
        XCTAssertNotNil(ct.detail)
    }

    func testDeadlines() throws {
        let d = Deadline(label: "Assurance", dueDate: T.date("2026-02-01"), repeatsYearly: true)
        ctx.insert(d); d.car = car
        try ctx.save()
        let item = items().first { $0.source == .deadline }!
        XCTAssertEqual(item.label, "Assurance")
        XCTAssertEqual(item.status, .soon)
        XCTAssertEqual(item.carName, "Clio")
    }

    func testLastKnownMileageRespectsDate() throws {
        addReading("2025-01-01", km: 30_000)
        addReading("2026-01-01", km: 50_000)
        try ctx.save()
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: T.date("2025-06-01")), 30_000)
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: T.date("2024-06-01")), nil)
    }

    func testCostEntries() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .pneus, cents: 40_000)
        addIntervention("2026-01-06", km: 50_000, kind: .pneus)  // sans montant : ignorée
        try ctx.save()
        let entries = CarAnalytics.costEntries(for: [car])
        XCTAssertEqual(entries, [CostEntry(carID: car.uuid.uuidString, carName: "Clio", date: T.date("2026-01-05"), kind: .pneus, amountCents: 40_000, status: .facture)])
    }

    func testSameDateItemsAreOrderedDeterministically() {
        let d = T.date("2026-03-01")
        func item(_ id: String, _ car: String, _ label: String, _ status: DueStatus, _ date: Date? = d) -> DueItem {
            DueItem(id: id, carName: car, carColorHex: "#000000", label: label, detail: nil,
                    dueDate: date, dueKm: nil, status: status, source: .deadline)
        }
        let list = [
            item("z", "C3", "B", .ok, nil),
            item("y", "C3", "A", .ok, nil),
            item("5", "Clio", "B", .ok),
            item("4", "Clio", "A", .ok),
            item("3", "C3", "A", .soon),
            item("2", "C3", "A", .ok, d),
            item("1", "C3", "A", .ok, d),
        ]
        let expected = ["3", "1", "2", "4", "5", "y", "z"]
        XCTAssertEqual(list.sorted(by: DueItem.byDate).map(\.id), expected)
        XCTAssertEqual(list.reversed().sorted(by: DueItem.byDate).map(\.id), expected)
    }
}

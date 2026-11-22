import XCTest
import SwiftData
@testable import SuiviAuto

final class ModelTests: XCTestCase {
    func testCarRelationshipsAndCascade() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-01-01"), mileage: 40_000, kind: .entretien)
        ctx.insert(i); i.car = car
        let r = OdometerReading(date: T.date("2026-02-01"), mileage: 41_000)
        ctx.insert(r); r.car = car
        try ctx.save()

        XCTAssertEqual(car.interventions.count, 1)
        XCTAssertEqual(car.readings.count, 1)

        ctx.delete(car)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Intervention>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<OdometerReading>()), 0)
    }

    func testEnumAccessors() {
        let i = Intervention(date: .now, mileage: 0, kind: .controleTechnique, status: .devis)
        XCTAssertEqual(i.kind, .controleTechnique)
        XCTAssertEqual(i.status, .devis)
        i.ctResult = .critique
        XCTAssertEqual(i.ctResultRaw, "critique")
        i.ctResult = nil
        XCTAssertNil(i.ctResultRaw)
    }

    func testDefaultRules() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        car.addDefaultRules(in: ctx)
        try ctx.save()
        XCTAssertEqual(Set(car.rules.map(\.key)), ["vidange", "courroie", "liquide-frein"])
        let vidange = car.rules.first { $0.key == "vidange" }!
        XCTAssertEqual(vidange.intervalKm, 15_000)
        XCTAssertEqual(vidange.intervalMonths, 12)
    }

    func testDefaultRulesAreIdempotent() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        car.addDefaultRules(in: ctx)
        car.addDefaultRules(in: ctx)
        try ctx.save()
        XCTAssertEqual(car.rules.count, 3)
    }

    func testUnknownStatusFallsBackToQuote() {
        let i = Intervention(date: .now, mileage: 0, kind: .entretien)
        i.statusRaw = "xyz"
        XCTAssertEqual(i.status, .devis)
    }

    func testRuleKeyGeneration() {
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Filtre à air", existing: []), "filtre-a-air")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Vidange", existing: ["vidange"]), "vidange-2")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Vidange", existing: ["vidange", "vidange-2"]), "vidange-3")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "!!!", existing: []), "regle")
    }

    func testDeadlineMarkDone() {
        let yearly = Deadline(label: "Assurance", dueDate: T.date("2026-03-01"), repeatsYearly: true)
        XCTAssertTrue(yearly.markDone(calendar: T.calendar))
        XCTAssertEqual(yearly.dueDate, T.date("2027-03-01"))

        let once = Deadline(label: "Garantie", dueDate: T.date("2026-03-01"), repeatsYearly: false)
        XCTAssertFalse(once.markDone(calendar: T.calendar))
        XCTAssertEqual(once.dueDate, T.date("2026-03-01"))
    }
}

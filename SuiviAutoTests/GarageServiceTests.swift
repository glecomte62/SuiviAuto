import SwiftData
import XCTest
@testable import SuiviAuto

final class GarageServiceTests: XCTestCase {
    var ctx: ModelContext!
    var car: Car!

    override func setUpWithError() throws {
        ctx = try T.makeContext()
        car = Car(name: "Clio", firstRegistrationDate: T.date("2018-01-01"))
        ctx.insert(car)
    }

    func garage(_ name: String) -> Garage {
        let g = Garage(name: name)
        ctx.insert(g)
        return g
    }

    @discardableResult
    func intervention(_ date: String, at g: Garage, status: InterventionStatus = .facture, cents: Int? = nil) -> Intervention {
        let i = Intervention(date: T.date(date), mileage: 1, kind: .entretien, status: status)
        i.amountCents = cents
        i.garageTextMigrated = true
        ctx.insert(i)
        i.car = car
        i.garageRef = g
        return i
    }

    func testSortedIgnoresCaseAndAccents() {
        let names = GarageService.sorted([garage("Émile Auto"), garage("speedy"), garage("Allo Pneus")]).map(\.name)
        XCTAssertEqual(names, ["Allo Pneus", "Émile Auto", "speedy"])
    }

    func testDuplicateName() {
        let a = garage("Garage du Nord")
        let all = [a, garage("Speedy")]
        XCTAssertTrue(GarageService.hasDuplicateName(" garage du nörd ", among: all, excluding: nil))
        XCTAssertFalse(GarageService.hasDuplicateName("Garage du Nord", among: all, excluding: a))
        XCTAssertFalse(GarageService.hasDuplicateName("Norauto", among: all, excluding: nil))
    }

    func testDeleteKeepsNameOnInterventionsAndRemovesContacts() throws {
        let g = garage("Garage du Nord")
        let c = GarageContact(name: "Paul")
        ctx.insert(c)
        c.garage = g
        let i = intervention("2025-01-01", at: g)
        try ctx.save()

        try GarageService.delete(g, in: ctx)

        XCTAssertNil(i.garageRef)
        XCTAssertEqual(i.garage, "Garage du Nord")
        XCTAssertTrue(i.garageTextMigrated)
        XCTAssertEqual(i.garageDisplayName, "Garage du Nord")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Garage>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<GarageContact>()), 0)
        XCTAssertEqual(try GarageMigrator.run(in: ctx), GarageMigrator.Result(created: 0, linked: 0))
    }

    func testHistoryAndInvoiceTotal() throws {
        let g = garage("Garage du Nord")
        let old = intervention("2024-01-01", at: g, cents: 10_000)
        let recent = intervention("2025-01-01", at: g, cents: 5_000)
        let quote = intervention("2025-06-01", at: g, status: .devis, cents: 99_999)
        let latest = intervention("2025-07-01", at: g)
        try ctx.save()

        let history = GarageService.interventions(of: g)
        XCTAssertEqual(history.count, 4)
        XCTAssertTrue(history[0] === latest)
        XCTAssertTrue(history[1] === quote)
        XCTAssertTrue(history[2] === recent)
        XCTAssertTrue(history[3] === old)
        XCTAssertEqual(GarageService.invoiceTotalCents(of: g), 15_000)
    }
}

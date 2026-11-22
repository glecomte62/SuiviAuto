import SwiftData
import XCTest
@testable import SuiviAuto

final class GarageModelTests: XCTestCase {
    func testNameKeyIgnoresCaseSpacesAndAccents() {
        XCTAssertEqual(Garage.cleanedName("  garage   du\tNord "), "garage du Nord")
        XCTAssertEqual(Garage.nameKey("Garage du Nörd"), Garage.nameKey("  garage  du NORD "))
        XCTAssertNotEqual(Garage.nameKey("Garage du Nord"), Garage.nameKey("Garage du Sud"))
    }

    func testRatingIsClamped() {
        let g = Garage(name: "A")
        g.rating = 9
        XCTAssertEqual(g.rating, 5)
        g.rating = -2
        XCTAssertEqual(g.rating, 0)
        g.ratingValue = 42 // valeur corrompue en base
        XCTAssertEqual(g.rating, 5)
    }

    func testDisplayNamePrefersLinkedGarage() throws {
        let ctx = try T.makeContext()
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        i.garage = "Ancien nom"
        ctx.insert(i)
        XCTAssertEqual(i.garageDisplayName, "Ancien nom")
        let g = Garage(name: "Garage du Nord")
        ctx.insert(g)
        i.garageRef = g
        XCTAssertEqual(i.garageDisplayName, "Garage du Nord")
    }

    func testContactsCascadeAndInterventionsNullify() throws {
        let ctx = try T.makeContext()
        let g = Garage(name: "Garage du Nord")
        ctx.insert(g)
        let c = GarageContact(name: "Paul")
        ctx.insert(c)
        c.garage = g
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        ctx.insert(i)
        i.garageRef = g
        try ctx.save()
        XCTAssertEqual(g.contacts.count, 1)
        XCTAssertEqual(g.interventions.count, 1)

        ctx.delete(g)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<GarageContact>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Intervention>()), 1)
        XCTAssertNil(i.garageRef)
    }

    func testSuggestedRoles() {
        XCTAssertEqual(GarageContact.suggestedRoles.first, "Réception")
        XCTAssertTrue(GarageContact.suggestedRoles.contains("Chef d'atelier"))
    }
}

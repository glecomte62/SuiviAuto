import PDFKit
import SwiftData
import XCTest
@testable import SuiviAuto

final class CarnetTests: XCTestCase {
    var ctx: ModelContext!
    var car: Car!
    var nord: Garage!

    override func setUpWithError() throws {
        ctx = try T.makeContext()
        car = Car(name: "Clio", firstRegistrationDate: T.date("2018-01-01"))
        car.plate = "AB-123-CD"
        ctx.insert(car)
        nord = Garage(name: "Garage du Nord")
        ctx.insert(nord)
        add("2024-01-10", km: 40_000, ops: [.vidange, .filtres], cents: 18_990, garage: nord)
        add("2025-03-01", km: 52_000, ops: [.pneus], cents: 40_000, garage: nil)
        add("2025-06-01", km: 55_000, ops: [.freins], cents: 99_999, garage: nord, status: .devis)
        add("2025-09-01", km: 58_000, ops: [], cents: nil, garage: nil, title: "Remplacement balais")
        try ctx.save()
    }

    @discardableResult
    func add(_ date: String, km: Int, ops: [MaintenanceOperation], cents: Int?, garage: Garage?,
             status: InterventionStatus = .facture, title: String = "") -> Intervention {
        let i = Intervention(date: T.date(date), mileage: km, kind: .entretien, title: title, status: status)
        i.operations = ops
        i.amountCents = cents
        i.garageTextMigrated = true
        ctx.insert(i); i.car = car; i.garageRef = garage
        return i
    }

    func testInvoicesOnlyNewestFirst() {
        let e = Carnet.entries(for: car, query: CarnetQuery(), calendar: T.calendar)
        XCTAssertEqual(e.map(\.mileage), [58_000, 52_000, 40_000])
        XCTAssertEqual(Carnet.totalCents(e), 58_990)
    }

    func testFilters() {
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(operation: .vidange), calendar: T.calendar).map(\.mileage), [40_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(year: 2025), calendar: T.calendar).map(\.mileage), [58_000, 52_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(garageID: nord.uuid), calendar: T.calendar).map(\.mileage), [40_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(text: "filtres"), calendar: T.calendar).map(\.mileage), [40_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(text: "balais"), calendar: T.calendar).map(\.mileage), [58_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(text: "nord"), calendar: T.calendar).map(\.mileage), [40_000])
    }

    func testYearsAndGarages() {
        XCTAssertEqual(Carnet.years(for: car, calendar: T.calendar), [2025, 2024])
        XCTAssertEqual(Carnet.garages(for: car).map(\.name), ["Garage du Nord"])
    }

    func testPDFExport() throws {
        let entries = Carnet.entries(for: car, query: CarnetQuery(), calendar: T.calendar)
        let data = CarnetPDFExporter.render(car: car, entries: entries, estimatedMileage: 60_000, calendar: T.calendar)
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThanOrEqual(doc.pageCount, 1)
        let text = doc.string ?? ""
        XCTAssertTrue(text.contains("Clio"))
        XCTAssertTrue(text.contains("AB-123-CD"))
        XCTAssertTrue(text.contains("Vidange, Filtres"))
        XCTAssertTrue(text.contains("Garage du Nord"))
        XCTAssertTrue(text.contains("Remplacement balais"))
    }

    func testPDFPaginates() throws {
        for n in 0..<120 { add("2023-01-01", km: 1_000 + n, ops: [.vidange], cents: 100, garage: nil) }
        try ctx.save()
        let entries = Carnet.entries(for: car, query: CarnetQuery(), calendar: T.calendar)
        let data = CarnetPDFExporter.render(car: car, entries: entries, estimatedMileage: nil, calendar: T.calendar)
        XCTAssertGreaterThan(try XCTUnwrap(PDFDocument(data: data)).pageCount, 1)
    }
}

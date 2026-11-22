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

    // MARK: - Revue de code

    func testGaragesOnlyFromInvoices() throws {
        let devisOnly = Garage(name: "Autre garage")
        ctx.insert(devisOnly)
        add("2025-07-01", km: 56_000, ops: [.pneus], cents: 1_000, garage: devisOnly, status: .devis)
        try ctx.save()
        XCTAssertEqual(Carnet.garages(for: car).map(\.name), ["Garage du Nord"])
    }

    func testSearchIgnoresAccents() throws {
        add("2025-10-01", km: 60_000, ops: [], cents: 7_800, garage: nil, title: "Contrôle technique")
        try ctx.save()
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(text: "controle"), calendar: T.calendar).map(\.mileage), [60_000])
        XCTAssertEqual(Carnet.entries(for: car, query: CarnetQuery(text: "CONTRÔLE"), calendar: T.calendar).map(\.mileage), [60_000])
    }

    /// Colonnes du PDF : opérations longues et garage long restent dans leur colonne, montant à droite.
    func testPDFColumns() throws {
        let renault = Garage(name: "Garage Renault Lille Centre")
        ctx.insert(renault)
        let i = add("2026-03-05", km: 123_456, ops: [.vidange, .courroie, .liquideFrein, .freins, .pneus, .filtres],
                    cents: 123_456, garage: renault)
        try ctx.save()
        let data = CarnetPDFExporter.render(car: car, entries: [i], estimatedMileage: nil, calendar: T.calendar)
        let doc = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(doc.page(at: 0))
        let garage = try XCTUnwrap(doc.findString("Garage Renault", withOptions: []).first)
        XCTAssertGreaterThanOrEqual(garage.bounds(for: page).minX, 340)
        let amount = try XCTUnwrap(doc.findString("1 234,56", withOptions: []).first)
        XCTAssertGreaterThan(amount.bounds(for: page).minX, 450)
        let header = try XCTUnwrap(doc.findString("Montant", withOptions: []).first)
        XCTAssertGreaterThan(header.bounds(for: page).minX, 450)
        // les opérations repliées restent dans la colonne « Opérations » (pas sous la date)
        for sel in doc.findString("Filtres", withOptions: []) {
            let x = sel.bounds(for: page).minX
            XCTAssertTrue((175..<380).contains(x), "Filtres à x=\(x)")
        }
    }

    func testPDFStripsTabsAndNewlinesAndNumbersPages() throws {
        let i = add("2026-03-05", km: 70_000, ops: [], cents: 5_000, garage: nil, title: "Balais\tAV\nAR")
        for n in 0..<120 { add("2023-01-01", km: 1_000 + n, ops: [.vidange], cents: 100, garage: nil) }
        try ctx.save()
        let entries = Carnet.entries(for: car, query: CarnetQuery(), calendar: T.calendar)
        let doc = try XCTUnwrap(PDFDocument(data: CarnetPDFExporter.render(car: car, entries: entries, estimatedMileage: nil, calendar: T.calendar)))
        let n = doc.pageCount
        XCTAssertGreaterThan(n, 1)
        XCTAssertTrue(doc.page(at: 0)?.string?.contains("page 1 / \(n)") ?? false)
        XCTAssertTrue(doc.page(at: n - 1)?.string?.contains("page \(n) / \(n)") ?? false)
        XCTAssertTrue(doc.page(at: 1)?.string?.contains("Opérations") ?? false, "en-tête répété page 2")
        XCTAssertEqual(i.title, "Balais\tAV\nAR")
        let first = try XCTUnwrap(doc.findString("Balais", withOptions: []).first)
        let page = try XCTUnwrap(first.pages.first)
        let ar = try XCTUnwrap(doc.findString("AR", withOptions: [.caseInsensitive]).first { $0.pages.first == page && abs($0.bounds(for: page).midY - first.bounds(for: page).midY) < 3 })
        XCTAssertGreaterThan(ar.bounds(for: page).minX, first.bounds(for: page).minX)
    }
}

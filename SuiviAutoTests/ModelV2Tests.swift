import SwiftData
import XCTest
@testable import SuiviAuto

final class ModelV2Tests: XCTestCase {
    func testOperationsRoundTripInCatalogOrder() {
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        XCTAssertEqual(i.operations, [])
        i.operations = [.filtres, .vidange, .filtres]
        XCTAssertEqual(i.operationsRaw, "vidange,filtres")
        XCTAssertEqual(i.operations, [.vidange, .filtres])
        i.operationsRaw = "vidange,inconnu,pneus"
        XCTAssertEqual(i.operations, [.vidange, .pneus])
    }

    func testOperationsSummary() {
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien, title: "Révision")
        XCTAssertEqual(i.operationsSummary, "")
        i.operations = [.vidange, .filtres]
        i.customOperation = "Balais d'essuie-glace"
        XCTAssertEqual(i.operationsSummary, "Vidange, Filtres, Balais d'essuie-glace")
    }

    func testOperationCatalog() {
        XCTAssertEqual(MaintenanceOperation.allCases.map(\.label), [
            "Vidange", "Courroie de distribution / accessoires", "Liquide de frein", "Plaquettes / Disques",
            "Filtres", "Pneumatiques", "Contrôle technique", "Autre",
        ])
        XCTAssertEqual(MaintenanceOperation.vidange.suggestedRuleKey, "vidange")
        XCTAssertEqual(MaintenanceOperation.courroie.suggestedRuleKey, "courroie")
        XCTAssertEqual(MaintenanceOperation.liquideFrein.suggestedRuleKey, "liquide-frein")
        XCTAssertNil(MaintenanceOperation.pneus.suggestedRuleKey)
    }

    func testDetectOperationsFromText() {
        XCTAssertEqual(MaintenanceOperation.detect(in: "VIDANGE + FILTRE A HUILE, plaquettes AV"), [.vidange, .freins, .filtres])
        XCTAssertEqual(MaintenanceOperation.detect(in: "Remplacement kit de distribution"), [.courroie])
        XCTAssertEqual(MaintenanceOperation.detect(in: "Contrôle technique périodique"), [.controleTechnique])
        XCTAssertEqual(MaintenanceOperation.detect(in: "Purge liquide de frein"), [.liquideFrein])
        XCTAssertEqual(MaintenanceOperation.detect(in: "2 pneus Michelin + équilibrage"), [.pneus])
        XCTAssertEqual(MaintenanceOperation.detect(in: "Lavage"), [])
    }

    func testDetectAvoidsFalsePositives() {
        let cases: [(String, [MaintenanceOperation])] = [
            ("Vidange liquide de refroidissement", []),
            ("Vidange du circuit de refroidissement", []),
            ("Vidange boîte de vitesses", []),
            ("Vidange + filtre à huile", [.vidange, .filtres]),
            ("Vidange boîte + vidange moteur", [.vidange]),
            ("Disque d'embrayage", []),
            ("Disques et plaquettes AV", [.freins]),
            ("Purge clim", []),
            ("Purge du liquide de frein", [.liquideFrein]),
            ("Purge circuit de freinage", [.liquideFrein]),
            ("Auto Distribution SAS", []),
            ("Kit de distribution + pompe à eau", [.courroie]),
            ("Kit distribution", [.courroie]),
            ("contrôle\ntechnique", [.controleTechnique]),
        ]
        for (text, expected) in cases {
            XCTAssertEqual(MaintenanceOperation.detect(in: text), expected, text)
        }
    }

    func testFoldNormalisesPunctuationButLightFoldKeepsIt() {
        XCTAssertEqual(MaintenanceOperation.fold("  Disque d'EMBRAYAGE,\n(contrôle) "), "disque d embrayage controle")
        XCTAssertEqual(MaintenanceOperation.foldCaseAndAccents("Payé le 05/03/2026 : 189,90 €"), "paye le 05/03/2026 : 189,90 €")
    }

    func testDeadlineDefaultsAndMode() {
        let d = Deadline(label: "Pneus", dueDate: T.date("2026-01-01"), repeatsYearly: false)
        XCTAssertEqual(d.mode, .date)
        d.mode = .km
        d.targetMileage = 90_000
        XCTAssertEqual(d.modeRaw, "km")
    }

    func testDeadlineDocumentsCascade() throws {
        let ctx = try T.makeContext()
        let d = Deadline(label: "Pneus", dueDate: .now, repeatsYearly: false)
        ctx.insert(d)
        let doc = StoredDocument(fileName: "x.pdf", originalName: "devis.pdf", kind: .pdf)
        ctx.insert(doc)
        doc.deadline = d
        try ctx.save()
        XCTAssertEqual(d.documents.count, 1)
        ctx.delete(d)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<StoredDocument>()), 0)
    }

    func testOpensV10AndV11Fixtures() throws {
        for name in ["v1_0", "v1_1"] {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }
            let store = try T.copyFixture(name, to: tmp)
            let container = try ModelContainer(for: Schema(SchemaModels.all), configurations: ModelConfiguration(url: store))
            let ctx = ModelContext(container)
            XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Car>()), 1, name)
            for d in try ctx.fetch(FetchDescriptor<Deadline>()) {
                XCTAssertEqual(d.mode, .date, name)
                XCTAssertNil(d.targetMileage, name)
            }
            for i in try ctx.fetch(FetchDescriptor<Intervention>()) {
                XCTAssertEqual(i.operations, [], name)
            }
        }
    }
}

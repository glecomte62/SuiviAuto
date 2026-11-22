import XCTest
import SwiftData
@testable import SuiviAuto

final class DeletionServiceTests: XCTestCase {
    var root: URL!
    var store: DocumentStore!
    var ctx: ModelContext!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = DocumentStore(directory: root.appendingPathComponent("Documents"))
        ctx = try T.makeContext()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeCarWithDocument() throws -> (Car, Intervention, StoredDocument) {
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        ctx.insert(i); i.car = car
        let src = root.appendingPathComponent("f.pdf")
        try Data("x".utf8).write(to: src)
        let doc = try store.importFile(at: src)
        ctx.insert(doc); doc.intervention = i
        try ctx.save()
        return (car, i, doc)
    }

    func testDeleteCarRemovesFiles() throws {
        let (car, _, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(car, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Car>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<StoredDocument>()), 0)
    }

    func testDeleteInterventionRemovesFiles() throws {
        let (car, i, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(i, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(car.interventions.count, 0)
    }

    func testDeleteSingleDocument() throws {
        let (_, i, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(doc, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(i.documents.count, 0)
    }

    func testDeleteRecordRemovesPlainModel() throws {
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let d = Deadline(label: "Assurance", dueDate: T.date("2027-01-01"), repeatsYearly: true)
        ctx.insert(d); d.car = car
        try ctx.save()
        try DeletionService.deleteRecord(d, in: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Deadline>()), 0)
        XCTAssertEqual(car.deadlines.count, 0)
    }

    func testSaveOrRollbackPersistsChanges() throws {
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        try DeletionService.saveOrRollback(ctx)
        XCTAssertFalse(ctx.hasChanges)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Car>()), 1)
    }

    func testDeleteRuleUnlinksInterventions() throws {
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let rule = MaintenanceRule(key: "vidange", label: "Vidange", intervalKm: 15_000, intervalMonths: 12)
        ctx.insert(rule); rule.car = car
        let linked = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        ctx.insert(linked); linked.car = car; linked.ruleKey = "vidange"
        let other = Intervention(date: T.date("2026-02-01"), mileage: 2, kind: .entretien)
        ctx.insert(other); other.car = car; other.ruleKey = "courroie"
        try ctx.save()

        XCTAssertEqual(DeletionService.linkedInterventions(of: rule).count, 1)
        try DeletionService.delete(rule, in: ctx)
        XCTAssertNil(linked.ruleKey)
        XCTAssertEqual(other.ruleKey, "courroie")
        XCTAssertEqual(car.rules.count, 0)
        XCTAssertFalse(ctx.hasChanges)
    }
}

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
}

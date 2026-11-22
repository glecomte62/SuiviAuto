import XCTest
import SwiftData
@testable import SuiviAuto

final class BackupServiceTests: XCTestCase {
    var root: URL!
    var base: URL!
    var pending: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        base = root.appendingPathComponent("SuiviAuto")
        pending = root.appendingPathComponent("SuiviAuto-PendingRestore")
        try fm.createDirectory(at: base.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try Data("store-v1".utf8).write(to: base.appendingPathComponent("SuiviAuto.store"))
        try Data("pdf".utf8).write(to: base.appendingPathComponent("Documents/a.pdf"))
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    func read(_ url: URL) throws -> String { String(decoding: try Data(contentsOf: url), as: UTF8.self) }

    func testExportStageAndApplyRoundTrip() throws {
        let zip = root.appendingPathComponent("sauvegarde.zip")
        try BackupService.exportBackup(to: zip, base: base)
        XCTAssertTrue(fm.fileExists(atPath: zip.path))

        // les données changent après la sauvegarde
        try Data("store-v2".utf8).write(to: base.appendingPathComponent("SuiviAuto.store"))

        try BackupService.stageRestore(from: zip, pending: pending)
        XCTAssertTrue(fm.fileExists(atPath: pending.appendingPathComponent("SuiviAuto.store").path))

        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending)
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(base.appendingPathComponent("Documents/a.pdf")), "pdf")
        XCTAssertFalse(fm.fileExists(atPath: pending.path))

        let previous = root.appendingPathComponent("SuiviAuto-avant-restauration/SuiviAuto.store")
        XCTAssertEqual(try read(previous), "store-v2")
    }

    func testApplyWithoutPendingDoesNothing() throws {
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending)
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
    }

    func testStageRejectsInvalidArchive() throws {
        let other = root.appendingPathComponent("Autre")
        try fm.createDirectory(at: other, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: other.appendingPathComponent("x.txt"))
        let zip = root.appendingPathComponent("invalide.zip")
        try BackupService.exportBackup(to: zip, base: other)
        XCTAssertThrowsError(try BackupService.stageRestore(from: zip, pending: pending)) {
            XCTAssertEqual($0 as? BackupService.BackupError, .invalidArchive)
        }
    }

    func testCSV() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio; rouge", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-03-05"), mileage: 45_000, kind: .entretien, title: "Vidange \"complète\"")
        i.garage = "Garage du Nord"
        i.amountCents = 18_990
        ctx.insert(i); i.car = car
        let q = Intervention(date: T.date("2026-04-01"), mileage: 46_000, kind: .pneus, status: .devis)
        ctx.insert(q); q.car = car
        try ctx.save()

        let csv = BackupService.csv(for: [q, i], calendar: T.calendar)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        let lines = csv.dropFirst().components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "Voiture;Date;Km;Type;Titre;Garage;Montant;Statut")
        XCTAssertEqual(lines[1], "\"Clio; rouge\";05/03/2026;45000;Entretien;\"Vidange \"\"complète\"\"\";Garage du Nord;189,90;Facture")
        XCTAssertEqual(lines[2], "\"Clio; rouge\";01/04/2026;46000;Pneus;Pneus;;;Devis")
    }
}

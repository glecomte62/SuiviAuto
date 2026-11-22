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

        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: localDate(2026, 3, 5, 14, 7, 9))
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(base.appendingPathComponent("Documents/a.pdf")), "pdf")
        XCTAssertFalse(fm.fileExists(atPath: pending.path))

        let previous = root.appendingPathComponent("SuiviAuto-avant-restauration-20260305-140709/SuiviAuto.store")
        XCTAssertEqual(try read(previous), "store-v2")
    }

    /// Date dans le fuseau local (celui du DateFormatter de BackupService).
    func localDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    func makePending(_ content: String) throws {
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        try Data(content.utf8).write(to: pending.appendingPathComponent("SuiviAuto.store"))
    }

    func testSafetyCopiesArePreservedAcrossRestores() throws {
        try makePending("restore-1")
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: localDate(2026, 3, 5, 10, 0, 0))
        try makePending("restore-2")
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: localDate(2026, 3, 6, 10, 0, 0))

        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "restore-2")
        XCTAssertEqual(try read(root.appendingPathComponent("SuiviAuto-avant-restauration-20260305-100000/SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(root.appendingPathComponent("SuiviAuto-avant-restauration-20260306-100000/SuiviAuto.store")), "restore-1")
    }

    func testSafetyCopyWithSameTimestampIsNotOverwritten() throws {
        let now = localDate(2026, 3, 5, 10, 0, 0)
        try makePending("restore-1")
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: now)
        try makePending("restore-2")
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: now)

        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "restore-2")
        XCTAssertEqual(try read(root.appendingPathComponent("SuiviAuto-avant-restauration-20260305-100000/SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(root.appendingPathComponent("SuiviAuto-avant-restauration-20260305-100000-2/SuiviAuto.store")), "restore-1")
    }

    func testFailedRestoreRollsBackCurrentData() throws {
        struct Boom: Error {}
        try makePending("restore-1")
        var calls = 0
        let move: (URL, URL) throws -> Void = { src, dst in
            calls += 1
            if calls == 2 { throw Boom() } // pending → base
            try FileManager.default.moveItem(at: src, to: dst)
        }
        XCTAssertThrowsError(try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, moveItem: move)) {
            XCTAssertTrue($0 is Boom)
        }
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(base.appendingPathComponent("Documents/a.pdf")), "pdf")
        XCTAssertEqual(try read(pending.appendingPathComponent("SuiviAuto.store")), "restore-1")
        let leftovers = try fm.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("SuiviAuto-avant-restauration") }
        XCTAssertEqual(leftovers, [])
    }

    func testExportDoesNotDestroyExistingZipOnFailure() throws {
        // destination dans un dossier inexistant : l'export échoue sans rien créer
        let zip = root.appendingPathComponent("absent/sauvegarde.zip")
        XCTAssertThrowsError(try BackupService.exportBackup(to: zip, base: base))
        // destination existante : remplacée par une archive valide
        let existing = root.appendingPathComponent("existante.zip")
        try Data("ancienne".utf8).write(to: existing)
        try BackupService.exportBackup(to: existing, base: base)
        try BackupService.stageRestore(from: existing, pending: pending)
        XCTAssertEqual(try read(pending.appendingPathComponent("SuiviAuto.store")), "store-v1")
    }

    @MainActor
    func testExportLiveSQLiteStoreRoundTrip() throws {
        let storeURL = base.appendingPathComponent("SuiviAuto.store")
        try fm.removeItem(at: storeURL)
        let container = try ModelContainer(for: Schema(SchemaModels.all),
                                           configurations: ModelConfiguration(url: storeURL))
        let ctx = ModelContext(container)
        ctx.insert(Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01")))
        try ctx.save()

        // export pendant que le conteneur est ouvert (WAL non fusionné)
        let zip = root.appendingPathComponent("live.zip")
        try BackupService.exportBackup(to: zip, base: base)

        let otherRoot = root.appendingPathComponent("autre")
        let otherBase = otherRoot.appendingPathComponent("SuiviAuto")
        let otherPending = otherRoot.appendingPathComponent("SuiviAuto-PendingRestore")
        try fm.createDirectory(at: otherRoot, withIntermediateDirectories: true)
        try BackupService.stageRestore(from: zip, pending: otherPending)
        try BackupService.applyPendingRestoreIfNeeded(base: otherBase, pending: otherPending)
        XCTAssertEqual(try read(otherBase.appendingPathComponent("Documents/a.pdf")), "pdf")

        let restored = try ModelContainer(for: Schema(SchemaModels.all),
                                          configurations: ModelConfiguration(url: otherBase.appendingPathComponent("SuiviAuto.store")))
        let cars = try ModelContext(restored).fetch(FetchDescriptor<Car>())
        XCTAssertEqual(cars.map(\.name), ["Clio"])
        _ = container
    }

    func testQuarantinePendingRestore() throws {
        try makePending("cassée")
        let moved = try XCTUnwrap(BackupService.quarantinePendingRestore(pending: pending, now: localDate(2026, 3, 5, 10, 0, 0)))
        XCTAssertEqual(moved.lastPathComponent, "SuiviAuto-PendingRestore-echec-20260305-100000")
        XCTAssertFalse(fm.fileExists(atPath: pending.path))
        XCTAssertEqual(try read(moved.appendingPathComponent("SuiviAuto.store")), "cassée")
    }

    func testQuarantineWithoutPendingReturnsNil() {
        XCTAssertNil(BackupService.quarantinePendingRestore(pending: pending))
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

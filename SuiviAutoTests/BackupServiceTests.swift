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

    /// Crée une vraie base SwiftData contenant une voiture ; le conteneur est libéré au retour.
    func makeRealStore(at storeURL: URL, carName: String) throws {
        for suffix in ["", "-wal", "-shm"] { try? fm.removeItem(atPath: storeURL.path + suffix) }
        try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: storeURL))
            let ctx = ModelContext(container)
            ctx.insert(Car(name: carName, firstRegistrationDate: T.date("2020-01-01")))
            try ctx.save()
        }
    }

    func carNames(in storeURL: URL) throws -> [String] {
        try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: storeURL))
            return try ModelContext(container).fetch(FetchDescriptor<Car>()).map(\.name)
        }
    }

    func testExportStageAndApplyRoundTrip() throws {
        let store = base.appendingPathComponent("SuiviAuto.store")
        try makeRealStore(at: store, carName: "Clio")
        let zip = root.appendingPathComponent("sauvegarde.zip")
        try BackupService.exportBackup(to: zip, base: base)
        XCTAssertTrue(fm.fileExists(atPath: zip.path))

        // les données changent après la sauvegarde
        try makeRealStore(at: store, carName: "Mégane")

        try BackupService.stageRestore(from: zip, pending: pending)
        XCTAssertTrue(fm.fileExists(atPath: pending.appendingPathComponent("SuiviAuto.store").path))

        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending, now: localDate(2026, 3, 5, 14, 7, 9))
        XCTAssertEqual(try carNames(in: store), ["Clio"])
        XCTAssertEqual(try read(base.appendingPathComponent("Documents/a.pdf")), "pdf")
        XCTAssertFalse(fm.fileExists(atPath: pending.path))

        let previous = root.appendingPathComponent("SuiviAuto-avant-restauration-20260305-140709/SuiviAuto.store")
        XCTAssertEqual(try carNames(in: previous), ["Mégane"])
    }

    /// Une sauvegarde .zip faite en 1.0 doit se restaurer en 1.1.
    func testStageRestoreAcceptsVersion10Backup() throws {
        let oldRoot = root.appendingPathComponent("v1_0")
        let oldBase = oldRoot.appendingPathComponent("SuiviAuto")
        try T.copyV10Fixture(to: oldBase)
        let zip = root.appendingPathComponent("sauvegarde-1.0.zip")
        try BackupService.exportBackup(to: zip, base: oldBase)

        try BackupService.stageRestore(from: zip, pending: pending)
        let staged = pending.appendingPathComponent("SuiviAuto.store")
        let count = try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all), configurations: ModelConfiguration(url: staged))
            return try ModelContext(container).fetchCount(FetchDescriptor<Intervention>())
        }
        XCTAssertEqual(count, 5)
    }

    /// Une sauvegarde .zip faite en 1.1 (garages, contacts) doit se restaurer en 2.0.
    func testStageRestoreAcceptsVersion11Backup() throws {
        let oldBase = root.appendingPathComponent("v1_1").appendingPathComponent("SuiviAuto")
        try T.copyFixture("v1_1", to: oldBase)
        let zip = root.appendingPathComponent("sauvegarde-1.1.zip")
        try BackupService.exportBackup(to: zip, base: oldBase)

        try BackupService.stageRestore(from: zip, pending: pending)
        let staged = pending.appendingPathComponent("SuiviAuto.store")
        let counts = try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all), configurations: ModelConfiguration(url: staged))
            let ctx = ModelContext(container)
            return [try ctx.fetchCount(FetchDescriptor<Intervention>()),
                    try ctx.fetchCount(FetchDescriptor<Garage>()),
                    try ctx.fetchCount(FetchDescriptor<GarageContact>()),
                    try ctx.fetchCount(FetchDescriptor<Deadline>())]
        }
        XCTAssertEqual(counts, [3, 1, 1, 2])
    }

    func testStageRejectsUnreadableStore() throws {
        // base de setUp : « SuiviAuto.store » est un fichier texte, pas une base SQLite
        let zip = root.appendingPathComponent("corrompue.zip")
        try BackupService.exportBackup(to: zip, base: base)
        XCTAssertThrowsError(try BackupService.stageRestore(from: zip, pending: pending)) {
            XCTAssertEqual($0 as? BackupService.BackupError, .unreadableStore)
        }
        XCTAssertFalse(fm.fileExists(atPath: pending.path))
    }

    func testStageRejectionKeepsExistingPending() throws {
        try makePending("précédente")
        let zip = root.appendingPathComponent("corrompue.zip")
        try BackupService.exportBackup(to: zip, base: base)
        XCTAssertThrowsError(try BackupService.stageRestore(from: zip, pending: pending))
        XCTAssertEqual(try read(pending.appendingPathComponent("SuiviAuto.store")), "précédente")
    }

    func testLatestSafetyCopy() throws {
        XCTAssertNil(BackupService.latestSafetyCopy(in: root))
        for name in ["SuiviAuto-avant-restauration-20260305-100000",
                     "SuiviAuto-avant-restauration-20260306-090000",
                     "SuiviAuto-avant-restauration-20260306-090000-2",
                     "SuiviAuto-PendingRestore-echec-20260307-100000"] {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        XCTAssertEqual(BackupService.latestSafetyCopy(in: root)?.lastPathComponent,
                       "SuiviAuto-avant-restauration-20260306-090000-2")
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
        try makeRealStore(at: base.appendingPathComponent("SuiviAuto.store"), carName: "Clio")
        let existing = root.appendingPathComponent("existante.zip")
        try Data("ancienne".utf8).write(to: existing)
        try BackupService.exportBackup(to: existing, base: base)
        try BackupService.stageRestore(from: existing, pending: pending)
        XCTAssertEqual(try carNames(in: pending.appendingPathComponent("SuiviAuto.store")), ["Clio"])
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

    func testCSVUsesLinkedGarageName() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let g = Garage(name: "Garage du Nord")
        ctx.insert(g)
        let i = Intervention(date: T.date("2026-03-05"), mileage: 45_000, kind: .entretien, title: "Vidange")
        i.garage = "ancien texte"
        ctx.insert(i)
        i.car = car
        i.garageRef = g
        try ctx.save()

        let lines = BackupService.csv(for: [i], calendar: T.calendar).dropFirst().components(separatedBy: "\r\n")
        XCTAssertEqual(lines[1], "Clio;05/03/2026;45000;Entretien;Vidange;Garage du Nord;;Facture")
    }
}

import SwiftData
import XCTest
@testable import SuiviAuto

final class UpgradeBackupTests: XCTestCase {
    var root: URL!
    var base: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        base = root.appendingPathComponent("SuiviAuto")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    func localDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    func testCopiesVersion10StoreBeforeMigration() throws {
        let store = try T.copyV10Fixture(to: base)
        let support = base.appendingPathComponent(".SuiviAuto_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try Data("blob".utf8).write(to: support.appendingPathComponent("x"))

        let copy = try XCTUnwrap(UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: localDate(2026, 11, 22, 9, 5, 7), version: "1.1"))

        XCTAssertEqual(copy.deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(copy.lastPathComponent, "SuiviAuto-avant-1.1-20261122-090507")
        XCTAssertFalse(fm.fileExists(atPath: copy.appendingPathComponent("Documents").path))
        XCTAssertEqual(try Data(contentsOf: copy.appendingPathComponent(".SuiviAuto_SUPPORT/_EXTERNAL_DATA/x")), Data("blob".utf8))

        // la copie est une base 1.0 intacte (pas encore migrée) qui s'ouvre
        let copiedStore = copy.appendingPathComponent("SuiviAuto.store")
        XCTAssertFalse(try UpgradeBackup.isCompatibleWithCurrentModel(storeURL: copiedStore))
        try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: copiedStore))
            XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Intervention>()), 5)
        }
        // l'original n'est pas touché
        XCTAssertFalse(try UpgradeBackup.isCompatibleWithCurrentModel(storeURL: store))
    }

    func testFolderNameUsesAppVersion() throws {
        XCTExpectFailure("passe après la Task 2")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try T.copyFixture("v1_1", to: tmp.appendingPathComponent("SuiviAuto"))
        let copy = try XCTUnwrap(try UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: T.date("2026-11-23"), version: "2.0"))
        XCTAssertTrue(copy.lastPathComponent.hasPrefix("SuiviAuto-avant-2.0-"), copy.lastPathComponent)
    }

    func testSecondCopyWithSameTimestampDoesNotOverwrite() throws {
        let store = try T.copyV10Fixture(to: base)
        let now = localDate(2026, 11, 22, 9, 5, 7)
        let first = try XCTUnwrap(UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: now, version: "1.1"))
        let second = try XCTUnwrap(UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: now, version: "1.1"))
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "SuiviAuto-avant-1.1-20261122-090507-2")
    }

    func testCurrentSchemaStoreNeedsNoCopy() throws {
        let store = base.appendingPathComponent("SuiviAuto.store")
        try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: store))
            let ctx = ModelContext(container)
            ctx.insert(Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01")))
            try ctx.save()
        }
        XCTAssertNil(try UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: .now))
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["SuiviAuto"])
    }

    func testMigratedFixtureNeedsNoCopy() throws {
        let store = try T.copyV10Fixture(to: base)
        try autoreleasepool {
            let container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: store))
            _ = try ModelContext(container).fetchCount(FetchDescriptor<Car>())
        }
        XCTAssertNil(try UpgradeBackup.backupIfNeedsMigration(storeURL: store, now: .now))
    }

    func testNoStoreNeedsNoCopy() throws {
        XCTAssertNil(try UpgradeBackup.backupIfNeedsMigration(storeURL: base.appendingPathComponent("SuiviAuto.store"), now: .now))
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["SuiviAuto"])
    }

    func testLatestSafetyCopyConsidersBothKinds() throws {
        for name in ["SuiviAuto-avant-restauration-20261120-100000",
                     "SuiviAuto-avant-1.1-20261121-080000",
                     "SuiviAuto-avant-restauration-20261121-070000"] {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        XCTAssertEqual(BackupService.latestSafetyCopy(in: root)?.lastPathComponent, "SuiviAuto-avant-1.1-20261121-080000")

        try fm.createDirectory(at: root.appendingPathComponent("SuiviAuto-avant-restauration-20261122-070000"),
                               withIntermediateDirectories: true)
        XCTAssertEqual(BackupService.latestSafetyCopy(in: root)?.lastPathComponent,
                       "SuiviAuto-avant-restauration-20261122-070000")
    }
}

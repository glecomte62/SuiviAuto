import Foundation
import SwiftData
@testable import SuiviAuto

/// Outils de test : calendrier UTC fixe et fabrication de dates.
enum T {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "fr_FR")
        return c
    }()

    /// `T.date("2026-03-01")` ou `T.date("2026-03-01", hour: 9)`
    static func date(_ s: String, hour: Int = 0) -> Date {
        let p = s.split(separator: "-").map { Int($0)! }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
    }
}

extension T {
    /// Contexte SwiftData en mémoire, isolé pour chaque test.
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(SchemaModels.all),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}

extension T {
    /// Copie la base 1.0 de référence (fichiers `SuiviAuto.store*` uniquement) dans `directory`.
    /// Échoue si le fichier versionné est absent ou n'est pas une vraie base SQLite (ex. emplacement iCloud non téléchargé).
    @discardableResult
    static func copyV10Fixture(to directory: URL) throws -> URL {
        let fm = FileManager.default
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/v1_0", isDirectory: true)
        let store = fixture.appendingPathComponent("SuiviAuto.store")
        guard fm.fileExists(atPath: store.path) else { throw FixtureError.missing(store.path) }
        let header = try FileHandle(forReadingFrom: store).read(upToCount: 16) ?? Data()
        guard header == Data("SQLite format 3\u{0}".utf8) else { throw FixtureError.notSQLite(store.path) }

        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in try fm.contentsOfDirectory(atPath: fixture.path) where name.hasPrefix("SuiviAuto.store") {
            try fm.copyItem(at: fixture.appendingPathComponent(name), to: directory.appendingPathComponent(name))
        }
        return directory.appendingPathComponent("SuiviAuto.store")
    }

    enum FixtureError: Error {
        case missing(String)
        case notSQLite(String)
    }
}

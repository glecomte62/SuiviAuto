import Foundation

/// Emplacements disque de l'application (hors iCloud).
enum AppPaths {
    static let baseURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SuiviAuto", isDirectory: true)

    static var storeURL: URL { baseURL.appendingPathComponent("SuiviAuto.store") }
    static var documentsURL: URL { baseURL.appendingPathComponent("Documents", isDirectory: true) }

    /// Dossier où une sauvegarde importée attend d'être appliquée au prochain lancement.
    static var pendingRestoreURL: URL {
        baseURL.deletingLastPathComponent().appendingPathComponent("SuiviAuto-PendingRestore", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }
}

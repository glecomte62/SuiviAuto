import AppKit
import CoreData
import Foundation

enum BackupService {
    enum BackupError: LocalizedError, Equatable {
        case dittoFailed(Int32)
        case invalidArchive
        var errorDescription: String? {
            switch self {
            case .dittoFailed(let code): "La compression a échoué (code \(code))."
            case .invalidArchive: "Cette archive n'est pas une sauvegarde SuiviAuto."
            }
        }
    }

    private static func ditto(_ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw BackupError.dittoFailed(p.terminationStatus) }
    }

    /// Zippe une copie cohérente de la base (SQLite + Documents) sous un dossier racine « SuiviAuto ».
    /// L'appelant doit avoir fait `context.save()` avant. Une archive existante n'est remplacée qu'en cas de succès.
    static func exportBackup(to zipURL: URL, base: URL = AppPaths.baseURL) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let staging = temp.appendingPathComponent("SuiviAuto")
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        try copyStore(from: base.appendingPathComponent("SuiviAuto.store"),
                      to: staging.appendingPathComponent("SuiviAuto.store"))
        let documents = base.appendingPathComponent("Documents")
        if fm.fileExists(atPath: documents.path) {
            try fm.copyItem(at: documents, to: staging.appendingPathComponent("Documents"))
        }

        let tempZip = temp.appendingPathComponent("sauvegarde.zip")
        try ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", staging.path, tempZip.path])

        // Copie à côté de la destination (même volume), puis remplacement atomique.
        let sibling = zipURL.deletingLastPathComponent()
            .appendingPathComponent(".\(zipURL.lastPathComponent).\(UUID().uuidString).tmp")
        try fm.copyItem(at: tempZip, to: sibling)
        do {
            if fm.fileExists(atPath: zipURL.path) {
                _ = try fm.replaceItemAt(zipURL, withItemAt: sibling)
            } else {
                try fm.moveItem(at: sibling, to: zipURL)
            }
        } catch {
            try? fm.removeItem(at: sibling)
            throw error
        }
    }

    /// Copie cohérente d'un store SQLite ouvert (WAL inclus) ; copie simple sinon (fichier non SQLite, tests).
    private static func copyStore(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        if isSQLite(source) {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try coordinator.replacePersistentStore(at: destination, destinationOptions: nil,
                                                   withPersistentStoreFrom: source, sourceOptions: nil, type: .sqlite)
        } else {
            for suffix in ["", "-wal", "-shm"] {
                let src = URL(fileURLWithPath: source.path + suffix)
                guard fm.fileExists(atPath: src.path) else { continue }
                try fm.copyItem(at: src, to: URL(fileURLWithPath: destination.path + suffix))
            }
        }
    }

    private static func isSQLite(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 16)) ?? Data()
        return header == Data("SQLite format 3\u{0}".utf8)
    }

    /// Décompresse l'archive dans `pending`. Elle sera appliquée au prochain lancement.
    static func stageRestore(from zipURL: URL, pending: URL = AppPaths.pendingRestoreURL) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        try ditto(["-x", "-k", zipURL.path, temp.path])
        let extracted = temp.appendingPathComponent("SuiviAuto")
        guard fm.fileExists(atPath: extracted.appendingPathComponent("SuiviAuto.store").path) else {
            throw BackupError.invalidArchive
        }
        if fm.fileExists(atPath: pending.path) { try fm.removeItem(at: pending) }
        try fm.moveItem(at: extracted, to: pending)
    }

    static func timestamp(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss"
        return df.string(from: date)
    }

    /// Premier chemin libre « <prefix> », « <prefix>-2 », … dans `directory`.
    private static func freeURL(in directory: URL, prefix: String) -> URL {
        var url = directory.appendingPathComponent(prefix)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(prefix)-\(n)")
            n += 1
        }
        return url
    }

    /// À appeler au lancement, AVANT d'ouvrir le ModelContainer.
    /// Les données actuelles sont conservées dans « SuiviAuto-avant-restauration-<date> » (jamais supprimées).
    /// Si la mise en place échoue, les données actuelles sont remises en place avant de relancer l'erreur.
    static func applyPendingRestoreIfNeeded(base: URL = AppPaths.baseURL, pending: URL = AppPaths.pendingRestoreURL,
                                            now: Date = .now,
                                            moveItem: (URL, URL) throws -> Void = FileManager.default.moveItem) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pending.path) else { return }
        var previous: URL?
        if fm.fileExists(atPath: base.path) {
            let url = freeURL(in: base.deletingLastPathComponent(),
                              prefix: "SuiviAuto-avant-restauration-\(timestamp(now))")
            try moveItem(base, url)
            previous = url
        }
        do {
            try moveItem(pending, base)
        } catch {
            if let previous { try? moveItem(previous, base) }
            throw error
        }
    }

    /// Après un échec de restauration : met le dossier en attente de côté (sans le supprimer)
    /// pour que le prochain lancement ne réessaie pas. Renvoie son nouvel emplacement.
    @discardableResult
    static func quarantinePendingRestore(pending: URL = AppPaths.pendingRestoreURL, now: Date = .now) -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pending.path) else { return nil }
        let url = freeURL(in: pending.deletingLastPathComponent(),
                          prefix: "\(pending.lastPathComponent)-echec-\(timestamp(now))")
        do { try fm.moveItem(at: pending, to: url) } catch { return nil }
        return url
    }

    /// Relance l'application : un shell détaché attend la fin du processus actuel puis rouvre l'app.
    @MainActor
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                       Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier)]
        try? p.run()
        NSApp.terminate(nil)
    }

    /// CSV pour Excel en français : séparateur « ; », UTF-8 avec BOM, fins de ligne CRLF.
    static func csv(for interventions: [Intervention], calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "dd/MM/yyyy"

        func field(_ s: String) -> String {
            guard s.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        let sorted = interventions.sorted {
            ($0.car?.name ?? "", $0.date) < ($1.car?.name ?? "", $1.date)
        }
        let rows = sorted.map { i in
            [
                field(i.car?.name ?? ""),
                df.string(from: i.date),
                String(i.mileage),
                field(i.kind.label),
                field(i.displayTitle),
                field(i.garage),
                i.amountCents.map(Money.editString(cents:)) ?? "",
                i.status.label,
            ].joined(separator: ";")
        }
        let header = "Voiture;Date;Km;Type;Titre;Garage;Montant;Statut"
        return "\u{FEFF}" + ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }
}

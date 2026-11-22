import AppKit
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

    /// Zippe le dossier `base` (base + Documents). L'appelant doit avoir fait `context.save()` avant.
    static func exportBackup(to zipURL: URL, base: URL = AppPaths.baseURL) throws {
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", base.path, zipURL.path])
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

    /// À appeler au lancement, AVANT d'ouvrir le ModelContainer.
    /// Les données actuelles sont conservées dans « SuiviAuto-avant-restauration ».
    static func applyPendingRestoreIfNeeded(base: URL = AppPaths.baseURL, pending: URL = AppPaths.pendingRestoreURL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pending.path) else { return }
        if fm.fileExists(atPath: base.path) {
            let previous = base.deletingLastPathComponent().appendingPathComponent("SuiviAuto-avant-restauration")
            if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
            try fm.moveItem(at: base, to: previous)
        }
        try fm.moveItem(at: pending, to: base)
    }

    /// Relance l'application : un shell détaché attend 1 s puis rouvre l'app, qui se termine aussitôt.
    @MainActor
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
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

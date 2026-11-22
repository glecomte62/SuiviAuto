import CoreData
import Foundation
import SwiftData

/// Copie de sécurité faite au premier lancement d'une version dont le schéma diffère de la base existante
/// (ex. 1.0 → 1.1), AVANT que SwiftData ne migre la base. Les documents ne sont pas copiés :
/// la migration ne les modifie pas.
enum UpgradeBackup {
    static let folderPrefix = "SuiviAuto-avant-1.1-"

    /// Modèle Core Data équivalent au schéma SwiftData actuel.
    private static let currentModel: NSManagedObjectModel? =
        NSManagedObjectModel.makeManagedObjectModel(for: SchemaModels.all)

    /// Entités attendues (repli si le modèle n'a pas pu être construit).
    private static var expectedEntityNames: Set<String> {
        Set(SchemaModels.all.map { String(describing: $0) })
    }

    /// Vrai si la base peut être ouverte telle quelle par le schéma actuel (aucune migration).
    static func isCompatibleWithCurrentModel(storeURL: URL) throws -> Bool {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
        if let model = currentModel {
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Any] ?? [:]
        return expectedEntityNames.isSubset(of: Set(hashes.keys))
    }

    /// Si la base existe et va être migrée, la copie (de façon cohérente) avec son dossier de données externes
    /// dans « SuiviAuto-avant-1.1-<date> », à côté du dossier de l'app. Renvoie le dossier créé, ou nil si rien à faire.
    @discardableResult
    static func backupIfNeedsMigration(storeURL: URL = AppPaths.storeURL, now: Date = .now) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return nil }
        guard try !isCompatibleWithCurrentModel(storeURL: storeURL) else { return nil }

        let baseDir = storeURL.deletingLastPathComponent()
        let folder = BackupService.freeURL(in: baseDir.deletingLastPathComponent(),
                                           prefix: folderPrefix + BackupService.timestamp(now))
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try BackupService.copyStore(from: storeURL, to: folder.appendingPathComponent(storeURL.lastPathComponent))
            let storeName = storeURL.deletingPathExtension().lastPathComponent
            let support = baseDir.appendingPathComponent(".\(storeName)_SUPPORT", isDirectory: true)
            if fm.fileExists(atPath: support.path) {
                // `replacePersistentStore` peut déjà avoir recréé ce dossier : on complète sans écraser.
                try copyMissingItems(from: support, to: folder.appendingPathComponent(support.lastPathComponent))
            }
        } catch {
            try? fm.removeItem(at: folder) // pas de copie partielle trompeuse
            throw error
        }
        return folder
    }

    /// Copie récursive de ce qui manque dans `destination` (les éléments déjà présents sont conservés).
    private static func copyMissingItems(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: destination.path, isDirectory: &isDir) else {
            try fm.copyItem(at: source, to: destination)
            return
        }
        guard isDir.boolValue else { return }
        for name in try fm.contentsOfDirectory(atPath: source.path) {
            var srcIsDir: ObjCBool = false
            let src = source.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path, isDirectory: &srcIsDir) else { continue }
            if srcIsDir.boolValue {
                try copyMissingItems(from: src, to: destination.appendingPathComponent(name))
            } else if !fm.fileExists(atPath: destination.appendingPathComponent(name).path) {
                try fm.copyItem(at: src, to: destination.appendingPathComponent(name))
            }
        }
    }
}

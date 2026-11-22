import CoreData
import Foundation
import SwiftData

/// Copie de sécurité faite au premier lancement d'une version dont le schéma diffère de la base existante
/// (ex. 1.0 → 1.1 → 2.0), AVANT que SwiftData ne migre la base. Les documents ne sont pas copiés :
/// la migration ne les modifie pas.
enum UpgradeBackup {
    static let folderPrefixBase = "SuiviAuto-avant-"

    /// Modèle Core Data équivalent au schéma SwiftData actuel (nil si la construction échoue).
    static let currentModel: NSManagedObjectModel? =
        NSManagedObjectModel.makeManagedObjectModel(for: SchemaModels.all)

    /// Vrai si la base peut être ouverte telle quelle par le schéma actuel (aucune migration).
    /// Comparaison des empreintes de version de chaque entité (`NSStoreModelVersionHashesKey`) avec celles du modèle :
    /// une 1.1 a les mêmes entités qu'une 2.0 mais des attributs différents, donc des empreintes différentes.
    /// Sans modèle, rien ne prouve la compatibilité : on répond « non » pour que la copie de sécurité soit faite.
    static func isCompatibleWithCurrentModel(storeURL: URL, model: NSManagedObjectModel? = currentModel) throws -> Bool {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
        guard let model else { return false }
        return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }

    /// Si la base existe et va être migrée, la copie (de façon cohérente) avec son dossier de données externes
    /// dans « SuiviAuto-avant-<version>-<date> », à côté du dossier de l'app. Renvoie le dossier créé, ou nil si rien à faire.
    @discardableResult
    static func backupIfNeedsMigration(storeURL: URL = AppPaths.storeURL, now: Date = .now,
                                       version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "nouvelle-version",
                                       model: NSManagedObjectModel? = currentModel) throws -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return nil }
        guard try !isCompatibleWithCurrentModel(storeURL: storeURL, model: model) else { return nil }

        let baseDir = storeURL.deletingLastPathComponent()
        let folder = BackupService.freeURL(in: baseDir.deletingLastPathComponent(),
                                           prefix: "\(folderPrefixBase)\(version)-" + BackupService.timestamp(now))
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

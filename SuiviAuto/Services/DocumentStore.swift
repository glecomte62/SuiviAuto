import Foundation

/// Copie et retrouve les fichiers de factures et devis.
struct DocumentStore {
    let directory: URL

    static let shared = DocumentStore(directory: AppPaths.documentsURL)

    enum ImportError: LocalizedError, Equatable {
        case unsupportedFormat(String)
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let name):
                "« \(name) » n'est pas pris en charge. Formats acceptés : PDF, JPEG, PNG, HEIC."
            }
        }
    }

    static let allowedExtensions: [String: DocumentKind] = [
        "pdf": .pdf, "jpg": .image, "jpeg": .image, "png": .image, "heic": .image,
    ]

    /// Copie le fichier sous un nom unique. Le `StoredDocument` retourné n'est pas encore inséré dans un contexte.
    func importFile(at source: URL) throws -> StoredDocument {
        let ext = source.pathExtension.lowercased()
        guard let kind = Self.allowedExtensions[ext] else {
            throw ImportError.unsupportedFormat(source.lastPathComponent)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(fileName))
        return StoredDocument(fileName: fileName, originalName: source.lastPathComponent, kind: kind)
    }

    func url(for document: StoredDocument) -> URL {
        directory.appendingPathComponent(document.fileName)
    }

    func fileExists(for document: StoredDocument) -> Bool {
        FileManager.default.fileExists(atPath: url(for: document).path)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    /// Supprime les fichiers du dossier qu'aucun `StoredDocument` ne référence (copies laissées par un plantage
    /// ou une fermeture forcée pendant un formulaire). Les fichiers de moins de `olderThan` secondes sont gardés :
    /// ils peuvent appartenir à un formulaire encore ouvert. Renvoie les noms supprimés.
    @discardableResult
    func removeOrphans(referenced: Set<String>, olderThan age: TimeInterval = 3600, now: Date = .now) throws -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey,
                                      .attributeModificationDateKey]
        let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys,
                                               options: [.skipsHiddenFiles])
        var deleted: [String] = []
        for url in files where !referenced.contains(url.lastPathComponent) {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            // Une copie garde souvent les dates de l'original : on retient la plus récente (dont le ctime, mis à jour à la copie).
            let dates = [values.creationDate, values.contentModificationDate, values.attributeModificationDate].compactMap { $0 }
            guard let newest = dates.max(), now.timeIntervalSince(newest) > age else { continue }
            if (try? fm.removeItem(at: url)) != nil { deleted.append(url.lastPathComponent) }
        }
        return deleted.sorted()
    }
}

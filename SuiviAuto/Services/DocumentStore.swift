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
}

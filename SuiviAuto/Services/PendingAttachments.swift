import Foundation
import Observation
import SwiftData

/// Pièces jointes ajoutées dans un formulaire avant son enregistrement.
/// Les fichiers sont copiés tout de suite ; `discard()` les supprime si le formulaire est annulé.
@Observable
final class PendingAttachments {
    private(set) var documents: [StoredDocument] = []
    @ObservationIgnored private let store: DocumentStore

    init(store: DocumentStore = .shared) { self.store = store }

    /// Filet de sécurité : un formulaire fermé sans enregistrer ne laisse aucune copie orpheline.
    deinit { documents.forEach { store.delete(fileName: $0.fileName) } }

    var isEmpty: Bool { documents.isEmpty }

    /// Copie les fichiers ; renvoie les messages d'erreur des fichiers refusés.
    @discardableResult
    func add(urls: [URL]) -> [String] {
        var rejected: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do { documents.append(try store.importFile(at: url)) }
            catch { rejected.append(error.localizedDescription) }
        }
        return rejected
    }

    func url(for document: StoredDocument) -> URL { store.url(for: document) }

    func remove(_ document: StoredDocument) {
        documents.removeAll { $0 === document }
        store.delete(fileName: document.fileName)
    }

    /// Insère et relie les documents ; renvoie les noms de fichiers attachés, à passer à `deleteFiles(named:)`
    /// si l'enregistrement qui suit échoue (le rollback retire les documents du contexte, pas les fichiers).
    @discardableResult
    func attach(to intervention: Intervention, in context: ModelContext) -> [String] {
        let names = documents.map(\.fileName)
        for doc in documents { context.insert(doc); doc.intervention = intervention }
        documents = []
        return names
    }

    @discardableResult
    func attach(to deadline: Deadline, in context: ModelContext) -> [String] {
        let names = documents.map(\.fileName)
        for doc in documents { context.insert(doc); doc.deadline = deadline }
        documents = []
        return names
    }

    func deleteFiles(named names: [String]) {
        names.forEach(store.delete(fileName:))
    }

    func discard() {
        documents.forEach { store.delete(fileName: $0.fileName) }
        documents = []
    }
}

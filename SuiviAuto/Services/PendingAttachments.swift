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

    /// Description d'un document en attente, indépendante du contexte SwiftData.
    struct Snapshot: Equatable {
        let fileName: String
        let originalName: String
        let kind: DocumentKind
        let addedAt: Date
    }

    /// Insère et relie les documents ; renvoie leur description, à passer à `restore(_:)` si l'enregistrement
    /// qui suit échoue (le rollback retire du contexte les documents insérés, mais leurs fichiers restent).
    @discardableResult
    func attach(to intervention: Intervention, in context: ModelContext) -> [Snapshot] {
        attach(in: context) { $0.intervention = intervention }
    }

    @discardableResult
    func attach(to deadline: Deadline, in context: ModelContext) -> [Snapshot] {
        attach(in: context) { $0.deadline = deadline }
    }

    private func attach(in context: ModelContext, link: (StoredDocument) -> Void) -> [Snapshot] {
        let snapshot = documents.map {
            Snapshot(fileName: $0.fileName, originalName: $0.originalName, kind: $0.kind, addedAt: $0.addedAt)
        }
        for doc in documents { context.insert(doc); link(doc) }
        documents = []
        return snapshot
    }

    /// Après un enregistrement manqué : remet les documents en attente (objets neufs, fichiers inchangés).
    func restore(_ snapshot: [Snapshot]) {
        documents.append(contentsOf: snapshot.map {
            StoredDocument(fileName: $0.fileName, originalName: $0.originalName, kind: $0.kind, addedAt: $0.addedAt)
        })
    }

    func discard() {
        documents.forEach { store.delete(fileName: $0.fileName) }
        documents = []
    }
}

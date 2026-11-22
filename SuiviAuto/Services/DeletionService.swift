import Foundation
import SwiftData

/// Suppression des objets ET des fichiers associés sur le disque.
enum DeletionService {
    static func delete(_ car: Car, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = car.interventions.flatMap { $0.documents.map(\.fileName) }
        context.delete(car)
        try saveOrRollback(context)
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ intervention: Intervention, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = intervention.documents.map(\.fileName)
        context.delete(intervention)
        try saveOrRollback(context)
        names.forEach(store.delete(fileName:))
    }

    /// En cas d'échec, annule les suppressions en attente pour ne pas laisser le contexte incohérent.
    private static func saveOrRollback(_ context: ModelContext) throws {
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }

    static func delete(_ document: StoredDocument, in context: ModelContext, store: DocumentStore = .shared) throws {
        let name = document.fileName
        context.delete(document)
        try saveOrRollback(context)
        store.delete(fileName: name)
    }
}

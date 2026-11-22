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

    /// Enregistre ; en cas d'échec, annule toutes les modifications en attente pour ne pas laisser le contexte incohérent.
    static func saveOrRollback(_ context: ModelContext) throws {
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }

    /// Suppression d'un objet sans fichier associé (relevé, règle, échéance).
    /// Nom distinct des surcharges ci-dessus pour ne jamais court-circuiter la suppression des fichiers.
    static func deleteRecord(_ model: some PersistentModel, in context: ModelContext) throws {
        context.delete(model)
        try saveOrRollback(context)
    }

    static func delete(_ document: StoredDocument, in context: ModelContext, store: DocumentStore = .shared) throws {
        let name = document.fileName
        context.delete(document)
        try saveOrRollback(context)
        store.delete(fileName: name)
    }
}

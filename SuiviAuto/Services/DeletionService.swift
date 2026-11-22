import Foundation
import SwiftData

/// Suppression des objets ET des fichiers associés sur le disque.
enum DeletionService {
    static func delete(_ car: Car, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = car.interventions.flatMap { $0.documents.map(\.fileName) }
            + car.deadlines.flatMap { $0.documents.map(\.fileName) }
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

    static func delete(_ deadline: Deadline, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = deadline.documents.map(\.fileName)
        context.delete(deadline)
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

    /// Suppression d'un objet sans fichier associé (relevé, règle).
    /// Nom distinct des surcharges ci-dessus pour ne jamais court-circuiter la suppression des fichiers.
    static func deleteRecord(_ model: some PersistentModel, in context: ModelContext) throws {
        context.delete(model)
        try saveOrRollback(context)
    }

    /// Interventions de la même voiture rattachées à cette règle.
    static func linkedInterventions(of rule: MaintenanceRule) -> [Intervention] {
        (rule.car?.interventions ?? []).filter { $0.ruleKey == rule.key }
    }

    /// Détache les interventions liées puis supprime la règle, en un seul enregistrement.
    static func delete(_ rule: MaintenanceRule, in context: ModelContext) throws {
        linkedInterventions(of: rule).forEach { $0.ruleKey = nil }
        context.delete(rule)
        try saveOrRollback(context)
    }

    /// Enregistre les modifications en cours en supprimant au passage ces documents ; fichiers effacés après succès.
    static func save(_ context: ModelContext, deleting documents: [StoredDocument], store: DocumentStore = .shared) throws {
        let names = documents.map(\.fileName)
        documents.forEach(context.delete)
        try saveOrRollback(context)
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ document: StoredDocument, in context: ModelContext, store: DocumentStore = .shared) throws {
        let name = document.fileName
        context.delete(document)
        try saveOrRollback(context)
        store.delete(fileName: name)
    }
}

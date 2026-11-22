import Foundation
import SwiftData

/// Suppression des objets ET des fichiers associés sur le disque.
enum DeletionService {
    static func delete(_ car: Car, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = car.interventions.flatMap { $0.documents.map(\.fileName) }
        context.delete(car)
        try context.save()
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ intervention: Intervention, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = intervention.documents.map(\.fileName)
        context.delete(intervention)
        try context.save()
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ document: StoredDocument, in context: ModelContext, store: DocumentStore = .shared) throws {
        let name = document.fileName
        context.delete(document)
        try context.save()
        store.delete(fileName: name)
    }
}

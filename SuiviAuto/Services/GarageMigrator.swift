import Foundation
import SwiftData

/// Convertit les noms de garage texte (1.0) en fiches Garage. Idempotent ; ne modifie jamais le texte d'origine.
enum GarageMigrator {
    struct Result: Equatable {
        let created: Int
        let linked: Int
    }

    @discardableResult
    static func run(in context: ModelContext) throws -> Result {
        let pending = try context.fetch(FetchDescriptor<Intervention>(sortBy: [SortDescriptor(\.date)]))
            .filter { $0.garageRef == nil && !$0.garageTextMigrated }
        guard !pending.isEmpty else { return Result(created: 0, linked: 0) }

        var byKey: [String: Garage] = [:]
        for garage in try context.fetch(FetchDescriptor<Garage>(sortBy: [SortDescriptor(\.createdAt)])) {
            let key = Garage.nameKey(garage.name)
            if byKey[key] == nil { byKey[key] = garage }
        }

        var created = 0
        var linked = 0
        for intervention in pending {
            intervention.garageTextMigrated = true
            let cleaned = Garage.cleanedName(intervention.garage)
            guard !cleaned.isEmpty else { continue }
            let key = Garage.nameKey(cleaned)
            let garage: Garage
            if let existing = byKey[key] {
                garage = existing
            } else {
                garage = Garage(name: cleaned)
                context.insert(garage)
                byKey[key] = garage
                created += 1
            }
            intervention.garageRef = garage
            linked += 1
        }
        try DeletionService.saveOrRollback(context)
        return Result(created: created, linked: linked)
    }
}

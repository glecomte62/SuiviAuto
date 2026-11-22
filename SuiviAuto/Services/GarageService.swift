import Foundation
import SwiftData

enum GarageService {
    private static let locale = Locale(identifier: "fr_FR")

    /// Tri alphabétique français, insensible à la casse et aux accents.
    static func sorted(_ garages: [Garage]) -> [Garage] {
        garages.sorted {
            $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: locale)
                == .orderedAscending
        }
    }

    static func hasDuplicateName(_ name: String, among garages: [Garage], excluding: Garage?) -> Bool {
        let key = Garage.nameKey(name)
        guard !key.isEmpty else { return false }
        return garages.contains { $0 !== excluding && Garage.nameKey($0.name) == key }
    }

    /// Les interventions liées gardent le nom du garage en texte ; les contacts sont supprimés.
    static func delete(_ garage: Garage, in context: ModelContext) throws {
        for intervention in garage.interventions {
            intervention.garage = garage.name
            intervention.garageTextMigrated = true
            intervention.garageRef = nil
        }
        context.delete(garage)
        try DeletionService.saveOrRollback(context)
    }

    /// Toutes voitures confondues, de la plus récente à la plus ancienne.
    static func interventions(of garage: Garage) -> [Intervention] {
        garage.interventions.sorted { ($0.date, $0.mileage) > ($1.date, $1.mileage) }
    }

    /// Total des factures (devis exclus), en centimes.
    static func invoiceTotalCents(of garage: Garage) -> Int {
        garage.interventions
            .filter { $0.status == .facture }
            .compactMap(\.amountCents)
            .reduce(0, +)
    }
}

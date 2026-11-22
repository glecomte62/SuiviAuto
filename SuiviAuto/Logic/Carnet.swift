import Foundation

struct CarnetQuery: Equatable {
    var text = ""
    var operation: MaintenanceOperation?
    var year: Int?
    var garageID: UUID?
}

/// Carnet d'entretien : factures d'une voiture, filtrées, de la plus récente à la plus ancienne.
enum Carnet {
    static func entries(for car: Car, query: CarnetQuery, calendar: Calendar = .current) -> [Intervention] {
        let needle = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return car.interventions
            .filter { $0.status == .facture }
            .filter { i in query.operation.map { i.operations.contains($0) } ?? true }
            .filter { query.year == nil || calendar.component(.year, from: $0.date) == query.year }
            .filter { query.garageID == nil || $0.garageRef?.uuid == query.garageID }
            .filter { i in
                needle.isEmpty || [i.title, i.operationsSummary, i.garageDisplayName, i.notes, i.kind.label]
                    .contains { $0.localizedStandardContains(needle) }
            }
            .sorted { ($0.date, $0.mileage) > ($1.date, $1.mileage) }
    }

    static func totalCents(_ entries: [Intervention]) -> Int {
        entries.compactMap(\.amountCents).reduce(0, +)
    }

    static func years(for car: Car, calendar: Calendar = .current) -> [Int] {
        Set(car.interventions.filter { $0.status == .facture }.map { calendar.component(.year, from: $0.date) })
            .sorted(by: >)
    }

    /// Garages des factures du carnet (les devis n'y figurent pas).
    static func garages(for car: Car) -> [Garage] {
        var seen = Set<UUID>()
        let garages = car.interventions.filter { $0.status == .facture }.compactMap(\.garageRef).filter { seen.insert($0.uuid).inserted }
        return GarageService.sorted(garages)
    }

    /// Texte de la colonne « Opérations » : opérations, sinon titre, sinon catégorie.
    static func operationsText(_ i: Intervention) -> String {
        let ops = i.operationsSummary
        if !ops.isEmpty { return ops }
        return i.displayTitle
    }
}

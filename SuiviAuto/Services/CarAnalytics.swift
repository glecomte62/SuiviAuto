import Foundation

/// Conversion des modèles SwiftData en entrées pour la couche Logic.
enum CarAnalytics {
    /// Points km : relevés manuels + interventions facturées.
    static func mileagePoints(for car: Car, excluding: Intervention? = nil) -> [MileagePoint] {
        let readings = car.readings.map { MileagePoint(date: $0.date, km: $0.mileage) }
        let invoices = car.interventions
            .filter { $0.status == .facture && $0 != excluding }
            .map { MileagePoint(date: $0.date, km: $0.mileage) }
        var points = readings + invoices
        if let date = car.purchaseDate, let km = car.purchaseMileage {
            points.append(MileagePoint(date: date, km: km))
        }
        return points
    }

    /// Départ d'une règle jamais effectuée : achat (voiture d'occasion), sinon 1re immatriculation à 0 km.
    static func defaultRuleStart(for car: Car) -> MileagePoint {
        if let date = car.purchaseDate { return MileagePoint(date: date, km: car.purchaseMileage ?? 0) }
        return MileagePoint(date: car.firstRegistrationDate, km: 0)
    }

    static func estimator(for car: Car, now: Date = .now, calendar: Calendar = .current) -> MileageEstimator {
        MileageEstimator(points: mileagePoints(for: car), now: now, calendar: calendar)
    }

    /// Plus grand km connu à une date donnée (pour avertir d'une saisie incohérente).
    static func lastKnownMileage(for car: Car, onOrBefore date: Date, excluding: Intervention? = nil) -> Int? {
        mileagePoints(for: car, excluding: excluding).filter { $0.date <= date }.map(\.km).max()
    }

    static func costEntries(for cars: [Car]) -> [CostEntry] {
        cars.flatMap { car in
            car.interventions.compactMap { i -> CostEntry? in
                guard let cents = i.amountCents else { return nil }
                return CostEntry(carID: car.uuid.uuidString, carName: car.name, date: i.date, kind: i.kind, amountCents: cents, status: i.status)
            }
        }
        .sorted { $0.date < $1.date }
    }
}

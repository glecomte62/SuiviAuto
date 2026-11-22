import Foundation

struct MileagePoint: Equatable {
    let date: Date
    let km: Int
}

struct MileageEstimator {
    let points: [MileagePoint]
    let now: Date
    let calendar: Calendar

    private static let secondsPerDay = 86_400.0

    init(points: [MileagePoint], now: Date = .now, calendar: Calendar = .current) {
        // Tri au jour près puis par km : le même jour, le km le plus élevé est le plus récent, quelle que soit l'heure.
        self.points = points.sorted {
            (calendar.startOfDay(for: $0.date), $0.km, $0.date) < (calendar.startOfDay(for: $1.date), $1.km, $1.date)
        }
        self.now = now
        self.calendar = calendar
    }

    var latest: MileagePoint? { points.last }

    /// Jours calendaires entre deux points (l'heure de saisie ne compte pas).
    private func calendarDays(_ a: MileagePoint, _ b: MileagePoint) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a.date), to: calendar.startOfDay(for: b.date)).day ?? 0
    }

    /// Moyenne km/jour : sur les 12 derniers mois s'il y a au moins 2 points sur des jours différents,
    /// sinon sur tout l'historique.
    var kmPerDay: Double? {
        guard points.count >= 2 else { return nil }
        let windowStart = calendar.startOfDay(for: calendar.date(byAdding: .month, value: -12, to: now)!)
        let recent = points.filter { $0.date >= windowStart }
        let recentUsable = recent.count >= 2 && calendarDays(recent.first!, recent.last!) > 0
        let sample = recentUsable ? recent : points
        guard let first = sample.first, let last = sample.last else { return nil }
        let days = Double(calendarDays(first, last))
        guard days > 0 else { return nil }
        return Double(last.km - first.km) / days
    }

    func estimatedMileage(at date: Date) -> Int? {
        guard let latest else { return nil }
        guard let rate = kmPerDay, rate > 0, date > latest.date else { return latest.km }
        let days = date.timeIntervalSince(latest.date) / Self.secondsPerDay
        return latest.km + Int((rate * days).rounded())
    }

    var estimatedCurrentMileage: Int? { estimatedMileage(at: now) }

    /// Date estimée à laquelle `target` km sera atteint. Si déjà atteint : date du dernier point.
    func estimatedDate(forMileage target: Int) -> Date? {
        guard let latest else { return nil }
        if target <= latest.km { return latest.date }
        guard let rate = kmPerDay, rate > 0 else { return nil }
        let days = Int((Double(target - latest.km) / rate).rounded(.up))
        return calendar.date(byAdding: .day, value: days, to: latest.date)
    }
}

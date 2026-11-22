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
        self.points = points.sorted { ($0.date, $0.km) < ($1.date, $1.km) }
        self.now = now
        self.calendar = calendar
    }

    var latest: MileagePoint? { points.last }

    /// Moyenne km/jour : sur les 12 derniers mois s'il y a au moins 2 points, sinon sur tout l'historique.
    var kmPerDay: Double? {
        guard points.count >= 2 else { return nil }
        let windowStart = calendar.date(byAdding: .month, value: -12, to: now)!
        let recent = points.filter { $0.date >= windowStart }
        let sample = recent.count >= 2 ? recent : points
        guard let first = sample.first, let last = sample.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / Self.secondsPerDay
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
        return latest.date.addingTimeInterval(Double(target - latest.km) / rate * Self.secondsPerDay)
    }
}

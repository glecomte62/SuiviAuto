import Foundation

struct RuleSpec: Equatable {
    let label: String
    let intervalKm: Int?
    let intervalMonths: Int?
}

struct MaintenanceDue: Equatable {
    let dueDate: Date?
    let dueKm: Int?
    let remainingKm: Int?
    let status: DueStatus
}

enum MaintenanceScheduler {
    /// `lastDone` : dernière facture liée à la règle. Si nil : 1re immatriculation et 0 km.
    static func due(rule: RuleSpec, lastDone: MileagePoint?, firstRegistration: Date,
                    estimator: MileageEstimator, now: Date, calendar: Calendar = .current) -> MaintenanceDue {
        let start = lastDone ?? MileagePoint(date: firstRegistration, km: 0)
        let dueKm = rule.intervalKm.map { start.km + $0 }
        let dateByTime = rule.intervalMonths.flatMap { calendar.date(byAdding: .month, value: $0, to: start.date) }
        let dateByKm = dueKm.flatMap { estimator.estimatedDate(forMileage: $0) }
        let dueDate = [dateByTime, dateByKm].compactMap { $0 }.min()

        var remainingKm: Int?
        if let dueKm, let current = estimator.estimatedCurrentMileage {
            remainingKm = dueKm - current
        }

        let status = DueStatusEvaluator.status(dueDate: dueDate, remainingKm: remainingKm, now: now, calendar: calendar)
        return MaintenanceDue(dueDate: dueDate, dueKm: dueKm, remainingKm: remainingKm, status: status)
    }
}

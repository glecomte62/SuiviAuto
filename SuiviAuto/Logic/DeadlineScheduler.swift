import Foundation

struct DeadlineDue: Equatable {
    let dueDate: Date?
    let dueKm: Int?
    let remainingKm: Int?
    let status: DueStatus
}

enum DeadlineScheduler {
    static func due(mode: DeadlineMode, dueDate: Date, targetMileage: Int?,
                    estimator: MileageEstimator, now: Date, calendar: Calendar = .current) -> DeadlineDue {
        switch mode {
        case .date:
            return DeadlineDue(dueDate: dueDate, dueKm: nil, remainingKm: nil,
                               status: DueStatusEvaluator.status(dueDate: dueDate, remainingKm: nil, now: now, calendar: calendar))
        case .km:
            guard let target = targetMileage else {
                return DeadlineDue(dueDate: nil, dueKm: nil, remainingKm: nil, status: .ok)
            }
            let remaining = estimator.estimatedCurrentMileage.map { target - $0 }
            let estimatedDate = estimator.estimatedDate(forMileage: target)
            let status = DueStatusEvaluator.status(dueDate: estimatedDate, remainingKm: remaining, now: now, calendar: calendar)
            // Cible déjà dépassée : la « date estimée » serait celle du dernier relevé, sans signification.
            let shownDate = (remaining ?? 0) < 0 ? nil : estimatedDate
            return DeadlineDue(dueDate: shownDate, dueKm: target, remainingKm: remaining, status: status)
        }
    }
}

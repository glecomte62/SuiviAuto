import Foundation

enum DueStatus: Int, Comparable {
    case ok = 0, soon = 1, overdue = 2
    static func < (lhs: DueStatus, rhs: DueStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .ok: "À jour"
        case .soon: "Bientôt"
        case .overdue: "Dépassé"
        }
    }
}

enum DueThresholds {
    static let soonDays = 60
    static let soonKm = 1_000
}

enum DueStatusEvaluator {
    /// Statut d'une échéance : le critère le plus défavorable (date ou km) l'emporte.
    static func status(dueDate: Date?, remainingKm: Int?, now: Date, calendar: Calendar = .current) -> DueStatus {
        var result = DueStatus.ok
        if let dueDate {
            let days = daysBetween(now, dueDate, calendar: calendar)
            if days < 0 { return .overdue }
            if days <= DueThresholds.soonDays { result = .soon }
        }
        if let remainingKm {
            if remainingKm < 0 { return .overdue }
            if remainingKm <= DueThresholds.soonKm { result = .soon }
        }
        return result
    }

    /// Nombre de jours calendaires entre deux dates (0 si même jour).
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

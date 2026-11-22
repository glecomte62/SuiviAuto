import Foundation

struct PlannedNotification: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

enum NotificationPlanner {
    static let leadDays = [30, 7]
    static let fireHour = 9
    /// macOS limite le nombre de notifications en attente : on garde les plus proches.
    static let maxPending = 60

    static func plan(items: [DueItem], now: Date, calendar: Calendar = .current) -> [PlannedNotification] {
        let all = items.flatMap { item -> [PlannedNotification] in
            guard let due = item.dueDate else { return [] }
            return leadDays.compactMap { lead in
                guard let day = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: due)),
                      let fire = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: day),
                      fire > now else { return nil }
                let when = due.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
                let estimated = item.dueKm != nil ? " (date estimée)" : ""
                return PlannedNotification(id: "\(item.id)-J\(lead)",
                                           title: "\(item.carName) : \(item.label)",
                                           body: "Échéance dans \(lead) jours, le \(when)\(estimated).",
                                           fireDate: fire)
            }
        }
        return Array(all.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }
}

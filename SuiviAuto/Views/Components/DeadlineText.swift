import Foundation

/// Textes d'affichage d'une échéance.
enum DeadlineText {
    /// Cible courte, pour un menu : « 15 mars 2027 » ou « à 90 000 km ».
    static func target(mode: DeadlineMode, dueDate: Date, targetMileage: Int?) -> String {
        switch mode {
        case .date: Fmt.date(dueDate)
        case .km: targetMileage.map { "à \(Fmt.km($0))" } ?? "km cible inconnu"
        }
    }

    /// Ligne de détail de la liste des échéances.
    static func detail(mode: DeadlineMode, dueDate: Date, repeatsYearly: Bool, intervalKm: Int?, due: DeadlineDue) -> String {
        switch mode {
        case .date:
            return Fmt.date(dueDate) + (repeatsYearly ? " · chaque année" : "")
        case .km:
            guard let km = due.dueKm else { return "Kilométrage cible inconnu" }
            var parts = ["à \(Fmt.km(km))"]
            if let date = due.dueDate { parts.append("≈ \(Fmt.date(date))") }
            if let remaining = due.remainingKm {
                parts.append(remaining < 0 ? "dépassé de \(Fmt.km(-remaining))" : "reste \(Fmt.km(remaining))")
            }
            if let interval = intervalKm, interval > 0 { parts.append("puis tous les \(Fmt.km(interval))") }
            return parts.joined(separator: " · ")
        }
    }

    /// Ordre de la liste : km déjà dépassés (sans date estimée) en tête, puis par date réelle ou estimée,
    /// puis les échéances au km sans estimation, par km cible.
    static func sortKey(_ due: DeadlineDue) -> (Int, Date, Int) {
        if let date = due.dueDate { return (1, date, due.dueKm ?? 0) }
        return (due.status == .overdue ? 0 : 2, .distantPast, due.dueKm ?? .max)
    }
}

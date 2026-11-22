import Foundation

/// Outils de test : calendrier UTC fixe et fabrication de dates.
enum T {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "fr_FR")
        return c
    }()

    /// `T.date("2026-03-01")` ou `T.date("2026-03-01", hour: 9)`
    static func date(_ s: String, hour: Int = 0) -> Date {
        let p = s.split(separator: "-").map { Int($0)! }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
    }
}

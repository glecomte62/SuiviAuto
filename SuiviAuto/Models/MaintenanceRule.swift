import Foundation
import SwiftData

@Model
final class MaintenanceRule {
    var uuid: UUID = UUID()
    var key: String = ""
    var label: String = ""
    var intervalKm: Int?
    var intervalMonths: Int?
    var car: Car?

    init(key: String, label: String, intervalKm: Int?, intervalMonths: Int?) {
        self.key = key
        self.label = label
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
    }

    static let defaults: [(key: String, label: String, km: Int?, months: Int?)] = [
        ("vidange", "Vidange moteur", 15_000, 12),
        ("courroie", "Courroie de distribution", 120_000, 72),
        ("liquide-frein", "Liquide de frein", nil, 24),
    ]

    /// "Filtre à air" -> "filtre-a-air", rendu unique parmi `existing`.
    static func makeKey(label: String, existing: Set<String>) -> String {
        let folded = label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        var base = folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        if base.isEmpty { base = "regle" }
        var candidate = base
        var n = 2
        while existing.contains(candidate) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return candidate
    }

    /// "Tous les 15 000 km ou 12 mois"
    var intervalDescription: String {
        let km = intervalKm.map { "\($0.formatted(.number.locale(Locale(identifier: "fr_FR")))) km" }
        let months = intervalMonths.map { "\($0) mois" }
        return "Tous les " + [km, months].compactMap { $0 }.joined(separator: " ou ")
    }
}

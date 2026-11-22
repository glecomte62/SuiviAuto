import Foundation

/// Catalogue des opérations d'entretien (ordre = ordre d'affichage et de stockage).
enum MaintenanceOperation: String, CaseIterable, Identifiable, Codable {
    case vidange, courroie, liquideFrein, freins, filtres, pneus, controleTechnique, autre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vidange: "Vidange"
        case .courroie: "Courroie de distribution / accessoires"
        case .liquideFrein: "Liquide de frein"
        case .freins: "Plaquettes / Disques"
        case .filtres: "Filtres"
        case .pneus: "Pneumatiques"
        case .controleTechnique: "Contrôle technique"
        case .autre: "Autre"
        }
    }

    var symbol: String {
        switch self {
        case .vidange: "drop.fill"
        case .courroie: "gearshape.2.fill"
        case .liquideFrein: "drop.triangle.fill"
        case .freins: "circle.circle"
        case .filtres: "line.3.horizontal.decrease.circle.fill"
        case .pneus: "circle.dashed"
        case .controleTechnique: "checkmark.seal.fill"
        case .autre: "ellipsis.circle.fill"
        }
    }

    /// Règle d'entretien par défaut correspondante (voir MaintenanceRule.defaults).
    var suggestedRuleKey: String? {
        switch self {
        case .vidange: "vidange"
        case .courroie: "courroie"
        case .liquideFrein: "liquide-frein"
        default: nil
        }
    }

    /// Mots-clés (déjà repliés : minuscules, sans accents).
    var keywords: [String] {
        switch self {
        case .vidange: ["vidange", "huile moteur"]
        case .courroie: ["courroie", "distribution", "galet", "pompe a eau"]
        case .liquideFrein: ["liquide de frein", "purge"]
        case .freins: ["plaquette", "disque"]
        case .filtres: ["filtre"]
        case .pneus: ["pneu", "pneumatique", "equilibrage", "parallelisme"]
        case .controleTechnique: ["controle technique"]
        case .autre: []
        }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Opérations reconnues dans un texte, dans l'ordre du catalogue.
    static func detect(in text: String) -> [MaintenanceOperation] {
        let folded = fold(text)
        return allCases.filter { op in op.keywords.contains { folded.contains($0) } }
    }

    /// Codes séparés par des virgules -> opérations connues, dédoublonnées, ordre du catalogue.
    static func decode(_ raw: String) -> [MaintenanceOperation] {
        let codes = Set(raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
        return allCases.filter { codes.contains($0.rawValue) }
    }

    static func encode(_ operations: [MaintenanceOperation]) -> String {
        let set = Set(operations)
        return allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

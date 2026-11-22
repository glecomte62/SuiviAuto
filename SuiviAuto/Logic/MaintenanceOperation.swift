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

    /// Mots-clés, écrits sous forme normalisée (voir `fold`) : minuscules, sans accents, mots séparés par une espace.
    var keywords: [String] {
        switch self {
        case .vidange: ["vidange", "huile moteur"]
        case .courroie: ["courroie", "kit de distribution", "kit distribution", "galet", "pompe a eau"]
        case .liquideFrein: ["liquide de frein", "purge"]
        case .freins: ["plaquette", "disque"]
        case .filtres: ["filtre"]
        case .pneus: ["pneu", "pneumatique", "equilibrage", "parallelisme"]
        case .controleTechnique: ["controle technique"]
        case .autre: []
        }
    }

    /// Expressions (regex sur le texte normalisé) retirées du texte avant de chercher les mots-clés de cette opération.
    var excludedPhrases: [String] {
        switch self {
        case .vidange: [#"vidange (?:(?:de la|du|des|de) )?(?:liquide|boite|circuit|refroidissement)"#]
        case .freins: [#"disques? d embrayage"#]
        default: []
        }
    }

    /// Mots-clés trop vagues seuls : ils ne comptent que si le mot associé figure aussi dans le texte.
    var keywordContext: [String: String] {
        switch self {
        case .liquideFrein: ["purge": "frein"]
        default: [:]
        }
    }

    /// Minuscules et sans accents, ponctuation conservée (pour l'analyse des dates et montants).
    static func foldCaseAndAccents(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Forme normalisée pour la reconnaissance des mots-clés : `foldCaseAndAccents`, puis toute suite de caractères
    /// non alphanumériques (espaces, retours à la ligne, apostrophes, ponctuation) remplacée par une seule espace.
    static func fold(_ text: String) -> String {
        foldCaseAndAccents(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func matches(folded text: String) -> Bool {
        let remaining = excludedPhrases.reduce(text) {
            $0.replacingOccurrences(of: $1, with: " ", options: .regularExpression)
        }
        return keywords.contains { keyword in
            guard remaining.contains(keyword) else { return false }
            return keywordContext[keyword].map { remaining.contains($0) } ?? true
        }
    }

    /// Opérations reconnues dans un texte, dans l'ordre du catalogue.
    static func detect(in text: String) -> [MaintenanceOperation] {
        let folded = fold(text)
        return allCases.filter { $0.matches(folded: folded) }
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

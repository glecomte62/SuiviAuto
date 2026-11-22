import Foundation

enum FuelType: String, CaseIterable, Identifiable, Codable {
    case essence, diesel, hybride, electrique, gpl, autre
    var id: String { rawValue }
    var label: String {
        switch self {
        case .essence: "Essence"
        case .diesel: "Diesel"
        case .hybride: "Hybride"
        case .electrique: "Électrique"
        case .gpl: "GPL"
        case .autre: "Autre"
        }
    }
}

enum InterventionKind: String, CaseIterable, Identifiable, Codable {
    case entretien, reparation, controleTechnique, pneus, carrosserie, autre
    var id: String { rawValue }
    var label: String {
        switch self {
        case .entretien: "Entretien"
        case .reparation: "Réparation"
        case .controleTechnique: "Contrôle technique"
        case .pneus: "Pneus"
        case .carrosserie: "Carrosserie"
        case .autre: "Autre"
        }
    }
    var symbol: String {
        switch self {
        case .entretien: "oilcan.fill"
        case .reparation: "wrench.and.screwdriver.fill"
        case .controleTechnique: "checkmark.seal.fill"
        case .pneus: "circle.circle.fill"
        case .carrosserie: "car.side.fill"
        case .autre: "ellipsis.circle.fill"
        }
    }
}

enum DeadlineMode: String, CaseIterable, Identifiable, Codable {
    case date, km
    var id: String { rawValue }
    var label: String { self == .date ? "À une date" : "À un kilométrage" }
}

enum InterventionStatus: String, CaseIterable, Identifiable, Codable {
    case devis, facture
    var id: String { rawValue }
    var label: String { self == .devis ? "Devis" : "Facture" }
}

enum CTResult: String, CaseIterable, Identifiable, Codable {
    case favorable, defavorable, critique
    var id: String { rawValue }
    var label: String {
        switch self {
        case .favorable: "Favorable"
        case .defavorable: "Défavorable (contre-visite)"
        case .critique: "Défaillance critique"
        }
    }
}

enum DocumentKind: String, Codable {
    case pdf, image
}

/// Couleurs d'accent proposées pour les voitures.
enum CarPalette {
    static let colors = ["#2E86AB", "#E4572E", "#17BEBB", "#F18F01", "#76B041", "#A23B72", "#FFC914", "#5B5F97"]
    static func color(forIndex i: Int) -> String { colors[((i % colors.count) + colors.count) % colors.count] }
}

import Foundation
import SwiftData

@Model
final class Garage {
    var uuid: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var phone: String = ""
    var email: String = ""
    var website: String = ""
    var openingHours: String = ""
    var specialties: String = ""
    /// Valeur brute ; utiliser `rating` (bornée 0…5, 0 = non noté).
    var ratingValue: Int = 0
    var review: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \GarageContact.garage) var contacts: [GarageContact] = []
    @Relationship(deleteRule: .nullify, inverse: \Intervention.garageRef) var interventions: [Intervention] = []

    init(name: String) {
        self.name = name
    }

    var rating: Int {
        get { min(max(ratingValue, 0), 5) }
        set { ratingValue = min(max(newValue, 0), 5) }
    }

    /// Espaces superflus supprimés (début, fin, répétitions, tabulations).
    static func cleanedName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Clé de regroupement : nom nettoyé, insensible à la casse et aux accents.
    static func nameKey(_ name: String) -> String {
        cleanedName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}

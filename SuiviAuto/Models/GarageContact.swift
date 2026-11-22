import Foundation
import SwiftData

@Model
final class GarageContact {
    var uuid: UUID = UUID()
    var name: String = ""
    var role: String = ""
    var phone: String = ""
    var mobile: String = ""
    var email: String = ""
    var notes: String = ""
    var garage: Garage?

    init(name: String) {
        self.name = name
    }

    static let suggestedRoles = [
        "Réception", "Chef d'atelier", "Mécanicien", "Carrossier",
        "Commercial", "Comptabilité", "Pièces détachées",
    ]
}

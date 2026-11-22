import Foundation
import SwiftData

@Model
final class Car {
    var uuid: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var modelName: String = ""
    var plate: String = ""
    var vin: String = ""
    var firstRegistrationDate: Date = Date.now
    var fuelRaw: String = "essence"
    var colorHex: String = "#2E86AB"
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Intervention.car) var interventions: [Intervention] = []
    @Relationship(deleteRule: .cascade, inverse: \OdometerReading.car) var readings: [OdometerReading] = []
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRule.car) var rules: [MaintenanceRule] = []
    @Relationship(deleteRule: .cascade, inverse: \Deadline.car) var deadlines: [Deadline] = []

    init(name: String, firstRegistrationDate: Date, colorHex: String = "#2E86AB") {
        self.name = name
        self.firstRegistrationDate = firstRegistrationDate
        self.colorHex = colorHex
    }

    var fuel: FuelType {
        get { FuelType(rawValue: fuelRaw) ?? .autre }
        set { fuelRaw = newValue.rawValue }
    }

    /// Ajoute les règles d'entretien proposées par défaut (spec §3). Les clés déjà présentes sont ignorées.
    func addDefaultRules(in context: ModelContext) {
        let existing = Set(rules.map(\.key))
        for d in MaintenanceRule.defaults where !existing.contains(d.key) {
            let rule = MaintenanceRule(key: d.key, label: d.label, intervalKm: d.km, intervalMonths: d.months)
            context.insert(rule)
            rule.car = self
        }
    }
}

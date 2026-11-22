import SwiftData

enum SchemaModels {
    static let all: [any PersistentModel.Type] = [
        Car.self, Intervention.self, StoredDocument.self,
        OdometerReading.self, MaintenanceRule.self, Deadline.self,
        Garage.self, GarageContact.self,
    ]
}

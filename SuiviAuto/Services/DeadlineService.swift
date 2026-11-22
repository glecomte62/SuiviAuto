import Foundation
import SwiftData

enum DeadlineService {
    enum CompletionError: LocalizedError, Equatable {
        case differentCar

        var errorDescription: String? {
            switch self {
            case .differentCar: "L'intervention et l'échéance ne concernent pas la même voiture."
            }
        }
    }

    /// Transfère les documents de l'échéance vers l'intervention puis applique la validation. Une seule sauvegarde.
    /// Le kilométrage de l'intervention n'est retenu que s'il est renseigné (0 = inconnu).
    static func complete(_ deadline: Deadline, with intervention: Intervention, in context: ModelContext,
                         calendar: Calendar = .current) throws {
        guard deadline.car === intervention.car else { throw CompletionError.differentCar }
        for doc in deadline.documents {
            doc.deadline = nil
            doc.intervention = intervention
        }
        // Vide aussi le côté échéance de la relation : sans cela, la suppression en cascade ci-dessous
        // pourrait encore voir les documents transférés et les supprimer avec l'échéance.
        deadline.documents = []
        let mileage = intervention.mileage > 0 ? intervention.mileage : nil
        if deadline.complete(on: intervention.date, mileage: mileage, calendar: calendar) == .remove {
            context.delete(deadline)
        }
        try DeletionService.saveOrRollback(context)
    }
}

import Foundation
import SwiftData

/// Ce qui change quand une échéance est soldée : sert à détecter une validation faite ailleurs entre-temps.
struct DeadlineSnapshot: Equatable {
    let dueDate: Date
    let targetMileage: Int?

    init(_ deadline: Deadline) {
        dueDate = deadline.dueDate
        targetMileage = deadline.targetMileage
    }
}

enum DeadlineService {
    static let changedElsewhereMessage = "Cette échéance a été modifiée ou supprimée entre-temps."

    /// L'échéance existe encore et appartient toujours à cette voiture (pas supprimée dans une autre fenêtre).
    static func isStillPresent(_ deadline: Deadline, in car: Car) -> Bool {
        guard !deadline.isDeleted, deadline.modelContext != nil else { return false }
        return car.deadlines.contains { $0 === deadline }
    }

    /// Présente ET inchangée depuis sa sélection : la solder maintenant ne la validerait pas deux fois.
    static func isStillPending(_ deadline: Deadline, snapshot: DeadlineSnapshot, in car: Car) -> Bool {
        isStillPresent(deadline, in: car) && DeadlineSnapshot(deadline) == snapshot
    }

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

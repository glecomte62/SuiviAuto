import Foundation
import SwiftData

enum DeadlineService {
    /// Transfère les documents de l'échéance vers l'intervention puis applique la validation. Une seule sauvegarde.
    static func complete(_ deadline: Deadline, with intervention: Intervention, in context: ModelContext,
                         calendar: Calendar = .current) throws {
        for doc in deadline.documents {
            doc.deadline = nil
            doc.intervention = intervention
        }
        if deadline.complete(on: intervention.date, mileage: intervention.mileage, calendar: calendar) == .remove {
            context.delete(deadline)
        }
        try DeletionService.saveOrRollback(context)
    }
}

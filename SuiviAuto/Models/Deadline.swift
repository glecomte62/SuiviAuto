import Foundation
import SwiftData

@Model
final class Deadline {
    var uuid: UUID = UUID()
    var label: String = ""
    var dueDate: Date = Date.now
    var repeatsYearly: Bool = false
    var notes: String = ""
    var car: Car?
    var modeRaw: String = "date"
    var targetMileage: Int?
    var intervalKm: Int?
    @Relationship(deleteRule: .cascade, inverse: \StoredDocument.deadline) var documents: [StoredDocument] = []

    var mode: DeadlineMode {
        get { DeadlineMode(rawValue: modeRaw) ?? .date }
        set { modeRaw = newValue.rawValue }
    }

    init(label: String, dueDate: Date, repeatsYearly: Bool, notes: String = "") {
        self.label = label
        self.dueDate = dueDate
        self.repeatsYearly = repeatsYearly
        self.notes = notes
    }

    /// Échéance annuelle : avance d'un an et retourne true. Sinon retourne false (l'appelant la supprime).
    @discardableResult
    func markDone(calendar: Calendar = .current) -> Bool {
        complete(on: .now, mileage: nil, calendar: calendar) == .advanced
    }
}

enum DeadlineCompletion: Equatable { case advanced, remove }

extension Deadline {
    /// Applique la validation de l'échéance. `.remove` : l'appelant supprime l'échéance.
    func complete(on date: Date, mileage: Int?, calendar: Calendar = .current) -> DeadlineCompletion {
        switch mode {
        case .date:
            guard repeatsYearly else { return .remove }
            dueDate = calendar.date(byAdding: .year, value: 1, to: dueDate) ?? dueDate
            return .advanced
        case .km:
            guard let interval = intervalKm, interval > 0 else { return .remove }
            if let mileage { targetMileage = mileage + interval }
            else { targetMileage = (targetMileage ?? 0) + interval }
            return .advanced
        }
    }
}

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

    init(label: String, dueDate: Date, repeatsYearly: Bool, notes: String = "") {
        self.label = label
        self.dueDate = dueDate
        self.repeatsYearly = repeatsYearly
        self.notes = notes
    }

    /// Échéance annuelle : avance d'un an et retourne true. Sinon retourne false (l'appelant la supprime).
    @discardableResult
    func markDone(calendar: Calendar = .current) -> Bool {
        guard repeatsYearly else { return false }
        dueDate = calendar.date(byAdding: .year, value: 1, to: dueDate)!
        return true
    }
}

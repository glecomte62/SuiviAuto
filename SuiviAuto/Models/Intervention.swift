import Foundation
import SwiftData

@Model
final class Intervention {
    var date: Date = Date.now
    var mileage: Int = 0
    var kindRaw: String = "entretien"
    var title: String = ""
    var garage: String = ""
    var amountCents: Int?
    var statusRaw: String = "facture"
    var notes: String = ""
    var ctResultRaw: String?
    var ruleKey: String?
    var car: Car?

    @Relationship(deleteRule: .cascade, inverse: \StoredDocument.intervention) var documents: [StoredDocument] = []

    init(date: Date, mileage: Int, kind: InterventionKind, title: String = "", status: InterventionStatus = .facture) {
        self.date = date
        self.mileage = mileage
        self.kindRaw = kind.rawValue
        self.title = title
        self.statusRaw = status.rawValue
    }

    var kind: InterventionKind {
        get { InterventionKind(rawValue: kindRaw) ?? .autre }
        set { kindRaw = newValue.rawValue }
    }

    var status: InterventionStatus {
        get { InterventionStatus(rawValue: statusRaw) ?? .facture }
        set { statusRaw = newValue.rawValue }
    }

    var ctResult: CTResult? {
        get { ctResultRaw.flatMap(CTResult.init(rawValue:)) }
        set { ctResultRaw = newValue?.rawValue }
    }

    var displayTitle: String { title.isEmpty ? kind.label : title }
}

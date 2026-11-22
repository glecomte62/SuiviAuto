import Foundation

struct CTRecord: Equatable {
    let date: Date
    let result: CTResult
}

struct CTDue: Equatable {
    let dueDate: Date
    let isCounterVisit: Bool
    let drivingForbidden: Bool
}

enum TechnicalInspectionCalculator {
    /// `records` : uniquement les CT facturés (les devis sont exclus par l'appelant).
    static func nextDue(firstRegistration: Date, records: [CTRecord], calendar: Calendar = .current) -> CTDue {
        func add(_ component: Calendar.Component, _ value: Int, to date: Date) -> Date {
            calendar.date(byAdding: component, value: value, to: date)!
        }

        var due = CTDue(dueDate: add(.year, 4, to: firstRegistration), isCounterVisit: false, drivingForbidden: false)
        /// Date du CT initial défavorable dont la contre-visite est en attente.
        var anchor: Date?

        // Tri par date ; le même jour, les échecs passent avant le favorable (ordre déterministe).
        let sorted = records.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.result != .favorable && $1.result == .favorable
        }

        for record in sorted {
            let withinWindow = anchor.map { record.date <= add(.month, 2, to: $0) } ?? false
            switch record.result {
            case .favorable:
                let base = withinWindow ? anchor! : record.date
                due = CTDue(dueDate: add(.year, 2, to: base), isCounterVisit: false, drivingForbidden: false)
                anchor = nil
            case .defavorable, .critique:
                // Contre-visite défavorable dans les 2 mois : on garde le CT initial ; sinon nouveau cycle.
                if !withinWindow { anchor = record.date }
                due = CTDue(dueDate: add(.month, 2, to: anchor!),
                            isCounterVisit: true,
                            drivingForbidden: record.result == .critique)
            }
        }
        return due
    }
}

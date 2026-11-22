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
        var pendingFailure: Date?

        for record in records.sorted(by: { $0.date < $1.date }) {
            switch record.result {
            case .favorable:
                var base = record.date
                if let failure = pendingFailure, record.date <= add(.month, 2, to: failure) {
                    base = failure
                }
                due = CTDue(dueDate: add(.year, 2, to: base), isCounterVisit: false, drivingForbidden: false)
                pendingFailure = nil
            case .defavorable, .critique:
                if pendingFailure == nil { pendingFailure = record.date }
                due = CTDue(dueDate: add(.month, 2, to: record.date),
                            isCounterVisit: true,
                            drivingForbidden: record.result == .critique)
            }
        }
        return due
    }
}

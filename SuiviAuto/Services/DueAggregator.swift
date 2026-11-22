import Foundation

struct DueItem: Identifiable, Equatable {
    enum Source: Equatable {
        case technicalInspection
        case rule(String)
        case deadline
    }

    let id: String
    let carName: String
    let carColorHex: String
    let label: String
    let detail: String?
    let dueDate: Date?
    let dueKm: Int?
    let status: DueStatus
    let source: Source

    /// Tri : date croissante, sans date en dernier. À date égale : statut le plus grave d'abord,
    /// puis nom de voiture, libellé, identifiant. Sans date : par identifiant.
    static func byDate(_ a: DueItem, _ b: DueItem) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?):
            if x != y { return x < y }
            if a.status != b.status { return a.status > b.status }
            if a.carName != b.carName { return a.carName < b.carName }
            if a.label != b.label { return a.label < b.label }
            return a.id < b.id
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.id < b.id
        }
    }
}

enum DueAggregator {
    static func ctDue(for car: Car, calendar: Calendar = .current) -> CTDue {
        let records = car.interventions.compactMap { i -> CTRecord? in
            guard i.status == .facture, i.kind == .controleTechnique, let result = i.ctResult else { return nil }
            return CTRecord(date: i.date, result: result)
        }
        return TechnicalInspectionCalculator.nextDue(firstRegistration: car.firstRegistrationDate,
                                                     records: records, calendar: calendar)
    }

    static func ruleDue(_ rule: MaintenanceRule, car: Car, estimator: MileageEstimator,
                        now: Date, calendar: Calendar = .current) -> MaintenanceDue {
        let last = car.interventions
            .filter { $0.status == .facture && $0.ruleKey == rule.key }
            .max { ($0.date, $0.mileage) < ($1.date, $1.mileage) }
        return MaintenanceScheduler.due(
            rule: RuleSpec(label: rule.label, intervalKm: rule.intervalKm, intervalMonths: rule.intervalMonths),
            lastDone: last.map { MileagePoint(date: $0.date, km: $0.mileage) },
            defaultStart: CarAnalytics.defaultRuleStart(for: car),
            estimator: estimator, now: now, calendar: calendar)
    }

    static func items(for car: Car, now: Date = .now, calendar: Calendar = .current) -> [DueItem] {
        var result: [DueItem] = []
        let carID = car.uuid.uuidString

        let ct = ctDue(for: car, calendar: calendar)
        let ctStatus = ct.drivingForbidden
            ? .overdue
            : DueStatusEvaluator.status(dueDate: ct.dueDate, remainingKm: nil, now: now, calendar: calendar)
        result.append(DueItem(id: "\(carID)-ct", carName: car.name, carColorHex: car.colorHex,
                              label: ct.isCounterVisit ? "Contre-visite" : "Contrôle technique",
                              detail: ct.drivingForbidden ? "Défaillance critique : circulation interdite" : nil,
                              dueDate: ct.dueDate, dueKm: nil, status: ctStatus, source: .technicalInspection))

        let estimator = CarAnalytics.estimator(for: car, now: now, calendar: calendar)
        for rule in car.rules {
            let due = ruleDue(rule, car: car, estimator: estimator, now: now, calendar: calendar)
            result.append(DueItem(id: "rule-\(rule.uuid.uuidString)", carName: car.name, carColorHex: car.colorHex,
                                  label: rule.label, detail: rule.intervalDescription,
                                  dueDate: due.dueDate, dueKm: due.dueKm, status: due.status,
                                  source: .rule(rule.key)))
        }

        for deadline in car.deadlines {
            let status = DueStatusEvaluator.status(dueDate: deadline.dueDate, remainingKm: nil, now: now, calendar: calendar)
            result.append(DueItem(id: "deadline-\(deadline.uuid.uuidString)", carName: car.name, carColorHex: car.colorHex,
                                  label: deadline.label, detail: deadline.notes.isEmpty ? nil : deadline.notes,
                                  dueDate: deadline.dueDate, dueKm: nil, status: status, source: .deadline))
        }

        return result.sorted(by: DueItem.byDate)
    }

    static func items(for cars: [Car], now: Date = .now, calendar: Calendar = .current) -> [DueItem] {
        cars.flatMap { items(for: $0, now: now, calendar: calendar) }.sorted(by: DueItem.byDate)
    }

    static func worstStatus(for car: Car, now: Date = .now, calendar: Calendar = .current) -> DueStatus {
        items(for: car, now: now, calendar: calendar).map(\.status).max() ?? .ok
    }
}

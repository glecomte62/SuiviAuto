import Foundation

struct CostEntry: Equatable {
    let carName: String
    let date: Date
    let kind: InterventionKind
    let amountCents: Int
    let status: InterventionStatus
}

struct YearCar: Hashable {
    let year: Int
    let carName: String
}

/// Totaux en centimes. Les devis sont toujours exclus.
enum CostSummary {
    static func totals<K: Hashable>(_ entries: [CostEntry], by key: (CostEntry) -> K) -> [K: Int] {
        entries.filter { $0.status == .facture }
            .reduce(into: [K: Int]()) { $0[key($1), default: 0] += $1.amountCents }
    }

    static func byYear(_ entries: [CostEntry], calendar: Calendar = .current) -> [Int: Int] {
        totals(entries) { calendar.component(.year, from: $0.date) }
    }

    static func byCarAndYear(_ entries: [CostEntry], calendar: Calendar = .current) -> [YearCar: Int] {
        totals(entries) { YearCar(year: calendar.component(.year, from: $0.date), carName: $0.carName) }
    }

    static func byKind(_ entries: [CostEntry], year: Int, calendar: Calendar = .current) -> [InterventionKind: Int] {
        totals(entries.filter { calendar.component(.year, from: $0.date) == year }) { $0.kind }
    }

    static func total(_ entries: [CostEntry], year: Int, calendar: Calendar = .current) -> Int {
        byYear(entries, calendar: calendar)[year] ?? 0
    }
}

import Charts
import SwiftUI

struct DashboardChartsView: View {
    let cars: [Car]

    private struct KmPoint: Identifiable {
        let id: String
        let car: String
        let date: Date
        let km: Int
    }

    private struct YearCost: Identifiable {
        let id: String
        let year: String
        let car: String
        let euros: Double
    }

    /// Série unique par voiture (clé = uuid) ; deux voitures de même nom restent distinctes.
    /// Le nom affiché reçoit un suffixe « (2) », « (3) »… en cas de doublon.
    private var displayNames: [String: String] {
        var seen: [String: Int] = [:]
        var display: [String: String] = [:]
        for car in cars {
            let n = (seen[car.name] ?? 0) + 1
            seen[car.name] = n
            display[car.uuid.uuidString] = n == 1 ? car.name : "\(car.name) (\(n))"
        }
        return display
    }

    var body: some View {
        let year = Calendar.current.component(.year, from: .now)
        let entries = CarAnalytics.costEntries(for: cars)
        let items = DueAggregator.items(for: cars)
        let display = displayNames
        let names = cars.map { display[$0.uuid.uuidString] ?? $0.name }
        let colors = cars.map { Color(hex: $0.colorHex) }

        let kmPoints = cars.flatMap { car in
            CarAnalytics.estimator(for: car).points.enumerated().map { index, p in
                KmPoint(id: "\(car.uuid.uuidString)-\(index)", car: display[car.uuid.uuidString] ?? car.name, date: p.date, km: p.km)
            }
        }
        let costs = CostSummary.byCarAndYear(entries)
            .map { YearCost(id: "\($0.key.year)-\($0.key.carID)", year: String($0.key.year), car: display[$0.key.carID] ?? $0.key.carName, euros: Double($0.value) / 100) }
            .sorted { $0.year < $1.year }

        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    StatTile(title: "Dépenses \(String(year))",
                             value: Money.format(cents: CostSummary.total(entries, year: year)),
                             symbol: "eurosign.circle.fill", tint: .pink)
                    StatTile(title: "Voitures", value: "\(cars.count)", symbol: "car.2.fill", tint: .blue)
                    StatTile(title: "À surveiller", value: "\(items.filter { $0.status != .ok }.count)",
                             symbol: "exclamationmark.triangle.fill", tint: .orange)
                }

                Card(tint: .teal) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Kilométrage", systemImage: "speedometer").font(.headline)
                        ForEach(cars) { car in
                            HStack {
                                CarAvatar(car: car, size: 22)
                                Text(car.name)
                                Spacer()
                                Text(CarAnalytics.estimator(for: car).estimatedCurrentMileage.map(Fmt.km) ?? "—")
                                    .fontWeight(.semibold).monospacedDigit()
                            }
                        }
                        if kmPoints.count >= 2 {
                            Chart(kmPoints) { p in
                                LineMark(x: .value("Date", p.date), y: .value("Km", p.km))
                                    .foregroundStyle(by: .value("Voiture", p.car))
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", p.date), y: .value("Km", p.km))
                                    .foregroundStyle(by: .value("Voiture", p.car))
                            }
                            .chartForegroundStyleScale(domain: names, range: colors)
                            .frame(height: 220)
                        }
                    }
                }

                Card(tint: .pink) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Dépenses par année", systemImage: "chart.bar.fill").font(.headline)
                        if costs.isEmpty {
                            Text("Aucune facture avec montant pour l'instant.").foregroundStyle(.secondary)
                        } else {
                            Chart(costs) { c in
                                BarMark(x: .value("Année", c.year), y: .value("€", c.euros))
                                    .foregroundStyle(by: .value("Voiture", c.car))
                                    .cornerRadius(4)
                            }
                            .chartForegroundStyleScale(domain: names, range: colors)
                            .frame(height: 220)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Tableau de bord")
    }
}

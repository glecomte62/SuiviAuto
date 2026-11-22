import SwiftUI

/// Colonne de détail d'une voiture quand aucune intervention n'est sélectionnée.
struct CarSummaryView: View {
    let car: Car

    var body: some View {
        let tint = Color(hex: car.colorHex)
        let items = DueAggregator.items(for: car)
        let year = Calendar.current.component(.year, from: .now)
        let spent = CostSummary.total(CarAnalytics.costEntries(for: [car]), year: year)
        let km = CarAnalytics.estimator(for: car).estimatedCurrentMileage

        ScrollView {
            VStack(spacing: 16) {
                Card(tint: tint) {
                    HStack(spacing: 16) {
                        CarAvatar(car: car, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name).font(.title.bold())
                            Text([car.brand, car.modelName, car.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 14) {
                    StatTile(title: "Km estimé", value: km.map(Fmt.km) ?? "—", symbol: "speedometer", tint: tint)
                    StatTile(title: "Dépenses \(String(year))", value: Money.format(cents: spent), symbol: "eurosign.circle.fill", tint: .pink)
                }
                Card(tint: tint) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Échéances").font(.headline)
                        ForEach(items) { item in
                            DueItemRow(item: item, showCar: false)
                            Divider()
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

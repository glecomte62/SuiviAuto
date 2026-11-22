import SwiftUI

/// Colonne de droite d'un garage : historique toutes voitures confondues et total facturé.
struct GarageInterventionsView: View {
    let garage: Garage

    var body: some View {
        let items = GarageService.interventions(of: garage)
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    StatTile(title: "Interventions", value: "\(items.count)",
                             symbol: "wrench.and.screwdriver.fill", tint: .orange)
                    StatTile(title: "Total des factures",
                             value: Money.format(cents: GarageService.invoiceTotalCents(of: garage)),
                             symbol: "eurosign.circle.fill", tint: .pink)
                }
                Card(tint: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historique").font(.headline)
                        if items.isEmpty {
                            Text("Aucune intervention dans ce garage pour l'instant.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(items) { i in
                            HStack(spacing: 10) {
                                if let car = i.car { CarAvatar(car: car, size: 26) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i.displayTitle).fontWeight(.medium)
                                    Text([i.car?.name ?? "", Fmt.shortDate(i.date), Fmt.km(i.mileage)]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let cents = i.amountCents {
                                        Text(Money.format(cents: cents)).monospacedDigit()
                                    }
                                    StatusPill(text: i.status.label, color: i.status == .devis ? .purple : .blue)
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

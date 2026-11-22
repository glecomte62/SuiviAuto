import SwiftUI

struct CarInfoView: View {
    let car: Car
    let onDelete: () -> Void
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card(tint: Color(hex: car.colorHex)) {
                    HStack(spacing: 16) {
                        CarAvatar(car: car, size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name).font(.title2.bold())
                            Text("\(car.brand) \(car.modelName)").foregroundStyle(.secondary)
                        }
                    }
                }
                Card(tint: Color(hex: car.colorHex)) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        row("Immatriculation", car.plate)
                        row("N° VIN", car.vin)
                        row("1re immatriculation", Fmt.date(car.firstRegistrationDate))
                        if car.isUsedPurchase, let d = car.purchaseDate {
                            row("Achat", "\(Fmt.date(d)) à \(Fmt.km(car.purchaseMileage ?? 0))")
                        }
                        row("Carburant", car.fuel.label)
                        row("Interventions", "\(car.interventions.count)")
                    }
                }
                HStack {
                    Button { editing = true } label: { Label("Modifier", systemImage: "pencil") }
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer la voiture", systemImage: "trash") }
                }
            }
            .padding(14)
        }
        .sheet(isPresented: $editing) { CarFormView(car: car).tracksSheetPresentation() }
        .confirmationDialog("Supprimer « \(car.name) » ?", isPresented: $confirmDelete) {
            Button("Supprimer définitivement", role: .destructive) { onDelete() }
        } message: {
            Text("Toutes ses interventions, documents, relevés, règles et échéances seront supprimés.")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value.isEmpty ? "—" : value).textSelection(.enabled)
        }
    }
}

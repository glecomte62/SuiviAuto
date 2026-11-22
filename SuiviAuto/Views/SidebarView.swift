import SwiftUI

enum SidebarItem: Hashable {
    case dashboard
    case car(Car)
    case garage(Garage)
}

struct SidebarView: View {
    let cars: [Car]
    let garages: [Garage]
    @Binding var selection: SidebarItem?
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: $selection) {
            Label("Tableau de bord", systemImage: "gauge.with.dots.needle.67percent")
                .tag(SidebarItem.dashboard)
            Section("Mes voitures") {
                ForEach(cars) { car in
                    CarRow(car: car).tag(SidebarItem.car(car))
                }
            }
            Section {
                ForEach(garages) { garage in
                    GarageRow(garage: garage).tag(SidebarItem.garage(garage))
                }
            } header: {
                HStack {
                    Text("Garages")
                    Spacer()
                    Button { appState.showingNewGarage = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .help("Nouveau garage (⌥⌘N)")
                        .accessibilityLabel("Nouveau garage")
                }
            }
        }
        .navigationTitle("SuiviAuto")
        .toolbar {
            Button { appState.showingNewCar = true } label: {
                Label("Nouvelle voiture", systemImage: "plus")
            }
            .help("Nouvelle voiture (⇧⌘N)")
        }
    }
}

struct CarRow: View {
    let car: Car
    var body: some View {
        let status = DueAggregator.worstStatus(for: car)
        HStack(spacing: 10) {
            CarAvatar(car: car, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(car.name).fontWeight(.semibold)
                Text(car.plate.isEmpty ? "\(car.brand) \(car.modelName)" : car.plate)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status != .ok {
                Image(systemName: status.symbol).foregroundStyle(status.color)
                    .help(status.label)
                    .accessibilityLabel(status.label)
            }
        }
        .padding(.vertical, 3)
    }
}

struct GarageRow: View {
    let garage: Garage
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.orange.gradient).shadow(color: .orange.opacity(0.4), radius: 2, y: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(garage.name).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    if garage.rating > 0 { StarRating(rating: .constant(garage.rating), size: 9, editable: false) }
                    Text("\(garage.contacts.count) contact\(garage.contacts.count > 1 ? "s" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

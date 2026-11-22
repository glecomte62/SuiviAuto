import SwiftUI

enum SidebarItem: Hashable {
    case dashboard
    case car(Car)
}

struct SidebarView: View {
    let cars: [Car]
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

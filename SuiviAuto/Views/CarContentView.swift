import SwiftUI

enum CarTab: String, CaseIterable, Identifiable {
    case interventions, carnet, kilometrage, regles, echeances, infos
    var id: String { rawValue }
    var label: String {
        switch self {
        case .interventions: "Interventions"
        case .carnet: "Carnet"
        case .kilometrage: "Km"
        case .regles: "Règles"
        case .echeances: "Échéances"
        case .infos: "Infos"
        }
    }
}

struct CarContentView: View {
    let car: Car
    @Binding var tab: CarTab
    @Binding var selectedIntervention: Intervention?
    let onDeleteCar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("Onglet", selection: $tab) {
                ForEach(CarTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            switch tab {
            // Recherche et filtres propres à chaque voiture : remis à zéro au changement de voiture.
            case .interventions: InterventionListView(car: car, selection: $selectedIntervention).id(car.persistentModelID)
            case .carnet: CarnetView(car: car, selection: $selectedIntervention).id(car.persistentModelID)
            case .kilometrage: MileageView(car: car)
            case .regles: RulesView(car: car)
            case .echeances: DeadlinesView(car: car)
            case .infos: CarInfoView(car: car, onDelete: onDeleteCar)
            }
        }
        .navigationTitle(car.name)
    }
}

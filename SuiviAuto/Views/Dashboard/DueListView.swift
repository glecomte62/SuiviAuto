import SwiftUI

struct DueListView: View {
    let items: [DueItem]
    let hasCars: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            let urgent = items.filter { $0.status != .ok }
            let later = items.filter { $0.status == .ok }
            if !urgent.isEmpty {
                Section("À surveiller") {
                    ForEach(urgent) { DueItemRow(item: $0) }
                }
            }
            if !later.isEmpty {
                Section("Plus tard") {
                    ForEach(later) { DueItemRow(item: $0) }
                }
            }
        }
        .navigationTitle("Prochaines échéances")
        .overlay {
            if !hasCars {
                ContentUnavailableView {
                    Label("Aucune voiture", systemImage: "car.2.fill")
                } description: {
                    Text("Ajoutez votre première voiture pour suivre son entretien.")
                } actions: {
                    Button("Ajouter une voiture") { appState.showingNewCar = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

import SwiftUI

struct InterventionListView: View {
    let car: Car
    @Binding var selection: Intervention?
    @Environment(AppState.self) private var appState
    @State private var search = ""
    @State private var kindFilter: InterventionKind?

    private var filtered: [Intervention] {
        car.interventions
            .filter { i in
                (kindFilter == nil || i.kind == kindFilter)
                && (search.isEmpty
                    || i.title.localizedCaseInsensitiveContains(search)
                    || i.garage.localizedCaseInsensitiveContains(search)
                    || i.notes.localizedCaseInsensitiveContains(search))
            }
            .sorted { ($0.date, $0.mileage) > ($1.date, $1.mileage) }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filtered) { i in
                InterventionRow(intervention: i).tag(i)
            }
        }
        .searchable(text: $search, prompt: "Titre, garage, notes…")
        .overlay {
            if car.interventions.isEmpty {
                ContentUnavailableView("Aucune intervention", systemImage: "wrench.and.screwdriver",
                                       description: Text("Ajoutez la première avec ⌘N."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Type", selection: $kindFilter) {
                    Text("Tous les types").tag(InterventionKind?.none)
                    Divider()
                    ForEach(InterventionKind.allCases) { Label($0.label, systemImage: $0.symbol).tag(Optional($0)) }
                }
                .help("Filtrer par type")
                Button { appState.showingNewIntervention = true } label: {
                    Label("Nouvelle intervention", systemImage: "plus")
                }
                .help("Nouvelle intervention (⌘N)")
            }
        }
    }
}

import SwiftData
import SwiftUI

struct RulesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editingRule: MaintenanceRule?
    @State private var creating = false
    @State private var ruleToDelete: MaintenanceRule?

    var body: some View {
        let estimator = CarAnalytics.estimator(for: car)
        List {
            ForEach(car.rules.sorted { $0.label < $1.label }) { rule in
                let due = DueAggregator.ruleDue(rule, car: car, estimator: estimator, now: .now)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.label).fontWeight(.semibold)
                        Text(rule.intervalDescription).font(.caption).foregroundStyle(.secondary)
                        Text("Prochaine : " + [due.dueDate.map(Fmt.date), due.dueKm.map(Fmt.km)].compactMap { $0 }.joined(separator: " ou "))
                            .font(.caption)
                    }
                    Spacer()
                    StatusBadge(status: due.status)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editingRule = rule }
                .contextMenu {
                    Button("Modifier") { editingRule = rule }
                    Button("Supprimer", role: .destructive) { ruleToDelete = rule }
                }
            }
        }
        .overlay {
            if car.rules.isEmpty {
                ContentUnavailableView("Aucune règle", systemImage: "list.bullet.clipboard",
                                       description: Text("Ex. vidange tous les 15 000 km ou 12 mois."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Pour qu'une facture fasse avancer une règle, choisissez cette règle dans le formulaire de l'intervention. Double-clic pour modifier.")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
        .toolbar {
            Button { creating = true } label: { Label("Nouvelle règle", systemImage: "plus") }
        }
        .confirmationDialog("Supprimer la règle « \(ruleToDelete?.label ?? "") » ?",
                            isPresented: Binding(get: { ruleToDelete != nil }, set: { if !$0 { ruleToDelete = nil } }),
                            presenting: ruleToDelete) { rule in
            Button("Supprimer", role: .destructive) { remove(rule) }
        } message: { rule in
            let n = DeletionService.linkedInterventions(of: rule).count
            Text(n == 0 ? "Aucune intervention n'y est rattachée." : "\(n) intervention(s) liée(s) ne seront plus rattachées.")
        }
        .sheet(item: $editingRule) { RuleFormView(car: car, rule: $0).tracksSheetPresentation() }
        .sheet(isPresented: $creating) { RuleFormView(car: car, rule: nil).tracksSheetPresentation() }
    }

    /// On ferme d'abord la boîte de dialogue, puis on supprime au tour suivant (comme ContentView.delete).
    private func remove(_ rule: MaintenanceRule) {
        ruleToDelete = nil
        DispatchQueue.main.async {
            do { try DeletionService.delete(rule, in: context) }
            catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
        }
    }
}

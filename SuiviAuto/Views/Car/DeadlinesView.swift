import SwiftData
import SwiftUI

struct DeadlinesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editing: Deadline?
    @State private var creating = false
    /// Échéances dont le bouton « Fait » vient d'être cliqué (désactivé 1 s contre le double-clic).
    @State private var justDone: Set<UUID> = []
    @State private var oneOffToComplete: Deadline?

    var body: some View {
        List {
            ForEach(car.deadlines.sorted { $0.dueDate < $1.dueDate }) { d in
                let status = DueStatusEvaluator.status(dueDate: d.dueDate, remainingKm: nil, now: .now)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.label).fontWeight(.semibold)
                        Text(Fmt.date(d.dueDate) + (d.repeatsYearly ? " · chaque année" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                        if !d.notes.isEmpty { Text(d.notes).font(.caption) }
                    }
                    Spacer()
                    StatusBadge(status: status)
                    Button(d.repeatsYearly ? "Fait ✓ (+1 an)" : "Fait ✓") {
                        if d.repeatsYearly { markDone(d) } else { oneOffToComplete = d }
                    }
                    .buttonStyle(.bordered)
                    .disabled(justDone.contains(d.uuid))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editing = d }
                .contextMenu {
                    Button("Modifier") { editing = d }
                    Button("Supprimer", role: .destructive) { remove(d) }
                }
            }
        }
        .overlay {
            if car.deadlines.isEmpty {
                ContentUnavailableView("Aucune échéance", systemImage: "calendar.badge.clock",
                                       description: Text("Assurance, pneus hiver, fin de garantie…"))
            }
        }
        .toolbar {
            Button { creating = true } label: { Label("Nouvelle échéance", systemImage: "plus") }
        }
        .confirmationDialog("Marquer « \(oneOffToComplete?.label ?? "") » comme faite ?",
                            isPresented: Binding(get: { oneOffToComplete != nil }, set: { if !$0 { oneOffToComplete = nil } }),
                            presenting: oneOffToComplete) { d in
            Button("Fait, supprimer l'échéance", role: .destructive) {
                // On ferme d'abord la boîte de dialogue, puis on supprime au tour suivant.
                oneOffToComplete = nil
                DispatchQueue.main.async { markDone(d) }
            }
        } message: { _ in
            Text("Cette échéance ponctuelle sera supprimée.")
        }
        .sheet(item: $editing) { DeadlineFormView(car: car, deadline: $0).tracksSheetPresentation() }
        .sheet(isPresented: $creating) { DeadlineFormView(car: car, deadline: nil).tracksSheetPresentation() }
    }

    /// Annuelle : avance d'un an. Ponctuelle : supprimée.
    private func markDone(_ d: Deadline) {
        let id = d.uuid
        guard !justDone.contains(id) else { return }
        justDone.insert(id)
        Task {
            try? await Task.sleep(for: .seconds(1))
            justDone.remove(id)
        }
        do {
            if d.markDone() { try DeletionService.saveOrRollback(context) }
            else { try DeletionService.delete(d, in: context) }
        } catch { appState.errorMessage = "Enregistrement impossible : \(error.localizedDescription)" }
    }

    private func remove(_ d: Deadline) {
        do { try DeletionService.delete(d, in: context) }
        catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }
}

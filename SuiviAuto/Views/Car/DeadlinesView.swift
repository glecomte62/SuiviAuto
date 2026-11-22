import SwiftData
import SwiftUI

struct DeadlinesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editing: Deadline?
    @State private var creating = false
    /// Échéance dont on saisit l'intervention (« Fait ✓… »).
    @State private var completing: Deadline?
    @State private var deleting: Deadline?

    private struct Row: Identifiable {
        let deadline: Deadline
        let due: DeadlineDue
        var id: PersistentIdentifier { deadline.persistentModelID }
    }

    private func rows() -> [Row] {
        let estimator = CarAnalytics.estimator(for: car)
        return car.deadlines
            .map { d in
                Row(deadline: d, due: DeadlineScheduler.due(mode: d.mode, dueDate: d.dueDate, targetMileage: d.targetMileage,
                                                            estimator: estimator, now: .now))
            }
            .sorted { DeadlineText.sortKey($0.due) < DeadlineText.sortKey($1.due) }
    }

    var body: some View {
        List {
            ForEach(rows()) { row in
                let d = row.deadline
                HStack(spacing: 10) {
                    Image(systemName: d.mode == .km ? "speedometer" : "calendar")
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(row.due.status.color.gradient)
                            .shadow(color: row.due.status.color.opacity(0.4), radius: 2, y: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(d.label).fontWeight(.semibold)
                            if !d.documents.isEmpty {
                                Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary)
                                    .accessibilityLabel("Documents joints")
                            }
                        }
                        Text(DeadlineText.detail(mode: d.mode, dueDate: d.dueDate, repeatsYearly: d.repeatsYearly,
                                                 intervalKm: d.intervalKm, due: row.due))
                            .font(.caption).foregroundStyle(.secondary)
                        if !d.notes.isEmpty { Text(d.notes).font(.caption) }
                    }
                    Spacer()
                    StatusBadge(status: row.due.status)
                    Button("Fait ✓…") { completing = d }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Marquer comme fait…")
                        .help("Saisir l'intervention correspondante : l'échéance sera validée à son enregistrement")
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editing = d }
                .contextMenu {
                    Button("Modifier") { editing = d }
                    Button("Supprimer", role: .destructive) { deleting = d }
                }
            }
        }
        .overlay {
            if car.deadlines.isEmpty {
                ContentUnavailableView("Aucune échéance", systemImage: "calendar.badge.clock",
                                       description: Text("Assurance, pneus hiver, courroie à 90 000 km…"))
            }
        }
        .toolbar {
            Button { creating = true } label: { Label("Nouvelle échéance", systemImage: "plus") }
        }
        .confirmationDialog("Supprimer « \(deleting?.label ?? "") » ?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { d in
            Button("Supprimer", role: .destructive) {
                // On ferme d'abord la boîte de dialogue, puis on supprime au tour suivant.
                deleting = nil
                DispatchQueue.main.async { remove(d) }
            }
        } message: { d in
            Text(d.documents.isEmpty
                 ? "Cette échéance sera supprimée."
                 : "Cette échéance et ses \(d.documents.count) document(s) joint(s) seront supprimés.")
        }
        .sheet(item: $editing) { DeadlineFormView(car: car, deadline: $0).tracksSheetPresentation() }
        .sheet(isPresented: $creating) { DeadlineFormView(car: car, deadline: nil).tracksSheetPresentation() }
        .sheet(item: $completing) { d in
            InterventionFormView(car: car, intervention: nil, prefillDeadline: d).tracksSheetPresentation()
        }
    }

    private func remove(_ d: Deadline) {
        do { try DeletionService.delete(d, in: context) }
        catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }
}

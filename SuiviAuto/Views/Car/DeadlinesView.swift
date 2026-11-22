import SwiftData
import SwiftUI

struct DeadlinesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @State private var editing: Deadline?
    @State private var creating = false

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
                    Button(d.repeatsYearly ? "Fait ✓ (+1 an)" : "Fait ✓") { markDone(d) }
                        .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editing = d }
                .contextMenu {
                    Button("Modifier") { editing = d }
                    Button("Supprimer", role: .destructive) { context.delete(d); try? context.save() }
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
        .sheet(item: $editing) { DeadlineFormView(car: car, deadline: $0) }
        .sheet(isPresented: $creating) { DeadlineFormView(car: car, deadline: nil) }
    }

    /// Annuelle : avance d'un an. Ponctuelle : supprimée.
    private func markDone(_ d: Deadline) {
        if !d.markDone() { context.delete(d) }
        try? context.save()
    }
}

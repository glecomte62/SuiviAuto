import SwiftData
import SwiftUI

struct DeadlineFormView: View {
    let car: Car
    let deadline: Deadline?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var dueDate = Date.now
    @State private var repeatsYearly = true
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(deadline == nil ? "Nouvelle échéance" : "Modifier l'échéance").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                TextField("Libellé", text: $label, prompt: Text("ex. Assurance, pneus hiver, fin de garantie"))
                DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                Toggle("Se répète chaque année", isOn: $repeatsYearly)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 440)
        .onAppear {
            if let deadline {
                label = deadline.label; dueDate = deadline.dueDate; repeatsYearly = deadline.repeatsYearly; notes = deadline.notes
            }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let target: Deadline
        if let deadline {
            target = deadline
        } else {
            target = Deadline(label: label, dueDate: dueDate, repeatsYearly: repeatsYearly)
            context.insert(target)
            target.car = car
        }
        target.label = label.trimmingCharacters(in: .whitespaces)
        target.dueDate = dueDate
        target.repeatsYearly = repeatsYearly
        target.notes = notes
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}

import SwiftData
import SwiftUI

struct RuleFormView: View {
    let car: Car
    let rule: MaintenanceRule?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var intervalKm: Int?
    @State private var intervalMonths: Int?
    @State private var errorMessage: String?

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
        && ((intervalKm ?? 0) > 0 || (intervalMonths ?? 0) > 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rule == nil ? "Nouvelle règle d'entretien" : "Modifier la règle").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                TextField("Nom", text: $label, prompt: Text("ex. Filtre à air"))
                TextField("Tous les … km", value: $intervalKm, format: .number, prompt: Text("facultatif"))
                TextField("Tous les … mois", value: $intervalMonths, format: .number, prompt: Text("facultatif"))
                Text("Renseignez au moins un des deux intervalles. Le premier atteint déclenche l'alerte.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }.keyboardShortcut(.defaultAction).disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420)
        .onAppear {
            if let rule { label = rule.label; intervalKm = rule.intervalKm; intervalMonths = rule.intervalMonths }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let km = (intervalKm ?? 0) > 0 ? intervalKm : nil
        let months = (intervalMonths ?? 0) > 0 ? intervalMonths : nil
        let name = label.trimmingCharacters(in: .whitespaces)
        if let rule {
            rule.label = name; rule.intervalKm = km; rule.intervalMonths = months
        } else {
            let key = MaintenanceRule.makeKey(label: name, existing: Set(car.rules.map(\.key)))
            let r = MaintenanceRule(key: key, label: name, intervalKm: km, intervalMonths: months)
            context.insert(r)
            r.car = car
        }
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}

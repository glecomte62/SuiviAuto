import SwiftData
import SwiftUI

struct ReadingFormView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var mileageText = ""
    @State private var showWarning = false
    @State private var errorMessage: String?

    /// nil si vide ou invalide (négatif, lettres…) : Enregistrer reste désactivé.
    private var mileage: Int? { NumberInput.parseInt(mileageText) }

    private var lastKnown: Int? { CarAnalytics.lastKnownMileage(for: car, onOrBefore: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nouveau relevé km — \(car.name)").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Kilométrage", text: $mileageText,
                          prompt: Text(lastKnown.map { "dernier : \(Fmt.km($0))" } ?? "km"))
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") {
                    if let m = mileage, let last = lastKnown, m < last { showWarning = true } else { save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mileage == nil)
            }
            .padding()
        }
        .frame(width: 420)
        .confirmationDialog("Kilométrage inférieur au dernier connu", isPresented: $showWarning) {
            Button("Enregistrer quand même") { save() }
            Button("Corriger", role: .cancel) {}
        } message: { Text("Le dernier kilométrage connu est \(Fmt.km(lastKnown ?? 0)).") }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let r = OdometerReading(date: date, mileage: mileage ?? 0)
        context.insert(r)
        r.car = car
        do {
            try DeletionService.saveOrRollback(context)
            dismiss()
        } catch {
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }
}

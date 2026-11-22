import SwiftData
import SwiftUI

struct DeadlineFormView: View {
    let car: Car
    let deadline: Deadline?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var mode: DeadlineMode = .date
    @State private var dueDate = Date.now
    @State private var repeatsYearly = true
    @State private var targetMileageText = ""
    @State private var intervalKmText = ""
    @State private var notes = ""
    @State private var pending = PendingAttachments()
    /// Documents existants retirés : supprimés seulement à l'enregistrement (« Annuler » les conserve).
    @State private var removedExisting: [StoredDocument] = []
    @State private var saved = false
    @State private var loaded = false
    @State private var errorMessage: String?
    /// Empêche un double enregistrement (double clic, Entrée répétée).
    @State private var saving = false

    private var targetMileage: Int? { NumberInput.parseInt(targetMileageText) }
    private var intervalKm: Int? { NumberInput.parseInt(intervalKmText) }

    private var isValid: Bool {
        guard !label.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard mode == .km else { return true }
        let intervalBlankOrValid = intervalKmText.trimmingCharacters(in: .whitespaces).isEmpty || intervalKm != nil
        return targetMileage != nil && intervalBlankOrValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(deadline == nil ? "Nouvelle échéance" : "Modifier l'échéance").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                Section {
                    TextField("Libellé", text: $label, prompt: Text("ex. Assurance, pneus hiver, courroie"))
                    Picker("Type d'échéance", selection: $mode) {
                        ForEach(DeadlineMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .date:
                        DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                        Toggle("Se répète chaque année", isOn: $repeatsYearly)
                    case .km:
                        TextField("Kilométrage cible", text: $targetMileageText, prompt: Text("obligatoire, ex. 90 000"))
                        TextField("Puis tous les … km (facultatif)", text: $intervalKmText, prompt: Text("ex. 15 000"))
                        Text("Kilométrage estimé aujourd'hui : "
                             + (CarAnalytics.estimator(for: car).estimatedCurrentMileage.map(Fmt.km) ?? "inconnu"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                }
                AttachmentsSection(pending: pending,
                                   existing: (deadline?.documents ?? []).filter { doc in !removedExisting.contains { $0 === doc } },
                                   onDeleteExisting: { removedExisting.append($0) })
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) {
                    pending.discard()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid || saving)
            }
            .padding()
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: 480, minHeight: 340, idealHeight: 480, maxHeight: 680)
        .onAppear(perform: load)
        .onDisappear { if !saved { pending.discard() } }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let deadline else { return }
        label = deadline.label; mode = deadline.mode; dueDate = deadline.dueDate
        repeatsYearly = deadline.repeatsYearly; notes = deadline.notes
        targetMileageText = deadline.targetMileage.map(String.init) ?? ""
        intervalKmText = deadline.intervalKm.map(String.init) ?? ""
    }

    private func save() {
        guard !saving else { return }
        if let deadline, !DeadlineService.isStillPresent(deadline, in: car) {
            errorMessage = DeadlineService.changedElsewhereMessage
            return
        }
        let target: Deadline
        if let deadline {
            target = deadline
        } else {
            target = Deadline(label: label, dueDate: dueDate, repeatsYearly: repeatsYearly)
            context.insert(target)
            target.car = car
        }
        target.label = label.trimmingCharacters(in: .whitespaces)
        target.mode = mode
        target.notes = notes
        switch mode {
        case .date:
            target.dueDate = dueDate
            target.repeatsYearly = repeatsYearly
            target.targetMileage = nil
            target.intervalKm = nil
        case .km:
            target.targetMileage = targetMileage
            target.intervalKm = (intervalKm ?? 0) > 0 ? intervalKm : nil
            target.repeatsYearly = false
        }
        saving = true
        let attached = pending.attach(to: target, in: context)
        do {
            try DeletionService.save(context, deleting: removedExisting)
            removedExisting = []
            saved = true
            dismiss()
        } catch {
            // Rollback déjà fait : les documents ajoutés repassent en attente, les retraits restent à appliquer.
            pending.restore(attached)
            saving = false
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }
}

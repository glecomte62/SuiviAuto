import SwiftData
import SwiftUI

/// Choix du garage dans le formulaire.
enum GarageChoice: Hashable {
    case none
    case legacyText          // ancien nom texte non converti, conservé tel quel
    case garage(Garage)
}

struct InterventionFormView: View {
    let car: Car
    let intervention: Intervention?
    /// Pré-saisie depuis « Fait ✓… » d'une échéance (création uniquement).
    var prefillDeadline: Deadline? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var garages: [Garage]

    @State private var date = Date.now
    @State private var mileageText = ""
    @State private var kind: InterventionKind = .entretien
    @State private var title = ""
    @State private var garageChoice: GarageChoice = .none
    @State private var creatingGarage = false
    @State private var amountText = ""
    @State private var status: InterventionStatus = .facture
    @State private var notes = ""
    @State private var ctResult: CTResult = .favorable
    @State private var ruleKey = ""
    @State private var showLowMileageWarning = false
    @State private var operations: Set<MaintenanceOperation> = []
    @State private var customOperation = ""
    /// Échéance à solder à CET enregistrement (jamais mémorisée : un nouvel enregistrement ne la solde pas deux fois).
    @State private var completingDeadline: Deadline?
    /// État de l'échéance au moment où elle a été choisie : une validation faite ailleurs entre-temps est refusée.
    @State private var completingSnapshot: DeadlineSnapshot?
    @State private var pending = PendingAttachments()
    @State private var showingDetected = false
    @State private var extraction: InvoiceExtraction?
    @State private var analysisID = UUID()
    @State private var saved = false
    @State private var errorMessage: String?
    /// `onAppear` se redéclenche à la fermeture d'une feuille imbriquée : ne charger qu'une fois.
    @State private var loaded = false

    /// Texte brut converti à la volée (voir `NumberInput`).
    private var mileage: Int? { NumberInput.parseInt(mileageText) }

    private var lastKnown: Int? {
        CarAnalytics.lastKnownMileage(for: car, onOrBefore: date, excluding: intervention)
    }

    private var ruleKeys: Set<String> { Set(car.rules.map(\.key)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(intervention == nil ? "Nouvelle intervention" : "Modifier l'intervention")
                .font(.title2.bold()).padding([.top, .horizontal])
            if showingDetected {
                DetectedValuesBanner(extraction: extraction, onApply: applyExtraction, onDismiss: dismissExtraction)
                    .padding([.top, .horizontal])
            }
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(InterventionKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Statut", selection: $status) {
                        ForEach(InterventionStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Titre", text: $title, prompt: Text("ex. Vidange + filtres"))
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Kilométrage", text: $mileageText, prompt: Text(lastKnown.map { "dernier : \(Fmt.km($0))" } ?? "km"))
                    HStack {
                        Picker("Garage", selection: $garageChoice) {
                            Text("Aucun").tag(GarageChoice.none)
                            if let legacy = intervention?.garage, intervention?.garageRef == nil,
                               !Garage.cleanedName(legacy).isEmpty {
                                Text("\(Garage.cleanedName(legacy)) (texte)").tag(GarageChoice.legacyText)
                            }
                            if !garages.isEmpty { Divider() }
                            ForEach(GarageService.sorted(garages)) { Text($0.name).tag(GarageChoice.garage($0)) }
                        }
                        Button("Nouveau garage…") { creatingGarage = true }
                    }
                    TextField("Montant (€)", text: $amountText, prompt: Text("ex. 189,90"))
                }
                Section("Opérations") {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                              alignment: .leading, spacing: 6) {
                        ForEach(MaintenanceOperation.allCases.filter { $0 != .autre }) { op in
                            Toggle(isOn: operationBinding(op)) { Label(op.label, systemImage: op.symbol) }
                                .toggleStyle(.checkbox)
                        }
                    }
                    TextField("Autre opération", text: $customOperation, prompt: Text("ex. Essuie-glaces"))
                }
                Section {
                    if kind == .controleTechnique {
                        Picker("Résultat du CT", selection: $ctResult) {
                            ForEach(CTResult.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    Picker("Règle d'entretien", selection: $ruleKey) {
                        Text("Aucune").tag("")
                        ForEach(car.rules.sorted { $0.label < $1.label }) { Text($0.label).tag($0.key) }
                    }
                    .help("Relie cette intervention à une règle pour recalculer la prochaine échéance")
                    Picker("Solde l'échéance", selection: $completingDeadline) {
                        Text("Aucune").tag(Deadline?.none)
                        let deadlines = car.deadlines.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
                        if !deadlines.isEmpty { Divider() }
                        ForEach(deadlines) { d in
                            Text("\(d.label) (\(DeadlineText.target(mode: d.mode, dueDate: d.dueDate, targetMileage: d.targetMileage)))")
                                .tag(Optional(d))
                        }
                    }
                    .help("À l'enregistrement, l'échéance est validée et ses documents rejoignent cette intervention")
                    .disabled(status == .devis)
                    if status == .devis && completingDeadline != nil {
                        Text("Un devis ne solde pas l'échéance : passez le statut à « Facture ».")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                AttachmentsSection(pending: pending, onAnalyze: analyze)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) {
                    pending.discard()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(mileage == nil)
            }
            .padding()
        }
        .frame(width: 560)
        .onAppear(perform: load)
        .onChange(of: completingDeadline) { _, new in completingSnapshot = new.map(DeadlineSnapshot.init) }
        // Ignoré quand c'est la feuille « Nouveau garage » qui masque ce formulaire.
        .onDisappear { if !saved && !creatingGarage { pending.discard() } }
        .confirmationDialog("Kilométrage inférieur au dernier connu", isPresented: $showLowMileageWarning) {
            Button("Enregistrer quand même") { save() }
            Button("Corriger", role: .cancel) {}
        } message: {
            Text("Le dernier kilométrage connu à cette date est \(Fmt.km(lastKnown ?? 0)).")
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: $creatingGarage) {
            GarageFormView(garage: nil) { newGarage in
                // Après la mise à jour de @Query, pour que le Picker connaisse déjà ce garage.
                DispatchQueue.main.async { garageChoice = .garage(newGarage) }
            }
                .tracksSheetPresentation()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let i = intervention else {
            if let d = prefillDeadline {
                title = d.label
                for op in MaintenanceOperation.detect(in: d.label) { setOperation(op, checked: true) }
                completingDeadline = d
                completingSnapshot = DeadlineSnapshot(d)
            }
            return
        }
        date = i.date; mileageText = String(i.mileage); kind = i.kind; title = i.title
        if let linked = i.garageRef {
            garageChoice = .garage(linked)
        } else if !Garage.cleanedName(i.garage).isEmpty {
            garageChoice = .legacyText
        }
        amountText = i.amountCents.map(Money.editString(cents:)) ?? ""
        status = i.status; notes = i.notes; ctResult = i.ctResult ?? .favorable; ruleKey = i.ruleKey ?? ""
        operations = Set(i.operations); customOperation = i.customOperation
        // Règle supprimée entre-temps : on évite une sélection invalide dans le Picker.
        if !car.rules.contains(where: { $0.key == ruleKey }) { ruleKey = "" }
    }

    private func attemptSave() {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && Money.parse(trimmed) == nil {
            errorMessage = "Montant invalide. Exemple : 189,90"
            return
        }
        if let m = mileage, let last = lastKnown, m < last {
            showLowMileageWarning = true
        } else {
            save()
        }
    }

    private func save() {
        if let deadline = completingDeadline {
            guard let snapshot = completingSnapshot,
                  DeadlineService.isStillPending(deadline, snapshot: snapshot, in: car) else {
                completingDeadline = nil
                errorMessage = DeadlineService.changedElsewhereMessage
                return
            }
        }
        let target: Intervention
        if let intervention {
            target = intervention
        } else {
            target = Intervention(date: date, mileage: mileage ?? 0, kind: kind)
            context.insert(target)
            target.car = car
        }
        target.date = date
        target.mileage = mileage ?? 0
        target.kind = kind
        target.title = title.trimmingCharacters(in: .whitespaces)
        switch garageChoice {
        case .none:
            target.garageRef = nil
            target.garage = ""
            target.garageTextMigrated = true
        case .legacyText:
            break // texte conservé tel quel
        case .garage(let chosen):
            target.garageRef = chosen
            target.garage = "" // le texte n'est gardé que tant qu'aucun garage n'est choisi
            target.garageTextMigrated = true
        }
        target.amountCents = Money.parse(amountText)
        target.status = status
        target.notes = notes
        target.ctResult = kind == .controleTechnique ? ctResult : nil
        target.ruleKey = ruleKey.isEmpty ? nil : ruleKey
        target.operations = InterventionDraft.storedOperations(operations, custom: customOperation)
        target.customOperation = customOperation.trimmingCharacters(in: .whitespacesAndNewlines)
        let attached = pending.attach(to: target, in: context)
        do {
            if let deadline = completingDeadline, status == .facture {
                try DeadlineService.complete(deadline, with: target, in: context)
            } else {
                try DeletionService.saveOrRollback(context)
            }
            completingDeadline = nil
            saved = true
            dismiss()
        } catch {
            // `complete` peut échouer avant d'enregistrer : on annule aussi dans ce cas (sans effet si déjà fait).
            context.rollback()
            // Les documents insérés ont disparu avec le rollback : on les remet en attente pour un nouvel essai.
            pending.restore(attached)
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - Opérations

    private func operationBinding(_ op: MaintenanceOperation) -> Binding<Bool> {
        Binding(get: { operations.contains(op) }, set: { setOperation(op, checked: $0) })
    }

    private func setOperation(_ op: MaintenanceOperation, checked: Bool) {
        if checked {
            operations.insert(op)
            ruleKey = InterventionDraft.ruleKey(afterChecking: op, current: ruleKey, available: ruleKeys)
        } else {
            operations.remove(op)
        }
    }

    // MARK: - Lecture automatique

    private func analyze(_ url: URL) {
        let id = UUID()
        analysisID = id
        extraction = nil
        showingDetected = true
        Task {
            let result = (try? await InvoiceOCRService.analyze(fileAt: url)) ?? InvoiceExtraction()
            // Une analyse plus récente (ou « Ignorer ») a pris le relais.
            guard analysisID == id, showingDetected else { return }
            extraction = result
        }
    }

    private func applyExtraction() {
        guard let extraction else { return }
        let fields = InterventionDraft.apply(
            extraction,
            to: .init(date: date, mileageText: mileageText, amountText: amountText, operations: operations, ruleKey: ruleKey),
            availableRuleKeys: ruleKeys)
        date = fields.date; mileageText = fields.mileageText; amountText = fields.amountText
        operations = fields.operations; ruleKey = fields.ruleKey
        dismissExtraction()
    }

    private func dismissExtraction() {
        analysisID = UUID()
        showingDetected = false
        extraction = nil
    }
}

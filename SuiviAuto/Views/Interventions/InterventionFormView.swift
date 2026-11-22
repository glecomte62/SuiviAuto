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
    @State private var errorMessage: String?
    /// `onAppear` se redéclenche à la fermeture d'une feuille imbriquée : ne charger qu'une fois.
    @State private var loaded = false

    /// Texte brut converti à la volée (voir `NumberInput`).
    private var mileage: Int? { NumberInput.parseInt(mileageText) }

    private var lastKnown: Int? {
        CarAnalytics.lastKnownMileage(for: car, onOrBefore: date, excluding: intervention)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(intervention == nil ? "Nouvelle intervention" : "Modifier l'intervention")
                .font(.title2.bold()).padding([.top, .horizontal])
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
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(mileage == nil)
            }
            .padding()
        }
        .frame(width: 500)
        .onAppear(perform: load)
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
        guard let i = intervention else { return }
        date = i.date; mileageText = String(i.mileage); kind = i.kind; title = i.title
        if let linked = i.garageRef {
            garageChoice = .garage(linked)
        } else if !Garage.cleanedName(i.garage).isEmpty {
            garageChoice = .legacyText
        }
        amountText = i.amountCents.map(Money.editString(cents:)) ?? ""
        status = i.status; notes = i.notes; ctResult = i.ctResult ?? .favorable; ruleKey = i.ruleKey ?? ""
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
        do {
            try DeletionService.saveOrRollback(context)
            dismiss()
        } catch {
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }
}

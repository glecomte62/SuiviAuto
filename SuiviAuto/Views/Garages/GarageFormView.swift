import SwiftData
import SwiftUI

struct GarageFormView: View {
    let garage: Garage?
    var onCreated: ((Garage) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allGarages: [Garage]

    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var openingHours = ""
    @State private var specialties = ""
    @State private var rating = 0
    @State private var review = ""
    @State private var errorMessage: String?

    private var cleanedName: String { Garage.cleanedName(name) }
    private var isDuplicate: Bool {
        GarageService.hasDuplicateName(cleanedName, among: allGarages, excluding: garage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(garage == nil ? "Nouveau garage" : "Modifier le garage")
                .font(.title2.bold()).padding([.top, .horizontal])
            Form {
                Section {
                    TextField("Nom", text: $name, prompt: Text("ex. Garage du Nord"))
                    if isDuplicate {
                        Label("Un garage porte déjà ce nom.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("Coordonnées") {
                    TextField("Adresse", text: $address, axis: .vertical).lineLimit(2...4)
                    TextField("Téléphone", text: $phone)
                    TextField("E-mail", text: $email)
                    TextField("Site web", text: $website, prompt: Text("ex. garage-du-nord.fr"))
                }
                Section("Infos pratiques") {
                    TextField("Horaires", text: $openingHours, prompt: Text("ex. Lun-ven 8h-12h / 14h-18h"), axis: .vertical)
                        .lineLimit(1...4)
                    TextField("Spécialités / marques", text: $specialties, prompt: Text("ex. Renault, pneus, carrosserie"))
                }
                Section("Mon avis") {
                    LabeledContent("Note") { StarRating(rating: $rating, size: 18) }
                    TextField("Avis", text: $review, prompt: Text("Accueil, prix, délais…"), axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleanedName.isEmpty)
            }
            .padding()
        }
        .frame(width: 500)
        .onAppear(perform: load)
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        guard let garage else { return }
        name = garage.name; address = garage.address; phone = garage.phone; email = garage.email
        website = garage.website; openingHours = garage.openingHours; specialties = garage.specialties
        rating = garage.rating; review = garage.review
    }

    private func save() {
        let target: Garage
        if let garage {
            target = garage
        } else {
            target = Garage(name: cleanedName)
            context.insert(target)
        }
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        target.name = cleanedName
        target.address = trim(address)
        target.phone = trim(phone)
        target.email = trim(email)
        target.website = trim(website)
        target.openingHours = trim(openingHours)
        target.specialties = trim(specialties)
        target.rating = rating
        target.review = trim(review)
        do {
            try DeletionService.saveOrRollback(context)
            if garage == nil { onCreated?(target) }
            dismiss()
        } catch {
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }
}

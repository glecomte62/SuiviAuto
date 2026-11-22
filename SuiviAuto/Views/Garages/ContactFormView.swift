import SwiftData
import SwiftUI

struct ContactFormView: View {
    let garage: Garage
    let contact: GarageContact?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var mobile = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    private var cleanedName: String { Garage.cleanedName(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(contact == nil ? "Nouveau contact — \(garage.name)" : "Modifier le contact")
                .font(.title2.bold()).padding([.top, .horizontal])
            Form {
                TextField("Nom", text: $name, prompt: Text("ex. Paul Martin"))
                HStack {
                    TextField("Fonction", text: $role, prompt: Text("ex. Chef d'atelier"))
                    Menu {
                        ForEach(GarageContact.suggestedRoles, id: \.self) { suggestion in
                            Button(suggestion) { role = suggestion }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Fonctions courantes")
                    .accessibilityLabel("Fonctions courantes")
                }
                TextField("Téléphone direct", text: $phone)
                TextField("Portable", text: $mobile)
                TextField("E-mail", text: $email)
                TextField("Notes", text: $notes, prompt: Text("ex. présent le matin, demander de sa part"), axis: .vertical)
                    .lineLimit(2...4)
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
        .frame(width: 460)
        .onAppear {
            if let contact {
                name = contact.name; role = contact.role; phone = contact.phone
                mobile = contact.mobile; email = contact.email; notes = contact.notes
            }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let target: GarageContact
        if let contact {
            target = contact
        } else {
            target = GarageContact(name: cleanedName)
            context.insert(target)
            target.garage = garage
        }
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        target.name = cleanedName
        target.role = trim(role)
        target.phone = trim(phone)
        target.mobile = trim(mobile)
        target.email = trim(email)
        target.notes = trim(notes)
        do {
            try DeletionService.saveOrRollback(context)
            dismiss()
        } catch {
            errorMessage = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }
}

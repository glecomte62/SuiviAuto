import SwiftData
import SwiftUI

/// Colonne du milieu : fiche du garage et ses contacts.
struct GarageContentView: View {
    @Bindable var garage: Garage
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var creatingContact = false
    @State private var editingContact: GarageContact?
    @State private var contactToDelete: GarageContact?

    private var hasCoordinates: Bool {
        !(garage.address.isEmpty && garage.phone.isEmpty && garage.email.isEmpty && garage.website.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if hasCoordinates { coordinatesCard }
                if !garage.openingHours.isEmpty { textCard("Horaires", symbol: "clock.fill", text: garage.openingHours, tint: .indigo) }
                if !garage.specialties.isEmpty { textCard("Spécialités / marques", symbol: "tag.fill", text: garage.specialties, tint: .purple) }
                if !garage.review.isEmpty { textCard("Mon avis", symbol: "text.bubble.fill", text: garage.review, tint: .yellow) }
                contactsCard
            }
            .padding(14)
        }
        .navigationTitle(garage.name)
        .toolbar {
            ToolbarItemGroup {
                Button { editing = true } label: { Label("Modifier", systemImage: "pencil") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
            }
        }
        .sheet(isPresented: $editing) { GarageFormView(garage: garage).tracksSheetPresentation() }
        .sheet(isPresented: $creatingContact) { ContactFormView(garage: garage, contact: nil).tracksSheetPresentation() }
        .sheet(item: $editingContact) { ContactFormView(garage: garage, contact: $0).tracksSheetPresentation() }
        .confirmationDialog("Supprimer « \(garage.name) » ?", isPresented: $confirmDelete) {
            Button("Supprimer le garage", role: .destructive) { onDelete() }
        } message: {
            Text("\(garage.interventions.count) intervention(s) liée(s) garderont le nom du garage. Ses \(garage.contacts.count) contact(s) seront supprimés.")
        }
        .confirmationDialog("Supprimer ce contact ?",
                            isPresented: Binding(get: { contactToDelete != nil }, set: { if !$0 { contactToDelete = nil } }),
                            presenting: contactToDelete) { contact in
            Button("Supprimer « \(contact.name) »", role: .destructive) {
                let target = contact
                contactToDelete = nil
                DispatchQueue.main.async {
                    do { try DeletionService.deleteRecord(target, in: context) }
                    catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
                }
            }
        }
    }

    private var header: some View {
        Card(tint: .orange) {
            HStack(spacing: 14) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.gradient)
                        .shadow(color: .orange.opacity(0.5), radius: 5, y: 3))
                VStack(alignment: .leading, spacing: 6) {
                    Text(garage.name).font(.title2.bold())
                    StarRating(rating: Binding(get: { garage.rating }, set: { garage.rating = $0; save() }), size: 18)
                }
                Spacer()
            }
        }
    }

    private var coordinatesCard: some View {
        Card(tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Coordonnées").font(.headline)
                if !garage.address.isEmpty {
                    InfoActionRow(symbol: "mappin.and.ellipse", text: garage.address,
                                  actionLabel: "Itinéraire", url: ContactLinks.mapsURL(garage.address))
                }
                if !garage.phone.isEmpty {
                    InfoActionRow(symbol: "phone.fill", text: garage.phone,
                                  actionLabel: "Appeler", url: ContactLinks.phoneURL(garage.phone))
                }
                if !garage.email.isEmpty {
                    InfoActionRow(symbol: "envelope.fill", text: garage.email,
                                  actionLabel: "Écrire", url: ContactLinks.mailURL(garage.email))
                }
                if !garage.website.isEmpty {
                    InfoActionRow(symbol: "globe", text: garage.website,
                                  actionLabel: "Site web", url: ContactLinks.webURL(garage.website))
                }
            }
        }
    }

    private func textCard(_ title: String, symbol: String, text: String, tint: Color) -> some View {
        Card(tint: tint) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: symbol).font(.headline)
                Text(text).textSelection(.enabled)
            }
        }
    }

    private var contactsCard: some View {
        Card(tint: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Contacts", systemImage: "person.2.fill").font(.headline)
                    Spacer()
                    Button { creatingContact = true } label: { Label("Nouveau contact", systemImage: "plus") }
                }
                if garage.contacts.isEmpty {
                    Text("Ajoutez la réception, le chef d'atelier, votre mécanicien…")
                        .foregroundStyle(.secondary)
                }
                ForEach(garage.contacts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { contact in
                    ContactRow(contact: contact)
                        .onTapGesture(count: 2) { editingContact = contact }
                        .contextMenu {
                            Button("Modifier") { editingContact = contact }
                            if !contact.phone.isEmpty { Button("Copier le téléphone") { Pasteboard.copy(contact.phone) } }
                            if !contact.mobile.isEmpty { Button("Copier le portable") { Pasteboard.copy(contact.mobile) } }
                            if !contact.email.isEmpty { Button("Copier l'e-mail") { Pasteboard.copy(contact.email) } }
                            Divider()
                            Button("Supprimer", role: .destructive) { contactToDelete = contact }
                        }
                    Divider()
                }
                if !garage.contacts.isEmpty {
                    Text("Double-clic pour modifier · clic droit pour copier ou supprimer")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        do { try DeletionService.saveOrRollback(context) }
        catch { appState.errorMessage = "Enregistrement impossible : \(error.localizedDescription)" }
    }
}

/// Ligne « icône · texte · bouton d'action », avec « Copier » au clic droit.
struct InfoActionRow: View {
    let symbol: String
    let text: String
    let actionLabel: String
    let url: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 20)
                .accessibilityHidden(true)
            Text(text).textSelection(.enabled)
            Spacer()
            if let url {
                Button(actionLabel) { NSWorkspace.shared.open(url) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .contextMenu { Button("Copier") { Pasteboard.copy(text) } }
    }
}

struct ContactRow: View {
    let contact: GarageContact

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.teal.gradient)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name).fontWeight(.semibold)
                if !contact.role.isEmpty {
                    Text(contact.role).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if !contact.phone.isEmpty { Label(contact.phone, systemImage: "phone") }
                    if !contact.mobile.isEmpty { Label(contact.mobile, systemImage: "iphone") }
                    if !contact.email.isEmpty { Label(contact.email, systemImage: "envelope") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                if !contact.notes.isEmpty {
                    Text(contact.notes).font(.caption).italic()
                }
            }
            Spacer()
            HStack(spacing: 6) {
                if let url = ContactLinks.phoneURL(contact.phone) {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "phone.fill") }
                        .help("Appeler le téléphone direct").accessibilityLabel("Appeler le téléphone direct")
                }
                if let url = ContactLinks.phoneURL(contact.mobile) {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "iphone") }
                        .help("Appeler le portable").accessibilityLabel("Appeler le portable")
                }
                if let url = ContactLinks.mailURL(contact.email) {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "envelope.fill") }
                        .help("Écrire").accessibilityLabel("Écrire un e-mail")
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.teal)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct InterventionDetailView: View {
    @Bindable var intervention: Intervention
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var importing = false
    @State private var dropTargeted = false
    @State private var previewURL: URL?
    @State private var selectedDoc: StoredDocument?
    @FocusState private var gridFocused: Bool

    private var tint: Color { Color(hex: intervention.car?.colorHex ?? "#2E86AB") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                infoCard
                documentsCard
            }
            .padding(20)
        }
        .dropDestination(for: URL.self) { urls, _ in
            importFiles(urls)
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .quickLookPreview($previewURL)
        .toolbar {
            ToolbarItemGroup {
                if intervention.status == .devis {
                    Button {
                        intervention.status = .facture
                        save()
                    } label: { Label("Transformer en facture", systemImage: "doc.badge.arrow.up") }
                }
                Button { editing = true } label: { Label("Modifier", systemImage: "pencil") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
            }
        }
        .sheet(isPresented: $editing) {
            if let car = intervention.car {
                InterventionFormView(car: car, intervention: intervention).tracksSheetPresentation()
            }
        }
        .confirmationDialog("Supprimer cette intervention et ses \(intervention.documents.count) document(s) ?",
                            isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) { onDelete() }
        }
    }

    private var header: some View {
        Card(tint: intervention.kind.color) {
            HStack(spacing: 14) {
                Image(systemName: intervention.kind.symbol)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(intervention.kind.color.gradient)
                        .shadow(color: intervention.kind.color.opacity(0.5), radius: 5, y: 3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.displayTitle).font(.title2.bold())
                    HStack {
                        Text(intervention.kind.label).foregroundStyle(.secondary)
                        StatusPill(text: intervention.status.label, color: intervention.status == .devis ? .purple : .blue)
                    }
                }
                Spacer()
                if let cents = intervention.amountCents {
                    Text(Money.format(cents: cents))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
    }

    private var infoCard: some View {
        Card(tint: tint) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                infoRow("Date", Fmt.date(intervention.date))
                infoRow("Kilométrage", Fmt.km(intervention.mileage))
                if !intervention.garageDisplayName.isEmpty { infoRow("Garage", intervention.garageDisplayName) }
                if let r = intervention.ctResult { infoRow("Résultat CT", r.label) }
                if let key = intervention.ruleKey,
                   let rule = intervention.car?.rules.first(where: { $0.key == key }) {
                    infoRow("Règle", rule.label)
                }
                if !intervention.notes.isEmpty { infoRow("Notes", intervention.notes) }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).textSelection(.enabled)
        }
    }

    private var documentsCard: some View {
        Card(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Factures et devis", systemImage: "doc.on.doc.fill").font(.headline)
                    Spacer()
                    Button { importing = true } label: { Label("Ajouter…", systemImage: "plus") }
                }
                if intervention.documents.isEmpty {
                    Text("Glissez ici un PDF ou une photo de la facture ou du devis.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 12)], spacing: 12) {
                        ForEach(intervention.documents.sorted { $0.addedAt < $1.addedAt }) { doc in
                            DocumentThumbnail(document: doc, isSelected: selectedDoc == doc)
                                .onTapGesture(count: 2) {
                                    selectedDoc = doc
                                    open(doc)
                                }
                                .onTapGesture {
                                    selectedDoc = doc
                                    gridFocused = true
                                }
                                .contextMenu {
                                    let missing = !DocumentStore.shared.fileExists(for: doc)
                                    Button("Coup d'œil") { preview(doc) }.disabled(missing)
                                    Button("Ouvrir") { open(doc) }.disabled(missing)
                                    Button("Afficher dans le Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([DocumentStore.shared.url(for: doc)])
                                    }
                                    .disabled(missing)
                                    Divider()
                                    Button("Supprimer", role: .destructive) { deleteDocument(doc) }
                                }
                        }
                    }
                    .focusable()
                    .focused($gridFocused)
                    .focusEffectDisabled()
                    .onKeyPress(.space) {
                        guard let doc = selectedDoc else { return .ignored }
                        preview(doc)
                        return .handled
                    }
                    Text("Barre d'espace : Coup d'œil · Double-clic : ouvrir").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func preview(_ doc: StoredDocument) {
        guard DocumentStore.shared.fileExists(for: doc) else { return }
        previewURL = DocumentStore.shared.url(for: doc)
    }

    private func open(_ doc: StoredDocument) {
        guard DocumentStore.shared.fileExists(for: doc) else { return }
        NSWorkspace.shared.open(DocumentStore.shared.url(for: doc))
    }

    private func deleteDocument(_ doc: StoredDocument) {
        if selectedDoc == doc { selectedDoc = nil }
        do { try DeletionService.delete(doc, in: context) }
        catch { appState.errorMessage = error.localizedDescription }
    }

    /// Retourne true si au moins un fichier a été importé et enregistré.
    @discardableResult
    private func importFiles(_ urls: [URL]) -> Bool {
        var imported: [String] = []
        var rejected: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let doc = try DocumentStore.shared.importFile(at: url)
                context.insert(doc)
                doc.intervention = intervention
                imported.append(doc.fileName)
            } catch {
                rejected.append(error.localizedDescription)
            }
        }
        if !imported.isEmpty {
            do {
                try DeletionService.saveOrRollback(context)
            } catch {
                // Aucun fichier orphelin : les copies non référencées sont supprimées.
                imported.forEach(DocumentStore.shared.delete(fileName:))
                appState.errorMessage = "Import impossible : \(error.localizedDescription)"
                return false
            }
        }
        if !rejected.isEmpty {
            appState.errorMessage = "Non importé(s) :\n" + rejected.joined(separator: "\n")
        }
        return !imported.isEmpty
    }

    private func save() {
        do { try DeletionService.saveOrRollback(context) }
        catch { appState.errorMessage = "Enregistrement impossible : \(error.localizedDescription)" }
    }
}

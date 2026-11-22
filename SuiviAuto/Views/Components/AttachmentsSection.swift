import SwiftUI
import UniformTypeIdentifiers

/// Section de formulaire : pièces jointes en attente d'enregistrement (glisser-déposer ou « Ajouter… »).
struct AttachmentsSection: View {
    let pending: PendingAttachments
    /// nil : pas de bouton « Analyser » ni d'analyse automatique.
    var onAnalyze: ((URL) -> Void)? = nil
    /// Documents déjà enregistrés (modification), avec leur suppression.
    var existing: [StoredDocument] = []
    var onDeleteExisting: ((StoredDocument) -> Void)? = nil

    @State private var importing = false
    @State private var dropTargeted = false
    @State private var rejected: [String] = []
    @State private var analyzedFirst = false

    var body: some View {
        Section {
            ForEach(existing.sorted { $0.addedAt < $1.addedAt }) { doc in
                row(name: doc.originalName, kind: doc.kind, url: DocumentStore.shared.url(for: doc), analyzable: false) {
                    onDeleteExisting?(doc)
                }
            }
            ForEach(pending.documents, id: \.fileName) { doc in
                row(name: doc.originalName, kind: doc.kind, url: pending.url(for: doc), analyzable: true) {
                    pending.remove(doc)
                }
            }
            HStack {
                Button { importing = true } label: { Label("Ajouter…", systemImage: "plus") }
                Spacer()
                Text(existing.isEmpty && pending.isEmpty ? "ou glissez ici un PDF ou une photo" : "ou glissez d'autres fichiers ici")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !rejected.isEmpty {
                Label(rejected.joined(separator: "\n"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        } header: {
            Label("Pièces jointes (devis, factures)", systemImage: "paperclip")
        }
        .dropDestination(for: URL.self) { urls, _ in
            add(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .allowsHitTesting(false)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { add(urls) }
        }
    }

    private func row(name: String, kind: DocumentKind, url: URL, analyzable: Bool,
                     onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .pdf ? "doc.richtext.fill" : "photo.fill")
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill((kind == .pdf ? Color.red : Color.blue).gradient))
            Text(name).lineLimit(1).truncationMode(.middle)
            Spacer()
            if analyzable, let onAnalyze {
                Button { onAnalyze(url) } label: { Label("Analyser", systemImage: "text.viewfinder") }
                    .buttonStyle(.borderless)
                    .help("Lire la date, le montant, le km et les opérations de ce document")
            }
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Retirer ce fichier")
                .accessibilityLabel("Retirer \(name)")
        }
    }

    private func add(_ urls: [URL]) {
        let wasEmpty = pending.isEmpty
        rejected = pending.add(urls: urls)
        // Analyse automatique au premier fichier ajouté dans ce formulaire.
        if wasEmpty, !analyzedFirst, let first = pending.documents.first, let onAnalyze {
            analyzedFirst = true
            onAnalyze(pending.url(for: first))
        }
    }
}

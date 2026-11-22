import QuickLookThumbnailing
import SwiftUI

struct DocumentThumbnail: View {
    let document: StoredDocument
    let isSelected: Bool
    @State private var image: NSImage?

    private var url: URL { DocumentStore.shared.url(for: document) }
    private var exists: Bool { DocumentStore.shared.fileExists(for: document) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                if !exists {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Fichier introuvable").font(.caption2).multilineTextAlignment(.center)
                    }
                } else if let image {
                    Image(nsImage: image).resizable().scaledToFit().padding(4)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 110, height: 130)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3))
            Text(document.originalName)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 110)
        }
        .task(id: document.fileName) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard exists else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 110, height: 130),
                                                   scale: 2, representationTypes: .thumbnail)
        image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        if image == nil { image = NSWorkspace.shared.icon(forFile: url.path) }
    }
}

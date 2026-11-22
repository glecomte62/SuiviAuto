import SwiftUI

/// Encadré « Valeurs détectées » : rien n'est appliqué sans clic sur « Appliquer ».
struct DetectedValuesBanner: View {
    /// nil pendant la lecture.
    let extraction: InvoiceExtraction?
    /// Fichier illisible (distinct de « rien de reconnu »).
    var failureMessage: String? = nil
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.purple.gradient)
                    .shadow(color: .purple.opacity(0.4), radius: 3, y: 2))
            VStack(alignment: .leading, spacing: 6) {
                Text("Valeurs détectées").font(.headline)
                if let failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if let extraction {
                    if extraction.isEmpty {
                        Text("Aucune information reconnue dans ce document").foregroundStyle(.secondary)
                    } else {
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                            if let d = extraction.date { line("Date", Fmt.date(d)) }
                            if let c = extraction.amountCents { line("Montant", Money.format(cents: c)) }
                            if let km = extraction.mileage { line("Kilométrage", Fmt.km(km)) }
                            if !extraction.operations.isEmpty {
                                line("Opérations", extraction.operations.map(\.label).joined(separator: ", "))
                            }
                        }
                        .font(.callout)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Lecture du document…").foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let extraction, !extraction.isEmpty {
                    Button("Appliquer", action: onApply).buttonStyle(.borderedProminent).tint(.purple)
                }
                Button("Ignorer", action: onDismiss)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.purple.opacity(0.1))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.background))
                .shadow(color: .purple.opacity(0.25), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.purple.opacity(0.7), .purple.opacity(0.15)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
    }

    private func line(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value)
        }
    }
}

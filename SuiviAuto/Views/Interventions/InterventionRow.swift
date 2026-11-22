import SwiftUI

struct InterventionRow: View {
    let intervention: Intervention

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: intervention.kind.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(intervention.kind.color.gradient).shadow(color: intervention.kind.color.opacity(0.4), radius: 2, y: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(intervention.displayTitle).fontWeight(.medium).lineLimit(1)
                Text("\(Fmt.shortDate(intervention.date)) · \(Fmt.km(intervention.mileage))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let cents = intervention.amountCents {
                    Text(Money.format(cents: cents)).fontWeight(.semibold).monospacedDigit()
                }
                HStack(spacing: 4) {
                    if !intervention.documents.isEmpty {
                        Image(systemName: "paperclip").font(.caption2).foregroundStyle(.secondary)
                    }
                    StatusPill(text: intervention.status.label, color: intervention.status == .devis ? .purple : .blue)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

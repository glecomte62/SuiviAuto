import SwiftUI

/// Carte en relief : fond, ombre portée, liseré dégradé de la couleur d'accent.
struct Card<Content: View>: View {
    var tint: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [tint.opacity(0.7), tint.opacity(0.1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 1.5)
            )
    }
}

/// Grande valeur chiffrée avec légende (KPI).
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        Card(tint: tint) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(tint.gradient).shadow(color: tint.opacity(0.4), radius: 4, y: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
            }
        }
    }
}

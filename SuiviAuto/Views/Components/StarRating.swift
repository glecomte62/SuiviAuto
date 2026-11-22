import SwiftUI

/// Note de 0 à 5 étoiles. Cliquer sur l'étoile déjà sélectionnée remet à 0.
/// En lecture seule (`editable: false`), les clics traversent vers la vue parente (ex. ligne de la barre latérale).
struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat = 16
    var editable = true

    var body: some View {
        let stars = HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? AnyShapeStyle(Color.yellow.gradient) : AnyShapeStyle(.secondary))
                    .shadow(color: index <= rating ? .orange.opacity(0.4) : .clear, radius: 1, y: 1)
                    .onTapGesture { rating = (rating == index) ? 0 : index }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating == 0 ? "Non noté" : "\(rating) étoile\(rating > 1 ? "s" : "") sur 5")

        if editable {
            stars.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: rating = min(5, rating + 1)
                case .decrement: rating = max(0, rating - 1)
                @unknown default: break
                }
            }
        } else {
            stars.allowsHitTesting(false)
        }
    }
}

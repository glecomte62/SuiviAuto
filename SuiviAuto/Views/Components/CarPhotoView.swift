import SwiftUI

/// Photo du véhicule affichée en entier (sans rognage), sur un fond dégradé de sa couleur.
struct CarPhotoView: View {
    let car: Car

    var body: some View {
        let tint = Color(hex: car.colorHex)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Group {
            if let data = car.photo, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .padding(8)
                    .background(shape.fill(tint.opacity(0.25).gradient))
            } else {
                Image(systemName: "car.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(shape.fill(tint.gradient))
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint, lineWidth: 1.5))
        .shadow(color: tint.opacity(0.4), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

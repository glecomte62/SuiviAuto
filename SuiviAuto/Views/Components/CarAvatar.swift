import SwiftUI

struct CarAvatar: View {
    let car: Car
    var size: CGFloat = 34

    var body: some View {
        let tint = Color(hex: car.colorHex)
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            shape.fill(tint.gradient)
            if let data = car.photo, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit().padding(size * 0.06)
            } else {
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint, lineWidth: 2))
        .shadow(color: tint.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

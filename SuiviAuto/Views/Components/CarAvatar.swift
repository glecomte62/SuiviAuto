import SwiftUI

struct CarAvatar: View {
    let car: Car
    var size: CGFloat = 34

    var body: some View {
        let tint = Color(hex: car.colorHex)
        ZStack {
            if let data = car.photo, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(tint.gradient)
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(tint, lineWidth: 2))
        .shadow(color: tint.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

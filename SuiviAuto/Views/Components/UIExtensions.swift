import SwiftUI

extension Color {
    /// "#2E86AB" -> Color
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(s, radix: 16) ?? 0x2E86AB
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

extension DueStatus {
    var color: Color {
        switch self {
        case .ok: .green
        case .soon: .orange
        case .overdue: .red
        }
    }
    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .soon: "clock.badge.exclamationmark.fill"
        case .overdue: "exclamationmark.triangle.fill"
        }
    }
}

extension InterventionKind {
    var color: Color {
        switch self {
        case .entretien: .blue
        case .reparation: .orange
        case .controleTechnique: .green
        case .pneus: .gray
        case .carrosserie: .purple
        case .autre: .teal
        }
    }
}

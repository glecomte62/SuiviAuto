import SwiftUI

struct StatusBadge: View {
    let status: DueStatus
    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(status.color.gradient))
            .foregroundStyle(.white)
            .shadow(color: status.color.opacity(0.4), radius: 3, y: 2)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .overlay(Capsule().strokeBorder(color.opacity(0.5)))
            .foregroundStyle(color)
    }
}

struct DueItemRow: View {
    let item: DueItem
    var showCar = true
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: item.carColorHex).gradient).frame(width: 12, height: 12)
                .shadow(radius: 1, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).fontWeight(.semibold)
                Text([showCar ? item.carName : nil, item.whenText, item.detail].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            StatusBadge(status: item.status)
        }
        .padding(.vertical, 4)
    }
}

extension DueItem {
    var whenText: String? {
        var parts: [String] = []
        if let dueDate { parts.append(Fmt.date(dueDate)) }
        if let dueKm { parts.append(Fmt.km(dueKm)) }
        return parts.isEmpty ? nil : parts.joined(separator: " ou ")
    }
}

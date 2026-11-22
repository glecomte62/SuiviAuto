import Foundation

/// Liens d'action à partir des coordonnées saisies. Retourne nil si la valeur est inutilisable.
enum ContactLinks {
    static func phoneURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = String(trimmed.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789").contains($0) })
        guard !digits.isEmpty else { return nil }
        let prefix = trimmed.hasPrefix("+") ? "+" : ""
        return URL(string: "tel:\(prefix)\(digits)")
    }

    static func mailURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), !trimmed.contains(where: \.isWhitespace) else { return nil }
        return URL(string: "mailto:\(trimmed)")
    }

    static func mapsURL(_ address: String) -> URL? {
        let oneLine = address.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !oneLine.isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: oneLine)]
        return components.url
    }

    static func webURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }
}

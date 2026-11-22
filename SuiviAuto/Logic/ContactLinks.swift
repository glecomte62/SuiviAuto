import Foundation

/// Liens d'action à partir des coordonnées saisies. Retourne nil si la valeur est inutilisable.
enum ContactLinks {
    /// Premier numéro seulement : la lecture s'arrête au premier « / » ou à la première lettre après le début du numéro
    /// (« poste 12 », « ext. », « x12 »…). « +33 (0)6… » devient « +336… ».
    static func phoneURL(_ text: String) -> URL? {
        var number = ""
        var plus = false
        var started = false
        for ch in text {
            if ch.isASCII, ch.isNumber {
                started = true
                number.append(ch)
            } else if !started {
                if ch == "+" { plus = true }
            } else if ch == "/" || ch.isLetter {
                break
            } else {
                number.append(ch)
            }
        }
        if plus {
            number = number.replacingOccurrences(of: #"\(\s*0\s*\)"#, with: "", options: .regularExpression)
        }
        let digits = number.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(plus ? "+" : "")\(digits)")
    }

    private static let forbiddenInMail = CharacterSet(charactersIn: "?&,;<>\"")
        .union(.whitespacesAndNewlines)
        .union(.controlCharacters)
        .union(.illegalCharacters)

    /// Une seule adresse : un « @ », partie locale et domaine non vides, domaine avec un point,
    /// aucun caractère pouvant ajouter des paramètres ou d'autres destinataires.
    static func mailURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.unicodeScalars.allSatisfy({ !forbiddenInMail.contains($0) }) else { return nil }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix(".") else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmed
        return components.url
    }

    /// Caractères laissés tels quels dans la valeur de la requête (« + », « & », « = », « # » sont encodés).
    private static let queryValueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&=#"))

    static func mapsURL(_ address: String) -> URL? {
        let oneLine = address.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !oneLine.isEmpty,
              let encoded = oneLine.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.percentEncodedQueryItems = [URLQueryItem(name: "q", value: encoded)]
        return components.url
    }

    /// Sites web uniquement (http / https), avec un nom de domaine contenant un point.
    static func webURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              components.user == nil, components.password == nil
        else { return nil }
        return components.url
    }
}

import Foundation

/// Montants en centimes d'euro.
enum Money {
    static let locale = Locale(identifier: "fr_FR")
    private static let pattern = try! Regex("^[0-9]+([.][0-9]{1,2})?$")

    /// "1 234,56 €" -> 123456. Retourne nil si le texte n'est pas un montant positif valide.
    static func parse(_ text: String) -> Int? {
        let cleaned = String(text.replacingOccurrences(of: "€", with: "").filter { !$0.isWhitespace })
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.wholeMatch(of: pattern) != nil,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// 123456 -> "1 234,56 €" (format français).
    static func format(cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "EUR").locale(locale))
    }

    /// 18990 -> "189,90", pour pré-remplir un champ de saisie.
    static func editString(cents: Int) -> String {
        String(format: "%d,%02d", cents / 100, cents % 100)
    }
}

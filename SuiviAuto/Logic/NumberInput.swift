import Foundation

/// Saisie d'entiers dans un champ texte (km, intervalles).
/// Sur macOS, `TextField(value:format:)` ne met à jour la valeur qu'en fin d'édition :
/// on garde donc le texte brut et on le convertit à la volée.
enum NumberInput {
    /// "15 000" -> 15000. Espaces, espaces insécables et fines insécables ignorés.
    /// nil si vide, négatif, non numérique ou plus de 9 chiffres.
    static func parseInt(_ text: String) -> Int? {
        let digits = text.filter { $0 != " " && $0 != "\u{00A0}" && $0 != "\u{202F}" }
        guard !digits.isEmpty, digits.count <= 9,
              digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }
}

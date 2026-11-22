import CoreGraphics

/// Remet en lignes des fragments de texte positionnés (Vision, PDFKit), pour que « Total TTC » et « 189,90 € »
/// imprimés dans deux colonnes se retrouvent sur la même ligne.
enum TextLayout {
    static let columnSeparator = "   "

    /// Regroupe les fragments en lignes (centres verticaux distants de moins de la moitié de la plus petite hauteur),
    /// lignes de haut en bas, fragments de gauche à droite, séparés par trois espaces.
    /// - Parameter yAxisUp: `true` si l'axe vertical monte (Vision, PDF), `false` s'il descend.
    static func rows(_ fragments: [(text: String, rect: CGRect)], yAxisUp: Bool) -> String {
        let ordered = fragments
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { yAxisUp ? $0.rect.midY > $1.rect.midY : $0.rect.midY < $1.rect.midY }
        var rows: [[(text: String, rect: CGRect)]] = []
        for fragment in ordered {
            if let last = rows.last?.first,
               abs(last.rect.midY - fragment.rect.midY) < 0.5 * min(last.rect.height, fragment.rect.height) {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows
            .map { $0.sorted { $0.rect.minX < $1.rect.minX }.map(\.text).joined(separator: columnSeparator) }
            .joined(separator: "\n")
    }
}

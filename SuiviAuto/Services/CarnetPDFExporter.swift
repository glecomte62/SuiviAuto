import AppKit
import CoreText

/// Carnet d'entretien imprimable (PDF A4) : tableau en colonnes, en-tête répété sur chaque page, « page n / N ».
enum CarnetPDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let footerSpace: CGFloat = 24
    private static let rowSpacing: CGFloat = 5
    private static let gutter: CGFloat = 6

    /// Colonnes du tableau, en points depuis la marge gauche ; le montant est aligné à droite sur 515.
    private struct Column { let x: CGFloat; let width: CGFloat; var alignment: NSTextAlignment = .left }
    private static let columns = [
        Column(x: 0, width: 70 - gutter),          // Date
        Column(x: 70, width: 70 - gutter),         // Km
        Column(x: 140, width: 200 - gutter),       // Opérations
        Column(x: 340, width: 105 - gutter),       // Garage
        Column(x: 445, width: 70, alignment: .right), // Montant
    ]

    private struct Item { let text: NSAttributedString; let rect: CGRect }

    static func render(car: Car, entries: [Intervention], estimatedMileage: Int?, calendar: Calendar = .current) -> Data {
        let pages = layout(car: car, entries: entries, estimatedMileage: estimatedMileage, calendar: calendar)
        let data = NSMutableData()
        var box = page
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for (index, items) in pages.enumerated() {
            ctx.beginPDFPage(nil)
            for item in items { draw(item, in: ctx) }
            let footer = text("\(clean(car.name)) — page \(index + 1) / \(pages.count)", size: 8, color: .gray)
            draw(Item(text: footer, rect: CGRect(x: margin, y: margin / 2 - 4, width: page.width - 2 * margin, height: 14)), in: ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    // MARK: - Mise en page (premier passage : sert aussi à compter les pages)

    private static func layout(car: Car, entries: [Intervention], estimatedMileage: Int?,
                               calendar: Calendar) -> [[Item]] {
        let df = DateFormatter()
        df.calendar = calendar; df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "fr_FR"); df.dateFormat = "dd/MM/yyyy"

        let width = page.width - 2 * margin
        let top = page.maxY - margin, bottom = margin + footerSpace
        var pages: [[Item]] = [[]]
        var y = top

        func place(_ s: NSAttributedString, x: CGFloat = 0, width w: CGFloat = width, spacing: CGFloat = 4) {
            let h = height(of: s, width: w)
            pages[pages.count - 1].append(Item(text: s, rect: CGRect(x: margin + x, y: y - h, width: w, height: h)))
            y -= h + spacing
        }

        func row(_ cells: [String], bold: Bool) -> (items: [(NSAttributedString, Column)], height: CGFloat) {
            let attributed = zip(cells, columns).map { text($0, size: 9, bold: bold, alignment: $1.alignment) }
            let h = zip(attributed, columns).map { height(of: $0, width: $1.width) }.max() ?? 0
            return (Array(zip(attributed, columns)), h)
        }

        func placeRow(_ r: (items: [(NSAttributedString, Column)], height: CGFloat)) {
            for (s, column) in r.items {
                pages[pages.count - 1].append(Item(text: s, rect: CGRect(x: margin + column.x, y: y - r.height,
                                                                         width: column.width, height: r.height)))
            }
            y -= r.height + rowSpacing
        }

        let header = row(["Date", "Km", "Opérations", "Garage", "Montant"], bold: true)

        place(text("Carnet d'entretien — \(clean(car.name))", size: 18, bold: true))
        let identity = [car.brand, car.modelName, car.plate].map(clean).filter { !$0.isEmpty }.joined(separator: " · ")
        if !identity.isEmpty { place(text(identity, size: 11, color: .darkGray)) }
        var meta = "1re immatriculation : \(df.string(from: car.firstRegistrationDate))"
        if let km = estimatedMileage { meta += " · Kilométrage estimé : \(Fmt.km(km))" }
        meta += " · Édité le \(df.string(from: .now))"
        place(text(meta, size: 9, color: .darkGray), spacing: 12)
        placeRow(header)

        for i in entries {
            let r = row([df.string(from: i.date), Fmt.km(i.mileage), clean(Carnet.operationsText(i)),
                         clean(i.garageDisplayName), i.amountCents.map { Money.format(cents: $0) } ?? ""], bold: false)
            if y - r.height < bottom {
                pages.append([])
                y = top
                placeRow(header)
            }
            placeRow(r)
        }

        let total = text("\(entries.count) intervention(s) · Total : \(Money.format(cents: Carnet.totalCents(entries)))",
                         size: 10, bold: true)
        let credit = text("SuiviAuto — créé par Guillaume LECOMTE", size: 8, color: .gray)
        y -= 6
        if y - height(of: total, width: width) - height(of: credit, width: width) - 4 < bottom {
            pages.append([])
            y = top
        }
        place(total)
        place(credit)
        return pages
    }

    // MARK: - Outils

    /// Texte saisi par l'utilisateur sur une seule ligne logique (pas de tabulation ni de retour à la ligne).
    private static func clean(_ s: String) -> String {
        s.components(separatedBy: CharacterSet(charactersIn: "\t\r\n\u{2028}\u{2029}"))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func text(_ s: String, size: CGFloat, bold: Bool = false, color: NSColor = .black,
                             alignment: NSTextAlignment = .left) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: s, attributes: [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: color, .paragraphStyle: style,
        ])
    }

    private static func height(of s: NSAttributedString, width: CGFloat) -> CGFloat {
        guard s.length > 0 else { return 0 }
        let fs = CTFramesetterCreateWithAttributedString(s)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(location: 0, length: 0), nil,
                                                                CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        return ceil(size.height) + 1
    }

    private static func draw(_ item: Item, in ctx: CGContext) {
        guard item.text.length > 0 else { return }
        let fs = CTFramesetterCreateWithAttributedString(item.text)
        let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), CGPath(rect: item.rect, transform: nil), nil)
        CTFrameDraw(frame, ctx)
    }
}

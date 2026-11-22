import AppKit
import CoreText

/// Carnet d'entretien imprimable (PDF A4, pagination automatique).
enum CarnetPDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 40

    static func render(car: Car, entries: [Intervention], estimatedMileage: Int?, calendar: Calendar = .current) -> Data {
        let body = attributedCarnet(car: car, entries: entries, estimatedMileage: estimatedMileage, calendar: calendar)
        let data = NSMutableData()
        var box = page
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let frameRect = page.insetBy(dx: margin, dy: margin)
        var location = 0
        var pageNumber = 1
        repeat {
            ctx.beginPDFPage(nil)
            let path = CGPath(rect: frameRect.insetBy(dx: 0, dy: 10).offsetBy(dx: 0, dy: 10), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            drawFooter("\(car.name) — page \(pageNumber)", in: ctx)
            let visible = CTFrameGetVisibleStringRange(frame)
            ctx.endPDFPage()
            guard visible.length > 0 else { break }
            location += visible.length
            pageNumber += 1
        } while location < body.length
        ctx.closePDF()
        return data as Data
    }

    private static func drawFooter(_ text: String, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.gray,
        ]))
        ctx.textPosition = CGPoint(x: margin, y: margin / 2)
        CTLineDraw(line, ctx)
    }

    private static func attributedCarnet(car: Car, entries: [Intervention], estimatedMileage: Int?,
                                         calendar: Calendar) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let df = DateFormatter()
        df.calendar = calendar; df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "fr_FR"); df.dateFormat = "dd/MM/yyyy"

        func add(_ s: String, size: CGFloat, bold: Bool = false, color: NSColor = .black, tabs: [CGFloat] = []) {
            let style = NSMutableParagraphStyle()
            style.tabStops = tabs.map { NSTextTab(textAlignment: .left, location: $0) }
            style.paragraphSpacing = 4
            out.append(NSAttributedString(string: s + "\n", attributes: [
                .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
                .foregroundColor: color, .paragraphStyle: style,
            ]))
        }

        add("Carnet d'entretien — \(car.name)", size: 18, bold: true)
        let identity = [car.brand, car.modelName, car.plate].filter { !$0.isEmpty }.joined(separator: " · ")
        if !identity.isEmpty { add(identity, size: 11, color: .darkGray) }
        var meta = "1re immatriculation : \(df.string(from: car.firstRegistrationDate))"
        if let km = estimatedMileage { meta += " · Kilométrage estimé : \(Fmt.km(km))" }
        meta += " · Édité le \(df.string(from: .now))"
        add(meta, size: 9, color: .darkGray)
        add("", size: 6)

        let tabs: [CGFloat] = [70, 140, 360]
        add("Date\tKm\tOpérations\tGarage", size: 9, bold: true, tabs: tabs)
        for i in entries {
            var line = "\(df.string(from: i.date))\t\(Fmt.km(i.mileage))\t\(Carnet.operationsText(i))\t\(i.garageDisplayName)"
            if let cents = i.amountCents { line += " — \(Money.format(cents: cents))" }
            add(line, size: 9, tabs: tabs)
        }
        add("", size: 6)
        add("\(entries.count) intervention(s) · Total : \(Money.format(cents: Carnet.totalCents(entries)))", size: 10, bold: true)
        add("SuiviAuto — créé par Guillaume LECOMTE", size: 8, color: .gray)
        return out
    }
}

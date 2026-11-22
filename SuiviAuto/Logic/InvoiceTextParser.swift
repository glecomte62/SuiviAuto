import Foundation

struct InvoiceExtraction: Equatable {
    var date: Date?
    var amountCents: Int?
    var mileage: Int?
    var operations: [MaintenanceOperation] = []

    var isEmpty: Bool { date == nil && amountCents == nil && mileage == nil && operations.isEmpty }
}

/// Extrait date, montant TTC, kilométrage et opérations d'un texte de facture ou de devis.
enum InvoiceTextParser {
    private static let months = ["janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet",
                                 "aout", "septembre", "octobre", "novembre", "decembre"]
    private static let numericDate = try! Regex(#"(?:^|\D)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)"#)
    private static let textDate = try! Regex(#"(?:^|\D)(\d{1,2})(?:er)?\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)\s+(\d{4})"#)
    private static let money = try! Regex(#"(?:^|[^\d,.])(\d{1,3}(?:[   .]\d{3})*|\d+)[,.](\d{2})(?!\d)"#)
    private static let kmAfterNumber = try! Regex(#"(?:^|[^\d,.])(\d{1,3}(?:[   .]\d{3})+|\d{3,7})\s*kms?\b"#)
    private static let kmAfterLabel = try! Regex(#"(?:kilometrage|km compteur|kms?)\s*:?\s*(\d{1,3}(?:[   .]\d{3})+|\d{3,7})(?![\d,])"#)

    static func parse(_ text: String, calendar: Calendar = .current) -> InvoiceExtraction {
        let lines = text.components(separatedBy: .newlines)
        let folded = lines.map { MaintenanceOperation.foldCaseAndAccents($0) }
        return InvoiceExtraction(date: findDate(folded, calendar: calendar),
                                 amountCents: findAmount(folded),
                                 mileage: findMileage(folded),
                                 operations: MaintenanceOperation.detect(in: text))
    }

    // MARK: - Date

    private static func findDate(_ lines: [String], calendar: Calendar) -> Date? {
        let preferred = lines.filter { $0.contains("date") || $0.contains("facture") || $0.contains("devis") }
        for line in preferred + lines {
            if let d = dates(in: line, calendar: calendar).first { return d }
        }
        return nil
    }

    private static func dates(in line: String, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        for m in line.matches(of: numericDate) {
            guard let d = Int(m.output[1].substring ?? ""), let mo = Int(m.output[2].substring ?? ""),
                  var y = Int(m.output[3].substring ?? "") else { continue }
            if y < 100 { y += 2000 }
            if let date = validDate(y, mo, d, calendar) { result.append(date) }
        }
        for m in line.matches(of: textDate) {
            guard let d = Int(m.output[1].substring ?? ""),
                  let name = m.output[2].substring, let mo = months.firstIndex(of: String(name)),
                  let y = Int(m.output[3].substring ?? "") else { continue }
            if let date = validDate(y, mo + 1, d, calendar) { result.append(date) }
        }
        return result
    }

    private static func validDate(_ y: Int, _ m: Int, _ d: Int, _ calendar: Calendar) -> Date? {
        guard (1990...2100).contains(y), (1...12).contains(m), (1...31).contains(d) else { return nil }
        let comps = DateComponents(year: y, month: m, day: d)
        guard let date = calendar.date(from: comps) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return (back.year == y && back.month == m && back.day == d) ? date : nil
    }

    // MARK: - Montant

    private static func findAmount(_ lines: [String]) -> Int? {
        let ttc = lines.filter { $0.contains("ttc") }
        let net = lines.filter { $0.contains("net a payer") }
        let total = lines.filter { $0.contains("total") && !$0.contains(" ht") && !$0.hasPrefix("ht") }
        for group in [ttc, net, total] {
            if let best = group.flatMap(amounts(in:)).max() { return best }
        }
        return nil
    }

    private static func amounts(in line: String) -> [Int] {
        line.matches(of: money).compactMap { m in
            guard let whole = m.output[1].substring, let cents = m.output[2].substring else { return nil }
            let digits = whole.filter(\.isNumber)
            guard digits.count <= 9, let euros = Int(digits), let c = Int(cents) else { return nil }
            return euros * 100 + c
        }
    }

    // MARK: - Kilométrage

    private static func findMileage(_ lines: [String]) -> Int? {
        for line in lines where line.contains("km") || line.contains("kilometrage") {
            for regex in [kmAfterLabel, kmAfterNumber] {
                for m in line.matches(of: regex) {
                    guard let raw = m.output[1].substring,
                          let value = Int(raw.filter(\.isNumber)),
                          (100...2_000_000).contains(value) else { continue }
                    return value
                }
            }
        }
        return nil
    }
}

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
    private static let thousands = "[ \u{00A0}\u{202F}.]"
    private static let numericDate = try! Regex(#"(?:^|\D)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)"#)
    private static let textDate = try! Regex(#"(?:^|\D)(\d{1,2})(?:er)?\s+(janvier|janv|jan|fevrier|fevr|fev|mars|mar|avril|avr|mai|juin|juillet|juil|aout|septembre|sept|sep|octobre|oct|novembre|nov|decembre|dec)\.?\s+(\d{4})"#)
    /// Mois abrégés ou complets, reconnus par leur début.
    private static let monthPrefixes = ["jan", "fev", "mar", "avr", "mai", "juin", "juil", "aou", "sep", "oct", "nov", "dec"]
    /// Mots qui annoncent une autre date que celle de la facture (mise en circulation, échéance, validité, téléphone).
    private static let otherDateWords = try! Regex(#"circulation|\bmec\b|immatric|echeance|valable|validite|jusqu|\btel\b|telephone|portable|\bfax\b|mobile"#)
        .wordBoundaryKind(.simple)
    private static let invoiceDateMarker = try! Regex(#"date|facture|devis|, le "#)

    private static let money = try! Regex(#"(?:^|[^\d,.\-−])([\-−]?)(\d{1,3}(?:"# + thousands + #"\d{3})*|\d+)[,.](\d{2})(?!\d)"#)
    private static let moneyWithoutCents = try! Regex(#"(?:^|[^\d,.\-−])([\-−]?)(\d{1,3}(?:"# + thousands + #"\d{3})*|\d+)\s*(?:€|eur\b)"#)

    private static let kmValue = #"(\d{1,3}(?:"# + thousands + #"\d{3})+|\d{3,7})(?![\d,])"#
    private static let kmLabel = #"(?:^|[^a-z0-9])(?:kilom\w*\.?|kms?(?:\s+(?:au\s+)?compteur|\s+entree|\s+releve)?|compteur)"#
    private static let kmAfterLabel = try! Regex(kmLabel + #"[^\d\n]{0,12}?"# + kmValue)
    private static let kmLabelAtLineEnd = try! Regex(kmLabel + #"[^\d]{0,12}$"#)
    private static let kmValueAtLineStart = try! Regex(#"^\s*"# + kmValue)
    private static let kmAfterNumber = try! Regex(#"(?:^|[^\d,.])"# + kmValue + #"\s*kms?\b"#)
    /// Lignes qui parlent d'un kilométrage futur ou théorique, pas du relevé du jour.
    private static let futureMileageWords = ["prochain", "tous les", "a faire", "garantie"]

    static func parse(_ text: String, calendar: Calendar = .current, now: Date = .now) -> InvoiceExtraction {
        let lines = text.components(separatedBy: .newlines)
        let folded = lines.map { MaintenanceOperation.foldCaseAndAccents($0) }
        return InvoiceExtraction(date: findDate(folded, calendar: calendar, now: now),
                                 amountCents: findAmount(folded),
                                 mileage: findMileage(folded),
                                 operations: MaintenanceOperation.detect(in: text))
    }

    // MARK: - Date

    /// Première date de facture : d'abord sur une ligne qui l'annonce (date, facture, devis, « Lille, le »),
    /// sinon la première trouvée ; jamais une date de mise en circulation, d'échéance, de validité ou un téléphone,
    /// ni une date à plus d'un an dans le futur.
    private static func findDate(_ lines: [String], calendar: Calendar, now: Date) -> Date? {
        let limit = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        var preferred: [Date] = [], others: [Date] = []
        for line in lines {
            var previousEnd = line.startIndex
            for found in dates(in: line, calendar: calendar, now: now) {
                var context = line[previousEnd..<found.range.lowerBound]
                previousEnd = max(previousEnd, found.range.upperBound)
                if let marker = context.matches(of: invoiceDateMarker).last { context = context[marker.range.upperBound...] }
                guard let date = found.date, date <= limit, context.firstMatch(of: otherDateWords) == nil else { continue }
                if line[..<found.range.lowerBound].firstMatch(of: invoiceDateMarker) != nil {
                    preferred.append(date)
                } else {
                    others.append(date)
                }
            }
        }
        return preferred.first ?? others.first
    }

    /// Dates d'une ligne dans l'ordre où elles apparaissent (`date` nil si la date est invalide).
    private static func dates(in line: String, calendar: Calendar, now: Date) -> [(range: Range<String.Index>, date: Date?)] {
        let currentShortYear = calendar.component(.year, from: now) % 100
        var result: [(range: Range<String.Index>, date: Date?)] = []
        for m in line.matches(of: numericDate) {
            guard let start = m.output[1].range?.lowerBound,
                  let d = Int(m.output[1].substring ?? ""), let mo = Int(m.output[2].substring ?? ""),
                  var y = Int(m.output[3].substring ?? "") else { continue }
            if y < 100 { y += y > currentShortYear + 1 ? 1900 : 2000 }
            result.append((start..<m.range.upperBound, validDate(y, mo, d, calendar)))
        }
        for m in line.matches(of: textDate) {
            guard let start = m.output[1].range?.lowerBound,
                  let d = Int(m.output[1].substring ?? ""), let name = m.output[2].substring,
                  let mo = monthPrefixes.firstIndex(where: { name.hasPrefix($0) }),
                  let y = Int(m.output[3].substring ?? "") else { continue }
            result.append((start..<m.range.upperBound, validDate(y, mo + 1, d, calendar)))
        }
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
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

    /// Montants positifs d'une ligne, en centimes (« 189,90 », « 1 250,00 », « 190 € ») ; les avoirs (« -50,00 ») sont ignorés.
    private static func amounts(in line: String) -> [Int] {
        let withCents = line.matches(of: money).compactMap { m -> Int? in
            guard m.output[1].substring?.isEmpty ?? true,
                  let whole = m.output[2].substring, let cents = m.output[3].substring else { return nil }
            let digits = whole.filter(\.isNumber)
            guard digits.count <= 9, let euros = Int(digits), let c = Int(cents) else { return nil }
            return euros * 100 + c
        }
        let withoutCents = line.matches(of: moneyWithoutCents).compactMap { m -> Int? in
            guard m.output[1].substring?.isEmpty ?? true, let whole = m.output[2].substring else { return nil }
            let digits = whole.filter(\.isNumber)
            guard digits.count <= 9, let euros = Int(digits) else { return nil }
            return euros * 100
        }
        return withCents + withoutCents
    }

    // MARK: - Kilométrage

    /// Kilométrage relevé : d'abord après un libellé (« Kilométrage : », « Km entrée », « Compteur »…, éventuellement
    /// au début de la ligne suivante), sinon un nombre suivi de « km ». Les lignes « prochaine vidange à 60 000 km »,
    /// « tous les », « à faire », « garantie » sont ignorées.
    private static func findMileage(_ lines: [String]) -> Int? {
        func value(_ raw: Substring?) -> Int? {
            guard let raw, let v = Int(raw.filter(\.isNumber)), (100...2_000_000).contains(v) else { return nil }
            return v
        }
        let usable = lines.map { line in !futureMileageWords.contains { line.contains($0) } }
        for (index, line) in lines.enumerated() where usable[index] {
            for m in line.matches(of: kmAfterLabel) {
                if let v = value(m.output[1].substring) { return v }
            }
            if line.firstMatch(of: kmLabelAtLineEnd) != nil, index + 1 < lines.count, usable[index + 1],
               let m = lines[index + 1].firstMatch(of: kmValueAtLineStart), let v = value(m.output[1].substring) {
                return v
            }
        }
        for (index, line) in lines.enumerated() where usable[index] {
            for m in line.matches(of: kmAfterNumber) {
                if let v = value(m.output[1].substring) { return v }
            }
        }
        return nil
    }
}

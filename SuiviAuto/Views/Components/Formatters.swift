import Foundation

enum Fmt {
    static let locale = Locale(identifier: "fr_FR")
    static func km(_ v: Int) -> String { "\(v.formatted(.number.locale(locale))) km" }
    static func date(_ d: Date) -> String { d.formatted(.dateTime.day().month(.wide).year().locale(locale)) }
    static func shortDate(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)) }
}

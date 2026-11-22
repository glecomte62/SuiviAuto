import Foundation
import SwiftData

@Model
final class StoredDocument {
    var fileName: String = ""
    var originalName: String = ""
    var addedAt: Date = Date.now
    var kindRaw: String = "pdf"
    var intervention: Intervention?
    var deadline: Deadline?

    init(fileName: String, originalName: String, kind: DocumentKind, addedAt: Date = .now) {
        self.fileName = fileName
        self.originalName = originalName
        self.kindRaw = kind.rawValue
        self.addedAt = addedAt
    }

    var kind: DocumentKind { DocumentKind(rawValue: kindRaw) ?? .pdf }
}

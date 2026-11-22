import SwiftData
import XCTest
@testable import SuiviAuto

final class PendingAttachmentsTests: XCTestCase {
    var root: URL!
    var store: DocumentStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = DocumentStore(directory: root.appendingPathComponent("Documents"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeFile(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("contenu".utf8).write(to: url)
        return url
    }

    func testAddCopiesAcceptedFilesAndReportsRejected() throws {
        let pending = PendingAttachments(store: store)
        let rejected = pending.add(urls: [try makeFile("facture.pdf"), try makeFile("notes.docx")])
        XCTAssertEqual(rejected.count, 1)
        XCTAssertTrue(rejected[0].contains("notes.docx"))
        XCTAssertEqual(pending.documents.map(\.originalName), ["facture.pdf"])
        XCTAssertTrue(store.fileExists(for: pending.documents[0]))
    }

    func testDiscardDeletesCopies() throws {
        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("a.pdf"), try makeFile("b.png")])
        let docs = pending.documents
        pending.discard()
        XCTAssertTrue(pending.documents.isEmpty)
        XCTAssertFalse(docs.contains { store.fileExists(for: $0) })
    }

    func testAttachToInterventionLinksAndKeepsFiles() throws {
        let context = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"), colorHex: "#2E86AB")
        context.insert(car)
        let intervention = Intervention(date: T.date("2026-01-01"), mileage: 10_000, kind: .entretien)
        context.insert(intervention); intervention.car = car

        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("facture.pdf")])
        let doc = pending.documents[0]
        let names = pending.attach(to: intervention, in: context)
        try context.save()

        XCTAssertEqual(names.map(\.fileName), [doc.fileName])
        XCTAssertTrue(pending.documents.isEmpty)
        XCTAssertEqual(intervention.documents.map(\.fileName), [doc.fileName])
        pending.discard()
        XCTAssertTrue(store.fileExists(for: doc))
    }

    func testAttachToDeadline() throws {
        let context = try T.makeContext()
        let deadline = Deadline(label: "Assurance", dueDate: T.date("2026-06-01"), repeatsYearly: true)
        context.insert(deadline)

        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("devis.pdf"), try makeFile("photo.jpg")])
        pending.attach(to: deadline, in: context)
        try context.save()

        XCTAssertEqual(Set(deadline.documents.map(\.originalName)), ["devis.pdf", "photo.jpg"])
        XCTAssertTrue(pending.documents.isEmpty)
        pending.discard()
        XCTAssertTrue(deadline.documents.allSatisfy { store.fileExists(for: $0) })
    }

    func testRemoveDeletesOnePendingFile() throws {
        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("a.pdf"), try makeFile("b.pdf")])
        let (a, b) = (pending.documents[0], pending.documents[1])
        pending.remove(a)
        XCTAssertEqual(pending.documents.map(\.fileName), [b.fileName])
        XCTAssertFalse(store.fileExists(for: a))
        XCTAssertTrue(store.fileExists(for: b))
    }

    func testFailedSaveRestoresPendingDocuments() throws {
        let context = try T.makeContext()
        let deadline = Deadline(label: "Pneus", dueDate: T.date("2026-06-01"), repeatsYearly: false)
        context.insert(deadline)
        try context.save()
        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("a.pdf"), try makeFile("b.png")])
        let before = pending.documents.map { [$0.fileName, $0.originalName, $0.kindRaw] }

        let attached = pending.attach(to: deadline, in: context)
        XCTAssertTrue(pending.isEmpty)
        context.rollback()        // échec de l'enregistrement
        pending.restore(attached)

        XCTAssertEqual(pending.documents.map { [$0.fileName, $0.originalName, $0.kindRaw] }, before)
        XCTAssertTrue(pending.documents.allSatisfy { $0.modelContext == nil }, "documents neufs, hors contexte")
        XCTAssertTrue(pending.documents.allSatisfy { store.fileExists(for: $0) }, "fichiers conservés")
        XCTAssertTrue(deadline.documents.isEmpty)

        // Nouvel essai réussi.
        pending.attach(to: deadline, in: context)
        try context.save()
        XCTAssertEqual(Set(deadline.documents.map(\.originalName)), ["a.pdf", "b.png"])
    }

    func testRestoredDocumentsAreDeletedOnDiscard() throws {
        let context = try T.makeContext()
        let deadline = Deadline(label: "Pneus", dueDate: T.date("2026-06-01"), repeatsYearly: false)
        context.insert(deadline)
        let pending = PendingAttachments(store: store)
        pending.add(urls: [try makeFile("a.pdf")])
        let attached = pending.attach(to: deadline, in: context)
        context.rollback()
        pending.restore(attached)
        let doc = try XCTUnwrap(pending.documents.first)
        pending.discard()
        XCTAssertFalse(store.fileExists(for: doc))
    }

    func testDeinitDeletesUnsavedCopies() throws {
        var pending: PendingAttachments? = PendingAttachments(store: store)
        pending?.add(urls: [try makeFile("a.pdf")])
        let doc = try XCTUnwrap(pending?.documents.first)
        pending = nil
        XCTAssertFalse(store.fileExists(for: doc))
    }
}

final class InterventionDraftTests: XCTestCase {
    let keys: Set<String> = ["vidange", "courroie"]

    func testCheckingSuggestsRuleOnlyWhenNoneChosenAndRuleExists() {
        XCTAssertEqual(InterventionDraft.ruleKey(afterChecking: .vidange, current: "", available: keys), "vidange")
        XCTAssertEqual(InterventionDraft.ruleKey(afterChecking: .vidange, current: "courroie", available: keys), "courroie")
        XCTAssertEqual(InterventionDraft.ruleKey(afterChecking: .liquideFrein, current: "", available: keys), "")
        XCTAssertEqual(InterventionDraft.ruleKey(afterChecking: .filtres, current: "", available: keys), "")
    }

    func testApplyFillsOnlyDetectedFields() {
        let start = InterventionDraft.Fields(date: T.date("2026-01-01"), mileageText: "12000", amountText: "10,00",
                                             operations: [.filtres], ruleKey: "")
        let onlyAmount = InterventionDraft.apply(InvoiceExtraction(amountCents: 18990), to: start, availableRuleKeys: keys)
        XCTAssertEqual(onlyAmount, InterventionDraft.Fields(date: T.date("2026-01-01"), mileageText: "12000",
                                                            amountText: "189,90", operations: [.filtres], ruleKey: ""))

        let all = InterventionDraft.apply(InvoiceExtraction(date: T.date("2026-03-12"), amountCents: 5000, mileage: 45_000,
                                                            operations: [.vidange, .filtres]),
                                          to: start, availableRuleKeys: keys)
        XCTAssertEqual(all, InterventionDraft.Fields(date: T.date("2026-03-12"), mileageText: "45000", amountText: "50,00",
                                                     operations: [.vidange, .filtres], ruleKey: "vidange"))
    }

    func testStoredOperationsTracksCustomText() {
        XCTAssertEqual(InterventionDraft.storedOperations([.vidange, .autre], custom: "  "), [.vidange])
        XCTAssertEqual(InterventionDraft.storedOperations([.vidange], custom: "Essuie-glaces"), [.vidange, .autre])
    }
}

final class DeadlineTextTests: XCTestCase {
    func testKmDetail() {
        let due = DeadlineDue(dueDate: T.date("2027-03-01"), dueKm: 90_000, remainingKm: 3_200, status: .ok)
        let text = DeadlineText.detail(mode: .km, dueDate: .distantPast, repeatsYearly: false, intervalKm: nil, due: due)
        XCTAssertTrue(text.hasPrefix("à \(Fmt.km(90_000)) · ≈ "))
        XCTAssertTrue(text.hasSuffix(" · reste \(Fmt.km(3_200))"))
    }

    func testKmPassedShowsOverrun() {
        let due = DeadlineDue(dueDate: nil, dueKm: 90_000, remainingKm: -500, status: .overdue)
        XCTAssertEqual(DeadlineText.detail(mode: .km, dueDate: .distantPast, repeatsYearly: false, intervalKm: 15_000, due: due),
                       "à \(Fmt.km(90_000)) · dépassé de \(Fmt.km(500)) · puis tous les \(Fmt.km(15_000))")
    }

    func testKmWithoutTarget() {
        let due = DeadlineDue(dueDate: nil, dueKm: nil, remainingKm: nil, status: .ok)
        XCTAssertEqual(DeadlineText.detail(mode: .km, dueDate: .distantPast, repeatsYearly: false, intervalKm: nil, due: due),
                       "Kilométrage cible inconnu")
        XCTAssertEqual(DeadlineText.target(mode: .km, dueDate: .distantPast, targetMileage: 90_000), "à \(Fmt.km(90_000))")
    }
}

final class DeadlineSortTests: XCTestCase {
    func testOverdueKmFirstThenByDateThenUnknown() {
        let passed = DeadlineDue(dueDate: nil, dueKm: 80_000, remainingKm: -10, status: .overdue)
        let early = DeadlineDue(dueDate: T.date("2026-02-01"), dueKm: nil, remainingKm: nil, status: .soon)
        let late = DeadlineDue(dueDate: T.date("2027-02-01"), dueKm: 95_000, remainingKm: 9_000, status: .ok)
        let unknown = DeadlineDue(dueDate: nil, dueKm: nil, remainingKm: nil, status: .ok)
        let sorted = [unknown, late, passed, early].sorted { DeadlineText.sortKey($0) < DeadlineText.sortKey($1) }
        XCTAssertEqual(sorted, [passed, early, late, unknown])
    }
}

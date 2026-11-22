import SwiftData
import XCTest
@testable import SuiviAuto

final class DeadlineV2Tests: XCTestCase {
    func estimator(_ pts: [(String, Int)], now: String) -> MileageEstimator {
        MileageEstimator(points: pts.map { MileagePoint(date: T.date($0.0), km: $0.1) }, now: T.date(now), calendar: T.calendar)
    }

    func testDateMode() {
        let due = DeadlineScheduler.due(mode: .date, dueDate: T.date("2026-02-01"), targetMileage: nil,
                                        estimator: estimator([], now: "2026-01-10"), now: T.date("2026-01-10"), calendar: T.calendar)
        XCTAssertEqual(due, DeadlineDue(dueDate: T.date("2026-02-01"), dueKm: nil, remainingKm: nil, status: .soon))
    }

    func testKmModeUsesEstimate() {
        // 100 km/jour ; dernier point 2026-01-11 à 11 000 ; cible 25 000 -> 140 jours -> 2026-05-31
        let e = estimator([("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        let due = DeadlineScheduler.due(mode: .km, dueDate: .distantPast, targetMileage: 25_000,
                                        estimator: e, now: T.date("2026-01-11"), calendar: T.calendar)
        XCTAssertEqual(due.dueKm, 25_000)
        XCTAssertEqual(due.remainingKm, 14_000)
        XCTAssertEqual(due.dueDate, T.date("2026-05-31"))
        XCTAssertEqual(due.status, .ok)
    }

    func testKmModeSoonAndOverdue() {
        let e = estimator([("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        XCTAssertEqual(DeadlineScheduler.due(mode: .km, dueDate: .distantPast, targetMileage: 11_800,
                                             estimator: e, now: T.date("2026-01-11"), calendar: T.calendar).status, .soon)
        XCTAssertEqual(DeadlineScheduler.due(mode: .km, dueDate: .distantPast, targetMileage: 10_500,
                                             estimator: e, now: T.date("2026-01-11"), calendar: T.calendar).status, .overdue)
    }

    func testKmModeWithoutDataIsOk() {
        let due = DeadlineScheduler.due(mode: .km, dueDate: .distantPast, targetMileage: 90_000,
                                        estimator: estimator([], now: "2026-01-11"), now: T.date("2026-01-11"), calendar: T.calendar)
        XCTAssertEqual(due, DeadlineDue(dueDate: nil, dueKm: 90_000, remainingKm: nil, status: .ok))
        let noTarget = DeadlineScheduler.due(mode: .km, dueDate: .distantPast, targetMileage: nil,
                                             estimator: estimator([], now: "2026-01-11"), now: T.date("2026-01-11"), calendar: T.calendar)
        XCTAssertEqual(noTarget, DeadlineDue(dueDate: nil, dueKm: nil, remainingKm: nil, status: .ok))
    }

    func testComplete() {
        let yearly = Deadline(label: "Assurance", dueDate: T.date("2026-03-01"), repeatsYearly: true)
        XCTAssertEqual(yearly.complete(on: T.date("2026-02-20"), mileage: nil, calendar: T.calendar), .advanced)
        XCTAssertEqual(yearly.dueDate, T.date("2027-03-01"))

        let once = Deadline(label: "Garantie", dueDate: T.date("2026-03-01"), repeatsYearly: false)
        XCTAssertEqual(once.complete(on: .now, mileage: nil, calendar: T.calendar), .remove)

        let tyres = Deadline(label: "Pneus", dueDate: .now, repeatsYearly: false)
        tyres.mode = .km; tyres.targetMileage = 90_000; tyres.intervalKm = 40_000
        XCTAssertEqual(tyres.complete(on: .now, mileage: 91_200, calendar: T.calendar), .advanced)
        XCTAssertEqual(tyres.targetMileage, 131_200)
        XCTAssertEqual(tyres.complete(on: .now, mileage: nil, calendar: T.calendar), .advanced)
        XCTAssertEqual(tyres.targetMileage, 171_200)

        let kmOnce = Deadline(label: "Révision", dueDate: .now, repeatsYearly: false)
        kmOnce.mode = .km; kmOnce.targetMileage = 60_000
        XCTAssertEqual(kmOnce.complete(on: .now, mileage: 60_100, calendar: T.calendar), .remove)
    }

    func testAggregatorUsesKmMode() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2022-05-01"))
        ctx.insert(car)
        for (date, km) in [("2026-01-01", 10_000), ("2026-01-11", 11_000)] {
            let r = OdometerReading(date: T.date(date), mileage: km); ctx.insert(r); r.car = car
        }
        let d = Deadline(label: "Pneus", dueDate: .distantPast, repeatsYearly: false)
        d.mode = .km; d.targetMileage = 11_800
        ctx.insert(d); d.car = car
        try ctx.save()
        let item = DueAggregator.items(for: car, now: T.date("2026-01-11"), calendar: T.calendar).first { $0.source == .deadline }!
        XCTAssertEqual(item.dueKm, 11_800)
        XCTAssertEqual(item.status, .soon)
        XCTAssertEqual(item.dueDate, T.date("2026-01-19"))
    }

    func testCompleteTransfersDocumentsAndApplies() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2022-05-01"))
        ctx.insert(car)
        let d = Deadline(label: "Garantie", dueDate: T.date("2026-03-01"), repeatsYearly: false)
        ctx.insert(d); d.car = car
        let doc = StoredDocument(fileName: "a.pdf", originalName: "devis.pdf", kind: .pdf)
        ctx.insert(doc); doc.deadline = d
        let i = Intervention(date: T.date("2026-02-28"), mileage: 50_000, kind: .entretien)
        ctx.insert(i); i.car = car
        try ctx.save()

        try DeadlineService.complete(d, with: i, in: ctx, calendar: T.calendar)

        XCTAssertTrue(doc.intervention === i)
        XCTAssertNil(doc.deadline)
        XCTAssertEqual(i.documents.count, 1)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Deadline>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<StoredDocument>()), 1)
    }

    func testDeleteDeadlineAndCarRemoveFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentStore(directory: root.appendingPathComponent("Documents"))
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2022-05-01"))
        ctx.insert(car)

        func deadlineWithFile() throws -> (Deadline, URL) {
            let d = Deadline(label: "Pneus", dueDate: .now, repeatsYearly: false)
            ctx.insert(d); d.car = car
            let src = root.appendingPathComponent("\(UUID().uuidString).pdf")
            try Data("x".utf8).write(to: src)
            let doc = try store.importFile(at: src)
            ctx.insert(doc); doc.deadline = d
            try ctx.save()
            return (d, store.url(for: doc))
        }

        let (d1, f1) = try deadlineWithFile()
        try DeletionService.delete(d1, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f1.path))

        let (_, f2) = try deadlineWithFile()
        try DeletionService.delete(car, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f2.path))
    }
}

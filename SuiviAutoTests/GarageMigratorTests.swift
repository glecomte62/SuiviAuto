import SwiftData
import XCTest
@testable import SuiviAuto

final class GarageMigratorTests: XCTestCase {
    var ctx: ModelContext!
    var car: Car!

    override func setUpWithError() throws {
        ctx = try T.makeContext()
        car = Car(name: "Clio", firstRegistrationDate: T.date("2018-01-01"))
        ctx.insert(car)
    }

    @discardableResult
    func add(_ date: String, garage: String) -> Intervention {
        let i = Intervention(date: T.date(date), mileage: 1, kind: .entretien)
        i.garage = garage
        ctx.insert(i)
        i.car = car
        return i
    }

    func garages() throws -> [Garage] {
        try ctx.fetch(FetchDescriptor<Garage>(sortBy: [SortDescriptor(\.name)]))
    }

    func testGroupsSpellingsKeepsFirstAndLeavesTextUntouched() throws {
        let late = add("2025-01-01", garage: "garage  du NORD ")
        let early = add("2024-01-01", garage: "Garage du Nord")
        let accent = add("2025-06-01", garage: "Garage du Nörd")
        add("2025-02-01", garage: "Speedy")
        add("2025-03-01", garage: "   ")

        let result = try GarageMigrator.run(in: ctx)

        XCTAssertEqual(result, GarageMigrator.Result(created: 2, linked: 4))
        XCTAssertEqual(try garages().map(\.name), ["Garage du Nord", "Speedy"])
        XCTAssertTrue(early.garageRef === late.garageRef)
        XCTAssertTrue(early.garageRef === accent.garageRef)
        XCTAssertEqual(late.garage, "garage  du NORD ")
        XCTAssertTrue(late.garageTextMigrated)
    }

    func testIsIdempotent() throws {
        add("2024-01-01", garage: "Garage du Nord")
        try GarageMigrator.run(in: ctx)
        XCTAssertEqual(try GarageMigrator.run(in: ctx), GarageMigrator.Result(created: 0, linked: 0))
        XCTAssertEqual(try garages().count, 1)
    }

    func testReusesExistingGarage() throws {
        let existing = Garage(name: "Garage du Nord")
        ctx.insert(existing)
        let i = add("2024-01-01", garage: "GARAGE DU NORD")
        XCTAssertEqual(try GarageMigrator.run(in: ctx), GarageMigrator.Result(created: 0, linked: 1))
        XCTAssertTrue(i.garageRef === existing)
    }

    func testAlreadyProcessedTextIsNotRecreated() throws {
        let i = add("2024-01-01", garage: "Garage supprimé")
        i.garageTextMigrated = true
        XCTAssertEqual(try GarageMigrator.run(in: ctx), GarageMigrator.Result(created: 0, linked: 0))
        XCTAssertNil(i.garageRef)
    }

    func testOpensVersion10StoreAndConverts() throws {
        let fm = FileManager.default
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/v1_0", isDirectory: true)
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        for name in try fm.contentsOfDirectory(atPath: fixture.path) {
            try fm.copyItem(at: fixture.appendingPathComponent(name), to: tmp.appendingPathComponent(name))
        }

        let container = try ModelContainer(for: Schema(SchemaModels.all),
                                           configurations: ModelConfiguration(url: tmp.appendingPathComponent("SuiviAuto.store")))
        let store = ModelContext(container)
        XCTAssertEqual(try store.fetchCount(FetchDescriptor<Intervention>()), 5)

        XCTAssertEqual(try GarageMigrator.run(in: store), GarageMigrator.Result(created: 2, linked: 4))
        let names = try store.fetch(FetchDescriptor<Garage>(sortBy: [SortDescriptor(\.name)])).map(\.name)
        XCTAssertEqual(names, ["Garage du Nord", "Speedy Lille"])
        let nord = try store.fetch(FetchDescriptor<Garage>()).first { $0.name == "Garage du Nord" }!
        XCTAssertEqual(nord.interventions.count, 3)
        XCTAssertEqual(try GarageMigrator.run(in: store), GarageMigrator.Result(created: 0, linked: 0))
    }
}

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

    func testSortsByMileageWhenSameDate() throws {
        let second = Intervention(date: T.date("2024-01-01"), mileage: 20, kind: .entretien)
        second.garage = "GARAGE DU NORD"
        ctx.insert(second); second.car = car
        let first = Intervention(date: T.date("2024-01-01"), mileage: 10, kind: .entretien)
        first.garage = "Garage du Nord"
        ctx.insert(first); first.car = car

        try GarageMigrator.run(in: ctx)
        XCTAssertEqual(try garages().map(\.name), ["Garage du Nord"])
    }

    func testLinkedRowIsMarkedButNotCounted() throws {
        let a = Garage(name: "A")
        ctx.insert(a)
        let i = add("2024-01-01", garage: "Speedy")
        i.garageRef = a

        XCTAssertEqual(try GarageMigrator.run(in: ctx), GarageMigrator.Result(created: 0, linked: 0))
        XCTAssertEqual(try garages().map(\.name), ["A"])
        XCTAssertTrue(i.garageRef === a)
        XCTAssertTrue(i.garageTextMigrated)
        XCTAssertEqual(i.garage, "Speedy")
    }

    func testOpensVersion10StoreAndConverts() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tmp) }
        let storeURL = try T.copyV10Fixture(to: tmp)

        let container = try ModelContainer(for: Schema(SchemaModels.all),
                                           configurations: ModelConfiguration(url: storeURL))
        let store = ModelContext(container)
        let interventions = try store.fetch(FetchDescriptor<Intervention>(sortBy: [SortDescriptor(\.title)]))
        XCTAssertEqual(interventions.count, 5)
        XCTAssertEqual(try store.fetchCount(FetchDescriptor<Car>()), 1)
        XCTAssertTrue(interventions.allSatisfy { $0.car != nil })
        XCTAssertEqual(interventions.compactMap(\.amountCents).reduce(0, +), 123_990)
        XCTAssertEqual(interventions.map(\.title), (1...5).map { "Intervention \($0)" })

        XCTAssertEqual(try GarageMigrator.run(in: store), GarageMigrator.Result(created: 2, linked: 4))
        let names = try store.fetch(FetchDescriptor<Garage>(sortBy: [SortDescriptor(\.name)])).map(\.name)
        XCTAssertEqual(names, ["Garage du Nord", "Speedy Lille"])
        let nord = try store.fetch(FetchDescriptor<Garage>()).first { $0.name == "Garage du Nord" }!
        XCTAssertEqual(nord.interventions.count, 3)
        XCTAssertEqual(interventions.first { $0.title == "Intervention 2" }?.garage, "garage  du NORD ")
        XCTAssertEqual(interventions.compactMap(\.amountCents).reduce(0, +), 123_990)
        XCTAssertEqual(try GarageMigrator.run(in: store), GarageMigrator.Result(created: 0, linked: 0))
    }
}

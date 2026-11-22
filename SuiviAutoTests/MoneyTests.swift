import XCTest
@testable import SuiviAuto

final class MoneyTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(Money.parse("189,90"), 18_990)
        XCTAssertEqual(Money.parse("189.9"), 18_990)
        XCTAssertEqual(Money.parse("1 234,5 €"), 123_450)
        XCTAssertEqual(Money.parse("1\u{202F}234,56\u{00A0}€"), 123_456)
        XCTAssertEqual(Money.parse("42"), 4_200)
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("abc"))
        XCTAssertNil(Money.parse("12abc"))
        XCTAssertNil(Money.parse("-5"))
        XCTAssertNil(Money.parse("1,234"))
        XCTAssertNil(Money.parse("99999999999"))
        XCTAssertEqual(Money.parse("999999999,99"), 99_999_999_999)
    }

    func testEditString() {
        XCTAssertEqual(Money.editString(cents: 18_990), "189,90")
        XCTAssertEqual(Money.editString(cents: 5), "0,05")
        XCTAssertEqual(Money.editString(cents: -5), "-0,05")
        XCTAssertEqual(Money.editString(cents: -18_990), "-189,90")
    }

    func testFormat() {
        let s = Money.format(cents: 123_456)
        XCTAssertTrue(s.contains("234,56"), s)
        XCTAssertTrue(s.contains("€"), s)
    }
}

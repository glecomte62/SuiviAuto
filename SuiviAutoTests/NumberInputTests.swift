import XCTest
@testable import SuiviAuto

final class NumberInputTests: XCTestCase {
    func testPlainDigits() {
        XCTAssertEqual(NumberInput.parseInt("15000"), 15000)
        XCTAssertEqual(NumberInput.parseInt("0"), 0)
    }

    func testStripsSpacesAndNonBreakingSpaces() {
        XCTAssertEqual(NumberInput.parseInt(" 15 000 "), 15000)
        XCTAssertEqual(NumberInput.parseInt("15\u{00A0}000"), 15000)
        XCTAssertEqual(NumberInput.parseInt("120\u{202F}000"), 120000)
    }

    func testRejectsEmptyAndBlank() {
        XCTAssertNil(NumberInput.parseInt(""))
        XCTAssertNil(NumberInput.parseInt("   "))
    }

    func testRejectsNegativeAndNonDigits() {
        XCTAssertNil(NumberInput.parseInt("-5"))
        XCTAssertNil(NumberInput.parseInt("12a"))
        XCTAssertNil(NumberInput.parseInt("1,5"))
        XCTAssertNil(NumberInput.parseInt("+3"))
        XCTAssertNil(NumberInput.parseInt("١٢")) // chiffres non ASCII
    }

    func testRejectsMoreThanNineDigits() {
        XCTAssertEqual(NumberInput.parseInt("999999999"), 999_999_999)
        XCTAssertNil(NumberInput.parseInt("1000000000"))
    }
}

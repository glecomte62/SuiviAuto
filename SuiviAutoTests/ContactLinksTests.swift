import XCTest
@testable import SuiviAuto

final class ContactLinksTests: XCTestCase {
    func testPhone() {
        XCTAssertEqual(ContactLinks.phoneURL("01 23 45 67 89")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL(" +33 6 12-34.56.78 ")?.absoluteString, "tel:+33612345678")
        XCTAssertNil(ContactLinks.phoneURL("standard"))
        XCTAssertNil(ContactLinks.phoneURL(""))
    }

    func testMail() {
        XCTAssertEqual(ContactLinks.mailURL(" atelier@garage.fr ")?.absoluteString, "mailto:atelier@garage.fr")
        XCTAssertNil(ContactLinks.mailURL("atelier"))
        XCTAssertNil(ContactLinks.mailURL("a b@c.fr"))
        XCTAssertNil(ContactLinks.mailURL(""))
    }

    func testMaps() {
        XCTAssertEqual(ContactLinks.mapsURL("12 rue de la Paix\n59000 Lille")?.absoluteString,
                       "https://maps.apple.com/?q=12%20rue%20de%20la%20Paix,%2059000%20Lille")
        XCTAssertNil(ContactLinks.mapsURL("  \n "))
    }

    func testWeb() {
        XCTAssertEqual(ContactLinks.webURL("garage-du-nord.fr")?.absoluteString, "https://garage-du-nord.fr")
        XCTAssertEqual(ContactLinks.webURL("http://exemple.fr/page")?.absoluteString, "http://exemple.fr/page")
        XCTAssertNil(ContactLinks.webURL("pas un site"))
        XCTAssertNil(ContactLinks.webURL(""))
    }
}

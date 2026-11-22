import XCTest
@testable import SuiviAuto

final class ContactLinksTests: XCTestCase {
    func testPhone() {
        XCTAssertEqual(ContactLinks.phoneURL("01 23 45 67 89")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL(" +33 6 12-34.56.78 ")?.absoluteString, "tel:+33612345678")
        XCTAssertNil(ContactLinks.phoneURL("standard"))
        XCTAssertEqual(ContactLinks.phoneURL("01 23 45 67 89 poste 12")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL("01 23 45 67 89 ext. 12")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL("0123456789x12")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL("01 23 45 67 89 / 06 11 22 33 44")?.absoluteString, "tel:0123456789")
        XCTAssertEqual(ContactLinks.phoneURL("+33 (0)6 12 34 56 78")?.absoluteString, "tel:+33612345678")
        XCTAssertEqual(ContactLinks.phoneURL("Tél. +33 6 12 34 56 78")?.absoluteString, "tel:+33612345678")
        XCTAssertNil(ContactLinks.phoneURL(""))
    }

    func testMail() {
        XCTAssertEqual(ContactLinks.mailURL(" atelier@garage.fr ")?.absoluteString, "mailto:atelier@garage.fr")
        XCTAssertNil(ContactLinks.mailURL("atelier"))
        XCTAssertNil(ContactLinks.mailURL("a b@c.fr"))
        XCTAssertNil(ContactLinks.mailURL(""))
        XCTAssertNil(ContactLinks.mailURL("a@b.fr?subject=x"))
        XCTAssertNil(ContactLinks.mailURL("a@b.fr&cc=c@d.fr"))
        XCTAssertNil(ContactLinks.mailURL("a@b.fr,c@d.fr"))
        XCTAssertNil(ContactLinks.mailURL("<a@b.fr>"))
        XCTAssertNil(ContactLinks.mailURL("a\u{0}@b.fr"))
        XCTAssertNil(ContactLinks.mailURL("@"))
        XCTAssertNil(ContactLinks.mailURL("a@"))
        XCTAssertNil(ContactLinks.mailURL("@b.fr"))
        XCTAssertNil(ContactLinks.mailURL("a@b"))
        XCTAssertNil(ContactLinks.mailURL("a@b@c.fr"))
    }

    func testMaps() {
        XCTAssertEqual(ContactLinks.mapsURL("12 rue de la Paix\n59000 Lille")?.absoluteString,
                       "https://maps.apple.com/?q=12%20rue%20de%20la%20Paix,%2059000%20Lille")
        XCTAssertNil(ContactLinks.mapsURL("  \n "))
        let plus = ContactLinks.mapsURL("A+B rue & co")?.absoluteString ?? ""
        XCTAssertTrue(plus.contains("A%2BB"), plus)
        XCTAssertTrue(plus.contains("%26"), plus)
    }

    func testWeb() {
        XCTAssertEqual(ContactLinks.webURL("garage-du-nord.fr")?.absoluteString, "https://garage-du-nord.fr")
        XCTAssertEqual(ContactLinks.webURL("http://exemple.fr/page")?.absoluteString, "http://exemple.fr/page")
        XCTAssertNil(ContactLinks.webURL("pas un site"))
        XCTAssertNil(ContactLinks.webURL(""))
        XCTAssertEqual(ContactLinks.webURL("HTTPS://Exemple.fr")?.absoluteString, "HTTPS://Exemple.fr")
        XCTAssertNil(ContactLinks.webURL("file:///etc/passwd"))
        XCTAssertNil(ContactLinks.webURL("ftp://exemple.fr"))
        XCTAssertNil(ContactLinks.webURL("javascript:alert(1)"))
        XCTAssertNil(ContactLinks.webURL("localhost"))
        XCTAssertNil(ContactLinks.webURL("https://"))
    }
}

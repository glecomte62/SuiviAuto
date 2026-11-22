import XCTest
@testable import SuiviAuto

final class InvoiceTextParserTests: XCTestCase {
    let invoice = """
    GARAGE DU NORD - 12 rue de la Paix 59000 Lille
    Tél. 03 20 00 00 00
    FACTURE N° 2026-0142          Date : 05/03/2026
    Véhicule : Renault Clio AB-123-CD    Kilométrage : 45 230 km
    Vidange huile moteur 5W30            4,5 L     62,10
    Filtre à huile                                 14,90
    Plaquettes de frein AV                         89,00
    Total HT                                      158,25
    TVA 20 %                                       31,65
    Total TTC                                     189,90 €
    """

    func testFullInvoice() {
        let r = InvoiceTextParser.parse(invoice, calendar: T.calendar)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.mileage, 45_230)
        XCTAssertEqual(r.operations, [.vidange, .freins, .filtres])
        XCTAssertFalse(r.isEmpty)
    }

    func testNetAPayerAndTextualDate() {
        let r = InvoiceTextParser.parse("""
        Devis du 12 mars 2026
        Remplacement kit distribution + pompe à eau
        Montant HT 1 041,67
        Net à payer : 1 250,00 EUR
        """, calendar: T.calendar)
        XCTAssertEqual(r.date, T.date("2026-03-12"))
        XCTAssertEqual(r.amountCents, 125_000)
        XCTAssertNil(r.mileage)
        XCTAssertEqual(r.operations, [.courroie])
    }

    func testShortYearAndDotsAndKmLabel() {
        let r = InvoiceTextParser.parse("""
        Le 07.11.25 — KM compteur 123456
        TOTAL 49,90
        """, calendar: T.calendar)
        XCTAssertEqual(r.date, T.date("2025-11-07"))
        XCTAssertEqual(r.mileage, 123_456)
        XCTAssertEqual(r.amountCents, 4_990)
    }

    func testPrefersTTCOverHTAndIgnoresInvalidValues() {
        let r = InvoiceTextParser.parse("""
        31/02/2026 date invalide
        Total HT 100,00
        Total TTC 120,00
        Pression 2 km
        """, calendar: T.calendar)
        XCTAssertNil(r.date)
        XCTAssertEqual(r.amountCents, 12_000)
        XCTAssertNil(r.mileage)
    }

    func testEmpty() {
        XCTAssertTrue(InvoiceTextParser.parse("Merci de votre visite", calendar: T.calendar).isEmpty)
    }
}

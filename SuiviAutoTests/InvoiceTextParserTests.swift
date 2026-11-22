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

    // MARK: - Revue de code

    func parse(_ s: String, now: Date = T.date("2026-11-22")) -> InvoiceExtraction {
        InvoiceTextParser.parse(s, calendar: T.calendar, now: now)
    }

    /// C1 : une fois les colonnes remises en lignes, le libellé et le montant sont sur la même ligne.
    func testColumnRowsJoinedBySpaces() {
        let r = parse("FACTURE N° 2026-0142   Date : 05/03/2026\nKilométrage   45 230 km\nTotal HT   158,25\nTotal TTC   189,90 €")
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertEqual(r.mileage, 45_230)
    }

    /// I3 : la date de la facture, pas celle de mise en circulation, d'échéance, de validité ou un numéro de téléphone.
    func testPrefersInvoiceDate() {
        let rows: [(String, String)] = [
            ("Tél. 06.12.10.24.55\nLille, le 05/03/2026", "2026-03-05"),
            ("Portable 07.11.25.33.44\nArras le 05/03/2026", "2026-03-05"),
            ("Fax 03.11.24.00.00\n05/03/2026", "2026-03-05"),
            ("Date d'échéance : 30/04/2026\nFacture du 15/03/2026", "2026-03-15"),
            ("Échéance : 30/04/2026\nDate facture : 15/03/2026", "2026-03-15"),
            ("Date d'échéance 30/04/2026  Facture du 15/03/2026", "2026-03-15"),
            ("Devis valable jusqu'au 15/04/2026\nArras, le 15/03/2026", "2026-03-15"),
            ("Validité de l'offre : 15/04/2026\nLe 15/03/2026", "2026-03-15"),
            ("Facture N° 4512\nDate 1ère MEC : 12/06/2018\nDate : 05/03/2026", "2026-03-05"),
            ("Date MEC 12/06/2018 Facture 05/03/2026", "2026-03-05"),
            ("Mise en circulation : 01/01/2018\n05/03/2026", "2026-03-05"),
            ("1re immatriculation 01/01/2018\n05/03/2026", "2026-03-05"),
            ("Atelier mécanique\nFacture du 05/03/2026", "2026-03-05"),
            ("Date 05/03/98", "1998-03-05"),
            ("Date 05/03/27", "2027-03-05"),
        ]
        for (text, expected) in rows {
            XCTAssertEqual(parse(text).date, T.date(expected), text)
        }
    }

    func testRejectsDatesMoreThanOneYearAhead() {
        XCTAssertEqual(parse("Garantie 05/03/2031\nFacture 05/03/2026").date, T.date("2026-03-05"))
        XCTAssertNil(parse("05/03/2031").date)
        XCTAssertEqual(parse("Date 01/11/2027").date, T.date("2027-11-01"))
    }

    func testAbbreviatedMonths() {
        XCTAssertEqual(parse("Le 05 mars. 2026").date, T.date("2026-03-05"))
        XCTAssertEqual(parse("Le 5 janv. 2026").date, T.date("2026-01-05"))
        XCTAssertEqual(parse("Le 12 fév 2026").date, T.date("2026-02-12"))
        XCTAssertEqual(parse("Le 3 sept. 2026").date, T.date("2026-09-03"))
        XCTAssertEqual(parse("Le 3 juil 2026").date, T.date("2026-07-03"))
        XCTAssertEqual(parse("DATE: 5 MARS 2026").date, T.date("2026-03-05"))
    }

    /// I4/I5 : kilométrage relevé, pas celui de la prochaine révision.
    func testMileageLabels() {
        let rows = [
            "Prochaine vidange à 60 000 km\nKilométrage : 45 230",
            "Kilom. 45 230",
            "Kilomètres : 45 230",
            "Km entrée : 45 230",
            "Compteur : 45 230",
            "Kilométrage\n45 230",
            "Kilométrage relevé: 45 230",
            "Km au compteur 45 230",
            "Tél 03 20 45 67 89 Km 45230",
            "Kilométrage : 45 230 59000 Lille",
            "Km : 45 230 125,00",
            "Révision tous les 20 000 km\nVéhicule 45 230 km",
            "Garantie 100 000 km\nKm 45 230",
        ]
        for text in rows { XCTAssertEqual(parse(text).mileage, 45_230, text) }
    }

    func testMileageNeedsWordBoundary() {
        XCTAssertNil(parse("Parking skm 12345").mileage)
        XCTAssertNil(parse("Prochain entretien à faire à 60 000 km").mileage)
    }

    func testAmountWithoutCentsAndNegativeLines() {
        XCTAssertEqual(parse("Total TTC 190 €").amountCents, 19_000)
        XCTAssertEqual(parse("Total TTC 1 250 EUR").amountCents, 125_000)
        XCTAssertEqual(parse("Total TTC 189,90 €\nAvoir TTC -250,00").amountCents, 18_990)
        XCTAssertEqual(parse("Total TTC -50,00\nNet à payer 139,90").amountCents, 13_990)
    }
}

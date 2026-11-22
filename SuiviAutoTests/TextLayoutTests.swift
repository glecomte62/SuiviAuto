import CoreGraphics
import XCTest
@testable import SuiviAuto

final class TextLayoutTests: XCTestCase {
    /// Facture en deux colonnes, fragments donnés colonne par colonne (comme Vision ou PDFKit).
    func testTwoColumnInvoiceYAxisUp() {
        let left = ["FACTURE N° 2026-0142", "Kilométrage", "Total HT", "Total TTC"]
        let right = ["Date : 05/03/2026", "45 230 km", "158,25", "189,90 €"]
        var fragments: [(text: String, rect: CGRect)] = []
        for (i, s) in left.enumerated() { fragments.append((s, CGRect(x: 40, y: 780 - CGFloat(i) * 20, width: 120, height: 12))) }
        for (i, s) in right.enumerated() { fragments.append((s, CGRect(x: 470, y: 781 - CGFloat(i) * 20, width: 80, height: 11))) }
        XCTAssertEqual(TextLayout.rows(fragments, yAxisUp: true), """
        FACTURE N° 2026-0142   Date : 05/03/2026
        Kilométrage   45 230 km
        Total HT   158,25
        Total TTC   189,90 €
        """)
    }

    func testYAxisDownAndLeftToRight() {
        let fragments: [(text: String, rect: CGRect)] = [
            ("B", CGRect(x: 0.6, y: 0.10, width: 0.1, height: 0.02)),
            ("A", CGRect(x: 0.1, y: 0.10, width: 0.1, height: 0.02)),
            ("C", CGRect(x: 0.1, y: 0.20, width: 0.1, height: 0.02)),
        ]
        XCTAssertEqual(TextLayout.rows(fragments, yAxisUp: false), "A   B\nC")
        XCTAssertEqual(TextLayout.rows(fragments, yAxisUp: true), "C\nA   B")
    }

    func testCloseButDistinctLinesStaySeparate() {
        let fragments: [(text: String, rect: CGRect)] = [
            ("haut", CGRect(x: 0, y: 100, width: 50, height: 10)),
            ("bas", CGRect(x: 60, y: 89, width: 50, height: 10)),
        ]
        XCTAssertEqual(TextLayout.rows(fragments, yAxisUp: true), "haut\nbas")
        XCTAssertEqual(TextLayout.rows([], yAxisUp: true), "")
    }
}

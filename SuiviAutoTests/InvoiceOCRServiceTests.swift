import AppKit
import PDFKit
import XCTest
@testable import SuiviAuto

final class InvoiceOCRServiceTests: XCTestCase {
    let text = "FACTURE du 05/03/2026\nVidange + filtre a huile\nKilometrage : 45 230 km\nTotal TTC 189,90 EUR"
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// Rend le texte en noir sur blanc, grand corps, dans une image PNG.
    func makePNG() throws -> URL {
        let size = NSSize(width: 1400, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill(); NSRect(origin: .zero, size: size).fill()
        (text as NSString).draw(in: NSRect(x: 40, y: 40, width: 1320, height: 520),
                                withAttributes: [.font: NSFont.systemFont(ofSize: 44), .foregroundColor: NSColor.black])
        image.unlockFocus()
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let url = dir.appendingPathComponent("facture.png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    /// PDF avec couche texte (comme une facture générée par un logiciel de garage).
    func makePDF() throws -> URL {
        let url = dir.appendingPathComponent("facture.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        (text as NSString).draw(in: NSRect(x: 40, y: 500, width: 500, height: 300),
                                withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    func testPDFTextLayer() async throws {
        let r = try await InvoiceOCRService.analyze(fileAt: try makePDF(), calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertEqual(r.mileage, 45_230)
    }

    func testImageThroughVision() async throws {
        let r = try await InvoiceOCRService.analyze(fileAt: try makePNG(), calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertTrue(r.operations.contains(.vidange))
    }

    func testUnsupportedFile() async throws {
        let url = dir.appendingPathComponent("x.txt")
        try Data("x".utf8).write(to: url)
        do {
            _ = try await InvoiceOCRService.analyze(fileAt: url, calendar: T.calendar)
            XCTFail("doit échouer")
        } catch {}
    }

    // MARK: - Revue de code

    /// Facture en deux colonnes : libellés à gauche, valeurs tout à droite.
    func makeTwoColumnPNG() throws -> URL {
        let w = 1700, h = 900
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(.white); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let rows = [("FACTURE N° 2026-0142", "Date : 05/03/2026"), ("Kilométrage", "45 230 km"),
                    ("Vidange huile moteur", "62,10"), ("Total HT", "158,25"), ("Total TTC", "189,90 €")]
        let font = NSFont.systemFont(ofSize: 36)
        for (i, (l, r)) in rows.enumerated() {
            for (x, s) in [(60.0, l), (1250.0, r)] {
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.black]))
                ctx.textPosition = CGPoint(x: x, y: CGFloat(h - 80 - i * 70)); CTLineDraw(line, ctx)
            }
        }
        let url = dir.appendingPathComponent("colonnes.png")
        try NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    /// PDF sans couche texte : l'image de la facture posée sur la page (scan), avec éventuellement un filigrane texte.
    func makeScannedPDF(name: String = "scan.pdf", watermark: String? = nil) throws -> URL {
        let png = try makePNG()
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(png as CFURL, nil)!, 0, nil)!
        let url = dir.appendingPathComponent(name)
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        ctx.draw(image, in: CGRect(x: 20, y: 500, width: 555, height: 238))
        if let watermark {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            (watermark as NSString).draw(at: NSPoint(x: 40, y: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 8)])
            NSGraphicsContext.restoreGraphicsState()
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    func testTwoColumnImage() async throws {
        let r = try await InvoiceOCRService.analyze(fileAt: try makeTwoColumnPNG(), calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertEqual(r.mileage, 45_230)
    }

    /// PDF généré colonne par colonne : PDFKit rend « Total TTC » loin de « 189,90 € » dans `string`.
    func testTwoColumnPDFTextLayer() async throws {
        let url = dir.appendingPathComponent("colonnes.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        let rows = [("FACTURE N° 2026-0142", "Date : 05/03/2026"), ("Kilométrage", "45 230 km"), ("Vidange huile moteur", "62,10"),
                    ("Total HT", "158,25"), ("TVA 20 %", "31,65"), ("Total TTC", "189,90 €")]
        let font = NSFont.systemFont(ofSize: 11)
        for (x, column) in [(40.0, rows.map(\.0)), (470.0, rows.map(\.1))] {
            for (i, s) in column.enumerated() {
                ctx.textPosition = CGPoint(x: x, y: 780 - CGFloat(i) * 20)
                CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font])), ctx)
            }
        }
        ctx.endPDFPage(); ctx.closePDF()
        let r = try await InvoiceOCRService.analyze(fileAt: url, calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
        XCTAssertEqual(r.mileage, 45_230)
    }

    func testScannedPDFWithoutTextLayer() async throws {
        let r = try await InvoiceOCRService.analyze(fileAt: try makeScannedPDF(), calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
        XCTAssertEqual(r.date, T.date("2026-03-05"))
    }

    func testRotatedScannedPDF() async throws {
        let source = try makeScannedPDF()
        let doc = try XCTUnwrap(PDFDocument(url: source))
        doc.page(at: 0)?.rotation = 90
        let url = dir.appendingPathComponent("tourne.pdf")
        XCTAssertTrue(doc.write(to: url))
        XCTAssertEqual(PDFDocument(url: url)?.page(at: 0)?.rotation, 90)
        let r = try await InvoiceOCRService.analyze(fileAt: url, calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
    }

    /// Un filigrane « Numérisé avec CamScanner » ne doit pas masquer l'image numérisée.
    func testScannerWatermarkTextLayerFallsBackToOCR() async throws {
        let url = try makeScannedPDF(watermark: "Numérisé avec CamScanner")
        XCTAssertTrue(PDFDocument(url: url)?.string?.contains("CamScanner") ?? false)
        let r = try await InvoiceOCRService.analyze(fileAt: url, calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
    }

    func testTIFFImage() async throws {
        let png = try makePNG()
        let url = dir.appendingPathComponent("facture.tiff")
        try NSBitmapImageRep(data: try Data(contentsOf: png))!.representation(using: .tiff, properties: [:])!.write(to: url)
        let r = try await InvoiceOCRService.analyze(fileAt: url, calendar: T.calendar)
        XCTAssertEqual(r.amountCents, 18_990)
    }
}

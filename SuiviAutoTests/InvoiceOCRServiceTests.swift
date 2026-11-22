import AppKit
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
}

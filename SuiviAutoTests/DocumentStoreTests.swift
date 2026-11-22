import XCTest
@testable import SuiviAuto

final class DocumentStoreTests: XCTestCase {
    var root: URL!
    var store: DocumentStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = DocumentStore(directory: root.appendingPathComponent("Documents"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeFile(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("contenu".utf8).write(to: url)
        return url
    }

    func testImportCopiesFile() throws {
        let src = try makeFile("Facture Garage.PDF")
        let doc = try store.importFile(at: src)
        XCTAssertEqual(doc.originalName, "Facture Garage.PDF")
        XCTAssertEqual(doc.kind, .pdf)
        XCTAssertTrue(doc.fileName.hasSuffix(".pdf"))
        XCTAssertTrue(store.fileExists(for: doc))
        XCTAssertEqual(try Data(contentsOf: store.url(for: doc)), Data("contenu".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path), "l'original reste en place")
    }

    func testImageKinds() throws {
        for name in ["a.jpg", "b.jpeg", "c.png", "d.HEIC"] {
            XCTAssertEqual(try store.importFile(at: try makeFile(name)).kind, .image)
        }
    }

    func testRejectsUnsupportedFormat() throws {
        let src = try makeFile("devis.docx")
        XCTAssertThrowsError(try store.importFile(at: src)) { error in
            XCTAssertEqual(error as? DocumentStore.ImportError, .unsupportedFormat("devis.docx"))
        }
    }

    func testMissingFileAndDelete() throws {
        let doc = try store.importFile(at: try makeFile("x.pdf"))
        store.delete(fileName: doc.fileName)
        XCTAssertFalse(store.fileExists(for: doc))
        store.delete(fileName: doc.fileName) // deuxième suppression : aucune erreur
    }
}

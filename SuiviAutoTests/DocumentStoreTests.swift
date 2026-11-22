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

    // MARK: - Fichiers orphelins

    func testRemoveOrphansKeepsReferencedAndRecentFiles() throws {
        let kept = try store.importFile(at: try makeFile("facture.pdf"))
        let recent = try store.importFile(at: try makeFile("en-attente.pdf"))
        let deleted = try store.removeOrphans(referenced: [kept.fileName], now: .now)
        XCTAssertEqual(deleted, [], "fichier non référencé de moins d'une heure : peut-être en cours d'ajout")
        XCTAssertTrue(store.fileExists(for: kept))
        XCTAssertTrue(store.fileExists(for: recent))
    }

    func testRemoveOrphansDeletesOldUnreferencedFiles() throws {
        let kept = try store.importFile(at: try makeFile("facture.pdf"))
        let orphan = try store.importFile(at: try makeFile("perdu.png"))
        let deleted = try store.removeOrphans(referenced: [kept.fileName], now: Date.now.addingTimeInterval(2 * 3600))
        XCTAssertEqual(deleted, [orphan.fileName])
        XCTAssertTrue(store.fileExists(for: kept), "un fichier référencé n'est jamais supprimé, même ancien")
        XCTAssertFalse(store.fileExists(for: orphan))
    }

    func testRemoveOrphansHonoursCustomAge() throws {
        let orphan = try store.importFile(at: try makeFile("perdu.pdf"))
        let later = Date.now.addingTimeInterval(120)
        XCTAssertEqual(try store.removeOrphans(referenced: [], olderThan: 3600, now: later), [])
        XCTAssertEqual(try store.removeOrphans(referenced: [], olderThan: 60, now: later), [orphan.fileName])
    }

    func testRemoveOrphansIgnoresHiddenFilesAndMissingDirectory() throws {
        XCTAssertEqual(try store.removeOrphans(referenced: [], now: .now), [], "dossier absent : rien à faire")
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let hidden = store.directory.appendingPathComponent(".DS_Store")
        try Data().write(to: hidden)
        XCTAssertEqual(try store.removeOrphans(referenced: [], now: Date.now.addingTimeInterval(7200)), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: hidden.path))
    }
}

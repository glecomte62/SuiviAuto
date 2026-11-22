import AppKit
import XCTest
@testable import SuiviAuto

final class ImageResizerTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makePNG(width: Int, height: Int) throws -> URL {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let url = dir.appendingPathComponent("\(width)x\(height).png")
        try data.write(to: url)
        return url
    }

    private func size(of data: Data?) throws -> (Int, Int) {
        let rep = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(data)))
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    func testLandscapeKeepsWholeImageAndRatio() throws {
        let (w, h) = try size(of: ImageResizer.jpegData(from: makePNG(width: 3000, height: 1500)))
        XCTAssertEqual(w, 1024, accuracy: 1)
        XCTAssertEqual(h, 512, accuracy: 1)
    }

    func testPortraitKeepsWholeImageAndRatio() throws {
        let (w, h) = try size(of: ImageResizer.jpegData(from: makePNG(width: 1000, height: 3000)))
        XCTAssertEqual(w, 341, accuracy: 1)
        XCTAssertEqual(h, 1024, accuracy: 1)
    }
}

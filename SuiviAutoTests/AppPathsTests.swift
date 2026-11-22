import XCTest
@testable import SuiviAuto

final class AppPathsTests: XCTestCase {
    func testPathsLiveInApplicationSupport() {
        XCTAssertEqual(AppPaths.baseURL.lastPathComponent, "SuiviAuto")
        XCTAssertEqual(AppPaths.baseURL.deletingLastPathComponent().lastPathComponent, "Application Support")
        XCTAssertEqual(AppPaths.storeURL.lastPathComponent, "SuiviAuto.store")
        XCTAssertEqual(AppPaths.documentsURL.deletingLastPathComponent(), AppPaths.baseURL)
        XCTAssertEqual(AppPaths.pendingRestoreURL.lastPathComponent, "SuiviAuto-PendingRestore")
        XCTAssertFalse(AppPaths.baseURL.path.contains("Mobile Documents"))
    }
}

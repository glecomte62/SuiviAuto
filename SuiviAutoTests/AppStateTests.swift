import XCTest
@testable import SuiviAuto

final class AppStateTests: XCTestCase {
    func testLocalSheetCountsAsPresentingSheet() {
        let state = AppState()
        XCTAssertFalse(state.isPresentingSheet)
        state.localSheetCount = 1
        XCTAssertTrue(state.isPresentingSheet)
    }
}

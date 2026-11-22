import XCTest
@testable import SuiviAuto

final class PurchaseValidationTests: XCTestCase {
    func testSameDayPurchaseIsAllowedEvenWithDifferentTimes() {
        let reg = T.date("2026-03-01", hour: 18)
        let purchase = T.date("2026-03-01", hour: 9)
        XCTAssertTrue(PurchaseValidation.isDateValid(purchase: purchase, firstRegistration: reg, calendar: T.calendar))
    }

    func testPurchaseBeforeRegistrationDayIsRejected() {
        XCTAssertFalse(PurchaseValidation.isDateValid(purchase: T.date("2026-02-28", hour: 23),
                                                      firstRegistration: T.date("2026-03-01", hour: 1), calendar: T.calendar))
    }

    func testUsedPurchaseRequiresMileage() {
        XCTAssertFalse(PurchaseValidation.isComplete(usedPurchase: true, mileage: nil))
        XCTAssertTrue(PurchaseValidation.isComplete(usedPurchase: true, mileage: 0))
        XCTAssertTrue(PurchaseValidation.isComplete(usedPurchase: false, mileage: nil))
    }
}

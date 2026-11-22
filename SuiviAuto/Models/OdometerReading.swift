import Foundation
import SwiftData

@Model
final class OdometerReading {
    var date: Date = Date.now
    var mileage: Int = 0
    var car: Car?

    init(date: Date, mileage: Int) {
        self.date = date
        self.mileage = mileage
    }
}

import Foundation

enum PurchaseValidation {
    /// La date d'achat doit être le jour de la 1re immatriculation ou après (comparaison par jour calendaire).
    static func isDateValid(purchase: Date, firstRegistration: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: purchase) >= calendar.startOfDay(for: firstRegistration)
    }

    /// Une voiture d'occasion exige le kilométrage à l'achat.
    static func isComplete(usedPurchase: Bool, mileage: Int?) -> Bool {
        !usedPurchase || mileage != nil
    }
}

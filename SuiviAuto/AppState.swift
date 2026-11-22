import Observation

@Observable
final class AppState {
    var showingNewCar = false
    var showingNewIntervention = false
    var showingNewReading = false
    var errorMessage: String?

    init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }
}

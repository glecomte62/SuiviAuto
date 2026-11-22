import Observation

@Observable
final class AppState {
    var showingNewCar = false
    var showingNewIntervention = false
    var showingNewReading = false
    var errorMessage: String?
    /// Feuilles ouvertes localement par les vues (voir `tracksSheetPresentation()`).
    var localSheetCount = 0

    var isPresentingSheet: Bool {
        showingNewCar || showingNewIntervention || showingNewReading || localSheetCount > 0
    }

    init(errorMessage: String? = nil) {
        self.errorMessage = errorMessage
    }
}

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Car.createdAt) private var cars: [Car]

    @State private var selection: SidebarItem? = .dashboard
    @State private var selectedIntervention: Intervention?
    @State private var carTab: CarTab = .interventions
    @State private var rescheduleTask: Task<Void, Never>?

    private var selectedCar: Car? {
        if case .car(let car) = selection { return car }
        return nil
    }

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            SidebarView(cars: cars, selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } content: {
            Group {
                if let car = selectedCar {
                    CarContentView(car: car, tab: $carTab, selectedIntervention: $selectedIntervention,
                                   onDeleteCar: { delete(car) })
                } else {
                    DueListView(items: DueAggregator.items(for: cars), hasCars: !cars.isEmpty)
                }
            }
            .navigationSplitViewColumnWidth(min: 340, ideal: 420)
        } detail: {
            if let car = selectedCar {
                if carTab == .interventions, let i = selectedIntervention, i.car == car {
                    InterventionDetailView(intervention: i, onDelete: { delete(i) })
                } else {
                    CarSummaryView(car: car)
                }
            } else {
                DashboardChartsView(cars: cars)
            }
        }
        .onChange(of: selection) { selectedIntervention = nil }
        .onChange(of: appState.showingNewIntervention) { _, shown in
            if shown && selectedCar == nil {
                appState.showingNewIntervention = false
                appState.errorMessage = "Sélectionnez d'abord une voiture dans la barre latérale."
            }
        }
        .onChange(of: appState.showingNewReading) { _, shown in
            if shown && selectedCar == nil {
                appState.showingNewReading = false
                appState.errorMessage = "Sélectionnez d'abord une voiture dans la barre latérale."
            }
        }
        .sheet(isPresented: $appState.showingNewCar) {
            CarFormView(car: nil) { newCar in selection = .car(newCar) }
        }
        .sheet(isPresented: Binding(get: { appState.showingNewIntervention && selectedCar != nil },
                                    set: { appState.showingNewIntervention = $0 })) {
            if let car = selectedCar { InterventionFormView(car: car, intervention: nil) }
        }
        .sheet(isPresented: Binding(get: { appState.showingNewReading && selectedCar != nil },
                                    set: { appState.showingNewReading = $0 })) {
            if let car = selectedCar { ReadingFormView(car: car) }
        }
        .alert("Erreur", isPresented: Binding(get: { appState.errorMessage != nil },
                                               set: { if !$0 { appState.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .task {
            guard !SuiviAutoApp.isRunningTests else { return }
            await NotificationScheduler.requestAuthorization()
            reschedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            guard !SuiviAutoApp.isRunningTests else { return }
            reschedule()
        }
    }

    /// Une seule replanification à la fois : la précédente est annulée et attendue avant de recommencer.
    private func reschedule() {
        let previous = rescheduleTask
        previous?.cancel()
        rescheduleTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await NotificationScheduler.reschedule(context: context)
        }
    }

    /// On désélectionne d'abord, puis on supprime au tour suivant pour ne pas afficher un objet supprimé.
    private func delete(_ intervention: Intervention) {
        selectedIntervention = nil
        DispatchQueue.main.async {
            do { try DeletionService.delete(intervention, in: context) }
            catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
        }
    }

    private func delete(_ car: Car) {
        selectedIntervention = nil
        selection = .dashboard
        carTab = .interventions
        DispatchQueue.main.async {
            do { try DeletionService.delete(car, in: context) }
            catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
        }
    }
}

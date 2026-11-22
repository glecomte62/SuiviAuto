import SwiftData
import SwiftUI

@main
struct SuiviAutoApp: App {
    let container: ModelContainer
    @State private var appState = AppState()

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        do {
            if Self.isRunningTests {
                container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } else {
                try BackupService.applyPendingRestoreIfNeeded()
                try AppPaths.ensureDirectories()
                container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: AppPaths.storeURL))
            }
        } catch {
            fatalError("Impossible d'ouvrir la base de données : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 980, minHeight: 620)
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle voiture") { appState.showingNewCar = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Nouvelle intervention") { appState.showingNewIntervention = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Nouveau relevé km") { appState.showingNewReading = true }
                    .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(replacing: .importExport) {
                Button("Exporter une sauvegarde…") { BackupActions.exportBackup(container: container, appState: appState) }
                Button("Importer une sauvegarde…") { BackupActions.importBackup(appState: appState) }
                Divider()
                Button("Exporter l'historique en CSV…") { BackupActions.exportCSV(container: container, appState: appState) }
            }
        }
    }
}

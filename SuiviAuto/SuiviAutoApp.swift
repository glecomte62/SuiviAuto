import AppKit
import SwiftData
import SwiftUI

@main
struct SuiviAutoApp: App {
    let container: ModelContainer
    @State private var appState: AppState

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        var launchMessage: String?
        if !Self.isRunningTests {
            do {
                try BackupService.applyPendingRestoreIfNeeded()
            } catch {
                let moved = BackupService.quarantinePendingRestore()
                launchMessage = "La restauration de la sauvegarde a échoué : \(error.localizedDescription)"
                    + (moved.map { " La sauvegarde décompressée a été mise de côté dans « \($0.lastPathComponent) »." } ?? "")
            }
        }
        do {
            if Self.isRunningTests {
                container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } else {
                try AppPaths.ensureDirectories()
                container = try ModelContainer(for: Schema(SchemaModels.all),
                                               configurations: ModelConfiguration(url: AppPaths.storeURL))
            }
        } catch {
            Self.failToOpenDatabase(error)
        }
        _appState = State(initialValue: AppState(errorMessage: launchMessage))
    }

    /// Alerte bloquante puis sortie propre (au lieu d'un plantage).
    private static func failToOpenDatabase(_ error: Error) -> Never {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Impossible d'ouvrir la base de données"
        var info = "\(error.localizedDescription)\n\nEmplacement : \(AppPaths.storeURL.path)"
        if let previous = BackupService.latestSafetyCopy() {
            info += "\n\nUne copie de vos données précédentes se trouve dans : \(previous.path)"
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Quitter")
        alert.runModal()
        exit(1)
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
                    .disabled(appState.isPresentingSheet)
                Button("Nouvelle intervention") { appState.showingNewIntervention = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(appState.isPresentingSheet)
                Button("Nouveau relevé km") { appState.showingNewReading = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(appState.isPresentingSheet)
            }
            CommandGroup(replacing: .importExport) {
                Button("Exporter une sauvegarde…") { BackupActions.exportBackup(container: container, appState: appState) }
                Button("Importer une sauvegarde…") { BackupActions.importBackup(appState: appState) }
                Divider()
                Button("Exporter l'historique en CSV…") { BackupActions.exportCSV(container: container, appState: appState) }
            }
            CommandGroup(replacing: .help) {
                Button("Aide de SuiviAuto") { NSWorkspace.shared.open(HelpLinks.guide) }
                    .keyboardShortcut("?", modifiers: .command)
                Button("Signaler un problème ou proposer une idée…") { NSWorkspace.shared.open(HelpLinks.issues) }
                Button("Télécharger la dernière version…") { NSWorkspace.shared.open(HelpLinks.releases) }
            }
        }
    }
}

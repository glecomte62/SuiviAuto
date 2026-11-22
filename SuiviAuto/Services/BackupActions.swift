import AppKit
import SwiftData
import UniformTypeIdentifiers

/// Actions des menus Fichier > Exporter / Importer.
@MainActor
enum BackupActions {
    static func exportBackup(container: ModelContainer, appState: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "SuiviAuto-sauvegarde-\(Date.now.formatted(.iso8601.year().month().day())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try container.mainContext.save()
            try BackupService.exportBackup(to: url)
        } catch {
            appState.errorMessage = "Échec de la sauvegarde : \(error.localizedDescription)"
        }
    }

    static func importBackup(appState: AppState) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remplacer toutes les données ?"
        alert.informativeText = "Les données actuelles seront remplacées par la sauvegarde. Une copie est conservée dans « SuiviAuto-avant-restauration-<date> » (Application Support). L'application va redémarrer."
        alert.addButton(withTitle: "Remplacer et redémarrer")
        alert.addButton(withTitle: "Annuler")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try BackupService.stageRestore(from: url)
            BackupService.relaunch()
        } catch {
            appState.errorMessage = "Échec de l'import : \(error.localizedDescription)"
        }
    }

    static func exportCSV(container: ModelContainer, appState: AppState) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "SuiviAuto-historique.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let all = try container.mainContext.fetch(FetchDescriptor<Intervention>())
            try BackupService.csv(for: all).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            appState.errorMessage = "Échec de l'export CSV : \(error.localizedDescription)"
        }
    }
}

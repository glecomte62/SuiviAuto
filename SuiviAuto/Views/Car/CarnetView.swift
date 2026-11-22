import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Carnet d'entretien : factures de la voiture (jamais les devis), filtrées, avec total et export.
struct CarnetView: View {
    let car: Car
    @Binding var selection: Intervention?
    @Environment(AppState.self) private var appState
    @State private var query = CarnetQuery()

    var body: some View {
        let entries = Carnet.entries(for: car, query: query)
        let tint = Color(hex: car.colorHex)
        VStack(spacing: 0) {
            header(entries: entries)
            Divider()
            List(selection: $selection) {
                ForEach(entries) { i in
                    CarnetRow(intervention: i, tint: tint).tag(i)
                }
            }
            .overlay {
                if Carnet.entries(for: car, query: CarnetQuery()).isEmpty {
                    ContentUnavailableView("Aucun entretien", systemImage: "book.closed",
                                           description: Text("Les factures de cette voiture apparaîtront ici."))
                } else if entries.isEmpty {
                    ContentUnavailableView("Aucune facture ne correspond", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Exporter en PDF…") { exportPDF(entries) }
                    Button("Exporter en CSV…") { exportCSV(entries) }
                } label: { Label("Exporter", systemImage: "square.and.arrow.up") }
                .disabled(entries.isEmpty)
                .help("Exporter les factures affichées")
            }
        }
    }

    private func header(entries: [Intervention]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Rechercher (titre, opérations, garage, notes)", text: $query.text)
                    .textFieldStyle(.plain)
                if !query.text.isEmpty {
                    Button { query.text = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.6)))
            HStack(spacing: 8) {
                Picker("Opération", selection: $query.operation) {
                    Text("Toutes").tag(MaintenanceOperation?.none)
                    Divider()
                    ForEach(MaintenanceOperation.allCases) { Label($0.label, systemImage: $0.symbol).tag(Optional($0)) }
                }
                .fixedSize()
                Picker("Année", selection: $query.year) {
                    Text("Toutes").tag(Int?.none)
                    ForEach(Carnet.years(for: car), id: \.self) { Text(String($0)).tag(Optional($0)) }
                }
                .fixedSize()
                Picker("Garage", selection: $query.garageID) {
                    Text("Tous").tag(UUID?.none)
                    ForEach(Carnet.garages(for: car)) { Text($0.name).tag(Optional($0.uuid)) }
                }
                .fixedSize()
                Spacer(minLength: 8)
            }
            .controlSize(.small)
            HStack {
                Spacer()
                Text("\(entries.count) intervention\(entries.count > 1 ? "s" : "") · Total \(Money.format(cents: Carnet.totalCents(entries)))")
                    .font(.callout.bold()).monospacedDigit()
            }
        }
        .padding(10)
    }

    private var fileSafeName: String { Carnet.fileSafeName(car.name) }

    private func exportPDF(_ entries: [Intervention]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Carnet-\(fileSafeName).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let km = CarAnalytics.estimator(for: car).estimatedCurrentMileage
            try CarnetPDFExporter.render(car: car, entries: entries, estimatedMileage: km).write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch {
            appState.errorMessage = "Échec de l'export PDF : \(error.localizedDescription)"
        }
    }

    private func exportCSV(_ entries: [Intervention]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Carnet-\(fileSafeName).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BackupService.csv(for: entries).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            appState.errorMessage = "Échec de l'export CSV : \(error.localizedDescription)"
        }
    }
}

private struct CarnetRow: View {
    let intervention: Intervention
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(Fmt.shortDate(intervention.date)).font(.callout.bold())
                Text(Fmt.km(intervention.mileage)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(width: 90)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(0.45)))
            VStack(alignment: .leading, spacing: 2) {
                Text(Carnet.operationsText(intervention)).fontWeight(.medium).lineLimit(2)
                if !intervention.garageDisplayName.isEmpty {
                    Text(intervention.garageDisplayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if !intervention.documents.isEmpty {
                Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("Documents joints")
            }
            if let cents = intervention.amountCents {
                Text(Money.format(cents: cents)).fontWeight(.semibold).monospacedDigit()
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

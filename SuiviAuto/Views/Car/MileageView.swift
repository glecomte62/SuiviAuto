import Charts
import SwiftData
import SwiftUI

struct MileageView: View {
    let car: Car
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    var body: some View {
        let estimator = CarAnalytics.estimator(for: car)
        let tint = Color(hex: car.colorHex)
        ScrollView {
            VStack(spacing: 14) {
                Card(tint: tint) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kilométrage estimé aujourd'hui").font(.caption).foregroundStyle(.secondary)
                            Text(estimator.estimatedCurrentMileage.map(Fmt.km) ?? "—")
                                .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Moyenne").font(.caption).foregroundStyle(.secondary)
                            Text(estimator.kmPerDay.flatMap { $0 > 0 ? "\(Fmt.km(Int(($0 * 365).rounded()))) / an" : nil } ?? "—")
                                .font(.title3.bold()).monospacedDigit()
                        }
                    }
                }

                if estimator.points.count >= 2 {
                    Card(tint: tint) {
                        Chart {
                            ForEach(Array(estimator.points.enumerated()), id: \.offset) { _, p in
                                LineMark(x: .value("Date", p.date), y: .value("Km", p.km))
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", p.date), y: .value("Km", p.km))
                            }
                        }
                        .foregroundStyle(tint.gradient)
                        .frame(height: 200)
                    }
                }

                Card(tint: tint) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Relevés manuels").font(.headline)
                            Spacer()
                            Button { appState.showingNewReading = true } label: { Label("Nouveau relevé", systemImage: "plus") }
                                .help("⌘K")
                        }
                        if car.readings.isEmpty {
                            Text("Aucun relevé manuel. Les kilométrages des factures sont aussi pris en compte.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(car.readings.sorted { $0.date > $1.date }) { r in
                            HStack {
                                Text(Fmt.date(r.date))
                                Spacer()
                                Text(Fmt.km(r.mileage)).monospacedDigit()
                                Button(role: .destructive) {
                                    remove(r)
                                } label: { Label("Supprimer le relevé", systemImage: "trash").labelStyle(.iconOnly) }
                                .buttonStyle(.borderless)
                                .help("Supprimer le relevé")
                            }
                            Divider()
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func remove(_ reading: OdometerReading) {
        do { try DeletionService.deleteRecord(reading, in: context) }
        catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
    }
}

import SwiftUI

struct ReadingFormView: View { let car: Car; var body: some View { Text("Relevé") } }
struct MileageView: View { let car: Car; var body: some View { Text("Km") } }
struct RulesView: View { let car: Car; var body: some View { Text("Règles") } }
struct DeadlinesView: View { let car: Car; var body: some View { Text("Échéances") } }
struct CarInfoView: View { let car: Car; let onDelete: () -> Void; var body: some View { Text("Infos") } }
struct CarSummaryView: View { let car: Car; var body: some View { Text(car.name) } }
struct DueListView: View { let items: [DueItem]; let hasCars: Bool; var body: some View { Text("Échéances") } }
struct DashboardChartsView: View { let cars: [Car]; var body: some View { Text("Tableau de bord") } }

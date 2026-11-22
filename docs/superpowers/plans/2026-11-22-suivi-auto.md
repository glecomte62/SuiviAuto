# SuiviAuto — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** construire une application macOS native (SwiftUI + SwiftData) de suivi d'entretien de voitures : interventions, factures et devis archivés, contrôle technique, kilométrage estimé, rappels et notifications.

**Architecture :** une seule cible app et une cible de tests unitaires, générées par XcodeGen.
- `Logic/` : calculs purs sans SwiftData (CT, km, règles, coûts, notifications), entièrement testés.
- `Services/` : relie les modèles SwiftData à la logique (agrégation des échéances, documents, sauvegarde).
- `Views/` : SwiftUI, sans logique métier.

**Tech Stack :** Swift (mode de langage 5), SwiftUI, SwiftData, Swift Charts, QuickLookThumbnailing, UserNotifications, XCTest, XcodeGen, Xcode 27.2, macOS 27.

**Spec :** `docs/superpowers/specs/2026-11-22-suivi-auto-design.md`

---

## Conventions (à lire avant toute tâche)

- **Racine du projet** (contient des espaces, toujours entre guillemets) :
  ```bash
  PROJ="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/XCODE/SUIVIAUTO"
  cd "$PROJ"
  ```
- Tous les chemins de fichiers ci-dessous sont relatifs à `$PROJ`.
- Le `.xcodeproj` est **généré** (`xcodegen generate`) et ignoré par git. Après avoir ajouté un fichier Swift, il suffit de relancer les scripts, qui régénèrent le projet.
- Tests : `scripts/test.sh` (tous) ou `scripts/test.sh -only-testing:SuiviAutoTests/NomDeLaClasse`.
- Compilation : `scripts/build.sh`.
- Les produits de compilation vont dans `~/Library/Developer/Xcode/DerivedData/SuiviAuto-cli`, **jamais** dans iCloud.
- Les tests utilisent un calendrier grégorien **UTC** (`T.calendar`) pour éviter les décalages d'heure d'été.
- Les montants sont stockés en **centimes** (`Int`) pour rester exacts.
- Les nouveaux objets SwiftData sont rattachés ainsi : `context.insert(enfant); enfant.car = car` (on renseigne le côté « vers un » ; SwiftData met à jour le tableau inverse).

---

## Structure des fichiers

```
project.yml                                  configuration XcodeGen
scripts/build.sh, scripts/test.sh, scripts/install.sh
SuiviAuto/
  SuiviAutoApp.swift                         point d'entrée, ModelContainer, commandes de menu
  AppState.swift                             état partagé UI (feuilles ouvertes, erreurs)
  AppPaths.swift                             emplacements disque
  Resources/Assets.xcassets                  couleur d'accent
  Models/
    Enums.swift                              FuelType, InterventionKind, InterventionStatus, CTResult, DocumentKind, CarPalette
    Car.swift, Intervention.swift, StoredDocument.swift,
    OdometerReading.swift, MaintenanceRule.swift, Deadline.swift
    SchemaModels.swift                       liste des modèles du schéma
  Logic/
    DueStatus.swift                          statut ok / bientôt / dépassé et seuils
    Money.swift                              centimes <-> texte
    TechnicalInspectionCalculator.swift
    MileageEstimator.swift
    MaintenanceScheduler.swift
    CostSummary.swift
    NotificationPlanner.swift
  Services/
    CarAnalytics.swift                       modèles -> points km, coûts
    DueAggregator.swift                      modèles -> liste de DueItem
    DocumentStore.swift
    DeletionService.swift
    NotificationScheduler.swift
    BackupService.swift
    BackupActions.swift                      panneaux d'enregistrement et d'ouverture des menus
    ImageResizer.swift
  Views/
    ContentView.swift, SidebarView.swift, CarContentView.swift
    Components/  Card.swift, Badges.swift, CarAvatar.swift, Formatters.swift, UIExtensions.swift
    Interventions/ InterventionListView.swift, InterventionRow.swift, InterventionFormView.swift,
                   InterventionDetailView.swift, DocumentThumbnail.swift
    Car/  CarFormView.swift, CarInfoView.swift, CarSummaryView.swift, MileageView.swift,
          ReadingFormView.swift, RulesView.swift, RuleFormView.swift, DeadlinesView.swift, DeadlineFormView.swift
    Dashboard/ DueListView.swift, DashboardChartsView.swift
SuiviAutoTests/
  TestHelpers.swift
  AppPathsTests.swift, DueStatusTests.swift, MoneyTests.swift, TechnicalInspectionTests.swift,
  MileageEstimatorTests.swift, MaintenanceSchedulerTests.swift, CostSummaryTests.swift,
  ModelTests.swift, DueAggregatorTests.swift, DocumentStoreTests.swift, DeletionServiceTests.swift,
  NotificationPlannerTests.swift, BackupServiceTests.swift
```

---

### Task 1 : Squelette du projet, scripts et AppPaths

**Files :**
- Create: `project.yml`, `scripts/build.sh`, `scripts/test.sh`, `SuiviAuto/SuiviAutoApp.swift`, `SuiviAuto/AppPaths.swift`, `SuiviAuto/Resources/Assets.xcassets/Contents.json`, `SuiviAuto/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`, `SuiviAutoTests/TestHelpers.swift`, `SuiviAutoTests/AppPathsTests.swift`
- Modify: `.gitignore`

- [ ] **Step 1 : Installer XcodeGen**

```bash
brew install xcodegen && xcodegen --version
```
Attendu : `Version: 2.x.x`

- [ ] **Step 2 : Créer `project.yml`**

```yaml
name: SuiviAuto
options:
  bundleIdPrefix: fr.glecomte
  deploymentTarget:
    macOS: "27.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"
    DEVELOPMENT_TEAM: ""
targets:
  SuiviAuto:
    type: application
    platform: macOS
    sources:
      - SuiviAuto
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.glecomte.SuiviAuto
        PRODUCT_NAME: SuiviAuto
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: SuiviAuto
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity
        INFOPLIST_KEY_NSHumanReadableCopyright: ""
        CFBundleDevelopmentRegion: fr
        DEVELOPMENT_LANGUAGE: fr
        ENABLE_APP_SANDBOX: NO
        ENABLE_HARDENED_RUNTIME: NO
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
  SuiviAutoTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - SuiviAutoTests
    dependencies:
      - target: SuiviAuto
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: fr.glecomte.SuiviAutoTests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/SuiviAuto.app/Contents/MacOS/SuiviAuto"
        BUNDLE_LOADER: "$(TEST_HOST)"
schemes:
  SuiviAuto:
    build:
      targets:
        SuiviAuto: all
        SuiviAutoTests: [test]
    test:
      targets:
        - SuiviAutoTests
```

- [ ] **Step 3 : Créer les scripts**

`scripts/test.sh` :
```bash
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild test \
  -project SuiviAuto.xcodeproj \
  -scheme SuiviAuto \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli" \
  -quiet "$@"
echo "TESTS OK"
```

`scripts/build.sh` :
```bash
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build \
  -project SuiviAuto.xcodeproj \
  -scheme SuiviAuto \
  -configuration "${CONFIGURATION:-Debug}" \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli" \
  -quiet
echo "BUILD OK: $HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/${CONFIGURATION:-Debug}/SuiviAuto.app"
```

```bash
chmod +x scripts/*.sh
```

- [ ] **Step 4 : Compléter `.gitignore`**

Contenu complet :
```
.DS_Store
build/
DerivedData/
SuiviAuto.xcodeproj/
*.xcodeproj/xcuserdata/
```

- [ ] **Step 5 : Catalogue d'assets**

`SuiviAuto/Resources/Assets.xcassets/Contents.json` :
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`SuiviAuto/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` :
```json
{
  "colors" : [
    { "idiom" : "universal",
      "color" : { "color-space" : "srgb",
        "components" : { "red" : "0.180", "green" : "0.525", "blue" : "0.671", "alpha" : "1.000" } } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 6 : Écrire le test qui échoue**

`SuiviAutoTests/TestHelpers.swift` :
```swift
import Foundation

/// Outils de test : calendrier UTC fixe et fabrication de dates.
enum T {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "fr_FR")
        return c
    }()

    /// `T.date("2026-03-01")` ou `T.date("2026-03-01", hour: 9)`
    static func date(_ s: String, hour: Int = 0) -> Date {
        let p = s.split(separator: "-").map { Int($0)! }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hour))!
    }
}
```

`SuiviAutoTests/AppPathsTests.swift` :
```swift
import XCTest
@testable import SuiviAuto

final class AppPathsTests: XCTestCase {
    func testPathsLiveInApplicationSupport() {
        XCTAssertEqual(AppPaths.baseURL.lastPathComponent, "SuiviAuto")
        XCTAssertEqual(AppPaths.baseURL.deletingLastPathComponent().lastPathComponent, "Application Support")
        XCTAssertEqual(AppPaths.storeURL.lastPathComponent, "SuiviAuto.store")
        XCTAssertEqual(AppPaths.documentsURL.deletingLastPathComponent(), AppPaths.baseURL)
        XCTAssertEqual(AppPaths.pendingRestoreURL.lastPathComponent, "SuiviAuto-PendingRestore")
        XCTAssertFalse(AppPaths.baseURL.path.contains("Mobile Documents"))
    }
}
```

`SuiviAuto/SuiviAutoApp.swift` (temporaire, remplacé à la tâche 11) :
```swift
import SwiftUI

@main
struct SuiviAutoApp: App {
    var body: some Scene {
        WindowGroup {
            Text("SuiviAuto")
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}
```

- [ ] **Step 7 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh`
Attendu : échec de compilation `cannot find 'AppPaths' in scope`.

- [ ] **Step 8 : Implémenter `SuiviAuto/AppPaths.swift`**

```swift
import Foundation

/// Emplacements disque de l'application (hors iCloud).
enum AppPaths {
    static let baseURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SuiviAuto", isDirectory: true)

    static var storeURL: URL { baseURL.appendingPathComponent("SuiviAuto.store") }
    static var documentsURL: URL { baseURL.appendingPathComponent("Documents", isDirectory: true) }

    /// Dossier où une sauvegarde importée attend d'être appliquée au prochain lancement.
    static var pendingRestoreURL: URL {
        baseURL.deletingLastPathComponent().appendingPathComponent("SuiviAuto-PendingRestore", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 9 : Lancer les tests**

Run : `scripts/test.sh`
Attendu : `TESTS OK`

- [ ] **Step 10 : Commit**

```bash
git add -A && git commit -m "feat: squelette du projet XcodeGen, scripts et AppPaths"
```

---

### Task 2 : Énumérations du domaine

**Files :**
- Create: `SuiviAuto/Models/Enums.swift`

Pas de logique à tester, uniquement des types. Ils sont vérifiés par la compilation et utilisés dès la tâche 3.

- [ ] **Step 1 : Écrire `SuiviAuto/Models/Enums.swift`**

```swift
import Foundation

enum FuelType: String, CaseIterable, Identifiable, Codable {
    case essence, diesel, hybride, electrique, gpl, autre
    var id: String { rawValue }
    var label: String {
        switch self {
        case .essence: "Essence"
        case .diesel: "Diesel"
        case .hybride: "Hybride"
        case .electrique: "Électrique"
        case .gpl: "GPL"
        case .autre: "Autre"
        }
    }
}

enum InterventionKind: String, CaseIterable, Identifiable, Codable {
    case entretien, reparation, controleTechnique, pneus, carrosserie, autre
    var id: String { rawValue }
    var label: String {
        switch self {
        case .entretien: "Entretien"
        case .reparation: "Réparation"
        case .controleTechnique: "Contrôle technique"
        case .pneus: "Pneus"
        case .carrosserie: "Carrosserie"
        case .autre: "Autre"
        }
    }
    var symbol: String {
        switch self {
        case .entretien: "oilcan.fill"
        case .reparation: "wrench.and.screwdriver.fill"
        case .controleTechnique: "checkmark.seal.fill"
        case .pneus: "circle.circle.fill"
        case .carrosserie: "car.side.fill"
        case .autre: "ellipsis.circle.fill"
        }
    }
}

enum InterventionStatus: String, CaseIterable, Identifiable, Codable {
    case devis, facture
    var id: String { rawValue }
    var label: String { self == .devis ? "Devis" : "Facture" }
}

enum CTResult: String, CaseIterable, Identifiable, Codable {
    case favorable, defavorable, critique
    var id: String { rawValue }
    var label: String {
        switch self {
        case .favorable: "Favorable"
        case .defavorable: "Défavorable (contre-visite)"
        case .critique: "Défaillance critique"
        }
    }
}

enum DocumentKind: String, Codable {
    case pdf, image
}

/// Couleurs d'accent proposées pour les voitures.
enum CarPalette {
    static let colors = ["#2E86AB", "#E4572E", "#17BEBB", "#F18F01", "#76B041", "#A23B72", "#FFC914", "#5B5F97"]
    static func color(forIndex i: Int) -> String { colors[((i % colors.count) + colors.count) % colors.count] }
}
```

- [ ] **Step 2 : Compiler**

Run : `scripts/build.sh`
Attendu : `BUILD OK: ...`

- [ ] **Step 3 : Commit**

```bash
git add -A && git commit -m "feat: énumérations du domaine"
```

---

### Task 3 : DueStatus et seuils

**Files :**
- Create: `SuiviAuto/Logic/DueStatus.swift`
- Test: `SuiviAutoTests/DueStatusTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class DueStatusTests: XCTestCase {
    let now = T.date("2026-01-01", hour: 15)

    func status(days: Int?, km: Int?) -> DueStatus {
        let due = days.map { T.calendar.date(byAdding: .day, value: $0, to: T.date("2026-01-01"))! }
        return DueStatusEvaluator.status(dueDate: due, remainingKm: km, now: now, calendar: T.calendar)
    }

    func testDateThresholds() {
        XCTAssertEqual(status(days: 61, km: nil), .ok)
        XCTAssertEqual(status(days: 60, km: nil), .soon)
        XCTAssertEqual(status(days: 0, km: nil), .soon)
        XCTAssertEqual(status(days: -1, km: nil), .overdue)
    }

    func testKmThresholds() {
        XCTAssertEqual(status(days: nil, km: 1_001), .ok)
        XCTAssertEqual(status(days: nil, km: 1_000), .soon)
        XCTAssertEqual(status(days: nil, km: 0), .soon)
        XCTAssertEqual(status(days: nil, km: -1), .overdue)
    }

    func testWorstCriterionWins() {
        XCTAssertEqual(status(days: 300, km: 500), .soon)
        XCTAssertEqual(status(days: 30, km: -10), .overdue)
        XCTAssertEqual(status(days: -5, km: 50_000), .overdue)
    }

    func testNothingKnownIsOk() {
        XCTAssertEqual(status(days: nil, km: nil), .ok)
    }

    func testOrdering() {
        XCTAssertEqual([DueStatus.soon, .overdue, .ok].max(), .overdue)
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DueStatusTests`
Attendu : échec de compilation `cannot find 'DueStatusEvaluator'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/DueStatus.swift`**

```swift
import Foundation

enum DueStatus: Int, Comparable {
    case ok = 0, soon = 1, overdue = 2
    static func < (lhs: DueStatus, rhs: DueStatus) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .ok: "À jour"
        case .soon: "Bientôt"
        case .overdue: "Dépassé"
        }
    }
}

enum DueThresholds {
    static let soonDays = 60
    static let soonKm = 1_000
}

enum DueStatusEvaluator {
    /// Statut d'une échéance : le critère le plus défavorable (date ou km) l'emporte.
    static func status(dueDate: Date?, remainingKm: Int?, now: Date, calendar: Calendar = .current) -> DueStatus {
        var result = DueStatus.ok
        if let dueDate {
            let days = daysBetween(now, dueDate, calendar: calendar)
            if days < 0 { return .overdue }
            if days <= DueThresholds.soonDays { result = .soon }
        }
        if let remainingKm {
            if remainingKm < 0 { return .overdue }
            if remainingKm <= DueThresholds.soonKm { result = .soon }
        }
        return result
    }

    /// Nombre de jours calendaires entre deux dates (0 si même jour).
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DueStatusTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: statut d'échéance et seuils (60 jours / 1000 km)"
```

---

### Task 4 : Money (centimes ↔ texte)

**Files :**
- Create: `SuiviAuto/Logic/Money.swift`
- Test: `SuiviAutoTests/MoneyTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class MoneyTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(Money.parse("189,90"), 18_990)
        XCTAssertEqual(Money.parse("189.9"), 18_990)
        XCTAssertEqual(Money.parse("1 234,5 €"), 123_450)
        XCTAssertEqual(Money.parse("1\u{202F}234,56\u{00A0}€"), 123_456)
        XCTAssertEqual(Money.parse("42"), 4_200)
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("abc"))
        XCTAssertNil(Money.parse("12abc"))
        XCTAssertNil(Money.parse("-5"))
        XCTAssertNil(Money.parse("1,234"))
    }

    func testEditString() {
        XCTAssertEqual(Money.editString(cents: 18_990), "189,90")
        XCTAssertEqual(Money.editString(cents: 5), "0,05")
    }

    func testFormat() {
        let s = Money.format(cents: 123_456)
        XCTAssertTrue(s.contains("234,56"), s)
        XCTAssertTrue(s.contains("€"), s)
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MoneyTests`
Attendu : échec de compilation `cannot find 'Money'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/Money.swift`**

```swift
import Foundation

/// Montants en centimes d'euro.
enum Money {
    static let locale = Locale(identifier: "fr_FR")
    private static let pattern = try! Regex("^[0-9]+([.][0-9]{1,2})?$")

    /// "1 234,56 €" -> 123456. Retourne nil si le texte n'est pas un montant positif valide.
    static func parse(_ text: String) -> Int? {
        let cleaned = String(text.replacingOccurrences(of: "€", with: "").filter { !$0.isWhitespace })
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.wholeMatch(of: pattern) != nil,
              let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// 123456 -> "1 234,56 €" (format français).
    static func format(cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "EUR").locale(locale))
    }

    /// 18990 -> "189,90", pour pré-remplir un champ de saisie.
    static func editString(cents: Int) -> String {
        String(format: "%d,%02d", cents / 100, cents % 100)
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MoneyTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: conversion des montants en centimes"
```

---

### Task 5 : TechnicalInspectionCalculator

**Files :**
- Create: `SuiviAuto/Logic/TechnicalInspectionCalculator.swift`
- Test: `SuiviAutoTests/TechnicalInspectionTests.swift`

Règles (spec §4) :
- Aucun CT : 1re immatriculation + 4 ans.
- CT favorable : + 2 ans.
- CT défavorable ou critique : contre-visite à + 2 mois.
- Contre-visite favorable (moins de 2 mois après le 1er échec) : + 2 ans **depuis le CT initial défavorable**.

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class TechnicalInspectionTests: XCTestCase {
    let firstReg = T.date("2020-03-15")

    func due(_ records: [CTRecord]) -> CTDue {
        TechnicalInspectionCalculator.nextDue(firstRegistration: firstReg, records: records, calendar: T.calendar)
    }

    func testFirstInspectionAtFourYears() {
        XCTAssertEqual(due([]), CTDue(dueDate: T.date("2024-03-15"), isCounterVisit: false, drivingForbidden: false))
    }

    func testFavorableAddsTwoYears() {
        XCTAssertEqual(due([CTRecord(date: T.date("2024-03-10"), result: .favorable)]).dueDate, T.date("2026-03-10"))
    }

    func testUnfavorableRequiresCounterVisitWithinTwoMonths() {
        let d = due([CTRecord(date: T.date("2024-03-10"), result: .defavorable)])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2024-05-10"), isCounterVisit: true, drivingForbidden: false))
    }

    func testCriticalForbidsDriving() {
        let d = due([CTRecord(date: T.date("2024-03-10"), result: .critique)])
        XCTAssertEqual(d.dueDate, T.date("2024-05-10"))
        XCTAssertTrue(d.isCounterVisit)
        XCTAssertTrue(d.drivingForbidden)
    }

    func testFavorableCounterVisitExtendsFromInitialInspection() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-04-01"), result: .favorable),
        ])
        XCTAssertEqual(d, CTDue(dueDate: T.date("2026-03-10"), isCounterVisit: false, drivingForbidden: false))
    }

    func testLateCounterVisitCountsAsNewInspection() {
        let d = due([
            CTRecord(date: T.date("2024-03-10"), result: .defavorable),
            CTRecord(date: T.date("2024-06-15"), result: .favorable),
        ])
        XCTAssertEqual(d.dueDate, T.date("2026-06-15"))
    }

    func testRecordsAreSortedByDate() {
        let d = due([
            CTRecord(date: T.date("2026-03-01"), result: .favorable),
            CTRecord(date: T.date("2024-03-01"), result: .favorable),
        ])
        XCTAssertEqual(d.dueDate, T.date("2028-03-01"))
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/TechnicalInspectionTests`
Attendu : échec de compilation `cannot find 'CTRecord'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/TechnicalInspectionCalculator.swift`**

```swift
import Foundation

struct CTRecord: Equatable {
    let date: Date
    let result: CTResult
}

struct CTDue: Equatable {
    let dueDate: Date
    let isCounterVisit: Bool
    let drivingForbidden: Bool
}

enum TechnicalInspectionCalculator {
    /// `records` : uniquement les CT facturés (les devis sont exclus par l'appelant).
    static func nextDue(firstRegistration: Date, records: [CTRecord], calendar: Calendar = .current) -> CTDue {
        func add(_ component: Calendar.Component, _ value: Int, to date: Date) -> Date {
            calendar.date(byAdding: component, value: value, to: date)!
        }

        var due = CTDue(dueDate: add(.year, 4, to: firstRegistration), isCounterVisit: false, drivingForbidden: false)
        var pendingFailure: Date?

        for record in records.sorted(by: { $0.date < $1.date }) {
            switch record.result {
            case .favorable:
                var base = record.date
                if let failure = pendingFailure, record.date <= add(.month, 2, to: failure) {
                    base = failure
                }
                due = CTDue(dueDate: add(.year, 2, to: base), isCounterVisit: false, drivingForbidden: false)
                pendingFailure = nil
            case .defavorable, .critique:
                if pendingFailure == nil { pendingFailure = record.date }
                due = CTDue(dueDate: add(.month, 2, to: record.date),
                            isCounterVisit: true,
                            drivingForbidden: record.result == .critique)
            }
        }
        return due
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/TechnicalInspectionTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: calcul de l'échéance du contrôle technique"
```

---

### Task 6 : MileageEstimator

**Files :**
- Create: `SuiviAuto/Logic/MileageEstimator.swift`
- Test: `SuiviAutoTests/MileageEstimatorTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class MileageEstimatorTests: XCTestCase {
    func make(_ pts: [(String, Int)], now: String) -> MileageEstimator {
        MileageEstimator(points: pts.map { MileagePoint(date: T.date($0.0), km: $0.1) },
                         now: T.date(now), calendar: T.calendar)
    }

    func testNoPoints() {
        let e = make([], now: "2026-01-01")
        XCTAssertNil(e.latest)
        XCTAssertNil(e.kmPerDay)
        XCTAssertNil(e.estimatedCurrentMileage)
        XCTAssertNil(e.estimatedDate(forMileage: 1000))
    }

    func testSinglePoint() {
        let e = make([("2025-06-01", 42_000)], now: "2026-01-01")
        XCTAssertNil(e.kmPerDay)
        XCTAssertEqual(e.estimatedCurrentMileage, 42_000)
        XCTAssertNil(e.estimatedDate(forMileage: 50_000))
        XCTAssertEqual(e.estimatedDate(forMileage: 40_000), T.date("2025-06-01"))
    }

    func testExtrapolatesFromAllHistoryWhenFewRecentPoints() {
        // une seule mesure dans les 12 derniers mois -> on utilise tout l'historique
        let e = make([("2025-01-01", 10_000), ("2026-01-01", 25_000)], now: "2026-07-02")
        XCTAssertEqual(e.kmPerDay!, 15_000.0 / 365.0, accuracy: 0.0001)
        XCTAssertEqual(e.estimatedCurrentMileage, 32_479) // 25000 + 15000*182/365
    }

    func testUsesLastTwelveMonthsWhenEnoughPoints() {
        let e = make([("2020-01-01", 0), ("2025-08-01", 50_000), ("2026-06-01", 60_000)], now: "2026-07-01")
        XCTAssertEqual(e.kmPerDay!, 10_000.0 / 304.0, accuracy: 0.0001)
    }

    func testEstimatedDateForMileage() {
        let e = make([("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        XCTAssertEqual(e.estimatedDate(forMileage: 12_000), T.date("2026-01-21"))
        XCTAssertEqual(e.estimatedDate(forMileage: 5_000), T.date("2026-01-11"))
    }

    func testDecreasingMileageGivesNoProjection() {
        let e = make([("2026-01-01", 10_000), ("2026-01-11", 9_000)], now: "2026-02-01")
        XCTAssertEqual(e.estimatedCurrentMileage, 9_000)
        XCTAssertNil(e.estimatedDate(forMileage: 20_000))
    }

    func testUnsortedInput() {
        let e = make([("2026-01-11", 11_000), ("2026-01-01", 10_000)], now: "2026-01-11")
        XCTAssertEqual(e.latest, MileagePoint(date: T.date("2026-01-11"), km: 11_000))
        XCTAssertEqual(e.kmPerDay!, 100, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MileageEstimatorTests`
Attendu : échec de compilation `cannot find 'MileageEstimator'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/MileageEstimator.swift`**

```swift
import Foundation

struct MileagePoint: Equatable {
    let date: Date
    let km: Int
}

struct MileageEstimator {
    let points: [MileagePoint]
    let now: Date
    let calendar: Calendar

    private static let secondsPerDay = 86_400.0

    init(points: [MileagePoint], now: Date = .now, calendar: Calendar = .current) {
        self.points = points.sorted { ($0.date, $0.km) < ($1.date, $1.km) }
        self.now = now
        self.calendar = calendar
    }

    var latest: MileagePoint? { points.last }

    /// Moyenne km/jour : sur les 12 derniers mois s'il y a au moins 2 points, sinon sur tout l'historique.
    var kmPerDay: Double? {
        guard points.count >= 2 else { return nil }
        let windowStart = calendar.date(byAdding: .month, value: -12, to: now)!
        let recent = points.filter { $0.date >= windowStart }
        let sample = recent.count >= 2 ? recent : points
        guard let first = sample.first, let last = sample.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / Self.secondsPerDay
        guard days > 0 else { return nil }
        return Double(last.km - first.km) / days
    }

    func estimatedMileage(at date: Date) -> Int? {
        guard let latest else { return nil }
        guard let rate = kmPerDay, rate > 0, date > latest.date else { return latest.km }
        let days = date.timeIntervalSince(latest.date) / Self.secondsPerDay
        return latest.km + Int((rate * days).rounded())
    }

    var estimatedCurrentMileage: Int? { estimatedMileage(at: now) }

    /// Date estimée à laquelle `target` km sera atteint. Si déjà atteint : date du dernier point.
    func estimatedDate(forMileage target: Int) -> Date? {
        guard let latest else { return nil }
        if target <= latest.km { return latest.date }
        guard let rate = kmPerDay, rate > 0 else { return nil }
        return latest.date.addingTimeInterval(Double(target - latest.km) / rate * Self.secondsPerDay)
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MileageEstimatorTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: estimation du kilométrage"
```

---

### Task 7 : MaintenanceScheduler

**Files :**
- Create: `SuiviAuto/Logic/MaintenanceScheduler.swift`
- Test: `SuiviAutoTests/MaintenanceSchedulerTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class MaintenanceSchedulerTests: XCTestCase {
    func estimator(_ pts: [(String, Int)], now: String) -> MileageEstimator {
        MileageEstimator(points: pts.map { MileagePoint(date: T.date($0.0), km: $0.1) }, now: T.date(now), calendar: T.calendar)
    }

    func due(_ rule: RuleSpec, last: (String, Int)?, firstReg: String = "2020-01-01",
             pts: [(String, Int)] = [], now: String) -> MaintenanceDue {
        MaintenanceScheduler.due(rule: rule,
                                 lastDone: last.map { MileagePoint(date: T.date($0.0), km: $0.1) },
                                 firstRegistration: T.date(firstReg),
                                 estimator: estimator(pts, now: now),
                                 now: T.date(now), calendar: T.calendar)
    }

    func testTimeOnlyRuleOk() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 12), last: ("2026-01-10", 30_000), now: "2026-02-01")
        XCTAssertEqual(d.dueDate, T.date("2027-01-10"))
        XCTAssertNil(d.dueKm)
        XCTAssertNil(d.remainingKm)
        XCTAssertEqual(d.status, .ok)
    }

    func testTimeOnlyRuleSoon() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 12), last: ("2025-03-01", 30_000), now: "2026-01-15")
        XCTAssertEqual(d.dueDate, T.date("2026-03-01"))
        XCTAssertEqual(d.status, .soon)
    }

    func testKmReachedBeforeDate() {
        let d = due(RuleSpec(label: "Vidange", intervalKm: 15_000, intervalMonths: 12),
                    last: ("2026-01-01", 10_000),
                    pts: [("2026-01-01", 10_000), ("2026-01-11", 11_000)], now: "2026-01-11")
        XCTAssertEqual(d.dueKm, 25_000)
        XCTAssertEqual(d.remainingKm, 14_000)
        XCTAssertEqual(d.dueDate, T.date("2026-05-31"))
        XCTAssertEqual(d.status, .ok)
    }

    func testKmOverdue() {
        let d = due(RuleSpec(label: "Courroie", intervalKm: 30_000, intervalMonths: nil),
                    last: nil, firstReg: "2025-01-01",
                    pts: [("2025-01-01", 0), ("2026-01-01", 36_500)], now: "2026-01-01")
        XCTAssertEqual(d.remainingKm, -6_500)
        XCTAssertEqual(d.status, .overdue)
    }

    func testKmSoon() {
        let d = due(RuleSpec(label: "Vidange", intervalKm: 1_800, intervalMonths: 120),
                    last: ("2026-01-01", 0),
                    pts: [("2026-01-01", 0), ("2026-01-11", 1_000)], now: "2026-01-11")
        XCTAssertEqual(d.remainingKm, 800)
        XCTAssertEqual(d.status, .soon)
    }

    func testWithoutPreviousDoneStartsAtFirstRegistration() {
        let d = due(RuleSpec(label: "Liquide", intervalKm: nil, intervalMonths: 24), last: nil, firstReg: "2024-06-01", now: "2026-07-01")
        XCTAssertEqual(d.dueDate, T.date("2026-06-01"))
        XCTAssertEqual(d.status, .overdue)
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MaintenanceSchedulerTests`
Attendu : échec de compilation `cannot find 'RuleSpec'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/MaintenanceScheduler.swift`**

```swift
import Foundation

struct RuleSpec: Equatable {
    let label: String
    let intervalKm: Int?
    let intervalMonths: Int?
}

struct MaintenanceDue: Equatable {
    let dueDate: Date?
    let dueKm: Int?
    let remainingKm: Int?
    let status: DueStatus
}

enum MaintenanceScheduler {
    /// `lastDone` : dernière facture liée à la règle. Si nil : 1re immatriculation et 0 km.
    static func due(rule: RuleSpec, lastDone: MileagePoint?, firstRegistration: Date,
                    estimator: MileageEstimator, now: Date, calendar: Calendar = .current) -> MaintenanceDue {
        let start = lastDone ?? MileagePoint(date: firstRegistration, km: 0)
        let dueKm = rule.intervalKm.map { start.km + $0 }
        let dateByTime = rule.intervalMonths.flatMap { calendar.date(byAdding: .month, value: $0, to: start.date) }
        let dateByKm = dueKm.flatMap { estimator.estimatedDate(forMileage: $0) }
        let dueDate = [dateByTime, dateByKm].compactMap { $0 }.min()

        var remainingKm: Int?
        if let dueKm, let current = estimator.estimatedCurrentMileage {
            remainingKm = dueKm - current
        }

        let status = DueStatusEvaluator.status(dueDate: dueDate, remainingKm: remainingKm, now: now, calendar: calendar)
        return MaintenanceDue(dueDate: dueDate, dueKm: dueKm, remainingKm: remainingKm, status: status)
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/MaintenanceSchedulerTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: calcul des échéances d'entretien (km ou date)"
```

---

### Task 8 : CostSummary

**Files :**
- Create: `SuiviAuto/Logic/CostSummary.swift`
- Test: `SuiviAutoTests/CostSummaryTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class CostSummaryTests: XCTestCase {
    let entries = [
        CostEntry(carName: "Clio", date: T.date("2025-03-01"), kind: .entretien, amountCents: 20_000, status: .facture),
        CostEntry(carName: "Clio", date: T.date("2026-02-01"), kind: .pneus, amountCents: 40_000, status: .facture),
        CostEntry(carName: "Clio", date: T.date("2026-05-01"), kind: .reparation, amountCents: 99_999, status: .devis),
        CostEntry(carName: "C3", date: T.date("2026-04-01"), kind: .entretien, amountCents: 15_000, status: .facture),
    ]

    func testByYearExcludesQuotes() {
        XCTAssertEqual(CostSummary.byYear(entries, calendar: T.calendar), [2025: 20_000, 2026: 55_000])
    }

    func testByCarAndYear() {
        let r = CostSummary.byCarAndYear(entries, calendar: T.calendar)
        XCTAssertEqual(r[YearCar(year: 2026, carName: "Clio")], 40_000)
        XCTAssertEqual(r[YearCar(year: 2026, carName: "C3")], 15_000)
        XCTAssertEqual(r[YearCar(year: 2025, carName: "Clio")], 20_000)
        XCTAssertEqual(r.count, 3)
    }

    func testByKindForYear() {
        XCTAssertEqual(CostSummary.byKind(entries, year: 2026, calendar: T.calendar), [.pneus: 40_000, .entretien: 15_000])
    }

    func testTotalForYear() {
        XCTAssertEqual(CostSummary.total(entries, year: 2026, calendar: T.calendar), 55_000)
        XCTAssertEqual(CostSummary.total(entries, year: 2024, calendar: T.calendar), 0)
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/CostSummaryTests`
Attendu : échec de compilation `cannot find 'CostEntry'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/CostSummary.swift`**

```swift
import Foundation

struct CostEntry: Equatable {
    let carName: String
    let date: Date
    let kind: InterventionKind
    let amountCents: Int
    let status: InterventionStatus
}

struct YearCar: Hashable {
    let year: Int
    let carName: String
}

/// Totaux en centimes. Les devis sont toujours exclus.
enum CostSummary {
    static func totals<K: Hashable>(_ entries: [CostEntry], by key: (CostEntry) -> K) -> [K: Int] {
        entries.filter { $0.status == .facture }
            .reduce(into: [K: Int]()) { $0[key($1), default: 0] += $1.amountCents }
    }

    static func byYear(_ entries: [CostEntry], calendar: Calendar = .current) -> [Int: Int] {
        totals(entries) { calendar.component(.year, from: $0.date) }
    }

    static func byCarAndYear(_ entries: [CostEntry], calendar: Calendar = .current) -> [YearCar: Int] {
        totals(entries) { YearCar(year: calendar.component(.year, from: $0.date), carName: $0.carName) }
    }

    static func byKind(_ entries: [CostEntry], year: Int, calendar: Calendar = .current) -> [InterventionKind: Int] {
        totals(entries.filter { calendar.component(.year, from: $0.date) == year }) { $0.kind }
    }

    static func total(_ entries: [CostEntry], year: Int, calendar: Calendar = .current) -> Int {
        byYear(entries, calendar: calendar)[year] ?? 0
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/CostSummaryTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: synthèse des coûts (devis exclus)"
```

---

### Task 9 : Modèles SwiftData

**Files :**
- Create: `SuiviAuto/Models/Car.swift`, `Intervention.swift`, `StoredDocument.swift`, `OdometerReading.swift`, `MaintenanceRule.swift`, `Deadline.swift`, `SchemaModels.swift`
- Test: `SuiviAutoTests/ModelTests.swift`, ajout d'un helper dans `SuiviAutoTests/TestHelpers.swift`

- [ ] **Step 1 : Ajouter le conteneur en mémoire dans `SuiviAutoTests/TestHelpers.swift`**

Ajouter en bas du fichier (et `import SwiftData` en haut, avec `@testable import SuiviAuto`) :
```swift
import SwiftData
@testable import SuiviAuto

extension T {
    /// Contexte SwiftData en mémoire, isolé pour chaque test.
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(SchemaModels.all),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}
```

- [ ] **Step 2 : Écrire le test qui échoue, `SuiviAutoTests/ModelTests.swift`**

```swift
import XCTest
import SwiftData
@testable import SuiviAuto

final class ModelTests: XCTestCase {
    func testCarRelationshipsAndCascade() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-01-01"), mileage: 40_000, kind: .entretien)
        ctx.insert(i); i.car = car
        let r = OdometerReading(date: T.date("2026-02-01"), mileage: 41_000)
        ctx.insert(r); r.car = car
        try ctx.save()

        XCTAssertEqual(car.interventions.count, 1)
        XCTAssertEqual(car.readings.count, 1)

        ctx.delete(car)
        try ctx.save()
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Intervention>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<OdometerReading>()), 0)
    }

    func testEnumAccessors() {
        let i = Intervention(date: .now, mileage: 0, kind: .controleTechnique, status: .devis)
        XCTAssertEqual(i.kind, .controleTechnique)
        XCTAssertEqual(i.status, .devis)
        i.ctResult = .critique
        XCTAssertEqual(i.ctResultRaw, "critique")
        i.ctResult = nil
        XCTAssertNil(i.ctResultRaw)
    }

    func testDefaultRules() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        car.addDefaultRules(in: ctx)
        try ctx.save()
        XCTAssertEqual(Set(car.rules.map(\.key)), ["vidange", "courroie", "liquide-frein"])
        let vidange = car.rules.first { $0.key == "vidange" }!
        XCTAssertEqual(vidange.intervalKm, 15_000)
        XCTAssertEqual(vidange.intervalMonths, 12)
    }

    func testRuleKeyGeneration() {
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Filtre à air", existing: []), "filtre-a-air")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Vidange", existing: ["vidange"]), "vidange-2")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "Vidange", existing: ["vidange", "vidange-2"]), "vidange-3")
        XCTAssertEqual(MaintenanceRule.makeKey(label: "!!!", existing: []), "regle")
    }

    func testDeadlineMarkDone() {
        let yearly = Deadline(label: "Assurance", dueDate: T.date("2026-03-01"), repeatsYearly: true)
        XCTAssertTrue(yearly.markDone(calendar: T.calendar))
        XCTAssertEqual(yearly.dueDate, T.date("2027-03-01"))

        let once = Deadline(label: "Garantie", dueDate: T.date("2026-03-01"), repeatsYearly: false)
        XCTAssertFalse(once.markDone(calendar: T.calendar))
        XCTAssertEqual(once.dueDate, T.date("2026-03-01"))
    }
}
```

- [ ] **Step 3 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/ModelTests`
Attendu : échec de compilation `cannot find 'Car'` / `'SchemaModels'`.

- [ ] **Step 4 : Implémenter les modèles**

`SuiviAuto/Models/Car.swift` :
```swift
import Foundation
import SwiftData

@Model
final class Car {
    var uuid: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var modelName: String = ""
    var plate: String = ""
    var vin: String = ""
    var firstRegistrationDate: Date = Date.now
    var fuelRaw: String = "essence"
    var colorHex: String = "#2E86AB"
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Intervention.car) var interventions: [Intervention] = []
    @Relationship(deleteRule: .cascade, inverse: \OdometerReading.car) var readings: [OdometerReading] = []
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRule.car) var rules: [MaintenanceRule] = []
    @Relationship(deleteRule: .cascade, inverse: \Deadline.car) var deadlines: [Deadline] = []

    init(name: String, firstRegistrationDate: Date, colorHex: String = "#2E86AB") {
        self.name = name
        self.firstRegistrationDate = firstRegistrationDate
        self.colorHex = colorHex
    }

    var fuel: FuelType {
        get { FuelType(rawValue: fuelRaw) ?? .autre }
        set { fuelRaw = newValue.rawValue }
    }

    /// Ajoute les règles d'entretien proposées par défaut (spec §3).
    func addDefaultRules(in context: ModelContext) {
        for d in MaintenanceRule.defaults {
            let rule = MaintenanceRule(key: d.key, label: d.label, intervalKm: d.km, intervalMonths: d.months)
            context.insert(rule)
            rule.car = self
        }
    }
}
```

`SuiviAuto/Models/Intervention.swift` :
```swift
import Foundation
import SwiftData

@Model
final class Intervention {
    var date: Date = Date.now
    var mileage: Int = 0
    var kindRaw: String = "entretien"
    var title: String = ""
    var garage: String = ""
    var amountCents: Int?
    var statusRaw: String = "facture"
    var notes: String = ""
    var ctResultRaw: String?
    var ruleKey: String?
    var car: Car?

    @Relationship(deleteRule: .cascade, inverse: \StoredDocument.intervention) var documents: [StoredDocument] = []

    init(date: Date, mileage: Int, kind: InterventionKind, title: String = "", status: InterventionStatus = .facture) {
        self.date = date
        self.mileage = mileage
        self.kindRaw = kind.rawValue
        self.title = title
        self.statusRaw = status.rawValue
    }

    var kind: InterventionKind {
        get { InterventionKind(rawValue: kindRaw) ?? .autre }
        set { kindRaw = newValue.rawValue }
    }

    var status: InterventionStatus {
        get { InterventionStatus(rawValue: statusRaw) ?? .facture }
        set { statusRaw = newValue.rawValue }
    }

    var ctResult: CTResult? {
        get { ctResultRaw.flatMap(CTResult.init(rawValue:)) }
        set { ctResultRaw = newValue?.rawValue }
    }

    var displayTitle: String { title.isEmpty ? kind.label : title }
}
```

`SuiviAuto/Models/StoredDocument.swift` :
```swift
import Foundation
import SwiftData

@Model
final class StoredDocument {
    var fileName: String = ""
    var originalName: String = ""
    var addedAt: Date = Date.now
    var kindRaw: String = "pdf"
    var intervention: Intervention?

    init(fileName: String, originalName: String, kind: DocumentKind, addedAt: Date = .now) {
        self.fileName = fileName
        self.originalName = originalName
        self.kindRaw = kind.rawValue
        self.addedAt = addedAt
    }

    var kind: DocumentKind { DocumentKind(rawValue: kindRaw) ?? .pdf }
}
```

`SuiviAuto/Models/OdometerReading.swift` :
```swift
import Foundation
import SwiftData

@Model
final class OdometerReading {
    var date: Date = Date.now
    var mileage: Int = 0
    var car: Car?

    init(date: Date, mileage: Int) {
        self.date = date
        self.mileage = mileage
    }
}
```

`SuiviAuto/Models/MaintenanceRule.swift` :
```swift
import Foundation
import SwiftData

@Model
final class MaintenanceRule {
    var uuid: UUID = UUID()
    var key: String = ""
    var label: String = ""
    var intervalKm: Int?
    var intervalMonths: Int?
    var car: Car?

    init(key: String, label: String, intervalKm: Int?, intervalMonths: Int?) {
        self.key = key
        self.label = label
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
    }

    static let defaults: [(key: String, label: String, km: Int?, months: Int?)] = [
        ("vidange", "Vidange moteur", 15_000, 12),
        ("courroie", "Courroie de distribution", 120_000, 72),
        ("liquide-frein", "Liquide de frein", nil, 24),
    ]

    /// "Filtre à air" -> "filtre-a-air", rendu unique parmi `existing`.
    static func makeKey(label: String, existing: Set<String>) -> String {
        let folded = label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        var base = folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        if base.isEmpty { base = "regle" }
        var candidate = base
        var n = 2
        while existing.contains(candidate) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return candidate
    }

    /// "Tous les 15 000 km ou 12 mois"
    var intervalDescription: String {
        let km = intervalKm.map { "\($0.formatted(.number.locale(Locale(identifier: "fr_FR")))) km" }
        let months = intervalMonths.map { "\($0) mois" }
        return "Tous les " + [km, months].compactMap { $0 }.joined(separator: " ou ")
    }
}
```

`SuiviAuto/Models/Deadline.swift` :
```swift
import Foundation
import SwiftData

@Model
final class Deadline {
    var uuid: UUID = UUID()
    var label: String = ""
    var dueDate: Date = Date.now
    var repeatsYearly: Bool = false
    var notes: String = ""
    var car: Car?

    init(label: String, dueDate: Date, repeatsYearly: Bool, notes: String = "") {
        self.label = label
        self.dueDate = dueDate
        self.repeatsYearly = repeatsYearly
        self.notes = notes
    }

    /// Échéance annuelle : avance d'un an et retourne true. Sinon retourne false (l'appelant la supprime).
    @discardableResult
    func markDone(calendar: Calendar = .current) -> Bool {
        guard repeatsYearly else { return false }
        dueDate = calendar.date(byAdding: .year, value: 1, to: dueDate)!
        return true
    }
}
```

`SuiviAuto/Models/SchemaModels.swift` :
```swift
import SwiftData

enum SchemaModels {
    static let all: [any PersistentModel.Type] = [
        Car.self, Intervention.self, StoredDocument.self,
        OdometerReading.self, MaintenanceRule.self, Deadline.self,
    ]
}
```

- [ ] **Step 5 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/ModelTests`
Attendu : `TESTS OK`

- [ ] **Step 6 : Commit**

```bash
git add -A && git commit -m "feat: modèles SwiftData (voiture, intervention, document, relevé, règle, échéance)"
```

---

### Task 10 : CarAnalytics et DueAggregator

**Files :**
- Create: `SuiviAuto/Services/CarAnalytics.swift`, `SuiviAuto/Services/DueAggregator.swift`
- Test: `SuiviAutoTests/DueAggregatorTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
import SwiftData
@testable import SuiviAuto

final class DueAggregatorTests: XCTestCase {
    var ctx: ModelContext!
    var car: Car!
    let now = T.date("2026-01-10")

    override func setUpWithError() throws {
        ctx = try T.makeContext()
        car = Car(name: "Clio", firstRegistrationDate: T.date("2022-05-01"))
        ctx.insert(car)
        car.addDefaultRules(in: ctx)
        try ctx.save()
    }

    @discardableResult
    func addIntervention(_ date: String, km: Int, kind: InterventionKind, status: InterventionStatus = .facture,
                         ruleKey: String? = nil, ct: CTResult? = nil, cents: Int? = nil) -> Intervention {
        let i = Intervention(date: T.date(date), mileage: km, kind: kind, status: status)
        i.ruleKey = ruleKey
        i.ctResult = ct
        i.amountCents = cents
        ctx.insert(i); i.car = car
        return i
    }

    func addReading(_ date: String, km: Int) {
        let r = OdometerReading(date: T.date(date), mileage: km)
        ctx.insert(r); r.car = car
    }

    func items() -> [DueItem] { DueAggregator.items(for: car, now: now, calendar: T.calendar) }

    func testScenarioFromSpec() throws {
        addIntervention("2025-03-01", km: 40_000, kind: .entretien, ruleKey: "vidange")
        addReading("2026-01-01", km: 52_000)
        try ctx.save()

        let list = items()
        XCTAssertEqual(list.map(\.label), ["Liquide de frein", "Vidange moteur", "Contrôle technique", "Courroie de distribution"])

        let vidange = list.first { $0.label == "Vidange moteur" }!
        XCTAssertEqual(vidange.dueKm, 55_000)
        XCTAssertEqual(vidange.dueDate, T.date("2026-03-01"))
        XCTAssertEqual(vidange.status, .soon)

        let ct = list.first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.dueDate, T.date("2026-05-01"))
        XCTAssertEqual(ct.status, .ok)

        XCTAssertEqual(list.first!.status, .overdue)
        XCTAssertEqual(DueAggregator.worstStatus(for: car, now: now, calendar: T.calendar), .overdue)
        XCTAssertEqual(CarAnalytics.estimator(for: car, now: now, calendar: T.calendar).estimatedCurrentMileage, 52_353)
    }

    func testQuotesAreIgnored() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .controleTechnique, ct: .favorable)
        addIntervention("2026-01-08", km: 50_100, kind: .controleTechnique, status: .devis, ct: .defavorable)
        addIntervention("2026-01-08", km: 99_999, kind: .entretien, status: .devis, ruleKey: "vidange")
        try ctx.save()

        let ct = items().first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.dueDate, T.date("2028-01-05"))
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: now), 50_000)
    }

    func testCriticalCTIsOverdueWithDetail() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .controleTechnique, ct: .critique)
        try ctx.save()
        let ct = items().first { $0.source == .technicalInspection }!
        XCTAssertEqual(ct.label, "Contre-visite")
        XCTAssertEqual(ct.status, .overdue)
        XCTAssertNotNil(ct.detail)
    }

    func testDeadlines() throws {
        let d = Deadline(label: "Assurance", dueDate: T.date("2026-02-01"), repeatsYearly: true)
        ctx.insert(d); d.car = car
        try ctx.save()
        let item = items().first { $0.source == .deadline }!
        XCTAssertEqual(item.label, "Assurance")
        XCTAssertEqual(item.status, .soon)
        XCTAssertEqual(item.carName, "Clio")
    }

    func testLastKnownMileageRespectsDate() throws {
        addReading("2025-01-01", km: 30_000)
        addReading("2026-01-01", km: 50_000)
        try ctx.save()
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: T.date("2025-06-01")), 30_000)
        XCTAssertEqual(CarAnalytics.lastKnownMileage(for: car, onOrBefore: T.date("2024-06-01")), nil)
    }

    func testCostEntries() throws {
        addIntervention("2026-01-05", km: 50_000, kind: .pneus, cents: 40_000)
        addIntervention("2026-01-06", km: 50_000, kind: .pneus)  // sans montant : ignorée
        try ctx.save()
        let entries = CarAnalytics.costEntries(for: [car])
        XCTAssertEqual(entries, [CostEntry(carName: "Clio", date: T.date("2026-01-05"), kind: .pneus, amountCents: 40_000, status: .facture)])
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DueAggregatorTests`
Attendu : échec de compilation `cannot find 'DueAggregator'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Services/CarAnalytics.swift`**

```swift
import Foundation

/// Conversion des modèles SwiftData en entrées pour la couche Logic.
enum CarAnalytics {
    /// Points km : relevés manuels + interventions facturées.
    static func mileagePoints(for car: Car, excluding: Intervention? = nil) -> [MileagePoint] {
        let readings = car.readings.map { MileagePoint(date: $0.date, km: $0.mileage) }
        let invoices = car.interventions
            .filter { $0.status == .facture && $0 != excluding }
            .map { MileagePoint(date: $0.date, km: $0.mileage) }
        return readings + invoices
    }

    static func estimator(for car: Car, now: Date = .now, calendar: Calendar = .current) -> MileageEstimator {
        MileageEstimator(points: mileagePoints(for: car), now: now, calendar: calendar)
    }

    /// Plus grand km connu à une date donnée (pour avertir d'une saisie incohérente).
    static func lastKnownMileage(for car: Car, onOrBefore date: Date, excluding: Intervention? = nil) -> Int? {
        mileagePoints(for: car, excluding: excluding).filter { $0.date <= date }.map(\.km).max()
    }

    static func costEntries(for cars: [Car]) -> [CostEntry] {
        cars.flatMap { car in
            car.interventions.compactMap { i -> CostEntry? in
                guard let cents = i.amountCents else { return nil }
                return CostEntry(carName: car.name, date: i.date, kind: i.kind, amountCents: cents, status: i.status)
            }
        }
        .sorted { $0.date < $1.date }
    }
}
```

- [ ] **Step 4 : Implémenter `SuiviAuto/Services/DueAggregator.swift`**

```swift
import Foundation

struct DueItem: Identifiable, Equatable {
    enum Source: Equatable {
        case technicalInspection
        case rule(String)
        case deadline
    }

    let id: String
    let carName: String
    let carColorHex: String
    let label: String
    let detail: String?
    let dueDate: Date?
    let dueKm: Int?
    let status: DueStatus
    let source: Source

    /// Tri : date croissante, sans date en dernier.
    static func byDate(_ a: DueItem, _ b: DueItem) -> Bool {
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        default: return false
        }
    }
}

enum DueAggregator {
    static func ctDue(for car: Car, calendar: Calendar = .current) -> CTDue {
        let records = car.interventions.compactMap { i -> CTRecord? in
            guard i.status == .facture, i.kind == .controleTechnique, let result = i.ctResult else { return nil }
            return CTRecord(date: i.date, result: result)
        }
        return TechnicalInspectionCalculator.nextDue(firstRegistration: car.firstRegistrationDate,
                                                     records: records, calendar: calendar)
    }

    static func ruleDue(_ rule: MaintenanceRule, car: Car, estimator: MileageEstimator,
                        now: Date, calendar: Calendar = .current) -> MaintenanceDue {
        let last = car.interventions
            .filter { $0.status == .facture && $0.ruleKey == rule.key }
            .max { ($0.date, $0.mileage) < ($1.date, $1.mileage) }
        return MaintenanceScheduler.due(
            rule: RuleSpec(label: rule.label, intervalKm: rule.intervalKm, intervalMonths: rule.intervalMonths),
            lastDone: last.map { MileagePoint(date: $0.date, km: $0.mileage) },
            firstRegistration: car.firstRegistrationDate,
            estimator: estimator, now: now, calendar: calendar)
    }

    static func items(for car: Car, now: Date = .now, calendar: Calendar = .current) -> [DueItem] {
        var result: [DueItem] = []
        let carID = car.uuid.uuidString

        let ct = ctDue(for: car, calendar: calendar)
        let ctStatus = ct.drivingForbidden
            ? .overdue
            : DueStatusEvaluator.status(dueDate: ct.dueDate, remainingKm: nil, now: now, calendar: calendar)
        result.append(DueItem(id: "\(carID)-ct", carName: car.name, carColorHex: car.colorHex,
                              label: ct.isCounterVisit ? "Contre-visite" : "Contrôle technique",
                              detail: ct.drivingForbidden ? "Défaillance critique : circulation interdite" : nil,
                              dueDate: ct.dueDate, dueKm: nil, status: ctStatus, source: .technicalInspection))

        let estimator = CarAnalytics.estimator(for: car, now: now, calendar: calendar)
        for rule in car.rules {
            let due = ruleDue(rule, car: car, estimator: estimator, now: now, calendar: calendar)
            result.append(DueItem(id: "rule-\(rule.uuid.uuidString)", carName: car.name, carColorHex: car.colorHex,
                                  label: rule.label, detail: rule.intervalDescription,
                                  dueDate: due.dueDate, dueKm: due.dueKm, status: due.status,
                                  source: .rule(rule.key)))
        }

        for deadline in car.deadlines {
            let status = DueStatusEvaluator.status(dueDate: deadline.dueDate, remainingKm: nil, now: now, calendar: calendar)
            result.append(DueItem(id: "deadline-\(deadline.uuid.uuidString)", carName: car.name, carColorHex: car.colorHex,
                                  label: deadline.label, detail: deadline.notes.isEmpty ? nil : deadline.notes,
                                  dueDate: deadline.dueDate, dueKm: nil, status: status, source: .deadline))
        }

        return result.sorted(by: DueItem.byDate)
    }

    static func items(for cars: [Car], now: Date = .now, calendar: Calendar = .current) -> [DueItem] {
        cars.flatMap { items(for: $0, now: now, calendar: calendar) }.sorted(by: DueItem.byDate)
    }

    static func worstStatus(for car: Car, now: Date = .now, calendar: Calendar = .current) -> DueStatus {
        items(for: car, now: now, calendar: calendar).map(\.status).max() ?? .ok
    }
}
```

- [ ] **Step 5 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DueAggregatorTests`
Attendu : `TESTS OK`

- [ ] **Step 6 : Commit**

```bash
git add -A && git commit -m "feat: agrégation des échéances par voiture"
```

---

### Task 11 : DocumentStore et DeletionService

**Files :**
- Create: `SuiviAuto/Services/DocumentStore.swift`, `SuiviAuto/Services/DeletionService.swift`
- Test: `SuiviAutoTests/DocumentStoreTests.swift`, `SuiviAutoTests/DeletionServiceTests.swift`

- [ ] **Step 1 : Écrire les tests qui échouent**

`SuiviAutoTests/DocumentStoreTests.swift` :
```swift
import XCTest
@testable import SuiviAuto

final class DocumentStoreTests: XCTestCase {
    var root: URL!
    var store: DocumentStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = DocumentStore(directory: root.appendingPathComponent("Documents"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeFile(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("contenu".utf8).write(to: url)
        return url
    }

    func testImportCopiesFile() throws {
        let src = try makeFile("Facture Garage.PDF")
        let doc = try store.importFile(at: src)
        XCTAssertEqual(doc.originalName, "Facture Garage.PDF")
        XCTAssertEqual(doc.kind, .pdf)
        XCTAssertTrue(doc.fileName.hasSuffix(".pdf"))
        XCTAssertTrue(store.fileExists(for: doc))
        XCTAssertEqual(try Data(contentsOf: store.url(for: doc)), Data("contenu".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path), "l'original reste en place")
    }

    func testImageKinds() throws {
        for name in ["a.jpg", "b.jpeg", "c.png", "d.HEIC"] {
            XCTAssertEqual(try store.importFile(at: try makeFile(name)).kind, .image)
        }
    }

    func testRejectsUnsupportedFormat() throws {
        let src = try makeFile("devis.docx")
        XCTAssertThrowsError(try store.importFile(at: src)) { error in
            XCTAssertEqual(error as? DocumentStore.ImportError, .unsupportedFormat("devis.docx"))
        }
    }

    func testMissingFileAndDelete() throws {
        let doc = try store.importFile(at: try makeFile("x.pdf"))
        store.delete(fileName: doc.fileName)
        XCTAssertFalse(store.fileExists(for: doc))
        store.delete(fileName: doc.fileName) // deuxième suppression : aucune erreur
    }
}
```

`SuiviAutoTests/DeletionServiceTests.swift` :
```swift
import XCTest
import SwiftData
@testable import SuiviAuto

final class DeletionServiceTests: XCTestCase {
    var root: URL!
    var store: DocumentStore!
    var ctx: ModelContext!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = DocumentStore(directory: root.appendingPathComponent("Documents"))
        ctx = try T.makeContext()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func makeCarWithDocument() throws -> (Car, Intervention, StoredDocument) {
        let car = Car(name: "Clio", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-01-01"), mileage: 1, kind: .entretien)
        ctx.insert(i); i.car = car
        let src = root.appendingPathComponent("f.pdf")
        try Data("x".utf8).write(to: src)
        let doc = try store.importFile(at: src)
        ctx.insert(doc); doc.intervention = i
        try ctx.save()
        return (car, i, doc)
    }

    func testDeleteCarRemovesFiles() throws {
        let (car, _, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(car, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Car>()), 0)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<StoredDocument>()), 0)
    }

    func testDeleteInterventionRemovesFiles() throws {
        let (car, i, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(i, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(car.interventions.count, 0)
    }

    func testDeleteSingleDocument() throws {
        let (_, i, doc) = try makeCarWithDocument()
        let url = store.url(for: doc)
        try DeletionService.delete(doc, in: ctx, store: store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(i.documents.count, 0)
    }
}
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DocumentStoreTests -only-testing:SuiviAutoTests/DeletionServiceTests`
Attendu : échec de compilation `cannot find 'DocumentStore'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Services/DocumentStore.swift`**

```swift
import Foundation

/// Copie et retrouve les fichiers de factures et devis.
struct DocumentStore {
    let directory: URL

    static let shared = DocumentStore(directory: AppPaths.documentsURL)

    enum ImportError: LocalizedError, Equatable {
        case unsupportedFormat(String)
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let name):
                "« \(name) » n'est pas pris en charge. Formats acceptés : PDF, JPEG, PNG, HEIC."
            }
        }
    }

    static let allowedExtensions: [String: DocumentKind] = [
        "pdf": .pdf, "jpg": .image, "jpeg": .image, "png": .image, "heic": .image,
    ]

    /// Copie le fichier sous un nom unique. Le `StoredDocument` retourné n'est pas encore inséré dans un contexte.
    func importFile(at source: URL) throws -> StoredDocument {
        let ext = source.pathExtension.lowercased()
        guard let kind = Self.allowedExtensions[ext] else {
            throw ImportError.unsupportedFormat(source.lastPathComponent)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(fileName))
        return StoredDocument(fileName: fileName, originalName: source.lastPathComponent, kind: kind)
    }

    func url(for document: StoredDocument) -> URL {
        directory.appendingPathComponent(document.fileName)
    }

    func fileExists(for document: StoredDocument) -> Bool {
        FileManager.default.fileExists(atPath: url(for: document).path)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
```

- [ ] **Step 4 : Implémenter `SuiviAuto/Services/DeletionService.swift`**

```swift
import Foundation
import SwiftData

/// Suppression des objets ET des fichiers associés sur le disque.
enum DeletionService {
    static func delete(_ car: Car, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = car.interventions.flatMap { $0.documents.map(\.fileName) }
        context.delete(car)
        try context.save()
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ intervention: Intervention, in context: ModelContext, store: DocumentStore = .shared) throws {
        let names = intervention.documents.map(\.fileName)
        context.delete(intervention)
        try context.save()
        names.forEach(store.delete(fileName:))
    }

    static func delete(_ document: StoredDocument, in context: ModelContext, store: DocumentStore = .shared) throws {
        let name = document.fileName
        context.delete(document)
        try context.save()
        store.delete(fileName: name)
    }
}
```

- [ ] **Step 5 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/DocumentStoreTests -only-testing:SuiviAutoTests/DeletionServiceTests`
Attendu : `TESTS OK`

- [ ] **Step 6 : Commit**

```bash
git add -A && git commit -m "feat: stockage des documents et suppression en cascade des fichiers"
```

---

### Task 12 : NotificationPlanner et NotificationScheduler

**Files :**
- Create: `SuiviAuto/Logic/NotificationPlanner.swift`, `SuiviAuto/Services/NotificationScheduler.swift`
- Test: `SuiviAutoTests/NotificationPlannerTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
@testable import SuiviAuto

final class NotificationPlannerTests: XCTestCase {
    func item(_ id: String, due: String?) -> DueItem {
        DueItem(id: id, carName: "Clio", carColorHex: "#000000", label: "Vidange", detail: nil,
                dueDate: due.map { T.date($0) }, dueKm: nil, status: .ok, source: .rule("vidange"))
    }

    func testPlansThirtyAndSevenDaysBeforeAtNine() {
        let plans = NotificationPlanner.plan(items: [item("a", due: "2026-03-01")], now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(plans.map(\.id), ["a-J30", "a-J7"])
        XCTAssertEqual(plans.map(\.fireDate), [T.date("2026-01-30", hour: 9), T.date("2026-02-22", hour: 9)])
        XCTAssertEqual(plans[0].title, "Clio : Vidange")
    }

    func testSkipsPastFireDates() {
        let plans = NotificationPlanner.plan(items: [item("a", due: "2026-03-01")], now: T.date("2026-02-10"), calendar: T.calendar)
        XCTAssertEqual(plans.map(\.id), ["a-J7"])
    }

    func testNoDateNoNotification() {
        XCTAssertTrue(NotificationPlanner.plan(items: [item("a", due: nil)], now: T.date("2026-01-01"), calendar: T.calendar).isEmpty)
    }

    func testLimitKeepsSoonest() {
        let items = (1...40).map { item("i\($0)", due: "2027-01-\(String(format: "%02d", min($0, 28)))") }
        let plans = NotificationPlanner.plan(items: items, now: T.date("2026-01-01"), calendar: T.calendar)
        XCTAssertEqual(plans.count, NotificationPlanner.maxPending)
        XCTAssertEqual(plans, plans.sorted { $0.fireDate < $1.fireDate })
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/NotificationPlannerTests`
Attendu : échec de compilation `cannot find 'NotificationPlanner'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Logic/NotificationPlanner.swift`**

```swift
import Foundation

struct PlannedNotification: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

enum NotificationPlanner {
    static let leadDays = [30, 7]
    static let fireHour = 9
    /// macOS limite le nombre de notifications en attente : on garde les plus proches.
    static let maxPending = 60

    static func plan(items: [DueItem], now: Date, calendar: Calendar = .current) -> [PlannedNotification] {
        let all = items.flatMap { item -> [PlannedNotification] in
            guard let due = item.dueDate else { return [] }
            return leadDays.compactMap { lead in
                guard let day = calendar.date(byAdding: .day, value: -lead, to: calendar.startOfDay(for: due)),
                      let fire = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: day),
                      fire > now else { return nil }
                let when = due.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
                let estimated = item.dueKm != nil ? " (date estimée)" : ""
                return PlannedNotification(id: "\(item.id)-J\(lead)",
                                           title: "\(item.carName) : \(item.label)",
                                           body: "Échéance dans \(lead) jours, le \(when)\(estimated).",
                                           fireDate: fire)
            }
        }
        return Array(all.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/NotificationPlannerTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Implémenter `SuiviAuto/Services/NotificationScheduler.swift`**

Code système, non testé unitairement. Il est vérifié manuellement à la tâche 19.
```swift
import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Supprime puis replanifie toutes les notifications (idempotent).
    static func reschedule(context: ModelContext) async {
        let cars = (try? context.fetch(FetchDescriptor<Car>())) ?? []
        let plans = NotificationPlanner.plan(items: DueAggregator.items(for: cars), now: .now)
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}
```

- [ ] **Step 6 : Compiler**

Run : `scripts/build.sh`
Attendu : `BUILD OK`

- [ ] **Step 7 : Commit**

```bash
git add -A && git commit -m "feat: planification des notifications J-30 et J-7"
```

---

### Task 13 : BackupService (zip et CSV)

**Files :**
- Create: `SuiviAuto/Services/BackupService.swift`
- Test: `SuiviAutoTests/BackupServiceTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

```swift
import XCTest
import SwiftData
@testable import SuiviAuto

final class BackupServiceTests: XCTestCase {
    var root: URL!
    var base: URL!
    var pending: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        base = root.appendingPathComponent("SuiviAuto")
        pending = root.appendingPathComponent("SuiviAuto-PendingRestore")
        try fm.createDirectory(at: base.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try Data("store-v1".utf8).write(to: base.appendingPathComponent("SuiviAuto.store"))
        try Data("pdf".utf8).write(to: base.appendingPathComponent("Documents/a.pdf"))
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    func read(_ url: URL) throws -> String { String(decoding: try Data(contentsOf: url), as: UTF8.self) }

    func testExportStageAndApplyRoundTrip() throws {
        let zip = root.appendingPathComponent("sauvegarde.zip")
        try BackupService.exportBackup(to: zip, base: base)
        XCTAssertTrue(fm.fileExists(atPath: zip.path))

        // les données changent après la sauvegarde
        try Data("store-v2".utf8).write(to: base.appendingPathComponent("SuiviAuto.store"))

        try BackupService.stageRestore(from: zip, pending: pending)
        XCTAssertTrue(fm.fileExists(atPath: pending.appendingPathComponent("SuiviAuto.store").path))

        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending)
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
        XCTAssertEqual(try read(base.appendingPathComponent("Documents/a.pdf")), "pdf")
        XCTAssertFalse(fm.fileExists(atPath: pending.path))

        let previous = root.appendingPathComponent("SuiviAuto-avant-restauration/SuiviAuto.store")
        XCTAssertEqual(try read(previous), "store-v2")
    }

    func testApplyWithoutPendingDoesNothing() throws {
        try BackupService.applyPendingRestoreIfNeeded(base: base, pending: pending)
        XCTAssertEqual(try read(base.appendingPathComponent("SuiviAuto.store")), "store-v1")
    }

    func testStageRejectsInvalidArchive() throws {
        let other = root.appendingPathComponent("Autre")
        try fm.createDirectory(at: other, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: other.appendingPathComponent("x.txt"))
        let zip = root.appendingPathComponent("invalide.zip")
        try BackupService.exportBackup(to: zip, base: other)
        XCTAssertThrowsError(try BackupService.stageRestore(from: zip, pending: pending)) {
            XCTAssertEqual($0 as? BackupService.BackupError, .invalidArchive)
        }
    }

    func testCSV() throws {
        let ctx = try T.makeContext()
        let car = Car(name: "Clio; rouge", firstRegistrationDate: T.date("2020-01-01"))
        ctx.insert(car)
        let i = Intervention(date: T.date("2026-03-05"), mileage: 45_000, kind: .entretien, title: "Vidange \"complète\"")
        i.garage = "Garage du Nord"
        i.amountCents = 18_990
        ctx.insert(i); i.car = car
        let q = Intervention(date: T.date("2026-04-01"), mileage: 46_000, kind: .pneus, status: .devis)
        ctx.insert(q); q.car = car
        try ctx.save()

        let csv = BackupService.csv(for: [q, i], calendar: T.calendar)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        let lines = csv.dropFirst().components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "Voiture;Date;Km;Type;Titre;Garage;Montant;Statut")
        XCTAssertEqual(lines[1], "\"Clio; rouge\";05/03/2026;45000;Entretien;\"Vidange \"\"complète\"\"\";Garage du Nord;189,90;Facture")
        XCTAssertEqual(lines[2], "\"Clio; rouge\";01/04/2026;46000;Pneus;Pneus;;;Devis")
    }
}
```

- [ ] **Step 2 : Lancer le test pour vérifier qu'il échoue**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/BackupServiceTests`
Attendu : échec de compilation `cannot find 'BackupService'`.

- [ ] **Step 3 : Implémenter `SuiviAuto/Services/BackupService.swift`**

```swift
import AppKit
import Foundation

enum BackupService {
    enum BackupError: LocalizedError, Equatable {
        case dittoFailed(Int32)
        case invalidArchive
        var errorDescription: String? {
            switch self {
            case .dittoFailed(let code): "La compression a échoué (code \(code))."
            case .invalidArchive: "Cette archive n'est pas une sauvegarde SuiviAuto."
            }
        }
    }

    private static func ditto(_ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw BackupError.dittoFailed(p.terminationStatus) }
    }

    /// Zippe le dossier `base` (base + Documents). L'appelant doit avoir fait `context.save()` avant.
    static func exportBackup(to zipURL: URL, base: URL = AppPaths.baseURL) throws {
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }
        try ditto(["-c", "-k", "--sequesterRsrc", "--keepParent", base.path, zipURL.path])
    }

    /// Décompresse l'archive dans `pending`. Elle sera appliquée au prochain lancement.
    static func stageRestore(from zipURL: URL, pending: URL = AppPaths.pendingRestoreURL) throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        try ditto(["-x", "-k", zipURL.path, temp.path])
        let extracted = temp.appendingPathComponent("SuiviAuto")
        guard fm.fileExists(atPath: extracted.appendingPathComponent("SuiviAuto.store").path) else {
            throw BackupError.invalidArchive
        }
        if fm.fileExists(atPath: pending.path) { try fm.removeItem(at: pending) }
        try fm.moveItem(at: extracted, to: pending)
    }

    /// À appeler au lancement, AVANT d'ouvrir le ModelContainer.
    /// Les données actuelles sont conservées dans « SuiviAuto-avant-restauration ».
    static func applyPendingRestoreIfNeeded(base: URL = AppPaths.baseURL, pending: URL = AppPaths.pendingRestoreURL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pending.path) else { return }
        if fm.fileExists(atPath: base.path) {
            let previous = base.deletingLastPathComponent().appendingPathComponent("SuiviAuto-avant-restauration")
            if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
            try fm.moveItem(at: base, to: previous)
        }
        try fm.moveItem(at: pending, to: base)
    }

    /// Relance l'application : un shell détaché attend 1 s puis rouvre l'app, qui se termine aussitôt.
    @MainActor
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }

    /// CSV pour Excel en français : séparateur « ; », UTF-8 avec BOM, fins de ligne CRLF.
    static func csv(for interventions: [Intervention], calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "dd/MM/yyyy"

        func field(_ s: String) -> String {
            guard s.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        let sorted = interventions.sorted {
            ($0.car?.name ?? "", $0.date) < ($1.car?.name ?? "", $1.date)
        }
        let rows = sorted.map { i in
            [
                field(i.car?.name ?? ""),
                df.string(from: i.date),
                String(i.mileage),
                field(i.kind.label),
                field(i.displayTitle),
                field(i.garage),
                i.amountCents.map(Money.editString(cents:)) ?? "",
                i.status.label,
            ].joined(separator: ";")
        }
        let header = "Voiture;Date;Km;Type;Titre;Garage;Montant;Statut"
        return "\u{FEFF}" + ([header] + rows).joined(separator: "\r\n") + "\r\n"
    }
}
```

- [ ] **Step 4 : Lancer les tests**

Run : `scripts/test.sh -only-testing:SuiviAutoTests/BackupServiceTests`
Attendu : `TESTS OK`

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: sauvegarde zip, restauration au lancement et export CSV"
```

---

### Task 14 : Composants visuels (style coloré en relief)

**Files :**
- Create: `SuiviAuto/Views/Components/UIExtensions.swift`, `Card.swift`, `Badges.swift`, `CarAvatar.swift`, `Formatters.swift`, `SuiviAuto/Services/ImageResizer.swift`

- [ ] **Step 1 : `SuiviAuto/Views/Components/UIExtensions.swift`**

```swift
import SwiftUI

extension Color {
    /// "#2E86AB" -> Color
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

extension DueStatus {
    var color: Color {
        switch self {
        case .ok: .green
        case .soon: .orange
        case .overdue: .red
        }
    }
    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .soon: "clock.badge.exclamationmark.fill"
        case .overdue: "exclamationmark.triangle.fill"
        }
    }
}

extension InterventionKind {
    var color: Color {
        switch self {
        case .entretien: .blue
        case .reparation: .orange
        case .controleTechnique: .green
        case .pneus: .gray
        case .carrosserie: .purple
        case .autre: .teal
        }
    }
}
```

- [ ] **Step 2 : `SuiviAuto/Views/Components/Card.swift`**

```swift
import SwiftUI

/// Carte en relief : fond, ombre portée, liseré dégradé de la couleur d'accent.
struct Card<Content: View>: View {
    var tint: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [tint.opacity(0.7), tint.opacity(0.1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 1.5)
            )
    }
}

/// Grande valeur chiffrée avec légende (KPI).
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        Card(tint: tint) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(tint.gradient).shadow(color: tint.opacity(0.4), radius: 4, y: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
            }
        }
    }
}
```

- [ ] **Step 3 : `SuiviAuto/Views/Components/Badges.swift`**

```swift
import SwiftUI

struct StatusBadge: View {
    let status: DueStatus
    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(status.color.gradient))
            .foregroundStyle(.white)
            .shadow(color: status.color.opacity(0.4), radius: 3, y: 2)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .overlay(Capsule().strokeBorder(color.opacity(0.5)))
            .foregroundStyle(color)
    }
}

struct DueItemRow: View {
    let item: DueItem
    var showCar = true
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: item.carColorHex).gradient).frame(width: 12, height: 12)
                .shadow(radius: 1, y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).fontWeight(.semibold)
                Text([showCar ? item.carName : nil, item.whenText, item.detail].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            StatusBadge(status: item.status)
        }
        .padding(.vertical, 4)
    }
}

extension DueItem {
    var whenText: String? {
        var parts: [String] = []
        if let dueDate { parts.append(Fmt.date(dueDate)) }
        if let dueKm { parts.append(Fmt.km(dueKm)) }
        return parts.isEmpty ? nil : parts.joined(separator: " ou ")
    }
}
```

- [ ] **Step 4 : `SuiviAuto/Views/Components/Formatters.swift`**

```swift
import Foundation

enum Fmt {
    static let locale = Locale(identifier: "fr_FR")
    static func km(_ v: Int) -> String { "\(v.formatted(.number.locale(locale))) km" }
    static func date(_ d: Date) -> String { d.formatted(.dateTime.day().month(.wide).year().locale(locale)) }
    static func shortDate(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)) }
}
```

- [ ] **Step 5 : `SuiviAuto/Views/Components/CarAvatar.swift`**

```swift
import SwiftUI

struct CarAvatar: View {
    let car: Car
    var size: CGFloat = 34

    var body: some View {
        let tint = Color(hex: car.colorHex)
        ZStack {
            if let data = car.photo, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(tint.gradient)
                Image(systemName: "car.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(tint, lineWidth: 2))
        .shadow(color: tint.opacity(0.45), radius: 3, y: 2)
    }
}
```

- [ ] **Step 6 : `SuiviAuto/Services/ImageResizer.swift`**

```swift
import AppKit
import ImageIO

enum ImageResizer {
    /// Lit une image, la réduit à `maxDimension` px et la retourne en JPEG.
    static func jpegData(from url: URL, maxDimension: Int = 1024) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
```

- [ ] **Step 7 : Compiler**

Run : `scripts/build.sh`
Attendu : `BUILD OK`

- [ ] **Step 8 : Commit**

```bash
git add -A && git commit -m "feat: composants visuels (cartes en relief, badges, avatar)"
```

---

### Task 15 : Application, menus, fenêtre principale et barre latérale

**Files :**
- Create: `SuiviAuto/AppState.swift`, `SuiviAuto/Services/BackupActions.swift`, `SuiviAuto/Views/ContentView.swift`, `SuiviAuto/Views/SidebarView.swift`, `SuiviAuto/Views/CarContentView.swift`
- Create (provisoire, complétés aux tâches 16 à 18) : `SuiviAuto/Views/Car/CarFormView.swift`, ainsi que des vues de remplacement dans `SuiviAuto/Views/Placeholders.swift`
- Modify: `SuiviAuto/SuiviAutoApp.swift` (remplacement complet)

- [ ] **Step 1 : `SuiviAuto/AppState.swift`**

```swift
import Observation

@Observable
final class AppState {
    var showingNewCar = false
    var showingNewIntervention = false
    var showingNewReading = false
    var errorMessage: String?
}
```

- [ ] **Step 2 : `SuiviAuto/Services/BackupActions.swift`**

```swift
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
        alert.informativeText = "Les données actuelles seront remplacées par la sauvegarde. Une copie est conservée dans « SuiviAuto-avant-restauration ». L'application va redémarrer."
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
```

- [ ] **Step 3 : Remplacer `SuiviAuto/SuiviAutoApp.swift`**

```swift
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
```

- [ ] **Step 4 : `SuiviAuto/Views/SidebarView.swift`**

```swift
import SwiftUI

enum SidebarItem: Hashable {
    case dashboard
    case car(Car)
}

struct SidebarView: View {
    let cars: [Car]
    @Binding var selection: SidebarItem?
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: $selection) {
            Label("Tableau de bord", systemImage: "gauge.with.dots.needle.67percent")
                .tag(SidebarItem.dashboard)
            Section("Mes voitures") {
                ForEach(cars) { car in
                    CarRow(car: car).tag(SidebarItem.car(car))
                }
            }
        }
        .navigationTitle("SuiviAuto")
        .toolbar {
            Button { appState.showingNewCar = true } label: {
                Label("Nouvelle voiture", systemImage: "plus")
            }
            .help("Nouvelle voiture (⇧⌘N)")
        }
    }
}

struct CarRow: View {
    let car: Car
    var body: some View {
        let status = DueAggregator.worstStatus(for: car)
        HStack(spacing: 10) {
            CarAvatar(car: car, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(car.name).fontWeight(.semibold)
                Text(car.plate.isEmpty ? "\(car.brand) \(car.modelName)" : car.plate)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status != .ok {
                Image(systemName: status.symbol).foregroundStyle(status.color)
                    .help(status.label)
            }
        }
        .padding(.vertical, 3)
    }
}
```

- [ ] **Step 5 : `SuiviAuto/Views/CarContentView.swift`**

```swift
import SwiftUI

enum CarTab: String, CaseIterable, Identifiable {
    case interventions, kilometrage, regles, echeances, infos
    var id: String { rawValue }
    var label: String {
        switch self {
        case .interventions: "Interventions"
        case .kilometrage: "Km"
        case .regles: "Règles"
        case .echeances: "Échéances"
        case .infos: "Infos"
        }
    }
}

struct CarContentView: View {
    let car: Car
    @Binding var tab: CarTab
    @Binding var selectedIntervention: Intervention?
    let onDeleteCar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("Onglet", selection: $tab) {
                ForEach(CarTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            Divider()
            switch tab {
            case .interventions: InterventionListView(car: car, selection: $selectedIntervention)
            case .kilometrage: MileageView(car: car)
            case .regles: RulesView(car: car)
            case .echeances: DeadlinesView(car: car)
            case .infos: CarInfoView(car: car, onDelete: onDeleteCar)
            }
        }
        .navigationTitle(car.name)
    }
}
```

- [ ] **Step 6 : `SuiviAuto/Views/ContentView.swift`**

```swift
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query(sort: \Car.createdAt) private var cars: [Car]

    @State private var selection: SidebarItem? = .dashboard
    @State private var selectedIntervention: Intervention?
    @State private var carTab: CarTab = .interventions

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
            await NotificationScheduler.reschedule(context: context)
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            guard !SuiviAutoApp.isRunningTests else { return }
            Task { await NotificationScheduler.reschedule(context: context) }
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
        DispatchQueue.main.async {
            do { try DeletionService.delete(car, in: context) }
            catch { appState.errorMessage = "Suppression impossible : \(error.localizedDescription)" }
        }
    }
}
```

- [ ] **Step 7 : `SuiviAuto/Views/Car/CarFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct CarFormView: View {
    let car: Car?
    var onCreated: ((Car) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allCars: [Car]

    @State private var name = ""
    @State private var brand = ""
    @State private var modelName = ""
    @State private var plate = ""
    @State private var vin = ""
    @State private var firstRegistrationDate = Date.now
    @State private var fuel: FuelType = .essence
    @State private var colorHex = CarPalette.colors[0]
    @State private var photo: Data?
    @State private var pickingPhoto = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(car == nil ? "Nouvelle voiture" : "Modifier la voiture")
                .font(.title2.bold()).padding([.top, .horizontal])
            Form {
                Section {
                    HStack(spacing: 16) {
                        avatarPreview
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Choisir une photo…") { pickingPhoto = true }
                            if photo != nil { Button("Retirer la photo", role: .destructive) { photo = nil } }
                            Text("ou glissez une image sur le cercle").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Couleur")
                        Spacer()
                        ForEach(CarPalette.colors, id: \.self) { hex in
                            Circle().fill(Color(hex: hex).gradient)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2.5 : 0))
                                .shadow(radius: 1, y: 1)
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Section {
                    TextField("Nom", text: $name, prompt: Text("ex. Clio de Marie"))
                    TextField("Marque", text: $brand)
                    TextField("Modèle", text: $modelName)
                    TextField("Immatriculation", text: $plate, prompt: Text("AB-123-CD"))
                    TextField("N° VIN", text: $vin)
                    DatePicker("1re immatriculation", selection: $firstRegistrationDate, displayedComponents: .date)
                    Picker("Carburant", selection: $fuel) {
                        ForEach(FuelType.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 520)
        .onAppear(perform: load)
        .fileImporter(isPresented: $pickingPhoto, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { loadPhoto(url) }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private var avatarPreview: some View {
        ZStack {
            if let photo, let image = NSImage(data: photo) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(Color(hex: colorHex).gradient)
                Image(systemName: "car.fill").font(.system(size: 30)).foregroundStyle(.white)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .shadow(color: Color(hex: colorHex).opacity(0.5), radius: 5, y: 3)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            loadPhoto(url)
            return true
        }
    }

    private func loadPhoto(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let data = ImageResizer.jpegData(from: url) { photo = data } else { errorMessage = "Image illisible." }
    }

    private func load() {
        guard let car else {
            colorHex = CarPalette.color(forIndex: allCars.count)
            return
        }
        name = car.name; brand = car.brand; modelName = car.modelName; plate = car.plate; vin = car.vin
        firstRegistrationDate = car.firstRegistrationDate; fuel = car.fuel; colorHex = car.colorHex; photo = car.photo
    }

    private func save() {
        let target: Car
        if let car {
            target = car
        } else {
            target = Car(name: name, firstRegistrationDate: firstRegistrationDate, colorHex: colorHex)
            context.insert(target)
            target.addDefaultRules(in: context)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.brand = brand; target.modelName = modelName; target.plate = plate.uppercased(); target.vin = vin.uppercased()
        target.firstRegistrationDate = firstRegistrationDate; target.fuel = fuel; target.colorHex = colorHex; target.photo = photo
        do {
            try context.save()
            if car == nil { onCreated?(target) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 8 : `SuiviAuto/Views/Placeholders.swift`**, des vues provisoires pour que l'app compile

Chaque vue est remplacée (et supprimée de ce fichier) dans les tâches 16 à 18.
```swift
import SwiftUI

struct InterventionListView: View { let car: Car; @Binding var selection: Intervention?; var body: some View { Text("Interventions") } }
struct InterventionDetailView: View { let intervention: Intervention; let onDelete: () -> Void; var body: some View { Text(intervention.displayTitle) } }
struct InterventionFormView: View { let car: Car; let intervention: Intervention?; var body: some View { Text("Formulaire") } }
struct ReadingFormView: View { let car: Car; var body: some View { Text("Relevé") } }
struct MileageView: View { let car: Car; var body: some View { Text("Km") } }
struct RulesView: View { let car: Car; var body: some View { Text("Règles") } }
struct DeadlinesView: View { let car: Car; var body: some View { Text("Échéances") } }
struct CarInfoView: View { let car: Car; let onDelete: () -> Void; var body: some View { Text("Infos") } }
struct CarSummaryView: View { let car: Car; var body: some View { Text(car.name) } }
struct DueListView: View { let items: [DueItem]; let hasCars: Bool; var body: some View { Text("Échéances") } }
struct DashboardChartsView: View { let cars: [Car]; var body: some View { Text("Tableau de bord") } }
```

- [ ] **Step 9 : Compiler, tester et lancer**

Run : `scripts/test.sh && scripts/build.sh && open "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Debug/SuiviAuto.app"`
Attendu : `TESTS OK`, `BUILD OK`, et la fenêtre s'ouvre. Vérifier à la main :
- `⇧⌘N` ouvre « Nouvelle voiture ».
- Après l'enregistrement, la voiture apparaît dans la barre latérale avec sa pastille de couleur.
- `⌘N` sans voiture sélectionnée affiche « Sélectionnez d'abord une voiture ».
- macOS demande l'autorisation des notifications.

Quitter l'app (`⌘Q`).

- [ ] **Step 10 : Commit**

```bash
git add -A && git commit -m "feat: fenêtre principale, barre latérale, menus et formulaire voiture"
```

---

### Task 16 : Interventions (liste, formulaire, détail, documents)

**Files :**
- Create: `SuiviAuto/Views/Interventions/InterventionListView.swift`, `InterventionRow.swift`, `InterventionFormView.swift`, `InterventionDetailView.swift`, `DocumentThumbnail.swift`
- Modify: `SuiviAuto/Views/Placeholders.swift` (supprimer les lignes `InterventionListView`, `InterventionDetailView`, `InterventionFormView`)

- [ ] **Step 1 : Retirer de `Placeholders.swift` les 3 lignes commençant par `struct InterventionListView`, `struct InterventionDetailView`, `struct InterventionFormView`.**

- [ ] **Step 2 : `SuiviAuto/Views/Interventions/InterventionRow.swift`**

```swift
import SwiftUI

struct InterventionRow: View {
    let intervention: Intervention

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: intervention.kind.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(intervention.kind.color.gradient).shadow(color: intervention.kind.color.opacity(0.4), radius: 2, y: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(intervention.displayTitle).fontWeight(.medium).lineLimit(1)
                Text("\(Fmt.shortDate(intervention.date)) · \(Fmt.km(intervention.mileage))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let cents = intervention.amountCents {
                    Text(Money.format(cents: cents)).fontWeight(.semibold).monospacedDigit()
                }
                HStack(spacing: 4) {
                    if !intervention.documents.isEmpty {
                        Image(systemName: "paperclip").font(.caption2).foregroundStyle(.secondary)
                    }
                    StatusPill(text: intervention.status.label, color: intervention.status == .devis ? .purple : .blue)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
```

- [ ] **Step 3 : `SuiviAuto/Views/Interventions/InterventionListView.swift`**

```swift
import SwiftUI

struct InterventionListView: View {
    let car: Car
    @Binding var selection: Intervention?
    @Environment(AppState.self) private var appState
    @State private var search = ""
    @State private var kindFilter: InterventionKind?

    private var filtered: [Intervention] {
        car.interventions
            .filter { i in
                (kindFilter == nil || i.kind == kindFilter)
                && (search.isEmpty
                    || i.title.localizedCaseInsensitiveContains(search)
                    || i.garage.localizedCaseInsensitiveContains(search)
                    || i.notes.localizedCaseInsensitiveContains(search))
            }
            .sorted { ($0.date, $0.mileage) > ($1.date, $1.mileage) }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filtered) { i in
                InterventionRow(intervention: i).tag(i)
            }
        }
        .searchable(text: $search, prompt: "Titre, garage, notes…")
        .overlay {
            if car.interventions.isEmpty {
                ContentUnavailableView("Aucune intervention", systemImage: "wrench.and.screwdriver",
                                       description: Text("Ajoutez la première avec ⌘N."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Type", selection: $kindFilter) {
                    Text("Tous les types").tag(InterventionKind?.none)
                    Divider()
                    ForEach(InterventionKind.allCases) { Label($0.label, systemImage: $0.symbol).tag(Optional($0)) }
                }
                .help("Filtrer par type")
                Button { appState.showingNewIntervention = true } label: {
                    Label("Nouvelle intervention", systemImage: "plus")
                }
                .help("Nouvelle intervention (⌘N)")
            }
        }
    }
}
```

- [ ] **Step 4 : `SuiviAuto/Views/Interventions/InterventionFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct InterventionFormView: View {
    let car: Car
    let intervention: Intervention?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var mileage: Int?
    @State private var kind: InterventionKind = .entretien
    @State private var title = ""
    @State private var garage = ""
    @State private var amountText = ""
    @State private var status: InterventionStatus = .facture
    @State private var notes = ""
    @State private var ctResult: CTResult = .favorable
    @State private var ruleKey = ""
    @State private var showLowMileageWarning = false
    @State private var errorMessage: String?

    private var lastKnown: Int? {
        CarAnalytics.lastKnownMileage(for: car, onOrBefore: date, excluding: intervention)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(intervention == nil ? "Nouvelle intervention" : "Modifier l'intervention")
                .font(.title2.bold()).padding([.top, .horizontal])
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(InterventionKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Statut", selection: $status) {
                        ForEach(InterventionStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Titre", text: $title, prompt: Text("ex. Vidange + filtres"))
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Kilométrage", value: $mileage, format: .number, prompt: Text(lastKnown.map { "dernier : \(Fmt.km($0))" } ?? "km"))
                    TextField("Garage", text: $garage)
                    TextField("Montant (€)", text: $amountText, prompt: Text("ex. 189,90"))
                }
                Section {
                    if kind == .controleTechnique {
                        Picker("Résultat du CT", selection: $ctResult) {
                            ForEach(CTResult.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    Picker("Règle d'entretien", selection: $ruleKey) {
                        Text("Aucune").tag("")
                        ForEach(car.rules.sorted { $0.label < $1.label }) { Text($0.label).tag($0.key) }
                    }
                    .help("Relie cette intervention à une règle pour recalculer la prochaine échéance")
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { attemptSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(mileage == nil)
            }
            .padding()
        }
        .frame(width: 500)
        .onAppear(perform: load)
        .confirmationDialog("Kilométrage inférieur au dernier connu", isPresented: $showLowMileageWarning) {
            Button("Enregistrer quand même") { save() }
            Button("Corriger", role: .cancel) {}
        } message: {
            Text("Le dernier kilométrage connu à cette date est \(Fmt.km(lastKnown ?? 0)).")
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        guard let i = intervention else { return }
        date = i.date; mileage = i.mileage; kind = i.kind; title = i.title; garage = i.garage
        amountText = i.amountCents.map(Money.editString(cents:)) ?? ""
        status = i.status; notes = i.notes; ctResult = i.ctResult ?? .favorable; ruleKey = i.ruleKey ?? ""
    }

    private func attemptSave() {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && Money.parse(trimmed) == nil {
            errorMessage = "Montant invalide. Exemple : 189,90"
            return
        }
        if let m = mileage, let last = lastKnown, m < last {
            showLowMileageWarning = true
        } else {
            save()
        }
    }

    private func save() {
        let target: Intervention
        if let intervention {
            target = intervention
        } else {
            target = Intervention(date: date, mileage: mileage ?? 0, kind: kind)
            context.insert(target)
            target.car = car
        }
        target.date = date
        target.mileage = mileage ?? 0
        target.kind = kind
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.garage = garage.trimmingCharacters(in: .whitespaces)
        target.amountCents = Money.parse(amountText)
        target.status = status
        target.notes = notes
        target.ctResult = kind == .controleTechnique ? ctResult : nil
        target.ruleKey = ruleKey.isEmpty ? nil : ruleKey
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 5 : `SuiviAuto/Views/Interventions/DocumentThumbnail.swift`**

```swift
import QuickLookThumbnailing
import SwiftUI

struct DocumentThumbnail: View {
    let document: StoredDocument
    let isSelected: Bool
    @State private var image: NSImage?

    private var url: URL { DocumentStore.shared.url(for: document) }
    private var exists: Bool { DocumentStore.shared.fileExists(for: document) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                if !exists {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Fichier introuvable").font(.caption2).multilineTextAlignment(.center)
                    }
                } else if let image {
                    Image(nsImage: image).resizable().scaledToFit().padding(4)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 110, height: 130)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3))
            Text(document.originalName)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 110)
        }
        .task(id: document.fileName) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard exists else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 110, height: 130),
                                                   scale: 2, representationTypes: .thumbnail)
        image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        if image == nil { image = NSWorkspace.shared.icon(forFile: url.path) }
    }
}
```

- [ ] **Step 6 : `SuiviAuto/Views/Interventions/InterventionDetailView.swift`**

```swift
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct InterventionDetailView: View {
    @Bindable var intervention: Intervention
    let onDelete: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var importing = false
    @State private var dropTargeted = false
    @State private var previewURL: URL?
    @State private var selectedDoc: StoredDocument?

    private var tint: Color { Color(hex: intervention.car?.colorHex ?? "#2E86AB") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                infoCard
                documentsCard
            }
            .padding(20)
        }
        .dropDestination(for: URL.self) { urls, _ in
            importFiles(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .jpeg, .png, .heic],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .quickLookPreview($previewURL)
        .toolbar {
            ToolbarItemGroup {
                if intervention.status == .devis {
                    Button {
                        intervention.status = .facture
                        save()
                    } label: { Label("Transformer en facture", systemImage: "doc.badge.arrow.up") }
                }
                Button { editing = true } label: { Label("Modifier", systemImage: "pencil") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
            }
        }
        .sheet(isPresented: $editing) {
            if let car = intervention.car { InterventionFormView(car: car, intervention: intervention) }
        }
        .confirmationDialog("Supprimer cette intervention et ses \(intervention.documents.count) document(s) ?",
                            isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) { onDelete() }
        }
    }

    private var header: some View {
        Card(tint: intervention.kind.color) {
            HStack(spacing: 14) {
                Image(systemName: intervention.kind.symbol)
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 14).fill(intervention.kind.color.gradient)
                        .shadow(color: intervention.kind.color.opacity(0.5), radius: 5, y: 3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.displayTitle).font(.title2.bold())
                    HStack {
                        Text(intervention.kind.label).foregroundStyle(.secondary)
                        StatusPill(text: intervention.status.label, color: intervention.status == .devis ? .purple : .blue)
                    }
                }
                Spacer()
                if let cents = intervention.amountCents {
                    Text(Money.format(cents: cents))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
    }

    private var infoCard: some View {
        Card(tint: tint) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                infoRow("Date", Fmt.date(intervention.date))
                infoRow("Kilométrage", Fmt.km(intervention.mileage))
                if !intervention.garage.isEmpty { infoRow("Garage", intervention.garage) }
                if let r = intervention.ctResult { infoRow("Résultat CT", r.label) }
                if let key = intervention.ruleKey,
                   let rule = intervention.car?.rules.first(where: { $0.key == key }) {
                    infoRow("Règle", rule.label)
                }
                if !intervention.notes.isEmpty { infoRow("Notes", intervention.notes) }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).textSelection(.enabled)
        }
    }

    private var documentsCard: some View {
        Card(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Factures et devis", systemImage: "doc.on.doc.fill").font(.headline)
                    Spacer()
                    Button { importing = true } label: { Label("Ajouter…", systemImage: "plus") }
                }
                if intervention.documents.isEmpty {
                    Text("Glissez ici un PDF ou une photo de la facture ou du devis.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 12)], spacing: 12) {
                        ForEach(intervention.documents.sorted { $0.addedAt < $1.addedAt }) { doc in
                            DocumentThumbnail(document: doc, isSelected: selectedDoc == doc)
                                .onTapGesture(count: 2) { open(doc) }
                                .onTapGesture { selectedDoc = doc }
                                .contextMenu {
                                    Button("Coup d'œil") { preview(doc) }
                                    Button("Ouvrir") { open(doc) }
                                    Button("Afficher dans le Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([DocumentStore.shared.url(for: doc)])
                                    }
                                    Divider()
                                    Button("Supprimer", role: .destructive) { deleteDocument(doc) }
                                }
                        }
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .onKeyPress(.space) {
                        guard let doc = selectedDoc else { return .ignored }
                        preview(doc)
                        return .handled
                    }
                    Text("Barre d'espace : Coup d'œil · Double-clic : ouvrir").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func preview(_ doc: StoredDocument) {
        guard DocumentStore.shared.fileExists(for: doc) else { return }
        previewURL = DocumentStore.shared.url(for: doc)
    }

    private func open(_ doc: StoredDocument) {
        guard DocumentStore.shared.fileExists(for: doc) else { return }
        NSWorkspace.shared.open(DocumentStore.shared.url(for: doc))
    }

    private func deleteDocument(_ doc: StoredDocument) {
        if selectedDoc == doc { selectedDoc = nil }
        do { try DeletionService.delete(doc, in: context) }
        catch { appState.errorMessage = error.localizedDescription }
    }

    private func importFiles(_ urls: [URL]) {
        var rejected: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let doc = try DocumentStore.shared.importFile(at: url)
                context.insert(doc)
                doc.intervention = intervention
            } catch {
                rejected.append(url.lastPathComponent)
            }
        }
        save()
        if !rejected.isEmpty {
            appState.errorMessage = "Non importé(s) : \(rejected.joined(separator: ", ")). Formats acceptés : PDF, JPEG, PNG, HEIC."
        }
    }

    private func save() {
        do { try context.save() }
        catch { appState.errorMessage = error.localizedDescription }
    }
}
```

- [ ] **Step 7 : Compiler et tester à la main**

Run : `scripts/test.sh && scripts/build.sh && open "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Debug/SuiviAuto.app"`
Vérifier à la main :
- Sélectionner une voiture puis `⌘N`, saisir un devis à 189,90 € → la ligne apparaît avec la pastille « Devis ».
- Glisser un PDF depuis le Finder sur le détail → la miniature apparaît. La barre d'espace ouvre Coup d'œil, le double-clic ouvre Aperçu.
- Glisser un `.docx` → message d'erreur sur le format.
- « Transformer en facture » → la pastille passe à « Facture ».
- Saisir un km inférieur au précédent → avertissement, puis « Enregistrer quand même ».
- Supprimer l'intervention → le fichier disparaît de `~/Library/Application Support/SuiviAuto/Documents/`.

- [ ] **Step 8 : Commit**

```bash
git add -A && git commit -m "feat: interventions avec documents, Coup d'œil et glisser-déposer"
```

---

### Task 17 : Onglets voiture (Km, Règles, Échéances, Infos, Résumé)

**Files :**
- Create: `SuiviAuto/Views/Car/ReadingFormView.swift`, `MileageView.swift`, `RulesView.swift`, `RuleFormView.swift`, `DeadlinesView.swift`, `DeadlineFormView.swift`, `CarInfoView.swift`, `CarSummaryView.swift`
- Modify: `SuiviAuto/Views/Placeholders.swift` (supprimer `ReadingFormView`, `MileageView`, `RulesView`, `DeadlinesView`, `CarInfoView`, `CarSummaryView`)

- [ ] **Step 1 : Retirer ces 6 lignes de `Placeholders.swift`.**

- [ ] **Step 2 : `SuiviAuto/Views/Car/ReadingFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct ReadingFormView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var mileage: Int?
    @State private var showWarning = false
    @State private var errorMessage: String?

    private var lastKnown: Int? { CarAnalytics.lastKnownMileage(for: car, onOrBefore: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nouveau relevé km — \(car.name)").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Kilométrage", value: $mileage, format: .number,
                          prompt: Text(lastKnown.map { "dernier : \(Fmt.km($0))" } ?? "km"))
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") {
                    if let m = mileage, let last = lastKnown, m < last { showWarning = true } else { save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mileage == nil)
            }
            .padding()
        }
        .frame(width: 420)
        .confirmationDialog("Kilométrage inférieur au dernier connu", isPresented: $showWarning) {
            Button("Enregistrer quand même") { save() }
            Button("Corriger", role: .cancel) {}
        } message: { Text("Le dernier kilométrage connu est \(Fmt.km(lastKnown ?? 0)).") }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let r = OdometerReading(date: date, mileage: mileage ?? 0)
        context.insert(r)
        r.car = car
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
```

- [ ] **Step 3 : `SuiviAuto/Views/Car/MileageView.swift`**

```swift
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
                            Text(estimator.kmPerDay.map { "\(Fmt.km(Int(($0 * 365).rounded()))) / an" } ?? "—")
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
                                    context.delete(r)
                                    try? context.save()
                                } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                            }
                            Divider()
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 4 : `SuiviAuto/Views/Car/RuleFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct RuleFormView: View {
    let car: Car
    let rule: MaintenanceRule?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var intervalKm: Int?
    @State private var intervalMonths: Int?
    @State private var errorMessage: String?

    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
        && ((intervalKm ?? 0) > 0 || (intervalMonths ?? 0) > 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rule == nil ? "Nouvelle règle d'entretien" : "Modifier la règle").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                TextField("Nom", text: $label, prompt: Text("ex. Filtre à air"))
                TextField("Tous les … km", value: $intervalKm, format: .number, prompt: Text("facultatif"))
                TextField("Tous les … mois", value: $intervalMonths, format: .number, prompt: Text("facultatif"))
                Text("Renseignez au moins un des deux intervalles. Le premier atteint déclenche l'alerte.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }.keyboardShortcut(.defaultAction).disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420)
        .onAppear {
            if let rule { label = rule.label; intervalKm = rule.intervalKm; intervalMonths = rule.intervalMonths }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let km = (intervalKm ?? 0) > 0 ? intervalKm : nil
        let months = (intervalMonths ?? 0) > 0 ? intervalMonths : nil
        let name = label.trimmingCharacters(in: .whitespaces)
        if let rule {
            rule.label = name; rule.intervalKm = km; rule.intervalMonths = months
        } else {
            let key = MaintenanceRule.makeKey(label: name, existing: Set(car.rules.map(\.key)))
            let r = MaintenanceRule(key: key, label: name, intervalKm: km, intervalMonths: months)
            context.insert(r)
            r.car = car
        }
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
```

- [ ] **Step 5 : `SuiviAuto/Views/Car/RulesView.swift`**

```swift
import SwiftData
import SwiftUI

struct RulesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @State private var editingRule: MaintenanceRule?
    @State private var creating = false

    var body: some View {
        let estimator = CarAnalytics.estimator(for: car)
        List {
            ForEach(car.rules.sorted { $0.label < $1.label }) { rule in
                let due = DueAggregator.ruleDue(rule, car: car, estimator: estimator, now: .now)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.label).fontWeight(.semibold)
                        Text(rule.intervalDescription).font(.caption).foregroundStyle(.secondary)
                        Text("Prochaine : " + [due.dueDate.map(Fmt.date), due.dueKm.map(Fmt.km)].compactMap { $0 }.joined(separator: " ou "))
                            .font(.caption)
                    }
                    Spacer()
                    StatusBadge(status: due.status)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editingRule = rule }
                .contextMenu {
                    Button("Modifier") { editingRule = rule }
                    Button("Supprimer", role: .destructive) {
                        context.delete(rule)
                        try? context.save()
                    }
                }
            }
        }
        .overlay {
            if car.rules.isEmpty {
                ContentUnavailableView("Aucune règle", systemImage: "list.bullet.clipboard",
                                       description: Text("Ex. vidange tous les 15 000 km ou 12 mois."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Pour qu'une facture fasse avancer une règle, choisissez cette règle dans le formulaire de l'intervention. Double-clic pour modifier.")
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }
        .toolbar {
            Button { creating = true } label: { Label("Nouvelle règle", systemImage: "plus") }
        }
        .sheet(item: $editingRule) { RuleFormView(car: car, rule: $0) }
        .sheet(isPresented: $creating) { RuleFormView(car: car, rule: nil) }
    }
}
```

- [ ] **Step 6 : `SuiviAuto/Views/Car/DeadlineFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct DeadlineFormView: View {
    let car: Car
    let deadline: Deadline?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var dueDate = Date.now
    @State private var repeatsYearly = true
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(deadline == nil ? "Nouvelle échéance" : "Modifier l'échéance").font(.title2.bold()).padding([.top, .horizontal])
            Form {
                TextField("Libellé", text: $label, prompt: Text("ex. Assurance, pneus hiver, fin de garantie"))
                DatePicker("Date", selection: $dueDate, displayedComponents: .date)
                Toggle("Se répète chaque année", isOn: $repeatsYearly)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 440)
        .onAppear {
            if let deadline {
                label = deadline.label; dueDate = deadline.dueDate; repeatsYearly = deadline.repeatsYearly; notes = deadline.notes
            }
        }
        .alert("Erreur", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let target: Deadline
        if let deadline {
            target = deadline
        } else {
            target = Deadline(label: label, dueDate: dueDate, repeatsYearly: repeatsYearly)
            context.insert(target)
            target.car = car
        }
        target.label = label.trimmingCharacters(in: .whitespaces)
        target.dueDate = dueDate
        target.repeatsYearly = repeatsYearly
        target.notes = notes
        do { try context.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}
```

- [ ] **Step 7 : `SuiviAuto/Views/Car/DeadlinesView.swift`**

```swift
import SwiftData
import SwiftUI

struct DeadlinesView: View {
    let car: Car
    @Environment(\.modelContext) private var context
    @State private var editing: Deadline?
    @State private var creating = false

    var body: some View {
        List {
            ForEach(car.deadlines.sorted { $0.dueDate < $1.dueDate }) { d in
                let status = DueStatusEvaluator.status(dueDate: d.dueDate, remainingKm: nil, now: .now)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.label).fontWeight(.semibold)
                        Text(Fmt.date(d.dueDate) + (d.repeatsYearly ? " · chaque année" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                        if !d.notes.isEmpty { Text(d.notes).font(.caption) }
                    }
                    Spacer()
                    StatusBadge(status: status)
                    Button(d.repeatsYearly ? "Fait ✓ (+1 an)" : "Fait ✓") { markDone(d) }
                        .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editing = d }
                .contextMenu {
                    Button("Modifier") { editing = d }
                    Button("Supprimer", role: .destructive) { context.delete(d); try? context.save() }
                }
            }
        }
        .overlay {
            if car.deadlines.isEmpty {
                ContentUnavailableView("Aucune échéance", systemImage: "calendar.badge.clock",
                                       description: Text("Assurance, pneus hiver, fin de garantie…"))
            }
        }
        .toolbar {
            Button { creating = true } label: { Label("Nouvelle échéance", systemImage: "plus") }
        }
        .sheet(item: $editing) { DeadlineFormView(car: car, deadline: $0) }
        .sheet(isPresented: $creating) { DeadlineFormView(car: car, deadline: nil) }
    }

    /// Annuelle : avance d'un an. Ponctuelle : supprimée.
    private func markDone(_ d: Deadline) {
        if !d.markDone() { context.delete(d) }
        try? context.save()
    }
}
```

- [ ] **Step 8 : `SuiviAuto/Views/Car/CarInfoView.swift`**

```swift
import SwiftUI

struct CarInfoView: View {
    let car: Car
    let onDelete: () -> Void
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card(tint: Color(hex: car.colorHex)) {
                    HStack(spacing: 16) {
                        CarAvatar(car: car, size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name).font(.title2.bold())
                            Text("\(car.brand) \(car.modelName)").foregroundStyle(.secondary)
                        }
                    }
                }
                Card(tint: Color(hex: car.colorHex)) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        row("Immatriculation", car.plate)
                        row("N° VIN", car.vin)
                        row("1re immatriculation", Fmt.date(car.firstRegistrationDate))
                        row("Carburant", car.fuel.label)
                        row("Interventions", "\(car.interventions.count)")
                    }
                }
                HStack {
                    Button { editing = true } label: { Label("Modifier", systemImage: "pencil") }
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer la voiture", systemImage: "trash") }
                }
            }
            .padding(14)
        }
        .sheet(isPresented: $editing) { CarFormView(car: car) }
        .confirmationDialog("Supprimer « \(car.name) » ?", isPresented: $confirmDelete) {
            Button("Supprimer définitivement", role: .destructive) { onDelete() }
        } message: {
            Text("Toutes ses interventions, documents, relevés, règles et échéances seront supprimés.")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value.isEmpty ? "—" : value).textSelection(.enabled)
        }
    }
}
```

- [ ] **Step 9 : `SuiviAuto/Views/Car/CarSummaryView.swift`**

```swift
import SwiftUI

/// Colonne de détail d'une voiture quand aucune intervention n'est sélectionnée.
struct CarSummaryView: View {
    let car: Car

    var body: some View {
        let tint = Color(hex: car.colorHex)
        let items = DueAggregator.items(for: car)
        let year = Calendar.current.component(.year, from: .now)
        let spent = CostSummary.total(CarAnalytics.costEntries(for: [car]), year: year)
        let km = CarAnalytics.estimator(for: car).estimatedCurrentMileage

        ScrollView {
            VStack(spacing: 16) {
                Card(tint: tint) {
                    HStack(spacing: 16) {
                        CarAvatar(car: car, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name).font(.title.bold())
                            Text([car.brand, car.modelName, car.plate].filter { !$0.isEmpty }.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 14) {
                    StatTile(title: "Km estimé", value: km.map(Fmt.km) ?? "—", symbol: "speedometer", tint: tint)
                    StatTile(title: "Dépenses \(String(year))", value: Money.format(cents: spent), symbol: "eurosign.circle.fill", tint: .pink)
                }
                Card(tint: tint) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Échéances").font(.headline)
                        ForEach(items) { item in
                            DueItemRow(item: item, showCar: false)
                            Divider()
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
```

- [ ] **Step 10 : Compiler et tester à la main**

Run : `scripts/test.sh && scripts/build.sh && open "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Debug/SuiviAuto.app"`
Vérifier à la main :
- **Km** : `⌘K` ajoute deux relevés espacés → courbe, moyenne par an et km estimé.
- **Règles** : les 3 règles par défaut ont un badge. Créer une facture « Vidange » liée à la règle → la date de « Prochaine » avance.
- **Échéances** : créer « Assurance » à J+30 (badge orange), puis « Fait ✓ » → la date avance d'un an et le badge passe au vert.
- **Infos** : modifier, puis supprimer la voiture → retour au tableau de bord.
- **Détail sans intervention sélectionnée** : le résumé s'affiche avec ses tuiles.

- [ ] **Step 11 : Commit**

```bash
git add -A && git commit -m "feat: onglets kilométrage, règles, échéances, infos et résumé voiture"
```

---

### Task 18 : Tableau de bord

**Files :**
- Create: `SuiviAuto/Views/Dashboard/DueListView.swift`, `SuiviAuto/Views/Dashboard/DashboardChartsView.swift`
- Delete: `SuiviAuto/Views/Placeholders.swift` (il ne doit plus rester que `DueListView` et `DashboardChartsView`)

- [ ] **Step 1 : Supprimer `SuiviAuto/Views/Placeholders.swift`**

```bash
git rm SuiviAuto/Views/Placeholders.swift
```

- [ ] **Step 2 : `SuiviAuto/Views/Dashboard/DueListView.swift`**

```swift
import SwiftUI

struct DueListView: View {
    let items: [DueItem]
    let hasCars: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            let urgent = items.filter { $0.status != .ok }
            let later = items.filter { $0.status == .ok }
            if !urgent.isEmpty {
                Section("À surveiller") {
                    ForEach(urgent) { DueItemRow(item: $0) }
                }
            }
            if !later.isEmpty {
                Section("Plus tard") {
                    ForEach(later) { DueItemRow(item: $0) }
                }
            }
        }
        .navigationTitle("Prochaines échéances")
        .overlay {
            if !hasCars {
                ContentUnavailableView {
                    Label("Aucune voiture", systemImage: "car.2.fill")
                } description: {
                    Text("Ajoutez votre première voiture pour suivre son entretien.")
                } actions: {
                    Button("Ajouter une voiture") { appState.showingNewCar = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
```

- [ ] **Step 3 : `SuiviAuto/Views/Dashboard/DashboardChartsView.swift`**

```swift
import Charts
import SwiftUI

struct DashboardChartsView: View {
    let cars: [Car]

    private struct KmPoint: Identifiable {
        let id = UUID()
        let car: String
        let date: Date
        let km: Int
    }

    private struct YearCost: Identifiable {
        let id = UUID()
        let year: String
        let car: String
        let euros: Double
    }

    var body: some View {
        let year = Calendar.current.component(.year, from: .now)
        let entries = CarAnalytics.costEntries(for: cars)
        let items = DueAggregator.items(for: cars)
        let names = cars.map(\.name)
        let colors = cars.map { Color(hex: $0.colorHex) }

        let kmPoints = cars.flatMap { car in
            CarAnalytics.estimator(for: car).points.map { KmPoint(car: car.name, date: $0.date, km: $0.km) }
        }
        let costs = CostSummary.byCarAndYear(entries)
            .map { YearCost(year: String($0.key.year), car: $0.key.carName, euros: Double($0.value) / 100) }
            .sorted { $0.year < $1.year }

        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    StatTile(title: "Dépenses \(String(year))",
                             value: Money.format(cents: CostSummary.total(entries, year: year)),
                             symbol: "eurosign.circle.fill", tint: .pink)
                    StatTile(title: "Voitures", value: "\(cars.count)", symbol: "car.2.fill", tint: .blue)
                    StatTile(title: "À surveiller", value: "\(items.filter { $0.status != .ok }.count)",
                             symbol: "exclamationmark.triangle.fill", tint: .orange)
                }

                Card(tint: .teal) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Kilométrage", systemImage: "speedometer").font(.headline)
                        ForEach(cars) { car in
                            HStack {
                                CarAvatar(car: car, size: 22)
                                Text(car.name)
                                Spacer()
                                Text(CarAnalytics.estimator(for: car).estimatedCurrentMileage.map(Fmt.km) ?? "—")
                                    .fontWeight(.semibold).monospacedDigit()
                            }
                        }
                        if kmPoints.count >= 2 {
                            Chart(kmPoints) { p in
                                LineMark(x: .value("Date", p.date), y: .value("Km", p.km))
                                    .foregroundStyle(by: .value("Voiture", p.car))
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", p.date), y: .value("Km", p.km))
                                    .foregroundStyle(by: .value("Voiture", p.car))
                            }
                            .chartForegroundStyleScale(domain: names, range: colors)
                            .frame(height: 220)
                        }
                    }
                }

                Card(tint: .pink) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Dépenses par année", systemImage: "chart.bar.fill").font(.headline)
                        if costs.isEmpty {
                            Text("Aucune facture avec montant pour l'instant.").foregroundStyle(.secondary)
                        } else {
                            Chart(costs) { c in
                                BarMark(x: .value("Année", c.year), y: .value("€", c.euros))
                                    .foregroundStyle(by: .value("Voiture", c.car))
                                    .cornerRadius(4)
                            }
                            .chartForegroundStyleScale(domain: names, range: colors)
                            .frame(height: 220)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Tableau de bord")
    }
}
```

- [ ] **Step 4 : Compiler et tester à la main**

Run : `scripts/test.sh && scripts/build.sh && open "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Debug/SuiviAuto.app"`
Vérifier : avec 2 voitures et quelques factures, le tableau de bord affiche les tuiles, la liste « À surveiller / Plus tard », la courbe km et l'histogramme par année, chaque voiture dans sa couleur. Sans aucune voiture, le bouton « Ajouter une voiture » s'affiche.

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "feat: tableau de bord (échéances, kilométrage, dépenses)"
```

---

### Task 19 : Vérification finale et installation

**Files :**
- Create: `scripts/install.sh`, `README.md`

- [ ] **Step 1 : `scripts/install.sh`**

```bash
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION=Release scripts/build.sh
APP="$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Release/SuiviAuto.app"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/SuiviAuto.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installé : $HOME/Applications/SuiviAuto.app"
```
```bash
chmod +x scripts/install.sh
```

- [ ] **Step 2 : `README.md`**

````markdown
# SuiviAuto

Suivi d'entretien de voitures pour macOS : interventions, factures et devis, contrôle technique, kilométrage, rappels.

## Commandes

```bash
scripts/test.sh      # tests unitaires
scripts/build.sh     # compilation Debug
scripts/install.sh   # compilation Release + copie dans ~/Applications
```

Prérequis : Xcode 27+, `brew install xcodegen`.

## Données

- Base et documents : `~/Library/Application Support/SuiviAuto/` (sauvegardés par Time Machine)
- Sauvegarde manuelle : Fichier > Exporter une sauvegarde… (.zip)
- Export : Fichier > Exporter l'historique en CSV…

## Raccourcis

⇧⌘N nouvelle voiture · ⌘N nouvelle intervention · ⌘K relevé km · Espace : Coup d'œil sur un document
````

- [ ] **Step 3 : Lancer la suite complète**

Run : `scripts/test.sh`
Attendu : `TESTS OK`, sans aucun échec.

- [ ] **Step 4 : Installer et vérifier le parcours complet à la main**

Run : `scripts/install.sh && open "$HOME/Applications/SuiviAuto.app"`

Parcours :
1. Créer 2 voitures avec photo et couleurs différentes.
2. Pour la 1re : un CT favorable daté d'il y a 23 mois → badge orange « Contrôle technique ». Puis un devis pneus avec un PDF glissé → « Transformer en facture ».
3. Ajouter un relevé km (`⌘K`) → onglet Km mis à jour.
4. Fichier > Exporter une sauvegarde… → `.zip` créé.
5. Supprimer une intervention, puis Fichier > Importer une sauvegarde… → l'app redémarre et l'intervention est revenue.
6. Fichier > Exporter l'historique en CSV… → ouvrir dans Numbers ou Excel : colonnes correctes, accents corrects.
7. Notifications : `Réglages Système > Notifications > SuiviAuto` est autorisé. Pour tester, créer une échéance libre à J+8 : une notification J-7 est planifiée pour demain 9 h.

- [ ] **Step 5 : Commit**

```bash
git add -A && git commit -m "chore: script d'installation et README"
```

---

## Couverture de la spec (auto-relecture)

| Spec | Tâche |
|---|---|
| §2 SwiftUI, SwiftData, XcodeGen, CLI, fr_FR | 1, 14, 15 |
| §3 Car, Intervention, Document, Relevé, Règle, Échéance, règles par défaut | 2, 9 |
| §3 Devis exclus et « Transformer en facture » | 8, 10, 16 |
| §4 CT (4 ans, 2 ans, contre-visite, critique) | 5, 10 |
| §4 Estimation km (fenêtre de 12 mois) | 6 |
| §4 Règles km ou date et statuts 60 j / 1000 km | 3, 7 |
| §4 Coûts | 8, 17, 18 |
| §5 DocumentStore, fichier introuvable | 11, 16 |
| §5 Notifications J-30 / J-7 à 9 h, idempotentes | 12, 15 |
| §5 Sauvegarde zip, restauration avec redémarrage, CSV « ; » + BOM | 13, 15 |
| §6 3 colonnes, onglets, tableau de bord, raccourcis, style en relief | 14 à 18 |
| §7 Erreurs (km inférieur, confirmations, format refusé, échec d'enregistrement) | 11, 15, 16, 17 |
| §9 Tests | 3 à 13 |

Écart assumé par rapport à la spec : les montants sont stockés en centimes (`Int`) plutôt qu'en `Decimal`, pour garantir l'exactitude et éviter les limites de SwiftData.

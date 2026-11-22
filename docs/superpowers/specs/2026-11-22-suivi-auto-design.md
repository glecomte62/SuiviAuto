# SuiviAuto — Spécification de conception

Date : 2026-11-22
Statut : validé (brainstorming), en attente de relecture

## 1. Objectif

Application Mac native pour suivre l'entretien de plusieurs voitures personnelles :
historique des interventions, archivage des factures et devis (PDF / images),
suivi du contrôle technique, suivi du kilométrage, rappels d'entretien et d'échéances.

Usage mono-utilisateur, données 100 % locales, aucun serveur.

## 2. Choix techniques

- **Plateforme** : macOS 27+ uniquement (Xcode 27.2 installé).
- **UI** : SwiftUI, `NavigationSplitView` 3 colonnes, Swift Charts pour les graphiques.
- **Persistance** : SwiftData.
- **Projet** : généré par XcodeGen depuis `project.yml` ; compilation et tests via `xcodebuild` en ligne de commande.
- **Tests** : XCTest sur la couche `Logic/`.
- **Langue de l'interface** : français. Formats de date, de montant (€) et de km au format `fr_FR`.

## 3. Modèle de données

### Car (voiture)
| Champ | Type | Obligatoire |
|---|---|---|
| name | String (ex. « Clio de Marie ») | oui |
| brand, model | String | non |
| plate | String (immatriculation) | non |
| vin | String | non |
| firstRegistrationDate | Date (1re immatriculation) | oui (sert au calcul du CT) |
| fuel | enum : essence, diesel, hybride, électrique, GPL, autre | non |
| colorTag | String (couleur d'accent, hex) | oui, valeur par défaut attribuée |
| photo | Data (image redimensionnée, max 1024 px) | non |
| interventions, readings, rules, deadlines | relations, suppression en cascade | — |

### Intervention
| Champ | Type |
|---|---|
| date | Date (obligatoire) |
| mileage | Int, km (obligatoire) |
| kind | enum : entretien, réparation, contrôleTechnique, pneus, carrosserie, autre |
| title | String (ex. « Vidange + filtres ») |
| garage | String, optionnel |
| amount | Decimal en €, optionnel |
| status | enum : devis, facture |
| notes | String, optionnel |
| ctResult | enum optionnel : favorable, défavorable (contre-visite), critique — uniquement si `kind == contrôleTechnique` |
| ruleKey | String optionnel : lie l'intervention à une règle d'entretien (ex. « vidange ») |
| documents | relation vers Document, suppression en cascade |

Un **devis** n'est pas pris en compte dans les coûts ni comme « dernière réalisation » d'une règle.
L'action « Transformer en facture » passe `status` à `facture`, sans perdre les champs ni les documents.

### Document
| Champ | Type |
|---|---|
| fileName | String : nom du fichier copié (UUID + extension d'origine) |
| originalName | String : nom affiché |
| addedAt | Date |
| kind | enum : pdf, image |

Fichiers stockés dans `~/Library/Application Support/SuiviAuto/Documents/`.
Formats acceptés : PDF, JPEG, PNG, HEIC.

### OdometerReading (relevé km)
`date: Date`, `mileage: Int`. Relevé manuel, en dehors d'une intervention.

### MaintenanceRule (règle d'entretien)
| Champ | Type |
|---|---|
| key | String, unique par voiture (ex. « vidange ») |
| label | String (ex. « Vidange moteur ») |
| intervalKm | Int optionnel |
| intervalMonths | Int optionnel |

Au moins un des deux intervalles est renseigné. Le point de départ est la dernière **facture**
avec le même `ruleKey`. S'il n'y en a pas, on part de la date de 1re immatriculation et de 0 km.

Règles proposées par défaut à la création d'une voiture (modifiables ou supprimables) :
vidange 15 000 km / 12 mois, courroie de distribution 120 000 km / 72 mois, liquide de frein 24 mois.

### Deadline (échéance libre)
`label: String`, `dueDate: Date`, `repeatsYearly: Bool`, `notes: String?`.
Exemples : assurance, fin de garantie, pneus hiver.
Une échéance annuelle peut être marquée « faite » : sa date avance alors d'un an.

## 4. Logique métier (`Logic/`, code pur, testé)

### TechnicalInspectionCalculator
Calcule la prochaine échéance du contrôle technique à partir de `firstRegistrationDate` et des interventions CT facturées :
- Aucun CT enregistré : échéance = 1re immatriculation + 4 ans.
- Dernier CT favorable : échéance = date de ce CT + 2 ans.
- Dernier CT défavorable ou critique : contre-visite = date de ce CT + 2 mois.
  Pour le résultat « critique », la voiture ne peut plus circuler après le jour même. L'app l'affiche, mais l'échéance calculée reste + 2 mois.
- Une contre-visite favorable (CT favorable moins de 2 mois après un CT défavorable) prolonge de 2 ans **à partir de la date du CT initial défavorable**.

### MileageEstimator
- Prend en entrée tous les points (date, km) : relevés et interventions facturées.
- Avec 0 point, pas d'estimation. Avec 1 point, km estimé = ce km et aucune moyenne.
- Avec 2 points ou plus : moyenne en km/jour calculée sur les 12 derniers mois s'il y a au moins 2 points sur cette période, sinon sur tout l'historique.
- `estimatedMileage(at: Date)` = dernier km + moyenne × jours écoulés.
- `estimatedDate(forMileage:)` = date à laquelle un km donné sera atteint (nil si la moyenne est ≤ 0).

### MaintenanceScheduler
Pour chaque règle :
- échéance en km = km de départ + `intervalKm` ;
- échéance en date = date de départ + `intervalMonths` ;
- la date d'échéance retenue est la plus proche entre la date calculée et `estimatedDate(forMileage:)` ;
- statut : `ok` à plus de 60 jours **et** à plus de 1 000 km ; `bientôt` à 60 jours ou moins **ou** à 1 000 km ou moins ; `dépassé` si la date est passée **ou** si le km estimé dépasse le seuil.

Les mêmes seuils de statut s'appliquent au CT et aux échéances libres (critère date seulement).

### CostSummary
Totaux des factures, devis exclus : par voiture et par année civile, par type d'intervention, et total général de l'année en cours.

## 5. Services

### DocumentStore
- `importFile(url) -> Document` : copie le fichier sous un nom UUID et refuse les formats non pris en charge.
- `url(for:)`, `delete(_:)`.
- Fichier absent sur le disque : renvoie un état « introuvable » sans lever d'erreur fatale.

### NotificationScheduler
- Demande l'autorisation au premier lancement.
- À chaque lancement et après chaque modification, recalcule toutes les échéances (CT, règles, échéances libres) et planifie des notifications locales à J-30 et J-7 à 9 h.
- Pour les règles en km, notifie lorsque la date estimée tombe dans moins de 30 jours.
- Supprime toutes les notifications en attente puis les replanifie (idempotent).

### BackupService
- « Exporter une sauvegarde… » : `.zip` contenant le store SwiftData et le dossier `Documents/`.
- « Importer une sauvegarde… » : remplace les données actuelles après confirmation, puis relance l'app.
- « Exporter l'historique en CSV… » : une ligne par intervention (voiture, date, km, type, titre, garage, montant, statut). Séparateur `;`, encodage UTF-8 avec BOM, pour Excel en français.

## 6. Interface

Style : coloré et en relief. Cartes avec coins arrondis et ombres portées, couleur d'accent par voiture, badges colorés (vert = ok, orange = bientôt, rouge = dépassé).

### Fenêtre principale (NavigationSplitView)
1. **Barre latérale** : « Tableau de bord » en tête, puis la liste des voitures (vignette, pastille couleur, badge du pire statut d'échéance). Bouton « + » pour ajouter une voiture.
2. **Liste** : interventions de la voiture choisie, de la plus récente à la plus ancienne. Icône par type, date, km, titre, montant, pastille devis/facture. Recherche texte et filtre par type.
3. **Détail** : fiche de l'intervention, modifiable. Grille de miniatures des documents (glisser-déposer pour en ajouter, barre d'espace pour Coup d'œil, double-clic pour ouvrir dans Aperçu). Bouton « Transformer en facture » si c'est un devis.

Onglets de la fiche voiture (accessibles depuis la colonne liste) : Interventions · Kilométrage · Règles d'entretien · Échéances · Infos.

### Tableau de bord
- **Prochaines échéances** : toutes voitures confondues, triées par date, avec badge de statut.
- **Kilométrage** : km estimé par voiture et courbe d'évolution (Swift Charts).
- **Dépenses** : total de l'année en cours et histogramme par année, empilé par voiture.

### Raccourcis
- `⌘N` : nouvelle intervention (voiture sélectionnée).
- `⌘K` : nouveau relevé km.
- `⌘⇧N` : nouvelle voiture.

## 7. Gestion des erreurs

- Km saisi inférieur au dernier km connu : avertissement, enregistrement autorisé.
- Suppression d'une intervention ou d'une voiture : confirmation, puis suppression des documents associés sur le disque.
- Fichier déposé dans un format non pris en charge : message, aucun import.
- Fichier de document manquant : miniature « Fichier introuvable », pas de crash.
- Échec d'écriture SwiftData : alerte avec le message d'erreur.

## 8. Arborescence du projet

```
~/SuiviAuto/
  project.yml
  SuiviAuto/
    SuiviAutoApp.swift
    Models/        Car, Intervention, Document, OdometerReading, MaintenanceRule, Deadline, Enums
    Logic/         TechnicalInspectionCalculator, MileageEstimator, MaintenanceScheduler, CostSummary, DueStatus
    Services/      DocumentStore, NotificationScheduler, BackupService
    Views/         Sidebar, Dashboard, InterventionList, InterventionDetail, Forms/, Components/
    Resources/     Assets.xcassets
  SuiviAutoTests/  tests XCTest de Logic/ et DocumentStore
  docs/superpowers/specs/
```

## 9. Tests

XCTest via `xcodebuild test`, sur la couche `Logic/` (sans UI) :
- CT : 1er CT à 4 ans, CT favorable à +2 ans, contre-visite à +2 mois, contre-visite favorable qui prolonge depuis le CT initial, devis CT ignoré.
- Kilométrage : 0, 1 ou plusieurs points ; fenêtre de 12 mois contre historique complet ; moyenne nulle.
- Règles : seul le km atteint, seule la date atteinte, les deux ; règle sans réalisation antérieure ; devis ignoré.
- Statuts : bornes à 60 jours et à 1 000 km.
- Coûts : devis exclus, regroupement par année.
- DocumentStore : import, format refusé, fichier manquant (dans un dossier temporaire).

## 10. Hors périmètre (V1)

OCR des factures, application iPhone et synchronisation iCloud, suivi du carburant, multi-utilisateur.

# SuiviAuto

Suivi d'entretien de voitures pour macOS : interventions, factures et devis, contrôle technique, kilométrage, rappels.

## Commandes

```bash
scripts/test.sh      # tests unitaires
scripts/build.sh     # compilation Debug
scripts/install.sh   # compilation Release + copie dans /Applications
scripts/make-dmg.sh  # installeur à partager : dist/SuiviAuto-<version>.dmg
swift scripts/make-icon.swift sortie.png  # régénère l'icône
```

Prérequis : Xcode 27+, `brew install xcodegen`.

## Données

- Base et documents : `~/Library/Application Support/SuiviAuto/` (sauvegardés par Time Machine)
- Sauvegarde manuelle : Fichier > Exporter une sauvegarde… (.zip)
- Restauration : Fichier > Importer une sauvegarde… ; les copies de sécurité des données remplacées sont conservées dans `~/Library/Application Support/SuiviAuto-avant-restauration-<date>`
- Export : Fichier > Exporter l'historique en CSV…
- Voiture d'occasion (« Achetée d'occasion ») : les règles d'entretien jamais effectuées démarrent à la date et au kilométrage d'achat.

## Raccourcis

⇧⌘N nouvelle voiture · ⌘N nouvelle intervention · ⌘K relevé km · Espace : Coup d'œil sur un document

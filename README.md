# SuiviAuto

Créé par **Guillaume LECOMTE**.

📖 **[Guide d'utilisation complet](docs/GUIDE.md)** · ⬇️ **[Télécharger la dernière version](https://github.com/glecomte62/SuiviAuto/releases/latest)**

Suivi d'entretien de voitures pour macOS : interventions, factures et devis, contrôle technique, kilométrage, rappels.

**Nouveautés 2.0 :** photo de voiture en entier, opérations détaillées, onglet Carnet (filtres, export PDF/CSV), échéances au kilométrage avec devis joints, lecture automatique des factures (sur le Mac, hors ligne).

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

⇧⌘N nouvelle voiture · ⌘N nouvelle intervention · ⌘K relevé km · ⌥⌘N nouveau garage · Espace : Coup d'œil sur un document

## Un problème, une idée ?

[Signaler un problème ou proposer une idée](https://github.com/glecomte62/SuiviAuto/issues/new/choose) — sans informations personnelles, la page est publique.

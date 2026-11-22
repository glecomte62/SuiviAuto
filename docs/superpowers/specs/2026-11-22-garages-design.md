# SuiviAuto 1.1 — Garages et contacts : spécification

Date : 2026-11-22
Statut : validé (brainstorming)
Complète : `2026-11-22-suivi-auto-design.md`

## 1. Objectif

Remplacer le champ texte libre « Garage » des interventions par un **carnet de garages** en base de données. Chaque garage a ses coordonnées, ses horaires, ses spécialités, une note et une **liste de contacts internes** (réception, chef d'atelier, mécanicien…). Un garage est partagé entre toutes les voitures.

Contrainte forte : SuiviAuto 1.0 est déjà distribuée. Les bases et les sauvegardes `.zip` de la 1.0 doivent s'ouvrir sans perte en 1.1.

## 2. Modèle de données

### Garage (nouveau)
| Champ | Type | Remarque |
|---|---|---|
| uuid | UUID | identifiant stable |
| name | String | obligatoire (non vide après nettoyage) |
| address | String | « » par défaut |
| phone | String | « » |
| email | String | « » |
| website | String | « » |
| openingHours | String | texte libre multiligne |
| specialties | String | texte libre, ex. « Renault, pneus, carrosserie » |
| rating | Int | 0 à 5 ; 0 = non noté ; borné (stocké dans `ratingValue`, exposé par la propriété calculée `rating`) |
| review | String | avis privé, multiligne |
| createdAt | Date | |
| contacts | [GarageContact] | suppression en cascade |
| interventions | [Intervention] | inverse de `Intervention.garageRef`, règle *nullify* |

### GarageContact (nouveau)
| Champ | Type |
|---|---|
| uuid | UUID |
| name | String (obligatoire) |
| role | String — choisi parmi des suggestions ou saisi librement |
| phone | String (téléphone direct) |
| mobile | String |
| email | String |
| notes | String |
| garage | Garage? |

Fonctions suggérées : Réception, Chef d'atelier, Mécanicien, Carrossier, Commercial, Comptabilité, Pièces détachées.

### Intervention (modifié)
- Nouveau : `garageRef: Garage?` (relation optionnelle).
- Conservé : `garage: String`, désormais **nom de réserve** (texte historique). Il n'est plus saisi directement.
- Nouveau calculé : `garageDisplayName: String` = `garageRef?.name` s'il existe, sinon `garage`.

Tous les nouveaux attributs ont une valeur par défaut ou sont optionnels : SwiftData applique une migration légère automatique (ajout d'entités et d'une relation optionnelle). Aucun schéma versionné n'est nécessaire.

## 3. Conversion des garages texte (GarageMigrator)

Exécutée au lancement, après l'ouverture de la base (et donc aussi après une restauration de sauvegarde, qui relance l'app).

- Pour chaque intervention avec `garageRef == nil`, `garageTextMigrated == false` et `garage` non vide après nettoyage :
  - clé de regroupement = nom sans espaces superflus (début, fin, multiples), insensible à la casse et aux accents ;
  - si un Garage existant a la même clé, on le relie ; sinon on crée un Garage dont le nom est la **première graphie rencontrée** (interventions triées par date croissante), nettoyée des espaces.
- Le texte `garage` de l'intervention n'est **jamais modifié** ; `garageTextMigrated` passe à vrai.
- Idempotente : une seconde exécution ne crée rien et ne change rien.
- Une seule sauvegarde du contexte à la fin ; en cas d'échec : annulation (rollback) et l'app continue avec les noms texte (message d'erreur non bloquant).

## 4. Règles de gestion

- **Suppression d'un garage** (après confirmation indiquant le nombre d'interventions liées) :
  - chaque intervention liée reçoit `garage = nom du garage` (pour garder l'historique) et `garageTextMigrated = true`, puis le lien est retiré ;
  - les contacts du garage sont supprimés ;
  - une seule sauvegarde, avec rollback en cas d'échec.
- **Renommer un garage** met à jour l'affichage de toutes ses interventions (via le lien).
- **Doublon de nom** à la création d'un garage : autorisé (deux agences peuvent porter le même nom), mais le formulaire affiche un avertissement non bloquant « Un garage porte déjà ce nom ».
- **Note** : 0 à 5 étoiles ; cliquer sur l'étoile déjà sélectionnée remet à 0.

## 5. Actions de contact (ContactLinks)

Fonctions pures, testées :
- `phoneURL("01 23 45 67 89")` → `tel:0123456789` (on garde chiffres et « + » initial) ; `nil` si aucun chiffre.
- `mailURL("a@b.fr")` → `mailto:a@b.fr` ; `nil` si pas de « @ ».
- `mapsURL(adresse)` → `https://maps.apple.com/?q=<adresse encodée>` ; `nil` si vide.
- `webURL("garage.fr")` → `https://garage.fr` (ajout de `https://` si aucun schéma) ; `nil` si vide.

Sur Mac, `tel:` passe par FaceTime / l'iPhone (Continuité) ; si aucun service ne répond, macOS affiche son propre message.

## 6. Interface

### Barre latérale
Nouvelle section **« Garages »** sous « Mes voitures » : nom, étoiles éventuelles, nombre de contacts. Bouton **+** (« Nouveau garage ») dans la section. Raccourci **⌥⌘N** « Nouveau garage » dans le menu Fichier.

### Colonne du milieu : fiche du garage
- En-tête : nom, étoiles cliquables, boutons **Modifier** et **Supprimer**.
- Carte **Coordonnées** : adresse, téléphone, e-mail, site, chacun avec son bouton d'action (Itinéraire, Appeler, Écrire, Site web) et clic droit « Copier ». Masqués si vides.
- Carte **Horaires**, carte **Spécialités**, carte **Avis** (masquées si vides).
- Carte **Contacts** : un contact par ligne (nom, fonction, numéros, e-mail) avec boutons appeler/écrire ; **+** pour ajouter, double-clic ou clic droit > Modifier, clic droit > Supprimer (confirmation), clic droit > Copier le numéro / l'e-mail.

### Colonne de droite : interventions du garage
Toutes voitures confondues, de la plus récente à la plus ancienne : avatar de la voiture, date, titre, montant, pastille devis/facture. En tête : nombre d'interventions et **total des factures** (devis exclus).

### Formulaire d'intervention
Le champ texte « Garage » est remplacé par un menu **Garage** : « Aucun » + garages triés par nom (sans tenir compte des accents ni de la casse). Bouton **« Nouveau garage… »** à côté : ouvre le formulaire garage ; à l'enregistrement, le nouveau garage est sélectionné. Si l'intervention n'a qu'un nom texte sans lien (cas non converti), le menu affiche « <nom> (texte) » en option désactivée et le texte est conservé tant qu'on ne choisit pas un garage.

### Formulaire garage
Nom (obligatoire), Adresse (multiligne), Téléphone, E-mail, Site web, Horaires (multiligne), Spécialités, Note (étoiles), Avis (multiligne).

### Formulaire contact
Nom (obligatoire), Fonction (champ texte avec menu de suggestions), Téléphone direct, Portable, E-mail, Notes.

### Ailleurs
`garageDisplayName` remplace `garage` dans : fiche détaillée de l'intervention, recherche de la liste des interventions, export CSV (colonne « Garage »).

## 7. Erreurs

Mêmes règles que la 1.0 : toute sauvegarde passe par `saveOrRollback` et les erreurs s'affichent dans l'alerte globale. Feuilles locales suivies par `.tracksSheetPresentation()`.

## 8. Tests

- GarageMigrator : regroupement casse / espaces / accents, première graphie conservée, texte d'origine intact, idempotence, interventions déjà liées ignorées, textes vides ignorés.
- Suppression de garage : nom recopié dans les interventions, lien retiré, contacts supprimés.
- `garageDisplayName` ; `rating` borné.
- ContactLinks : tous les cas du §5.
- CSV : colonne Garage issue du lien.
- Ouverture d'une base au schéma 1.0 (créée sans les nouvelles entités) puis migration légère et conversion.

## 9. Livraison

Version **1.1** (`MARKETING_VERSION`), nouvelle section « Garages » dans `docs/GUIDE.md`, DMG et release GitHub.

## Hors périmètre

Import depuis l'app Contacts de macOS, géolocalisation / carte intégrée, prise de rendez-vous.

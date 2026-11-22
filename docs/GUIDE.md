# Guide d'utilisation de SuiviAuto

SuiviAuto vous aide à suivre l'entretien de vos voitures sur Mac. Vous y rangez les factures et les devis, l'app calcule le prochain contrôle technique, estime le kilométrage et vous rappelle les vidanges, la courroie ou l'assurance avant qu'il soit trop tard.

*Créé par Guillaume LECOMTE.* Toutes vos données restent sur votre Mac : rien n'est envoyé sur Internet.

---

## Sommaire

1. [Installer SuiviAuto](#1-installer-suiviauto)
2. [Découvrir la fenêtre](#2-découvrir-la-fenêtre)
3. [Ajouter une voiture](#3-ajouter-une-voiture)
4. [Les interventions : entretiens, réparations, CT](#4-les-interventions--entretiens-réparations-ct)
5. [Factures et devis (documents)](#5-factures-et-devis-documents)
6. [Le kilométrage](#6-le-kilométrage)
7. [Les règles d'entretien](#7-les-règles-dentretien)
8. [Le contrôle technique](#8-le-contrôle-technique)
9. [Les échéances libres (assurance, pneus…)](#9-les-échéances-libres-assurance-pneus)
10. [Le tableau de bord](#10-le-tableau-de-bord)
11. [Les rappels (notifications)](#11-les-rappels-notifications)
12. [Sauvegarder, restaurer, exporter](#12-sauvegarder-restaurer-exporter)
13. [Raccourcis clavier](#13-raccourcis-clavier)
14. [Questions fréquentes et dépannage](#14-questions-fréquentes-et-dépannage)
15. [Signaler un problème, proposer une idée](#15-signaler-un-problème-proposer-une-idée)

---

## 1. Installer SuiviAuto

**Configuration requise :** un Mac sous **macOS 27** ou plus récent (Mac à puce Apple).

1. Téléchargez **SuiviAuto-x.y.dmg** sur la [page des versions](https://github.com/glecomte62/SuiviAuto/releases/latest).
2. Ouvrez le fichier `.dmg`, puis faites glisser l'icône **SuiviAuto** sur le dossier **Applications** à côté.
3. Éjectez le disque « SuiviAuto » (clic droit > Éjecter).

### Première ouverture

SuiviAuto est une app gratuite partagée entre amis : elle n'est pas enregistrée auprès d'Apple. Au premier lancement, macOS affiche un message du type *« Apple n'a pas pu vérifier… »* et refuse de l'ouvrir. C'est normal, il suffit de l'autoriser **une seule fois** :

1. Cliquez sur **OK** (ou **Terminé**) dans le message.
2. Ouvrez **Réglages Système > Confidentialité et sécurité**.
3. Dans la section **Sécurité**, une ligne indique que « SuiviAuto » a été bloquée : cliquez sur **Ouvrir quand même**.
4. Confirmez avec votre mot de passe ou Touch ID.

Ensuite, macOS vous demande si SuiviAuto peut afficher des **notifications** : acceptez, elles servent aux rappels.

### Mettre à jour

Téléchargez la nouvelle version et remplacez l'ancienne dans Applications. Vos données sont conservées : elles ne sont pas stockées dans l'app elle-même.

---

## 2. Découvrir la fenêtre

La fenêtre est divisée en **trois colonnes** :

| Colonne | Contenu |
|---|---|
| **À gauche** (barre latérale) | **Tableau de bord** en haut, puis **Mes voitures**. Chaque voiture a sa photo ou sa pastille de couleur. Une icône orange ⏰ ou rouge ⚠️ signale une échéance proche ou dépassée. Le bouton **+** ajoute une voiture. |
| **Au milieu** | Le contenu de la voiture choisie, réparti en onglets : **Interventions · Km · Règles · Échéances · Infos**. Pour le tableau de bord : la liste des prochaines échéances. |
| **À droite** (détail) | La fiche de l'intervention sélectionnée. Si aucune intervention n'est sélectionnée : le résumé de la voiture. Pour le tableau de bord : les graphiques. |

### Les couleurs des badges

Partout dans l'app, chaque échéance porte un badge :

| Badge | Signification |
|---|---|
| 🟢 **À jour** | Plus de 60 jours **et** plus de 1 000 km avant l'échéance. |
| 🟠 **Bientôt** | 60 jours ou moins, **ou** 1 000 km ou moins avant l'échéance. |
| 🔴 **Dépassé** | La date est passée **ou** le kilométrage estimé a dépassé le seuil. |

---

## 3. Ajouter une voiture

Cliquez sur **+** dans la barre latérale ou utilisez **⇧⌘N** (menu Fichier > Nouvelle voiture).

| Champ | Utilité |
|---|---|
| **Photo** | **Choisir une photo…** ou glissez une image sur le cercle. Elle est réduite automatiquement. **Retirer la photo** l'enlève. |
| **Couleur** | Couleur d'accent de la voiture dans toute l'app (pastille, graphiques). |
| **Nom** *(obligatoire)* | Comme vous l'appelez : « Clio de Marie », « Le Kangoo »… |
| **Marque, Modèle, Immatriculation, N° VIN** | Facultatifs, pour mémoire. L'immatriculation et le VIN sont mis en majuscules. |
| **1re immatriculation** *(obligatoire)* | Indispensable : elle sert à calculer le premier contrôle technique. Vous la trouvez sur la carte grise (case B). |
| **Carburant** | Pour mémoire. |
| **Achetée d'occasion** | À cocher si vous n'êtes pas le premier propriétaire. Indiquez la **Date d'achat** et le **Km à l'achat** (obligatoire dans ce cas). Les règles d'entretien jamais faites partiront alors de cet achat (voir [§ 7](#7-les-règles-dentretien)). |

Cliquez sur **Enregistrer**. La voiture apparaît dans la barre latérale.

> **Bon à savoir :** chaque nouvelle voiture reçoit trois **règles d'entretien** par défaut : vidange tous les 15 000 km ou 12 mois, courroie de distribution tous les 120 000 km ou 6 ans, liquide de frein tous les 2 ans. Vous pouvez les modifier ou les supprimer dans l'onglet **Règles**.

### Modifier ou supprimer une voiture

Onglet **Infos** de la voiture :
- **Modifier** rouvre le formulaire.
- **Supprimer la voiture** efface, après confirmation, la voiture **et tout son historique** : interventions, factures, relevés, règles et échéances. Pensez à [faire une sauvegarde](#12-sauvegarder-restaurer-exporter) avant.

---

## 4. Les interventions : entretiens, réparations, CT

Une intervention, c'est tout passage au garage ou opération sur la voiture : vidange, réparation, pneus, contrôle technique, carrosserie…

### Ajouter une intervention

Sélectionnez la voiture, puis **⌘N** (ou le bouton **+** de l'onglet **Interventions**).

| Champ | Utilité |
|---|---|
| **Type** | Entretien, Réparation, Contrôle technique, Pneus, Carrosserie ou Autre. |
| **Statut** | **Devis** ou **Facture** (voir ci-dessous). |
| **Titre** | Ex. « Vidange + filtres ». Si vide, le type est affiché. |
| **Date** | Date de l'intervention. |
| **Kilométrage** *(obligatoire)* | Le km au compteur ce jour-là. Le dernier km connu est rappelé en grisé. |
| **Garage** | Facultatif. |
| **Montant (€)** | Ex. `189,90`. Virgule ou point acceptés. |
| **Résultat du CT** | Apparaît seulement pour un contrôle technique : Favorable, Défavorable (contre-visite) ou Défaillance critique. |
| **Règle d'entretien** | Relie l'intervention à une règle (vidange, courroie…) pour que la prochaine échéance se recalcule. **Pensez-y pour chaque entretien périodique !** |
| **Notes** | Texte libre. |

> Si le kilométrage saisi est **inférieur** au dernier connu à cette date, l'app vous prévient. Vous pouvez **Corriger** ou **Enregistrer quand même** (utile en cas de changement de compteur).

### Devis ou facture ?

- Un **devis** est conservé avec ses documents, mais il **ne compte pas** : ni dans les dépenses, ni dans le kilométrage, ni pour le contrôle technique, ni pour les règles d'entretien.
- Quand les travaux sont faits, ouvrez le devis et cliquez sur **Transformer en facture** dans la barre d'outils. Tout est conservé, y compris les documents ; seul le statut change.

### Retrouver une intervention

- La liste est triée de la plus récente à la plus ancienne.
- Le champ de **recherche** (en haut) cherche dans le titre, le type, le garage et les notes.
- Le menu **Type** filtre la liste (« Tous les types » pour tout revoir).
- Un trombone 📎 indique qu'une intervention a des documents joints.

### Modifier ou supprimer

Sélectionnez l'intervention : sa fiche s'affiche à droite. Dans la barre d'outils :
- **Modifier** rouvre le formulaire.
- **Supprimer** efface l'intervention **et ses documents**, après confirmation.

---

## 5. Factures et devis (documents)

Chaque intervention peut contenir autant de documents que vous voulez : factures, devis, procès-verbal de CT, photos…

**Formats acceptés :** PDF, JPEG, PNG, HEIC (photos d'iPhone).

### Ajouter un document

Dans la fiche de l'intervention, carte **Factures et devis** :
- **Glissez** un ou plusieurs fichiers depuis le Finder, le Bureau ou Mail directement sur la fiche (un cadre pointillé apparaît), **ou**
- cliquez sur **Ajouter…** et choisissez les fichiers.

Le fichier est **copié** dans SuiviAuto : vous pouvez supprimer ou déplacer l'original sans rien perdre.

> **Astuce :** pour une facture papier, photographiez-la avec votre iPhone, puis envoyez la photo sur le Mac (AirDrop) et glissez-la dans la fiche.

### Consulter un document

- **Clic** sur la vignette pour la sélectionner, puis **barre d'espace** : aperçu rapide (Coup d'œil).
- **Double-clic** : ouvre le document dans l'application par défaut (Aperçu, en général).
- **Clic droit** : Coup d'œil, Ouvrir, **Afficher dans le Finder**, Supprimer.

Une vignette **« Fichier introuvable »** signifie que le fichier a disparu du dossier de SuiviAuto (voir [§ 14](#14-questions-fréquentes-et-dépannage)).

---

## 6. Le kilométrage

SuiviAuto **estime** le kilométrage actuel de chaque voiture, ce qui permet de prévoir les entretiens exprimés en km.

### D'où viennent les kilométrages ?

1. Les **relevés manuels** que vous saisissez (**⌘K**).
2. Le km de chaque **facture**.
3. Le **km à l'achat** pour une voiture d'occasion.

### Saisir un relevé

**⌘K** (ou **Nouveau relevé** dans l'onglet **Km**) : la date et le km au compteur. Faites-le de temps en temps, par exemple à chaque plein ou une fois par mois : l'estimation n'en sera que plus juste.

### L'onglet Km

- **Kilométrage estimé aujourd'hui** : le dernier km connu, prolongé selon votre rythme habituel.
- **Moyenne** : vos km par an.
- Une **courbe** d'évolution (dès 2 relevés).
- La liste des **Relevés manuels**, avec l'icône 🗑 pour en supprimer un.

> **Comment est calculée la moyenne ?** Sur les 12 derniers mois s'il y a au moins deux relevés sur cette période, sinon sur tout l'historique.

---

## 7. Les règles d'entretien

Une règle dit **tous les combien** il faut refaire une opération : « Vidange tous les 15 000 km ou 12 mois ». **La première limite atteinte** (km ou date) déclenche l'alerte.

### L'onglet Règles

Pour chaque règle : son intervalle, la **prochaine** échéance (date et/ou km) et son badge de couleur.

- **+** (barre d'outils) : nouvelle règle. Donnez un nom et au moins un intervalle (**Tous les … km** et/ou **Tous les … mois**).
- **Double-clic** sur une règle, ou clic droit > **Modifier**.
- Clic droit > **Supprimer** : une confirmation indique combien d'interventions y étaient rattachées ; elles sont conservées mais ne sont plus liées à cette règle.

### D'où part le calcul ?

1. De la **dernière facture** rattachée à cette règle (champ **Règle d'entretien** de l'intervention).
2. Sinon, de l'**achat** pour une voiture d'occasion (date et km d'achat).
3. Sinon, de la **1re immatriculation** à 0 km.

> **Important :** si vous ajoutez une voiture qui roule déjà, ses règles risquent d'être **🔴 Dépassé** au début. C'est normal : saisissez la dernière vidange (ou la dernière courroie…) comme une intervention **facture** en choisissant la bonne **Règle d'entretien**, et l'échéance se recalcule.

### Pour une règle en kilomètres

La date affichée est une **estimation** : SuiviAuto calcule quand vous atteindrez le km prévu à votre rythme habituel. Plus vos relevés sont réguliers, plus elle est juste.

---

## 8. Le contrôle technique

SuiviAuto calcule automatiquement la date du prochain contrôle technique selon les règles françaises :

| Situation | Prochain CT |
|---|---|
| Aucun CT enregistré | **4 ans** après la 1re immatriculation |
| Dernier CT **favorable** | **2 ans** après ce CT |
| Dernier CT **défavorable** | **Contre-visite** dans les **2 mois** |
| Contre-visite favorable (dans les 2 mois) | **2 ans** après le **CT initial** (pas après la contre-visite) |
| Contre-visite défavorable (dans les 2 mois) | L'échéance reste **2 mois après le CT initial** |
| **Défaillance critique** | Contre-visite dans les 2 mois, **et circulation interdite** dès le lendemain : l'échéance est marquée 🔴 |

**Pour l'enregistrer :** ajoutez une intervention de type **Contrôle technique**, au statut **Facture**, et choisissez le **Résultat du CT**. Joignez le procès-verbal en PDF : il sera toujours sous la main.

> Le CT est toujours calculé depuis la **1re immatriculation**, même pour une voiture d'occasion : c'est la règle légale.

---

## 9. Les échéances libres (assurance, pneus…)

Pour tout ce qui a une date mais n'est pas un entretien : assurance, fin de garantie, pose des pneus hiver, vignette, abonnement…

Onglet **Échéances** > **+** :
- **Libellé** : ex. « Assurance ».
- **Date**.
- **Se répète chaque année** : à cocher pour l'assurance, les pneus hiver…
- **Notes** : ex. n° de contrat.

Quand c'est fait, cliquez sur **Fait ✓** :
- échéance **annuelle** (**Fait ✓ (+1 an)**) : la date avance d'un an ;
- échéance **ponctuelle** : elle est supprimée, après confirmation.

**Double-clic** ou clic droit > **Modifier** pour la changer ; clic droit > **Supprimer** pour l'effacer.

---

## 10. Le tableau de bord

Cliquez sur **Tableau de bord** en haut de la barre latérale.

- **Au milieu :** toutes les prochaines échéances de toutes vos voitures (CT, règles, échéances libres), triées par date, en deux groupes : **À surveiller** (🟠 et 🔴) et **Plus tard** (🟢).
- **À droite :**
  - trois tuiles : **Dépenses** de l'année, nombre de **Voitures**, nombre d'échéances **À surveiller** ;
  - **Kilométrage** : le km estimé de chaque voiture et une courbe par voiture, dans sa couleur ;
  - **Dépenses par année** : un histogramme empilé par voiture. Seules les **factures avec un montant** comptent (pas les devis).

Le **résumé d'une voiture** (colonne de droite quand aucune intervention n'est sélectionnée) montre la même chose pour elle seule : km estimé, dépenses de l'année et toutes ses échéances.

---

## 11. Les rappels (notifications)

SuiviAuto vous prévient **30 jours** puis **7 jours** avant chaque échéance datée, à **9 h** du matin : contrôle technique, règles d'entretien, échéances libres. Pour les règles en kilomètres, c'est la date **estimée** qui sert.

Les rappels sont recalculés à chaque modification, et à chaque ouverture de l'app.

**Je ne reçois pas de rappels ?**
1. Ouvrez **Réglages Système > Notifications > SuiviAuto** et vérifiez que **Autoriser les notifications** est activé.
2. Vérifiez que le mode **Concentration** (Ne pas déranger) ne les masque pas.
3. Ouvrez SuiviAuto au moins une fois après avoir saisi vos données : c'est à ce moment que les rappels sont programmés.

---

## 12. Sauvegarder, restaurer, exporter

Vos données (base et documents) sont dans `~/Library/Application Support/SuiviAuto/`. **Time Machine** les sauvegarde automatiquement. Vous pouvez aussi faire des sauvegardes manuelles, par exemple avant de changer de Mac.

### Exporter une sauvegarde

Menu **Fichier > Exporter une sauvegarde…** : un fichier `.zip` contenant **toutes** vos voitures, interventions, photos et documents. Rangez-le en lieu sûr (clé USB, iCloud Drive…).

### Importer une sauvegarde

Menu **Fichier > Importer une sauvegarde…**, choisissez le `.zip`, puis confirmez **Remplacer et redémarrer**.

- Les données actuelles sont **remplacées** par celles de la sauvegarde. L'app redémarre toute seule.
- Par sécurité, vos données d'avant sont **conservées** dans un dossier `SuiviAuto-avant-restauration-<date>` (dans `~/Library/Application Support/`). Vous pourrez le supprimer quand tout vous semble correct.
- Une sauvegarde abîmée ou qui ne vient pas de SuiviAuto est refusée, sans toucher à vos données.

### Exporter l'historique en CSV

Menu **Fichier > Exporter l'historique en CSV…** : un tableau (voiture, date, km, type, titre, garage, montant, statut) qui s'ouvre directement dans **Excel** ou **Numbers**.

### Changer de Mac

1. Sur l'ancien Mac : **Exporter une sauvegarde…**
2. Installez SuiviAuto sur le nouveau Mac.
3. Sur le nouveau Mac : **Importer une sauvegarde…**

---

## 13. Raccourcis clavier

| Raccourci | Action |
|---|---|
| **⇧⌘N** | Nouvelle voiture |
| **⌘N** | Nouvelle intervention (voiture sélectionnée) |
| **⌘K** | Nouveau relevé kilométrique (voiture sélectionnée) |
| **Espace** | Coup d'œil sur le document sélectionné |
| **Double-clic** | Ouvrir un document · modifier une règle ou une échéance |
| **Entrée** | Enregistrer un formulaire |
| **Échap** | Annuler un formulaire |
| **⌘?** | Ouvrir cette aide |
| **⌘Q** | Quitter |

---

## 14. Questions fréquentes et dépannage

**Toutes les échéances de ma voiture sont rouges juste après l'avoir ajoutée.**
C'est normal pour une voiture qui roule déjà : l'app ne connaît pas encore son historique. Saisissez le **dernier contrôle technique** et les **derniers entretiens** (en factures, avec la bonne **Règle d'entretien**). Si vous l'avez achetée d'occasion, cochez **Achetée d'occasion** dans l'onglet **Infos > Modifier**.

**« Sélectionnez d'abord une voiture dans la barre latérale. »**
⌘N et ⌘K ajoutent une intervention ou un relevé à la voiture sélectionnée : cliquez d'abord sur une voiture.

**Le bouton Enregistrer est grisé.**
Un champ obligatoire est vide ou mal rempli : le kilométrage (chiffres uniquement), le nom de la voiture, le km à l'achat pour une voiture d'occasion, ou au moins un intervalle pour une règle.

**« Montant invalide ».**
Écrivez le montant avec au plus deux décimales, par exemple `189,90` ou `1 250`.

**Un document n'est pas importé.**
Seuls les PDF, JPEG, PNG et HEIC sont acceptés. Un document Word (`.docx`) peut être enregistré en PDF depuis Word ou Pages (Fichier > Exporter en PDF).

**Une vignette affiche « Fichier introuvable ».**
Le fichier a été supprimé du dossier `~/Library/Application Support/SuiviAuto/Documents/`. Restaurez-le depuis Time Machine ou une sauvegarde, ou supprimez la vignette (clic droit > Supprimer) et rajoutez le document.

**L'estimation du kilométrage me semble fausse.**
Elle dépend de vos relevés. Ajoutez un relevé récent (**⌘K**) avec le km exact au compteur ; supprimez dans l'onglet **Km** un relevé saisi par erreur.

**L'app ne s'ouvre pas : « Apple n'a pas pu vérifier… ».**
Voir [Première ouverture](#première-ouverture).

**L'app affiche « Impossible d'ouvrir la base de données ».**
Le message indique où se trouve la base et, s'il en existe une, la copie de vos données précédentes. Signalez le problème (voir ci-dessous) en joignant ce message : ne supprimez rien.

**Désinstaller SuiviAuto.**
Mettez l'app à la corbeille depuis Applications. Pour effacer aussi vos données (définitivement !), supprimez le dossier `~/Library/Application Support/SuiviAuto/`. Pour y accéder : dans le Finder, menu **Aller > Aller au dossier…** (⇧⌘G) et collez ce chemin.

---

## 15. Signaler un problème, proposer une idée

Rendez-vous sur la [page de suivi](https://github.com/glecomte62/SuiviAuto/issues/new/choose) (menu **Aide > Signaler un problème ou proposer une idée…** dans l'app) et choisissez **Signaler un problème** ou **Proposer une idée**.

⚠️ Cette page est **publique** : n'y mettez pas d'informations personnelles (immatriculation, VIN, adresse…), et masquez-les sur vos captures d'écran.

---

*SuiviAuto — créé par Guillaume LECOMTE.*

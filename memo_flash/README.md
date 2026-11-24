# Mémo Flash ⚡

Application Android **personnelle** (Flutter) de cartes mémoire (flashcards) à **répétition espacée**, dans l'esprit d'Anki : tu crées des cartes recto/verso, tu les révises chaque jour, et l'appli te représente chaque carte juste avant que tu l'oublies.

- **Hors-ligne, zéro frais** : tout est stocké dans la base SQLite du téléphone. Aucun compte, aucun serveur, aucune connexion réseau.
- **Paquets** de cartes : créer, renommer, rechercher, supprimer, recommencer à zéro.
- **Ajout en rafale** : l'écran reste ouvert après chaque carte, avec l'option de créer aussi la **carte inverse** (verso → recto).
- **Import** d'une liste collée (`recto ; verso`, `recto = verso`, ou deux colonnes copiées depuis un tableur ou un export texte d'Anki) et **export** au même format.
- **Révision façon Anki** : quatre boutons *À revoir*, *Difficile*, *Correct* et *Facile*, chacun affichant le délai avant le prochain passage. Le bouton ↶ annule la dernière réponse.
- **Statistiques** : révisions du jour, taux de réussite, série de jours, historique sur 14 jours, prévisions sur 7 jours.
- **Sauvegarde complète** (paquets, cartes, progression) copiée dans le presse-papiers, et restauration.
- Thème clair, sombre ou celui du système.

## Comment l'appli choisit quand te remontrer une carte

L'algorithme est celui d'Anki (SM-2), avec les mêmes réglages par défaut :

| État de la carte | À revoir | Difficile | Correct | Facile |
|---|---|---|---|---|
| Nouvelle (étapes 1 min puis 10 min) | 1 min | 6 min | 10 min, puis 1 jour | 4 jours |
| Apprise (intervalle *I*, facilité *F* = 250 % au départ) | 10 min (oubli, *F* − 20 %) | *I* × 1,2 (*F* − 15 %) | *I* × *F* | *I* × *F* × 1,3 (*F* + 15 %) |

- Une « journée » de révision commence à **4 h du matin** : réviser à 1 h compte encore pour la veille.
- Un petit aléa (± 5 %) étale les cartes ajoutées ensemble, pour qu'elles ne reviennent pas toutes le même jour.
- Par défaut, **20 nouvelles cartes** et **200 révisions** au maximum par jour et par paquet (modifiable dans Réglages).
- Compteurs en couleur : **bleu** = nouvelles, **rouge** = en apprentissage, **vert** = à réviser.

## Installer l'APK sur le téléphone

1. Sur le téléphone, ouvre GitHub dans le navigateur et **connecte-toi** : le dépôt est privé, il faut donc être connecté pour télécharger.
2. Va dans le dépôt → **Releases** → **latest** → télécharge `memo-flash.apk`.
3. Autorise ce navigateur à **installer des applications inconnues** quand Android le demande.
4. HyperOS peut afficher un avertissement de sécurité pour un APK hors Play Store : c'est normal, continue l'installation.

## Mettre à jour

Chaque push sur `main` déclenche GitHub Actions (`.github/workflows/build-apk.yml`), qui analyse le code, lance les tests, compile un APK arm64 signé et remplace la Release `latest`. Il faut compter **5 à 8 minutes**. Retélécharge ensuite `memo-flash.apk` et installe-le **par-dessus** l'ancien : tes cartes sont conservées, parce que la signature ne change pas et que le numéro de build augmente à chaque exécution.

Un lancement manuel du workflow (onglet **Actions** → *Run workflow*) sur une autre branche compile et teste sans rien publier.

## Signature : configuration unique

La CI a besoin de 4 **secrets** du dépôt (**Settings → Secrets and variables → Actions → New repository secret**) :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | le fichier `upload-keystore.jks` encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | alias de la clé (par exemple `upload`) |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |

**Tu peux réutiliser exactement la même clé que pour Frigo Malin** : recopie les 4 mêmes valeurs. Deux applis différentes peuvent partager une clé de signature.

Pour créer une nouvelle clé, sur un ordinateur où Java est installé :

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

```bash
base64 -w0 upload-keystore.jks
```

La seconde commande affiche la valeur à coller dans `ANDROID_KEYSTORE_BASE64`.

Sans ces secrets, la CI compile quand même mais **ne publie pas** : l'APK est seulement disponible comme artefact du workflow, signé avec une clé de debug. Garde une copie du `.jks` et des mots de passe dans un gestionnaire de mots de passe. **Si tu les perds**, il faudra désinstaller l'appli (et donc perdre les données, sauf sauvegarde) pour installer une version signée avec une nouvelle clé. Ces fichiers ne doivent jamais être committés : le `.gitignore` les exclut.

## Sauvegarder ses cartes

Les données ne quittent jamais le téléphone. Avant de changer de téléphone ou de désinstaller l'appli :

1. **Réglages → Copier une sauvegarde complète** : tout est copié dans le presse-papiers sous forme de texte.
2. Colle ce texte dans une note, un e-mail ou un fichier.
3. Sur le nouveau téléphone, copie ce texte puis **Réglages → Restaurer depuis le presse-papiers**.

Pour un seul paquet, utilise le menu ⋮ du paquet → **Copier toutes les cartes**. Ce format texte se réimporte ici comme dans Anki, mais sans la progression.

## Développement

```bash
flutter pub get
flutter analyze   # doit être sans aucun message (la CI échoue sinon)
flutter test      # les tests de base utilisent sqflite_common_ffi (libsqlite3 requis)
flutter run
```

Structure :

- `lib/services/planificateur.dart` : l'algorithme de répétition espacée (fonctions pures, très testées).
- `lib/db/base_donnees.dart` : SQLite (paquets, cartes, journal des révisions, réglages), file de révision, limites quotidiennes, statistiques, sauvegarde.
- `lib/services/import_texte.dart` : lecture et écriture du format texte.
- `lib/screens/` : écrans (paquets, détail d'un paquet, éditeur, import, révision, statistiques, réglages).
- `lib/theme.dart` : couleurs, thèmes et petits composants partagés.

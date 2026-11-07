# Frigo Malin — notes pour les sessions futures

Appli Android personnelle (Flutter), cible unique : Xiaomi 17 Ultra (HyperOS 3 / Android 16, arm64). Interface, commentaires et README en **français avec accents**.

## Architecture

- `lib/main.dart` : démarrage, locale fr_FR, coque à 3 onglets (IndexedStack), cycle de vie.
- `lib/theme.dart` : **seule source de vérité** des couleurs d'urgence (`Urgence`), libellés, thèmes clair/sombre, widget `CarteApp`.
- `lib/models/` : `Produit` (+ `normaliser`, dates ISO), `Recette`, `CatalogueItem`.
- `lib/db/base_donnees.dart` : SQLite (sqflite), suppression logique, historique, lectures/écritures de synchro. `BaseDonnees.version` est incrémenté à chaque écriture, les écrans l'écoutent.
- `lib/data/` : `recettes.dart` (30 recettes), `durees.dart` (durées indicatives).
- `lib/services/` : moteur de suggestions, notifications, réglages (SharedPreferences), catalogue (Open * Facts), synchro (`SyncBackend` abstrait + `SyncGoogleSheets` + `SyncService`).
- `lib/screens/`, `lib/widgets/` : UI.
- `apps_script/Code.gs` : script Google déployé à la main par l'utilisateur.

## Commandes

```bash
flutter analyze   # doit être sans aucun message (la CI échoue sinon)
flutter test
flutter run
```

## Règles clés

- Dates de péremption/ajout en **texte ISO `AAAA-MM-JJ`**, jamais en timestamp ; `joursRestants` se calcule sur des dates sans heure.
- `updated_at` : UTC ISO-8601 avec millisecondes (`maintenantUtcIso()`).
- **Pas de `ThemeData.cardTheme`** : utiliser `CarteApp`.
- **versionCode = `--build-number=${{ github.run_number }}`** dans la CI ; ne jamais le figer.
- **Offline-first** : le réseau ne doit jamais bloquer ni faire planter l'appli ; erreurs de synchro silencieuses (ligne d'état dans Réglages).
- **URL et jeton de synchro jamais dans le dépôt** ni dans les logs.
- **Ne jamais committer** keystore, `key.properties`, mots de passe.
- Permission `INTERNET` indispensable dans le manifeste principal.
- Alarmes exactes (`USE_EXACT_ALARM`), repli inexact sur `exact_alarms_not_permitted`.

## Livraison

Push sur `main` → GitHub Actions (`.github/workflows/build-apk.yml`) : analyse, tests, build APK arm64 signé, publication dans la Release `latest` (`frigo-malin.apk`). Sans les 4 secrets de signature, la CI compile mais ne publie pas (APK en artefact seulement).

Secrets attendus : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

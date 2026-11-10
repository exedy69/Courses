# Frigo Malin — notes pour les sessions futures

Appli Android personnelle (Flutter), cible unique : Xiaomi 17 Ultra (HyperOS 3 / Android 16, arm64). Interface, commentaires et README en **français avec accents**.

## Architecture

- `lib/main.dart` : démarrage, locale fr_FR, coque à 4 onglets (Mon stock, Repas, Courses, Réglages ; IndexedStack), cycle de vie.
- `lib/theme.dart` : **seule source de vérité** des couleurs d'urgence (`Urgence`), libellés, thèmes clair/sombre, widget `CarteApp`.
- `lib/models/` : `Produit` (+ `normaliser`, dates ISO), `Recette`, `CatalogueItem`.
- `lib/db/base_donnees.dart` : SQLite (sqflite), schéma versionné (`versionSchema`, `migrerSchema`), suppression logique, historique, liste de courses, synchro générique décrite par `tablesSync`. `BaseDonnees.version` est incrémenté à chaque écriture, les écrans l'écoutent.
- `lib/data/` : `recettes.dart` (30 recettes), `durees.dart` (durées indicatives).
- `lib/services/` : moteur de suggestions, notifications, réglages (SharedPreferences ; jeton dans `flutter_secure_storage`), catalogue (Open * Facts), synchro (`SyncBackend` abstrait + `SyncGoogleSheets` + `SyncService`).
- `lib/screens/`, `lib/widgets/` : UI.
- `apps_script/Code.gs` : script Google déployé à la main par l'utilisateur ; `apps_script/test_code_gs.js` le teste avec un faux Google Sheets.

## Commandes

```bash
flutter analyze   # doit être sans aucun message (la CI échoue sinon)
flutter test      # les tests de base utilisent sqflite_common_ffi (libsqlite3 requis)
node apps_script/test_code_gs.js apps_script/Code.gs
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

## Synchro (protocole v2)

- Chaque ligne locale a un drapeau `sale` (1 = à envoyer). Toute écriture locale le remet à 1 ; une ligne reçue le met à 0.
- Le serveur numérote chaque écriture acceptée (colonne `seq`). Le téléphone mémorise un **curseur** et demande « seq > curseur ». Ne jamais revenir à une comparaison d'heures entre téléphone et serveur : elle perd des changements à deux.
- Conflits : dernière écriture gagne sur `updated_at`.
- Synchro légère toutes les 20 s au premier plan ; passage `complet` au démarrage, au retour au premier plan et à la demande.
- Toute modification de `Code.gs` ou d'une colonne synchronisée doit être répercutée dans `tablesSync`, `Code.gs`, les tests, et le README (l'utilisateur doit redéployer le script).
- Les textes libres passent par `neutraliserFormule` (injection de formules dans le Sheet).
- Changer le schéma SQLite : incrémenter `versionSchema` et compléter `migrerSchema` (+ test de migration).

## Livraison

Push sur `main` → GitHub Actions (`.github/workflows/build-apk.yml`) : analyse, tests, build APK arm64 signé, publication dans la Release `latest` (`frigo-malin.apk`). Un lancement manuel sur une autre branche compile et teste sans publier. Les actions sont épinglées par commit et les secrets limités à l'étape de signature. Sans les 4 secrets de signature, la CI compile mais ne publie pas (APK en artefact seulement).

Secrets attendus : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

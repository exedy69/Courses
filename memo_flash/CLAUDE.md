# Mémo Flash — notes pour les sessions futures

Appli Android personnelle (Flutter) de flashcards à répétition espacée, façon Anki. Cible : Xiaomi 17 Ultra (HyperOS 3 / Android 16, arm64). Interface, commentaires et README en **français avec accents**.

## Architecture

- `lib/main.dart` : démarrage, locale fr_FR, coque à 3 onglets (Paquets, Statistiques, Réglages ; IndexedStack).
- `lib/theme.dart` : couleurs des compteurs et des boutons, thèmes, `modeTheme`, dialogues partagés.
- `lib/models/` : `Carte` (+ `EtatCarte`), `Paquet`, `Compteurs`.
- `lib/services/planificateur.dart` : SM-2 façon Anki, **fonctions pures** (heure passée en paramètre, aléa injectable). Journée de révision qui commence à 4 h (`numeroJour`, `debutJour`).
- `lib/db/base_donnees.dart` : SQLite (sqflite), `versionSchema` / `migrerSchema`, file de révision (`prochaineCarte`), limites quotidiennes, journal `revisions`, réglages clé/valeur, sauvegarde JSON. `BaseDonnees.version` est incrémenté à chaque écriture, les écrans l'écoutent.
- `lib/services/import_texte.dart` : import/export texte (tabulation, `;`, `=`).

## Commandes

```bash
flutter analyze   # doit être sans aucun message (la CI échoue sinon)
flutter test
```

## Règles clés

- Flutter ≥ 3.47 : importer `package:material_ui/material_ui.dart`, **pas** `package:flutter/material.dart` (déprécié, l'analyse échouerait). La CI fige la version de Flutter (`flutter-version`) ; la mettre à jour volontairement.
- Échéances en millisecondes depuis l'époque. Carte en révision : échéance = 4 h du matin du jour prévu, donc « échue » ⇔ `echeance <= maintenant` pour tous les états.
- Ne pas lire l'horloge dans le planificateur : passer `maintenant`.
- Hors-ligne, aucune permission réseau, aucun service payant.
- **versionCode = `--build-number=${{ github.run_number }}`** dans la CI ; ne jamais le figer.
- **Ne jamais committer** keystore, `key.properties`, mots de passe.
- Changer le schéma SQLite : incrémenter `versionSchema`, compléter `migrerSchema`, ajouter un test de migration, et garder `restaurerTout` compatible avec les anciennes sauvegardes.

## Livraison

Push sur `main` → `.github/workflows/build-apk.yml` : analyse, tests, APK arm64 signé, Release `latest` (`memo-flash.apk`). Secrets : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Sans eux : APK en artefact seulement.

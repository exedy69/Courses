# Frigo Malin 🥕

Application Android **personnelle** (Flutter) pour suivre les dates de péremption de son frigo, être prévenu avant qu'il ne soit trop tard et trouver un repas anti-gaspi avec ce qu'on a vraiment en stock.

- **Hors-ligne d'abord** : la base SQLite du téléphone est la source de vérité.
- **Zéro frais** : aucune clé d'API, aucun serveur payant.
- **Scan** des codes-barres en « mode rafale » ; le nom du produit est retrouvé via Open Food Facts, Open Beauty Facts et Open Products Facts (gratuits, sans clé), puis mémorisé.
- **Rappels** quotidiens, de courses et anti-oubli.
- **Suggestions de repas** : 30 recettes, classées selon l'urgence des produits.
- **Synchronisation facultative** vers un Google Sheet gratuit.

## Installer l'APK sur le Xiaomi

1. Sur le téléphone, ouvre GitHub dans le navigateur, connecté à ton compte.
2. Va dans **Releases** → **latest** → télécharge `frigo-malin.apk`.
3. Autorise ce navigateur à **installer des applications inconnues** quand Android le demande.
4. HyperOS peut afficher un avertissement de sécurité pour un APK hors Play Store : c'est normal, continue l'installation.

## Mettre à jour

Modifie le code, commit, push sur `main`, attends la fin du workflow GitHub Actions (environ 5 à 8 minutes), retélécharge l'APK de la Release `latest` et installe-le **par-dessus** : tes données sont conservées parce que la signature est stable et que le numéro de build augmente à chaque exécution.

## Signature : à sauvegarder absolument

La clé de signature est dans les **secrets GitHub** (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). Garde aussi une copie du fichier `upload-keystore.jks` et des mots de passe dans un gestionnaire de mots de passe. **Si tu les perds**, il faudra désinstaller l'appli (et donc perdre les données locales) pour pouvoir installer une version signée avec une nouvelle clé. Ces fichiers ne doivent jamais être committés (le `.gitignore` les exclut).

## Synchronisation Google Sheets (facultative, ≈ 10 minutes)

1. Crée un nouveau **Google Sheet** (nom libre).
2. Menu **Extensions → Apps Script**. Supprime le code d'exemple et colle le contenu de [`apps_script/Code.gs`](apps_script/Code.gs). Enregistre.
3. **Paramètres du projet** (roue dentée) → **Propriétés du script** → ajoute `TOKEN` avec une valeur aléatoire longue (30 caractères ou plus).
4. **Déployer → Nouveau déploiement → Application Web** : *Exécuter en tant que* : **Moi** ; *Qui a accès* : **Tout le monde**. Autorise les accès demandés, puis copie l'**URL** qui se termine par `/exec`.
5. Dans l'appli : **Réglages → Synchronisation Google Sheets** : colle l'URL et le jeton, appuie sur **Tester la connexion**, puis active **Synchroniser**.

Les onglets « Stock », « Catalogue » et « Historique » sont créés automatiquement. Tu peux corriger une ligne à la main dans le Sheet : sa date de modification est mise à jour et la correction arrive sur le téléphone à la prochaine synchro. Les photos ne sont jamais envoyées.

> ⚠️ Toute personne qui possède l'URL **et** le jeton peut lire et écrire ton Sheet : ne les partage pas. Ils sont saisis dans l'appli et ne sont jamais dans ce dépôt.

Après une modification de `Code.gs`, il faut créer un **nouveau déploiement** (ou « Gérer les déploiements » → modifier → nouvelle version) pour qu'elle soit prise en compte.

## Fiabilité des rappels sur Xiaomi (HyperOS)

HyperOS arrête agressivement les applis en arrière-plan. Dans **Réglages → Fiabilité des rappels (Xiaomi)** de l'appli, vérifie une fois :

- [ ] Démarrage automatique autorisé pour Frigo Malin.
- [ ] Économiseur de batterie de l'appli sur « Aucune restriction ».
- [ ] Appli verrouillée dans les applications récentes.
- [ ] Notifications autorisées, y compris sur l'écran de verrouillage et en bannière.
- [ ] Bouton **Envoyer une notification de test dans 1 minute** : ferme l'appli et vérifie qu'elle arrive.

Les intitulés exacts varient selon la version du système.

## Personnaliser

- **Ajouter une recette** : dans [`lib/data/recettes.dart`](lib/data/recettes.dart), copie un bloc `Recette(...)` : titre, ingrédients (mots-clés simples, sans quantités), basiques supposés présents, instructions, minutes.
- **Ajouter une durée de conservation** : dans [`lib/data/durees.dart`](lib/data/durees.dart), ajoute une ligne à `dureesParNom` (nom sans accent, au singulier, durée en jours).

## Développement

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Voir [`CLAUDE.md`](CLAUDE.md) pour l'architecture et les règles du projet.

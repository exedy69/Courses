# Frigo Malin 🥕

Application Android **personnelle** (Flutter) pour suivre les dates de péremption de son frigo, être prévenu avant qu'il ne soit trop tard et trouver un repas anti-gaspi avec ce qu'on a vraiment en stock.

- **Hors-ligne d'abord** : la base SQLite du téléphone est la source de vérité.
- **Zéro frais** : aucune clé d'API, aucun serveur payant.
- **Scan** des codes-barres en « mode rafale » ; le nom du produit est retrouvé via Open Food Facts, Open Beauty Facts et Open Products Facts (gratuits, sans clé), puis mémorisé.
- **Rappels** quotidiens, de courses et anti-oubli.
- **Suggestions de repas** : 30 recettes, classées selon l'urgence des produits.
- **Liste de courses** partagée, alimentée par les ingrédients manquants des recettes.
- **Synchronisation facultative** vers un Google Sheet gratuit, utilisable **à deux** : appli ouverte, les changements de l'autre téléphone arrivent en 20 secondes environ.

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
3. **Paramètres du projet** (roue dentée) → **Propriétés du script** → ajoute `TOKEN` avec une valeur aléatoire longue (**32 caractères ou plus** ; en dessous de 16, le script refuse tout).
4. **Déployer → Nouveau déploiement → Application Web** : *Exécuter en tant que* : **Moi** ; *Qui a accès* : **Tout le monde**. Autorise les accès demandés, puis copie l'**URL** qui se termine par `/exec`.
5. Dans l'appli : **Réglages → Synchronisation Google Sheets** : colle l'URL et le jeton, appuie sur **Tester la connexion**, puis active **Synchroniser**.

Les onglets « Stock », « Catalogue », « Historique » et « Courses » sont créés automatiquement. Tu peux corriger une ligne à la main dans le Sheet : la correction arrive sur les téléphones à la synchro suivante. Ne touche pas à la colonne `seq` (numéro d'écriture géré par le script). Les photos ne sont jamais envoyées.

> ⚠️ Toute personne qui possède l'URL **et** le jeton peut lire et écrire ton Sheet : ne les partage qu'avec la personne qui utilise le frigo avec toi. Ils sont saisis dans l'appli (le jeton est gardé dans le stockage chiffré d'Android) et ne sont jamais dans ce dépôt.

**Après chaque mise à jour de `Code.gs`** : recolle le fichier, puis **Déployer → Gérer les déploiements → Modifier (crayon) → Version : Nouvelle version → Déployer**. L'URL ne change pas. Si l'appli affiche « Script Google trop ancien », c'est cette étape qui manque.

### Utiliser l'appli à deux

1. Installe le même APK sur le second téléphone (téléphone arm64, soit presque tous les modèles récents).
2. Sur le premier téléphone : **Réglages → Partager (QR)**. Sur le second : **Réglages → Scanner un QR**. L'URL et le jeton sont remplis et la synchro démarre.
3. Chacun peut saisir son prénom dans Réglages : il s'affiche à côté des produits et des articles qu'il ajoute.

Fonctionnement : chaque téléphone garde ses données et fonctionne sans réseau. Appli ouverte, une synchro légère part toutes les 20 secondes et après chaque enregistrement. Appli fermée, rien n'est reçu : les changements arrivent à l'ouverture. Si vous modifiez le même produit au même moment, la dernière modification l'emporte.

Les lignes supprimées et l'historique de plus de 90 jours sont effacés du téléphone et du Sheet.

### Changement de téléphone

L'appli est exclue des sauvegardes Android (pour que le jeton et la base ne partent pas dans le cloud). Pour retrouver tes données sur un nouveau téléphone, active la synchro avant de changer : le nouveau téléphone récupère tout depuis le Sheet. Les photos, elles, ne sont pas transférées.

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
flutter test                                              # nécessite libsqlite3 (paquet libsqlite3-dev sous Linux)
node apps_script/test_code_gs.js apps_script/Code.gs      # test du script Google
flutter run
```

Voir [`CLAUDE.md`](CLAUDE.md) pour l'architecture et les règles du projet.

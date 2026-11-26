# Atelier schémas

Application de bureau (Python + PySide6) pour apprendre à lire un schéma de
carte mère Mac, en préparation au dépannage de MacBook.

> Les schémas de l'appli sont **pédagogiques et inventés**. Ils reprennent
> l'architecture et les conventions de nommage Apple (PPBUS_G3H, rails
> `_S5`/`_S0`, signaux actifs bas en `_L`…) mais ne copient aucun schéma ni
> boardview réel.

## Ce qui est jouable

| Niveau | Contenu | État |
|---|---|---|
| Cours · Analyser avant de réparer | 7 chapitres à lire : pourquoi une méthode, questionner et inspecter, observer la consommation (ampèremètre USB-C), suivre la chaîne d'alimentation (premier rail absent, entrée → EN → sortie → PGOOD, exemple illustré sur schéma), mesurer correctement (tension, mode diode), localiser le fautif (injection de tension), réparer et vérifier | ✅ 17 cartes de quiz |
| 1. Symboles et lecture de base | 17 symboles (résistance, condensateurs, diodes, MOSFET N/P, bobine, fusible, quartz, connecteur, CI…), lettres de référence (R, C, L, D, Q, U, F, J, Y, TP), repérage sur schéma | ✅ 50 cartes |
| 2. Conventions des schémas Mac | Préfixe PP, lecture des tensions (PP3V3 → 3,3 V), suffixes G3H/S5/S3/S0, `_L` et `#`, `_EN`, `_PGOOD`, `PM_`, renvois de pages, NOSTUFF, XW, valeurs de composants, clics sur les nets d'un schéma | ✅ 42 cartes |
| 3. Suivre un chemin | — | bientôt |
| 4. Chaîne d'alimentation | Nouveau schéma « entrée de charge » (connecteur, fusible, MOSFET d'isolation, chargeur, batterie, PPBUS_G3H, LDO PP3V42_G3H du SMC), rôle du chargeur, ACOK, RSMRST, SLP_S4/S3, ALL_SYS_PWRGD, PLTRST#, exercices « remets dans l'ordre » de la séquence d'allumage | ✅ 28 cartes |
| 5. Diagnostic (panne simulée, multimètre) | — | bientôt |

Fonctionnement :

- **Sessions de 12 questions**, chrono de 20 s par question (la barre passe au
  rouge sous 5 s). Touches `1` à `4` pour répondre, `Entrée` pour continuer.
- Quatre sortes de questions : symbole affiché → nom ; nom → choisir le
  symbole ; **schéma interactif** où l'on clique un composant ou un net (survol
  en bleu, correction en vert/rouge) ; **remets dans l'ordre** (séquence
  d'allumage, chemin du courant), avec 60 s au lieu de 20.
- Sur les schémas, une croix grise marque une broche non connectée (NC).
- Chaque réponse est corrigée avec une explication.
- **Répétition espacée** (boîtes de Leitner) : juste et rapide → la carte monte
  d'une boîte (revue après 1, 3, 7 puis 21 jours) ; juste mais lent (plus de la
  moitié du temps accordé) →
  elle reste dans sa boîte ; faux → retour en boîte 1, à revoir le jour même.
  Le bouton « Révision du jour » ne propose que les cartes dues.
- Progression enregistrée en SQLite dans le dossier de données de
  l'utilisateur (`~/.local/share/atelier_schemas/` sous Linux,
  `~/Library/Application Support/atelier_schemas/` sous macOS).

## Lancer

```bash
cd atelier_schemas
python3 -m venv .venv
source .venv/bin/activate        # Windows : .venv\Scripts\activate
pip install -r requirements.txt
python -m atelier
```

Variable facultative : `ATELIER_DB=/chemin/progression.db` pour utiliser un
autre fichier de progression.

## Tests

```bash
cd atelier_schemas
QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests -t .
```

Les tests vérifient les symboles (SVG valides), la cohérence des questions,
la géométrie des schémas (chaque borne de composant est raccordée à un net,
fils orthogonaux, jonctions sur leur net), le moteur de quiz, la répétition
espacée, et l'interface en mode hors écran (sessions complètes, clics sur le
schéma).

## Organisation

```
atelier/
  symboles.py    symboles SVG + position de leurs bornes
  schemas.py     schémas pédagogiques (composants, nets, géométrie)
  cours.py       cours « Analyser avant de réparer » + son quiz
  contenu.py     questions des niveaux 1 et 2, aiguillage par niveau
  niveau4.py     questions du niveau 4 (chaîne d'alimentation)
  quiz.py        session chronométrée, correction (sans Qt)
  progression.py SQLite, boîtes de Leitner
  vue_schema.py  vue Qt cliquable d'un schéma
  interface.py   fenêtre : accueil, quiz, résultats
tests/
```

Ajouter un schéma : décrire ses composants (`Composant(ref, symbole, x, y,
rotation, valeur)`) et ses nets (polylignes dont les extrémités peuvent être
des bornes comme `"Q7130.G"`) dans `schemas.py`, puis des questions « clique
sur… » dans `contenu.py`. Le test de géométrie signale toute borne oubliée.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/article_course.dart';
import '../models/catalogue_item.dart';
import '../models/produit.dart';

class Bilan {
  final int consommes;
  final int jetes;
  const Bilan(this.consommes, this.jetes);
  int get total => consommes + jetes;
  double get pourcentageSauves => total == 0 ? 0 : consommes / total;
}

/// Résultat d'un archivage, pour pouvoir l'annuler.
class Archivage {
  final String produitUuid;
  final String historiqueUuid;
  final int quantiteAvant;
  const Archivage(this.produitUuid, this.historiqueUuid, this.quantiteAvant);
}

/// Produit accompagné de l'image du catalogue (une seule requête).
class ProduitAffiche {
  final Produit produit;
  final String? imageUrl;
  const ProduitAffiche(this.produit, this.imageUrl);
}

/// Le dernier écrivain gagne : vrai si la ligne distante remplace la locale.
bool distantGagne(String? localUpdatedAt, String distantUpdatedAt) {
  if (localUpdatedAt == null) return true;
  return distantUpdatedAt.compareTo(localUpdatedAt) > 0;
}

/// Description d'une table synchronisée.
class TableSync {
  /// Nom dans le protocole JSON.
  final String nom;
  final String table;
  final String cle;

  /// Colonnes échangées (clé et updated_at comprises).
  final List<String> colonnes;
  final List<String> requises;
  final List<String> dates;
  final List<String> entiers;
  final Map<String, Object> defauts;

  const TableSync({
    required this.nom,
    required this.table,
    required this.cle,
    required this.colonnes,
    required this.requises,
    this.dates = const [],
    this.entiers = const [],
    this.defauts = const {},
  });
}

const tablesSync = <TableSync>[
  TableSync(
    nom: 'produits',
    table: 'produits',
    cle: 'uuid',
    colonnes: [
      'uuid', 'code_barres', 'nom', 'date_peremption', 'quantite', 'categorie',
      'date_ajout', 'auteur', 'updated_at', 'deleted_at',
    ],
    requises: ['uuid', 'nom', 'date_peremption', 'updated_at'],
    dates: ['date_peremption', 'date_ajout'],
    entiers: ['quantite'],
    defauts: {'quantite': 1},
  ),
  TableSync(
    nom: 'catalogue',
    table: 'catalogue',
    cle: 'code_barres',
    colonnes: [
      'code_barres', 'nom', 'marque', 'categorie', 'image_url', 'source',
      'duree_habituelle_jours', 'updated_at',
    ],
    requises: ['code_barres', 'nom', 'updated_at'],
    entiers: ['duree_habituelle_jours'],
    defauts: {'source': 'manuel'},
  ),
  TableSync(
    nom: 'historique',
    table: 'historique',
    cle: 'uuid',
    colonnes: [
      'uuid', 'nom', 'issue', 'date_peremption', 'date_action', 'updated_at', 'deleted_at',
    ],
    requises: ['uuid', 'nom', 'issue', 'date_peremption', 'date_action', 'updated_at'],
    dates: ['date_peremption', 'date_action'],
  ),
  TableSync(
    nom: 'courses',
    table: 'courses',
    cle: 'uuid',
    colonnes: ['uuid', 'nom', 'fait', 'auteur', 'updated_at', 'deleted_at'],
    requises: ['uuid', 'nom', 'updated_at'],
    entiers: ['fait'],
    defauts: {'fait': 0},
  ),
];

TableSync tableSync(String nom) => tablesSync.firstWhere((t) => t.nom == nom);

String? _txt(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _entier(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

/// Nettoie une ligne distante ; null si elle est inutilisable.
Map<String, Object?>? normaliserLigneDistante(TableSync t, Map<String, Object?> l) {
  final res = <String, Object?>{};
  for (final c in t.colonnes) {
    Object? v;
    if (t.entiers.contains(c)) {
      v = _entier(l[c]);
    } else {
      var s = _txt(l[c]);
      if (s != null && t.dates.contains(c) && s.length > 10) s = s.substring(0, 10);
      v = s;
    }
    v ??= t.defauts[c];
    res[c] = v;
  }
  for (final c in t.requises) {
    if (res[c] == null) return null;
  }
  if (t.table == 'produits') res['date_ajout'] ??= dateIso(aujourdhui());
  return res;
}

class BaseDonnees {
  BaseDonnees._();
  static final BaseDonnees instance = BaseDonnees._();

  /// Incrémenté après chaque écriture : les écrans écoutent pour se rafraîchir.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static const versionSchema = 2;

  Database? _db;

  Future<Database> get _base async => _db ??= await _ouvrir();

  /// Pour les tests : instance indépendante sur une base déjà ouverte.
  @visibleForTesting
  BaseDonnees.pourTest(Database db) : _db = db;

  Future<Database> _ouvrir() async {
    final chemin = p.join(await getDatabasesPath(), 'frigo_malin.db');
    return openDatabase(chemin,
        version: versionSchema, onCreate: creerSchema, onUpgrade: migrerSchema);
  }

  /// Schéma de la version 1 (conservé pour tester la migration).
  static Future<void> creerSchemaV1(Database db) async {
    await db.execute('''
CREATE TABLE produits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  code_barres TEXT,
  nom TEXT NOT NULL,
  date_peremption TEXT NOT NULL,
  quantite INTEGER NOT NULL DEFAULT 1,
  categorie TEXT,
  photo_path TEXT,
  date_ajout TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
)''');
    await db.execute('CREATE INDEX idx_produits_peremption ON produits(date_peremption)');
    await db.execute('''
CREATE TABLE catalogue (
  code_barres TEXT PRIMARY KEY,
  nom TEXT NOT NULL,
  marque TEXT,
  categorie TEXT,
  image_url TEXT,
  source TEXT NOT NULL,
  duree_habituelle_jours INTEGER,
  updated_at TEXT NOT NULL
)''');
    await db.execute('''
CREATE TABLE historique (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  nom TEXT NOT NULL,
  issue TEXT NOT NULL,
  date_peremption TEXT NOT NULL,
  date_action TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''');
  }

  static Future<void> creerSchema(Database db, int v) async {
    await creerSchemaV1(db);
    await migrerSchema(db, 1, v);
  }

  static Future<void> migrerSchema(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      // « sale » = 1 tant que la ligne n'a pas été envoyée à la synchro.
      await db.execute('ALTER TABLE produits ADD COLUMN auteur TEXT');
      await db.execute('ALTER TABLE produits ADD COLUMN sale INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE catalogue ADD COLUMN sale INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE historique ADD COLUMN deleted_at TEXT');
      await db.execute('ALTER TABLE historique ADD COLUMN sale INTEGER NOT NULL DEFAULT 1');
      await db.execute('''
CREATE TABLE courses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  nom TEXT NOT NULL,
  fait INTEGER NOT NULL DEFAULT 0,
  auteur TEXT,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  sale INTEGER NOT NULL DEFAULT 1
)''');
    }
  }

  void _notifier() => version.value++;

  // ---------- Produits ----------

  Future<List<Produit>> lister() async {
    final db = await _base;
    final rows = await db.query('produits',
        where: 'deleted_at IS NULL', orderBy: 'date_peremption ASC, nom ASC');
    return rows.map(Produit.fromMap).toList();
  }

  /// Stock avec l'image du catalogue, en une seule requête.
  Future<List<ProduitAffiche>> listerAvecImages() async {
    final db = await _base;
    final rows = await db.rawQuery('''
SELECT p.*, c.image_url AS image_catalogue
FROM produits p LEFT JOIN catalogue c ON c.code_barres = p.code_barres
WHERE p.deleted_at IS NULL
ORDER BY p.date_peremption ASC, p.nom ASC''');
    return rows
        .map((r) => ProduitAffiche(Produit.fromMap(r), r['image_catalogue'] as String?))
        .toList();
  }

  Future<List<Produit>> listerUrgents(int jours) async {
    final db = await _base;
    final limite = dateIso(aujourdhui().add(Duration(days: jours)));
    final rows = await db.query('produits',
        where: 'deleted_at IS NULL AND date_peremption <= ?',
        whereArgs: [limite],
        orderBy: 'date_peremption ASC, nom ASC');
    return rows.map(Produit.fromMap).toList();
  }

  Map<String, Object?> _ligneProduit(Produit prod) =>
      prod.toMap()..remove('id')..['sale'] = 1;

  Future<int> ajouter(Produit prod) async {
    final db = await _base;
    prod.updatedAt = maintenantUtcIso();
    final id = await db.insert('produits', _ligneProduit(prod));
    prod.id = id;
    _notifier();
    return id;
  }

  Future<void> ajouterLot(List<Produit> produits) async {
    final db = await _base;
    final batch = db.batch();
    for (final prod in produits) {
      prod.updatedAt = maintenantUtcIso();
      batch.insert('produits', _ligneProduit(prod));
    }
    await batch.commit(noResult: true);
    _notifier();
  }

  Future<void> modifier(Produit prod) async {
    final db = await _base;
    prod.updatedAt = maintenantUtcIso();
    await db.update('produits', _ligneProduit(prod),
        where: 'uuid = ?', whereArgs: [prod.uuid]);
    _notifier();
  }

  /// Suppression logique (propagée par la synchro).
  Future<void> supprimer(Produit prod) async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.update('produits', {'deleted_at': t, 'updated_at': t, 'sale': 1},
        where: 'uuid = ?', whereArgs: [prod.uuid]);
    _notifier();
  }

  /// Archive [nombre] unités (toutes par défaut). issue : 'consomme' | 'jete'.
  /// S'il reste des unités, la quantité est simplement diminuée.
  Future<Archivage> archiver(Produit prod, String issue, {int? nombre}) async {
    final db = await _base;
    final t = maintenantUtcIso();
    final n = (nombre ?? prod.quantite).clamp(1, prod.quantite);
    final histUuid = nouvelUuid();
    await db.transaction((txn) async {
      await txn.insert('historique', {
        'uuid': histUuid,
        'nom': prod.nom,
        'issue': issue,
        'date_peremption': dateIso(prod.datePeremption),
        'date_action': dateIso(aujourdhui()),
        'updated_at': t,
        'sale': 1,
      });
      if (n >= prod.quantite) {
        await txn.update('produits', {'deleted_at': t, 'updated_at': t, 'sale': 1},
            where: 'uuid = ?', whereArgs: [prod.uuid]);
      } else {
        await txn.update(
            'produits', {'quantite': prod.quantite - n, 'updated_at': t, 'sale': 1},
            where: 'uuid = ?', whereArgs: [prod.uuid]);
      }
    });
    _notifier();
    return Archivage(prod.uuid, histUuid, prod.quantite);
  }

  /// Annule un archivage : le produit revient, la ligne d'historique est retirée.
  Future<void> annulerArchivage(Archivage a) async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.transaction((txn) async {
      await txn.update(
          'produits',
          {'deleted_at': null, 'quantite': a.quantiteAvant, 'updated_at': t, 'sale': 1},
          where: 'uuid = ?',
          whereArgs: [a.produitUuid]);
      await txn.update('historique', {'deleted_at': t, 'updated_at': t, 'sale': 1},
          where: 'uuid = ?', whereArgs: [a.historiqueUuid]);
    });
    _notifier();
  }

  Future<int> compter() async {
    final db = await _base;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM produits WHERE deleted_at IS NULL');
    return (r.first['n'] as int?) ?? 0;
  }

  /// Date du dernier ajout (suppressions logiques comprises : c'est une activité).
  Future<DateTime?> dernierAjout() async {
    final db = await _base;
    final r = await db.rawQuery('SELECT MAX(date_ajout) AS d FROM produits');
    final d = r.first['d'] as String?;
    return d == null ? null : lireDateIso(d);
  }

  Future<Bilan> bilan({int jours = 30}) async {
    final db = await _base;
    final depuis = dateIso(aujourdhui().subtract(Duration(days: jours)));
    final r = await db.rawQuery(
        'SELECT issue, COUNT(*) AS n FROM historique '
        'WHERE date_action >= ? AND deleted_at IS NULL GROUP BY issue',
        [depuis]);
    var c = 0, j = 0;
    for (final l in r) {
      if (l['issue'] == 'consomme') c = l['n'] as int;
      if (l['issue'] == 'jete') j = l['n'] as int;
    }
    return Bilan(c, j);
  }

  /// Noms récemment consommés ou jetés qui ne sont plus en stock (idées de rachat).
  Future<List<String>> recemmentTermines({int limite = 12}) async {
    final db = await _base;
    final r = await db.rawQuery('''
SELECT h.nom AS nom, MAX(h.updated_at) AS t FROM historique h
WHERE h.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM produits p WHERE p.deleted_at IS NULL AND p.nom = h.nom)
  AND NOT EXISTS (SELECT 1 FROM courses c WHERE c.deleted_at IS NULL AND c.nom = h.nom)
GROUP BY h.nom ORDER BY t DESC LIMIT ?''', [limite]);
    return r.map((l) => l['nom'] as String).toList();
  }

  // ---------- Liste de courses ----------

  Future<List<ArticleCourse>> listerCourses() async {
    final db = await _base;
    final r = await db.query('courses',
        where: 'deleted_at IS NULL', orderBy: 'fait ASC, nom COLLATE NOCASE ASC');
    return r.map(ArticleCourse.fromMap).toList();
  }

  /// Ajoute un article ; ignoré s'il est déjà dans la liste (non coché).
  Future<bool> ajouterCourse(String nom, {String? auteur}) async {
    final propre = neutraliserFormule(nom);
    if (propre.isEmpty) return false;
    final db = await _base;
    final existants = await db.query('courses',
        columns: ['nom'], where: 'deleted_at IS NULL AND fait = 0');
    final cible = normaliser(propre);
    if (existants.any((e) => normaliser(e['nom'] as String) == cible)) return false;
    await db.insert('courses', {
      'uuid': nouvelUuid(),
      'nom': propre,
      'fait': 0,
      'auteur': auteur,
      'updated_at': maintenantUtcIso(),
      'sale': 1,
    });
    _notifier();
    return true;
  }

  Future<void> cocherCourse(ArticleCourse a, bool fait) async {
    final db = await _base;
    await db.update(
        'courses', {'fait': fait ? 1 : 0, 'updated_at': maintenantUtcIso(), 'sale': 1},
        where: 'uuid = ?', whereArgs: [a.uuid]);
    _notifier();
  }

  Future<void> supprimerCourse(ArticleCourse a) async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.update('courses', {'deleted_at': t, 'updated_at': t, 'sale': 1},
        where: 'uuid = ?', whereArgs: [a.uuid]);
    _notifier();
  }

  Future<void> viderCoursesCochees() async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.update('courses', {'deleted_at': t, 'updated_at': t, 'sale': 1},
        where: 'deleted_at IS NULL AND fait = 1');
    _notifier();
  }

  // ---------- Catalogue ----------

  Future<CatalogueItem?> getCatalogue(String code) async {
    final db = await _base;
    final r = await db.query('catalogue', where: 'code_barres = ?', whereArgs: [code], limit: 1);
    return r.isEmpty ? null : CatalogueItem.fromMap(r.first);
  }

  Future<void> upsertCatalogue(CatalogueItem item) async {
    final db = await _base;
    await db.insert('catalogue', item.toMap()..['sale'] = 1,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Synchro ----------

  /// Lignes locales pas encore envoyées.
  Future<List<Map<String, Object?>>> lignesAEnvoyer(TableSync t) async {
    final db = await _base;
    return db.query(t.table, columns: t.colonnes, where: 'sale = 1');
  }

  /// Marque comme envoyées les lignes qui n'ont pas changé depuis l'envoi.
  Future<void> marquerEnvoyees(TableSync t, List<Map<String, Object?>> lignes) async {
    if (lignes.isEmpty) return;
    final db = await _base;
    final batch = db.batch();
    for (final l in lignes) {
      batch.update(t.table, {'sale': 0},
          where: '${t.cle} = ? AND updated_at = ?', whereArgs: [l[t.cle], l['updated_at']]);
    }
    await batch.commit(noResult: true);
  }

  /// Applique des lignes distantes (dernière écriture gagne). Renvoie le nombre appliqué.
  Future<int> appliquerDistant(TableSync t, List<Map<String, Object?>> lignes) async {
    if (lignes.isEmpty) return 0;
    final db = await _base;
    var appliquees = 0;
    await db.transaction((txn) async {
      for (final brute in lignes) {
        final l = normaliserLigneDistante(t, brute);
        if (l == null) continue;
        final cle = l[t.cle];
        final existant = await txn.query(t.table,
            columns: ['updated_at'], where: '${t.cle} = ?', whereArgs: [cle], limit: 1);
        final localMaj = existant.isEmpty ? null : existant.first['updated_at'] as String;
        if (!distantGagne(localMaj, l['updated_at'] as String)) continue;
        final valeurs = {...l, 'sale': 0};
        if (existant.isEmpty) {
          await txn.insert(t.table, valeurs);
        } else {
          await txn.update(t.table, valeurs, where: '${t.cle} = ?', whereArgs: [cle]);
        }
        appliquees++;
      }
    });
    if (appliquees > 0 && t.table != 'catalogue') _notifier();
    return appliquees;
  }

  /// À appeler quand on change de Sheet : tout sera renvoyé.
  Future<void> toutMarquerAEnvoyer() async {
    final db = await _base;
    for (final t in tablesSync) {
      await db.update(t.table, {'sale': 1});
    }
  }

  /// Purge les lignes supprimées et l'historique de plus de [jours] jours déjà envoyés.
  Future<void> purger({int jours = 90}) async {
    final db = await _base;
    final limite = aujourdhui().subtract(Duration(days: jours));
    final limiteIso = maintenantUtcIso(limite);
    final limiteDate = dateIso(limite);
    await db.delete('produits',
        where: 'sale = 0 AND deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [limiteIso]);
    await db.delete('courses',
        where: 'sale = 0 AND deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [limiteIso]);
    await db.delete('historique',
        where: 'sale = 0 AND date_action < ?', whereArgs: [limiteDate]);
  }
}

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/catalogue_item.dart';
import '../models/produit.dart';

class Bilan {
  final int consommes;
  final int jetes;
  const Bilan(this.consommes, this.jetes);
  int get total => consommes + jetes;
  double get pourcentageSauves => total == 0 ? 0 : consommes / total;
}

/// Le dernier écrivain gagne : vrai si la ligne distante remplace la locale.
bool distantGagne(String? localUpdatedAt, String distantUpdatedAt) {
  if (localUpdatedAt == null) return true;
  return distantUpdatedAt.compareTo(localUpdatedAt) > 0;
}

String? _txt(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String? _date(Object? v) {
  final s = _txt(v);
  if (s == null) return null;
  return s.length >= 10 ? s.substring(0, 10) : s;
}

int? _entier(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

class BaseDonnees {
  BaseDonnees._();
  static final BaseDonnees instance = BaseDonnees._();

  /// Incrémenté après chaque écriture : les écrans écoutent pour se rafraîchir.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  Database? _db;

  Future<Database> get _base async => _db ??= await _ouvrir();

  Future<Database> _ouvrir() async {
    final chemin = p.join(await getDatabasesPath(), 'frigo_malin.db');
    return openDatabase(chemin, version: 1, onCreate: (db, v) async {
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
    });
  }

  void _notifier() => version.value++;

  // ---------- Produits ----------

  Future<List<Produit>> lister() async {
    final db = await _base;
    final rows = await db.query('produits',
        where: 'deleted_at IS NULL', orderBy: 'date_peremption ASC, nom ASC');
    return rows.map(Produit.fromMap).toList();
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

  Future<int> ajouter(Produit prod) async {
    final db = await _base;
    prod.updatedAt = maintenantUtcIso();
    final id = await db.insert('produits', prod.toMap()..remove('id'));
    prod.id = id;
    _notifier();
    return id;
  }

  Future<void> ajouterLot(List<Produit> produits) async {
    final db = await _base;
    final batch = db.batch();
    for (final prod in produits) {
      prod.updatedAt = maintenantUtcIso();
      batch.insert('produits', prod.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
    _notifier();
  }

  Future<void> modifier(Produit prod) async {
    final db = await _base;
    prod.updatedAt = maintenantUtcIso();
    await db.update('produits', prod.toMap()..remove('id'),
        where: 'uuid = ?', whereArgs: [prod.uuid]);
    _notifier();
  }

  /// Suppression logique (propagée par la synchro).
  Future<void> supprimer(Produit prod) async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.update('produits', {'deleted_at': t, 'updated_at': t},
        where: 'uuid = ?', whereArgs: [prod.uuid]);
    _notifier();
  }

  /// issue : 'consomme' | 'jete'
  Future<void> archiver(Produit prod, String issue) async {
    final db = await _base;
    final t = maintenantUtcIso();
    await db.transaction((txn) async {
      await txn.insert('historique', {
        'uuid': nouvelUuid(),
        'nom': prod.nom,
        'issue': issue,
        'date_peremption': dateIso(prod.datePeremption),
        'date_action': dateIso(aujourdhui()),
        'updated_at': t,
      });
      await txn.update('produits', {'deleted_at': t, 'updated_at': t},
          where: 'uuid = ?', whereArgs: [prod.uuid]);
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
        'SELECT issue, COUNT(*) AS n FROM historique WHERE date_action >= ? GROUP BY issue',
        [depuis]);
    var c = 0, j = 0;
    for (final l in r) {
      if (l['issue'] == 'consomme') c = l['n'] as int;
      if (l['issue'] == 'jete') j = l['n'] as int;
    }
    return Bilan(c, j);
  }

  // ---------- Catalogue ----------

  Future<CatalogueItem?> getCatalogue(String code) async {
    final db = await _base;
    final r = await db.query('catalogue', where: 'code_barres = ?', whereArgs: [code], limit: 1);
    return r.isEmpty ? null : CatalogueItem.fromMap(r.first);
  }

  Future<void> upsertCatalogue(CatalogueItem item) async {
    final db = await _base;
    await db.insert('catalogue', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Synchro : lectures « modifié depuis T » ----------

  Future<List<Map<String, Object?>>> produitsModifiesDepuis(String? depuis) async {
    final db = await _base;
    final rows = await db.query('produits',
        columns: [
          'uuid', 'code_barres', 'nom', 'date_peremption', 'quantite',
          'categorie', 'date_ajout', 'updated_at', 'deleted_at'
        ],
        where: depuis == null ? null : 'updated_at > ?',
        whereArgs: depuis == null ? null : [depuis]);
    return rows;
  }

  Future<List<Map<String, Object?>>> catalogueModifieDepuis(String? depuis) async {
    final db = await _base;
    return db.query('catalogue',
        where: depuis == null ? null : 'updated_at > ?',
        whereArgs: depuis == null ? null : [depuis]);
  }

  Future<List<Map<String, Object?>>> historiqueModifieDepuis(String? depuis) async {
    final db = await _base;
    return db.query('historique',
        columns: ['uuid', 'nom', 'issue', 'date_peremption', 'date_action', 'updated_at'],
        where: depuis == null ? null : 'updated_at > ?',
        whereArgs: depuis == null ? null : [depuis]);
  }

  // ---------- Synchro : application des lignes distantes (dernière écriture gagne) ----------

  Future<void> appliquerProduitsDistants(List<Map<String, Object?>> lignes) async {
    final db = await _base;
    await db.transaction((txn) async {
      for (final l in lignes) {
        final uuid = _txt(l['uuid']);
        final maj = _txt(l['updated_at']);
        final nom = _txt(l['nom']);
        final per = _date(l['date_peremption']);
        if (uuid == null || maj == null || nom == null || per == null) continue;
        final existant = await txn.query('produits',
            columns: ['updated_at'], where: 'uuid = ?', whereArgs: [uuid], limit: 1);
        final localMaj = existant.isEmpty ? null : existant.first['updated_at'] as String;
        if (!distantGagne(localMaj, maj)) continue;
        final valeurs = <String, Object?>{
          'uuid': uuid,
          'code_barres': _txt(l['code_barres']),
          'nom': nom,
          'date_peremption': per,
          'quantite': _entier(l['quantite']) ?? 1,
          'categorie': _txt(l['categorie']),
          'date_ajout': _date(l['date_ajout']) ?? dateIso(aujourdhui()),
          'updated_at': maj,
          'deleted_at': _txt(l['deleted_at']),
        };
        if (existant.isEmpty) {
          await txn.insert('produits', valeurs);
        } else {
          await txn.update('produits', valeurs, where: 'uuid = ?', whereArgs: [uuid]);
        }
      }
    });
    _notifier();
  }

  Future<void> appliquerCatalogueDistant(List<Map<String, Object?>> lignes) async {
    final db = await _base;
    await db.transaction((txn) async {
      for (final l in lignes) {
        final code = _txt(l['code_barres']);
        final maj = _txt(l['updated_at']);
        final nom = _txt(l['nom']);
        if (code == null || maj == null || nom == null) continue;
        final existant = await txn.query('catalogue',
            columns: ['updated_at'], where: 'code_barres = ?', whereArgs: [code], limit: 1);
        final localMaj = existant.isEmpty ? null : existant.first['updated_at'] as String;
        if (!distantGagne(localMaj, maj)) continue;
        await txn.insert(
            'catalogue',
            {
              'code_barres': code,
              'nom': nom,
              'marque': _txt(l['marque']),
              'categorie': _txt(l['categorie']),
              'image_url': _txt(l['image_url']),
              'source': _txt(l['source']) ?? 'manuel',
              'duree_habituelle_jours': _entier(l['duree_habituelle_jours']),
              'updated_at': maj,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> appliquerHistoriqueDistant(List<Map<String, Object?>> lignes) async {
    final db = await _base;
    await db.transaction((txn) async {
      for (final l in lignes) {
        final uuid = _txt(l['uuid']);
        final maj = _txt(l['updated_at']);
        final nom = _txt(l['nom']);
        final per = _date(l['date_peremption']);
        final act = _date(l['date_action']);
        final issue = _txt(l['issue']);
        if (uuid == null || maj == null || nom == null || per == null || act == null || issue == null) {
          continue;
        }
        final existant = await txn.query('historique',
            columns: ['updated_at'], where: 'uuid = ?', whereArgs: [uuid], limit: 1);
        final localMaj = existant.isEmpty ? null : existant.first['updated_at'] as String;
        if (!distantGagne(localMaj, maj)) continue;
        await txn.insert(
            'historique',
            {
              'uuid': uuid,
              'nom': nom,
              'issue': issue,
              'date_peremption': per,
              'date_action': act,
              'updated_at': maj,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _notifier();
  }
}

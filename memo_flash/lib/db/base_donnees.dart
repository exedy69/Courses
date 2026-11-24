import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/carte.dart';
import '../models/paquet.dart';
import '../services/planificateur.dart';

/// Les cartes en apprentissage dues dans ce délai sont montrées en avance
/// quand il ne reste rien d'autre (comportement d'Anki).
const avanceApprentissage = Duration(minutes: 20);

/// Une révision enregistrée, pour pouvoir l'annuler.
class ReponseEnregistree {
  final Carte avant;
  final int revisionId;
  const ReponseEnregistree(this.avant, this.revisionId);
}

/// Une ligne du journal des révisions (statistiques).
class LigneRevision {
  final DateTime date;
  final Note note;
  final EtatCarte etatAvant;
  const LigneRevision(this.date, this.note, this.etatAvant);
}

class BaseDonnees {
  static const versionSchema = 1;

  static BaseDonnees? _instance;
  final Database db;

  /// Incrémenté à chaque écriture : les écrans l'écoutent pour se rafraîchir.
  final ValueNotifier<int> version = ValueNotifier(0);

  BaseDonnees._(this.db);

  /// Base de test ; [installer] en fait l'instance globale (tests d'écrans).
  @visibleForTesting
  factory BaseDonnees.pourTest(Database db, {bool installer = false}) {
    final b = BaseDonnees._(db);
    if (installer) _instance = b;
    return b;
  }

  static BaseDonnees get instance {
    final i = _instance;
    if (i == null) throw StateError('BaseDonnees.ouvrir() n\'a pas été appelé');
    return i;
  }

  static Future<BaseDonnees> ouvrir() async {
    if (_instance != null) return _instance!;
    final chemin = p.join(await getDatabasesPath(), 'memo_flash.db');
    final db = await openDatabase(
      chemin,
      version: versionSchema,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: creerSchema,
      onUpgrade: migrerSchema,
    );
    return _instance = BaseDonnees._(db);
  }

  static Future<void> creerSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE paquets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        cree_le INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE cartes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        paquet_id INTEGER NOT NULL REFERENCES paquets(id) ON DELETE CASCADE,
        recto TEXT NOT NULL,
        verso TEXT NOT NULL,
        etat INTEGER NOT NULL DEFAULT 0,
        echeance INTEGER NOT NULL,
        intervalle INTEGER NOT NULL DEFAULT 0,
        facilite INTEGER NOT NULL DEFAULT 2500,
        etape INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        oublis INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        cree_le INTEGER NOT NULL,
        modifie_le INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_cartes_paquet ON cartes(paquet_id, etat, echeance)');
    await db.execute('''
      CREATE TABLE revisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carte_id INTEGER NOT NULL REFERENCES cartes(id) ON DELETE CASCADE,
        paquet_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note INTEGER NOT NULL,
        etat_avant INTEGER NOT NULL,
        intervalle INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_revisions_date ON revisions(date)');
    await db.execute('CREATE TABLE reglages (cle TEXT PRIMARY KEY, valeur TEXT NOT NULL)');
  }

  /// Migrations futures : incrémenter [versionSchema] et ajouter une étape ici.
  static Future<void> migrerSchema(Database db, int ancienne, int nouvelle) async {}

  void _changer() => version.value++;

  // ---------------------------------------------------------------- Réglages

  Future<String?> lireReglage(String cle) async {
    final r = await db.query('reglages', where: 'cle = ?', whereArgs: [cle]);
    return r.isEmpty ? null : r.first['valeur'] as String;
  }

  Future<int> lireEntier(String cle, int defaut) async =>
      int.tryParse(await lireReglage(cle) ?? '') ?? defaut;

  Future<void> ecrireReglage(String cle, String valeur) async {
    await db.insert('reglages', {
      'cle': cle,
      'valeur': valeur,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changer();
  }

  Future<int> nouvellesParJour() => lireEntier('nouvelles_par_jour', 20);
  Future<int> revisionsParJour() => lireEntier('revisions_par_jour', 200);

  // ---------------------------------------------------------------- Paquets

  Future<List<Paquet>> listerPaquets() async {
    final r = await db.query('paquets', orderBy: 'nom COLLATE NOCASE');
    return r.map(Paquet.depuisLigne).toList();
  }

  Future<Paquet?> paquet(int id) async {
    final r = await db.query('paquets', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Paquet.depuisLigne(r.first);
  }

  Future<int> creerPaquet(String nom) async {
    final id = await db.insert(
      'paquets',
      Paquet(nom: nom.trim(), creeLe: DateTime.now()).versLigne(),
    );
    _changer();
    return id;
  }

  Future<void> renommerPaquet(int id, String nom) async {
    await db.update('paquets', {'nom': nom.trim()}, where: 'id = ?', whereArgs: [id]);
    _changer();
  }

  Future<void> supprimerPaquet(int id) async {
    await db.transaction((t) async {
      await t.delete('revisions', where: 'paquet_id = ?', whereArgs: [id]);
      await t.delete('cartes', where: 'paquet_id = ?', whereArgs: [id]);
      await t.delete('paquets', where: 'id = ?', whereArgs: [id]);
    });
    _changer();
  }

  /// Remet toutes les cartes du paquet à l'état « nouvelle ».
  Future<void> reinitialiserPaquet(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'cartes',
      {
        'etat': 0,
        'echeance': now,
        'intervalle': 0,
        'facilite': 2500,
        'etape': 0,
        'repetitions': 0,
        'oublis': 0,
        'modifie_le': now,
      },
      where: 'paquet_id = ?',
      whereArgs: [id],
    );
    _changer();
  }

  // ---------------------------------------------------------------- Cartes

  Future<int> _positionSuivante(DatabaseExecutor e) async {
    final r = await e.rawQuery('SELECT COALESCE(MAX(position), 0) + 1 AS p FROM cartes');
    return (r.first['p'] as num).toInt();
  }

  Future<int> ajouterCarte(Carte c) async {
    final id = await db.transaction((t) async {
      final pos = await _positionSuivante(t);
      return t.insert('cartes', c.copier(position: pos).versLigne()..remove('id'));
    });
    _changer();
    return id;
  }

  /// Ajoute plusieurs cartes en une transaction (import). Renvoie le nombre ajouté.
  Future<int> ajouterCartes(List<Carte> cartes) async {
    if (cartes.isEmpty) return 0;
    await db.transaction((t) async {
      var pos = await _positionSuivante(t);
      final lot = t.batch();
      for (final c in cartes) {
        lot.insert('cartes', c.copier(position: pos++).versLigne()..remove('id'));
      }
      await lot.commit(noResult: true);
    });
    _changer();
    return cartes.length;
  }

  Future<void> modifierCarte(Carte c) async {
    await db.update(
      'cartes',
      c.copier(modifieLe: DateTime.now()).versLigne(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    _changer();
  }

  Future<void> supprimerCarte(int id) async {
    await db.transaction((t) async {
      await t.delete('revisions', where: 'carte_id = ?', whereArgs: [id]);
      await t.delete('cartes', where: 'id = ?', whereArgs: [id]);
    });
    _changer();
  }

  Future<Carte?> carte(int id) async {
    final r = await db.query('cartes', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Carte.depuisLigne(r.first);
  }

  /// Cartes d'un paquet, filtrées par texte (recto ou verso, sans casse).
  Future<List<Carte>> listerCartes(int paquetId, {String recherche = ''}) async {
    final q = recherche.trim();
    final r = await db.query(
      'cartes',
      where: q.isEmpty
          ? 'paquet_id = ?'
          : 'paquet_id = ? AND (recto LIKE ? ESCAPE \'\\\' OR verso LIKE ? ESCAPE \'\\\')',
      whereArgs: q.isEmpty ? [paquetId] : [paquetId, _motif(q), _motif(q)],
      orderBy: 'position, id',
    );
    return r.map(Carte.depuisLigne).toList();
  }

  static String _motif(String q) =>
      '%${q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

  // ---------------------------------------------------------------- Révision

  Future<({int nouvelles, int revisions})> _faitesAujourdhui(
    int paquetId,
    DateTime maintenant,
  ) async {
    final debut = debutJour(numeroJour(maintenant)).millisecondsSinceEpoch;
    final r = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN etat_avant = 0 THEN 1 ELSE 0 END) AS n,
        SUM(CASE WHEN etat_avant = 2 THEN 1 ELSE 0 END) AS r
      FROM revisions WHERE paquet_id = ? AND date >= ?''',
      [paquetId, debut],
    );
    return (
      nouvelles: (r.first['n'] as num?)?.toInt() ?? 0,
      revisions: (r.first['r'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Compteurs> compteurs(int paquetId, {DateTime? maintenant}) async {
    final t = maintenant ?? DateTime.now();
    final faites = await _faitesAujourdhui(paquetId, t);
    final limNouv = max(0, await nouvellesParJour() - faites.nouvelles);
    final limRev = max(0, await revisionsParJour() - faites.revisions);
    final r = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN etat = 0 THEN 1 ELSE 0 END) AS n,
        SUM(CASE WHEN etat IN (1, 3) AND echeance <= ? THEN 1 ELSE 0 END) AS a,
        SUM(CASE WHEN etat = 2 AND echeance <= ? THEN 1 ELSE 0 END) AS r,
        COUNT(*) AS total
      FROM cartes WHERE paquet_id = ?''',
      [t.add(avanceApprentissage).millisecondsSinceEpoch, t.millisecondsSinceEpoch, paquetId],
    );
    final l = r.first;
    int v(String c) => (l[c] as num?)?.toInt() ?? 0;
    return Compteurs(
      nouvelles: min(v('n'), limNouv),
      apprentissage: v('a'),
      revision: min(v('r'), limRev),
      total: v('total'),
    );
  }

  /// Prochaine carte à présenter, ou `null` si la séance est terminée.
  /// Ordre : apprentissage échu, révisions, nouvelles, puis apprentissage en avance.
  Future<Carte?> prochaineCarte(int paquetId, {DateTime? maintenant, int? sauf}) async {
    final t = maintenant ?? DateTime.now();
    final now = t.millisecondsSinceEpoch;
    final exclure = sauf == null ? '' : ' AND id != $sauf';

    Future<Carte?> premiere(String where, List<Object?> args, String ordre) async {
      final r = await db.query(
        'cartes',
        where: 'paquet_id = ? AND $where$exclure',
        whereArgs: [paquetId, ...args],
        orderBy: ordre,
        limit: 1,
      );
      return r.isEmpty ? null : Carte.depuisLigne(r.first);
    }

    final apprentissage = await premiere('etat IN (1, 3) AND echeance <= ?', [now], 'echeance');
    if (apprentissage != null) return apprentissage;

    final faites = await _faitesAujourdhui(paquetId, t);
    if (faites.revisions < await revisionsParJour()) {
      final rev = await premiere('etat = 2 AND echeance <= ?', [now], 'echeance, id');
      if (rev != null) return rev;
    }
    if (faites.nouvelles < await nouvellesParJour()) {
      final nouv = await premiere('etat = 0', [], 'position, id');
      if (nouv != null) return nouv;
    }
    final avance = await premiere('etat IN (1, 3) AND echeance <= ?', [
      t.add(avanceApprentissage).millisecondsSinceEpoch,
    ], 'echeance');
    if (avance != null) return avance;
    // La carte exclue (celle qu'on vient de voir) reste possible en dernier recours.
    if (sauf != null) return prochaineCarte(paquetId, maintenant: t);
    return null;
  }

  /// Cartes en apprentissage qui reviendront plus tard aujourd'hui.
  Future<int> apprentissagePlusTard(int paquetId) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM cartes WHERE paquet_id = ? AND etat IN (1, 3)',
      [paquetId],
    );
    return (r.first['n'] as num).toInt();
  }

  Future<ReponseEnregistree> repondre(
    Carte c,
    Note note, {
    DateTime? maintenant,
    Planificateur planif = const Planificateur(),
  }) async {
    final t = maintenant ?? DateTime.now();
    final apres = planif.repondre(c, note, t).copier(modifieLe: t);
    late int revId;
    await db.transaction((tx) async {
      await tx.update('cartes', apres.versLigne(), where: 'id = ?', whereArgs: [c.id]);
      revId = await tx.insert('revisions', {
        'carte_id': c.id,
        'paquet_id': c.paquetId,
        'date': t.millisecondsSinceEpoch,
        'note': note.index,
        'etat_avant': c.etat.index,
        'intervalle': apres.intervalle,
      });
    });
    _changer();
    return ReponseEnregistree(c, revId);
  }

  Future<void> annuler(ReponseEnregistree r) async {
    await db.transaction((tx) async {
      await tx.update('cartes', r.avant.versLigne(), where: 'id = ?', whereArgs: [r.avant.id]);
      await tx.delete('revisions', where: 'id = ?', whereArgs: [r.revisionId]);
    });
    _changer();
  }

  // ---------------------------------------------------------------- Statistiques

  Future<List<LigneRevision>> revisionsDepuis(DateTime debut) async {
    final r = await db.query(
      'revisions',
      columns: ['date', 'note', 'etat_avant'],
      where: 'date >= ?',
      whereArgs: [debut.millisecondsSinceEpoch],
      orderBy: 'date',
    );
    return [
      for (final l in r)
        LigneRevision(
          DateTime.fromMillisecondsSinceEpoch((l['date'] as num).toInt()),
          Note.values[((l['note'] as num).toInt()).clamp(0, 3)],
          EtatCarte.depuis((l['etat_avant'] as num).toInt()),
        ),
    ];
  }

  /// Nombre de cartes par état, tous paquets confondus.
  Future<Map<EtatCarte, int>> repartition() async {
    final r = await db.rawQuery('SELECT etat, COUNT(*) AS n FROM cartes GROUP BY etat');
    return {
      for (final e in EtatCarte.values) e: 0,
      for (final l in r) EtatCarte.depuis((l['etat'] as num).toInt()): (l['n'] as num).toInt(),
    };
  }

  /// Révisions prévues pour chacun des [jours] prochains jours (indice 0 = aujourd'hui,
  /// retards compris).
  Future<List<int>> prevision(int jours, {DateTime? maintenant}) async {
    final t = maintenant ?? DateTime.now();
    final auj = numeroJour(t);
    final fin = debutJour(auj + jours).millisecondsSinceEpoch;
    final r = await db.query(
      'cartes',
      columns: ['echeance'],
      where: 'etat = 2 AND echeance < ?',
      whereArgs: [fin],
    );
    final res = List.filled(jours, 0);
    for (final l in r) {
      final j = numeroJour(DateTime.fromMillisecondsSinceEpoch((l['echeance'] as num).toInt()));
      res[max(0, j - auj)]++;
    }
    return res;
  }

  // ---------------------------------------------------------------- Sauvegarde

  Future<Map<String, Object?>> exporterTout() async => {
    'format': 'memo-flash',
    'version': 1,
    'paquets': await db.query('paquets'),
    'cartes': await db.query('cartes'),
    'revisions': await db.query('revisions'),
  };

  /// Remplace TOUTES les données par celles de la sauvegarde.
  Future<void> restaurerTout(Map<String, Object?> s) async {
    if (s['format'] != 'memo-flash') {
      throw const FormatException('Ce texte n\'est pas une sauvegarde Mémo Flash.');
    }
    List<Map<String, Object?>> lignes(String cle) => [
      for (final l in (s[cle] as List? ?? const [])) Map<String, Object?>.from(l as Map),
    ];
    final paquets = lignes('paquets');
    final cartes = lignes('cartes');
    final revisions = lignes('revisions');
    await db.transaction((t) async {
      await t.delete('revisions');
      await t.delete('cartes');
      await t.delete('paquets');
      final lot = t.batch();
      for (final l in paquets) {
        lot.insert('paquets', l);
      }
      for (final l in cartes) {
        lot.insert('cartes', l);
      }
      for (final l in revisions) {
        lot.insert('revisions', l);
      }
      await lot.commit(noResult: true);
    });
    _changer();
  }
}

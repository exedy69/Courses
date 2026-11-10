import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/db/base_donnees.dart';
import 'package:frigo_malin/models/produit.dart';
import 'package:frigo_malin/services/sync_backend.dart';
import 'package:frigo_malin/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class EtatMemoire implements EtatSync {
  @override
  bool actif = true;
  @override
  String url = 'https://script.google.com/macros/s/xxx/exec';
  @override
  String token = 'secret';
  @override
  int curseur = 0;
  @override
  String? urlConnue;
  String? dernierOk;
  @override
  Future<void> setCurseur(int v) async => curseur = v;
  @override
  Future<void> setUrlConnue(String v) async => urlConnue = v;
  @override
  Future<void> setDernierOk(String iso) async => dernierOk = iso;
}

/// Faux serveur : même logique que apps_script/Code.gs (numéro d'écriture croissant).
class ServeurFactice implements SyncBackend {
  final tables = <String, Map<String, Map<String, Object?>>>{};
  int seq = 0;
  bool panne = false;
  bool ancienScript = false;
  SyncRequete? derniere;
  int appels = 0;

  @override
  Future<void> tester() async {}

  @override
  Future<SyncReponse> echanger(SyncRequete r) async {
    appels++;
    if (panne) throw const SyncErreur('Connexion impossible');
    if (ancienScript) {
      throw const SyncErreur('Script Google trop ancien : recolle Code.gs et refais un déploiement');
    }
    derniere = r;
    final sortie = <String, List<Map<String, Object?>>>{};
    for (final e in r.tables.entries) {
      final t = tables.putIfAbsent(e.key, () => {});
      final cle = tableSync(e.key).cle;
      for (final l in e.value) {
        final k = l[cle] as String;
        final existant = t[k];
        if (distantGagne(existant?['updated_at'] as String?, l['updated_at'] as String)) {
          t[k] = {...l, 'seq': ++seq};
        }
      }
      sortie[e.key] = [
        for (final l in t.values)
          if ((l['seq'] as int) > r.curseur) Map<String, Object?>.from(l)..remove('seq'),
      ];
    }
    return SyncReponse(tables: sortie, curseur: seq);
  }
}

class Telephone {
  final BaseDonnees base;
  final EtatMemoire etat = EtatMemoire();
  late final SyncService sync;
  Telephone(this.base, ServeurFactice serveur) {
    sync = SyncService.pour(
        store: SyncStoreSqlite(base), fabriqueBackend: (_, _) => serveur, etat: etat);
  }
  Future<List<String>> noms() async => [for (final p in await base.lister()) p.nom];
}

Future<BaseDonnees> nouvelleBase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: BaseDonnees.versionSchema,
          onCreate: BaseDonnees.creerSchema,
          singleInstance: false));
  return BaseDonnees.pourTest(db);
}

Produit prod(String nom, {int jours = 5}) =>
    Produit(nom: nom, datePeremption: aujourdhui().add(Duration(days: jours)));

void main() {
  sqfliteFfiInit();

  test('distantGagne : la plus récente gagne, égalité = local conservé', () {
    expect(distantGagne(null, '2026-01-01T00:00:00.000Z'), isTrue);
    expect(distantGagne('2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.001Z'), isTrue);
    expect(distantGagne('2026-01-01T00:00:01.000Z', '2026-01-01T00:00:00.999Z'), isFalse);
    expect(distantGagne('2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'), isFalse);
  });

  test('fusionner : dernière écriture gagne et suppressions propagées', () {
    Map<String, Object?> l(String nom, String maj, {String? supprime}) =>
        {'uuid': 'a', 'nom': nom, 'updated_at': maj, 'deleted_at': supprime};
    final locales = {'a': l('Local', '2026-11-07T10:00:00.000Z')};
    expect(fusionner(locales, [l('Ancien', '2026-11-07T09:00:00.000Z')], 'uuid')['a']!['nom'], 'Local');
    expect(fusionner(locales, [l('Récent', '2026-11-07T11:00:00.000Z')], 'uuid')['a']!['nom'], 'Récent');
    final supprime = fusionner(locales,
        [l('Local', '2026-11-07T11:00:00.000Z', supprime: '2026-11-07T11:00:00.000Z')], 'uuid');
    expect(supprime['a']!['deleted_at'], isNotNull);
  });

  group('deux téléphones', () {
    late ServeurFactice serveur;
    late Telephone a;
    late Telephone b;

    setUp(() async {
      serveur = ServeurFactice();
      a = Telephone(await nouvelleBase(), serveur);
      b = Telephone(await nouvelleBase(), serveur);
    });

    test('un ajout sur A arrive sur B', () async {
      await a.base.ajouter(prod('Lait'));
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      expect(await b.noms(), ['Lait']);
      expect(a.sync.etat.value, 'Synchronisé');
      expect(a.etat.dernierOk, isNotNull);
    });

    test('une modification faite hors-ligne AVANT la synchro de l\'autre n\'est pas perdue', () async {
      // B modifie hors-ligne (son heure de modification est ancienne)…
      await b.base.ajouter(prod('Yaourt de B'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // …puis A synchronise et avance son curseur…
      await a.base.ajouter(prod('Lait de A'));
      await a.sync.synchroniser();
      // …et B ne synchronise qu'ensuite.
      await b.sync.synchroniser();
      await a.sync.synchroniser();
      expect(await a.noms(), containsAll(['Lait de A', 'Yaourt de B']));
      expect(await b.noms(), containsAll(['Lait de A', 'Yaourt de B']));
    });

    test('seules les lignes modifiées sont renvoyées', () async {
      await a.base.ajouter(prod('Lait'));
      await a.sync.synchroniser();
      expect(serveur.derniere!.tables['produits']!.length, 1);
      await a.sync.synchroniser();
      expect(serveur.derniere!.tables['produits'], isEmpty);
      await a.base.ajouter(prod('Beurre'));
      await a.sync.synchroniser();
      expect(serveur.derniere!.tables['produits']!.map((l) => l['nom']), ['Beurre']);
    });

    test('les lignes reçues ne sont pas renvoyées (pas de ping-pong)', () async {
      await a.base.ajouter(prod('Lait'));
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      final seqAvant = serveur.seq;
      await b.sync.synchroniser();
      await a.sync.synchroniser();
      expect(serveur.seq, seqAvant);
    });

    test('une suppression sur A se propage à B', () async {
      final p = prod('Lait');
      await a.base.ajouter(p);
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      expect(await b.noms(), ['Lait']);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await a.base.archiver(p, 'consomme');
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      expect(await b.noms(), isEmpty);
      expect((await b.base.bilan()).consommes, 1);
    });

    test('modification concurrente : la dernière écriture gagne des deux côtés', () async {
      final p = prod('Lait');
      await a.base.ajouter(p);
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      final chezB = (await b.base.lister()).single;
      p.quantite = 2;
      await a.base.modifier(p);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      chezB.quantite = 5;
      await b.base.modifier(chezB);
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      await a.sync.synchroniser();
      expect((await a.base.lister()).single.quantite, 5);
      expect((await b.base.lister()).single.quantite, 5);
    });

    test('la liste de courses et le catalogue sont partagés', () async {
      await a.base.ajouterCourse('Farine', auteur: 'Kendrick');
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      final courses = await b.base.listerCourses();
      expect(courses.single.nom, 'Farine');
      expect(courses.single.auteur, 'Kendrick');
      await b.base.cocherCourse(courses.single, true);
      await b.sync.synchroniser();
      await a.sync.synchroniser();
      expect((await a.base.listerCourses()).single.fait, isTrue);
    });

    test('changement de Sheet : tout est renvoyé et le curseur repart de zéro', () async {
      await a.base.ajouter(prod('Lait'));
      await a.sync.synchroniser();
      expect(a.etat.curseur, greaterThan(0));
      a.etat.url = 'https://script.google.com/macros/s/autre/exec';
      await a.sync.synchroniser();
      expect(serveur.derniere!.curseur, 0);
      expect(serveur.derniere!.tables['produits']!.length, 1);
    });

    test('une panne réseau ne lève rien, rien n\'est perdu', () async {
      serveur.panne = true;
      await a.base.ajouter(prod('Lait'));
      await a.sync.synchroniser();
      expect(a.sync.etat.value, startsWith('Échec'));
      expect(a.etat.dernierOk, isNull);
      serveur.panne = false;
      await a.sync.synchroniser();
      await b.sync.synchroniser();
      expect(await b.noms(), ['Lait']);
    });

    test('script Google trop ancien : message clair, curseur inchangé', () async {
      serveur.ancienScript = true;
      await a.sync.synchroniser();
      expect(a.sync.etat.value, contains('Script Google trop ancien'));
      expect(a.etat.curseur, 0);
    });

    test('inactive si désactivée, sauf demande explicite', () async {
      a.etat.actif = false;
      await a.sync.synchroniser();
      expect(serveur.appels, 0);
      await a.sync.synchroniser(force: true, complet: true);
      expect(serveur.derniere!.complet, isTrue);
    });
  });
}

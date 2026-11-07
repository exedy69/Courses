import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/db/base_donnees.dart';
import 'package:frigo_malin/services/reglages.dart';
import 'package:frigo_malin/services/sync_backend.dart';
import 'package:frigo_malin/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Magasin en mémoire qui applique la même règle que SQLite (distantGagne).
class StoreMemoire implements SyncStore {
  final produits = <String, Map<String, Object?>>{};
  final catalogue = <String, Map<String, Object?>>{};
  final historique = <String, Map<String, Object?>>{};

  List<Map<String, Object?>> _depuis(Map<String, Map<String, Object?>> m, String? d) => m.values
      .where((l) => d == null || (l['updated_at'] as String).compareTo(d) > 0)
      .map((l) => Map<String, Object?>.from(l))
      .toList();

  @override
  Future<List<Map<String, Object?>>> produitsModifiesDepuis(String? d) async => _depuis(produits, d);
  @override
  Future<List<Map<String, Object?>>> catalogueModifieDepuis(String? d) async => _depuis(catalogue, d);
  @override
  Future<List<Map<String, Object?>>> historiqueModifieDepuis(String? d) async => _depuis(historique, d);

  void _appliquer(Map<String, Map<String, Object?>> cible, List<Map<String, Object?>> l, String cle) {
    final f = fusionner(cible, l, cle);
    cible
      ..clear()
      ..addAll(f);
  }

  @override
  Future<void> appliquerProduitsDistants(List<Map<String, Object?>> l) async => _appliquer(produits, l, 'uuid');
  @override
  Future<void> appliquerCatalogueDistant(List<Map<String, Object?>> l) async => _appliquer(catalogue, l, 'code_barres');
  @override
  Future<void> appliquerHistoriqueDistant(List<Map<String, Object?>> l) async => _appliquer(historique, l, 'uuid');
}

/// Faux serveur Apps Script : même logique d'upsert « dernière écriture gagne ».
class ServeurFactice implements SyncBackend {
  final produits = <String, Map<String, Object?>>{};
  final catalogue = <String, Map<String, Object?>>{};
  final historique = <String, Map<String, Object?>>{};
  SyncRequete? derniere;
  String heure = '2026-11-07T12:00:00.000Z';
  bool panne = false;

  List<Map<String, Object?>> _depuis(Map<String, Map<String, Object?>> m, String since) => m.values
      .where((l) => since.isEmpty || (l['updated_at'] as String).compareTo(since) > 0)
      .toList();

  @override
  Future<void> tester() async {}

  @override
  Future<SyncReponse> echanger(SyncRequete r) async {
    if (panne) throw const SyncErreur('Connexion impossible');
    derniere = r;
    for (final (m, l, k) in [
      (produits, r.produits, 'uuid'),
      (catalogue, r.catalogue, 'code_barres'),
      (historique, r.historique, 'uuid'),
    ]) {
      final f = fusionner(m, l, k);
      m
        ..clear()
        ..addAll(f);
    }
    return SyncReponse(
      produits: _depuis(produits, r.since),
      catalogue: _depuis(catalogue, r.since),
      historique: _depuis(historique, r.since),
      serverTime: heure,
    );
  }
}

Map<String, Object?> prod(String uuid, String nom, String maj, {String? supprime}) => {
      'uuid': uuid,
      'nom': nom,
      'date_peremption': '2026-11-20',
      'quantite': 1,
      'updated_at': maj,
      'deleted_at': supprime,
    };

void main() {
  test('distantGagne : la plus récente gagne, égalité = local conservé', () {
    expect(distantGagne(null, '2026-01-01T00:00:00.000Z'), isTrue);
    expect(distantGagne('2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.001Z'), isTrue);
    expect(distantGagne('2026-01-01T00:00:01.000Z', '2026-01-01T00:00:00.999Z'), isFalse);
    expect(distantGagne('2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'), isFalse);
  });

  test('fusionner : dernière écriture gagne', () {
    final locales = {'a': prod('a', 'Local', '2026-11-07T10:00:00.000Z')};
    final res = fusionner(locales, [
      prod('a', 'Distant plus ancien', '2026-11-07T09:00:00.000Z'),
      prod('b', 'Nouveau', '2026-11-07T09:00:00.000Z'),
    ], 'uuid');
    expect(res['a']!['nom'], 'Local');
    expect(res['b']!['nom'], 'Nouveau');
    final res2 = fusionner(locales, [prod('a', 'Distant récent', '2026-11-07T11:00:00.000Z')], 'uuid');
    expect(res2['a']!['nom'], 'Distant récent');
  });

  test('fusionner : une suppression logique plus récente se propage', () {
    final locales = {'a': prod('a', 'Lait', '2026-11-07T10:00:00.000Z')};
    final res = fusionner(locales,
        [prod('a', 'Lait', '2026-11-07T11:00:00.000Z', supprime: '2026-11-07T11:00:00.000Z')], 'uuid');
    expect(res['a']!['deleted_at'], '2026-11-07T11:00:00.000Z');
    // et une modification locale plus récente ressuscite le produit
    final res2 = fusionner(res, [prod('a', 'Lait', '2026-11-07T12:00:00.000Z')], 'uuid');
    expect(res2['a']!['deleted_at'], isNull);
  });

  group('SyncService', () {
    late StoreMemoire store;
    late ServeurFactice serveur;
    late SyncService service;
    late Reglages reglages;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'sync_actif': true,
        'sync_url': 'https://script.google.com/macros/s/xxx/exec',
        'sync_token': 'secret',
      });
      reglages = await Reglages.charger();
      store = StoreMemoire();
      serveur = ServeurFactice();
      service = SyncService.pour(
          store: store, fabriqueBackend: (_, _) => serveur, reglages: reglages);
    });

    test('push des lignes locales, pull des lignes distantes', () async {
      store.produits['a'] = prod('a', 'Local', '2026-11-07T10:00:00.000Z');
      serveur.produits['z'] = prod('z', 'Du Sheet', '2026-11-07T08:00:00.000Z');
      await service.synchroniser();
      expect(serveur.produits.keys, containsAll(['a', 'z']));
      expect(store.produits.keys, containsAll(['a', 'z']));
      expect(service.etat.value, 'Synchronisé');
      expect(reglages.syncDernierOk, serveur.heure);
      expect(reglages.syncDernierPush, isNotNull);
    });

    test('seconde synchro : push seulement des lignes modifiées depuis le dernier push', () async {
      store.produits['a'] = prod('a', 'Ancien', '2000-01-01T00:00:00.000Z');
      await service.synchroniser();
      expect(serveur.derniere!.produits.length, 1);
      await service.synchroniser();
      expect(serveur.derniere!.produits, isEmpty);
      expect(serveur.derniere!.since, serveur.heure);
      store.produits['b'] = prod('b', 'Récent', '2999-01-01T00:00:00.000Z');
      await service.synchroniser();
      expect(serveur.derniere!.produits.map((p) => p['uuid']), ['b']);
    });

    test('suppression distante propagée vers le téléphone', () async {
      store.produits['a'] = prod('a', 'Lait', '2026-11-07T10:00:00.000Z');
      await service.synchroniser();
      serveur.produits['a'] = prod('a', 'Lait', '2999-01-01T00:00:00.000Z',
          supprime: '2999-01-01T00:00:00.000Z');
      await service.synchroniser();
      expect(store.produits['a']!['deleted_at'], '2999-01-01T00:00:00.000Z');
    });

    test('catalogue et historique sont synchronisés', () async {
      store.catalogue['3017620422003'] = {
        'code_barres': '3017620422003', 'nom': 'Nutella', 'updated_at': '2026-11-07T10:00:00.000Z'
      };
      serveur.historique['h'] = {
        'uuid': 'h', 'nom': 'Pain', 'issue': 'jete', 'updated_at': '2026-11-07T09:00:00.000Z'
      };
      await service.synchroniser();
      expect(serveur.catalogue.keys, ['3017620422003']);
      expect(store.historique.keys, ['h']);
    });

    test('une panne réseau ne lève rien et laisse l\'état d\'échec', () async {
      serveur.panne = true;
      store.produits['a'] = prod('a', 'Local', '2026-11-07T10:00:00.000Z');
      await service.synchroniser();
      expect(service.etat.value, startsWith('Échec'));
      expect(reglages.syncDernierOk, isNull);
      serveur.panne = false;
      await service.synchroniser();
      expect(serveur.produits.keys, contains('a'));
    });

    test('inactive si désactivée', () async {
      await reglages.setSyncActif(false);
      await service.synchroniser();
      expect(serveur.derniere, isNull);
    });
  });
}

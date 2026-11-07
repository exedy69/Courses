import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/models/catalogue_item.dart';
import 'package:frigo_malin/services/catalogue_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class StoreMemoire implements CatalogueStore {
  final Map<String, CatalogueItem> donnees = {};
  @override
  Future<CatalogueItem?> getCatalogue(String code) async => donnees[code];
  @override
  Future<void> upsertCatalogue(CatalogueItem item) async => donnees[item.codeBarres] = item;
}

String _off({String? fr, String? nom}) => jsonEncode({
      'code': '3017620422003',
      'status': 1,
      'product': {
        'product_name_fr': ?fr,
        'product_name': ?nom,
        'brands': 'Ferrero,Autre',
        'categories_tags': ['en:spreads', 'en:chocolate-spreads'],
        'image_front_small_url': 'https://images.openfoodfacts.org/x.jpg',
      },
    });

const _json = {'content-type': 'application/json; charset=utf-8'};
const _absent = '{"status":0,"status_verbose":"product not found"}';

void main() {
  const code = '3017620422003';

  test('analyse un JSON Open Food Facts et préfère product_name_fr', () {
    final item = CatalogueService.analyser(_off(fr: 'Pâte à tartiner', nom: 'Spread'), code, 'off')!;
    expect(item.nom, 'Pâte à tartiner');
    expect(item.marque, 'Ferrero');
    expect(item.categorie, 'en:spreads,en:chocolate-spreads');
    expect(item.imageUrl, startsWith('https://'));
    expect(item.source, 'off');
  });

  test('repli sur product_name, nom vide => null', () {
    expect(CatalogueService.analyser(_off(nom: 'Spread'), code, 'off')!.nom, 'Spread');
    expect(CatalogueService.analyser(_off(), code, 'off'), isNull);
    expect(CatalogueService.analyser(_absent, code, 'off'), isNull);
  });

  test('le catalogue local est prioritaire (aucun appel réseau)', () async {
    final store = StoreMemoire();
    store.donnees[code] = CatalogueItem(
        codeBarres: code, nom: 'Local', source: 'manuel', updatedAt: '2026-01-01T00:00:00.000Z');
    var appels = 0;
    final s = CatalogueService(
        store: store, client: MockClient((_) async {
          appels++;
          return http.Response(_off(fr: 'X'), 200);
        }));
    final r = await s.resoudre(code);
    expect(r.item!.nom, 'Local');
    expect(appels, 0);
  });

  test('ordre de repli off → obf → opf, avec User-Agent et HTTPS', () async {
    final hotes = <String>[];
    final client = MockClient((req) async {
      hotes.add(req.url.host);
      expect(req.url.scheme, 'https');
      expect(
          req.headers.entries
              .firstWhere((e) => e.key.toLowerCase() == 'user-agent')
              .value,
          'FrigoMalin/1.0 (usage personnel)');
      if (req.url.host == 'world.openproductsfacts.org') {
        return http.Response(_off(fr: 'Trouvé en OPF'), 200, headers: _json);
      }
      return http.Response(_absent, 200);
    });
    final store = StoreMemoire();
    final r = await CatalogueService(store: store, client: client).resoudre(code);
    expect(hotes, [
      'world.openfoodfacts.org',
      'world.openbeautyfacts.org',
      'world.openproductsfacts.org',
    ]);
    expect(r.item!.source, 'opf');
    expect(store.donnees[code]!.nom, 'Trouvé en OPF');
  });

  test('premier trouvé : on s\'arrête et on enregistre', () async {
    var appels = 0;
    final client = MockClient((_) async {
      appels++;
      return http.Response(_off(fr: 'Nutella'), 200, headers: _json);
    });
    final store = StoreMemoire();
    final r = await CatalogueService(store: store, client: client).resoudre(code);
    expect(appels, 1);
    expect(r.item!.source, 'off');
    expect(store.donnees.containsKey(code), isTrue);
  });

  test('produit introuvable partout', () async {
    final client = MockClient((_) async => http.Response(_absent, 404));
    final r = await CatalogueService(store: StoreMemoire(), client: client).resoudre(code);
    expect(r.item, isNull);
    expect(r.horsLigne, isFalse);
  });

  test('hors-ligne : une seule tentative puis abandon', () async {
    var appels = 0;
    final client = MockClient((_) async {
      appels++;
      throw http.ClientException('pas de réseau');
    });
    final r = await CatalogueService(store: StoreMemoire(), client: client).resoudre(code);
    expect(r.item, isNull);
    expect(r.horsLigne, isTrue);
    expect(appels, 1);
  });

  test('délai dépassé => hors-ligne', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final r = await CatalogueService(store: StoreMemoire(), client: client)
        .resoudre(code)
        .timeout(const Duration(seconds: 20));
    expect(r.horsLigne, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('enregistrement manuel dans le catalogue', () async {
    final store = StoreMemoire();
    final s = CatalogueService(store: store, client: MockClient((_) async => http.Response('', 500)));
    await s.enregistrerManuel(code, '  Mon produit ');
    expect(store.donnees[code]!.source, 'manuel');
    expect(store.donnees[code]!.nom, 'Mon produit');
    expect((await s.resoudre(code)).item!.nom, 'Mon produit');
  });
}

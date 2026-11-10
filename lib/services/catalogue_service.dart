import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../db/base_donnees.dart';
import '../models/catalogue_item.dart';
import '../models/produit.dart';

/// Stockage minimal du catalogue (injectable pour les tests).
abstract class CatalogueStore {
  Future<CatalogueItem?> getCatalogue(String code);
  Future<void> upsertCatalogue(CatalogueItem item);
}

class CatalogueStoreSqlite implements CatalogueStore {
  @override
  Future<CatalogueItem?> getCatalogue(String code) =>
      BaseDonnees.instance.getCatalogue(code);
  @override
  Future<void> upsertCatalogue(CatalogueItem item) =>
      BaseDonnees.instance.upsertCatalogue(item);
}

class ResultatCatalogue {
  final CatalogueItem? item;

  /// Vrai si la recherche en ligne a échoué à cause du réseau (hors-ligne, délai dépassé).
  final bool horsLigne;
  const ResultatCatalogue(this.item, {this.horsLigne = false});
  bool get trouve => item != null;
}

class CatalogueService {
  static const userAgent = 'FrigoMalin/1.0 (usage personnel)';
  static const delai = Duration(seconds: 6);

  /// (source, hôte) dans l'ordre de repli.
  static const sources = <(String, String)>[
    ('off', 'world.openfoodfacts.org'),
    ('obf', 'world.openbeautyfacts.org'),
    ('opf', 'world.openproductsfacts.org'),
  ];

  final CatalogueStore store;
  final http.Client client;

  CatalogueService({CatalogueStore? store, http.Client? client})
      : store = store ?? CatalogueStoreSqlite(),
        client = client ?? http.Client();

  static Uri urlProduit(String hote, String code) => Uri.https(
        hote,
        '/api/v2/product/$code.json',
        {'fields': 'product_name,product_name_fr,brands,categories_tags,image_front_small_url'},
      );

  /// Local d'abord, puis OFF → OBF → OPF. Un produit introuvable passe à la source
  /// suivante ; une erreur réseau (hors-ligne, délai) arrête la recherche en ligne.
  Future<ResultatCatalogue> resoudre(String code) async {
    final local = await store.getCatalogue(code);
    if (local != null) return ResultatCatalogue(local);

    for (final (source, hote) in sources) {
      try {
        final rep = await client
            .get(urlProduit(hote, code), headers: {'User-Agent': userAgent})
            .timeout(delai);
        if (rep.statusCode != 200) continue;
        final item = analyser(utf8.decode(rep.bodyBytes, allowMalformed: true), code, source);
        if (item != null) {
          await store.upsertCatalogue(item);
          return ResultatCatalogue(item);
        }
      } on TimeoutException {
        return const ResultatCatalogue(null, horsLigne: true);
      } on http.ClientException {
        return const ResultatCatalogue(null, horsLigne: true);
      } on FormatException {
        continue;
      } catch (_) {
        return const ResultatCatalogue(null, horsLigne: true);
      }
    }
    return const ResultatCatalogue(null);
  }

  /// Analyse la réponse JSON d'une API Open * Facts ; null si produit absent.
  static CatalogueItem? analyser(String corps, String code, String source) {
    final dynamic json = jsonDecode(corps);
    if (json is! Map) return null;
    final prod = json['product'];
    if (json['status'] == 0 || prod is! Map) return null;
    String? lire(String cle) {
      final v = prod[cle];
      if (v is! String) return null;
      final propre = neutraliserFormule(v);
      return propre.isEmpty ? null : propre;
    }

    final nom = lire('product_name_fr') ?? lire('product_name');
    if (nom == null) return null;
    final marque = lire('brands')?.split(',').first.trim();
    String? categorie;
    final tags = prod['categories_tags'];
    if (tags is List && tags.isNotEmpty) {
      categorie = tags.whereType<String>().join(',');
    }
    return CatalogueItem(
      codeBarres: code,
      nom: nom,
      marque: marque,
      categorie: categorie,
      imageUrl: prod['image_front_small_url'] is String
          ? (prod['image_front_small_url'] as String).trim()
          : null,
      source: source,
      updatedAt: maintenantUtcIso(),
    );
  }

  /// Enregistre un nom saisi à la main (source = 'manuel').
  Future<CatalogueItem> enregistrerManuel(String code, String nom) async {
    final item = CatalogueItem(
      codeBarres: code,
      nom: neutraliserFormule(nom),
      source: 'manuel',
      updatedAt: maintenantUtcIso(),
    );
    await store.upsertCatalogue(item);
    return item;
  }

  /// Met à jour nom et/ou durée habituelle d'un code du catalogue.
  Future<void> memoriser(CatalogueItem item, {String? nom, int? duree}) async {
    await store.upsertCatalogue(item.avec(
      nom: nom,
      dureeHabituelleJours: duree,
      updatedAt: maintenantUtcIso(),
    ));
  }
}

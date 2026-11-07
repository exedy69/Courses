import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/base_donnees.dart';
import '../models/produit.dart';
import 'reglages.dart';
import 'sync_backend.dart';
import 'sync_google_sheets.dart';

/// Accès aux données locales pour la synchro (injectable pour les tests).
abstract class SyncStore {
  Future<List<Map<String, Object?>>> produitsModifiesDepuis(String? depuis);
  Future<List<Map<String, Object?>>> catalogueModifieDepuis(String? depuis);
  Future<List<Map<String, Object?>>> historiqueModifieDepuis(String? depuis);
  Future<void> appliquerProduitsDistants(List<Map<String, Object?>> l);
  Future<void> appliquerCatalogueDistant(List<Map<String, Object?>> l);
  Future<void> appliquerHistoriqueDistant(List<Map<String, Object?>> l);
}

class SyncStoreSqlite implements SyncStore {
  final BaseDonnees _b = BaseDonnees.instance;
  @override
  Future<List<Map<String, Object?>>> produitsModifiesDepuis(String? d) => _b.produitsModifiesDepuis(d);
  @override
  Future<List<Map<String, Object?>>> catalogueModifieDepuis(String? d) => _b.catalogueModifieDepuis(d);
  @override
  Future<List<Map<String, Object?>>> historiqueModifieDepuis(String? d) => _b.historiqueModifieDepuis(d);
  @override
  Future<void> appliquerProduitsDistants(List<Map<String, Object?>> l) => _b.appliquerProduitsDistants(l);
  @override
  Future<void> appliquerCatalogueDistant(List<Map<String, Object?>> l) => _b.appliquerCatalogueDistant(l);
  @override
  Future<void> appliquerHistoriqueDistant(List<Map<String, Object?>> l) => _b.appliquerHistoriqueDistant(l);
}

/// Fusion « dernière écriture gagne » sur un jeu de lignes indexées par [cle].
/// Renvoie le nouvel état (les suppressions logiques sont des lignes avec `deleted_at`).
Map<String, Map<String, Object?>> fusionner(
  Map<String, Map<String, Object?>> locales,
  List<Map<String, Object?>> distantes,
  String cle,
) {
  final res = {for (final e in locales.entries) e.key: Map<String, Object?>.from(e.value)};
  for (final d in distantes) {
    final k = d[cle]?.toString();
    final maj = d['updated_at']?.toString();
    if (k == null || k.isEmpty || maj == null) continue;
    final l = res[k];
    if (distantGagne(l?['updated_at']?.toString(), maj)) {
      res[k] = Map<String, Object?>.from(d);
    }
  }
  return res;
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Pour les tests ou un autre backend.
  SyncService.pour({
    required this._store,
    required this.fabriqueBackend,
    this._reglages,
  });

  SyncStore? _store;
  Reglages? _reglages;
  SyncBackend Function(String url, String token)? fabriqueBackend;

  SyncStore get store => _store ??= SyncStoreSqlite();
  Reglages get reglages => _reglages ?? Reglages.instance;

  /// Ligne d'état affichée dans Réglages.
  final ValueNotifier<String> etat = ValueNotifier<String>('');
  bool _enCours = false;
  Timer? _antiRebond;

  bool get actif => reglages.syncActif && reglages.syncUrl.isNotEmpty && reglages.syncToken.isNotEmpty;

  SyncBackend _backend() => (fabriqueBackend ??
      (u, t) => SyncGoogleSheets(url: u, token: t))(reglages.syncUrl, reglages.syncToken);

  /// Planifie une synchro dans ~5 s (regroupe plusieurs enregistrements).
  void planifier() {
    if (!actif) return;
    _antiRebond?.cancel();
    _antiRebond = Timer(const Duration(seconds: 5), () => synchroniser());
  }

  Future<String> tester() async {
    try {
      await _backend().tester();
      return 'Connexion réussie';
    } on SyncErreur catch (e) {
      return e.message;
    } catch (_) {
      return 'Connexion impossible';
    }
  }

  /// Ne lève jamais d'exception : le résultat va dans [etat].
  Future<void> synchroniser({bool force = false}) async {
    if (_enCours) return;
    if (!force && !actif) return;
    _enCours = true;
    etat.value = 'Synchronisation…';
    try {
      final debutPush = maintenantUtcIso();
      final sincePush = reglages.syncDernierPush;
      final produits = await store.produitsModifiesDepuis(sincePush);
      final catalogue = await store.catalogueModifieDepuis(sincePush);
      final historique = await store.historiqueModifieDepuis(sincePush);

      final rep = await _backend().echanger(SyncRequete(
        since: reglages.syncDernierOk ?? '',
        produits: produits,
        catalogue: catalogue,
        historique: historique,
      ));

      await store.appliquerProduitsDistants(rep.produits);
      await store.appliquerCatalogueDistant(rep.catalogue);
      await store.appliquerHistoriqueDistant(rep.historique);

      await reglages.setSyncDernierPush(debutPush);
      await reglages.setSyncDernierOk(
          rep.serverTime.isNotEmpty ? rep.serverTime : maintenantUtcIso());
      etat.value = 'Synchronisé';
    } on SyncErreur catch (e) {
      etat.value = 'Échec : ${e.message}';
    } catch (_) {
      etat.value = 'Échec de la synchronisation';
    } finally {
      _enCours = false;
    }
  }
}

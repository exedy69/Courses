import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/base_donnees.dart';
import '../models/produit.dart';
import 'reglages.dart';
import 'sync_backend.dart';
import 'sync_google_sheets.dart';

/// Accès aux données locales pour la synchro (injectable pour les tests).
abstract class SyncStore {
  Future<List<Map<String, Object?>>> lignesAEnvoyer(String table);
  Future<void> marquerEnvoyees(String table, List<Map<String, Object?>> lignes);

  /// Renvoie le nombre de lignes réellement appliquées.
  Future<int> appliquerDistant(String table, List<Map<String, Object?>> lignes);

  /// Tout renvoyer à la prochaine synchro (changement de Sheet).
  Future<void> toutMarquerAEnvoyer();
}

class SyncStoreSqlite implements SyncStore {
  SyncStoreSqlite([BaseDonnees? base]) : _b = base ?? BaseDonnees.instance;
  final BaseDonnees _b;
  @override
  Future<List<Map<String, Object?>>> lignesAEnvoyer(String t) => _b.lignesAEnvoyer(tableSync(t));
  @override
  Future<void> marquerEnvoyees(String t, List<Map<String, Object?>> l) =>
      _b.marquerEnvoyees(tableSync(t), l);
  @override
  Future<int> appliquerDistant(String t, List<Map<String, Object?>> l) =>
      _b.appliquerDistant(tableSync(t), l);
  @override
  Future<void> toutMarquerAEnvoyer() => _b.toutMarquerAEnvoyer();
}

/// État persistant de la synchro (injectable pour les tests).
abstract class EtatSync {
  bool get actif;
  String get url;
  String get token;
  int get curseur;
  String? get urlConnue;
  Future<void> setCurseur(int v);
  Future<void> setUrlConnue(String v);
  Future<void> setDernierOk(String iso);
}

class EtatSyncReglages implements EtatSync {
  Reglages get _r => Reglages.instance;
  @override
  bool get actif => _r.syncActif;
  @override
  String get url => _r.syncUrl;
  @override
  String get token => _r.syncToken;
  @override
  int get curseur => _r.syncCurseur;
  @override
  String? get urlConnue => _r.syncUrlConnue;
  @override
  Future<void> setCurseur(int v) => _r.setSyncCurseur(v);
  @override
  Future<void> setUrlConnue(String v) => _r.setSyncUrlConnue(v);
  @override
  Future<void> setDernierOk(String iso) => _r.setSyncDernierOk(iso);
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
    required this._etat,
    List<String>? tables,
  }) : tables = tables ?? [for (final t in tablesSync) t.nom];

  SyncStore? _store;
  EtatSync? _etat;
  SyncBackend Function(String url, String token)? fabriqueBackend;
  List<String> tables = [for (final t in tablesSync) t.nom];

  SyncStore get store => _store ??= SyncStoreSqlite();
  EtatSync get reglages => _etat ??= EtatSyncReglages();

  /// Ligne d'état affichée dans Réglages.
  final ValueNotifier<String> etat = ValueNotifier<String>('');
  bool _enCours = false;
  bool _encoreUneFois = false;
  Timer? _antiRebond;

  bool get actif => reglages.actif && reglages.url.isNotEmpty && reglages.token.isNotEmpty;

  SyncBackend _backend() => (fabriqueBackend ??
      (u, t) => SyncGoogleSheets(url: u, token: t))(reglages.url, reglages.token);

  /// Planifie une synchro dans ~2 s (regroupe plusieurs enregistrements).
  void planifier() {
    if (!actif) return;
    _antiRebond?.cancel();
    _antiRebond = Timer(const Duration(seconds: 2), () => synchroniser());
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
  /// [complet] demande au serveur de relire tout le Sheet (corrections manuelles).
  Future<void> synchroniser({bool force = false, bool complet = false}) async {
    if (!force && !actif) return;
    if (_enCours) {
      _encoreUneFois = true;
      return;
    }
    _enCours = true;
    try {
      // Nouveau Sheet (ou première synchro) : on repart de zéro et on renvoie tout.
      if (reglages.urlConnue != reglages.url) {
        await store.toutMarquerAEnvoyer();
        await reglages.setCurseur(0);
        await reglages.setUrlConnue(reglages.url);
      }
      final envoi = <String, List<Map<String, Object?>>>{};
      for (final t in tables) {
        envoi[t] = await store.lignesAEnvoyer(t);
      }
      final rep = await _backend().echanger(SyncRequete(
        curseur: reglages.curseur,
        complet: complet,
        tables: envoi,
      ));
      for (final t in tables) {
        await store.appliquerDistant(t, rep.tables[t] ?? const []);
      }
      for (final t in tables) {
        await store.marquerEnvoyees(t, envoi[t]!);
      }
      await reglages.setCurseur(rep.curseur);
      await reglages.setDernierOk(maintenantUtcIso());
      if (etat.value != 'Synchronisé') etat.value = 'Synchronisé';
    } on SyncErreur catch (e) {
      etat.value = 'Échec : ${e.message}';
    } catch (_) {
      etat.value = 'Échec de la synchronisation';
    } finally {
      _enCours = false;
    }
    if (_encoreUneFois) {
      _encoreUneFois = false;
      await synchroniser();
    }
  }
}

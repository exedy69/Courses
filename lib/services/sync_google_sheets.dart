import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_backend.dart';

/// Backend Google Sheets via une application web Apps Script (voir apps_script/Code.gs).
/// L'URL et le jeton ne sont jamais journalisés.
class SyncGoogleSheets implements SyncBackend {
  final String url;
  final String token;
  final http.Client client;
  static const delai = Duration(seconds: 30);

  SyncGoogleSheets({required this.url, required this.token, http.Client? client})
      : client = client ?? http.Client();

  Uri get _uri {
    final u = Uri.tryParse(url.trim());
    if (u == null || u.scheme != 'https' || u.host.isEmpty) {
      throw const SyncErreur('L\'URL doit commencer par https://');
    }
    return u;
  }

  /// Suit à la main les redirections d'Apps Script (302/303 → GET sur Location).
  Future<http.Response> _suivre(http.StreamedResponse premiere) async {
    var rep = await http.Response.fromStream(premiere);
    var essais = 0;
    while ({301, 302, 303, 307, 308}.contains(rep.statusCode) && essais < 5) {
      final loc = rep.headers['location'];
      if (loc == null) break;
      final cible = _uri.resolve(loc);
      if (cible.scheme != 'https') {
        throw const SyncErreur('Redirection non sécurisée refusée');
      }
      final req = http.Request('GET', cible)..followRedirects = false;
      rep = await http.Response.fromStream(await client.send(req).timeout(delai));
      essais++;
    }
    return rep;
  }

  Map<String, dynamic> _decoder(http.Response rep) {
    if (rep.statusCode != 200) {
      throw SyncErreur('Réponse inattendue du serveur (${rep.statusCode})');
    }
    try {
      final j = jsonDecode(utf8.decode(rep.bodyBytes));
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    throw const SyncErreur('Réponse illisible : vérifiez l\'URL de l\'application web');
  }

  @override
  Future<void> tester() async {
    try {
      final req = http.Request('GET', _uri.replace(queryParameters: {'ping': '1'}))
        ..followRedirects = false;
      final rep = await _suivre(await client.send(req).timeout(delai));
      final j = _decoder(rep);
      if (j['ok'] != true || j['service'] != 'frigo-malin') {
        throw const SyncErreur('Ce n\'est pas le service Frigo Malin');
      }
    } on SyncErreur {
      rethrow;
    } on TimeoutException {
      throw const SyncErreur('Délai dépassé');
    } catch (_) {
      throw const SyncErreur('Connexion impossible');
    }
  }

  List<Map<String, Object?>> _liste(Object? v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, Object?>.from(m)).toList()
      : <Map<String, Object?>>[];

  @override
  Future<SyncReponse> echanger(SyncRequete r) async {
    try {
      final req = http.Request('POST', _uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode({
          'token': token,
          'action': 'sync',
          'v': 2,
          'cursor': r.curseur,
          'complet': r.complet,
          ...r.tables,
        });
      final rep = await _suivre(await client.send(req).timeout(delai));
      final j = _decoder(rep);
      if (j['ok'] != true) {
        throw const SyncErreur('Refusé par le serveur (jeton incorrect ?)');
      }
      final curseur = j['cursor'];
      if (curseur is! num) {
        throw const SyncErreur(
            'Script Google trop ancien : recolle Code.gs et refais un déploiement');
      }
      return SyncReponse(
        tables: {for (final nom in r.tables.keys) nom: _liste(j[nom])},
        curseur: curseur.toInt(),
      );
    } on SyncErreur {
      rethrow;
    } on TimeoutException {
      throw const SyncErreur('Délai dépassé');
    } catch (_) {
      throw const SyncErreur('Connexion impossible');
    }
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Reglages {
  Reglages._(this._p, this._token);
  final SharedPreferences _p;
  String _token;

  static const _coffre = FlutterSecureStorage();

  static Reglages? _instance;
  static Reglages get instance => _instance!;

  static Future<Reglages> charger() async {
    final p = await SharedPreferences.getInstance();
    var token = '';
    try {
      token = await _coffre.read(key: cSyncToken) ?? '';
      // Migration : l'ancien jeton en clair passe dans le stockage chiffré.
      final ancien = p.getString(cSyncToken);
      if (ancien != null) {
        if (token.isEmpty && ancien.isNotEmpty) {
          token = ancien;
          await _coffre.write(key: cSyncToken, value: ancien);
        }
        await p.remove(cSyncToken);
      }
    } catch (_) {
      // Stockage chiffré indisponible : la synchro restera simplement inactive.
    }
    _instance = Reglages._(p, token);
    return _instance!;
  }

  // Clés
  static const cHeure = 'heure_notif';
  static const cMinute = 'minute_notif';
  static const cJourCourses = 'jour_courses';
  static const cNotifsActives = 'notifs_actives';
  static const cDerniereRelance = 'derniere_relance';
  static const cSeuilSilence = 'seuil_silence';
  static const cSyncActif = 'sync_actif';
  static const cSyncUrl = 'sync_url';
  static const cSyncToken = 'sync_token';
  static const cSyncDernierOk = 'sync_dernier_ok';
  static const cSyncCurseur = 'sync_curseur';
  static const cPrenom = 'prenom';
  static const cSyncUrlConnue = 'sync_url_connue';

  int get heure => _p.getInt(cHeure) ?? 18;
  int get minute => _p.getInt(cMinute) ?? 0;
  Future<void> setHeure(int h, int m) async {
    await _p.setInt(cHeure, h);
    await _p.setInt(cMinute, m);
  }

  /// 0 = aucun, 1 = lundi … 7 = dimanche
  int get jourCourses => _p.getInt(cJourCourses) ?? 0;
  Future<void> setJourCourses(int j) => _p.setInt(cJourCourses, j);

  bool get notifsActives => _p.getBool(cNotifsActives) ?? false;
  Future<void> setNotifsActives(bool v) => _p.setBool(cNotifsActives, v);

  String? get derniereRelance => _p.getString(cDerniereRelance);
  Future<void> setDerniereRelance(String iso) => _p.setString(cDerniereRelance, iso);

  int get seuilSilence => _p.getInt(cSeuilSilence) ?? 10;
  Future<void> setSeuilSilence(int j) => _p.setInt(cSeuilSilence, j);

  /// Prénom affiché à côté des produits ajoutés (« ajouté par »).
  String get prenom => _p.getString(cPrenom) ?? '';
  String? get prenomOuNull => prenom.isEmpty ? null : prenom;
  Future<void> setPrenom(String v) => _p.setString(cPrenom, v.trim());

  bool get syncActif => _p.getBool(cSyncActif) ?? false;
  Future<void> setSyncActif(bool v) => _p.setBool(cSyncActif, v);

  String get syncUrl => _p.getString(cSyncUrl) ?? '';
  Future<void> setSyncUrl(String v) => _p.setString(cSyncUrl, v.trim());

  /// Jeton conservé dans le stockage chiffré d'Android, jamais en clair.
  String get syncToken => _token;
  Future<void> setSyncToken(String v) async {
    _token = v.trim();
    try {
      await _coffre.write(key: cSyncToken, value: _token);
    } catch (_) {}
  }

  String? get syncDernierOk => _p.getString(cSyncDernierOk);
  Future<void> setSyncDernierOk(String v) => _p.setString(cSyncDernierOk, v);

  /// URL avec laquelle le curseur actuel a été obtenu (détecte un changement de Sheet).
  String? get syncUrlConnue => _p.getString(cSyncUrlConnue);
  Future<void> setSyncUrlConnue(String v) => _p.setString(cSyncUrlConnue, v);

  /// Dernier numéro d'écriture serveur reçu.
  int get syncCurseur => _p.getInt(cSyncCurseur) ?? 0;
  Future<void> setSyncCurseur(int v) => _p.setInt(cSyncCurseur, v);
}

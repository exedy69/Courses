import 'package:shared_preferences/shared_preferences.dart';

class Reglages {
  Reglages._(this._p);
  final SharedPreferences _p;

  static Reglages? _instance;
  static Reglages get instance => _instance!;

  static Future<Reglages> charger() async {
    _instance = Reglages._(await SharedPreferences.getInstance());
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
  static const cSyncDernierPush = 'sync_dernier_push';

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

  bool get syncActif => _p.getBool(cSyncActif) ?? false;
  Future<void> setSyncActif(bool v) => _p.setBool(cSyncActif, v);

  String get syncUrl => _p.getString(cSyncUrl) ?? '';
  Future<void> setSyncUrl(String v) => _p.setString(cSyncUrl, v.trim());

  String get syncToken => _p.getString(cSyncToken) ?? '';
  Future<void> setSyncToken(String v) => _p.setString(cSyncToken, v.trim());

  String? get syncDernierOk => _p.getString(cSyncDernierOk);
  Future<void> setSyncDernierOk(String v) => _p.setString(cSyncDernierOk, v);

  String? get syncDernierPush => _p.getString(cSyncDernierPush);
  Future<void> setSyncDernierPush(String v) => _p.setString(cSyncDernierPush, v);
}

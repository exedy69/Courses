import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/base_donnees.dart';
import '../models/produit.dart';
import 'reglages.dart';

class ServiceNotifications {
  ServiceNotifications._();
  static final ServiceNotifications instance = ServiceNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _pret = false;

  static const _idQuotidien = 1;
  static const _idCourses = 2;
  static const _idRelance = 3;
  static const _idUrgents = 4;
  static const _idTest = 5;

  static const _canalQuotidien = AndroidNotificationDetails(
    'rappel_quotidien',
    'Rappel quotidien',
    channelDescription: 'Produits qui approchent de leur date de péremption',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _canalCourses = AndroidNotificationDetails(
    'rappel_courses',
    'Rappel de courses',
    channelDescription: 'Rappel hebdomadaire pour saisir les courses',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_pret) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _pret = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> notificationsAutorisees() async =>
      (await _android?.areNotificationsEnabled()) ?? false;

  /// Demande la permission d'afficher des notifications ; renvoie vrai si accordée.
  Future<bool> demanderPermission() async {
    await init();
    if (await notificationsAutorisees()) return true;
    return (await _android?.requestNotificationsPermission()) ?? false;
  }

  Future<void> _programmer({
    required int id,
    required String titre,
    required String corps,
    required tz.TZDateTime date,
    required AndroidNotificationDetails canal,
    DateTimeComponents? repetition,
  }) async {
    Future<void> essai(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: titre,
          body: corps,
          scheduledDate: date,
          notificationDetails: NotificationDetails(android: canal),
          androidScheduleMode: mode,
          matchDateTimeComponents: repetition,
        );
    try {
      await essai(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await essai(AndroidScheduleMode.inexactAllowWhileIdle);
      } else {
        rethrow;
      }
    }
  }

  tz.TZDateTime _prochaine(int heure, int minute, {int? jourSemaine}) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, heure, minute);
    if (jourSemaine != null) {
      while (d.weekday != jourSemaine) {
        d = d.add(const Duration(days: 1));
      }
    }
    if (!d.isAfter(now)) {
      d = d.add(Duration(days: jourSemaine != null ? 7 : 1));
    }
    return d;
  }

  /// Annule puis reprogramme les rappels récurrents selon les réglages.
  Future<void> reprogrammer() async {
    await init();
    final r = Reglages.instance;
    await _plugin.cancel(id: _idQuotidien);
    await _plugin.cancel(id: _idCourses);
    if (!r.notifsActives) {
      await _plugin.cancelAll();
      return;
    }
    await _programmer(
      id: _idQuotidien,
      titre: 'Frigo Malin',
      corps: 'Des produits approchent de leur date. Ouvre l\'appli pour voir lesquels.',
      date: _prochaine(r.heure, r.minute),
      canal: _canalQuotidien,
      repetition: DateTimeComponents.time,
    );
    if (r.jourCourses >= 1 && r.jourCourses <= 7) {
      await _programmer(
        id: _idCourses,
        titre: 'Courses faites ?',
        corps: 'Courses faites ? Pense à saisir tes achats avant de tout ranger.',
        date: _prochaine(19, 30, jourSemaine: r.jourCourses),
        canal: _canalCourses,
        repetition: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> annulerTout() async {
    await init();
    await _plugin.cancelAll();
  }

  /// À l'ouverture : notification immédiate s'il y a des produits ≤ 3 jours.
  Future<void> notifierUrgentsMaintenant() async {
    await init();
    if (!Reglages.instance.notifsActives || !await notificationsAutorisees()) return;
    final urgents = await BaseDonnees.instance.listerUrgents(3);
    if (urgents.isEmpty) return;
    final noms = urgents.take(3).map((p) => p.nom).join(', ');
    final plus = urgents.length > 3 ? '…' : '';
    await _plugin.show(
      id: _idUrgents,
      title: '${urgents.length} produit(s) à consommer vite',
      body: '$noms$plus',
      notificationDetails: const NotificationDetails(android: _canalQuotidien),
    );
  }

  /// Relance anti-oubli : au plus une tous les 3 jours.
  Future<void> verifierSilence() async {
    await init();
    final r = Reglages.instance;
    if (!r.notifsActives || !await notificationsAutorisees()) return;
    final dernier = await BaseDonnees.instance.dernierAjout();
    final auj = aujourdhui();
    if (dernier != null && auj.difference(dernier).inDays < r.seuilSilence) return;
    final rel = r.derniereRelance;
    if (rel != null && auj.difference(lireDateIso(rel)).inDays < 3) return;
    await _plugin.show(
      id: _idRelance,
      title: 'Ton frigo est-il à jour ?',
      body: dernier == null
          ? 'Aucun produit saisi pour l\'instant : scanne tes courses !'
          : 'Aucun ajout depuis ${auj.difference(dernier).inDays} jours. Pense à saisir tes achats.',
      notificationDetails: const NotificationDetails(android: _canalQuotidien),
    );
    await r.setDerniereRelance(dateIso(auj));
  }

  /// Notification de test dans 1 minute (écran « Fiabilité des rappels »).
  Future<void> programmerTest() async {
    await init();
    await _programmer(
      id: _idTest,
      titre: 'Test Frigo Malin',
      corps: 'Si tu lis ceci, les rappels fonctionnent sur ton téléphone.',
      date: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      canal: _canalQuotidien,
    );
  }

  Future<void> annulerTest() async {
    await init();
    await _plugin.cancel(id: _idTest);
  }
}

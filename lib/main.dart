import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'db/base_donnees.dart';
import 'screens/accueil.dart';
import 'screens/courses.dart';
import 'screens/repas.dart';
import 'screens/reglages_ecran.dart';
import 'services/reglages.dart';
import 'services/service_notifications.dart';
import 'services/sync_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Reglages.charger();
  await initializeDateFormatting('fr_FR');
  runApp(const FrigoMalinApp());
}

class FrigoMalinApp extends StatelessWidget {
  const FrigoMalinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frigo Malin',
      debugShowCheckedModeBanner: false,
      theme: themeClair(),
      darkTheme: themeSombre(),
      themeMode: ThemeMode.system,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CoquillePrincipale(),
    );
  }
}

class CoquillePrincipale extends StatefulWidget {
  const CoquillePrincipale({super.key});

  @override
  State<CoquillePrincipale> createState() => _CoquillePrincipaleState();
}

class _CoquillePrincipaleState extends State<CoquillePrincipale>
    with WidgetsBindingObserver {
  int _onglet = 0;
  Timer? _minuteur;

  /// Délai entre deux synchros quand l'appli est au premier plan.
  static const _intervalle = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _demarrer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    try {
      final n = ServiceNotifications.instance;
      await n.init();
      await n.reprogrammer();
      await n.verifierSilence();
      await n.notifierUrgentsMaintenant();
    } catch (_) {
      // Les notifications ne doivent jamais empêcher l'appli de démarrer.
    }
    try {
      await BaseDonnees.instance.purger();
    } catch (_) {}
    SyncService.instance.synchroniser(complet: true);
    _lancerMinuteur();
  }

  /// Synchro légère toutes les 20 s tant que l'appli est visible.
  void _lancerMinuteur() {
    _minuteur?.cancel();
    _minuteur = Timer.periodic(_intervalle, (_) => SyncService.instance.synchroniser());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) {
      // Les couleurs dépendent de la date : on recharge stock et repas.
      BaseDonnees.version.value++;
      SyncService.instance.synchroniser(complet: true);
      _lancerMinuteur();
    } else if (etat == AppLifecycleState.paused) {
      _minuteur?.cancel();
      _minuteur = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: const [EcranAccueil(), EcranRepas(), EcranCourses(), EcranReglages()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), selectedIcon: Icon(Icons.kitchen), label: 'Mon stock'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Repas'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Réglages'),
        ],
      ),
    );
  }
}

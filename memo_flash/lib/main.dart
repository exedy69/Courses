import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'data/exemple.dart';
import 'db/base_donnees.dart';
import 'screens/paquets.dart';
import 'screens/reglages.dart';
import 'screens/statistiques.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final base = await BaseDonnees.ouvrir();
  modeTheme.value = modeDepuisTexte(await base.lireReglage('theme'));
  await creerPaquetExempleSiBesoin(base);
  runApp(const MemoFlashApp());
}

class MemoFlashApp extends StatelessWidget {
  const MemoFlashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: modeTheme,
      builder: (context, mode, _) => MaterialApp(
        title: 'Mémo Flash',
        debugShowCheckedModeBanner: false,
        theme: themeClair(),
        darkTheme: themeSombre(),
        themeMode: mode,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Coquille(),
      ),
    );
  }
}

class Coquille extends StatefulWidget {
  const Coquille({super.key});

  @override
  State<Coquille> createState() => _CoquilleState();
}

class _CoquilleState extends State<Coquille> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: const [EcranPaquets(), EcranStatistiques(), EcranReglages()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Paquets',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Statistiques',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}

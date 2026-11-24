import 'package:material_ui/material_ui.dart';

import '../db/base_donnees.dart';
import '../models/paquet.dart';
import '../theme.dart';
import 'editeur_carte.dart';
import 'paquet.dart';
import 'revision.dart';

class EcranPaquets extends StatefulWidget {
  const EcranPaquets({super.key});

  @override
  State<EcranPaquets> createState() => _EcranPaquetsState();
}

class _EcranPaquetsState extends State<EcranPaquets> {
  final _base = BaseDonnees.instance;
  List<(Paquet, Compteurs)>? _paquets;

  @override
  void initState() {
    super.initState();
    _base.version.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    _base.version.removeListener(_charger);
    super.dispose();
  }

  Future<void> _charger() async {
    final paquets = await _base.listerPaquets();
    final res = [for (final p in paquets) (p, await _base.compteurs(p.id!))];
    if (mounted) setState(() => _paquets = res);
  }

  Future<void> _nouveauPaquet() async {
    final nom = await demanderTexte(context, titre: 'Nouveau paquet', ok: 'Créer');
    if (nom == null) return;
    final id = await _base.creerPaquet(nom);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EcranPaquet(paquetId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final paquets = _paquets;
    final aFaire = paquets?.fold<int>(0, (s, e) => s + e.$2.aFaire) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Mémo Flash')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouveauPaquet,
        icon: const Icon(Icons.add),
        label: const Text('Paquet'),
      ),
      body: paquets == null
          ? const Center(child: CircularProgressIndicator())
          : paquets.isEmpty
          ? const _Vide()
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    aFaire == 0
                        ? 'Rien à réviser pour l\'instant. Bravo !'
                        : '$aFaire carte${aFaire > 1 ? 's' : ''} à voir aujourd\'hui',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [_Entete()]),
                ),
                for (final (p, c) in paquets)
                  ListTile(
                    title: Text(p.nom),
                    subtitle: Text('${c.total} carte${c.total > 1 ? 's' : ''}'),
                    trailing: LigneCompteurs(
                      nouvelles: c.nouvelles,
                      apprentissage: c.apprentissage,
                      revision: c.revision,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EcranPaquet(paquetId: p.id!)),
                    ),
                    onLongPress: () => _menuRapide(p, c),
                  ),
              ],
            ),
    );
  }

  void _menuRapide(Paquet p, Compteurs c) {
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(p.nom, style: Theme.of(context).textTheme.titleMedium)),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Réviser'),
              enabled: c.aFaire > 0,
              onTap: () {
                Navigator.pop(s);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EcranRevision(paquetId: p.id!)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Ajouter des cartes'),
              onTap: () {
                Navigator.pop(s);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditeurCarte(paquetId: p.id!)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget t(String s, Color c) => SizedBox(
      width: 39,
      child: Text(
        s,
        textAlign: TextAlign.end,
        style: style?.copyWith(color: c),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        t('Nouv.', CouleursCompteurs.nouvelles(context)),
        t('Appr.', CouleursCompteurs.apprentissage(context)),
        t('Rév.', CouleursCompteurs.revision(context)),
      ],
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          const Text('Aucun paquet', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Crée un paquet, ajoute des cartes recto/verso, puis révise-les '
            'chaque jour : l\'appli te les représente juste avant que tu les oublies.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

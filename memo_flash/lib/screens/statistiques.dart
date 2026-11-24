import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../db/base_donnees.dart';
import '../models/carte.dart';
import '../services/planificateur.dart';
import '../theme.dart';

/// Résumé calculé à partir du journal des révisions.
class Resume {
  final int aujourdhui;
  final double reussiteAujourdhui; // part des réponses autres que « À revoir »
  final int serie; // jours consécutifs avec au moins une révision
  final List<int> parJour; // du plus ancien à aujourd'hui

  const Resume(this.aujourdhui, this.reussiteAujourdhui, this.serie, this.parJour);

  factory Resume.calculer(List<LigneRevision> revs, DateTime maintenant, int jours) {
    final auj = numeroJour(maintenant);
    final parJour = List.filled(jours, 0);
    final actifs = <int>{};
    var reussies = 0, faites = 0;
    for (final r in revs) {
      final j = numeroJour(r.date);
      actifs.add(j);
      final i = jours - 1 - (auj - j);
      if (i >= 0 && i < jours) parJour[i]++;
      if (j == auj) {
        faites++;
        if (r.note != Note.aRevoir) reussies++;
      }
    }
    // La série continue si l'on n'a pas encore révisé aujourd'hui mais qu'on l'a fait hier.
    var jour = actifs.contains(auj) ? auj : auj - 1;
    var serie = 0;
    while (actifs.contains(jour)) {
      serie++;
      jour--;
    }
    return Resume(faites, faites == 0 ? 0 : reussies / faites, serie, parJour);
  }
}

class EcranStatistiques extends StatefulWidget {
  const EcranStatistiques({super.key});

  @override
  State<EcranStatistiques> createState() => _EcranStatistiquesState();
}

class _EcranStatistiquesState extends State<EcranStatistiques> {
  final _base = BaseDonnees.instance;
  static const _jours = 14;
  Resume? _resume;
  Map<EtatCarte, int> _repartition = {};
  List<int> _prevision = [];

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
    final t = DateTime.now();
    // Un an d'historique suffit pour la série.
    final revs = await _base.revisionsDepuis(debutJour(numeroJour(t) - 365));
    final rep = await _base.repartition();
    final prev = await _base.prevision(7);
    if (!mounted) return;
    setState(() {
      _resume = Resume.calculer(revs, t, _jours);
      _repartition = rep;
      _prevision = prev;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _resume;
    final theme = Theme.of(context);
    final total = _repartition.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _Tuile('Aujourd\'hui', '${r.aujourdhui}', 'révisions'),
                    _Tuile(
                      'Réussite',
                      r.aujourdhui == 0 ? '—' : '${(r.reussiteAujourdhui * 100).round()} %',
                      'aujourd\'hui',
                    ),
                    _Tuile('Série', '${r.serie}', r.serie > 1 ? 'jours' : 'jour'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Révisions des $_jours derniers jours', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Barres(
                  valeurs: r.parJour,
                  couleur: theme.colorScheme.primary,
                  legendeFin: 'auj.',
                  legendeDebut: '-${_jours - 1} j',
                ),
                const SizedBox(height: 24),
                Text('À réviser dans les 7 prochains jours', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Barres(
                  valeurs: _prevision,
                  couleur: CouleursCompteurs.revision(context),
                  legendeDebut: 'auj.',
                  legendeFin: '+6 j',
                ),
                const SizedBox(height: 24),
                Text('Cartes ($total)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _ligne(
                  'Nouvelles',
                  _repartition[EtatCarte.nouvelle] ?? 0,
                  CouleursCompteurs.nouvelles(context),
                ),
                _ligne(
                  'En apprentissage',
                  (_repartition[EtatCarte.apprentissage] ?? 0) +
                      (_repartition[EtatCarte.reapprentissage] ?? 0),
                  CouleursCompteurs.apprentissage(context),
                ),
                _ligne(
                  'Apprises',
                  _repartition[EtatCarte.revision] ?? 0,
                  CouleursCompteurs.revision(context),
                ),
              ],
            ),
    );
  }

  Widget _ligne(String libelle, int n, Color c) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(radius: 6, backgroundColor: c),
    title: Text(libelle),
    trailing: Text('$n', style: const TextStyle(fontSize: 16)),
  );
}

class _Tuile extends StatelessWidget {
  final String titre, valeur, unite;
  const _Tuile(this.titre, this.valeur, this.unite);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(titre, style: t.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(valeur, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(unite, style: t.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit histogramme sans bibliothèque.
class _Barres extends StatelessWidget {
  final List<int> valeurs;
  final Color couleur;
  final String legendeDebut, legendeFin;
  const _Barres({
    required this.valeurs,
    required this.couleur,
    required this.legendeDebut,
    required this.legendeFin,
  });

  @override
  Widget build(BuildContext context) {
    final maxi = valeurs.fold<int>(0, max);
    final petit = Theme.of(context).textTheme.labelSmall;
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in valeurs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (v > 0) Text('$v', style: petit),
                        Container(
                          height: maxi == 0 ? 2 : max(2, 96 * v / maxi),
                          decoration: BoxDecoration(
                            color: v == 0 ? Theme.of(context).dividerColor : couleur,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(legendeDebut, style: petit),
            Text(legendeFin, style: petit),
          ],
        ),
      ],
    );
  }
}

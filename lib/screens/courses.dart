import 'package:flutter/material.dart';

import '../db/base_donnees.dart';
import '../models/article_course.dart';
import '../services/reglages.dart';
import '../services/sync_service.dart';
import '../theme.dart';

/// Liste de courses partagée (synchronisée comme le stock).
class EcranCourses extends StatefulWidget {
  const EcranCourses({super.key});

  @override
  State<EcranCourses> createState() => _EcranCoursesState();
}

class _EcranCoursesState extends State<EcranCourses> {
  final _champ = TextEditingController();
  List<ArticleCourse> _articles = [];
  List<String> _idees = [];
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    BaseDonnees.version.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    BaseDonnees.version.removeListener(_charger);
    _champ.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final a = await BaseDonnees.instance.listerCourses();
    final i = await BaseDonnees.instance.recemmentTermines();
    if (!mounted) return;
    setState(() {
      _articles = a;
      _idees = i;
      _charge = true;
    });
  }

  Future<void> _ajouter(String nom) async {
    final ok = await BaseDonnees.instance
        .ajouterCourse(nom, auteur: Reglages.instance.prenomOuNull);
    SyncService.instance.planifier();
    if (!ok && mounted && nom.trim().isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Déjà dans la liste')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nbCoches = _articles.where((a) => a.fait).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          if (nbCoches > 0)
            TextButton.icon(
              onPressed: () async {
                await BaseDonnees.instance.viderCoursesCochees();
                SyncService.instance.planifier();
              },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text('Retirer les cochés ($nbCoches)'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !_charge
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        if (_articles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.shopping_cart_outlined,
                                    size: 64, color: Theme.of(context).colorScheme.outline),
                                const SizedBox(height: 16),
                                Text('La liste de courses est vide',
                                    style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                  'Ajoute un article en bas, ou depuis une recette dans « Repas ».',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        for (final a in _articles) ...[
                          Dismissible(
                            key: ValueKey(a.uuid),
                            background: Container(
                              decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) async {
                              setState(() => _articles.removeWhere((x) => x.uuid == a.uuid));
                              await BaseDonnees.instance.supprimerCourse(a);
                              SyncService.instance.planifier();
                            },
                            child: CarteApp(
                              onTap: () async {
                                await BaseDonnees.instance.cocherCourse(a, !a.fait);
                                SyncService.instance.planifier();
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: a.fait,
                                    onChanged: (v) async {
                                      await BaseDonnees.instance.cocherCourse(a, v ?? false);
                                      SyncService.instance.planifier();
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.nom,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              decoration:
                                                  a.fait ? TextDecoration.lineThrough : null,
                                              color: a.fait
                                                  ? Theme.of(context).colorScheme.outline
                                                  : null),
                                        ),
                                        if (a.auteur != null && a.auteur!.isNotEmpty)
                                          Text('Ajouté par ${a.auteur}',
                                              style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_idees.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Terminés récemment : à racheter ?',
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final nom in _idees)
                                ActionChip(
                                  avatar: const Icon(Icons.add, size: 18),
                                  label: Text(nom),
                                  onPressed: () => _ajouter(nom),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _champ,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                          labelText: 'Ajouter un article', border: OutlineInputBorder()),
                      onSubmitted: (v) {
                        _ajouter(v);
                        _champ.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: IconButton.filled(
                      onPressed: () {
                        _ajouter(_champ.text);
                        _champ.clear();
                      },
                      icon: const Icon(Icons.add),
                      tooltip: 'Ajouter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

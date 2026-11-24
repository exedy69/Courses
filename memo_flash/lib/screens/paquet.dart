import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../db/base_donnees.dart';
import '../models/carte.dart';
import '../models/paquet.dart';
import '../services/import_texte.dart';
import '../services/planificateur.dart';
import '../theme.dart';
import 'editeur_carte.dart';
import 'import.dart';
import 'revision.dart';

class EcranPaquet extends StatefulWidget {
  final int paquetId;
  const EcranPaquet({super.key, required this.paquetId});

  @override
  State<EcranPaquet> createState() => _EcranPaquetState();
}

class _EcranPaquetState extends State<EcranPaquet> {
  final _base = BaseDonnees.instance;
  final _recherche = TextEditingController();
  Paquet? _paquet;
  Compteurs _compteurs = const Compteurs();
  List<Carte> _cartes = [];
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _base.version.addListener(_charger);
    _charger();
  }

  @override
  void dispose() {
    _base.version.removeListener(_charger);
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final p = await _base.paquet(widget.paquetId);
    if (p == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final c = await _base.compteurs(widget.paquetId);
    final cartes = await _base.listerCartes(widget.paquetId, recherche: _recherche.text);
    if (!mounted) return;
    setState(() {
      _paquet = p;
      _compteurs = c;
      _cartes = cartes;
      _charge = true;
    });
  }

  Future<void> _action(String a) async {
    final p = _paquet!;
    switch (a) {
      case 'renommer':
        final nom = await demanderTexte(context, titre: 'Renommer', initial: p.nom);
        if (nom != null) await _base.renommerPaquet(p.id!, nom);
      case 'importer':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EcranImport(paquetId: p.id!)),
        );
      case 'exporter':
        final tout = await _base.listerCartes(p.id!);
        await Clipboard.setData(ClipboardData(text: exporterTexte(tout)));
        if (mounted) {
          afficherMessage(
            context,
            '${tout.length} cartes copiées (format tabulé, réimportable ici ou dans Anki).',
          );
        }
      case 'reinitialiser':
        if (await confirmer(
          context,
          titre: 'Recommencer à zéro ?',
          message:
              'Toutes les cartes de « ${p.nom} » redeviendront nouvelles. '
              'Le contenu est conservé, la progression est perdue.',
          ok: 'Réinitialiser',
        )) {
          await _base.reinitialiserPaquet(p.id!);
        }
      case 'supprimer':
        if (await confirmer(
          context,
          titre: 'Supprimer le paquet ?',
          message:
              '« ${p.nom} » et ses ${_compteurs.total} cartes seront définitivement '
              'supprimés.',
        )) {
          await _base.supprimerPaquet(p.id!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paquet;
    final c = _compteurs;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.nom ?? ''),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              onSelected: _action,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renommer', child: Text('Renommer')),
                PopupMenuItem(value: 'importer', child: Text('Importer du texte')),
                PopupMenuItem(value: 'exporter', child: Text('Copier toutes les cartes')),
                PopupMenuItem(value: 'reinitialiser', child: Text('Recommencer à zéro')),
                PopupMenuItem(value: 'supprimer', child: Text('Supprimer le paquet')),
              ],
            ),
        ],
      ),
      floatingActionButton: p == null
          ? null
          : FloatingActionButton(
              tooltip: 'Ajouter une carte',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditeurCarte(paquetId: p.id!)),
              ),
              child: const Icon(Icons.add),
            ),
      body: !_charge
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Chiffre(
                              'Nouvelles',
                              c.nouvelles,
                              CouleursCompteurs.nouvelles(context),
                            ),
                            _Chiffre(
                              'Apprentissage',
                              c.apprentissage,
                              CouleursCompteurs.apprentissage(context),
                            ),
                            _Chiffre('À réviser', c.revision, CouleursCompteurs.revision(context)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: c.aFaire == 0
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EcranRevision(paquetId: widget.paquetId),
                                    ),
                                  ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(c.aFaire == 0 ? 'Rien à réviser' : 'Réviser'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _recherche,
                    onChanged: (_) => _charger(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Rechercher dans ${c.total} carte${c.total > 1 ? 's' : ''}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_cartes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      c.total == 0
                          ? 'Aucune carte. Appuie sur + pour en ajouter, ou importe une liste '
                                'depuis le menu ⋮.'
                          : 'Aucune carte ne correspond.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final carte in _cartes)
                  ListTile(
                    title: Text(carte.recto, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(carte.verso, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      etiquetteEtat(carte),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditeurCarte(paquetId: widget.paquetId, carte: carte),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// « Nouvelle », « Aujourd'hui », « Dans 12 j »…
String etiquetteEtat(Carte c, {DateTime? maintenant}) {
  final t = maintenant ?? DateTime.now();
  if (c.estNouvelle) return 'Nouvelle';
  if (c.enApprentissage) return 'Apprentissage';
  final jours = numeroJour(c.echeance) - numeroJour(t);
  if (jours <= 0) return 'Aujourd\'hui';
  if (jours == 1) return 'Demain';
  return 'Dans ${formaterDelai(Duration(days: jours))}';
}

class _Chiffre extends StatelessWidget {
  final String libelle;
  final int valeur;
  final Color couleur;
  const _Chiffre(this.libelle, this.valeur, this.couleur);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$valeur',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: couleur),
      ),
      Text(libelle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

import 'package:flutter/material.dart';

import '../db/base_donnees.dart';
import '../models/produit.dart';
import '../services/moteur_suggestions.dart';
import '../services/reglages.dart';
import '../services/sync_service.dart';
import '../theme.dart';

class EcranRepas extends StatefulWidget {
  const EcranRepas({super.key});

  @override
  State<EcranRepas> createState() => _EcranRepasState();
}

class _EcranRepasState extends State<EcranRepas> {
  final _moteur = MoteurSuggestions();
  List<Suggestion> _suggestions = [];
  int _nbStock = 0;
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
    super.dispose();
  }

  Future<void> _charger() async {
    final stock = await BaseDonnees.instance.lister();
    final s = _moteur.suggerer(stock);
    if (!mounted) return;
    setState(() {
      _suggestions = s;
      _nbStock = stock.length;
      _charge = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final soir = _moteur.suggestionDuJour(_suggestions);
    return Scaffold(
      appBar: AppBar(title: const Text('Repas')),
      body: !_charge
          ? const Center(child: CircularProgressIndicator())
          : _nbStock == 0
              ? _vide('Ton stock est vide',
                  'Ajoute des produits dans « Mon stock » pour recevoir des idées de repas anti-gaspi.')
              : _suggestions.isEmpty
                  ? _vide('Aucune idée pour l\'instant',
                      'Aucune recette ne correspond à ton stock actuel. Ajoute d\'autres produits pour en obtenir.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (soir != null) _bandeau(soir),
                        const SizedBox(height: 16),
                        for (final s in _suggestions) ...[
                          _CarteSuggestion(suggestion: s),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
    );
  }

  Widget _vide(String titre, String texte) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.restaurant_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(titre, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(texte, textAlign: TextAlign.center),
        ],
      );

  Widget _bandeau(Suggestion s) {
    final cs = Theme.of(context).colorScheme;
    final urgent = s.utilises.reduce((a, b) => a.joursRestants() <= b.joursRestants() ? a : b);
    return CarteApp(
      couleurFond: cs.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CE SOIR',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(s.recette.titre,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Sauve : ${urgent.nom} — ${libelleUrgence(urgent.joursRestants())}',
              style: TextStyle(color: cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _CarteSuggestion extends StatefulWidget {
  final Suggestion suggestion;
  const _CarteSuggestion({required this.suggestion});

  @override
  State<_CarteSuggestion> createState() => _CarteSuggestionState();
}

class _CarteSuggestionState extends State<_CarteSuggestion> {
  bool _ouverte = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final r = s.recette;
    final b = Theme.of(context).brightness;
    return CarteApp(
      onTap: () => setState(() => _ouverte = !_ouverte),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.titre,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Icon(_ouverte ? Icons.expand_less : Icons.expand_more),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.minutes} min · ${s.complete ? 'Tout est là' : 'Manque ${s.manquants.length}'}',
            style: TextStyle(
                color: s.complete ? couleurTexteUrgence(30, b) : couleurTexteUrgence(2, b),
                fontWeight: FontWeight.w600),
          ),
          if (_ouverte) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final Produit p in s.utilises)
                  Chip(
                    label: Text(p.nom),
                    side: BorderSide(color: couleurUrgence(p.joursRestants())),
                    avatar: CircleAvatar(backgroundColor: couleurUrgence(p.joursRestants()), radius: 6),
                  ),
                for (final m in s.manquants)
                  Chip(
                    label: Text('À acheter : $m'),
                    avatar: const Icon(Icons.shopping_cart_outlined, size: 16),
                  ),
              ],
            ),
            if (s.manquants.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final messager = ScaffoldMessenger.of(context);
                    var ajoutes = 0;
                    for (final m in s.manquants) {
                      if (await BaseDonnees.instance
                          .ajouterCourse(m, auteur: Reglages.instance.prenomOuNull)) {
                        ajoutes++;
                      }
                    }
                    SyncService.instance.planifier();
                    messager
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                          content: Text(ajoutes == 0
                              ? 'Déjà dans la liste de courses'
                              : '$ajoutes article(s) ajouté(s) à la liste de courses')));
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Ajouter les manquants aux courses'),
                ),
              ),
            const SizedBox(height: 10),
            Text(r.instructions),
            if (r.basiques.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Placard : ${r.basiques.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}

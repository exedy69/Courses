import 'package:flutter/material.dart';

import '../db/base_donnees.dart';
import '../models/produit.dart';
import '../services/service_notifications.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import '../widgets/miniature.dart';
import '../widgets/saisie_date.dart';
import 'ajout.dart';
import 'scan.dart';

enum _Filtre { tout, urgent, semaine }

class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil> {
  List<Produit> _produits = [];
  Map<String, String> _images = {};
  _Filtre _filtre = _Filtre.tout;
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
    final liste = await BaseDonnees.instance.listerAvecImages();
    if (!mounted) return;
    setState(() {
      _produits = [for (final l in liste) l.produit];
      _images = {
        for (final l in liste)
          if (l.imageUrl != null) l.produit.uuid: l.imageUrl!,
      };
      _charge = true;
    });
  }

  List<Produit> get _visibles {
    switch (_filtre) {
      case _Filtre.tout:
        return _produits;
      case _Filtre.urgent:
        return _produits.where((p) => p.joursRestants() <= 3).toList();
      case _Filtre.semaine:
        return _produits.where((p) => p.joursRestants() <= 7).toList();
    }
  }

  /// Demande combien d'unités sont concernées quand il y en a plusieurs.
  Future<int?> _demanderNombre(Produit p, String issue) {
    var n = p.quantite;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) => AlertDialog(
          title: Text(issue == 'consomme' ? 'Combien de consommés ?' : 'Combien de jetés ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${p.nom} (×${p.quantite})'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                      onPressed: n > 1 ? () => maj(() => n--) : null,
                      icon: const Icon(Icons.remove)),
                  SizedBox(
                    width: 56,
                    child: Text('$n',
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.headlineSmall),
                  ),
                  IconButton.filledTonal(
                      onPressed: n < p.quantite ? () => maj(() => n++) : null,
                      icon: const Icon(Icons.add)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, n), child: const Text('Valider')),
          ],
        ),
      ),
    );
  }

  /// Appelé par le glissement. Renvoie vrai si la carte doit disparaître.
  Future<bool> _surGlissement(Produit p, String issue) async {
    var nombre = p.quantite;
    if (p.quantite > 1) {
      final choix = await _demanderNombre(p, issue);
      if (choix == null) return false;
      nombre = choix;
    }
    final archivage = await BaseDonnees.instance.archiver(p, issue, nombre: nombre);
    SyncService.instance.planifier();
    if (!mounted) return true;
    final quoi = nombre > 1 || p.quantite > 1 ? '$nombre × ${p.nom}' : p.nom;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(issue == 'consomme' ? 'Consommé : $quoi' : 'Jeté : $quoi'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () async {
            await BaseDonnees.instance.annulerArchivage(archivage);
            SyncService.instance.planifier();
          },
        ),
      ));
    // S'il reste des unités, la carte reste en place (la liste se recharge).
    return nombre >= p.quantite;
  }

  Future<void> _rafraichir() async {
    await _charger();
    await SyncService.instance.synchroniser(complet: true);
    await ServiceNotifications.instance.reprogrammer().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final nbUrgent = _produits.where((p) => p.joursRestants() <= 3).length;
    final visibles = _visibles;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon stock')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'manuel',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EcranAjout())),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Saisie manuelle'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EcranScan())),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Tout (${_produits.length})'),
                  selected: _filtre == _Filtre.tout,
                  onSelected: (_) => setState(() => _filtre = _Filtre.tout),
                ),
                ChoiceChip(
                  label: Text('Urgent ($nbUrgent)'),
                  selected: _filtre == _Filtre.urgent,
                  onSelected: (_) => setState(() => _filtre = _Filtre.urgent),
                ),
                ChoiceChip(
                  label: const Text('Cette semaine'),
                  selected: _filtre == _Filtre.semaine,
                  onSelected: (_) => setState(() => _filtre = _Filtre.semaine),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _rafraichir,
              child: !_charge
                  ? const Center(child: CircularProgressIndicator())
                  : visibles.isEmpty
                      ? _etatVide()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 190),
                          itemCount: visibles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _carte(visibles[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etatVide() {
    final stockVide = _produits.isEmpty;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(stockVide ? Icons.kitchen_outlined : Icons.check_circle_outline,
            size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          stockVide ? 'Ton frigo est vide' : 'Rien d\'urgent',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          stockVide
              ? 'Scanne tes courses ou ajoute un produit à la main avec les boutons en bas.'
              : 'Aucun produit ne périme bientôt dans ce filtre.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _carte(Produit p) {
    final jours = p.joursRestants();
    final couleur = couleurUrgence(jours);
    final texte = couleurTexteUrgence(jours, Theme.of(context).brightness);
    return Dismissible(
      key: ValueKey(p.uuid),
      background: _fondGlisse(Colors.green.shade700, Icons.check, 'Consommé', Alignment.centerLeft),
      secondaryBackground:
          _fondGlisse(Colors.red.shade700, Icons.delete_outline, 'Jeté', Alignment.centerRight),
      confirmDismiss: (dir) =>
          _surGlissement(p, dir == DismissDirection.startToEnd ? 'consomme' : 'jete'),
      onDismissed: (_) => setState(() => _produits.removeWhere((x) => x.uuid == p.uuid)),
      child: CarteApp(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => EcranAjout(produit: p))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: couleur),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Miniature(photoPath: p.photoPath, imageUrl: _images[p.uuid]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.nom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${libelleUrgence(jours)} · ${formatDateCourte(p.datePeremption)}',
                          style: TextStyle(color: texte, fontWeight: FontWeight.w600)),
                      if (p.auteur != null && p.auteur!.isNotEmpty)
                        Text('Ajouté par ${p.auteur}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              if (p.quantite > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('×${p.quantite}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSecondaryContainer)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fondGlisse(Color c, IconData icone, String texte, Alignment al) {
    return Container(
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
      alignment: al,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (al == Alignment.centerLeft) Icon(icone, color: Colors.white),
          const SizedBox(width: 8),
          Text(texte, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (al == Alignment.centerRight) Icon(icone, color: Colors.white),
        ],
      ),
    );
  }
}


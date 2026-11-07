import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/durees.dart';
import '../db/base_donnees.dart';
import '../models/catalogue_item.dart';
import '../models/produit.dart';
import '../services/catalogue_service.dart';
import '../services/sync_service.dart';
import '../widgets/miniature.dart';
import '../widgets/saisie_date.dart';

class ResultatFeuille {
  final String nom;
  final int quantite;
  final DateTime date;
  const ResultatFeuille(this.nom, this.quantite, this.date);
}

/// Durée pré-remplie : catalogue → catégories OFF → nom → +7 jours.
int dureeInitiale(CatalogueItem item) =>
    item.dureeHabituelleJours ??
    dureeDepuisCategories(item.categorie) ??
    dureeDepuisNom(item.nom) ??
    7;

String? libelleCategorie(String? tags) {
  if (tags == null || tags.isEmpty) return null;
  final dernier = tags.split(',').last;
  final sansPrefixe = dernier.contains(':') ? dernier.split(':').last : dernier;
  return sansPrefixe.replaceAll('-', ' ');
}

class EcranScan extends StatefulWidget {
  const EcranScan({super.key});

  @override
  State<EcranScan> createState() => _EcranScanState();
}

class _EcranScanState extends State<EcranScan> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _service = CatalogueService();
  bool _occupe = false;
  bool _recherche = false;
  bool _lampe = false;
  double _zoom = 0;
  int _scannes = 0;
  String? _dernierCode;
  DateTime _dernierInstant = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _surDetection(BarcodeCapture capture) {
    if (_occupe) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((c) => c != null && c.isNotEmpty, orElse: () => null);
    if (code == null) return;
    final maintenant = DateTime.now();
    if (code == _dernierCode &&
        maintenant.difference(_dernierInstant) < const Duration(seconds: 2)) {
      return;
    }
    _dernierCode = code;
    _dernierInstant = maintenant;
    _traiter(code);
  }

  Future<void> _traiter(String code) async {
    if (_occupe) return;
    _occupe = true;
    HapticFeedback.mediumImpact();
    try {
      setState(() => _recherche = true);
      final res = await _service.resoudre(code);
      if (mounted) setState(() => _recherche = false);
      CatalogueItem? item = res.item;
      if (item == null) {
        if (!mounted) return;
        final nom = await _demanderNom(code, res.horsLigne);
        if (nom == null || nom.trim().isEmpty) return;
        item = await _service.enregistrerManuel(code, nom);
      }
      if (!mounted) return;
      await _ouvrirFeuille(item);
    } finally {
      if (mounted) setState(() => _recherche = false);
      _dernierInstant = DateTime.now();
      _occupe = false;
    }
  }

  Future<String?> _demanderNom(String code, bool horsLigne) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produit inconnu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(horsLigne
                ? 'Pas de réseau pour le retrouver. Donne-lui un nom : il sera retenu pour la prochaine fois.'
                : 'Code $code introuvable. Donne-lui un nom : il sera retenu pour la prochaine fois.'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nom du produit', border: OutlineInputBorder()),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ignorer')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Enregistrer')),
        ],
      ),
    );
  }

  Future<void> _ouvrirFeuille(CatalogueItem item) async {
    final res = await showModalBottomSheet<ResultatFeuille>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FeuilleProduit(item: item),
    );
    if (res == null) return;
    final produit = Produit(
      codeBarres: item.codeBarres,
      nom: res.nom,
      datePeremption: res.date,
      quantite: res.quantite,
      categorie: libelleCategorie(item.categorie),
    );
    await BaseDonnees.instance.ajouter(produit);
    final duree = res.date.difference(aujourdhui()).inDays;
    await _service.memoriser(item,
        nom: res.nom != item.nom ? res.nom : null, duree: duree < 0 ? 0 : duree);
    SyncService.instance.planifier();
    if (mounted) setState(() => _scannes++);
  }

  Future<void> _saisirCode() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisir le code-barres'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Chiffres sous le code-barres', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider')),
        ],
      ),
    );
    final propre = code?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (propre.length >= 6) _traiter(propre);
  }

  Widget _erreur(BuildContext context, MobileScannerException e) {
    final refuse = e.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(
            refuse
                ? 'L\'accès à la caméra est refusé. Frigo Malin en a besoin pour lire les codes-barres.'
                : 'La caméra n\'a pas pu démarrer.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (refuse)
            FilledButton.icon(
              onPressed: () => AppSettings.openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Ouvrir les réglages de l\'appli'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saisirCode,
            child: const Text('Saisir le code à la main'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _surDetection,
            errorBuilder: _erreur,
          ),
          // Cadre de visée large
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.88,
                child: AspectRatio(
                  aspectRatio: 2.2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Retour',
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          await _controller.toggleTorch();
                          if (mounted) setState(() => _lampe = !_lampe);
                        },
                        icon: Icon(_lampe ? Icons.flash_on : Icons.flash_off,
                            color: _lampe ? Colors.amber : Colors.white),
                        tooltip: 'Lampe',
                      ),
                    ],
                  ),
                ),
                if (_recherche)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Chip(
                        avatar: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        label: Text('Recherche du produit…')),
                  ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Recule d\'une dizaine de centimètres si l\'image est floue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          onChanged: (v) {
                            setState(() => _zoom = v);
                            _controller.setZoomScale(v);
                          },
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white70),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: Colors.black54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_scannes produit(s) scanné(s)',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _saisirCode,
                                icon: const Icon(Icons.dialpad),
                                label: const Text('Saisir le code'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Terminer'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille modale en bas d'écran (la caméra reste active derrière).
class FeuilleProduit extends StatefulWidget {
  final CatalogueItem item;
  const FeuilleProduit({super.key, required this.item});

  @override
  State<FeuilleProduit> createState() => _FeuilleProduitState();
}

class _FeuilleProduitState extends State<FeuilleProduit> {
  late final TextEditingController _nom;
  late DateTime _date;
  int _quantite = 1;

  @override
  void initState() {
    super.initState();
    _nom = TextEditingController(text: widget.item.nom);
    _date = aujourdhui().add(Duration(days: dureeInitiale(widget.item)));
  }

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Miniature(imageUrl: it.imageUrl, taille: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nom,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Nom', border: OutlineInputBorder(), isDense: true),
                      ),
                      if (it.marque != null && it.marque!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(it.marque!, style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DateAvecUrgence(date: _date),
            const SizedBox(height: 8),
            RaccourcisDate(date: _date, onChange: (d) => setState(() => _date = d)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Quantité', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                SelecteurQuantite(valeur: _quantite, onChange: (v) => setState(() => _quantite = v)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final nom = _nom.text.trim();
                        if (nom.isEmpty) return;
                        Navigator.pop(context, ResultatFeuille(nom, _quantite, _date));
                      },
                      child: const Text('Enregistrer et scanner le suivant'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

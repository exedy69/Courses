import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/durees.dart';
import '../db/base_donnees.dart';
import '../models/produit.dart';
import '../services/reglages.dart';
import '../services/sync_service.dart';
import '../widgets/miniature.dart';
import '../widgets/saisie_date.dart';

class EcranAjout extends StatefulWidget {
  /// Null en création.
  final Produit? produit;
  const EcranAjout({super.key, this.produit});

  @override
  State<EcranAjout> createState() => _EcranAjoutState();
}

class _EcranAjoutState extends State<EcranAjout> {
  final _nom = TextEditingController();
  final _code = TextEditingController();
  final _focusNom = FocusNode();
  late DateTime _date;
  int _quantite = 1;
  String? _photo;
  bool _dateChoisieAMain = false;
  int _ajoutes = 0;

  bool get _edition => widget.produit != null;

  @override
  void initState() {
    super.initState();
    final pr = widget.produit;
    if (pr != null) {
      _nom.text = pr.nom;
      _code.text = pr.codeBarres ?? '';
      _date = pr.datePeremption;
      _quantite = pr.quantite;
      _photo = pr.photoPath;
      _dateChoisieAMain = true;
    } else {
      _date = aujourdhui().add(const Duration(days: 7));
      _nom.addListener(_prerempliDate);
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _code.dispose();
    _focusNom.dispose();
    super.dispose();
  }

  void _prerempliDate() {
    if (_dateChoisieAMain) return;
    final d = dureeDepuisNom(_nom.text);
    if (d != null) {
      setState(() => _date = aujourdhui().add(Duration(days: d)));
    }
  }

  Future<void> _prendrePhoto() async {
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 70, maxWidth: 1200);
      if (f == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final dossier = Directory(p.join(docs.path, 'photos'));
      await dossier.create(recursive: true);
      final dest = p.join(dossier.path, '${nouvelUuid()}.jpg');
      await File(f.path).copy(dest);
      if (mounted) setState(() => _photo = dest);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo impossible : autorise la caméra dans les réglages.')));
      }
    }
  }

  Future<bool> _enregistrer() async {
    final nom = neutraliserFormule(_nom.text);
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donne un nom au produit.')));
      _focusNom.requestFocus();
      return false;
    }
    final code = _code.text.trim();
    final base = BaseDonnees.instance;
    if (_edition) {
      final pr = widget.produit!;
      pr.nom = nom;
      pr.codeBarres = code.isEmpty ? null : code;
      pr.datePeremption = _date;
      pr.quantite = _quantite;
      pr.photoPath = _photo;
      await base.modifier(pr);
    } else {
      await base.ajouter(Produit(
        nom: nom,
        codeBarres: code.isEmpty ? null : code,
        datePeremption: _date,
        quantite: _quantite,
        photoPath: _photo,
        auteur: Reglages.instance.prenomOuNull,
      ));
    }
    SyncService.instance.planifier();
    return true;
  }

  Future<void> _enregistrerEtFermer() async {
    if (await _enregistrer() && mounted) Navigator.pop(context, true);
  }

  Future<void> _enregistrerEtSuivant() async {
    if (!await _enregistrer()) return;
    setState(() {
      _ajoutes++;
      _nom.clear();
      _code.clear();
      _quantite = 1;
      _photo = null;
    });
    _focusNom.requestFocus();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
          content: Text('Enregistré'), duration: Duration(milliseconds: 900)));
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text(widget.produit!.nom),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await BaseDonnees.instance.supprimer(widget.produit!);
      SyncService.instance.planifier();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edition ? 'Modifier le produit' : 'Ajouter un produit'),
        actions: [
          if (_edition)
            IconButton(
                onPressed: _supprimer,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nom,
                    focusNode: _focusNom,
                    autofocus: !_edition,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Nom du produit', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Code-barres (facultatif)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  Text('Date de péremption', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  DateAvecUrgence(date: _date),
                  const SizedBox(height: 8),
                  RaccourcisDate(
                    date: _date,
                    onChange: (d) => setState(() {
                      _date = d;
                      _dateChoisieAMain = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Quantité', style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      SelecteurQuantite(
                          valeur: _quantite, onChange: (v) => setState(() => _quantite = v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Miniature(photoPath: _photo, taille: 64),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _prendrePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(_photo == null ? 'Ajouter une photo' : 'Changer la photo'),
                      ),
                      if (_photo != null)
                        IconButton(
                            onPressed: () => setState(() => _photo = null),
                            icon: const Icon(Icons.close),
                            tooltip: 'Retirer la photo'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _edition
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                          onPressed: _enregistrerEtFermer, child: const Text('Enregistrer')),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_ajoutes > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('$_ajoutes produit(s) ajouté(s)'),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                    onPressed: _enregistrerEtFermer,
                                    child: const Text('Enregistrer et fermer')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: FilledButton(
                                    onPressed: _enregistrerEtSuivant,
                                    child: const Text('Enregistrer et suivant')),
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
    );
  }
}

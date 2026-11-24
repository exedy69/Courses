import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../db/base_donnees.dart';
import '../theme.dart';

class EcranReglages extends StatefulWidget {
  const EcranReglages({super.key});

  @override
  State<EcranReglages> createState() => _EcranReglagesState();
}

class _EcranReglagesState extends State<EcranReglages> {
  final _base = BaseDonnees.instance;
  int _nouvelles = 20;
  int _revisions = 200;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final n = await _base.nouvellesParJour();
    final r = await _base.revisionsParJour();
    if (mounted) {
      setState(() {
        _nouvelles = n;
        _revisions = r;
      });
    }
  }

  Future<void> _choisirLimite(String cle, String titre, int actuelle, int maxi) async {
    final txt = await demanderTexte(
      context,
      titre: titre,
      initial: '$actuelle',
      libelle: 'Nombre par jour (0 à $maxi)',
    );
    final v = int.tryParse(txt ?? '');
    if (v == null) return;
    await _base.ecrireReglage(cle, '${v.clamp(0, maxi)}');
    await _charger();
  }

  Future<void> _sauvegarder() async {
    final json = jsonEncode(await _base.exporterTout());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    afficherMessage(
      context,
      'Sauvegarde copiée (${(json.length / 1024).toStringAsFixed(0)} Ko). Colle-la dans une note ou un e-mail.',
    );
  }

  Future<void> _restaurer() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final texte = d?.text?.trim() ?? '';
    if (!mounted) return;
    Map<String, Object?> s;
    try {
      s = Map<String, Object?>.from(jsonDecode(texte) as Map);
      if (s['format'] != 'memo-flash') throw const FormatException();
    } catch (_) {
      afficherMessage(context, 'Le presse-papiers ne contient pas de sauvegarde Mémo Flash.');
      return;
    }
    final n = (s['cartes'] as List?)?.length ?? 0;
    if (!await confirmer(
      context,
      titre: 'Restaurer la sauvegarde ?',
      message:
          'Toutes les données actuelles seront remplacées par la sauvegarde '
          '($n cartes).',
      ok: 'Restaurer',
    )) {
      return;
    }
    try {
      await _base.restaurerTout(s);
      if (mounted) afficherMessage(context, 'Sauvegarde restaurée.');
    } catch (e) {
      if (mounted) afficherMessage(context, 'Restauration impossible : sauvegarde abîmée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titre = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary);
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Révision', style: titre),
          ),
          ListTile(
            leading: const Icon(Icons.fiber_new_outlined),
            title: const Text('Nouvelles cartes par jour'),
            subtitle: Text('$_nouvelles par paquet'),
            onTap: () =>
                _choisirLimite('nouvelles_par_jour', 'Nouvelles cartes par jour', _nouvelles, 9999),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Révisions maximum par jour'),
            subtitle: Text('$_revisions par paquet'),
            onTap: () => _choisirLimite(
              'revisions_par_jour',
              'Révisions maximum par jour',
              _revisions,
              99999,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Apparence', style: titre),
          ),
          ValueListenableBuilder(
            valueListenable: modeTheme,
            builder: (context, mode, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Système')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
                ],
                selected: {mode},
                onSelectionChanged: (s) {
                  modeTheme.value = s.first;
                  _base.ecrireReglage('theme', texteDepuisMode(s.first));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Sauvegarde', style: titre),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: const Text('Copier une sauvegarde complète'),
            subtitle: const Text('Paquets, cartes et progression, dans le presse-papiers.'),
            onTap: _sauvegarder,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurer depuis le presse-papiers'),
            subtitle: const Text('Remplace toutes les données actuelles.'),
            onTap: _restaurer,
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Les données restent sur ce téléphone, sans compte ni connexion. '
              'Pense à copier une sauvegarde de temps en temps : désinstaller l\'appli efface tout.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

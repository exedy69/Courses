import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../db/base_donnees.dart';
import '../models/carte.dart';
import '../models/paquet.dart';
import '../services/planificateur.dart';
import '../theme.dart';
import 'editeur_carte.dart';

class EcranRevision extends StatefulWidget {
  final int paquetId;
  const EcranRevision({super.key, required this.paquetId});

  @override
  State<EcranRevision> createState() => _EcranRevisionState();
}

class _EcranRevisionState extends State<EcranRevision> {
  final _base = BaseDonnees.instance;
  final _planif = Planificateur(alea: Random());
  final _annulables = <ReponseEnregistree>[];

  String _nomPaquet = '';
  Carte? _carte;
  Compteurs _compteurs = const Compteurs();
  bool _reponse = false;
  bool _charge = false;
  bool _occupe = false;
  int _vues = 0;
  int _plusTard = 0;

  @override
  void initState() {
    super.initState();
    _suivante();
  }

  Future<void> _suivante({int? sauf}) async {
    final p = await _base.paquet(widget.paquetId);
    final carte = await _base.prochaineCarte(widget.paquetId, sauf: sauf);
    final c = await _base.compteurs(widget.paquetId);
    final plusTard = carte == null ? await _base.apprentissagePlusTard(widget.paquetId) : 0;
    if (!mounted) return;
    setState(() {
      _nomPaquet = p?.nom ?? '';
      _carte = carte;
      _compteurs = c;
      _plusTard = plusTard;
      _reponse = false;
      _charge = true;
      _occupe = false;
    });
  }

  Future<void> _repondre(Note note) async {
    final c = _carte;
    if (c == null || _occupe) return;
    _occupe = true;
    final r = await _base.repondre(c, note, planif: _planif);
    _annulables.add(r);
    if (_annulables.length > 20) _annulables.removeAt(0);
    _vues++;
    await _suivante(sauf: c.id);
  }

  Future<void> _annuler() async {
    if (_annulables.isEmpty || _occupe) return;
    _occupe = true;
    final r = _annulables.removeLast();
    await _base.annuler(r);
    _vues = max(0, _vues - 1);
    final carte = await _base.carte(r.avant.id!);
    final c = await _base.compteurs(widget.paquetId);
    if (!mounted) return;
    setState(() {
      _carte = carte;
      _compteurs = c;
      _reponse = false;
      _occupe = false;
    });
  }

  Future<void> _modifier() async {
    final c = _carte;
    if (c == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditeurCarte(paquetId: c.paquetId, carte: c),
      ),
    );
    final maj = await _base.carte(c.id!);
    if (!mounted) return;
    if (maj == null) {
      await _suivante();
    } else {
      setState(() => _carte = maj);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _carte;
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomPaquet),
        actions: [
          IconButton(
            tooltip: 'Annuler la dernière réponse',
            onPressed: _annulables.isEmpty ? null : _annuler,
            icon: const Icon(Icons.undo),
          ),
          if (c != null)
            IconButton(
              tooltip: 'Modifier la carte',
              onPressed: _modifier,
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SafeArea(
        child: !_charge
            ? const Center(child: CircularProgressIndicator())
            : c == null
            ? _Fin(vues: _vues, plusTard: _plusTard)
            : _vueCarte(c),
      ),
    );
  }

  Widget _vueCarte(Carte c) {
    final theme = Theme.of(context);
    final t = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _CompteursSeance(compteurs: _compteurs, carte: c),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _reponse ? null : () => setState(() => _reponse = true),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  SelectableText(
                    c.recto,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (_reponse) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(thickness: 1),
                    ),
                    SelectableText(
                      c.verso,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: !_reponse
              ? SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.tonal(
                    onPressed: () => setState(() => _reponse = true),
                    child: const Text('Afficher la réponse', style: TextStyle(fontSize: 16)),
                  ),
                )
              : Row(
                  children: [
                    for (final n in Note.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _BoutonNote(
                            note: n,
                            delai: formaterDelai(_planif.apercu(c, n, t)),
                            onTap: () => _repondre(n),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CompteursSeance extends StatelessWidget {
  final Compteurs compteurs;
  final Carte carte;
  const _CompteursSeance({required this.compteurs, required this.carte});

  @override
  Widget build(BuildContext context) {
    Widget n(int v, Color couleur, bool courant) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '$v',
        style: TextStyle(
          fontSize: 16,
          color: couleur,
          fontWeight: courant ? FontWeight.bold : FontWeight.normal,
          decoration: courant ? TextDecoration.underline : null,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        n(compteurs.nouvelles, CouleursCompteurs.nouvelles(context), carte.estNouvelle),
        n(compteurs.apprentissage, CouleursCompteurs.apprentissage(context), carte.enApprentissage),
        n(
          compteurs.revision,
          CouleursCompteurs.revision(context),
          carte.etat == EtatCarte.revision,
        ),
      ],
    );
  }
}

class _BoutonNote extends StatelessWidget {
  final Note note;
  final String delai;
  final VoidCallback onTap;
  const _BoutonNote({required this.note, required this.delai, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurNote(context, note.index);
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: couleur, width: 1.5),
          foregroundColor: couleur,
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(delai, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                note.libelle,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fin extends StatelessWidget {
  final int vues;
  final int plusTard;
  const _Fin({required this.vues, required this.plusTard});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Bravo !', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            [
              if (vues > 0) '$vues réponse${vues > 1 ? 's' : ''} pendant cette séance.',
              'Tu as fini ce paquet pour le moment.',
              if (plusTard > 0)
                '$plusTard carte${plusTard > 1 ? 's' : ''} en apprentissage '
                    'reviendr${plusTard > 1 ? 'ont' : 'a'} un peu plus tard.',
            ].join('\n'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminer')),
        ],
      ),
    ),
  );
}

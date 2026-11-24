import 'package:material_ui/material_ui.dart';

import '../db/base_donnees.dart';
import '../models/carte.dart';
import '../theme.dart';

/// Ajout (rafale : l'écran reste ouvert) ou modification d'une carte.
class EditeurCarte extends StatefulWidget {
  final int paquetId;
  final Carte? carte;
  const EditeurCarte({super.key, required this.paquetId, this.carte});

  @override
  State<EditeurCarte> createState() => _EditeurCarteState();
}

class _EditeurCarteState extends State<EditeurCarte> {
  final _base = BaseDonnees.instance;
  late final _recto = TextEditingController(text: widget.carte?.recto ?? '');
  late final _verso = TextEditingController(text: widget.carte?.verso ?? '');
  final _focusRecto = FocusNode();
  bool _inverse = false;
  int _ajoutees = 0;

  bool get _modification => widget.carte != null;
  bool get _valide => _recto.text.trim().isNotEmpty && _verso.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _recto.addListener(() => setState(() {}));
    _verso.addListener(() => setState(() {}));
    _base.lireReglage('inverse_par_defaut').then((v) {
      if (mounted && v == '1' && !_modification) setState(() => _inverse = true);
    });
  }

  @override
  void dispose() {
    _recto.dispose();
    _verso.dispose();
    _focusRecto.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_valide) return;
    if (_modification) {
      await _base.modifierCarte(
        widget.carte!.copier(recto: _recto.text.trim(), verso: _verso.text.trim()),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    final c = Carte.nouvelle(paquetId: widget.paquetId, recto: _recto.text, verso: _verso.text);
    await _base.ajouterCartes([c, if (_inverse) c.inverse()]);
    await _base.ecrireReglage('inverse_par_defaut', _inverse ? '1' : '0');
    if (!mounted) return;
    setState(() => _ajoutees += _inverse ? 2 : 1);
    _recto.clear();
    _verso.clear();
    _focusRecto.requestFocus();
    afficherMessage(context, _inverse ? '2 cartes ajoutées' : 'Carte ajoutée');
  }

  Future<void> _supprimer() async {
    if (!await confirmer(
      context,
      titre: 'Supprimer la carte ?',
      message: 'Elle et son historique seront perdus.',
    )) {
      return;
    }
    await _base.supprimerCarte(widget.carte!.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _oublier() async {
    await _base.modifierCarte(widget.carte!.oublier(DateTime.now()));
    if (!mounted) return;
    afficherMessage(context, 'La carte redevient nouvelle.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modification
              ? 'Modifier la carte'
              : _ajoutees == 0
              ? 'Nouvelle carte'
              : 'Nouvelle carte ($_ajoutees ajoutée${_ajoutees > 1 ? 's' : ''})',
        ),
        actions: [
          if (_modification)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'oublier' ? _oublier() : _supprimer(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'oublier', child: Text('Remettre en nouvelle')),
                PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _recto,
            focusNode: _focusRecto,
            autofocus: !_modification,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Recto (question)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _verso,
            minLines: 2,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Verso (réponse)',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_modification)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _inverse,
              onChanged: (v) => setState(() => _inverse = v),
              title: const Text('Créer aussi la carte inverse'),
              subtitle: const Text('Pour réviser dans les deux sens (verso → recto).'),
            ),
          if (_modification) ...[const SizedBox(height: 16), _Infos(widget.carte!)],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _valide ? _enregistrer : null,
            icon: Icon(_modification ? Icons.check : Icons.add),
            label: Text(_modification ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _Infos extends StatelessWidget {
  final Carte c;
  const _Infos(this.c);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Text(
      [
        'Révisions : ${c.repetitions}',
        'Oublis : ${c.oublis}',
        if (c.etat == EtatCarte.revision) 'Intervalle : ${c.intervalle} j',
        'Facilité : ${(c.facilite / 10).round()} %',
      ].join('  ·  '),
      style: style,
    );
  }
}

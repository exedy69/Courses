import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../db/base_donnees.dart';
import '../models/carte.dart';
import '../services/import_texte.dart';
import '../theme.dart';

/// Import d'une liste collée : une carte par ligne, « recto ; verso ».
class EcranImport extends StatefulWidget {
  final int paquetId;
  const EcranImport({super.key, required this.paquetId});

  @override
  State<EcranImport> createState() => _EcranImportState();
}

class _EcranImportState extends State<EcranImport> {
  final _texte = TextEditingController();
  bool _inverse = false;
  AnalyseImport _analyse = const AnalyseImport([], []);

  @override
  void initState() {
    super.initState();
    _texte.addListener(() => setState(() => _analyse = analyserTexte(_texte.text)));
  }

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _coller() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t != null && t.isNotEmpty) _texte.text = t;
  }

  Future<void> _importer() async {
    final cartes = <Carte>[
      for (final p in _analyse.paires) ...[
        Carte.nouvelle(paquetId: widget.paquetId, recto: p.recto, verso: p.verso),
        if (_inverse) Carte.nouvelle(paquetId: widget.paquetId, recto: p.verso, verso: p.recto),
      ],
    ];
    final n = await BaseDonnees.instance.ajouterCartes(cartes);
    if (!mounted) return;
    afficherMessage(context, '$n carte${n > 1 ? 's' : ''} importée${n > 1 ? 's' : ''}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = _analyse;
    final n = a.paires.length * (_inverse ? 2 : 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importer du texte'),
        actions: [
          IconButton(tooltip: 'Coller', onPressed: _coller, icon: const Icon(Icons.content_paste)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Une carte par ligne : le recto, puis une tabulation, un « ; » ou un '
            '« = », puis le verso. Les lignes vides ou commençant par # sont ignorées. '
            'Un export texte d\'Anki ou deux colonnes copiées depuis un tableur '
            'fonctionnent aussi.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texte,
            minLines: 8,
            maxLines: 20,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'chat ; cat\nchien ; dog\nmaison = house',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _inverse,
            onChanged: (v) => setState(() => _inverse = v),
            title: const Text('Créer aussi les cartes inverses'),
          ),
          if (a.lignesIgnorees.isNotEmpty)
            Text(
              'Lignes ignorées (pas de séparateur ou côté vide) : '
              '${a.lignesIgnorees.take(15).join(', ')}${a.lignesIgnorees.length > 15 ? '…' : ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (a.paires.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Aperçu', style: Theme.of(context).textTheme.titleSmall),
            for (final p in a.paires.take(3))
              ListTile(dense: true, title: Text(p.recto), subtitle: Text(p.verso)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: n == 0 ? null : _importer,
            icon: const Icon(Icons.download),
            label: Text(n == 0 ? 'Importer' : 'Importer $n carte${n > 1 ? 's' : ''}'),
          ),
        ],
      ),
    );
  }
}

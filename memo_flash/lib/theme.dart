import 'package:material_ui/material_ui.dart';

/// Couleurs des compteurs, comme dans Anki : bleu = nouvelles,
/// rouge = en apprentissage, vert = à réviser.
class CouleursCompteurs {
  static Color nouvelles(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF7FB3FF) : const Color(0xFF1565C0);
  static Color apprentissage(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
  static Color revision(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
}

/// Couleurs des quatre boutons de réponse.
Color couleurNote(BuildContext c, int indice) {
  final sombre = Theme.of(c).brightness == Brightness.dark;
  const clair = [Color(0xFFC62828), Color(0xFFEF6C00), Color(0xFF2E7D32), Color(0xFF1565C0)];
  const fonce = [Color(0xFFFF8A80), Color(0xFFFFB74D), Color(0xFF81C784), Color(0xFF7FB3FF)];
  return (sombre ? fonce : clair)[indice];
}

/// Thème choisi dans les réglages (système, clair ou sombre).
final modeTheme = ValueNotifier(ThemeMode.system);

const _graine = Color(0xFF5E35B1);

ThemeData themeClair() =>
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _graine), useMaterial3: true);

ThemeData themeSombre() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _graine, brightness: Brightness.dark),
  useMaterial3: true,
);

ThemeMode modeDepuisTexte(String? v) => switch (v) {
  'clair' => ThemeMode.light,
  'sombre' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String texteDepuisMode(ThemeMode m) => switch (m) {
  ThemeMode.light => 'clair',
  ThemeMode.dark => 'sombre',
  ThemeMode.system => 'systeme',
};

/// Les trois compteurs colorés d'un paquet.
class LigneCompteurs extends StatelessWidget {
  final int nouvelles;
  final int apprentissage;
  final int revision;
  final double taille;

  const LigneCompteurs({
    super.key,
    required this.nouvelles,
    required this.apprentissage,
    required this.revision,
    this.taille = 15,
  });

  @override
  Widget build(BuildContext context) {
    Widget n(int v, Color c, String aide) => Tooltip(
      message: aide,
      child: SizedBox(
        width: taille * 2.6,
        child: Text(
          '$v',
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: taille,
            fontWeight: FontWeight.w600,
            color: v == 0 ? Theme.of(context).disabledColor : c,
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        n(nouvelles, CouleursCompteurs.nouvelles(context), 'Nouvelles'),
        n(apprentissage, CouleursCompteurs.apprentissage(context), 'En apprentissage'),
        n(revision, CouleursCompteurs.revision(context), 'À réviser'),
      ],
    );
  }
}

/// Boîte de dialogue de saisie d'un texte court. Renvoie `null` si annulée.
Future<String?> demanderTexte(
  BuildContext context, {
  required String titre,
  String initial = '',
  String libelle = 'Nom',
  String ok = 'OK',
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: libelle),
        onSubmitted: (v) => Navigator.pop(c, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            Navigator.pop(c, v.isEmpty ? null : v);
          },
          child: Text(ok),
        ),
      ],
    ),
  );
}

/// Demande confirmation d'une action. Renvoie vrai si confirmée.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String ok = 'Supprimer',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void afficherMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

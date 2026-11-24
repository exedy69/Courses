import '../models/carte.dart';

/// Une paire recto/verso lue dans un texte collé.
typedef Paire = ({String recto, String verso});

/// Résultat d'une analyse : paires valides et lignes ignorées.
class AnalyseImport {
  final List<Paire> paires;
  final List<int> lignesIgnorees; // numéros de ligne (à partir de 1)
  const AnalyseImport(this.paires, this.lignesIgnorees);
}

/// Lit un texte au format « recto, séparateur, verso », une carte par ligne.
/// Séparateurs reconnus, par ordre de priorité : tabulation (export Anki, tableur),
/// point-virgule, « = ». Les lignes vides et celles commençant par `#` sont ignorées.
AnalyseImport analyserTexte(String texte) {
  final paires = <Paire>[];
  final ignorees = <int>[];
  final lignes = texte.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  for (var i = 0; i < lignes.length; i++) {
    final ligne = lignes[i];
    if (ligne.trim().isEmpty || ligne.trimLeft().startsWith('#')) continue;
    final paire = _decouper(ligne);
    if (paire == null) {
      ignorees.add(i + 1);
    } else {
      paires.add(paire);
    }
  }
  return AnalyseImport(paires, ignorees);
}

Paire? _decouper(String ligne) {
  for (final sep in const ['\t', ';', '=']) {
    final i = ligne.indexOf(sep);
    if (i < 0) continue;
    final recto = _deballer(ligne.substring(0, i));
    final verso = _deballer(ligne.substring(i + sep.length));
    if (recto.isEmpty || verso.isEmpty) return null;
    return (recto: recto, verso: verso);
  }
  return null;
}

/// Retire les espaces et d'éventuels guillemets englobants ; `<br>` devient un retour à la ligne.
String _deballer(String s) {
  var t = s.trim();
  if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
    t = t.substring(1, t.length - 1).replaceAll('""', '"');
  }
  return t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').trim();
}

/// Exporte des cartes au format tabulé (réimportable ici ou dans Anki).
String exporterTexte(Iterable<Carte> cartes) {
  String champ(String s) => s.replaceAll('\t', ' ').replaceAll('\n', '<br>');
  return cartes.map((c) => '${champ(c.recto)}\t${champ(c.verso)}').join('\n');
}

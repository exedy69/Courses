import '../data/recettes.dart' as data;
import '../models/produit.dart';
import '../models/recette.dart';

class Suggestion {
  final Recette recette;

  /// Produits utilisés (un par ingrédient trouvé).
  final List<Produit> utilises;

  /// Ingrédients manquants.
  final List<String> manquants;
  final int score;

  const Suggestion({
    required this.recette,
    required this.utilises,
    required this.manquants,
    required this.score,
  });

  bool get complete => manquants.isEmpty;
}

List<String> _mots(String s) => normaliser(s).split(' ').where((m) => m.isNotEmpty).toList();

/// Vrai si la suite de mots [sous] apparaît telle quelle dans [mots] (mots entiers).
bool _contientSuite(List<String> mots, List<String> sous) {
  if (sous.isEmpty) return false;
  for (var i = 0; i + sous.length <= mots.length; i++) {
    var ok = true;
    for (var j = 0; j < sous.length; j++) {
      if (mots[i + j] != sous[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

class MoteurSuggestions {
  final List<Recette> recettes;
  final DateTime Function() maintenant;

  MoteurSuggestions({List<Recette>? recettes, DateTime Function()? maintenant})
      : recettes = recettes ?? data.recettes,
        maintenant = maintenant ?? DateTime.now;

  /// Ingrédients connus (normalisés) de toutes les recettes.
  Set<String> get _ingredientsConnus => {
        for (final r in recettes)
          for (final i in r.ingredients) normaliser(i),
      };

  int _pointsProduit(int jours) {
    if (jours <= 0) return 100;
    if (jours <= 7) return 100 - 12 * jours;
    return 5;
  }

  Produit? _meilleurProduit(
    String ingredient,
    List<Produit> stock,
    Set<String> connus,
    Set<String> dejaPris,
  ) {
    final ing = normaliser(ingredient);
    final motsIng = _mots(ingredient);
    final ref = maintenant();

    int parUrgence(Produit a, Produit b) =>
        a.joursRestants(ref).compareTo(b.joursRestants(ref));

    final exacts = stock
        .where((p) => !dejaPris.contains(p.uuid) && normaliser(p.nom) == ing)
        .toList()
      ..sort(parUrgence);
    if (exacts.isNotEmpty) return exacts.first;

    final partiels = <Produit>[];
    for (final p in stock) {
      if (dejaPris.contains(p.uuid)) continue;
      final nomNorm = normaliser(p.nom);
      // Anti-faux-positifs : un produit qui est lui-même un ingrédient connu
      // (pomme de terre, lait de coco, pâte feuilletée…) ne satisfait pas
      // un autre ingrédient par correspondance partielle.
      if (connus.contains(nomNorm) && nomNorm != ing) continue;
      if (_contientSuite(_mots(p.nom), motsIng)) partiels.add(p);
    }
    partiels.sort(parUrgence);
    return partiels.isEmpty ? null : partiels.first;
  }

  List<Suggestion> suggerer(List<Produit> stock) {
    final ref = maintenant();
    final frais = stock.where((p) => p.joursRestants(ref) >= 0).toList();
    final connus = _ingredientsConnus;
    final resultat = <Suggestion>[];

    for (final r in recettes) {
      final utilises = <Produit>[];
      final manquants = <String>[];
      final pris = <String>{};
      for (final ing in r.ingredients) {
        final p = _meilleurProduit(ing, frais, connus, pris);
        if (p == null) {
          manquants.add(ing);
        } else {
          pris.add(p.uuid);
          utilises.add(p);
        }
      }
      if (utilises.isEmpty || manquants.length > 2) continue;
      var score = 0;
      for (final p in utilises) {
        score += _pointsProduit(p.joursRestants(ref)) + 3;
      }
      score -= 40 * manquants.length;
      resultat.add(Suggestion(
        recette: r,
        utilises: utilises,
        manquants: manquants,
        score: score,
      ));
    }
    resultat.sort((a, b) => b.score.compareTo(a.score));
    return resultat;
  }

  /// Meilleure recette COMPLÈTE si elle existe, sinon la meilleure tout court.
  Suggestion? suggestionDuJour(List<Suggestion> suggestions) {
    if (suggestions.isEmpty) return null;
    for (final s in suggestions) {
      if (s.complete) return s;
    }
    return suggestions.first;
  }
}

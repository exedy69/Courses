class Recette {
  final String titre;

  /// Mots-clés simples, sans quantités.
  final List<String> ingredients;

  /// Basiques supposés présents (sel, huile…).
  final List<String> basiques;
  final String instructions;
  final int minutes;

  const Recette({
    required this.titre,
    required this.ingredients,
    this.basiques = const [],
    required this.instructions,
    required this.minutes,
  });
}

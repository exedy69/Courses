class Paquet {
  final int? id;
  final String nom;
  final DateTime creeLe;

  const Paquet({this.id, required this.nom, required this.creeLe});

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'nom': nom,
    'cree_le': creeLe.millisecondsSinceEpoch,
  };

  factory Paquet.depuisLigne(Map<String, Object?> l) => Paquet(
    id: (l['id'] as num?)?.toInt(),
    nom: (l['nom'] ?? '').toString(),
    creeLe: DateTime.fromMillisecondsSinceEpoch((l['cree_le'] as num?)?.toInt() ?? 0),
  );
}

/// Compteurs affichés à côté d'un paquet, comme dans Anki.
class Compteurs {
  final int nouvelles; // nouvelles cartes encore présentables aujourd'hui
  final int apprentissage; // cartes en (ré)apprentissage échues
  final int revision; // révisions échues présentables aujourd'hui
  final int total;

  const Compteurs({this.nouvelles = 0, this.apprentissage = 0, this.revision = 0, this.total = 0});

  int get aFaire => nouvelles + apprentissage + revision;
}

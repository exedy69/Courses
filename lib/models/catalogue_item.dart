class CatalogueItem {
  final String codeBarres;
  final String nom;
  final String? marque;
  final String? categorie;
  final String? imageUrl;

  /// 'off' | 'obf' | 'opf' | 'manuel'
  final String source;
  final int? dureeHabituelleJours;
  final String updatedAt;

  const CatalogueItem({
    required this.codeBarres,
    required this.nom,
    this.marque,
    this.categorie,
    this.imageUrl,
    required this.source,
    this.dureeHabituelleJours,
    required this.updatedAt,
  });

  CatalogueItem avec({String? nom, int? dureeHabituelleJours, String? updatedAt}) =>
      CatalogueItem(
        codeBarres: codeBarres,
        nom: nom ?? this.nom,
        marque: marque,
        categorie: categorie,
        imageUrl: imageUrl,
        source: source,
        dureeHabituelleJours: dureeHabituelleJours ?? this.dureeHabituelleJours,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'code_barres': codeBarres,
        'nom': nom,
        'marque': marque,
        'categorie': categorie,
        'image_url': imageUrl,
        'source': source,
        'duree_habituelle_jours': dureeHabituelleJours,
        'updated_at': updatedAt,
      };

  factory CatalogueItem.fromMap(Map<String, Object?> m) => CatalogueItem(
        codeBarres: m['code_barres'].toString(),
        nom: m['nom'] as String,
        marque: m['marque'] as String?,
        categorie: m['categorie'] as String?,
        imageUrl: m['image_url'] as String?,
        source: (m['source'] as String?) ?? 'manuel',
        dureeHabituelleJours: m['duree_habituelle_jours'] as int?,
        updatedAt: m['updated_at'] as String,
      );
}

import 'produit.dart';

/// Ligne de la liste de courses partagée.
class ArticleCourse {
  final String uuid;
  final String nom;
  final bool fait;
  final String? auteur;
  final String updatedAt;
  final String? deletedAt;

  ArticleCourse({
    String? uuid,
    required this.nom,
    this.fait = false,
    this.auteur,
    String? updatedAt,
    this.deletedAt,
  })  : uuid = uuid ?? nouvelUuid(),
        updatedAt = updatedAt ?? maintenantUtcIso();

  factory ArticleCourse.fromMap(Map<String, Object?> m) => ArticleCourse(
        uuid: m['uuid'] as String,
        nom: m['nom'] as String,
        fait: ((m['fait'] as int?) ?? 0) != 0,
        auteur: m['auteur'] as String?,
        updatedAt: m['updated_at'] as String,
        deletedAt: m['deleted_at'] as String?,
      );
}

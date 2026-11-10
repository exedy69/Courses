import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String nouvelUuid() => _uuid.v4();

/// Date du jour à minuit local (sans heure).
DateTime aujourdhui([DateTime? maintenant]) {
  final n = maintenant ?? DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// `AAAA-MM-JJ`
String dateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Lit `AAAA-MM-JJ` (tolère un suffixe horaire) et renvoie minuit local.
DateTime lireDateIso(String s) {
  final p = s.substring(0, 10).split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Maintenant en UTC, ISO-8601 avec millisecondes exactement.
String maintenantUtcIso([DateTime? t]) {
  final ms = (t ?? DateTime.now()).millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Minuscules, sans accents, ligatures éclatées, ponctuation → espace,
/// espaces compressés, pluriel simple (« s » final des mots de 4 lettres ou plus).
/// Retire les caractères de tête qui feraient d'un texte une formule de tableur
/// (les noms viennent d'une base publique et finissent dans un Google Sheet).
String neutraliserFormule(String texte) =>
    texte.replaceFirst(RegExp(r'^[=+\-@\t\r\n\s]+'), '').trim();

String normaliser(String texte) {
  final b = StringBuffer();
  for (final c in texte.toLowerCase().split('')) {
    b.write(_accents[c] ?? c);
  }
  final propre = b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  if (propre.isEmpty) return '';
  return propre.split(' ').map((m) {
    if (m.length >= 4 && m.endsWith('s')) return m.substring(0, m.length - 1);
    return m;
  }).join(' ');
}

class Produit {
  int? id;
  String uuid;
  String? codeBarres;
  String nom;
  DateTime datePeremption;
  int quantite;
  String? categorie;
  String? photoPath;

  /// Prénom de la personne qui a ajouté le produit (facultatif).
  String? auteur;
  DateTime dateAjout;
  String updatedAt;
  String? deletedAt;

  Produit({
    this.id,
    String? uuid,
    this.codeBarres,
    required this.nom,
    required this.datePeremption,
    this.quantite = 1,
    this.categorie,
    this.photoPath,
    this.auteur,
    DateTime? dateAjout,
    String? updatedAt,
    this.deletedAt,
  })  : uuid = uuid ?? nouvelUuid(),
        dateAjout = dateAjout ?? aujourdhui(),
        updatedAt = updatedAt ?? maintenantUtcIso();

  /// Jours entiers entre aujourd'hui (minuit) et la péremption (minuit).
  int joursRestants([DateTime? reference]) {
    final ref = aujourdhui(reference);
    final p = DateTime(datePeremption.year, datePeremption.month, datePeremption.day);
    return DateTime.utc(p.year, p.month, p.day)
        .difference(DateTime.utc(ref.year, ref.month, ref.day))
        .inDays;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'code_barres': codeBarres,
        'nom': nom,
        'date_peremption': dateIso(datePeremption),
        'quantite': quantite,
        'categorie': categorie,
        'photo_path': photoPath,
        'auteur': auteur,
        'date_ajout': dateIso(dateAjout),
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  factory Produit.fromMap(Map<String, Object?> m) => Produit(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        codeBarres: m['code_barres'] as String?,
        nom: m['nom'] as String,
        datePeremption: lireDateIso(m['date_peremption'] as String),
        quantite: (m['quantite'] as int?) ?? 1,
        categorie: m['categorie'] as String?,
        photoPath: m['photo_path'] as String?,
        auteur: m['auteur'] as String?,
        dateAjout: lireDateIso(m['date_ajout'] as String),
        updatedAt: m['updated_at'] as String,
        deletedAt: m['deleted_at'] as String?,
      );

  Produit copie() => Produit(
        id: id,
        uuid: uuid,
        codeBarres: codeBarres,
        nom: nom,
        datePeremption: datePeremption,
        quantite: quantite,
        categorie: categorie,
        photoPath: photoPath,
        auteur: auteur,
        dateAjout: dateAjout,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

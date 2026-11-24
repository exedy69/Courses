/// État d'une carte dans le cycle d'apprentissage (mêmes valeurs qu'Anki).
enum EtatCarte {
  nouvelle, // jamais vue
  apprentissage, // vue récemment, étapes courtes en minutes
  revision, // apprise, revient après des jours
  reapprentissage; // oubliée pendant une révision

  static EtatCarte depuis(int v) => v >= 0 && v < values.length ? values[v] : EtatCarte.nouvelle;
}

class Carte {
  final int? id;
  final int paquetId;
  final String recto;
  final String verso;
  final EtatCarte etat;

  /// Prochaine présentation. Pour une carte en révision : 4 h du matin du jour prévu.
  final DateTime echeance;

  /// Intervalle courant en jours (cartes en révision).
  final int intervalle;

  /// Facilité en pour mille (2500 = 250 %).
  final int facilite;

  /// Indice de l'étape d'apprentissage en cours.
  final int etape;
  final int repetitions;
  final int oublis;

  /// Ordre d'introduction des nouvelles cartes.
  final int position;
  final DateTime creeLe;
  final DateTime modifieLe;

  const Carte({
    this.id,
    required this.paquetId,
    required this.recto,
    required this.verso,
    this.etat = EtatCarte.nouvelle,
    required this.echeance,
    this.intervalle = 0,
    this.facilite = 2500,
    this.etape = 0,
    this.repetitions = 0,
    this.oublis = 0,
    this.position = 0,
    required this.creeLe,
    required this.modifieLe,
  });

  factory Carte.nouvelle({
    required int paquetId,
    required String recto,
    required String verso,
    DateTime? maintenant,
  }) {
    final t = maintenant ?? DateTime.now();
    return Carte(
      paquetId: paquetId,
      recto: recto.trim(),
      verso: verso.trim(),
      echeance: t,
      creeLe: t,
      modifieLe: t,
    );
  }

  /// Carte « inverse » : le verso devient la question.
  Carte inverse() => Carte.nouvelle(paquetId: paquetId, recto: verso, verso: recto);

  /// Remet la carte à zéro (redevient nouvelle), contenu conservé.
  Carte oublier(DateTime maintenant) => Carte(
    id: id,
    paquetId: paquetId,
    recto: recto,
    verso: verso,
    echeance: maintenant,
    position: position,
    creeLe: creeLe,
    modifieLe: maintenant,
  );

  bool get estNouvelle => etat == EtatCarte.nouvelle;
  bool get enApprentissage => etat == EtatCarte.apprentissage || etat == EtatCarte.reapprentissage;

  Carte copier({
    int? id,
    int? paquetId,
    String? recto,
    String? verso,
    EtatCarte? etat,
    DateTime? echeance,
    int? intervalle,
    int? facilite,
    int? etape,
    int? repetitions,
    int? oublis,
    int? position,
    DateTime? modifieLe,
  }) => Carte(
    id: id ?? this.id,
    paquetId: paquetId ?? this.paquetId,
    recto: recto ?? this.recto,
    verso: verso ?? this.verso,
    etat: etat ?? this.etat,
    echeance: echeance ?? this.echeance,
    intervalle: intervalle ?? this.intervalle,
    facilite: facilite ?? this.facilite,
    etape: etape ?? this.etape,
    repetitions: repetitions ?? this.repetitions,
    oublis: oublis ?? this.oublis,
    position: position ?? this.position,
    creeLe: creeLe,
    modifieLe: modifieLe ?? this.modifieLe,
  );

  Map<String, Object?> versLigne() => {
    if (id != null) 'id': id,
    'paquet_id': paquetId,
    'recto': recto,
    'verso': verso,
    'etat': etat.index,
    'echeance': echeance.millisecondsSinceEpoch,
    'intervalle': intervalle,
    'facilite': facilite,
    'etape': etape,
    'repetitions': repetitions,
    'oublis': oublis,
    'position': position,
    'cree_le': creeLe.millisecondsSinceEpoch,
    'modifie_le': modifieLe.millisecondsSinceEpoch,
  };

  factory Carte.depuisLigne(Map<String, Object?> l) {
    DateTime date(String c) => DateTime.fromMillisecondsSinceEpoch((l[c] as num?)?.toInt() ?? 0);
    int entier(String c, [int defaut = 0]) => (l[c] as num?)?.toInt() ?? defaut;
    return Carte(
      id: (l['id'] as num?)?.toInt(),
      paquetId: entier('paquet_id'),
      recto: (l['recto'] ?? '').toString(),
      verso: (l['verso'] ?? '').toString(),
      etat: EtatCarte.depuis(entier('etat')),
      echeance: date('echeance'),
      intervalle: entier('intervalle'),
      facilite: entier('facilite', 2500),
      etape: entier('etape'),
      repetitions: entier('repetitions'),
      oublis: entier('oublis'),
      position: entier('position'),
      creeLe: date('cree_le'),
      modifieLe: date('modifie_le'),
    );
  }
}

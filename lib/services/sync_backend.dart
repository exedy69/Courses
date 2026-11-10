/// Requête de synchronisation (un seul aller-retour).
class SyncRequete {
  /// Dernier numéro d'écriture serveur déjà reçu.
  final int curseur;

  /// Vrai pour demander au serveur un passage complet (prise en compte des
  /// corrections faites à la main dans le Sheet, purge).
  final bool complet;

  /// Lignes locales à envoyer, par nom de table.
  final Map<String, List<Map<String, Object?>>> tables;

  const SyncRequete({required this.curseur, required this.complet, required this.tables});
}

class SyncReponse {
  /// Lignes dont le numéro d'écriture serveur dépasse le curseur envoyé.
  final Map<String, List<Map<String, Object?>>> tables;

  /// Nouveau curseur à mémoriser.
  final int curseur;

  const SyncReponse({required this.tables, required this.curseur});
}

class SyncErreur implements Exception {
  final String message;
  const SyncErreur(this.message);
  @override
  String toString() => message;
}

/// Contrat d'un serveur de synchro (Google Sheets aujourd'hui, autre chose demain).
abstract class SyncBackend {
  Future<void> tester();
  Future<SyncReponse> echanger(SyncRequete requete);
}

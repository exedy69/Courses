/// Requête de synchronisation (un seul aller-retour).
class SyncRequete {
  final String since;
  final List<Map<String, Object?>> produits;
  final List<Map<String, Object?>> catalogue;
  final List<Map<String, Object?>> historique;
  const SyncRequete({
    required this.since,
    required this.produits,
    required this.catalogue,
    required this.historique,
  });
}

class SyncReponse {
  final List<Map<String, Object?>> produits;
  final List<Map<String, Object?>> catalogue;
  final List<Map<String, Object?>> historique;
  final String serverTime;
  const SyncReponse({
    required this.produits,
    required this.catalogue,
    required this.historique,
    required this.serverTime,
  });
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

import '../db/base_donnees.dart';
import '../models/carte.dart';

/// Paquet de démonstration créé au premier lancement (supprimable).
const _capitales = <(String, String)>[
  ('Capitale de l\'Australie ?', 'Canberra'),
  ('Capitale du Canada ?', 'Ottawa'),
  ('Capitale du Brésil ?', 'Brasília'),
  ('Capitale de la Turquie ?', 'Ankara'),
  ('Capitale du Maroc ?', 'Rabat'),
  ('Capitale de la Suisse ?', 'Berne'),
  ('Capitale du Japon ?', 'Tokyo'),
  ('Capitale de la Norvège ?', 'Oslo'),
  ('Capitale de l\'Égypte ?', 'Le Caire'),
  ('Capitale du Pérou ?', 'Lima'),
];

Future<void> creerPaquetExempleSiBesoin(BaseDonnees base) async {
  if (await base.lireReglage('exemple_cree') != null) return;
  final id = await base.creerPaquet('Exemple : capitales');
  await base.ajouterCartes([
    for (final (q, r) in _capitales) Carte.nouvelle(paquetId: id, recto: q, verso: r),
  ]);
  await base.ecrireReglage('exemple_cree', '1');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/models/produit.dart';

void main() {
  group('normaliser', () {
    test('accents et casse', () {
      expect(normaliser('Crème Fraîche'), 'creme fraiche');
      expect(normaliser('ÉPINARDS'), 'epinard');
    });
    test('ligatures', () {
      expect(normaliser('Œufs'), 'oeuf');
      expect(normaliser('Tæniæ'), 'taeniae');
    });
    test('pluriel simple (mots de 4 lettres ou plus)', () {
      expect(normaliser('Tomates cerises'), 'tomate cerise');
      expect(normaliser('pâtes'), 'pate');
      expect(normaliser('riz'), 'riz');
      expect(normaliser('gaz'), 'gaz');
    });
    test('ponctuation et espaces', () {
      expect(normaliser('  Lait,  demi-écrémé!! '), 'lait demi ecreme');
      expect(normaliser(''), '');
    });
  });

  group('joursRestants (dates sans heure)', () {
    Produit p(DateTime d) => Produit(nom: 'x', datePeremption: d);

    test('demain reste demain quelle que soit l\'heure', () {
      final demain = DateTime(2026, 11, 8);
      expect(p(demain).joursRestants(DateTime(2026, 11, 7, 0, 1)), 1);
      expect(p(demain).joursRestants(DateTime(2026, 11, 7, 23, 59)), 1);
    });
    test('aujourd\'hui et périmé', () {
      expect(p(DateTime(2026, 11, 7)).joursRestants(DateTime(2026, 11, 7, 15)), 0);
      expect(p(DateTime(2026, 11, 4)).joursRestants(DateTime(2026, 11, 7, 15)), -3);
    });
    test('passage à l\'heure d\'hiver', () {
      expect(p(DateTime(2026, 10, 26)).joursRestants(DateTime(2026, 10, 24, 23)), 2);
    });
    test('date ISO aller-retour', () {
      expect(dateIso(DateTime(2026, 1, 5)), '2026-01-05');
      expect(lireDateIso('2026-01-05'), DateTime(2026, 1, 5));
      expect(lireDateIso('2026-01-05T00:00:00.000Z'), DateTime(2026, 1, 5));
    });
    test('updated_at en UTC avec millisecondes', () {
      final s = maintenantUtcIso(DateTime.utc(2026, 11, 7, 12, 30, 45, 123, 456));
      expect(s, '2026-11-07T12:30:45.123Z');
    });
  });
}

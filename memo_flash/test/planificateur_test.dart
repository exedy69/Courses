import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_flash/models/carte.dart';
import 'package:memo_flash/services/planificateur.dart';

void main() {
  const planif = Planificateur();
  // Un mardi à 10 h, heure locale.
  final t = DateTime(2026, 3, 10, 10);

  Carte nouvelle() => Carte.nouvelle(paquetId: 1, recto: 'q', verso: 'r', maintenant: t);

  Carte enRevision({int ivl = 10, int facilite = 2500, DateTime? echeance}) => nouvelle().copier(
    etat: EtatCarte.revision,
    intervalle: ivl,
    facilite: facilite,
    echeance: echeance ?? debutJour(numeroJour(t)),
  );

  group('jours de révision', () {
    test('la journée commence à 4 h', () {
      expect(numeroJour(DateTime(2026, 3, 10, 3, 59)), numeroJour(DateTime(2026, 3, 9, 12)));
      expect(numeroJour(DateTime(2026, 3, 10, 4)), numeroJour(DateTime(2026, 3, 9, 12)) + 1);
    });

    test('debutJour est l\'inverse de numeroJour', () {
      final j = numeroJour(t);
      expect(debutJour(j), DateTime(2026, 3, 10, 4));
      expect(numeroJour(debutJour(j)), j);
    });

    test('passage à l\'heure d\'été sans décalage de jour', () {
      // Dernier dimanche de mars 2026 : 29 mars.
      final avant = numeroJour(DateTime(2026, 3, 28, 12));
      expect(debutJour(avant + 1), DateTime(2026, 3, 29, 4));
      expect(debutJour(avant + 2), DateTime(2026, 3, 30, 4));
    });
  });

  group('nouvelle carte', () {
    test('À revoir : première étape (1 min)', () {
      final c = planif.repondre(nouvelle(), Note.aRevoir, t);
      expect(c.etat, EtatCarte.apprentissage);
      expect(c.etape, 0);
      expect(c.echeance, t.add(const Duration(minutes: 1)));
      expect(c.repetitions, 1);
    });

    test('Difficile sur la première étape : moyenne des deux étapes', () {
      final c = planif.repondre(nouvelle(), Note.difficile, t);
      expect(c.echeance.difference(t), const Duration(minutes: 6));
    });

    test('Correct puis Correct : diplômée à 1 jour', () {
      var c = planif.repondre(nouvelle(), Note.correct, t);
      expect(c.etat, EtatCarte.apprentissage);
      expect(c.etape, 1);
      expect(c.echeance, t.add(const Duration(minutes: 10)));
      c = planif.repondre(c, Note.correct, c.echeance);
      expect(c.etat, EtatCarte.revision);
      expect(c.intervalle, 1);
      expect(c.echeance, DateTime(2026, 3, 11, 4));
    });

    test('Facile : diplômée directement à 4 jours', () {
      final c = planif.repondre(nouvelle(), Note.facile, t);
      expect(c.etat, EtatCarte.revision);
      expect(c.intervalle, 4);
      expect(c.echeance, DateTime(2026, 3, 14, 4));
    });
  });

  group('carte en révision', () {
    test('Correct : intervalle × facilité', () {
      final c = planif.repondre(enRevision(), Note.correct, t);
      expect(c.intervalle, 25);
      expect(c.facilite, 2500);
      expect(c.echeance, debutJour(numeroJour(t) + 25));
    });

    test('Difficile < Correct < Facile, facilité ajustée', () {
      final d = planif.repondre(enRevision(), Note.difficile, t);
      final c = planif.repondre(enRevision(), Note.correct, t);
      final f = planif.repondre(enRevision(), Note.facile, t);
      expect(d.intervalle, 12);
      expect(d.facilite, 2350);
      expect(f.intervalle, 33);
      expect(f.facilite, 2650);
      expect(d.intervalle < c.intervalle && c.intervalle < f.intervalle, isTrue);
    });

    test('un retard allonge l\'intervalle (la carte était mieux sue)', () {
      final enRetard = enRevision(echeance: debutJour(numeroJour(t) - 4));
      final c = planif.repondre(enRetard, Note.correct, t);
      expect(c.intervalle, 30); // (10 + 4 / 2) × 2,5
    });

    test('À revoir : oubli, facilité −20 %, réapprentissage 10 min', () {
      final c = planif.repondre(enRevision(), Note.aRevoir, t);
      expect(c.etat, EtatCarte.reapprentissage);
      expect(c.oublis, 1);
      expect(c.facilite, 2300);
      expect(c.intervalle, 1);
      expect(c.echeance, t.add(const Duration(minutes: 10)));
      final r = planif.repondre(c, Note.correct, c.echeance);
      expect(r.etat, EtatCarte.revision);
      expect(r.echeance, DateTime(2026, 3, 11, 4));
    });

    test('la facilité ne descend pas sous 130 %', () {
      var c = enRevision(facilite: 1350);
      c = planif.repondre(c, Note.aRevoir, t);
      expect(c.facilite, 1300);
    });

    test('intervalle maximum respecté', () {
      final c = planif.repondre(enRevision(ivl: 30000), Note.facile, t);
      expect(c.intervalle, 36500);
    });

    test('aléa : reste à ±5 % et ne change pas l\'aperçu', () {
      final p = Planificateur(alea: Random(1));
      for (var i = 0; i < 50; i++) {
        final c = p.repondre(enRevision(ivl: 40), Note.correct, t);
        expect(c.intervalle, inInclusiveRange(95, 105));
      }
      expect(p.apercu(enRevision(ivl: 40), Note.correct, t), const Duration(days: 100));
      expect(p.apercu(nouvelle(), Note.facile, t), const Duration(days: 4));
      expect(p.apercu(nouvelle(), Note.correct, t), const Duration(minutes: 10));
    });
  });

  test('formaterDelai', () {
    expect(formaterDelai(const Duration(seconds: 30)), '<1 min');
    expect(formaterDelai(const Duration(minutes: 10)), '10 min');
    expect(formaterDelai(const Duration(hours: 3)), '3 h');
    expect(formaterDelai(const Duration(hours: 18)), '18 h');
    expect(formaterDelai(const Duration(days: 4)), '4 j');
    expect(formaterDelai(const Duration(days: 76)), '2,5 mois');
    expect(formaterDelai(const Duration(days: 365)), '1 an');
    expect(formaterDelai(const Duration(days: 1000)), '2,7 ans');
  });
}

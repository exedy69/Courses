import 'dart:math';

import '../models/carte.dart';

/// Heure à laquelle commence une nouvelle « journée » de révision (comme Anki) :
/// réviser à 1 h du matin compte encore pour la veille.
const heureDebutJournee = 4;

/// Numéro du jour de révision (jours depuis l'époque) d'un instant local.
int numeroJour(DateTime instant) {
  final decale = instant.toLocal().subtract(const Duration(hours: heureDebutJournee));
  return DateTime.utc(decale.year, decale.month, decale.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

/// Début (heure locale) du jour de révision [jour].
DateTime debutJour(int jour) {
  final d = DateTime.fromMillisecondsSinceEpoch(jour * Duration.millisecondsPerDay, isUtc: true);
  return DateTime(d.year, d.month, d.day, heureDebutJournee);
}

/// Les quatre réponses possibles, comme dans Anki.
enum Note {
  aRevoir('À revoir'),
  difficile('Difficile'),
  correct('Correct'),
  facile('Facile');

  final String libelle;
  const Note(this.libelle);
}

/// Réglages de l'algorithme (valeurs par défaut d'Anki).
class ParametresPlanif {
  final List<int> etapesApprentissage; // en minutes
  final List<int> etapesReapprentissage; // en minutes
  final int intervalleDiplome; // jours, après « Correct » sur la dernière étape
  final int intervalleFacile; // jours, après « Facile » sur une nouvelle carte
  final int faciliteInitiale; // en pour mille (2500 = 250 %)
  final int faciliteMin;
  final double bonusFacile;
  final double facteurDifficile;
  final int intervalleMax; // jours

  const ParametresPlanif({
    this.etapesApprentissage = const [1, 10],
    this.etapesReapprentissage = const [10],
    this.intervalleDiplome = 1,
    this.intervalleFacile = 4,
    this.faciliteInitiale = 2500,
    this.faciliteMin = 1300,
    this.bonusFacile = 1.3,
    this.facteurDifficile = 1.2,
    this.intervalleMax = 36500,
  });
}

/// Planification SM-2 façon Anki. Fonctions pures : aucune base, aucune horloge
/// cachée, donc entièrement testables.
class Planificateur {
  final ParametresPlanif p;

  /// Petit aléa sur les longs intervalles (étale les cartes ajoutées ensemble).
  /// `null` : pas d'aléa (tests, aperçu des boutons).
  final Random? alea;

  const Planificateur({this.p = const ParametresPlanif(), this.alea});

  /// Nouvel état de [c] après la réponse [note] donnée à l'instant [maintenant].
  Carte repondre(Carte c, Note note, DateTime maintenant) {
    switch (c.etat) {
      case EtatCarte.nouvelle:
      case EtatCarte.apprentissage:
        return _apprendre(c, note, maintenant, p.etapesApprentissage, depuisReapp: false);
      case EtatCarte.reapprentissage:
        return _apprendre(c, note, maintenant, p.etapesReapprentissage, depuisReapp: true);
      case EtatCarte.revision:
        return _reviser(c, note, maintenant);
    }
  }

  /// Délai affiché sur les boutons : minutes en apprentissage, jours entiers en révision
  /// (« 1 j » même si la carte revient demain matin dans 18 h).
  Duration apercu(Carte c, Note note, DateTime maintenant) {
    final apres = Planificateur(p: p).repondre(c, note, maintenant);
    if (apres.etat == EtatCarte.revision) return Duration(days: apres.intervalle);
    return apres.echeance.difference(maintenant);
  }

  Carte _apprendre(Carte c, Note note, DateTime t, List<int> etapes, {required bool depuisReapp}) {
    final etat = depuisReapp ? EtatCarte.reapprentissage : EtatCarte.apprentissage;
    final int etape = c.etat == EtatCarte.nouvelle
        ? 0
        : min(max(0, c.etape), max(0, etapes.length - 1));
    final base = c.copier(
      repetitions: c.repetitions + 1,
      facilite: c.etat == EtatCarte.nouvelle ? p.faciliteInitiale : c.facilite,
    );
    if (etapes.isEmpty) {
      return depuisReapp ? _retourRevision(base, t) : _diplomer(base, t, p.intervalleDiplome);
    }
    switch (note) {
      case Note.aRevoir:
        return base.copier(
          etat: etat,
          etape: 0,
          echeance: t.add(Duration(minutes: etapes[0])),
        );
      case Note.difficile:
        // Première étape : moyenne des deux premières (ou ×1,5 s'il n'y en a qu'une).
        final int minutes;
        if (etape == 0) {
          minutes = etapes.length > 1
              ? ((etapes[0] + etapes[1]) / 2).round()
              : min((etapes[0] * 1.5).round(), etapes[0] + 1440);
        } else {
          minutes = etapes[etape];
        }
        return base.copier(
          etat: etat,
          etape: etape,
          echeance: t.add(Duration(minutes: minutes)),
        );
      case Note.correct:
        final suivante = etape + 1;
        if (suivante >= etapes.length) {
          return depuisReapp ? _retourRevision(base, t) : _diplomer(base, t, p.intervalleDiplome);
        }
        return base.copier(
          etat: etat,
          etape: suivante,
          echeance: t.add(Duration(minutes: etapes[suivante])),
        );
      case Note.facile:
        return depuisReapp ? _retourRevision(base, t) : _diplomer(base, t, p.intervalleFacile);
    }
  }

  Carte _diplomer(Carte c, DateTime t, int jours) {
    final ivl = _borner(jours);
    return c.copier(
      etat: EtatCarte.revision,
      etape: 0,
      intervalle: ivl,
      echeance: debutJour(numeroJour(t) + ivl),
    );
  }

  Carte _retourRevision(Carte c, DateTime t) {
    final ivl = max(1, c.intervalle);
    return c.copier(
      etat: EtatCarte.revision,
      etape: 0,
      intervalle: ivl,
      echeance: debutJour(numeroJour(t) + ivl),
    );
  }

  Carte _reviser(Carte c, Note note, DateTime t) {
    final aujourdhui = numeroJour(t);
    final retard = max(0, aujourdhui - numeroJour(c.echeance));
    final ivl = max(1, c.intervalle);
    final ease = c.facilite / 1000;
    final base = c.copier(repetitions: c.repetitions + 1);

    if (note == Note.aRevoir) {
      final etapes = p.etapesReapprentissage;
      final oubliee = base.copier(
        oublis: c.oublis + 1,
        facilite: max(p.faciliteMin, c.facilite - 200),
        intervalle: 1,
      );
      if (etapes.isEmpty) {
        return oubliee.copier(etat: EtatCarte.revision, echeance: debutJour(aujourdhui + 1));
      }
      return oubliee.copier(
        etat: EtatCarte.reapprentissage,
        etape: 0,
        echeance: t.add(Duration(minutes: etapes[0])),
      );
    }

    final difficile = _borner(max(ivl + 1, (ivl * p.facteurDifficile).round()));
    final correct = _borner(max(difficile + 1, ((ivl + retard / 2) * ease).round()));
    final facile = _borner(max(correct + 1, ((ivl + retard) * ease * p.bonusFacile).round()));

    final int nouvelIvl;
    int nouvelleFacilite = c.facilite;
    switch (note) {
      case Note.difficile:
        nouvelIvl = difficile;
        nouvelleFacilite = max(p.faciliteMin, c.facilite - 150);
      case Note.correct:
        nouvelIvl = correct;
      case Note.facile:
        nouvelIvl = facile;
        nouvelleFacilite = c.facilite + 150;
      case Note.aRevoir:
        throw StateError('déjà traité');
    }
    final avecAlea = _borner(_alea(nouvelIvl));
    return base.copier(
      intervalle: avecAlea,
      facilite: nouvelleFacilite,
      echeance: debutJour(aujourdhui + avecAlea),
    );
  }

  int _borner(int jours) => min(max(1, jours), p.intervalleMax);

  int _alea(int jours) {
    final r = alea;
    if (r == null || jours < 3) return jours;
    final marge = max(1, (jours * 0.05).round());
    return jours - marge + r.nextInt(2 * marge + 1);
  }
}

/// « <1 min », « 10 min », « 3 h », « 4 j », « 2,5 mois », « 1,2 an ».
String formaterDelai(Duration d) {
  final minutes = d.inSeconds / 60;
  if (minutes < 1) return '<1 min';
  if (minutes < 60) return '${minutes.round()} min';
  final heures = minutes / 60;
  if (heures < 20) return '${heures.round()} h';
  final jours = heures / 24;
  if (jours < 30) return '${jours.round()} j';
  final mois = jours / 30.44;
  if (jours < 365) return '${_dec(mois)} mois';
  final ans = jours / 365.25;
  return '${_dec(ans)} an${ans >= 2 ? 's' : ''}';
}

String _dec(double v) {
  final arrondi = (v * 10).round() / 10;
  if (arrondi == arrondi.roundToDouble()) return arrondi.toInt().toString();
  return arrondi.toStringAsFixed(1).replaceAll('.', ',');
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/produit.dart';
import '../theme.dart';

DateTime ajouterMois(DateTime d, int mois) {
  final total = d.month - 1 + mois;
  final annee = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final dernier = DateTime(annee, m + 1, 0).day;
  return DateTime(annee, m, d.day > dernier ? dernier : d.day);
}

String formatDateCourte(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// Date choisie avec son libellé d'urgence coloré.
class DateAvecUrgence extends StatelessWidget {
  final DateTime date;
  const DateAvecUrgence({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final jours = Produit(nom: '', datePeremption: date).joursRestants();
    final couleur = couleurTexteUrgence(jours, Theme.of(context).brightness);
    return Text(
      '${libelleUrgence(jours)} · ${formatDateCourte(date)}',
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: couleur, fontWeight: FontWeight.w700),
    );
  }
}

/// Raccourcis +3 j … +1 an et sélecteur de date complet.
class RaccourcisDate extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChange;
  const RaccourcisDate({super.key, required this.date, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final auj = aujourdhui();
    final raccourcis = <(String, DateTime)>[
      ('+3 j', auj.add(const Duration(days: 3))),
      ('+1 sem', auj.add(const Duration(days: 7))),
      ('+2 sem', auj.add(const Duration(days: 14))),
      ('+1 mois', ajouterMois(auj, 1)),
      ('+3 mois', ajouterMois(auj, 3)),
      ('+1 an', ajouterMois(auj, 12)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (libelle, d) in raccourcis)
          ActionChip(
            label: Text(libelle),
            onPressed: () => onChange(d),
          ),
        ActionChip(
          avatar: const Icon(Icons.calendar_month, size: 18),
          label: const Text('Choisir'),
          onPressed: () async {
            final choix = await showDatePicker(
              context: context,
              initialDate: date.isBefore(auj) ? auj : date,
              firstDate: auj.subtract(const Duration(days: 365)),
              lastDate: auj.add(const Duration(days: 365 * 15)),
              locale: const Locale('fr', 'FR'),
            );
            if (choix != null) onChange(DateTime(choix.year, choix.month, choix.day));
          },
        ),
      ],
    );
  }
}

/// Sélecteur de quantité − / +.
class SelecteurQuantite extends StatelessWidget {
  final int valeur;
  final ValueChanged<int> onChange;
  const SelecteurQuantite({super.key, required this.valeur, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: valeur > 1 ? () => onChange(valeur - 1) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Moins',
        ),
        SizedBox(
          width: 48,
          child: Text('$valeur',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        IconButton.filledTonal(
          onPressed: valeur < 99 ? () => onChange(valeur + 1) : null,
          icon: const Icon(Icons.add),
          tooltip: 'Plus',
        ),
      ],
    );
  }
}

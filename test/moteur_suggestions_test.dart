import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/data/recettes.dart' as data;
import 'package:frigo_malin/models/produit.dart';
import 'package:frigo_malin/models/recette.dart';
import 'package:frigo_malin/services/moteur_suggestions.dart';

final _ref = DateTime(2026, 11, 7, 10);

Produit prod(String nom, int jours) =>
    Produit(nom: nom, datePeremption: DateTime(2026, 11, 7 + jours));

MoteurSuggestions moteur([List<Recette>? r]) =>
    MoteurSuggestions(recettes: r, maintenant: () => _ref);

const _omelette = Recette(
    titre: 'Omelette', ingredients: ['oeuf', 'fromage'], instructions: '.', minutes: 5);
const _compote =
    Recette(titre: 'Compote', ingredients: ['pomme'], instructions: '.', minutes: 5);
const _puree = Recette(
    titre: 'Purée', ingredients: ['pomme de terre'], instructions: '.', minutes: 5);
const _curry = Recette(
    titre: 'Curry', ingredients: ['lait de coco', 'oignon'], instructions: '.', minutes: 5);
const _gateau =
    Recette(titre: 'Gâteau', ingredients: ['lait', 'farine'], instructions: '.', minutes: 5);
const _tarte = Recette(
    titre: 'Tarte', ingredients: ['pate feuilletee', 'pomme'], instructions: '.', minutes: 5);
const _pates =
    Recette(titre: 'Pâtes', ingredients: ['pate', 'tomate'], instructions: '.', minutes: 5);
const _salade = Recette(
    titre: 'Salade', ingredients: ['tomate', 'oeuf', 'salade', 'thon'], instructions: '.', minutes: 5);

void main() {
  test('les 30 recettes sont présentes', () {
    expect(data.recettes.length, 30);
  });

  test('priorité au produit qui périme en premier', () {
    final m = moteur([_compote, _omelette]);
    final s = m.suggerer([prod('Pomme', 0), prod('Oeufs', 6), prod('Fromage', 6)]);
    expect(s.first.recette.titre, 'Compote');
  });

  test('score : 100 si aujourd\'hui, 100-12j de 1 à 7 j, 5 au-delà, +3 par produit, -40 par manque', () {
    final m = moteur([_compote]);
    expect(m.suggerer([prod('Pomme', 0)]).single.score, 103);
    expect(m.suggerer([prod('Pomme', 2)]).single.score, 100 - 24 + 3);
    expect(m.suggerer([prod('Pomme', 20)]).single.score, 8);
    final m2 = moteur([_omelette]);
    expect(m2.suggerer([prod('Oeuf', 0)]).single.score, 103 - 40);
  });

  test('recette complète préférée pour la suggestion du jour', () {
    final m = moteur([_omelette, _compote]);
    final s = m.suggerer([prod('Oeuf', 0), prod('Pomme', 5)]);
    // Omelette incomplète mais mieux notée (103-40=63) que compote (100-60+3=43)
    expect(s.first.recette.titre, 'Omelette');
    expect(m.suggestionDuJour(s)!.recette.titre, 'Compote');
  });

  test('sans recette complète, la meilleure tout court', () {
    final m = moteur([_omelette]);
    final s = m.suggerer([prod('Oeuf', 1)]);
    expect(m.suggestionDuJour(s)!.recette.titre, 'Omelette');
    expect(m.suggestionDuJour([]), isNull);
  });

  test('produits périmés ignorés', () {
    final m = moteur([_compote]);
    expect(m.suggerer([prod('Pomme', -1)]), isEmpty);
  });

  test('« pomme de terre » ne satisfait pas « pomme »', () {
    final m = moteur([_compote, _puree]);
    final s = m.suggerer([prod('Pomme de terre', 1)]);
    expect(s.map((e) => e.recette.titre), ['Purée']);
  });

  test('« lait de coco » ne satisfait pas « lait »', () {
    final m = moteur([_gateau, _curry]);
    final s = m.suggerer([prod('Lait de coco', 1), prod('Oignon', 3)]);
    expect(s.map((e) => e.recette.titre), ['Curry']);
  });

  test('« pâte feuilletée » ne satisfait pas « pâte »', () {
    final m = moteur([_pates, _tarte]);
    final s = m.suggerer([prod('Pâte feuilletée', 2), prod('Tomate', 2)]);
    final pates = s.firstWhere((e) => e.recette.titre == 'Pâtes');
    expect(pates.utilises.map((p) => p.nom), ['Tomate']);
    expect(pates.manquants, ['pate']);
  });

  test('« tomates cerises » satisfait « tomate »', () {
    final m = moteur([_pates]);
    final s = m.suggerer([prod('Pâtes', 30), prod('Tomates cerises', 2)]);
    expect(s.single.complete, isTrue);
  });

  test('correspondance exacte avant partielle', () {
    final m = moteur([_pates]);
    final s = m.suggerer([prod('Pâtes', 40), prod('Pâtes fraîches', 1), prod('Tomate', 1)]);
    expect(s.single.utilises.map((p) => p.nom), contains('Pâtes'));
  });

  test('maximum 2 manquants et au moins 1 trouvé', () {
    final m = moteur([_salade]);
    expect(m.suggerer([prod('Tomate', 1)]), isEmpty); // 3 manquants
    expect(m.suggerer([prod('Tomate', 1), prod('Oeuf', 1)]).single.manquants.length, 2);
    expect(m.suggerer([]), isEmpty);
  });
}

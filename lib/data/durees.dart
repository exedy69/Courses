import '../models/produit.dart';

/// Durées de conservation indicatives (en jours) selon des mots-clés du nom.
/// Pour ajouter une durée : ajoutez une ligne ci-dessous (nom sans accent, au singulier).
const Map<String, int> dureesParNom = {
  'yaourt': 21,
  'lait': 7,
  'fromage': 14,
  'oeuf': 21,
  'poulet': 3,
  'viande': 3,
  'poisson': 2,
  'jambon': 5,
  'lardon': 7,
  'salade': 4,
  'tomate': 7,
  'carotte': 14,
  'pomme de terre': 30,
  'oignon': 30,
  'pomme': 14,
  'banane': 5,
  'pain': 3,
  'creme': 14,
  'beurre': 30,
  'pate': 365,
  'riz': 365,
  'conserve': 365,
  'surgele': 180,
};

bool _contientMots(List<String> motsNom, String cle) {
  final c = cle.split(' ');
  for (var i = 0; i + c.length <= motsNom.length; i++) {
    var ok = true;
    for (var j = 0; j < c.length; j++) {
      if (motsNom[i + j] != c[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// Durée déduite du nom (comparaison sur noms normalisés, mots entiers,
/// la clé la plus longue l'emporte : « pomme de terre » avant « pomme »).
int? dureeDepuisNom(String nom) {
  final mots = normaliser(nom).split(' ').where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return null;
  String? meilleure;
  for (final cle in dureesParNom.keys) {
    if (_contientMots(mots, normaliser(cle))) {
      if (meilleure == null || cle.length > meilleure.length) meilleure = cle;
    }
  }
  return meilleure == null ? null : dureesParNom[meilleure];
}

/// Fragments de catégories Open Food Facts (ex. « en:yogurts ») → durée.
const Map<String, int> _dureesParCategorie = {
  'yogurt': 21,
  'milk': 7,
  'cheese': 14,
  'eggs': 21,
  'poultry': 3,
  'chicken': 3,
  'meat': 3,
  'fish': 2,
  'seafood': 2,
  'ham': 5,
  'bacon': 7,
  'salad': 4,
  'tomato': 7,
  'carrot': 14,
  'potato': 30,
  'onion': 30,
  'apple': 14,
  'banana': 5,
  'bread': 3,
  'cream': 14,
  'butter': 30,
  'pasta': 365,
  'rice': 365,
  'canned': 365,
  'frozen': 180,
};

int? dureeDepuisCategories(String? categories) {
  if (categories == null || categories.isEmpty) return null;
  final c = categories.toLowerCase();
  for (final e in _dureesParCategorie.entries) {
    if (c.contains(e.key)) return e.value;
  }
  return null;
}

import '../models/recette.dart';

/// Pour ajouter une recette : copiez un bloc ci-dessous et adaptez-le.
/// Les ingrédients sont des mots-clés simples (sans quantités).
const List<Recette> recettes = [
  Recette(
    titre: 'Omelette au fromage',
    ingredients: ['oeuf', 'fromage'],
    basiques: ['sel', 'poivre', 'beurre'],
    instructions:
        'Battez les œufs avec une pincée de sel et de poivre, puis versez-les dans une poêle beurrée. Ajoutez le fromage râpé, repliez l\'omelette et servez dès qu\'elle est dorée.',
    minutes: 10,
  ),
  Recette(
    titre: 'Pâtes à la tomate',
    ingredients: ['pate', 'tomate'],
    basiques: ['sel', 'huile', 'ail'],
    instructions:
        'Faites cuire les pâtes dans l\'eau bouillante salée. Pendant ce temps, faites revenir les tomates coupées dans un filet d\'huile pendant 10 minutes, puis mélangez avec les pâtes égouttées.',
    minutes: 20,
  ),
  Recette(
    titre: 'Riz sauté aux légumes',
    ingredients: ['riz', 'carotte', 'oignon'],
    basiques: ['sel', 'huile', 'sauce soja'],
    instructions:
        'Faites cuire le riz, puis laissez-le refroidir un peu. Faites sauter l\'oignon et les carottes en petits dés à l\'huile, ajoutez le riz et poêlez à feu vif quelques minutes.',
    minutes: 25,
  ),
  Recette(
    titre: 'Soupe de légumes',
    ingredients: ['carotte', 'pomme de terre', 'oignon'],
    basiques: ['sel', 'poivre', 'eau'],
    instructions:
        'Épluchez et coupez les légumes en morceaux, puis couvrez-les d\'eau salée et laissez cuire 25 minutes. Mixez le tout et rectifiez l\'assaisonnement.',
    minutes: 35,
  ),
  Recette(
    titre: 'Gratin de pommes de terre',
    ingredients: ['pomme de terre', 'creme', 'fromage'],
    basiques: ['sel', 'poivre', 'ail'],
    instructions:
        'Coupez les pommes de terre en fines rondelles et disposez-les dans un plat avec la crème, le sel et le poivre. Parsemez de fromage râpé et enfournez 45 minutes à 180 °C.',
    minutes: 60,
  ),
  Recette(
    titre: 'Croque-monsieur',
    ingredients: ['pain de mie', 'jambon', 'fromage'],
    basiques: ['beurre'],
    instructions:
        'Garnissez deux tranches de pain de mie de jambon et de fromage, puis refermez. Faites dorer des deux côtés à la poêle ou au four jusqu\'à ce que le fromage fonde.',
    minutes: 10,
  ),
  Recette(
    titre: 'Salade de riz',
    ingredients: ['riz', 'tomate', 'thon'],
    basiques: ['huile', 'vinaigre', 'sel'],
    instructions:
        'Faites cuire le riz et laissez-le refroidir complètement. Mélangez-le avec les tomates en dés et le thon émietté, puis assaisonnez d\'huile et de vinaigre.',
    minutes: 20,
  ),
  Recette(
    titre: 'Poêlée de poulet aux oignons',
    ingredients: ['poulet', 'oignon'],
    basiques: ['sel', 'poivre', 'huile'],
    instructions:
        'Coupez le poulet en morceaux et faites-le dorer à l\'huile 8 minutes. Ajoutez les oignons émincés et poursuivez la cuisson à feu doux pendant 15 minutes.',
    minutes: 30,
  ),
  Recette(
    titre: 'Quiche rapide',
    ingredients: ['oeuf', 'creme', 'lardon', 'pate feuilletee'],
    basiques: ['sel', 'poivre'],
    instructions:
        'Étalez la pâte dans un moule et piquez-la avec une fourchette. Versez le mélange d\'œufs battus, de crème et de lardons, puis enfournez 30 minutes à 180 °C.',
    minutes: 45,
  ),
  Recette(
    titre: 'Pâtes carbonara',
    ingredients: ['pate', 'oeuf', 'lardon', 'fromage'],
    basiques: ['sel', 'poivre'],
    instructions:
        'Faites cuire les pâtes et dorer les lardons à sec. Hors du feu, mélangez les pâtes aux lardons, aux œufs battus et au fromage râpé pour obtenir une sauce onctueuse.',
    minutes: 20,
  ),
  Recette(
    titre: 'Ratatouille',
    ingredients: ['courgette', 'aubergine', 'tomate', 'poivron'],
    basiques: ['sel', 'huile', 'herbes'],
    instructions:
        'Coupez tous les légumes en dés et faites-les revenir séparément à l\'huile. Réunissez-les dans une cocotte et laissez mijoter 30 minutes à couvert.',
    minutes: 50,
  ),
  Recette(
    titre: 'Pain perdu',
    ingredients: ['pain', 'oeuf', 'lait'],
    basiques: ['sucre', 'beurre'],
    instructions:
        'Battez les œufs avec le lait et un peu de sucre, puis trempez-y les tranches de pain rassis. Faites-les dorer dans une poêle beurrée des deux côtés.',
    minutes: 15,
  ),
  Recette(
    titre: 'Purée maison',
    ingredients: ['pomme de terre', 'lait', 'beurre'],
    basiques: ['sel', 'muscade'],
    instructions:
        'Faites cuire les pommes de terre épluchées 20 minutes à l\'eau salée, puis égouttez-les. Écrasez-les avec le beurre et le lait chaud jusqu\'à obtenir une purée lisse.',
    minutes: 30,
  ),
  Recette(
    titre: 'Salade composée',
    ingredients: ['salade', 'tomate', 'oeuf'],
    basiques: ['huile', 'vinaigre', 'sel'],
    instructions:
        'Faites durcir les œufs 10 minutes dans l\'eau bouillante, puis écalez-les. Dressez la salade, les tomates et les œufs coupés, puis assaisonnez.',
    minutes: 15,
  ),
  Recette(
    titre: 'Wrap au poulet',
    ingredients: ['tortilla', 'poulet', 'salade', 'tomate'],
    basiques: ['sauce', 'sel'],
    instructions:
        'Faites dorer le poulet en lamelles à la poêle. Garnissez les tortillas de poulet, de salade et de tomates, ajoutez un peu de sauce et roulez-les.',
    minutes: 15,
  ),
  Recette(
    titre: 'Gratin de pâtes',
    ingredients: ['pate', 'fromage', 'creme', 'jambon'],
    basiques: ['sel', 'poivre'],
    instructions:
        'Faites cuire les pâtes et mélangez-les avec la crème et le jambon en morceaux. Versez dans un plat, couvrez de fromage râpé et faites gratiner 15 minutes au four.',
    minutes: 35,
  ),
  Recette(
    titre: 'Soupe de courgettes',
    ingredients: ['courgette', 'oignon', 'fromage'],
    basiques: ['sel', 'poivre', 'eau'],
    instructions:
        'Faites revenir l\'oignon, ajoutez les courgettes en rondelles et couvrez d\'eau. Après 20 minutes de cuisson, mixez avec le fromage jusqu\'à obtenir une soupe veloutée.',
    minutes: 30,
  ),
  Recette(
    titre: 'Riz au lait',
    ingredients: ['riz', 'lait'],
    basiques: ['sucre', 'vanille'],
    instructions:
        'Portez le lait à frémissement avec le sucre et la vanille, puis versez le riz. Laissez cuire à feu doux 30 minutes en remuant souvent jusqu\'à ce que le mélange épaississe.',
    minutes: 40,
  ),
  Recette(
    titre: 'Tortilla de pommes de terre',
    ingredients: ['pomme de terre', 'oeuf', 'oignon'],
    basiques: ['sel', 'huile'],
    instructions:
        'Faites cuire les pommes de terre et l\'oignon en lamelles à l\'huile jusqu\'à ce qu\'ils soient tendres. Versez les œufs battus par-dessus et cuisez la tortilla de chaque côté.',
    minutes: 40,
  ),
  Recette(
    titre: 'Poisson au four et légumes',
    ingredients: ['poisson', 'courgette', 'tomate'],
    basiques: ['sel', 'huile', 'citron'],
    instructions:
        'Disposez les légumes coupés dans un plat avec un filet d\'huile et enfournez 15 minutes à 200 °C. Ajoutez le poisson, assaisonnez et poursuivez 15 minutes.',
    minutes: 35,
  ),
  Recette(
    titre: 'Chili express',
    ingredients: ['haricot rouge', 'tomate', 'oignon', 'viande hachee'],
    basiques: ['sel', 'piment', 'huile'],
    instructions:
        'Faites revenir l\'oignon puis saisissez la viande hachée. Ajoutez les tomates, les haricots rouges et le piment, puis laissez mijoter 20 minutes.',
    minutes: 35,
  ),
  Recette(
    titre: 'Smoothie anti-gaspi',
    ingredients: ['banane', 'yaourt', 'lait'],
    basiques: ['miel'],
    instructions:
        'Épluchez la banane et coupez-la en morceaux. Mixez-la avec le yaourt et le lait jusqu\'à obtenir une texture lisse, et sucrez au miel si besoin.',
    minutes: 5,
  ),
  Recette(
    titre: 'Compote maison',
    ingredients: ['pomme'],
    basiques: ['sucre', 'cannelle'],
    instructions:
        'Épluchez les pommes et coupez-les en morceaux. Faites-les cuire à feu doux 20 minutes avec un peu d\'eau, puis écrasez-les à la fourchette.',
    minutes: 25,
  ),
  Recette(
    titre: 'Sandwich thon-crudités',
    ingredients: ['pain', 'thon', 'tomate', 'salade'],
    basiques: ['mayonnaise', 'sel'],
    instructions:
        'Ouvrez le pain et tartinez-le de mayonnaise. Garnissez de thon émietté, de rondelles de tomate et de feuilles de salade.',
    minutes: 10,
  ),
  Recette(
    titre: 'Curry de légumes au lait de coco',
    ingredients: ['lait de coco', 'carotte', 'pomme de terre', 'oignon'],
    basiques: ['sel', 'curry', 'huile'],
    instructions:
        'Faites revenir l\'oignon avec le curry, puis ajoutez les carottes et les pommes de terre en dés. Versez le lait de coco et laissez mijoter 25 minutes.',
    minutes: 40,
  ),
  Recette(
    titre: 'Œufs au plat et pommes de terre sautées',
    ingredients: ['oeuf', 'pomme de terre'],
    basiques: ['sel', 'huile', 'poivre'],
    instructions:
        'Faites sauter les pommes de terre en dés à l\'huile pendant 15 minutes jusqu\'à ce qu\'elles soient dorées. Cassez les œufs dans une poêle et cuisez-les au plat.',
    minutes: 25,
  ),
  Recette(
    titre: 'Pizza maison express',
    ingredients: ['pate a pizza', 'tomate', 'fromage'],
    basiques: ['sel', 'huile', 'origan'],
    instructions:
        'Étalez la pâte sur une plaque et garnissez-la de tomates écrasées. Parsemez de fromage et enfournez 15 minutes à 220 °C.',
    minutes: 25,
  ),
  Recette(
    titre: 'Velouté de carottes',
    ingredients: ['carotte', 'oignon', 'creme'],
    basiques: ['sel', 'poivre', 'eau'],
    instructions:
        'Faites cuire les carottes et l\'oignon coupés dans l\'eau salée pendant 25 minutes. Mixez en ajoutant la crème pour une texture veloutée.',
    minutes: 35,
  ),
  Recette(
    titre: 'Pâtes au thon',
    ingredients: ['pate', 'thon', 'tomate'],
    basiques: ['sel', 'huile', 'ail'],
    instructions:
        'Faites cuire les pâtes. Réchauffez les tomates en dés avec le thon et un filet d\'huile, puis mélangez à la sauce avec les pâtes égouttées.',
    minutes: 20,
  ),
  Recette(
    titre: 'Crêpes',
    ingredients: ['oeuf', 'lait', 'farine'],
    basiques: ['sucre', 'beurre', 'sel'],
    instructions:
        'Mélangez la farine, les œufs et le lait jusqu\'à obtenir une pâte fluide, puis laissez reposer 30 minutes. Faites cuire de fines louches de pâte dans une poêle beurrée.',
    minutes: 45,
  ),
];

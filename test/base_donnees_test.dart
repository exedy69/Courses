import 'package:flutter_test/flutter_test.dart';
import 'package:frigo_malin/db/base_donnees.dart';
import 'package:frigo_malin/models/catalogue_item.dart';
import 'package:frigo_malin/models/produit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<BaseDonnees> nouvelleBase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: BaseDonnees.versionSchema,
          onCreate: BaseDonnees.creerSchema,
          singleInstance: false));
  return BaseDonnees.pourTest(db);
}

Produit prod(String nom, {int jours = 5, int quantite = 1, String? code}) => Produit(
    nom: nom,
    datePeremption: aujourdhui().add(Duration(days: jours)),
    quantite: quantite,
    codeBarres: code);

void main() {
  sqfliteFfiInit();
  late BaseDonnees base;
  setUp(() async => base = await nouvelleBase());

  test('migration de la version 1 vers la version 2 sans perte de données', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) => BaseDonnees.creerSchemaV1(db),
            singleInstance: false));
    await db.insert('produits', {
      'uuid': 'u1', 'nom': 'Lait', 'date_peremption': '2026-12-01', 'quantite': 2,
      'date_ajout': '2026-11-01', 'updated_at': '2026-11-01T10:00:00.000Z',
    });
    await db.insert('historique', {
      'uuid': 'h1', 'nom': 'Pain', 'issue': 'jete', 'date_peremption': '2026-11-01',
      'date_action': dateIso(aujourdhui()), 'updated_at': '2026-11-01T10:00:00.000Z',
    });
    await BaseDonnees.migrerSchema(db, 1, 2);
    final b = BaseDonnees.pourTest(db);
    final liste = await b.lister();
    expect(liste.single.nom, 'Lait');
    expect(liste.single.quantite, 2);
    expect(liste.single.auteur, isNull);
    expect((await b.bilan()).jetes, 1);
    // Les anciennes lignes seront envoyées à la première synchro.
    expect((await b.lignesAEnvoyer(tableSync('produits'))).length, 1);
    expect(await b.listerCourses(), isEmpty);
  });

  test('lister : tri par date, suppressions logiques exclues', () async {
    final tard = prod('Tard', jours: 10);
    await base.ajouter(tard);
    await base.ajouter(prod('Tôt', jours: 1));
    final jete = prod('Jeté', jours: 2);
    await base.ajouter(jete);
    await base.supprimer(jete);
    expect([for (final p in await base.lister()) p.nom], ['Tôt', 'Tard']);
    expect(await base.compter(), 2);
    expect([for (final p in await base.listerUrgents(3)) p.nom], ['Tôt']);
  });

  test('listerAvecImages : image du catalogue en une requête', () async {
    await base.upsertCatalogue(const CatalogueItem(
        codeBarres: '123', nom: 'Nutella', source: 'off',
        imageUrl: 'https://images.openfoodfacts.org/x.jpg', updatedAt: '2026-01-01T00:00:00.000Z'));
    await base.ajouter(prod('Nutella', code: '123'));
    await base.ajouter(prod('Sans code', jours: 9));
    final l = await base.listerAvecImages();
    expect(l.first.imageUrl, 'https://images.openfoodfacts.org/x.jpg');
    expect(l.last.imageUrl, isNull);
  });

  test('archivage complet puis annulation', () async {
    final p = prod('Lait');
    await base.ajouter(p);
    final a = await base.archiver(p, 'consomme');
    expect(await base.lister(), isEmpty);
    expect((await base.bilan()).consommes, 1);
    await base.annulerArchivage(a);
    expect((await base.lister()).single.nom, 'Lait');
    expect((await base.bilan()).total, 0);
  });

  test('archivage partiel : la quantité diminue, annulation possible', () async {
    final p = prod('Yaourt', quantite: 4);
    await base.ajouter(p);
    final a = await base.archiver(p, 'jete', nombre: 1);
    expect((await base.lister()).single.quantite, 3);
    expect((await base.bilan()).jetes, 1);
    await base.annulerArchivage(a);
    expect((await base.lister()).single.quantite, 4);
    expect((await base.bilan()).jetes, 0);
  });

  test('liste de courses : pas de doublon, cocher, retirer les cochés', () async {
    expect(await base.ajouterCourse('Tomates'), isTrue);
    expect(await base.ajouterCourse('tomate'), isFalse);
    expect(await base.ajouterCourse('   '), isFalse);
    expect(await base.ajouterCourse('=HYPERLINK("x")'), isTrue);
    final liste = await base.listerCourses();
    expect(liste.map((a) => a.nom), containsAll(['Tomates', 'HYPERLINK("x")']));
    await base.cocherCourse(liste.firstWhere((a) => a.nom == 'Tomates'), true);
    await base.viderCoursesCochees();
    expect((await base.listerCourses()).map((a) => a.nom), ['HYPERLINK("x")']);
  });

  test('idées de rachat : terminés récemment, absents du stock et de la liste', () async {
    final lait = prod('Lait');
    final pain = prod('Pain');
    await base.ajouter(lait);
    await base.ajouter(pain);
    await base.archiver(lait, 'consomme');
    await base.archiver(pain, 'consomme');
    await base.ajouterCourse('Pain');
    expect(await base.recemmentTermines(), ['Lait']);
  });

  test('synchro : marquage des lignes envoyées, sauf si modifiées entre-temps', () async {
    final t = tableSync('produits');
    final p = prod('Lait');
    await base.ajouter(p);
    final envoi = await base.lignesAEnvoyer(t);
    expect(envoi.single.containsKey('photo_path'), isFalse);
    p.quantite = 3;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await base.modifier(p);
    await base.marquerEnvoyees(t, envoi);
    expect((await base.lignesAEnvoyer(t)).length, 1);
    await base.marquerEnvoyees(t, await base.lignesAEnvoyer(t));
    expect(await base.lignesAEnvoyer(t), isEmpty);
  });

  test('synchro : application distante tolérante (texte, dates longues, lignes invalides)', () async {
    final t = tableSync('produits');
    final n = await base.appliquerDistant(t, [
      {
        'uuid': 'r1', 'nom': 'Du Sheet', 'date_peremption': '2026-12-24T00:00:00.000Z',
        'quantite': '3', 'updated_at': '2026-11-01T10:00:00.000Z', 'code_barres': '',
      },
      {'uuid': 'r2', 'nom': null, 'date_peremption': '2026-12-24', 'updated_at': 'x'},
      {'nom': 'Sans clé', 'date_peremption': '2026-12-24', 'updated_at': 'x'},
    ]);
    expect(n, 1);
    final p = (await base.lister()).single;
    expect(p.quantite, 3);
    expect(dateIso(p.datePeremption), '2026-12-24');
    expect(p.codeBarres, isNull);
    // Une version plus ancienne ne remplace rien.
    expect(
        await base.appliquerDistant(t, [
          {'uuid': 'r1', 'nom': 'Vieux', 'date_peremption': '2026-12-24', 'updated_at': '2020-01-01T00:00:00.000Z'}
        ]),
        0);
    expect(await base.lignesAEnvoyer(t), isEmpty);
  });

  test('purge : uniquement les vieilles lignes supprimées déjà envoyées', () async {
    final t = tableSync('produits');
    final vieux = '2020-01-01T00:00:00.000Z';
    await base.appliquerDistant(t, [
      {'uuid': 'v', 'nom': 'Vieux supprimé', 'date_peremption': '2020-01-01', 'updated_at': vieux, 'deleted_at': vieux},
      {'uuid': 'n', 'nom': 'Vivant', 'date_peremption': '2030-01-01', 'updated_at': vieux},
    ]);
    await base.purger();
    final restant = await base.appliquerDistant(t, [
      {'uuid': 'v', 'nom': 'Vieux supprimé', 'date_peremption': '2020-01-01', 'updated_at': vieux, 'deleted_at': vieux},
    ]);
    expect(restant, 1, reason: 'la ligne purgée n\'existe plus localement');
    expect((await base.lister()).single.nom, 'Vivant');
  });
}

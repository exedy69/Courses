import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_flash/data/exemple.dart';
import 'package:memo_flash/db/base_donnees.dart';
import 'package:memo_flash/models/carte.dart';
import 'package:memo_flash/services/planificateur.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<BaseDonnees> nouvelleBase() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: BaseDonnees.versionSchema,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: BaseDonnees.creerSchema,
      singleInstance: false,
    ),
  );
  return BaseDonnees.pourTest(db);
}

void main() {
  sqfliteFfiInit();
  late BaseDonnees base;
  late int paquet;
  final t = DateTime(2026, 3, 10, 10);

  setUp(() async {
    base = await nouvelleBase();
    paquet = await base.creerPaquet('Anglais');
  });

  Future<void> ajouter(int n, {DateTime? quand}) => base.ajouterCartes([
    for (var i = 0; i < n; i++)
      Carte.nouvelle(paquetId: paquet, recto: 'q$i', verso: 'r$i', maintenant: quand ?? t),
  ]);

  test('les nouvelles cartes sortent dans l\'ordre d\'ajout', () async {
    await ajouter(3);
    final c = await base.prochaineCarte(paquet, maintenant: t);
    expect(c!.recto, 'q0');
    final cpt = await base.compteurs(paquet, maintenant: t);
    expect(cpt.nouvelles, 3);
    expect(cpt.total, 3);
  });

  test('limite de nouvelles cartes par jour, remise à zéro le lendemain', () async {
    await base.ecrireReglage('nouvelles_par_jour', '2');
    await ajouter(5);
    for (var i = 0; i < 2; i++) {
      final c = await base.prochaineCarte(paquet, maintenant: t);
      await base.repondre(c!, Note.facile, maintenant: t);
    }
    expect((await base.compteurs(paquet, maintenant: t)).nouvelles, 0);
    expect(await base.prochaineCarte(paquet, maintenant: t), isNull);
    final demain = t.add(const Duration(days: 1));
    expect((await base.compteurs(paquet, maintenant: demain)).nouvelles, 2);
  });

  test('une séance complète : apprentissage puis révision le lendemain', () async {
    await ajouter(1);
    var c = (await base.prochaineCarte(paquet, maintenant: t))!;
    await base.repondre(c, Note.correct, maintenant: t); // étape 2 : 10 min
    // Rien d'autre : la carte est montrée en avance (moins de 20 min).
    c = (await base.prochaineCarte(paquet, maintenant: t))!;
    expect(c.etat, EtatCarte.apprentissage);
    expect((await base.compteurs(paquet, maintenant: t)).apprentissage, 1);
    await base.repondre(c, Note.correct, maintenant: t.add(const Duration(minutes: 10)));
    expect(await base.prochaineCarte(paquet, maintenant: t), isNull);

    final demain = DateTime(2026, 3, 11, 8);
    final cpt = await base.compteurs(paquet, maintenant: demain);
    expect(cpt.revision, 1);
    c = (await base.prochaineCarte(paquet, maintenant: demain))!;
    expect(c.etat, EtatCarte.revision);
  });

  test('sauf : la carte qu\'on vient de voir passe après les autres', () async {
    await ajouter(2);
    final a = (await base.prochaineCarte(paquet, maintenant: t))!;
    await base.repondre(a, Note.aRevoir, maintenant: t);
    final plusTard = t.add(const Duration(minutes: 2));
    // a est échue (1 min) mais on vient de la voir : b passe d'abord.
    final b = (await base.prochaineCarte(paquet, maintenant: plusTard, sauf: a.id))!;
    expect(b.recto, 'q1');
    // Sans autre choix, a revient.
    await base.repondre(b, Note.facile, maintenant: plusTard);
    final encore = await base.prochaineCarte(paquet, maintenant: plusTard, sauf: a.id);
    expect(encore!.id, a.id);
  });

  test('annuler une réponse restaure la carte et efface le journal', () async {
    await ajouter(1);
    final c = (await base.prochaineCarte(paquet, maintenant: t))!;
    final r = await base.repondre(c, Note.facile, maintenant: t);
    expect((await base.carte(c.id!))!.etat, EtatCarte.revision);
    await base.annuler(r);
    expect((await base.carte(c.id!))!.etat, EtatCarte.nouvelle);
    expect(await base.revisionsDepuis(DateTime(2000)), isEmpty);
  });

  test('recherche insensible à la casse, caractères spéciaux échappés', () async {
    await base.ajouterCartes([
      Carte.nouvelle(paquetId: paquet, recto: 'Hello', verso: 'Bonjour'),
      Carte.nouvelle(paquetId: paquet, recto: '50 %', verso: 'moitié'),
      Carte.nouvelle(paquetId: paquet, recto: 'Cat', verso: 'Chat'),
    ]);
    expect((await base.listerCartes(paquet, recherche: 'bonj')).single.recto, 'Hello');
    expect((await base.listerCartes(paquet, recherche: '%')).single.recto, '50 %');
    expect(await base.listerCartes(paquet, recherche: '_'), isEmpty);
  });

  test('supprimer un paquet supprime ses cartes et son journal', () async {
    await ajouter(2);
    final c = (await base.prochaineCarte(paquet, maintenant: t))!;
    await base.repondre(c, Note.correct, maintenant: t);
    await base.supprimerPaquet(paquet);
    expect(await base.listerPaquets(), isEmpty);
    expect((await base.repartition()).values.every((n) => n == 0), isTrue);
    expect(await base.revisionsDepuis(DateTime(2000)), isEmpty);
  });

  test('réinitialiser un paquet remet les cartes en nouvelles', () async {
    await ajouter(1);
    final c = (await base.prochaineCarte(paquet, maintenant: t))!;
    await base.repondre(c, Note.facile, maintenant: t);
    await base.reinitialiserPaquet(paquet);
    expect((await base.carte(c.id!))!.etat, EtatCarte.nouvelle);
  });

  test('prévision : cartes en révision par jour, retards comptés aujourd\'hui', () async {
    await ajouter(2);
    final cartes = await base.listerCartes(paquet);
    await base.modifierCarte(
      cartes[0].copier(etat: EtatCarte.revision, echeance: debutJour(numeroJour(t) - 3)),
    );
    await base.modifierCarte(
      cartes[1].copier(etat: EtatCarte.revision, echeance: debutJour(numeroJour(t) + 2)),
    );
    expect(await base.prevision(7, maintenant: t), [1, 0, 1, 0, 0, 0, 0]);
  });

  test('sauvegarde complète puis restauration à l\'identique', () async {
    await ajouter(3);
    final c = (await base.prochaineCarte(paquet, maintenant: t))!;
    await base.repondre(c, Note.facile, maintenant: t);
    final json = jsonEncode(await base.exporterTout());

    final autre = await nouvelleBase();
    await autre.creerPaquet('À écraser');
    await autre.restaurerTout(jsonDecode(json) as Map<String, Object?>);
    final paquets = await autre.listerPaquets();
    expect(paquets.single.nom, 'Anglais');
    final cartes = await autre.listerCartes(paquets.single.id!);
    expect(cartes.length, 3);
    expect(cartes.first.etat, EtatCarte.revision);
    expect((await autre.revisionsDepuis(DateTime(2000))).length, 1);
    // Les nouvelles cartes ajoutées ensuite ne réutilisent pas les identifiants.
    await autre.ajouterCartes([
      Carte.nouvelle(paquetId: paquets.single.id!, recto: 'x', verso: 'y'),
    ]);
    expect((await autre.listerCartes(paquets.single.id!)).length, 4);
  });

  test('restaurer refuse un texte qui n\'est pas une sauvegarde', () async {
    expect(() => base.restaurerTout({'format': 'autre'}), throwsFormatException);
    expect((await base.listerPaquets()).length, 1);
  });

  test('le paquet d\'exemple n\'est créé qu\'une fois', () async {
    final b = await nouvelleBase();
    await creerPaquetExempleSiBesoin(b);
    await creerPaquetExempleSiBesoin(b);
    final paquets = await b.listerPaquets();
    expect(paquets.length, 1);
    expect((await b.listerCartes(paquets.single.id!)).length, 10);
  });
}

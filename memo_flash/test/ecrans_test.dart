import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:memo_flash/data/exemple.dart';
import 'package:memo_flash/db/base_donnees.dart';
import 'package:memo_flash/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Les accès SQLite sont de vraies E/S : on les laisse s'exécuter hors de
/// l'horloge simulée, puis on redessine.
Future<void> attendre(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  sqfliteFfiInit();

  testWidgets('parcours : paquet d\'exemple, révision, réponse, statistiques', (tester) async {
    await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: BaseDonnees.versionSchema,
          onCreate: BaseDonnees.creerSchema,
          singleInstance: false,
        ),
      );
      await creerPaquetExempleSiBesoin(BaseDonnees.pourTest(db, installer: true));
    });

    await tester.pumpWidget(const MemoFlashApp());
    await attendre(tester);
    expect(find.text('Exemple : capitales'), findsOneWidget);
    expect(find.text('10 cartes à voir aujourd\'hui'), findsOneWidget);

    await tester.tap(find.text('Exemple : capitales'));
    await attendre(tester);
    await tester.tap(find.text('Réviser'));
    await attendre(tester);

    expect(find.text('Capitale de l\'Australie ?'), findsOneWidget);
    await tester.tap(find.text('Afficher la réponse'));
    await tester.pump();
    expect(find.text('Canberra'), findsOneWidget);
    expect(find.text('Facile'), findsOneWidget);
    expect(find.text('4 j'), findsOneWidget);

    await tester.tap(find.text('Correct'));
    await attendre(tester);
    expect(find.text('Capitale du Canada ?'), findsOneWidget);

    // Annuler ramène la carte précédente.
    await tester.tap(find.byIcon(Icons.undo));
    await attendre(tester);
    expect(find.text('Capitale de l\'Australie ?'), findsOneWidget);

    // Retour à l'accueil puis statistiques.
    await tester.binding.handlePopRoute();
    await attendre(tester);
    await tester.binding.handlePopRoute();
    await attendre(tester);
    await tester.tap(find.text('Statistiques'));
    await attendre(tester);
    expect(find.text('Réussite'), findsOneWidget);
    expect(find.text('Révisions des 14 derniers jours'), findsOneWidget);
  });
}

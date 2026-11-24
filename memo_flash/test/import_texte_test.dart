import 'package:flutter_test/flutter_test.dart';
import 'package:memo_flash/models/carte.dart';
import 'package:memo_flash/services/import_texte.dart';

void main() {
  test('séparateurs : tabulation, point-virgule, égal', () {
    final a = analyserTexte('chat\tcat\nchien ; dog\nmaison = house');
    expect(a.paires.map((p) => '${p.recto}|${p.verso}'), ['chat|cat', 'chien|dog', 'maison|house']);
    expect(a.lignesIgnorees, isEmpty);
  });

  test('la tabulation prime : un « ; » dans le verso est conservé', () {
    final a = analyserTexte('Liste\tun ; deux ; trois');
    expect(a.paires.single.verso, 'un ; deux ; trois');
  });

  test('lignes vides et commentaires ignorés, lignes invalides signalées', () {
    final a = analyserTexte('# titre\n\nsans séparateur\nrecto ;\r\nok;bien\n');
    expect(a.paires.single.recto, 'ok');
    expect(a.lignesIgnorees, [3, 4]);
  });

  test('guillemets et <br> d\'un export Anki', () {
    final a = analyserTexte('"Il a dit ""oui"""\tligne 1<br>ligne 2');
    expect(a.paires.single.recto, 'Il a dit "oui"');
    expect(a.paires.single.verso, 'ligne 1\nligne 2');
  });

  test('export puis réimport sans perte', () {
    final cartes = [
      Carte.nouvelle(paquetId: 1, recto: 'a\tb', verso: 'deux\nlignes'),
      Carte.nouvelle(paquetId: 1, recto: 'x', verso: 'y ; z'),
    ];
    final texte = exporterTexte(cartes);
    final a = analyserTexte(texte);
    expect(a.paires.length, 2);
    expect(a.paires[0].recto, 'a b');
    expect(a.paires[0].verso, 'deux\nlignes');
    expect(a.paires[1].verso, 'y ; z');
  });
}

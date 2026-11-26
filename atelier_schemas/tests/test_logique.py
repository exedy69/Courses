"""Tests sans interface : symboles, contenu, schémas, quiz, progression."""

import random
import sqlite3
import tempfile
import unittest
import xml.etree.ElementTree as ET
from datetime import date, timedelta
from pathlib import Path

from atelier import contenu
from atelier.progression import Progression
from atelier.quiz import CHOIX, ORDRE, Session
from atelier.schemas import SCHEMAS, polylignes, position_borne, tourner
from atelier.symboles import SYMBOLES, svg

JOUR = date(2026, 11, 26)


def _sur_polyligne(point, seg):
    x, y = point
    for (x1, y1), (x2, y2) in zip(seg, seg[1:]):
        if (min(x1, x2) <= x <= max(x1, x2) and min(y1, y2) <= y <= max(y1, y2)
                and (x - x1) * (y2 - y1) == (y - y1) * (x2 - x1)):
            return True
    return False


class TestSymboles(unittest.TestCase):
    def test_svg_valides(self):
        for sid in SYMBOLES:
            with self.subTest(sid):
                racine = ET.fromstring(svg(sid, broches=("A", "B", "C", "D")))
                self.assertTrue(racine.tag.endswith("svg"))
                self.assertNotIn("{c}", svg(sid))

    def test_prefixes(self):
        self.assertEqual(SYMBOLES["resistance"].prefixe, "R")
        self.assertEqual(SYMBOLES["mosfet_p"].prefixe, "Q")
        self.assertEqual(SYMBOLES["ci"].prefixe, "U")


class TestContenu(unittest.TestCase):
    def setUp(self):
        self.rng = random.Random(42)

    def test_tension_du_net(self):
        self.assertEqual(contenu.tension_du_net("PP3V3_S5"), "3,3 V")
        self.assertEqual(contenu.tension_du_net("PP5V_S3"), "5 V")
        self.assertEqual(contenu.tension_du_net("PP3V42_G3H"), "3,42 V")
        self.assertEqual(contenu.tension_du_net("PP1V05_S0"), "1,05 V")
        with self.assertRaises(ValueError):
            contenu.tension_du_net("PPBUS_G3H")

    def test_questions_coherentes(self):
        for niveau in contenu.NIVEAUX_JOUABLES:
            qs = contenu.questions(niveau, self.rng)
            self.assertGreater(len(qs), 20)
            ids = [q.id for q in qs]
            self.assertEqual(len(ids), len(set(ids)), "ids en double")
            for q in qs:
                with self.subTest(q.id):
                    self.assertEqual(q.niveau, niveau)
                    self.assertTrue(q.explication)
                    if q.type == CHOIX:
                        self.assertEqual(len(q.choix), 4)
                        self.assertEqual(len(set(q.choix)), 4)
                        self.assertTrue(0 <= q.bonne < 4)
                        self.assertTrue(q.est_juste(q.bonne))
                        faux = (q.bonne + 1) % 4
                        self.assertFalse(q.est_juste(faux))
                    elif q.type == ORDRE:
                        textes = [c.texte for c in q.choix]
                        self.assertEqual(sorted(textes), sorted(q.ordre))
                        self.assertNotEqual(tuple(textes), q.ordre)
                        bon = tuple(textes.index(e) for e in q.ordre)
                        self.assertTrue(q.est_juste(bon))
                        self.assertFalse(q.est_juste(bon[::-1]))
                        self.assertFalse(q.est_juste(bon[:-1]))
                        self.assertGreaterEqual(q.duree, 30)
                    else:
                        schema = SCHEMAS[q.schema]
                        genre, cibles = q.cible
                        for c in cibles:
                            if genre == "composant":
                                schema.composant(c)
                            else:
                                schema.net(c)
                        self.assertTrue(q.est_juste((genre, next(iter(cibles)))))
                        self.assertFalse(q.est_juste(("net", "INEXISTANT")))
                        self.assertFalse(q.est_juste(None))

    def test_ids_stables_entre_tirages(self):
        a = {q.id for q in contenu.toutes_les_questions(random.Random(1))}
        b = {q.id for q in contenu.toutes_les_questions(random.Random(2))}
        self.assertEqual(a, b)

    def test_bonne_tension_parmi_les_choix(self):
        for q in contenu.questions(2, self.rng):
            if q.id.startswith("tension:"):
                rail = q.id.split(":", 1)[1]
                self.assertEqual(q.choix[q.bonne].texte,
                                 contenu.tension_du_net(rail))


class TestSchemas(unittest.TestCase):
    def test_rotation(self):
        self.assertEqual(tourner((10, 50), 0), (10, 50))
        self.assertEqual(tourner((10, 50), 90), (60, 0))
        self.assertEqual(tourner((110, 50), 90), (60, 100))
        self.assertEqual(tourner((10, 50), 180), (110, 50))
        self.assertEqual(tourner((10, 50), 270), (60, 100))

    def test_chaque_borne_est_raccordee(self):
        for schema in SCHEMAS.values():
            extremites = set()
            for net in schema.nets:
                for seg in polylignes(schema, net):
                    extremites.add(seg[0])
                    extremites.add(seg[-1])
            for comp in schema.composants:
                for borne in SYMBOLES[comp.symbole].bornes:
                    with self.subTest(f"{comp.ref}.{borne}"):
                        p = position_borne(schema, f"{comp.ref}.{borne}")
                        if borne in comp.nc:
                            self.assertNotIn(p, extremites)
                        else:
                            self.assertIn(p, extremites)

    def test_segments_orthogonaux_et_jonctions(self):
        for schema in SCHEMAS.values():
            for net in schema.nets:
                segs = polylignes(schema, net)
                for seg in segs:
                    for (x1, y1), (x2, y2) in zip(seg, seg[1:]):
                        self.assertTrue(x1 == x2 or y1 == y2, net.nom)
                for j in net.jonctions:
                    self.assertTrue(any(_sur_polyligne(j, s) for s in segs),
                                    f"jonction {j} hors de {net.nom}")

    def test_dans_le_cadre(self):
        for schema in SCHEMAS.values():
            for net in schema.nets:
                for seg in polylignes(schema, net):
                    for x, y in seg:
                        self.assertTrue(0 <= x <= schema.largeur)
                        self.assertTrue(0 <= y <= schema.hauteur)


class TestOrdre(unittest.TestCase):
    def test_chrono_propre_et_lenteur(self):
        q = next(q for q in contenu.questions(4, random.Random(0))
                 if q.type == ORDRE)
        bon = tuple([c.texte for c in q.choix].index(e) for e in q.ordre)
        s = Session([q, q, q], chrono=20)
        self.assertEqual(s.limite(), q.duree)
        r = s.repondre(bon, 25)              # au-delà de 20 s mais permis
        self.assertTrue(r.juste)
        self.assertFalse(r.lent)
        self.assertTrue(s.repondre(bon, q.duree * 0.8).lent)
        self.assertFalse(s.repondre(bon, q.duree + 1).juste)
        self.assertIn(" → ", q.texte_bonne_reponse())


class TestSession(unittest.TestCase):
    def setUp(self):
        self.qs = [q for q in contenu.questions(2, random.Random(3))][:3]

    def test_deroule(self):
        s = Session(list(self.qs), chrono=20)
        r = s.repondre(self.qs[0].bonne if self.qs[0].type == CHOIX
                       else ("x", "y"), 2.0)
        self.assertEqual(r.juste, self.qs[0].type == CHOIX)
        s.repondre(None, 20)           # chrono écoulé
        self.assertFalse(s.reponses[-1].juste)
        q = s.question
        s.repondre(q.bonne, 25)        # juste mais hors délai
        self.assertFalse(s.reponses[-1].juste)
        self.assertTrue(s.terminee)
        self.assertEqual(len(s.erreurs), 3 - s.score)
        with self.assertRaises(RuntimeError):
            s.repondre(0, 1)

    def test_lent(self):
        q = next(q for q in self.qs if q.type == CHOIX)
        s = Session([q, q])
        self.assertFalse(s.repondre(q.bonne, 3).lent)
        self.assertTrue(s.repondre(q.bonne, 15).lent)


class TestProgression(unittest.TestCase):
    def setUp(self):
        self.p = Progression()

    def test_leitner(self):
        p = self.p
        p.enregistrer("a", 1, juste=True, aujourdhui=JOUR)
        self.assertEqual(p.carte("a")["boite"], 2)
        self.assertEqual(p.carte("a")["echeance"],
                         (JOUR + timedelta(days=1)).isoformat())
        p.enregistrer("a", 1, juste=True, lent=True, aujourdhui=JOUR)
        self.assertEqual(p.carte("a")["boite"], 2)
        for _ in range(10):
            p.enregistrer("a", 1, juste=True, aujourdhui=JOUR)
        self.assertEqual(p.carte("a")["boite"], 5)
        p.enregistrer("a", 1, juste=False, aujourdhui=JOUR)
        c = p.carte("a")
        self.assertEqual((c["boite"], c["echeance"]), (1, JOUR.isoformat()))
        self.assertEqual(c["vues"], 13)
        self.assertEqual(c["reussites"], 12)

    def test_choix_priorise_les_dues(self):
        qs = contenu.questions(1, random.Random(0))
        due, plus_tard = qs[0], qs[1]
        self.p.enregistrer(due.id, 1, juste=False, aujourdhui=JOUR)
        self.p.enregistrer(plus_tard.id, 1, juste=True, aujourdhui=JOUR)
        choisies = self.p.choisir(qs, 5, random.Random(0), aujourdhui=JOUR)
        self.assertIn(due, choisies)
        self.assertNotIn(plus_tard, choisies)   # il reste des nouvelles
        dues = self.p.choisir(qs, 5, random.Random(0), aujourdhui=JOUR,
                              seulement_dues=True)
        self.assertEqual(dues, [due])
        self.assertEqual(self.p.nombre_dues(JOUR), 1)

    def test_stats(self):
        ids = ["a", "b", "c"]
        for _ in range(3):
            self.p.enregistrer("a", 1, True, aujourdhui=JOUR)
        self.p.enregistrer("b", 1, False, aujourdhui=JOUR)
        s = self.p.stats_niveau(1, ids, JOUR)
        self.assertEqual(s, {"total": 3, "vues": 2, "acquises": 1, "dues": 1})

    def test_fichier_et_version(self):
        with tempfile.TemporaryDirectory() as d:
            chemin = str(Path(d) / "p.db")
            p = Progression(chemin)
            p.enregistrer("a", 2, True, aujourdhui=JOUR)
            p.enregistrer_session("Niveau 2", 9, 12, 80.5, JOUR)
            p.fermer()
            p = Progression(chemin)            # réouverture : rien ne casse
            self.assertEqual(p.carte("a")["boite"], 2)
            self.assertEqual(p.dernieres_sessions()[0]["score"], 9)
            p.fermer()
            v = sqlite3.connect(chemin).execute("PRAGMA user_version")
            self.assertEqual(v.fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()

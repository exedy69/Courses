"""Tests de l'interface Qt, en mode hors écran (QT_QPA_PLATFORM=offscreen)."""

import os
import random
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_LOGGING_RULES", "qt.qpa.*=false")

from PySide6.QtCore import QPointF  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from atelier.interface import STYLE, FenetrePrincipale  # noqa: E402
from atelier.progression import Progression  # noqa: E402
from atelier.quiz import CHOIX  # noqa: E402
from atelier.schemas import SCHEMAS  # noqa: E402
from atelier.symboles import SYMBOLES  # noqa: E402
from atelier.vue_schema import VueSchema  # noqa: E402

app = QApplication.instance() or QApplication([])
app.setStyleSheet(STYLE)


class TestVueSchema(unittest.TestCase):
    def setUp(self):
        self.vue = VueSchema()
        self.vue.resize(1100, 360)
        self.vue.show()
        self.schema = SCHEMAS["rail_3v3"]
        self.vue.charger(self.schema)
        app.processEvents()

    def _cle(self, x, y):
        return self.vue.cle_sous(self.vue.mapFromScene(QPointF(x, y)))

    def test_clic_sur_chaque_composant(self):
        for comp in self.schema.composants:
            item = next(i for i in self.vue._groupes[("composant", comp.ref)]
                        if hasattr(i, "comp"))
            centre = item.mapToScene(item.shape().boundingRect().center())
            with self.subTest(comp.ref):
                self.assertEqual(self._cle(centre.x(), centre.y()),
                                 ("composant", comp.ref))

    def test_clic_sur_les_noms_de_nets(self):
        for net in self.schema.nets:
            if not net.etiquette:
                continue
            texte = next(i for i in self.vue._groupes[("net", net.nom)]
                         if hasattr(i, "text"))
            centre = texte.sceneBoundingRect().center()
            with self.subTest(net.nom):
                self.assertEqual(self._cle(centre.x(), centre.y()),
                                 ("net", net.nom))

    def test_signal_clique(self):
        recus = []
        self.vue.clique.connect(lambda g, i: recus.append((g, i)))
        self.vue.clique.emit("net", "PPBUS_G3H")
        self.assertEqual(recus, [("net", "PPBUS_G3H")])


class TestFenetre(unittest.TestCase):
    def setUp(self):
        self.fenetre = FenetrePrincipale(Progression(), random.Random(7))
        self.fenetre.show()
        app.processEvents()

    def tearDown(self):
        self.fenetre.quiz.arreter()
        self.fenetre.close()

    def _jouer(self, juste):
        quiz = self.fenetre.quiz
        n = 0
        while self.fenetre.pile.currentWidget() is quiz:
            q = quiz.session.question
            if q.type == CHOIX:
                quiz._choisir(q.bonne if juste else (q.bonne + 1) % 4)
            else:
                genre, ids = q.cible
                quiz._clic_schema(genre, sorted(ids)[0] if juste else "AUCUN")
            app.processEvents()
            self.assertTrue(quiz.suivant.isEnabled())
            quiz._suivante()
            app.processEvents()
            n += 1
        return n

    def test_session_parfaite_niveau_1_et_2(self):
        for niveau in (1, 2):
            self.fenetre.lancer_niveau(niveau)
            n = self._jouer(juste=True)
            self.assertEqual(n, 12)
            res = self.fenetre.resultats
            self.assertIs(self.fenetre.pile.currentWidget(), res)
            self.assertEqual(res.score.text(), "12/12")
            self.assertFalse(res.b_erreurs.isEnabled())

    def test_erreurs_puis_revision(self):
        self.fenetre.lancer_niveau(2)
        self._jouer(juste=False)
        res = self.fenetre.resultats
        self.assertEqual(res.score.text(), "0/12")
        self.assertIn("À revoir", res.erreurs.text())
        self.assertEqual(self.fenetre.progression.nombre_dues(), 12)
        res._refaire_erreurs()
        self.assertEqual(self._jouer(juste=True), 12)
        self.fenetre.afficher_accueil()
        # Rattrapées juste : boîte 2, plus rien à revoir aujourd'hui.
        self.assertIn("rien à revoir",
                      self.fenetre.accueil.bouton_revision.text())

    def test_chrono_ecoule(self):
        self.fenetre.lancer_niveau(1)
        quiz = self.fenetre.quiz
        quiz._valider(None, temps=quiz.session.chrono)
        self.assertIn("Temps écoulé", quiz.retour.text())
        self.assertFalse(quiz.session.reponses[0].juste)

    def test_choix_en_symboles(self):
        quiz = self.fenetre.quiz
        self.fenetre.lancer_niveau(1)
        for _ in range(40):
            q = quiz.session.question
            if q.type == CHOIX and q.choix[0].symbole:
                self.assertFalse(quiz.boutons[0].icon().isNull())
                quiz._choisir((q.bonne + 1) % 4)
                self.assertIn("encadré en vert", quiz.retour.text())
                return
            self.fenetre.lancer_niveau(1)
        self.skipTest("aucune question à symboles tirée")

    def test_symboles_connus(self):
        self.assertIn("mosfet_p", SYMBOLES)


if __name__ == "__main__":
    unittest.main()

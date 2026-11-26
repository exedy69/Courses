"""Tests du cours « Analyser avant de réparer »."""

import os
import random
import unittest
from html.parser import HTMLParser

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_LOGGING_RULES", "qt.qpa.*=false")

from PySide6.QtWidgets import QApplication  # noqa: E402

from atelier import contenu, cours  # noqa: E402
from atelier.interface import STYLE, FenetrePrincipale  # noqa: E402
from atelier.progression import Progression  # noqa: E402
from atelier.quiz import CHOIX  # noqa: E402
from atelier.schemas import SCHEMAS  # noqa: E402

app = QApplication.instance() or QApplication([])
app.setStyleSheet(STYLE)


class _Balises(HTMLParser):
    """Vérifie que les balises ouvertes sont refermées (hors balises vides)."""
    VIDES = {"br", "hr", "img"}

    def __init__(self):
        super().__init__()
        self.pile = []

    def handle_starttag(self, tag, attrs):
        if tag not in self.VIDES:
            self.pile.append(tag)

    def handle_endtag(self, tag):
        assert self.pile and self.pile[-1] == tag, f"</{tag}> inattendu"
        self.pile.pop()


class TestContenuCours(unittest.TestCase):
    def test_chapitres(self):
        self.assertGreaterEqual(len(cours.CHAPITRES), 5)
        for ch in cours.CHAPITRES:
            with self.subTest(ch.titre):
                p = _Balises()
                p.feed(ch.html)
                self.assertEqual(p.pile, [])
                if ch.schema:
                    schema = SCHEMAS[ch.schema]
                    for genre, ident, _ in ch.surlignage:
                        (schema.net if genre == "net"
                         else schema.composant)(ident)

    def test_questions(self):
        qs = contenu.questions(cours.NIVEAU_COURS, random.Random(1))
        self.assertGreaterEqual(len(qs), 12)
        self.assertEqual(len({q.id for q in qs}), len(qs))
        for q in qs:
            with self.subTest(q.id):
                self.assertEqual(q.niveau, cours.NIVEAU_COURS)
                self.assertTrue(q.explication)
                if q.type == CHOIX:
                    self.assertEqual(len(set(q.choix)), 4)
                else:
                    genre, ids = q.cible
                    for i in ids:
                        (SCHEMAS[q.schema].net if genre == "net"
                         else SCHEMAS[q.schema].composant)(i)

    def test_dans_la_revision(self):
        ids = {q.id for q in contenu.toutes_les_questions(random.Random(0))}
        self.assertIn("methode:premier_absent", ids)


class TestPageCours(unittest.TestCase):
    def setUp(self):
        self.f = FenetrePrincipale(Progression(), random.Random(3))
        self.f.show()
        app.processEvents()

    def tearDown(self):
        self.f.quiz.arreter()
        self.f.close()

    def test_lecture_puis_quiz(self):
        self.f.lire_cours()
        page = self.f.cours
        self.assertIs(self.f.pile.currentWidget(), page)
        self.assertFalse(page.precedent.isEnabled())
        vus_avec_schema = 0
        for i in range(len(cours.CHAPITRES)):
            self.assertEqual(page.index, i)
            self.assertIn(cours.CHAPITRES[i].titre, page.titre.text())
            vus_avec_schema += page.vue.isVisible()
            if i < len(cours.CHAPITRES) - 1:
                page.suivant.click()
                app.processEvents()
        self.assertGreaterEqual(vus_avec_schema, 1)
        self.assertIn("quiz", page.suivant.text())
        page.precedent.click()
        self.assertEqual(page.index, len(cours.CHAPITRES) - 2)
        page.aller(len(cours.CHAPITRES) - 1)
        page.suivant.click()
        app.processEvents()
        quiz = self.f.quiz
        self.assertIs(self.f.pile.currentWidget(), quiz)
        self.assertIn(cours.TITRE, quiz.titre.text())
        while self.f.pile.currentWidget() is quiz:
            q = quiz.session.question
            if q.type == CHOIX:
                quiz._choisir(q.bonne)
            else:
                quiz._clic_schema(q.cible[0], sorted(q.cible[1])[0])
            quiz._suivante()
        self.assertEqual(self.f.resultats.score.text(), "12/12")

    def test_carte_accueil(self):
        self.f.afficher_accueil()
        texte = " ".join(w.text() for w in self.f.accueil.findChildren(
            type(self.f.accueil.bouton_revision)))
        self.assertIn("Lire le cours", texte)


if __name__ == "__main__":
    unittest.main()

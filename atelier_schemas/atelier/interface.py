"""Fenêtre principale : accueil, cours, quiz chronométré, résultats."""

from __future__ import annotations

import os
import random
from pathlib import Path

from PySide6.QtCore import QByteArray, QElapsedTimer, QSize, QStandardPaths, \
    Qt, QTimer
from PySide6.QtGui import QIcon, QKeySequence, QPainter, QPixmap, QShortcut
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtSvgWidgets import QSvgWidget
from PySide6.QtWidgets import QApplication, QFrame, QGridLayout, \
    QHBoxLayout, QLabel, QMainWindow, QProgressBar, QPushButton, \
    QScrollArea, QSizePolicy, QStackedWidget, QTextBrowser, QVBoxLayout, \
    QWidget

from . import contenu, cours
from .progression import Progression
from .quiz import CHOIX, CLIC, Session
from .schemas import SCHEMAS
from .symboles import SYMBOLES, svg
from .vue_schema import FAUX, JUSTE, VueSchema

QUESTIONS_PAR_SESSION = 12

STYLE = """
QWidget { font-size: 14px; color: #1f2328; }
QMainWindow, #fond { background: #f4f5f7; }
#carte { background: #ffffff; border: 1px solid #d8dbe0; border-radius: 10px; }
#titre { font-size: 26px; font-weight: 600; }
#sousTitre { color: #5f6670; }
#enonce { font-size: 19px; font-weight: 600; }
#grand { font-size: 44px; font-weight: 700; }
QPushButton { background: #ffffff; border: 1px solid #c4c9d0;
              border-radius: 8px; padding: 10px 16px; }
QPushButton:hover { border-color: #1a73e8; }
QPushButton:disabled { color: #9aa0a6; background: #f1f3f4; }
QPushButton#principal { background: #1a73e8; color: white; border: none;
                        font-weight: 600; }
QPushButton#principal:disabled { background: #9ec2f5; }
QPushButton[etat="juste"] { background: #e6f4ea; border: 2px solid #188038; }
QPushButton[etat="faux"] { background: #fce8e6; border: 2px solid #d93025; }
QPushButton[etat="juste"]:disabled, QPushButton[etat="faux"]:disabled {
    color: #1f2328; }
QProgressBar { border: none; background: #e3e6ea; border-radius: 4px;
               height: 8px; }
QProgressBar::chunk { background: #1a73e8; border-radius: 4px; }
QProgressBar[urgent="true"]::chunk { background: #d93025; }
QTextBrowser#lecture { background: #ffffff; border: 1px solid #d8dbe0;
                       border-radius: 10px; padding: 14px 18px;
                       font-size: 15px; }
"""


def pixmap_symbole(id_symbole, taille=QSize(120, 100), broches=()):
    rendu = QSvgRenderer(QByteArray(svg(id_symbole, broches=broches).encode()))
    ratio = 2
    pm = QPixmap(taille * ratio)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    rendu.render(p)
    p.end()
    pm.setDevicePixelRatio(ratio)
    return pm


def chemin_base() -> str:
    if os.environ.get("ATELIER_DB"):
        return os.environ["ATELIER_DB"]
    dossier = Path(QStandardPaths.writableLocation(
        QStandardPaths.AppDataLocation))
    dossier.mkdir(parents=True, exist_ok=True)
    return str(dossier / "progression.db")


def _carte():
    f = QFrame()
    f.setObjectName("carte")
    return f


def _vider(layout):
    while layout.count():
        item = layout.takeAt(0)
        if item.widget():
            item.widget().deleteLater()
        elif item.layout():
            _vider(item.layout())


# ---------------------------------------------------------------------------


class PageAccueil(QWidget):
    def __init__(self, fenetre):
        super().__init__()
        self.fenetre = fenetre
        self.setObjectName("fond")
        racine = QVBoxLayout(self)
        racine.setContentsMargins(32, 28, 32, 28)
        titre = QLabel("Atelier schémas")
        titre.setObjectName("titre")
        sous = QLabel("Apprendre à lire un schéma de carte mère Mac, niveau "
                      "par niveau. Schémas pédagogiques inventés, conventions "
                      "réelles.")
        sous.setObjectName("sousTitre")
        sous.setWordWrap(True)
        racine.addWidget(titre)
        racine.addWidget(sous)
        racine.addSpacing(12)

        self.bouton_revision = QPushButton()
        self.bouton_revision.setObjectName("principal")
        self.bouton_revision.clicked.connect(fenetre.lancer_revision)
        racine.addWidget(self.bouton_revision, 0, Qt.AlignLeft)
        racine.addSpacing(8)

        self.liste = QVBoxLayout()
        self.liste.setSpacing(10)
        defil = QScrollArea()
        defil.setWidgetResizable(True)
        defil.setFrameShape(QFrame.NoFrame)
        conteneur = QWidget()
        conteneur.setObjectName("fond")
        conteneur.setLayout(self.liste)
        defil.setWidget(conteneur)
        racine.addWidget(defil, 1)
        self.rafraichir()

    def rafraichir(self):
        prog = self.fenetre.progression
        dues = prog.nombre_dues()
        self.bouton_revision.setText(
            f"Révision du jour : {dues} carte{'s' if dues > 1 else ''} à revoir"
            if dues else "Révision du jour : rien à revoir")
        self.bouton_revision.setEnabled(dues > 0)

        _vider(self.liste)
        rng = random.Random(0)
        self.liste.addWidget(self._carte_cours(prog, rng))
        for niveau, (nom, description) in contenu.NIVEAUX.items():
            carte = _carte()
            ligne = QHBoxLayout(carte)
            ligne.setContentsMargins(18, 14, 18, 14)
            textes = QVBoxLayout()
            t = QLabel(f"<b>Niveau {niveau} · {nom}</b>")
            d = QLabel(description)
            d.setObjectName("sousTitre")
            d.setWordWrap(True)
            textes.addWidget(t)
            textes.addWidget(d)
            jouable = niveau in contenu.NIVEAUX_JOUABLES
            if jouable:
                ids = [q.id for q in contenu.questions(niveau, rng)]
                s = prog.stats_niveau(niveau, ids)
                barre = QProgressBar()
                barre.setRange(0, s["total"])
                barre.setValue(s["acquises"])
                barre.setTextVisible(False)
                barre.setFixedHeight(8)
                info = QLabel(f"{s['acquises']}/{s['total']} cartes acquises "
                              f"· {s['vues']} vues · {s['dues']} à revoir")
                info.setObjectName("sousTitre")
                textes.addWidget(barre)
                textes.addWidget(info)
            ligne.addLayout(textes, 1)
            bouton = QPushButton("Jouer" if jouable else "Bientôt")
            bouton.setEnabled(jouable)
            if jouable:
                bouton.setObjectName("principal")
                bouton.clicked.connect(
                    lambda _=False, n=niveau: self.fenetre.lancer_niveau(n))
            ligne.addWidget(bouton, 0, Qt.AlignVCenter)
            self.liste.addWidget(carte)

        historique = prog.dernieres_sessions()
        if historique:
            h = QLabel("Dernières sessions : " + " · ".join(
                f"{r['titre']} {r['score']}/{r['total']}" for r in historique))
            h.setObjectName("sousTitre")
            h.setWordWrap(True)
            self.liste.addWidget(h)
        self.liste.addStretch(1)

    def _carte_cours(self, prog, rng):
        carte = _carte()
        ligne = QHBoxLayout(carte)
        ligne.setContentsMargins(18, 14, 18, 14)
        textes = QVBoxLayout()
        textes.addWidget(QLabel(f"<b>Cours · {cours.TITRE}</b>"))
        d = QLabel(f"{cours.RESUME} {len(cours.CHAPITRES)} chapitres, puis "
                   f"un quiz.")
        d.setObjectName("sousTitre")
        d.setWordWrap(True)
        textes.addWidget(d)
        ids = [q.id for q in contenu.questions(cours.NIVEAU_COURS, rng)]
        s = prog.stats_niveau(cours.NIVEAU_COURS, ids)
        info = QLabel(f"Quiz : {s['acquises']}/{s['total']} cartes acquises "
                      f"· {s['dues']} à revoir")
        info.setObjectName("sousTitre")
        textes.addWidget(info)
        ligne.addLayout(textes, 1)
        lire = QPushButton("Lire le cours")
        lire.setObjectName("principal")
        lire.clicked.connect(self.fenetre.lire_cours)
        quiz = QPushButton("Quiz")
        quiz.clicked.connect(
            lambda: self.fenetre.lancer_niveau(cours.NIVEAU_COURS))
        ligne.addWidget(lire, 0, Qt.AlignVCenter)
        ligne.addWidget(quiz, 0, Qt.AlignVCenter)
        return carte


# ---------------------------------------------------------------------------


class PageCours(QWidget):
    """Lecture du cours, chapitre par chapitre."""

    def __init__(self, fenetre):
        super().__init__()
        self.fenetre = fenetre
        self.index = 0
        self.setObjectName("fond")
        racine = QVBoxLayout(self)
        racine.setContentsMargins(28, 20, 28, 20)
        racine.setSpacing(12)

        haut = QHBoxLayout()
        retour = QPushButton("← Accueil")
        retour.clicked.connect(fenetre.afficher_accueil)
        titre = QLabel(f"Cours · {cours.TITRE}")
        titre.setObjectName("sousTitre")
        self.compteur = QLabel()
        haut.addWidget(retour)
        haut.addWidget(titre, 1)
        haut.addWidget(self.compteur)
        racine.addLayout(haut)

        self.titre = QLabel()
        self.titre.setObjectName("titre")
        racine.addWidget(self.titre)

        self.texte = QTextBrowser()
        self.texte.setObjectName("lecture")
        self.texte.setOpenLinks(False)
        racine.addWidget(self.texte, 3)

        self.vue = VueSchema()
        self.vue.setMinimumHeight(240)
        self.vue.setFrameShape(QFrame.NoFrame)
        racine.addWidget(self.vue, 2)
        self.legende = QLabel()
        self.legende.setObjectName("sousTitre")
        racine.addWidget(self.legende)

        bas = QHBoxLayout()
        self.precedent = QPushButton("← Chapitre précédent")
        self.precedent.clicked.connect(lambda: self.aller(self.index - 1))
        self.suivant = QPushButton()
        self.suivant.setObjectName("principal")
        self.suivant.clicked.connect(self._suivant)
        bas.addWidget(self.precedent)
        bas.addStretch(1)
        bas.addWidget(self.suivant)
        racine.addLayout(bas)
        self.aller(0)

    def aller(self, index):
        self.index = max(0, min(index, len(cours.CHAPITRES) - 1))
        ch = cours.CHAPITRES[self.index]
        dernier = self.index == len(cours.CHAPITRES) - 1
        self.compteur.setText(
            f"Chapitre {self.index + 1}/{len(cours.CHAPITRES)}")
        self.titre.setText(ch.titre)
        self.texte.setHtml(ch.html)
        self.precedent.setEnabled(self.index > 0)
        self.suivant.setText("Passer au quiz →" if dernier
                             else "Chapitre suivant →")
        illustre = ch.schema is not None
        self.vue.setVisible(illustre)
        self.legende.setVisible(illustre)
        if illustre:
            self.vue.charger(SCHEMAS[ch.schema])
            self.vue.actif = False
            for genre, ident, couleur in ch.surlignage:
                self.vue.marquer(genre, ident, couleur)
            self.legende.setText(ch.legende)

    def _suivant(self):
        if self.index == len(cours.CHAPITRES) - 1:
            self.fenetre.lancer_niveau(cours.NIVEAU_COURS)
        else:
            self.aller(self.index + 1)


# ---------------------------------------------------------------------------


class PageQuiz(QWidget):
    def __init__(self, fenetre):
        super().__init__()
        self.fenetre = fenetre
        self.session: Session | None = None
        self.repondu = False
        self.setObjectName("fond")

        racine = QVBoxLayout(self)
        racine.setContentsMargins(28, 20, 28, 20)
        racine.setSpacing(12)

        haut = QHBoxLayout()
        self.quitter = QPushButton("← Accueil")
        self.quitter.clicked.connect(fenetre.afficher_accueil)
        self.titre = QLabel()
        self.titre.setObjectName("sousTitre")
        self.compteur = QLabel()
        haut.addWidget(self.quitter)
        haut.addWidget(self.titre, 1)
        haut.addWidget(self.compteur)
        racine.addLayout(haut)

        self.barre = QProgressBar()
        self.barre.setTextVisible(False)
        self.barre.setFixedHeight(8)
        self.barre.setRange(0, 1000)
        racine.addWidget(self.barre)

        self.enonce = QLabel()
        self.enonce.setObjectName("enonce")
        self.enonce.setWordWrap(True)
        racine.addWidget(self.enonce)

        # Zone centrale : symbole seul, schéma, ou rien.
        self.zone = QStackedWidget()
        self.vide = QWidget()
        cadre_symbole = _carte()
        lc = QVBoxLayout(cadre_symbole)
        self.symbole = QSvgWidget()
        self.symbole.setFixedSize(288, 240)
        lc.addWidget(self.symbole, 0, Qt.AlignCenter)
        self.cadre_symbole = QWidget()
        ls = QHBoxLayout(self.cadre_symbole)
        ls.addWidget(cadre_symbole, 0, Qt.AlignCenter)
        self.vue = VueSchema()
        self.vue.setMinimumHeight(300)
        self.vue.setFrameShape(QFrame.NoFrame)
        self.vue.clique.connect(self._clic_schema)
        for w in (self.vide, self.cadre_symbole, self.vue):
            self.zone.addWidget(w)
        racine.addWidget(self.zone, 1)

        self.grille = QGridLayout()
        self.grille.setSpacing(10)
        self.boutons = []
        for i in range(4):
            b = QPushButton()
            b.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
            b.setMinimumHeight(56)
            b.clicked.connect(lambda _=False, i=i: self._choisir(i))
            self.grille.addWidget(b, i // 2, i % 2)
            self.boutons.append(b)
            QShortcut(QKeySequence(str(i + 1)), self,
                      activated=lambda i=i: self._choisir(i))
        racine.addLayout(self.grille)

        self.retour = QLabel()
        self.retour.setWordWrap(True)
        self.retour.setTextFormat(Qt.RichText)
        self.retour.setMinimumHeight(60)
        self.retour.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        racine.addWidget(self.retour)

        bas = QHBoxLayout()
        bas.addStretch(1)
        self.suivant = QPushButton("Suivant  ⏎")
        self.suivant.setObjectName("principal")
        self.suivant.clicked.connect(self._suivante)
        bas.addWidget(self.suivant)
        racine.addLayout(bas)
        for touche in (Qt.Key_Return, Qt.Key_Enter):
            QShortcut(QKeySequence(touche), self,
                      activated=self._touche_suivant)

        self.horloge = QElapsedTimer()
        self.minuteur = QTimer(self)
        self.minuteur.setInterval(50)
        self.minuteur.timeout.connect(self._tic)

    # -- déroulé -------------------------------------------------------------

    def demarrer(self, session: Session):
        self.session = session
        self.titre.setText(session.titre)
        self._afficher_question()

    def _afficher_question(self):
        s = self.session
        q = s.question
        self.repondu = False
        self.compteur.setText(f"Question {s.index + 1}/{len(s.questions)} "
                              f"· score {s.score}")
        self.enonce.setText(q.enonce)
        self.retour.setText("")
        self.suivant.setEnabled(False)

        if q.type == CLIC:
            self.vue.charger(SCHEMAS[q.schema])
            self.vue.reinitialiser()
            self.zone.setCurrentWidget(self.vue)
        elif q.symbole:
            self.symbole.load(QByteArray(
                svg(q.symbole, broches=q.broches).encode()))
            self.zone.setCurrentWidget(self.cadre_symbole)
        else:
            self.zone.setCurrentWidget(self.vide)

        for i, b in enumerate(self.boutons):
            b.setProperty("etat", "")
            b.style().unpolish(b)
            b.style().polish(b)
            if q.type == CHOIX and i < len(q.choix):
                c = q.choix[i]
                b.setVisible(True)
                b.setEnabled(True)
                if c.symbole:
                    b.setText(f"{i + 1}")
                    b.setIcon(QIcon(pixmap_symbole(c.symbole,
                                                   broches=q.broches)))
                    b.setIconSize(QSize(120, 100))
                    b.setMinimumHeight(116)
                else:
                    b.setIcon(QIcon())
                    b.setText(f"{i + 1}.  {c.texte}")
                    b.setMinimumHeight(56)
            else:
                b.setVisible(False)

        self.barre.setProperty("urgent", False)
        self._repolir(self.barre)
        self.barre.setValue(1000)
        self.horloge.start()
        self.minuteur.start()

    def _tic(self):
        restant = self.session.chrono - self.horloge.elapsed() / 1000
        self.barre.setValue(max(0, int(1000 * restant / self.session.chrono)))
        urgent = restant < 5
        if self.barre.property("urgent") != urgent:
            self.barre.setProperty("urgent", urgent)
            self._repolir(self.barre)
        if restant <= 0:
            self._valider(None, temps=self.session.chrono)

    def _choisir(self, i):
        q = self.session.question if self.session else None
        if (not self.repondu and q is not None and q.type == CHOIX
                and i < len(q.choix) and self.isVisible()):
            self._valider(i)

    def _clic_schema(self, genre, ident):
        if not self.repondu:
            self._valider((genre, ident))

    def _valider(self, reponse, temps=None):
        self.minuteur.stop()
        self.repondu = True
        temps = self.horloge.elapsed() / 1000 if temps is None else temps
        q = self.session.question
        r = self.session.repondre(reponse, temps)
        self.fenetre.progression.enregistrer(q.id, q.niveau, r.juste, r.lent)

        if q.type == CHOIX:
            for i, b in enumerate(self.boutons):
                b.setEnabled(False)
                if i == q.bonne:
                    b.setProperty("etat", "juste")
                elif i == reponse:
                    b.setProperty("etat", "faux")
                self._repolir(b)
        else:
            self.vue.actif = False
            genre, ids = q.cible
            if reponse and not r.juste:
                self.vue.marquer(reponse[0], reponse[1], FAUX)
            for ident in ids:
                self.vue.marquer(genre, ident, JUSTE)

        if r.juste:
            entete = (f"<b style='color:{JUSTE}'>✓ Juste</b>"
                      + (" — un peu lent, cette carte reviendra vite."
                         if r.lent else f" en {temps:.1f} s."))
        elif reponse is None:
            entete = (f"<b style='color:{FAUX}'>⏱ Temps écoulé</b> — "
                      f"réponse : {q.texte_bonne_reponse()}.")
        else:
            entete = (f"<b style='color:{FAUX}'>✗ Faux</b> — "
                      f"réponse : {q.texte_bonne_reponse()}.")
        if q.type == CHOIX and q.choix[q.bonne].symbole:
            entete = entete.replace(q.texte_bonne_reponse(),
                                    "le symbole encadré en vert")
        self.retour.setText(f"{entete}<br>{q.explication}")
        self.compteur.setText(
            f"Question {self.session.index}/{len(self.session.questions)} "
            f"· score {self.session.score}")
        self.suivant.setEnabled(True)
        self.suivant.setFocus()

    def _touche_suivant(self):
        if self.repondu and self.isVisible():
            self._suivante()

    def _suivante(self):
        if self.session.terminee:
            self.fenetre.terminer(self.session)
        else:
            self._afficher_question()

    def arreter(self):
        self.minuteur.stop()

    @staticmethod
    def _repolir(w):
        w.style().unpolish(w)
        w.style().polish(w)


# ---------------------------------------------------------------------------


class PageResultats(QWidget):
    def __init__(self, fenetre):
        super().__init__()
        self.fenetre = fenetre
        self.session = None
        self.setObjectName("fond")
        racine = QVBoxLayout(self)
        racine.setContentsMargins(32, 28, 32, 28)
        self.titre = QLabel()
        self.titre.setObjectName("sousTitre")
        self.score = QLabel()
        self.score.setObjectName("grand")
        self.detail = QLabel()
        self.detail.setObjectName("sousTitre")
        racine.addWidget(self.titre)
        racine.addWidget(self.score)
        racine.addWidget(self.detail)

        self.erreurs = QLabel()
        self.erreurs.setWordWrap(True)
        self.erreurs.setTextFormat(Qt.RichText)
        self.erreurs.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        defil = QScrollArea()
        defil.setWidgetResizable(True)
        defil.setFrameShape(QFrame.NoFrame)
        defil.setWidget(self.erreurs)
        racine.addWidget(defil, 1)

        bas = QHBoxLayout()
        self.b_accueil = QPushButton("Accueil")
        self.b_accueil.clicked.connect(fenetre.afficher_accueil)
        self.b_erreurs = QPushButton("Refaire mes erreurs")
        self.b_erreurs.clicked.connect(self._refaire_erreurs)
        self.b_rejouer = QPushButton("Nouvelle session")
        self.b_rejouer.setObjectName("principal")
        self.b_rejouer.clicked.connect(self._rejouer)
        bas.addWidget(self.b_accueil)
        bas.addStretch(1)
        bas.addWidget(self.b_erreurs)
        bas.addWidget(self.b_rejouer)
        racine.addLayout(bas)
        self._relancer = None

    def afficher(self, session: Session, relancer):
        self.session = session
        self._relancer = relancer
        total = len(session.questions)
        self.titre.setText(session.titre)
        self.score.setText(f"{session.score}/{total}")
        moyenne = session.duree / total if total else 0
        lentes = sum(1 for r in session.reponses if r.lent)
        self.detail.setText(
            f"Durée {session.duree:.0f} s · {moyenne:.1f} s par question"
            + (f" · {lentes} réponse{'s' if lentes > 1 else ''} juste"
               f"{'s' if lentes > 1 else ''} mais lente"
               f"{'s' if lentes > 1 else ''}" if lentes else ""))
        erreurs = session.erreurs
        if erreurs:
            lignes = ["<h3>À revoir</h3>"]
            for r in erreurs:
                q = r.question
                bonne = q.texte_bonne_reponse()
                if q.type == CHOIX and q.choix[q.bonne].symbole:
                    bonne = SYMBOLES[bonne].nom
                lignes.append(f"<p><b>{q.enonce}</b><br>"
                              f"Réponse : {bonne}<br>"
                              f"<span style='color:#5f6670'>{q.explication}"
                              f"</span></p>")
            self.erreurs.setText("".join(lignes))
        else:
            self.erreurs.setText("<h3>Sans faute !</h3>")
        self.b_erreurs.setEnabled(bool(erreurs))

    def _rejouer(self):
        if self._relancer:
            self._relancer()

    def _refaire_erreurs(self):
        qs = [r.question for r in self.session.erreurs]
        self.fenetre.demarrer(Session(qs, titre="Mes erreurs"))


# ---------------------------------------------------------------------------


class FenetrePrincipale(QMainWindow):
    def __init__(self, progression: Progression, rng=None):
        super().__init__()
        self.progression = progression
        self.rng = rng or random.Random()
        self.setWindowTitle("Atelier schémas")
        self.resize(1100, 820)
        self.pile = QStackedWidget()
        self.setCentralWidget(self.pile)
        self.accueil = PageAccueil(self)
        self.quiz = PageQuiz(self)
        self.resultats = PageResultats(self)
        self.cours = PageCours(self)
        for p in (self.accueil, self.quiz, self.resultats, self.cours):
            self.pile.addWidget(p)
        self._relancer = None

    def lire_cours(self):
        self.pile.setCurrentWidget(self.cours)

    def afficher_accueil(self):
        self.quiz.arreter()
        self.accueil.rafraichir()
        self.pile.setCurrentWidget(self.accueil)

    def demarrer(self, session: Session):
        if not session.questions:
            self.afficher_accueil()
            return
        self.pile.setCurrentWidget(self.quiz)
        self.quiz.demarrer(session)

    def lancer_niveau(self, niveau: int):
        self._relancer = lambda: self.lancer_niveau(niveau)
        qs = contenu.questions(niveau, self.rng)
        choisies = self.progression.choisir(qs, QUESTIONS_PAR_SESSION,
                                            self.rng)
        if niveau == cours.NIVEAU_COURS:
            titre = f"Cours · {cours.TITRE}"
        else:
            titre = f"Niveau {niveau} · {contenu.NIVEAUX[niveau][0]}"
        self.demarrer(Session(choisies, titre=titre))

    def lancer_revision(self):
        self._relancer = self.lancer_revision
        qs = contenu.toutes_les_questions(self.rng)
        choisies = self.progression.choisir(qs, QUESTIONS_PAR_SESSION,
                                            self.rng, seulement_dues=True)
        self.demarrer(Session(choisies, titre="Révision du jour"))

    def terminer(self, session: Session):
        self.progression.enregistrer_session(
            session.titre, session.score, len(session.questions),
            session.duree)
        self.resultats.afficher(session, self._relancer)
        self.pile.setCurrentWidget(self.resultats)


def main(argv=None):
    import sys
    app = QApplication(argv if argv is not None else sys.argv)
    app.setApplicationName("atelier_schemas")
    app.setStyle("Fusion")
    app.setStyleSheet(STYLE)
    fenetre = FenetrePrincipale(Progression(chemin_base()))
    fenetre.show()
    return app.exec()

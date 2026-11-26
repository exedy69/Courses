"""Progression et répétition espacée (boîtes de Leitner), stockées en SQLite.

Chaque question est une carte. Réponse juste et rapide : la carte monte d'une
boîte et revient plus tard. Juste mais lente : elle reste dans sa boîte.
Fausse : retour en boîte 1, à revoir le jour même.
"""

from __future__ import annotations

import random
import sqlite3
from datetime import date, timedelta

# Boîte → délai avant la prochaine révision, en jours.
INTERVALLES = {1: 0, 2: 1, 3: 3, 4: 7, 5: 21}
BOITE_MAX = max(INTERVALLES)
BOITE_ACQUISE = 4

VERSION_SCHEMA = 1


class Progression:
    def __init__(self, chemin: str = ":memory:"):
        self.db = sqlite3.connect(chemin)
        self.db.row_factory = sqlite3.Row
        self._migrer()

    def _migrer(self):
        version = self.db.execute("PRAGMA user_version").fetchone()[0]
        if version < 1:
            self.db.executescript("""
                CREATE TABLE IF NOT EXISTS cartes (
                    id TEXT PRIMARY KEY,
                    niveau INTEGER NOT NULL,
                    boite INTEGER NOT NULL DEFAULT 1,
                    echeance TEXT NOT NULL,      -- AAAA-MM-JJ
                    vues INTEGER NOT NULL DEFAULT 0,
                    reussites INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    jour TEXT NOT NULL,
                    titre TEXT NOT NULL,
                    score INTEGER NOT NULL,
                    total INTEGER NOT NULL,
                    duree REAL NOT NULL
                );
            """)
        self.db.execute(f"PRAGMA user_version = {VERSION_SCHEMA}")
        self.db.commit()

    def fermer(self):
        self.db.close()

    # -- cartes ------------------------------------------------------------

    def carte(self, id_carte: str):
        return self.db.execute("SELECT * FROM cartes WHERE id = ?",
                               (id_carte,)).fetchone()

    def enregistrer(self, id_carte: str, niveau: int, juste: bool,
                    lent: bool = False, aujourdhui: date | None = None):
        jour = aujourdhui or date.today()
        ligne = self.carte(id_carte)
        boite = ligne["boite"] if ligne else 1
        if not juste:
            boite = 1
        elif not lent:
            boite = min(BOITE_MAX, boite + 1)
        echeance = (jour + timedelta(days=INTERVALLES[boite])).isoformat()
        self.db.execute("""
            INSERT INTO cartes (id, niveau, boite, echeance, vues, reussites)
            VALUES (?, ?, ?, ?, 1, ?)
            ON CONFLICT(id) DO UPDATE SET
                boite = excluded.boite, echeance = excluded.echeance,
                vues = vues + 1, reussites = reussites + excluded.reussites
        """, (id_carte, niveau, boite, echeance, int(juste)))
        self.db.commit()

    def enregistrer_session(self, titre, score, total, duree,
                            aujourdhui: date | None = None):
        jour = (aujourdhui or date.today()).isoformat()
        self.db.execute(
            "INSERT INTO sessions (jour, titre, score, total, duree) "
            "VALUES (?, ?, ?, ?, ?)", (jour, titre, score, total, duree))
        self.db.commit()

    # -- choix des questions -------------------------------------------------

    def choisir(self, questions, nombre: int, rng: random.Random,
                aujourdhui: date | None = None, seulement_dues=False):
        """Choisit les questions d'une session.

        Priorité : cartes dues (boîte basse d'abord), puis cartes jamais
        vues, puis les autres (échéance la plus proche d'abord).
        """
        jour = (aujourdhui or date.today()).isoformat()
        etat = {r["id"]: r for r in self.db.execute("SELECT * FROM cartes")}
        dues, nouvelles, autres = [], [], []
        melange = list(questions)
        rng.shuffle(melange)
        for q in melange:
            r = etat.get(q.id)
            if r is None:
                nouvelles.append(q)
            elif r["echeance"] <= jour:
                dues.append((r["boite"], r["echeance"], q))
            else:
                autres.append((r["echeance"], r["boite"], q))
        dues.sort(key=lambda t: (t[0], t[1]))
        autres.sort(key=lambda t: (t[0], t[1]))
        ordre = [q for *_, q in dues]
        if not seulement_dues:
            ordre += nouvelles + [q for *_, q in autres]
        choisies = ordre[:nombre]
        rng.shuffle(choisies)
        return choisies

    # -- statistiques --------------------------------------------------------

    def stats_niveau(self, niveau: int, ids_cartes, aujourdhui=None):
        """Nombre de cartes vues, acquises et dues parmi ``ids_cartes``."""
        jour = (aujourdhui or date.today()).isoformat()
        ids = set(ids_cartes)
        vues = acquises = dues = 0
        for r in self.db.execute("SELECT * FROM cartes WHERE niveau = ?",
                                 (niveau,)):
            if r["id"] not in ids:
                continue
            vues += 1
            acquises += r["boite"] >= BOITE_ACQUISE
            dues += r["echeance"] <= jour
        return {"total": len(ids), "vues": vues, "acquises": acquises,
                "dues": dues}

    def nombre_dues(self, aujourdhui=None) -> int:
        jour = (aujourdhui or date.today()).isoformat()
        return self.db.execute("SELECT COUNT(*) FROM cartes WHERE echeance "
                               "<= ?", (jour,)).fetchone()[0]

    def dernieres_sessions(self, nombre=5):
        return self.db.execute("SELECT * FROM sessions ORDER BY id DESC "
                               "LIMIT ?", (nombre,)).fetchall()

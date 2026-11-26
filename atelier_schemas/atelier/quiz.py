"""Moteur de quiz : questions, session chronométrée, correction.

Aucune dépendance à Qt : tout se teste sans interface.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

CHOIX = "choix"
CLIC = "clic"
ORDRE = "ordre"

# Temps accordé par question ; au-delà, la question compte comme ratée.
CHRONO_SECONDES = 20
# Réponse juste mais en plus de la moitié du temps accordé : la carte ne
# monte pas de boîte.
PART_LENTE = 0.5


@dataclass(frozen=True)
class Choix:
    texte: str = ""
    symbole: str | None = None   # affiche un symbole à la place du texte


@dataclass(frozen=True)
class Question:
    id: str                      # identifiant stable (répétition espacée)
    niveau: int
    theme: str
    enonce: str
    type: str = CHOIX
    choix: tuple = ()
    bonne: int = 0               # index de la bonne réponse (type choix)
    cible: tuple = ()            # (« composant » | « net », {ids}) (type clic)
    symbole: str | None = None   # symbole affiché avec l'énoncé
    broches: tuple = ()
    schema: str | None = None    # schéma affiché (type clic)
    explication: str = ""
    ordre: tuple = ()            # textes dans le bon ordre (type ordre)
    duree: int | None = None     # chrono propre à la question (secondes)

    def est_juste(self, reponse) -> bool:
        if reponse is None:
            return False
        if self.type == CHOIX:
            return reponse == self.bonne
        if self.type == ORDRE:
            try:
                return tuple(self.choix[i].texte for i in reponse) == self.ordre
            except (IndexError, TypeError):
                return False
        genre, ids = self.cible
        return reponse[0] == genre and reponse[1] in ids

    def texte_bonne_reponse(self) -> str:
        if self.type == CLIC:
            return " / ".join(sorted(self.cible[1]))
        if self.type == ORDRE:
            return " → ".join(self.ordre)
        c = self.choix[self.bonne]
        return c.texte or c.symbole or ""


def melanger_choix(rng: random.Random, bonne: Choix, autres) -> tuple:
    """Renvoie (choix mélangés, index de la bonne réponse)."""
    tous = [bonne] + [a for a in autres if a != bonne]
    rng.shuffle(tous)
    return tuple(tous), tous.index(bonne)


def melanger_ordre(rng: random.Random, etapes) -> tuple:
    """Choix mélangés d'un exercice « remets dans l'ordre » (jamais déjà
    dans le bon ordre)."""
    choix = [Choix(e) for e in etapes]
    while len(choix) > 1 and [c.texte for c in choix] == list(etapes):
        rng.shuffle(choix)
    return tuple(choix)


@dataclass
class Reponse:
    question: Question
    reponse: object
    juste: bool
    temps: float
    limite: float = CHRONO_SECONDES

    @property
    def lent(self) -> bool:
        return self.juste and self.temps > self.limite * PART_LENTE


@dataclass
class Session:
    questions: list
    titre: str = ""
    chrono: int = CHRONO_SECONDES
    reponses: list = field(default_factory=list)

    @property
    def index(self) -> int:
        return len(self.reponses)

    @property
    def terminee(self) -> bool:
        return self.index >= len(self.questions)

    @property
    def question(self) -> Question | None:
        return None if self.terminee else self.questions[self.index]

    def limite(self, q: Question | None = None) -> int:
        """Temps accordé pour la question (courante par défaut)."""
        q = q or self.question
        return q.duree if q is not None and q.duree else self.chrono

    def repondre(self, reponse, temps: float) -> Reponse:
        """Enregistre la réponse à la question courante.

        ``reponse`` vaut ``None`` quand le chrono est écoulé.
        """
        q = self.question
        if q is None:
            raise RuntimeError("session terminée")
        limite = self.limite(q)
        juste = temps <= limite and q.est_juste(reponse)
        r = Reponse(q, reponse, juste, temps, limite)
        self.reponses.append(r)
        return r

    @property
    def score(self) -> int:
        return sum(1 for r in self.reponses if r.juste)

    @property
    def duree(self) -> float:
        return sum(r.temps for r in self.reponses)

    @property
    def erreurs(self) -> list:
        return [r for r in self.reponses if not r.juste]

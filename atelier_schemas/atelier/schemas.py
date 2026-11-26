"""Schémas pédagogiques interactifs.

Ces schémas sont **inventés** : ils reprennent l'architecture et les
conventions de nommage des cartes mères Mac (PPBUS_G3H, rails _S5/_S0,
signaux actifs bas en _L…) sans copier aucun schéma réel.

Un schéma = des composants posés sur une grille + des nets (fils). Un point
de fil est soit des coordonnées ``(x, y)``, soit une borne ``"R1.2"``.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .symboles import HAUTEUR, LARGEUR, SYMBOLES


@dataclass(frozen=True)
class Composant:
    ref: str                 # R7110, Q7130…
    symbole: str             # clé de SYMBOLES
    x: float
    y: float
    rotation: int = 0        # 0, 90, 180 ou 270 (sens horaire)
    valeur: str = ""         # « 10K », « 22UF 25V »…
    broches: tuple = ()      # noms de broches pour un circuit intégré
    etiquette: tuple = (0, -14)  # décalage du texte ref/valeur


@dataclass(frozen=True)
class Net:
    nom: str
    segments: tuple          # suites de points (polylignes)
    etiquette: tuple = None  # position (x, y) du nom
    pages: str = ""          # renvois de pages, comme sur un vrai schéma
    jonctions: tuple = ()    # points de jonction (gros points)
    est_rail: bool = False


@dataclass(frozen=True)
class Schema:
    id: str
    titre: str
    largeur: int
    hauteur: int
    composants: tuple
    nets: tuple = field(default=())

    def composant(self, ref: str) -> Composant:
        for c in self.composants:
            if c.ref == ref:
                return c
        raise KeyError(ref)

    def net(self, nom: str) -> Net:
        for n in self.nets:
            if n.nom == nom:
                return n
        raise KeyError(nom)


def tourner(point, rotation: int):
    """Tourne un point local du symbole autour du centre de sa boîte."""
    cx, cy = LARGEUR / 2, HAUTEUR / 2
    dx, dy = point[0] - cx, point[1] - cy
    r = rotation % 360
    if r == 90:
        dx, dy = -dy, dx
    elif r == 180:
        dx, dy = -dx, -dy
    elif r == 270:
        dx, dy = dy, -dx
    elif r != 0:
        raise ValueError("rotation par quart de tour uniquement")
    return (cx + dx, cy + dy)


def position_borne(schema: Schema, reference: str):
    """``"Q1.G"`` → coordonnées de la borne dans le schéma."""
    ref, borne = reference.rsplit(".", 1)
    comp = schema.composant(ref)
    lx, ly = tourner(SYMBOLES[comp.symbole].bornes[borne], comp.rotation)
    return (comp.x + lx, comp.y + ly)


def resoudre(schema: Schema, point):
    return position_borne(schema, point) if isinstance(point, str) else point


def polylignes(schema: Schema, net: Net):
    """Segments du net en coordonnées absolues."""
    return [[resoudre(schema, p) for p in seg] for seg in net.segments]


# ---------------------------------------------------------------------------
# Schéma 1 : du PPBUS_G3H au 3,3 V allumé.
# Un régulateur à découpage fabrique PP3V3_S5, puis un MOSFET P (interrupteur
# de charge) le recopie en PP3V3_S0 quand la machine est allumée.
# ---------------------------------------------------------------------------

RAIL_3V3 = Schema(
    id="rail_3v3",
    titre="Page 61 — Alimentation 3,3 V (S5 et S0)",
    largeur=1120,
    hauteur=330,
    composants=(
        Composant("C7100", "condensateur", 130, 110, 90, "10UF 25V",
                  etiquette=(-32, 30)),
        Composant("U7100", "ci", 300, 80, 0, "REGUL. BUCK",
                  broches=("VIN", "EN", "SW", "GND"), etiquette=(10, -22)),
        Composant("L7110", "inductance", 440, 60, 0, "2.2UH"),
        Composant("C7110", "condensateur", 540, 110, 90, "22UF 6.3V",
                  etiquette=(-32, 30)),
        Composant("R7130", "resistance", 640, 10, 90, "100K",
                  etiquette=(-56, 34)),
        Composant("Q7130", "mosfet_p", 740, 45, 90, "", etiquette=(66, 74)),
        Composant("C7130", "condensateur", 880, 110, 90, "10UF 6.3V",
                  etiquette=(-32, 30)),
        Composant("GND1", "masse", 130, 195),
        Composant("GND2", "masse", 370, 175),
        Composant("GND3", "masse", 540, 195),
        Composant("GND4", "masse", 880, 195),
    ),
    nets=(
        Net("PPBUS_G3H", ((( 30, 110), "U7100.1"), ((190, 110), "C7100.1")),
            etiquette=(34, 100), pages="6 7 45", jonctions=((190, 110),),
            est_rail=True),
        Net("P3V3S5_EN", (("U7100.2", (260, 150), (260, 300), (30, 300)),),
            etiquette=(34, 290), pages="45"),
        Net("P3V3S5_SW", (("U7100.3", "L7110.1"),),
            etiquette=(414, 96)),
        Net("PP3V3_S5", (("L7110.2", "Q7130.S"), ((600, 110), "C7110.1"),
                         ((700, 110), "R7130.2")),
            etiquette=(560, 100), pages="8 22 45",
            jonctions=((600, 110), (700, 110)), est_rail=True),
        Net("P3V3S0_EN_L", (("R7130.1", (790, 10), "Q7130.G"),
                            ((790, 10), (1040, 10))),
            etiquette=(880, 26), pages="45", jonctions=((790, 10),)),
        Net("PP3V3_S0", (("Q7130.D", (1040, 110)), ((940, 110), "C7130.1")),
            etiquette=(960, 100), pages="12 30 52",
            jonctions=((940, 110),), est_rail=True),
        Net("GND", (("C7100.2", "GND1.1"), ("U7100.4", (430, 150),
                                            "GND2.1"),
                    ("C7110.2", "GND3.1"), ("C7130.2", "GND4.1"))),
    ),
)

SCHEMAS = {s.id: s for s in [RAIL_3V3]}

"""Symboles électroniques dessinés en SVG.

Chaque symbole tient dans une boîte de 120 × 100 unités. Les bornes sont
déclarées dans ``BORNES`` pour que les schémas puissent y raccorder leurs fils.
Les dessins suivent les conventions des schémas de cartes mères (résistance en
zigzag, comme sur les schémas Apple).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

LARGEUR = 120
HAUTEUR = 100

# Bornes standard d'un dipôle horizontal.
_DIPOLE = {"1": (10, 50), "2": (110, 50)}


@dataclass(frozen=True)
class Symbole:
    id: str
    nom: str            # nom affiché (« Résistance »)
    prefixe: str        # lettre de référence sur un schéma (R, C, Q…)
    description: str    # ce qu'il faut retenir
    corps: str          # SVG sans l'enveloppe, couleur notée {c}
    bornes: dict


def _s(id, nom, prefixe, description, corps, bornes=None):
    return Symbole(id, nom, prefixe, description, corps, bornes or dict(_DIPOLE))


_ZIGZAG = "10,50 34,50 38,40 46,60 54,40 62,60 70,40 78,60 82,50 110,50"

SYMBOLES: dict[str, Symbole] = {s.id: s for s in [
    _s("resistance", "Résistance", "R",
       "Zigzag (ou rectangle en norme européenne). Limite le courant, sert de "
       "tirage (pull-up / pull-down) ou de diviseur de tension.",
       f'<polyline points="{_ZIGZAG}" fill="none"/>'),
    _s("condensateur", "Condensateur", "C",
       "Deux plaques parallèles. Filtre et stabilise les rails ; en mode "
       "diode, un condensateur en court-circuit est une panne fréquente.",
       '<line x1="10" y1="50" x2="54" y2="50"/>'
       '<line x1="54" y1="28" x2="54" y2="72"/>'
       '<line x1="66" y1="28" x2="66" y2="72"/>'
       '<line x1="66" y1="50" x2="110" y2="50"/>'),
    _s("condensateur_polarise", "Condensateur polarisé", "C",
       "Une plaque droite (+) et une plaque courbe (−). Tantale ou polymère, "
       "souvent sur PPBUS et les rails processeur.",
       '<line x1="10" y1="50" x2="54" y2="50"/>'
       '<line x1="54" y1="28" x2="54" y2="72"/>'
       '<path d="M72,28 Q62,50 72,72" fill="none"/>'
       '<line x1="66" y1="50" x2="110" y2="50"/>'
       '<text x="40" y="32" font-size="16" stroke="none" fill="{c}">+</text>'),
    _s("inductance", "Inductance (bobine)", "L",
       "Suite de boucles. Stocke l'énergie dans les régulateurs à découpage "
       "(entre le nœud SW et la sortie) ; sert aussi de filtre.",
       '<path d="M10,50 H28 a8,8 0 0 1 16,0 a8,8 0 0 1 16,0 a8,8 0 0 1 16,0 '
       'a8,8 0 0 1 16,0 H110" fill="none"/>'),
    _s("diode", "Diode", "D",
       "Triangle et barre : le courant passe dans le sens de la flèche, de "
       "l'anode vers la cathode (la barre).",
       '<line x1="10" y1="50" x2="46" y2="50"/>'
       '<polygon points="46,32 46,68 72,50" fill="{c}"/>'
       '<line x1="72" y1="32" x2="72" y2="68"/>'
       '<line x1="72" y1="50" x2="110" y2="50"/>'),
    _s("zener", "Diode Zener", "D",
       "Barre aux extrémités repliées. Fixe une tension en inverse : "
       "protection contre les surtensions.",
       '<line x1="10" y1="50" x2="46" y2="50"/>'
       '<polygon points="46,32 46,68 72,50" fill="{c}"/>'
       '<polyline points="66,28 72,32 72,68 78,72" fill="none"/>'
       '<line x1="72" y1="50" x2="110" y2="50"/>'),
    _s("schottky", "Diode Schottky", "D",
       "Barre en forme de S. Faible chute de tension (≈ 0,3 V), rapide : "
       "redressement et protection d'alimentation.",
       '<line x1="10" y1="50" x2="46" y2="50"/>'
       '<polygon points="46,32 46,68 72,50" fill="{c}"/>'
       '<polyline points="66,38 66,32 72,32 72,68 78,68 78,62" fill="none"/>'
       '<line x1="72" y1="50" x2="110" y2="50"/>'),
    _s("led", "LED", "D",
       "Diode avec deux flèches sortantes : elle émet de la lumière "
       "(voyant de charge, rétroéclairage).",
       '<line x1="10" y1="50" x2="46" y2="50"/>'
       '<polygon points="46,32 46,68 72,50" fill="{c}"/>'
       '<line x1="72" y1="32" x2="72" y2="68"/>'
       '<line x1="72" y1="50" x2="110" y2="50"/>'
       '<line x1="60" y1="28" x2="72" y2="14"/>'
       '<polyline points="64,14 72,14 72,22" fill="none"/>'
       '<line x1="72" y1="32" x2="84" y2="18"/>'
       '<polyline points="76,18 84,18 84,26" fill="none"/>'),
    _s("fusible", "Fusible", "F",
       "Rectangle traversé par un fil. Coupe en cas de surintensité ; un "
       "fusible ouvert sur l'entrée de charge = pas de PPBUS.",
       '<line x1="10" y1="50" x2="36" y2="50"/>'
       '<rect x="36" y="40" width="48" height="20" fill="none"/>'
       '<line x1="36" y1="50" x2="84" y2="50"/>'
       '<line x1="84" y1="50" x2="110" y2="50"/>'),
    _s("quartz", "Quartz", "Y",
       "Petit rectangle entre deux plaques. Donne l'horloge (32,768 kHz pour "
       "l'horloge temps réel, 24/25 MHz pour le chipset).",
       '<line x1="10" y1="50" x2="42" y2="50"/>'
       '<line x1="42" y1="30" x2="42" y2="70"/>'
       '<rect x="50" y="34" width="20" height="32" fill="none"/>'
       '<line x1="78" y1="30" x2="78" y2="70"/>'
       '<line x1="78" y1="50" x2="110" y2="50"/>'),
    _s("mosfet_n", "MOSFET canal N", "Q",
       "Flèche vers le canal. Conduit quand la grille (G) est plus haute que "
       "la source (S) : interrupteur côté masse ou étage bas d'un régulateur.",
       '<line x1="10" y1="60" x2="42" y2="60"/>'
       '<line x1="42" y1="34" x2="42" y2="78"/>'
       '<line x1="50" y1="30" x2="50" y2="44"/>'
       '<line x1="50" y1="48" x2="50" y2="62"/>'
       '<line x1="50" y1="66" x2="50" y2="80"/>'
       '<polyline points="50,37 75,37 75,10" fill="none"/>'
       '<polyline points="50,73 75,73 75,90" fill="none"/>'
       '<polyline points="50,55 75,55 75,73" fill="none"/>'
       '<polygon points="51,55 62,49 62,61" fill="{c}"/>'
       '<text x="80" y="20" font-size="12" stroke="none" fill="{c}">D</text>'
       '<text x="14" y="54" font-size="12" stroke="none" fill="{c}">G</text>'
       '<text x="80" y="92" font-size="12" stroke="none" fill="{c}">S</text>',
       {"G": (10, 60), "D": (75, 10), "S": (75, 90)}),
    _s("mosfet_p", "MOSFET canal P", "Q",
       "Flèche qui sort du canal. Conduit quand la grille est plus basse que "
       "la source : interrupteur de charge (load switch) côté alimentation.",
       '<line x1="10" y1="60" x2="42" y2="60"/>'
       '<line x1="42" y1="34" x2="42" y2="78"/>'
       '<line x1="50" y1="30" x2="50" y2="44"/>'
       '<line x1="50" y1="48" x2="50" y2="62"/>'
       '<line x1="50" y1="66" x2="50" y2="80"/>'
       '<polyline points="50,37 75,37 75,10" fill="none"/>'
       '<polyline points="50,73 75,73 75,90" fill="none"/>'
       '<polyline points="50,55 75,55 75,73" fill="none"/>'
       '<polygon points="74,55 63,49 63,61" fill="{c}"/>'
       '<text x="80" y="20" font-size="12" stroke="none" fill="{c}">D</text>'
       '<text x="14" y="54" font-size="12" stroke="none" fill="{c}">G</text>'
       '<text x="80" y="92" font-size="12" stroke="none" fill="{c}">S</text>',
       {"G": (10, 60), "D": (75, 10), "S": (75, 90)}),
    _s("npn", "Transistor bipolaire NPN", "Q",
       "Base, collecteur, émetteur ; la flèche sort par l'émetteur. Plus "
       "rare que les MOSFET sur une carte récente, mais encore présent.",
       '<line x1="10" y1="50" x2="46" y2="50"/>'
       '<line x1="46" y1="30" x2="46" y2="70"/>'
       '<polyline points="46,40 75,22 75,6" fill="none"/>'
       '<polyline points="46,60 75,78 75,94" fill="none"/>'
       '<polygon points="75,78 62,78 69,68" fill="{c}"/>',
       {"B": (10, 50), "C": (75, 6), "E": (75, 94)}),
    _s("masse", "Masse (GND)", "—",
       "Trois traits décroissants : la référence 0 V. En mode diode, on mesure "
       "un net par rapport à la masse.",
       '<line x1="60" y1="15" x2="60" y2="50"/>'
       '<line x1="38" y1="50" x2="82" y2="50"/>'
       '<line x1="46" y1="58" x2="74" y2="58"/>'
       '<line x1="54" y1="66" x2="66" y2="66"/>',
       {"1": (60, 15)}),
    _s("connecteur", "Connecteur", "J",
       "Boîte avec des broches numérotées : clavier, écran, batterie, "
       "chargeur… Point d'entrée idéal pour suivre un signal.",
       '<rect x="50" y="12" width="34" height="76" fill="none"/>'
       '<line x1="10" y1="30" x2="50" y2="30"/>'
       '<line x1="10" y1="50" x2="50" y2="50"/>'
       '<line x1="10" y1="70" x2="50" y2="70"/>'
       '<text x="56" y="34" font-size="12" stroke="none" fill="{c}">1</text>'
       '<text x="56" y="54" font-size="12" stroke="none" fill="{c}">2</text>'
       '<text x="56" y="74" font-size="12" stroke="none" fill="{c}">3</text>',
       {"1": (10, 30), "2": (10, 50), "3": (10, 70)}),
    _s("ci", "Circuit intégré", "U",
       "Rectangle avec des broches nommées : régulateur, SMC, chargeur, "
       "contrôleur USB-C…",
       '<rect x="25" y="12" width="70" height="76" fill="none"/>'
       '<line x1="10" y1="30" x2="25" y2="30"/>'
       '<line x1="10" y1="70" x2="25" y2="70"/>'
       '<line x1="95" y1="30" x2="110" y2="30"/>'
       '<line x1="95" y1="70" x2="110" y2="70"/>'
       '<text x="29" y="34" font-size="11" stroke="none" fill="{c}">{p1}</text>'
       '<text x="29" y="74" font-size="11" stroke="none" fill="{c}">{p2}</text>'
       '<text x="91" y="34" font-size="11" stroke="none" fill="{c}" '
       'text-anchor="end">{p3}</text>'
       '<text x="91" y="74" font-size="11" stroke="none" fill="{c}" '
       'text-anchor="end">{p4}</text>',
       {"1": (10, 30), "2": (10, 70), "3": (110, 30), "4": (110, 70)}),
    _s("point_test", "Point de test", "TP",
       "Petit cercle sur un net : une pastille où poser la pointe du "
       "multimètre.",
       '<circle cx="60" cy="38" r="9" fill="none"/>'
       '<line x1="60" y1="47" x2="60" y2="90"/>',
       {"1": (60, 90)}),
]}


def svg(id_symbole: str, couleur: str = "#202124", broches=None,
        epaisseur: float = 2.5, lettres: bool = True) -> str:
    """SVG complet du symbole, prêt pour QSvgRenderer.

    ``broches`` : noms des 4 broches d'un circuit intégré (« ci »).
    ``lettres=False`` retire les repères D/G/S d'un transistor et les numéros
    d'un connecteur (utile quand le symbole est tourné : ils seraient
    couchés ou à l'envers).
    """
    sym = SYMBOLES[id_symbole]
    noms = list(broches or ["", "", "", ""]) + ["", "", "", ""]
    corps = sym.corps
    if not lettres and sym.prefixe in ("Q", "J"):
        corps = re.sub(r"<text[^>]*>[DGS123]</text>", "", corps)
    corps = (corps.replace("{c}", couleur)
             .replace("{p1}", noms[0]).replace("{p2}", noms[1])
             .replace("{p3}", noms[2]).replace("{p4}", noms[3]))
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {LARGEUR} '
        f'{HAUTEUR}" width="{LARGEUR}" height="{HAUTEUR}">'
        f'<g stroke="{couleur}" stroke-width="{epaisseur}" '
        f'stroke-linecap="round" stroke-linejoin="round" '
        f'font-family="sans-serif">{corps}</g></svg>'
    )

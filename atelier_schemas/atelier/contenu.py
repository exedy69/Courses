"""Contenu des niveaux 1 et 2.

Niveau 1 : symboles et lecture de base.
Niveau 2 : conventions des schémas Mac (noms de nets, suffixes d'état,
signaux actifs bas, références et valeurs de composants).

Les questions sont reconstruites à chaque session avec un générateur
aléatoire (ordre des réponses, net d'exemple), mais leur ``id`` reste stable
pour la répétition espacée.
"""

from __future__ import annotations

import random
import re

from .quiz import CLIC, Choix, Question, melanger_choix
from .symboles import SYMBOLES

NIVEAUX = {
    1: ("Symboles et lecture de base",
        "Reconnaître résistances, condensateurs, diodes, MOSFET, bobines, "
        "connecteurs… et leur lettre de référence."),
    2: ("Conventions des schémas Mac",
        "Lire PP3V3_S5 ou PPBUS_G3H, les suffixes d'état, les signaux actifs "
        "bas et les références de composants."),
    3: ("Suivre un chemin", "Bientôt : d'un connecteur à l'autre, page après "
        "page."),
    4: ("Chaîne d'alimentation", "Bientôt : de PPDCIN aux rails du "
        "processeur, ordre d'allumage."),
    5: ("Diagnostic", "Bientôt : panne simulée et multimètre virtuel."),
}
NIVEAUX_JOUABLES = (1, 2)

# Symboles qu'on confond facilement : ils servent de pièges en priorité.
_FAMILLES = [
    {"diode", "zener", "schottky", "led"},
    {"mosfet_n", "mosfet_p", "npn"},
    {"condensateur", "condensateur_polarise", "quartz"},
    {"resistance", "inductance", "fusible"},
    {"connecteur", "ci", "point_test", "masse"},
]


def _famille(id_symbole):
    for f in _FAMILLES:
        if id_symbole in f:
            return f
    return set()


def _pieges(rng, id_symbole, nombre=3):
    proches = sorted(_famille(id_symbole) - {id_symbole})
    rng.shuffle(proches)
    loin = sorted(set(SYMBOLES) - _famille(id_symbole))
    rng.shuffle(loin)
    pris = proches[:2]
    return (pris + loin)[:nombre]


# ---------------------------------------------------------------------------
# Niveau 1
# ---------------------------------------------------------------------------

_LETTRES = ["R", "C", "L", "D", "Q", "U", "F", "J", "Y", "TP"]
_AVEC_LETTRE = ["resistance", "condensateur", "inductance", "diode",
                "fusible", "quartz", "mosfet_n", "connecteur", "ci",
                "point_test"]
_SENS_LETTRE = {
    "R": "R = résistance", "C": "C = condensateur (capacitor)",
    "L": "L = inductance (bobine)", "D": "D = diode",
    "Q": "Q = transistor (MOSFET ou bipolaire)",
    "U": "U = circuit intégré", "F": "F = fusible (fuse)",
    "J": "J = connecteur (jack)", "Y": "Y = quartz (crystal)",
    "TP": "TP = point de test (test point)",
}

# Questions « clique sur… » du niveau 1, sur le schéma rail_3v3.
_CLICS_NIVEAU_1 = [
    ("composant", {"C7100", "C7110", "C7130"}, "Clique sur un condensateur.",
     "Deux plaques parallèles : C7100, C7110 et C7130."),
    ("composant", {"L7110"}, "Clique sur l'inductance.",
     "L7110 : la suite de boucles, entre le nœud SW et la sortie."),
    ("composant", {"R7130"}, "Clique sur la résistance.",
     "R7130 : le zigzag. Sa lettre de référence est R."),
    ("composant", {"Q7130"}, "Clique sur le transistor MOSFET.",
     "Q7130 : un MOSFET canal P (flèche sortante)."),
    ("composant", {"U7100"}, "Clique sur le circuit intégré.",
     "U7100 : le rectangle à broches nommées (VIN, EN, SW, GND)."),
    ("composant", {"GND1", "GND2", "GND3", "GND4"},
     "Clique sur un symbole de masse.",
     "Les trois traits décroissants sous chaque condensateur et sous U7100."),
]


def questions_niveau_1(rng: random.Random) -> list:
    qs = []
    for sid, sym in SYMBOLES.items():
        pieges = _pieges(rng, sid)
        choix, bonne = melanger_choix(
            rng, Choix(sym.nom), [Choix(SYMBOLES[p].nom) for p in pieges])
        qs.append(Question(
            id=f"sym_nom:{sid}", niveau=1, theme="Symboles",
            enonce="Quel est ce symbole ?", choix=choix, bonne=bonne,
            symbole=sid, broches=("IN", "EN", "OUT", "GND"),
            explication=f"{sym.nom}. {sym.description}"))

        pieges = _pieges(rng, sid)
        choix, bonne = melanger_choix(
            rng, Choix(symbole=sid), [Choix(symbole=p) for p in pieges])
        qs.append(Question(
            id=f"sym_inv:{sid}", niveau=1, theme="Symboles",
            enonce=f"Lequel de ces symboles est : {sym.nom} ?",
            choix=choix, bonne=bonne,
            explication=f"{sym.nom}. {sym.description}"))

    for sid in _AVEC_LETTRE:
        sym = SYMBOLES[sid]
        autres = [x for x in _LETTRES if x != sym.prefixe]
        rng.shuffle(autres)
        choix, bonne = melanger_choix(
            rng, Choix(sym.prefixe), [Choix(x) for x in autres[:3]])
        qs.append(Question(
            id=f"ref:{sid}", niveau=1, theme="Références",
            enonce="Quelle lettre de référence porte ce composant sur un "
                   "schéma ?",
            choix=choix, bonne=bonne, symbole=sid,
            broches=("IN", "EN", "OUT", "GND"),
            explication=f"{_SENS_LETTRE[sym.prefixe]}. Exemple : "
                        f"{sym.prefixe}7020."))

    for i, (genre, ids, enonce, expl) in enumerate(_CLICS_NIVEAU_1):
        qs.append(Question(
            id=f"clic1:rail_3v3:{i}", niveau=1, theme="Schéma",
            enonce=enonce, type=CLIC, cible=(genre, frozenset(ids)),
            schema="rail_3v3", explication=expl))
    return qs


# ---------------------------------------------------------------------------
# Niveau 2
# ---------------------------------------------------------------------------

_RE_TENSION = re.compile(r"^PP(\d+)V(\d*)")


def tension_du_net(nom: str) -> str:
    """« PP3V3_S5 » → « 3,3 V » ; « PP5V_S3 » → « 5 V »."""
    m = _RE_TENSION.match(nom)
    if not m:
        raise ValueError(f"pas un rail de tension : {nom}")
    entier, decimales = m.group(1), m.group(2)
    return f"{entier},{decimales} V" if decimales else f"{entier} V"


def _fausses_tensions(nom: str) -> list:
    m = _RE_TENSION.match(nom)
    entier, dec = m.group(1), m.group(2)
    candidats = []
    if dec:
        candidats += [f"{entier}{dec} V", f"{entier} V", f"0,{entier}{dec} V",
                      f"{dec},{entier} V"]
    else:
        candidats += [f"{entier}0 V", f"0,{entier} V", f"{entier},{entier} V"]
    candidats += ["3,3 V", "5 V", "1,8 V", "12,6 V"]
    vraie = tension_du_net(nom)
    vus = []
    for c in candidats:
        if c != vraie and c not in vus:
            vus.append(c)
    return vus


_RAILS = ["PP3V3_S5", "PP5V_S3", "PP1V8_S0", "PP1V2_S3", "PP3V42_G3H",
          "PP1V05_S0", "PP0V6_S0", "PP5V_S0", "PP3V3_S0", "PP1V8_S5"]

_ETATS = {
    "G3H": "Toujours, dès qu'une batterie ou un chargeur est branché",
    "S5": "En S5, S4, S3 et S0 : machine éteinte mais alimentée, et au-delà",
    "S3": "En S3 et S0 : en veille et allumée",
    "S0": "En S0 uniquement : machine allumée",
}
_EXPLI_ETATS = (
    "Règle : un rail _Sx est présent dans l'état Sx et dans tous les états "
    "plus « réveillés ». Ordre d'allumage : G3H → S5 → S4 → S3 → S0. "
    "G3H (G3 Hot) = présent dès qu'il y a une source, même machine éteinte.")
_EXEMPLES_ETATS = {
    "G3H": ["PPBUS_G3H", "PP3V42_G3H", "PPDCIN_G3H"],
    "S5": ["PP3V3_S5", "PP1V8_S5", "PP5V_S5"],
    "S3": ["PP1V2_S3", "PP5V_S3", "PP3V3_S3"],
    "S0": ["PP3V3_S0", "PP1V05_S0", "PPVCC_S0_CPU"],
}

# (id, énoncé, bonne réponse, pièges, explication)
_FICHES_2 = [
    ("pp", "Dans « PP3V3_S5 », que signifie le préfixe PP ?",
     "Un rail d'alimentation (power plane, tension positive)",
     ["Un signal logique de commande", "Une masse", "Un point de test"],
     "Chez Apple, tout net qui commence par PP est un rail d'alimentation. "
     "La tension suit : 3V3 = 3,3 V. Les signaux logiques n'ont pas ce "
     "préfixe (PM_, SMC_, …)."),
    ("ppbus", "Qu'est-ce que PPBUS_G3H ?",
     "Le rail principal : sortie du chargeur et batterie, il alimente tous "
     "les régulateurs",
     ["Le 3,3 V du processeur", "Le bus de données USB",
      "Une alimentation réservée au clavier"],
     "PPBUS_G3H (≈ 12,6 V sur une batterie 3 cellules, ≈ 8,6 V sur 2 "
     "cellules) est le point de départ de tous les autres rails. S'il est à "
     "0 V ou en court-circuit, rien d'autre ne s'allume."),
    ("ppdcin", "Que transporte PPDCIN_G3H ?",
     "La tension d'entrée de l'adaptateur secteur (DC IN)",
     ["La tension de la batterie", "Le 5 V des ports USB",
      "La tension du processeur"],
     "DCIN = DC input. C'est l'entrée de charge, avant le circuit "
     "chargeur ; il est là dès que le chargeur est branché, d'où le G3H."),
    ("vcc_cpu", "Que désigne un net comme PPVCC_S0_CPU ?",
     "La tension du cœur du processeur, variable selon la charge",
     ["Le 3,3 V du SMC", "La tension de la batterie", "La masse du "
      "processeur"],
     "Pas de chiffre de tension dans le nom : elle est variable, choisie "
     "par le processeur (VID). Rail _S0 : présent seulement machine "
     "allumée."),
    ("suffixe_l", "SMC_RESET_L : quand le SMC est-il en reset ?",
     "Quand le signal est à 0 V (actif à l'état bas)",
     ["Quand le signal est à 3,3 V", "Quand le signal oscille",
      "Jamais : _L signifie « libre »"],
     "Chez Apple, le suffixe _L marque un signal actif à l'état bas "
     "(chez Intel on écrit souvent # : PLTRST#). Un SMC_RESET_L bloqué à "
     "0 V garde le SMC en reset."),
    ("diese", "Dans la nomenclature Intel, que signifie le « # » de PLTRST# ?",
     "Signal actif à l'état bas", ["Numéro de broche", "Signal différentiel",
                                   "Signal facultatif"],
     "# (Intel) et _L (Apple) disent la même chose : le signal agit quand il "
     "est à 0 V."),
    ("slp_s3", "PM_SLP_S3_L mesure 3,3 V. Qu'en déduis-tu ?",
     "La machine n'est pas en veille S3 : les rails _S0 peuvent s'allumer",
     ["La machine est en veille S3", "Le rail 3,3 V est en court-circuit",
      "Le SMC est en reset"],
     "SLP_S3 = « sleep S3 », actif bas. À l'état haut, l'ordre de veille "
     "n'est pas donné : le chipset demande l'allumage des rails S0. À 0 V, "
     "la machine est en veille ou éteinte."),
    ("en", "Que signifie le suffixe _EN, comme dans P3V3S5_EN ?",
     "Enable : le signal qui autorise un régulateur à démarrer",
     ["Entrée du net", "Signal d'erreur", "Énergie nominale"],
     "Un régulateur ne démarre que si son EN est actif. Rail absent : on "
     "vérifie d'abord l'alimentation d'entrée, puis l'EN."),
    ("pgood", "P3V3S5_PGOOD reste à 0 V. Que t'indique ce signal ?",
     "Le régulateur n'a pas atteint sa tension de sortie (ou ne démarre "
     "pas)", ["Le rail est parfait", "La batterie est pleine",
              "Le signal n'est pas branché"],
     "PGOOD / PWRGD = power good : le régulateur confirme que sa sortie est "
     "correcte. La séquence d'allumage attend ces signaux pour passer à "
     "l'étape suivante ; ALL_SYS_PWRGD les résume tous."),
    ("pm", "Que regroupe le préfixe PM_, comme dans PM_SLP_S4_L ?",
     "Les signaux de gestion de l'alimentation (power management)",
     ["Les signaux du port mémoire", "Les points de mesure",
      "Les signaux du micro"],
     "PM_ = power management : ordres de veille, reset, power good échangés "
     "entre le chipset, le SMC et les régulateurs."),
    ("pages", "À côté d'un nom de net, des nombres comme « 6 7 45 » "
              "indiquent…",
     "Les autres pages du schéma où ce net apparaît",
     ["Les broches du composant", "La tension en volts",
      "Le nombre de condensateurs sur le net"],
     "Ce sont des renvois de pages : c'est ainsi qu'on suit un net d'une "
     "page à l'autre (niveau 3)."),
    ("nostuff", "Un composant est marqué NOSTUFF. Cela veut dire…",
     "Il n'est pas monté sur la carte (emplacement vide, option)",
     ["Il est indispensable", "Il est soudé à l'envers",
      "Il est en court-circuit"],
     "NOSTUFF = non monté. Ne cherche pas ce composant sur la carte : son "
     "emplacement vide est normal."),
    ("xw", "Que désigne une référence XW (XW7100) ?",
     "Un pont qui relie deux nets (souvent deux masses ou deux rails)",
     ["Un quartz", "Un connecteur externe", "Un fusible réarmable"],
     "XW = liaison de nets (net tie). Elle permet de garder deux noms de "
     "nets distincts sur le schéma tout en les reliant physiquement."),
    ("val_r", "Une résistance marquée « 100K » vaut…",
     "100 kΩ", ["100 Ω", "100 MΩ", "1 kΩ"],
     "K = kilo-ohm, M = méga-ohm, R sert de virgule (4R7 = 4,7 Ω)."),
    ("val_r0", "Une résistance de « 0 » ohm sert à…",
     "Faire un pont, une option de configuration (strap)",
     ["Couper le circuit", "Limiter fortement le courant",
      "Mesurer la température"],
     "Une 0 Ω est un simple pont qu'on monte ou non selon la version de "
     "carte. Ouverte, elle coupe le net comme un fusible."),
    ("val_c", "Sur « 4.7UF 10V X5R 0402 », que représente « 10V » ?",
     "La tension maximale supportée par le condensateur",
     ["La tension du rail", "La tolérance", "La taille du boîtier"],
     "4.7UF = capacité, 10V = tension max, X5R = diélectrique, 0402 = taille "
     "du boîtier (0,04 × 0,02 pouce)."),
    ("val_boitier", "Sur « 4.7UF 10V X5R 0402 », que représente « 0402 » ?",
     "La taille du boîtier", ["La date de fabrication",
                              "La capacité en nanofarads",
                              "Le numéro de page"],
     "0402 = 0,04 × 0,02 pouce (1,0 × 0,5 mm). Utile pour retrouver le "
     "composant sur la carte."),
    ("ordre", "Dans quel ordre les rails s'allument-ils au démarrage ?",
     "G3H → S5 → S4 → S3 → S0",
     ["S0 → S3 → S4 → S5 → G3H", "S5 → G3H → S0 → S3",
      "Tous en même temps"],
     _EXPLI_ETATS),
    ("ram_s3", "Pourquoi la mémoire vive est-elle alimentée par un rail _S3 "
               "(PP1V2_S3) ?",
     "Pour garder son contenu pendant la veille", [
         "Parce qu'elle chauffe moins", "Pour démarrer avant le SMC",
         "Parce qu'elle n'a besoin que de 3 V"],
     "S3 = suspend to RAM : en veille tout s'éteint sauf la mémoire, qui "
     "doit rester alimentée pour ne rien perdre."),
]

# Questions « clique sur… » du niveau 2.
_CLICS_NIVEAU_2 = [
    ("net", {"PPBUS_G3H"},
     "Clique sur le rail présent dès qu'une batterie ou un chargeur est "
     "branché.", "PPBUS_G3H : G3H = toujours présent."),
    ("net", {"PP3V3_S5"},
     "Clique sur le rail présent quand la machine est éteinte mais branchée.",
     "PP3V3_S5 : fabriqué par U7100 dès que P3V3S5_EN est actif."),
    ("net", {"PP3V3_S0"},
     "Clique sur le rail qui se coupe dès que la machine passe en veille.",
     "PP3V3_S0 : _S0 = seulement machine allumée."),
    ("net", {"P3V3S0_EN_L"},
     "Clique sur le signal actif à l'état bas.",
     "P3V3S0_EN_L : le _L final. À 0 V, il rend Q7130 passant."),
    ("net", {"P3V3S5_EN"},
     "Clique sur le signal qui autorise le régulateur à démarrer.",
     "P3V3S5_EN arrive sur la broche EN de U7100."),
    ("net", {"P3V3S5_SW"},
     "Clique sur le nœud de commutation du régulateur.",
     "P3V3S5_SW : entre la broche SW et l'inductance ; on y voit des "
     "créneaux à l'oscilloscope, pas une tension continue."),
    ("composant", {"R7130"},
     "Clique sur la résistance de tirage (pull-up) qui bloque le MOSFET par "
     "défaut.",
     "R7130 relie la grille à la source : Vgs = 0, Q7130 reste bloqué tant "
     "que personne ne tire P3V3S0_EN_L à la masse."),
    ("composant", {"Q7130"},
     "Clique sur le composant qui recopie PP3V3_S5 en PP3V3_S0.",
     "Q7130, un MOSFET P utilisé comme interrupteur de charge."),
    ("composant", {"C7100"},
     "Clique sur le condensateur d'entrée du régulateur (côté PPBUS).",
     "C7100 est sur PPBUS_G3H, à l'entrée VIN. Sa tension max (25V) dépasse "
     "largement les ≈ 12,6 V du PPBUS."),
]


def questions_niveau_2(rng: random.Random) -> list:
    qs = []
    for ident, enonce, bonne, pieges, expl in _FICHES_2:
        choix, idx = melanger_choix(rng, Choix(bonne),
                                    [Choix(p) for p in pieges])
        qs.append(Question(id=f"conv:{ident}", niveau=2,
                           theme="Conventions", enonce=enonce, choix=choix,
                           bonne=idx, explication=expl))

    for rail in _RAILS:
        fausses = _fausses_tensions(rail)
        rng.shuffle(fausses)
        choix, idx = melanger_choix(rng, Choix(tension_du_net(rail)),
                                    [Choix(f) for f in fausses[:3]])
        qs.append(Question(
            id=f"tension:{rail}", niveau=2, theme="Noms de nets",
            enonce=f"Quelle est la tension du rail {rail} ?",
            choix=choix, bonne=idx,
            explication=f"{rail} : le V sert de virgule → "
                        f"{tension_du_net(rail)}."))

    for etat, texte in _ETATS.items():
        exemple = rng.choice(_EXEMPLES_ETATS[etat])
        choix, idx = melanger_choix(
            rng, Choix(texte), [Choix(t) for e, t in _ETATS.items()
                                if e != etat])
        qs.append(Question(
            id=f"etat:{etat}", niveau=2, theme="Suffixes d'état",
            enonce=f"Quand le rail {exemple} est-il présent ?",
            choix=choix, bonne=idx, explication=_EXPLI_ETATS))

    for i, (genre, ids, enonce, expl) in enumerate(_CLICS_NIVEAU_2):
        qs.append(Question(
            id=f"clic2:rail_3v3:{i}", niveau=2, theme="Schéma",
            enonce=enonce, type=CLIC, cible=(genre, frozenset(ids)),
            schema="rail_3v3", explication=expl))
    return qs


def questions(niveau: int, rng: random.Random) -> list:
    if niveau == 1:
        return questions_niveau_1(rng)
    if niveau == 2:
        return questions_niveau_2(rng)
    return []


def toutes_les_questions(rng: random.Random) -> list:
    return [q for n in NIVEAUX_JOUABLES for q in questions(n, rng)]

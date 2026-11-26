"""Cours « Analyser avant de réparer » : la méthode de diagnostic.

Un cours = des chapitres à lire (texte, parfois illustré par un schéma
pédagogique avec des nets colorés), suivis d'un quiz. Les questions du quiz
entrent dans la répétition espacée comme les autres (niveau ``NIVEAU_COURS``).
"""

from __future__ import annotations

import random
from dataclasses import dataclass

from .quiz import CLIC, Choix, Question, melanger_choix

NIVEAU_COURS = 0
TITRE = "Analyser avant de réparer"
RESUME = ("La méthode : questionner, inspecter, observer la consommation, "
          "suivre la chaîne d'alimentation dans l'ordre, mesurer, puis "
          "seulement réparer.")

# Couleurs des illustrations (mêmes teintes que la correction des quiz).
PRESENT = "#188038"
ABSENT = "#d93025"
A_MESURER = "#1a73e8"


@dataclass(frozen=True)
class Chapitre:
    titre: str
    html: str
    schema: str | None = None
    surlignage: tuple = ()   # ((genre, id, couleur), …)
    legende: str = ""


def _etapes(*etapes):
    """Petite frise « A → B → C » en HTML."""
    cases = "<td align='center' style='color:#9aa0a6'>&nbsp;→&nbsp;</td>".join(
        f"<td style='background:#eef3fd; border:1px solid #c6d6f5; "
        f"padding:6px 8px'>{e}</td>" for e in etapes)
    return f"<table cellspacing='0' style='margin:8px 0'><tr>{cases}</tr></table>"


CHAPITRES = (
    Chapitre(
        "1. Pourquoi une méthode",
        "<p>Remplacer un composant « au hasard » coûte du temps, des pièces, "
        "et peut abîmer une carte qui n'avait qu'un seul défaut. Un bon "
        "réparateur passe la plupart de son temps à <b>comprendre</b> et très "
        "peu à souder.</p>"
        "<p>Chaque diagnostic suit la même boucle :</p>"
        + _etapes("Symptôme", "Hypothèse", "Mesure", "Conclusion")
        + "<p>Une mesure doit toujours répondre à une question précise "
        "(« PPBUS est-il présent ? »). Si tu ne sais pas ce que tu attends "
        "comme valeur, regarde d'abord le schéma.</p>"
        "<p><b>Note tout</b> : symptôme, mesures, composants retirés. Une "
        "réparation qui dure plusieurs jours se perd vite sans notes, et ces "
        "valeurs te serviront de référence pour les cartes suivantes.</p>"
        "<p>L'ordre de travail du cours :</p>"
        "<ol><li>Questionner et inspecter</li>"
        "<li>Observer la consommation au chargeur</li>"
        "<li>Suivre la chaîne d'alimentation dans l'ordre</li>"
        "<li>Mesurer correctement (tension, mode diode)</li>"
        "<li>Localiser le composant fautif</li>"
        "<li>Réparer, puis vérifier toute la chaîne</li></ol>"),

    Chapitre(
        "2. Questionner et inspecter",
        "<p><b>Avant d'ouvrir</b>, pose les questions qui orientent tout le "
        "diagnostic :</p>"
        "<ul><li>Que s'est-il passé ? Liquide, chute, orage, mise à jour, "
        "réparation précédente ?</li>"
        "<li>La panne est-elle franche ou intermittente ?</li>"
        "<li>Le chargeur et le câble fonctionnent-ils sur une autre "
        "machine ?</li></ul>"
        "<p><b>Sécurité</b> : débranche le chargeur et <b>déconnecte la "
        "batterie</b> avant toute manipulation de la carte. Une batterie "
        "gonflée ne se perce pas et ne se plie pas.</p>"
        "<p><b>Inspection visuelle</b> à la loupe ou au microscope, avant "
        "toute mesure :</p>"
        "<ul><li>corrosion (dépôts verts ou blancs), traces de liquide ;</li>"
        "<li>composant brûlé, fendu, gonflé ou manquant ;</li>"
        "<li>connecteurs abîmés, broches tordues, nappes mal enfichées ;</li>"
        "<li>traces d'une réparation précédente (flux, soudures "
        "douteuses).</li></ul>"
        "<p>Une carte corrodée se nettoie (alcool isopropylique, brosse, bac "
        "à ultrasons) <b>avant</b> de mesurer : la corrosion fausse les "
        "mesures et crée des fuites entre nets.</p>"),

    Chapitre(
        "3. Observer la consommation",
        "<p>Un ampèremètre USB-C entre le chargeur et la machine donne un "
        "premier diagnostic en quelques secondes, sans rien démonter. Sur "
        "les Mac USB-C, le chargeur fournit d'abord <b>5 V</b> ; la machine "
        "négocie ensuite une tension plus haute (souvent <b>20 V</b>).</p>"
        "<table cellpadding='6' style='margin:6px 0'>"
        "<tr><td><b>Ce que tu vois</b></td><td><b>Piste</b></td></tr>"
        "<tr><td>5 V, 0,00 A</td><td>La carte ne demande rien : entrée de "
        "charge, contrôleur USB-C, ou court-circuit qui empêche le démarrage "
        "du chargeur. Commence par PPBUS_G3H.</td></tr>"
        "<tr><td>Reste bloqué à 5 V avec un faible courant</td><td>La carte "
        "est en partie vivante mais la négociation n'aboutit pas : côté "
        "contrôleur USB-C ou rails G3H/S5.</td></tr>"
        "<tr><td>20 V, courant qui monte puis se fige</td><td>Le démarrage "
        "commence puis bloque plus loin : séquence d'allumage, rails S0, "
        "processeur, mémoire.</td></tr>"
        "<tr><td>20 V, courant élevé dès le branchement, carte chaude</td>"
        "<td>Court-circuit franc sur un rail : on le localise "
        "(chapitre 6).</td></tr></table>"
        "<p>Ces repères sont des <b>pistes</b>, pas des verdicts : ils "
        "disent par où commencer à mesurer. Compare toujours avec ce que "
        "fait une machine saine du même modèle.</p>"),

    Chapitre(
        "4. Suivre la chaîne d'alimentation",
        "<p>Tous les rails dépendent les uns des autres. On les vérifie donc "
        "<b>dans l'ordre où ils s'allument</b> :</p>"
        + _etapes("Entrée<br>USB-C / PPDCIN", "Chargeur", "PPBUS_G3H",
                  "Rails G3H<br>(SMC)", "Rails S5", "Rails S3", "Rails S0",
                  "Processeur")
        + "<p><b>Règle d'or : remonte jusqu'au premier rail absent</b> et "
        "concentre-toi sur lui. Inutile de chercher pourquoi un rail S0 "
        "manque si PP3V3_S5 n'est déjà pas là : tout ce qui est en aval "
        "dépend de lui.</p>"
        "<p>Pour chaque régulateur, quatre vérifications, toujours dans cet "
        "ordre :</p>"
        "<ol><li><b>Entrée</b> : sa tension d'alimentation (VIN) est-elle "
        "là ?</li>"
        "<li><b>Autorisation</b> : son signal _EN est-il actif ?</li>"
        "<li><b>Sortie</b> : le rail est-il à la bonne tension ?</li>"
        "<li><b>Confirmation</b> : son _PGOOD est-il revenu ?</li></ol>"
        "<p>Exemple ci-dessous : PPBUS_G3H et PP3V3_S5 sont présents (vert), "
        "PP3V3_S0 est absent (rouge). Q7130 a son entrée : la prochaine "
        "mesure est son autorisation, P3V3S0_EN_L (bleu). À 3,3 V, personne "
        "ne demande le rail S0 : le problème est en amont (séquence "
        "d'allumage). À 0 V alors que le rail manque : Q7130 est suspect.</p>",
        schema="rail_3v3",
        surlignage=(("net", "PPBUS_G3H", PRESENT),
                    ("net", "PP3V3_S5", PRESENT),
                    ("net", "PP3V3_S0", ABSENT),
                    ("net", "P3V3S0_EN_L", A_MESURER)),
        legende="Vert : présent · Rouge : absent · Bleu : prochaine mesure"),

    Chapitre(
        "5. Mesurer correctement",
        "<p>Deux mesures font l'essentiel d'un diagnostic :</p>"
        "<p><b>Tension</b> — carte <b>alimentée</b>. Pointe noire à la "
        "masse, pointe rouge sur le net. On compare au nom du rail "
        "(PP3V3_S5 → 3,3 V) et à l'état de la machine (un rail _S0 est "
        "normalement à 0 V machine éteinte).</p>"
        "<p><b>Mode diode</b> (ou résistance à la masse) — carte <b>hors "
        "tension, batterie déconnectée</b>. Pointe rouge à la masse, pointe "
        "noire sur le net : on lit une valeur caractéristique du net.</p>"
        "<ul><li>Valeur proche de 0 (quelques millièmes) : "
        "<b>court-circuit</b> à la masse.</li>"
        "<li>Valeur normale : elle se compare à une carte saine ou à des "
        "valeurs de référence pour ce modèle.</li>"
        "<li>Garde toujours la même convention de pointes, sinon les "
        "valeurs ne se comparent plus.</li></ul>"
        "<p><b>Jamais de mode diode sur une carte alimentée</b> : la mesure "
        "est fausse et tu risques d'endommager le multimètre ou la carte. "
        "Après avoir coupé l'alimentation, attends que les gros "
        "condensateurs se déchargent.</p>"
        "<p>Mesure de préférence sur un condensateur ou un point de test du "
        "net : c'est plus sûr que sur les broches fines d'une puce, où un "
        "glissement de pointe peut créer un court-circuit.</p>"),

    Chapitre(
        "6. Localiser le composant fautif",
        "<p>Un rail absent a presque toujours l'une de ces trois causes :</p>"
        "<ol><li><b>Pas d'entrée</b> : le régulateur n'est pas alimenté → "
        "remonter la chaîne.</li>"
        "<li><b>Pas d'autorisation</b> : le _EN n'arrive pas → chercher qui "
        "le commande (SMC, séquence d'allumage).</li>"
        "<li><b>Sortie en court-circuit</b> (ou régulateur mort) → mode diode "
        "sur le rail.</li></ol>"
        "<p><b>Trouver un court-circuit</b> : le rail est à la masse, mais "
        "des dizaines de condensateurs y sont reliés. On y injecte une "
        "tension avec une alimentation de laboratoire <b>limitée en "
        "courant</b>, à une tension <b>inférieure ou égale à celle du "
        "rail</b> (on commence bas, vers 1 V). Le composant fautif chauffe : "
        "on le repère à la caméra thermique, à l'alcool isopropylique qui "
        "s'évapore plus vite sur lui, ou à la colophane qui fond.</p>"
        "<p>Ne dépasse jamais la tension nominale du rail : injecter 5 V "
        "sur un rail 1,8 V détruirait les puces qui y sont reliées.</p>"
        "<p>Une fois le suspect retiré, <b>remesure</b> : le court-circuit "
        "doit avoir disparu. Sinon, il y en avait un autre.</p>"),

    Chapitre(
        "7. Réparer et vérifier",
        "<p>Remplace le composant par une pièce de même valeur, même boîtier "
        "et même tension maximale (pour un condensateur, jamais une tension "
        "max inférieure).</p>"
        "<p>Puis <b>vérifie toute la chaîne</b>, pas seulement le rail "
        "réparé :</p>"
        "<ul><li>mode diode sur le rail réparé (plus de court-circuit) ;</li>"
        "<li>tensions de chaque étage, de PPBUS jusqu'aux rails S0 ;</li>"
        "<li>consommation au chargeur : passe-t-elle les étapes qui "
        "bloquaient ?</li>"
        "<li>essai réel : démarrage, charge, veille et réveil, sur la "
        "durée.</li></ul>"
        "<p>Un composant grillé a souvent une cause : surtension venue d'un "
        "chargeur défectueux, liquide, autre composant en amont. Cherche-la, "
        "sinon la panne reviendra.</p>"
        "<p>Enfin, note la panne, les mesures et la solution : c'est ta "
        "propre base de connaissances.</p>"),
)

# (id, énoncé, bonne réponse, pièges, explication)
_FICHES = [
    ("premier_geste", "Une carte arrive en panne. Quel est le premier "
                      "geste ?",
     "Questionner sur l'historique et inspecter visuellement la carte",
     ["Remplacer le chargeur de la carte", "Injecter 5 V sur PPBUS",
      "Changer les condensateurs proches du processeur"],
     "On commence par l'historique (liquide, chute…) et l'inspection : "
     "beaucoup de pannes se voient avant de mesurer."),
    ("batterie", "Que faire avant de manipuler la carte ?",
     "Débrancher le chargeur et déconnecter la batterie",
     ["Allumer la machine pour vérifier qu'elle chauffe",
      "Passer le multimètre en mode diode, carte alimentée",
      "Retirer tous les condensateurs de PPBUS"],
     "Sécurité d'abord : sans source branchée, pas de court-circuit "
     "accidentel ni de mesure en mode diode faussée."),
    ("corrosion", "Tu vois de la corrosion près d'un connecteur. Que fais-tu "
                  "en premier ?",
     "Nettoyer la carte, puis mesurer",
     ["Mesurer tout de suite en mode diode", "Rebrancher la batterie",
      "Remplacer le connecteur sans regarder plus loin"],
     "La corrosion fausse les mesures et crée des fuites entre nets : on "
     "nettoie (alcool isopropylique, ultrasons) avant de diagnostiquer."),
    ("ordre_chaine", "Dans quel ordre vérifies-tu les rails ?",
     "Dans l'ordre d'allumage : entrée, PPBUS_G3H, G3H, S5, S3, S0",
     ["En commençant par les rails du processeur",
      "Au hasard, selon les composants les plus visibles",
      "Du plus haut voltage au plus bas, quel que soit l'état"],
     "Chaque rail dépend des précédents : on remonte jusqu'au premier rail "
     "absent."),
    ("premier_absent", "PPBUS_G3H est présent, PP3V3_S5 est absent, et "
                       "plusieurs rails S0 manquent. Où te concentrer ?",
     "Sur PP3V3_S5, le premier rail absent",
     ["Sur les rails S0", "Sur le processeur", "Sur le chargeur"],
     "Les rails S0 dépendent de la chaîne S5 : réparer PP3V3_S5 peut suffire "
     "à les faire revenir."),
    ("quatre_points", "Pour un régulateur dont la sortie manque, que "
                      "vérifies-tu d'abord ?",
     "Son entrée (VIN), puis son signal _EN",
     ["Son _PGOOD uniquement", "La température du processeur",
      "La valeur de son inductance"],
     "Entrée → autorisation (_EN) → sortie → confirmation (_PGOOD). Sans "
     "entrée ni autorisation, le régulateur ne peut pas démarrer."),
    ("trois_causes", "Quelles sont les trois causes classiques d'un rail "
                     "absent ?",
     "Pas d'entrée, pas d'autorisation (_EN), sortie en court-circuit",
     ["Firmware, écran, clavier", "Trop de condensateurs, trop de "
      "résistances, trop de MOSFET", "Chargeur trop puissant, batterie "
      "pleine, câble trop long"],
     "Ces trois pistes, vérifiées dans l'ordre, couvrent l'immense majorité "
     "des rails manquants (plus le régulateur lui-même, en dernier)."),
    ("diode_alim", "Peut-on mesurer en mode diode sur une carte alimentée ?",
     "Non : toujours carte hors tension et batterie déconnectée",
     ["Oui, c'est plus précis", "Oui, si le chargeur est en 5 V",
      "Seulement sur les rails G3H"],
     "En mode diode, le multimètre injecte son propre petit courant : une "
     "tension présente fausse la mesure et peut l'endommager."),
    ("diode_zero", "En mode diode, un rail affiche 0,003. Qu'est-ce que cela "
                   "signifie ?",
     "Le rail est en court-circuit à la masse",
     ["Le rail est parfait", "Le rail est coupé (circuit ouvert)",
      "Le rail fait 3 V"],
     "Une valeur proche de zéro = court-circuit. Une carte saine donne une "
     "valeur nettement plus haute, propre à chaque net."),
    ("injection", "Pour localiser un court-circuit sur un rail 1,8 V, tu "
                  "injectes une tension…",
     "Limitée en courant et ne dépassant pas 1,8 V",
     ["De 20 V pour aller plus vite", "De 5 V sans limite de courant",
      "Alternative, à 230 V"],
     "On injecte au plus la tension nominale du rail, courant limité, en "
     "commençant bas : le composant en court chauffe et se repère."),
    ("ampere_5v0a", "L'ampèremètre USB-C affiche 5 V et 0,00 A. Par quoi "
                    "commences-tu ?",
     "Vérifier l'entrée de charge et PPBUS_G3H",
     ["Remplacer la mémoire", "Changer l'écran",
      "Vérifier les rails du processeur"],
     "La carte ne demande rien : on commence au tout début de la chaîne, "
     "pas au bout."),
    ("apres", "Le composant en court-circuit est remplacé. Que fais-tu "
              "ensuite ?",
     "Remesurer le rail, vérifier toute la chaîne et chercher la cause",
     ["Refermer immédiatement la machine", "Remplacer aussi tous les "
      "composants voisins", "Rien, la réparation est finie"],
     "On vérifie que le court a disparu, que chaque étage est correct, et "
     "on cherche pourquoi le composant a grillé pour éviter une récidive."),
]

# Questions sur le schéma rail_3v3, posées comme un diagnostic.
_CLICS = [
    ("net", {"P3V3S5_EN"},
     "PPBUS_G3H est présent, PP3V3_S5 est absent et n'est pas en "
     "court-circuit. Clique sur ce que tu mesures ensuite.",
     "U7100 a son entrée (PPBUS_G3H) : on vérifie son autorisation, "
     "P3V3S5_EN."),
    ("net", {"P3V3S0_EN_L"},
     "PP3V3_S5 est présent, PP3V3_S0 est absent. Clique sur le signal à "
     "mesurer pour savoir si Q7130 reçoit l'ordre de s'allumer.",
     "La grille de Q7130 est commandée par P3V3S0_EN_L : à 0 V, le MOSFET "
     "doit conduire."),
    ("net", {"PPBUS_G3H"},
     "La machine ne réagit à rien. Sur ce schéma, clique sur le premier "
     "rail à vérifier.",
     "On commence par le début de la chaîne : PPBUS_G3H alimente U7100."),
    ("composant", {"Q7130"},
     "PP3V3_S5 est présent, P3V3S0_EN_L est à 0 V, mais PP3V3_S0 reste "
     "absent (et n'est pas en court). Clique sur le composant suspect.",
     "Entrée présente, ordre donné, pas de sortie : l'interrupteur Q7130 "
     "ne fait pas son travail."),
    ("composant", {"C7110"},
     "PP3V3_S5 est en court-circuit. En injectant 3,3 V limités en courant, "
     "C7110 chauffe. Clique sur le composant à retirer.",
     "Le composant qui chauffe sous injection est le suspect n° 1 : on le "
     "retire puis on remesure le rail."),
]


def questions_cours(rng: random.Random) -> list:
    qs = []
    for ident, enonce, bonne, pieges, expl in _FICHES:
        choix, idx = melanger_choix(rng, Choix(bonne),
                                    [Choix(p) for p in pieges])
        qs.append(Question(id=f"methode:{ident}", niveau=NIVEAU_COURS,
                           theme="Méthode", enonce=enonce, choix=choix,
                           bonne=idx, explication=expl))
    for i, (genre, ids, enonce, expl) in enumerate(_CLICS):
        qs.append(Question(
            id=f"methode_clic:rail_3v3:{i}", niveau=NIVEAU_COURS,
            theme="Méthode", enonce=enonce, type=CLIC,
            cible=(genre, frozenset(ids)), schema="rail_3v3",
            explication=expl))
    return qs

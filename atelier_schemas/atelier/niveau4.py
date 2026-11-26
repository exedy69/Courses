"""Niveau 4 : la chaîne d'alimentation.

De l'entrée de charge à PPBUS_G3H, puis l'ordre d'allumage des rails
(power sequencing) jusqu'au processeur. S'appuie sur deux schémas
pédagogiques : ``entree_charge`` et ``rail_3v3``.

La séquence décrite est celle, simplifiée, d'un Mac à processeur Intel :
SMC, chipset (PCH), signaux PM_SLP_Sx_L. Les noms de nets suivent les
conventions Apple, mais les schémas sont inventés.
"""

from __future__ import annotations

import random

from .quiz import CLIC, ORDRE, Choix, Question, melanger_choix, melanger_ordre

NIVEAU = 4

# Durée accordée à un exercice « remets dans l'ordre » (secondes).
DUREE_ORDRE = 60

# (id, énoncé, étapes dans le bon ordre, explication)
_SEQUENCES = [
    ("rails", "Remets ces rails dans leur ordre d'apparition au démarrage.",
     ("PPDCIN_G3H", "PPBUS_G3H", "PP3V42_G3H", "PP3V3_S5", "PP1V2_S3",
      "PP1V05_S0"),
     "Entrée de charge → PPBUS (chargeur) → PP3V42_G3H (régulateur "
     "toujours actif du SMC) → rails S5 → rails S3 (mémoire) → rails S0. "
     "Chaque rail dépend des précédents."),
    ("avant_bouton", "Avant l'appui sur le bouton : remets les étapes dans "
                     "l'ordre.",
     ("Le chargeur est branché : PPDCIN_G3H",
      "Le chargeur fabrique PPBUS_G3H",
      "PP3V42_G3H alimente le SMC, qui démarre",
      "Les rails S5 s'allument, le SMC relâche PM_RSMRST_L"),
     "Tout cela se passe machine « éteinte » : c'est l'état de veille "
     "profonde, prêt à réagir au bouton. RSMRST = resume reset : le SMC dit "
     "au chipset que ses rails S5 sont bons."),
    ("apres_bouton", "Après l'appui sur le bouton : remets les étapes dans "
                     "l'ordre.",
     ("Le SMC transmet l'appui au chipset (PM_PWRBTN_L)",
      "PM_SLP_S4_L passe à l'état haut : rails S3 (mémoire)",
      "PM_SLP_S3_L passe à l'état haut : rails S0",
      "Tous les PGOOD sont bons : ALL_SYS_PWRGD",
      "Le régulateur du processeur démarre, PLTRST# se relâche"),
     "Le chipset relâche ses signaux de veille l'un après l'autre ; chaque "
     "groupe de rails confirme par ses PGOOD avant l'étape suivante. Le "
     "reset de plateforme (PLTRST#) est relâché en dernier."),
    ("regulateur", "Pour un régulateur, remets les vérifications dans "
                   "l'ordre.",
     ("Entrée (VIN) présente", "Autorisation (_EN) active",
      "Sortie à la bonne tension", "Confirmation (_PGOOD) à l'état haut"),
     "Sans entrée ni autorisation, un régulateur ne peut pas démarrer : on "
     "vérifie toujours dans cet ordre."),
    ("chemin_charge", "Suis le courant de l'adaptateur jusqu'à PPBUS_G3H "
                      "(schéma page 95).",
     ("Connecteur J9500", "Fusible F9500", "MOSFET d'isolation Q9510",
      "Chargeur U9600 et bobine L9610", "PPBUS_G3H"),
     "PPDCIN_G3H → fusible → PPDCIN_G3H_F → Q9510 → PPVIN_CHGR → "
     "chargeur (à découpage, avec L9610) → PPBUS_G3H."),
]

# (id, énoncé, bonne réponse, pièges, explication)
_FICHES = [
    ("sans_chargeur", "Sans chargeur branché, qui alimente PPBUS_G3H ?",
     "La batterie, à travers le MOSFET batterie (Q9700)",
     ["Le SMC", "Le régulateur PP3V42_G3H", "Personne : la machine "
      "s'éteint"],
     "Le chargeur choisit la source : adaptateur quand il est là, sinon la "
     "batterie via le MOSFET batterie, commandé par CHGR_BGATE."),
    ("role_chargeur", "Pourquoi un circuit chargeur entre l'adaptateur et "
                      "PPBUS ?",
     "Il choisit la source, charge la batterie et régule PPBUS",
     ["Il convertit le 230 V alternatif", "Il fabrique les rails S0",
      "Il sert uniquement de fusible"],
     "Le chargeur (U9600) gère l'adaptateur, la batterie et PPBUS. C'est un "
     "régulateur à découpage, d'où la bobine L9610."),
    ("isolation", "À quoi sert le MOSFET d'isolation Q9510 ?",
     "Ne laisser passer l'adaptateur que lorsque le chargeur l'autorise",
     ["Charger la batterie", "Fabriquer PP3V42_G3H",
      "Mesurer la température"],
     "Le chargeur commande sa grille (CHGR_AGATE) : un adaptateur absent "
     "ou hors tolérance reste isolé du reste de la carte."),
    ("acok", "Que signale CHGR_ACOK ?",
     "Que l'adaptateur est présent et que sa tension est correcte",
     ["Que la batterie est pleine", "Que le processeur a démarré",
      "Que PPBUS est en court-circuit"],
     "AC OK : le chargeur prévient le SMC qu'un adaptateur valide est "
     "branché. Absent alors que PPDCIN est bon : regarder le chargeur."),
    ("pp3v42", "Pourquoi PP3V42_G3H est-il présent en permanence ?",
     "Il alimente le SMC, qui doit surveiller le bouton et la charge même "
     "machine éteinte",
     ["Il alimente l'écran", "Il sert de référence au processeur",
      "Il recharge la pile de l'horloge"],
     "Son régulateur a son EN relié à PPBUS : dès que PPBUS existe, le SMC "
     "est alimenté. Pas de PP3V42_G3H = SMC mort = rien ne démarre."),
    ("fusible", "PPDCIN_G3H est présent mais PPDCIN_G3H_F est à 0 V. "
                "Conclusion ?",
     "Le fusible F9500 est ouvert",
     ["Le chargeur est en panne", "La batterie est vide",
      "Le SMC est en reset"],
     "Tension d'un côté, rien de l'autre : le fusible est coupé. Il a "
     "souvent fondu à cause d'un court-circuit plus loin : cherche-le "
     "avant d'en souder un neuf."),
    ("ppbus_absent", "PPVIN_CHGR est présent, PPBUS_G3H est absent et "
                     "n'est pas en court-circuit. Suspect principal ?",
     "Le chargeur U9600 (ou ses conditions de démarrage)",
     ["Le fusible F9500", "Le connecteur J9500", "La mémoire"],
     "L'entrée du chargeur est bonne, sa sortie non : on regarde le "
     "chargeur, sa bobine et ce qui l'autorise à démarrer."),
    ("rsmrst", "Que signifie PM_RSMRST_L relâché par le SMC ?",
     "Les rails S5 sont bons : le chipset peut sortir de son reset",
     ["Le processeur redémarre", "La batterie est déconnectée",
      "L'écran s'allume"],
     "RSMRST = resume reset. Tant qu'il est à 0 V, le chipset reste en "
     "reset et ignore le bouton d'allumage."),
    ("slp_s3_bas", "Après l'appui sur le bouton, PM_SLP_S3_L reste à 0 V. "
                   "Que vérifies-tu ?",
     "Ce qui précède : rails S5, PM_RSMRST_L, appui transmis au chipset",
     ["Le régulateur du processeur", "Les rails S0 un par un",
      "L'écran"],
     "Le chipset ne lance pas les rails S0 : inutile de chercher dans les "
     "rails S0, la séquence s'est arrêtée avant."),
    ("all_sys", "Que résume ALL_SYS_PWRGD ?",
     "Tous les régulateurs ont confirmé leur tension (PGOOD)",
     ["La batterie est chargée", "Le système d'exploitation a démarré",
      "Le chargeur est branché"],
     "C'est le feu vert final de l'alimentation : le régulateur du "
     "processeur peut démarrer."),
    ("vcc_cpu_absent", "Tous les rails S0 sont présents sauf PPVCC_S0_CPU. "
                       "Où chercher ?",
     "Le régulateur du processeur : son autorisation et ALL_SYS_PWRGD",
     ["Le chargeur", "Le fusible d'entrée", "PP3V42_G3H"],
     "On remonte au premier élément absent de la séquence. Le régulateur "
     "processeur attend ALL_SYS_PWRGD et son propre signal d'activation."),
    ("pltrst", "Quel signal est relâché en dernier pour lancer le "
               "processeur ?",
     "PLTRST# (reset de plateforme)",
     ["PM_RSMRST_L", "CHGR_ACOK", "PM_SLP_S4_L"],
     "Le reset de plateforme maintient processeur et périphériques en "
     "reset jusqu'à ce que toute l'alimentation soit bonne."),
]

# (genre, ids, énoncé, explication) sur le schéma entree_charge.
_CLICS = [
    ("composant", {"F9500"}, "Clique sur le fusible d'entrée.",
     "F9500, juste après le connecteur DC IN."),
    ("composant", {"U9600"}, "Clique sur le circuit chargeur.",
     "U9600, avec ses broches AGATE, VIN, SW et ACOK."),
    ("composant", {"Q9700"},
     "Clique sur le MOSFET qui relie la batterie à PPBUS_G3H.",
     "Q9700, entre PPBUS_G3H et PPVBAT_G3H, commandé par CHGR_BGATE."),
    ("composant", {"Q9510"},
     "Clique sur le MOSFET d'isolation de l'entrée.",
     "Q9510, commandé par le chargeur via CHGR_AGATE."),
    ("composant", {"U9800"},
     "Clique sur le régulateur toujours actif qui alimente le SMC.",
     "U9800 fabrique PP3V42_G3H à partir de PPBUS_G3H."),
    ("net", {"PP3V42_G3H"}, "Clique sur le rail qui alimente le SMC.",
     "PP3V42_G3H : présent dès que PPBUS_G3H existe."),
    ("net", {"CHGR_ACOK"},
     "Clique sur le signal qui indique que l'adaptateur est bon.",
     "CHGR_ACOK part du chargeur vers le SMC (renvoi page 40)."),
    ("net", {"PPBUS_G3H"},
     "Clique sur le net qui autorise U9800 à démarrer (sa broche EN).",
     "L'EN de U9800 est relié directement à PPBUS_G3H : il démarre dès "
     "que PPBUS existe, d'où un rail « toujours présent »."),
    ("composant", {"F9500"},
     "PPDCIN_G3H est présent, PPDCIN_G3H_F est absent. Clique sur le "
     "suspect.",
     "Tension avant, rien après : F9500 est ouvert."),
    ("net", {"PPVBAT_G3H"}, "Clique sur le rail de la batterie.",
     "PPVBAT_G3H relie le connecteur batterie J9700 au MOSFET Q9700."),
    ("net", {"CHGR_SW"},
     "Clique sur le nœud de commutation du chargeur.",
     "CHGR_SW, entre la broche SW de U9600 et la bobine L9610."),
]


def questions_niveau_4(rng: random.Random) -> list:
    qs = []
    for ident, enonce, etapes, expl in _SEQUENCES:
        qs.append(Question(
            id=f"sequence:{ident}", niveau=NIVEAU, theme="Séquence",
            enonce=enonce, type=ORDRE, choix=melanger_ordre(rng, etapes),
            ordre=tuple(etapes), duree=DUREE_ORDRE, explication=expl))
    for ident, enonce, bonne, pieges, expl in _FICHES:
        choix, idx = melanger_choix(rng, Choix(bonne),
                                    [Choix(p) for p in pieges])
        qs.append(Question(id=f"chaine:{ident}", niveau=NIVEAU,
                           theme="Chaîne d'alimentation", enonce=enonce,
                           choix=choix, bonne=idx, explication=expl))
    for i, (genre, ids, enonce, expl) in enumerate(_CLICS):
        qs.append(Question(
            id=f"clic4:entree_charge:{i}", niveau=NIVEAU, theme="Schéma",
            enonce=enonce, type=CLIC, cible=(genre, frozenset(ids)),
            schema="entree_charge", explication=expl))
    return qs

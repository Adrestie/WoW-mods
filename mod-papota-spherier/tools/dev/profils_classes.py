# -*- coding: utf-8 -*-
r"""Ce que chaque classe et chaque spécialisation savent employer.

Écrit par archétypes plutôt que classe par classe : dix classes fois trois
spécialisations fois seize statistiques font près de cinq cents chiffres, et une
table écrite à la main à cette taille ne se relit pas. On part donc de six
profils de rôle, et chaque spécialisation les ajuste de quelques valeurs — celles
qui la distinguent vraiment.

**Deux spécialisations du même rôle doivent malgré tout différer**, sans quoi
leurs deux zones proposeraient la même chose et le zonage ne dirait plus rien.
Un mage Arcane vit de l'intelligence, un mage Feu du critique, un mage Givre de
la hâte : c'est peu, mais c'est ce qui rend les trois branches lisibles.

Les valeurs vont de 0 à 1 et disent l'intérêt en jeu, pas une catégorie. Une
statistique laissée hors de `utiles` ne paraît nulle part sur la grille.
"""

# ---------------------------------------------------------------------------
# Les rôles
# ---------------------------------------------------------------------------
TANK = {
    "endurance": 1.00, "parade": 1.00, "blocage": 1.00, "esquive": 0.95,
    "expertise": 0.85, "dexterite": 0.80, "touche": 0.50, "force": 0.40,
    "hate": 0.30, "critique": 0.25, "puissance_attaque": 0.15,
    "penetration_armure": 0.08, "intelligence": 0.05, "esprit": 0.05,
    "puissance_sorts": 0.05, "bonus_soins": 0.05,
}
MELEE_FORCE = {
    "force": 1.00, "touche": 0.95, "critique": 0.95, "expertise": 0.90,
    "puissance_attaque": 0.90, "hate": 0.90, "penetration_armure": 0.70,
    "dexterite": 0.45, "endurance": 0.25, "parade": 0.05, "blocage": 0.03,
    "esquive": 0.05, "intelligence": 0.03, "esprit": 0.03,
    "puissance_sorts": 0.03, "bonus_soins": 0.03,
}
MELEE_DEXTERITE = {
    "dexterite": 1.00, "touche": 0.95, "critique": 0.95, "hate": 0.90,
    "puissance_attaque": 0.90, "expertise": 0.85, "penetration_armure": 0.80,
    "force": 0.40, "endurance": 0.25, "parade": 0.05, "blocage": 0.03,
    "esquive": 0.10, "intelligence": 0.03, "esprit": 0.03,
    "puissance_sorts": 0.03, "bonus_soins": 0.03,
}
DISTANCE = {
    "dexterite": 1.00, "touche": 0.95, "critique": 0.90,
    "puissance_attaque": 0.90, "penetration_armure": 0.85, "hate": 0.80,
    "intelligence": 0.30, "force": 0.10, "endurance": 0.25, "expertise": 0.05,
    "parade": 0.03, "blocage": 0.02, "esquive": 0.08, "esprit": 0.05,
    "puissance_sorts": 0.03, "bonus_soins": 0.03,
}
LANCEUR = {
    "intelligence": 1.00, "puissance_sorts": 1.00, "critique": 0.90,
    "hate": 0.90, "touche": 0.85, "esprit": 0.40, "endurance": 0.25,
    "bonus_soins": 0.10, "dexterite": 0.05, "force": 0.03, "expertise": 0.03,
    "puissance_attaque": 0.03, "penetration_armure": 0.03,
    "parade": 0.03, "blocage": 0.02, "esquive": 0.05,
}
SOIGNEUR = {
    "intelligence": 1.00, "bonus_soins": 1.00, "puissance_sorts": 0.90,
    "esprit": 0.90, "hate": 0.85, "critique": 0.80, "endurance": 0.30,
    "touche": 0.15, "dexterite": 0.05, "force": 0.03, "expertise": 0.03,
    "puissance_attaque": 0.03, "penetration_armure": 0.03,
    "parade": 0.03, "blocage": 0.02, "esquive": 0.05,
}


def melange(base, **changements):
    """Un rôle, retouché de quelques valeurs — celles qui distinguent la spé."""
    p = dict(base)
    p.update(changements)
    return p


# ---------------------------------------------------------------------------
# Les classes
# ---------------------------------------------------------------------------
# `utiles` : ce qui paraît sur la grille, et rien d'autre. `commun` : ce que le
# centre propose, avant toute orientation — les statistiques que les trois
# spécialisations savent toutes employer. `specs` : les trois branches, dans
# l'ordre des angles croissants depuis le départ.
CLASSES = {

    "warrior": {
        "id": 1,
        "utiles": ["endurance", "force", "parade", "blocage", "esquive", "hate",
                   "critique", "touche", "puissance_attaque",
                   "penetration_armure", "expertise"],
        "commun": {"force": 1.00, "endurance": 1.00, "critique": 0.90,
                   "hate": 0.90, "touche": 0.50, "puissance_attaque": 0.50,
                   "expertise": 0.35, "penetration_armure": 0.35,
                   "parade": 0.16, "blocage": 0.14, "esquive": 0.16},
        "specs": [
            ("Fureur", melange(MELEE_FORCE, hate=1.00, touche=1.00,
                               critique=0.85, expertise=0.85, force=0.70,
                               penetration_armure=0.40, endurance=0.25)),
            ("Armes", melange(MELEE_FORCE, penetration_armure=1.00,
                              critique=1.00, puissance_attaque=0.90,
                              touche=0.80, expertise=0.75, force=0.70,
                              hate=0.30, endurance=0.25)),
            ("Protection", melange(TANK, touche=0.50, force=0.40,
                                   critique=0.25, hate=0.30)),
        ],
    },

    "paladin": {
        "id": 2,
        "utiles": ["endurance", "intelligence", "esprit", "force", "parade",
                   "blocage", "esquive", "hate", "critique", "touche",
                   "puissance_sorts", "puissance_attaque", "expertise",
                   "bonus_soins"],
        "commun": {"endurance": 1.00, "force": 0.90, "intelligence": 0.85,
                   "critique": 0.85, "hate": 0.85, "touche": 0.45,
                   "puissance_attaque": 0.45, "puissance_sorts": 0.45,
                   "expertise": 0.30, "esprit": 0.30, "bonus_soins": 0.30,
                   "parade": 0.16, "blocage": 0.14, "esquive": 0.16},
        "specs": [
            ("Vindicte", melange(MELEE_FORCE, penetration_armure=0.0,
                                 puissance_sorts=0.35, intelligence=0.20)),
            ("Protection", TANK),
            ("Sacré", SOIGNEUR),
        ],
    },

    "hunter": {
        "id": 3,
        "utiles": ["endurance", "intelligence", "dexterite", "hate", "critique",
                   "touche", "puissance_attaque", "penetration_armure"],
        "commun": {"dexterite": 1.00, "critique": 0.90, "hate": 0.85,
                   "endurance": 0.55, "touche": 0.55, "puissance_attaque": 0.55,
                   "penetration_armure": 0.35, "intelligence": 0.30},
        "specs": [
            # Précision : le toucher est sa signature, le pet vit de la maîtrise.
            ("Maîtrise des bêtes", melange(DISTANCE, puissance_attaque=1.00,
                                           critique=0.80, hate=0.70,
                                           penetration_armure=0.55,
                                           endurance=0.55)),
            ("Précision", melange(DISTANCE, penetration_armure=1.00,
                                  critique=1.00, hate=0.55,
                                  puissance_attaque=0.85)),
            # La Survie est la branche robuste : c'est elle qui accueille
            # l'endurance et l'intelligence, faute de quoi les deux reflueraient
            # au centre.
            ("Survie", melange(DISTANCE, hate=1.00, touche=1.00,
                               intelligence=0.85, endurance=0.85,
                               critique=0.80, penetration_armure=0.45)),
        ],
    },

    "rogue": {
        "id": 4,
        # La force sort de la liste : un voleur n'en tire à peu près rien, et une
        # statistique qu'aucune branche ne veut n'a rien à faire sur la grille.
        "utiles": ["endurance", "dexterite", "esquive", "hate",
                   "critique", "touche", "puissance_attaque",
                   "penetration_armure", "expertise"],
        "commun": {"dexterite": 1.00, "critique": 0.90, "hate": 0.90,
                   "endurance": 0.50, "touche": 0.55, "puissance_attaque": 0.50,
                   "expertise": 0.35, "penetration_armure": 0.35,
                   "esquive": 0.20},
        "specs": [
            ("Assassinat", melange(MELEE_DEXTERITE, touche=1.00, critique=1.00,
                                   hate=0.70, penetration_armure=0.45)),
            ("Combat", melange(MELEE_DEXTERITE, penetration_armure=1.00,
                               expertise=1.00, hate=0.85, critique=0.75)),
            # La Finesse est la branche insaisissable : esquive et endurance y
            # trouvent leur place.
            ("Finesse", melange(MELEE_DEXTERITE, hate=1.00, esquive=0.90,
                                endurance=0.85, puissance_attaque=1.00,
                                critique=0.80, penetration_armure=0.50)),
        ],
    },

    "priest": {
        "id": 5,
        "utiles": ["endurance", "intelligence", "esprit", "hate", "critique",
                   "touche", "puissance_sorts", "bonus_soins"],
        "commun": {"intelligence": 1.00, "puissance_sorts": 0.85,
                   "critique": 0.85, "hate": 0.85, "endurance": 0.50,
                   "esprit": 0.55, "bonus_soins": 0.45, "touche": 0.35},
        "specs": [
            ("Ombre", melange(LANCEUR, touche=1.00, hate=0.95, critique=0.85,
                              esprit=0.55, bonus_soins=0.0)),
            # La Discipline protège : l'endurance est chez elle.
            ("Discipline", melange(SOIGNEUR, critique=0.95, hate=0.90,
                                   endurance=0.90, esprit=0.55)),
            ("Sacré", melange(SOIGNEUR, esprit=1.00, bonus_soins=1.00,
                              critique=0.70)),
        ],
    },

    "deathknight": {
        "id": 6,
        "utiles": ["endurance", "force", "parade", "esquive", "hate",
                   "critique", "touche", "puissance_attaque",
                   "penetration_armure", "expertise"],
        "commun": {"force": 1.00, "endurance": 1.00, "critique": 0.85,
                   "hate": 0.85, "touche": 0.50, "puissance_attaque": 0.50,
                   "expertise": 0.40, "penetration_armure": 0.35,
                   "parade": 0.18, "esquive": 0.16},
        "specs": [
            # Sang tanke, Givre frappe des deux mains, Impie vit de la hâte.
            ("Impie", melange(MELEE_FORCE, hate=1.00, touche=0.95,
                              penetration_armure=0.90, critique=0.85)),
            ("Sang", melange(TANK, blocage=0.0, dexterite=0.0, force=0.60,
                             puissance_attaque=0.35, parade=1.00,
                             esquive=1.00, touche=0.60)),
            ("Givre", melange(MELEE_FORCE, touche=1.00, expertise=1.00,
                              critique=0.90, hate=0.75,
                              penetration_armure=0.50)),
        ],
    },

    "shaman": {
        "id": 7,
        "utiles": ["endurance", "intelligence", "esprit", "dexterite", "force",
                   "hate", "critique", "touche", "puissance_sorts",
                   "puissance_attaque", "expertise", "bonus_soins"],
        "commun": {"intelligence": 0.95, "endurance": 0.50, "critique": 0.90,
                   "hate": 0.90, "puissance_sorts": 0.55, "force": 0.50,
                   "dexterite": 0.50, "touche": 0.50,
                   "puissance_attaque": 0.45, "esprit": 0.35,
                   "bonus_soins": 0.30, "expertise": 0.25},
        "specs": [
            # L'Amélioration se bat au corps à corps : l'endurance y trouve sa
            # branche, comme la force et la puissance des sorts des armes.
            ("Amélioration", melange(MELEE_DEXTERITE, penetration_armure=0.0,
                                     force=0.70, intelligence=0.45,
                                     endurance=0.85, puissance_sorts=0.55,
                                     hate=1.00)),
            ("Élémentaire", melange(LANCEUR, touche=1.00, critique=0.95,
                                    hate=0.80)),
            ("Restauration", melange(SOIGNEUR, hate=0.95, intelligence=1.00,
                                     critique=0.65)),
        ],
    },

    "mage": {
        "id": 8,
        "utiles": ["endurance", "intelligence", "esprit", "hate", "critique",
                   "touche", "puissance_sorts"],
        "commun": {"intelligence": 1.00, "puissance_sorts": 0.90,
                   "critique": 0.90, "hate": 0.90, "endurance": 0.45,
                   "touche": 0.45, "esprit": 0.35},
        "specs": [
            # Les Arcanes vivent de la réserve de mana : l'esprit y est chez lui.
            ("Arcanes", melange(LANCEUR, intelligence=1.00,
                                puissance_sorts=1.00, hate=0.70,
                                critique=0.70, esprit=0.90)),
            ("Feu", melange(LANCEUR, critique=1.00, touche=0.95, hate=0.75,
                            intelligence=0.80)),
            # Le Givre est la branche qui tient : l'endurance y est chez elle.
            ("Givre", melange(LANCEUR, hate=1.00, touche=1.00, critique=0.80,
                              endurance=0.85, intelligence=0.85)),
        ],
    },

    "warlock": {
        "id": 9,
        "utiles": ["endurance", "intelligence", "esprit", "hate", "critique",
                   "touche", "puissance_sorts"],
        "commun": {"intelligence": 0.95, "puissance_sorts": 1.00,
                   "hate": 0.90, "critique": 0.85, "endurance": 0.45,
                   "touche": 0.45, "esprit": 0.30},
        "specs": [
            # L'Affliction draine : l'esprit y est chez lui.
            ("Affliction", melange(LANCEUR, hate=1.00, touche=1.00,
                                   critique=0.60, esprit=0.90)),
            # La Démonologie encaisse : c'est la branche de l'endurance.
            ("Démonologie", melange(LANCEUR, puissance_sorts=1.00,
                                    endurance=0.95, intelligence=0.95,
                                    critique=0.70)),
            ("Destruction", melange(LANCEUR, critique=1.00, touche=0.90,
                                    hate=0.80)),
        ],
    },

    "druid": {
        "id": 11,
        "utiles": ["endurance", "intelligence", "esprit", "dexterite", "force",
                   "esquive", "hate", "critique", "touche", "puissance_sorts",
                   "puissance_attaque", "penetration_armure", "expertise",
                   "bonus_soins"],
        "commun": {"intelligence": 0.90, "endurance": 0.55, "critique": 0.90,
                   "hate": 0.90, "dexterite": 0.60, "puissance_sorts": 0.50,
                   "force": 0.45, "touche": 0.50, "puissance_attaque": 0.45,
                   "esprit": 0.35, "bonus_soins": 0.30, "expertise": 0.25,
                   "esquive": 0.20},
        "specs": [
            # Le Farouche prend la forme d'ours autant que de félin : endurance,
            # esquive et force y ont toutes les trois leur place.
            ("Farouche", melange(MELEE_DEXTERITE, esquive=0.90,
                                 endurance=0.95, force=0.80)),
            ("Équilibre", melange(LANCEUR, touche=1.00, hate=0.95,
                                  critique=0.85)),
            ("Restauration", melange(SOIGNEUR, esprit=1.00, hate=0.90,
                                     critique=0.65)),
        ],
    },
}


def profil(classe):
    """Rend (utiles, commun, [(nom, profil), ...]) pour une classe."""
    d = CLASSES[classe]
    utiles = list(d["utiles"])
    commun = dict((s, d["commun"].get(s, 0.05)) for s in utiles)
    specs = [(nom, dict((s, p.get(s, 0.03)) for s in utiles))
             for nom, p in d["specs"]]
    return utiles, commun, specs

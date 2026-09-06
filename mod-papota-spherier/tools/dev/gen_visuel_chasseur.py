# -*- coding: utf-8 -*-
r"""Monte le visuel de la Bombe incendiaire du chasseur (8600023).

Aucun fichier à injecter : tout est NATIF au client 3.3.5, seuls les
enregistrements DBC sont posés. Relevés du 2026-08-31 :

  - `spells\missile_bomb.mdx`  = effet 1863 — la bombe qui vole ;
  - `Spells\Bomb_ExplosionA.mdx` = effet 257 — l'explosion à l'arrivée ;
  - le Choc de flammes (42926, visuel 10408) porte au champ 25 le kit 9357 :
    LA FLAQUE DE FEU persistante. Réutilisé tel quel — c'est explicitement
    l'effet demandé (« faire comme l'effet persistant du choc de flamme »).

La charpente du visuel suit celle de la Boule de feu (relevé 67) : kit de
lancer au champ 2, kit d'IMPACT au champ 3 (il joue au point d'arrivée du
missile), champ 7 = HasMissile, 8 = modèle du missile, 10 = attache à
destination, 16 = -1 (départ main). Le sort porte la vitesse du missile
(sorts_classes) : sans elle, rien ne vole.

    python gen_visuel_chasseur.py      (JEU FERMÉ requis : écrit dans patch-z)
"""
import ctypes as C
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sorts_classes as G
from gen_visuel_aube import Dbc, stormlib, lit, ecrit
from gen_visuel_voleur import lit_effectif

sys.stdout.reconfigure(encoding="utf-8")

BS = chr(92)

KIT_BOMBE_LANCER = 30038     # l'animation de jet, sans effet ni son
KIT_BOMBE_IMPACT = 30039     # l'explosion, au point d'arrivée
VISUEL_BOMBE = 30038

ANIM_LANCER = 107            # AttackThrown — le jet, prouvé sur le grappin
EFFET_MISSILE_BOMBE = 1863   # spells\missile_bomb.mdx
EFFET_EXPLOSION = 257        # Spells\Bomb_ExplosionA.mdx
KIT_ZONE_CHOC_FLAMMES = 9357  # la flaque du Choc de flammes — NATIF, jamais
                              # modifié, seulement référencé

# --- l'animation des Tirs consécutifs (8600022, 2026-08-31) -----------------
# Le personnage restait statique : un sort DÉCLENCHÉ ne rejoue pas
# l'animation de lancement, et l'emote envoyée à la main est ignorée pendant
# une canalisation (les deux tentatives précédentes). Le canal qui marche est
# celui des KITS (prouvé sur le bond héroïque et la Marque) : trois kits nus
# ne portant QUE l'animation, choisis selon l'arme portée.
KITS_TIR = [
    (30040, 46, "arc et arbalete"),   # AttackBow
    (30041, 49, "fusil"),             # AttackRifle
    (30042, 107, "arme de jet"),      # AttackThrown
]

# --- la détonation des traits fichés (8600098, 2026-08-31) ------------------
# L'explosion arcane demandée : le kit d'IMPACT de l'Explosion des arcanes
# native (relevé du visuel 965 : 1 = 266, 2 = 1004 lancer, 3 = 1005 impact).
# Le 1005 est réutilisé tel quel — jamais modifié.
VISUEL_DETONATION = 30043
KIT_IMPACT_ARCANE = 1005

# --- l'icône des Tirs consécutifs (8600022) et de sa détonation ------------
# Seul fichier à injecter de ce générateur : l'icône exportée le 2026-08-31.
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_chasseur")
ICONE_TIRS = 8060
NOM_ICONE_TIRS = "ability_hunter_blindingshot"


def main():
    dll = stormlib()
    h = C.c_void_p()
    if not dll.SFileOpenArchive(G.ARCHIVE, 0, 0, C.byref(h)):
        raise SystemExit("archive non ouverte en écriture — JEU FERMÉ requis")
    try:
        prefixe = "DBFilesClient" + BS

        # --- l'icône ----------------------------------------------------------
        local = os.path.join(ART, "interface", "icons",
                             NOM_ICONE_TIRS + ".blp")
        interne = ("Interface" + BS + "Icons" + BS + NOM_ICONE_TIRS + ".blp")
        donnees = io.open(local, "rb").read()
        ecrit(dll, h, interne, donnees)
        if len(lit(dll, h, interne)) != len(donnees):
            raise SystemExit("injection de l'icône non conforme")
        brut, source = lit_effectif(dll, h, "SpellIcon.dbc")
        d = Dbc(brut)
        d.retire({ICONE_TIRS})
        d.pose([ICONE_TIRS, d.chaine("Interface" + BS + "Icons" + BS
                                     + NOM_ICONE_TIRS)])
        ecrit(dll, h, prefixe + "SpellIcon.dbc", d.octets())
        print("SpellIcon : %d -> %s — base %s"
              % (ICONE_TIRS, NOM_ICONE_TIRS, source))

        # --- SpellVisualKit : le jet et l'explosion ---------------------------
        # 38 champs (relevé gen_visuel_voleur) : champ 2 = animation,
        # champ 5 = effet au point d'attache Base.
        d = Dbc(lit(dll, h, prefixe + "SpellVisualKit.dbc"))
        d.retire({KIT_BOMBE_LANCER, KIT_BOMBE_IMPACT}
                 | {ident for ident, _a, _n in KITS_TIR})
        d.pose([KIT_BOMBE_LANCER, -1, ANIM_LANCER] + [0] * 12 + [0, 0]
               + [-1, -1, -1, -1] + [0] * 17)
        d.pose([KIT_BOMBE_IMPACT, -1, -1, 0, 0, EFFET_EXPLOSION]
               + [0] * 9 + [0, 0] + [-1, -1, -1, -1] + [0] * 17)
        for ident, anim, _nom in KITS_TIR:
            d.pose([ident, -1, anim] + [0] * 12 + [0, 0]
                   + [-1, -1, -1, -1] + [0] * 17)
        ecrit(dll, h, prefixe + "SpellVisualKit.dbc", d.octets())
        print("SpellVisualKit : kits %d (jet, anim %d), %d (explosion %d) et"
              " %s (animations de tir) posés"
              % (KIT_BOMBE_LANCER, ANIM_LANCER, KIT_BOMBE_IMPACT,
                 EFFET_EXPLOSION,
                 "/".join(str(i) for i, _a, _n in KITS_TIR)))

        # --- SpellVisual ------------------------------------------------------
        d = Dbc(lit(dll, h, prefixe + "SpellVisual.dbc"))
        d.retire({VISUEL_BOMBE, VISUEL_DETONATION})
        det = [0] * 32
        det[0] = VISUEL_DETONATION
        det[3] = KIT_IMPACT_ARCANE      # l'explosion arcane, sur la cible
        d.pose(det)
        v = [0] * 32
        v[0] = VISUEL_BOMBE
        v[2] = KIT_BOMBE_LANCER
        v[3] = KIT_BOMBE_IMPACT
        v[7] = 1                      # HasMissile
        v[8] = EFFET_MISSILE_BOMBE
        v[10] = 1                     # attache à destination
        v[16] = -1                    # départ : la main
        v[25] = KIT_ZONE_CHOC_FLAMMES  # la flaque persistante
        d.pose(v)
        ecrit(dll, h, prefixe + "SpellVisual.dbc", d.octets())
        print("SpellVisual : visuels %d (jet %d, missile %d, explosion %d,"
              " zone persistante %d) et %d (détonation arcane, kit natif %d)"
              " posés"
              % (VISUEL_BOMBE, KIT_BOMBE_LANCER, EFFET_MISSILE_BOMBE,
                 KIT_BOMBE_IMPACT, KIT_ZONE_CHOC_FLAMMES, VISUEL_DETONATION,
                 KIT_IMPACT_ARCANE))
    finally:
        dll.SFileCloseArchive(h)
    print("\nLe sort 8600023 pointe ce visuel (sorts_classes.py) : régénérer"
          " par\n  python gen_sorts_classes.py --deploy")


if __name__ == "__main__":
    main()

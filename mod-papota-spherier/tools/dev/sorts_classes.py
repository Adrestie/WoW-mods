# -*- coding: utf-8 -*-
r"""Les quarante sorts de classe : ce qu'ils sont, et ce qu'ils font.

Quatre par classe — un de mobilité, commun à la classe, et un par
spécialisation. Tous à RANG UNIQUE : aucune ligne dans `spell_ranks`, ce qui
écarte au passage le plantage de `GetSpellWithRank` déjà rencontré.

**Les identifiants se lisent.** 86000CS, où C est le numéro de classe dans
l'ordre du jeu et S le numéro du sort dans la classe — 0 pour la mobilité, 1 à 3
pour les trois spécialisations. Le sort 8600031 est donc le premier sort de
spécialisation du voleur.

**Le client de 3.3.5 n'a l'art d'aucun de ces sorts.** Chacun emprunte donc le
`SpellVisualID` d'un sort existant, choisi pour son registre : la charge du
guerrier pour un bond, la nova de givre pour une pluie de comètes. C'est le choix
qui décide le plus de l'aspect en jeu, et c'est celui qu'il faudra revoir le plus
souvent.

**Les paliers** disent le travail restant : 1, l'effet vit entièrement dans le
DBC ; 2, un script court le complète ; 3, la mécanique est à écrire.
"""

# ---------------------------------------------------------------------------
# Les icônes
# ---------------------------------------------------------------------------
# Comme les visuels, elles s'empruntent — mais le SpellIcon.dbc porte le NOM DE
# FICHIER de chacune, si bien qu'on les cherche par mot-clé plutôt qu'au jugé.
# C'est ainsi qu'on trouve « Ability_HeroicLeap », « Ability_Mount_Charger »,
# « INV_MISC_HOOK_01 » ou « inv_misc_dice_01 » : le jeu avait déjà l'icône
# exacte de la plupart de ces sorts.
#
#   8600000   3149  Ability_HeroicLeap
#   8600001   565   Ability_Warrior_Sunder
#   8600002   2006  Ability_Warrior_Rampage
#   8600003   281   Ability_Warrior_ShieldWall
#   8600010   1716  Ability_Mount_Charger
#   8600011   8052  spell_holy_holyprotection (rétroportée, gen_visuel_paladin)
#   8600012   8053  spell_holy_lastingdefense (rétroportée, gen_visuel_paladin)
#   8600013   2176  Spell_Holy_SurgeOfLight
#   8600020   1181  Ability_Mount_JungleTiger (l'icone du vrai Aspect)
#   8600021   255   Ability_Hunter_BeastTaming
#   8600022   537   Ability_Hunter_RunningShot (l'icone du vrai Tir rapide)
#   8600023   3407  Ability_Hunter_ExplosiveShot
#   8600030   30    Spell_Nature_Invisibilty (la fumée du Shunpo ; la 8050
#                    du crochet, rétroportée, reste posée dans patch-z)
#   8600031   247   Ability_Poisons
#   8600032   4175  inv_misc_dice_01
#   8600033   8051  ability_rogue_deathmark (rétroportée, gen_visuel_voleur)
#   8600034   243   Ability_BackStab
#   8600035   138   Ability_CriticalStrike
#   8600036   515   Ability_Rogue_SliceDice
#   8600037   202   Racial_Dwarf_FindTreasure
#   8600038   516   Ability_Rogue_Sprint
#   8600040   505   Spell_Magic_FeatherFall
#   8600041   548   Spell_Shadow_SiphonMana
#   8600042   3837  spell_holy_powerwordbarrier
#   8600043   1874  Spell_Holy_HolyNova
#   8600050   75    Spell_Shadow_SpectralSight
#   8600051   61    Spell_Shadow_RaiseDead
#   8600052   1614  Spell_Shadow_CallofBone
#   8600053   56    Spell_Frost_FreezingBreath
#   8600060   220   Spell_Nature_Cyclone
#   8600061   687   Spell_Nature_EarthShock
#   8600062   1930  Spell_Fire_ElementalDevastation
#   8600063   1647  INV_Spear_04 (l'icone du vrai Totem de soins)
#   8600070   1499  Spell_Arcane_Blink
#   8600071   1973  INV_Misc_Orb_01
#   8600072   45    Spell_Fire_MeteorStorm
#   8600073   285   Spell_Frost_IceStorm
#   8600080   2127  Spell_Fire_BurningSpeed
#   8600081   1932  Spell_Shadow_SeedOfDestruction
#   8600082   1500  Spell_Shadow_EnslaveDemon
#   8600083   2369  Spell_Fire_FelHellfire
#   8600090   3930  spell_druid_feralchargecat
#   8600091   2852  Ability_Druid_Berserk
#   8600092   2856  Ability_Druid_Eclipse
#   8600093   2864  Ability_Druid_Flourish (l'icone du vrai Floraison)

# ---------------------------------------------------------------------------
# Les visuels
# ---------------------------------------------------------------------------
# Le client de 3.3.5 n'a l'art d'AUCUN de ces sorts : chacun emprunte celui d'un
# sort existant, choisi pour son registre. Un premier jet en avait mis un seul
# partout — l'Infusion de puissance — parce qu'il était visible ; c'était régler
# le symptôme et non la question. La table ci-dessous dit à qui chacun emprunte.
#
#   8600000   11927  Marteau du juste, un choc au sol
#   8600001   8996  Poussée d'adrénaline (PROVISOIRE — Frappes fauchantes)
#   8600002   372    Déchirure (l'Onde de choc 10704 étourdissait, voir l'entrée)
#   8600003   3442   Blocage avec bouclier
#   8600010   2936   Lumière divine
#   8600011   30023  Zone kyriane redorée (gen_visuel_paladin) — lancer et
#                    impact empruntés à la Consécration déchaînée (165/121)
#   8600012   30025  Impact de la Bénédiction de garde-sorts, doré
#                    (gen_visuel_paladin)
#   8600013   2176  Spell_Holy_SurgeOfLight
#   8600020   1181  Ability_Mount_JungleTiger (l'icone du vrai Aspect)
#   8600021   13077  Loups spectraux
#   8600022   537   Ability_Hunter_RunningShot (l'icone du vrai Tir rapide)
#   8600023   3302   Piège explosif
#   8600030   0     Shunpo : aucun visuel de sort — fumée (kit 404 de
#                    Disparition) et invisibilité orchestrées par le script
#   8600031   8144   Empoisonner
#   8600032   30018  Dés rétroportés (gen_visuel_voleur)
#   8600033   30020  Marque rétroportée : lancer + marque d'état sur la cible
#                    (gen_visuel_voleur)
#   8600034   8996   Poussée d'adrénaline
#   8600035   8996   Poussée d'adrénaline
#   8600036   8996   Poussée d'adrénaline
#   8600037   8996   Poussée d'adrénaline
#   8600038   8996   Poussée d'adrénaline
#   8600040   194    Prière de soins
#   8600041   548   Spell_Shadow_SiphonMana
#   8600042   784    Mot de pouvoir : Bouclier
#   8600043   12006  Tempête divine, une onde radiale
#   8600050   75    Spell_Shadow_SpectralSight
#   8600051   10906  Étreinte de la mort
#   8600052   9735   Mort-et-Décrépitude
#   8600053   11684  Souffle de givre
#   8600060   311    Forme de loup fantomatique
#   8600061   10703  Onde de choc
#   8600062   1930  Spell_Fire_ElementalDevastation
#   8600063   1647  INV_Spear_04 (l'icone du vrai Totem de soins)
#   8600070   263    Déplacement
#   8600071   1973  INV_Misc_Orb_01
#   8600072   2253   Explosion pyrotechnique
#   8600073   285   Spell_Frost_IceStorm
#   8600080   2127  Spell_Fire_BurningSpeed
#   8600081   1932  Spell_Shadow_SeedOfDestruction
#   8600082   8360   Invocation de gangregarde
#   8600083   5423   Feu de l'enfer
#   8600090   4228   Forme de félin
#   8600091   2852  Ability_Druid_Berserk
#   8600092   2856  Ability_Druid_Eclipse
#   8600093   2864  Ability_Druid_Flourish (l'icone du vrai Floraison)

# --- index des tables annexes, relevés dans les DBC du serveur -------------
# Portée
P_SOI, P_5, P_8, P_10, P_20, P_25, P_30, P_35, P_40, P_100 = 1, 2, 137, 7, 3, 34, 4, 35, 5, 6
P_15 = 11    # 0-15 m (relevé SpellRange ; l'index 179 a un minimum de 5 m)
# Incantation
I_INSTANT, I_1S, I_1S5, I_2S, I_2S5 = 1, 4, 16, 5, 19
I_3S = 14           # 3000 ms (relevé SpellCastTimes)
# Durée
D_3S, D_4S, D_5S, D_6S, D_8S, D_10S, D_12S, D_15S, D_20S, D_30S = 27, 35, 28, 32, 31, 1, 29, 8, 18, 9
D_1S = 36           # 1 000 ms (relevé SpellDuration)
D_2S = 39           # 2 000 ms (relevé SpellDuration) — la chute du Séisme
D_9S = 105          # 9 000 ms (relevé SpellDuration) — la zone du Séisme
D_16S = 387         # 16 000 ms (relevé SpellDuration)
D_19S = 900019      # 19 000 ms — la vie d'une goule (2026-09-02 : 16 + 3).
                    # Entrée CUSTOM : SpellDuration.dbc n'en a aucune de
                    # 19 s, gen_visuel_dk la pose côté client et serveur.
D_45S = 22          # 45 000 ms (relevé SpellDuration) — la vie d'une porte
D_PERMANENT = 21    # base -1 (relevé SpellDuration) : l'aura tient jusqu'à
                    # ce qu'on la retire — la réserve de plumes
# Rayon
R_5, R_8, R_10, R_12, R_15, R_20, R_30 = 8, 14, 13, 32, 18, 9, 10
R_6 = 29     # 6 m (relevé SpellRadius)
R_4 = 26     # 4 m (relevé SpellRadius) — le réticule du Bond héroïque
R_DERRIERE = 7      # le « derrière la cible » de Pas de l'ombre (relevé 36563)
R_2 = 7             # 2 m (relevé SpellRadius) — le même index, autre usage :
                    # le réticule de la Plume angélique
R_7 = 37            # 7 m (relevé SpellRadius) — la zone du Séisme
R_9 = 40            # 9 m (relevé SpellRadius) — le dôme de la Barrière

# --- effets et auras --------------------------------------------------------
E_DEGATS, E_DUMMY, E_AURA, E_SOIN, E_SUMMON = 2, 3, 6, 10, 28
E_ENERGIE, E_SAUT, E_TRIGGER, E_SCRIPT = 30, 42, 64, 77
E_TELEPORT = 5      # TELEPORT_UNITS — le cœur de Pas de l'ombre (36563)
# L'effet 27 pose au sol un objet dynamique qui applique une aura périodique à
# qui s'y trouve : c'est la Consécration, la Pluie de feu — et tout ce qu'il
# fallait pour nos zones. Il évite d'écrire à la main ce que le cœur sait faire.
E_ZONE = 27
A_PERIODIQUE, A_DUMMY, A_SOIN_PERIODIQUE, A_ETOURDI = 3, 4, 8, 12
A_SOIN_PCT_PERIODIQUE = 20   # OBS_MOD_HEALTH : soigne $s1 % des PV MAX
A_DEGATS_SUBIS_PCT = 87      # MOD_DAMAGE_PERCENT_TAKEN : valeur negative
A_VITESSE, A_ABSORPTION, A_DEGATS_PCT, A_RESISTANCE_PCT = 31, 69, 79, 101
A_PROC_DECLENCHE = 42   # PROC_TRIGGER_SPELL : l'aura lance EffectTriggerSpell
                        # quand son porteur remplit les ProcTypeMask
A_PERIODIQUE_FACTICE = 226   # PERIODIC_DUMMY : l'aura bat, le script décide
                             # de ce qui se passe à chaque battement
A_PERIODIQUE_DECLENCHE = 23  # PERIODIC_TRIGGER_SPELL : l'aura lance
                             # EffectTriggerSpell à CHAQUE tic
# 53 draine la cible ET soigne le lanceur ; 87 majore les dégâts qu'elle subit.
A_DRAIN, A_DEGATS_SUBIS, A_DECLENCHEUR = 53, 87, 23
# DAMAGE_SHIELD : le renvoi natif des Épines et de l'Aura de vengeance. Le cœur
# le règle seul dans Unit::DealMeleeDamage — aucun script n'est nécessaire pour
# la partie « renvoie des dégâts ». Valeurs natives au niveau 80, pour situer :
# Épines rang 8 = 73 par coup, Aura de vengeance rang 7 = 112, toutes deux
# PERMANENTES.
A_RENVOI = 15
# Monter ne se dit pas avec une aura de vitesse : il faut l'aura 78, dont le
# EffectMiscValue porte l'ENTREE DE CREATURE de la monture, et l'aura 32 pour la
# vitesse — celle de la vitesse à pied ne s'applique pas à un cavalier. Relevé
# sur les quarante montures du Spell.dbc, qui suivent toutes ce motif.
A_MONTURE, A_VITESSE_MONTE = 78, 32
A_CRITIQUE, A_HATE_MELEE, A_REGEN_RESSOURCE = 52, 138, 110
A_HATE_SORT = 65     # MOD_CASTING_SPEED_NOT_STACK : vitesse d'incantation
A_CRITIQUE_SORT = 57 # MOD_SPELL_CRIT_CHANCE : critique des SORTS
A_MANA_PCT_PERIODIQUE = 21   # OBS_MOD_POWER : rend $s1 % du mana MAX
# LES FAMILLES DE SORTS, pour les modificateurs cibles. Un modificateur
# n'agit que sur les sorts de la famille et du masque indiques.
FAMILLE_DEMONISTE = 5
# Feu de l'ame 0x80 et Trait du Chaos 0x20000, tous rangs, y compris
# les rangs de rune du chantier (8511231+ et 8511291+) qui portent le
# meme masque. Releve le 2026-09-03 dans Spell.dbc.
MASQUE_FEU_AME = 0x80
MASQUE_TRAIT_CHAOS = 0x20000
MASQUE_IMMOLATION = 0x4
A_MODIF_PLAT = 107   # ADD_FLAT_MODIFIER : idem, en valeur absolue
MODIF_CRITIQUE = 7   # SPELLMOD_CRITICAL_CHANCE
A_MODIF_PCT = 108    # ADD_PCT_MODIFIER : modifie un sort D'UNE FAMILLE
                     # de $s1 %, l'operation etant portee par misc.
MODIF_INCANTATION = 10   # SPELLMOD_CASTING_TIME : -100 % = instantane
A_MENACE = 10        # MOD_THREAT : menace generee, en pourcentage
A_ECHELLE = 61       # MOD_SCALE : la taille du modele
# Majore les dégâts que la cible reçoit DU SEUL LANCEUR : le cœur filtre
# par GUID dans Unit.cpp. Deux voleurs posent donc deux auras distinctes,
# chacune ne servant que son propre porteur — ce n'est pas un cumul.
A_DEGATS_DU_LANCEUR = 271
DESTRIER_ASPECT = 14584   # l'apparence du « Charger », posée par le script
GARDIEN = 803800          # notre propre PNJ : voir gen_gardien.py

# --- cibles -----------------------------------------------------------------
C_SOI, C_ENNEMI, C_ZONE_ENNEMIS, C_POINT_SOI = 1, 6, 15, 18
C_ALLIE = 21    # TARGET_UNIT_TARGET_ALLY : l'allie EXPLICITEMENT vise.
C_SOURCE = 22   # TARGET_SRC_CASTER : la POSITION du lanceur, d'ou
                # partent les zones centrees sur lui (cibleB = 15).
                # C_SOI (TARGET_UNIT_CASTER) pose l'aura sur le LANCEUR
                # quoi qu'on passe a CastSpell — releve en jeu le
                # 2026-09-03 : les bonus du tyran atterrissaient sur
                # lui au lieu du demon.
C_GROUPE, C_ALLIE, C_ZONE_ALLIES, C_POINT, C_CONE = 20, 21, 30, 87, 104
C_DEST_DERRIERE = 65    # destination DERRIÈRE la cible (Pas de l'ombre, 36563)
C_DEST_CIBLE = 63       # destination SUR la cible, sans décalage — 63 dans
                        # la table de ce cœur (76 n'y est PAS câblée : «
                        # does not have destination », constaté 2026-08-30)
# Le cône de C_CONE ramasse les ENNEMIS : y poser un soin soigne l'adversaire.
# Un soin en cône veut celui-ci, et lui seul.
C_CONE_ALLIES = 59
# Les conventions de zone, relevées sur les sorts Blizzard plutôt que devinées :
# un sort VISÉ AU SOL met ses dégâts en 16 (unités au point visé) et sa zone
# persistante en 28 ; une NOVA autour de soi s'écrit 22/15 (Coup de tonnerre),
# 22/30 pour les alliés. Le familier est la cible 5.
C_ZONE_VISEE, C_ZONE_POSEE, C_SRC, C_FAMILIER = 16, 28, 22, 5
C_ZONE_ALLIES_VISEE = 31   # TARGET_UNIT_DEST_AREA_ALLY : le pendant allié du
                           # 16 — les alliés autour du POINT visé, et non
                           # autour du lanceur (relevé SharedDefines.h)
# Le réticule au sol : sans ce drapeau dans le champ Targets, le client ne
# demande jamais de position et la zone tombe aux pieds du lanceur — c'est le
# défaut qui a traversé tous les premiers tests au corps à corps.
VISE_AU_SOL = 0x40
# Une canalisation, telle que Flèches des arcanes et Fouet mental l'écrivent.
CANAL_ATTREX, CANAL_INTERRUPT, CANAL_FLAGS = 0x4, 0xF, 0x7C0C
# La canalisation QUI LAISSE AGIR (2026-09-02) : les mêmes drapeaux moins
# MOVE (0x8), MELEE_ATTACK (0x1000) et SPELL_ATTACK (0x2000) — le porteur
# marche et frappe sans rompre le fil. Restent CAST, TALK et USE : lancer un
# autre sort, parler à un PNJ ou fouiller un objet coupe toujours.
CANAL_FLAGS_LIBRE = 0x4C04
A_IMMUNITE_MECANIQUE = 77
MECANIQUE_ENTRAVE = 11

# --- écoles -----------------------------------------------------------------
PHYSIQUE, SACRE, FEU, NATURE, GIVRE, OMBRE, ARCANES = 1, 2, 4, 8, 16, 32, 64
# Une aura de majoration des dégâts lit son EffectMiscValue comme un masque
# d'écoles. À zéro elle ne majore RIEN : elle s'applique, s'affiche, et ne fait
# rien du tout. C'est le piège de SPELL_AURA_MOD_DAMAGE_PERCENT_DONE.
TOUTES_ECOLES = 127

# --- types de ressource -----------------------------------------------------
MANA, RAGE, FOCUS, ENERGIE, PUISSANCE_RUNIQUE = 0, 1, 2, 3, 6


# Sans cet attribut, le client range l'aura parmi les BIENFAITS, même quand elle
# ronge sa cible : c'est lui, et non le signe de la valeur, qui décide du cadre.
ATTR_MALUS = 0x04000000
# SPELL_ATTR0_CANT_CANCEL : le joueur ne peut pas retirer l'aura au clic droit.
# Pour les auras qui PORTENT UN ÉTAT du serveur (la jauge céleste) : les
# retirer désynchroniserait la barre du client d'avec la jauge en mémoire.
ATTR_SANS_ANNULATION = 0x80000000
# SPELL_ATTR4_NOT_STEALABLE (AttributesEx4) : hors de portée du Vol de sort.
ATTR4_INVOLABLE = 0x00000100
# Le client RANGE l'arme au lancement d'un sort ordinaire (constaté sur le
# Bond héroïque le 2026-08-30, la garde Ready2H jouait à vide). Le bit 0x20
# (« do not sheath » des nomenclatures modernes) NE SUFFIT PAS : le relevé
# des quatre natifs qui gardent l'arme en main (Charge 100, Interception
# 20252, Jet héroïque 57755, Coup de tonnerre 6343) donne le masque commun
# 0x10 + 0x40000 — c'est LUI qui fait foi.
ATTR_CAPACITE = 0x10             # « Ability »
ATTR_FOURREAU_INTACT = 0x40000   # « Dont affect sheath state »
# AttributesEx2 : 0x20000 = « ne remet pas les compteurs de combat à zéro ».
# C'est LUI qui laisse les attaques automatiques suivre leur cours pendant
# une incantation — le cœur suspend le compteur au lieu de le réarmer
# (relevé Unit.cpp/Spell.cpp, 2026-09-02).
ATTR2_ATTAQUE_INTACTE = 0x20000
# (FRAPPER PENDANT L'INCANTATION ne se dit par AUCUN champ du DBC : c'est
# une ligne du cœur, PlayerUpdates.cpp, qui l'interdit. Un correctif local y
# nomme les sorts concernés — le bit libre 0x8000 d'AttributesEx2, essayé le
# 2026-09-02, est REFUSÉ PAR LE CLIENT : « le sort n'est pas utilisable ».)


# `parent` : l'identifiant du sort QUE LE JOUEUR LANCE, pour un porteur qui
# n'a pas de recharge à lui — écho, onde, zone posée par un script. Le
# barème de puissance lui fait alors prendre la recharge du parent : sans
# cela il recevrait la prime la plus basse tout en portant les dégâts d'un
# sort à soixante secondes.
#
# `part` : la fraction de la valeur du parent qui revient à CE porteur,
# quand plusieurs se la partagent. Le Halo lance deux ondes : chacune en
# prend la moitié, sinon le joueur reçoit deux fois le compte.
def sort(id, classe, spec, en, fr, desc_en, desc_fr, icone, visuel, palier,
         ecole=PHYSIQUE, cast=I_INSTANT, portee=P_SOI, recharge=0,
         duree=0, ressource=None, cout=0, cout_pct=0, effets=(), script=None,
         pile=0,
         aura_en="", aura_fr="", attributs=None, cible_sol=False, canal=False,
         vitesse=0, attributs_ex=0, attributs_ex2=0, attributs_ex3=0,
         attributs_ex4=0, attributs_ex6=0,
         interrompu=None,
         canal_flags=None,
         proc_flags=0, famille=0, famille_masque=(0, 0, 0),
         classe_degats=0, blocage=0, arme=(-1, 0), mecanique=0,
         charges=0, reactif=(0, 0), formes=0, grimoire=None,
         aura_requise=0, parent=0, part=1.0):
    effets = list(effets)
    if attributs is None:
        # Une aura posée sur un ennemi est un malus : on le déduit des cibles
        # plutôt que de le saisir sort par sort et d'en oublier.
        hostile = any(e["aura"] and e["cible"] in (C_ENNEMI, C_ZONE_ENNEMIS, C_CONE)
                      for e in effets)
        attributs = ATTR_MALUS if hostile else 0
    return dict(id=id, classe=classe, spec=spec, en=en, fr=fr,
                desc_en=desc_en, desc_fr=desc_fr, icone=icone, visuel=visuel,
                palier=palier, ecole=ecole, cast=cast, portee=portee,
                recharge=recharge, duree=duree, ressource=ressource, cout=cout,
                cout_pct=cout_pct, effets=effets, script=script, pile=pile,
                aura_en=aura_en, aura_fr=aura_fr, attributs=attributs,
                cible_sol=cible_sol, canal=canal, vitesse=vitesse,
                attributs_ex=attributs_ex, attributs_ex2=attributs_ex2,
                attributs_ex3=attributs_ex3, attributs_ex4=attributs_ex4,
                attributs_ex6=attributs_ex6,
                interrompu=interrompu,
                canal_flags=canal_flags, proc_flags=proc_flags,
                famille=famille, famille_masque=famille_masque,
                classe_degats=classe_degats, blocage=blocage, arme=arme,
                mecanique=mecanique, charges=charges, reactif=reactif,
                formes=formes, grimoire=grimoire,
                aura_requise=aura_requise, parent=parent, part=part)


# LES AURAS AUXILIAIRES (2026-09-03). Le schema 86000CS donne DIX identifiants
# a chaque classe, ce qui suffit aux sorts VISIBLES mais pas aux auras que les
# scripts posent en coulisse : le tyran demoniaque en demande neuf a lui seul.
# Elles vivent donc dans une plage a part, effacee et reecrite en entier comme
# celle des sorts de classe, et exclue du grimoire par gen_sla_classes.
# Les DEUX plages du chantier, decrites la ou vivent les sorts plutot que
# dans le generateur : c'est ici qu'on ajoute un sort, donc ici qu'on doit
# lire quelle plage il occupe.
# LES FORMES, en masque de bits : 1 << (forme - 1), les valeurs de forme
# venant de UnitDefines.h. `ShapeshiftMask` a zero = toutes les formes ; pour
# exiger l'ABSENCE de forme, c'est l'attribut ATTR_HORS_FORME qu'il faut.
FORME_FELIN = 1 << (0x01 - 1)
FORME_ARBRE = 1 << (0x02 - 1)
FORME_VOYAGE = 1 << (0x03 - 1)
FORME_OURS = (1 << (0x05 - 1)) | (1 << (0x08 - 1))   # ours et ours redoutable
FORME_SELENIEN = 1 << (0x1F - 1)
ATTR_HORS_FORME = 0x00010000    # SPELL_ATTR0_NOT_SHAPESHIFTED

# SPELL_ATTR1_ALLOW_WHILE_STEALTHED : « ne rompt pas le camouflage ». Sans
# lui, tout lancement sort le druide de sa Traque.
ATTR1_GARDE_CAMOUFLAGE = 0x00000020

# SPELL_ATTR3_CAN_PROC_FROM_PROCS : l'aura peut aussi être consommée par une
# capacité déclenchée par une autre. Relevé sur Sang-froid (14177).
ATTR3_PROC_DES_PROCS = 0x04000000

# LE MASQUE DE PROC DE SANG-FROID, relevé tel quel sur 14177 : tous les
# « fait par une capacité » — mêlée 0x10, tir 0x40, capacité à distance 0x100,
# sort sans classe de dégâts 0x400 et 0x1000, sort magique 0x4000 et 0x10000 —
# et surtout PAS le 0x4 de l'attaque automatique, qui emporterait la charge
# avant la compétence.
PROCS_COMPETENCE = 87376

FAMILLE_DRUIDE = 7      # SPELLFAMILY_DRUID

# UN MODIFICATEUR SANS MASQUE VISE TOUTE LA FAMILLE. Releve dans le coeur le
# 2026-09-04 : SpellInfo::IsAffected rend vrai des que le masque du
# modificateur est nul, et ce masque vient de Effects[i].SpellClassMask —
# c'est-a-dire des colonnes EffectSpellClassMask*, que ce generateur n'ecrit
# pas. Le champ `famille_masque` remplit SpellClassMask_1..3, qui sont les
# drapeaux de famille DU SORT LUI-MEME, pas la cible du modificateur : le
# poser ici ne restreindrait rien et ferait seulement reclamer a notre aura
# des bits de famille qui ne sont pas les siens.

# SPELL_ATTR6_CAN_ASSIST_IMMUNE_PC. Sans lui, aucun sort d'entraide n'atteint
# un PNJ : _IsValidAssistTarget refuse tout ce qui porte UNIT_FLAG_IMMUNE_TO_PC
# ou UNIT_FLAG_NON_ATTACKABLE, drapeaux que porte la quasi-totalite des PNJ
# amicaux (donneurs de quete, gardes, marchands). C'est ce bit, et lui seul,
# qui leve les deux refus d'un coup.
ATTR6_ASSISTE_IMMUNISES = 0x00000008

# LA FAMILLE DE SORTS de chaque classe (SPELLFAMILY_*). Sans elle, les talents
# qui ciblent une famille ne voient pas nos sorts : une Boule de feu améliorée
# par un talent de Feu ne profitait pas au Météore.
FAMILLES = {
    "warrior": 4, "paladin": 10, "hunter": 9, "rogue": 8, "priest": 6,
    "deathknight": 15, "shaman": 11, "mage": 3, "warlock": 5, "druid": 7,
}

# LES SORTS QUI NE S'APPRENNENT PAS : ni onglet de grimoire, ni temps de
# recharge global. Ce sont les porteurs de visuel, les échos et les bienfaits
# que les scripts posent. (Cette liste vivait dans gen_sla_classes ; elle est
# remontée ici, où gen_sorts_classes en a besoin aussi.)
SANS_ONGLET = {8600034, 8600035, 8600036, 8600037, 8600038, 8600039, 8600054,
               8600055, 8600057, 8600058, 8600059, 8600094, 8600095, 8600096,
               8600097, 8600098, 8600099,
               8600044, 8600045,          # les deux ondes du Halo
               8600048,                   # la levée d'une goule
               8600068,                   # la chute du Séisme
               8600064, 8600069}          # les auras du Lien d'esprit (chaman), auxiliaires

# LES SORTS APPRIS QUI ÉCHAPPENT AU TEMPS DE RECHARGE GLOBAL — ils ne le
# déclenchent pas ET ne s'y soumettent pas. Les deux vont ensemble : le cœur
# lit `StartRecoveryTime` pour savoir ce que le sort IMPOSE et
# `StartRecoveryCategory` pour savoir ce qu'il SUBIT (Spell::HasGlobalCooldown).
# Les mettre tous deux à zéro affranchit dans les deux sens.
#
# À n'employer que sur des sorts qui ne doivent rien coûter au rythme de
# combat : le Retour stellaire est un déplacement, il doit pouvoir s'intercaler
# entre deux sorts sans en manger un (2026-09-04).
SANS_GCD = {8610020}               # Retour stellaire

PLAGE_CLASSES = (8600000, 8600099)     # 86000CS : dix ids par classe
PLAGE_AUXILIAIRE = (8610000, 8610099)


def auxiliaire(ident):
    """Vrai si `ident` est une aura auxiliaire, jamais apprise ni affichee."""
    return PLAGE_AUXILIAIRE[0] <= ident <= PLAGE_AUXILIAIRE[1]


def eff(effet, cible=C_SOI, points=0, aura=0, rayon=0, cibleB=0, periode=0,
        misc=0, miscB=0, declenche=0, des=0, mecanique=0, masque=(0, 0, 0)):
    """Un effet du sort. `points` est la valeur affichée par $s1 : on écrit
    N - 1 dans BasePoints et 1 dans DieSides, le client additionnant les deux.
    `des` (dés) ouvre une FOURCHETTE : min = points, max = points - 1 + des
    ($m1/$M1 dans l'infobulle). `miscB` porte le second champ misc — pour une
    invocation, l'entrée de SummonProperties qui décide du GENRE de créature
    invoquée (gardien, familier, totem…).

    `masque` porte la CIBLE d'un modificateur de sort : les trois mots de
    EffectSpellClassMask, qui disent QUELS sorts de la famille le modificateur
    touche. À ne pas confondre avec `famille_masque`, qui déclare les drapeaux
    de famille DU SORT LUI-MÊME — ce par quoi les talents Blizzard l'attrapent.
    Un masque de modificateur NUL vaut « toute la famille »."""
    return dict(effet=effet, cible=cible, points=points, aura=aura, rayon=rayon,
                cibleB=cibleB, periode=periode, misc=misc, miscB=miscB,
                declenche=declenche, des=des, mecanique=mecanique,
                masque=masque)


# ---------------------------------------------------------------------------
# Les sorts
# ---------------------------------------------------------------------------
SORTS = [

    # ---------------------------------------------------------- guerrier ---
    sort(8600000, "warrior", "mobilité", "Heroic Leap", "Bond héroïque",
         "Leap to the targeted spot, dealing $s2 damage on landing.",
         "Bondit à l'endroit ciblé et inflige $s2 points de dégâts à l'atterrissage.",
         # E_SAUT -> E_DUMMY (2026-08-30, bogue « ne fait rien » : le
         # EffectJumpDest PAR DÉFAUT re-sautait sur place par-dessus le
         # script — le patron du Shunpo vaut pour les trois anciens sorts
         # directionnels). Puis refonte du même jour : le bond du guerrier
         # devient un saut CIBLÉ (réticule au sol, 20 m — script
         # bond_heroique dédié) ; Bourrasque (8600060) et Miroitement
         # (8600070) restent DIRECTIONNELS sur bond_directionnel. Les
         # dégâts frappent la zone visée À L'APPLICATION (le vol dure
         # ~0,9 s à 20 m) — signalé, sémantique conservée de l'ancien bond.
         # Réglages utilisateur du 2026-08-30 : portée 35 m. LE RÉTICULE LIT
         # LE RAYON DE L'EFFET DE DÉGÂTS (prouvé par bissection : deux
         # réductions du rayon du dummy — 6 puis 4 m — sans aucun effet sur
         # le curseur) : réticule et zone frappée sont COUPLÉS. Les deux
         # passent à 6 m — le réticule montre exactement ce que le sort
         # frappe.
         # Visuel 11927 (Marteau du juste) remplacé par 30028 le 2026-08-30 :
         # son kit de LANCER jouait l'anim d'incantation instantanée avec
         # l'éclat sacré sur les mains, par-dessus la pose READY2H du script.
         # Le 30028 (gen_visuel_guerrier) ne garde que l'impact natif 11014
         # sur les victimes — lancer, précast et missile supprimés.
         icone=3149, visuel=30028, palier=2, portee=P_35, recharge=45000,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT, cible_sol=True,
         effets=[eff(E_DUMMY, C_POINT),
                 eff(E_DEGATS, C_ZONE_VISEE, 450, rayon=R_6)],
         script="spell_papota_bond_heroique"),
    # REMPLACÉ le 2026-08-30 (Fracasse-colosse jugé « pas fun ») par le choix
    # utilisateur parmi trois propositions : Frappes fauchantes, avec sa
    # variante — sans cible secondaire à portée, la cible unique est frappée
    # DEUX fois. L'aura porte les drapeaux de proc mêlée (ProcTypeMask 0x14 :
    # autos 0x4 + techniques 0x10) ; le script rejoue les dégâts RÉELS du
    # coup via l'écho 8600055. Coût et recharge du slot conservés (20 rage,
    # 20 s). Icône (565) et visuel (8996) PROVISOIRES — décision en attente.
    # Réglages utilisateur du 2026-08-30 : tiret retiré du tooltip, durée
    # affichée ($d), 12 s, recharge 60 s. (Le « buff appliqué à la cible en
    # débuff » observé venait de l'ANCIEN Fracasse-colosse résident côté
    # serveur — données désynchronisées ; la ligne générée cible bien le
    # lanceur, vérifiée au différentiel.)
    sort(8600001, "warrior", "Armes", "Sweeping Strikes", "Frappes fauchantes",
         "For $d, each melee strike also hits a second nearby enemy, or "
         "the same target again if none is in reach.",
         "Pendant $d, chaque coup de mêlée frappe aussi un second ennemi "
         "proche, ou la même cible une seconde fois s'il n'y en a pas.",
         aura_en="Melee strikes hit an additional target.",
         aura_fr="Les coups de mêlée frappent une cible supplémentaire.",
         icone=565, visuel=8996, palier=3, portee=P_SOI, recharge=60000,
         duree=D_12S, ressource=RAGE, cout=200, proc_flags=0x14,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)],
         script="spell_papota_frappes_fauchantes"),
    # « Fureur d'Odyn » renommée « Empalement » (2026-08-30) — le débuff
    # (le dot, effet 2 du même sort) porte le même nom par construction.
    sort(8600002, "warrior", "Fureur", "Impalement", "Empalement",
         "Strikes all enemies in front of you for $s1, leaving them bleeding "
         "for $s2 damage per second for $d.",
         "Frappe tous les ennemis devant vous pour $s1 points et les laisse "
         "en sang : $s2 points de dégâts par seconde pendant $d.",
         # Le débuff sur la cible ne mentionne QUE le saignement (demande du
         # 2026-08-30) — sans texte d'aura, la barre affichait toute la
         # description du sort.
         # Libellé arrêté par l'utilisateur le 2026-08-30 (« Saigne. X dégâts
         # subit par secondes. ») — accords rétablis : subis, seconde.
         aura_en="Bleeding. $s2 damage taken per second.",
         aura_fr="Saigne. $s2 dégâts subis par seconde.",
         # Visuel 10704 (Onde de choc) remplacé par 372 (Déchirure) le
         # 2026-08-30 : l'Onde de choc est un ÉTOURDISSEMENT — son kit
         # d'état jouait l'anim de sonné sur les cibles pendant toute
         # l'aura, « bloque toutes les animations » constaté en jeu. La
         # Déchirure est le saignement canonique, état bénin prouvé. Puis
         # rétroport du même jour (gen_visuel_guerrier) : visuel 30031 =
         # cône sethrak + son au lancer (anim et impact sanglant du 372
         # conservés), icône achievement_boss_odyn (8054).
         icone=8054, visuel=30031, palier=2, portee=P_8, recharge=45000, duree=D_12S,
         ressource=RAGE, cout=300,
         effets=[eff(E_DEGATS, C_CONE, 700, rayon=R_8),
                 eff(E_AURA, C_CONE, 120, aura=A_PERIODIQUE, rayon=R_8, periode=1000)]),
    # Le cône visuel est ANCRÉ AU SOL par le mécanisme NATIF de l'Onde de
    # choc (2026-08-30) : effet monde au champ 14 du kit de lancer — aucun
    # script (la tentative par dummy-socle est retirée).
    # Refonte du 2026-08-30 : durée 6 -> 12 s, majoration 4 -> 6 points par
    # dixième de rage, et la majoration SCALE sur le score de blocage (ratio
    # sentinelle 0.1234 en attendant l'équilibrage — script).
    # « Barrière de bouclier » renommée « Bouclier Spartiate » (2026-08-30).
    sort(8600003, "warrior", "Protection", "Spartan Shield", "Bouclier Spartiate",
         "Raises a barrier absorbing $s1 damage, larger for each point of "
         "rage spent, your block value and your armor.",
         "Dresse une barrière absorbant $s1 points de dégâts, d'autant plus "
         "vaste que la rage dépensée, votre score de blocage et votre armure "
         "sont grands.",
         # SCHOOL_ABSORB exige le MASQUE D'ÉCOLES en MiscValue : sans lui,
         # l'aura s'affiche et n'absorbe RIEN (bogue constaté en jeu le
         # 2026-08-30 — le sort n'avait jamais été revu).
         icone=281, visuel=3442, palier=2, portee=P_SOI, recharge=6000, duree=D_12S,
         ressource=RAGE, cout=200,
         effets=[eff(E_AURA, C_SOI, 800, aura=A_ABSORPTION, misc=TOUTES_ECOLES)],
         script="spell_papota_barriere_bouclier"),

    # ----------------------------------------------------------- paladin ---
    sort(8600010, "paladin", "mobilité", "Divine Steed", "Destrier divin",
         "You move $s1% faster for $d, astride a divine steed.",
         "Vous vous déplacez $s1% plus vite pendant $d, en selle sur un destrier divin.",
         aura_en="Riding a divine steed.", aura_fr="En selle sur un destrier divin.",
         icone=1716, visuel=2936, palier=2, ecole=SACRE, portee=P_SOI, recharge=45000, duree=D_3S,
         effets=[eff(E_AURA, C_SOI, 100, aura=A_VITESSE)],
         script="spell_papota_destrier_divin"),
    # Le visuel doit être une NAPPE, pas un pilier — la Lumière stellaire de
    # Freya, essayée d'abord, projette un faisceau — et il doit être taillé pour
    # le rayon du sort, faute de quoi le cercle ment sur la zone. L'emprunt à la
    # Consécration déchaînée (11182) est REMPLACÉ le 2026-08-30 par le
    # RÉTROPORT fourni par l'utilisateur : visuel 30023 (gen_visuel_paladin) —
    # zone kyriane REDORÉE (bleu -> or, dore_textures.py), échelle calée sur
    # les 8 m du sort, lancer/impact/missile de la déchaînée conservés, son
    # d'impact au lancement et NAPPE bouclée tant que la zone vit (kit de
    # zone persistante, champ 25 du SpellVisual — relevé sur la
    # Consécration). Icône moderne 8052 (spell_holy_holyprotection).
    sort(8600011, "paladin", "Vindicte", "Final Reckoning", "Jugement dernier",
         "Smites the ground for $s1 damage and marks it: enemies there take "
         "$s2% more damage for $d.",
         "Frappe le sol pour $s1 points de dégâts et le marque : les ennemis qui "
         "s'y trouvent subissent $s2% de dégâts supplémentaires pendant $d.",
         aura_en="Taking $s2% more damage.",
         aura_fr="Subit $s2% de dégâts supplémentaires.",
         icone=8052, visuel=30023, palier=3, ecole=SACRE, portee=P_30, recharge=60000, duree=D_8S,
         ressource=MANA, cout=500,
         cible_sol=True,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 500, rayon=R_8),
                 eff(E_ZONE, C_ZONE_POSEE, 15, aura=A_DEGATS_SUBIS, rayon=R_8,
                     periode=1000, misc=TOUTES_ECOLES)],
         attributs=ATTR_MALUS),
    # L'Œil de Tyr faisait double emploi avec le Jugement dernier — deux zones de
    # dégâts assorties d'un malus. Une branche de tank mérite un autre axe : le
    # Gardien est la SEULE défensive personnelle des quarante sorts.
    # REFONTE du 2026-08-30 (le PNJ Gardien — script, IA, créature 803800 —
    # avait été retiré le même jour) : le sort devient le « Bouclier de
    # l'Inquisition ». Réduction de dégâts RAMENÉE de 50 à 30 % (annoncée
    # par $s1 dans l'infobulle), visuel rétroporté 30025 — l'impact de la
    # Bénédiction de garde-sorts, trois textures dorées et renommées _dore
    # (prepare_bouclier.py) — avec le son d'impact du Bouclier du vertueux
    # au lancement ; icône moderne 8053 (spell_holy_lastingdefense).
    sort(8600012, "paladin", "Protection", "Shield of the Inquisition",
         "Bouclier de l'Inquisition",
         "You take $s1% less damage for $d.",
         "Vous subissez $s1% de dégâts en moins pendant $d.",
         aura_en="Taking $s1% less damage.",
         aura_fr="Subit $s1% de dégâts en moins.",
         icone=8053, visuel=30025, palier=2, ecole=SACRE, portee=P_SOI,
         recharge=180000, duree=D_12S,
         effets=[eff(E_AURA, C_SOI, -30, aura=A_DEGATS_SUBIS, misc=TOUTES_ECOLES)]),
    sort(8600013, "paladin", "Sacré", "Light of Dawn", "Lumière de l'aube",
         "A wave of light heals allies in front of you for $s1.",
         "Une vague de lumière soigne les alliés devant vous de $s1 points.",
         aura_en="", aura_fr="",
         # Le VRAI visuel du sort, rétroporté du client moderne : le cône doré
         # part du lanceur, l'impact de soin fleurit sur chaque allié touché.
         # Monté par gen_visuel_aube.py — modèles dans spells\, chaîne
         # SpellVisual 30014 -> kits 30014/30015 -> effets 8200206/8200207.
         icone=2176, visuel=30014, palier=2, ecole=SACRE, portee=P_10,
         recharge=12000, ressource=MANA, cout=600,
         effets=[eff(E_SOIN, C_CONE_ALLIES, 900, rayon=R_15)]),

    # ---------------------------------------------------------- chasseur ---
    # Renommé « Aspect du jaguar » le 2026-08-31.
    sort(8600020, "hunter", "mobilité", "Aspect of the Jaguar", "Aspect du jaguar",
         "You and nearby allies gain $s1% speed for $d.",
         "Vous et vos alliés proches gagnez $s1% de vitesse pendant $d.",
         # Réglages du 2026-08-31 : +150 % pendant 3 s (était +30 % / 8 s).
         icone=1181, visuel=3719, palier=1, ecole=NATURE, portee=P_SOI, recharge=60000, duree=D_3S,
         effets=[eff(E_AURA, C_GROUPE, 150, aura=A_VITESSE, rayon=R_15)]),
    sort(8600021, "hunter", "Maîtrise des bêtes", "Stampede", "Ruée sauvage",
         "Your stable erupts: all your beasts charge for $d.",
         "Toute votre écurie surgit et charge pendant $d.",
         # Réglages du 2026-08-31 : les bêtes surgissent AUTOUR DE LA CIBLE
         # (elles apparaissaient autour du chasseur) et tiennent 30 s.
         icone=255, visuel=13077, palier=3, ecole=NATURE, portee=P_40, recharge=120000, duree=D_30S,
         ressource=FOCUS, cout=0,
         effets=[eff(E_DUMMY, C_ENNEMI)],
         script="spell_papota_ruee_sauvage"),
    # Renommé « Tirs consécutifs » le 2026-08-31.
    sort(8600022, "hunter", "Précision", "Consecutive Shots", "Tirs consécutifs",
         # L'infobulle lit les dégâts DU TIR DÉCLENCHÉ (jetons inter-sorts,
         # le procédé du 28884 natif) : le sort porteur n'en inflige plus
         # lui-même, il affichait donc « 0 à 1 » (2026-08-31). Elle décrit
         # aussi la mécanique des traits fichés et de leur détonation, en
         # français courant (demande du jour) — sans nombre de traits ni
         # montant par trait, que le client ne sait pas calculer.
         # Texte ARRÊTÉ PAR L'UTILISATEUR le 2026-08-31, à la lettre. Les
         # durées et la portée sont lues dans les sorts concernés ($d = 3 s,
         # $8600096d = 8 s, $8600098a1 = 8 m) ; le « 6 secondes » est écrit
         # EN DUR car il ne correspond à aucune valeur du sort — l'explosion
         # tombe 8 s après la dernière salve. Écart signalé à l'utilisateur.
         "Channel a volley of piercing shots for $d. Each shot lodges in "
         "the target for $8600096d. The target explodes after 6 seconds, "
         "dealing damage based on the number of shafts to all foes within "
         "$8600098a1 yards.",
         "Canalise une volée de traits perforants pendant $d. Chaque tir se "
         "loge dans la cible pendant $8600096d. La cible explose après 6 "
         "secondes et inflige des dégâts selon le nombre de traits aux "
         "ennemis dans un rayon de $8600098a1 mètres.",
         # L'ANIMATION DE TIR (2026-08-31) : elle ne vient pas d'un kit —
         # tous les tirs natifs (Volée 42243, Tir des arcanes 3044, Tir
         # automatique 75) portent le bit 0x2 des Attributes
         # (SPELL_ATTR0_USES_RANGED_SLOT) et la classe de dégâts 3
         # (distance), et exigent une arme à distance (classe 2,
         # sous-classes 0x4000C = arcs, fusils, arbalètes). C'est cela qui
         # fait lever l'arme au personnage.
         # Icône moderne ability_hunter_blindingshot (8060, gen_visuel_
         # chasseur), exportée le 2026-08-31.
         icone=8060, visuel=567, palier=2, portee=P_40, recharge=20000, duree=D_3S,
         ressource=FOCUS, cout=0, canal=True,
         # Le personnage TIRE À CHAQUE SALVE (2026-08-31) : une aura de
         # dégâts ne se lance qu'UNE fois, donc une seule animation. Le
         # design natif (Tir des arcanes 3044 : vitesse 40, missile, attribut
         # d'arme à distance) joue l'animation AU LANCEMENT — on lance donc
         # un vrai tir à chaque tic, via PERIODIC_TRIGGER_SPELL vers le
         # 8600096. (L'emote rejouée à la main, essayée d'abord, supprimait
         # l'animation au lieu de la répéter.) Le sort porteur ne fait plus
         # de dégâts lui-même : ils vivent dans le tir déclenché.
         # Le bit 0x2 (emplacement d'arme à distance) est RETIRÉ du porteur
         # le 2026-08-31 : il faisait traiter le lancement comme un tir et
         # la BARRE DE CANALISATION ne s'affichait pas. Il vit désormais
         # uniquement sur la salve 8600096, qui en a l'usage. Le porteur
         # garde l'exigence d'arme à distance et reste une canalisation pure.
         attributs=ATTR_MALUS, arme=(2, 0x4000C),
         effets=[eff(E_AURA, C_ENNEMI, 0, aura=A_PERIODIQUE_DECLENCHE,
                     periode=500, declenche=8600096)],
         script="spell_papota_tirs_consecutifs"),
    sort(8600023, "hunter", "Survie", "Wildfire Bomb", "Bombe incendiaire",
         "Hurls a bomb, dealing $s1 damage and setting the ground alight for $d.",
         "Lance une bombe infligeant $s1 points de dégâts et embrasant le sol pendant $d.",
         # Refonte du 2026-08-31 : visuel 30038 (gen_visuel_chasseur) — un
         # MISSILE de bombe (spells\missile_bomb, effet 1863) part à la main
         # (vitesse 25), EXPLOSE à l'arrivée (Bomb_ExplosionA, effet 257) et
         # laisse une flaque de feu VISIBLE : le kit de zone persistante du
         # Choc de flammes (9357, natif, au champ 25 du visuel — le relevé du
         # 42926). attributs_ex 0x10000000 = SPELL_ATTR1_NO_AURA_ICON, que
         # porte AUSSI le Choc de flammes : la zone brûle sans coller
         # d'icône de débuff aux cibles (« retirer le dot appliqué aux
         # cibles »). La mécanique DBC — dégâts directs + zone périodique —
         # est déjà celle du Choc de flammes et ne bouge pas.
         icone=3407, visuel=30038, palier=2, ecole=FEU, portee=P_40, recharge=18000, duree=D_6S,
         cible_sol=True, vitesse=25, attributs_ex=0x10000000,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 450, rayon=R_8),
                 eff(E_ZONE, C_ZONE_POSEE, 90, aura=A_PERIODIQUE, rayon=R_8, periode=1000)]),

    # ------------------------------------------------------------ voleur ---
    # Seul des cinq déplacements à viser un point plutôt qu'une direction : on
    # ne lance pas un grappin devant soi au hasard.
    # DESIGN « DASH FUMÉE » (pivot utilisateur du 2026-08-29 — LE GRAPPIN EST
    # ABANDONNÉ, corde comprise ; l'historique des mécanismes reste sur
    # 8600039). Séquence exigée, en 7 temps : 1 réticule au sol (Targets
    # 0x40 / cible_sol) ; 2 un dummy INVISIBLE (803804, display 802102
    # opacité 0) apparaît au point visé ; 3 nuage de fumée sur le joueur
    # (kit 404 de Disparition, joué par SendPlaySpellVisual) ; 4 le
    # personnage devient invisible (SetDisplayId 802102) et intouchable
    # (NOT_SELECTABLE + IMMUNE_TO_PC/NPC) ; 5 il se TÉLÉPORTE derrière le
    # dummy — copie de Pas de l'ombre (8600039), demandée par l'utilisateur
    # le 2026-08-30 en remplacement de la charge (MoveCharge subissait le
    # plafond de spline et l'acquittement d'allure) ; 6 fumée sur le dummy ;
    # 7 réapparition (RestoreDisplayId). Tout est dans le script C++.
    # visuel=0 : plus d'animation de jet (héritage grappin). Pas de vitesse.
    # Identité fixée par l'utilisateur le 2026-08-30 : « Shunpo », icône 30
    # (Spell_Nature_Invisibilty, le nuage de fumée — aucun sort de voleur ne
    # la porte, l'icône 8050 du crochet est rendue). Recharge 45 s, fixée le
    # 2026-08-30 — le sort est COMPLET.
    sort(8600030, "rogue", "mobilité", "Shunpo", "Shunpo",
         "Appear at the targeted location.",
         "Apparait à l'endroit ciblé.",
         icone=30, visuel=0, palier=2, portee=P_15, recharge=45000,
         cible_sol=True,
         effets=[eff(E_DUMMY, C_POINT)],
         script="spell_papota_shunpo"),
    sort(8600031, "rogue", "Assassinat", "Kingsbane", "Fléau des rois",
         "Plunges a venomed blade for $s1 damage over $d. Damage increased by "
         "25% per poison on the target.",
         "Plante une lame envenimée infligeant $s1 points de dégâts sur $d. "
         "Dégâts augmentés de 25% par poison présent sur la cible.",
         aura_en="Damage increased by 25% per poison on the target.",
         aura_fr="Dégâts augmentés de 25% par poison présent sur la cible.",
         icone=247, visuel=8144, palier=3, ecole=NATURE, portee=P_5, recharge=60000, duree=D_12S,
         ressource=ENERGIE, cout=35,
         effets=[eff(E_DEGATS, C_ENNEMI, 300),
                 eff(E_AURA, C_ENNEMI, 150, aura=A_PERIODIQUE, periode=2000)],
         script="spell_papota_fleau_des_rois"),
    # Visuel 30018 : les dés rétroportés (cfx_rogue_rollthebones_castbasedice)
    # roulent devant le lanceur, et l'un des trois sons de lancer part au
    # hasard — le tirage est natif : SoundEntries joue un de ses fichiers selon
    # leurs fréquences. Montage dans gen_visuel_voleur.py.
    # REFONTE du 2026-08-30 : dépense les points de combo (1 à 5, consommés
    # par le script — en 3.3.5 ils vivent sur la cible, le sort reste un sort
    # de soi et le script exige au moins 1 point au lancement). Table :
    # 1/3/5 pts = 1/2/3 bienfaits 15 s ; 2/4 pts = 1/2 bienfaits 30 s (le
    # script double la durée aux mises paires). Recharge 45 s -> 15 s.
    # Le tooltip suit LE FORMAT DES FINISHERS (relevé sur Lames et
    # tranchants 6774) : ouverture « Coup de grâce qui… », puis une ligne
    # par mise séparées par des lignes VIDES (\n\n), trois espaces d'alinéa,
    # et l'espace INSÉCABLE française avant les deux-points ( ).
    sort(8600032, "rogue", "Combat", "Roll the Bones", "Coup de dés",
         "Finishing move that rolls the bones, granting random boons. "
         "Amount and duration depend on combo points:"
         "\n\n   1 point  : 1 boon for 15 seconds"
         "\n\n   2 points: 1 boon for 30 seconds"
         "\n\n   3 points: 2 boons for 15 seconds"
         "\n\n   4 points: 2 boons for 30 seconds"
         "\n\n   5 points: 3 boons for 15 seconds",
         "Coup de grâce qui lance les dés et octroie des bienfaits "
         "aléatoires. Leur nombre et leur durée dépendent des points de "
         "combo :"
         "\n\n   1 point : 1 bienfait pendant 15 secondes"
         "\n\n   2 points : 1 bienfait pendant 30 secondes"
         "\n\n   3 points : 2 bienfaits pendant 15 secondes"
         "\n\n   4 points : 2 bienfaits pendant 30 secondes"
         "\n\n   5 points : 3 bienfaits pendant 15 secondes",
         icone=4175, visuel=30018, palier=2, portee=P_SOI, recharge=15000,
         ressource=ENERGIE, cout=25,
         effets=[eff(E_DUMMY, C_SOI)],
         script="spell_papota_coup_de_des"),

    # Les cinq bienfaits du Coup de dés. Un seul sort à piles ne disait rien de
    # ce qu'il apportait : le joueur voyait « x2 » sans savoir de quoi. Cinq
    # auras distinctes, chacune nommée et décrite, se lisent d'un coup d'œil sur
    # la barre. Le script en tire selon la mise de points de combo (voir
    # 8600032). Durée DBC = 15 s, la base — le script la double aux mises
    # paires (2 et 4 points). Elles ne s'apprennent pas.
    sort(8600034, "rogue", "Combat", "Broadside", "Bordée",
         "Your damage is increased by $s1%.", "Vos dégâts augmentent de $s1%.",
         aura_en="Damage increased by $s1%.", aura_fr="Dégâts augmentés de $s1%.",
         icone=243, visuel=8996, palier=1, portee=P_SOI, duree=D_15S,
         effets=[eff(E_AURA, C_SOI, 15, aura=A_DEGATS_PCT, misc=TOUTES_ECOLES)]),
    sort(8600035, "rogue", "Combat", "Snake Eyes", "Œil du serpent",
         "Your critical chance is increased by $s1%.",
         "Vos chances de coup critique augmentent de $s1%.",
         aura_en="Critical chance increased by $s1%.",
         aura_fr="Chances de critique augmentées de $s1%.",
         icone=138, visuel=8996, palier=1, portee=P_SOI, duree=D_15S,
         effets=[eff(E_AURA, C_SOI, 15, aura=A_CRITIQUE)]),
    sort(8600036, "rogue", "Combat", "Grand Melee", "Grande mêlée",
         "Your attack speed is increased by $s1%.",
         "Votre vitesse d'attaque augmente de $s1%.",
         aura_en="Attack speed increased by $s1%.",
         aura_fr="Vitesse d'attaque augmentée de $s1%.",
         icone=515, visuel=8996, palier=1, portee=P_SOI, duree=D_15S,
         effets=[eff(E_AURA, C_SOI, 20, aura=A_HATE_MELEE)]),
    sort(8600037, "rogue", "Combat", "Buried Treasure", "Trésor enfoui",
         "Your energy returns $s1% faster.",
         "Votre énergie revient $s1% plus vite.",
         aura_en="Energy regeneration increased by $s1%.",
         aura_fr="Régénération d'énergie augmentée de $s1%.",
         icone=202, visuel=8996, palier=1, portee=P_SOI, duree=D_15S,
         effets=[eff(E_AURA, C_SOI, 50, aura=A_REGEN_RESSOURCE, misc=ENERGIE)]),
    sort(8600038, "rogue", "Combat", "True Bearing", "Cap franc",
         "You move $s1% faster.", "Vous vous déplacez $s1% plus vite.",
         aura_en="Movement speed increased by $s1%.",
         aura_fr="Vitesse de déplacement augmentée de $s1%.",
         icone=516, visuel=8996, palier=1, portee=P_SOI, duree=D_15S,
         effets=[eff(E_AURA, C_SOI, 30, aura=A_VITESSE)]),

    # Le PAS du dash — copie du cœur de Pas de l'ombre (36563, relevé le
    # 2026-08-30) : effet 5 TELEPORT_UNITS, cible A = lanceur (1). La
    # composante « DERRIÈRE la cible » (65 + rayon 7) est RETIRÉE le
    # 2026-08-30 : cible B = 63 (DEST_TARGET_ANY de ce cœur), destination
    # SUR la cible, sans décalage.
    # L'ORIENTATION : la destination d'une téléportation porte celle de la
    # CIBLE — le script invoque donc le dummy avec l'orientation du lanceur
    # au clic, et le personnage atterrit dans SA propre orientation.
    # Le script du dash (8600030) lance ce sort EN DÉCLENCHÉ sur le dummy —
    # aucune spline, aucun plafond de vitesse, aucun acquittement d'allure.
    # Les effets 2/3 de l'original (menace) et son visuel violet (8262) ne
    # sont PAS copiés : visuel=0, la fumée du dash habille tout. Jamais
    # appris, hors grimoire (SANS_ONGLET de gen_sla_classes.py). Le SAVOIR
    # de l'ère grappin/corde/câble (harnais de champs validé sur l'étalon
    # drain 12655, chaîne custom 2000, « un missile client n'est pas un
    # objet », piège SetSpeedRate, textures bannies) est archivé en mémoire
    # de projet.
    sort(8600039, "rogue", "mobilité", "Shunpo Step", "Pas du Shunpo",
         "Teleports you to the target.", "Vous téléporte sur la cible.",
         icone=30, visuel=0, palier=1, portee=P_100,
         attributs_ex=0x100,
         effets=[eff(E_TELEPORT, C_SOI, cibleB=C_DEST_CIBLE)]),
    # Le malus vise la CIBLE et ne sert que son porteur : deux voleurs marquent
    # la même victime sans se gêner, chacun profitant de sa propre marque.
    # Visuels RÉTROPORTÉS le 2026-08-30 (sources utilisateur, montage dans
    # gen_visuel_voleur.py) : visuel 30020 — kit de lancer
    # (cfx_rogue_deathmark_cast aux pieds, validé) + kit d'IMPACT (la marque
    # cfx_rogue_deathmark_aura PLEINE échelle au TORSE de la cible, one-shot
    # à l'application — réglage utilisateur du 2026-08-30) + kit d'ÉTAT (la
    # même marque, échelle 0,15, À LA TÊTE tant que l'aura tient — validé) ;
    # icône moderne 8051 (ability_rogue_deathmark). Remplacent les emprunts
    # 3582/776. La variante aura01 est injectée en réserve, non référencée ;
    # aucun son dans l'export (signalé).
    sort(8600033, "rogue", "Finesse", "Symbols of Death", "Symboles de mort",
         "Marks the target: it takes $s1% more damage from YOU for $d, and $s2 "
         "energy floods back to you.",
         "Marque la cible : elle subit $s1% de dégâts supplémentaires DE VOTRE "
         "part pendant $d, et $s2 points d'énergie vous reviennent.",
         aura_en="Taking $s1% more damage from the rogue who marked it.",
         aura_fr="Subit $s1% de dégâts supplémentaires du voleur qui l'a marquée.",
         icone=8051, visuel=30020, palier=1, ecole=OMBRE, portee=P_30,
         recharge=30000, duree=D_10S,
         effets=[eff(E_AURA, C_ENNEMI, 15, aura=A_DEGATS_DU_LANCEUR),
                 eff(E_ENERGIE, C_SOI, 40, misc=ENERGIE)]),

    # ------------------------------------------------------------ prêtre ---
    # Refonte du 2026-08-31 (« ne fait rien ») : la zone d'accélération est
    # remplacée par une VRAIE PLUME posée au sol — la créature 803812,
    # habillée du modèle exporté (display 802108, gen_visuel_pretre), qui
    # vit 6 s et donne le bienfait 8600097 au premier allié qui la touche
    # avant de s'effacer. Réticule RÉDUIT DE 60 % : 5 m -> 2 m (le curseur
    # lit le rayon du premier effet). Icône moderne (8061).
    sort(8600040, "priest", "mobilité", "Angelic Feather", "Plume angélique",
         # La plume tient 6 s au sol (PLUME_VIE, côté script — aucun sort ne
         # porte cette durée, elle est donc écrite en clair) ; le bienfait,
         # lui, est lu dans le 8600097.
         "Places a feather for 6 sec; the first ally to cross it gains "
         "$8600097s1% speed for $8600097d. Holds three feathers.",
         "Pose une plume pendant 6 sec : le premier allié qui la traverse "
         "gagne $8600097s1% de vitesse pendant $8600097d. Vous disposez de "
         "trois plumes.",
         icone=8061, visuel=0, palier=3, ecole=SACRE, portee=P_30, recharge=20000,
         ressource=MANA, cout=200,
         cible_sol=True,
         effets=[eff(E_DUMMY, C_POINT, rayon=R_2)],
         script="spell_papota_plume"),
    # CHANGEMENT TOTAL du 2026-09-01 : le Torrent du Vide (jugé trop proche
    # d'Incandescence mentale) devient « Mot de l'ombre : désespoir ». Il ne
    # fait aucun dégât direct : il POSE les deux maléfices d'Ombre du prêtre
    # sur tout ennemi à 10 m, AU MEILLEUR RANG QU'IL CONNAISSE (le script
    # lit son grimoire ; les deux sorts se reconnaissent à la famille 6 et
    # aux masques 0x8000 — Douleur — et 0x400 du deuxième mot — Toucher
    # vampirique). Visuel, son et icône rétroportés (gen_visuel_pretre).
    sort(8600041, "priest", "Ombre", "Shadow Word: Despair",
         "Mot de l'ombre : désespoir",
         # Texte arrêté par l'utilisateur le 2026-09-01.
         "Deals $s1 damage in an area; the victims also suffer Shadow Word: "
         "Pain and Vampiric Touch.",
         "Inflige $s1 dégâts dans une zone, les victimes subissent aussi "
         "Mot de l'ombre : Douleur et Toucher vampirique.",
         # Réglages du 2026-09-01 : 3 s d'incantation, RÉTICULE AU SOL (la
         # zone s'ouvre au point visé, cible 16, et non plus autour du
         # prêtre), 65 % du mana de base, et 1250 points de dégâts en plus
         # des deux maléfices.
         icone=8062, visuel=30044, palier=2, ecole=OMBRE, portee=P_30,
         cast=I_3S, recharge=15000, ressource=MANA, cout_pct=65, blocage=1,
         classe_degats=1, famille=6, cible_sol=True,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 1250, rayon=R_10),
                 eff(E_DUMMY, C_ZONE_VISEE, rayon=R_10)],
         script="spell_papota_desespoir"),
    # Changement de design du 2026-09-01 : plus de réduction en pourcentage,
    # mais UNE RÉSERVE D'ABSORPTION COMMUNE — 25 000 points partagés par tous
    # les membres du groupe ou du raid présents dans les 15 m, à la manière
    # du Bouclier anti-magie mais pour TOUS les dégâts. Le dôme est une
    # créature posée au réticule (803813, display 802109) : elle tient la
    # réserve et distribue la protection 8600059. Visuel et son rétroportés
    # (gen_visuel_pretre).
    sort(8600042, "priest", "Discipline", "Power Word: Barrier", "Mot de pouvoir : Barrière",
         "Raises a dome for $d: allies beneath it take $8600059s1% less "
         "physical damage. The dome shrinks to half its size as it wanes.",
         "Dresse un dôme pendant $d : les alliés qu'il abrite subissent "
         "$8600059s1% de dégâts physiques en moins. Le dôme se resserre "
         "jusqu'à la moitié de sa taille en s'épuisant.",
         # 2,5 s d'incantation et visuel 30047 (le précast SACRÉ natif) :
         # le prêtre lève les mains de Lumière pendant le lancement
         # (2026-09-01).
         icone=3837, visuel=30047, palier=3, ecole=SACRE, portee=P_30,
         cast=I_2S5, recharge=120000, duree=D_10S,
         ressource=MANA, cout=800,
         cible_sol=True,
         # Réticule et zone à 8 m (2026-09-01 : 15 -> 9 -> 8).
         effets=[eff(E_DUMMY, C_POINT, rayon=R_8)],
         script="spell_papota_barriere_zone"),
    # RÉTROPORT DU 2026-09-01 : le sort se joue EN DEUX TEMPS, autour de la
    # POSITION DU LANCEUR AU MOMENT DU LANCER — le prêtre peut s'en aller,
    # l'anneau ne bouge plus. Temps 1, l'anneau S'OUVRE (créature 803814,
    # modèle cfx_priest_halo_cast02) et l'onde passe ; trois secondes plus
    # tard, temps 2, il SE REFERME (803815, cfx_priest_halo_cast) et l'onde
    # repasse. Le sort lui-même ne porte donc plus ni dégâts ni soins : les
    # deux ondes sont les sorts auxiliaires 8600044 (dégâts) et 8600045
    # (soins), lancés par le prêtre au point d'ancrage. Son visuel 30051 ne
    # porte que le SON du lancement, icône ability_priest_halo (8063).
    sort(8600043, "priest", "Sacré", "Halo", "Halo",
         "A ring of light spreads outward, then draws back in: each passage "
         "heals allies for $8600045s1 and sears enemies for $8600044s1.",
         "Un anneau de lumière se déploie puis se resserre : à chaque passage "
         "il soigne les alliés de $8600045s1 points et brûle les ennemis de "
         "$8600044s1 points.",
         icone=8063, visuel=30051, palier=3, ecole=SACRE, portee=P_SOI,
         recharge=40000, ressource=MANA, cout=600,
         effets=[eff(E_DUMMY, C_SOI)],
         script="spell_papota_halo"),

    # ------------------------------------------- chevalier de la mort ------
    # CHANGEMENT TOTAL du 2026-09-01 : le glissement spectral devient une
    # PAIRE DE PORTES, posée d'UN SEUL LANCER. Le client de 3.3.5 n'ouvre son
    # réticule que sur une pression de touche et aucun paquet ne le lui
    # commande : un lancer ne peut donc désigner qu'UNE position. La paire
    # est donc « ici et là-bas » — une porte aux pieds du chevalier, l'autre
    # au réticule. Chacune (objet 803820) tient 45 s ; un clic droit sur
    # l'une transporte à l'autre, la porte franchie s'efface et celle
    # d'arrivée gagne 45 s. Si une porte est déjà debout, le lancer n'en pose
    # qu'une, au réticule. Les deux secondes d'incantation sont désormais
    # celles du sort lui-même : il n'y a plus qu'un lancer, donc plus besoin
    # du sort auxiliaire qui les portait — ni du jeton de second temps, ni de
    # la recharge posée à la main.
    # Renommé « Tunnel de la mort » le 2026-09-02, avec son icône
    # inv_netherportal (8067) ; ses portes prennent le portail rétroporté.
    sort(8600050, "deathknight", "mobilité", "Death Tunnel", "Tunnel de la mort",
         "Raises a door at your feet and another at the target point, both "
         "for 45 sec. Use a door to travel to the other: it vanishes and the "
         "other gains 45 sec. With a door already standing, only one is "
         "raised.",
         "Dresse une porte à vos pieds et une autre au point visé, chacune "
         "pendant 45 sec. Utilisez une porte pour rejoindre l'autre : elle "
         "disparaît et l'autre gagne 45 sec. Si une porte est déjà dressée, "
         "une seule est posée.",
         icone=8067, visuel=11005, palier=2, ecole=OMBRE, portee=P_30,
         # 1 s d'incantation (2026-09-02 ; 2 s puis 1,5 s auparavant).
         cast=I_1S, recharge=40000, cible_sol=True,
         effets=[eff(E_DUMMY, C_POINT)],
         script="spell_papota_porte"),
    # Refonte du 2026-09-02 : UNE GOULE PAR ENNEMI dans les 8 m autour de la
    # cible (deux au minimum, toutes deux sous la cible), levées 16 s aux
    # PIEDS de leurs proies. Elles frappent le plus proche d'elles et
    # majorent leurs coups de 12,5 % par maladie du chevalier sur la
    # victime. Art rétroporté (gen_visuel_dk) : icône
    # spell_deathknight_defile (8064), visuel 30052 — l'animation d'attaque
    # à deux mains critique (Special2H) et le son au lancement, le
    # tourbillon au sol à l'impact.
    sort(8600051, "deathknight", "Impie", "Apocalypse", "Apocalypse",
         "Bursts your diseases on the target: $s1 damage, half again per "
         "disease, and half as much to enemies within 8 yards. Raises a "
         "ghoul beneath each of them (two at least) for $d.",
         "Fait éclater vos maladies sur la cible : $s1 points de dégâts, "
         "majorés de moitié par maladie, et la moitié de ce montant aux "
         "ennemis à moins de 8 mètres. Lève une goule sous chacun d'eux "
         "(deux au minimum) pendant $d.",
         icone=8064, visuel=30052, palier=3, ecole=OMBRE, portee=P_5,
         recharge=90000, duree=D_19S,
         ressource=PUISSANCE_RUNIQUE, cout=0,
         # Le factice vise L'ENNEMI et non plus le lanceur (2026-09-02) :
         # en C_SOI le chevalier comptait parmi les touchés, et le kit
         # d'impact du visuel — le tourbillon — s'ouvrait aussi sous SES
         # pieds. Le script ne s'appuie pas sur cet effet (il travaille en
         # AfterCast), le changement de cible ne lui coûte rien.
         effets=[eff(E_DEGATS, C_ENNEMI, 800), eff(E_DUMMY, C_ENNEMI)],
         script="spell_papota_apocalypse"),
    # Art rétroporté (gen_visuel_dk, 2026-09-02) : icône
    # achievement_boss_lordmarrowgar (8065) et visuel 30055 — le son au
    # lancement, puis le modèle d'état `cfx_deathknight_bonestorm_state`
    # qui tourne autour du chevalier tant que l'aura tient.
    # Refonte du 2026-09-02 : c'est UN BIENFAIT SUR LE CHEVALIER, et non
    # plus une aura de drain posée sur chaque ennemi. Elle bat chaque
    # seconde ; le script lacère alors les ennemis à 5 m et rend au porteur
    # 2 % de ses points de vie maximum PAR ENNEMI pris dans la tempête.
    # L'aura factice périodique est le canal : le DBC fait battre, le script
    # décide.
    sort(8600052, "deathknight", "Sang", "Bonestorm", "Tempête d'os",
         "A storm of bone whirls about you for $d, tearing at enemies within "
         "5 yards for $s1 each second and mending $s2% of your maximum health "
         "per enemy caught in it.",
         "Une tempête d'os tournoie autour de vous pendant $d : elle lacère "
         "les ennemis à moins de 5 mètres de $s1 points par seconde et vous "
         "rend $s2% de vos points de vie maximum par ennemi pris dedans.",
         aura_en="A storm of bone whirls about you.",
         aura_fr="Une tempête d'os tournoie autour de vous.",
         icone=8065, visuel=30055, palier=3, ecole=OMBRE, portee=P_SOI, recharge=60000, duree=D_8S,
         ressource=PUISSANCE_RUNIQUE, cout=0,
         effets=[eff(E_AURA, C_SOI, 200, aura=A_PERIODIQUE_FACTICE,
                     rayon=R_5, periode=1000),
                 # $s2 : le pourcentage de vie rendu, lu par le script.
                 eff(E_AURA, C_SOI, 2, aura=A_DUMMY)],
         script="spell_papota_tempete_os"),
    # Refonte de l'audit : l'aura vivait sur CHAQUE ennemi du cône, et le drain
    # de puissance runique se payait par battement de chaque cible — trois
    # ennemis, triple facture. La canalisation vit désormais sur le LANCEUR et
    # déclenche chaque seconde le sort de cône 8600054 ; le script ne fait plus
    # que payer la note et souffler la canalisation quand la réserve est vide.
    sort(8600053, "deathknight", "Givre", "Breath of Sindragosa", "Souffle de Sindragosa",
         "Exhale a freezing breath, dealing $8600054s1 damage every second while runic power lasts.",
         "Exhale un souffle glacial infligeant $8600054s1 points de dégâts par seconde tant que dure la puissance runique.",
         aura_en="Exhaling a freezing breath.",
         aura_fr="Vous exhalez un souffle glacial.",
         # Art rétroporté (gen_visuel_dk, 2026-09-02) : icône
         # achievement_boss_sindragosa (8066) et visuel 30056 — le son au
         # départ, puis la TÊTE DE DRAGON au point d'attache Head et le
         # GIVRE AU SOL au point Base, tous deux dans le kit de
         # canalisation : ils tiennent tant que le souffle dure.
         icone=8066, visuel=30056, palier=3, ecole=GIVRE, portee=P_SOI, recharge=120000, duree=D_30S,
         # PLUS DE CANALISATION (2026-09-02) : un simple BIENFAIT, posé et
         # oublié. Alléger les drapeaux d'interruption ne suffisait pas —
         # une canalisation suspend les attaques automatiques quoi qu'on
         # fasse. L'aura bat chaque seconde, mord et prélève sa puissance
         # runique ; elle tombe d'elle-même quand la réserve est vide. Les
         # 30 s de durée ne sont qu'un plafond.
         ressource=PUISSANCE_RUNIQUE, cout=0,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DECLENCHEUR, periode=1000,
                     declenche=8600054)],
         script="spell_papota_souffle_sindragosa"),
    # Le cône déclenché : jamais appris, jamais visible — c'est la dent du
    # souffle, une morsure par seconde.
    # Visuel 30057 (2026-09-02) : rien que l'impact sur chaque ennemi du
    # cône — l'effet exporté pour les touchés.
    sort(8600054, "deathknight", "Givre", "Breath of Sindragosa Tick",
         "Souffle de Sindragosa",
         "Freezing breath.", "Souffle glacial.",
         parent=8600053,   # l'écho du Souffle de Sindragosa
         icone=8066, visuel=30057, palier=1, ecole=GIVRE, portee=P_SOI,
         effets=[eff(E_DEGATS, C_CONE, 250, rayon=R_12)]),

    # (Le banc d'essai des souffles — quatre sorts factices 8600064-67 qui ne
    # faisaient que jouer une animation — est RETIRÉ le 2026-09-02 : le choix
    # est arrêté sur `dragonbreath_frost`, qui remplace désormais l'effet au
    # sol dans le kit de canalisation.)

    # LA CHUTE DU SÉISME (8600061, 2026-09-02) : DEUX secondes
    # d'étourdissement de mécanique 14 « assommé ». Posée par le script sur
    # une victime tirée au sort à chaque battement. Son visuel 30073 ne
    # porte que le KIT D'ÉTAT NATIF des étourdissements (349 : animation 14
    # et le modèle StunSwirl_State_Head, les étoiles au-dessus de la tête) —
    # sans lui, la victime était bien figée mais sans rien le montrer.
    # Jamais apprise (SANS_ONGLET).
    # LA MARQUE. Elle ne fait rien non plus : elle DIT au joueur qu'il est
    # dans la zone et que ses PV sont mis en commun. Le script la pose quand
    # il entre dans les 10 metres et la retire des qu'il en sort — c'est le
    # seul retour visible d'une mecanique par ailleurs silencieuse (les PV
    # sont poses directement, sans soin ni degats affiches).
    sort(8600064, "shaman", "Restauration", "Spirit Link", "Lien d'esprit",
         "Your health is pooled with nearby group members. Healing for $s1% "
         "of maximum health every second, and damage taken reduced by 3%.",
         "Vos points de vie sont mis en commun avec les membres du groupe "
         "proches. Vous recuperez $s1% de vos points de vie maximum chaque "
         "seconde et subissez 3% de degats en moins.",
         aura_en="Health pooled with the group. Healing $s1% per second, "
                 "damage taken reduced by 3%.",
         aura_fr="Points de vie mis en commun avec le groupe. $s1% de soins "
                 "par seconde, 3% de degats subis en moins.",
         icone=8071, visuel=0, palier=2, ecole=NATURE, portee=P_SOI,
         # PERMANENTE, sans decompte : la marque n'a pas de vie propre, elle
         # suit la zone. C'est le script qui la pose en entrant et la retire
         # en sortant, ou a la fin du totem. Une duree n'aurait fait
         # qu'afficher un compte a rebours faux — reinitialise a chaque
         # battement, puis fini avant le totem.
         duree=D_PERMANENT,
         # Le soin est en POURCENTAGE des PV max : l'aura 20 le fait
         # nativement, elle bat et soigne $s1 % du maximum de la cible — pas
         # besoin de le calculer dans le script. La reduction de degats est
         # NEGATIVE : -3 signifie 3 % de moins.
         effets=[eff(E_AURA, C_SOI, 2, aura=A_SOIN_PCT_PERIODIQUE,
                     periode=1000),
                 eff(E_AURA, C_SOI, -3, aura=A_DEGATS_SUBIS_PCT)]),
    # Le PORTEUR du visuel du Totem de lien d'esprit. Il ne fait rien : il
    # existe pour qu'une aura vive sur le TOTEM pendant les 16 secondes et y
    # accroche l'effet. Le script le pose sur la creature au moment ou elle
    # apparait. DEUX visuels sont montes cote a cote pour trancher en jeu :
    # 30076 = effet vaste, a la taille de la zone (actif), 30075 = effet
    # compact. Changer ce seul nombre puis relancer gen_sorts_classes.py
    # --deploy suffit a basculer, sans toucher au serveur.
    sort(8600069, "shaman", "Restauration", "Spirit Link Totem", "Lien d'esprit",
         "", "",
         icone=8071, visuel=30076, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_16S,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),
    sort(8600068, "shaman", "Amélioration", "Earthquake", "Séisme",
         "Knocked down.", "Jeté à la renverse.",
         aura_en="Knocked down.", aura_fr="Jeté à la renverse.",
         icone=8068, visuel=30073, palier=1, ecole=NATURE, portee=P_30,
         duree=D_2S, mecanique=14,
         effets=[eff(E_AURA, C_ENNEMI, 1, aura=A_ETOURDI, mecanique=14)]),

    # ------------------------------------------------------------ chaman ---
    sort(8600060, "shaman", "mobilité", "Gust of Wind", "Bourrasque",
         "The wind hurls you in the direction you are moving.",
         "Le vent vous propulse dans la direction où vous allez.",
         # Icône spell_druid_astralstorm (8069) et son propre son greffé sur
         # le visuel natif du vent (gen_visuel_chaman, 2026-09-02). Le script
         # ne fait plus PIVOTER le personnage : le vent le pousse.
         icone=8069, visuel=30072, palier=2, ecole=NATURE, portee=P_SOI, recharge=35000,
         effets=[eff(E_DUMMY, C_POINT_SOI)],   # E_SAUT -> E_DUMMY, voir 8600000
         script="spell_papota_bond_directionnel"),
    # CHANGEMENT TOTAL du 2026-09-02 : le Fracassement devient « Séisme ».
    # Une zone posée au réticule, 7 m de rayon, qui tremble 9 secondes et
    # frappe chaque seconde ; chaque coup a une chance de jeter sa victime à
    # la renverse (le script, 10 %). Art rétroporté (gen_visuel_chaman).
    sort(8600061, "shaman", "Amélioration", "Earthquake", "Séisme",
         "Shakes the ground for $d: $s1 damage each second, with a chance to "
         "knock victims down.",
         "Fait trembler le sol pendant $d : $s1 points de dégâts par seconde, "
         "avec une chance de jeter les victimes à la renverse.",
         # INSTANTANÉ et 16 s de recharge (2026-09-02 ; 3 s d'incantation
         # puis 1 s auparavant). Le sort ne coupe donc plus les attaques
         # automatiques, sans qu'il faille toucher au cœur — le correctif de
         # PlayerUpdates.cpp, et l'attribut « ne remet pas les compteurs à
         # zéro », sont annulés avec l'incantation.
         icone=8068, visuel=30070, palier=2, ecole=NATURE, portee=P_30,
         recharge=16000, duree=D_9S, ressource=MANA, cout=300,
         # MALUS DÉCLARÉ (2026-09-02, « considéré comme un buff sur les
         # ennemis ») : la déduction automatique se fonde sur la CIBLE de
         # l'aura, et une zone posée au sol (C_POINT) sert aussi bien aux
         # effets amis — le dôme de la Barrière. Il faut donc le dire ici.
         cible_sol=True, attributs=ATTR_MALUS,
         effets=[eff(E_ZONE, C_POINT, 400, aura=A_PERIODIQUE, rayon=R_7,
                     periode=1000)],
         script="spell_papota_seisme"),
    # Refonte du 2026-09-02 : le chaman prend la FORME D'UN ASCENDANT
    # (modèle rétroporté, display 802120) pendant 16 secondes. Ses dégâts
    # magiques montent de 15 %, ses trois sorts de foudre et de lave se
    # lancent en marchant, et le lancement pose Horion de feu sur cinq
    # ennemis en face de lui à 36 mètres, chacun suivi d'une Explosion de
    # lave. Icône et son rétroportés (gen_visuel_chaman).
    sort(8600062, "shaman", "Élémentaire", "Ascendance", "Ascendance",
         "Your magic damage is increased by $s1%, and Lightning Bolt, Chain "
         "Lightning and Lava Burst may be cast while moving, for $d. "
         "In addition, five foes before you are struck by Flame Shock "
         "followed by a Lava Burst.",
         "Vos dégâts magiques augmentent de 15%, Éclair, Chaîne d'éclairs "
         "et Explosion de lave se lancent en marchant pendant 16 secondes. "
         "De plus, cinq ennemis devant vous subissent Horion de feu puis "
         "une Explosion de lave.",
         aura_en="Magic damage increased by $s1%. Can cast while moving.",
         aura_fr="Dégâts magiques augmentés de 15%. Peut incanter en "
                 "mouvement.",
         icone=8070, visuel=30074, palier=3, ecole=NATURE, portee=P_SOI,
         recharge=180000, duree=D_16S,
         # MISC 126 : toutes les écoles SAUF le physique — « dégâts
         # magiques ». À zéro, l'aura s'appliquerait sans rien majorer.
         effets=[eff(E_AURA, C_SOI, 15, aura=A_DEGATS_PCT, misc=126),
                 eff(E_AURA, C_SOI, 1, aura=A_DUMMY)],
         script="spell_papota_ascendance"),
    # Refonte du 2026-09-03 : le totem ne soigne plus, il REDISTRIBUE. Le DBC
    # ne porte qu'une aura FACTICE qui bat une fois par seconde sur le chaman ;
    # tout le calcul est dans spell_papota_lien_esprit, qui pose le totem,
    # travaille autour de LUI (rayon 10 m) et pose les PV directement.
    sort(8600063, "shaman", "Restauration", "Spirit Link Totem", "Totem de lien d'esprit",
         "Summons a totem for $d. Every second, you and any group or raid "
         "members within 7 yards heal for 2% of maximum health and take 3% "
         "less damage. With others present, health is also redistributed: "
         "those above the median give up to 10% of their current health to "
         "those below, in proportion to what they are missing.",
         "Pose un totem pendant $d. Chaque seconde, vous et les membres du "
         "groupe ou du raid dans un rayon de 7 mètres récupérez 2% de vos "
         "points de vie maximum et subissez 3% de dégâts en moins. À "
         "plusieurs, vos points de vie sont en outre redistribués : ceux "
         "au-dessus de la médiane cèdent jusqu'à 10% de leurs points de vie "
         "actuels à ceux en dessous, au prorata de ce qui leur manque.",
         aura_en="Health is being redistributed among nearby group members.",
         aura_fr="Les points de vie des membres du groupe proches sont "
                 "redistribués.",
         # Le visuel du SORT ne porte que le son du lancement : l'effet
         # lui-meme est sur le TOTEM, via le sort porteur 8600069.
         icone=8071, visuel=30078, palier=3, ecole=NATURE, portee=P_SOI, recharge=180000, duree=D_16S,
         # L'aura du SORT ne pilote que le battement : elle est MASQUEE
         # de la barre de bienfaits (0x10000000 = NO_AURA_ICON). Le
         # chaman ne porte donc qu'une seule icone, la marque 8600064,
         # exactement celle que voient ses allies.
         attributs_ex=0x10000000,
         ressource=MANA, cout=700,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_PERIODIQUE_FACTICE, periode=1000)],
         script="spell_papota_lien_esprit"),

    # -------------------------------------------------------------- mage ---
    # Refonte du 2026-08-30 : COPIE DE TRANSFERT (téléportation, plus un
    # saut) sur 40 m, direction des touches conservée (AngleDeplacement) —
    # script dédié, Bourrasque garde le saut directionnel.
    # EN DEUX TEMPS (2026-08-31) : le premier lancer téléporte et laisse une
    # marque au point de départ, SANS déclencher la recharge ; un second
    # lancer dans les 5 s ramène à la marque et déclenche la recharge ;
    # passé ce délai, la marque tombe et la recharge part quand même.
    sort(8600070, "mage", "mobilité", "Shimmer", "Miroitement",
         "You shimmer in the direction you are moving, leaving a mark behind. "
         "Cast again within $8600058d to return to it.",
         "Vous vous déplacez par miroitement dans la direction où vous allez "
         "et laissez une marque derrière vous. Relancez le sort dans les "
         "$8600058d pour y revenir.",
         # Icône moderne spell_mage_evanesce (8058, gen_visuel_mage),
         # exportée le 2026-08-31.
         icone=8058, visuel=263, palier=2, ecole=ARCANES, portee=P_SOI, recharge=20000,
         effets=[eff(E_DUMMY, C_POINT_SOI)],   # E_SAUT -> E_DUMMY, voir 8600000
         script="spell_papota_miroitement"),
    # Refonte du 2026-08-30 (« ne fait rien » + sources exportées) : le VRAI
    # orbe voyageur — une créature habillée du modèle 11fx_arcaneorb02
    # (display 802103, gen_visuel_mage) avance en ligne droite sur 40 m et
    # frappe chaque ennemi croisé UNE fois ($s1, livraison explicite, patron
    # des Frappes fauchantes) avec le son d'impact exporté. Icône moderne
    # inv_112_arcane_orb (8055).
    sort(8600071, "mage", "Arcanes", "Arcane Orb", "Orbe des arcanes",
         "Sends forth an orb that strikes everything in its path for $s1.",
         "Envoie un orbe qui frappe tout sur son passage pour $s1 points.",
         # classe_degats=1 (magie) : c'est lui qui rend les COUPS CRITIQUES
         # possibles (demande du 2026-08-31) — l'IA de l'orbe tire la chance
         # de critique du cœur, qui reste à zéro en classe « aucune ».
         icone=8055, visuel=0, palier=3, ecole=ARCANES, portee=P_SOI, recharge=20000,
         ressource=MANA, cout=400, classe_degats=1,
         effets=[eff(E_DUMMY, C_SOI, 750)],
         script="spell_papota_orbe_arcanes"),
    # Le RÉTROPORT du Météore (trois modèles orchestrés, coutures, sons —
    # 2026-08-30/31) a été RETIRÉ le 2026-08-31 (« ça ne mène à rien ») :
    # retour à la forme DBC d'origine. Les fichiers injectés restent
    # dormants dans patch-z ; les créatures 803807-09 sont supprimées (SQL).
    sort(8600072, "mage", "Feu", "Meteor", "Météore",
         "Calls a meteor that strikes for $s1 and leaves the ground burning for $d.",
         "Appelle un météore qui frappe pour $s1 points et laisse le sol en flammes pendant $d.",
         icone=45, visuel=2253, palier=2, ecole=FEU, portee=P_40, recharge=45000, duree=D_8S,
         ressource=MANA, cout=600,
         cible_sol=True,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 900, rayon=R_8),
                 eff(E_ZONE, C_ZONE_POSEE, 120, aura=A_PERIODIQUE, rayon=R_8, periode=1000)]),
    # « Pluie de comètes » REMPLACÉE par « Rayon de givre » (2026-08-30) :
    # canalisation de 5 s sur cible, dont les dégâts de givre AUGMENTENT
    # avec la durée (base x numéro du tic — script). Icône et visuel
    # PROVISOIRES en attendant un choix : tous deux restent ceux des
    # comètes — un vrai visuel de rayon (chaîne de canal givre) est à
    # monter si le sort est retenu.
    sort(8600073, "mage", "Givre", "Ray of Frost", "Rayon de givre",
         "Channels a ray of frost at the target for $d, dealing $s1 damage "
         "per second, increasing each second.",
         "Canalise un rayon de givre sur la cible pendant $d : $s1 points de "
         "dégâts par seconde, augmentant à chaque seconde.",
         # Montage du 2026-08-31 : visuel 30037 — la COPIE FIDÈLE du Drain
         # de vie (charpente 12655, kit de canal cloné du 11762, chaîne
         # clonée du 719) avec la seule texture remplacée par le faisceau
         # glaciaire exporté. attributs_ex 0x4000 : le bit que porte le
         # drain en plus du « canalisé » (relevé 689/47857 = 0x4004) — c'est
         # lui qui fait SUIVRE la cible au faisceau. Icône
         # ability_mage_rayoffrost (8059). classe_degats=1 (magie) : ce fork
         # autorise les tics de dégâts à critiquer, mais la chance reste
         # nulle en classe « aucune ».
         # Le test du 2026-08-31 (visuel natif 12655 posé un instant) a
         # tranché : le faisceau vert s'affichait, donc canalisation et canal
         # visuel fonctionnent — seule NOTRE TEXTURE ne se chargeait pas,
         # rangée sous spells\ au lieu du dossier natif des chaînes. Retour
         # à notre clone, texture déplacée et défilement retourné.
         icone=8059, visuel=30037, palier=2, ecole=GIVRE, portee=P_40, recharge=30000,
         ressource=MANA, cout=500, classe_degats=1, attributs_ex=0x4000,
         duree=D_6S, canal=True,
         effets=[eff(E_AURA, C_ENNEMI, 100, aura=A_PERIODIQUE, periode=1000)],
         script="spell_papota_rayon_givre"),

    # --------------------------------------------------------- démoniste ---
    sort(8600080, "warlock", "mobilité", "Burning Rush", "Ruée ardente",
         "Your speed rises by $s1%, burning $s2% of your maximum health every "
         "second, until you cast it again. It ends on its own before it can "
         "kill you, and requires more than 16% health to be cast.",
         "Votre vitesse augmente de $s1%, au prix de $s2% de vos points de vie "
         "maximum par seconde, jusqu'à ce que vous le relanciez. Le sort "
         "s'interrompt de lui-même avant de vous tuer, et exige plus de 16% "
         "de vos points de vie pour être lancé.",
         icone=2127, visuel=12038, palier=2, ecole=FEU, portee=P_SOI, recharge=0,
         # SANS DUREE : la ruee tient jusqu'a ce qu'on la relance, ou que le
         # plancher de 10 % de vie l'arrete.
         duree=D_PERMANENT,
         # 15 % des PV MAX par seconde (2026-09-03) : le script lit ce nombre
         # et le passe a CountPctFromMaxHealth. Le plancher est ailleurs, dans
         # l'AuraScript : sous 10 % de vie l'aura se retire, donc la ruee ne
         # peut pas tuer.
         #
         # L'effet periodique est FACTICE, pas une aura de degats. Le coeur
         # tient une aura de degats periodiques lancee SUR SOI pour negative
         # par construction (SpellInfo::_IsPositiveEffect, cas
         # SPELL_AURA_PERIODIC_DAMAGE : « part of negative spell if casted at
         # self (prevent cancel) ») : elle s'affichait donc en malus, et le
         # clic droit etait impossible. Le script calculant lui-meme les
         # degats, le type d'aura n'a aucune importance fonctionnelle.
         effets=[eff(E_AURA, C_SOI, 50, aura=A_VITESSE),
                 eff(E_AURA, C_SOI, 15, aura=A_PERIODIQUE_FACTICE,
                     periode=1000)],
         script="spell_papota_ruee_ardente"),
    sort(8600081, "warlock", "Affliction", "Phantom Singularity", "Singularité fantomatique",
         "A singularity drains all enemies beneath it for $s1 every second.",
         "Une singularité draine tous les ennemis qu'elle surplombe de $s1 points par seconde.",
         # Art exporte le 2026-09-03 (gen_visuel_demoniste) : icone moderne
         # spell_shadow_mindtwisting, et le visuel 30079 — le son au
         # lancement, puis le decal mannoroth_gooflowshadow_state_projected
         # au sol tant que la zone vit (kit de zone persistante, champ 25).
         icone=8072, visuel=30079, palier=3, ecole=OMBRE, portee=P_40, recharge=40000, duree=D_15S,
         ressource=MANA, cout=400,
         cible_sol=True,
         # RAYON 8 m (2026-09-03, etait 10) : RAYON_SINGULARITE dans
         # gen_visuel_demoniste.py doit suivre, sinon le decal ment.
         # L'ECLAT SUR LES ENNEMIS : aucun script. Le visuel 30079 porte un
         # kit d'ETAT (champ 4, gen_visuel_demoniste), et le client pose le
         # modele sur chaque unite sous l'aura — la mecanique des 128 sorts
         # natifs a aura de zone persistante qui marquent leurs cibles.
         effets=[eff(E_ZONE, C_ZONE_POSEE, 180, aura=A_DRAIN, rayon=R_8, periode=1000)]),
    # (Le sort porteur 8600084 a existe le 2026-09-03 puis a ete RETIRE le jour
    # meme : le client suit les visuels par couple lanceur/sort, donc deux
    # lancers simultanes sur deux ennemis n'en affichaient qu'un. L'eclat passe
    # desormais par SMSG_PLAY_SPELL_VISUAL, ou chaque ennemi est sa propre
    # source -- voir spell_papota_singularite. 8600084 est libre a nouveau.)
    sort(8600082, "warlock", "Démonologie", "Summon Demonic Tyrant", "Invocation de tyran démoniaque",
         "Calls a demonic tyrant for $d, strengthening every demon you command.",
         "Appelle un tyran démoniaque pendant $d, qui renforce tous les démons à vos ordres.",
         # Refonte du 2026-09-03 : 30 s (etait 15), modele et icone propres
         # (gen_visuel_demoniste), degats de zone automatiques facon Infernal,
         # et les bonus aux demons portes par les auras auxiliaires 8610000+.
         # Le +25 % de degats au familier est RETIRE du DBC : il ne touchait
         # que le familier actif et doublonnait avec les nouvelles auras.
         icone=8073, visuel=8360, palier=3, ecole=OMBRE, portee=P_SOI, recharge=90000, duree=D_30S,
         ressource=MANA, cout=600,
         # L'INVOCATION EST DANS LE DBC (2026-09-03), plus dans le script.
         # SummonProperties 61 : categorie 1, type 2 — un Guardian SIMPLE,
         # donc SANS le masque CONTROLLABLE_GUARDIAN, donc NON commandable.
         # C'est le gabarit de la goule de Reanimation morbide (26125, montee
         # par le 829 : memes categorie et type, a l'emplacement pres — le 829
         # occupe le 1, celui du totem de feu, dont un demoniste n'a que faire
         # mais qu'on evite par principe).
         # Un essai avec le 1161 (l'Esprit farouche) a ete ecarte : categorie
         # 2, type 1, il donne un CONTROLLABLE_GUARDIAN — commandable comme un
         # familier de chasseur, ce qui n'est pas voulu.
         #
         # La seconde aura mene les 30 secondes et sert de point de MENAGE :
         # son retrait reprend tous les bonus, que la fenetre expire ou que le
         # tyran meure — son IA retire alors cette aura.
         effets=[eff(E_SUMMON, C_SOI, 0, misc=803802, miscB=61),
                 eff(E_AURA, C_SOI, 0, aura=A_DUMMY)],
         script="spell_papota_tyran"),
    # REFONTE TOTALE du 2026-09-03. L'ancien Cataclysme fendait le sol pour
    # 800 points puis laissait brûler une zone ; il visait le sol, portait le
    # visuel des Flammes infernales (joué SUR LE LANCEUR, donc au mauvais
    # endroit) et n'avait jamais été retravaillé.
    sort(8600083, "warlock", "Destruction", "Cataclysm", "Cataclysme",
         "Consumes a soul shard to strike your target for $s1, setting every "
         "foe within $a3 yards ablaze. Your damage rises by $s2% for $d, and "
         "your next two Soul Fire or Chaos Bolt casts become instant.",
         "Consume un fragment d'âme pour frapper votre cible de $s1 points et "
         "embraser tous les adversaires dans un rayon de $a3 mètres. Vos "
         "dégâts augmentent de $s2% pendant $d, et vos deux prochains Feu de "
         "l'âme ou Trait du Chaos deviennent instantanés.",
         aura_en="Damage increased by $s2%.",
         aura_fr="Dégâts augmentés de $s2%.",
         # Art exporté le 2026-09-03 (gen_visuel_demoniste) : icône
         # ability_warlock_shadowfury, et un MISSILE d'écho de trait démoniaque
         # qui part à la main et éclate sur la cible.
         icone=8074, visuel=30087, palier=2, ecole=FEU, portee=P_40,
         recharge=90000, duree=D_12S, vitesse=25,
         ressource=MANA, cout=700,
         # LE FRAGMENT D'ÂME, consommé au lancement (objet 6265).
         reactif=(6265, 1),
         # 1234 = valeur SENTINELLE : « impact massif » n'a pas été chiffré.
         # Le rayon vit sur le TROISIÈME effet, celui que le script lit pour
         # propager l'Immolation — d'où $a1 dans l'infobulle.
         effets=[eff(E_DEGATS, C_ENNEMI, 1234),
                 eff(E_AURA, C_SOI, 10, aura=A_DEGATS_PCT, misc=TOUTES_ECOLES),
                 eff(E_DUMMY, C_ENNEMI, 0, rayon=R_6)],
         script="spell_papota_cataclysme"),

    # ----------------------------------------- auras auxiliaires du tyran ---
    # Posees par spell_papota_tyran a chaque attaque du tyran, retirees quand
    # il meurt ou disparait. Elles ne s'apprennent pas et n'apparaissent nulle
    # part : seule leur infobulle de BIENFAIT (aura_fr) est lue, au survol de
    # l'icone sur le demon.
    #
    # CUMULABLES sans plafond (decision du 2026-09-03) : le tyran frappe une
    # quinzaine de fois en 30 s, donc +30 % de hate au diablotin, +30 % de
    # degats au demon asservi et +75 % aux demons de Xer'thul en fin de
    # fenetre. Les non-cumulables portent pile=1.
    sort(8610000, "warlock", "Démonologie", "Demonic Power: Imp", "Puissance démoniaque : diablotin",
         "", "",
         aura_en="Casting speed increased by $s1%.",
         aura_fr="Vitesse d'incantation augmentée de $s1%.",
         icone=8073, visuel=30083, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=99,
         effets=[eff(E_AURA, C_ALLIE, 2, aura=A_HATE_SORT)]),
    sort(8610001, "warlock", "Démonologie", "Demonic Power: Felhunter", "Puissance démoniaque : chasseur corrompu",
         "", "",
         aura_en="Attacks drain $s1% of the target's maximum mana.",
         aura_fr="Les attaques drainent $s1% du mana maximum de la cible.",
         # 5 % (2026-09-03, etait 2). Le visuel est joue SUR LA CIBLE
         # frappee, donc par le script : une aura ne sait pas viser
         # quelqu'un d'autre que son porteur.
         # PROC : le script fait la brulure lui-meme, faute de quoi il aurait
         # fallu un dixieme identifiant pour le sort declenche.
         icone=8073, visuel=0, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1, proc_flags=0x00000014,
         effets=[eff(E_AURA, C_ALLIE, 5, aura=A_PROC_DECLENCHE)],
         script="spell_papota_tyran_chasseur"),
    sort(8610002, "warlock", "Démonologie", "Demonic Power: Succubus", "Puissance démoniaque : succube",
         "", "",
         aura_en="Attacks have a $s1% chance to seduce the target.",
         aura_fr="Les attaques ont $s1% de chances de charmer la cible.",
         # 6358 = Séduction, le sort NATIF de la succube.
         icone=8073, visuel=0, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1, proc_flags=0x00000014,
         effets=[eff(E_AURA, C_ALLIE, 5, aura=A_PROC_DECLENCHE, declenche=6358)],
         script="spell_papota_tyran_succube"),
    sort(8610003, "warlock", "Démonologie", "Demonic Power: Voidwalker", "Puissance démoniaque : marcheur du vide",
         "", "",
         aura_en="Threat increased by $s1%, and shielded for half its maximum health.",
         aura_fr="Menace augmentée de $s1%, et protégé par un bouclier valant la moitié de ses points de vie maximum.",
         # Le montant du bouclier est calcule par le script : 50 % des PV max
         # du demon, que le DBC ne sait pas exprimer.
         icone=8073, visuel=30084, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1,
         effets=[eff(E_AURA, C_ALLIE, 50, aura=A_MENACE),
                 eff(E_AURA, C_ALLIE, 0, aura=A_ABSORPTION, misc=TOUTES_ECOLES)]),
    sort(8610004, "warlock", "Démonologie", "Demonic Power: Enslaved", "Puissance démoniaque : démon asservi",
         "", "",
         aura_en="Damage increased by $s1%.",
         aura_fr="Dégâts augmentés de $s1%.",
         icone=8073, visuel=30085, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=99,
         effets=[eff(E_AURA, C_ALLIE, 2, aura=A_DEGATS_PCT, misc=TOUTES_ECOLES)]),
    sort(8610005, "warlock", "Démonologie", "Demonic Power: Chained", "Puissance démoniaque : âmes enchaînées",
         "", "",
         aura_en="Damage increased by $s1%.",
         aura_fr="Dégâts augmentés de $s1%.",
         icone=8073, visuel=30085, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=99,
         effets=[eff(E_AURA, C_ALLIE, 5, aura=A_DEGATS_PCT, misc=TOUTES_ECOLES)]),
    sort(8610006, "warlock", "Démonologie", "Demonic Power: Unchained", "Puissance démoniaque : chaînes brisées",
         "", "",
         aura_en="Movement and attack speed increased by $s1%.",
         aura_fr="Vitesse de déplacement et d'attaque augmentées de $s1%.",
         # SEPAREE de la 8610005 parce qu'elle NE CUMULE PAS : dans une meme
         # aura, tous les effets suivraient le nombre de cumuls, et les
         # vitesses grimperaient a +375 % en fin de fenetre.
         icone=8073, visuel=0, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1,
         effets=[eff(E_AURA, C_ALLIE, 25, aura=A_VITESSE),
                 eff(E_AURA, C_ALLIE, 25, aura=A_HATE_MELEE)]),
    sort(8610007, "warlock", "Démonologie", "Demonic Power", "Puissance démoniaque",
         "", "",
         aura_en="Empowered by the demonic tyrant.",
         aura_fr="Renforcé par le tyran démoniaque.",
         # LA TAILLE, a part : elle vaut pour tout demon renforce, y compris
         # ceux dont le bonus cumule — une echelle cumulable les ferait
         # gonfler de 50 % par attaque du tyran.
         icone=8073, visuel=0, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1,
         effets=[eff(E_AURA, C_ALLIE, 50, aura=A_ECHELLE)]),
    # (Les flammes de zone — 8610008 et 8610009, calquees sur l'Immolation de
    # l'Infernal — ont ete RETIREES le 2026-09-03 a la demande : le tyran
    # frappe 15 % plus vite a la place, ce que regle npc_papota_tyran.)
    sort(8610008, "warlock", "Démonologie", "Demonic Power: Felguard", "Puissance démoniaque : gangregarde",
         "", "",
         aura_en="Damage increased by $s1%.",
         aura_fr="Dégâts augmentés de $s1%.",
         icone=8073, visuel=30085, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1,
         effets=[eff(E_AURA, C_ALLIE, 25, aura=A_DEGATS_PCT, misc=TOUTES_ECOLES)]),
    sort(8610009, "warlock", "Démonologie", "Demonic Fury: Felguard", "Fureur démoniaque : gangregarde",
         "", "",
         aura_en="Attack speed increased by $s1%.",
         aura_fr="Vitesse d'attaque augmentée de $s1%.",
         # SEPAREE de la 8610008 : la hate CUMULE, les degats non.
         icone=8073, visuel=30085, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=99,
         effets=[eff(E_AURA, C_ALLIE, 5, aura=A_HATE_MELEE)]),
    # LE DEMONISTE SOUS METAMORPHOSE. Le tyran verifie a CHAQUE coup : la
    # forme peut etre endossee apres son arrivee, et elle est alors prise en
    # compte. Les bonus tombent si elle s'acheve avant lui.
    sort(8610010, "warlock", "Démonologie", "Demonic Fury", "Fureur démoniaque",
         "", "",
         aura_en="Haste and critical strike increased by $s1%.",
         aura_fr="Hâte et coups critiques augmentés de $s1%.",
         icone=8073, visuel=30085, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=99,
         effets=[eff(E_AURA, C_ALLIE, 1, aura=A_HATE_SORT),
                 eff(E_AURA, C_ALLIE, 1, aura=A_CRITIQUE_SORT,
                     misc=TOUTES_ECOLES)]),
    sort(8610011, "warlock", "Démonologie", "Demonic Presence", "Présence démoniaque",
         "", "",
         aura_en="Movement speed increased by $s1%, restoring $s2% of maximum mana each second.",
         aura_fr="Vitesse de déplacement augmentée de $s1%, et $s2% du mana maximum rendu chaque seconde.",
         # NON CUMULABLE : la vitesse et la regeneration ne montent pas avec
         # les coups, contrairement a la hate et au critique ci-dessus.
         icone=8073, visuel=0, palier=1, ecole=OMBRE, portee=P_40,
         duree=D_PERMANENT, pile=1,
         effets=[eff(E_AURA, C_ALLIE, 10, aura=A_VITESSE),
                 eff(E_AURA, C_ALLIE, 1, aura=A_MANA_PCT_PERIODIQUE,
                     periode=1000)]),

    # LES DEUX INCANTATIONS INSTANTANÉES du Cataclysme. Un modificateur CIBLÉ :
    # ADD_PCT_MODIFIER à -100 % sur l'opération « temps d'incantation », restreint
    # à la famille du démoniste et aux masques du Feu de l'âme (0x80) et du
    # Trait du Chaos (0x20000). Le cœur consomme une charge par sort touché et
    # retire l'aura à la dernière — aucun script pour cela.
    #
    # SANS DURÉE (charges seules) : « les deux prochains » ne dit pas de délai,
    # contrairement au +10 % de dégâts qui, lui, tient 12 secondes.
    sort(8610012, "warlock", "Destruction", "Cataclysm", "Cataclysme",
         "", "",
         aura_en="Your next two Soul Fire or Chaos Bolt casts are instant.",
         aura_fr="Vos deux prochains Feu de l'âme ou Trait du Chaos sont instantanés.",
         icone=8074, visuel=0, palier=1, ecole=FEU, portee=P_SOI,
         duree=D_PERMANENT, charges=2,
         famille=FAMILLE_DEMONISTE,
         # LE MASQUE VA SUR L'EFFET, pas sur le sort : c'est
         # EffectSpellClassMask que le cœur lit pour savoir quels sorts un
         # modificateur touche. Posé sur le sort, il ne restreignait RIEN et
         # rendait instantané n'importe quel sort de démoniste (2026-09-04).
         effets=[eff(E_AURA, C_SOI, -100, aura=A_MODIF_PCT,
                     misc=MODIF_INCANTATION,
                     masque=(0, MASQUE_FEU_AME | MASQUE_TRAIT_CHAOS, 0))]),

    # ------------------------------------ auxiliaires de la Charge sauvage ---
    # (Le sprint auxiliaire 8610013 a existe puis a ete RETIRE le jour meme :
    # le sort 8600090 EST desormais le sprint, plus besoin d'un porteur.)
    #
    # LES CINQ SORTS DE FORME. Ils vivent dans la plage auxiliaire faute de
    # place dans le bloc du druide (8600094+ sont pris par d'autres classes),
    # mais ils sont VISIBLES : `grimoire=True` force leur entree au grimoire,
    # sans quoi la regle de plage les en exclurait.
    sort(8610016, "druid", "Farouche", "Bear Leap", "Bond de l'ours",
         "Leap to the targeted spot.", "Bondit à l'endroit ciblé.",
         # SANS VISUEL (demande du 2026-09-03) : le kit 30028 du Bond
         # heroique restait accroche au bond de l'ours. Zero ici ne touche
         # pas le guerrier, qui porte 30028 dans sa propre ligne (8600000).
         # ICONE 3497 : Ability_Mount_PolarBear_Brown, une tete d'ours brun.
         # Les trois icones d'ours du client que le druide porte deja
         # (107 forme d'ours, 1558 et 1559) sont donc laissees tranquilles.
         icone=3497, visuel=0, palier=3, ecole=NATURE, portee=P_40,
         recharge=15000, cible_sol=True, formes=FORME_OURS, grimoire=True,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         effets=[eff(E_DUMMY, C_POINT)],
         script="spell_papota_charge_ours"),
    sort(8610017, "druid", "Farouche", "Shadow Prowler", "Rôdeur de l'ombre",
         "Blink to the targeted spot.", "Translation jusqu'à l'endroit ciblé.",
         # ICONE 836 : Ability_Mount_BlackPanther, une panthere noire — un
         # felin que le druide n'emploie nulle part, et qui dit l'ombre.
         icone=836, visuel=4228, palier=3, ecole=NATURE, portee=P_40,
         recharge=15000, cible_sol=True, formes=FORME_FELIN, grimoire=True,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         # LE CAMOUFLAGE TIENT : un rodeur qui se decouvre en rodant n'aurait
         # pas de sens.
         attributs_ex=ATTR1_GARDE_CAMOUFLAGE,
         effets=[eff(E_DUMMY, C_POINT)],
         script="spell_papota_charge_felin"),
    sort(8610018, "druid", "Farouche", "Traveler's Bound", "Élan du voyageur",
         "Bound forward.", "Vous bondissez droit devant.",
         # ICONE 3149 : celle du Bond heroique, la seule qui montre un saut.
         icone=3149, visuel=4228, palier=3, ecole=NATURE, portee=P_SOI,
         recharge=15000, formes=FORME_VOYAGE, grimoire=True,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         effets=[eff(E_DUMMY, C_SOI)],
         script="spell_papota_charge_voyage"),
    sort(8610019, "druid", "Restauration", "Grove's Call", "Appel du bosquet",
         "Leap to a friendly target.", "Bondit jusqu'à une cible alliée.",
         # VISE UN ALLIE : le seul des six a prendre une unite pour cible,
         # JOUEUR OU PNJ. Le bit 0x8 d'AttributesEx6 est indispensable au
         # second cas : sans lui _IsValidAssistTarget refuse tout PNJ portant
         # UNIT_FLAG_IMMUNE_TO_PC, c'est-a-dire presque tous.
         # ICONE 3088 : Spell_Nature_WispSplodeGreen, demandee telle quelle.
         # VISUEL 30092 : deux kits qui ne portent QUE les sons du Transfert
         # du mage (gen_visuel_druide) — le son change, pas l'image.
         icone=3088, visuel=30092, palier=3, ecole=NATURE, portee=P_40,
         recharge=15000, formes=FORME_ARBRE, grimoire=True,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         attributs_ex6=ATTR6_ASSISTE_IMMUNISES,
         effets=[eff(E_DUMMY, C_ALLIE)],
         script="spell_papota_charge_arbre"),
    sort(8610020, "druid", "Équilibre", "Stellar Return", "Retour stellaire",
         "Return to your most recent star. Changing form dispels your stars.",
         "Vous retournez à votre étoile la plus récente. Changer de forme"
         " dissipe vos étoiles.",
         # SANS RECHARGE, mais refuse s'il n'y a pas d'etoile.
         # ICONE 458 : celle du Rappel astral (556) — un retour a un point
         # pose, ce que le sort fait exactement. L'icone de Pluie d'etoiles
         # passe au compteur 8610024.
         # VISUEL 30097 (gen_visuel_druide.py) : le 4228 de la Forme de felin
         # tel quel, mais son kit d'impact joue le son « Teleport » du
         # Transfert du mage a la place du rugissement (2026-09-06).
         icone=458, visuel=30097, palier=3, ecole=NATURE, portee=P_SOI,
         recharge=0, formes=FORME_SELENIEN, grimoire=True,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         effets=[eff(E_DUMMY, C_SOI)],
         script="spell_papota_charge_selenien"),
    sort(8610014, "druid", "mobilité", "Starfall Trail", "Sillage d'étoiles",
         "", "",
         aura_en="Leaving a trail of stars behind you.",
         aura_fr="Vous laissez un sillage d'étoiles derrière vous.",
         # LE BATTEMENT QUI POSE LES ETOILES. Permanente et SANS ICONE : elle
         # est posee a la connexion sur tout druide qui connait 8600090, et
         # ne fait rien tant qu'il n'est pas en forme de selenien. C'est ce
         # qui evite d'avoir a guetter les changements de forme.
         icone=3930, visuel=0, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_PERMANENT, attributs_ex=0x10000000,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_PERIODIQUE_FACTICE,
                     periode=5000)],
         script="spell_papota_etoiles"),
    # LES ETOILES NE SONT PLUS DES SORTS (2026-09-03, troisieme temps). Trois
    # sorts de couleur et un d'eclat ont vecu ici : ils posaient le modele par
    # une aura a kit d'etat sur la creature-marque, et rien ne s'affichait —
    # ni avec un modele, ni avec un autre. La creature portait l'apparence
    # 802102, InvisibleStalker : le client n'avait aucun corps sur quoi
    # accrocher le kit. La creature EST maintenant l'etoile, sa couleur est
    # une APPARENCE (802103-802105) et la marque de depart une creature de
    # deux secondes (802106). Voir gen_visuel_druide.
    #
    # ----------------------------- auxiliaires de Solstice et Équinoxe ---
    # LA JAUGE VIT DANS DEUX AURAS, une par moitié, de UNE à TROIS piles — et
    # non dans une seule de treize crans (2026-09-04) : au centre le joueur
    # n'en porte aucune, et chaque côté se lit d'un coup d'œil dans la barre
    # de bienfaits, l'icône bleue pour la lune, l'orange pour le soleil.
    # C'est aussi ce que lit la barre du client, sans un mot de réseau.
    sort(8610032, "druid", "Équilibre", "Lunar Gauge", "Jauge lunaire",
         "", "",
         aura_en="One charge per notch toward the moon. Arcane damage pushes"
                 " here.",
         aura_fr="Une charge par cran vers la lune. Ce sont les dégâts des"
                 " Arcanes qui poussent de ce côté.",
         icone=2856, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_PERMANENT, pile=3,
         attributs=ATTR_SANS_ANNULATION, attributs_ex4=ATTR4_INVOLABLE,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),
    sort(8610033, "druid", "Équilibre", "Solar Gauge", "Jauge solaire",
         "", "",
         aura_en="One charge per notch toward the sun. Nature damage pushes"
                 " here.",
         aura_fr="Une charge par cran vers le soleil. Ce sont les dégâts de"
                 " Nature qui poussent de ce côté.",
         icone=3449, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_PERMANENT, pile=3,
         attributs=ATTR_SANS_ANNULATION, attributs_ex4=ATTR4_INVOLABLE,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),
    # LE SOLEIL ATTEINT récompense les ARCANES — l'école opposée à celle qui a
    # poussé jusque-là, la Nature. C'est tout le dessin : on n'est payé qu'en
    # changeant de main. Six secondes (2026-09-04).
    sort(8610029, "druid", "Équilibre", "Solstice", "Solstice",
         "", "",
         aura_en="Arcane damage increased by $s1%, and spell critical"
                 " strike by $s2%.",
         aura_fr="Dégâts des Arcanes augmentés de $s1%, et coups critiques"
                 " des sorts de $s2%.",
         icone=2856, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_6S,
         effets=[eff(E_AURA, C_SOI, 10, aura=A_DEGATS_PCT, misc=ARCANES),
                 eff(E_AURA, C_SOI, 10, aura=A_CRITIQUE_SORT,
                     misc=TOUTES_ECOLES)]),
    # LA LUNE ATTEINTE récompense la NATURE.
    sort(8610030, "druid", "Équilibre", "Equinox", "Équinoxe",
         "", "",
         aura_en="Nature damage increased by $s1%, and haste by $s2%.",
         aura_fr="Dégâts de Nature augmentés de $s1%, et hâte de $s2%.",
         icone=2856, visuel=0, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_6S,
         effets=[eff(E_AURA, C_SOI, 10, aura=A_DEGATS_PCT, misc=NATURE),
                 eff(E_AURA, C_SOI, 10, aura=A_HATE_SORT)]),
    # LE VERROU SE DIT AU CLIENT. Un bout atteint ferme son côté jusqu'à ce
    # que l'autre soit touché ; la barre doit alors éteindre l'astre épuisé,
    # et elle n'a aucun moyen de le déduire — la jauge seule ne dit pas d'où
    # l'on vient, et un rechargement d'interface effacerait ce qu'elle aurait
    # retenu. Deux auras, une par côté, portent donc l'information ; leur
    # infobulle dit aussi au joueur quelle école il lui reste.
    sort(8610034, "druid", "Équilibre", "Spent Sun", "Soleil épuisé",
         "", "",
         aura_en="The sun is spent: only Arcane damage moves the gauge until"
                 " you reach the moon.",
         aura_fr="Le soleil est épuisé : seuls les dégâts des Arcanes"
                 " déplacent la jauge jusqu'à ce que vous atteigniez la lune.",
         icone=3449, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_PERMANENT,
         attributs=ATTR_SANS_ANNULATION, attributs_ex4=ATTR4_INVOLABLE,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),
    sort(8610035, "druid", "Équilibre", "Spent Moon", "Lune épuisée",
         "", "",
         aura_en="The moon is spent: only Nature damage moves the gauge until"
                 " you reach the sun.",
         aura_fr="La lune est épuisée : seuls les dégâts de Nature déplacent"
                 " la jauge jusqu'à ce que vous atteigniez le soleil.",
         icone=2856, visuel=0, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_PERMANENT,
         attributs=ATTR_SANS_ANNULATION, attributs_ex4=ATTR4_INVOLABLE,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),

    # LA FENETRE : cinq secondes pour lancer Solstice et Équinoxe. Le DBC du
    # sort l'exige par CasterAuraSpell, le script la retire a l'emploi. Elle
    # n'est PAS cumulable : fenêtre manquée, tour à refaire.
    sort(8610031, "druid", "Équilibre", "Alignment", "Alignement",
         "", "",
         aura_en="You may cast Solstice and Equinox.",
         aura_fr="Vous pouvez lancer Solstice et Équinoxe.",
         icone=2856, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_5S,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),

    # ------------------------------------- auxiliaire de la Floraison ---
    # LA ZONE DE SOINS, posee par le script aux pieds de la cible. Quinze
    # metres de rayon, comme demande ; la duree et le soin par seconde, eux,
    # n'etaient pas dits — douze secondes et quatre cents points, a revoir si
    # le compte n'y est pas.
    # ------------------------------------- le sort de tank du druide (ours) ---
    # RAGE DU DORMEUR (2026-09-04). Le druide était la seule classe sans sort
    # défensif : en 3.3.5 il n'a que trois arbres, et Combat farouche porte DEUX
    # rôles — le félin et l'ours. Les neuf autres classes ont une spécialisation
    # par rôle ; lui, non. D'où un second nœud Farouche, côté ours.
    #
    # Il ne recoupe aucun des trois autres tanks : le guerrier absorbe, le
    # paladin temporise, le chevalier de la mort frappe en zone. Celui-ci
    # RENVOIE — il récompense d'être frappé par plusieurs ennemis à la fois,
    # ce qui est le terrain de l'ours.
    #
    # Trois effets, dont deux natifs : la réduction (87) et le renvoi (15) sont
    # réglés par le cœur. Le troisième est un DUMMY qui ne sert qu'à porter la
    # fraction rendue en soin, que le script lit ; sans lui il faudrait coder
    # ce pourcentage en dur, hors de portée de l'équilibrage.
    #
    # LES NOMBRES SONT ÉCRITS À LA MAIN, comme ceux des trois autres tanks : le
    # barème ne réécrit que les dégâts directs, les soins directs et les tics
    # (gen_sorts_classes.valeur_mesuree). 250 par coup encaissé sur 10 s contre
    # trois assaillants rend environ 3 750 — l'ordre d'une Frénésie farouche —
    # mais la vraie valeur du sort est ailleurs, dans les 20 % encaissés en
    # moins.
    sort(8610037, "druid", "Farouche", "Rage of the Sleeper",
         "Rage du Dormeur",
         "You take $s1% less damage for $d. Each melee blow you take deals $s2"
         " Nature damage to the attacker and heals you for $s3% of it.",
         "Vous subissez $s1% de dégâts en moins pendant $d. Chaque coup de mêlée"
         " encaissé inflige $s2 points de dégâts de Nature à l'assaillant et"
         " vous soigne de $s3% de ce montant.",
         aura_en="Taking $s1% less damage; melee attackers take $s2 Nature"
                 " damage.",
         aura_fr="Subit $s1% de dégâts en moins ; les assaillants au corps à"
                 " corps subissent $s2 points de dégâts de Nature.",
         grimoire=True, formes=FORME_OURS,
         icone=86, visuel=11149, palier=3, ecole=NATURE, portee=P_SOI,
         recharge=90000, duree=D_10S,
         # 0x28 = TAKEN_MELEE_AUTO_ATTACK | TAKEN_SPELL_MELEE_DMG_CLASS : le
         # coup REÇU, pas le coup donné. Le 0x14 des Frappes fauchantes est son
         # exact miroir.
         proc_flags=0x28,
         effets=[eff(E_AURA, C_SOI, -20, aura=A_DEGATS_SUBIS,
                     misc=TOUTES_ECOLES),
                 eff(E_AURA, C_SOI, 250, aura=A_RENVOI),
                 eff(E_AURA, C_SOI, 50, aura=A_DUMMY)],
         script="spell_papota_rage_dormeur"),

    sort(8610036, "druid", "Restauration", "Flourish", "Floraison",
         "", "",
         aura_en="Healing for $s1 every second.",
         aura_fr="Soigne $s1 points par seconde.",
         parent=8600093,   # la zone de la Floraison
         icone=8076, visuel=30096, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_12S,
         # LA CIBLE B DECIDE DE TOUT pour une aura de zone. DynObjAura::
         # FillTargetMap (SpellAuras.cpp:2901) ne lit QUE `TargetB` : allié
         # sur 29 et 31, quiconque est attaquable sur 88, et — dernier cas,
         # celui du zéro — les cibles d'AoE, c'est-à-dire les ENNEMIS. La
         # zone soignait donc ce qu'elle devait soulager le druide de
         # combattre. La Consécration du paladin marche précisément par ce
         # zéro-là ; il n'y a aucune zone de soin native en 3.3.5 dont
         # s'inspirer, Blizzard n'en pose que trois avec la cible 31.
         effets=[eff(E_ZONE, C_POINT, 400, cibleB=C_ZONE_ALLIES_VISEE,
                     aura=A_SOIN_PERIODIQUE, rayon=R_15, periode=1000)]),

    # --------------------------------- auxiliaires de la Frenesie farouche ---
    # LA PLAIE : une seconde de periode, le montant venant du palier. Six
    # secondes, comme demande.
    sort(8610026, "druid", "Farouche", "Deep Wound", "Plaie profonde",
         "", "",
         aura_en="Bleeding; the damage follows the combo points spent.",
         aura_fr="Saigne ; les dégâts suivent les points de combo dépensés.",
         parent=8600091,   # la plaie de la Frénésie farouche
         icone=2852, visuel=0, palier=1, portee=P_5, duree=D_6S,
         effets=[eff(E_AURA, C_ENNEMI, 0, aura=A_PERIODIQUE, periode=1000)]),
    # LA HATE : la duree n'etait pas dite, on l'a calee sur celle de la plaie.
    sort(8610027, "druid", "Farouche", "Frenzy", "Frénésie",
         "", "",
         aura_en="Haste increased; the gain follows the combo points spent.",
         aura_fr="Hâte augmentée ; le gain suit les points de combo dépensés.",
         icone=2852, visuel=0, palier=1, portee=P_SOI, duree=D_6S,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_HATE_MELEE)]),
    # LE COUP ASSURE : le CALQUE DE SANG-FROID (14177), relevé champ par
    # champ le 2026-09-04. Le talent du voleur fait exactement cela, et il le
    # fait par un MODIFICATEUR DE SORT, pas par une aura de critique de mêlée :
    #
    #   aura 107 (ADD_FLAT_MODIFIER), misc 7 (SPELLMOD_CRITICAL_CHANCE), +100
    #   ProcCharges 1, ProcTypeMask 87376, durée permanente
    #
    # Le modificateur ne touche QUE les capacités — une attaque automatique
    # n'en profite pas, ce que l'aura 52 ne savait pas éviter. Et c'est le
    # masque de proc qui fait tomber la charge, non la machinerie des mods :
    # Unit::isSpellCrit appelle ApplySpellMod sans passer le Spell, donc
    # ApplyModToSpell rend la main et ne consommerait rien.
    #
    # Sang-froid, lui, restreint sa liste par EffectSpellClassMaskA_1/2
    # (0x06020206 / 0x0004010F, relevé sur 14177). On ne restreint PAS : la
    # Frénésie ne promet pas une liste, et un masque de modificateur nul vaut
    # « toutes les capacités de la famille ».
    sort(8610028, "druid", "Farouche", "Sure Strike", "Coup assuré",
         "", "",
         aura_en="Your next ability is a critical strike.",
         aura_fr="Votre prochaine compétence est un coup critique.",
         icone=2852, visuel=0, palier=1, portee=P_SOI, duree=D_PERMANENT,
         charges=1, proc_flags=PROCS_COMPETENCE,
         attributs_ex=ATTR1_GARDE_CAMOUFLAGE,
         attributs_ex3=ATTR3_PROC_DES_PROCS,
         famille=FAMILLE_DRUIDE,
         effets=[eff(E_AURA, C_SOI, 100, aura=A_MODIF_PLAT,
                     misc=MODIF_CRITIQUE)]),

    # LE COMPTEUR, sur le druide : une pile par etoile posee. VISIBLE, lui —
    # c'est tout son objet, dire combien il en reste sans les chercher des
    # yeux. Le script tient la pile a jour a chaque pose et a chaque reprise.
    sort(8610024, "druid", "mobilité", "Stars", "Étoiles",
         "", "",
         # PAS DE NOMBRE dans le texte : aucun jeton d'infobulle ne rend la
         # taille de pile en 3.3.5, et le client l'ecrit deja sur l'icone.
         aura_en="One charge per star standing. Changing form dispels them.",
         aura_fr="Une charge par étoile posée. Changer de forme les dissipe.",
         icone=2854, visuel=0, palier=1, ecole=NATURE, portee=P_SOI,
         duree=D_PERMANENT, pile=3,
         effets=[eff(E_AURA, C_SOI, 0, aura=A_DUMMY)]),

    # ------------------------------------------------------------ druide ---
    # REFONTE DU 2026-09-03, deuxieme temps : SIX SORTS, un par forme, chacun
    # exigeant la sienne par `ShapeshiftMask`. Un aiguillage unique imposait
    # un reticule a toutes les formes — l'ours et le felin se visent chez
    # leurs proprietaires, et un reticule ne peut pas etre conditionnel.
    # Separes, chacun porte SON ciblage. La barre d'action du druide changeant
    # avec la forme, chaque forme montre son bouton.
    #
    # 8600090 reste le sort du SPHERIER : c'est lui que le noeud accorde, et
    # papota_sillage_joueur donne les cinq autres a qui le connait.
    #
    # UN NOM PAR SORT (2026-09-03) : six « Charge sauvage » au grimoire ne se
    # distinguaient pas les unes des autres. Chacune porte desormais le nom de
    # sa forme — Petite foulee, Bond de l'ours, Foulee feline, Elan du
    # voyageur, Appel du bosquet, Retour stellaire — son icone, et l'onglet de
    # la specialisation qui possede sa forme (l'ours, le felin et la forme de
    # voyage sont farouches : leurs sorts natifs sont tous sur la ligne 134).
    #
    # LA RECHARGE n'est PAS partagee entre les six : chacun a la sienne, le
    # selenien excepte (« pas de CD »). Un druide peut donc sprinter puis
    # bondir en changeant de forme — signale, la mutualisation demanderait une
    # categorie de recharge et une ligne de SpellCategory.dbc.
    sort(8600090, "druid", "Général", "Light Stride", "Petite foulée",
         "Increases movement speed by $s1% for $d. Humanoid form only: cast"
         " in any other form, it returns you to humanoid form first.",
         "Augmente la vitesse de déplacement de $s1% pendant $d. Uniquement"
         " sous forme humaine : lancé sous une autre forme, il vous y ramène"
         " d'abord.",
         aura_en="Movement speed increased by $s1%.",
         aura_fr="Vitesse de déplacement augmentée de $s1%.",
         # LE VISUEL DU SPRINT DU VOLEUR (2026-09-03) : SpellVisual 6, releve
         # sur le sort 2983 — kit d'incantation 395 de son 3339, kit d'etat
         # 697. On reprend le visuel entier, le son y est.
         #
         # PLUS D'ATTR_HORS_FORME : le sort se lance desormais sous TOUTE
         # forme, et son script rend d'abord la forme humaine. L'attribut,
         # lui, refusait le lancement au lieu de detransformer.
         #
         # « Général » n'est pas une ligne de competence : c'est l'onglet ou
         # le client range ce qu'il ne sait rattacher a aucune, donc pas de
         # ligne de SkillLineAbility pour ce sort (voir gen_sla_classes).
         # ICONE 516 : Ability_Rogue_Sprint, une silhouette qui court —
         # et c'est deja du voleur que vient le visuel du sort.
         icone=516, visuel=6, palier=3, ecole=NATURE, portee=P_SOI,
         recharge=15000, duree=D_20S,
         attributs=ATTR_CAPACITE | ATTR_FOURREAU_INTACT,
         effets=[eff(E_AURA, C_SOI, 15, aura=A_VITESSE)],
         script="spell_papota_petite_foulee"),
    # CINQ PALIERS (2026-09-04) : la force du coup suit les points de combo,
    # qui sont CONSOMMES — c'est un coup de finition, comme tous ceux qui les
    # lisent. Le DBC ne sait pas se brancher sur eux : le sort ne porte que
    # l'effet de degats, et spell_papota_frenesie en fixe le montant puis pose
    # ce que le palier ajoute (8610026 la plaie, 8610027 la hate, 8610028 le
    # coup assure).
    sort(8600091, "druid", "Farouche", "Feral Frenzy", "Frénésie farouche",
         "Finishing move that causes damage per combo point, then bleeding"
         " for 6 sec. At 5 points, your next ability is a critical strike:"
         "\n\n"
         "    1 point  : 700 damage.\n"
         "    2 points: 800 damage, 120 per sec.\n"
         "    3 points: 1000 damage, 160 per sec, 5% haste.\n"
         "    4 points: 1100 damage, 200 per sec, 7% haste, 10 energy.\n"
         "    5 points: 1200 damage, 240 per sec, 10% haste, 15 energy.",
         "Coup de finition qui inflige des dégâts par point de combo, puis"
         " fait saigner pendant 6 sec. À 5 points, votre prochaine compétence"
         " est un coup critique :\n\n"
         "    1 point  : 700 points.\n"
         "    2 points : 800 points, 120 par sec.\n"
         "    3 points : 1000 points, 160 par sec, 5% de hâte.\n"
         "    4 points : 1100 points, 200 par sec, 7% de hâte, 10 énergie.\n"
         "    5 points : 1200 points, 240 par sec, 10% de hâte,"
         " 15 énergie.",
         icone=2852, visuel=3941, palier=2, portee=P_5, recharge=45000,
         ressource=ENERGIE, cout=50,
         # UNIQUEMENT EN FELIN : c'est la seule forme qui ait de l'energie et
         # des points de combo, le sort n'a de sens dans aucune autre.
         formes=FORME_FELIN,
         effets=[eff(E_DEGATS, C_ENNEMI, 700)],
         script="spell_papota_frenesie"),
    # REFONTE DU 2026-09-04 : la Pleine lune et son cycle a trois phases ont
    # laisse place a une JAUGE, sur le modele de l'Eclipse de Cataclysm. Le
    # sort n'est plus qu'une frappe, rationnee par la jauge : le DBC exige
    # l'aura de fenetre (CasterAuraSpell), toute la mecanique vit dans
    # papota_solstice_joueur.
    sort(8600092, "druid", "Équilibre", "Solstice and Equinox",
         "Solstice et Équinoxe",
         "Strikes for $s1 arcane damage. Usable only in the few seconds that"
         " follow each time your celestial gauge reaches one of its ends.",
         "Frappe pour $s1 points de dégâts des Arcanes. Utilisable seulement"
         " dans les quelques secondes qui suivent chaque fois que votre jauge"
         " céleste atteint l'une de ses extrémités.",
         # ICONE ET VISUEL IMPORTES (2026-09-04) : icone 8075, visuel 30095
         # — l impact lunaire, avec son son (gen_visuel_druide).
         icone=8075, visuel=30095, palier=3, ecole=ARCANES, portee=P_40,
         cast=I_INSTANT, recharge=0, ressource=MANA, cout_pct=70,
         formes=FORME_SELENIEN, aura_requise=8610031,
         effets=[eff(E_DEGATS, C_ENNEMI, 2500)]),
    # REFONTE DU 2026-09-04 : la rallonge de huit secondes a laissé place a
    # une REMISE A NEUF. Tous les soins sur la duree presents sur la cible
    # repartent a leur duree maximale, QUEL QUE SOIT LEUR LANCEUR — ceux de
    # « Liora, Berceuse des Racines » (8140110) compris —, et une zone de
    # soins s'ouvre sous ses pieds.
    sort(8600093, "druid", "Restauration", "Flourish", "Floraison",
         "Every heal over time on the target is restored to its full"
         " duration, and a healing bloom opens at its feet.",
         "Tous les soins sur la durée présents sur la cible repartent à leur"
         " durée maximale, et une floraison de soins s'ouvre sous ses pieds.",
         # ICONE ET SON IMPORTES (2026-09-04). Le visuel vit sur la zone,
         # pas sur le sort : c'est elle qu'on voit.
         icone=8076, visuel=0, palier=2, ecole=NATURE, portee=P_40,
         recharge=90000, ressource=MANA, cout=400,
         effets=[eff(E_DUMMY, C_ALLIE)],
         script="spell_papota_floraison"),

    # La frappe FAUCHÉE : l'écho des Frappes fauchantes (8600001). Jamais
    # apprise (SANS_ONGLET de gen_sla_classes.py). Le montant est TOUJOURS
    # écrasé par le script (CastCustomSpell, les dégâts réels du coup) —
    # 1234 = sentinelle. AJOUTÉE EN FIN DE LISTE : les index SLA des sorts
    # existants ne doivent jamais glisser.
    sort(8600055, "warrior", "Armes", "Sweeping Blow", "Frappe fauchée",
         "Struck by a sweeping blow.", "Frappé par un coup fauché.",
         parent=8600001,   # l'écho des Frappes fauchantes
         icone=565, visuel=0, palier=1, portee=P_8,
         attributs_ex=0x100,
         effets=[eff(E_DEGATS, C_ENNEMI, 1234)]),

    # DUPLICATA du « Meteor » PNJ natif 28884 (demande du 2026-08-31), champ
    # à champ : cast 1,5 s (index 16), portée 20 m (index 3), réticule au
    # sol, dégâts de feu en zone de 8 m, visuel de chute 7479, icône 184.
    # DIAGNOSTIC du « pas de dégâts aux monstres » : l'original porte
    # AttributesEx3 = 0x100 — SPELL_ATTR3_ONLY_ON_PLAYER, « ne peut cibler
    # que des joueurs » (un sort de boss) : le cœur filtre les non-joueurs
    # de sa zone. Le duplicata ne porte pas ce drapeau. Deux écarts assumés :
    # dégâts aplatis à 14500 (l'original tire 13775-15225, notre écrivain
    # force DieSides=1) ; le PARTAGE des dégâts entre cibles est un
    # comportement serveur attaché à l'id 28884 (liste des attributs custom
    # du cœur), non hérité — chaque cible prend le plein montant. Jamais
    # appris (SANS_ONGLET) ; en fin de liste, les index SLA ne glissent pas.
    sort(8600056, "mage", "Feu", "Meteor", "Météore",
         "Deals $m1 to $M1 Fire damage to enemies within $a1 yards of the "
         "impact and liquefies them: $8600057s1 Fire damage per second "
         "for $8600057d.",
         "Inflige $m1 à $M1 points de dégâts de Feu aux ennemis à moins de "
         "$a1 mètres de l'impact et les liquéfie : $8600057s1 points de "
         "dégâts de Feu par seconde pendant $8600057d.",
         # Réglages du 2026-08-31 : portée 40 m, recharge 45 s. COÛT au
         # RÉGIME DE BLIZZARD (demande du jour) : un pourcentage du mana de
         # BASE (GetCreateMana, constante de classe et de niveau : 2843 pour
         # un mage 80 — l'équipement et l'intellect n'y changent rien).
         # Porté à 80 % le 2026-08-31 (~2274 points au niveau 80) — au-dessus
         # du Blizzard rang max, qui prend 74 %.
         # Dégâts en FOURCHETTE 2500-3200
         # (des=701). Le dot « Liquéfaction » est le sort 8600057, déclenché
         # sur chaque cible de la zone (E_TRIGGER) ; l'infobulle lit ses
         # valeurs par les jetons inter-sorts $8600057s1/$8600057d (le
         # procédé du 28884 natif, ${$57964m1...}).
         # Famille MAGE + masque du Choc de flammes (0x4, relevé 42926) :
         # les talents Feu ciblés (crit de « Monde en flammes », spellmods)
         # attrapent le sort ; les bonus d'école s'appliquaient déjà.
         # classe_degats=1 (magie) : SANS LUI, AUCUN CRITIQUE POSSIBLE —
         # Unit::SpellDoneCritChance ne calcule rien en classe « aucune »
         # (relevé du 2026-08-31, le défaut de tous nos sorts customs).
         icone=8056, visuel=7479, palier=1, ecole=FEU, cast=I_1S5, portee=P_40,
         recharge=45000, ressource=MANA, cout_pct=80,
         # blocage=1 (SILENCE) : le sort tombe sous le silence et les
         # contresorts d'école, comme tout sort de mage (demande du
         # 2026-08-31 ; relevé 42926, qui porte 1).
         famille=3, famille_masque=(0x4, 0, 0), classe_degats=1, blocage=1,
         cible_sol=True,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 2500, rayon=R_8, des=701),
                 eff(E_TRIGGER, C_ZONE_VISEE, rayon=R_8, declenche=8600057)]),

    # Le dot du Météore (28884) : « Liquéfaction », 350 points de Feu par
    # seconde pendant 8 s — sort séparé pour porter son NOM sur la barre de
    # débuff. Déclenché par l'effet 2 du 8600056 ; jamais appris
    # (SANS_ONGLET) ; en fin de liste, les index SLA ne glissent pas.
    sort(8600057, "mage", "Feu", "Liquefaction", "Liquéfaction",
         "Liquefied: $s1 Fire damage per second.",
         "Liquéfié : $s1 points de dégâts de Feu par seconde.",
         aura_en="Liquefied: $s1 Fire damage per second.",
         aura_fr="Liquéfié : $s1 points de dégâts de Feu par seconde.",
         # Visuel 46 = Immolation (2026-08-31) : l'état « lourdement
         # enflammé » sur la cible — même mécanique (dot de feu), la règle
         # des emprunts de débuff. Famille MAGE + masques de la Bombe
         # vivante (relevé 55360) : les talents Feu ciblés attrapent le dot.
         # classe_degats=1 (magie) comme le porteur ; un dot ne critique
         # cependant qu'avec les talents qui l'y autorisent (règle 3.3.5).
         parent=8600056,   # la flaque du Météore
         icone=8057, visuel=46, palier=1, ecole=FEU, portee=P_100, duree=D_8S,
         famille=3, famille_masque=(0, 0x20000, 0x8), classe_degats=1,
         effets=[eff(E_AURA, C_ENNEMI, 350, aura=A_PERIODIQUE, periode=1000)]),

    # Le témoin du Miroitement en deux temps (2026-08-31) : porté 5 s par le
    # mage après le premier saut, il autorise le retour et — À SON
    # EXPIRATION SEULEMENT — déclenche la recharge et efface la marque.
    # Jamais appris (SANS_ONGLET) ; en fin de liste, les index SLA ne
    # glissent pas.
    sort(8600058, "mage", "mobilité", "Shimmer", "Miroitement",
         "You can shimmer back to your mark.",
         "Vous pouvez revenir par miroitement jusqu'à votre marque.",
         aura_en="You can shimmer back to your mark.",
         aura_fr="Vous pouvez revenir par miroitement jusqu'à votre marque.",
         icone=8058, visuel=0, palier=1, ecole=ARCANES, portee=P_SOI,
         duree=D_5S,
         effets=[eff(E_AURA, C_SOI, 1, aura=A_DUMMY)],
         script="spell_papota_miroitement_temoin"),

    # --- la meute de la Ruée sauvage (8600021), montage du 2026-08-31 -------
    # Le SAIGNEMENT que chaque bête invoquée applique à ses coups : cumulable
    # (jusqu'à 10 piles, chacune vivant sa propre durée), 15 s, sans temps de
    # rechargement interne — c'est la demande. Jamais appris (SANS_ONGLET).
    sort(8600094, "hunter", "Maîtrise des bêtes", "Savage Bleed",
         "Morsure sanglante",
         "Bleeding for $s1 damage every $t1 sec.",
         "Saigne : $s1 points de dégâts toutes les $t1 sec.",
         aura_en="Bleeding for $s1 damage every $t1 sec.",
         aura_fr="Saigne : $s1 points de dégâts toutes les $t1 sec.",
         # 120 -> 24 (divisé par cinq comme les coups), puis DOUBLÉ à 48 par
         # seconde le même jour (2026-08-31).
         parent=8600021,   # le saignement de la Ruée sauvage
         icone=255, visuel=372, palier=1, portee=P_8, duree=D_15S, pile=10,
         classe_degats=1,
         effets=[eff(E_AURA, C_ENNEMI, 48, aura=A_PERIODIQUE, periode=1000)]),

    # L'aura POSÉE SUR LES BÊTES par le script : chaque coup de mêlée
    # (ProcTypeMask 0x14 = autos + techniques) déclenche le saignement, à
    # 101 % de chances et sans charges — donc à TOUS les coups. Invisible
    # (pas d'icône) et jamais apprise.
    sort(8600095, "hunter", "Maîtrise des bêtes", "Pack Frenzy",
         "Frénésie de la meute",
         "Melee strikes cause Savage Bleed.",
         "Les coups de mêlée provoquent une morsure sanglante.",
         icone=255, visuel=0, palier=1, portee=P_SOI, duree=D_30S,
         attributs_ex=0x10000000,   # NO_AURA_ICON : rien dans la barre
         proc_flags=0x14,
         effets=[eff(E_AURA, C_SOI, 1, aura=A_PROC_DECLENCHE,
                     declenche=8600094)]),

    # La SALVE des Tirs consécutifs (8600022) : un vrai tir, lancé à chaque
    # tic de la canalisation — c'est LUI qui porte les dégâts, le missile et
    # l'animation d'arme (attribut 0x2 + classe de dégâts « distance » +
    # vitesse, la signature relevée sur le Tir des arcanes 3044). Jamais
    # appris (SANS_ONGLET).
    sort(8600096, "hunter", "Précision", "Consecutive Shot", "Tir consécutif",
         "A piercing shot for $s1 damage.",
         "Un trait perforant pour $s1 points de dégâts.",
         # Chaque tir FICHE un trait dans la cible (2026-08-31) : l'aura
         # cumulable vit sur ce sort — chaque salve la rafraîchit et empile.
         # À son expiration, le script fait DÉTONER les traits (8600098).
         parent=8600022,   # une salve des Tirs consécutifs
         icone=8060, visuel=3299, palier=1, portee=P_40, duree=D_8S, pile=20,
         attributs=0x2, classe_degats=3, arme=(2, 0x4000C), vitesse=40,
         aura_en="Pierced: the shafts will detonate.",
         aura_fr="Transpercé : les traits vont détoner.",
         effets=[eff(E_DEGATS, C_ENNEMI, 350),
                 eff(E_AURA, C_ENNEMI, 0, aura=A_DUMMY)],
         script="spell_papota_traits_fiches"),

    # LA DÉTONATION : les traits fichés explosent à l'expiration du cumul,
    # dégâts d'arcanes dans 8 m — montant ÉCRASÉ par le script (sentinelle
    # 1234, il vaut la base multipliée par le nombre de cumuls). Visuel
    # 30043 : l'impact de l'Explosion des arcanes native (kit 1005, relevé
    # du visuel 965). Jamais appris (SANS_ONGLET).
    sort(8600098, "hunter", "Précision", "Piercing Detonation",
         "Détonation perforante",
         "The lodged shafts detonate for $s1 Arcane damage within $a1 yards.",
         "Les traits fichés détonent pour $s1 points de dégâts des Arcanes "
         "dans un rayon de $a1 mètres.",
         # Ciblage : zone au POINT DE LA CIBLE (16 + destination 63), et non
         # C_ZONE_ENNEMIS (15) — celui-ci centre la nova sur le LANCEUR,
         # d'où « aucun effet visible à l'expiration » (2026-08-31). C'est le
         # patron déjà éprouvé sur le Shunpo (effet 5 + destination 63).
         parent=8600022,   # la détonation des Tirs consécutifs
         icone=537, visuel=30043, palier=1, ecole=ARCANES, portee=P_40,
         classe_degats=1,
         effets=[eff(E_DEGATS, C_ZONE_VISEE, 1234, rayon=R_8,
                     cibleB=C_DEST_CIBLE)]),

    # La protection de Mot de pouvoir : Barrière (8600042) : posée par le
    # dôme aux alliés présents, retirée dès qu'ils sortent. Le montant est
    # ÉCRASÉ par le script (la réserve commune restante) — 1234 sentinelle.
    # Le visuel 30046 ne porte que le kit d'état sacré (Protection divine,
    # natif) : un effet sacré, et surtout PAS celui de Mot de pouvoir :
    # Bouclier. Jamais apprise (SANS_ONGLET).
    sort(8600059, "priest", "Discipline", "Power Word: Barrier",
         "Mot de pouvoir : Barrière",
         "Sheltered by the barrier: physical damage taken reduced by $s1%.",
         "Abrité par la barrière : dégâts physiques subis réduits de $s1%.",
         aura_en="Physical damage taken reduced by $s1%.",
         aura_fr="Dégâts physiques subis réduits de $s1%.",
         # Cible ALLIÉ et portée 30 m (2026-09-01) : en C_SOI/P_SOI, l'aura
         # se posait sur LE DÔME qui la lançait, jamais sur les protégés —
         # « le joueur ne reçoit aucune aura ni visuel ».
         # Durée PERMANENTE : ce n'est pas un bienfait qui s'écoule mais un
         # INDICATEUR — on l'a tant qu'on est sous le dôme, on la perd en
         # sortant ou quand la barrière tombe (le script s'en charge).
         icone=3837, visuel=30046, palier=1, ecole=SACRE, portee=P_30,
         duree=D_PERMANENT,
         # Changement de mécanique du 2026-09-01 : plus de réserve absorbée,
         # mais une RÉDUCTION EN POURCENTAGE des dégâts PHYSIQUES (misc = 1,
         # le masque de l'école physique). -50 % est une valeur d'attente, à
         # trancher à l'équilibrage. L'aura est désormais du DBC pur : plus
         # de script d'absorption.
         effets=[eff(E_AURA, C_ALLIE, -50, aura=A_DEGATS_SUBIS, misc=1)]),

    # Le bienfait de la Plume angélique (8600040) : posé par la plume au
    # premier allié qui la touche. Jamais appris (SANS_ONGLET).
    sort(8600097, "priest", "mobilité", "Angelic Feather", "Plume angélique",
         "Speed increased by $s1%.",
         "Vitesse augmentée de $s1%.",
         aura_en="Speed increased by $s1%.",
         aura_fr="Vitesse augmentée de $s1%.",
         # Visuel 6 = LE SPRINT DU VOLEUR (relevé 2983) : son kit de lancer
         # porte l'effet ET le son (3339), son kit d'état habille le porteur
         # tant que l'aura tient. Réutilisé tel quel (2026-08-31).
         # Réglages du 2026-08-31 : +60 % pendant 3 s (était +40 % / 6 s).
         icone=8061, visuel=6, palier=1, ecole=SACRE, portee=P_SOI,
         duree=D_3S,
         effets=[eff(E_AURA, C_SOI, 60, aura=A_VITESSE)]),

    # LES TROIS CHARGES de la Plume angélique (2026-08-31) : 3.3.5 n'a pas
    # de système de charges. Modèle MODERNE, où CHAQUE plume posée programme
    # son propre retour 20 s plus tard (et non un rechargement groupé) : les
    # piles de cette aura comptent les plumes RESTANTES, elle n'existe que
    # tant qu'il en manque — d'où la durée PERMANENTE, le script la retirant
    # dès la réserve pleine. Jamais apprise (SANS_ONGLET).
    sort(8600099, "priest", "mobilité", "Angelic Feathers", "Plumes en réserve",
         "Feathers ready to be placed.",
         "Plumes prêtes à être posées.",
         aura_en="Feathers ready to be placed.",
         aura_fr="Plumes prêtes à être posées.",
         icone=8061, visuel=0, palier=1, ecole=SACRE, portee=P_SOI,
         duree=D_PERMANENT, pile=3,
         effets=[eff(E_AURA, C_SOI, 1, aura=A_DUMMY)]),

    # LES DEUX ONDES DU HALO (8600043, 2026-09-01). Deux sorts et non un
    # seul : un sort n'a QU'UN visuel, or les touchés doivent recevoir un
    # impact différent selon leur camp — impact de dégâts sacrés (kit natif
    # 291, celui du Châtiment) pour les ennemis, impact de soin sacré (kit
    # 442, celui des Soins inférieurs) pour les alliés.
    # CIBLE UNIQUE et non plus zone (2026-09-01) : l'onde ne frappe plus la
    # zone d'un bloc, elle SUIT L'ANNEAU — l'IA de l'anneau lance le sort sur
    # chaque cible à l'instant précis où le front l'atteint, et dose le
    # montant au passage. Portée 100 m parce que le prêtre peut s'être
    # éloigné de son halo. Jamais appris (SANS_ONGLET).
    sort(8600044, "priest", "Sacré", "Halo", "Halo",
         "Sears enemies for $s1.",
         "Brûle les ennemis de $s1 points.",
         part=0.5,   # deux ondes se partagent le compte
         parent=8600043,   # la première onde du Halo
         icone=8063, visuel=30048, palier=1, ecole=SACRE, portee=P_100,
         classe_degats=1,
         effets=[eff(E_DEGATS, C_ENNEMI, 700)]),
    sort(8600045, "priest", "Sacré", "Halo", "Halo",
         "Heals allies for $s1.",
         "Soigne les alliés de $s1 points.",
         part=0.5,   # deux ondes se partagent le compte
         parent=8600043,   # la seconde onde du Halo
         icone=8063, visuel=30049, palier=1, ecole=SACRE, portee=P_100,
         classe_degats=1,
         effets=[eff(E_SOIN, C_ALLIE, 700)]),

    # (Les deux pièces auxiliaires de la Marche spectrale — 8600046, les deux
    # secondes d'incantation du second temps, et 8600047, le jeton qui
    # l'ouvrait — sont RETIRÉES le 2026-09-01 : le sort tient désormais en un
    # seul lancer, il porte lui-même son incantation et sa recharge.)

    # LA LEVÉE D'UNE GOULE (Apocalypse, 8600051 — 2026-09-02). Un sort
    # PORTEUR DE VISUEL et rien d'autre : le chevalier le lance sur chaque
    # goule, et le cœur joue l'impact de Réanimation morbide dessus. Envoyé
    # en paquet brut (SendPlaySpellVisual) sur une créature à peine invoquée
    # il ne rendait rien — le client n'a pas encore la créature. Jamais
    # appris (SANS_ONGLET).
    # Visuel 9311 : celui de Réanimation morbide LUI-MÊME (relevé sur son
    # sort d'invocation 46585/52150). Le sort ne fait QUE porter ce visuel,
    # que le chevalier joue sur chaque goule levée.
    # (Le passage à un vrai SPELL_EFFECT_SUMMON, essayé le 2026-09-02 pour
    # coller au natif — qui lève un GARDIEN par SummonProperties là où nous
    # posons une invocation sauvage — n'a rien changé à l'artefact d'ombre
    # et est retiré. Le générateur garde le support d'EffectMiscValueB,
    # ajouté à cette occasion.)
    sort(8600048, "deathknight", "Impie", "Apocalypse", "Apocalypse",
         "A ghoul claws its way out.", "Une goule s'extirpe du sol.",
         icone=8064, visuel=9311, palier=1, ecole=OMBRE, portee=P_40,
         effets=[eff(E_DUMMY, C_ALLIE)]),
]


CLASSES_FR = {
    "warrior": "Guerrier", "paladin": "Paladin", "hunter": "Chasseur",
    "rogue": "Voleur", "priest": "Prêtre", "deathknight": "Chevalier de la mort",
    "shaman": "Chaman", "mage": "Mage", "warlock": "Démoniste", "druid": "Druide",
}

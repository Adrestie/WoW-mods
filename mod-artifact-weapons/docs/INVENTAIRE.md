# Inventaire — armes artefacts de Papota_hard

Relevé du 2026-09-28. **Identifiants renumérotés le 2026-09-29 dans la tranche 84 du registre des plages**
(`ID_RANGES.md`, à la racine du dépôt) : les numéros de ce document sont les nouveaux. Hors numéros et hors
corrections du §7, les fichiers de `data/` et `src/` sont des extraits fidèles.

## 1. Sources lues

| Source | Emplacement |
|---|---|
| Base monde | `acore_world_hard` |
| Base personnages et comptes | `acore_characters_hard`, `acore_auth_hard` (relevé seul, rien d'extrait) |
| DBC du serveur | `D:\Serveur WoW\server_hard\bin\RelWithDebInfo\Data\dbc` |
| Client | le client WoW Papota 1.2.0 (dossier `Data`), chaîne effective (patch-a, b, c, z), comparée aux seules archives Blizzard du même client |
| C++ | `D:\Serveur WoW\azerothcore-wotlk\modules\mod-papota-spells` |

Méthode : balayage de **toutes** les colonnes numériques des trois bases `_hard` à la recherche des identifiants
des armes, puis suivi des renvois (objet → affichage → modèle → textures et vues ; sort → visuel → kit → effet → modèle).
Les outils sont dans `E:\atelier\artifact-weapons`.

## 2. Ce qui a été extrait, et où

| Dossier | Contenu |
|---|---|
| `data/sql/db-world/base/` | 21 fichiers `artifact_weapons_NN_<table>.sql`, un par table, chacun `DELETE` + `INSERT` de la même clause (rangés et préfixés le 2026-09-29 pour l'updater du cœur) |
| `data/sql/historique/` | les 4 SQL de recalibrage du 2026-09-04, appliqués par l'updater le 2026-09-05 (gardés pour mémoire) |
| `data/dbc/client/` | lignes des armes dans les DBC du client, en DBC réduits |
| `data/dbc/serveur/` | copie 1:1 de `data/dbc/client/` : le client fait foi |
| `data/client/` | 263 fichiers ajoutés par `patch-z` (absents des archives Blizzard) |
| `data/client-surcharges/` | 12 fichiers Blizzard **remplacés** par patch-z ou patch-c (voir §6) |
| `src/` | `papota_spells.cpp` et `MP_loader.cpp`, copie exacte de mod-papota-spells |
| `docs/historique/` | les deux inventaires texte du 2026-09-04 |

Nombre de lignes par fichier SQL :

| Fichier | Lignes |
|---|---|
| `01_item_template.sql` | 65 |
| `02_spell_dbc.sql` | 143 |
| `03_spell_proc.sql` | 47 |
| `04_spell_bonus_data.sql` | 34 |
| `05_spell_custom_attr.sql` | 5 |
| `06_spell_script_names.sql` | 12 |
| `07_spell_cooldown_overrides.sql` | 2 |
| `08_spell_jump_distance.sql` | 1 |
| `09_creature_template.sql` | 37 |
| `10_creature_template_model.sql` | 37 |
| `11_creature_text.sql` | 1 |
| `12_creature.sql` | 33 |
| `15_quest_template.sql` | 32 |
| `16_quest_template_addon.sql` | 31 |
| `18_quest_offer_reward.sql` | 32 |
| `19_creature_questender.sql` | 32 |
| `20_page_text.sql` | 1 |
| `21_gameobject_template.sql` | 1 |
| `22_reference_loot_template.sql` | 32 |
| `23_creature_loot_template.sql` | 36 |
| `24_gameobject_loot_template.sql` | 12 |

## 3. Identifiants employés, à plat

| Espace | Table ou DBC | Identifiants | Nombre |
|---|---|---|---|
| Objets (armes et munitions) | `item_template`, `Item.dbc` | 84002-84034 | 33 |
| Objets (livres de quête) | `item_template`, `Item.dbc` | 84102-84132, 84134 | 32 |
| Affichages d'objets | `ItemDisplayInfo.dbc` | 84002-84032, 84034 | 32 |
| Sorts | `spell_dbc`, `Spell.dbc` | 84300-84943, 20 numéros par arme (§4) | 143 |
| Visuels de sorts | `SpellVisual.dbc` | 84001-84015 | 15 |
| Kits de visuels | `SpellVisualKit.dbc` | 84001-84016 | 16 |
| Effets de visuels | `SpellVisualEffectName.dbc` | 84001-84006 | 6 |
| Attaches de modèles | `SpellVisualKitModelAttach.dbc` | 84001-84002 | 2 |
| Créatures | `creature_template` | 84002-84032, 84034, 84200-84204 | 37 |
| Apparitions | `creature.guid` | 8400000, 8400001-8400005, 8400006, 8400007-8400020, 8400021-8400032 | 33 |
| Quêtes | `quest_template` | 84002-84032, 84034 | 32 |
| Page de texte | `page_text` | 84019 | 1 |
| Objet du monde | `gameobject_template` | 84019 | 1 |
| Affichage d'objet du monde | `GameObjectDisplayInfo.dbc` | 84019 (inexistant, §7) | 0 |
| Butin de référence | `reference_loot_template` | 84000 | 32 lignes |
| Rattachements du butin | `creature_loot_template`, `gameobject_loot_template` | lignes `Reference = 84000` ajoutées à 36 tables de boss et 12 de coffres Blizzard de la Citadelle de la Couronne de glace, toutes difficultés, chance de 7 à 100 % | 48 |
| Scripts de sorts | `spell_script_names` | 12 noms, §5 | 12 |
| IA de créature | `creature_template.ScriptName` | `npc_xerthul_demon` (84200-84204) | 1 |

Les identifiants se recoupent entre espaces : **84002-84034** désigne à la fois des objets, des créatures,
des quêtes, des affichages, une page et un objet du monde ; **84000** est à la fois la référence
de butin des livres et la créature « Sac de frappe », sans lien avec les armes.

## 4. Les armes, une par une

| Objet | Nom | Affichage | Quête | PNJ de quête | Livre | Sorts portés |
|---|---|---|---|---|---|---|
| 84002 | Ezh’ra, Voix du Tonnerre | 84002 | 84002 | 84002 | 84102 | 84301 (équipé), 84304 (équipé) |
| 84003 | Nairūn, Souffle des Anciens | 84003 | 84003 | 84003 | 84103 | 84320 (équipé), 84325 (équipé) |
| 84004 | Kelrah, Harmonie des Éléments | 84004 | 84004 | 84004 | 84104 | 84340 (équipé) |
| 84005 | Drokhan, Poing des Tempêtes | 84005 | 84005 | 84005 | 84105 | 84361 (équipé) |
| 84006 | Mak'hor, Frappe des Esprits | 84006 | 84006 | 84006 | 84106 | 84381 (équipé) |
| 84007 | Kael’Thorr, Hurlement Sanglant | 84007 | 84007 | 84007 | 84107 | 84400 (équipé), 84402 (équipé), 84404 (utilisation) |
| 84008 | Xer’thul, Maître des Chaînes | 84008 | 84008 | 84008 | 84108 | 84421 (équipé), 84422 (équipé), 84427 (équipé) |
| 84009 | Varkhal, Lame du Silence Glacé | 84009 | 84009 | 84009 | 84109 | 84440 (équipé) |
| 84010 | Skorrn, Morsure de l’Hiver Noir | 84010 | 84010 | 84010 | 84110 | 84445 (équipé) |
| 84011 | Vorthalak, Fléau des Vivants | 84011 | 84011 | 84011 | 84111 | 84481 (équipé), 84482 (équipé), 84485 (équipé) |
| 84012 | Drethmâr, Trône de Sang | 84012 | 84012 | 84012 | 84112 | 84502 (équipé), 84503 (équipé), 84505 (équipé) |
| 84013 | Elun'dor, Voix des Cieux Silencieux | 84013 | 84013 | 84013 | 84113 | 84520 (équipé), 84527 (équipé) |
| 84014 | Liora, Berceuse des Racines | 84014 | 84014 | 84014 | 84114 | 84540 (équipé), 84543 (équipé) |
| 84015 | Tharnok, Échine du Monde | 84015 | 84015 | 84015 | 84115 | 84560 (équipé), 84563 (équipé), 84565 (équipé) |
| 84016 | Brakk, Fracture Totale | 84016 | 84016 | 84016 | 84116 | 84581 (équipé) |
| 84017 | Drakthor, Le Brise-Écaille | 84017 | 84017 | 84017 | 84117 | 84601 (équipé) |
| 84018 | Malthen, Égide éternelle | 84018 | 84018 | 84018 | 84118 | 84620 (équipé), 84622 (équipé) |
| 84019 | Vaelthis, Brise-sortilège | 84019 | 84019 | 84019 | 84119 | 84641 (équipé), 84642 (équipé), 84644 (équipé) |
| 84020 | Ashbringer, Fléau des morts | 84020 | 84020 | 84020 | 84120 | 84660 (équipé), 84664 (équipé), 84661 (équipé), 84662 (équipé) |
| 84021 | Vindictus, Châtiment-ardent | 84023 | 84021 | 84021 | 84121 | 84681 (équipé), 84683 (équipé), 84684 (équipé), 84685 (équipé) |
| 84022 | Salvation, Égide de Sanctuaire | 84024 | 84022 | 84022 | 84122 | 84700 (équipé) |
| 84023 | Solareth,  Souffle-de-vie | 84021 | 84023 | 84023 | 84123 | 84720 (équipé) |
| 84024 | Kyresion, Rempart du Juste | 84022 | 84024 | 84024 | 84124 | 84740 (équipé), 84741 (équipé) |
| 84025 | Sha'haggul, Voix des tourments | 84025 | 84025 | 84025 | 84125 | 84760 (équipé), 84763 (équipé) |
| 84026 | Luminaris, Bénédiction éternelle | 84026 | 84026 | 84026 | 84126 | 84780 (équipé), 84784 (équipé), 84783 (équipé) |
| 84027 | Sanguineus, la silencieuse | 84027 | 84027 | 84027 | 84127 | 84801 (équipé) |
| 84028 | Carnifex, la pernicieuse | 84028 | 84028 | 84028 | 84128 | 84821 (équipé) |
| 84029 | Shuor'ror, Crépuscule du savoir | 84029 | 84029 | 84029 | 84129 | 84842 (équipé), 84843 (équipé) |
| 84030 | Shuadslayern, Aube de l'oubli | 84030 | 84030 | 84030 | 84130 | 84862 (équipé) |
| 84031 | Vorgath, plaie des dragons | 84031 | 84031 | 84031 | 84131 | 84880 (équipé), 84883 (équipé) |
| 84032 | Draemorr, Brise-Monde | 84032 | 84032 | 84032 | 84132 | 84903 (équipé), 84904 (équipé) |
| 84033 | Aiguilles de l'Aube | 5996 | — | — | — | — |
| 84034 | Crocs-de-Sang l'Écorcheur | 84034 | 84034 | 84034 | 84134 | 84940 (équipé), 84943 (équipé) |

Sorts : l'arme NN (objet **840NN**) a les numéros **84300 + 20 × (NN − 2)** à **84319 + 20 × (NN − 2)**. Noms lus dans le `Spell.dbc` du client.

| Numéros | Objet | Sorts |
|---|---|---|
| 84300-84319 | 84002 | 84300 Grondement d'Ezh'ra; 84301 Grondement d'Ezh'ra; 84302 Ascension d'Ehz'ra; 84303 Ascension d'Ezh'ra; 84304 Ascension d'Ezh'ra; 84305 Vrilles d'Ezh'ra |
| 84320-84339 | 84003 | 84320 Appel des Anciens; 84321 Chaine de soins des Anciens; 84322 Vague de soins des Anciens; 84323 Protection des Anciens; 84324 Protection des Anciens (recharge); 84325 Appel des Anciens |
| 84340-84359 | 84004 | 84340 Étreinte des Esprits; 84341 Voile des Esprits; 84342 Souffle purificateur |
| 84360-84379 | 84005 | 84360 Fureur de Drokhan; 84361 Fureur de Drokhan |
| 84380-84399 | 84006 | 84380 Rage de Mak'hor; 84381 Rage de Mak'hor |
| 84400-84419 | 84007 | 84400 Précision de Kael'Thorr; 84401 Precision de Kael'Thorr; 84402 Sulfateuse; 84403 Sulfateuse; 84404 Aiguilles de l'Aube |
| 84420-84439 | 84008 | 84420 Corruption de Xer'Thul; 84421 Corruption de Xer'Thul; 84422 Incinération de Xer'Thul; 84423 Incinération de Xer'Thul; 84424 Corruption de Xer'Thul; 84425 Immolation de Xer'Thul; 84426 Malédiction de Xer'Thul; 84427 Nuée démoniaque; 84428 Sentinelle enchainee; 84429 Harpie gangrenee; 84430 Devoreur d ames; 84431 Abomination man'ari; 84432 Faucheur nervin |
| 84440-84459 | 84009 | 84440 Repos de Varkhal; 84441 Repos de Varkhal; 84442 Repos de Varkhal; 84443 Hiver Noir; 84444 Hiver Noir; 84445 Hiver Noir |
| 84480-84499 | 84011 | 84480 Rune de Vorthalak; 84481 Rune de Vorthalak; 84482 Pourriture de Vorthalak; 84483 Fièvre de givre nécrotique; 84484 Peste nécrotique; 84485 Pourriture de Vorthalak (Peste) |
| 84500-84519 | 84012 | 84500 Poigne du Trône de sang; 84501 Poigne du Trône de sang; 84502 Poigne du Trône de sang; 84503 Trône de sang; 84504 Trône de sang; 84505 Autorité de Drethmâr |
| 84520-84539 | 84013 | 84520 Cycle céleste; 84521 Zénith lunaire; 84522 Éclat lunaire d'Elun'Dor; 84523 Rayon de Soleil; 84524 Zénith solaire; 84525 Plénitude d'Elun'Dor; 84526 Faveur d'Elun'Dor; 84527 Plénitude d'Elun'Dor |
| 84540-84559 | 84014 | 84540 Sève de Liora; 84541 Seve de Liora; 84542 Vigueur de Liora; 84543 Appel des Racines; 84544 Appel des Racines (recharge) |
| 84560-84579 | 84015 | 84560 Ronces de givre; 84561 Ronces de givre; 84562 Ronces de givre; 84563 Peau impénétrable; 84564 Peau impénétrable; 84565 Echine du Monde |
| 84580-84599 | 84016 | 84580 Frénésie de Brakk; 84581 Frénésie de Brakk (Proc) |
| 84600-84619 | 84017 | 84600 Contrainte de Drakthor; 84601 Contrainte de Drakthor (Proc) |
| 84620-84639 | 84018 | 84620 Barrière runique de Malthen; 84621 Barrière runique de Malthen; 84622 Vigilance de Malthen |
| 84640-84659 | 84019 | 84640 Infusion de Vaelthis; 84641 Infusion de Vaelthis; 84642 Pyrotechnie de Vaelthis; 84643 Pyrotechnie de Vaelthis; 84644 Brise-Sort de Vaelthis; 84645 Brise-Sort de Vaelthis |
| 84660-84679 | 84020 | 84660 Aura du Porte-Cendre; 84661 Épée de justice; 84662 Main de justice; 84663 Épée de justice; 84664 Ashbringer |
| 84680-84699 | 84021 | 84680 Bouclier du Séraphin; 84681 Bouclier du Séraphin; 84682 Bouclier de Vindictus; 84683 Bouclier de Vindictus; 84684 Consécration de Vindictus; 84685 Châtiment-ardent |
| 84700-84719 | 84022 | 84700 Égide de Sanctuaire; 84701 Aura de sainteté; 84702 Égide de Sanctuaire; 84703 Égide de Sanctuaire (recharge) |
| 84720-84739 | 84023 | 84720 Souffle de Solareth; 84721 Souffle de Solareth; 84722 Souffle de Solareth |
| 84740-84759 | 84024 | 84740 Aura de penitence; 84741 Aura de penitence |
| 84760-84779 | 84025 | 84760 Aiguilles sombres; 84761 Aiguilles sombres; 84762 Aiguilles sombres (cast); 84763 Missile des Ombres; 84764 Missile des Ombres |
| 84780-84799 | 84026 | 84780 Présence de Luminaris; 84781 Présence de Luminaris (Ailes); 84782 Présence de Luminaris; 84783 Présence de Luminaris; 84784 Infusion de Luminaris; 84785 Infusion de Luminaris |
| 84800-84819 | 84027 | 84800 Surin de Sanguineus; 84801 Surin de Sanguineus |
| 84820-84839 | 84028 | 84820 Croc de Carnifex; 84821 Croc de Carnifex |
| 84840-84859 | 84029 | 84840 Vivacite de Shuor'ror; 84841 Rage de Shuor'ror; 84842 Vivacité de Shuor'ror; 84843 Rage de Shuor'ror |
| 84860-84879 | 84030 | 84860 Extermination de Shuadslayern; 84861 Éxtermination de Shuadslayern; 84862 Extermination de Shuadslayern |
| 84880-84899 | 84031 | 84880 Rugissement de Vorgath; 84881 Rugissement de Vorgath; 84882 Exaltation de Vorgath; 84883 Exaltation de Vorgath |
| 84900-84919 | 84032 | 84900 Enchaînement de Draemorr; 84901 Enchainement de Draemorr (proc); 84902 Enchainement de Draemorr; 84903 Enchaînement de Draemorr; 84904 Éviscération de Draemorr; 84905 Éventré |
| 84940-84959 | 84034 | 84940 Équarrissage; 84941 Equarrissage; 84942 Ecorchement; 84943 Écorchement |

## 5. C++

`src/papota_spells.cpp` (871 lignes) enregistre 12 scripts de sorts et une IA, tous propres aux armes :

| Sort | Script |
|---|---|
| 84320 | `spell_nairun_appel_des_anciens` |
| 84340 | `spell_kelrah_etreinte_des_esprits` |
| 84427 | `spell_xerthul_nuee_demoniaque` |
| 84520 | `spell_elundor_cycle_celeste` |
| 84540 | `spell_liora_seve` |
| 84543 | `spell_liora_appel_des_racines` |
| 84561 | `spell_tharnok_ronces_de_givre` |
| 84681 | `spell_vindictus_bouclier_seraphin` |
| 84700 | `spell_salvation_egide` |
| 84720 | `spell_solareth_souffle` |
| 84722 | `spell_solareth_zone` |
| 84943 | `spell_crocs_ecorchement` |
| créatures 84200-84204 | `npc_xerthul_demon` |

Identifiants écrits en dur dans le code (commentaires exclus) : 53563, 72429, 84321, 84322, 84323, 84324, 84424, 84425, 84428, 84429, 84430, 84431, 84432, 84521, 84522, 84523, 84524, 84541, 84542, 84544, 84562, 84680, 84701, 84702, 84703, 84721, 84722.
Les sorts 53563 et 72429 sont des sorts Blizzard ; 600000 est une durée, pas un identifiant.


## 6. Fichiers du client

Tous les ajouts viennent de `patch-z.MPQ`. Par dossier :

| Dossier | Extension | Fichiers |
|---|---|---|
| `Interface\Icons` | .blp | 26 |
| `Item\ObjectComponents\Shield` | .blp | 22 |
| `Item\ObjectComponents\Shield` | .m2 | 4 |
| `Item\ObjectComponents\Shield` | .phys | 1 |
| `Item\ObjectComponents\Shield` | .skin | 4 |
| `Item\ObjectComponents\Weapon` | .blp | 121 |
| `Item\ObjectComponents\Weapon` | .m2 | 23 |
| `Item\ObjectComponents\Weapon` | .phys | 7 |
| `Item\ObjectComponents\Weapon` | .skin | 28 |
| `Spells` | .blp | 18 |
| `Spells` | .json | 3 |
| `Spells` | .m2 | 3 |
| `Spells` | .skin | 3 |

Les `.phys` et `.json` sont des fichiers du jeu moderne ou de wow.export, **sans usage en 3.3.5** ; ils sont
extraits parce que patch-z les porte.

Fichiers Blizzard **remplacés** (extraits dans `data/client-surcharges/`) : un remplacement change l'apparence de
tout ce qui emploie le fichier dans le jeu, pas seulement des armes.

| Fichier | Archive | Relevé via (premier renvoi rencontré) |
|---|---|---|
| `Item\ObjectComponents\Shield\ARMORREFLECT4.BLP` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\bow_1h_deathwingraiddw_d_01.m2 |
| `Item\ObjectComponents\Weapon\ArmorReflect4.blp` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\sword_2h_artifactashbringer_d_06.m2 |
| `Item\ObjectComponents\Weapon\ArmorReflect_Hard.blp` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\sword_1h_artifactskywall_d_06Red.m2 |
| `Item\ObjectComponents\Weapon\ArmorReflect_Rainbow.blp` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\sword_1h_artifactvigfus_d_02.m2 |
| `Item\ObjectComponents\Weapon\draenei_wire_spark.blp` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\staff_2h_artifactheartofkure_d_04.m2 |
| `Item\ObjectComponents\Weapon\FrostmourneFrost.blp` | patch-z.MPQ | texture de Item\ObjectComponents\Weapon\staff_2h_artifactnordrassil_d_05.m2 |
| `Spells\grad2db.blp` | patch-c.mpq | texture de Spells\Holy_Precast_Uber_Base.m2 |
| `Spells\HOLY_RUNE1.BLP` | patch-c.mpq | texture de spells\circle_of_renewal_impact.m2 |
| `Spells\STAR4.BLP` | patch-c.mpq | texture de spells\holyzone.m2 |
| `Spells\star5a.blp` | patch-z.MPQ | texture de Spells\Holy_Precast_Uber_Base.m2 |
| `Spells\t_star2_bw.blp` | patch-z.MPQ | texture de spells\7fx_priest_blessingoftuure_statechest.m2 |
| `Spells\T_VFX_FLARE05_A.BLP` | patch-c.mpq | texture de spells\holyzone.m2 |

18 fichiers Blizzard intacts sont aussi employés : les modèles d'effets `holyzone`, `circle_of_renewal_impact` et
`Holy_Precast_Uber_Base` avec leurs textures, quelques textures du décor reprises par les modèles d'armes, et une icône.
Ils ne sont pas extraits.

## 7. Corrections apportées à l'extraction

Écrites dans `E:\atelier\artifact-weapons\corrections.py`, rejouées après chaque extraction. Tout le reste est fidèle à Papota_hard.

| Correction | Détail |
|---|---|
| Ligne `Item.dbc` de 84134 « Parchemin effacé », client et serveur | 84134, classe 15, sous-classe 4, son -1, matière 0, affichage 2616, emplacement 0, fourreau 0 : les colonnes de `item_template`, comme les 64 autres lignes |
| `Spell.dbc` du client, 84501 « Poigne du Trône de sang » | sort déclenché 49576 → 49560 |
| `Spell.dbc` du client, 84504 « Trône de sang » | durée 20 s → 35 s (index 18 → 125) ; valeurs 25 / 2 / 80 → 35 / 3 / 120 (points de base 24 / 1 / 79 → 34 / 2 / 119) |
| Champs de déclenchement de 34 sorts, dans les deux `Spell.dbc` et dans `spell_dbc` (UPDATE ajoutés en fin de `02_spell_dbc.sql`) | chance et, pour 84442, 84503 et 84561, type de déclenchement : les valeurs de `spell_proc`, que le serveur applique ; texte de 84642 « Pyrotechnie de Vaelthis » : « (15 %) » → « (40 %) » |
| DBC du serveur remplacés par ceux du client, octet pour octet (le client fait foi) | aligne le visuel de Kyresion (84740 : 0 → 84015 ; 84741 : ancien visuel 30010 → 0) et ajoute côté serveur le visuel 84015, le kit 84016 et l'effet 84006 |

Pour Drethmâr, le client a été aligné sur `spell_dbc`, que le serveur applique et que son propre DBC porte déjà.

## 8. Anomalies constatées (non corrigées)

| Constat | Conséquence probable |
|---|---|
| `GameObjectDisplayInfo` 84019 n'existe nulle part, alors que l'objet du monde 84019 l'emploie | objet invisible ; il n'a d'ailleurs aucune apparition |
| Deux sorts qu'aucune arme n'emploie : aucun objet, aucun sort (déclenchement ou description), aucun script ne les cite. 84426 « Malédiction de Xer'Thul », 84861 « Éxtermination de Shuadslayern » | sorts morts |
| `spell_dbc` a toutes les valeurs du client (après ses UPDATE), mais ses colonnes de texte sont vides : noms et descriptions ne vivent que dans les DBC | noms vides côté serveur |
| Commentaire du C++ : le rayon de soleil (84523) « emploie le visuel 20003 » ; il emploie 84006 (ancien 30003) | commentaire périmé |
| Affichages 84021-84024 croisés : l'objet 84021 porte l'affichage 84023, 84022 → 84024, 84023 → 84021, 84024 → 84022 | aucune, mais la règle « affichage = objet » ne tient pas |
| 84024 a deux apparitions (8400006 et 8400023) | PNJ en double |
| L'updater a appliqué les deux `.rollback.sql` du 2026-09-04, chacun juste avant son aller (ordre alphabétique) | l'état final est celui de l'aller ; un rollback rangé dans `custom` est rejoué comme une mise à jour |
| Anciens visuels 17001, 17005 et 17006 (aujourd'hui 84001-84003) : une ancienne version dort dans `patch-frFR-z.mpq.disabled` du client Papota | aucune tant que l'archive reste désactivée |

Les démons de Xer'thul (84200-84204) empruntent cinq affichages Blizzard. Le client Papota modifie trois d'entre eux
(2878, 19110, 19950) au sein d'une modification de 8 043 lignes de `CreatureDisplayInfo.dbc` qui touche tout le jeu :
hors périmètre des armes, rien n'en est extrait.

## 9. Données des joueurs (relevées, non extraites)

| Table | Ce qu'elle référence | Lignes |
|---|---|---|
| `item_instance.itemEntry` | armes et livres possédés (dont 66 hors bots) | 131 |
| `characters.ammoId` | munitions 84033 équipées | 68 |
| `pet_spell_cooldown.spell` | sort 84680 | 5 |
| `acore_auth_hard.account_transmog` | `unlocked_item_id` et `display_id` des armes | 44 |

Toute renumérotation des objets, sorts ou affichages devra migrer ces lignes.


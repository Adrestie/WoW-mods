# Sphèrier Papota — conception

Document de référence pour le système de sphèrier (talents customs).
Rédigé le 2026-08-22, révisé le même jour après arbitrage des décisions ouvertes.
Révisé le 2026-08-23 : la monnaie s'obtient aussi par des objets lootables à qualités,
et le prix des emplacements croît avec le nombre déjà acheté.
Révisé le 2026-08-24 : la monnaie s'appelle la **Spherite**, et les objets qui en
octroient sont les **Nexus** — le mot « sphère » a disparu du vocabulaire.

---

## 1. Vocabulaire

Deux types d'emplacement, deux types d'objet, et une correspondance stricte entre les deux.
Le slot est au rune ce que le nœud est à la pierre.

| Terme | Définition | Contenu accepté |
|---|---|---|
| **Sphèrier** | Grille fixe, une par classe (10 au total). Tracé identique pour tous les personnages d'une même classe. | — |
| **Nœud** | Emplacement à pierres. Pré-rempli d'une pierre à la conception, **ou vide** (révision du 2026-08-23) — un nœud vide ne produit rien tant qu'aucune pierre n'y est sertie. | Pierres uniquement |
| **Slot** | Emplacement **vide** à la création. | Runes uniquement |
| **Sort** | Emplacement porteur d'un **sort custom inédit**, fixé à la conception de la grille (révision du 2026-08-23). L'activer apprend le sort au personnage. | — (le sort fait partie de la grille) |
| **Pierre** | Objet lootable. Ajoute un montant fixe à une statistique principale ou secondaire. Cinq qualités. | — |
| **Rune** | Objet lootable. Ajoute un pourcentage à une statistique principale, ou un rang à un sort. Pas de qualité, mais un niveau d'amélioration. | — |
| **Spherite** | La monnaie du sphèrier. Elle ne s'obtient que par les Nexus et les accroches de contenu, jamais en montant de niveau. C'est elle qu'on dépense pour activer un emplacement. | — |
| **Nexus** | Objet lootable. Consommé, crédite de la Spherite. Cinq qualités, de la plus basse à la plus haute : Nexus **appauvri** (50), **vacillant** (100), **lumineux** (250), **irradiant** (500), **solaire** (1000). | — |
| **Épingle de l'oubli** | Consommable unique, valable pour tous les emplacements. Sur un nœud ou un slot : vide l'emplacement, la pierre ou la rune est **détruite**. Sur un emplacement de sort : le personnage **oublie le sort**, mais le sort n'est pas retiré du sphérier (il fait partie de la grille). | — |

Une conséquence importante de cette structure : ce que le cahier des charges appelait
« nœud de statistique principale ou secondaire » **est** la pierre pré-allouée dans ce nœud.
Le sphèrier ne porte donc aucun bonus en propre — tout bonus vient d'une pierre ou d'une rune.
C'est ce qui rend cohérente la règle « une pierre donne de base plus qu'un nœud normal » :
les pierres pré-allouées sont de qualité basse, les pierres lootées les remplacent
avantageusement.

## 2. Progression

Le joueur gagne de la **Spherite** par deux canaux, jamais en montant de niveau
(révision du 2026-08-23 — auparavant, seules les accroches de contenu existaient) :

1. **Les Nexus** : objets lootables sur tous les monstres du jeu qui ont une table de
   butin, en cinq qualités. La plus basse tombe un peu partout, la plus haute uniquement
   sur les boss de fin de jeu. Consommer un Nexus crédite un montant de Spherite qui
   dépend de sa qualité — 50, 100, 250, 500 ou 1000. Distribution : même mécanisme que
   les pierres (§7).
2. **Les accroches de contenu** : attribution directe de Spherite sur les événements de
   jeu, en complément du loot.

| Source | Accroche |
|---|---|
| Boss de donjon et de raid | `PlayerScript::OnPlayerCreatureKill`, filtré sur le rang de la créature |
| Mythique+ | dans le chemin de récompense existant de `Mythic_Server.lua` |
| Donjon terminé | `mod-dungeon-clear`, déjà en place |

Il dépense cette Spherite pour activer les emplacements un par un. Un emplacement n'est
activable que s'il est adjacent à un emplacement déjà actif, ou s'il s'agit du point de
départ de la classe.

**Le prix d'un emplacement croît avec l'avancement** : il dépend du nombre total
d'emplacements déjà activés par le personnage, selon un barème par tranches vivant en base
(arbitrage du 2026-08-23 — global et indépendant de la grille, plutôt qu'un prix par
profondeur ou par emplacement). Nœuds et slots suivent le même barème.

**La courbe, arrêtée le 2026-08-26** : les grilles visent **254 emplacements**. Le premier
est **gratuit**, le deuxième coûte **50 Spherite**, le dernier **50 000**, la croissance
étant régulière entre les deux — soit **+2,7791 % par emplacement**, taux déduit de
50 × r²⁵² = 50 000.

Le barème est engendré par `outils_spherier\gen_bareme_couts.py`, une ligne par emplacement.
Deux façons d'appliquer la même croissance ne donnent pas le même résultat, et le choix est
explicite : **la formule fermée arrondie** `prix(n) = ⌈50 × r^(n−2)⌉` est retenue, parce
qu'elle ne dérive pas et tombe exactement sur la cible. Composer sur la valeur déjà arrondie
— « le prix précédent majoré de x % » — accumulerait l'arrondi vers le haut et pousserait la
fin de courbe loin au-dessus. La contrepartie du choix retenu : au début, où l'arrondi pèse
lourd, deux prix voisins ne montent pas d'exactement le taux annoncé. L'arrondi supérieur
demande enfin une tolérance d'un milliardième, sans quoi l'erreur de virgule flottante fait
finir le dernier emplacement à 50 001.

Repères : 10ᵉ emplacement 63, 20ᵉ 82, 30ᵉ 108, 50ᵉ 187, 100ᵉ 734, 150ᵉ 2 890, 200ᵉ 11 380,
254ᵉ 50 000. Cumulés : 507 pour les dix premiers, 5 114 pour cinquante, 25 384 pour cent,
419 128 pour deux cents, **1 847 467 pour la grille entière**.

- Activer un **nœud** applique immédiatement la pierre qu'il contient — s'il en
  contient une : un nœud vide ne produit rien tant qu'aucune pierre n'y est sertie.
- Activer un **slot** ne produit rien tant qu'aucune rune n'y est sertie.
- Activer un emplacement de **sort** apprend le sort au personnage.
- L'épingle de l'oubli ne désactive pas l'emplacement : elle le vide (pierre ou rune
  détruite, emplacement disponible pour un nouveau sertissage). Sur un emplacement de
  sort, le personnage oublie le sort ; le sort reste dans la grille, et l'emplacement
  reste actif — **re-cliquer l'emplacement ré-apprend le sort au coût habituel d'un
  emplacement** (décision du 2026-08-24). Le prix est celui du barème pour le nombre
  d'emplacements déjà activés, donc le même que celui du prochain achat : oublier un sort
  n'est jamais définitif, mais le rendre n'est pas gratuit.

## 3. Principe directeur : rien de chiffré dans le code

**Aucune valeur numérique ne doit vivre dans le code.** Montants des pierres par qualité,
pourcentages des runes, points accordés par source, coûts de fusion et de relance : tout est
lu depuis des tables de la base, rechargeables en jeu par une commande `.spherier reload`,
sans recompilation ni redémarrage.

Cette contrainte est structurante, pas cosmétique : elle conditionne la façon dont le module
est écrit dès le premier jalon. L'équilibrage n'est pas dans le périmètre, mais il doit
rester réglable en quelques secondes.

## 4. Modèle de données

### Définition — base world

```
papota_sphere_node
    node_id, class_id, kind (0 = NŒUD, 1 = SLOT),
    grid_x, grid_y, icon, name,
    default_stone_entry     -- pour kind = NŒUD uniquement

papota_sphere_edge
    class_id, node_a, node_b

papota_sphere_start
    class_id, node_id

papota_sphere_point_source    -- barème d'attribution de Spherite par accroche, rechargeable
    source_type, source_value, points

papota_sphere_item            -- hérité : Spherite créditée par objet consommé. Les Nexus
    item_entry, points        -- ne s'en servent plus, leur montant vit dans leur sort (§13).

papota_sphere_cost            -- barème du prix croissant, par tranches, rechargeable
    activated_min, cost       -- prix applicable à partir de N emplacements déjà activés
```

### État du personnage — base characters

```
character_sphere_node
    guid, node_id,
    content_entry,          -- entrée de l'objet serti (0 si vide)
    content_upgrade         -- niveau d'amélioration, runes uniquement

character_sphere_points
    guid, earned, spent
```

Seuls les emplacements activés ont une ligne. Les points disponibles se déduisent
(`earned - spent`), ils ne sont pas stockés en double.

### Niveau d'amélioration des runes en sac

Une rune améliorée dans un sac doit porter son niveau **par instance**, pas par entrée
d'objet. C'est exactement ce que fait déjà `mod-item-upgrade` avec
`character_item_upgrade (guid, item_guid, stat_id)` : le suivi se fait sur le GUID de
l'objet. On reprend ce motif dans `character_rune_upgrade (guid, item_guid, level)`.
Au sertissage, le niveau est recopié dans `character_sphere_node.content_upgrade`
et l'objet est consommé.

## 5. Application des effets

Un seul principe, repris d'`Attriboost` : **recalcul total, jamais incrémental**.

Une fonction unique resomme l'ensemble des emplacements actifs, puis :

1. pousse le bloc de statistiques agrégé via des auras customs dont on pilote le montant ;
2. synchronise la liste des sorts appris au titre des runes de rang.

Elle est appelée à la connexion, à chaque activation, à chaque sertissage et à chaque usage
d'épingle. Toute application incrémentale finit par désynchroniser — c'est la panne classique
de ce type de système.

## 6. Les rangs de sorts

> **Révision du 2026-08-26 — les sorts de talent rentrent dans le périmètre.** Le paragraphe
> ci-dessous décrit l'arbitrage d'origine, qui les excluait ; il est remplacé par la section
> « Sorts de talent » plus bas. Les sorts de familier, eux, restent hors périmètre.

**Les talents sont hors périmètre. Seuls les sorts sont concernés.** Cet arbitrage supprime
la seule inconnue technique réelle du système : la validation, à la connexion, de la
cohérence entre points de talent dépensés et talents connus, qui exposait à une
réinitialisation involontaire des talents du personnage. Le sujet est clos.

### Ce qu'une rune de rang fait, exactement (2026-08-26)

Une rune ajoute **un** rang au-delà du maximum de Blizzard. Elles se cumulent : deux runes
de Pourfendre donnent les rangs 11 et 12, et le joueur **connaît les deux** — un rang
supérieur ne remplace pas l'inférieur, ce sont des sorts distincts du grimoire. Retirer une
rune fait oublier le rang du dessus, en pile. **Trois runes au maximum par sort**, donc
trois rangs customs à créer pour chacun ; l'interface refuse la quatrième avec une erreur.

Le retrait passe par l'**épingle de l'oubli**, comme tout ce qui vide un emplacement.

Une rune se loote sans condition de classe : un guerrier peut trouver une rune de druide.
C'est l'établi qui la rendra utile, à défaut de quoi elle s'échange. Les runes ne tombent
que sur le contenu de fin de jeu (§14), ce qui rend le sujet des bas niveaux sans objet.

**Six sorts améliorables par classe**, soit soixante sorts et cent quatre-vingts rangs.
Le recensement des candidats vit dans `outils_spherier\sorts_ameliorables.xlsx`, engendré
par `gen_tableau_sorts.py` depuis `trainer_spell`, `Talent.dbc` et `Spell.dbc`.

### Sorts de talent : les rangs suivent le talent, en direct

Un sort de talent peut disparaître — remise à zéro, changement de spécialisation. Dans ce
cas **les runes sont désactivées et les rangs supplémentaires oubliés sur-le-champ**, sans
que le joueur ait à ouvrir la moindre interface. La rune reste sertie ; elle reprend son
effet dès que le talent revient.

La règle tient en une phrase : les rangs supplémentaires n'existent que tant que le joueur
connaît le rang maximal de Blizzard dont ils sont la suite. Le recalcul total du §5 gagne
donc cette condition, et se déclenche sur quatre événements — la connexion, déjà en place,
plus `OnPlayerTalentsReset`, `OnPlayerAfterSpecSlotChanged` et `OnPlayerLearnSpell`.

Deux pièges relevés à la lecture du cœur : `OnPlayerTalentsReset` part **avant** la remise à
zéro, donc un recalcul immédiat verrait l'ancien état — il faut le différer d'un tour de
boucle ; et `OnPlayerLearnSpell` part une fois par sort, soit une rafale entière lors d'un
repec, d'où un recalcul différé et dédoublonné. Il n'existe aucun crochet sur le retrait
d'un sort, ce qui interdit d'observer la perte directement.

**Un talent partiellement investi ne compte pas** (décision du 2026-08-26) : les runes
n'étendent que le maximum absolu du sort. Un talent à trois points reste sans effet sur les
runes tant qu'il n'est pas complet, puis leur ouvre les rangs 4, 5 et 6. L'autre lecture —
enchaîner sur le rang réellement atteint — aurait fait dépendre la valeur d'une rune du
nombre de points investis, et fait sauter des rangs non appris.

Reste le coût, qui est du travail de contenu et non du risque. À 80, la quasi-totalité des
sorts sont déjà à leur rang maximum : un « +1 rang » suppose donc de **créer le rang suivant,
qui n'existe pas**. Pour chaque sort visé :

1. une entrée dans le `Spell.dbc` serveur (motif déjà en place, sorts 803xxxx) ;
2. la même entrée dans le `Spell.dbc` client, empaquetée dans `patch-z.MPQ`, sans quoi
   l'infobulle et la barre d'action seront muettes ;
3. une ligne dans `spell_ranks` (base world, 3502 lignes déjà présentes) pour que le cœur
   traite le nouveau sort comme la suite de la chaîne.

**Conséquence à assumer : le catalogue des runes de sort doit être choisi, pas exhaustif.**
Une poignée de sorts structurants par classe est réaliste ; le grimoire complet ne l'est pas.

### Les sorts custom inédits (révision du 2026-08-23)

En plus des rangs, le sphérier **propose des sorts custom inédits**, portés par un
troisième type d'emplacement : l'emplacement de **sort**, fixé dans la grille à la
conception (comme la pierre d'un nœud, mais inamovible). L'activer apprend le sort ;
l'épingle de l'oubli le fait oublier sans le retirer de la grille. Ces sorts sont à
créer de toutes pièces (motif déjà en place : sorts customs 803xxxx / 83xxxxx du
serveur, Spell.dbc serveur + client via patch-z, scripts dans mod-papota-spells si
besoin). Le coût d'activation suit le barème commun. La création du catalogue de sorts
est du travail de contenu (jalons 6-7) ; l'éditeur référence le sort par son
identifiant.

## 7. Sources de butin

### Pierres — une table de référence par qualité

Révision du 2026-08-23 : **cinq qualités** au lieu de six — la « Magique » est retirée
(les donjons en mode normal retombent dans leurs bandes de niveau), la « Normale » devient
« Commun ». Le barème ci-dessous est celui de l'infobulle de l'éditeur ; en jeu il vivra en
base, comme tout le chiffré.

Le mécanisme demandé existe nativement dans le cœur : `reference_loot_template`. On crée
**cinq tables de référence**, une par qualité, contenant toutes les pierres de cette qualité
à chances égales. La plage d'entrées 803001 à 803005 est libre.

| Qualité | Bonus | Table | Critère d'affectation |
|---|---|---|---|
| Commun | +5 | 803001 | contenu de niveau 1 à 60 |
| Inhabituel | +7 | 803002 | contenu de niveau 61 à 70 |
| Rare | +10 | 803003 | contenu de niveau 71 à 80 |
| Épique | +15 | 803004 | donjons héroïques et raids antérieurs à Icecrown |
| Légendaire | +30 | 803005 | Icecrown uniquement |

> **Révision du 2026-08-24 — la distribution ne passe plus par des lignes de butin.**
> Tout ce qui suit dans ce §7, jusqu'aux runes, décrit le mécanisme d'origine : des tables
> de référence affectées aux tables de butin existantes, soit ~7 650 lignes régénérables.
> Il est **remplacé** par l'injection décrite au §14 : aucune ligne n'est ajoutée à la base,
> les tranches vivent dans le code du serveur. Le raisonnement ci-dessous reste utile — il
> établit les chiffres de couverture et l'écueil des tables partagées, tous deux toujours
> valables — mais ce n'est plus l'implémentation.

### L'affectation vise les tables de butin, pas les créatures

C'est le point de conception important, et il découle des chiffres.

**71 % des créatures n'ont aucune table de butin** (`lootid = 0`) : ce sont les déclencheurs,
les lapins de mise en scène, les véhicules, les créatures cosmétiques. Sur la bande 1–60,
10 432 créatures sur 14 660 sont dans ce cas.

Affecter les références « à toutes les créatures d'une bande » obligerait donc à modifier en
masse `creature_template.lootid`, et donnerait du butin à des objets invisibles. **On affecte
au contraire les références aux tables de butin déjà existantes** : une ligne dans
`creature_loot_template` par `lootid` distinct de la bande, avec `Reference` pointant sur la
table de qualité et `GroupId = 0` pour que le tirage reste indépendant du butin d'origine.

Conséquences : `creature_template` n'est pas touchée, et les créatures sans butin sont
exclues gratuitement, sans liste d'exceptions à maintenir.

| Bande | Tables de butin distinctes |
|---|---|
| 1–60 | 4 170 |
| 61–70 | 1 728 |
| 71–80 | 1 758 |

Soit environ 7 650 lignes, produites par un script régénérable et non écrites à la main.

**Exception connue : 152 tables de butin sont partagées entre plusieurs bandes de niveau.**
Sans règle, elles recevraient deux qualités de pierre. Règle retenue par défaut : ne garder
que la bande la plus haute.

### Nexus — le même mécanisme, en bandes cumulatives

Les Nexus empruntent exactement le circuit des pierres : **cinq tables de référence**,
une par qualité (plage 803011 à 803015), affectées aux tables de butin existantes par le
même script régénérable. Tables séparées de celles des pierres pour que les chances de
chaque famille restent réglables indépendamment.

Une différence assumée avec les pierres : les bandes sont **cumulatives, pas exclusives**.
Une qualité tombe à partir de sa bande plancher et continue au-delà — c'est ce qui rend
la qualité basse « un peu partout » et réserve la haute aux boss de fin de jeu.

| Qualité | Plancher (arbitrage par défaut) |
|---|---|
| Commune | tout contenu, niveau 1 et plus |
| Inhabituelle | contenu de niveau 61 et plus |
| Rare | contenu de niveau 71 et plus |
| Épique | donjons héroïques et raids |
| Légendaire | boss d'Icecrown uniquement |

Les chances de tirage décroissent avec la qualité ; les chances vivent en base, et le
montant de Spherite d'un Nexus vit dans son sort d'utilisation (§13).

### Runes — deux sources, toutes deux déjà outillées

| Source | Mécanisme |
|---|---|
| Boss d'Icecrown | table de référence 803007, affectée aux tables de butin des 20 entrées de boss de la carte 631 |
| Donjon mythique+ | lignes dans `world_mythic_loot`, qui distribue déjà les composants de Puissance par palier |

Aucun mécanisme nouveau n'est requis : la table `world_mythic_loot` porte déjà
`itemid`, `amount`, `type`, `loot_bracket` et `chancePercent`, et sert exactement à cela
pour les composants 801050 et suivants.

## 8. Volumétrie des objets à créer

Plages libres retenues : 803000–810999 (801xxx, 802xxx et 811xxx sont pris).

| Famille | Décompte estimé | Détail |
|---|---|---|
| Pierres | 80 | 16 effets (5 principales, 11 secondaires) × 5 qualités |
| Runes de statistique | ~5 à 15 | une par statistique principale, éventuellement en paliers de base |
| Runes de sort | ~80 | catalogue choisi, ordre de grandeur de 8 par classe |
| Nexus | 5 | une par qualité, consommables |
| Épingle de l'oubli | 1 | consommable |

Le catalogue des 16 effets (fixé le 2026-08-23, source de vérité : `STATS` dans
`Spherier_Server.lua`) : endurance, intelligence, esprit, dextérité, force — les cinq
principales — puis parade, blocage, esquive, hâte, critique, touché, puissance des sorts,
puissance d'attaque, pénétration d'armure, expertise, bonus des soins.

**Allocation des entrées de pierres (fixée le 2026-08-23 par l'importeur)** :
`803100 + (stat − 1) × 5 + (qualité − 1)`, l'indice de stat étant l'ordre du catalogue
ci-dessus (1 à 16), la qualité 1 à 5 — soit la plage 803100 à 803179. Les objets
eux-mêmes seront créés au jalon 3 avec ces entrées.

Les cinq qualités se projettent exactement sur les qualités client 1 à 5 (blanc, vert,
bleu, violet, orange) : l'ancien décalage « rare affichée en violet », introduit par la
sixième qualité, a disparu avec elle.

## 9. Recettes de l'établi

> **Révision du 2026-08-27.** Trois recettes, et non quatre : **une rune ne
> s'améliore pas, elle se refond**. Il en faut **trois** pour en tirer une
> nouvelle, prise au hasard dans le catalogue entier — sans condition de classe,
> ce qui est la raison d'être de l'établi énoncée au §6 : une rune de druide
> trouvée par un guerrier finit par devenir utile. L'« amélioration aux
> composants de Puissance » est retirée : les runes n'ont pas de paliers.

| Opération | Coût | Résultat |
|---|---|---|
| Fusion de pierres | 3 pierres, même effet, même qualité | 1 pierre, même effet, qualité supérieure |
| Relance de pierre | 2 pierres, même qualité | 1 pierre, même qualité, effet différent |
| Refonte de runes | 3 runes, quelles qu'elles soient | 1 rune tirée au hasard dans tout le catalogue |

Les pierres ne montent en qualité que par fusion, jamais aux composants. Une
pierre légendaire ne fusionne plus : il n'y a rien au-dessus.

**L'établi est un objet de monde** (arbitrage du 2026-08-27), pas un bouton de
l'interface : il faut aller le trouver. Le module fournit le gabarit et le
script ; les apparitions sont posées en jeu, à la main, là où l'administrateur
le décide.

## 10. Phasage

| Jalon | Contenu | Critère de validation |
|---|---|---|
| **1** | Squelette `mod-papota-spherier`, tables, chargement au démarrage, `.spherier reload`, commandes GM. Aucun effet. | Le serveur démarre, `.spherier info` répond, le rechargement fonctionne |
| **2** | Spherite (accroches sur le contenu), barème de coût croissant, adjacence, activation, persistance — en commandes GM | Activation correcte après reconnexion, prix conforme au barème |
| **3** | Pierres et Nexus : objets, consommation des Nexus, sertissage, agrégation, épingle de l'oubli | La feuille de personnage bouge, un Nexus consommé crédite sa Spherite, l'épingle rend l'emplacement libre |
| **4** | Interface AIO du sphèrier, sur **une seule classe**, fond provisoire | Jouable à la souris |
| **5** | Runes de statistique, établi (fusion, relance, refonte) | Les trois recettes fonctionnent |
| **6** | Runes de sort : rangs customs sur le catalogue choisi | Un rang supplémentaire est effectif en jeu |
| **7** | Les 9 autres grilles, fonds définitifs, tables de butin, équilibrage | — |

Les jalons 1 à 3 ne touchent ni au client ni aux assets : tout est testable en commandes GM.

### État au 2026-08-23 — jalon 1 livré

Le module `mod-papota-spherier` existe (`azerothcore-wotlk\modules\mod-papota-spherier\`),
compile et charge. Les six tables world et les deux tables characters sont créées (SQL du
module dans `data\sql\`, appliqué à la main et consigné dans `updates`, règle maison), avec
les amorces sentinelles (coût 1234 dès 0 emplacement, quatre sources d'accroche à 1234).
La définition se charge avant l'ouverture du monde (`OnBeforeWorldInitialized`, motif
mod-item-upgrade) ; `.spherier info` (GM) et `.spherier reload` (admin) sont disponibles en
jeu et en console — l'éditeur Lua n'intercepte que `.spherier` nu, les sous-commandes
traversent. Contrôles d'intégrité au chargement : liaisons invalides, départs manquants,
nœuds sans pierre, morceaux non reliés au départ (BFS).

### État au 2026-08-23 — jalon 2 livré (tests en jeu à faire)

`SpherierPlayerMgr` : état par personnage (Spherite, activations) chargé à la connexion —
les playerbots sont écartés d'emblée —, écrit en base à chaque mutation. Activation selon
les règles du §2 : départ ou adjacence, coût du barème d'après le nombre déjà activé,
classe vérifiée ; activer un nœud enregistre sa pierre pré-allouée dans `content_entry`
(les effets viendront au jalon 3). Crédit des boss par les hooks kill (familiers compris,
leçon M+) : donjon → `boss_donjon`, raid ou boss de plein monde → `boss_raid`, tout le
groupe présent dans la carte est crédité, barème par entrée de boss possible avec repli
sur le défaut du type. Commandes (noms anglais, décision du 2026-08-23) : `.spherier
status [joueur]` ; `.spherier points add|remove|set <montant> [joueur]` (admin — add
crédite, remove débite plafonné à la Spherite disponible, set fixe les **disponibles** à
la valeur donnée ; sans montant, chaque sous-commande affiche son aide) ; `.spherier
activate <node_id>` ; `.spherier reset [joueur]` (admin). `.spherier` nu
affiche la liste des sous-commandes (natif du cœur, filtrée par niveau).
`.spherier show` est réservé au sphérier du joueur (jalon 4) — message d'attente en
place. `.spherier editor` ouvre l'éditeur de disposition, **administrateurs seulement** :
la garde (`GetGMRank() >= 3`) vit dans les cinq handlers AIO du serveur, pas seulement
dans la commande, car `/spherier` appelle AIO directement. Jalon 2 **validé** le
2026-08-23. Ouvert, à trancher à l'équilibrage : un boss qui repope recrédite de la
Spherite (aucun verrou de première fois).

**Les trois accroches sont câblées (2026-08-23)** :
- `boss_donjon` / `boss_raid` : hooks kill du module (déjà en place au jalon 2) ;
- `mythique_plus` : greffe dans le chemin de récompense de `Mythic_Server.lua`
  (complétion du run, y compris hors temps), joueurs réels présents seulement,
  valeur = palier — via la commande console dédiée `.spherier points source <type>
  <valeur> [joueur]` (SEC_CONSOLE, invisible en jeu), appelée par `RunCommand` ;
- `donjon_termine` : greffe dans `mod-dungeon-clear`
  (`DungeonClearDisableOnClearedAction::Execute`, une seule exécution par run
  garantie par l'armement de DcRun), joueurs humains présents dans l'instance
  (self-bots compris — `DcPlayerbotCompat::IsHumanControlled`, appel qualifié
  obligatoire), valeur = mapId, par appel C++ direct `CrediterSource`.

Messages : tout passe par `module_string` (anglais par défaut) et
`module_string_locale` (frFR), servis selon la locale du client — 33 chaînes,
identifiants dans `src\SpherierStrings.h`. Les messages Lua de commande
suivent la même règle (`GetDbLocaleIndex`).

### État au 2026-08-24 — jalon 3 : les effets

**Les objets existent** : 80 pierres (803100–803179, 16 statistiques × 5 qualités),
5 Nexus (803200–803204) et l'épingle de l'oubli (803300), engendrés par
`outils_spherier\gen_objets_spherier.py` — noms anglais dans `item_template`,
français dans `item_template_locale`, comme les messages. L'effet chiffré d'une
pierre ne vit pas dans son nom mais dans `papota_sphere_stone` (entrée → stat,
montant), rechargeable ; `papota_sphere_config` porte les réglages, dont
l'entrée de l'épingle.

**L'application des statistiques n'utilise ni aura ni DBC.** Le catalogue des 16
statistiques est projeté sur les API du cœur : `HandleStatFlatModifier` pour les
cinq principales et la puissance d'attaque, `ApplyRatingMod` pour les notes de
combat (hâte, critique et toucher couvrant chacun leurs trois écoles),
`ApplySpellPowerBonus` et `ApplySpellHealingBonus` pour les deux dernières.
C'est la seule correspondance codée en dur du module. Le recalcul est **total** :
`Recalculer` resomme les emplacements actifs, retire le bloc précédemment posé,
applique le nouveau — appelé à la connexion, à chaque activation, sertissage et
usage d'épingle. Ces modificateurs ne survivant pas à une déconnexion, la
connexion les repose.

**Sertissage et épingle** : `.spherier socket <emplacement> <objet>` (niveau
joueur — c'est le chemin qu'empruntera l'interface) consomme la pierre du sac et
la pose dans un nœud actif et vide ; `.spherier unsocket <emplacement>` consomme
une épingle, détruit le contenu et rend l'emplacement libre. Sur un emplacement
de sort, l'épingle fait **oublier** le sort sans le retirer de la grille.
`.spherier stats [joueur]` (GM) montre le bloc appliqué.

**Nexus** : un Nexus se consomme **comme n'importe quel consommable du jeu**,
sans rien détourner. Il porte un sort custom (`spellid_1`, `spelltrigger_1 = 0`,
`spellcharges_1 = -1`), le cœur le lance au clic droit et l'objet part avec sa
charge ; un **script de sort** rattaché par `spell_script_names` crédite la
Spherite. Le montant est **porté par le sort lui-même**
(`EffectBasePoints_1 = N − 1`, `EffectDieSides_1 = 1`) : le client l'affiche par
`$s1` dans l'infobulle — « Utiliser : Ajoute 250 Spherites » — et le serveur lit
la même valeur par `GetEffectValue()`. Une seule valeur, deux lectures, aucune
divergence possible. Les cinq montants, du plus bas au plus haut : 50, 100, 250,
500 et 1000 — ce ne sont plus des sentinelles.

Les cinq sorts (8500001–8500005) sont clonés du modèle Blizzard 59061 « Charge
Shield » — instantané, ciblant le lanceur, effet muet, sans exigence
d'équipement — et portent le kit visuel de Power Infusion (7553), une
déflagration dorée sur le joueur. `outils_spherier\gen_sorts_spherier.py` écrit
d'un même mouvement le `Spell.dbc` du client, celui du serveur et le SQL
(`spell_dbc`, `spell_script_names`, rattachement aux objets).

**Où vivent les DBC customs, et pourquoi les trois dépôts sont nécessaires**
(établi à la dure le 2026-08-24) : tout ce qui est custom — objets comme sorts —
vit dans **`patch-z.MPQ`** côté client, là où se trouvaient déjà les 247 objets
et 144 sorts du serveur ; l'autre copie de `Spell.dbc`, dans `patch-frFR-z`,
n'en contient aucun et n'est pas celle que le client ouvre. Côté serveur, les
mêmes entrées vont dans `Data\dbc\Item.dbc` et `Spell.dbc`, doublées des tables
de surcharge `item_dbc` / `spell_dbc` que charge AzerothCore. Chacun de ces
dépôts répond à un besoin distinct : sans l'`Item.dbc` **serveur**, le cœur
ignore purement et simplement la ligne d'`item_template` ; sans l'`Item.dbc`
**client**, l'objet s'affiche avec le point d'interrogation rouge, car le client
résout l'apparence par son propre DBC et non par ce que le serveur lui envoie ;
sans le `Spell.dbc` **client**, ni infobulle ni visuel. Les générateurs écrivent
tous ces dépôts depuis la même source, et l'injection dans une archive exige le
**jeu fermé**.

**L'index de locale d'un `Spell.dbc` 3.3.5 : frFR est le 2, pas le 3** (0 enUS, 1 koKR,
2 frFR, 3 deDE, 4 zhCN, 5 zhTW, 6 esES, 7 esMX, 8 ruRU). Vérifié sur le sort 47471, dont
l'index 2 rend « Exécution » et le 3 « Hinrichten ». Les cinq sorts des Nexus avaient été
écrits à l'index 3 : leur texte français partait en allemand et un client français
affichait l'anglais. Corrigé et réinjecté le 2026-08-26, serveur et `patch-z.MPQ`.

**Sertissage à la souris (2026-08-24)** : les commandes `socket`/`unsocket` restent le
chemin, mais l'interface les emprunte désormais elle-même. Sur un emplacement acheté :
clic droit = épingle ; clic gauche sur un emplacement vide = liste des pierres du
sac, ou sertissage direct si le curseur en porte déjà une ; on peut aussi **lâcher** une
pierre prise dans un sac sur l'emplacement.

**L'objet mène à la grille (2026-08-24, demande utilisateur)** : une pierre, une rune ou
une épingle sont **utilisables depuis le sac**. Un clic droit dessus ouvre le sphèrier et
met l'objet « en main » — un bandeau de la fenêtre rappelle lequel. Le clic gauche sur un
emplacement fait alors exactement ce que ferait le geste équivalent dans l'interface.

Le curseur suit la règle du jeu pour tout ce qui s'applique sur une cible : **barré**
(`CAST_ERROR_CURSOR`) partout, **franc** (`CAST_CURSOR`) seulement au survol d'un
emplacement qui peut recevoir l'objet — un emplacement vide du bon type pour une pierre ou
une rune, un emplacement garni pour une épingle. Il est réaffirmé à chaque image, car tout
cadre survolé appelle `ResetCursor()` de son côté (`CursorUpdate`, UIParent.lua). **Tout
clic ailleurs repose l'objet**, rend le curseur par défaut et **ne déclenche rien
d'autre** : cliquer un emplacement non acheté avec une épingle en main annule, sans
proposer son achat ; cliquer le fond annule, sans entamer un déplacement de la grille. Les
clics sont observés (`IsMouseButtonDown`, front montant) plutôt qu'interceptés, sans quoi
ils n'atteindraient plus le reste de l'interface — mais l'observation tombant sur
l'enfoncement et le clic sur le relâchement, un emplacement survolé garde la main sur son
propre clic, sinon le relâchement retomberait dans le comportement ordinaire. Une
confirmation ouverte prolonge le geste et ne compte pas pour un ailleurs. Le point d'accroche est `UseContainerItem`, que
le jeu appelle sur tout clic droit d'un objet en sac (`ContainerFrame.lua`, branche
« else » de `ContainerFrameItemButton_OnClick`) : nos objets n'ayant aucun sort
d'utilisation, ce clic ne fait rien côté serveur et peut donc recevoir un sens sans rien
détourner. On s'abstient quand une fenêtre de marchand, de courrier, d'échange ou d'hôtel
des ventes est ouverte — là, le clic droit vend ou joint, il ne veut pas dire « utiliser ».
Pour que ce clic soit reconnu **avant** la première ouverture de la fenêtre, le client
réclame le catalogue des objets (pierres, runes, entrée de l'épingle) dès son chargement.

**Toute consommation demande confirmation** : sertir une pierre comme employer une
épingle ouvre une boîte de dialogue nommant l'objet et son effet, bouton **Valider**. Pour
l'épingle, Valider est **grisé** tant que le joueur n'en porte aucune — le refus du module
reste la vraie barrière, mais l'impossibilité se voit d'emblée. Le client reconnaît une pierre par le
catalogue que le serveur lui envoie (`def.pierres`), affiche l'icône de la statistique
relevée sur la grille elle-même (`def.iconeParStat` — aucun chemin codé en dur), et
distingue « acheté mais vide » de « acheté et garni » par `etat.brut`, l'entrée réellement
portée. Un emplacement acheté montre désormais **ce qu'il porte**, pas ce que la grille
prévoyait : icône, couleur de qualité, infobulle et récapitulatif suivent le sertissage.

Reste hors jalon : les runes et l'établi (jalon 5), la création des sorts customs
(jalon 6).

### État au 2026-08-26 — jalon 5 : les runes de rang

**Le contenu existe.** 157 sorts retenus par l'utilisateur — sorts de maître et de talent —,
471 rangs supplémentaires et 21 sous-sorts déclenchés écrits dans le `Spell.dbc` du serveur
et dans celui du client (`patch-z.MPQ`), 471 lignes de chaînage dans `spell_ranks`, et
**157 runes** (objets 803401 à 803557, entrées `item_dbc` comprises). Sauvegardes posées :
`Spell.dbc.avant_rangs` et `patch-z.MPQ.avant_rangs`.

Chaîne d'outils, dans `outils_spherier` : `gen_tableau_sorts.py` recense les candidats,
`analyse_courbes.py` relève les courbes existantes, `extrapole_rangs.py` en déduit les
rangs, `gen_tableau_rangs.py` produit la table de relecture, `gen_rangs_sorts.py` engendre
DBC, SQL et runes.

**La méthode d'extrapolation** est décrite dans la feuille « Méthode » de
`rangs_proposes.xlsx` : croissance médiane de ×1,211 par rang mesurée sur 1 095 rangs,
chaque sort gardant la sienne quand elle est mesurable, bornée à [1,10 ; 1,35]. Les
pourcentages suivent la règle +15/30/50 relatifs. Huit sorts sans rien de chiffrable
reçoivent un **bonus plat** égal à ce qu'un rang vaut dans leur classe.

**La mécanique est écrite.** `papota_sphere_rune` relie une entrée d'objet à son sort et au
nombre de rangs de Blizzard. `SynchroniserRunes` compte les runes serties par famille,
exige que le joueur connaisse le rang de base — sinon la rune reste inerte —, apprend les
rangs suivants et retire ce qui n'a plus lieu d'être. Le retrait par le haut n'a demandé
aucun code : on repart de l'ensemble voulu. La quatrième rune identique est refusée.
Les trois crochets de talent sont branchés et différés d'un tour de boucle.

**Deux défauts corrigés le 2026-08-26, au premier démarrage réel.**

*Une chaîne de `spell_ranks` se décrit ENTIÈRE.* `SpellMgr::LoadSpellRanks` exige que la
chaîne commence au rang 1 et ne saute aucun cran, faute de quoi elle est rejetée en bloc.
Blizzard ne chaîne pas les sorts à rang unique : pour ces 20 familles, nos rangs 2-3-4
formaient une chaîne commençant à 2. Le générateur pose désormais le sort lui-même en
rang 1 quand `rangs_existants` vaut 1 — et ces familles-là sont exactement celles qui
n'avaient aucune ligne, vérifié en base.

*Les CHAÎNES PARALLÈLES sont le vrai piège.* Plusieurs scripts du cœur traduisent le rang
du sort lancé en un rang d'une AUTRE chaîne : les dégâts et les soins du Horion sacré, la
copie main gauche du chevalier de la mort, le sort déclenché de la Nova de feu.
`SpellMgr::GetSpellWithRank` (SpellMgr.cpp:647) y remonte de rang en rang et déréférence
`node->next` **sans vérifier qu'il est non nul** : un rang au-delà du dernier fait planter
le serveur — au démarrage pour les scripts qui ont un `Validate`, en jeu pour les autres.
Huit sorts sont dans ce cas et ont été **écartés du catalogue en attendant que leurs
chaînes parallèles soient étendues elles aussi** : Horion sacré (25912, 25914), Pénitence
(47758, 47757), Nova de feu (8349), Semence de corruption (27285), Frappe de mort (66188),
Frappe de givre (66196), Oblitération (66198), Frappe de sang (66215). La liste vit dans
`EXCLUS`, au début de `gen_rangs_sorts.py`, avec le motif de chacun ; **l'index de sort
continue de compter pour un sort écarté**, sans quoi tous les identifiants glisseraient.

*Défauts de contenu relevés au même audit* (comparaison DBC du dernier rang Blizzard avec
notre premier rang custom, sur les 157) :

- **Météores** : le `EffectBasePoints` du sous-sort 53198 contient l'**identifiant** 53194
  du sort de dégâts appelé. Le bonus plat de druide, +93, lui a été ajouté : le rang custom
  appelait 53287, « Crystal of Unstable Energy ». Le garde-fou « croissance inférieure à
  2 % = c'est un identifiant » n'est appliqué qu'au sort parent, pas aux sous-sorts.
- **Mutilation** et **Estropier** : leurs deux effets pointent chacun vers un sous-sort
  distinct (ours et félin, main droite et main gauche). Le schéma d'identifiants
  « sous-sort = rang + 5 » n'en autorise qu'un : les deux ont été fusionnés. En félin,
  Mutilation prendrait les chiffres de l'ours — dont un pourcentage d'arme de 114 au lieu
  de 199.
- **Bénédiction du sanctuaire supérieure** et **Bouclier d'os** : le rang custom est le
  clone EXACT du rang de Blizzard, rien n'y varie. **Retirés du catalogue** le 2026-08-26.

État après correction : **147 runes**, 441 rangs et 21 sous-sorts, 459 lignes de chaînage
(441 rangs customs et 18 rangs 1 posés). Le serveur démarre, `Validating Spell Scripts`
valide 3 426 scripts sans une erreur.

**Trois manques d'HABILLAGE CLIENT, corrigés le 2026-08-26 après les premiers
essais en jeu.** Ils tenaient tous au même principe : le client ne se contente
pas de ce que le serveur lui envoie, il résout par SES propres fichiers.

- **Les runes n'avaient pas d'icône**, pour deux raisons cumulées. Elles étaient
  absentes de l'`Item.dbc` du client — la leçon des Nexus, à retenir une bonne
  fois : *tout objet custom doit y figurer*. Et leur `displayid` 20860 n'existe
  pas dans `ItemDisplayInfo.dbc`. On crée désormais **une entrée d'affichage par
  rune** (802001 et suivants), qui porte **l'icône du sort amélioré** : la Rune
  de Frappe héroïque montre l'icône de Frappe héroïque. L'icône se lit dans
  `SpellIcon.dbc` à l'identifiant que le sort porte déjà — aucun chemin codé en
  dur, et le nom de fichier seul, sans dossier, comme le veut ItemDisplayInfo.
- **Un rang custom tombait dans l'onglet « Général » du grimoire.** L'onglet
  vient de `SkillLineAbility.dbc`, côté client : un sort qui n'y figure pas
  n'appartient à aucune ligne de compétence. On clone la ligne du dernier rang
  de Blizzard — les 147 sorts retenus en ont une et une seule — en remettant à
  zéro `SupercededBySpell` (le joueur doit CONNAÎTRE tous ses rangs, pas voir
  seulement le dernier) et `AcquireMethod`. 441 lignes, identifiants 30000 et
  suivants. Le serveur n'en a pas besoin : il n'y lit rien qui nous concerne.
- **Une rune sertie laissait le slot vide à l'écran.** `contenu` ne décrit que
  les pierres, dont l'effet est connu ; pour une rune, seul `brut` sait ce qui
  est serti. Le rendu d'un slot, lui, ne montrait jamais d'icône. L'interface
  lit maintenant la rune dans `brut` + le catalogue, pose son icône dans la
  châsse comme une gemme, la nomme dans l'infobulle, et la section « Runes
  actives » du panneau gauche se remplit — regroupée par sort, car trois runes
  d'une même famille ne font pas trois lignes mais trois rangs.

Les trois DBC vont dans **patch-z.MPQ**, avec `Spell.dbc`. La preuve que cette
archive l'emporte sur les archives de locale est désormais directe : nos rangs
customs, qui ne vivent que là, s'affichent en jeu — alors que
`SkillLineAbility.dbc` vient à l'origine de `patch-frfr-3.mpq` et `SpellIcon.dbc`
de `patch-frFR-z.mpq`.

**LE RETRAIT D'UNE RUNE FAISAIT PERDRE LE SORT ENTIER (corrigé le
2026-08-26).** C'est le piège le plus profond rencontré sur les rangs.
Apprendre un rang supérieur **désactive** les rangs inférieurs : `Player::addSpell`
pose `Active = false` et envoie `SMSG_SUPERCEDED_SPELL`, le client remplace
alors le rang 13 par le 14 dans le grimoire et sur les barres. `Player::removeSpell`,
lui, ne fait **jamais** l'inverse — il le dit en toutes lettres dans son propre
commentaire : « can't be replaced by previous rank ». Retirer notre rang
laissait donc le joueur sans aucun rang, et définitivement : `SendInitialSpells`
saute les sorts inactifs, la reconnexion ne le rendait pas non plus.

Deux réparations évidentes sont fausses, et il faut savoir pourquoi :

- `addSpell` **refuse de toucher un sort déjà connu** dans le bon spec — retour
  anticipé dès que `specMask` contient le masque demandé ;
- `removeSpell` puis `learnSpell` **emporte au passage les sorts qui exigent
  celui-là** (`spell_required` : la Prière d'esprit exige Esprit divin) et
  `learnSpell` ne les rend pas, puisqu'il saute ce qui est marqué
  `PLAYERSPELL_REMOVED`.

On rallume donc le drapeau à la main — `Player::GetSpellMap()` et
`SendLearnPacket` sont publics — sur le **sommet** de chaque famille : le
dernier de nos rangs que le joueur conserve, ou le dernier rang de Blizzard
quand il ne lui reste plus aucune rune. Ce dernier cas n'est pas dans
`comptes` : on le retrouve en remontant `GetPrevSpellInChain` depuis le rang
que l'on retire, jusqu'à repasser sous 8 500 000. Reste un effet de bord
assumé : le bouton de barre d'action est vidé par le retrait, comme pour tout
sort désappris ; il faut le reposer à la main.

**Ce que l'interface dit d'une rune (2026-08-26, demandes utilisateur)** : la
confirmation de sertissage annonce « Sertir cette rune vous apprendra *Frappe
héroïque* (rang 14) » et non plus un « Rang 14 » sans sujet ; pour un sort de
**talent**, une seconde ligne donne le **pré-requis** — vert s'il est tenu,
rouge sinon —, car sans le talent la rune reste inerte. `papota_sphere_rune`
porte pour cela deux colonnes de plus, `base_spell_id` (le dernier rang de
Blizzard) et `is_talent` (10 runes sur 147) ; l'état envoyé au client dit
lesquels le joueur remplit *à cet instant*, puisque cela suit ses talents.
L'épingle, enfin, nomme ce qu'elle détruit : « Rune de Frappe héroïque sera
détruite » et non « +0 ? sera détruit » — une rune sertie n'étant plus dans les
sacs, `GetItemInfo` ne la connaît pas, et le nom se reconstruit depuis le sort.
Élision faite au passage, en base comme à l'écran : « Rune **d'**Onde de choc ».

**Ce que l'interface dit d'une rune, deuxième passe (2026-08-26, demandes
utilisateur).** Le rang annoncé tient compte de ce qui est **déjà serti** : la
deuxième rune d'une famille promet le rang 15, la troisième le 16 — la
confirmation comme la liste de choix comptent les runes de la même famille
avant d'annoncer quoi que ce soit. L'épingle dit où le sort **retombera** :
« Rune de Frappe héroïque sera détruite et le sort retournera au rang 15 ».
Un pré-requis non tenu ne se contente plus d'être rouge : le bouton **Valider
est grisé**, le sertissage n'ayant aucun effet tant que le talent n'est pas
pris. Comme `OnShow` est appelé AVANT que l'appelant ne pose `popup.data`, le
blocage passe par une variable de module posée juste avant l'ouverture — même
détour que l'épingle pour griser son bouton quand le sac est vide.

**Une rune sertie peut devenir INERTE** — le joueur perd le talent, la rune
reste en place et ne donne plus rien, c'est la règle du module. Cela se voit
désormais : icône **teintée de rouge**, **anneau rouge** autour de la châsse
(`ping4` en fusion additive, celui des nœuds), et une ligne rouge dans
l'infobulle qui en donne la raison — talent non appris, ou rang de base
inconnu. Le panneau de gauche liste ces runes **sous les actives, en rouge**,
sans rang : les compter serait mentir. La question « cette rune agit-elle ? »
a une seule réponse dans le code, `ACT.RuneActive`, qui lit `etat.requisOk`
envoyé par le serveur — donc à jour à chaque changement de talent.

**Le panneau de gauche, troisième passe (2026-08-26).** Les runes y ont deux
catégories, « Runes actives » et « Runes inactives », le second titre
n'apparaissant que s'il y a lieu. Les lignes de rune sont désormais des
**cadres survolables**, calqués sur les lignes de statistique : la ligne
s'éclaire et les emplacements qui portent cette rune reçoivent le halo des
nœuds — **rouge** quand la rune est inerte. Un slot portant une rune inerte
vire au rouge en entier, icône **et châsse** ; l'anneau rouge essayé d'abord a
été retiré, il faisait doublon avec la couleur.

Deux pièges de cette mécanique, tous deux vérifiés : `MettreAJourRecap` tourne
à la fin de **chaque** `Rebuild`, donc à chaque survol — éteindre la
surbrillance sans condition l'effacerait aussitôt après l'avoir allumée ; et
une ligne masquée pendant qu'on la survole ne reçoit **pas** d'`OnLeave`, sa
surbrillance ressortirait donc sur la rune suivante à occuper la même ligne.
On l'éteint quand, et seulement quand, la ligne change de contenu.

**LE CLIENT NE DEVINE PAS QU'UN RANG REDESCEND (2026-08-26).** Apprendre un
rang supérieur lui est annoncé par `SMSG_SUPERCEDED_SPELL` — « ce sort devient
celui-là » — et **rien n'existe dans l'autre sens**. En retirant la rune, le
serveur avait raison, la reconnexion le montrait, mais le grimoire restait sur
son ancien affichage : les dégâts du rang du bas sous l'étiquette du rang du
haut, jusqu'à un `/reload`. On envoie donc le même paquet à l'envers, et
**avant** le retrait — après, le client ne connaîtrait plus l'identifiant à
remplacer. C'est aussi ce qui fait suivre le bouton de barre d'action, que le
désapprentissage vidait. Le paquet de rappel (`SendLearnPacket`) reste posé
derrière, sans effet quand le remplacement a été reçu.

**La quatrième rune est refusée avant d'être tentée.** Le module tranchait
déjà (`SpherierSertissage::TropDeRunes`), mais le joueur ne l'apprenait qu'au
message d'erreur : la confirmation annonce maintenant « Trois runes au maximum
par sort. » en rouge et grise son bouton Valider.

**UN RANG VIDE N'EFFACE PAS L'ÉTIQUETTE PRÉCÉDENTE (2026-08-26).** Le
remplacement annoncé plus haut marchait pour Frappe héroïque et pas pour Onde
de choc : le sort redescendait bien — dégâts du rang 1 — mais gardait
l'étiquette « Rang 2 » jusqu'à un `/reload`. La cause n'est pas le talent, c'est
le **rang unique** : les vingt familles que Blizzard ne décline qu'une fois ont
un **texte de rang vide** dans `Spell.dbc`, et les dix runes de talent portent
justement toutes sur des sorts de ce genre. En redescendant, le client écrit ce
vide par-dessus « Rang 2 » et le libellé reste. Frappe héroïque, elle, écrit
« Rang 13 » et chasse l'ancien.

Le générateur pose donc **« Rang 1 »** sur le premier rang de ces familles-là.
C'est aussi ce qu'il faut dire : un sort dont nous faisons une chaîne de quatre
a bel et bien un premier rang.

### Runes de statistique (2026-08-26)

**Ce qu'elles font.** Une rune de statistique ne donne pas de points : elle
**majore de 10 % ce que la grille accorde** (5 % à l'origine, porté à 10 le
2026-08-27) dans cette statistique. Elle
s'applique donc APRÈS la somme des pierres, jamais sur une valeur brute du
personnage. Seize objets, un par statistique du catalogue, entrées
**803600 à 803615** — la plage 803400-803599 appartenant aux runes de rang.

**Arbitrages du 2026-08-26.** Les seize statistiques, et pas seulement les cinq
principales : le sphèrier en donne seize, un trou serait inexplicable. Un seul
palier, à 5 % ; les paliers du §9 viendront avec l'établi. Cumul additif
**plafonné à trois**, la même règle que les runes de rang — une seule règle à
retenir, et le plafond était déjà écrit côté module.

**Où vivent les chiffres.** `papota_sphere_stat_rune` (item_entry, stat_id,
percent), rechargeable par `.spherier reload`. Le pourcentage n'apparaît nulle
part dans le code, §3.

**Ce que l'interface montre.** Un slot garni d'une rune de statistique porte
l'icône de sa statistique — la même que les pierres, relevée sur la grille. Le
panneau de gauche donne la forme demandée : **« Rune d'Endurance +10 % (34) »**,
le pourcentage cumulé puis, entre parenthèses, ce qu'il rapporte réellement.

**La ligne « acquis / total » ADDITIONNE la majoration** (arbitrage repris le
2026-08-27 : elle l'excluait d'abord, l'utilisateur a tranché dans l'autre
sens). Ce qui est plus subtil, c'est que **la couleur ne regarde que les
pierres** — une rune ne fait pas une grille complète, elle la dépasse :

| Cas | Affichage | Couleur |
|---|---|---|
| 24 de pierres sur 100 | 24 / 100 | blanc |
| 90 de pierres + 10 d'une rune | 100 / 100 | **blanc** — la grille n'est pas pleine |
| 100 de pierres, aucune rune | 100 / 100 | **vert** |
| 100 de pierres + 10 d'une rune | 110 / 100 | **violet**, celui des objets épiques |

Le vert récompense donc une grille complète, le violet ce qui la dépasse ; et
une rune ne peut pas faire passer une ligne au vert.

**Une conséquence de méthode** : le comptage des runes se fait désormais par
**entrée d'objet** et non par famille de sort. C'est exactement la règle du
module — trois entrées identiques au plus dans la grille — et elle vaut pour
les deux sortes de rune sans distinction.

**Piège relevé au premier démarrage** : le `DELETE` d'`item_dbc` ne couvrait
que l'ancienne plage. Le fichier passait à la main — rien n'existait encore —
mais la **ré-application par l'updater d'AzerothCore** échouait sur
`Duplicate entry '803600' for key 'item_dbc.PRIMARY'`, et l'échec interrompt le
fichier entier : le `DELETE` précédent avait alors vidé `item_dbc` de ses 86
premières entrées sans les réinsérer. Règle : **tout `INSERT` d'un fichier
régénérable doit avoir son `DELETE` sur exactement la même plage**, et une plage
ajoutée en réclame un second quand elle n'est pas contiguë.

**Classeur des icônes (2026-08-26)** : `outils_spherier\gen_tableau_icones.py`
engendre `icones_objets.xlsx`, une ligne par objet du sphèrier — 249 au total,
réparties en cinq feuilles — avec son `DisplayInfoID` actuel, le nom de l'icône
que cet identifiant résout, et une colonne **« Icône souhaitée »** à remplir.
Deux écritures y sont acceptées : un nombre (un `DisplayInfoID` existant, dont
l'apparence est reprise telle quelle) ou un nom d'icône, auquel cas une entrée
d'affichage sera créée comme pour les runes de rang. **Le script ÉCRASE le
classeur** : ne le relancer que pour repartir d'un gabarit vierge, comme
`gen_tableau_butin.py`.

### Les trois défauts de contenu, réparés le 2026-08-26

**Météores : un bonus posé sur un identifiant.** `bonus_plat` choisissait le
premier effet capable de porter une valeur **sans** le garde-fou que
`extrapoler_sous_sort` applique déjà. Or les Météores logent dans ce champ
l'identifiant du sort de dégâts qu'ils appellent — 50287, 53190, 53193, 53194
selon le rang — et lui ajouter +93 le faisait pointer sur « Crystal of Unstable
Energy ». Le garde-fou est désormais partagé, et **il faut la MÉDIANE des pas,
pas leur maximum** : deux identifiants consécutifs ne se suivent pas forcément,
50287 → 53190 fait un saut de 5,8 % qui masquait le reste. Météores n'a plus
rien à faire croître : sa puissance vit **deux** niveaux plus bas, dans le sort
que le sort muet désigne. Il est écarté du catalogue en attendant qu'on
descende ce cran de plus.

**Un seul sous-sort là où il en fallait deux.** Le générateur n'écrivait que le
premier et le faisait pointer depuis *tous* les effets déclencheurs. Mutilation
a pourtant deux formes — l'ours à 90, le félin à 119, avec un pourcentage d'arme
de 114 contre 199 — et le félin héritait des chiffres de l'ours ; Estropier et
Frappe-tempête ont de même une main droite et une main gauche. Un identifiant
par sous-sort désormais, associé à l'effet qui l'appelle ; le second va dans la
plage **8520000**, le bloc de dix d'un rang n'ayant pas la place pour deux. Un
effet déclencheur sans sous-sort à lui garde celui du modèle — le rang de
Blizzard vaut mieux qu'un sort étranger. `bonus_plat` sert lui aussi tous les
porteurs, et non plus le premier seul.

**Les dix chaînes parallèles sont étendues, les huit sorts reviennent.**
`CHAINES_PARALLELES`, dans `analyse_courbes.py`, déclare pour chaque sort les
chaînes qu'un script du cœur indexe par son rang. Elles suivent le même chemin
que les autres — relevé, extrapolation, génération — mais ne donnent **aucune
rune** : c'est le sort parent qui en porte une. Leurs identifiants vivent dans
la plage **8540000** et n'entrent PAS dans le compte de l'index principal, sans
quoi tous les identifiants des sorts suivants glisseraient. Vérifié en base :
chaque chaîne parallèle atteint exactement le rang maximal de son parent.

**PIÈGE DE RE-LECTURE** : `analyse_courbes.py` relit `spell_ranks`, **qui
contient maintenant nos propres rangs**. Les relever comme s'ils étaient de
Blizzard ferait passer Frappe héroïque pour un sort à seize rangs et
extrapolerait à partir de nos propres chiffres. Tout ce qui vit au-dessus de
8 500 000 est écarté au chargement de la table.

État : **154 runes de rang**, 16 runes de statistique, 519 sorts créés dont 27
sous-sorts et 30 rangs de chaîne parallèle, 510 lignes de chaînage. Le serveur
valide 3 444 scripts sans une erreur.

**Piège des plages, deuxième fois** : le nettoyage des runes de rang allait de
803400 à **804399**. Il mordait donc sur les runes de statistique, posées à
803600 : chaque génération des rangs les effaçait d'`item_template`, d'`item_dbc`
et de l'`Item.dbc` du client, sans un mot. Les 154 runes de rang tenant de
803400 à 803553, la borne haute est désormais **803599**, nommée `RUNE_MAX`.
La règle générale, valable pour le SQL comme pour les DBC : **un générateur ne
doit effacer que sa propre plage, bornée au plus juste** — une plage large
« pour voir venir » finit toujours par recouvrir celle du voisin.

### État au 2026-08-27 — l'établi est livré

`SpherierEtabli.{h,cpp}` porte les trois recettes, `cs_spherier.cpp` les trois
sous-commandes `fusion` / `relance` / `refonte` (SEC_PLAYER, empruntées par
l'interface comme l'est le sertissage), et neuf chaînes de message s'ajoutent
en 45-53. L'objet de monde **803700** et son gabarit viennent du SQL du module ;
les apparitions se posent à la main, `.gobject add 803700`.

**Aucun chiffre dans le code, une fois de plus.** La qualité d'une pierre ne se
lit pas dans son identifiant mais dans son **montant** : le catalogue donne le
même montant à toutes les pierres d'une qualité — 5, 7, 10, 15, 30 —, si bien
que « même qualité » se dit « même montant » et « qualité au-dessus » se dit
« le montant juste au-dessus, à effet égal ». Une pierre légendaire refuse de
fusionner parce que les données n'ont rien au-dessus, pas parce qu'une borne
l'a décidé.

**L'ordre des opérations** : la place en sac est vérifiée AVANT toute
destruction (`CanStoreNewItem` puis `DestroyItemCount` puis `AddItem`). Un sac
plein ferait autrement disparaître les composants sans rien rendre.

Interface : `Spherier_Etabli.lua` (catalogue, relais vers les commandes, crochet
d'utilisation de l'objet de monde — événement 14, le même montage que le coffre
hebdomadaire du mythique+) et `Spherier_Etabli_Client.lua`.

**Une fenêtre, TROIS emplacements, et la recette DEVINÉE** (demande du
2026-08-27) — non pas trois panneaux imposant chacun la sienne. On pose ce
qu'on veut ; l'établi reconnaît, montre l'icône du résultat attendu et allume
le bouton. Le résultat d'une fusion est connu d'avance, son icône est donc la
vraie ; les deux autres tirent au sort, mais l'icône reste honnête — **toutes
les pierres d'une même qualité partagent leur apparence**, si bien que montrer
« une pierre de cette qualité » ne promet rien de faux, seule la statistique
étant inconnue, ce que l'infobulle dit. La refonte, elle, peut rendre l'une ou
l'autre sorte de rune : son icône est une rune quelconque, et le mot « hasard »
est écrit.

Trois pierres de même qualité mais d'effets différents ne forment **aucune**
recette — la relance en prend deux — et la ligne d'aide le rappelle. Le
décompte des exemplaires tient compte de ce que les emplacements ont déjà pris,
sans quoi la dernière pierre du sac serait proposée deux fois.

**Couleur de qualité et bouton d'aide (2026-08-27).** Le cadre d'un
emplacement — les trois d'entrée comme celui du résultat — prend la **couleur de
qualité** de ce qu'il porte. La couleur se lit dans `ITEM_QUALITY_COLORS`, la
table du client : la recopier à la main la ferait mentir le jour où le jeu en
change une. La qualité, elle, vient du catalogue, que le serveur lit dans
`item_template` — `GetItemInfo` ne sert que de repli, un objet jamais vu du
client n'y étant pas connu, ce qui est justement le cas du résultat d'une
fusion. Pour la refonte, la couleur n'est annoncée que tant que **toutes** les
runes partagent la même qualité ; si elles venaient à se diversifier, on ne
promet plus rien.

Un bouton **« i »** en haut à gauche explique les trois recettes au survol.
C'est celui du plugin Paragon, `Interface\Common\help-i`, relevé dans son
`UIParagon.xml` : une texture standard du client, à demi effacée au repos et
franche au survol — pas une ressource à empaqueter.

**Échap ferme les fenêtres (2026-08-27).** `UISpecialFrames` est la liste que
le client parcourt à chaque appui : **une fenêtre qui n'y figure pas ne se
ferme jamais ainsi**. Seuls la liste de choix des pierres et l'établi y
étaient ; la fenêtre du sphèrier et celle de l'éditeur non. Les cinq y sont
désormais — sphèrier, sa liste de choix, éditeur, établi, sa liste de choix.

Le client n'en cache **qu'une par appui**, et la plus récemment inscrite passe
la première : Échap referme donc la liste de choix d'abord, la fenêtre ensuite.
Rien n'est perdu au passage — l'`OnHide` du sphèrier fait déjà le ménage (liste
fermée, objet en main reposé) et la disposition de l'éditeur vit dans des
variables de module, qui survivent à un `Hide()`.

**Le premier composant ferme les possibilités (2026-08-27).** Dès qu'un objet
est posé, la liste des suivants ne propose plus que ce qui peut former une
recette valide : une pierre rare n'appelle que des pierres rares — la fusion en
veut trois fois la même, la relance deux de la même qualité, les deux exigent
donc la même qualité — et une rune n'appelle que des runes. Un mélange
impossible ne se compose donc plus par mégarde.

Une subtilité qui compte : **l'emplacement qu'on remplit ne se contraint pas
lui-même**. Rouvrir la liste d'une case déjà garnie doit permettre d'en changer,
et de repartir sur tout autre chose quand c'est la seule posée — sans quoi le
premier choix serait irrévocable.

**Une rune de rang ne se sertit que dans le sphèrier de SA classe
(2026-08-27).** Elle se **loote** toujours sans condition — c'est le §6 et c'est
voulu, un guerrier peut trouver une rune de druide — mais elle n'entre pas dans
sa grille pour autant : l'établi est là pour la refondre. La classe vit en base,
`papota_sphere_rune.class_id`, écrite par le générateur depuis la feuille du
classeur, plutôt que devinée à l'exécution. Les runes de **statistique** ne sont
pas concernées : elles majorent ce que la grille donne, quelle que soit la
classe.

Le module refuse (`SpherierSertissage::MauvaiseClasse`, chaîne 54) et
l'interface n'offre plus ces runes ; la confirmation garde un barrage de dernier
recours, le curseur chargé et le lâcher pouvant y mener par un autre chemin. Le
client apprend sa classe par la définition que le serveur lui envoie —
`UnitClass` ne rend pas d'identifiant numérique en 3.3.5.

**Deux retouches de l'établi le même jour** : la ligne qui dit ce qu'on va
fabriquer passe **au-dessus** des emplacements, pour se lire avant de poser ; et
le refus s'affiche **dans la liste**, en rouge — « Aucun objet dans vos sacs ne
convient ». J'avais d'abord doublé ce message par une ligne dans la fenêtre
elle-même ; l'utilisateur l'a retirée, le refus n'ayant de sens qu'à l'endroit
où l'on cherche.

**Planche-contact de l'art d'interface (2026-08-27)** :
`outils_spherier\extrait_art_interface.py` sort des archives customs du client
tout ce qui peut servir d'habillage — icônes, écrans de chargement et modèles
de l'écran de connexion écartés — sous ses **vrais noms**, un PNG par planche
dans `apercu_interface\`, plus une planche-contact qui les montre toutes avec
leur chemin. **149 planches** ressortent de `patch-z.MPQ` et `patch-frFR-z.mpq`.

Deux détails qui font la lisibilité : les planches sont **rognées** à ce qui est
réellement peint — la plupart sont un dessin dans un coin d'un carré de 1024 ou
2048 — et posées sur un **damier**, sans quoi on ne distingue pas le transparent
du blanc, alors que la moitié sont des cadres évidés.

### Habillage des fenêtres (2026-08-27)

Rien de neuf n'est empaqueté : tout vient des archives du client, relevé par
`extrait_art_interface.py`.

- **Le fond des deux fenêtres** est la **dalle de pierre** du mode logement,
  `housingbasicpanelstonebackground2x` : une planche de 1024 de côté, sombre et
  sans motif marqué, qui s'étire sans que rien ne se répète ni ne se déforme.
- **Le contour** est celui des boîtes de dialogue du jeu, `UI-DialogBox-Border`,
  à la place du filet d'un pixel qui faisait toute l'austérité.
- **Le panneau des statistiques** prend le décor de la **spécialisation
  courante**. `GetTalentTabInfo` rend jusqu'au nom de fichier du décor : on prend
  l'arbre où le joueur a mis le plus de points, rien n'est codé en dur, et
  l'image suit un changement d'arbre sans qu'on s'en mêle.
- **Toutes les typographies** sont celles des infobulles du jeu —
  `GameTooltipHeaderText`, `GameTooltipText`, `GameTooltipTextSmall`.

**Couvrir sans déformer.** Un décor fait 320 par 331, le panneau 196 par 634 :
l'étirer aurait doublé sa hauteur. L'image est donc mise à l'échelle par la
hauteur et l'on ne montre qu'une **bande verticale centrée**. Le panneau étant
étroit, cette bande tombe le plus souvent tout entière dans les quartiers de
gauche, et les deux autres se cachent d'eux-mêmes — le calcul reste néanmoins
général, une largeur différente les ramènerait.

**Ce qu'il fallait mesurer avant d'écrire.** Un décor est peint en **quatre
quartiers** — aucune texture ne dépassait 256 de côté en 3.3.5 — soit 256 + 64
de large et 256 + 75 de haut. Mais les deux quartiers du bas mesurent **128** de
haut : les 53 derniers ne sont que du vide, qu'il faut couper au `SetTexCoord`.

**L'établi**, enfin : les emplacements ne portaient pas un cadre mais **deux**,
la texture de quickslot ayant son propre liseré à l'intérieur de celui de la
qualité — l'emplacement vide ne montre plus que son fond sombre. Et les listes
d'objets sont **opaques** : sans fond plein, le décor se lisait au travers.

**L'établi, mise au point du 2026-08-27** : un **aplat opaque** couvre toute la
fenêtre, bord à bord — le contour des boîtes de dialogue se dessine par-dessus,
sa bordure vivant dans une couche supérieure. La dalle de pierre en est retirée
pour la raison qui l'avait fait retirer du sphèrier : elle n'est peinte que sur
940 × 728 de sa planche de 1024, et laissait donc voir au travers.

**La liste d'objets prend la largeur de son texte le plus long.** La mesure
porte sur **toutes** les entrées et non sur les seules visibles — une entrée en
bas de défilement serait sinon tronquée — et passe par une chaîne cachée de la
même police, `GetStringWidth` ne rendant rien avant que le texte ne soit posé.
Les lignes sont ancrées à gauche ET à droite du cadre, elles suivent donc sa
largeur d'elles-mêmes.

**LA BORNE DE DÉFILEMENT IGNORAIT LE ZOOM (2026-08-27).** Le défilement se
compte en pixels d'écran — `CentrerSur` pose `px * zoom - largeur / 2` — mais la
borne venait de `GetHorizontalScrollRange()`, que **le client calcule sur la
largeur brute de l'enfant, sans tenir compte de son échelle**. Au-delà d'un zoom
de 1, la borne rendue était donc bien plus petite que la course réelle : la
caméra s'arrêtait avant le bord de la grille et les clusters les plus excentrés
restaient hors de vue. En deçà de 1, les deux valent zéro — d'où un défaut qui
ne se voyait qu'à certains zooms.

La course se calcule désormais ici : **largeur du canevas × zoom, moins la
largeur de la vue**. La zone de déplacement est alors exactement celle qui a été
spécifiée — la boîte englobante des centres de clusters élargie d'un rayon de
cluster —, puisque le canevas porte déjà cette étendue : les emplacements sont
posés autour de leur centre à un rayon de distance, si bien que leur boîte
englobante *est* celle des clusters élargie d'autant.

J'avais d'abord ajouté une demi-vue de marge de chaque côté, ce qui masquait le
symptôme en laissant la caméra pousser au-delà du contenu ; cette marge est
retirée.

### Réglage des pierres d'une disposition (2026-08-27)

`outils_spherier
egle_pierres.py` règle qualités, statistiques et nœuds vides
d'une disposition, et **ne touche qu'aux emplacements de type « nœud »** : slots,
emplacements de sort, clusters, liaisons et départ ressortent identiques à
l'octet près — vérifié ligne à ligne avant import.

**L'éloignement se mesure en nombre de LIAISONS depuis le départ**, pas à vol
d'oiseau : c'est le chemin que le joueur paie réellement, et c'est la mesure qui
donne son sens à « bout de ligne ».

**Ce que « les plus lointains et en bout de ligne » a demandé d'arbitrer** : pris
au pied de la lettre, cela ne désignait qu'**un seul** nœud. La grille du
guerrier compte 56 bouts de ligne, échelonnés de 4 à 65 liaisons du départ, mais
une seule branche file jusqu'au bout. On retient donc les **40 % les plus
éloignés des bouts de ligne**, soit 22 légendaires — assez rares pour valoir
quelque chose, assez nombreux pour récompenser chaque branche poussée à son
terme. La part se règle par une constante.

Les quatre autres qualités se répartissent en bandes d'**effectifs** comparables
et non de distances : les nœuds se pressent entre quinze et vingt-cinq liaisons
du départ, si bien que des bandes taillées sur les distances videraient les
qualités hautes.

**L'équilibrage** donne à chaque nœud la statistique dont le total est le plus
bas à cet instant, les plus grosses pierres d'abord — placer les légendaires en
dernier laisserait un déséquilibre que rien ne pourrait plus rattraper. Les
montants de chaque qualité sont **lus dans le catalogue**, jamais recopiés.

État de la grille du guerrier : 343 nœuds dont **35 vides** répartis sur les
dix-sept clusters, 22 légendaires, **douze statistiques** utiles à la classe —
ni intelligence, ni esprit, ni puissance des sorts, ni bonus des soins — et un
écart de **5 points** entre la mieux et la moins bien servie, sur environ 275
chacune.


#### Zonage par spécialisation

La grille se partage en trois secteurs autour de son centre géométrique, un par
spécialisation. **Les axes ne sont pas posés arbitrairement** : ce sont les trois
clusters porteurs de sort, que l'éditeur avait placés aux extrémités et qui se
trouvent écartés d'environ cent vingt degrés — Fureur au nord-est (cluster 20),
Armes au nord-ouest (17), Protection au sud-ouest (19). Chaque branche se termine
donc sur son sort.

Deux courbes se combinent. La **pureté** monte avec l'éloignement au centre :
nulle en deçà de 20 % du rayon, entière au-delà de 88 %, en S entre les deux. La
**netteté angulaire** monte avec elle : près du centre un cluster entend les
trois zones, au bord il n'entend plus que la sienne — ce qui laisse aux clusters
à cheval leur mélange tant qu'ils ne sont pas au bout. Une **épuration** finale
efface, au bord, ce qui ne sert pas à la zone.

**Le tirage est probabiliste**, conformément à la règle : les statistiques utiles
à la zone ont plus de *chances* d'y apparaître, pas la certitude d'y régner.
Prendre à chaque fois la mieux notée donnait des clusters d'une monotonie absurde
— vingt nœuds de pénétration d'armure à la file.

**L'équilibrage se règle par des prix, non par un ordre de passage.** Une
statistique qui traîne voit son prix monter jusqu'à emporter des nœuds. Un
glouton ne pouvait pas convenir : servant les nœuds du bord en premier parce
qu'ils sont les plus contraints, il laissait au centre les seules statistiques
encore en manque, c'est-à-dire les défensives — le centre se retrouvait couvert
de parade et de blocage, l'inverse de ce qu'on lui demande.

**Le centre porte le générique, les branches le spécifique.** C'est ce qui rend
le reste possible : tant que la force valait 1,0 pour les trois spécialisations
*et* pour le centre, l'équilibrage écrasait son prix et la faisait disparaître
partout, y compris au départ. Elle ne vaut plus que 0,70 pour Armes et Fureur,
0,40 pour Protection, et reste à 1,0 au centre.

**La dextérité est écartée de la grille du guerrier.** Elle rendait quelque chose
à un Protection — esquive et armure — et à peu près rien aux deux autres, si bien
qu'exiger d'elle autant de points que des autres la faisait refluer vers le
centre. Onze statistiques qui servent valent mieux que douze dont une encombre.

**Trois d'affilée au plus.** En suivant les liaisons, on ne rencontre jamais
quatre fois de suite la même statistique. C'est bien une LIGNE qu'on mesure, et
non la taille du groupe : quatre pierres identiques en étoile autour d'une
cinquième ne font jamais quatre d'affilée, puisque tout trajet qui les traverse
repasse par le centre — les interdire serait plus sévère que la règle. La
correction fait partie de l'attribution et non d'une retouche après coup, sinon
les prix se règlent sur une répartition qui n'existe plus. Sur la grille du
guerrier elle déplace une vingtaine de nœuds : il reste 190 pierres isolées,
33 paires et 17 lignes de trois, rien au-delà.

État de la grille du guerrier : 343 nœuds dont 35 vides, 22 légendaires, onze
statistiques entre **286 et 311 points** (écart de 25). Le centre donne endurance,
force et critique ; les bouts de branche donnent parade / blocage / esquive,
pénétration d'armure / critique, et toucher / puissance d'attaque / hâte /
expertise. Les zones ne pèsent pas le même poids — Fureur 1323 points, Protection
1068, Armes 912 — parce que les clusters ne sont pas répartis également autour du
centre ; c'est une propriété de la disposition, qu'on ne touche pas.



#### La qualité ne dépend plus que de la distance

**La qualité ne dépend QUE de l'éloignement**, en cinq bandes de distance. C'est
cette forme, et elle seule, qui garantit la transition : deux nœuds voisins ne
diffèrent que d'une liaison de distance, donc au plus d'un cran de qualité —
jamais de légendaire après une rare. Le critère « être en bout de ligne », qui
faisait les légendaires jusqu'ici, est incompatible avec cette garantie et a été
retiré : une feuille légendaire pouvait toucher un nœud rare.

**Le centre du zonage est le DÉPART**, et non le barycentre des clusters. Le
barycentre a l'air plus juste et ne l'est pas : il se déplace dès qu'on ajoute
des clusters, si bien que tout côté qu'on cherche à enrichir devient « central »
et s'appauvrit de ce seul fait.

**La mesure du poids d'une zone est pondérée par la pureté.** Compter un cluster
entier pour sa zone dominante exagère : à 0 % de pureté un cluster n'appartient à
personne.

#### État à la pause du 2026-08-27 au soir

Tout le chantier des sorts est DÉPLOYÉ — binaire du 27/08 20:47, 46 sorts en
base et dans patch-z, réticules, canalisations, icônes, onglets, créatures —
mais **la revue en jeu de l'audit n'a pas eu lieu**. À la reprise : dérouler le
protocole (réticules des neuf sorts au sol en premier, c'est un changement de
comportement visible), puis poursuivre la revue individuelle des sorts — seuls
ceux du paladin et du voleur ont été passés au crible jusqu'ici.

#### L'audit des sorts de classe (2026-08-27), et ce qu'il a corrigé

**Un sort visé au sol exige le drapeau Targets=0x40**, sans quoi le client ne
demande jamais de position et la zone tombe aux pieds du lanceur — le défaut a
traversé tous les premiers tests parce qu'ils se faisaient au corps à corps.
Conventions relevées sur Pluie de feu et Déluge de flammes : dégâts en cible 16,
zone persistante en cible 28. Les novas autour de soi s'écrivent 22/15
(Coup de tonnerre), 22/30 pour les alliés.

**Une invocation empruntée apporte sa faction et ses scripts.** La goule 26125
est faction 14 — hostile à tous — avec le script des pets de chevalier ; le
garde funeste 11859 est un démon en SmartAI. Les invocations sont désormais des
clones à nous (803801-803803, SQL _04_), et l'IA commune npc_papota_invocation
leur donne la faction de l'invocateur et la cible de son maître. Les copies de
la Ruée sauvage gardent le template du familier mais reçoivent faction et cible
par script.

**Le montant d'une absorption ne se corrige pas par SetHitDamage** — il se
décide dans DoEffectCalcAmount de l'aura, et la rage se vide APRÈS le calcul,
à l'application.

**Un déclencheur périodique sans EffectTriggerSpell lance le sort zéro** à
chaque battement ; PreventDefaultAction dans le script, ou nommer le sort dans
le DBC. Le Souffle de Sindragosa fait les deux : canalisation sur le lanceur
qui déclenche le cône 8600054 par le DBC, le script ne payant que la note.

**Une canalisation se dit en trois champs** : AttributesEx 0x4,
InterruptFlags 0xF, ChannelInterruptFlags 0x7C0C — relevés sur Flèches des
arcanes et Fouet mental.

**Divers** : Pleine lune exigeait pile=3 (le compte des phases vit dans les
piles) ; Marche spectrale reçoit l'immunité aux entraves (aura 77, mécanique
11) plus la purge à l'application ; la Ruée ardente brûle 2 % des PV max par
seconde et s'éteint sous 10 % ; Apocalypse fait éclater les MALADIES (+50 %
chacune) ; le Tyran renforce le familier par le DBC (cible 5) ; la Chaîne
d'éclairs d'Ascendance passe au rang max (49271). Les quarante sorts
apprenables rejoignent les onglets du grimoire (gen_sla_classes.py, lignes
SLA 41000+).

#### Les scripts des sorts : quatorze au lieu de trente et un

**L'effet 27, `PERSISTENT_AREA_AURA`, existe en 3.3.5** — c'est lui qui fait la
Consécration et la Pluie de feu. Il pose au point visé un objet dynamique qui
applique une aura périodique à qui s'y trouve, et il couvrait à lui seul toutes
les zones au sol. Trois auras suffisent à les distinguer : **87** majore les
dégâts subis (Jugement dernier ; Mot de pouvoir : Barrière en négatif), **53**
draine la cible ET soigne le lanceur (Singularité fantomatique, Tempête d'os),
**3** brûle (Bombe, Météore, Cataclysme, Pluie de comètes), **31** accélère
(Plume angélique).

Onze autres sorts n'avaient pas besoin de script non plus : un cône de dégâts, un
soin en cône, une canalisation périodique s'écrivent entièrement dans le DBC. On
retire l'accroche plutôt que d'écrire un script vide.

Ce qui reste dans `src/SpherierSorts.cpp` est ce qu'aucun champ ne sait dire :
lire une ressource, tirer au sort, mesurer une distance, invoquer, compter les
incantations, s'adapter à la forme.

**Trois API inexistantes, attrapées avant le build.**
`GetAttackableUnitListInRange` et `GetAlliesWithinRange` n'existent pas dans ce
cœur. Plutôt qu'une recherche manuelle, on laisse le DBC choisir les cibles : le
Halo reçoit deux effets de zone et le script ne fait plus que doser selon la
distance, l'Orbe des arcanes devient un simple cône — ce qui dit déjà « tout ce
qui est sur sa route » sans une ligne de C++ — et Floraison parcourt le groupe,
qui est de toute façon la portée utile d'un soin. `Unit::DealDamage` est statique
et prend `SPELL_DIRECT_DAMAGE` ; `HasInArc` attend un `Position const*`.

**Un faux échec de compilation, à ne pas rejouer.** Le build a été signalé en
échec alors qu'il avait réussi : la commande finissait par un `grep -c` des
erreurs, et `grep` sort en code 1 quand il ne trouve RIEN — c'est-à-dire quand
tout va bien. Ne pas terminer une commande de build par un grep dont le code de
retour devient celui de la commande.

#### Rétroporter un visuel moderne (fait pour la Lumière de l'aube)

La chaîne d'outils : **WoW.export** (sort déjà en MD20 ici) → **FixTXID** avant
toute conversion — il écrit les chemins de textures dans le M2 à partir des
FileDataID — → **MultiConverter** si le M2 est encore MD21. Les fichiers vont
dans patch-z sous `spells\`, textures comprises, **plus le `<nom>00.skin` de
chaque M2** : c'est l'oubli classique, tous les M2 à vues en exigent un.

Côté client, trois DBC font exister le modèle, et la chaîne est toujours :

    Spell.SpellVisualID -> SpellVisual (quel kit à quel moment)
                          -> SpellVisualKit (quel effet à quel point d'attache)
                           -> SpellVisualEffectName (le chemin du modèle, en .mdx)

Conventions maison, relues dans l'archive : effets nommés en **82002xx**, kits et
visuels en **300xx** ; un kit sans animation porte -1 dans ses deux premiers
champs ; le **BaseEffect** suit l'orientation du lanceur (bon pour un cône
dessiné vers l'avant), le **ChestEffect** fleurit au buste de chaque cible
touchée. `outils_spherier\gen_visuel_aube.py` fait tout le montage, idempotent.

**Piège vu en vrai : la rotation de tuile des émetteurs.** WotLK n'admet que
-1 à 1 sur textureTileRotation (octet 0x2E de l'émetteur) ; les modèles
rétroportés peuvent garder des valeurs modernes (-20, 50, 100). Sur une texture
en damier — chaque particule montre une case — l'échantillonnage déborde alors
sur les cases voisines : des points servis dans des carrés translucides. Les
imports sains restent entre 0 et 4 ; ramener à zéro tout ce qui dépasse.
Diagnostic, dans l'ordre, pour un rendu de particules faux : alpha de la
texture (décodage DXT), mode de fusion (octet 0x28), damier lignes/colonnes
(0x30), rotation de tuile (0x2E) — toujours en COMPARANT AUX IMPORTS SAINS.

**Texture invisible : ne pas fabriquer un BLP, en cloner un.** Deux essais
faits main — BGRA brut puis palettisé — sont restés illisibles pour le client,
qui rend une texture illisible EN VERT. La voie sûre : cloner un BLP natif DXT
à alpha (ils dominent chez Blizzard) et mettre ses mips à zéro — des points
d'alpha nuls rendent chaque bloc invisible, quel que soit le reste. C'est
`spells\papota_vide.blp`, à réutiliser pour éteindre n'importe quel émetteur.

**Piège vu en vrai, erreur 132 au lancer** : certains M2 rétroportés sortent
avec une table `texUnitLookup` VIDE alors que leurs lots de rendu réclament une
à deux entrées — le client déréférence une table à l'adresse nulle
(« referenced memory at 0x00000000 »). Les imports sains montrent la forme
attendue : une entrée par unité, valant son rang — [0] pour une texture,
[0, 1] pour deux. `outils_spherier
epare_m2_texunit.py` diagnostique et
répare (table ajoutée en fin de fichier, en-tête repointé, idempotent).
Diagnostiquer en COMPARANT AUX IMPORTS QUI MARCHENT : skins, bornes des
tableaux, lots de rendu — c'est le différentiel qui a désigné la cause, pas la
lecture du seul modèle fautif.

**Piège vu en vrai** : FixTXID peut écrire un chemin de texture avec une espace
parasite (« alpha grad4_paladin.blp »). Le M2 est autoritaire — déposer la
texture sous ce nom-là aussi, plutôt que de retoucher le M2.

#### Les quarante sorts de classe

Quatre par classe — un de mobilité commun à la classe, un par spécialisation —
repris des extensions postérieures à Wrath. Tous à **rang unique** : aucune ligne
dans `spell_ranks`, ce qui écarte au passage le plantage de `GetSpellWithRank`.

**Les identifiants se lisent : 86000CS**, où C est le numéro de classe dans
l'ordre du jeu et S le numéro du sort dans la classe — 0 pour la mobilité, 1 à 3
pour les spécialisations. Le sort 8600031 est le premier sort de spécialisation
du voleur.

`outils_spherier\sorts_classes.py` porte la table des quarante sorts,
`gen_sorts_classes.py` les fabrique des deux côtés : la table `spell_dbc` pour le
serveur, le Spell.dbc de patch-z.MPQ pour le client.

**La carte des champs n'est pas devinée.** Les 234 colonnes de `spell_dbc`
suivent exactement l'ordre des 234 champs du DBC : on la lit dans
`information_schema` et l'on écrit TOUTES les colonnes, plutôt que d'en choisir
vingt et de s'en remettre aux défauts de la table. Cela a attrapé deux erreurs :
la colonne s'appelle `ManaCostPct` et non `ManaCostPercentage`, et le bloc de
texte du rang est à l'index **153** (NameSubtext), pas 204 — où se trouve
justement `ManaCostPct`. Le confondre effaçait le coût de chaque sort.

**LA RÈGLE DE DIRECTION**, dans `src/SpherierSorts.cpp` : un déplacement linéaire
part dans la direction où le personnage VA s'il bouge, et devant lui s'il est
immobile. Le client envoie un masque de touches — `MOVEMENTFLAG_FORWARD` 0x1,
`BACKWARD` 0x2, `STRAFE_LEFT` 0x4, `STRAFE_RIGHT` 0x8 — dont on déduit l'angle
RELATIF à l'orientation. Masque vide, l'angle vaut zéro.

Deux pièges du cœur, payés une fois :

- **`MotionMaster::MoveJumpTo` refuse les joueurs**, et son propre commentaire dit
  pourquoi : « this function may make players fall below map ». Il passe par
  `GetClosePoint`, qui ne teste pas la géométrie. Pour un joueur il faut
  `MovePositionToFirstCollision` puis `MoveJump`.
- **`MovePositionToFirstCollision` ajoute elle-même l'orientation** à l'angle
  qu'on lui donne. On lui passe donc l'angle relatif, jamais l'absolu, sans quoi
  le bond part au double de la direction voulue.

**Les visuels sont tous empruntés** : le client de 3.3.5 n'a l'art d'aucun de ces
sorts. C'est le champ qui demandera le plus de retouches, et il tient dans un
numéro de `sorts_classes.py`.

**Les paliers** disent le travail restant : ① l'effet vit entièrement dans le
DBC, ② un script court le complète, ③ la mécanique est à écrire. Six sorts sont
de palier ① et complets dès la génération.

**Le SQL est en trois fichiers, et l'ordre compte** : les enregistrements
(`..._00_...`), puis les accroches de script — mais seulement celles dont le
script C++ existe (`..._02_..._prets.sql`). Le cœur refuse un nom de script
inconnu et le signale à chaque démarrage ; le fichier `..._01_...` garde les 34
accroches pour quand les scripts seront écrits.

#### La taille d'une grille se déduit du nombre de statistiques

**Le total de points d'une grille ne dépend que du nombre de pierres et de la
pyramide des qualités ; il se partage ensuite entre les statistiques utiles.**
Pour que chacune en reçoive trois cents, il faut donc autant de pierres que la
classe a de statistiques — une grille de mage n'a pas à être aussi vaste qu'une
grille de druide. À taille égale, le démoniste sortait à 530 points par
statistique avec sept, et le druide à 240 avec quatorze.

On résout donc à l'envers : trois cents points par statistique donnent le total,
le total donne le nombre de pierres, et de là le nombre de clusters et leur
taille. Le nombre de clusters reste borné entre dix-huit et trente-deux, pour que
deux grilles ne soient pas d'aspect trop différent.

**Les motifs rendent un peu moins que la mesure demandée** — ils se trouent plus
volontiers qu'ils ne se remplissent. On corrige donc le tir plutôt que d'espérer :
on bâtit, on compte, et l'on relance d'un cran tant que le total reste sous la
cible.

#### Chaque statistique doit avoir une branche où elle est chez elle

Le démoniste avait seize nœuds d'endurance parmi les quarante plus proches du
départ. Ce n'est pas le hasard : **une statistique que les trois spécialisations
dédaignent n'a nulle part où aller**, et l'équilibrage la pousse au centre — c'est
là que le profil discrimine le moins, donc là qu'un prix élevé l'emporte le plus
facilement.

Le même défaut se lisait dans huit classes sur dix, et presque toujours sur
l'endurance. On lui donne donc partout une spécialisation qui la veut vraiment —
la plus résistante des trois : Survie chez le chasseur, Finesse chez le voleur,
Discipline chez le prêtre, Amélioration chez le chaman, Givre chez le mage,
Démonologie chez le démoniste, Farouche chez le druide — et l'on baisse d'autant
sa valeur au centre. Même traitement pour l'esprit chez les lanceurs, l'esquive
chez le voleur et le druide, la pénétration d'armure chez le chevalier de la mort.

**La force sort de la liste du voleur** : il n'en tire à peu près rien, et une
statistique qu'aucune branche ne veut n'a rien à faire sur la grille.

Un contrôle vérifie qu'aucune statistique n'a une affinité maximale inférieure à
0,70 sur ses trois spécialisations.

#### Les dix grilles, et ce que vos retouches ont appris

`outils_spherier\genere_grille.py` fabrique la disposition complète d'une classe.
Il est écrit d'après la grille du guerrier **telle que vous l'avez retouchée** :
cent liaisons retirées, douze ajoutées, et le motif s'y lit sans ambiguïté.

**UN CLUSTER EST UN ARBRE.** Vos suppressions touchaient tous les genres — arcs,
rayons, diagonales — jusqu'à ce qu'aucune boucle interne ne subsiste : vingt
clusters sur vingt-neuf sont des arbres exacts. Une boucle offre deux chemins
vers la même place et défait le labyrinthe. Le générateur tire donc un **arbre
couvrant au hasard** plutôt que de poser des liaisons par règle.

**UN TRAIT PEUT ALLER OÙ IL VEUT S'IL PASSE AU LARGE.** Vos ajouts comprennent
une corde de diamètre et trois sauts d'anneau — des traits que la règle de
l'éditeur n'aurait jamais posés, et qui sont propres parce que la place du milieu
est absente. Le critère n'est donc pas le genre du trait mais son **dégagement** :
tout couple de places est candidat pourvu que le segment reste à 0,70 des autres.
Le plus serré que vous ayez gardé passe à 0,78, soit cinquante pixels.

**CHAQUE CLUSTER A SON VISAGE.** Neuf familles de motifs — plein, secteurs,
couronnes, rayons, spirale, croissant, noyau, demi, damier — tirées au sort puis
trouées. Sur les 261 clusters produits, **210 silhouettes distinctes** à rotation
près.

**Le départ est la place centrale du cluster central**, à l'origine exacte du
maillage, qui est aussi le centre de la boîte englobante.

**Le piège de la division.** Le graphe des ponts est connexe entre CLUSTERS ;
diviser un cluster le dédouble, et rien ne garantit que ses deux moitiés restent
du même côté. Le premier jet a coupé cent quatre-vingt-sept places du reste de la
grille. On vérifie donc l'atteignabilité morceau par morceau, et l'on défait une
division tant que la grille reste coupée — défaire ne peut que rapprocher, si
bien que la boucle s'arrête toujours.

`outils_spherier\profils_classes.py` porte ce que chaque spécialisation sait
employer, écrit **par archétypes de rôle** — tank, mêlée force, mêlée dextérité,
distance, lanceur, soigneur — que chaque spécialisation retouche de quelques
valeurs. Dix classes fois trois spécialisations fois seize statistiques font près
de cinq cents chiffres, et une table écrite à la main à cette taille ne se relit
pas. Deux spécialisations du même rôle diffèrent malgré tout : un mage Arcane vit
de l'intelligence, un Feu du critique, un Givre de la hâte, faute de quoi leurs
zones proposeraient la même chose.

**Les axes des zones ne sont plus saisis.** On retrouve les clusters porteurs de
sort, on les ordonne par angle croissant depuis le départ, et on les apparie aux
trois spécialisations dans l'ordre de la table. La règle vaut pour toutes les
classes sans rien écrire de particulier.

| Classe | Clusters | Emplacements | Liaisons | Stats | Points par stat |
|---|---|---|---|---|---|
| Guerrier | 29 | 589 | 610 | 11 | 364-369 |
| Paladin | 32 | 625 | 629 | 14 | 300-303 |
| Chasseur | 20 | 365 | 367 | 8 | 298-301 |
| Voleur | 23 | 399 | 401 | 9 | 292-296 |
| Prêtre | 20 | 373 | 375 | 8 | 297-301 |
| Chevalier de la mort | 25 | 458 | 461 | 10 | 301-306 |
| Chaman | 30 | 534 | 538 | 12 | 296-301 |
| Mage | 18 | 325 | 328 | 7 | 291-295 |
| Démoniste | 18 | 334 | 336 | 7 | 296-300 |
| Druide | 32 | 632 | 637 | 14 | 308-312 |

La grille du GUERRIER est la vôtre et n'a pas été redimensionnée : elle reste à
364-369 points. La ramener vers 300 sans toucher à sa disposition demanderait de
porter les nœuds vides de 35 à environ 135 — une centaine de pierres en moins sur
543. C'est une ligne à changer, mais c'est votre décision.

Le total de points est comparable d'une classe à l'autre ; ce qui varie est le
NOMBRE de statistiques entre lesquelles il se partage. Un mage n'en emploie que
sept et en tire cinq cents de chacune ; un druide en emploie quatorze et en tire
deux cent quarante.

Toutes les règles tiennent sur les dix grilles : aucun saut de qualité de plus
d'un cran, aucune rare touchant une légendaire, une légendaire par cluster au
plus, jamais quatre fois de suite la même statistique, 35 nœuds vides, et aucune
statistique hors de ce que la classe emploie.

#### La pyramide des qualités, et la légendaire promue

**Les montants des pierres — 5 / 7 / 10 / 15 / 30 — ne sont PAS le levier du
volume de statistiques.** Un essai les avait ramenés à 3/4/6/9/18 pour faire
baisser les totaux ; c'est un réglage d'objet, qui touche aussi le butin et
l'établi, et il a été annulé. C'est la RÉPARTITION DES QUALITÉS qui règle le
volume, par `PARTS` dans `regle_pierres.py`.

**Quatre bandes de distance seulement** — commune, inhabituelle, rare, épique —
et une pyramide qui penche vers le bas : 48 / 29 / 15 / 8. Beaucoup de communes
et d'inhabituelles, peu d'épiques.

**La légendaire n'est pas une bande, c'est une PROMOTION.** « Une légendaire au
plus par cluster » ne se dit pas avec une bande de distance : un cluster profond
en déposerait une douzaine d'un coup. On promeut donc, dans chaque cluster, le
nœud le plus éloigné — et lui seul.

**Elle est promue AVEC SON HALO.** Exiger qu'elle soit déjà entourée d'épiques
liait deux choses sans rapport : plus la bande épique se resserre — et on la veut
resserrée — moins de clusters pouvaient en porter une, deux ou trois sur
vingt-neuf. Ses voisins passent donc en épique, juste ce qu'il faut pour
qu'aucune légendaire ne touche une rare : cinq épiques de halo pour huit
légendaires, au lieu d'une bande entière. La promotion se pose à l'essai et se
défait si elle casse quoi que ce soit — un halo peut toucher une inhabituelle en
contrebas, et le saut serait de deux crans.

Résultat sur la grille du guerrier : **264 communes, 172 inhabituelles, 63 rares,
35 épiques, 8 légendaires**, une par cluster au plus, dans les clusters 6, 10, 19,
20, 22, 24, 26 et 28. Les épiques sont divisées par trois (102 auparavant), les
communes gagnent la moitié (171) et les inhabituelles 42 % (121). Onze
statistiques entre **354 et 358 points**.

**Ce que la pyramide ne peut pas faire.** Avec ces montants et 542 nœuds portant
une pierre, le plancher absolu est de 246 points par statistique — tout en
communes. Viser 300 exactement demanderait environ 85 % de communes, c'est-à-dire
une grille grise. Le levier qui reste, si l'on y tient, est le NOMBRE DE NŒUDS
VIDES : il en faudrait environ 120 au lieu de 35 pour descendre de 356 à 300.

#### L'équilibrage : mêmes sommes, formes libres

**On impose la SOMME, jamais la forme.** Exiger que chaque statistique reçoive
autant de pierres de chaque qualité donne une matrice parfaite et un sphérier
abîmé : les cent soixante et onze pierres communes vivent toutes près du départ,
si bien que réclamer seize communes pour la parade la fait remonter au centre. Le
nœud de départ s'est retrouvé avec huit statistiques défensives sur dix-huit,
quand la règle du centre en demande peu. Chaque statistique atteint donc la même
somme, mais pas par le même chemin : celle qui vit au bord la fait en peu de
grosses pierres, celle qui vit au centre en beaucoup de petites.

**Les cibles viennent d'un ajustement biproportionnel.** On part de la
répartition NATURELLE — combien de fois chaque statistique sortirait à chaque
qualité si les prix n'existaient pas, ce que les profils de zone dictent — et
l'on met alternativement les colonnes puis les lignes à leur marge : chaque bande
place toutes ses pierres, chaque statistique atteint la même somme. La forme de
chaque profil reste celle que la géométrie commande ; seule son échelle bouge.

**La correction finale place les dernières pierres à la main.** Un prix agit sur
des probabilités : il ne peut plus rien quand il ne manque qu'une pierre. Or une
légendaire mal placée vaut trente points — l'écart entre statistiques passait de
quatre à cinquante-huit pour ce seul nœud. On termine donc en déplaçant le nœud
dont le changement coûte le moins d'affinité, sans jamais casser la règle des
trois d'affilée.

**Le prix est borné serré, à huit.** Une borne large amenait chaque case à sa
cible du premier coup — une seule pierre à replacer au lieu de vingt — mais au
prix des zones : la pénétration d'armure allait se loger jusqu'au bout de la
branche de Fureur, où elle n'a rien à faire. Le prix tranche les cas faciles, la
correction finale place le reste en connaissance des zones.

Résultat sur la grille du guerrier : les cinquante-cinq cases tombent **toutes**
sur leur cible, et l'écart entre la statistique la mieux et la moins bien servie
vaut **4 points** sur 508 — l'optimum arithmétique, cinq cent quarante-deux nœuds
ne se divisant pas par onze. La parade et le blocage vivent en dix-sept épiques et
six légendaires, la force en trente-six communes : mêmes sommes, progressions
différentes.

#### La caméra : le centre atteint les nœuds extrêmes

**La borne du défilement se pose sur LES NŒUDS LES PLUS EXCENTRÉS en X et en Y,
et le centre de la vue doit pouvoir les atteindre exactement.** Borner sur le
canevas revenait à pouvoir amener le bord du contenu au bord de l'écran mais
jamais en son milieu.

**LE DÉFILEMENT D'UN SCROLLFRAME SE COMPTE DANS L'UNITÉ DE L'ENFANT**, jamais en
pixels d'écran. Le canevas est mis à l'échelle par `SetScale(zoom)` : une unité
de défilement vaut donc zoom pixels d'écran, et la demi-vue qui sépare le bord de
la vue de son centre vaut `largeurVue / (2 × zoom)` unités de canevas. Amener le
point `px` au centre demande

    défilement = px − largeurVue / (2 × zoom)

et non `px × zoom − largeurVue / 2`.

C'est l'erreur qui a coûté deux tours. Sa signature est un COUPLE de symptômes
qu'il faut savoir lire : des zones entières hors d'atteinte d'un côté **et** du
vide accessible de l'autre, au même moment. Un seul des deux aurait pu venir
d'une marge mal réglée ; les deux ensemble ne peuvent venir que d'un facteur
d'échelle faux. Mesuré sur la grille du guerrier : quarante-neuf unités de grille
manquantes au bord droit à zoom 0,30, et quarante-deux de trop à zoom 1,60. **À
zoom 1 les deux calculs coïncident** — c'est ce qui rendait le défaut invisible
là, et là seulement.

Le glisser-déposer suit la même règle : le curseur se mesure en pixels d'écran,
il faut donc le diviser par le zoom pour le convertir en défilement.

`GetHorizontalScrollRange` ne sert à rien ici : le client le mesure sur la
largeur BRUTE de l'enfant, sans tenir compte de son échelle. Le canevas garde
malgré tout une réserve — au moins la vue brute plus deux marges — pour que cette
borne fausse reste au-delà de la nôtre, au cas où le client s'en servirait.

Le défilement vertical part du HAUT du canevas quand les positions partent du
BAS : l'inversion échange aussi les deux bornes, le nœud le plus haut donnant la
borne la plus basse.

Vérifié par simulation à sept zooms de 0,30 à 1,60 : le centre atteint exactement
-27,35 à 41,35 en X et -128,19 à -84,06 en Y, les bornes restent positives, et il
reste de 94 à 1938 px de réserve sous la borne du client.

#### Les nexus : un maillage aligné, des carrefours divisés

`outils_spherier\ajoute_nexus.py` ajoute des clusters **sans jamais réécrire ce
qui existe** — ni cluster, ni emplacement, ni liaison, ni départ ; le fichier ne
fait que grossir, et l'éditeur reprend les nexus fabriqués comme les siens
puisque les liaisons internes suivent sa règle.

**Le maillage est aligné.** Chaque nexus partage son abscisse, son ordonnée ou sa
diagonale exacte avec un autre nexus, et **aucun n'est tourné**. Le pas est de
huit, l'écart entre deux clusters voisins de la disposition d'origine, si bien
que les nexus s'alignent aussi sur les clusters existants. Un premier jet les
avait posés librement, avec des rotations : cela se lisait comme un semis, pas
comme un plan.

**Les nexus sont fournis.** Dix-huit à vingt et une places sur vingt-cinq. Le
même premier jet occupait dix à quatorze places en branches isolées — une croix,
une étoile —, ce qui donnait une géométrie pauvre et un dessin dégarni. On part
du plein et l'on creuse : **ce sont les MURS qu'on choisit, pas les couloirs.**

**Un carrefour peut être DIVISÉ, et c'est de là que vient le labyrinthe.** Son
réseau interne se coupe en deux morceaux qui ne communiquent pas ; il porte
quatre ponts, deux par morceau. Venant du cluster 17 on entre dans le premier
morceau du nexus 22 et l'on n'atteint que le nexus 23 : pour aller vers le 24 il
faut onze liaisons par le tour extérieur, alors que le nexus a l'air d'un
carrefour. Aucune place centrale dans ces formes — elle toucherait tout le
premier anneau et ressouderait les deux moitiés.

**L'ordre des morceaux vient du tri des places**, et il faut le lire, pas le
supposer : dans le carrefour tourné vers l'ouest, (1,1) passe avant (1,3), si
bien que le morceau 0 tient les branches 7-8-1 et non 3-4-5. S'y tromper fait
partir les ponts de l'anneau intérieur, à cinq de long au lieu de deux. Le
rapport de l'outil affiche les branches de chaque morceau pour cette raison.

Trois quartiers, un par spécialisation, chacun en losange : un carrefour au
milieu, trois satellites autour, le quatrième côté ouvert sur la disposition
existante. Accroches : cluster 17 pour les Armes, 19 pour Protection, 9 pour
Fureur. Aucun pont ne dépasse 5,1 quand les plus longs de la disposition
d'origine en font 7,0.

**Chaque nexus s'écarte un peu de la règle de l'éditeur.** Douze nexus qui la
suivent à la lettre se ressemblent tous. Deux sortes de variation, et elles ne se
valent pas : **retirer** une liaison allonge un trajet et ouvre une impasse —
c'est la plus utile au labyrinthe, et la plus discrète, puisqu'elle fait moins de
traits et non davantage ; **ajouter** une diagonale, d'un anneau au suivant et
d'une branche à la voisine, ouvre un passage oblique parmi les arcs et les rayons.

Les diagonales se prennent sur les anneaux EXTÉRIEURS, où les places sont assez
écartées pour que le trait passe au large des autres. Une corde à travers un
anneau passerait par-dessus la place du milieu — à six pixels de son centre, on
l'a mesuré — si bien que l'outil vérifie le dégagement de chaque trait ajouté et
refuse ce qui frotte. Les carrefours divisés gardent leurs deux moitiés : une
variation qui les ressouderait est refusée par le compte de morceaux.

État de la grille du guerrier : **29 clusters, 588 emplacements** (577 nœuds dont
35 vides, 8 slots, 3 sorts), **698 liaisons**. Qualités 171 / 121 / 104 / 102 / 44.
Onze statistiques entre **305 et 308 points**, écart de 3. Zones pondérées :
Protection 24 %, Fureur 18 %, Armes 15 %, commun 42 %.

**PIÈGE ctypes/StormLib, à ne pas redécouvrir** : `SFileOpenArchive`,
`SFileOpenFileEx` et `SFileReadFile` renvoient un `bool` C++, donc **un seul
octet**. Sans `restype = c_bool`, ctypes lit quatre octets et les bits de poids
fort, laissés tels quels par l'appelant, font passer un FAUX pour un VRAI : on
croit avoir ouvert un fichier que l'archive ne contient pas, et la taille
ressort à zéro. Symptôme : « buffer of at least 20 bytes… actual buffer size is
0 » sur le premier DBC absent de l'archive la plus prioritaire.

**Reste à faire pour clore le jalon 5** : étendre les dix chaînes parallèles et rétablir
les huit sorts écartés ; réparer Météores, Mutilation et Estropier ; l'établi et ses quatre
recettes (§9) ; les runes de statistique — celles qui donnent un pourcentage aux gains du
sphèrier — ; et les tests en jeu, dont un point ouvert : la façon dont le client affiche
deux rangs d'un même sort dans le grimoire, que le chaînage `spell_ranks` pourrait réduire
à un seul.

### État au 2026-08-23 — jalon 4 avancé : l'interface joueur (demande utilisateur)

Livrée avant le jalon 3, accessible par le bouton « Sphèrier » de la fenêtre des
talents (accroché au chargement de `Blizzard_TalentUI`, position provisoire),
par `/spherier` et par `.spherier show`. Fichiers : `Spherier_Joueur.lua`
(serveur) et `Spherier_Joueur_Client.lua` (client, expédié par AIO), textes
bilingues côté client via `GetLocale()`.

Architecture : le serveur Lua lit la définition dans `papota_sphere_*` et l'état
dans `character_sphere_*` ; **l'achat passe par `player:RunCommand("spherier
activate N")`** — la commande, passée `SEC_PLAYER`, s'exécute avec la session du
joueur : règles (départ, adjacence, coût, classe) et messages localisés restent
dans le module C++, l'interface n'est qu'une vue. Les écritures du module sont
devenues **synchrones** (`DirectExecute` / `DirectCommitTransaction`) pour que
la relecture immédiate après achat soit toujours fraîche.

Rendu : celui de l'éditeur (disque + anneau de qualité + icône ronde, châsse de
gemme, arcs cuits, départ cerclé d'or) avec trois états — actif (pleine
couleur), achetable (atténué 0.55, clic → confirmation), non adjacent (éteint
0.15) ; liaisons cyan entre actifs, grises en frontière, éteintes ailleurs.
Raffinements des 2026-08-23/24 : l'emplacement de **sort** est habillé du
**cadre de sort du grimoire custom NewSpellBook** (mod du client dans
`patch-frFR-z.mpq`, planche `Spellbook-Parts`, régions relevées dans
`NewSpellBookFrame.xml`) — assiette parchemin, icône **carrée** du sort, cadre
orné de sarments : **or** quand le sort est actif (ou en édition), **brun
« non appris »** sinon (interface joueur, et Aperçu de l'éditeur) ; l'or ne se
teintant pas, la couleur de base des états est le blanc. Le centre d'un
**nœud vide** est bouché par un disque opaque sombre découpé rond par le
masque de portrait.

**Récapitulatif des statistiques (2026-08-24, demande utilisateur)** : un
panneau à gauche de la grille liste les **seize** statistiques du catalogue,
chacune sous la forme « acquis / total de la grille » — l'acquis étant la somme
des pierres réellement serties dans les emplacements actifs, le total ce que la
grille entière donnerait si toutes ses pierres étaient activées. Une
statistique absente de la grille reste affichée, mais éteinte. Survoler une
ligne **allume d'un halo toutes les pierres de cette statistique**, achetées ou
non, ce qui montre d'un coup d'œil où elles se trouvent. Les montants viennent
de `papota_sphere_stone`, jamais d'un calcul sur l'entrée de l'objet. Une
section « Runes actives » est en place sous les statistiques ; elle restera
vide jusqu'au jalon 5, le serveur n'ayant encore aucune rune à envoyer.

**Achat de chemin (2026-08-23, demande utilisateur)** : cliquer n'importe quel
emplacement inactif calcule le plus court chemin (en sauts) depuis l'actif le
plus proche — ou depuis le départ, inclus, si rien n'est actif —, l'infobulle
et la confirmation affichent le nombre d'emplacements et le **coût total**
(barème appliqué séquentiellement), et l'achat confirmé se fait d'un coup,
tout ou rien : le serveur verrouille le coût total avant le premier achat
(refus en texte rouge sinon), puis achète dans l'ordre du chemin par la
commande du module, chaque étape re-vérifiant toutes les règles.
Pour les arcs, la géométrie des clusters est entrée en base :
`papota_sphere_cluster` + colonnes `cluster`/`ring`/`branch` sur
`papota_sphere_node`, remplies par l'importeur (le module C++ les ignore).
`/spherier` a été retiré de l'éditeur (collision de slash) — l'éditeur s'ouvre
par `.spherier editor` uniquement. La garde admin des handlers tolère le joueur
factice des bancs d'essai hors serveur.

Validation : `worldserver --dry-run` — monde initialisé en 4 min 21 s, ligne de chargement
conforme aux amorces. Deux acquis : `DatabaseEnv.h` ne tire ni `QueryResult.h` ni `Field.h`
(à inclure explicitement) ; le dry-run crashe à la **terminaison** (`exit(0)` court-circuite
l'ordre de destruction, destructeurs OutdoorPvP) — défaut préexistant du cœur, sans effet
sur l'arrêt normal. Reste à confirmer `info`/`reload` au prochain démarrage réel.

### État au 2026-08-23 — l'éditeur de disposition

Le travail s'est porté d'abord sur l'interface, avant tout code de jeu. **Le visuel est
validé** (soirée du 2026-08-23) : nœud = cercle (disque + anneau de qualité + icône ronde),
slot = châsse de gemme Blizzard, arcs lisses cuits en texture, liens fins (EDGE_THICK = 5),
infobulle stat + bonus. Ce qui existe se trouve dans `lua_scripts\Spherier\` :

| Fichier | Rôle |
|---|---|
| `Spherier_Server.lua` | Géométrie, catalogue, écriture / relecture / contrôle du XML |
| `Spherier_Client.lua` | L'éditeur, expédié au client par AIO |
| `layouts\*.xml` | Les dispositions, plus `index.txt` qui en tient l'inventaire |

Ouverture par `.spherier` ou `/spherier`. Aucun code de jeu : ni base, ni statistiques, ni
persistance de personnage. Rien de tout cela n'est destiné à survivre au jalon 1, sauf le
format XML et la géométrie des clusters.

**Le cluster.** Trois anneaux concentriques de huit emplacements, alignés en huit branches
rayonnant du centre, **plus une place centrale** (révision du 2026-08-23) — soit 25 places.
Rayons **1.1 / 2.1 / 3.1** : corde intra-anneau 0.84 au plus serré, écart entre anneaux
1.00. Un cluster mesure 6.2 unités de diamètre, deux voisins doivent donc être distants
d'au moins 6.9 unités. La place centrale (anneau 0) est vide à la pose du cluster et se
remplit comme toute place vide ; le repère de déplacement du cluster s'écarte quand elle
est occupée.

**Les quatre outils.** Sélection (modifier un emplacement, clic droit pour le retirer, clic
sur une place vide pour l'y rétablir, glisser un repère pour déplacer le cluster) ; Cluster
(poser, supprimer) ; Lier (deux clics pour créer ou retirer une liaison, clic droit pour
couper toutes celles d'un emplacement) ; Aperçu (marquer des emplacements comme achetés,
les liaisons dont les deux bouts le sont passent au cyan).

**Nœud et slot à l'écran.** Un nœud est un carré bordé de la couleur de sa pierre ; un slot
est un **octogone**, sans pierre. Passer un nœud en slot retire sa pierre.

**Le format XML.** Plat, lisible, modifiable à la main. La position d'un emplacement n'est
jamais stockée : elle se déduit du cluster, de l'anneau et de la branche, si bien que
déplacer ou tourner un cluster déplace ses vingt-quatre emplacements sans toucher au
fichier. Un emplacement retiré est simplement absent.

```xml
<cluster id="2" x="6.5000" y="0.0000" rot="0.3000"/>
<emplacement id="3" cluster="1" anneau="1" branche="3" type="slot"/>
<emplacement id="4" cluster="1" anneau="1" branche="4" type="noeud" stat="esprit" qualite="5"/>
<liaison a="1" b="25"/>
```

**Le contrôle**, lancé à chaque enregistrement, à chaque chargement et par le bouton
Vérifier, signale : deux emplacements trop proches, une liaison pointant dans le vide, une
liaison en double, et surtout des **morceaux non reliés entre eux** — le défaut le plus
facile à laisser passer, et celui que retirer des emplacements provoque le plus souvent.

**Outillage hors serveur** : `D:\Serveur WoW\outils_spherier\` contient trois bancs d'essai
qui s'exécutent avec `lua52_interpreter.exe` sans démarrer le serveur — aller-retour XML,
clusters percés, extraction d'une grille. Ils ont servi à valider chaque changement.

### Acquis techniques du prototype

Établi et vérifié avant le jalon 1, dans `lua_scripts\Spherier\` :

- **Le code d'interface n'a pas à être distribué.** AIO l'expédie au client depuis le
  serveur : ni addon à installer chez le joueur, ni empaquetage dans `patch-z.MPQ`. Itérer
  sur l'interface ne coûte qu'un `.reload ale`.
- **Les liaisons courbes sont possibles en Lua pur.** Le client 3.3.5 n'a pas de primitive de
  ligne, mais la rotation d'une texture par `SetTexCoord` à huit arguments — la technique des
  routes aériennes de Blizzard — permet des segments d'angle quelconque. La seule exigence est
  une texture contenant un trait entouré de transparence : une texture unie remplirait tout le
  rectangle. **Abandonné pour les arcs (2026-08-23)** : les courbes par Bézier segmentée
  laissaient voir les segments, et `UI-Taxi-Line` a un cœur quasi noir (RGB 18) qui donnait un
  trait sombre au milieu de chaque segment une fois teinté. Désormais : `line.tga` maison pour
  les segments droits, et les **arcs de 45° cuits en texture** (`arc1/2/3.tga`, un par rayon
  d'anneau, épaisseur constante à l'écran) — une liaison courbe = un seul quad lisse, posé par
  rotation de coordonnées de texture. Générateur : `outils_spherier\gen_textures_spherier.py`.
- **Le client lit `Interface\AddOns\` sur le disque, sans MPQ ni redémarrage** — c'est là que
  vivent les textures de l'éditeur (`Interface\AddOns\SpherierArt\` chez le client). Pour des
  joueurs, il faudra les empaqueter (jalon 7) ; pour l'éditeur GM, le disque suffit.
- **Le découpage passe par un `ScrollFrame`** : `SetClipsChildren` n'existe pas en 3.3.5.
- **Le masque rond n'est pas réglable.** `SetPortraitToTexture` est une fonction C (absente
  du FrameXML) dont le masque est un cercle inscrit dans le rectangle de la texture ; un
  `SetTexCoord` posé ensuite le **détruit**, l'icône redevenant carrée. Rétrécir l'icône ne
  sert à rien non plus, la bordure rapetissant avec elle. La bordure blanche des icônes se
  masque donc en **recouvrant leur pourtour d'un anneau, méthode du plugin Paragon** :
  icône ronde en ARTWORK, et par-dessus, en OVERLAY, le sprite d'anneau
  `Interface\Journeys\JourneysFrame2x` (coordonnées relevées dans `UIParagon.xml`) — cadre
  à 44 px pour une icône de 34, l'anneau de qualité étant porté à 46 pour rester au-delà.
- **Coût de rendu** : un arc = 1 texture, un segment droit = 1 texture, chaque liaison reste
  teintable individuellement — l'effet « le chemin s'allume » est préservé.
- **Outillage** : `lua52_compiler.exe` et `lua52_interpreter.exe`, produits par le build de
  mod-ale et situés dans `server_hard\modules\mod-ale\src\lualib\lua\RelWithDebInfo\`,
  permettent de valider la syntaxe (`-p`) et d'exécuter les générateurs hors du serveur.
  Systématiquement employés avant tout `.reload ale`.
- **Le Lua serveur a accès à `io`** (`luaL_openlibs` est appelé) : il peut donc écrire et
  relire de vrais fichiers. En revanche il ne sait ni créer un dossier ni lister un
  répertoire, d'où le dossier `layouts\` créé une fois pour toutes et son `index.txt`.
- **Visuel des emplacements (2026-08-23).** Un slot reprend la châsse de gemme de la
  fenêtre de sertissage, composée depuis la planche `UI-ItemSockets` avec les coordonnées
  relevées dans `Blizzard_ItemSocketingUI.xml` : creux ombré + cadre argenté générique,
  teintable pour les états de l'éditeur. La châsse « Prismatic » n'existe pas en 3.3.5.
  Un nœud est un cercle : disque `gradientCircle` + anneau `Interface\Cooldown\ping4`
  teinté à la couleur de qualité — ces deux textures sont blanc sur noir sans alpha et
  exigent la fusion **ADD** (les anneaux dorés du client ne se teintent pas en bleu).
  L'icône carrée est réduite au carré inscrit du cercle pour ne jamais déborder.

## 14. Le butin : injection à la volée, tranches déclarées dans le code

**Décision du 2026-08-24.** Aucune ligne n'est ajoutée aux tables de butin de la base. Les
objets du sphèrier sont **injectés dans le butin en cours de remplissage**, et les tranches
qui disent où et à quel taux vivent dans le **code du serveur** — ni en base, ni en Lua :
rien de ce qui décide d'un butin ne doit être lisible ou modifiable ailleurs que dans le
binaire. C'est la seule entorse assumée au §3 ; son prix est connu, un rééquilibrage
demande une recompilation.

**Le point d'accroche** est `MiscScript::OnAfterLootTemplateProcess`, appelé par
`Loot::FillLoot` (`LootMgr.cpp:563`) juste après le traitement de la table et **avant**
l'attribution des droits de groupe, des seuils de qualité et du tour de rôle : un objet
ajouté là est indiscernable d'un objet venu de la table. On l'ajoute par `Loot::AddItem`,
qui gère piles, visibilité par membre du groupe et compteur d'objets non ramassés.

**Reconnaître la source.** Le crochet ne reçoit pas la créature, mais `Loot` porte
`sourceWorldObjectGUID`, posé dans `Creature::AddToWorld` / `GameObject::AddToWorld` et —
vérifié — non remis à zéro par `Loot::clear()`. On résout donc la créature ou l'objet de
jeu, et l'on dispose du niveau réel, du rang, de la carte, de la zone, de la difficulté et
de l'extension. La colonne `creature.zoneId` n'est renseignée que pour 4 981 apparitions
sur 149 695 : la zone se lit **au moment du butin** par `GetZoneId()`, jamais en base.

**Quatre magasins concernés**, filtrés par comparaison de pointeur avant toute lecture :
`LootTemplates_Creature` (monstres), `LootTemplates_Skinning` (dépeçage, sur l'objet `Loot`
de la bête donc même source), `LootTemplates_Gameobject` (filons et plantes) et
`LootTemplates_Fishing` (pêche). Les butins d'objets du sac — prospection, broyage,
désenchantement — n'ont pas de source du monde et sont ignorés.

**Deux règles, à ne pas confondre.**

1. **Premier cas qui convient l'emporte.** Chaque table est ordonnée du plus précis au plus
   général ; un boss d'Icecrown est aussi un boss de raid, c'est le premier cas qui le
   prend, et lui seul.
2. **Toutes les lignes du cas retenu sont jouées**, chacune avec son propre tirage. Un boss
   de raid rend donc un Nexus **et** une pierre : deux tirages indépendants, pas une
   alternative.

Une ligne peut porter un **repli** : si son tirage échoue, le repli est tenté à son tour.
C'est ce qui garantit qu'un boss d'Icecrown ne reparte jamais les mains vides — 25 % de
Nexus solaire, sinon un irradiant à coup sûr — sans lui donner le solaire à tous les coups.

**Le barème vit dans `outils_spherier\butin_spherier.xlsx`**, rempli par l'utilisateur le
2026-08-24 : 43 cas sur quatre feuilles (monstres, récolte, dépeçage, coffres). Le fichier
`src\SpherierLoot.cpp` en est la transcription fidèle et fait foi à l'exécution ; le
classeur reste la trace de l'arbitrage. `gen_tableau_butin.py` ne regénère que le gabarit
vide — il écrase la saisie.

Ce qui identifie un cas : l'**extension de la carte** et le couple donjon/raid/héroïque/boss
pour les monstres et les coffres ; le **niveau de la bête** pour le dépeçage ; le couple
**(compétence exigée par le verrou, extension)** pour la récolte — la compétence seule ne
suffirait pas, le cobalt de Wrath et la riche adamantite de BC exigeant tous deux 350. Deux
cas se distinguent même par l'entrée de l'objet de jeu : le gisement de saronite pure
partage le verrou du titane et ne donne rien.

Les pierres sont désignées par **qualité** ; la statistique est tirée au hasard parmi les
seize au moment du butin.

**Écueils traités.** La fenêtre est plafonnée à 18 objets (`MAX_NR_LOOT_ITEMS`) et
`AddItem` abandonne en silence au-delà : le cas est journalisé plutôt que confondu avec un
tirage malheureux. Et `GameObject::GetFishLoot` appelle `FillLoot` jusqu'à trois fois
(sous-zone, zone, défaut) : la pêche vérifie qu'aucun de nos objets n'est déjà tombé avant
de rejouer.

## 12. Reprise — ce qui vient ensuite

1. **Composer une disposition** dans l'éditeur et l'enregistrer. C'est ce qui manque pour
   décider si la géométrie du cluster et l'échelle sont les bonnes.
2. **Jalon 2** : points, coût croissant, adjacence, activation, persistance — en
   commandes GM.

**L'importeur XML → tables existe** (2026-08-23) : `outils_spherier\importe_layout.lua`,
exécuté par `lua52_interpreter.exe` depuis `bin\RelWithDebInfo` :

```
lua52_interpreter.exe D:\...\importe_layout.lua <disposition> <class_id> [depart_xml_id] [sortie.sql]
```

Il recharge `Spherier_Server.lua` avec un AIO factice (motif des bancs d'essai) — lecture,
contrôle et géométrie sont donc ceux de l'éditeur, sans duplication — refuse toute
disposition à défauts, et produit un SQL régénérable qui remplace intégralement la classe
(`outils_spherier\sql\spherier_classe_<id>.sql`), à appliquer avec
`--default-character-set=utf8mb4` puis `.spherier reload`. Conventions :
`node_id = class_id × 10000 + id XML` ; pierre pré-allouée selon l'allocation du §8.

**Le point de départ se marque dans l'éditeur** (ajout du 2026-08-23, demandé) : bouton
« Définir comme départ » dans le panneau Sélection (bascule), anneau doré discret autour
de l'emplacement marqué, mention dans l'infobulle et le bandeau de comptage, balise
`<depart id="N"/>` dans le XML. Le contrôle de l'éditeur signale un départ absent ou
pointant sur un emplacement retiré. L'importeur l'exige : marquage de l'éditeur, ou
`depart_xml_id` en 3e argument (qui prime) — sans ni l'un ni l'autre, refus.

**Première vraie grille importée (2026-08-23)** : `guerrier1`, composée en jeu puis
re-enregistrée avec son départ (emplacement 19), importée en classe 1 — 80 emplacements
(64 nœuds, 16 slots), 80 liaisons, départ 10019. Chaîne complète validée : éditeur →
XML → importeur → base → chargement du module sans aucun avertissement d'intégrité.
`outils_spherier\rend_grille.lua` produit un rendu SVG d'une disposition (numéros
visibles) pour consultation hors jeu.

Point ouvert repéré à l'usage : l'éditeur ne propose ni annulation ni duplication de
cluster. Ni l'un ni l'autre n'a été demandé, mais les deux se feront sentir sur une grande
grille.

Le jalon 0 du plan initial — essai sur la validation des rangs de talents — a été supprimé :
l'abandon des talents le rend sans objet.

## 11. Décisions restant ouvertes

Aucune. La conception est complète et le jalon 1 peut démarrer.

Deux arbitrages ont été tranchés par défaut, faute d'enjeu, et restent modifiables à tout
moment puisqu'ils ne vivent que dans des tables :

- **Qualité « magique »** : l'arbitrage initial l'affectait aux donjons en mode normal ;
  il a été **annulé le 2026-08-23** — cinq qualités seulement, la Magique est retirée et
  les donjons normaux retombent dans leurs bandes de niveau (voir §7).
- **Chevauchement au niveau 70**, présent dans l'échelle d'origine (« 61 à 70 » puis
  « 70 à 80 ») : retenu comme 61–70 puis 71–80.

Arbitrages du 2026-08-23 sur les Nexus et le coût, pris par défaut et modifiables en
base : bandes de loot **cumulatives** pour les Nexus (planchers du §7) ; prix croissant
fondé sur le **nombre d'emplacements déjà activés**, par tranches, identique pour nœuds et
slots. Le nom provisoire « sphère » est tranché le 2026-08-24 : ce sont des **Nexus**, et
la monnaie est la **Spherite**.

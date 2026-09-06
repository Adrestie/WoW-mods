# Rétroportage d'un M2 moderne vers le client 3.3.5

Établi le 2026-09-03 en portant `shamanascendant_energetic` (modèle d'Ascendance,
apparence 802120) depuis un export wow.export du client moderne vers le client
Papota 3.3.5a. Tout ce qui suit a été **mesuré**, pas supposé : soit dans
`wow.exe` (désassemblage, point d'arrêt matériel), soit sur les 22 000 modèles
d'origine du client, soit relu depuis `patch-z.MPQ` après injection.

La chaîne est implémentée dans `gen_visuel_chaman.py` ; chaque étape ci-dessous
correspond à une fonction, appelée dans cet ordre depuis `main()`.

---

## 1. Le plantage : 75 os par section, sans contrôle de borne

**C'est la limite dure du client, et elle n'est écrite nulle part.**

La palette de matrices d'os est un **tampon statique** de `wow.exe` :

| élément | valeur |
| --- | --- |
| base rendue par `0x00683560(0)` | `0x00C5EFE8` |
| décalage ajouté par l'appelant | `+0x1F0` |
| début de la palette | `0x00C5F1D8` |
| fin (premier global suivant) | `0x00C5FFE8` |
| capacité | 3 600 octets ÷ 48 = **75 matrices** |

La boucle qui la remplit (`0x00829D02`–`0x00829D93`, écriture en `0x00829D6C`,
`fstp [eax-0x18]`) recopie `M2SkinSection.boneCount` matrices de 12 flottants
**sans aucun contrôle de borne** :

```
movzx ecx, word [esi+0x0E]     ; boneComboIndex de la section
mov   ebx, [edi+0x150]         ; le modèle
mov   ebx, [ebx+0x7C]          ; bone_combos
movzx ecx, word [ebx+ecx*2]    ; bone_combos[boneComboIndex + i]
shl   ecx, 6                   ; -> matrice source (64 o)
...                            ; 12 x fld/fstp vers la palette
movzx ecx, word [esi+0x0C]     ; boneCount
cmp   edx, ecx
jb    0x829D02
```

Au-delà de 75, l'écriture déborde sur les **descripteurs de constantes de
nuanceur** qui suivent en `0x00C60240`. Le plantage ne survient pas là : il
frappe le **premier modèle animé dessiné ensuite**, d'où des rapports d'erreur
qui accusent toujours un modèle natif innocent (goule, cafard, tauren, joueur…).
Dix dumps, dix modèles différents, tous natifs.

**Correctif — `limite_os_par_section`.** L'export moderne donne à *toutes* les
sections la table d'os entière (`boneCount = 107`, `boneComboIndex = 0`), alors
qu'aucune n'en emploie autant. On donne à chacune sa propre tranche de
`bone_combos` :

1. relever, par section, les index d'os réellement employés par ses sommets ;
2. si une section dépasse la limite, replier ses os les moins portants sur leur
   **premier ancêtre déjà présent** (ceux à poids nul se replient n'importe où :
   ils ne déforment rien) ;
3. écrire la tranche en fin de `bone_combos` (tableau réécrit en fin de M2,
   en-tête repointé), renuméroter les indices, poser `boneCount` et
   `boneComboIndex`, recalculer `boneCountMax`.

Résultat sur l'ascendant : `107 → 65, 11, 75 (13 replis), 17, 4, 4, 5, 13, 24,
5, 24, 5, 2, 2, 2` ; `bone_combos` 244 → 502 entrées ; `boneCountMax` 76.

**La renumérotation ne touche que le tableau d'indices de la skin** : le client
écrase `M2Vertex.bone_indices` avec celui-là (relevé en `0x0083641B`,
`mov ecx,[skin+0x18]` puis `mov [eax+0x10], ecx`). Inutile de toucher au M2.

### `boneCountMax` (skin, offset 44)

Sort à **zéro** de wow.export. Le client dimensionne dessus ; à zéro le tampon
est vide. Sans conséquence tant que les sections restent sous ~20 os (tous les
effets de sorts livrés jusque-là), **mortel au-delà**. Convention native : max
des sections + 1. **Réparer TOUT `.skin` injecté**, et un modèle à plusieurs
`nViews` en a un par niveau de détail (le Séisme : quatre).

### Méthode de diagnostic — point d'arrêt matériel

C'est elle qui a tranché, après quatre correctifs plausibles et inutiles.

- Débogueur ctypes attaché au client, `DR0` = l'adresse écrasée,
  `DR7 = 0xD0001` (écriture, 4 octets), posé sur **tous** les fils via
  `Wow64GetThreadContext` / `Wow64SetThreadContext`.
- **Piège** : un processus 32 bits sous débogueur 64 bits renvoie
  `0x4000001E` (`STATUS_WX86_SINGLE_STEP`), **pas** `0x80000004`. Mal classé,
  l'exception repart non traitée et tue le client.
- Penser à remettre `DR6` à zéro et à `DebugSetProcessKillOnExit(False)`.
- Script : `guetteur.py` (scratchpad de la session).

Lecture d'une erreur 132 en général : le `.txt` donne l'adresse et les
registres ; désassembler `wow.exe` à `EIP` (base `0x400000`, capstone) ; le
`.dmp` est un minidump (piles seules) mais suffit à relire les arguments
empilés, et le nom du modèle en cours de rendu se trouve en clair dans l'objet
pointé par le `ebx` sauvegardé de l'appelant.

---

## 2. Gabarit 3.3.5 relevé sur les modèles d'origine

Sur 1 500 M2 et 1 200 skins tirés au sort dans `common-2`, `expansion`,
`lichking`, `patch`, `patch-2`, `patch-3` :

| grandeur | maximum natif | ascendant |
| --- | --- | --- |
| os par section | 252 | 107 → 75 |
| `boneCountMax` | 256 | 0 → 76 |
| identifiant d'attache | 49 | 74 → 49 |
| table d'os-clés | 27 | 291 → 27 |
| union des drapeaux globaux | `0x1F` | `0x212030B8` → `0x18` |
| os du modèle | 188 | 244 |
| sommets | 23 673 | 35 645 |
| séquences | 156 | 358 |

`texture_coord_combos = 65535` (plaquage d'environnement) est **normal** en
3.3.5 : 456 occurrences dans l'échantillon. Ce n'est pas un défaut.

Les trois constantes `ATTACHE_MAX_335 = 49`, `OS_CLES_335 = 27` et
`DRAPEAUX_335 = 0x1F` de `ramene_au_gabarit_335` viennent de ce relevé.

---

## 3. Séquences d'animation

### Les `.anim` modernes sont récupérables (2026-09-03)

**Un `.anim` moderne est un unique chunk `AFM2` : huit octets d'en-tête, puis
EXACTEMENT la disposition attendue par 3.3.5.** Les décalages inscrits dans le
M2 sont relatifs à cette charge utile, et le nommage d'export
(`Modele0060-00.anim`) est déjà celui que le client cherche. Retirer les huit
octets suffit — vérifié sur les 46 fichiers présents : tous les décalages
tombent dans la charge, horodatages croissants finissant sur la durée déclarée
(`anim 66-00` : 35 clés, 0 → 1 134 ms pour 1 134 annoncés). C'est
`anims_convertis`, et les séquences correspondantes ne sont plus condamnées.

Ce sont **les émotes et les poses** : danse, salut, acclamation, révérence,
rire, parole, assis au sol et sur chaise, sommeil, furtivité, pêche. Les
oublier ne casse rien mais se voit tout de suite en jeu.

`neutralise_sequences_impossibles` ne condamne donc plus que ce qui est
réellement illisible : les identifiants absents d'`AnimationData.dbc` (qui
s'arrête à 505, le modèle va jusqu'à 1786) et les externes **sans fichier
fourni**. Sur l'ascendant : 208 sur 358 condamnées, **150 conservées** dont les
46 externes rendues. Les 201 identifiants inconnus vont de 508 à 1786, aucun
sous 505 : le client n'a aucun nom pour les désigner, les restaurer ne rendrait
rien de visible.

Les 104 séquences embarquées couvrent tout le nécessaire : `Stand`, `Walk`,
`Run`, `Walkbackwards`, `Death`, `Jump`, `Fall`, la nage complète, attaques,
parades, incantations, canalisations, `Mount`, `Loot`, `Sprint`.

Trois opérations, et la troisième est celle qu'on oublie :

1. identifiant réécrit sur un **refuge** (un identifiant connu de la dbc et
   inemployé), données déclarées embarquées, ni variante ni alias ;
2. table de correspondance coupée, chaînes de variantes et d'alias défaites ;
3. **vider les sous-tableaux de piste.** Rendre l'identifiant introuvable ne
   suffit pas : chaque piste du fichier porte un sous-tableau *par séquence*, et
   ceux des condamnées pointent toujours vers leurs données — pour une externe
   sans fichier, des décalages relatifs au `.anim` (dont zéro). Déclarée
   embarquée, le client lirait ces décalages **dans le M2**, soit l'en-tête relu
   comme des clés. Il faut les mettre à `(n=0, ofs=0)` sur **toutes** les
   pistes : os (×3), couleurs (×2), transparences, transformations UV (×3),
   attaches.

---

## 3 bis. Échelle d'un effet de zone (`SpellVisualEffectName`)

Le champ `Scale` ramène le modèle au rayon du sort. Trois pièges, tous
rencontrés, tous coûteux :

1. **La boîte englobante ment dès qu'il y a des particules.** Elle enferme leur
   course maximale, pas le halo visible. Sur le lien d'esprit du chaman elle
   annonçait 12,3 m pour 6,15 m réellement vus — le double exactement. Un
   modèle *sans* particule ni ruban (0 aux offsets 0x120 et 0x128) fait
   exception : sa boîte et sa géométrie concordent.
2. **On mesure au MILIEU D'UN BORD, jamais aux sommets.** Un halo est un disque
   peint sur un carré : le cercle visible est celui *inscrit* dans le carré. Le
   coin est plus loin d'un facteur racine de deux. Sur la singularité du
   démoniste, mesurer aux coins avait donné 8,882 m au lieu de 6,574 m, soit un
   effet une fois et demie trop grand.
3. **Les arêtes du quad sont celles qui n'appartiennent qu'à UN triangle.**
   Celle que deux triangles se partagent est la diagonale, et son milieu tombe
   sur le centre. Compter les triangles par arête sépare les deux sans risque.

```python
compte = {}
for t in range(debut, debut + nb, 3):
    a, b, c = tri[t], tri[t+1], tri[t+2]
    for u, v in ((a, b), (b, c), (c, a)):
        compte[(min(u, v), max(u, v))] = compte.get((min(u, v), max(u, v)), 0) + 1
bords = [e for e, n in compte.items() if n == 1]   # les diagonales font 2
```

Un modèle peut porter plusieurs carrés superposés de tailles différentes
(la singularité : 6,574 m et 6,390 m) — c'est le plus grand qui borne ce
qu'on voit.

### L'échelle des UV décide de la taille apparente, pas la géométrie

Une `M2TextureTransform` (offset 0x60) multiplie les coordonnées de texture.
Une valeur **supérieure à 1 RÉTRÉCIT** le motif d'autant : le halo n'occupe
plus que `1 / échelle` du cercle inscrit. Sur la singularité, la couche
extérieure portait 1,039 à 1,196 — un halo à 8,4 m au lieu de 10, alors que
la géométrie était juste au millimètre. **Vérifier cette piste avant de
retoucher `Scale`**, sinon on compense une erreur par une autre.

```python
piste = offset_transfo + i * 60 + 40      # translation(20) rotation(20) échelle(20)
nvs, ovs = struct.unpack_from("<2I", m2, piste + 12)   # M2Track : valeurs en 12
```

Lire aussi la **séquence globale** de la piste (champ 2 du `M2Track`) et la
comparer à `global_loops` (0x14) : si la boucle est plus courte que la piste,
seules les premières clés sont jamais atteintes et l'animation est gelée. Sur
la singularité, une piste de 29 988 ms pilotée par une boucle de 2 976 ms
restait bloquée à 1,19 — le « battement » ne battait pas.

### Décal au sol : le relever

Un quad posé à `z = 0` se bat avec le sol (z-fighting). On relève toute la
géométrie, **et la boîte englobante avec**. La hauteur se pense en mètres de
jeu et se divise par l'échelle avant d'être écrite, car le modèle vit en unités
d'avant mise à l'échelle (`souleve_decal`, gen_visuel_demoniste.py). 0,10 m
suffit sur terrain plat.

## 3 ter. Un effet de particules : où vit réellement la couleur

Établi le 2026-09-03 en cherchant pendant six passes pourquoi les recolorations
du missile du Cataclysme ne se voyaient pas. Dans l'ordre où il faut regarder :

1. **LE NOM DU FICHIER, d'abord.** `patch-c.mpq` porte déjà, sous leurs noms
   d'origine, les textures de nombreux effets modernes — quelqu'un les y a
   importées avant nous. Deux copies homonymes dans deux archives, et le client
   lit la sienne : nos textures étaient correctes dans patch-z et *invisibles*.
   **Tout fichier d'art à nous doit porter un préfixe qui n'appartient qu'à
   nous** (`papota_`), et le modèle être réécrit pour le désigner
   (`prefixe_textures`, gen_visuel_demoniste). Se battre contre l'ordre de
   priorité des archives serait fragile.

2. **LA COULEUR NE VIENT PRESQUE JAMAIS DE LA TEXTURE.** Les émetteurs de
   particules portent chacun leur piste de couleur — `M2PartTrack` dans le
   `M2Particle` de 476 octets, temps à **+0x104**, valeurs à **+0x10C**, trois
   flottants de 0 à 255 par clé. Les textures qu'ils emploient sont le plus
   souvent des MASQUES EN NIVEAUX DE GRIS. Recolorer les textures d'un effet de
   particules ne change donc rien : c'est la piste qu'il faut reteinter
   (`recolore_emetteurs`). Un blanc n'a pas de teinte — pour le colorer il faut
   lui DONNER une saturation.

3. **LES RUBANS : textures et matériaux doivent s'accorder.** Un `M2Ribbon`
   (176 octets) porte `textureIndices` à +0x14 et `materialIndices` à +0x1C,
   deux tableaux que le client parcourt ENSEMBLE. Les modèles modernes
   déclarent trois textures pour un seul matériau : le client lit deux
   matériaux hors bornes et rend la traînée avec un fondu pris au hasard.
   `gen_visuel_aube.ecrit()` accorde désormais les deux comptes.

4. **`boneCountMax` à zéro**, systématiquement, sur tout skin exporté — voir la
   section 1. Réparé au même endroit, pour tout skin qui entre dans l'archive.

Le `blendingType` des émetteurs, lui, n'a jamais été en cause : relevé sur 80
modèles natifs, il vaut 4 dans 294 cas sur 319, et nos convertis portent 4.

### Deux outils de rattrapage

- `repare_dbc_perdus.py` — patch-z avait été semé un jour depuis une archive
  incomplète, et 409 lignes de DBC en avaient disparu, dont le `SpellVisual`
  20013 du Feu de l'âme (le sort n'avait plus ni visuel ni animation).
- `repare_skins_patchz.py` — les `boneCountMax` et les rubans déjà déployés.

Les deux sont idempotents et ne touchent à rien de correct.

## 4. Côté DBC

- `CreatureModelData` : clone d'un gabarit natif (le Poulet), on ne change que
  le chemin, l'échelle et les champs 5–13 (sang, empreintes, son) mis à zéro.
- `CreatureDisplayInfo` : **`TextureVariation[0..2]` remplit les TYPES 11, 12 et
  13 — pas les index de texture du M2.** Le manifeste wow.export donne
  index → fichier, le M2 donne index → type, et les deux ordres diffèrent (ici
  index 11 = type 13, index 12 = type 11, index 13 = type 12). Les confondre
  décale les trois textures d'un cran et donne un modèle « complètement cassé ».
- Poser les mêmes lignes dans les DBC **serveur** (`Data\dbc`) : le serveur
  valide les displayid qu'on lui demande d'appliquer.

### Geosets

`CreatureGeosetData` = un quartet par groupe, quartet de poids faible = groupe 1,
valeur = **numéro de variante** — `0` signifie « variante `x00` », pas « variante
par défaut ». Un modèle sans geoset `x00` a donc ses groupes **invisibles**.

Le renseigner (`0x11`) n'a rien donné sur un joueur transformé. La voie sûre est
`promeut_geosets` : réécrire à `0` le `skinSectionId` des sections retenues,
elles sont alors dessinées sans condition ; les variantes concurrentes gardent
leur identifiant et restent muettes.

---

## 5. Rendu : la table des combinateurs du client

Relue dans `wow.exe` en `0x008366AB` (tables de saut `0x836850`, `0x836868`,
`0x836888`). Avec le drapeau global `0x8`, `M2Batch.shader_id` indexe
`texture_combiner_combos`, **une opérande par étage** :

| opérande | 1 texture | étage 2 après Opaque ou Mod |
| --- | --- | --- |
| 0 | Opaque | Opaque |
| 1 | Mod | Mod |
| 2 | Decal | (retombe sur Mod) |
| 3 | Add | Add |
| 4 | Mod2x | Mod2x |
| 5 | Fade | (retombe sur Mod) |
| 6 | — | **Mod2xNA** |
| 7 | — | **AddNA** |

Les sources des nuanceurs sont **en clair** dans les archives :
`shaders\Pixel\arbfp1\Combiners_*.bls` (aussi `ps_2_0`, `ps_3_0`, `nvts`…). Les
lire lève toute ambiguïté. Les quatre qui comptent ici :

```
Mod_Mod       couleur = t0 x t1        alpha = a0 x a1
Mod_Opaque    couleur = t0 x t1        alpha = a0          <- même couleur, alpha du seul étage 1
Mod_Mod2xNA   couleur = t0 x t1 x 2    alpha = a0
Mod_AddNA     couleur = t0 + t1        alpha = a0
```

### Le fichier JSON de wow.export fait foi

`<modèle>_<textures><geosets>.json`, écrit à côté de l'OBJ, donne l'état exact
de la référence : `textures`, `textureTypes`, `materials`, `textureCombos`,
`textureTransformsLookup`, et surtout `skin.subMeshes` avec un champ **`enabled`**
(quelles sections étaient affichées) et `skin.textureUnits` avec le `shaderID`
**brut** du fichier moderne. Formule de décodage, vérifiée :

```
étage 1 = (shader_id >> 4) & 7        étage 2 = shader_id & 7
0x4011 -> (1, 1) = Mod_Mod
```

**Attention** : les fichiers convertis en MD20 v264 ne sont pas l'export brut.
Pour ce modèle, `art_chaman` contient 18 lots là où `wow.export` en a 15 — trois
lots surnuméraires sur les sections 2, 8 et 10 (matériau 1, une texture, la
carte du corps) que la référence ne dessine pas.

### Le défaut de rendu, et sa correction

La crinière (section 1) est le seul lot en `AlphaKey`, avec `Mod_Mod` sur deux
étages qui échantillonnent la même texture d'énergie sous des UV différents.

- `Mod_Mod` multiplie **aussi** les alphas : 0,79 × 0,32 = 0,25.
- Le visualiseur de wow.export *fond* le matériau `AlphaKey` ; le client 3.3.5
  le **teste**. À 0,25 le test échoue : toutes les lames disparaissent.
- Prendre l'alpha du seul premier étage (`Mod_Opaque`) fait passer les lames…
  mais les zones **noires** de l'atlas, qui portaient un alpha nul, redeviennent
  opaques : plaques noires en travers de la crinière.

**Correction retenue, en deux temps :**

1. `combinaison_flux` : ajouter la paire `(1, 0)` = `Mod_Opaque` en fin de
   `texture_combiner_combos` et n'y pointer que les lots de la section 1
   (`shader_id` = son index). La couleur reste `t0 × t1`, identique à la
   référence ; l'alpha devient `a0`, qui passe le test.
2. `flux_dans_la_bande` : ramener les `UV1` de cette seule section dans une
   plage de l'atlas **sans aucun noir**. Mesure par bandes de 0,09 :
   `u 0,750–0,840` est la meilleure — luminance minimale **157**, moyenne
   212/255 (modulation douce ×0,83), raccord vertical 1/255 donc le
   défilement en V reste continu. Les `UV0` des lames ne bougent pas.

Le reste du modèle garde strictement l'export : 18 lots, matériaux, combos
`[1, 4, 1, 1]`, UV, transformations.

---

## 5 bis. Variantes de couleur

Une couleur supplémentaire ne coûte **ni modèle ni skin** : le `.m2`, le
`.skin` et les `.anim` sont communs. Il faut seulement :

1. exporter, depuis wow.export, les **trois BLP remplaçables** de la variante
   et les déposer dans le dossier du modèle (`art_chaman\creature\<modèle>\`).
   **Ne jamais y recopier les `.m2`/`.skin`/`.anim` d'un export brut** : ceux du
   dossier sont convertis en MD20 v264, un export brut est un M2 moderne chunké.
   Un garde-fou en tête de `main()` refuse de déployer si le `.m2` source n'est
   pas un MD20 v264 ;
2. ajouter une ligne à `VARIANTES_ASCENDANT` : identifiant d'apparence -> les
   trois textures **dans l'ordre des types 11, 12, 13**. L'affectation se lit
   sur les DIMENSIONS, qui sont propres à chaque emplacement (ici 1024×512 pour
   le type 11, 64×64 pour le 12, 512×256 pour le 13) ;
3. ajouter le même identifiant à `ASCENDANCE_FORMES` dans `SpherierSorts.cpp` —
   le tirage au sort à chaque lancement y est déjà écrit
   (`SelectRandomContainerElement`). **Cela impose un rebuild de worldserver,
   donc un arrêt du serveur.**

Fait le 2026-09-03 pour trois couleurs : 802120, 802121, 802122.


## 6. Injection et vérification

- Archive : `patch-z.MPQ`, pilotée par StormLib en ctypes. **Jeu et Noggit
  fermés** (ils verrouillent l'archive) ; le serveur peut tourner, il ne relit
  ses DBC qu'au démarrage.
- Sauvegarde avant première écriture : `patch-z.MPQ.avant_<motif>`. Le
  basculement témoin / corrigé est un simple **renommage**, instantané et
  réversible — c'est ce qui a permis la bissection décisive.
- **Toujours relire depuis l'archive après injection**, pas depuis les fichiers
  sources : c'est la seule preuve que ce qui tourne est ce qu'on croit. Chaque
  étape de ce document a été validée ainsi.

## 7. État validé le 2026-09-03

`gen_visuel_chaman.py`, constantes en vigueur :

```python
BISSECTION_MODELE_NATIF = False
GEOSETS_ASCENDANT       = 0
GEOSETS_RETENUS         = (101, 201)      # promus en geoset 0
SECTIONS_MONO_TEXTURE   = ()
SECTIONS_FLUX           = (1,)            # combinaison_flux
SECTIONS_PASSE_FLUX     = ()              # superpose_flux : inutilisé
MATERIAU_DES_SECTIONS   = {}
BANDE_FLUX              = (0.75, 0.84)
COMBINAISON_FLUX        = (1, 0)          # Mod_Opaque
MATERIAUX_FONDUS        = {}              # matériaux d'export inchangés
LIMITE_OS_SECTION       = 75
```

Ordre du pipeline dans `main()` :

```
repare_bonecountmax  ->  rallonge_transparence  ->  neutralise_sequences_impossibles
->  degraisse_modele  ->  ramene_au_gabarit_335  ->  limite_os_par_section
->  promeut_geosets   ->  mono_texture           ->  combinaison_flux
->  fond_materiaux    ->  materiau_des_sections  ->  flux_dans_la_bande
->  superpose_flux    ->  anims_convertis
```

`anims_convertis` alimente le dictionnaire `prepares` — **après** sa création,
piège de rédaction — et les `.anim` sont ajoutés à `fichiers_a_injecter`.

Les fonctions dont la constante est vide sont neutres et laissées en place :
elles resserviront pour un autre modèle rétroporté.

## Reste ouvert

- Le **Séisme** déclare 101 os par section, au-dessus de la limite de 75, sans
  planter — il passe donc par un autre chemin de rendu. `limite_os_par_section`
  lui est applicable tel quel le jour où ça mordrait.
- Les trois lots surnuméraires de la conversion (sections 2, 8, 10) se
  superposent au corps sans exister dans la référence.
- **7 séquences externes sans fichier** : le modèle les déclare, l'export ne
  les a pas fournies. Elles restent condamnées ; les ré-exporter les rendrait.
- La section 2 porte **13 os repliés** : déformation légèrement simplifiée sur
  les extrémités. Si cela se voyait, l'alternative est de scinder la section en
  deux plutôt que de replier.

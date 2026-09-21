# Ce qui est améliorable

Écrit au fil du travail. Chaque point dit **ce qui est en place**, **pourquoi**,
et **ce qu'il faudrait faire**. Rien ici n'est un défaut caché : ce sont les
endroits où la reproduction s'écarte de la référence, où le client de 2010 ne
sait pas faire, ou où l'outillage mérite mieux.

---

## 1. Écarts assumés par rapport à la référence

### 1.1 Trois boutons du micro-menu n'ont pas d'image

La référence a retiré ces boutons, l'atlas ne fournit donc pas leur jeu
d'images dans la variante que ce client affiche (`c60`).

| Bouton 3.3.5 | Ce qui est posé | À décider |
|---|---|---|
| Succès | jeu `Achievements`, variante de base (pas de `c60`) | garder, ou prendre un autre jeu `c60` |
| JcJ | fond de la référence + l'emblème de faction de 3.3.5, 24 x 24 centré | taille et position de l'emblème choisies à l'œil |
| Aide | jeu `AdventureGuide` | la référence lui donne le jeu du menu du jeu, mais **cache** le bouton ; le laisser visible mettrait deux « ? » côte à côte |

`data/addon/ForeverUI/BottomBar.lua`, table `MICRO`.

### 1.2 Les embouts sont remontés de 20 px

La référence pose l'embout 20 px **sous** le bas de la barre
(`MainMenuBarEndCaps.xml` : `BOTTOMRIGHT (9, -22)` pour 98 de haut ; la version
récente le centre à +5 sur une barre de 45 pour 95 de haut : même résultat). La
barre étant à 2 px du bord de l'écran, ces 20 px passent sous le bord : les
pattes du griffon disparaissaient et la barre venait mordre sa tête. Le bas de
l'image est donc calé sur le bas de la barre.

Reste à vérifier : à quelle hauteur d'écran la référence place réellement sa
rangée, et si l'écart vient de là plutôt que de l'art.

### 1.3 Les griffons sont écrasés

Le cadre fait 154 x 95 (la référence), l'image `c60` fait 240 x 140 : le rapport
passe de 1,71 à 1,62, soit 5 % d'écrasement vertical. C'est ce que fait la
source, qui pose la texture sans taille propre dans un cadre de 154 x 95.

À voir : la référence utilise peut-être une autre taille de cadre quand l'art
`c60` est actif.

### 1.4 Les micro-boutons sont étirés de 41 à 46

L'ouverture du cadre fait 46 (56 de cadre moins 5 px de liseré de chaque côté),
les images de bouton font 41. Elles sont étirées pour remplir, sur demande.
Le portrait du joueur, lui, garde sa taille d'origine (18 x 26) pour ne pas
déformer le visage.

### 1.5 Le trousseau est toujours visible

La référence garde toujours ce bouton dans la barre ; 3.3.5 ne l'affiche que
lorsque le joueur a ramassé une clé (`showKeyring`). On force l'affichage pour
que la rangée garde sa longueur. L'image change, elle, selon la variable :
trousseau garni ou emplacement vide.

### 1.6 Le sac à composants n'existe pas

3.3.5 n'a pas ce sac. Sa place n'est plus tenue (elle l'a été un temps par un
emplacement décoratif) : les 47 px sont reversés au bandeau du micro-menu, qui
fait donc 322 au lieu de 275. La rangée garde sa longueur totale, et l'espace
libre est à droite des dix boutons — du côté où le micro-menu s'allonge.

### 1.7 Coche des sacs

3.3.5 pose une coche verte carrée (`CheckButtonHilight`) sur un sac ouvert. Elle
est remplacée par le cadre du sac en mélange additif, comme sur les boutons
d'action. La référence ne dit rien sur ce point précis.

### 1.8 Les sacs : ce qui s'écarte de la source

| Point | Ce qui est fait | Pourquoi |
|---|---|---|
| Grille du sac à dos | descendue de 12 px, et le cadre grandi d'autant | 3.3.5 commence sa grille 48 px sous le haut du cadre, et le champ de recherche de camelot occupe cette bande (-37 à -55) |
| Portrait du sac | icône carrée de 34 x 34, rognée à 8 % et posée dans l'anneau | 3.3.5 n'a pas de `MaskTexture` ; la source masque un portrait de 62 x 62 en rond |
| Bouton de fermeture | celui de 3.3.5, à sa place d'origine | la source emploie `UIPanelCloseButtonDefaultAnchors`, non relevé |
| Son du tri | aucun | la source joue `SOUNDKIT.UI_BAG_SORTING_01`, qui n'existe pas en 3.3.5 |
| Ce que la recherche compare | nom, type et sous-type de l'objet | le client moderne fait la comparaison lui-même (`C_Container.SetItemSearch`) et sait aussi reconnaître la qualité ou l'emplacement d'équipement |
| Ordre du rangement | catégorie selon `GetAuctionItemClasses`, puis qualité décroissante, nom, taille de pile | `C_Container.SortBags` est écrit dans le client : son ordre n'est pas lisible. **CHOIX ASSUMÉ** |
| Rythme du rangement | un déplacement toutes les 0,1 s, 400 au maximum | chaque échange doit être confirmé par le serveur avant le suivant, sinon la case est encore verrouillée |

---

## 2. Ce que 3.3.5 ne sait pas faire

| Manque | Conséquence | Contournement possible |
|---|---|---|
| Pas de `MaskTexture` | les icônes restent carrées là où la référence les arrondit ; ce sont les coins pleins du cadre qui rattrapent | découper des images pré-arrondies, ou vivre avec |
| Pas de sous-niveaux de texture | l'ordre de dessin ne tient qu'à l'ordre de création, et un `SetTexture` tardif peut le changer | ce qui doit rester devant est dans un cadre fils, niveau +1 |
| Pas de `SetShown` | partout des `if ... then Show() else Hide() end` | rien à faire |
| Pas d'animations d'atlas (flipbook) | les barres d'état n'ont ni éclat de gain, ni animation de passage de niveau | les images existent (`*-flipbook`), il faudrait un `OnUpdate` qui déroule les vignettes, comme c'est déjà fait pour le sommeil du cadre joueur |
| Pas de `SetTextureSliceMargins` | la découpe en neuf est faite à la main dans `AtlasUtil.lua`, avec des marges mesurées sur l'image | rien à faire, mais toute nouvelle image encadrée demande de remesurer |

---

## 3. Ce qui manque aux barres d'état

- **Pas de séparateurs.** La référence découpe la barre en 20 segments
  (`STATUS_BAR_NUM_SEGMENTS`) avec l'image `ui-hud-experiencebar-divider`
  (4 x 7). Non posés.
- **Pas de repère de repos.** L'ancienne `ExhaustionTick` est neutralisée, et
  la référence a son propre repère (`ui-hud-experiencebar-frame-pip`, 10 x 14,
  et sa version survolée). Non posé.
- **Texte seulement au survol.** La référence suit les variables
  `statusText` du client (toujours, jamais, pourcentage). À reprendre comme
  c'est déjà fait pour les barres du cadre joueur.
- **Pas de barre d'honneur ni de pouvoir d'artefact** : sans objet sur 3.3.5,
  mais le fichier est construit pour en accueillir.

---

## 4. Outillage

### 4.1 Les noms logiques d'atlas tombent sur la mauvaise variante

`gen_atlas_lua.py` (hors dépôt) préfère la variante `c60` quand elle existe,
mais le générateur des compléments (`ajout_feuilles.py`) prend la **première
feuille dans l'ordre alphabétique** : `uimicromenu2x` passe avant
`uimicromenuc602x`, donc `ui-hud-micromenu-questlog-up` désigne la variante de
base. `BottomBar.lua` contourne en nommant les images `...-c60-2x` en clair.

À faire : donner au générateur des compléments la même préférence, puis
retirer le contournement. Attention, cela changerait la variante affichée pour
tout ce qui a déjà été validé à l'œil.

### 4.2 Une entrée n'est pas mise à l'échelle

`ui-hud-actionbar-frame` est annoncé en 110 x 110 dans la table 03 alors que sa
feuille est en double densité : il devrait valoir 55 x 55, comme le fait la
table 06. Sans conséquence aujourd'hui (la découpe en neuf travaille en
fractions), mais c'est un piège pour le prochain usage.

### 4.3 L'archive est le calque du depot

Cinq feuilles versees autrefois ne servaient plus a rien
(`commonbuttontertiary`, `uiframediamondmetal2x`,
`uiframediamondmetalvertical2x`, `uiactionbarframe2x`, `paperdollinfopart1` :
les variantes de base de feuilles dont on affiche la version `c60`). Elles ont
ete **retirees de `patch-Z.MPQ` le 2026-09-21**, et le deployeur retire
desormais de lui-meme tout fichier de ForeverUI que le depot ne porte plus :
`--verifier` signale aussi bien ce qui manque, ce qui differe, que ce qui est
en trop.

### 4.4 Quatre images portent un numéro au lieu d'un nom

`data/art/interface/ForeverUI/unknown/*.blp` : ces fichiers n'ont pas de nom
dans le client d'origine, seulement leur identifiant. Leur aperçu existe, mais
on ne sait pas dire ce qu'elles contiennent sans les ouvrir.

### 4.5 wow.export

Le pont HTTP (port 9455) est un ajout local : `src/automation.js` plus une
ligne dans `src/index.html`. Toute mise à jour du logiciel efface les deux, il
faut les reposer.

Un défaut a été corrigé dans `src/app.js` pendant ce travail : dans l'export de
textures, `markFileName2` était déclaré **dans** le `try` et utilisé dans le
`catch`. Toute texture en échec faisait donc lever le gestionnaire d'erreur
lui-même, ce qui arrêtait le lot entier et masquait la vraie cause. La
déclaration est remontée avant le `try`. Cette correction disparaîtra aussi à
la prochaine mise à jour du logiciel.

### 4.6 Le faux client n'est pas le jeu

`tools/test_addon.py` charge l'addon dans un bouchon Lua : il attrape les
erreurs de syntaxe, les noms faux, les tailles fausses. Il ne dit rien du rendu,
de l'ordre de dessin ni du comportement des cadres protégés. L'aperçu composé
(`tools/apercu_rangee.py`) comble une partie du manque, mais rien ne remplace
l'essai en jeu.

---

## 5. Reste à reproduire

Minicarte, fenêtre de discussion, infobulles, améliorations et afflictions,
cadres de groupe et de raid, livre de sorts, talents, feuille de personnage,
écrans de sélection et de création de personnage.

Les barres d'action secondaires (`MultiBar*`) sont habillées mais ne sont ni
placées ni encadrées comme la référence le fait.

Les sacs gardent la grille de 3.3.5 (quatre colonnes, boutons de 37, pas de
42 x 41) : seul l'habillage change. La fenêtre unique qui réunit tous les sacs
(`ContainerFrameCombinedBags`) n'existe pas ici, chaque sac garde la sienne.
`ForeverUI.SetPanelArt` est écrit pour servir à tous les panneaux à venir :
feuille de personnage, livre de sorts, talents.

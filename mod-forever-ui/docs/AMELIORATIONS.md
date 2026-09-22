# Ce qui est améliorable

Écrit au fil du travail. Chaque point dit **ce qui est en place**, **pourquoi**,
et **ce qu'il faudrait faire**. Rien ici n'est un défaut caché : ce sont les
endroits où la reproduction s'écarte de la référence, où le client de 2010 ne
sait pas faire, ou où l'outillage mérite mieux.

---

## 1. Écarts assumés par rapport à la référence

**RÈGLE DE LECTURE DES SOURCES.** Seuls les dossiers `camelot/` et `shared/`
de chaque addon font foi. Un fichier qui n'existe que dans `mainline/` n'est
**pas** une source : c'est un point à trancher avec l'utilisateur, pas à adopter
en silence. L'anneau d'autolancement du familier a été écrit depuis
`mainline/AutoCastTemplates` et il a fallu le retirer — camelot y garde le
comportement de 3.3.5.


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

**Son icône est toujours posée**, elle aussi. `KeyRingMixin:OnBagUpdate`
(`camelot/mainmenubarbagbuttons.lua`) ne montre `UI-HUD-ActionBar-Keyring-Small`
que si la CVar `showKeyring` est allumée, et prend sinon l'emplacement vide
`UI-HUD-ActionBar-IconFrame-Slot-Small`. Cette condition vient d'un client où le
trousseau n'est plus qu'un reste du passé, masqué par défaut : sa CVar ne
s'allume qu'au tutoriel, la première fois qu'on ramasse une clé. En 3.3.5 le
trousseau est un élément permanent de la barre, et notre barre montre toujours
sa cellule — un emplacement vide y serait faux.

**À REVOIR PLUS TARD (noté le 2026-09-22).** Le trousseau n'est traité que pour
son apparence : l'icône, le cadre étroit de 33 et sa place dans la barre. Le
reste du `KeyRingMixin` n'est pas repris — `PutKeyInKeyRing`, `GetKeyRingSize`
et son arrondi à quatre rangées, le tutoriel qui fait pulser le bouton, le
voile de recherche d'inventaire, la rotation des textures quand la barre passe
en vertical. La fenêtre du trousseau elle-même suit le chemin des sacs, sans
traitement particulier.

### 1.6 Le sac à composants n'existe pas

3.3.5 n'a pas ce sac. Sa place n'est plus tenue (elle l'a été un temps par un
emplacement décoratif) : les 47 px sont reversés au bandeau du micro-menu, qui
fait donc 322 au lieu de 275. La rangée garde sa longueur totale, et l'espace
libre est à droite des dix boutons — du côté où le micro-menu s'allonge.

### 1.7 Coche des sacs

3.3.5 pose une coche verte carrée (`CheckButtonHilight`) sur un sac ouvert. Elle
est remplacée par le cadre du sac en mélange additif, comme sur les boutons
d'action. La référence ne dit rien sur ce point précis.

### 1.7bis Ce que la capture de référence confirme

`docs/reference/camelot_rangee_du_bas.png` est une capture du vrai client
camelot, fournie le 2026-09-21. Elle confirme point par point la rangée du
bas telle qu'elle est posée ici : raccourci en haut à DROITE de chaque
emplacement, bloc de pagination à gauche par-dessus le griffon, séparateurs
entre emplacements, pattes du griffon sur le bas de la barre, barre de
réputation AU-DESSUS de celle d'expérience, les deux longues comme la rangée.

Elle montre aussi deux choses à garder en tête :

- le micro-menu de camelot affiche onze boutons -- portrait, métiers, sorts,
  talents, legs, quêtes, guilde, groupe, collections, boutique, menu du jeu --
  et **pas** de bouton d'aide : celui-ci est bien caché, comme le XML le dit.
  Les trois boutons de 3.3.5 sans équivalent (succès, JcJ, aide) restent donc
  des ajouts, traités au 1.1 ;
- la barre des sacs de camelot compte **sept** cases : le trousseau et le sac
  à composants, tous deux au cadre sombre, puis quatre sacs et le sac à dos au
  cadre doré. L'emplacement du sac à composants a été retiré sur demande (1.6) ;
  la barre en compte six.

### 1.8 Les sacs : ce qui s'écarte de la source

| Point | Ce qui est fait | Pourquoi |
|---|---|---|
| Grille du sac à dos | descendue de 12 px, et le cadre grandi d'autant | 3.3.5 commence sa grille 48 px sous le haut du cadre, et le champ de recherche de camelot occupe cette bande (-37 à -55) |
| Portrait du sac | 28 x 28 centré sur l'anneau en (14, −17), calque `BORDER`, rogné de 0,0625 | **La méthode du client 3.3.5**, relevée sur son art : il ne masque jamais une icône. Pour ses boutons de minimap il pose un anneau par-dessus (`MiniMap-TrackingBorder` : couronne opaque, trou transparent, rien au-delà), dessine l'icône assez petite pour tenir dans le trou, et la rogne de sa bordure — une icône fait 64 px et porte 4 px sombres, d'où 4/64. Ici l'anneau est celui de camelot : trou net jusqu'à 10,3 du centre, dégradé jusqu'à 14,3, métal opaque de 14,3 à 20,4. Pour qu'un carré disparaisse, demi-côté ≥ 14,3 et diagonale ≤ 20,4 : **28 est la seule taille qui tienne**, et ses coins finissent sous le métal — mieux que les boutons de minimap, dont les coins flottent dans le trou. Le calque décide de l'ordre : le fond est en `BACKGROUND`, le métal en `OVERLAY`, `BORDER` est libre entre les deux |
| Icône du trousseau | `Interface\ContainerFrame\KeyRing-Bag-Icon` | `UpdateMiscellaneousFrames` demande `Interface/Icons/ui-hud-actionbar-keyring`, qui n'existe pas en 3.3.5 |
| Bouton de fermeture | celui de 3.3.5, à sa place d'origine | la source emploie `UIPanelCloseButtonDefaultAnchors`, non relevé |
| Son du tri | aucun | la source joue `SOUNDKIT.UI_BAG_SORTING_01`, qui n'existe pas en 3.3.5 |
| Ce que la recherche compare | nom, type et sous-type de l'objet | le client moderne fait la comparaison lui-même (`C_Container.SetItemSearch`) et sait aussi reconnaître la qualité ou l'emplacement d'équipement |
| Ordre du rangement | catégorie selon `GetAuctionItemClasses`, puis qualité décroissante, nom, taille de pile | `C_Container.SortBags` est écrit dans le client : son ordre n'est pas lisible. **CHOIX ASSUMÉ** |
| Rythme du rangement | un déplacement toutes les 0,1 s, 400 au maximum | chaque échange doit être confirmé par le serveur avant le suivant, sinon la case est encore verrouillée |
| Espace sous la grille | `GetFirstButtonOffsetY()` passe de 9 à **15**, et la bourse de 8 à **14** | avec l'art de métal de camelot posé ici, le bord intérieur du bas remonte à 7,5 du bord du cadre : il ne restait que **1,5** sous la dernière rangée, contre 7,5 à gauche et 6 à droite (mesuré en jeu, échelle 4/3 confirmée par le pas des cases — 56 px écran pour 42 logiques). Les 6 de plus égalisent l'espace des quatre côtés. La fenêtre grandit d'autant, la formule de la hauteur comptant ce nombre : 269 pour le sac à dos, 226 pour un sac porté de 16 cases |
| Champ de recherche et bouton de tri | `−37` → `−43` et `−34` → `−40` | ancrés en haut, ils suivaient le bord supérieur, qui s'est éloigné des mêmes 6 : ils redescendent d'autant pour garder leur place dans la fenêtre |

**La fenêtre suit son contenu par un CALCUL, pas par un empilement.** Recopié
de `ContainerFrameMixin` (`blizzard_uipanels_game/mainline/containerframe.lua`,
lignes 945-981) :

```
CalculateWidth()       = CONTAINER_WIDTH = 178      -- une constante
CalculateHeight()      = rangées×37 + (rangées−1)×5 + comble + extra
GetPaddingHeight()     = GetFirstButtonOffsetY() (9) + 48
                         + 30 sur le sac à dos (champ de recherche)
CalculateExtraHeight() = 0 ; + la hauteur de la bourse sur le sac à dos
```

Sac à dos, 16 cases : 163 + 87 + 13 = **263**. Sac porté, 16 cases : 163 + 57 =
**220**. Les deux correspondent à la capture de référence. La largeur ne se
déduit **pas** de la grille : c'est une constante, et la grille y laisse 8 px à
gauche pour 7 à droite (`GetInitialItemAnchor` vaut `-7`).

Le comble (titre, champ de recherche, bouton de tri) est ancré **en haut**, à
hauteur fixe — `SetSearchBoxPoint` pose `TOPLEFT (42, −37)` et `UpdateSearchBox`
pose le tri en `TOPRIGHT (−9, −34)`. Ce n'est pas ce qui empêche la fenêtre de
s'adapter : l'adaptation vient de la formule. Une tentative de tout empiler
depuis le bas a été écrite puis retirée le 2026-09-21 — elle donnait 262 au lieu
de 263 et s'écartait de la source sans rien résoudre.

Seule la grille du **sac à dos** part de la bourse
(`ContainerFrameBackpackMixin:GetInitialItemAnchor` : `BOTTOMRIGHT` de la bourse,
`TOPRIGHT`, (0, 4)) ; un sac porté part du cadre, en (−7, 9).

**Ce que 3.3.5 impose en plus.** Le client repose ses propres morceaux dans
`ContainerFrame_Update` et dans `updateContainerFrameAnchors`, tous deux appelés
bien après `ContainerFrame_GenerateFrame`. La mise en page est donc rejouée
depuis ces deux fonctions et à chaque `BAG_UPDATE`.

Cela n'a pas suffi : mesuré en jeu le 2026-09-21, le cadre portait **178 × 240**
là où la formule donne 178 × 263. La largeur passait, la hauteur non — donc un
`SetHeight` tardif, après toutes les accroches (240 = 4 rangées × 41 + 76, le
pas de 3.3.5). Un **rattrapage** a donc été ajouté : un cadre nommé
`ForeverUIBagsRecheck`, réveillé par les accroches, relit la mesure au premier
`OnUpdate` et la repose si elle a bougé, puis se rendort. Il ne se réveille
jamais lui-même : il ne peut donc pas tourner en boucle contre le client.

`/fui sacs` affiche, pour chaque sac ouvert, la hauteur calculée en regard de
celle que le cadre porte, dit **DESACCORD** le cas échéant, et ajoute alors un
témoin : la hauteur relue *dans la foulée* du `SetHeight`, le nombre de fois où
elle a été défaite, et la liste des ancrages du cadre. Deux causes se séparent
ainsi sans supposition — relecture immédiate fausse = ce sont les ancrages qui
imposent la hauteur ; relecture bonne mais valeur fausse ensuite = quelqu'un
repasse derrière nous.

**Le nom, le titre, le portrait et les icônes** viennent tous de la source :

- `UpdateName` → `SetTitle(C_Container.GetBagName(bagID))`. Le nom est donc lu
  sur le sac à chaque mise à jour (`GetBagName` en 3.3.5) : aucun mot n'est
  écrit dans le code, et un sac porté affiche le nom de l'objet qu'il est. Le
  trousseau fait exception — `GetBagName(-2)` ne rend rien — et reprend alors
  le titre que le client a posé lui-même.
- `TitledPanelMixin:SetTitleOffsets`, que `ContainerFrame` appelle avec **35** :
  le conteneur du titre va de 35 à la largeur moins 24, le texte y est centré,
  à 5 px sous son haut placé à −1. Le titre n'est donc **pas** centré sur la
  fenêtre — il l'est entre le portrait et le bouton de fermeture, dont la
  largeur entre ainsi dans le calcul (centre à 94,5 pour une fenêtre de 178).
- `UpdateMiscellaneousFrames` → sac à dos `Inv_misc_bag_08`, trousseau son
  icône propre, sac porté `GetInventoryItemTexture` de l'objet. Le portrait est
  posé dans un **cadre fils** de niveau supérieur, comme `PortraitContainer` :
  le fond du panneau est en `BACKGROUND` comme le portrait du client et, deux
  régions d'un même calque n'étant ordonnées que par leur ordre de création, le
  fond — créé après — le couvrait entièrement.
- `SetItemButtonTexture_Base` → **une seule texture par case** : l'icône de
  l'objet, ou `bags-item-slot64` quand la case est vide, sur cette même icône.
  Il n'y a jamais de fond derrière. Poser l'emplacement sur la `NormalTexture`,
  comme c'était fait, le dessine **au-dessus** de l'icône en 3.3.5 : les objets
  disparaissaient derrière leur propre emplacement. L'art doré d'époque est
  simplement effacé.

**L'empilement de plusieurs sacs** est recopié de `UpdateContainerFrameAnchors`
(lignes 1372-1401) : `CONTAINER_SPACING = 8` entre deux sacs
(`BOTTOMRIGHT` sur le `TOPRIGHT` du précédent, +8), premier sac à
`GetInitialContainerFrameOffsetX()` (10, plus la largeur des barres d'action de
droite) du bord droit et `CONTAINER_OFFSET_Y` (85) du bas, saut de colonne à
(−11, 0) sur le `BOTTOMLEFT` du premier sac de la colonne précédente. 3.3.5
emploie ses propres écarts, plus serrés : ses sacs se chevauchaient de quelques
pixels. `EditModeUtil:GetRightActionBarWidth()` n'existant pas, la largeur est
prise sur `MultiBarRight` et `MultiBarLeft` quand elles sont affichées.

**`HeldBagLayout` est recopié au pixel près** : `TopLeft (−13, 16)`,
`TopRight (4, 16)`, `BottomLeft (−13, −3)`, `BottomRight (4, −3)`, et les huit
morceaux en **`OVERLAY`**. Les valeurs approchées d'avant (`(2, 16)`,
`(−13/2, −8)`, en `BORDER`) sont abandonnées.

Le calque a une conséquence : en `OVERLAY`, le métal couvre **toute région du
cadre lui-même**. La source s'en accommode parce qu'elle range ce qui doit
rester visible dans des **cadres fils** — `TitleContainer` à `frameLevel` 510,
`PortraitContainer` — et un cadre fils se dessine au-dessus des régions de son
parent quel que soit leur calque. Le titre est donc reproduit tel quel : un
cadre de 20 de haut, de 35 à la largeur moins 24, posé à −1, contenant un
`FontString` ancré `TOP (0, −5)`, `LEFT` et `RIGHT`. Le titre du client, simple
région, s'efface. Le portrait, lui, reste **sous** le métal, qui lui sert de
masque (voir plus haut) ; les boutons d'objet, la bourse, le champ de recherche
et le bouton de fermeture sont déjà des cadres fils et passent devant sans rien
changer.

**`NineSliceUtil.UpdateCornerCropping` est reproduit**, avec la formule de
`ClipNineSliceBottomCorner` :

```
débord = hauteurCoinHaut + hauteurCoinBas − hauteurCadre − décalageHaut − (−décalageBas)
```

Au-delà de zéro, le coin du **bas** est rogné par le haut de cet excédent : ses
coordonnées de texture remontent d'autant et sa hauteur diminue. Sans cela, sur
une fenêtre plus courte que ses deux coins empilés — le trousseau, une seule
rangée, 94 de haut contre 100 + 95 de coins — les deux coins se chevauchent et
le bord gauche, tendu entre eux, se retrouve dessiné en travers du cadre. C'est
la barre dorée qui coupait l'anneau du trousseau. Recalculé à chaque
changement de hauteur, comme `UpdateFrameSize` le fait.

### 1.8bis La barre bonus

Celle qui **remplace** la barre de sorts quand le joueur change de posture
(`BonusActionBarFrame`, `BonusActionButton1..12`). 3.3.5 la montre à une
position à elle, d'où un décalage visible.

Ses douze boutons sont donc posés sur **le même porteur** que la barre de
sorts, aux mêmes places : la barre de remplacement suit alors la position du
porteur, **y compris celle que le joueur a choisie** par `/fui`. Rien n'est
reparenté — un bouton reste enfant de la barre du client, donc il suit sa
visibilité (posture, véhicule, possession) ; seul son ancrage change.

**La glissière.** 3.3.5 fait *glisser* cette barre pour la faire paraître, et
ce mouvement est conservé. Mais on ne peut pas déplacer un bouton sécurisé image
par image : le client l'interdit en combat, et c'est précisément là qu'on change
de posture. Les boutons bonus sont donc ancrés **une fois** à une glissière —
`ForeverUIBonusSlide`, un cadre à nous posé sur le porteur — et c'est **elle**
qui glisse. Les boutons suivent sans qu'on y touche, et déplacer son propre
cadre reste permis en combat. La course vaut une hauteur de bouton, la durée
`BONUS_ACTIONBUTTON_SLIDE_TIME` quand le client la déclare, 0,2 s sinon.

Le mouvement va **dans les deux sens**. Au retrait, c'est le client qui le rend
possible : comme pour ses autres barres glissantes, il pose `mode = "hide"`,
**continue d'afficher la barre** le temps du mouvement, et ne la masque qu'à la
fin. On lit donc son `mode` et pas seulement sa visibilité. Si un client ne
portait pas ce champ, le retrait resterait instantané — rien ne peut animer des
boutons déjà masqués.

Son art d'époque (deux morceaux glissants) est effacé par le même balayage de
régions que celui de la barre du familier.

---

### 1.9 La barre des postures

Relevée de `mainline/StanceBar.xml`, `shared/StanceBar.lua`,
`SmallActionButtonTemplate` et `SmallActionButtonMixin` :

| Pièce | Valeur | Source |
|---|---|---|
| Bouton | 30 × 30 | `SmallActionButtonTemplate` |
| Écart | 2, soit un pas de 32 | `minButtonPadding` |
| Disposition | une rangée, 10 boutons au plus, vers la droite | `isHorizontal`, `numRows 1`, `numButtons 10`, `addButtonsToRight` |
| Cadre normal / enfoncé | `-IconFrame` et `-IconFrame-Down`, **35 × 35**, en `OVERLAY`, `TOPLEFT` | `SmallActionButtonMixin:UpdateButtonArt` |
| Survol, coché, bordure, éclat | **31,6 × 30,9**, `TOPLEFT` | `SmallActionButtonMixin_OnLoad` |
| Coché | le survol en mélange `ADD` | `ActionButtonTemplate.xml` |
| Emplacement vide | `-IconFrame-Background` + `-IconFrame-Slot` | `BaseActionButtonMixin:UpdateButtonArt` |
| Raccourci | `TOPRIGHT (−3, −4)` | `hotkeyX` / `hotkeyY` |
| Quantité | `BOTTOMRIGHT (−3, 1)` | `SmallActionButtonMixin_OnLoad` |
| Recharge | `TOPLEFT (1,7 ; −1,7)` / `BOTTOMRIGHT (−1 ; 1)` sur l'icône | idem |
| Forme active | le bouton est **coché** | `StanceBarMixin:UpdateState` |
| Forme non lançable | icône teintée à **0,4** | idem |
| Barre masquée | tant que `GetNumShapeshiftForms()` vaut 0 | `StanceBarMixin:Update` / `ShouldShow` |

**Le piège, et il est sérieux :** `GetShapeshiftFormInfo` ne rend pas la même
chose dans les deux clients. Le moderne donne
`(texture, isActive, isCastable, spellID)`, **3.3.5 donne
`(texture, nom, isActive, isCastable)`**. Recopier la source au mot près
prendrait le nom de la forme pour son état actif : toutes les formes
paraîtraient actives, et aucune lançable. Le harnais vérifie explicitement
qu'une forme active est cochée et qu'une forme non lançable est grisée, pour
que l'inversion ne puisse pas revenir.

**L'ancrage des quatre états est centré, pas `TOPLEFT`.** La source les ancre
en `TOPLEFT`. Sur le grand bouton cela tombe juste — un cadre de 46 × 45 sur un
bouton de 45 × 45 est centré à un demi-pixel près. Sur le petit, le même
ancrage met un cadre de 35 sur un bouton de 30 : il déborde de 5 à droite et en
bas, son trou se décale de 2,5 et mord l'icône d'un côté. Le trou du cadre,
mesuré sur l'art (élément de 47 × 46, bordure opaque de 5 px à gauche, 4 à
droite, 6 en haut, 5 en bas), vaut 35,2 × 34,2 à la taille d'atlas, soit **26,6
une fois le cadre ramené à 35**. Centré, il tombe dans l'icône de 30 avec 1,7 de
marge partout ; décalé, il en sort — et l'icône paraît plus petite qu'elle n'est.

**Écarts assumés.** Le mode édition n'existe pas : la position se règle par
`/fui`, et la barre s'aligne par défaut sur le bord gauche de la barre
d'action, au-dessus des barres d'expérience et de réputation. Les boutons du
client sont sécurisés : ils sont rhabillés, jamais recréés, et rien n'est
redimensionné ni déplacé en combat.

---

### 1.10 La barre du familier

Relevée de `mainline/PetActionBar.xml`, `shared/PetActionBar.lua`,
`SmallActionButtonMixin` et `AutoCastTemplates`. Le bouton est le même petit
bouton que les postures — 30 × 30, écart 2, cadre 35 × 35, états à
31,6 × 30,9, raccourci et quantité aux mêmes places, quatre états centrés pour
la raison donnée en 1.9.

Ce qui lui est propre :

| Pièce | Valeur | Source |
|---|---|---|
| Autolancement | **celui du client**, mis à l'échelle du bouton | voir ci-dessous |
| Action active | bouton coché | `UpdateButtonState` |
| Action d'attaque | clignote, et son coché tombe à **0,5** d'alpha | idem — « à pleine alpha on croirait une capacité de plus sélectionnée » |
| Action inutilisable | icône teintée à 0,4 | `GetPetActionSlotUsable` |
| Sans texture | icône masquée | `UpdateButtonState` |
| Barre visible | si `PetHasActionBar()` **et** `UnitIsVisible("pet")` | `PetActionBarMixin:OnEvent` |

**Le piège des signatures, deuxième fois.** `GetPetActionInfo` rend
`(nom, texture, isToken, active, autoPossible, autoActif, sortID)` chez le
client moderne et **`(nom, sous-texte, texture, isToken, active, autoPossible,
autoActif)`** en 3.3.5 : un champ de plus au deuxième rang. Recopier la source
au mot près prendrait le sous-texte (« Rang 5 ») pour la texture. Le faux client
suit la signature de 3.3.5 et le harnais le vérifie sur une action qui a un
sous-texte.

`isToken` se comporte pareil dans les deux clients : le nom et la texture sont
alors des **clés de variables globales**, pas des valeurs, et il faut les
résoudre — `_G[texture]`.

**La place par défaut** : juste au-dessus de la barre de réputation (y = 84),
sur le même bord gauche que la barre d'action. Si la barre des postures est
affichée, la barre du familier passe **à sa droite**, séparée d'elle par la
largeur de **deux de ses icônes** (60). La place se recalcule à chaque mise à
jour — les formes vont et viennent, donc la largeur de la barre des postures
aussi — et `Layout.SetDefaults` ne repose le cadre que si l'utilisateur ne l'a
pas déjà déplacé lui-même.

**L'art d'époque de la barre est effacé** : 3.3.5 encadre sa barre de familier
de deux morceaux glissants, `SlidingActionBarTexture0` et `1`. Plutôt que de se
fier à leurs noms, **toutes les régions du cadre lui-même** passent à alpha 0 —
les boutons sont des cadres fils, pas des régions, ils ne sont donc pas touchés.
Le balayage est rejoué à chaque habillage, donc une texture que le client
ajouterait ensuite disparaît aussi.

**L'autolancement garde le comportement d'origine.** `AutoCastTemplates`
n'existe que dans `mainline/`, et **seuls `camelot/` et `shared/` font foi** :
camelot ne remplace donc pas ici l'anneau du client. La bordure scintillante
(`$parentAutoCastable`) et les quatre étincelles tournantes (`$parentShine`)
restent celles de 3.3.5, allumées et éteintes par `PetActionBar_Update` ; elles
sont seulement mises à l'échelle du bouton, qui passe de 36 à 30 : la bordure
de 58 devient 48,3, et le cadre des étincelles reçoit `SetScale(30/36)`.

**L'échelle, pas la taille.** Redimensionner le cadre des étincelles ne suffit
pas : le client les pose lui-même à une taille fixe et `AutoCastShine_OnUpdate`
les déplace sans les retailler. On obtenait des étincelles trop grosses tournant
sur un cercle trop petit. `SetScale` sur le cadre fait suivre tout ce qu'il
contient — tailles et orbite.

Un anneau repris de `mainline` (coins + fourmis tournantes) avait été écrit
puis **retiré** : c'était une lecture d'une saveur qui ne s'applique pas.

**Non reproduit.** La marque de surbrillance (`SpellHighlightTexture`, atlas
`bags-newitem`) n'a pas d'équivalent : `HasPetActionHighlightMark` n'existe pas
en 3.3.5.

---

### 1.11 La feuille du personnage — jalon 1

Le chantier est découpé. **Ce jalon** pose le cadre, ses deux volets et les
emplacements d'équipement ; le volet droit (statistiques, onglets latéraux) et
les autres onglets — réputation, compétences, PvP, devises — viendront ensuite.

Relevé de `camelot/CharacterFrameConstants.lua`, `camelot/CharacterFrame.xml` et
`camelot/PaperDollFrame.xml` — le dossier `camelot/` existe pour les trois, il
n'y a donc rien à trancher ici.

| Pièce | Valeur |
|---|---|
| Fenêtre | 631 × 484 (`CHARACTER_FRAME_WIDTH/HEIGHT`), repliée 398 |
| Panneau | `PortraitFrameBaseTemplate` — la même famille que les sacs |
| Volet gauche | 398 de large, `TOPLEFT (0, −20)` au `BOTTOMLEFT` du cadre, fond `UI-Character-Info-General-BG` (398 × 464) |
| Volet droit | 233, accroché au `TOPRIGHT` du gauche, fonds `-Stat-BG` (233 × 383) et `-Stat-StoneBG` (233 × 85), séparateur `common-framedivider` de 11 posé à −6 |
| Emplacement | 40 × 40, cadre `UI-Character-Info-GearSlot` à sa taille (55), centré |
| Colonne gauche | `TOPLEFT (24, −60)` du volet gauche, écart 6 : tête, cou, épaules, dos, torse, chemise, tabard, poignets |
| Colonne droite | `TOPRIGHT (−20, −60)`, même écart : mains, taille, jambes, pieds, 2 anneaux, 2 bijoux |
| Armes | arme principale au `BOTTOM (−60, 30)` du volet gauche, puis secondaire et distance à +6 ; distance et munitions en 27 × 27 avec `-GearSlotSmall` |
| Munitions | `LEFT (+19)` de l'emplacement de distance |
| Modèle | occupe tout le volet gauche, comme la `ModelScene` de la source |
| Titre | bande de 58 à −24, texte centré à 5 px de son haut posé à −1 — `CharacterFrame` **n'appelle pas** `SetTitleOffsets`, il garde les valeurs par défaut du mixin ; son milieu tombe à 332,5 sur 631, ce que la capture confirme |
| Titre affiché | **toujours** le nom du personnage et son titre (`UnitPVPName`), en clair — écart assumé : `characterFrameDisplayInfo` fait suivre le titre au sous-cadre affiché (REPUTATION, PVP, SKILLS…), demandé autrement |
| Fermeture | 24 × 24 au `TOPRIGHT (1, 0)`, le X rouge des panneaux modernes |
| Niveau, race et classe | dans le **volet droit**, `TOP (0, −54)`, 220 de large — `PaperDollLevelInfo` est à `TOP (0, −50)` des onglets latéraux, eux-mêmes à `TOP (0, −4)` du volet |
| Flèches du modèle | centrées horizontalement dans le volet gauche (réglage : `ROTATION_Y`) |
| Déplacement | la **barre du haut** sert de poignée ; la place choisie est retenue dans `ForeverUIDB` et **reposée après le client**, dont le système de panneaux replace la fenêtre à chaque ouverture |
| Onglets latéraux | `ModeTabs` 64 × 384 au `TOPRIGHT` du cadre, y −30 ; onglets 55 × 55 (`common-sidetab` fait 55 × 60 dont 5 de transparent), icône centrée à −3 |

**L'ordre de dessin, corrigé après le premier essai en jeu.** Les volets sont
des cadres fils : ils recouvrent **toute région de leur parent**. L'art du
panneau posé sur le cadre lui-même se retrouvait donc sous eux — le contour ne
collait plus aux fonds, le fond du volet droit débordait sur le bord droit et
celui du volet gauche mangeait l'anneau du portrait. La source fait la même
chose que ce qu'il fallait faire : son `NineSlice` est un **cadre fils**, et son
`PortraitContainer` en est un autre, à `frameLevel` 400. `SetPanelArt` accepte
donc une option `niveau` qui loge **le métal** dans un cadre fils au-dessus.

**Le fond, lui, reste sur le cadre.** Monté avec le métal, il recouvrait les
volets à son tour — c'est une surface opaque, elle doit passer *derrière* tout
le reste. Une région du cadre se dessine sous tous ses cadres fils : c'est
exactement la place qu'il lui faut. Le métal monte, le fond descend.

Trois autres corrections du même essai :

- **le coin haut gauche n'est pas celui des sacs.** `PortraitFrameBaseTemplate`
  déclare `layoutType = "PortraitFrameTemplate"`, qui ne diffère de
  `HeldBagLayout` que par lui : `UI-Frame-PortraitMetal-CornerTopLeft`, un
  anneau plus large. `SetPanelArt` prend une option `coinHautGauche`.
- **le portrait était vide** parce que le balayage de l'art d'époque efface
  aussi celui du client — c'est une région du cadre. On en pose un à nous,
  44 × 44 centré sur le trou mesuré de l'anneau (25 ; −22,5), rempli par
  `SetPortraitTexture(…, "player")`. Le 44 vient du même calcul que sur les
  sacs : l'anneau est transparent jusqu'à 13 du centre, en dégradé jusqu'à 23,
  opaque de 24 à 31 ; aucune taille ne couvre le dégradé (46) tout en cachant
  ses coins (43,8), donc 44, dont les coins tombent à 31,1.
- **le fond du volet droit ne remplissait pas son volet** : la source le déclare
  **sans ancrage**, ce qui veut dire qu'il remplit. Posé à sa taille d'atlas
  (233 × 383) il laissait 81 px nus, le volet en faisant 464.
- **le séparateur s'étalait** : `common-framedivider` porte un embout à chaque
  extrémité, et l'étirer sur 464 px les répand. Il est découpé en trois
  tranches par ses coordonnées de texture (`ForeverUI.CreateVerticalDivider`).
- **l'art d'époque ne tient pas qu'au cadre** : la feuille de 3.3.5 le répartit
  sur ses sous-cadres, qui échappent à un balayage du seul `CharacterFrame`. La
  liste est balayée à chaque passage.

**Ce client n'a pas le `PaperDollFrame` d'origine.** Son
`Data/enus/patch-enus-9.mpq` livre un **FrameXML modifié** :
`Interface\FrameXML\PaperDollFrame.lua` et `.xml`, `CharacterFrame.lua` et
`.xml`, plus leurs textures. C'est donc ce code-là qui tourne, et non celui de
Blizzard. Sa présentation des statistiques est reprise telle quelle et reposée
dans le volet droit :

| Pièce | Valeur |
|---|---|
| Ligne de statistique | `PStatFrameTemplate`, 155 × 16 — intitulé à gauche, valeur à droite |
| Groupes | `PlayerStatFrameLeft1..6` et `PlayerStatFrameRight1..6`, deux groupes de six **empilés** (le client les pose à −24 et −155, même x) |
| Pas | 16, les lignes s'enchaînent sans écart |
| Sélecteur de catégorie | `MostrarStatPaperDollLeftDropDown` et `…RightDropDown`, un par groupe |
| Chez nous | dans le volet droit sous la bande de pierre, élargies à 193 (233 moins 20 de marge de chaque côté), niveau de cadre au-dessus du fond du volet |

Ce sont des cadres du client : ils sont déplacés et élargis, jamais recréés —
ce sont eux qui portent les infobulles et les menus de catégorie.

**Un sélecteur de catégorie sans art est invisible.** `MostrarStatPaperDoll*
DropDown` est un `CheckButton` de 153 × 21 qui ne porte **qu'un surlignage**
(`ButtonHilight-Square`) : aucune texture normale, aucun intitulé. L'art qui le
coiffait — `PlayerStatLeftToper`, sur `UI-Character-StatBackground` — est
déclaré `hidden="true"` dans ce FrameXML. Il est donc habillé à la manière de
`CharacterStatFrameCategoryTemplate` de camelot :

| Pièce | Camelot | Chez nous |
|---|---|---|
| Cadre | 197 × 40 | 203 × 40 — la hauteur de la source, la largeur des lignes (193) plus le débord |
| Débord sur les lignes | 5 de chaque côté (197 contre 187) | 5, d'où un `x` de 15 quand les lignes sont à 20 |
| Fond | `UI-Character-Info-Title` tendu du `TOPLEFT` au `BOTTOMRIGHT` | idem (`ui-character-info-title`, feuille 10) |
| Intitulé | `GameFontHighlight` centré à (0, 1) | idem |

L'intitulé n'est pas dans le bouton : la catégorie choisie vit dans une CVar
(`playerStatLeftDropdown`, `playerStatRightDropdown`) qui porte une **clé**
(`PLAYERSTAT_BASE_STATS`) ; le texte affichable est la globale du même nom. Le
client rappelle `UpdatePaperdollStats(préfixe, clé)` à chaque changement : un
`hooksecurefunc` dessus suffit à faire suivre l'intitulé. Le clic, lui, reste
celui du client (`ToggleDropDownMenu` sur `PlayerStatFrameLeftDropDowner` et
`PlayerStatFrameRightDropDown`, tous deux initialisés à leur `OnLoad`), et le
menu s'ancre au bouton : il suit donc le sélecteur où qu'on le pose.

À noter, le client ne masque ces boutons que pendant l'ouverture du
`PaperDollFrameItemFlyout` ; partout ailleurs il les montre. Leur absence à
l'écran tenait bien à l'art, pas à la visibilité.

**Le banc n'enveloppait pas ses greffons.** Son `hooksecurefunc` se contentait
d'enregistrer la fonction dans `HOOKS` : appeler la fonction greffée ne
déclenchait rien, et un greffon cassé serait passé inaperçu. Il enveloppe
désormais vraiment — l'originale, puis le greffon, et les valeurs rendues sont
celles de l'originale.

**Une région ne se reparente pas en 3.3.5.** `SetParent` n'existe pas dans la
table des méthodes de `FontString` de ce client, et ancrer la ligne du client au
volet ne suffirait pas : elle appartient au cadre, donc elle se dessinerait
*sous* les volets, qui sont des cadres fils. On efface la sienne et on pose la
nôtre dans le volet, en recopiant son texte — c'est le client qui le compose.

**Écarts assumés.** `PaperDollItemSlotButton_OnLoad` pose l'arme principale à
`(−60, 30)` quand l'emplacement de distance est montré et à `(−40, 30)` sinon,
en masquant alors la distance : 3.3.5 montre toujours cet emplacement — arc,
arme de jet ou relique selon la classe — donc la variante à −60 est la seule
employée. Les onglets du bas de 3.3.5 restent en place pour l'instant ; camelot
les met sur le côté (`CharacterFrameModeTabs`, 64 × 384), ce sera le jalon du
volet droit. Rien n'est recréé : les emplacements sont des boutons du client,
ils portent le glisser-déposer de l'équipement.

---

---

## 2. Ce que 3.3.5 ne sait pas faire

| Manque | Conséquence | Contournement possible |
|---|---|---|
| Aucun masque sur une texture | les icônes restent carrées là où la référence les arrondit ; ce sont les pleins du cadre qui découpent le rond | découper des images pré-arrondies, ou vivre avec |
| Pas de sous-niveaux de texture | l'ordre de dessin ne tient qu'à l'ordre de création, et un `SetTexture` tardif peut le changer | ce qui doit rester devant est dans un cadre fils, niveau +1 |
| Pas de `SetShown` | partout des `if ... then Show() else Hide() end` | rien à faire |
| Un bouton d'action vide est **caché**, pas seulement son fond | `ActionButton_HideGrid` masque le bouton entier dès que son compteur `showgrid` retombe à zéro, et ce compteur ne monte que le temps d'un glisser-déposer (`ACTIONBAR_SHOWGRID` / `_HIDEGRID`). L'art d'emplacement vide de camelot disparaissait avec lui | maintenir `showgrid` à 1 : le client garde alors ses boutons vides affichés de lui-même. Un `Show` de secours si le bouton était déjà masqué, **jamais en combat** — afficher un cadre sécurisé y est interdit ; ce qui est masqué pendant un combat revient à la sortie, `PLAYER_REGEN_ENABLED` étant surveillé |
| Pas d'animations d'atlas (flipbook) | les barres d'état n'ont ni éclat de gain, ni animation de passage de niveau | les images existent (`*-flipbook`), il faudrait un `OnUpdate` qui déroule les vignettes, comme c'est déjà fait pour le sommeil du cadre joueur |
| `SetNormalTexture` et ses sœurs n'acceptent qu'un **chemin** | leur passer un objet texture, comme le fait le client moderne, lève une erreur -- et une erreur au premier niveau d'un fichier abandonne **tout ce qui suit**. C'est ce qui a rendu `Bags.lua` inopérant sans rien afficher : l'habillage était appelé après le bouton de tri | poser le chemin de la feuille, puis régler l'atlas sur la texture que le bouton vient de créer ; le faux client lève maintenant la même erreur |
| `SetRotation` efface le rectangle d'atlas | il recalcule les coordonnées de texture sur l'image **entière** : la texture montre alors toute la feuille, et non l'élément voulu | tourner par la forme à huit arguments de `SetTexCoord` — `SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)`, que le message d'usage du client donne lui-même. Ses coins balaient le carré circonscrit (1,41 fois le côté) : l'élément doit alors être seul et centré dans sa feuille. **Aucun élément ne tourne aujourd'hui** ; la note reste pour le jour où l'un le fera |
| Pas de `SetTextureSliceMargins` | la découpe en neuf est faite à la main dans `AtlasUtil.lua`, avec des marges mesurées sur l'image | rien à faire, mais toute nouvelle image encadrée demande de remesurer |

**Le client d'origine fait exactement cela pour ses propres sacs.** Vérifié
le 2026-09-22 en décodant `Interface\ContainerFrame\UI-Bag-4x4.blp`
(rangé dans `Data/enus/locale-enus.mpq`, et non dans les archives communes)
avec `tools/foreverui/blp.py` : le cadre du sac de 3.3.5 porte un **trou
circulaire** d'environ 32 px dans son coin haut gauche, et l'icône carrée est
simplement posée derrière. Les icônes rondes des sacs d'origine ne sont donc
pas masquées — c'est l'art qui découpe. Même mécanisme ici, avec l'anneau de
camelot.

L'anneau de camelot, mesuré au pixel sur `uiframemetal2xc60` à la taille où il
est dessiné (95 x 95) : métal opaque, puis un **dégradé** de chaque côté, puis
le trou. Trou net ≈ 20 px, ≈ 28 px en comptant le dégradé, qui laisse aussi
passer l'icône — ce qui correspond au rond visible sur
`docs/reference/camelot_sac_principal.png`. Une première mesure n'avait retenu
que le cœur totalement transparent et annonçait 18 : c'était faux.

**Le seul masque de ce client est celui de la minimap.** Vérifié dans
`Wow.exe` le 2026-09-22 : la table des méthodes de `Texture` s'arrête à
`SetAlphaGradient, Set/GetVertTile, Set/GetHorizTile, Set/GetNonBlocking,
IsDesaturated, SetDesaturated, SetRotation, Set/GetTexCoord, Set/GetTexture,
Show, Hide, Set/GetAlpha, SetGradientAlpha, SetGradient, Set/GetVertexColor,
Set/GetBlendMode, Set/GetDrawLayer, GetObjectType, IsObjectType`. `SetMask`,
`AddMaskTexture` et `CreateMaskTexture` sont **absents du binaire**, et il n'y
a pas d'élément XML `MaskTexture`. Le seul `SetMaskTexture` présent est
`Minimap:SetMaskTexture("file")` — une méthode du widget **Minimap**, voisine
de `SetBlipTexture` et `SetIconTexture`, avec `Textures\MinimapMask` par
défaut. Elle arrondit la minimap, et rien d'autre : une icône d'objet ne peut
pas y passer. C'est utilisable le jour où la minimap sera reproduite, pas
avant.


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

### 4.6 Le faux client n'est pas le jeu, et l'aperçu composé ne l'était pas non plus

`tools/test_addon.py` charge l'addon dans un bouchon Lua : il attrape les
erreurs de syntaxe, les noms faux, les tailles fausses. Il ne dit rien du
rendu, de l'ordre de dessin ni du comportement des cadres protégés.

Des scripts composaient l'art en Python pour «voir» le résultat avant de le
poser en jeu. **Ils ont été retirés le 2026-09-21** : une telle image ne
prouve que l'arithmétique. Elle ignore l'ordre de dessin réel, ce que le
client pose par-dessus, l'échelle finale et les calques -- elle a montré
comme justes des fenêtres que le jeu montrait fausses. **Ce à quoi une chose
ressemble se juge en jeu, et nulle part ailleurs** ; `docs/reference/` garde
les captures du vrai client pour la comparaison.

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

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

**Une archive `.disabled` ne tourne pas — vérifier QUI répond.** Le
`Data/enus/patch-enus-9.mpq` de ce client porte l'extension **`.disabled`** :
le jeu ne l'ouvre pas. Le FrameXML modifié qu'il contient
(`MostrarStatPaperDoll*DropDown`, `PStatFrameTemplate`) n'existe donc nulle
part à l'écran, et un bloc bâti dessus vise des cadres absents. Une archive
se lit toujours par la **chaîne** (`foreverui.mpq.open_client(...).where(chemin)`),
qui répond comme le client : la dernière archive qui porte le fichier gagne,
et les `.disabled` n'y sont pas.

Réponse de la chaîne pour cette feuille :

| Fichier | Archive qui répond |
|---|---|
| `Interface\FrameXML\PaperDollFrame.xml` | `patch-enus-2.mpq` |
| `Interface\FrameXML\PaperDollFrame.lua` | `patch-enus-3.mpq` |
| `Interface\FrameXML\CharacterFrame.xml` | `patch-enus-2.mpq` |
| `Interface\FrameXML\CharacterFrame.lua` | `patch-enus.mpq` |

**Rien ne tient à une archive ajoutée.** La présentation des statistiques est
celle du FrameXML d'origine, reposée par l'addon :

| Pièce | Ce que le client charge | Chez nous |
|---|---|---|
| Ligne | `StatFrameTemplate`, **104 × 13** — intitulé à gauche, valeur dans un cadre fils calé à droite | élargie à 193 (233 moins 20 de marge de chaque côté) |
| Pas | **13**, les lignes s'enchaînent sans écart | 13 |
| Groupes | `PlayerStatFrameLeft1..6` et `…Right1..6`, **côte à côte** dans `CharacterAttributesFrame` (230 × 78) | l'un **sous** l'autre, une seule colonne comme camelot, 16 entre les deux |
| Sélecteur | `PlayerStatFrameLeftDropDown` et `…RightDropDown`, `UIDropDownMenuTemplate` | en-tête moderne, voir plus bas |

Ce sont des cadres du client : ils sont déplacés et élargis, jamais recréés —
ce sont eux qui portent le calcul des valeurs, les infobulles et le menu des
catégories.

**L'art d'un menu déroulant déborde de son cadre.** `UIDropDownMenuTemplate`
mesure 40 × 32, mais son art en fait 165 × 64 : `$parentLeft` 25,
`$parentMiddle` 115 (que `UIDropDownMenu_SetWidth` retaille), `$parentRight`
25, tous ancrés les uns aux autres et non au cadre. Le redimensionner ne
déplace donc rien. Les trois pièces et `$parentText` sont masqués, et
l'en-tête de `CharacterStatFrameCategoryTemplate` (camelot) prend leur place :

| Pièce | Camelot | Chez nous |
|---|---|---|
| Cadre | 197 × 40 | 203 × 40 — la hauteur de la source, la largeur des lignes (193) plus le débord |
| Débord sur les lignes | 5 de chaque côté (197 contre 187) | 5, d'où un `x` de 15 quand les lignes sont à 20 |
| Fond | `UI-Character-Info-Title` tendu du `TOPLEFT` au `BOTTOMRIGHT` | idem (`ui-character-info-title`, feuille 10) |
| Intitulé | `GameFontHighlight` centré à (0, 1) | idem |

**Une fonction locale appelée avant d'être écrite se résout en globale.**
`habillerSelecteur` greffe `majEtatSelecteurs` sur la liste, et celle-ci
n'est écrite que plus bas : à cet endroit son nom n'est pas encore une
variable de portée, Lua le cherche donc dans les globales et trouve `nil` —
`HookScript` répond alors *Usage: DropDownList1:HookScript("type",
function)*. Une **déclaration anticipée** (`local majEtatSelecteurs` avant,
`function majEtatSelecteurs()` ensuite) suffit : la fermeture voit la
variable se remplir.

Le banc ne l'a pas vu parce que son `HookScript` acceptait `nil`. Il refuse
désormais tout greffon qui n'est pas une fonction, comme le vrai.


**La liste tombe sous le bouton, sans décalage.** Sans ancrage donné,
`ToggleDropDownMenu` accroche la liste à `"<nom>Left"` — la pièce dorée du
menu déroulant, **que nous avons justement masquée** — d'où un décalage vers
la droite. `UIDropDownMenu_SetAnchor` est l'entrée que le client prévoit pour
cela : `TOPLEFT` de la liste sur le `BOTTOMLEFT` du bouton, sans écart.


**Le client retaille le sélecteur à chaque ouverture du menu.**
`UIDropDownMenu_InitializeHelper` finit par
`frame:SetHeight(UIDROPDOWNMENU_BUTTON_HEIGHT * 2)`. Cette constante, nous
l'avons portée à **20** pour les lignes de menu de camelot : le sélecteur
reprenait donc **40** dès qu'on cliquait dessus. Elle est appelée par
`securecall` depuis `UIDropDownMenu_Initialize`, donc un greffon sur
celle-ci passe bien après et repose la taille retenue.

C'est le genre d'effet de bord qu'un réglage global entraîne : la hauteur
de ligne des menus et la hauteur d'un bouton de menu déroulant sont la
**même** constante dans 3.3.5.


**Le sélecteur est un bouton, plus un en-tête.** Écart assumé, sur demande :
il portait `UI-Character-Info-Title`, l'en-tête de catégorie de camelot ; il
prend désormais l'art de bouton `commonbuttontertiaryc60`, avec ses deux
états `common-button-tertiary-normal` et `…-pressed` (46 × 34 chacun).
L'état pressé **tient tant que sa liste est ouverte**.

Découpé et non étiré : mesuré sur l'art, à partir de `x = 11` le profil d'une
colonne ne change plus — l'about arrondi fait 11 px, donc coin de **11** sur
les deux axes (11 + 24 + 11 en largeur, 11 + 12 + 11 en hauteur). Tendue de
46 à 203, l'image écraserait ses angles.

La recette vit **une seule fois**, dans `ForeverUI.SkinTertiaryButton`
(`AtlasUtil`) : les sélecteurs et le bouton « New Set » du gestionnaire
l'emploient tous les deux. Son option `auto` fait suivre l'état pressé au
bouton de la souris ; sans elle, l'appelant commande par
`bouton.foreverPresser(vrai ou faux)` — ce que font les sélecteurs, dont
l'état tient tant que leur liste est ouverte.

La liste se ferme de **deux** façons : par `ToggleDropDownMenu`, et par
`CloseDropDownMenus` quand on clique ailleurs — celle-là ne passe pas par la
première. L'état se relève donc sur le `OnShow` et le `OnHide` de la **liste
elle-même**, qui couvrent les deux. La flèche du client (`$parentButton`) est
masquée : toute la barre ouvre déjà le menu.


L'intitulé ne se lit pas sur le cadre : la catégorie choisie vit dans une CVar
(`playerStatLeftDropdown`, `playerStatRightDropdown`) qui porte une **clé**
(`PLAYERSTAT_BASE_STATS`) ; le texte affichable est la globale du même nom. Le
client rappelle `UpdatePaperdollStats(préfixe, clé)` à chaque changement : un
`hooksecurefunc` dessus suffit à faire suivre l'intitulé — et il vaut mieux que
le `$parentText` du client, qui reste vide tant que le menu n'a pas été ouvert
une fois.

Le menu reste celui du client : `$parentButton` porte son `OnClick`
(`ToggleDropDownMenu`) et revient contre le bord droit de l'en-tête. Une flèche
de 24 sur une barre de 203 se chercherait, donc la barre entière ouvre aussi le
menu (`OnMouseUp`), comme un en-tête de camelot.

**Le banc n'enveloppait pas ses greffons.** Son `hooksecurefunc` se contentait
d'enregistrer la fonction dans `HOOKS` : appeler la fonction greffée ne
déclenchait rien, et un greffon cassé serait passé inaperçu. Il enveloppe
désormais vraiment — l'originale, puis le greffon, et les valeurs rendues sont
celles de l'originale.

**La rangée du bas se resserre vers la gauche.** Écart assumé, sur demande.
Les valeurs sont **relatives au voisin de gauche** et s'additionnent le long
de la chaîne d'ancrage :

| Emplacement | Réglage | Résultat à l'écran |
|---|---|---|
| main droite | — | 0 |
| main gauche | −2 sur l'écart de la source | −2 |
| distance / relique | −2 de plus | −4 |
| munitions | inchangé (19) | −4, hérités de la distance |

La « flèche » des munitions n'a pas de réglage propre : c'est une **région de
l'emplacement lui-même** — une texture `OVERLAY` de 23 × 41 centrée à
(−22, 0) sur `CharacterAmmoSlot` — donc elle le suit.

**Les quatre emplacements de la rangée du bas ont la même taille.** camelot
pose celui de distance en 27 avec `UI-Character-Info-GearSlotSmall`, comme
les munitions. Il porte pourtant, selon la classe, une **arme à distance ou
une relique** — des objets de même rang que les deux armes de mêlée. Écart
assumé, sur demande : main droite, main gauche, relique et distance font tous
40. Les munitions gardent le petit emplacement de la source.

**L'écart entre emplacements est désormais dissymétrique.** La source n'en
donne qu'un, **6**, pour les deux sens. À la demande, les deux colonnes sont
resserrées de 2 px (`ECART_VERTICAL` = 4) ; la rangée des armes garde le 6 de
la source, et l'écart des munitions (19) ne bouge pas.

**L'échelle du modèle, et ce que ce client sait en faire.** Camelot cadre son
personnage par une scène (`CharacterModelScene`) et la position de son
acteur. 3.3.5 n'a pas de scène, et ce client n'a **ni `SetCamDistanceScale`
ni `SetPortraitZoom`** — vérifié dans `Wow.exe`, où seul `SetModelScale`
figure. Le personnage est donc reculé par `SetModelScale` à la demande (0,1 à l'essai).
Valeur choisie à l'œil, pas relevée.

Relevé dans `Wow.exe`, ce client ne porte que **deux leviers** :

| Levier | Ce qu'il fait | Ce qu'on voit |
|---|---|---|
| `SetModelScale(s)` | réduit le **modèle** ; la caméra ne bouge pas | le modèle se réduit **autour de son origine**, il paraît donc aussi glisser vers le bas du cadre |
| `SetPosition(profondeur, latéral, hauteur)` | déplace le modèle devant la caméra | l'éloigner le rapetisse **sans changer son cadrage** : c'est le vrai recul |

Absents : `SetCameraDistance`, `SetCameraPosition`, `SetCameraTarget`,
`SetCustomCamera`, `SetPortraitZoom`, `SetCamDistanceScale`.

**Valeur retenue : `SetPosition(−6,5 ; 0 ; 0)`**, jugée à l'écran. C'est la
position qui cadre, pas l'échelle ; `MODELE_ECHELLE` reste à `nil`, ce qui
veut dire qu'on ne touche pas à l'échelle du client — et non qu'on la remet
à 1. Aucune des deux
valeurs ne se relève dans la source — camelot cadre par une scène que 3.3.5
n'a pas — elles se jugent donc à l'œil, d'où **`/fui modele`** :

```
/fui modele                    ce que porte le modèle
/fui modele echelle 0.8        SetModelScale
/fui modele position -5 0 0    SetPosition
/fui modele position defaut    rend la position au client
```

**Le modèle se charge après coup, et repart à zéro.**
`PaperDollFrame_OnShow` appelle `CharacterModelFrame:SetUnit("player")`, qui
lance un chargement **asynchrone**. Le réglage posé juste après s'applique à
un modèle qui n'est pas encore là : la fin du chargement remet la
transformation à zéro et le personnage ressort du cadre. Symptôme typique —
**la même commande tapée à la main tient**, parce que le modèle est alors
déjà chargé.

Le réglage est donc reposé à chaque image pendant **1,5 s** après chaque
passage de l'habillage (`ForeverUICharacterModelRecheck`), puis le
rattrapage se rendort. **Sans condition** : rien ne garantit que
`GetPosition` rende ce que le moteur dessine vraiment, donc on ne compare
pas, on repose. C'est le même rattrapage que pour la hauteur des sacs.
`UNIT_MODEL_CHANGED` est écouté pour relancer la fenêtre quand le personnage
change d'apparence.

**Le séparateur des volets passe devant l'encadrement.** L'habillage de la
fenêtre vit dans un cadre fils à `NIVEAU_ART` (+5) ; le séparateur, posé au
niveau du volet, passait dessous et se perdait sous le métal. Il prend un
cran de plus que l'habillage — calculé depuis la constante et non depuis le
cadre, puisque l'habillage n'existe pas encore quand les volets se montent.

**La ligne de niveau perd la race.** Le `PLAYER_LEVEL` de ce client vaut
`"Level %s %s %s"` — niveau, **race**, classe. Camelot, lui, emploie
`PLAYER_LEVEL_NO_SPEC`, qui ne porte que le niveau et la classe ; cette
chaîne n'existe pas ici. La ligne est donc recomposée à partir de deux
chaînes que le client porte — `UNIT_LEVEL_TEMPLATE` et le nom de classe —
plutôt qu'avec un format écrit en dur qui ne tiendrait que dans une langue.

**Les deux onglets du volet droit.** `PaperDollSidebarTabs` de camelot est un
cadre de 233 × 85 ancré au `TOP` du volet droit à `y = −4`, tenant des
`CheckButton` de **42 × 42** dont le premier est au `TOP (0, −5)`, les autres
collés à ses côtés. Chacun porte une icône de 42 en `BACKGROUND`, le cadre
`UI-Character-Info-StatTab` en `BORDER`, et `…-StatTab-Selected` quand il est
choisi. Ici il y en a **deux**, centrés en paire.

`PAPERDOLL_SIDEBARS` (que camelot charge depuis `mainline/`) donne les
icônes :

| Onglet | Source | Chez nous |
|---|---|---|
| Statistiques | `icon = nil`, « Uses the character portrait », rogné à 0,109375 / 0,890625 / 0,09375 / 0,90625 | identique |
| Gestionnaire d'équipement | `Interface\PaperDollInfoFrame\PaperDollSidebarTabs`, rogné | ce fichier **n'existe pas** dans ce client : `UI-GearManager-Button` le remplace, qui y est et qui est justement l'icône du bouton d'origine |

Les chaînes `PAPERDOLL_SIDEBAR_STATS` et `PAPERDOLL_EQUIPMENTMANAGER` sont
absentes elles aussi : l'infobulle du premier prend `CHARACTER_INFO`, la plus
proche que ce client porte ; le second a `EQUIPMENT_MANAGER`, qui existe tel
quel.

**L'icône tient dans l'ouverture du cadre, pas dans le bouton.** camelot donne
42 à son `Icon`, soit tout le bouton : ses icônes à lui sont des rognages de
`PaperDollSidebarTabs`, qui portent leur propre marge transparente. Un
portrait, lui, remplit sa texture d'un bord à l'autre et ressort donc des
angles arrondis du cadre. Mesuré sur `UI-Character-Info-StatTab` : sur ses
42, la bande de métal occupe 3..6 et 35..38, l'ouverture va donc de 7 à 34 —
**28 px**, centrés. C'est la taille de l'icône.

### Le gestionnaire d'équipement dans le volet droit

**Relevé — `PaperDollFrame.EquipmentManagerPane` (camelot).** Le panneau part
du `BOTTOMLEFT` de la bande de pierre et descend jusqu'au bas du volet ;
bordure `common-insideframe` (1, 1 / −4, 2) ; liste de (5, −8) à (−20, 105) ;
trait `UI-Character-Info-ScrollLine` au bas de la liste ; **Equip** 99 × 28 au
`BOTTOM (−50, 20)`, **Save** 99 × 28 au `BOTTOM (50, 20)`, **New Set**
180 × 34 au `BOTTOM (0, 50)` avec `UI-Character-Info-Icon-Add` à `LEFT (13)`.

**Relevé — `GearSetButtonTemplate` (camelot), la carte d'un ensemble :**
169 × 44 ; fond `UI-Character-Info-OutfitCard` 152 × 49 posé à `TOPLEFT x=42` ;
survol `…-Hover` et sélection `…-Selected` à la même place ; coche
`UI-Character-Info-Icon-Tick` à `RIGHT (−23, 0)` quand l'ensemble est **porté** ;
intitulé `GameFontNormalLeft` 98 × 38 à `LEFT (55)` ; icône 36 × 36 à
`LEFT (4)`, cerclée de `UI-Character-Info-OutfitIcon-Frame`.

**Ce que le client porte**, et qui n'est pas recréé : `GearManagerDialog`, une
fenêtre de 261 × 155 sur `UIPanelDialogTemplate` dont les
`GearSetButton1..MAX_EQUIPMENT_SETS_PER_PLAYER` sont posés **en grille de
cinq**. Une carte y est un `CheckButton` de 36 sur `PopupButtonTemplate` : son
icône est sa **NormalTexture**, son intitulé le `$parentName` sous elle, et un
`UI-EmptySlot-Disabled` derrière. La fenêtre passe dans le volet, son art de
fenêtre est effacé, ses cartes se reposent en colonne et se rhabillent : c'est
toujours le client qui tient la liste, la sélection et les infobulles.

**Ce qui diffère, et pourquoi.**

| Point | Raison |
|---|---|
| **New Set** | 3.3.5 n'a pas ce bouton : on y crée un ensemble par **Save**, qui ouvre la fenêtre de nom. Le nôtre fait la même chose après avoir vidé la sélection — exactement « enregistrer sous un nouveau nom ». Son intitulé est écrit **en dur**, « New Set » : `PAPERDOLL_NEWEQUIPMENTSET`, que camelot écrit, n'existe pas ici, et ce client ne porte aucune chaîne équivalente — ce libellé ne se traduira donc pas. Il porte le même **bouton tertiaire** que les sélecteurs de statistiques. |
| **Le panneau suit son onglet** | Ses boutons sont des cadres fils du **panneau**, pas de la fenêtre du client : masquer `GearManagerDialog` ne les emportait pas, et « New » restait visible sous les statistiques. Le panneau entier se montre et se cache avec l'onglet. |
| **Delete gardé** | camelot efface un ensemble par le menu de sa carte, menu que 3.3.5 n'a pas. Le bouton du client est **conservé** plutôt que de retirer la seule façon d'effacer un ensemble ; il est masqué par défaut au-dessus de Save, à replacer sur décision. |
| **La coche** | `GetEquipmentSetInfo` ne dit pas si un ensemble est porté, et 3.3.5 n'a **aucune** notion d'ensemble actif — son propre gestionnaire n'affiche d'ailleurs rien de tel. Deux conditions : (a) chaque pièce est dans **son** emplacement, (b) l'ensemble est le **dernier équipé**. |
| **Pas de barre de défilement** | `MinimalScrollBar` n'est pas portée. La liste défile à la **molette**, et le trait de camelot marque son bas. |
| **La carte, écarts assumés** | camelot donne 169 × 44 avec un fond de 152 × 49 à `x = 42`. Sur demande : la liste glisse de **4** vers la droite, la carte descend à **40** de haut (fond 45, le débord de 5 de la source étant gardé) et son fond passe à **174** de large, **calculé** pour que l'écart séparateur → icône égale l'écart carte → bord de la fenêtre : le séparateur est à −6 et fait 11, donc son bord droit tombe à 5 ; l'icône commence à 13, soit 8 ; la carte doit donc finir à 233 − 8 = 225. |
| **Les deux boutons de survol** | `$parentDeleteButton` 14 × 14 à `BOTTOMRIGHT (−21, 2)` sur `UI-GroupLoot-Pass-Up`, `$parentEditButton` 16 × 16 à `RIGHT` sur son `LEFT` (`x = −1`) sur `GEAR_64GREY` — alpha 0,5 au repos, 1 au survol, texture décalée de (1, −1) quand on appuie. Les deux textures existent déjà dans 3.3.5. |
| **Ils ne paraissent qu'au survol, suivi à chaque image** | Un `OnEnter` ne suffit pas : ce sont des **cadres fils** de la carte, y entrer déclencherait son `OnLeave` et les masquerait aussitôt. camelot interroge `IsMouseOver` dans `PaperDollEquipmentManagerPane_OnUpdate` ; même méthode ici. |
| **L'engrenage : modifier un ensemble** | Ce client n'a **pas** de `ModifyEquipmentSet` — vérifié dans `Wow.exe`. Il n'a que `SaveEquipmentSet(nom, icône)`, qui enregistre l'**équipement porté**, et `DeleteEquipmentSet`. Changer le nom ou l'icône sans toucher à la liste d'objets est donc impossible directement. Chemin retenu, sur décision : **équiper l'ancien** — l'équipement porté devient alors sa liste — **enregistrer** sous le nouveau nom et la nouvelle icône, **effacer l'ancien**, et **remettre le nouveau à sa place** dans la liste. |
| **C'est asynchrone** | `UseEquipmentSet` rend la main avant la fin ; c'est `EQUIPMENT_SWAP_FINISHED(terminé, nom)` qui l'annonce. Si l'ensemble est déjà porté, rien n'est à équiper et on enchaîne. Au bout de 10 s sans réponse — combat, pièce verrouillée — l'opération est abandonnée plutôt que laissée en suspens. |
| **On n'efface l'ancien que si le nouveau existe** | Un renommage effaçait l'ancien sans vérifier que l'enregistrement avait abouti — l'ensemble disparaîssait. Deux causes : (a) l'**indice d'icône** peut manquer, la fenêtre retenant l'icône présélectionnée dans `selectedTexture` et ne la convertissant en `selectedIcon` que pour les icônes de la **page visible** ; (b) `MAX_EQUIPMENT_SETS_PER_PLAYER` — créer avant d'effacer demande une place de plus, qui n'existe pas au plafond. Sans indice valide on **abandonne** ; au plafond l'ancien part **d'abord**, ce qui est sans risque puisque son équipement est porté à cet instant ; et dans tous les cas l'effacement suit une vérification par `GetEquipmentSetInfoByName`. |
| **Lire avant de fermer** | `GearManagerDialogPopup_OnHide` remet `popup.name` à **nil** : lire le nom après avoir caché la fenêtre le rendait vide, et `SaveEquipmentSet` répondait *Usage: SaveEquipmentSet("setName", iconIndex)*. Le même `OnHide` abandonne l'édition, d'où un drapeau qui dit que la fermeture vient de nous. Trois manques du banc l'avaient laissé passer : son `Hide` ne déclenchait pas `OnHide`, son `SaveEquipmentSet` acceptait un nom vide, et son `GearManagerDialogSaveSet_OnClick` ne **montrait** pas la fenêtre. |
| **Le Okay est repris, pas greffé** | Un greffon passerait **après** le client, qui aurait déjà enregistré l'équipement porté sous ce nom — c'est-à-dire tout sauf ce qu'on veut. Hors édition, la main lui est rendue telle quelle. |
| **L'ordre d'affichage est tenu par nous** | 3.3.5 n'a aucun moyen de replacer un ensemble dans sa liste (pas de `SetEquipmentSetPosition`), son ordre étant celui de création. Le nôtre vit dans `ForeverUIDB.ordreEnsembles` et c'est lui qui pose les cartes ; un ensemble renommé garde donc son rang. |
| **L'engrenage, infobulle** | Chez camelot il ouvre un menu d'**assignation de spécialisation** (`C_EquipmentSet.AssignSpecToEquipmentSet`), qui n'existe pas en 3.3.5. À la demande il rouvre la fenêtre de création sur l'ensemble choisi : le client la remplit alors de son nom et de son icône (`RecalculateGearManagerDialogPopup`), et son Okay voit que le nom existe déjà — il demande confirmation (`CONFIRM_OVERWRITE_EQUIPMENT_SET`) puis **écrase** au lieu de créer. Infobulle `SETTINGS`, `EQUIPMENT_SET_SETTINGS` n'existant pas ici. |
| **La croix rouge** | `StaticPopup_Show("CONFIRM_DELETE_EQUIPMENT_SET", nom)` — la fenêtre de validation du client, exactement comme camelot l'appelle. |
| **Le choix au-dessus du survol** | Les deux étaient en `BORDER`, où seul l'ordre de création départage — trop fragile pour une règle d'affichage. Le survol reste en `BORDER`, le choix monte en `ARTWORK`. |
| **Bordure découpée** | camelot tend `common-insideframe` d'un coin à l'autre. L'image fait 107 × 107 et porte un **motif dans chaque angle** : tendue sur les 233 × 379 du panneau, elle est multipliée par deux en largeur et trois et demi en hauteur, et tout se brouille. Neuf tranches, coin de **20** — mesuré sur l'art : le filet occupe 2..12 et 94..104, le motif d'angle s'arrête à 19. |

**La fenêtre du client couvre le panneau et prend la souris.**
`GearManagerDialog` est étalée sur tout le panneau et posée un cran plus haut
que lui : un bouton fils du **panneau** passait dessous et ne recevait plus
rien. Ceux du client — Equip, Save — sont ses enfants à elle, donc épargnés.
Et elle **se hisse toute seule** : elle est déclarée `toplevel="true"` dans le
FrameXML, et son `OnShow` finit par `GearManagerDialog:Raise()` — à chaque
ouverture elle repasse au sommet de sa strate, après tout niveau posé une fois
pour toutes. Deux corrections : `SetToplevel(false)`, puisqu'elle n'est plus
une fenêtre, et le niveau du bouton **recalculé depuis le sien à chaque
passage**, la pose des boutons tournant justement après son `OnShow`. Même famille de défaut que
le modèle 3D sur les emplacements d'équipement : **un cadre sensible à la
souris qu'on étale sur un volet avale tout ce qui reste dessous**.


**La coche demandait deux questions, je n'en avais traité qu'une, mal.**

1. **La pièce est-elle dans le BON emplacement ?** `GetEquipmentSetLocations`
   rend une table indexée par **emplacement d'équipement**, et
   `EquipmentManager_UnpackLocation` rend `joueur, banque, sacs, SLOT`. Je ne
   lisais que les deux premiers drapeaux : une pièce portée dans un **autre**
   emplacement passait pour bonne, d'où des coches sur des ensembles sans
   rapport. Il faut comparer le slot rendu à la **clé**.
2. **Deux ensembles aux mêmes pièces.** Si deux ensembles décrivent le même
   équipement, la géométrie ne peut pas les départager : tous deux sont
   « portés ». Le dernier ensemble équipé est donc retenu (greffon sur
   `UseEquipmentSet`, gardé d'une session à l'autre dans `ForeverUIDB`), et la
   coche va à celui-là — **à condition qu'il soit encore porté**, sinon elle
   disparaît dès que le joueur change une pièce à la main.

**Le système de panneaux reprend la main, il faut repasser derrière.**
`GearManagerDialog_OnShow` appelle `UpdateUIPanelPositions(CharacterFrame)`
et `_OnHide` appelle `UpdateUIPanelPositions()` : le système de panneaux
replace alors la feuille à **sa** position, et la place retenue par le joueur
est perdue — ouvrir le gestionnaire remettait la fenêtre à zéro. Le greffon
est posé sur `UpdateUIPanelPositions` elle-même plutôt que sur le seul
gestionnaire : toute autre ouverture qui la déclenche pose le même problème,
et il ne coûte rien quand aucune place n'est retenue.

**Les deux onglets se comportent en onglets.** Celui qu'on ouvre ferme
l'autre : le gestionnaire montre son panneau et **masque les statistiques**,
les statistiques ferment le panneau et reviennent. Deux pièges :

- au retour, on ne rallume pas les lignes une à une et on laisse le client
  refaire son travail (`PaperDollFrame_UpdateStats`). `UpdatePaperdollStats`
  décide seul de la **sixième ligne** — il la montre, et la cache pour les
  catégories qui n'ont que cinq statistiques — et forcer la nôtre par-dessus
  ferait apparaître une ligne vide ;
- `poserStatistiques` repasse à chaque événement (équipement, ouverture,
  niveau…) et y montrait les sélecteurs sans condition : il lit désormais
  l'état de l'onglet, sinon les statistiques se rallumaient toutes seules.

Le client n'a **pas** d'onglets latéraux, ces deux-là sont donc créés — mais
le gestionnaire, lui, n'est pas recréé : l'onglet ouvre et ferme le
`GearManagerDialog` du client, exactement comme `GearManagerToggleButton`,
qui est masqué. `SetCheckedTexture` ne prend qu'un **chemin** dans ce client,
jamais un rectangle d'atlas : la marque de sélection est donc une texture à
nous, montrée et cachée à la main.

**Le portrait suit son anneau, il ne se recale pas.** L'anneau est porté par
le **coin haut gauche de l'encadrement** : déplacer ce coin déplace le trou,
et un portrait posé en absolu se retrouve à côté — c'est ce qui est arrivé
quand l'encadrement est passé au calcul sur le filet intérieur. Sa place se
calcule donc **depuis le coin** :

```
PORTRAIT_X = coinHautGauche.x + 38
PORTRAIT_Y = coinHautGauche.y - 38,5
```

Le centre du trou vaut (38 ; −38,5) en pixels d'affichage depuis le coin haut
gauche de l'image. Mesuré sur l'art — l'anneau occupe les plages 13..39 et
113..138 de la feuille, en double densité, soit un trou centré à 76 px de
feuille = 38 affichés — et c'est aussi ce que donnait la place validée en jeu
quand le coin était à (−13, 16). Le banc vérifie l'écart au coin, pas la
position absolue, pour que cela ne puisse plus dériver.

**La source ne s'arrête pas à `NineSliceLayouts`.** `PortraitFrameTemplate`
donne les mêmes décalages que `HeldBagLayout` — haut gauche (−13, 16), haut
droit (4, 16), bas gauche (−13, −3), bas droit (4, −3) — seul l'atlas du coin
haut gauche diffère. Mais camelot **repasse ensuite sur toutes les mises en
page** (`camelot/NineSliceLayoutOverrides.lua`), parce que, dans ses mots,
« l'art fait pour Camelot ne fait pas la taille exacte de l'art standard et
doit être décalé autrement » :

| Pièce | Atlas | Correction | Résultat |
|---|---|---|---|
| `TopRightCorner` | `UI-Frame-Metal-CornerTopRight` | `x += −2` | 2 |
| `BottomLeftCorner` | `UI-Frame-Metal-CornerBottomLeft` | `y = −8` (remplace) | −8 |
| `BottomRightCorner` | `UI-Frame-Metal-CornerBottomRight` | `x += −2`, `y = −8` | 2, −8 |

Nous prenions les valeurs **non corrigées** : les deux coins du bas étaient
5 px trop haut et les coins de droite 2 px trop à droite.

**Mais même corrigés, ces décalages posent le CONTOUR EXTÉRIEUR de l'image.**
Le filet intérieur du métal tombe alors à 6 px **dans** la fenêtre, et ces
6 px de fond restent visibles sous lui — ce qui se lit comme un encadrement
qui n'atteint pas le bas. Le décalage se calcule donc sur le **filet
intérieur**.

**Mesuré sur l'art, jamais sur une capture** : une capture d'écran a sa propre
échelle, l'atlas non. `uiframemetal2xc60` est en double densité, donc les
mesures sont divisées par deux. Distance du filet intérieur au bord de
l'image, en pixels d'affichage :

| Bande | Filet intérieur | Décalage |
|---|---|---|
| gauche | 18,5 (identique sur le coin portrait et le coin bas gauche) | `x = −18,5` |
| droite | 8,5 | `x = 8,5` |
| basse | 14 | `y = −14` |
| haute | 41,5 — c'est la **barre de titre**, intérieure par conception | le haut ne se recalcule pas |

`SetPanelArt` prend une option `coins` pour ces décalages ; la feuille s'en
sert, avec en plus **1 px de montée** — celui-là n'est pas de la source, il a
été jugé à l'écran (`PANNEAU_MONTEE`).

⚠ **La fenêtre des sacs a les deux mêmes défauts** : ni les overrides de
camelot, ni le calcul sur le filet intérieur. Elle est **validée**, donc
laissée telle quelle : à reprendre sur accord.

**À niveau de cadre égal, c'est le modèle qui reçoit le clic.** Chez le
client, la scène du modèle tient entre les deux colonnes d'emplacements
(233 × 215) : rien ne se recouvre. Camelot lui donne **tout le volet gauche**
et pose les emplacements par-dessus. Mais `CharacterModelFrame` est sensible
à la souris, et il naît au même niveau que les emplacements — tous enfants de
`PaperDollFrame`.

Mesuré en jeu avec `/fui perso` :

```
tete : 39x39 strate=MEDIUM niveau=28 souris=1 montre=1
   clic=true glisser=true recoit=true actif=true
   ce qui couvre son centre et prend la souris :
      PaperDollFrame        strate=MEDIUM  niveau=27
      CharacterModelFrame   strate=MEDIUM  niveau=28
      CharacterHeadSlot     strate=MEDIUM  niveau=28
      sous le curseur : CharacterModelFrame
```

Le bouton avait tous ses scripts et prenait la souris : c'est bien le modèle
qui interceptait, donc **plus de déséquipement et plus d'infobulle**. Les
emplacements passent d'un cran au-dessus de lui. Le test est un « au moins »
(`if niveau <= niveau du modèle`) et non une augmentation sèche : l'habillage
se rejoue à chaque ouverture et à chaque changement d'équipement, une
incrémentation ferait monter le niveau sans fin.

Le réflexe général : **dès qu'on agrandit un cadre sensible à la souris pour
lui faire remplir un volet, il faut remonter ce qui doit rester cliquable
par-dessus.** Un niveau égal ne se voit pas à l'écran.

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

### Les listes des menus déroulants

**Un seul cadre pour tout le jeu.** 3.3.5 n'a que `DropDownList1` et
`DropDownList2` (sous-menu), globaux : le menu des catégories de
statistiques, un clic droit sur un joueur et la liste d'un panneau
d'options passent tous par eux. Les rhabiller les rhabille tous, ce qui est
aussi ce que fait camelot — `MenuVariants.GetDefaultMenuMixin` et
`GetDefaultContextMenuMixin` rendent le même `MenuStyle1Mixin`.

**Quelle saveur.** `Blizzard_Menu.toc` charge `Camelot\Menu.xml` pour
camelot, mais ses gabarits viennent de `[Family]\MenuTemplates` et il n'y a
pas de `camelot/`. Entre les deux familles présentes, la réponse se lit dans
l'art : les atlas `common-dropdown-classic-*` que cite `classic/` n'existent
**nulle part** dans l'index de ce client, tandis que les
`common-dropdown-*` de `mainline/` ont tous leur variante `c60`. C'est donc
la famille `mainline`, avec l'art `c60`.

| Pièce | Ce que le client charge | Ce que fait camelot | Chez nous |
|---|---|---|---|
| Fond | deux `Backdrop` en cadres fils, montrés l'un ou l'autre selon `displayMode` : `UI-DialogBox-Background-Dark` et `UI-Tooltip-Background` | `common-dropdown-bg`, **une texture étirée**, `TOPLEFT (−10, 3)` → `BOTTOMRIGHT (10, −3)`, alpha 0,925 | `common-dropdown-bg-c60` en **neuf tranches**, marges prises sur l'image, même alpha |
| Hauteur d'une ligne | 16 (`UIDROPDOWNMENU_BUTTON_HEIGHT`) | 20 (`DarkMenuElementTemplate`) | 20, constante comprise — le client s'en sert pour le pas ET pour la hauteur de la liste |
| Police | `GameFontHighlightSmallLeft` | `GameFontHighlight`, blanc, justifié à gauche | `GameFontHighlightLeft` |
| Coche | une seule texture, `UI-CheckBox-Check` 18 × 18 à `LEFT`, montrée si coché | la **case** `common-dropdown-ticksquare` toujours là, la **coche jaune** `common-dropdown-icon-checkmark-yellow` par-dessus si choisi | la case en `BORDER`, la coche du client repeinte en jaune et centrée dessus à (2, 1) |
| Surbrillance | `UI-QuestTitleHighlight` en `ADD` | `MenuVariants.CreateHighlight` : **la même** | rien à faire |
| Flèche de sous-menu | `ChatFrameExpandArrow` | `MenuVariants.CreateSubmenuArrow` : **la même** | rien à faire |
| Largeur | taillée sur le texte le plus long (`maxWidth + 25`) | `DropdownButtonMixin:RegisterMenu` pose `SetMinimumWidth(self:GetWidth())` | plancher à la largeur du menu déroulant qui l'ouvre |

**Une image de panneau ne s'étire pas d'un bord à l'autre.** Camelot pose
`common-dropdown-bg` en **une seule texture étirée**. Mesuré sur l'image —
68 × 68 — le panneau n'occupe que `x 9..58` et `y 6..55` : le reste est une
**ombre** de 9 à gauche et à droite, 6 en haut et **12 en bas**, et les angles
sont coupés sur 6 pixels. L'étirer sur une liste de 200 × 130 multiplie cette
ombre par 3,3 en largeur et par 2 en hauteur : le filet doré rentre d'une
vingtaine de pixels de chaque côté, les angles s'écrasent, et le bas du
panneau remonte **au-dessus de la dernière ligne**.

Le fond est donc découpé en neuf tranches (`ForeverUI.CreateNineSlice`, une
image → neuf textures) : les coins gardent leur taille, les bords ne
s'étirent que dans un sens, le centre dans les deux. Le coin vaut **18** —
l'ombre la plus épaisse (12) plus le pan coupé (6) — ce qui laisse une bande
centrale de 32 sur les 68. Et les marges ne sont plus celles de camelot mais
**celles de l'image** (9, 6, 9, 12) : donner l'épaisseur de l'ombre fait
tomber le filet exactement sur le bord du cadre, donc sur la largeur du menu
déroulant.

**La largeur est une égalité — écart assumé, sur demande.** Camelot n'impose
à la liste qu'un *minimum* (`DropdownButtonMixin:RegisterMenu`,
`SetMinimumWidth`) et la laisse s'élargir si une entrée est plus longue ; ici
elle prend **exactement** la largeur de son bouton, quitte à serrer le texte
d'une entrée plus longue. Il se pose à l'affichage de la liste :
`ToggleDropDownMenu` retient le menu ouvert (`UIDROPDOWNMENU_OPEN_MENU`)
**avant** de la montrer et ne vérifie qu'elle tient dans l'écran
qu'**après** ; la largeur doit donc être acquise à ce moment-là, sinon le
recadrage se ferait sur l'ancienne. `UIDropDownMenu_Refresh` retaille aussi
la liste, donc le plancher se repose derrière elle. Les lignes gardent
l'écart de 25 que le client tient entre la liste et elles, pour que la marge
de droite ne bouge pas. Seul le premier niveau est concerné : un sous-menu
n'est ouvert par aucun bouton de menu déroulant.

**Retirer un fond, pas le masquer.** `ToggleDropDownMenu` montre l'un ou
l'autre `Backdrop` à chaque ouverture, selon `displayMode` : un cadre masqué
se relèverait au clic suivant. `SetBackdrop(nil)` le vide une fois pour
toutes, et un cadre sans fond ne dessine rien.

**La police se remet à chaque ligne.** `UIDropDownMenu_AddButton` repose
`GameFontHighlightSmallLeft` à chaque appel (sauf `info.fontObject`), et
c'est elle aussi qui sait si la ligne porte une case (`info.notCheckable`,
qu'elle retient dans `button.notCheckable`). L'habillage se rejoue donc
dans un `hooksecurefunc` sur elle, pas une fois pour toutes ; le rang de la
ligne posée est `listFrame.numButtons`.

**Écarts assumés.** Les marges de camelot sont dissymétriques (8 en haut, 15
en bas) ; 3.3.5 n'a qu'une constante pour les deux,
`UIDROPDOWNMENU_BORDER_HEIGHT`, et la sert deux fois — elle reste à 15. La
case à cocher et la coche jaune n'ont pas de variante `c60` : leur art de
base est celui que camelot montre. Enfin 3.3.5 ne distingue pas une case à
cocher d'un bouton radio (un menu n'a que `info.checked`), donc la paire
case + coche sert partout, là où camelot prendrait le rond
(`common-dropdown-tickradial`) pour un choix unique.

**Le piège des noms d'atlas.** `tools/ajouter_feuilles.py` inscrit chaque
atlas sous son nom brut **et** sous son nom logique (sans suffixe de
variante), premier arrivé premier servi, feuilles triées par nom. En versant
`commondropdown.blp` à côté de `commondropdownc60.blp`, le nom logique
`common-dropdown-bg` est donc allé à la feuille **de base**. Le code nomme
la variante en clair, `common-dropdown-bg-c60`, pour ne rien laisser au
hasard.

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

### Le choix d'icône d'un ensemble

**Relevé — `IconSelectorPopupFrameTemplate` (camelot).** Fenêtre 525 × 495 ;
intitulé du champ à `TOPLEFT (24, −21)` ; champ de nom 182 × 20 à
`(29, −35)`, 16 lettres ; « Choose an Icon: » à `(24, −79)` ; zone du choix
275 × 45 à `TOPRIGHT (−13, −13)`, son bouton d'icône 36 à `(−4,5 ; −3,5)` ;
grille 494 × 361 à `TOPLEFT (21, −97)`.

**Relevé — `ScrollBoxSelectorMixin`** (la grille elle-même) : `GetStride`
rend **10**, `GetButtonHeight` **36**, `GetPadding` marges de 5 et écarts de
**10** dans les deux sens.

**Tout le remplissage du client passe par quatre globales.**
`GearManagerDialogPopup_Update` et `RecalculateGearManagerDialogPopup` ne
lisent que `NUM_GEARSET_ICONS_PER_ROW`, `NUM_GEARSET_ICON_ROWS`,
`NUM_GEARSET_ICONS_SHOWN` et `GEARSET_ICON_ROW_HEIGHT`. Les porter aux
valeurs de camelot — 10, 8, 80 et 46 — suffit à obtenir sa grille : ni le
parcours des icônes, ni le défilement, ni la sélection ne sont réécrits.

**Ce qui diffère, et pourquoi.**

| Point | Raison |
|---|---|
| **Soixante-cinq boutons en plus** | Le client n'en crée que **quinze** à son `OnLoad`, en grille de cinq. Il en faut 80 : les manquants sont créés sur **son** gabarit (`GearSetPopupButtonTemplate`) et tous sont reposés en rangées de dix. |
| **Barre de défilement** | `MinimalScrollBar` est portée : 8 de large, glissière en trois morceaux (`minimal-scrollbar-track-top/-middle/-bottom`), curseur sur `minimal-scrollbar-thumb-middle`, flèches de 17 × 11. Seules les **textures** changent : le `FauxScrollFrame` du client garde tout son comportement. **Le curseur est une région de la barre** : la boucle qui efface l'art d'époque l'emportait, et lui rendre sa texture sans lui rendre son alpha le laissait invisible — la barre paraissait cassée. Il est exclu de l'effacement, et posé à 8 × 36, la taille du curseur le plus court de la source. |
| **Place** | camelot ancre la fenêtre en `TOPLEFT` sur le `TOPRIGHT` de ce qu'elle accompagne — ici la feuille de personnage. 3.3.5 la posait sous le gestionnaire, qui n'est plus une fenêtre. |
| **Hauteur** | Écart assumé, sur demande : celle de la **feuille de personnage**, et non les 495 de camelot. Le nombre de rangées s'en déduit — **sept**. |
| **Écart de la barre** | Sur demande, le même entre la dernière colonne d'icônes et la barre qu'entre la barre et le bord de la fenêtre. Il se **calcule** — `((largeur − bord droit) − droite des icônes − largeur de barre) / 2` — donc il suit si la grille ou la fenêtre changent. |
| **Okay et Cancel** | Ils tombent dans les **deux creux** du coin bas droit, et c'est la source qui le dit : `SelectionFrameTemplate` — le même gabarit qui porte cet encadrement — place `CancelButton` 78 × 22 à `BOTTOMRIGHT (−11, 13)` et `OkayButton` à `RIGHT` sur son `LEFT`, `x = −2`. Inutile de mesurer le socle. |
| **Flèches de la barre** | `minimal-scrollbar-arrow-top` et `-bottom` font **17 × 11**, et ce client n'en porte aucune variante en double densité : elles sont dessinées à leur taille exacte, leur finesse est celle de l'art. |
| **Fond et encadrement** | Fond noir à **80 %** de `(7, −7)` à `(−7, 7)`, et `SelectionFrameTemplate` en neuf pièces : coins hauts 18 × 71, coin bas gauche 18 × 39, **coin bas droit 174 × 39** (il porte le socle des boutons), bord haut 256 × 68, bord bas 256 × 39, bords latéraux 17 × 256. Quatre feuilles versées : `macropopupc60`, `macropopupverticalc60`, `minimalscrollbarproportionalc60`, `minimalscrollbarverticalc60`. **Les bandes latérales gardent leur largeur d'atlas** : les ancrer par deux coins opposés les étire jusqu'au coin voisin, et le coin bas droit fait 174 — la bande droite s'étalait sur 174 au lieu de 17. Deux points du **même côté** suffisent. |
| **L'encadrement de la barre n'est pas sur la barre** | Le cadre de défilement du client porte lui-même deux textures de 30 de large — le contour d'époque de la glissière — qu'effacer les régions de la seule barre laissait en place. |
| **Les deux lignes du choix courant** | `ICON_SELECTION_TITLE_CURRENT` et sa description n'existent pas dans ce client : écrites en dur, comme « New Set ». |
| **« Click to view in the list »** | 3.3.5 sait déjà faire ce saut : `RecalculateGearManagerDialogPopup` déplace le défilement jusqu'à l'icône retenue. Le bouton l'appelle. |


### Défauts connus

**Un sac peut sortir par le haut de l'écran.** Selon le nombre et la taille
des sacs ouverts, le dernier de la pile passe au-dessus du bord supérieur.

C'est une **reproduction fidèle d'un défaut de la source**.
`UpdateContainerFrameAnchors` (mainline ; camelot ne la redéfinit pas)
calcule la place restante ainsi :

```
libre = hauteurEcran / echelle - decalageY
pour chaque sac :
    1er            -> BOTTOMRIGHT du parent (-decalageX, decalageY)
    libre < hauteur -> nouvelle colonne, BOTTOMRIGHT sur le BOTTOMLEFT
                       du premier sac de la colonne courante, (-11, 0)
    sinon          -> BOTTOMRIGHT sur le TOPRIGHT du précédent, (0, 8)
    libre = libre - hauteur
```

`libre` est diminué de la **hauteur du sac seulement** : l'écart de 8 px
empilé entre deux sacs n'est jamais compté. Pour *N* sacs dans une colonne,
la pile réelle dépasse l'estimation de (*N* − 1) × 8, et le saut de colonne
arrive donc trop tard. Aucune marge n'est gardée en haut non plus.

`ForeverUI.BagsStack` reprend ce calcul à l'identique, et le rattrapage
(`ForeverUIBagsRecheck`) rejoue bien l'empilement quand une hauteur change —
ce n'est donc pas un défaut d'ordre, mais bien l'arithmétique de la source.

Le corriger serait un **écart assumé** : retrancher aussi l'écart de 8 à
chaque sac empilé, et éventuellement garder une marge haute. À décider, la
fenêtre des sacs étant validée.

**Le bouton du menu déroulant reste à reprendre.** La liste ouverte est
maintenant à la DA de camelot ; le bouton fermé, lui, ne l'est pas encore. Ce
qui est en place aujourd'hui est l'en-tête de catégorie
(`CharacterStatFrameCategoryTemplate`, `UI-Character-Info-Title`), choisi pour
coiffer un groupe de statistiques — pas le contrôle de menu déroulant que
camelot emploie ailleurs.

Le gabarit de camelot est `WowStyle1DropdownTemplate`
(`Blizzard_Menu/mainline/MenuTemplates.xml`), 120 × 25 :

| Pièce | Camelot | État chez nous |
|---|---|---|
| Fond | `common-dropdown-textholder`, `TOPLEFT (−8, 7)` → `BOTTOMRIGHT (8, −9)` | remplacé par `ui-character-info-title` |
| Flèche | `common-dropdown-a-button` à `RIGHT (1, −3)`, **six états** — `-hover`, `-pressed`, `-pressedhover`, `-open`, `-disabled` (`GetWowStyle1ArrowButtonState`) | la flèche du client, `UI-ChatIcon-ScrollDown-Up`, sans états |
| Texte | `GameFontHighlight`, `wordwrap` faux, justifié à gauche, entre `TOPLEFT (8, −8)` et la flèche | notre `FontString` centré |

L'art est **déjà dans l'atelier** : `commondropdownc60.blp` porte
`common-dropdown-textholder-c60`, `common-dropdown-a-button-c60` et ses cinq
variantes d'état, et `common-dropdown-b-button-c60` pour le gabarit de filtre
(`WowStyle1FilterDropdownTemplate`). Rien de nouveau à verser dans l'archive.

À trancher au moment de le faire : 3.3.5 n'a pas la notion d'état `open` sur
un `UIDropDownMenuTemplate` — il faudra la déduire de `DropDownList1:IsShown()`
et de `UIDROPDOWNMENU_OPEN_MENU` — et les sélecteurs de la feuille de
personnage devront choisir entre le contrôle de menu déroulant et l'en-tête de
catégorie, qui ne sont pas le même objet dans la référence.

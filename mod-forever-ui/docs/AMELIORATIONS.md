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
| **La liste du client se met à jour après coup, et l'événement ne suffit pas** | `GetNumEquipmentSets` et `GetEquipmentSetInfo` ne rendent pas le nouvel état dans la foulée d'un enregistrement ni même à l'instant où `EQUIPMENT_SETS_CHANGED` arrive. La liste se reposait donc sur l'état d'**avant** et restait en retard d'une opération : renommer AAA en AAB ne montrait plus rien, créer AZE faisait apparaître AAB, supprimer AAB faisait apparaître AZE. Elle se repose désormais à l'**image suivante** (`ForeverUIEquipmentRecheck`), comme la hauteur des sacs. |
| **L'ordre ne s'élague pas pendant l'affichage** | Il le faisait, et c'était la seconde moitié du défaut : quand le client ne rend momentanément **aucun** ensemble, l'élagage vidait la table d'ordre pour de bon, et les noms y revenaient ensuite un par un. Un nom inconnu est simplement sauté. |
| **Un fichier ajouté au `.toc` n'arrive qu'au prochain démarrage** | Le client dresse la liste des fichiers d'un addon à l'ouverture ; `/reload` rejoue ceux qu'il connaît déjà, mais n'en découvre pas de nouveau. `Panes.lua` était sur le disque, inscrit au `.toc`, et pourtant absent : `ForeverUI.Panes` valait nil et la feuille s'arrêtait sur une erreur au chargement. Elle le **dit** désormais et se tait, au lieu de casser — le reste de l'interface tient. Le banc rejoue le cas dans un client neuf, sans ce fichier. **À retenir pour tout nouveau fichier : il faut fermer et rouvrir le jeu, `/reload` ne suffit pas.** |
| **La visibilité se décidait à cinq endroits : elle n'en a plus qu'un** | L'habillage, les deux onglets du volet, le repli et la fonction des statistiques montraient et masquaient chacun de leur côté, et l'habillage reposait **toute** la géométrie à chaque événement. Deux fautes en découlaient, que rien ne pouvait prévenir : le panneau du gestionnaire restait à l'écran quand on changeait d'onglet latéral — il appartient à **notre** volet droit, et non au `PaperDollFrame` du client, seul cadre que le client masque — et les barres de réputation traversaient ce volet, `ReputationFrame` gardant la taille de la fenêtre d'origine sans que personne ne le borne. `Panes.lua` pose le modèle de camelot : des **hôtes** (`LeftPaneHost`, `RightPaneHost`), des **groupes** (ce qu'un onglet ouvre, un écran entier) et des **pages** (deux contenus qui se partagent une surface). Un contenu se construit une fois, à sa première ouverture, et ne fait ensuite que paraître. |
| **On ne reparente pas les cadres du client** | La tentation était d'adopter les douze lignes de statistiques et la fenêtre du gestionnaire dans nos volets : `Hide()` sur l'hôte les emporterait. Mais reparenter réinitialise le niveau et la strate, et des réglages déjà validés — les emplacements au-dessus du modèle, le bouton de repli au-dessus de lui — s'y perdraient. Un contenu déclare donc la **liste** des cadres du client qu'il possède, et la bibliothèque les montre et les masque avec sa racine. Une seule boucle, un seul endroit. |
| **Le commutateur du client est le nôtre** | `CharacterFrame_ShowSubFrame` n'affiche qu'un des cinq écrans de `CHARACTERFRAME_SUBFRAMES` : c'est lui le commutateur. Le nom de l'écran sert de nom de groupe — aucune table de correspondance à tenir à jour, et rien à réécrire si le client en ajoute un. |
| **Un fichier que le listfile ne nomme pas s'exporte par son FileDataID** | `CHARACTER_MODE_TAB_ICONS` nomme les icônes en clair, mais le listfile communautaire n'identifie pas les `INV_SideTab_*_c60` : `/resolve` rend `null` et `/search` n'en connaît aucune. Elles n'existent que par leur identifiant. `tools/ajouter_feuilles.py` accepte donc une ligne `source => nom voulu` : on exporte par l'identifiant et on range sous le nom que la source donne, pour que l'atelier reste lisible et que l'identifiant demeure noté. Réputation `8197103`, monnaie `8197078`, PvP Alliance `8197097`, PvP Horde `8197098`. |
| **Rien ne disait quel onglet était ouvert** | `LargeSideTabButtonTemplate` empile quatre choses : `common-sidetab` en BACKGROUND, l'icône en ARTWORK, **`common-sidetab-selected` en OVERLAY** pour l'onglet actif, et `common-sidetab-hover` en HIGHLIGHT pour le survol seul. Le marqueur d'actif n'était pas posé — son atlas était déclaré et jamais utilisé. Il l'est maintenant, et une seule chose le décide : le groupe ouvert. Rien à retenir, aucun clic à intercepter. |
| **L'icône d'onglet perdait un tiers de sa surface** | `fillToInterior` est vrai pour ces onglets, et `UpdateIconInterior` en tire deux gestes : `SetTexCoord(0.03125, 0.96875, …)` et `SetSize(extent, extent)` avec `interiorExtent` valant 50 par défaut. L'onglet faisant 55 de large, l'icône en prend 50 — tout l'intérieur, moins le bord. Elle était à 32. |
| **Le masque est cuit dans l'image** | La source découpe l'icône par `common-sidetab-mask`, une `MaskTexture` que 3.3.5 n'a pas. Ce que le client ne sait pas faire à l'écran, `tools/cuire_masque.py` le fait avant : l'alpha du masque est multiplié dans celui de l'icône. La géométrie vient de la source, pas d'une estimation — onglet 55 × 55, masque 55 × 60 ancré au centre, icône 50 × 50 en (−3, 0) rognée à 0,03125 — et hors du masque le wrap `CLAMPTOBLACKADDITIVE` donne zéro. Deux dossiers : `icons/` garde l'export brut, qui est la provenance et l'entrée de la cuisson ; `TabIcons/` porte les versions cuites, et c'est celles-là qu'on affiche. Relancer l'outil refait les secondes à partir des premières, sans wow.export. |
| **L'onglet de réputation, repris de camelot** | `ReputationFrame.xml` donne la liste — `TOPLEFT (10, −40)` et `BOTTOMRIGHT (−25, 15)` sur le volet gauche, deux traits `UI-Character-Info-ScrollLine-Long` centrés sur son haut et son bas — et les gabarits : entrée de 30, barre de 160 × 29 héritée de `ColoredProgressBarTemplate`, fond `common-stat-bar-bg`, remplissage `common-stat-bar-white` **teinté** et haut de 15. 3.3.5 a les mêmes pièces sous d'autres noms : quinze `ReputationBar<i>` ancrées une fois dans le XML, que `ReputationFrame_Update` ne fait que remplir — on peut donc les reposer une fois pour toutes, et se greffer après lui pour teindre. |
| **Cocher « Move to Inactive » désélectionnait la faction** | Le `OnClick` du client appelle `SetFactionInactive(GetSelectedFaction())`, qui **déplace** la faction dans le bloc des inactives : tout se renumérote, et l'indice retenu désignait alors une autre ligne. Le détail suit donc le **nom** — comme la marque de la liste — et retrouve l'indice à chaque passage, qu'il repose au client pour que ses trois cases agissent sur la bonne faction. Si la faction quitte la liste, le volet garde ce qu'il montrait plutôt que de se vider. |
| **Sans faction choisie, le volet droit est vide** | C'est l'état de départ. La source de vérité est notre nom retenu, pas `GetSelectedFaction` — que le client peut laisser pointer n'importe où. |
| **Les épées n'appartiennent qu'à la guerre** | Les trois cases partagent le même fond, `checkbox-minimal`, mais pas la même coche : `AtWarCheckbox` porte `Interface/Buttons/UI-CheckBox-SwordCheck` — deux épées croisées, en 32 posées à `(3, −5)` — tandis que `MakeInactiveCheckbox` et `WatchFactionCheckbox` prennent `checkmark-minimal`, centré. Les épées avaient été données aux trois. |
| **Un texte ne revient à la ligne que s'il a une boîte** | La description n'avait que son bord haut et ses deux côtés : sans bas, une description un peu longue n'avait nulle part où aller et disparaissait entièrement. Elle a maintenant ses quatre bords — du bas de la jauge au haut des trois cases — et se replie dedans. |
| **`GameFontNormal` est doré, pas blanc** | camelot déclare `fontName = GameFontNormal` sur son `ScrollingFontTemplate`, mais en 3.3.5 cet objet de police est celui des **titres**, en or. Le blanc y est `GameFontHighlight`, et c'est ce que montre la référence. |
| **Un `<Backdrop>` n'est pas une région** | `ReputationDetailFrame` porte un fond de fenêtre déclaré en `<Backdrop>` — `UI-DialogBox-Background` et `UI-DialogBox-Border`, avec ses marges et sa taille de tuile. Il ne figure pas dans `GetRegions` : le balayage des textures ne l'atteignait pas et son cadre gris restait à l'écran. `SetBackdrop(nil)` l'enlève, comme pour les listes de menu. **À vérifier sur tout cadre du client que l'on reprend** : les deux façons de poser un fond demandent deux gestes différents. |
| **Le même balayage appliqué à la réputation** | À la demande, l'onglet validé reçoit le traitement des compétences : régions **et** cadres fils masqués à chaque passage, sans énumération — sa liste à ascenseur, ses intitulés de colonne et ses traits d'arborescence partent avec. Les deux traits de liste ont migré sur notre panneau, hors d'atteinte du balayage. Le cadre de détail, lui, y échappe : il a changé de parent et vit dans le volet droit. |
| **Un écran du client ne se réduit pas à ses lignes** | `SkillFrame` déclare aussi un bouton de tri, un « tout replier », son cadre de dépliage et ses trois tuiles, deux boutons accepter / annuler, sa liste à ascenseur et tout un cadre de détail — `ScrollFrame`, `ScrollChildFrame`, `StatusBar`. Les énumérer serait une liste à tenir à jour et à oublier : on masque donc **tout** ce que ce cadre porte et qui n'est pas à nous. `GetRegions` ne rend que les textures, `GetChildren` que les cadres fils — il faut les deux, et à chaque passage, `SkillFrame_UpdateSkills` remontrant les siennes. |
| **Nos propres pièces vivent sur notre panneau** | Conséquence du balayage sans condition : les deux traits de liste sont créés sur **notre** panneau et non sur le cadre du client, sinon ils disparaîtraient avec le reste. |
| **Le faux client ne connaissait pas les cadres fils** | Il rendait `GetRegions` mais pas `GetChildren` : impossible d'écrire cet essai. Chaque cadre tient désormais la liste de ses fils, que `SetParent` met à jour. |
| **Le client reprend deux micro-boutons à chaque véhicule** | `VehicleMenuBar_MoveMicroButtons` réancre `CharacterMicroButton` à `BOTTOMLEFT (552, 2)` et `SocialsMicroButton` sur le `BOTTOMRIGHT` de `QuestLogMicroButton`. Elle est appelée par `MainMenuBar_ToPlayerArt` **et** `MainMenuBar_ToVehicleArt` — donc à chaque entrée ou sortie de véhicule, et le micro-menu se disloquait. `/fui micro` a montré ces deux boutons-là, et eux seuls, ancrés ailleurs que sur notre bandeau. On repose après elle. |
| **`MainMenuBar` aussi avalait les clics** | Déclarée `enableMouse="true"` et couvrant tout le bas de l'écran. Son art est remplacé par le nôtre, mais elle restait une dalle — `GetMouseFocus` la rendait à la place du bouton survolé. Même remède que pour la barre bonus. **La leçon se généralise : tout contenant du client qu'on vide garde sa souris, et il faut la lui retirer.** |
| **La barre bonus avalait les clics du micro-menu** | `BonusActionBarFrame` est déclarée 505 × 43, strate **HIGH**, `toplevel`, avec `enableMouse="true"`. Effacer son art la rend invisible mais **pas inoffensive** : elle reste une dalle au-dessus du bas de l'écran et avale les clics de tout ce qu'on y a posé — le bouton du personnage ne répondait plus. `/fui micro` l'a nommée : les dix boutons sont exactement à leur place, un seul ancrage chacun, et `GetMouseFocus` rend `BonusActionBarFrame`. C'est le même piège que `CharacterModelFrame` sur les emplacements d'équipement, et le même remède : un cadre qui ne sert que de contenant n'a pas à recevoir de clic ; ses douze boutons gardent le leur, étant des cadres fils. |
| **La table des chaînes de rang donne le décalage** | `UnitPVPRank` rend un **indice**, pas un numéro, et je n'avais aucun usage de référence pour en déduire le décalage — WotLK ne s'en sert plus. L'ordre des quarante chaînes le tranche : `PVP_RANK_1..4` sont les rangs **négatifs** (Pariah, Outlaw, Exiled, Dishonored), `PVP_RANK_5` est Scout / Private, c'est-à-dire le rang **1**, et `PVP_RANK_10` est Stone Guard / Knight, le rang 6. L'indice est donc la clé telle quelle, et le numéro affichable vaut l'indice moins quatre. |
| **Le rang ne vient pas du compteur de rang : il vient des titres** | `UnitPVPRank` rendait 0 avec 67 victoires honorables au compteur — relevé par `/fui pvp`. La raison est dans le serveur : `mod-pvp-titles/src/mod_pvp_titles.cpp`, lu en entier, compare les victoires honorables de toute une vie à quatorze seuils et pose un **titre** (`SetTitle` sur `CharTitles`) ; il ne touche jamais au vieux compteur de rang de l'époque classique. Le rang se demande donc à `IsTitleKnown` — présent dans `Wow.exe`, vérifié — sur les identifiants de `CharTitles.dbc` : **1 à 14** pour l'Alliance (Private … Grand Marshal), **15 à 28** pour la Horde (Scout … High Warlord), relevé dans le fichier du serveur. Le rang est le **plus haut** titre connu. `UnitPVPRank` reste essayé d'abord, au cas où un serveur l'alimenterait. |
| **Les seuils de victoires sont recopiés du serveur, et c'est le seul écart que le client ne peut pas vérifier** | `GetPVPRankProgress` ne rend rien, pour la même raison qu'`UnitPVPRank` : sans autre source, la jauge resterait vide à jamais. La progression se calcule donc sur les victoires honorables, que `GetPVPLifetimeStats` donne, comparées aux quatorze seuils de `configs/modules/mod_pvptitles.conf` (clés `PvPTitles.Rank_1` à `Rank_14`). Aucune fonction du client ne les demande : ils sont **recopiés** dans `SEUILS`, relevés le 23/09/2026 sur la production — 50, 100, 250, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 5000, 6500. Si le serveur change ses seuils, cette table est le seul endroit à reprendre. |
| **`FACTION_AT_WAR_COLOR` n'existe pas en 3.3.5, et la valeur exacte se lit dans une base de données** | `RefreshBackgroundHighlightColor` teinte le voile d'une ligne avec `FACTION_AT_WAR_COLOR` quand la faction est en guerre, sinon `WHITE_FONT_COLOR`. La première est absente du FrameXML de 3.3.5 — vérifié dans `Constants.lua`, `GlobalStrings.lua` et `ReputationFrame.lua` — et la teinte retombait donc sur le **blanc** : une faction en guerre se voyait recouverte d'un voile clair. Ces couleurs ne sont plus écrites en Lua dans le client moderne : elles sont générées depuis **`GlobalColor.db2`**, où chaque ligne porte un nom et une couleur ARGB. Relevée dans ce fichier : `FACTION_AT_WAR_COLOR = 0xFF690300`, soit **105, 3, 0**. Le décodage est vérifié sur deux témoins de la même table, `WHITE_FONT_COLOR` à `0xFFFFFFFF` et `RED_FONT_COLOR` à `0xFFFF2020`. |
| **Le harnais inventait cette couleur, et couvrait donc la faute** | Le faux client définissait `FACTION_AT_WAR_COLOR = {0,8 ; 0,2 ; 0,2}` — une couleur qui n'est celle de personne. Le voile était donc rouge au banc et blanc en jeu. La constante est retirée du faux. Même leçon que `IsTitleKnown` : **un faux plus aimable que le client ne prouve rien**. |
| **Une fonction de 3.3.5 peut rendre 0 là où on attend `false`, et zéro est vrai en Lua** | `IsTitleKnown` rend un **nombre**, 0 ou 1. Écrit `if IsTitleKnown(id) then`, le test est vrai pour tous les titres : la boucle partait du rang 14 et s'arrêtait au premier tour — en jeu, « Grand Marshal », le rang 14 et la jauge pleine avec 67 victoires. Le client l'écrit lui-même, `Interface/FrameXML/PaperDollFrame.lua` ligne 2605 : `if ( IsTitleKnown(i) ~= 0 )`. Le faux du harnais rendait un booléen et laissait donc passer la faute ; **il rend maintenant un nombre, comme le client**. Leçon générale : un faux qui simplifie le type d'une fonction du client ne prouve rien. |
| **`PVP_RANK_<n>_0` est la Horde, `_1` l'Alliance** | Vérifié dans le `GlobalStrings.lua` du client, lu par la chaîne d'archives : `PVP_RANK_5_0 = "Scout"`, `PVP_RANK_5_1 = "Private"`, `PVP_RANK_18_0 = "High Warlord"`, `PVP_RANK_18_1 = "Grand Marshal"`. La convention de camelot — `faction01 = (Alliance) et 1 ou 0` — est donc la bonne, et non l'inverse. |
| **Ce qui fait bouger le rang** | `KNOWN_TITLES_UPDATE` annonce le titre tombé, donc le rang gagné ; `PLAYER_PVP_KILLS_CHANGED` fait avancer la jauge à chaque victoire. Avec `PLAYER_PVP_RANK_CHANGED` et `HONOR_CURRENCY_UPDATE`, les quatre existent dans ce client, vérifié dans `Wow.exe`. |
| **Un chiffre nu se lit comme un rang** | La saison d'arène s'écrivait sans intitulé, juste au-dessus du rang : le « 1 » de la saison passait pour un rang. camelot écrit `EXPANSION_SEASON_NAME`, absent ici ; `ARENA` est ce que le client porte de plus proche. |
| **Sans rang, pas d'anneau** | Un cercle doré vide se lit comme un défaut. Le cadran garde sa lueur, son fond de faction et l'emblème ; l'anneau de récompense et son numéro disparaissent. |
| **Le titre en haut, le numéro dans l'anneau** | **À la demande, et non d'après la source** : camelot écrit les deux en haut — `PVP_RANK_NUMBER_AND_TITLE` donne « Rang N : Nom » dans le `CurrentRankField` — puis répète le numéro dans l'anneau de récompense, par `LevelLabel`. Ici le titre reste seul en haut, et le numéro n'est qu'à un endroit : dans le cercle doré. |
| **L'onglet PvP : l'écran de camelot, des données que WotLK a cessé d'employer** | `PVPRankFrame.xml` et `pvprankframe.lua` lus en entier. camelot tire tout de `C_MajorFactions` — le renom — qui n'existe pas ici ; mais les trois fonctions de l'époque des rangs sont **toujours dans le binaire**, vérifié dans `Wow.exe` : `UnitPVPRank`, `GetPVPRankInfo` et `GetPVPRankProgress`. WotLK a simplement cessé de s'en servir dans son FrameXML. Heureuse coïncidence : la planche c60 de camelot porte **quatorze** icônes de rang — exactement les quatorze rangs classiques. Son art *est* celui de l'époque. |
| **Une planche que le listfile ne nomme pas** | Tout l'art de cet écran vit sur une seule feuille sans nom, `fileDataID 8198433`. `ajouter_feuilles.py` accepte donc une ligne `fdid:<n>.blp => interface/...` : la feuille s'exporte par son identifiant, se range sous le nom choisi, et ses entrées d'atlas se retrouvent dans l'index par ce même identifiant. |
| **La jauge circulaire, refaite par quadrants** | camelot la fait avec un `Cooldown` dont il remplace la texture de balayage — `SetSwipeTexture`, **absent** du binaire de 3.3.5, vérifié, et la texture de balayage de son `Cooldown` est câblée dans le moteur : la remplacer changerait **tous** les temps de recharge du jeu. Le balayage est donc refait à la main. Le cadran est coupé en quatre quarts ; un quart que la jauge a dépassé montre le quart de l'anneau tel quel, et le quart où la jauge s'arrête montre un **demi** anneau qu'on fait tourner par `SetTexCoord` à huit arguments. Un demi anneau tourné de φ couvre les 180° qui *finissent* à φ ; le rectangle du quadrant le coupe, et il ne reste que l'arc voulu. Aucun masque, aucun `ScrollFrame` : quatre textures. |
| **Une texture qu'on fait tourner doit être centrée et bordée de vide** | `SetTexCoord` à huit arguments ne déplace pas les quatre coins du rectangle à l'écran : il dit seulement quel point de l'image chacun montre. Faire tourner l'image revient donc à faire tourner la **lecture** autour du centre de l'image — d'où deux exigences que la source ne remplit pas d'elle-même. Le centre du cercle doit être le centre du canevas, sinon l'anneau décrit une boucle en tournant : relevé sur `pvpqueue-sidebar-honorbar-fill`, son centre de gravité est à (64,0 ; 63,5) pour 128 de côté, un demi-texel trop haut, recalé à la cuisson. Et le bord doit être vide, car une fois tournée la texture est lue **hors de [0, 1]** dans les coins du quadrilatère, où le client recopie le texel du bord. |
| **La couleur s'interpole pondérée par l'alpha** | Les texels vides de cette image sont **blancs** — relevé : (255, 255, 255, 0). Agrandie en interpolant la couleur sans tenir compte de l'alpha, l'anneau se bordait d'un liséré clair. La cuisson interpole donc la couleur multipliée par l'alpha, puis la redivise. |
| **La progression s'écrit en chiffres, pas en pourcentage** | **À la demande**, et c'est aussi ce que fait camelot : `CurrentRankProgressField` écrit `string.format(PVP_RANK_CURRENT_PROGRESS, rankPoints, nextRankPointsThreshold)`. Cette chaîne n'existe pas en 3.3.5 — ce client n'a plus le système de rangs — d'où le `"%d / %d"` nu. Les deux nombres sont les **victoires honorables de toute une vie** et le **seuil du palier suivant** : ce sont eux que `mod-pvp-titles` compare, et eux qui font avancer la jauge. Au rang maximal il n'y a plus de seuil : le compte reste seul. |
| **Le sens de la jauge est une déduction, pas une observation** | `rotation="180"` sur le `Cooldown` : la jauge part du **bas**, six heures. Le sens est celui du `Cooldown`, celui des aiguilles — depuis le bas, elle monte donc par la **gauche**. C'est ce que l'attribut dit, non ce que j'ai vu : `JAUGE_SENS` existe pour le retourner d'un seul caractère si le jeu dit le contraire. |
| Ce qui manque encore à l'écran PvP | `GameFontNormalMed2` n'existe pas ; `GameFontNormalLarge` le remplace. Le compte à rebours de fin de saison demande `C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd`, absent : la ligne reste, vide. |
| **Le volet droit porte ce que WotLK sait vraiment donner** | `GetPVPLifetimeStats`, `GetPVPSessionStats`, `GetPVPYesterdayStats` et `GetHonorCurrency` : points d'honneur, victoires honorables, meilleur rang, aujourd'hui, hier. **Si le serveur n'alimente pas les rangs, `/fui pvp` le dira** — il rapporte ce que les trois fonctions rendent réellement. |
| **L'onglet des compétences : le même écran, en bleu** | `SkillsFrame.xml` et `skillsframe.lua` lus en entier. Tout est commun avec la réputation — liste `(10, −40)` / `(−25, 15)`, deux traits, retraits 0 / 2 / 46, marges 10, écart 3, survol à 0 / 0,10 / 0,20 — sauf quatre choses : l'en-tête fait **26** et non 28 ; le nom d'une entrée est à `x = 2` et non 15, faute d'`AccountWideIcon` ; la description du volet droit est décalée de **−8** sous la jauge et non −6 ; et **la barre est bleue par son sprite**, `SetFillTextureByColorType(Blue)` suivi d'`UpdateBarColor(WHITE_FONT_COLOR)` — donc aucune teinte. Le remplissage bleu est cuit au masque comme le blanc. |
| **Le texte de la barre est toujours la progression** | `InitializeBarForStandardSkill` appelle `TryShowBarProgressText` dès l'initialisation, pas seulement au survol : « rang / maximum », ou « rang (+bonus) / maximum » avec le bonus en vert. |
| **À l'ouverture, la première compétence est choisie** | `SelectFirstSkillIfNoneSelected` — *« opening the tab with an empty detail pane reads as broken »*, dit le commentaire de la source. Les en-têtes sont sautés. |
| **Trois écarts sur cet onglet** | 3.3.5 n'a **pas de sous-en-tête** : `GetSkillLineInfo` ne rend aucun indicateur d'enfant, sa hiérarchie n'a qu'un niveau — le gabarit existe dans le relevé mais ne sert pas. Les **lignes d'armes** ne sont pas détaillées : camelot y calcule les chances de toucher, de critique et de coup glançant face à un boss, avec des chaînes `WEAPON_SKILL_DETAIL_*` que ce client n'a pas. Et la description ne défile pas. |
| **Le volet droit de la réputation : le détail de la faction** | `CharacterFrameSidePaneTemplate` donne la surface — `TOPLEFT (16, −14)` et `BOTTOMRIGHT (−12, 14)` sur l'hôte droit — puis le titre en `GameFontNormalMed3` large de 195 et centré, le sous-titre en `GameFontHighlight`, un `UI-Character-Info-ScrollLine`, et la description dessous. `ReputationDetailFrame` y ajoute une `StandingBar` de 180 × 29 et trois cases de 26 empilées depuis le pied, la première à `x = −4`, les suivantes à `(0, −2)` — fond `checkbox-minimal`, coche `UI-CheckBox-SwordCheck` en 32 posée à `(3, −5)`, intitulé large de 158 à `+2`, celui d'« At War » en rouge. |
| **C'est le client qui remplit, nous ne faisons que reposer** | `ReputationFrame_Update` écrit le nom, la description et l'état des trois cases pour la faction que `SetSelectedFaction` désigne — **et seulement si son cadre de détail est visible**. Cliquer une ligne le lui dit donc, puis relit ce qu'il a posé. Les trois cases restent les siennes : elles portent la déclaration de guerre, le rangement parmi les inactives et le suivi sur la barre du bas. |
| **Deux écarts de police et de défilement** | `GameFontNormalMed3` n'existe pas en 3.3.5 ; `GameFontNormalLarge` est le plus proche. Et la description de camelot défile (`ScrollingFontTemplate`) : la nôtre est simplement bornée au volet. |
| **`GetNumFactions` et `GetFactionInfo` ne s'arrêtent pas au même endroit** | Relevé en jeu par `/fui reput` : le client annonce **neuf** factions et répond encore à la **dixième** — l'en-tête « Inactive », hors du compte. Sa propre boucle le sait et teste `factionIndex <= numFactions` ; la nôtre lisait tant que `GetFactionInfo` répondait, et posait une ligne de plus. C'est ce qui rendait le repli incompréhensible : la liste raccourcit, mais nous continuions à lire au-delà du compte, là où le client rend des entrées d'un autre bloc — un sous-en-tête paraissait alors hors de sa catégorie, et vide. Le faux client reproduit désormais ce piège, sinon l'essai ne prouverait rien. |
| **Replier raccourcit la liste, il ne masque pas** | `CollapseFactionHeader` retire les enfants de la numérotation du client : `GetNumFactions` diminue et tout ce qui suit remonte d'un cran. C'est ainsi que 3.3.5 et camelot fonctionnent tous les deux, et c'est voulu. **Ce qui ne l'était pas** : le défilement était borné *après* la pose, donc replier en bas de liste laissait un passage entier posé depuis un décalage devenu trop grand — des lignes vides ou les mauvaises factions, jusqu'au passage suivant. On borne maintenant, et on repose si cela a bougé. |
| **La sélection se retient par le nom, pas par l'indice** | Un indice ne survit pas à un repli : les factions se renumérotent et la marque changerait de ligne. Le nom, lui, ne bouge pas. 3.3.5 n'ayant pas de `factionID` dans `GetFactionInfo`, c'est la seule clé stable. |
| **Le faux client repliait sans renuméroter** | Il se contentait d'un drapeau, donc l'essai ne prouvait rien. Il retire désormais les enfants d'un en-tête replié de sa numérotation, comme le vrai, et le banc vérifie les deux sens ainsi que la marque après un aller-retour. |
| **La hiérarchie : trois gabarits, trois retraits** | `SetElementFactory` choisit selon deux drapeaux — ni en-tête → `ReputationEntryTemplate`, 30 ; en-tête et pas un enfant → `ReputationHeaderTemplate`, 28 ; en-tête **et** enfant → `ReputationSubHeaderTemplate`, 22. `SetElementIndentCalculator` donne le retrait : 0 pour un en-tête de premier niveau, **46** pour un enfant qui n'est pas un en-tête, 2 pour tout le reste. `SetPadding` ajoute 10 de marge sur les quatre bords et **3** entre deux lignes. 3.3.5 rend les trois drapeaux qu'il faut : `isHeader` en neuvième position, `hasRep` en onzième, `isChild` en treizième. Les hauteurs variant, la liste ne se divise plus : elle s'empile jusqu'à la marge du bas. |
| **Le nom d'une entrée est à 15, pas à 25** | `ReputationEntryMixin:Initialize` le décale de −10 quand l'`AccountWideIcon` est masquée — ce qu'elle est toujours ici, 3.3.5 n'ayant pas de réputation de compte. Un sous-en-tête, lui, ancre son nom à +4 de son bouton, que `ReputationSubHeaderMixin:Initialize` pose à `LEFT` du bord droit de cette même icône plus 3, soit x = 28. Et il ne montre sa barre que s'il porte de la réputation. |
| **Le client remontre ses propres lignes à chaque passage** | `ReputationFrame_Update` finit par `factionRow:Show()` sur chacune des quinze. Les masquer une fois, à la construction, ne suffisait pas : elles revenaient avec tout leur art d'époque, et certaines réputations semblaient échapper au thème. On repasse après lui. |
| **Le bouton d'un sous-en-tête n'a pas son art** | La source lui donne `campaign_headericon_closed` et `_open`, qui vivent dans `interface/questframe/questmaplogatlas.blp` — une grande feuille pour deux images de 22. Le `+` et le `−` de l'en-tête sont repris en attendant, ce qui garde la colonne cohérente. |
| **Une texture cuite doit faire une puissance de deux** | Le remplissage cuit sortait en 320 × 30 : en jeu, la barre devenait un bloc uni que la teinte de la faction coloriait — d'où des jauges entièrement vertes. Tout l'art d'interface du client d'origine est en puissance de deux (256 × 256, 256 × 64, 16 × 16) ; il ne sait visiblement pas échantillonner autre chose. La cuisson sort désormais en 512 × 32 — largement le double de la taille affichée, 160 × 15, et la lecture reste en 0..1. **`cuire_masque.py` refuse maintenant d'écrire une autre taille** : le défaut est muet à l'écriture et ne se voit qu'en jeu. |
| **Le témoin a servi à écarter, pas seulement à trouver** | `/fui reput` a montré que les fractions étaient proportionnelles (5, 2,4, 12, 29 px sur 160), que la teinte suivait `FACTION_BAR_COLORS` — vert pour les attitudes 5 à 8, jaune pour la 4 — et que les en-têtes n'avaient pas de barre. La logique était juste ; restait le support. Le fond nœuf-tranches a été rendu hors du jeu pour l'écarter à son tour. |
| **Le remplissage de jauge est cuit au masque, et découpé comme son fond** | camelot le découpe par `common-stat-bar-Mask`, une `MaskTexture` ancrée `LEFT` et `RIGHT` sur la barre — donc tendue sur toute sa largeur — à sa hauteur d'atlas, 29. Sans elle, le remplissage avait des bouts carrés qui ne suivaient pas le contour du fond. `tools/cuire_masque.py` multiplie donc l'alpha du masque dans le sien, une fois pour toutes. **Et il le découpe comme notre fond** : celui de camelot s'étire avec la barre, le nôtre garde ses bouts à 10 px et n'étire que le milieu — un masque tendu ne coïnciderait plus. Le résultat est un fichier à lui seul, calculé pour une barre de 160, qu'on rogne à la fraction voulue comme le fait `SetFillPercent`. |
| **Le fond de jauge se découpe, le remplissage non** | `common-stat-bar-bg` mesure 68 × 30 et la barre en fait 160 : étiré, ses bouts arrondis s'allongeaient. La mesure se prend sur l'art — la première colonne dont le profil vertical rejoint celui du milieu, c'est-à-dire où le bord est fini : elle tombe à **10**. La hauteur ne changeant pas, seules les tranches horizontales du milieu s'étirent. Le **remplissage**, lui, reste une seule texture : c'est une jauge, que `SetFillPercent` rogne à la fraction voulue ; la découper en ferait un cadre. La compression horizontale de sa feuille — 240 pour une barre de 160 — est celle de la source. |
| **La plaque d'en-tête se découpe, elle ne s'étire pas** | `ReputationHeaderTemplate` la pose sans ancrage, ce qui l'étire sur toute la ligne : à 64 × 29 pour une ligne de plus de trois cents, ses coins arrondis s'étalaient en ellipses. Mesure sur l'art — l'alpha de la colonne de gauche — l'arrondi court sur une dizaine de pixels ; un coin de **12** le couvre et reste sous la moitié de la hauteur, au-delà de quoi les tranches se chevaucheraient. Elle passe donc par `CreateNineSlice`. |
| **Les lignes de réputation sont les nôtres, plus celles du client** | Trois tentatives pour reposer et rhabiller les quinze `ReputationBar<i>` de 3.3.5, trois échecs de la même nature : `ReputationFrame_Update` ne remplit pas, il **repose son art** à chaque passage — `SetNormalTexture` sur les boutons, les `AtWarHighlight` additifs, les traits d'arborescence, la texture de la `StatusBar` — et le clic en déclenche un. Chaque correction tenait jusqu'au passage suivant. Les lignes sont donc bâties d'après les gabarits de camelot et remplies depuis `GetFactionInfo`, la seule chose que 3.3.5 apporte ici. Le `ReputationFrame` du client ne sert plus que de support. **C'est la leçon de l'onglet : quand un écran du client se repose lui-même, on ne le rhabille pas, on le remplace.** |
| **L'art du client revient à chaque mise à jour** | `ReputationFrame_Update` ne pose pas que des valeurs : il rappelle `SetNormalTexture(chemin)` sur les boutons et remontre l'art de 3.3.5 — texture de la `StatusBar`, les deux `AtWarHighlight` additifs, les traits d'arborescence. L'étouffer une seule fois, à la construction, ne suffit pas : l'image reprend sa taille déclarée — 16 × 16 ancrée à `LEFT +3`, pensée pour une ligne de 20 — et se superpose à la nôtre. C'est ce qui déformait les `+` et les `−` et faisait sortir les barres de leur cadre. On repasse désormais après lui, à chaque fois. |
| **Lire le gabarit en entier, pas par fragments** | Les trois erreurs de cet onglet — la plaque prise pour une flèche, la taille d'atlas oubliée, l'art du client étouffé une seule fois — viennent de la même méthode : lire un bout de XML et le plaquer sur les cadres de 3.3.5. `ReputationEntryTemplate` lu en entier donne tout : barre à `RIGHT x = −3`, nom en `GameFontHighlight` de hauteur 15 du `x = 25` — le `RIGHT` de l'`AccountWideIcon` — jusqu'au `LEFT` de la barre moins 10, intitulé d'attitude centré sur la barre par un `LEFT`+`RIGHT`. |
| **Le troisième argument de `SetAtlas` veut dire « ne touche pas à la taille »** | Il ne vaut donc que si on la pose soi-même juste après — un `SetAllPoints`, un `SetWidth`, un second ancrage. Posé sur une texture sans dimension ni second point, il la laisse s'étaler sur tout son parent : les deux traits de liste couvraient le volet entier d'une immense bande dorée. Les appels du reste de l'addon sont tous suivis d'un dimensionnement — c'était bien l'usage, mal repris. |
| **`common-button-list-collapseExpand` n'est pas une flèche** | C'est le **fond d'une ligne d'en-tête** : une plaque arrondie de 64 × 28 que `ReputationHeaderTemplate` pose sans ancrage, donc étirée sur toute la ligne. Posée à sa taille d'atlas sur un bouton de 20, elle se répétait sur chaque ligne et recouvrait les noms de réputation. La vraie flèche est le `StateIcon` du même gabarit, que `ReputationHeaderMixin` remplit avec `common-button-list-plus` ou `-minus`, ancré `RIGHT` en (−8, −1) — à **droite** de la ligne, pas à gauche. **Leçon : un nom d'atlas ne dit pas ce que l'art contient ; il faut le regarder.** Le recadrage d'un sprite depuis sa feuille prend dix lignes et évite ce genre d'erreur. |
| **Un en-tête n'a ni barre ni entrée** | camelot lui donne sa plaque, son nom à `LEFT` x = 10 et sa flèche ; la barre de réputation appartient aux entrées. `GetFactionInfo` rend `isHeader` en neuvième position, et c'est lui qui décide. |
| **Le nombre de lignes affichées est une constante du client** | `NUM_FACTIONS_DISPLAYED` vaut 15, calé sur l'ancienne fenêtre. Au pas de camelot — 30 au lieu de 23 — le volet en porte moins : on le recalcule, et on pose `REPUTATIONFRAME_FACTIONHEIGHT` au même pas, la pagination du client se servant des deux. |
| **Un contenu peut se bâtir avant que la fenêtre soit posée** | `GetHeight` rend alors zéro, et le nombre de lignes devient n'importe quoi. La hauteur du volet est donc prise **par construction** — 484 moins les 20 du bandeau — la mesure ne servant que lorsqu'elle est crédible. |
| **La barre de défilement de la réputation reste celle de 3.3.5** | camelot utilise un `MinimalScrollBar` ; le nôtre n'est pour l'instant habillé que dans la fenêtre de choix d'icône, sans fonction partagée. À extraire. |
| **L'onglet du personnage porte l'icône de sa classe** | **À la demande, et non d'après la source** : camelot y met le portrait du joueur — `CHARACTER_MODE_TAB_ICONS` laisse la première entrée à `nil` et `UpdateCharacterModeTabPortrait` appelle `SetPortraitTexture`. Une icône de classe demande un fichier par classe : les dix de 3.3.5 sont versées depuis `Interface/ICONS/ClassIcon_<classe>` et cuites au masque comme les autres. Le jeton vient du second retour de `UnitClass`, en capitales, et nomme le fichier — la casse est sans importance, une archive adresse ses fichiers par un condensé insensible à la casse. Le bouton **Character Info** du volet droit, lui, garde le portrait : il n'était pas concerné. |
| **Le survol et le marqueur d'actif débordaient sur le métal** | Un onglet est plus large que ce qu'on en voit : son art porte une langue à gauche, qui vient se glisser sous la fenêtre. Le fond de l'onglet y est sombre et passait inaperçu, mais le survol et le marqueur d'actif sont des **contours** qui tracent toute la forme, langue comprise — ils s'affichaient donc par-dessus l'encadrement du volet droit. Aucun niveau n'était fixé sur ces cadres, rien ne garantissait l'ordre. La barre prend maintenant le niveau du cadre et les onglets un cran au-dessus : assez pour couvrir le fond du panneau, pas assez pour atteindre l'habillage, qui vit à `NIVEAU_ART`. |
| **Deux constantes portaient le même nom, et la seconde masquait la première** | `ONGLET_ICONE` valait 28 pour les deux onglets du volet droit — Character Info et Equipment Manager. En portant l'icône des onglets **latéraux** à 50, une seconde déclaration du même nom a été posée plus bas : en Lua elle masque la première pour tout ce qui suit, et `creerOngletVolet` vient après. Les deux boutons du volet se sont donc agrandis sans qu'on l'ait demandé. Les noms sont désormais distincts — `ONGLET_VOLET_ICONE` et `ONGLET_LATERAL_ICONE` — et le banc vérifie les deux tailles séparément. |
| **Le masque est binaire : cuit tel quel, il donnait un escalier** | Relevé sur l'art : sa ligne du milieu passe de 0 à 255 d'un texel à l'autre, sans le moindre dégradé. Le client l'applique à la **résolution de l'écran**, où cette marche est fine ; cuite à 64 px elle devenait un escalier que l'agrandissement de l'interface étalait sur deux ou trois pixels réels — d'où des icônes « très pixelisées » alors que leur contenu n'avait pas bougé. Le masque est donc **interpolé**, pas lu au texel le plus proche, et pris dans sa version 2×. La cuisson sort à 128 × 128, pour que le contour ait de quoi s'adoucir. |
| **Sur-échantillonner sans interpoler ne servait à rien** | Première tentative : seize échantillons par texel. Ils tombaient tous dans le **même** texel du masque — à l'échelle où l'on cuit, la fenêtre d'échantillonnage est plus fine qu'un texel de masque. C'est le masque qui porte la marche, c'est donc lui qu'il faut interpoler. |
| **Le contenu de l'icône, lui, ne peut pas s'améliorer** | 64 × 64 est tout ce que le client possède : les quatorze fichiers voisins de ces identifiants sont tous de cette taille, et camelot affiche exactement les mêmes. La cuisson à 128 lisse la découpe, elle n'invente aucun détail. |
| **Le rognage reste indispensable après la cuisson** | Elle a été calculée en supposant l'icône affichée à 50 × 50 avec `SetTexCoord(0.03125, 0.96875, …)`. L'enlever décalerait l'image sous son propre masque. |
| **Le portrait du personnage garde ses angles vifs** | Son icône n'est pas un fichier : `SetPortraitTexture` la repose à chaque changement d'apparence. Il n'y a rien à cuire. |
| **Un écrivain PNG dans l'atelier** | Chaque `.blp` a un `.png` à côté pour qu'on voie ce qu'il contient. Ceux qui viennent du client sortent de wow.export ; une image que **nous** fabriquons n'a personne pour la produire, d'où les quelques lignes de `zlib` dans `cuire_masque.py`. |
| **Le sélecteur de catégorie revient à l'encadré de camelot** | **À la demande.** Il a porté un temps l'art de bouton `commonbuttontertiaryc60`, avec son état pressé ; il reprend `UI-Character-Info-Title`, l'encadré de cuir à clous de `paperdollinfopart1c60` — celui que `CharacterStatFrameCategoryTemplate` lui donne, tendu du TOPLEFT au BOTTOMRIGHT. **L'état pressé s'en va avec le bouton** : l'encadré de camelot n'en a pas. La mécanique qui le tenait (`majEtatSelecteurs`, greffée sur le `OnShow`/`OnHide` de `DropDownList1`) reste en place et ne trouve plus rien à presser. La hauteur reste à 34 : l'atlas fait 201 × 32, il s'y étire de deux pixels au lieu de huit à 40. |
| **Un fond alterné pour les lignes de statistiques** | **À la demande** : ni camelot ni 3.3.5 ne rayent les leurs. Les deux bandes viennent de `paperdollinfopart1c60` — relevé sur la planche, ce sont les deux seules bandes horizontales dont l'alpha s'éteint aux deux bouts : `UI-Character-Info-ItemLevel-Bounce` (204 × 21, **sombre**, (27, 21, 16) à 255) et `UI-Character-Info-Line-Bounce` (213 × 18, **claire**, (87, 67, 46) à 102). La planche en porte une troisième, `Line-Bounce2`, qui est la même bande claire en 213 × 23 ; camelot n'emploie aucune des deux. La sombre vient en premier, et **le compte repart à chaque catégorie**, un en-tête les séparant. |
| **3.3.5 n'a pas de sous-calque : c'est le texte qui monte, pas la bande qui descend** | `StatFrameTemplate` met son `$parentLabel` au calque **BACKGROUND** (`PaperDollFrame.xml`, ligne 175). Une texture ajoutée au même calque est créée après lui et passe donc **devant** le texte, et `SetDrawLayer` ne prend pas de sous-calque ici — `textureSubLevel` et `subLevel` sont absents du binaire, vérifié. L'intitulé passe donc à `ARTWORK`. |
| **Les statistiques revenaient d'elles-mêmes par-dessus une autre page** | `UpdatePaperdollStats` fait `statFrame:Show()` pour chaque ligne qu'elle remplit — **vingt-trois fois** dans le `PaperDollFrame.lua` du client — sans jamais demander si l'écran est ouvert. Un gain de niveau, un changement d'équipement, et les lignes reparaissaient superposées à la page des ensembles ou à celle des titres. Ce n'est pas à cette fonction de les recacher une par une : **montrer et masquer appartient à `ForeverUI.Panes`, et à lui seul**. Le greffon lui demande donc de repasser, et chaque hôte retrouve la page qui doit y être. |
| **Le faux `UpdatePaperdollStats` ne faisait rien** | Il était vide : tout ce chemin — le client qui remontre ses lignes de lui-même — n'était jamais essayé. Il montre désormais ses six lignes comme le vrai, et trois essais couvrent le cas : sur la page des titres, sur celle des ensembles, et sur la leur, où elles doivent bien revenir. Vérifié en retirant le correctif : l'essai tombe. |
| **L'alternance ne compte que les lignes visibles** | Le client montre et cache ses lignes selon la catégorie choisie : une alternance calculée sur les six laisserait des trous. Elle se recompte à chaque passage de mise en page et sur le greffon d'`UpdatePaperdollStats`, qui est justement ce que le client appelle après avoir remontré et recaché ses lignes. |
| **L'onglet du familier : apercu à gauche, statistiques à droite** | **À la demande, et non d'après la source.** camelot ne fait pas du familier un onglet de la colonne : son `PAPERDOLL_SIDEBARS` le met en **troisième onglet du volet droit**, à côté des statistiques et du gestionnaire, et son volet gauche garde la silhouette du joueur. 3.3.5 en fait un écran à part entière, `PetPaperDollFrame`, et c'est celui-là que la colonne ouvre. Le volet gauche reçoit `PetModelFrame` — l'aperçu que le client cale sur `"pet"` — borné au volet ; le volet droit reçoit la même interface que les statistiques du personnage : même marge de 20, même pas de 13, même en-tête `UI-Character-Info-Title` de 34 débordant de 5, même fond alterné dont le compte repart à chaque catégorie. |
| **L'aperçu du familier n'est pas fils de l'écran, il est petit-fils** | `PetModelFrame` (ligne 208 du `PetPaperDollFrame.xml`) vit dans `PetPaperDollFramePetFrame` (ligne 128), `setAllPoints` sur l'écran. Un balayage qui ne regarde que les fils **directs** et n'épargne que le modèle masquait donc son **parent**, et l'aperçu avec lui — aucun rendu en trois dimensions, sans qu'aucune ligne ne l'ait demandé. Les deux niveaux sont balayés, chacun épargnant ce qui porte la suite, et le porteur est remontré : `PetPaperDollFrame_SetTab` le masque dès qu'un autre onglet du client est choisi. **Le faux mettait le modèle directement sous l'écran** et couvrait donc la faute ; il est désormais petit-fils, et l'essai tombe sans le correctif. |
| **`ATTACK_POWER` vaut « Power » dans ce client** | Relevé dans ses `GlobalStrings`. La seule chaîne qui porte exactement « Attack Power » est **`ATTACK_POWER_TOOLTIP`**, celle de l'infobulle : c'est donc elle qu'on prend, `ATTACK_POWER` ne servant plus que de dernier recours. Écrire le texte en dur aurait tenu dans une langue et une seule. |
| **Les flèches de rotation du familier prennent la place de celles du personnage** | **À la demande** : les mêmes mesures que `poserModele` — centrées sur le **haut** du volet, côte à côte, à −12, et un cran au-dessus du modèle pour recevoir le clic. Les deux boutons font 35 × 35 dans les deux écrans (relevé dans les XML du client) : il n'y avait que la place qui différait. Elles sont **filles du modèle** — `PetPaperDollFrame.xml` ligne 230 — et le balayage ne les atteint donc pas. **Le faux leur donnait 16 de large au lieu de 35** ; comme leur écart se calcule sur leur largeur, le banc affichait ±10 là où le jeu montre ±19,5. |
| **Les résistances du familier sont des icônes, à l'horizontal** | **À la demande**, et non en lignes de texte. Ce sont les **cadres du client** — `PetMagicResFrame1` à 5, `MagicResistanceFrameTemplate`, 32 × 29 — qui portent déjà l'icône d'école découpée dans `UI-Character-ResistanceIcons`, la valeur au BOTTOM (0, 3) et l'infobulle que `PetPaperDollFrame_SetResistances` compose. Ils sont donc repris entiers et **reparentés** dans le volet droit, où le balayage ne les atteint plus, puis étalés à pas égaux sur la largeur des lignes. Leur ordre est celui du client : le premier cadre porte l'école **6** (arcane), puis 2, 3, 4, 5 — c'est son `GetID()` qui compte, pas son rang. |
| **Les valeurs du familier se lisent dans les cadres du client, après l'avoir fait calculer** | `PaperDollFrame_SetArmor`, `SetDamage` et `SetAttackPower` écrivent dans `<cadre>StatText` : c'est de là qu'on lit, pour que le **calcul et la mise en forme restent au client** — les dégâts s'écrivent « 45 - 62 », teintés s'il y a lieu. La santé vient de `UnitHealthMax("pet")`, les résistances de `UnitResistance("pet", école)`, **l'école venant du `GetID()` de `PetMagicResFrame<i>`** — ses cinq cadres portent les écoles 2 à 6 puis 1, et c'est cet identifiant qui nomme la ligne, pas le rang. |
| **Le score critique du familier est celui de l'agilité, et rien d'autre** | 3.3.5 n'expose pas le critique d'un familier : son écran ne le montre pas, et aucune fonction ne le rend. `GetCritChanceFromAgility("pet")` est ce que le client porte de plus proche — c'est même ce dont il se sert pour l'infobulle de l'agilité du familier. La valeur affichée est donc la **part venant de l'agilité**, pas le total. C'est un manque, signalé. |
| **L'onglet des monnaies** | `camelot/blizzard_tokenui.xml` et `.lua` lus en entier, plus le `Blizzard_TokenUI` du client 3.3.5. La liste reprend le gabarit déjà posé par la réputation et les compétences — mêmes bornes de `ScrollBox` (10, −40) à (−25, 15), même plaque d'en-tête `common-button-list-collapseExpand`, même survol en trois tranches. `TokenHeaderTemplate` fait 26, `TokenEntryTemplate` 22. Les données viennent de `GetCurrencyListSize` et `GetCurrencyListInfo`, présents dans le binaire et utilisés par le client lui-même : **neuf valeurs**, dont `isHeader`, `isUnused`, `isWatched`, `count`, `extraCurrencyType` et `icon`. |
| **Deux monnaies ont une icône écrite en dur dans le client** | Relevé dans `TokenFrame_Update` : `extraCurrencyType` 1, les points d'arène — `Interface/PVPFrame/PVP-ArenaPoints-Icon` ; 2, les points d'honneur — `Interface/TargetingFrame/UI-PVP-<faction>`, rognée à 0,03125 … 0,59375. Les autres prennent l'icône que la fonction rend. Une monnaie à zéro s'écrit en `GameFontDisable`, comme le client le fait. |
| **Ce que 3.3.5 ne donne pas pour les monnaies** | **Pas de sous-en-tête** : camelot a un `TokenSubHeaderTemplate`, mais `GetCurrencyListInfo` ne rend qu'un `isHeader`, sans notion d'enfant — la liste n'a que deux niveaux. **Pas de description** : camelot la tire de `GetCurrencyDescriptionText`, absent ici, et rien dans les neuf valeurs n'en porte. Le volet droit montre le nom, l'icône et la quantité ; la place de la description reste vide. **Pas de plafond ni de quota hebdomadaire**, pour la même raison. |
| **Un balayage qui ne prend que les textures n'est pas un balayage** | `TokenFramePopup` porte un **FontString**, `$parentTitle` — `TOKEN_OPTIONS`, « Currency Options » — ancré au TOPLEFT du popup (25, −17). Le balayage du volet droit ne mettait à zéro que les objets de type `Texture` : cet intitulé restait donc à l'écran, à une place qui n'a plus de sens une fois le cadre étalé sur le volet. Les deux natures de région sont désormais balayées — textures à zéro, `FontString` masqués — et les nôtres, créées après, ne sont pas concernées. |
| **Le faux `GetRegions` oubliait les `FontString`** | `CreateFontString` ne les inscrivait pas dans les régions du cadre : un balayage qui les oublie passait donc pour complet au banc. C'est corrigé, et l'essai tombe sans le correctif. Troisième faux pris en défaut sur cette série, après `IsTitleKnown` et `FACTION_AT_WAR_COLOR`. |
| **L'écran des monnaies aussi était un panneau** | `UIPanelWindows["TokenFrame"]` est déclaré à la **première ligne** du `Blizzard_TokenUI` du client. Même défaut que la fenêtre PvP : le système de panneaux lui rendrait ses ancres à l'écran, et la dalle invisible prendrait la souris. Il en sort, et le bornage au volet se refait à chaque passage — cette fois **avant** que le défaut ne se montre. |
| **Les deux cases du client sont réemployées, comme pour la réputation** | `TokenFramePopupInactiveCheckBox` et `TokenFramePopupBackpackCheckBox` gardent leur logique — elles appellent `SetCurrencyUnused` et `SetCurrencyBackpack` sur `TokenFrame.selectedID` — et prennent l'habillage `checkbox-minimal` / `checkmark-minimal`. L'indice du client est donc tenu à jour à chaque sélection. La sélection, elle, suit le **nom** : ranger une monnaie parmi les inutilisées ou replier sa catégorie renumérote toute la liste. Le client suit déjà cette règle — son `TokenFrame.selectedToken` porte un nom. |
| **Le segment des monnaies suivies, sous la bourse du sac** | **Relevé** — `ContainerFrameTokenWatcherMixin:UpdateCurrencyFrames` : le segment prend le **bas** de la fenêtre, `BOTTOMLEFT (8, 8)` et `BOTTOMRIGHT (−8, 8)`, et c'est **la bourse qui monte** — son bas sur le haut du segment, (0, 3). Sans monnaie suivie, la bourse reprend le bas et rien ne change. `CalculateExtraHeight` ajoute alors la hauteur du segment, et la fenêtre grandit d'autant. `BackpackTokenFrameTemplate` fait **17** de haut, encadré par `ContainerFrameCurrencyBorderTemplate` — deux bouts de 8 × 17 et un milieu tendu, le même découpage que la bourse. `BackpackTokenTemplate` : 50 × 12, icône de 12 ancrée `RIGHT (4, 1)`, compte calé à droite jusqu'au bord gauche de l'icône ; les jetons s'enchaînent **vers la gauche** depuis `RIGHT (−17, −1)`. |
| **Les chiffres du segment sont d'un cran au-dessus** | **À la demande** : camelot écrit son compte en `GameFontHighlightSmall` ; ici c'est `GameFontHighlight`. Celui de la **bourse ne bouge pas** — il appartient au cadre d'argent du client, que nous ne touchons pas. Le compte se **centre** en conséquence : camelot l'ancre par son `TOPLEFT`, ce qui convient à une police plus petite que le jeton ; avec celle-ci le texte dépassait vers le bas et ne s'alignait plus sur l'icône. Deux ancres horizontales, `LEFT` et `RIGHT`, le bornent comme avant **et** le centrent en hauteur. |
| **`ManageBackpackTokenFrame` repose la hauteur du sac** | Elle reparente `BackpackTokenFrame` dans le sac **et** lui pose `BACKPACK_HEIGHT + 22`, ce qui défaisait la nôtre. Le segment du client est donc masqué et sa souris coupée, et un greffon sur cette fonction repose notre mise en page derrière elle. Les données, elles, restent celles du client : `GetBackpackCurrencyInfo`, pour `i` de 1 à `MAX_WATCHED_TOKENS`. |
| **Cocher « Show on Backpack » passe par `SetCurrencyBackpack`, et par rien d'autre** | C'est ce qu'appelle la case du volet droit de l'onglet des monnaies. Un greffon sur cette fonction fait suivre le sac dans la foulée, et `CURRENCY_DISPLAY_UPDATE` tient les quantités à jour. |
| **Un troisième onglet au volet droit : les titres** | **À la demande, et non d'après camelot** : son `PAPERDOLL_SIDEBARS` vaut `{STATS, EQUIPMENTMANAGER, PET}` — il n'a pas d'onglet de titres, même si son `paperdollframe.lua` en garde tout le code. L'onglet vient de `mainline/PaperDollFrameConstants.lua`, `PAPERDOLL_SIDEBARTAB_TITLES`, qui en donne l'icône (`PaperDollSidebarTabs`, rognée à 0,015625 / 0,53125 / 0,32421875 / 0,46093750 — le parchemin scellé, vérifié à l'œil sur la découpe). La disposition à trois vient en revanche de camelot, `PaperDollFrame_UpdateSidebarTabLayout` : c'est le **deuxième** onglet qui porte l'ancre, au TOP (0, −5), le troisième collé à sa droite et le premier à sa gauche. Le gestionnaire prend donc le milieu. |
| **Le `TitleManagerPane` de camelot est resté sur une ancre morte** | Il s'ancre au TOPLEFT du volet droit (4, −4), donc **sous** la bande de pierre et les onglets, qui le recouvriraient : l'ancre n'a pas été revue le jour où les titres ont quitté `PAPERDOLL_SIDEBARS`. La page prend celle de l'`EquipmentManagerPane`, la seule vivante de ce volet : du bas de la pierre au bas du volet. |
| **`Char-Stat-Top` est un modèle de texture, pas un fichier** | `PlayerTitleButtonTemplate` ferme la liste par deux bouts arrondis qui en héritent. Ce modèle n'est défini nulle part dans ce que je peux lire — ni dans les XML de camelot, ni dans le FrameXML de 3.3.5, ni dans les `characterframetemplates` de cata — et `char-stat-top.blp` n'existe pas dans le listfile ; seul `Char-Stat-Middle` existe. **La liste n'a donc pas ses deux bouts** : c'est un manque, signalé, pas un choix. |
| **La liste des titres prend le même fond alterné que les statistiques** | **À la demande** : `Char-Stat-Middle` et la rayure claire de camelot (`STRIPE_COLOR`, 0,9 / 0,9 / 1 à 0,1 d'alpha) s'en vont, remplacées par les deux bandes de `paperdollinfopart1c60` — `ItemLevel-Bounce` (sombre) puis `Line-Bounce` (claire), la sombre en premier, comme dans les statistiques. L'alternance suit l'**entrée**, pas la place à l'écran : c'est l'index dans la liste, celui qui tient compte du défilement, et camelot raye de même (`PaperDollTitlesPane_InitButton`, sur `index % 2`). La question des deux bouts de liste (`Char-Stat-Top`) ne se pose donc plus. **`char-stat-middle.blp` n'est plus employée** : elle reste dans l'atelier et dans `patch-Z` jusqu'au prochain redémarrage du client, qui est le seul moment où l'archive peut être réécrite. |
| **La ligne de titre prend toute la largeur du volet** | **À la demande** : camelot donne 169 à son `PlayerTitleButtonTemplate`, sur un volet qui en fait 233. La liste s'aligne désormais sur les lignes de statistiques du même volet — `STAT_MARGE`, 20 de chaque côté — pour que les deux pages aient le même bord. `Char-Stat-Middle` porte 169 px de matière (relevé : x 0 à 170, transparent au-delà), une barre finie avec ses deux bords : étirée à 193, ils passent de 1 à 1,14 px, ce que l'œil ne voit pas. Un découpage en trois tranches pour si peu ne se justifie pas. |
| **La bande de ligne est étirée, pas tuilée** | camelot tuile `Char-Stat-Middle`, 8 px de haut, sur les 22 de la ligne (`vertTile`). `SetVertTile` existe bien dans ce client — vérifié dans `Wow.exe` — mais le marier à un `SetTexCoord` explicite ne l'est pas, et la bande ne varie verticalement que de deux à cinq niveaux de luminance, relevé texel par texel. On l'étire. |
| **`SetHighlightTexture` prend un chemin, jamais un objet** | Le XML de camelot déclare la texture de survol comme un objet du bouton ; en 3.3.5 la méthode attend un **chemin** et un mode de fondu, et le harnais refuse déjà l'autre forme. La texture se récupère ensuite par `GetHighlightTexture` pour l'étendre au bouton. |
| **Le nom de la feuille suit le titre, mais à l'événement, pas au clic** | `SetCurrentTitle` part au serveur ; c'est lui qui répond, et le client annonce la réponse par `UNIT_NAME_UPDATE`. `UnitPVPName` ne rend le nouveau nom qu'à ce moment-là : refaire la bande de titre au clic la remplirait de l'ancien. L'événement part pour **toutes** les unités du décor, et la feuille entière n'est donc pas refaite à chacune — seulement la bande de titre, et seulement pour `"player"`. |
| **Le menu déroulant de titre du client se tait à chaque passage** | `PlayerTitleFrame_UpdateTitles` appelle `PlayerTitleFrame:Show()` (ligne 2624) dès qu'un titre change : le masquer une fois ne suffirait pas. `PlayerTitleFrame` et `PlayerTitlePickerFrame` sont donc masqués à chaque passage, et leur souris coupée. |
| **Deux onglets que 3.3.5 n'a pas : PvP et statistiques** | `CHARACTERFRAME_SUBFRAMES` en compte cinq, camelot six. Les deux manquants sont créés, avec leurs icônes — celle du PvP suit la faction, comme `SetupModeTabs` le fait pour son quatrième onglet. L'ordre de la colonne suit camelot : le PvP entre compétences et monnaie, les statistiques en dernier ; le familier garde la deuxième place que 3.3.5 lui donne. |
| **Un onglet du client CHOISI est un onglet DÉSACTIVÉ** | `PanelTemplates_SelectTab` appelle `tab:Disable()` — on ne reclique pas l'onglet où l'on est — et seul `PanelTemplates_DeselectTab` lui rend la main par `tab:Enable()`. Les deux ne partent que de `ToggleCharacter`, via `PanelTemplates_SetTab`. **Nos écrans ne passent par aucun des deux** : l'onglet du client qui était choisi restait désactivé une fois notre écran ouvert, et ne répondait plus au clic. Venant de la feuille de personnage, c'était son onglet à elle qu'on ne pouvait plus reprendre — et lui seul, ce qui explique que les autres marchaient. `ouvrirEcranPropre` rend donc la main aux cinq boutons. |
| **`IsEnabled` rend un nombre, et le premier témoin a menti** | Écrit `onglet:IsEnabled() and true or false`, le témoin annonçait **tous** les onglets actifs, y compris celui que `PanelTemplates_SelectTab` venait de désactiver : `IsEnabled` rend 0 ou 1, et zéro est vrai en Lua. Troisième fois que ce piège coûte une recherche — après `IsTitleKnown` et `FACTION_AT_WAR_COLOR`. Au banc, `IsEnabled` rend désormais un nombre et un bouton désactivé ne reçoit plus son `OnClick`. |
| **Elle cesse aussi d'être un PANNEAU, et c'est ce qui bloquait les onglets** | `UIPanelWindows["PVPParentFrame"] = { area = "left", … }` — relevé dans l'`UIParent.lua` du client, ligne 52. Tant qu'elle y est inscrite, le système de panneaux lui **rend ses ancres à l'écran** dès qu'il repasse (`UpdateUIPanelPositions`, appelé par l'ouverture de n'importe quel panneau) : elle redevient une dalle de 384 × 512 posée sur `UIParent`. Son art étant éteint, cette dalle **ne se voit pas** — mais elle prend la souris, et les onglets latéraux cessaient de répondre au clic dès qu'on ouvrait le PvP. Même défaut que `BonusActionBarFrame` et `MainMenuBar` sur les micro-boutons : un cadre invisible qui intercepte. On la retire donc de la table. |
| **Le bornage se refait à chaque passage, pas une seule fois** | Ceinture et bretelles : `Panes` ne rappelle pas la construction, et un bornage posé une fois ne survivrait pas à un système qui rendrait ses ancres au cadre. Le parent et les deux ancres sont donc reposés à chaque mise à jour de l'écran. |
| **Le harnais ne jouait pas le clic des onglets du client, ni le système de panneaux** | Les boutons `CharacterFrameTab1..5` n'avaient aucun `OnClick` au banc, et `UpdateUIPanelPositions` n'y replaçait que la feuille. Deux chemins entiers n'étaient donc jamais essayés. Le faux joue maintenant `CharacterFrameTab_OnClick` → `ToggleCharacter` — qui **ferme** la fenêtre quand l'écran demandé est déjà montré, et non `CharacterFrame_ShowSubFrame` — et replace tout ce qui est inscrit dans `UIPanelWindows`. |
| **Témoin `/fui onglets`** | Un onglet latéral qui ne répond plus a trois causes possibles, dont aucune ne se voit à l'écran : un cadre le recouvre et prend la souris ; le bouton a perdu son clic, sa souris ou son activation ; ou le clic passe et c'est son effet qui manque. Le témoin répond aux trois, et dit en plus quels écrans du client sont encore montrés — car si l'un d'eux l'est, `ToggleCharacter` fermera la fenêtre au lieu de changer d'onglet. |
| **La fenêtre PvP cesse d'être une fenêtre** | 3.3.5 en fait un `PVPParentFrame` de 384 × 512, `toplevel`, fils d'`UIParent` ; camelot en fait un onglet. Elle est donc reparentée dans le volet gauche et son `toplevel` retiré — sans quoi elle resterait au-dessus de tout. Reparenter est ici sans danger, à la différence des lignes de statistiques ou des emplacements : ce cadre ne porte aucun de nos réglages de niveau. `TogglePVPFrame` — la touche et le bouton du micro-menu — est greffé pour ouvrir la feuille sur cet onglet, faute de quoi il n'aurait plus d'effet visible. **Sa mise en page reste à faire** : il garde son encadrement de fenêtre et sa largeur d'origine, seulement borné haut et bas au volet, la feuille étant moins haute que lui. |
| **Un écran qui n'est pas au client ne passe pas par `CharacterFrame_ShowSubFrame`** | Cette fonction ne connaît que ses cinq cadres : l'appeler avec un nom qu'elle ignore les masquerait tous et laisserait la feuille sans groupe. Les deux gestes se font donc séparément — masquer les cinq, puis ouvrir le nôtre — et le greffon posé sur elle ne se déclenche pas, puisqu'elle n'est pas appelée. |
| **L'onglet des statistiques est vide, et c'est voulu** | 3.3.5 met les siennes dans `AchievementFrameStats`, une fenêtre à part que `Blizzard_AchievementUI` charge à la demande. Ce qu'il faut y mettre n'est pas décidé : l'onglet et son icône existent, son volet gauche attend. |
| **L'onglet du familier n'a pas de source** | camelot n'a pas d'onglet familier : `CHARACTER_MODE_TAB_ICONS` n'en dit rien. Il garde son texte. |
| **L'écart entre deux onglets vaut −2, pas 0** | `UpdateTabLayout` pose chaque onglet visible sur le `BOTTOMLEFT` du précédent visible en `(0, -2)`. Le chevauchement de 2 px était perdu. La même fonction confirme au passage la règle du **précédent visible**. |
| **Un onglet latéral masqué laissait un trou** | 3.3.5 efface l'onglet du familier quand le personnage n'en a pas : `PetPaperDollFrame_UpdateIsAvailable` fait `CharacterFrameTab2:Hide()`, puis rattache le suivant sur le `LEFT` du masqué — sa réparation à lui, pensée pour une rangée horizontale. En colonne, l'onglet masqué restait ancré et réservait sa hauteur : réputation, compétences et monnaie flottaient sous le personnage au lieu de le suivre. La pile ne chaîne plus que sur le précédent **visible**, et se refait à chaque fois que cette fonction — la seule qui décide de cet état — est appelée. |
| **Le volet droit reste ouvert d'un onglet à l'autre** | C'est ce que fait la source : `UpdateRightPaneHeader` ne masque que le `StoneBg` — *« the stone header backs the PaperDoll sidebar tabs, so it should not render on tabs that have none »* — et `RightPaneHost` demeure. Chaque onglet aura ses propres informations à y mettre ; le volet leur est donc réservé dès maintenant, vide en attendant. Ce qui s'en va d'un onglet à l'autre n'est pas le volet mais le **mobilier du groupe** : bande de pierre, onglets de page et ligne de niveau pour le personnage — les trois choses exactes que `UpdateRightPaneHeader` et `HidePaperDollRightPane` masquent. |
| **Le mobilier : un troisième niveau, parce que deux ne suffisaient pas** | La bande de pierre et les deux onglets de page appartiennent au *groupe*, pas à l'une de ses deux pages : les déclarer dans une page les aurait fait disparaître en passant à l'autre. `Panes.Furniture(hôte, groupe, …)` les tient. Le calcul masque d'abord tout ce qui est déclaré, puis remontre celui du groupe courant, pour qu'un meuble partagé par deux groupes ne dépende d'aucun ordre de parcours. |
| **La largeur n'est plus un réglage mais une conséquence** | Elle ne dépend que d'une question : l'hôte droit a-t-il quelque chose à montrer ? La seule réponse négative est aujourd'hui le repli demandé par le joueur — qui traverse les onglets — mais la question reste posée à un seul endroit, prête pour un écran qui n'aurait pas de volet droit. |
| **La mise en page des quatre autres écrans reste à faire** | Réputation, compétences, monnaie et familier sont seulement **bornés** à l'hôte gauche, ce qui suffit à les empêcher de déborder. Les redessiner est un chantier par écran. |
| **Le repli du volet droit : ce que la source masque, et ce qu'elle garde** | `RefreshRightPane` masque `RightPaneHost` et les `SidePanes`, rien d'autre. `CharacterFrameModeTabs` — les onglets latéraux — n'y figure pas : il est ancré au `TOPRIGHT` de la **fenêtre**, dehors, donc il se rapproche avec le bord et reste visible. Replié, la fenêtre passe à `CHARACTER_FRAME_COLLAPSED_WIDTH`, soit exactement la largeur du volet gauche : le volet droit ne rétrécit pas, il s'en va. |
| **Masquer le volet n'emporte pas ce qui n'y est qu'ancré** | Les douze lignes de statistiques, leurs deux sélecteurs et le panneau du gestionnaire sont des cadres **du client**, seulement ancrés dans notre volet droit : `Hide()` sur le volet les laisse à l'écran, dans le vide. Ils se masquent un par un, par la même voie que l'onglet des statistiques. |
| **L'habillage repasse à chaque événement, et rouvrait le volet** | `habiller()` posait la largeur en tête de passage, puis `poserStatistiques` remontrait les lignes. La largeur se décide désormais **en fin** de passage, après que tout a été reposé. |
| **L'onglet ouvert se retient** | Replier appelle `montrerStatistiques(false)`, ce qui met `statsMontrees` à faux : sans mémoire séparée, déplier rouvrait toujours sur les statistiques, même si le gestionnaire était ouvert. |
| **Le bouton se pose là où le modèle prend la souris** | Coin haut droit du volet gauche, que `CharacterModelFrame` recouvre — le même piège que les emplacements d'équipement. Le bouton prend deux crans de plus que le modèle, comme les flèches de rotation, sans jamais descendre sous l'habillage. |
| **`reposerLaPlace` est écrite plus bas que le bouton** | Son nom s'y résolvait en globale, donc nil au moment du clic. Déclarée en amont, comme `majEtatSelecteurs`. |
| **Le faux client n'avait pas d'infobulle** | `GameTooltip` ne retenait ni propriétaire ni texte, et n'avait pas de `GetOwner` — que le jeu a. Une interface qui change un intitulé sous un curseur immobile doit la redemander depuis le même bouton, et cela ne se testait pas. |
| **L'ordre retenu tenait plusieurs fois le même nom** | C'était la vraie cause, et c'est le témoin `/fui sets` qui l'a montrée : pour **un** ensemble publié par le client, l'ordre retenu tenait sept entrées — `aab, aab, aze, aab, azq, zzzaq, aab`. Un nom que le client ne publie pas à cet instant est sauté par la première boucle, et la seconde le rajoute dès qu'il reparaît ; quelques renommages suffisaient. Chaque copie prenant un rang, l'ensemble se posait quatre fois. Un nom n'est désormais placé qu'**une** fois, `remplacerDansOrdre` retire les copies du nom qu'il vient de poser, et l'ordre se nettoie des noms effacés — mais **seulement quand le client publie au moins un ensemble**, sinon on retombe sur la table vidée d'avant. |
| **Le rang n'est pas l'indice du client** | La boucle d'affichage testait `index <= total` avec `index = position`, le rang dans *notre* ordre. Avec l'ordre dédoublonné le cas ne se voyait pas ; avec quatre copies, la carte finissait au rang 4 pour un total de 1 et se masquait — `carte 1 : visible=nil`. Le vrai indice se lit dans `ordre[position]`. |
| **Une image ne suffisait pas non plus : la liste ne s'attend plus, elle se surveille** | Le rattrapage d'une image a encore manqué la publication du client : en jeu, renommer AAA en AAB laissait la liste **vide jusqu'à l'opération suivante**. Les ensembles vivent côté serveur, et aucun moment ne peut être tenu pour sûr — ni le retour de `SaveEquipmentSet`, ni l'instant de `EQUIPMENT_SETS_CHANGED`, ni l'image d'après. On a donc cessé de parier sur un délai : le panneau compare toutes les **0,2 s** ce que le client rend (nombre d'ensembles, noms, icônes) à ce qui est affiché, et repose les cartes dès que cela diffère. Quand rien ne change, rien n'est reposé — le banc le vérifie : 0 pose sur 10 contrôles. Le contrôle ne tourne que panneau ouvert, c'est-à-dire exactement quand la liste se regarde. |
| **Le banc ne pouvait pas voir une publication tardive** | Sa séquence publiait toujours au moment de l'événement. Il rejoue maintenant le pire cas : l'événement arrive **avant** que le client ait refait sa liste, le rattrapage passe dans le vide, et plus rien n'est annoncé ensuite — seul le battement du panneau répare. |
| **Un témoin pour ne plus deviner** | `/fui sets` rapporte, depuis le jeu, les trois choses qui décident de l'affichage et qui peuvent se contredire : ce que le client publie (`GetNumEquipmentSets` et chaque `GetEquipmentSetInfo`), l'ordre retenu dans `ForeverUIDB`, l'ordre posé, puis pour chaque carte son nom, sa visibilité, son ancrage et sa coche — avec le défilement et le nombre de cartes qui tiennent. |
| **Le banc rendait ses listes tout de suite** | Il ne pouvait donc pas voir ce décalage. Son `GetNumEquipmentSets` et son `GetEquipmentSetInfo` répondent maintenant sur un état **publié**, qui ne rattrape le vrai qu'à l'événement ; `GetEquipmentSetInfoByName`, lui, répond tout de suite, comme le jeu le montre. La séquence signalée (créer AAA, renommer en AAB, créer AZE, supprimer AAB) est un test. | `SaveEquipmentSet` et `DeleteEquipmentSet` rendent la main **avant** que `GetNumEquipmentSets` ait changé : reposer les cartes dans la foulée montrait l'état d'avant, et un ensemble renommé n'apparaissait qu'à la prochaine secousse de la liste — la création d'un autre, par exemple. C'est `EQUIPMENT_SETS_CHANGED` qui l'annonce ; on s'y abonne **soi-même**, le client ne l'écoutant que fenêtre ouverte, et notre panneau peut être sur l'autre onglet. Le contenu des cartes venant du client, il faut aussi lui faire refaire son `GearManagerDialog_Update`, pas seulement les reposer. Au passage, l'ordre retenu est **élagué** des ensembles effacés. |
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


---

## 5. Ce qui reste à reprendre sur la feuille de personnage

### 5.1 L'onglet « Pet » n'a pas son icône

Les six onglets latéraux prennent leurs icônes de la référence — icône de
classe, poignée de main, outils, poing de faction, pièces, parchemin. **Celui
du familier garde encore l'icône de 3.3.5.** La référence n'en donne pas :
elle ne met pas le familier dans cette colonne, mais en troisième onglet du
volet droit (`PAPERDOLL_SIDEBARS` vaut `{STATS, EQUIPMENTMANAGER, PET}`), et
l'icône qu'elle lui donne là est un rognage de `PaperDollSidebarTabs` — une
planche qui est **déjà dans l'atelier** depuis l'onglet des titres.

À faire : choisir l'image. Trois pistes, par ordre de fidélité décroissante :
le rognage `PET` de `PaperDollSidebarTabs`, tel que
`mainline/PaperDollFrameConstants.lua` le déclare ; une icône
`INV_SideTab_*` de la même famille que les cinq autres, si le listfile en
porte une ; ou une icône de sort du familier, cuite au masque comme les
autres. Les deux premières ne demandent aucun art nouveau.

### 5.2 Le volet droit de l'onglet « PvP » est à revoir

Le volet gauche a été repris de `camelot/pvprankframe` et validé ; **le volet
droit, lui, n'a jamais été repris** — il empile les chiffres que WotLK sait
donner (points d'honneur, victoires honorables, meilleur rang, aujourd'hui,
hier) sous le nom du rang, sans le gabarit de la référence.

Ce que la référence y met, et qui manque ici : `TokenDetailFrame` et
`ReputationDetailFrame` partagent `CharacterFrameSidePaneTemplate` — titre,
sous-titre, séparateur, **lignes intitulé/valeur** posées par `AddRow` et
`AddWrappedRow`, et un pied. Le volet PvP devrait s'y conformer comme les
autres, et non composer ses lignes en chaînes de caractères.

À faire au même moment : décider ce qui mérite d'y figurer. La référence y
montre la progression de la saison et le marchand de récompenses, qui n'ont
pas d'équivalent ici ; les statistiques d'honneur, elles, n'y sont pas — ce
sont celles que 3.3.5 donne, et elles occupent la place faute de mieux.

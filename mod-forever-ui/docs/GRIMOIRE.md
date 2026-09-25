# Grimoire : Camelot contre WotLK

Chantier ouvert le 2026-09-25. Même règle que les chantiers précédents :
garder l'ossature de WotLK, remplacer ce qui se voit, ajouter ce que Camelot a
en plus.

## Sources lues

- Camelot : `blizzard_playerspells` (le `.toc`, `camelot/` pour le cadre et le
  grimoire, `spellbook/` pour le cadre, les catégories, l'élément de sort, les
  gabarits), l'index des atlas.
- WotLK : `SpellBookFrame.lua` / `.xml` (chaîne d'archives 3.3.5).

## Ce que montre Camelot

- **Cadre** : `PlayerSpellsFrame` (PortraitFrameTemplate), sans onglets
  Spécialisation / Talents (`IsTabSystemAvailable` rend faux pour Camelot).
  Portrait : l'icône de la ligne « Général ». Bouton agrandir / réduire à
  gauche de la croix.
- **Deux largeurs** : réduit 809 (une page, `spellbook-page-condensed`), agrandi
  1 618 (deux pages, `spellbook-page-left` / `-right`) ; 720 de haut.
- **Catégories** : une par ligne de sorts (Général, puis une par arbre), plus le
  familier, en **onglets-icônes** en haut à gauche (70, -26).
- **Page** : grille de 3 colonnes, 680 × 590 par page ; un **en-tête** (nom de
  la catégorie, séparateur) ; chaque sort : icône 40 × 40 dans un cadre
  **carré**, **rond** pour un passif, nom (SystemFont_Large), sous-titre (rang
  ou « Passive »), fond au survol.
- **Pages** : « Page n / m » et deux flèches, en bas à droite.
- **Recherche** : champ en haut à droite, aperçu des résultats sous le champ,
  pages de résultats.
- **Réglages** (flèche en haut à droite) : masquer les passifs, montrer tous
  les rangs (CVar `ShowAllSpellRanks`).

## Ce que fait WotLK

`SpellBookFrame` : 12 boutons de sort (`SpellButton1..12`), 2 colonnes × 6,
onglets de lignes à droite (`SpellBookSkillLineTab1..8`), onglets Sorts /
Familier en bas, pages de 12, case « Show All Spell Ranks ».

**LA CONTRAINTE QUI DÉCIDE DE TOUT.** Lancer un sort (`CastSpell`) est une
action **protégée**. Un bouton de WotLK lance le sort d'un emplacement calculé
depuis l'état interne du grimoire (type de livre, ligne choisie, page) ; si le
code de ForeverUI écrit dans cet état, tout lancement depuis le grimoire est
bloqué. Et un bouton de sort créé par ForeverUI ne peut lancer qu'à travers un
bouton **sécurisé** (`SecureActionButtonTemplate`), dont le sort ne se change
pas en combat — et un cadre qui contient des boutons sécurisés ne s'ouvre pas
en combat depuis un addon.

Conséquence : la grille de Camelot (18 à 21 sorts par page, en-têtes,
filtres, recherche) ne peut pas reposer sur les 12 boutons de WotLK.

## Décisions (2026-09-25)

1. **Construction** : la grille de Camelot complète, sur nos propres cases
   sécurisées. En combat, l'ouverture, les pages et les catégories passent par
   des scripts sécurisés précalculés ; la recherche seule y reste inutilisable.
2. **Largeur** : agrandi (deux pages, 1 618) par défaut ; le bouton réduit à
   une page (809) ; l'état est retenu.
3. **Périmètre** : le grimoire seul ; les talents feront un chantier à part.

Ordre : 1. le cadre, les catégories et la grille, hors combat ; 2. le combat
(scripts sécurisés) ; 3. la recherche et les réglages. Chaque étape validée
en jeu avant la suivante.

Étape 1 livrée le 2026-09-25 (non validée) : `SpellBook.lua` ; relevé et écarts en tête du fichier.

Retours du 2026-09-25 appliqués : portrait (livre fermé `inv_misc_book_09`, masque rond cuit par `tools/cuire_masque.py`), en-tête répété sur chaque vue, réglages (masquer les passifs, tous les rangs), croix au-dessus du livre, passifs sans ombre carrée.

Réglages complétés le 2026-09-25 : « Group Similar Spells on Flyouts » (groupes relevés dans `SpellFlyout.db2` / `SpellFlyoutItem.db2` de Camelot, menu volant à boutons sécurisés, hors combat) ; « Show all spell ranks » pour toutes les classes, à la demande (Camelot l'ôte au voleur et au guerrier).

Étape 1 VALIDÉE en jeu le 2026-09-25 (cadre, catégories, grille, portrait, réglages, menus volants par onglet et par faction, portails et téléportations de BC/WotLK).

Groupes complétés et validés le 2026-09-25 : sorts de Burning Crusade et WotLK ajoutés aux familles de Camelot ; deux groupes hors Camelot, « Seals » et « Judgements ».

Étape 2 livrée le 2026-09-25 (non validée) : contrôleur sécurisé ; hors combat tout est calculé et publié, en combat onglets, pages, roulette et menus volants passent par des blocs sécurisés, les images suivent par `CallMethod`.

Étape 2 VALIDÉE le 2026-09-25, avec les réglages immédiats en combat (menu en boutons sécurisés) ; poussée (9b2f68a).

Étape 3 livrée le 2026-09-25 (non validée) : `SpellBookSearch.lua` (champ, aperçu, recherche entière en sections, « Missing from action bar ») ; relevé et écarts en tête du fichier.

Étape 3 VALIDÉE le 2026-09-25 : la recherche suit « Hide Passives » et « Show all spell ranks » (ce dernier reste actif pendant une recherche), ne groupe jamais en menus volants, et l'aperçu montre 5 résultats — écarts à Camelot demandés.

Ajout du 2026-09-25 : fenêtre déplaçable par son titre (place retenue dans ForeverUIDB) et superposée entière aux autres grandes fenêtres (`Superposition.lua`).

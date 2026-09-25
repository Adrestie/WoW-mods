# Talents : Camelot contre WotLK

Chantier ouvert le 2026-09-25. Même règle que les chantiers précédents :
garder l'ossature de WotLK, remplacer ce qui se voit, ajouter ce que Camelot a
en plus.

## Sources lues

- Camelot : `blizzard_playerspells` (camelot/classtalents, classtalents,
  camelot/blizzard_playerspellsframe) et `blizzard_sharedtalentui` (boutons,
  arêtes, portes, surcharges camelot).
- WotLK : `Blizzard_TalentUI`, `Blizzard_GlyphUI`, `TalentFrameBase.lua`
  (chaîne d'archives 3.3.5).

## Ce que montre Camelot

- **Cadre** : `PlayerSpellsFrame`, page talents 1218 × 708, titre TALENTS,
  portrait = icône de classe. Pas de bouton agrandir / réduire.
- **Un seul écran, trois arbres côte à côte** : un en-tête par arbre (icône
  masquée ronde dans `Talents-Main-Ring-c60`, nom, points dépensés dans
  `talents-main-ring-box-c60`), séparateurs verticaux, fond par classe
  `talent-background-<classe>` (pas de chevalier de la mort), nuages et
  particules.
- **Nœuds** : carré (sort actif) ou rond (passif), 40 × 40, icône 36 ;
  vert = achetable ou partiel, jaune = au maximum, gris = verrouillé ; le
  chiffre = rang actuel seul.
- **Flèches** : une ligne droite de centre à centre, à tout angle, et sa
  pointe.
- **Portes** : `talents-gate` et le nombre de points requis, à gauche du
  premier nœud du palier.
- **Points** : `UNSPENT_POINTS` en haut à droite.
- **Validation** : changements en attente, Apply (barre d'incantation),
  Undo, menu Reset.
- **Double spé** : onglets `DUAL_SPEC_PRIMARY` / `DUAL_SPEC_SECONDARY` en haut,
  coche sur l'actif, cadenas si verrouillé ; `TALENT_SPEC_ACTIVE` ou le bouton
  `TALENT_SPEC_ACTIVATE`.
- **Recherche** : champ et options (masquer les passifs, montrer les rangs).
- **Absents** : talents du familier, glyphes, jeux de talents (masqués),
  import / export.

## Ce que fait WotLK

`PlayerTalentFrame` (384 × 512, LoadOnDemand) : un arbre à la fois (onglets du
bas), grille de 4 colonnes au pas de 63, flèches coudées, 5 points par palier
(3 pour le familier), rang « x/y », barre de points. Aperçu optionnel (CVar
`previewTalents`, Learn / Reset). Double spé en onglets latéraux, activation
= sort incanté (63645 / 63644). Talents du familier. Glyphes : onglet 4,
six alvéoles (3 majeures, 3 mineures), niveaux 15 / 15 / 30 / 50 / 70 / 80.

Rien n'est protégé : `LearnTalent`, `AddPreviewTalentPoints`,
`LearnPreviewTalents`, `SetActiveTalentGroup`, `PlaceGlyphInSocket`,
`RemoveGlyphFromSocket` sont appelés par Blizzard depuis du code ordinaire.

## Décisions (2026-09-25)

1. **Glyphes** : une page du cadre, par un onglet à côté de Primary /
   Secondary ; les 6 alvéoles de WotLK dans leur disposition en anneau,
   habillées avec l'art de Camelot.
2. **Familier** : un onglet « Pet » dans la rangée du haut ; même arbre, mêmes
   nœuds, flèches et portes.
3. **Validation** : toujours en attente (aperçu de WotLK forcé) ; Apply
   apprend, Undo annule. Pas de menu Reset : WotLK ne désapprend que chez un
   maître.
4. **Ordre** : 1. cadre, trois arbres, nœuds, flèches, portes, points ;
   2. attente / Apply / Undo, double spé, familier ; 3. glyphes ; 4. recherche.
   Chaque étape validée en jeu avant la suivante.

Précisions du 2026-09-25 : 11 paliers au lieu de 7 → nœuds à 0,75 et rangées au pas de 43, colonnes et arbres au pas de Camelot ; chevalier de la mort → le fond moderne de chaque spécialisation, un par arbre.

Étape 1 livrée le 2026-09-25 (non validée) : `Talents.lua`, `TalentsData.lua` (généré par `tools/formes_talents.py` depuis les DBC du serveur : carré = sort actif) ; relevé et écarts en tête du fichier.

Étape 2 livrée le 2026-09-25 (non validée) : onglets latéraux à droite (Primary, Secondary, Pet), « Activate » à la place d’Apply sur une spécialisation inactive, fenêtre réduite à un arbre pour le familier.

Étape 2 validée le 2026-09-25. Fenêtre déplaçable par son titre (place retenue dans ForeverUIDB) et superposée entière aux autres grandes fenêtres (`Superposition.lua`).

Étape 3 livrée le 2026-09-25 (non validée) : glyphes = le GlyphFrame de WotLK tel quel (choix de l’utilisateur), parchemin rogné, dans la fenêtre réduite ; onglet « Glyphs » après les spécialisations.

Glyphes refaits le 2026-09-25, validés : décor sur l’art fourni (`tools/cuire_glyphes.py` → `glyphes-fond.blp`, `glyphes-lueurs.blp`), fonctionnement et montures d’alvéole de WotLK conservés.

Étape 4 livrée le 2026-09-25 (non validée) : recherche (`TalentsSearch.lua`, champ à gauche du compteur, aperçu de 5) et confirmation à la fermeture avec des changements en attente.

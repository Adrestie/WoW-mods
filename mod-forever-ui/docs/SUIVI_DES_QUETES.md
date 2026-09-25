# Suivi de quêtes : Camelot contre WotLK

Chantier ouvert le 2026-09-25. Même règle que la carte : garder l'ossature de
WotLK (`WatchFrame`, ses événements, ses CVar, son API d'extension), remplacer
ce qui se voit, ajouter ce que Camelot a en plus.

## Sources lues

- Camelot : `blizzard_objectivetracker` (le `.toc`, `camelot/…override.lua`,
  conteneur, module, bloc, lignes, animations, repères, quêtes, hauts faits,
  gestionnaire, polices, `shared.xml`), `difficultyutil.lua`.
- WotLK : `WatchFrame.xml` / `WatchFrame.lua` (chaîne d'archives 3.3.5),
  `UIParent.lua` (placement).
- Chaînes et couleurs Camelot : `globalstrings.db2`, `globalcolor.db2`.

## Ossature WotLK

`WatchFrame` (204 × 140, sous la minimap, placé par `UIParent_ManageFramePositions`)
porte `WatchFrameLines`. `WatchFrame_Update` appelle dans l'ordre les
**gestionnaires d'objectifs** de `WATCHFRAME_OBJECTIVEHANDLERS` : minuteurs de
quête, hauts faits suivis, quêtes suivies. **Un addon peut y ajouter le sien**
(`WatchFrame_AddObjectiveHandler`) : c'est la porte d'entrée prévue par WotLK.

## Comparaison

| Élément | Camelot | WotLK | Proposition |
|---|---|---|---|
| Cadre | `ObjectiveTrackerFrame`, 260 de large, strate LOW | `WatchFrame`, 204 (306 en large, CVar `watchFrameWidth`) | garder `WatchFrame`, largeur 260 |
| En-tête général | « All Objectives », fond `ui-questtracker-primary-objective-header` 300 × 40, police 14 dorée, bouton réduire-tout 18 × 19 (rouge) | « Objectives (n) » en GameFontNormal, bouton `UI-Panel-QuestHideButton` | Camelot ; clic droit garde le menu de WotLK (voir question 2) |
| Fond | NineSlice `common-opacity-background`, alpha 0 par défaut | aucun | Camelot, alpha 0 |
| Modules | un en-tête par type : « Quests », « Achievements » (fond `secondary-objective-header` 300 × 30, bouton 16 × 16 jaune), chacun repliable | un seul bloc, types séparés de 10 | Camelot |
| Minuteurs de quête | pas de section ; barre de temps dans le bloc, désactivée par l'override Camelot | section « Quest Timers » en tête | question 2 |
| Bloc de quête | titre police 12 couleur `OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR` (0,749 / 0,612 / 0), à 20 du bord ; 10 entre blocs ; 4 entre lignes | titre 0,75 / 0,61 / 0 ; lignes de 16 | Camelot |
| Objectifs | tiret + texte 0,8 gris ; **les remplis restent**, gris 0,6, coche `ui-questtracker-tracker-check` | les remplis **disparaissent** ; texte inversé (« 3/10 Kobolds ») | Camelot |
| Quête terminée | « Ready for turn-in » ou le texte de rendu, sans tiret | texte de rendu avec tiret | Camelot |
| Échec | « Failed » rouge 0,8 / 0,098 / 0,098 | pas d'affichage | Camelot |
| Argent demandé | « x / y » en objectif | idem | commun |
| Survol d'un bloc | titre en jaune vif, lignes en blanc | idem (couleurs proches) | Camelot |
| Repère devant le titre | POIButton à (-7, 5) du titre | `QuestPOI_DisplayButton` numéroté, à (0, 5) | question 3 |
| Objet de quête | bouton 26 × 26, cadre `questitem-frame` 42 × 42 | `WatchFrameItem` 26 × 26, cadre `UI-Quickslot2` | garder `WatchFrameItem<n>`, le rhabiller |
| Clic gauche sur une quête | ouvre carte + page de la quête | ouvre le journal sur la quête | question 4 |
| Clic droit sur une quête | Focus, Open Quest Details, Open Quest Map, Untrack, Share, Share in Chat, Abandon | Open Quest Details, Stop Tracking, Share, Show Quest Map, déplacer (tri manuel) | question 2 |
| Maj-clic | ne plus suivre | idem | commun |
| Hauts faits | 5 critères au plus, « … » ensuite ; clic ouvre le haut fait | idem | commun, habillé Camelot |
| Tri et filtres | tri par la CVar du client, pas de menu | clic droit sur l'en-tête : tri (proximité, difficulté, manuel), filtres (hauts faits, quêtes terminées, zones lointaines) | question 2 |
| Animations | lueur à l'ajout, coche + lueur à l'accomplissement, fondu | aucune | Camelot (les groupes d'animation existent en 3.3.5) |
| Niveau devant le titre | seulement si la CVar `showQuestLevel` | non | question 1 |

## Art à verser

Feuille `interface/questframe/questtracker` (variante `c60` pour Camelot) :
en-têtes, boutons réduire / déplier / filtre et leurs surbrillances, coche et
sa lueur, lueurs d'animation, cadre de l'objet de quête. Feuille
`interface/hud/uicommonopacitybackground` (+ `center`) pour le fond.

## Décisions (2026-09-25)

1. **Titre** : Camelot par défaut — titre seul, doré uniforme, sans niveau ni
   couleur de difficulté.
2. **Fonctions propres à WotLK** : gardées, habillées Camelot — tri et filtres
   dans le bouton filtre de l'en-tête, déplacement manuel dans le menu de la
   quête, minuteurs de quête en barre de temps dans le bloc.
3. **Repères** : les numéros de WotLK (`QuestPOI_DisplayButton`), à (-7, 5) du
   titre.
4. **Clic gauche** : carte + page de la quête (étape 3 du journal).

Livré le 2026-09-25 (non validé) : `ObjectiveTracker.lua` ; écarts en tête du fichier.

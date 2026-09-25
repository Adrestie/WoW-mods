# Carte du monde et journal de quêtes — Camelot contre WotLK

Établi le 2026-09-24, avant toute ligne de code, à partir de trois relevés de
source : la fenêtre de la carte de Camelot, son volet de quêtes, et la carte et
le journal du client 3.3.5.

**La règle du chantier, posée par l'utilisateur** : on construit autour de la
carte d'origine de WotLK. On garde son ossature — ses cadres, leurs noms, ses
fonctions, ses CVar —, on remplace ce qui se voit, et on ajoute ce que Camelot
a en plus. Les addons de carte (Mapster, Astrolabe…) doivent continuer de
croire qu'ils parlent à la carte normale de WotLK.

Chaque ligne dit donc :

- **Commun** : les deux clients ont l'élément → on garde celui de WotLK et on
  l'habille comme Camelot.
- **Camelot seul** : on l'ajoute.
- **WotLK seul** : à trancher (garder, masquer).
- **Impossible** : 3.3.5 n'a ni la donnée ni l'API.

Sources : `Camelot` = `C:\Users\Arthe\Desktop\addons` (fichiers chargés pour
camelot d'après les `.toc`) ; `WotLK` = FrameXML du client, lu par la chaîne
d'archives (`patch-enus-2` et `-3`, aucun remplacement ultérieur).

---

## 1. La fenêtre de la carte

| # | Élément | Camelot | WotLK | Nature | Décision |
|---|---|---|---|---|---|
| 1 | Cadre racine | `WorldMapFrame` | `WorldMapFrame` | Commun | **On garde celui de WotLK.** Même nom : les addons le trouvent. |
| 2 | Deux tailles, CVar `miniWorldMap` | réduit 702 × 534 (1035 avec le volet) / agrandi | petite fenêtre `WINDOWED` / plein écran `QUESTLIST` ou `FULLMAP` | Commun | **On garde la bascule de WotLK** (`WorldMapFrame_ToggleWindowSize`, même CVar). Réduit Camelot = petite fenêtre WotLK ; agrandi Camelot = plein écran WotLK. |
| 3 | Échelle de la carte en mode réduit | zone 697 × 465 pour une carte de 1002 × 668 → ≈ 0,696 | petite fenêtre 0,573 ; plein écran avec liste 0,691 | Commun | Retailler la petite fenêtre WotLK à l'échelle de Camelot (≈ 0,696). |
| 4 | Bordure | NineSlice `PortraitFrameTemplateMinimizable` : coins métal, portrait, coin haut-droit « double » ; corrections camelot (−2 / −8) | `WorldMapFrameMiniBorderLeft/Right` (petite fenêtre), `WorldMapFrameTexture1..18` (plein écran) | Commun | Étouffer l'habillage WotLK, poser le métal Camelot (atlas déjà dans l'atelier). En agrandi : disposition `ButtonFrameTemplateNoPortraitMinimizable`. |
| 5 | Titre | `MAP_AND_QUEST_LOG` (réduit) / `WORLD_MAP` (agrandi), `GameFontNormal`, bandeau de 20 à (58, −1) | `WorldMapFrameTitle` | Commun | Garder `WorldMapFrameTitle`, le replacer et changer son texte selon le mode. |
| 6 | Portrait | `UI-QuestLog-BookIcon` rond 62 × 62 (réduit seulement) | — | Camelot seul | Ajouter. Le fichier existe dans 3.3.5. |
| 7 | Bouton de fermeture | `RedButton-Exit` 24 × 24, TOPRIGHT (−2, 1) | `WorldMapFrameCloseButton` | Commun | Garder celui de WotLK, l'habiller en rouge. |
| 8 | Agrandir / réduire | `RedButton-Expand` / `-Condense`, 24 × 24, collé à gauche de la fermeture (−1) | `WorldMapFrameSizeDownButton` / `SizeUpButton` | Commun | Garder ceux de WotLK, les habiller. |
| 9 | Navigation entre cartes | barre en fil d'Ariane (`NavBar`) à (64, −25), racine « Monde » | menus Continent et Zone, bouton « Zoom arrière », menu mini-carte de zone | Commun (même fonction, forme différente) | **Fil d'Ariane de Camelot** (décision 2) ; menus WotLK cachés mais fonctionnels. Les images de la barre (`CS_HelpTextures`) n'existent pas dans 3.3.5 : à verser. |
| 10 | Étages de donjon | menu 160 × 25 en haut à gauche de la carte | `WorldMapLevelDropDown` + flèches haut/bas | Commun | Garder le menu WotLK, le replacer et l'habiller. |
| 11 | Contenu de la carte | canevas moderne + fournisseurs de données | tuiles `WorldMapDetailTile1..12`, `WorldMapButton`, joueur, groupe, raid, cadavre, ping, zones découvertes | Commun | **On garde tout le contenu WotLK**, seulement replacé et mis à l'échelle — comme pour la minimap. |
| 12 | Repères de quête sur la carte | épingles modernes (`POIButton` 20 × 20) | `WorldMapPOIFrame`, blobs `WorldMapBlobFrame` | Commun | Garder ceux de WotLK. Leur habillage se décidera plus tard. |
| 13 | Fond noir en agrandi | `BlackoutFrame` plein écran | `BlackoutWorld` | Commun | Garder `BlackoutWorld`. |
| 14 | Masquage de l'interface en agrandi | panneau « fullscreen » | `UIParent:Hide()` : tout cadre parenté à UIParent disparaît | Commun, effets à vérifier | **Carte seule, comme Camelot** (décision 1) ; le masquage de l'interface par WotLK reste. |
| 15 | Fond derrière la carte | `gamepad-mapquestlog-bgtile-2k` + 4 vignettes, fond `UI-Background-Rock`, liseré `_UI-Frame-InnerTopTile` | — | Camelot seul | Ajouter. Feuilles à verser. `UI-Background-Rock` n'existe pas en 3.3.5. |
| 16 | Coordonnées curseur / joueur | panneau en bas à gauche, CVar `worldMapShowPlayerCoords` / `…CursorCoords` / `coordsByTenths` | — | Camelot seul | Ajouter. Les CVar n'existent pas en 3.3.5 : réglages dans `ForeverUIDB`. |
| 17 | Filtres | bouton `common-dropdown-a-button` à droite de la barre de navigation | case « Afficher les objectifs » (`WorldMapQuestShowObjectives`, CVar `questPOI`) | Commun (réglages d'affichage) | Garder la case WotLK et son CVar, présentés comme le bouton de filtres de Camelot. |
| 18 | Suivre la quête | dans le volet de quêtes | case `WorldMapTrackQuest` sous la carte | Commun | Garder la fonction WotLK, masquer la case : le suivi passe par le volet. |
| 19 | Épingle de destination | `WorldMapTrackingPinButton` | — | Impossible | 3.3.5 n'a pas de point de passage utilisateur. Non repris. |
| 20 | Bascule du volet de quêtes | bouton `QuestCollapse-Show/Hide` en bas à droite de la carte, CVar `questLogOpen` | — | Camelot seul | Ajouter. CVar absente : état dans `ForeverUIDB`. |
| 21 | Déplacement de la fenêtre | panneau « left », non déplaçable | petite fenêtre déplaçable si `advancedWorldMap` ; panneau « doublewide » sinon | Commun | Garder le système de panneaux de WotLK tel quel (Mapster le désactive lui-même). |
| 22 | Minuteur de zone, menace, primes, bouton d'action, suivi d'activité | cadres superposés | — | Impossible | Contenus retail sans données en 3.3.5. |

## 2. Le volet de quêtes

| # | Élément | Camelot | WotLK | Nature | Décision |
|---|---|---|---|---|---|
| 23 | Où vit le journal | volet de 330 px accroché à droite de la carte ; L ouvre carte + journal | `QuestLogFrame`, fenêtre à part (L) | Commun (même données) | **`QuestLogFrame` invisible, L ouvre la carte + le volet** (décision 3). |
| 24 | Données | `C_QuestLog` | `GetNumQuestLogEntries`, `GetQuestLogTitle` (10 retours), objectifs, récompenses… | Commun | On lit les API de WotLK. Aucune donnée inventée. |
| 25 | Lignes | en-têtes 289 × 22, quêtes 290 × 16, objectifs 220 × 16, reconstruites à chaque mise à jour | boutons `QuestLogScrollFrameButton1..22` (journal) ou `WorldMapQuestFrame<n>` (carte) | Commun | Nos propres lignes, habillées Camelot (règle « bâtir nos lignes, ne prendre du client que ses données »). |
| 26 | Quêtes listées | tout le journal, groupé par zone | journal : tout ; carte : seulement les quêtes ayant un repère sur la carte affichée | Commun | Tout le journal, comme Camelot. |
| 27 | Replier / déplier une zone | clic sur l'en-tête ; à l'entrée en jeu, zone courante dépliée | `ExpandQuestHeader` / `CollapseQuestHeader` | Commun | Fonctions de WotLK. L'état replié reste donc le même que dans son journal. |
| 28 | Niveau devant le titre | `[N]` ou `[N+]` si élite, toujours | `[N]` seulement en mode daltonien ; `questTag` « Élite » | Commun | Forme Camelot, données WotLK (`level`, `questTag`). |
| 29 | Mention Élite | « (Élite) » en fin de ligne | `questTag` en fin de ligne | Commun | Forme Camelot. |
| 30 | Couleur de difficulté | table Camelot (difficile = 1 / 0,82 / 0) | `GetQuestDifficultyColor(level)` | Commun | Classement de WotLK, couleurs de Camelot. |
| 31 | Suivi | case 14 × 14 cochée en jaune ; Maj+clic | coche ; `AddQuestWatch` / `RemoveQuestWatch`, limite 25 | Commun | Forme Camelot, fonctions WotLK. |
| 32 | Objectifs sous la quête | objectifs non remplis ; CVar `showQuestObjectivesInLog` | liste de la carte : idem ; journal : non | Commun | Afficher. La CVar n'existe pas en 3.3.5 : réglage dans `ForeverUIDB`, **affichés par défaut** (décision 4). |
| 33 | Quête terminée | texte de rendu à la place des objectifs | balise « Terminée » | Commun | Forme Camelot (`GetQuestLogCompletionText`). |
| 34 | Quête échouée | pas d'icône ; seulement dans l'infobulle et le titre du détail | balise « Échec » | Commun | Forme Camelot. |
| 35 | Membres du groupe sur la quête | préfixe `[n]` | `IsUnitOnQuest` | Commun | Forme Camelot, fonction WotLK. |
| 36 | Compteur de quêtes | `n / max` à droite de la recherche | `QuestLogQuestCount` (max 25) | Commun | Forme Camelot, maximum de WotLK (25). |
| 37 | Compteur de quotidiennes | — | `QuestLogDailyQuestCount` | WotLK seul | **Conservé** (décision 5). |
| 38 | Recherche | champ 200 × 20 (titre et objectifs) | — | Camelot seul | Ajouter (filtre local). |
| 39 | Réglages | bouton roue : « Afficher les objectifs » | — | Camelot seul | Ajouter. |
| 40 | Infobulle d'une quête | titre, temps restant, échec, objectifs, « Cliquer pour les détails » | — | Camelot seul | Ajouter. |
| 41 | Menu clic droit d'une quête | suivre, partager, lien dans le chat, abandonner (+ super-suivi) | — | Camelot seul | Ajouter, sans le super-suivi (absent de 3.3.5). |
| 42 | Clic droit sur un en-tête | tout suivre / ne rien suivre | — | Camelot seul | Ajouter. |
| 43 | Survol liste ↔ repère sur la carte | la ligne surligne le repère, et l'inverse | liste de la carte : surbrillance du blob | Commun | Via `WorldMapBlobFrame:DrawQuestBlob`, comme WotLK. |
| 44 | Campagnes, appels, récit de zone | code présent, piloté par les données | — | Impossible | Données absentes de 3.3.5. |
| 45 | Fond, cadre, ombre, barre de défilement | `QuestLog-main-background`, `questlog-frame`, `MinimalScrollBar` 8 px | — | Camelot seul | Ajouter. Feuilles à verser (voir §4). |

## 3. Le détail d'une quête

| # | Élément | Camelot | WotLK | Nature | Décision |
|---|---|---|---|---|---|
| 46 | Où | remplace la liste dans le volet (308 × 502), bouton Retour | panneau droit du journal ; `QuestLogDetailFrame` seul quand le journal est fermé | Commun | Dans le volet, comme Camelot. |
| 47 | Contenu | titre, objectifs, minuterie, argent requis, taille de groupe, description | mêmes données via `QuestInfo` | Commun | Données WotLK, mise en page Camelot. On **ne réutilise pas** les cadres `QuestInfo*` : uniques, partagés avec le dialogue des PNJ, ils se reparentent à chaque affichage. |
| 48 | Récompenses | bandeau qui grandit au défilement ; objets 2 par rangée, XP, argent… | objets, choix, sort, argent, honneur, points d'arène, talents, titre, réputation | Commun | Forme Camelot, données WotLK (y compris honneur, arène, talents, titre, que Camelot range dans ses sections). |
| 49 | Boutons Abandonner / Partager / Suivre | 105 / 103 / 105 × 22 en bas | `QuestLogControlPanel`, popups `ABANDON_QUEST` | Commun | Forme Camelot, fonctions et popups WotLK. |
| 50 | Carte suivant la quête | la carte bascule sur la zone de la quête et y revient au retour | `GetQuestWorldMapAreaID` + `SetMapByID` (`WorldMap_OpenToQuest`) | Commun | Mécanisme WotLK. |
| 51 | Sélection | `SetSelectedQuest` | `SelectQuestLogEntry` (la carte WotLK change déjà la sélection du journal) | Commun | `SelectQuestLogEntry`. |
| 52 | Portrait du donneur, boutons de destination | oui | — | Impossible | Non repris. |
| 53 | Ouverture depuis le suivi (WatchFrame) | ouvre la carte sur le détail | ouvre `QuestLogDetailFrame` | Commun | Ouvre la carte sur le détail (décision 3). |

## 4. Art à verser

Déjà dans l'atelier : coins et bords de métal, boutons rouges, liste
(`questlog-frame*`, cases, cases à cocher, plus/moins, recherche, réglages),
récompenses (`questlog-reward-*`), barre de défilement (sauf le pouce).

Feuilles manquantes :

| Feuille | Pour |
|---|---|
| `interface/questframe/questmaplogatlas.blp` | bascule du volet, ombre de coin, fond du détail, cadre des objets |
| `interface/questframe/questlogbackground.blp` | fond de la liste, liste vide |
| `interface/gamepad/gamepadmapbackgroundtile.blp`, `gamepadmapframe.blp` | fond et vignettes derrière la carte |
| `interface/framegeneral/uiframehorizontal.blp`, `uiframevertical.blp`, `interface/interface/framegeneral/uiframe.blp` | liserés intérieurs, séparateurs des boutons |
| `interface/buttons/minimalscrollbarsmallproportionalc60.blp` | pouce de la barre de défilement |

Fichiers absents de 3.3.5 : `CS_HelpTextures` et `_Tile` (barre de navigation),
`UI-Background-Rock` (fond), `ShadowOverlay-Left`.

## 5. À relever dans le client Camelot

Absents du code source : les couleurs `QUEST_OBJECTIVE_*`,
`DEFAULT_MATERIAL_*`, les chaînes `QUEST_LOG_COUNT_TEMPLATE`, `PARENS_TEMPLATE`,
`ELITE`, `QUEST_DASH`, `MAP_AND_QUEST_LOG`… — même méthode que pour les
coordonnées de la minimap (`globalstrings.db2`).

## 6. Décisions de l'utilisateur (2026-09-24)

1. **Mode agrandi** : comme Camelot — carte seule sur fond noir, sans volet ;
   la liste et le détail que WotLK affiche en plein écran sont masqués.
2. **Navigation** : la barre en fil d'Ariane de Camelot ; les menus
   Continent / Zone de WotLK restent en place, fonctionnels, mais cachés.
   Les images de la barre sont à verser.
3. **`QuestLogFrame`** : reste en place, invisible ; L, le micro-bouton et le
   suivi ouvrent la carte avec le volet.
4. **Objectifs sous les quêtes** : affichés par défaut.
5. **Compteur de quotidiennes** : conservé.

6. **Mapster désactivé** (après son audit, le 2026-09-25) : il retire la carte
   du système de panneaux, efface `miniWorldMap` et `advancedWorldMap` à chaque
   connexion, réimpose son échelle (0,75), sa strate et sa position à chaque
   ouverture, et se charge après ForeverUI. La fenêtre de Camelot et sa mise en
   page ne peuvent pas coexister. ForeverUI s'appuie donc sur la carte de WotLK
   telle que le FrameXML la décrit.

Ordre du chantier : 1. la fenêtre (mode réduit) ; 2. le volet liste ;
3. le détail ; 4. le mode agrandi. Chaque étape validée en jeu avant la
suivante.

Étape 3 livrée le 2026-09-25 (non validée) : relevé et écarts en tête de la
section « la page d'une quête » de `QuestLog.lua`.

Étape 4 livrée le 2026-09-25 (non validée) : relevé et principe en tête de `WorldMap.lua`.

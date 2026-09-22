# Cahier des charges — mod-limit-break

Jauge de Limite inspirée de Final Fantasy XIV pour AzerothCore 3.3.5a : une
ressource commune à un groupe ou un raid, alimentée par les actions de combat de
ses membres, dépensée par un membre pour déclencher un effet dont la puissance
dépend du palier atteint.

**Statut au 2026-09-19 : conception validée, aucune ligne de code écrite.** Ce
document est la seule référence du module. Les points listés au paragraphe 16 ne
sont pas tranchés et ne doivent pas être devinés à l'implémentation.

Ce document est en français, alors que la documentation publiée du dépôt est en
anglais : c'est un document de travail interne.

## 1. Périmètre

- Actif en monde ouvert et en contenu instancié.
- Désactivé en champ de bataille et en arène, avec un réglage de configuration
  pour l'activer ultérieurement.

## 2. Le conteneur — qui est concerné

Aucune distance n'est mesurée, aucun joueur ne sert de point de référence. Les
schémas « rayon autour du chef de groupe » et « map entière » ont été examinés
puis écartés : le premier parce qu'un chef déconnecté ou parti au cimetière fait
disparaître l'ancre, le second parce qu'un continent entier est un conteneur
trop grossier.

| Règle | Valeur |
|---|---|
| Clé du conteneur | map, instance, zone, phase |
| Élection | le conteneur réunissant le plus grand effectif de membres du groupe |
| Départage à effectif égal | le conteneur déjà actif l'emporte |
| Plancher d'activation | 4 membres présents |
| Participants | tous les présents du conteneur élu, sans exception : morts, au cimetière, en véhicule, en vol |
| Hors du conteneur élu | ni remplissage ni usage, exactement comme hors du groupe |
| Arrivée en cours de combat | participant immédiatement, sans délai |

L'élection retient le plus grand effectif, pas la majorité absolue : un groupe
de dix réparti 4/3/3 a bien un conteneur élu.

## 3. Cycle de vie de la jauge

| Règle | Valeur |
|---|---|
| Propriétaire | le groupe, jamais le conteneur ni un joueur |
| Changement de conteneur élu | la jauge suit, sans réinitialisation |
| Aucun conteneur n'atteint le plancher | pause : ni remplissage ni usage, montant conservé |
| Reprise après pause | le montant d'avant la pause est retrouvé à l'identique |
| Décroissance | aucune, jamais |
| Contribution du dernier instant | conservée même si le joueur vient de quitter le conteneur |
| Fin de vie | dissolution du groupe, ou redémarrage du serveur |
| Persistance en base | aucune |

## 4. Remplissage

Trois catégories, chacune un facteur configurable dans le `.conf` du module. Le
facteur multiplie une valeur **normalisée**, non la valeur brute, afin que la
jauge se comporte identiquement à tous les niveaux et à tout équipement.

| Clé de configuration | Quantité multipliée |
|---|---|
| `heal` | soin effectif rapporté aux points de vie maximaux du soigné |
| `DamageTaken` | dégâts nets subis rapportés aux points de vie maximaux de la victime |
| `DamageDone` | dégâts nets infligés rapportés aux points de vie maximaux de l'attaquant |

Le dénominateur de `DamageDone` est l'attaquant et non la cible : rapporté aux
points de vie de la cible, un coup sur un boss de trente millions de points de
vie ne compterait pour rien alors qu'un coup sur un sbire compterait pour la
moitié de sa barre, et la jauge se remplirait sur les sbires en restant figée sur
les boss.

Seuils cumulés : `GaugeThreshold_1` à `GaugeThreshold_4`, exprimés en points.

Le barème est relisible sans redémarrage du serveur.

## 5. Paliers

- **3 segments**, en nombre constant, indépendants de l'effectif présent.
- **4e segment** : ouvert à l'engagement d'un boss figurant dans une liste
  dédiée, refermé à la mort ou à la réinitialisation de ce boss. La progression
  déjà acquise dans les trois premiers segments est conservée. Il donne un effet
  propre, distinct du palier 3.

## 6. Choix des effets par le joueur

- Interface dédiée, intégrée au HUD.
- Le joueur choisit **un sort par palier**, soit quatre choix.
- Chaque choix se prend dans un **archétype ouvert à sa classe**, et l'archétype
  peut différer d'un palier à l'autre.
- Archétypes : soin, dégâts physiques, dégâts magiques, tank. Exemples posés :
  un prêtre accède à soin et dégâts magiques, un druide aux quatre.
- Modifiable hors combat, sans limite et sans coût. Refusé en combat.
- Les choix sont sauvegardés dans la base des personnages et revalidés côté
  serveur à chaque réception.

La route native — un talent custom par arbre, donc un archétype par arbre — a été
étudiée et écartée : un point de talent exprime un seul archétype pour les quatre
paliers, et ne permet pas d'en changer librement hors combat.

## 7. Déclenchement et dépense

- Par un bouton du HUD. Le serveur exécute l'effet.
- Aucun sort n'a besoin d'exister côté client pour que le lancement fonctionne.
- Le HUD n'expose que le sort du **palier atteint** : à 2,5 segments, seul le sort
  du palier 2 est présenté, celui du palier 1 n'est plus proposé, celui du palier
  3 pas encore.
- L'usage **remet la jauge à zéro**, quel que soit le dépassement : à 2,5, le
  demi-segment excédentaire est perdu avec le reste.
- Un seul usage à la fois pour le groupe.
- Si le joueur n'a choisi aucun sort pour le palier atteint, l'emplacement
  d'action présente à la place un bouton d'ouverture de l'interface de sélection.
  Ce bouton est grisé en combat, comme l'emplacement d'action.

## 8. PlayerBots

- Alimentent la jauge exactement comme les joueurs, par les mêmes hooks.
- Ne la dépensent jamais : ni bouton, ni logique d'usage.

## 9. Affichage

- HUD dédié, barre segmentée, poussée aux participants du conteneur élu.
- La barre est toujours affichée, indépendamment de l'état des choix du joueur.
- Cadence de rafraîchissement fixe et volontairement basse, jamais une diffusion
  par coup porté.

## 10. Architecture retenue

Trois phases qui ne se chevauchent jamais, donc **aucun verrou nulle part**.
C'est la propriété la plus importante du module : `MapUpdate.Threads = 8` en
production, et l'état partagé n'est jamais touché par deux threads à la fois.

| Phase | Où elle tourne | Ce qu'elle fait |
|---|---|---|
| A. Recensement et accumulation | dans chaque map, son propre thread | compte les membres de chaque groupe présents par conteneur, dans une table propre à la map ; les hooks de dégâts et de soins n'écrivent que dans un compteur propre à chaque joueur |
| B. Dépouillement | `WorldScript::OnUpdate`, thread monde, alors qu'aucune map ne tourne | élit le conteneur, récolte les compteurs, applique le barème, calcule les paliers, publie la liste des participants |
| C. Diffusion | même passage | pousse le HUD aux participants |

Répartition en couches :

| Couche | Contenu |
|---|---|
| Module C++ | recensement, élection, jauge, paliers, exécution des effets |
| SQL base monde | barème par défaut, catalogue archétype × palier → sort, archétypes ouverts par classe, liste des boss du 4e segment, lignes `spell_dbc` |
| SQL base personnages | les quatre choix de chaque joueur |
| Lua et AIO, ou addon dédié | HUD, barre segmentée, interface de sélection, bouton |
| Patch client | finition seulement : nom, icône et infobulle des auras posées sur les alliés, lisibilité du journal de combat. Détachable et repoussable |

Bloc d'identifiants de sorts : **10 000 000 et au-delà**.

## 11. Sécurité du canal client

`/run` et `/script` sont des commandes standard du client 3.3.5 : n'importe quel
joueur peut appeler le gestionnaire du HUD avec les paramètres qu'il veut, sans
client modifié. La réponse n'est pas de valider ce que le client envoie, mais de
**ne rien lui demander**.

La requête de déclenchement ne porte aucun paramètre. Le serveur recalcule tout à
la réception : le groupe du joueur, le conteneur élu et la présence du joueur dans
ce conteneur, le palier atteint, le sort enregistré pour ce palier, et la
disponibilité. Un appel forgé ne peut donc rien faire d'autre que ce que fait le
bouton.

La requête de sélection porte, elle, le palier et le sort choisis : le serveur
revérifie que ce sort appartient à ce palier, que son archétype est ouvert à la
classe du joueur, et que le joueur est hors combat.

Le flood par macro est à rejeter côté module avant tout travail, en complément du
limiteur de trafic addon que le cœur applique déjà.

## 12. Annexe technique — points d'appui vérifiés dans le cœur

Références relevées dans `azerothcore-wotlk` et dans la configuration de
production le 2026-09-19.

| Besoin | Point d'appui | Emplacement |
|---|---|---|
| Alimentation par les soins | `UnitScript::OnHeal`, appelé avec le gain effectif, surplus de soin exclu | `UnitScript.h:61`, `Unit.cpp:8124-8126` |
| Alimentation par les dégâts | `UnitScript::OnDamage`, appelé avec les dégâts nets après réduction et absorption ; un seul appel sert les deux lectures | `UnitScript.h:64`, `Unit.cpp:999` |
| Cycle de vie du groupe | `GroupScript` : création, ajout, retrait, changement de chef, dissolution | `GroupScript.h:48-64` |
| Effectif et membres | `Group::GetGUID`, `isRaidGroup`, `GetMembersCount`, `GetMemberSlots` ; `MAXRAIDSIZE 40` | `Group.h:223-254`, `Group.h:45` |
| Recensement par map | `Map::GetPlayers()` | `Map.h:334` |
| Zone, sans coût | `WorldObject::GetZoneId()` rend une valeur mise en cache, recalculée seulement après un déplacement | `Object.cpp:3166-3172` |
| Clé du conteneur | `Map::GetId`, `GetInstanceId`, `Instanceable` ; `InSamePhase` | `Map.h:233`, `:269`, `:297`, `Object.h:517-519` |
| Arbitrage sans verrou | `MapMgr::Update` planifie toutes les maps puis appelle `m_updater.wait()` ; le hook monde est appelé ensuite, aucune map active | `MapMgr.cpp:273-280`, `World.cpp:1245` puis `:1346`, `WorldScript.h:71` |
| Un thread par map | les instances filles sont mises à jour dans l'appel du parent | `MapInstanced.cpp:44-57` |
| Résolution d'un joueur sans verrou global | `ObjectAccessor::GetPlayer(Map const*, guid)`, là où `FindPlayer` passe par un verrou partagé | `ObjectAccessor.h:72`, `:57` |
| Verrou de combat | `Unit::IsInCombat()` | `Unit.h:936` |
| Sorts sans patcher de DBC serveur | table `spell_dbc` | `DBCStores.cpp:371` |
| Barème réglable à chaud | `WorldScript::OnAfterConfigLoad`, précédent dans Attriboost | `WorldScript.h:53`, `Attriboost.cpp:954` |
| Requêtes client dans le thread monde | `CMSG_MESSAGECHAT` est `PROCESS_THREADUNSAFE`, donc traité dans `World::UpdateSessions()` : deux joueurs qui appuient en même temps sont traités l'un après l'autre | `Opcodes.cpp:280`, `Opcodes.h:1369` |
| Canal de contrôle natif | `AddonChannelCommandHandler` analyse les messages du canal addon comme des commandes et répond sans les afficher au joueur | `Chat.h:286-294`, `ChatHandler.cpp:300-303` |
| Limiteur de flood addon | `Player::ChatFloodThrottle::ADDON`, distinct de celui de la discussion | `ChatHandler.cpp:249` |
| Messages addon depuis le C++ | `ChatHandler::BuildChatPacket` avec `CHAT_MSG_ADDON` et `LANG_ADDON` | `Chat.h:51` |
| Canal client déjà déployé | AIO serveur et client, précédent du HUD Mythic+ : barre `StatusBar` alimentée par une diffusion par membre | `lua_scripts/AIO_Server`, `Mythic_Client.lua:950`, `Mythic_Server.lua:1850` |

Deux contraintes de production relevées au passage :

- `MapUpdate.Threads = 8` : c'est ce qui rend l'architecture en trois phases
  nécessaire plutôt que confortable.
- `LeaveGroupOnLogout.Enabled = 0` : un joueur déconnecté reste dans le groupe,
  chef compris, et la promotion automatique n'a lieu que s'il quitte réellement le
  groupe. `GroupMgr.cpp:104` recharge par ailleurs les groupes au démarrage, donc
  un groupe survit à un redémarrage alors que la jauge, non persistée, disparaît.
  C'est ce qui a condamné le schéma ancré sur le chef.

Piège de dimensionnement : les magasins DBC sont des tableaux plats dimensionnés
par le plus grand identifiant (`DBCStore.h:69` et `:91`), et `SpellMgr` en alloue
un second de même taille (`SpellMgr.cpp:3027`). Un identifiant à dix millions
coûte de l'ordre de 80 Mo par magasin. Pour les sorts la dépense est déjà faite,
les sorts d'armes existants montant à 8 340 210 ; il ne faut en revanche jamais
placer un talent ou un objet dans cette plage.

## 13. Justification du custom

Règle du cœur d'abord : tout ce que le cœur sait faire passe par le cœur, et ce
qui reste doit être justifié.

| Élément custom | Pourquoi le cœur ne suffit pas |
|---|---|
| La jauge partagée et sa machine à états | WoW n'a aucune notion de ressource de groupe : tous les types de puissance sont par unité, sans partage ni diffusion |
| L'élection du conteneur | le cœur n'a aucune notion de « là où se trouve la majorité du groupe ». Les briques employées sont toutes natives — itération des membres, zone, phase, instance — seule la règle d'élection est nouvelle |
| Le choix par palier et son stockage | la route native existait et a été écartée en connaissance de cause : un talent exprime un archétype unique pour les quatre paliers, alors que l'exigence est un archétype par palier, modifiable librement hors combat |
| Le HUD segmenté | le client n'a pas de cadre pour une ressource de groupe ; l'option la plus proche, une aura à cumuls, ne montre ni le remplissage continu ni un emplacement d'action par palier |
| Le 4e segment conditionné à une liste de boss | aucun équivalent natif |

Aucune modification du cœur n'est nécessaire.

## 14. Conséquences connues et assumées

- **Le barème est le seul levier d'équilibrage.** Sans décroissance et sans remise
  à zéro, seuls l'usage et un redémarrage vident la jauge. Il n'y a pas de second
  garde-fou.
- **Attendre est toujours meilleur que dépenser.** La jauge étant entièrement
  vidée à l'usage et ne décroissant jamais, un groupe à 2,5 segments a intérêt à
  patienter. Les paliers 1 et 2 ne seront donc utilisés qu'en urgence, et huit des
  seize effets à concevoir risquent de rarement être vus. En FFXIV la même règle
  de vidage existe, mais la jauge y est remise à zéro entre les combats.
- **La pause ne protège rien**, puisque rien ne se perd : elle ne fait que
  suspendre le remplissage et l'usage.

## 15. Décisions retenues faute de réponse explicite

À corriger si elles ne correspondent pas à l'intention.

1. **3 segments dès 4 présents.** Le barème disait « de 5 à 40 joueurs » et le
   plancher a ensuite été fixé à 4.
2. **Dénominateur de `DamageDone` : les points de vie de l'attaquant**, pour la
   raison donnée au paragraphe 4.

## 16. Ce qui reste à déterminer

| Point | Nature |
|---|---|
| Valeurs des trois facteurs et des quatre seuils | réglage |
| Ce qui compte dans le barème : familiers, totems et gardiens, mannequins d'entraînement, dégâts d'environnement, duels, soins sur soi | règle |
| Liste des archétypes ouverts par classe, pour les dix classes | contenu |
| Les 16 effets, soit 4 archétypes × 4 paliers | contenu, poste le plus lourd |
| Liste des boss ouvrant le 4e segment, et difficultés concernées | contenu |
| Temps d'incantation du déclenchement, et son interruptibilité | règle, jamais abordée |
| Affichage du HUD pour un membre hors du conteneur élu : masqué ou grisé | règle, posée puis jamais tranchée |
| PvP sauvage en monde ouvert : les champs de bataille et arènes sont désactivés, mais le PvP en zone contestée alimenterait la jauge | règle, conséquence non tranchée de l'ouverture au monde ouvert |
| Visuels des effets : réutiliser des visuels existants ou en créer | production, impacte le besoin de patch client |
| Interaction avec l'autobalance et le Mythic+ | équilibrage |
| Canal du HUD : AIO, ou addon dédié sur le canal de commandes addon | implémentation |

Aucun de ces points ne remet en cause la faisabilité : ce sont des contenus, des
réglages et trois règles de jeu, pas des mécanismes.

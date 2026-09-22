# Candidats visuels — mod-limit-break

Chemins relevés dans wow.export par l'auteur du serveur le 2026-09-19.
**Ce sont des noms réels**, à la différence des reconstructions proposées
auparavant en conversation, qui sont nulles et non avenantes. 41 entrées.

Aucun de ces modèles n'est encore rétroporté : ils ne figurent ni dans
`mod-spheregrid/data/art`, ni dans le client 3.3.5. Chacun demande la chaîne
complète décrite au paragraphe 12 du cahier des charges — modèle en version 264,
`.skin`, `.blp`, puis `SpellVisualEffectName`, `SpellVisualKit`, `SpellVisual`.

Rappel de piège : dans le DBC le chemin s'écrit avec l'extension `.mdx`, alors que
le fichier livré porte `.m2`.

## Ce que ces noms apprennent sur la convention

- **`_areatrigger` est le suffixe des effets de zone persistants**, le pendant
  moderne de `_state` pour tout ce qui se pose au sol. C'est la famille à
  privilégier pour une Limite, puisque l'effet doit durer.
- `_aura` est le suffixe des effets persistants portés par une unité, `_state`
  celui des états en boucle.
- `_precast`, `_cast`, `_impact` et `_missile` sont brefs par construction. Une
  famille complète se présente souvent en `_precast` + `_cast` + `_state`, comme
  l'orbe de givre de Jaina : les trois voyagent ensemble.
- Le préfixe numérique monte jusqu'à **`12fx`** ; `11fx` est The War Within,
  `8fx` Battle for Azeroth, `7fx` Legion. Beaucoup d'assets récents n'ont
  **aucun préfixe numérique**, juste `fx_`.
- `fxhelpers` et le motif `poolauraez` désignent des **briques génériques
  réutilisables**, pas des effets propres à une rencontre. Ce sont les moins
  risquées à rétroporter et les plus faciles à re-texturer.
- Un nom en `..._areatrigger05` ou `..._felinferno_areatrigger02` désigne une
  variante d'une famille : regarder les voisines avant de choisir.
- **Un suffixe de durée comme `_3s` signale une longueur d'animation figée dans
  le modèle.** La synchronisation du kit doit s'y conformer, et trois secondes
  sont courtes pour une Limite.

## Barrières et dômes — piste tank

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/7fx_tombofsargeras_raid_cathedral_arcaneshield.m2` | grand dôme arcanique à l'échelle d'une salle de raid |
| `spells/fx_aegisofironforge_areatrigger.m2` | égide naine, gravée ; bon candidat pour un palier haut |
| `spells/7fx_lightforged_bunker_shield.m2` | bouclier sanctifié draeneï, plus resserré |
| `spells/fx_lightshield_areatrigger.m2` | bouclier de lumière au sol, sobre |
| `spells/fx_dawnlightbarrier_areatrigger.m2` | barrière de lumière posée au sol, persistante |
| `spells/fx_barrierblossom_areatrigger.m2` | barrière qui s'ouvre en corolle ; la plus décorative du groupe |

## Auras persistantes — piste tank, soin, magique

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/12fx_thevoidspire_lightblindedvanguard_auraofwrath_aura.m2` | aura de courroux ; forme une paire avec la suivante |
| `spells/12fx_thevoidspire_lightblindedvanguard_auraofpeace_aura.m2` | aura de paix ; la paire courroux/paix couvre à elle seule un couple dégâts/soin, avec une cohérence visuelle gratuite |
| `spells/fx_corebreach_aura.m2` | aura de rupture, tons chauds |
| `spells/fx_latentcultist_areatrigger.m2` | zone d'aura cultiste, persistante |

## Bassins et nappes au sol — piste soin et magique

Les trois sont des briques génériques, donc les plus rentables du lot.

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/fx_fxhelpersdawnwell01poolauraez_aura.m2` | bassin de lumière |
| `spells/fx_fxhelpersvoidspire01poolauraez_aura.m2` | bassin de Vide |
| `spells/fx_120darkwellfxchickenpoolauraez_aura.m2` | bassin sombre |

## Lumière — piste soin

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/fx_burstinglightshard_areatrigger.m2` | éclats de lumière qui jaillissent, zone persistante |
| `spells/11fx_arathor_areatrigger05.m2` | zone d'inspiration arathie ; variante numérotée, voir ses voisines |
| `spells/sunwell_beamfx_3s.m2` | faisceau du Puits de soleil ; durée figée à trois secondes, donc à enchaîner ou à réserver à une amorce |

## Givre — piste magique, et tank pour l'anneau

Famille complète, avec amorces et état : le meilleur ensemble cohérent du
catalogue pour un archétype entier.

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/8fx_jaina_frozenorb_state.m2` | orbe de givre en boucle ; le seul `_state` de la famille, donc le porteur du palier |
| `spells/8fx_jaina_frozenorb_precast.m2` | amorce de l'orbe |
| `spells/8fx_jaina_ringoffrost.m2` | anneau de givre au sol, persistant par nature ; lisible aussi en défensif |
| `spells/8fx_jaina_glacialray_precast.m2` | amorce de rayon glacial |
| `spells/8fx_jaina_icefall_precast.m2` | amorce de chute de glace |

## Vide et dévoration — piste magique, paliers hauts

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/cfx_priest_entropicrift_areatrigger.m2` | faille entropique, très lisible et conçue pour durer |
| `spells/11fx_accretiondisk_areatrigger.m2` | disque d'accrétion en rotation ; le plus spectaculaire du catalogue |
| `spells/fx_devouringcosmos_areatrigger.m2` | dévoration cosmique, la plus ample des trois dévorations |
| `spells/11fx_devour_areatrigger.m2` | zone de dévoration |
| `spells/11fx_devour_areatrigger01.m2` | variante de la précédente |
| `spells/7fx_soulengine_soulwrap.m2` | enveloppement d'âmes ; pas de suffixe, à prévisualiser pour savoir s'il boucle |
| `spells/fx_voidtest_areatrigger01.m2` | **asset de test** : à prévisualiser avant tout engagement, il peut être inachevé, mal texturé ou dépourvu de ses `.skin` |

## Fel, arcane et temporel — piste magique

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/11fx_felinferno_areatrigger02.m2` | brasier gangrené, vert ; variante numérotée |
| `spells/7fx_tombofsargeras_councilstar01.m2` | étoile du Conseil, motif géométrique au sol |
| `spells/7fx_deathtitan_temporalblast_cast.m2` | déflagration temporelle |
| `spells/7fx_deathtitan_temporalblast_precast.m2` | son amorce |

## Génériques de longue durée — utilisables partout

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/11fx_longdamagevisualareatrigger_areatrigger.m2` | littéralement un visuel de dégâts de zone de longue durée ; le candidat le plus directement aligné sur le besoin |

## Impacts, amorces et projectiles

Brefs par construction. Ils ne tiennent pas un palier seuls, mais servent
d'amorce, d'impact, ou de motif à répéter — voir la section suivante.

| Fichier | Ce qu'on en attend |
|---|---|
| `spells/7fx_kiljaeden_armageddon_meteor_missile.m2` | météore d'Armageddon ; le meilleur candidat pour une pluie d'artillerie, piste distance |
| `spells/7fx_lightforged_vindicaar_leap_impact.m2` | impact de saut, piste mêlée |
| `spells/7fx_tidalwave.m2` | vague qui balaie ; pas de suffixe, longueur d'animation à vérifier |
| `spells/fx_smash_cast.m2` | écrasement, piste mêlée |
| `spells/7fx_aggramar_flare_precast.m2` | amorce de flamme d'Aggramar |
| `spells/7fx_aggramar_flare_impact.m2` | impact correspondant |
| `spells/fx_cosmeticarcaneteleportin_cast.m2` | apparition arcanique |
| `spells/7fx_darkmoon_forsakenstage_missile.m2` | projectile de foire |

## La persistance peut venir du serveur, pas du modèle

Un modèle bref n'interdit pas un effet qui dure : le script C++ du palier peut
relancer un sort purement visuel à intervalle régulier pendant toute la durée de
la Limite. Une pluie de météores tenue quatre secondes, c'est un
`..._meteor_missile.m2` déclenché huit fois à un demi-intervalle, sur des points
tirés autour de la cible — exactement ce que font les rencontres de raid.

Cela vaut pour les deux archétypes physiques, qui n'ont presque aucun effet
persistant dans le catalogue : **la répétition côté serveur les débloque**, au
prix d'une boucle dans le script et d'aucun art supplémentaire.

## Couverture

| Archétype | État |
|---|---|
| DPS magique | **surservi** : givre, Vide, fel, temporel, plus les génériques |
| Tank | **largement couvert** : six barrières et dômes, de sobre à monumental, plus l'anneau de givre |
| Soigneur | **couvert** : lumière, bassins, aura de paix, barrière en corolle |
| DPS physique mêlée | **à couvrir** : deux impacts et une vague, aucun effet persistant — répétition côté serveur nécessaire |
| DPS physique distance | **à couvrir** : deux projectiles, dont le météore d'Armageddon, aucun effet persistant — répétition côté serveur nécessaire |

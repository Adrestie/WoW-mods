# Mod identifiers moved for CoA

Conquest of Azeroth content keeps its own numbers; a mod identifier it collides with moves inside the mod's own
block (see ID_RANGES.md). Every move is written here.

| Date | Mod | Kind | Old | New | Reason |
|---|---|---|---|---|---|
| 2026-10-29 | UniWoW | item_template, Item.dbc | 82800-82999 | 2363800-2363999 | CoA's Item.dbc fills 82800-82999 |
| 2026-10-29 | UniWoW | ItemDisplayInfo.dbc, itemdisplayinfo_dbc | 82800-82999 | 2363800-2363999 | CoA has 191 rows there |
| 2026-10-29 | UniWoW | Spell.dbc, spell_dbc | 82800-82999 | 2363800-2363999 | CoA's Spell.dbc fills 82800-82999 |
| 2026-10-29 | UniWoW | SpellIcon.dbc | 82800-82999 | 2363800-2363999 | CoA has 82810-82961 (5 rows) |
| 2026-10-29 | UniWoW | CreatureDisplayInfo.dbc, creaturedisplayinfo_dbc, creature_model_info | 82800-82999 | 2363800-2363999 | CoA has 9 rows there |
| 2026-10-29 | UniWoW | GameObjectDisplayInfo.dbc, gameobjectdisplayinfo_dbc | 82800-82999 | 2363800-2363999 | CoA has 82997 |
| 2026-10-29 | UniWoW | SoundEntries.dbc, soundentries_dbc | 82800-82999 | 2363800-2363999 | CoA has 82966 |
| 2026-10-29 | UniWoW | Achievement_Criteria.dbc, achievement_criteria_dbc | 22800-22999 | 38600-38799 | CoA's criteria fill 22800-22999 (16 bits: 98600-98799 less 60000) |
| 2026-10-29 | UniWoW | TaxiNodes.dbc, taxinodes_dbc | 406-437 | 422-437 | CoA takes 406-421 |
| 2026-10-29 | UniWoW | CharTitles bits (Mask_ID) | 182-191, provisional | 172-181, provisional | CoA uses 182-190; Maitre to choose |

Checked on 2026-10-28 for the Barbarian (class 12): its trainer NPCs (50295, 502950-502953,
602950-602953, 650295) collide with no mod and no stock creature (50295 is free in our world; the core update that
mentions 50295 is about an item's koKR name).

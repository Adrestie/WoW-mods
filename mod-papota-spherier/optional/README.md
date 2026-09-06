# Optional patches

Everything in this folder is **outside** the module. The module builds and runs
without any of it; each piece unlocks one behaviour that the Papota server has
and that lives in code the module does not own.

| File | What it does | Needed for |
|---|---|---|
| `core/spell_cast_while_moving.diff` | Lets two class spells cast on the move: the shaman under **Ascendance** (8600062) may cast Lightning Bolt, Chain Lightning and Lava Burst while moving; the warlock under **Cataclysm** (8610012) may cast its two instant Soul Fire / Chaos Bolt while moving. The 3.3.5 client refuses these casts on its own; the check lives in `Spell.cpp`. | The two spells above behave as designed. Without the patch they still work, standing still. |
| `core/periodic_damage_crit.diff` | Lets every periodic **damage** effect of playable classes (and their pets) crit with the spell's real crit chance, instead of the original short list (aura 286 and Rupture). A server-wide gameplay rule of the Papota server, not something the module relies on. | Nothing in the module. Apply only if you want the rule. |
| `mod-dungeon-clear/dungeon_completed_credit.diff` | When the [mod-dungeon-clear](https://github.com/jrad7/mod-dungeon-clear) bot AI finishes a dungeon, credits the `donjon_termine` source to every real player of the group (`SpherierPlayerMgr::CrediterInstance`). | Spherite for completed dungeons when dungeons are run through that module. Boss kills are credited by the module itself, everywhere. |
| `MythicPlus/Mythic_Server_hook.lua` | Snippet for a Mythic+ Lua mod: awards the `mythique_plus` source at the end of a run through `.spherier points source`. | Spherite for Mythic+ runs. |

## Applying a core patch

From the root of your AzerothCore checkout:

```
git apply --check optional/core/spell_cast_while_moving.diff
git apply optional/core/spell_cast_while_moving.diff
```

The diffs were taken against the mod-playerbots fork of AzerothCore
(`efe123fab5`, 2026-08-14). On another revision `git apply` may need
`--3way`, or the two hunks may have to be placed by hand; both are short and
commented (in French) so the intent is clear.

The dungeon-clear diff applies the same way, from the root of that module's
checkout (`4ee502f2`, 2026-08-10). It includes `SpherierPlayerMgr.h`, so
mod-papota-spherier must be present in `modules/` when you build.

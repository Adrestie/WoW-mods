# What the interface draws, and what the grid says

The grid carries CHOICES OF PLAY — where a cell sits, what statistic and what quality it
comes pre-filled with, whether it is a node, a socket or a spell cell. It carries no
presentation at all: no name, no icon.

Presentation belongs to the interface, for one reason: **it depends on the client**. A name
is a language, and an icon is art the client already owns. Storing either in the grid froze
one server's choice into 2 451 rows.

## The name of a cell

| cell | what the interface shows |
|---|---|
| a pre-filled node | `<statistic> (<quality>)` |
| an empty node | its own wording |
| a socket | its own wording |
| a spell cell | `GetSpellInfo(spellId)` — the client knows the spell in its own language |

The quality word comes **from the client itself**: `ITEM_QUALITY1_DESC` through
`ITEM_QUALITY5_DESC` are localized globals of the 3.3.5 client, and the five qualities of
the module line up with them exactly (1 common … 5 legendary). Nothing to translate, and
nothing that can fall out of step with the game.

The statistic names live in the interface, next to the icons below.

## The icon of a cell

Sixteen icons, one per statistic, plus one for a socket. A spell cell shows the icon of its
own spell, which the client resolves; an empty node shows none.

| statistic | icon |
|---|---|
| 1 stamina | `Interface\Icons\Spell_Holy_WordFortitude` |
| 2 intellect | `Interface\Icons\Spell_Holy_MagicalSentry` |
| 3 spirit | `Interface\Icons\Spell_Shadow_Charm` |
| 4 agility | `Interface\Icons\Spell_Holy_BlessingOfAgility` |
| 5 strength | `Interface\Icons\Spell_Nature_Strength` |
| 6 parry | `Interface\Icons\Ability_Parry` |
| 7 block | `Interface\Icons\Ability_Warrior_ShieldWall` |
| 8 dodge | `Interface\Icons\Spell_Magic_LesserInvisibilty` |
| 9 haste | `Interface\Icons\Spell_Nature_BloodLust` |
| 10 critical strike | `Interface\Icons\Ability_CriticalStrike` |
| 11 hit | `Interface\Icons\Ability_Hunter_SniperShot` |
| 12 spell power | `Interface\Icons\Spell_Fire_FlameBolt` |
| 13 attack power | `Interface\Icons\INV_Sword_04` |
| 14 armour penetration | `Interface\Icons\Ability_Rogue_Ambush` |
| 15 expertise | `Interface\Icons\Ability_Warrior_WeaponMastery` |
| 16 bonus healing | `Interface\Icons\Spell_Holy_HolyBolt` |
| — a socket | `Interface\ItemSocketingFrame\UI-EmptySocket` |

They are borrowed from the game, so they exist in every 3.3.5 client and no art has to be
shipped. A server that wants its own edits the interface: it is Lua, sent from the server,
so nothing has to reach the players by any other means.

## The order of the statistics is a contract

The index 1..16 above is what the whole module means by "a statistic". It appears in the
stone entries (a stone of statistic 5 sits five slots into the allocation), in the aggregated
blocks, and in the `stone_stat` column of the grid. **Inserting a statistic in the middle
renumbers every stone**: append, never insert.

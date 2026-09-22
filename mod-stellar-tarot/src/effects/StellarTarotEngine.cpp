/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * mod-stellar-tarot — the engine: the families of scripts the design
 * workbook's conditions map onto.
 *
 *   cond:<state>[:n]
 *       The level's spell is applied while the state holds and removed when
 *       it stops; checked every second and on combat changes. States:
 *       shield, twohand, dualwield, unarmed, solo, night, day, dawn_dusk,
 *       combat, nocombat, rested, water, charmed (feared or charmed),
 *       still:<sec>, walking:<sec> (moving, out of combat, for that long),
 *       running:<sec> (moving WITHOUT STOPPING for that long and without
 *       taking a blow, in combat or not: standing still wipes the count, and
 *       so does a direct blow, the aura falling whole with it; the tick of a
 *       periodic effect is not a blow -- the core announces it by another
 *       road),
 *       mounted:<sec>,
 *       hp_below:<pct>, hp_above:<pct>, mana_below:<pct>, gold_above:<copper>,
 *       hour:<from>:<to>. Then, optionally, and:<state>: a SECOND state held at
 *       the same time -- night, day, combat, nocombat, solo, rested, water,
 *       indoors, outdoors; the last two are second states ALONE, never the
 *       first, a card asking for one by itself being refused at load;
 *       stacks:<k>: a stack per period of the state, up to k
 *       (still:5:stacks:5); tick:<sec>:<action>:<n>: that small action while
 *       the state holds -- heal, mana, heal_both, repair; rating:<pct>: the
 *       aura carries that share of the COMBAT RATINGS the player wears, one
 *       effect per rating the spell names, read again while the state holds.
 *
 *   proc:<event>:<chance>:<icd>:<action>[:<params>]
 *       On the event, with that chance (percent) and no more often than the
 *       internal cooldown (seconds), the action. Events: kill, kill_boss,
 *       kill_elite, kill_humanoid, hit, hit_melee, hit_weapon (a blow of the
 *       weapon itself), hit_spell, dmg_taken,
 *       spell_cast_school:<school mask> (a spell of that school),
 *       dmg_taken_phys, dmg_taken_magic, spell_cast, spell_cast_dmg (a spell
 *       that deals damage), spell_cast_heal, spell_cast_id:<spell> (that one
 *       spell and no other), spell_cast_row:<n>:<sec> (the player's n-th spell
 *       in a ROW, the run broken by that many seconds during which he casts
 *       nothing at all; the count starts over as soon as the line fires),
 *       spell_cast_timed (a spell WITH A CAST TIME, as the
 *       caster's own haste and modifiers leave it: one the module has just made
 *       instant is not one), heal, heal_ally,
 *       enter_combat, leave_combat, nocombat:<sec> (THAT LONG SPENT OUT OF
 *       COMBAT: the count runs while the player fights no one and the line fires
 *       once it is full; entering combat sets it to zero AND re-arms the line,
 *       so a single peace gives the boon but once),
 *       levelup, resurrect, zone, quest,
 *       ally_low:<yards>:<pct> (AN ALLY WITHIN REACH IS IN DANGER: a friendly
 *       unit -- a companion, a pet, anyone the player would not strike -- stands
 *       under that share of his health within that many yards. The count is
 *       taken every second, and the line's own cooldown says how often the
 *       sentinel may answer),
 *       death_near:<yards> (a creature dies within that many yards, whoever
 *       killed it -- the core tells only the killer, the module finds the
 *       witnesses), enter_instance (the player steps into a dungeon or a raid),
 *       dmg_taken_back (a blow from behind), tick:<sec> (in combat), every:<sec>, hp_below:<pct> (when crossed),
 *       mana_below:<pct>, wand (a wand shot lands -- a second shot a card
 *       granted included, except for the line that granted it), vendor_buy
 *       (something bought from a vendor), repair (a repair about to be paid),
 *       flight_end (a taxi has just set the player down; watched every second,
 *       the core announcing nothing), loot_creature (a creature's loot is being
 *       filled -- what a card adds goes in the corpse, not in the bags),
 *       vendor_sell (something sold to a vendor: the sum follows), loot_gold
 *       hit_ranged (a blow of a RANGED weapon -- a shot, whatever spell carries
 *       it: the core sorts a spell by its damage class, and that class says
 *       ranged),
 *       (coin taken from a corpse or a chest), pet_hit (THE PET LANDS A BLOW --
 *       the master's own cards answer for it), jump (a jump, wherever and
 *       whenever), jump_combat (a jump in combat and nowhere else),
 *       death (the player's own death), dismount:<sec> (the player gets off his
 *       mount after riding at least that long; the count is kept second by
 *       second, the core announcing nothing),
 *       fever (THE PLAYER SUFFERS A BEAT OF HIS OWN FEVER -- the debuff the
 *       `fever` family lays, whichever of its four spells it is),
 *       spin:<turns>[:left|right] (THAT MANY FULL TURNS ON HIMSELF, the way the
 *       line names or either way when it names none, however
 *       fast, however done: the module adds up the turning that the movement
 *       packets announce -- all the server ever sees of it -- and the line fires
 *       at that many whole turns. EVERY bit of turning counts, both ways alike,
 *       however small, and nothing is forgotten with time. Turned BY KEY, the
 *       count follows the player's own turn rate for as long as the key is held
 *       -- the client announces its facing only as the key goes down and as it
 *       comes back up; turned by MOUSE, the angles themselves are read. THE TURN
 *       IS DONE ON THE SPOT: a step aside is the only thing that starts the
 *       count over),
 *       no_spend:<sec> (the player has SPENT NOTHING for that long: gold handed
 *       to a VENDOR -- a purchase, a repair -- or to the AUCTION HOUSE -- a
 *       deposit, a bid, a buyout -- puts the count back to zero, while the post,
 *       the taxi and the trainer are no spending at all; the count starts over
 *       as soon as the line fires).
 *       Actions: aura:<sec>:<stacks> (the level's spell, for that long, stacking
 *       up to that many), heal:<pct of max>, mana:<pct of max>, heal_both:<pct>,
 *       restore, leech:<pct of the damage> (hit events), gold_level:<copper x
 *       level>, silver_level:<silver x level>, damage_sp:<pct>:<school>,
 *       damage_ap:<pct>:<school>, hp_dmg:<pct>:<school> (of the PLAYER'S max
 *       health, on the other unit), extra:<pct>:<school> (of the damage dealt;
 *       school 0 or absent: the school of the blow itself),
 *       turn_ally:<sec>[:<yards>] (the same, but the creature becomes the
 *       player's ALLY for that long -- it fights its own and he can no longer
 *       strike it), turn:<sec>[:<yards>] (the creature struck goes over to the player's side
 *       for that long and falls on the nearest of its own -- a faction, not a
 *       charm: the player is given no hold over it; nothing happens when it
 *       stands alone), root:<sec>, stun:<sec>, bleed:<sec>:<pct of attack power per tick> (the
 *       other unit of a hit or kill event),
 *       bleed_hit:<sec>:<pct of the blow a tick>:<spell> (THE SAME WOUND, but
 *       measured on the blow that opened it, and wearing the spell named at the
 *       end -- whose tooltip says the share),
 *       mana_pm:<thousandths of max mana>,
 *       extra_shot (a second shot of the wand -- the module's own copy of Shoot,
 *       three times as fast, set apart by its identifier so that a granted shot
 *       never grants another), extra_copy (one more of what was just bought,
 *       for nothing), free_repair (the repair costs nothing), crate (the
 *       module's crate of goods, laid in the corpse; what it holds is drawn
 *       when it is opened -- see StellarTarotLoot::FillCrate), grey_item (one
 *       more grey trinket in the corpse), gem (a RARE GEM in the corpse, the
 *       one the place calls for: the Azerothian Diamond on the old world, an
 *       epic uncut gem of Outland or of Northrend where the map belongs to
 *       them), gold_mult:<n> on vendor_sell (the
 *       vendor pays that many times).
 *       AND ALSO: none (the line does nothing beyond the aura it already
 *       carries), aura_target:<sec>:<stacks> (that same aura, laid on the
 *       OTHER unit), aura_group:<sec>:<yards> (on every member of the group in
 *       range), heal_group:<pct of each one's max>:<yards>,
 *       heal_ally_amount:<pct of the amount>:<yards> (the most injured member,
 *       the one just healed left out), heal_pet:<pct of the pet's max>:<pct of
 *       the player's>, leech_pet:<pct of the damage> (THE PET is healed by that
 *       share of the blow), aura_pet:<sec>:<stacks> (the level's aura is laid ON
 *       THE PET, the master being the caster -- so a figure written per level
 *       follows the MASTER'S level), shield_self:<pct of max health>:<sec> (15 seconds when
 *       the figure is 0), shield_target:<pct of the amount>:<sec>,
 *       shield_ally:<pct of his max>:<yards>:<sec> (the most injured member),
 *       shield_group:<pct>:<yards>:<sec>, copper_per_damage:<copper a point>,
 *       splash:<pct of the amount>:<yards> (around the victim),
 *       cleave:<pct>:<yards> (before the player alone),
 *       explode:<pct of the victim's max health>:<yards> (never on a boss),
 *       explode_sp:<pct of spell power>:<yards>:<school> (arcane by default),
 *       fear:<sec>, sleep:<sec>, silence:<sec>, disorient:<sec>,
 *       immune_snare:<sec> (on the player himself), knockback:<yards>,
 *       blink:<yards>:<0 backwards, 1 any way>, burn:<sec>:<pct of the blow a
 *       tick>, recast (the spell just cast goes off again),
 *       mirror:<pct of the damage> (THE SPELL ITSELF GOES OFF AGAIN at once, on
 *       the same victim -- its own images, its own school, its own log -- and
 *       the blow it lands is brought back to that share of the first; the mirror
 *       never mirrors itself),
 *       cooldowns:<sec> (every cooldown of the player shortened by that much),
 *       reset_cooldowns:<sec> (those with less than that left are cleared),
 *       resurrect:<pct of max health> (he rises where he fell),
 *       repair:<pct>, repair_one:<pct> (one piece), repair_all (everything, for
 *       nothing), refund:<pct of what was really paid> on vendor_buy.
 *       THE STATES -- next_crit, next_sure, next_instant, free_next, cost_next
 *       -- promise the NEXT blow or the next cast. Their aura holds until it is
 *       spent, not for a while; what the line costs (`but:`) is paid at that
 *       moment and not before, so a promise that is never kept costs nothing.
 *       Then, optionally, trigger:<spell>:
 *       the passive aura the core's proc system fires the event through (the
 *       events crit, spell_crit, spell_crit_fire (a spell of fire), heal_crit,
 *       dodge, parry, block, crit_taken,
 *       miss come that way, as MARKER spells the core casts). Then also
 *       then:<figure>:<sec>[:<spell>] (WHAT COMES AFTER: when the level's aura
 *       falls, that other aura -- its own spell, so that a boon may be followed
 *       by a bane -- is laid at that figure for that long -- a sequence, not a
 *       loop; what comes back is the event, not the sequence, and the line will
 *       not re-arm while one is running),
 *       sign:<spell> (THE SIGN THAT THE LINE IS ARMED, shown to the player: that
 *       aura is laid, without duration, as soon as the condition is met, and
 *       taken off when the line fires -- the boon speaks in its place),
 *       count:<spell> (THE TALLY OF A RUN, shown to the player: that aura is
 *       laid at one stack per event and taken off when the line fires or the
 *       run breaks -- so the last event of the run shows nothing, the reward
 *       being there instead),
 *       debuff:<spell> (THE REVERSE AS AN AURA OF ITS OWN: that spell is laid on
 *       the player beside the boon, with the same duration and the same stacks,
 *       but ranged among the debuffs and carrying its own words -- for a line
 *       whose drawback must be READ and not merely suffered),
 *       core:chance[:icd] (the CORE holds that part of the line: spell_proc
 *       carries the chance and the cooldown, and the line stops drawing for
 *       it),
 *       rating:<pct> (the aura the action lays carries that share of the
 *       COMBAT RATINGS the player wears -- haste, crit, hit, parry, dodge,
 *       block, armour penetration, defence, expertise -- one effect per rating
 *       the spell names, the aura's own share taken out first),
 *       sp:<pct> (the aura the action lays carries a SPELL POWER read as that
 *       percentage of the player's own at the moment it is laid -- the aura's
 *       own share taken out first, so that it never compounds; as with cond),
 *       say:<string> (the line says THAT sentence of the module's own texts
 *       instead of the one its action would say), emote:<gesture> (the player
 *       plays it when the line falls -- 11 is a laugh),
 *       but:<kind>:<n>[:<n2>][:<spell>] -- THE REVERSE of the line, which the
 *       player suffers himself: hp:<pct>, mana:<pct>, stun, silence, sleep,
 *       disorient, root:<sec>, taken:<pct>:<sec>, armor:<pct>:<sec>,
 *       burn:<pct>:<sec>, burn_s:<pct>:<sec>[:<spell>] (the same, A TICK EVERY
 *       SECOND, under a debuff of its own -- the spell named at the end, whose
 *       tooltip says the share; without one, the module's common burning),
 *       self_hit:<pct of the blow>; taken and armor may name
 *       the MARK spell that tells the client the figure, two cards taking
 *       different shares being unable to share one. cost: says the same thing,
 *       the word from before. chance:<n>: the drawback's own chance, the boon
 *       being kept whole,
 *       night:<n> (the action's figure between 21:00 and 06:00), onlynight
 *       (nothing happens by day) and onlydark (nothing happens by day OUT OF
 *       DOORS -- the night or a roof).
 *
 *   dmgmod:<target condition>[:n]:<pct>[:<school>]
 *       A school mask at the end limits it to that school (absent: all).
 *       The damage the player deals is changed by pct when the target meets
 *       the condition: stunned, alone, hp_above:<pct>, hp_below:<pct>, full_hp,
 *       humanoid, range_over:<yards>, slowed, burning.
 *
 *   wandmod:<chance>:<pct>[:hp_below:<n>]
 *       What a WAND SHOT deals -- a granted second shot included -- changed by
 *       pct with that chance, and only when the target is under that share of
 *       health, when one is named.
 *
 *   takenmod:<condition>:<pct>[:<school>]
 *       The damage the player takes is changed by pct: alone (one attacker),
 *       controlled (stunned, rooted, feared, confused), charmed (feared or
 *       charmed -- the mind taken from him, and nothing else), back (the blow
 *       comes from BEHIND him, outside the half-circle he faces).
 *
 *   convoy:<sec>:<stacks>:<yards>
 *       THE COLUMN ON THE MARCH. While the bearer RIDES AND MOVES, the level's
 *       aura sits on him and on his own within that many yards -- alone, it is
 *       his only -- and gains a stack every <sec> seconds, up to <stacks>. The
 *       aura has NO DURATION: it comes off at once when he stops, when he leaves
 *       the saddle -- willingly or not -- or when a blow lands on him (the tick
 *       of a periodic effect is not a blow). Whoever falls out of range loses it
 *       at the next beat. Two bearers do not add up: the aura is one, the last
 *       to lay it holds it.
 *
 *   gempct:<pct>
 *       WHAT THE GEMS GIVE, and that much again. Every statistic the gems set
 *       in the player's gear hand him is added up, and he is given that percent
 *       more, applied the way the core applies an item's own -- so his sheet
 *       shows it. A meta gem's special power is no statistic and is left out.
 *       The total is read at every beat: changing a piece or setting a gem
 *       shows within the second.
 *
 *   seal:<sec>:<pct>:<n>:<spell>
 *       THE SEAL. A spell of the player's that strikes a target bearing no seal
 *       lays his own on it for that many seconds; each spell of HIS that strikes
 *       it after that adds a stack -- the seal answers only the hand that laid
 *       it -- and the n-th strike hits that many percent harder and breaks the
 *       seal. Every strike puts the seconds back to full.
 *
 *   sp_pct:<pct>[:night:<pct>]
 *       The level's spell carries a flat spell power (damage and healing)
 *       recomputed every second as pct of the player's current spell power.
 *       A night percentage takes over between 21:00 and 06:00.
 *
 *   schoolsp:<pct>:<school>[:<pct>:<school>...]
 *       A SHARE OF THE SPELL POWER, SCHOOL BY SCHOOL. The level's spell carries
 *       one MOD_DAMAGE_DONE effect per school named, and each is given that
 *       percentage of the spell power the player wears -- the share already
 *       given taken out first, so that it never compounds -- recomputed every
 *       second. The character sheet then shows it in that school's bonus
 *       damage, which a percentage of damage done never does. A negative
 *       percentage takes away.
 *
 *   secondpct:<pct>[:<spell>...]
 *       The SECONDARY statistics, in percent -- haste, crit, hit, attack power,
 *       spell power, block, parry. Eight auras are needed and a spell carries
 *       three, so the level lays its own spell and the companions the generator
 *       made for it.
 *
 *   ratingpct:<pct>
 *       A RATING as a share of itself: the level reads the rating the player
 *       already wears, takes that percent of it and hands it back in points.
 *       The ratings touched are the ones the spell names, one MOD_RATING
 *       effect each, its mask saying which. Recomputed every second.
 *
 *   stat:<day>:<night>
 *       The level's aura, with the figure it takes by day and the one it takes
 *       by night; every effect of the spell gets that figure.
 *
 *   statcond:<state>[:<n>]:<outside>:<inside>
 *       The same, but the figure follows a STATE rather than the hour:
 *       hp_below:<pct>, hp_above:<pct>, mana_below:<pct>, combat, nocombat,
 *       solo, night, day.
 *
 *   costmod:heal_low:<hp pct>:<discount pct>
 *   costmod:heal_self:<discount pct>
 *       A heal costs that much less mana -- on a target under that share of
 *       health for the first, on the player HIMSELF for the second. The core
 *       takes the cost AFTER this hook, so the share comes back on the next
 *       update, given by the level's own spell so that the player SEES it; the
 *       figure the client shows before the cast does not move.
 *
 *   fever:<share>:<worsened share>:<four spells>:<spell of the level that
 *         worsens>:<spell of the level that quickens>
 *       THE FEVER, A LEVEL THE OTHERS CHANGE. While the player is IN COMBAT he
 *       carries a debuff of his own that takes that share of his maximum health
 *       at every beat -- an exact share: the spells carry the attributes that
 *       keep the caster's power and the target's resistance out of the count.
 *       Four spells are named, one for each pair of share and beat, and the line
 *       lays the one the card calls for: the worsened share while the level that
 *       worsens it is laid, the quicker beat while the level that quickens it
 *       is. Out of combat the fever falls.
 *
 *   drink:<pct>
 *       WHAT A DRINK GIVES BACK, raised by that much. A drink is known by its
 *       shape -- a regen effect and a periodic dummy carrying the figure -- and
 *       it is that figure the line raises as the aura is laid; the core copies
 *       it into the regen at the first tick. The mana then comes as REGEN, so
 *       nothing floats above the head: the bar simply fills faster. Food gives
 *       health, not mana, and is left alone.
 *
 *   potion:<pct>
 *       WHAT A POTION GIVES, and that much again. As the flask is raised, every
 *       heal and every draught of mana the potion promises is read from ITS OWN
 *       figures and that share handed to the player on top -- the way the core
 *       serves the alchemist's stone, which cannot know the rolled amount
 *       either. A potion is the item's own kind: elixirs and flasks are none.
 *
 *   potion_keep:<chance>
 *       A POTION MAY NOT BE SPENT: with that chance, one of the same kind is
 *       put back in the bags as the flask is raised, so the stack never moves.
 *       A full bag spends nothing -- the room is asked for before the chance is
 *       rolled.
 *
 *   elixirlong:<pct>
 *       THE ELIXIRS LAST LONGER: an aura that an ELIXIR lays on the player is
 *       given that much more time as it is laid. The kind is the item's own,
 *       read from the aura itself, so flasks and potions are left alone.
 *
 *   prospect:<chance>[:<least>:<most>]
 *       PROSPECTING PAYS TWICE: with that chance, the ore's own table is drawn
 *       again as the prospecting loot is composed -- once, or between <least>
 *       and <most> times when both are given -- so every extra gem is one the
 *       ore itself could give.
 *
 *   chest_extra:<n>
 *       A chest gives more: its own table is drawn n times over, as the loot
 *       is being composed. The card chooses nothing -- the chest does.
 *
 *   ore:<chance>:<what>
 *       WHAT THE STONE GIVES UP, with that chance. double: the ore a MINING VEIN
 *       has just given is laid in double -- the same ore, twice over, whatever
 *       the vein gave; what is no ore is left alone, and a chest is no vein --
 *       the lock is read, and it must ask for the mining skill. bar: one more of
 *       the bar a SMELTING is about to give. keep: the ore that same smelting
 *       puts to the fire is put back in the bags as it goes, so the stack never
 *       moves. A SMELTING IS KNOWN BY ITS TRADE -- a spell of the mining skill
 *       that creates an item -- for a bar and an ore are of one kind to the
 *       game, and only the trade tells them apart.
 *
 *   fish:<chance>:<what>
 *       WHAT THE LINE BRINGS OUT OF THE WATER, as the fishing loot is being
 *       composed, with that chance. double: the catch is laid in double -- the
 *       same item, twice over -- whatever is no fish being left alone, and the
 *       chance played only when a fish is there. chest: one more of the
 *       containers fishing gives of itself, the one the place calls for -- the
 *       waterlogged crate on the old world, the curious crate in Outland, the
 *       reinforced crate in Northrend. pearl: a pearl, chosen by the place in
 *       the same way.
 *
 *   hearthcd:<pct>
 *       The hearthstone comes back sooner: its cooldown is cut by that share
 *       of its ORIGINAL length, so two levels at -25 and -50 make -75.
 *
 *   shoutlong:<factor>
 *       The player's CRIES -- Shout, Howl, Scream, Roar by their English name --
 *       last that many times longer. A drawback may follow, as on a proc.
 *
 *   stunlong:<sec>
 *       The stuns the player lays last that many seconds longer. A drawback
 *       may follow, as on a proc.
 *
 *   tickmod:<chance>:<pct>[:onlynight]
 *       With that chance, one tick of one of the player's periodic effects --
 *       damage or healing -- counts for pct percent more (100: one tick more).
 *       onlynight: nothing by day.
 *
 *   dotlong:<school>:<ticks>
 *       A PERIODIC effect of that school lasts that many ticks longer, caught
 *       as the aura is laid -- a spell in flight lays it late.
 *
 *   xpkin:<pct>
 *       THE KIN ALREADY AT THE CAP. Every character of the ACCOUNT who has
 *       reached the level cap is worth that much more experience, and the
 *       level's aura shows the tally in its stacks -- one stack a character.
 *       The tally is read from the character database when the card is laid and
 *       again at every level gained; a kinsman who reaches the cap elsewhere is
 *       counted at the next of those.
 *
 *   econ:<kind>:<pct>[:and:<kind>:<pct>][:per_gold:<gold>:cap:<pct>][:<state>]
 *       gold_loot, xp, rep, quest_gold, repair (cost), vendor_buy (price),
 *       vendor_sell (price), vendor_sell_grey (POOR items alone),
 *       vendor_sell_good (UNCOMMON items and better).
 *       per_gold:<gold>:cap:<pct>: the figure counts once per slice of that
 *       many gold pieces the player owns, never beyond the cap; the slice and
 *       the cap belong to the first kind alone.
 *       A state at the end -- rested, combat, nocombat, solo, night, day,
 *       water -- and the line counts only while it holds.
 *
 * Schools: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane.
 */

#include "StellarTarotScript.h"
#include "StellarTarotEffects.h"   // le verrou de re-entrance, tenu par les repartiteurs
#include "StellarTarotLoot.h"
#include "StellarTarotLayout.h"
#include "StellarTarotMgr.h"
#include "Creature.h"
#include "TemporarySummon.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Item.h"
#include "LootMgr.h"
#include "ItemTemplate.h"
#include "Player.h"
#include "QuestDef.h"
#include "SharedDefines.h"
#include "Spell.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "Unit.h"
#include "World.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "GameObject.h"
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "Pet.h"
#include "SpellMgr.h"
#include "DBCStores.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Opcodes.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include "Chat.h"
#include "Log.h"
#include "StellarTarotStrings.h"
#include <algorithm>
#include <map>
#include <set>
#include <cmath>
#include <cstdlib>
#include <ctime>

namespace
{
    // -- parameters ----------------------------------------------------------

    bool Number(std::string const& s, int32 low, int32 high, int32& out)
    {
        if (s.empty())
            return false;
        size_t i = (s[0] == '-' || s[0] == '+') ? 1 : 0;
        if (i >= s.size() || s.find_first_not_of("0123456789", i) != std::string::npos)
            return false;
        long const v = std::strtol(s.c_str(), nullptr, 10);
        if (v < low || v > high)
            return false;
        out = int32(v);
        return true;
    }

    // UNE CHANCE AU DIXIEME DE POUR-CENT, rendue EN POUR MILLE. « 2.5 » vaut 25,
    // « 10 » en vaut 100 : une ligne ecrite en entiers garde exactement son
    // sens. Le point et la virgule se lisent tous les deux, un seul chiffre
    // apres -- c'est la finesse que le tirage sait tenir.
    bool Millieme(std::string const& s, int32 low, int32 high, int32& out)
    {
        if (s.empty())
            return false;
        size_t const sep = s.find_first_of(".,");
        int32 unites = 0;
        if (!Number(s.substr(0, sep), 0, 100000, unites))
            return false;
        int32 dixieme = 0;
        if (sep != std::string::npos)
        {
            std::string const reste = s.substr(sep + 1);
            if (reste.size() != 1 || !Number(reste, 0, 9, dixieme))
                return false;
        }
        int32 const v = unites * 10 + dixieme;
        if (v < low || v > high)
            return false;
        out = v;
        return true;
    }

    // "hp_below:30" split on the first colon is already done by the spec:
    // the state and its number come as two parameters. This joins a name and
    // reads the optional number that follows it in the parameter list.
    struct Reader
    {
        std::vector<std::string> const& p;
        size_t at = 0;
        explicit Reader(std::vector<std::string> const& params) : p(params) { }
        bool End() const { return at >= p.size(); }
        std::string Word() { return at < p.size() ? p[at++] : std::string(); }
        std::string Peek() const { return at < p.size() ? p[at] : std::string(); }
        bool Int(int32 low, int32 high, int32& out)
        {
            if (at >= p.size() || !Number(p[at], low, high, out))
                return false;
            ++at;
            return true;
        }
        // Une chance, au dixieme de pour-cent pres, rendue en pour mille.
        bool Mille(int32 low, int32 high, int32& out)
        {
            if (at >= p.size() || !Millieme(p[at], low, high, out))
                return false;
            ++at;
            return true;
        }
        // An optional number: consumed only if the next word is one.
        bool OptInt(int32 low, int32 high, int32& out)
        {
            if (at < p.size() && Number(p[at], low, high, out)) { ++at; return true; }
            return false;
        }
    };

    // -- the game, read --------------------------------------------------------

    int LocalHour()
    {
        time_t t = time_t(GameTime::GetGameTime().count());
        tm lt{};
#ifdef _WIN32
        localtime_s(&lt, &t);
#else
        localtime_r(&t, &lt);
#endif
        return lt.tm_hour;
    }

    // Night: between 21:00 and 06:00, by the clock of the machine.
    bool IsNight() { int const h = LocalHour(); return h < 6 || h >= 21; }

    Item* Equipped(Player* player, uint8 slot)
    {
        return player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
    }

    bool HasShield(Player* player)
    {
        Item* off = Equipped(player, EQUIPMENT_SLOT_OFFHAND);
        return off && off->GetTemplate()->InventoryType == INVTYPE_SHIELD;
    }
    bool HasTwoHand(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        return main && main->GetTemplate()->InventoryType == INVTYPE_2HWEAPON;
    }
    bool DualWields(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        Item* off = Equipped(player, EQUIPMENT_SLOT_OFFHAND);
        return main && off && main->GetTemplate()->Class == ITEM_CLASS_WEAPON
            && off->GetTemplate()->Class == ITEM_CLASS_WEAPON;
    }
    bool Unarmed(Player* player)
    {
        Item* main = Equipped(player, EQUIPMENT_SLOT_MAINHAND);
        return !main || main->GetTemplate()->Class != ITEM_CLASS_WEAPON;
    }

    // LE HAUT DE L'ECHELLE DES NIVEAUX : 83, le niveau des boss de Norfendre.
    // Au-dela, rien ne monte plus -- un boss y est compte d'office.
    constexpr uint32 PALIER_HAUT = 83;

    // UNE CAPITALE : le coeur le dit dans la table des zones.
    bool EstUneCapitale(uint32 zone)
    {
        AreaTableEntry const* const ici = sAreaTableStore.LookupEntry(zone);
        return ici && (ici->flags & AREA_FLAG_CAPITAL) != 0;
    }

    bool IsBoss(Creature* c)
    {
        return c && (c->isWorldBoss() || c->IsDungeonBoss());
    }
    bool IsElite(Creature* c)
    {
        return c && c->GetCreatureTemplate()->rank != CREATURE_ELITE_NORMAL;
    }

    uint32 PctOf(uint32 value, int32 pct)
    {
        return uint32(std::llround(double(value) * pct / 100.0));
    }

    // Le modele de faction « Hates Everything » : ami de personne, ennemi de
    // tous, joueurs compris (FactionTemplate.dbc 2189, faction 1145).
    constexpr uint32 FACTION_HATES_EVERYTHING = 2189;

    // Re-entrancy guard: damage dealt from inside a damage hook must not fire
    // the hook again.
    // LES SORTS DE FIEVRE, inscrits par la famille `fever` au moment ou elle se
    // charge : c'est a eux que l'evenement `fever` reconnait un tic de fievre.
    std::set<uint32> gFeverSpells;

    // POSER UNE STATISTIQUE SANS AURA, par le chemin meme que le coeur
    // emploie pour les statistiques d'un objet. Deux familles s'en servent :
    // `gempct`, qui rend une part de ce que les gemmes donnent, et `randstat`,
    // qui en tire une au sort -- car le `EffectMiscValue` d'un sort, QUELLE
    // statistique il majore, est ecrit dans le DBC et ne se choisit pas a la
    // pose. Deplacee ici telle quelle depuis `GemPct`, sans un mot de change.
    void Poser(Player* player, uint32 stat, int32 val, bool apply)
    {
        float const f = float(val);
        switch (stat)
        {
            case ITEM_MOD_MANA: player->HandleStatFlatModifier(UNIT_MOD_MANA, BASE_VALUE, f, apply); break;
            case ITEM_MOD_HEALTH: player->HandleStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, f, apply); break;
            case ITEM_MOD_AGILITY:
                player->HandleStatFlatModifier(UNIT_MOD_STAT_AGILITY, BASE_VALUE, f, apply);
                player->UpdateStatBuffMod(STAT_AGILITY);
                break;
            case ITEM_MOD_STRENGTH:
                player->HandleStatFlatModifier(UNIT_MOD_STAT_STRENGTH, BASE_VALUE, f, apply);
                player->UpdateStatBuffMod(STAT_STRENGTH);
                break;
            case ITEM_MOD_INTELLECT:
                player->HandleStatFlatModifier(UNIT_MOD_STAT_INTELLECT, BASE_VALUE, f, apply);
                player->UpdateStatBuffMod(STAT_INTELLECT);
                break;
            case ITEM_MOD_SPIRIT:
                player->HandleStatFlatModifier(UNIT_MOD_STAT_SPIRIT, BASE_VALUE, f, apply);
                player->UpdateStatBuffMod(STAT_SPIRIT);
                break;
            case ITEM_MOD_STAMINA:
                player->HandleStatFlatModifier(UNIT_MOD_STAT_STAMINA, BASE_VALUE, f, apply);
                player->UpdateStatBuffMod(STAT_STAMINA);
                break;
            case ITEM_MOD_DEFENSE_SKILL_RATING: player->ApplyRatingMod(CR_DEFENSE_SKILL, val, apply); break;
            case ITEM_MOD_DODGE_RATING: player->ApplyRatingMod(CR_DODGE, val, apply); break;
            case ITEM_MOD_PARRY_RATING: player->ApplyRatingMod(CR_PARRY, val, apply); break;
            case ITEM_MOD_BLOCK_RATING: player->ApplyRatingMod(CR_BLOCK, val, apply); break;
            case ITEM_MOD_HIT_MELEE_RATING: player->ApplyRatingMod(CR_HIT_MELEE, val, apply); break;
            case ITEM_MOD_HIT_RANGED_RATING: player->ApplyRatingMod(CR_HIT_RANGED, val, apply); break;
            case ITEM_MOD_HIT_SPELL_RATING: player->ApplyRatingMod(CR_HIT_SPELL, val, apply); break;
            case ITEM_MOD_CRIT_MELEE_RATING: player->ApplyRatingMod(CR_CRIT_MELEE, val, apply); break;
            case ITEM_MOD_CRIT_RANGED_RATING: player->ApplyRatingMod(CR_CRIT_RANGED, val, apply); break;
            case ITEM_MOD_CRIT_SPELL_RATING: player->ApplyRatingMod(CR_CRIT_SPELL, val, apply); break;
            case ITEM_MOD_HASTE_MELEE_RATING: player->ApplyRatingMod(CR_HASTE_MELEE, val, apply); break;
            case ITEM_MOD_HASTE_RANGED_RATING: player->ApplyRatingMod(CR_HASTE_RANGED, val, apply); break;
            case ITEM_MOD_HASTE_SPELL_RATING: player->ApplyRatingMod(CR_HASTE_SPELL, val, apply); break;
            case ITEM_MOD_HIT_RATING:
                player->ApplyRatingMod(CR_HIT_MELEE, val, apply);
                player->ApplyRatingMod(CR_HIT_RANGED, val, apply);
                player->ApplyRatingMod(CR_HIT_SPELL, val, apply);
                break;
            case ITEM_MOD_CRIT_RATING:
                player->ApplyRatingMod(CR_CRIT_MELEE, val, apply);
                player->ApplyRatingMod(CR_CRIT_RANGED, val, apply);
                player->ApplyRatingMod(CR_CRIT_SPELL, val, apply);
                break;
            case ITEM_MOD_RESILIENCE_RATING:
                player->ApplyRatingMod(CR_CRIT_TAKEN_MELEE, val, apply);
                player->ApplyRatingMod(CR_CRIT_TAKEN_RANGED, val, apply);
                player->ApplyRatingMod(CR_CRIT_TAKEN_SPELL, val, apply);
                break;
            case ITEM_MOD_HASTE_RATING:
                player->ApplyRatingMod(CR_HASTE_MELEE, val, apply);
                player->ApplyRatingMod(CR_HASTE_RANGED, val, apply);
                player->ApplyRatingMod(CR_HASTE_SPELL, val, apply);
                break;
            case ITEM_MOD_EXPERTISE_RATING: player->ApplyRatingMod(CR_EXPERTISE, val, apply); break;
            case ITEM_MOD_ARMOR_PENETRATION_RATING: player->ApplyRatingMod(CR_ARMOR_PENETRATION, val, apply); break;
            case ITEM_MOD_ATTACK_POWER:
                player->HandleStatFlatModifier(UNIT_MOD_ATTACK_POWER, TOTAL_VALUE, f, apply);
                player->HandleStatFlatModifier(UNIT_MOD_ATTACK_POWER_RANGED, TOTAL_VALUE, f, apply);
                break;
            case ITEM_MOD_RANGED_ATTACK_POWER:
                player->HandleStatFlatModifier(UNIT_MOD_ATTACK_POWER_RANGED, TOTAL_VALUE, f, apply);
                break;
            case ITEM_MOD_SPELL_POWER: player->ApplySpellPowerBonus(val, apply); break;
            case ITEM_MOD_MANA_REGENERATION: player->ApplyManaRegenBonus(val, apply); break;
            case ITEM_MOD_HEALTH_REGEN: player->ApplyHealthRegenBonus(val, apply); break;
            default: break;
        }
    }

    // AUTOUR DE L'ADVERSAIRE : la distance a laquelle un autre ennemi le rend
    // « accompagne ». Dix metres : un camp de monstres tient dedans, un
    // adversaire ecarte du groupe n'y tient pas.
    constexpr float SEUL_RAYON = 10.0f;

    // The hostile units within `range` of `center`, `except` left out.
    std::list<Unit*> HostilesAround(Player* player, WorldObject* center, float range, Unit* except)
    {
        std::list<Unit*> out;
        Acore::AnyUnfriendlyUnitInObjectRangeCheck check(center, player, range);
        Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> searcher(center, out, check);
        Cell::VisitObjects(center, searcher, range);
        out.remove(except);
        return out;
    }

    // UN CONTRE UN : le joueur seul face a un monstre seul, les deux cotes
    // mesures. L'adversaire est seul quand aucun autre ennemi vivant ne se
    // tient a moins de dix metres de lui ; le joueur l'est quand aucun autre
    // allie ne se tient a moins de dix metres de LUI -- un autre joueur, un
    // familier, un garde. LES TOTEMS NE COMPTENT PAS : ils ne poursuivent
    // personne, et un chaman ne pourrait plus jamais etre seul.
    // UN LEURRE N'EST PAS UN ADVERSAIRE. Les creatures que le coeur marque
    // `CREATURE_FLAG_EXTRA_TRIGGER` ne sont la que pour porter un effet : la
    // flamme au sol de Marrowgar, un totem de decor, une zone qui tique. Elles
    // sont invisibles et insaisissables pour le joueur, et les compter comme
    // ennemis rompait le duel en permanence (releve en jeu le 2026-09-21).
    bool EstUnLeurre(Unit const* unit)
    {
        Creature const* const creature = unit ? unit->ToCreature() : nullptr;
        return creature && creature->IsTrigger();
    }

    // DERRIERE LE LEURRE, CELUI QUI L'A POSE : la flamme appartient au boss,
    // c'est LUI l'adversaire. Sans cela, un tic de flamme se mesurait autour de
    // la flamme, qui a toujours son maitre a cote d'elle.
    Unit* Derriere(Unit* unit)
    {
        if (!EstUnLeurre(unit))
            return unit;
        if (TempSummon const* const invoque = unit->ToTempSummon())
            if (Unit* const maitre = invoque->GetSummonerUnit())
                return maitre;
        if (Unit* const proprietaire = unit->GetOwner())
            return proprietaire;
        return unit;
    }

    bool UnContreUn(Player* player, Unit* adversaire)
    {
        if (!player || !adversaire)
            return false;
        adversaire = Derriere(adversaire);
        for (Unit* autre : HostilesAround(player, adversaire, SEUL_RAYON, adversaire))
            if (!EstUnLeurre(autre))
                return false;
        std::list<Unit*> amis;
        Acore::AnyFriendlyUnitInObjectRangeCheck check(player, player, SEUL_RAYON);
        Acore::UnitListSearcher<Acore::AnyFriendlyUnitInObjectRangeCheck> searcher(player, amis, check);
        Cell::VisitObjects(player, searcher, SEUL_RAYON);
        for (Unit* ami : amis)
            if (ami && ami != player && !ami->IsTotem())
                return false;
        return true;
    }

    // The states a line can wait for WITHOUT keeping anything: no parameter,
    // no memory of the past. `cond` knows more of them and remembers what it
    // must; these are the ones any other family may read as they stand.
    bool SimpleState(Player const* player, std::string const& state);


    SpellInfo const* Info(uint32 spellId) { return spellId ? sSpellMgr->GetSpellInfo(spellId) : nullptr; }

    // A shot of the wand ITSELF: the ranged auto-attack a wand grants. The
    // core fires it as a spell of its own, so a blow is a wand shot when the
    // spell is the AUTO-REPEAT one of the ranged slot and what the player
    // holds there is a wand. Not its damage class: Shoot (5019) is written as
    // MAGIC in the client's own data, ranged is the hunter's Auto Shot.
    bool IsWandShot(Player* player, uint32 spellId)
    {
        if (!player || !spellId)
            return false;
        SpellInfo const* const info = Info(spellId);
        if (!info || !info->IsAutoRepeatRangedSpell())
            return false;
        Item const* const ranged = player->GetWeaponForAttack(RANGED_ATTACK, true);
        if (!ranged)
            return false;
        ItemTemplate const* const tpl = ranged->GetTemplate();
        return tpl && tpl->Class == ITEM_CLASS_WEAPON && tpl->SubClass == ITEM_SUBCLASS_WEAPON_WAND;
    }

    // Every blow a wand deals: its own shot, and the second shot a card grants
    // -- a shot in every way, and counted as one by every line of a card but
    // the line that grants it.
    bool IsWandBlow(Player* player, uint32 spellId)
    {
        return spellId == STELLAR_TAROT_SPELL_WAND_SHOT || IsWandShot(player, spellId);
    }

    // Damage dealt by the module, logged under the level's spell so the
    // client shows the figure.
    void Hurt(Player* player, Unit* victim, uint32 damage, uint32 school, uint32 spellId = 0)
    {
        if (!victim || !victim->IsAlive() || !damage
            || StellarTarotEffects::HeldFor(player->GetGUID()))
            return;
        StellarTarotEffects::HoldFor(player->GetGUID());
        SpellInfo const* info = Info(spellId);
        uint32 const dealt = Unit::DealDamage(player, victim, damage, nullptr, SPELL_DIRECT_DAMAGE, SpellSchoolMask(school), info, false);
        // CE QUE LA CARTE A INFLIGE, et non ce que la cible a bien voulu
        // perdre : un mannequin d'entrainement ramene tout a zero par script
        // (Unit::DealDamage, premiere ligne), et le joueur ne verrait rien de
        // ce qu'il mesure. Le coeur inscrit ses frappes d'arme de la meme
        // facon, avant ce passage.
        if (info)
            player->SendSpellNonMeleeDamageLog(victim, info, dealt ? dealt : damage,
                                               SpellSchoolMask(school), 0, 0, school == 1, 0);
        StellarTarotEffects::ReleaseFor(player->GetGUID());
    }

    // A heal by the module: through the spell log, so the client shows it.
    void Heal(Player* player, Unit* target, uint32 amount, uint32 spellId)
    {
        if (!target || !target->IsAlive() || !amount)
            return;
        SpellInfo const* info = Info(spellId);
        if (!info)
        {
            target->ModifyHealth(int32(amount));
            return;
        }
        StellarTarotEffects::HoldFor(player->GetGUID());
        HealInfo healInfo(player, target, amount, info, SPELL_SCHOOL_MASK_HOLY);
        player->HealBySpell(healInfo);
        StellarTarotEffects::ReleaseFor(player->GetGUID());
    }
    // ================= CE QU'UNE CARTE DIT DANS LE CHAT =================
    //
    // Chaque phrase porte SA SOURCE : « [The Tithe] : ... ». Et plusieurs
    // lignes d'une meme carte peuvent agir sur le meme evenement -- deux parts
    // d'or de quete, par exemple : leurs montants s'ajoutent et ne font qu'UNE
    // phrase. Pour cela rien n'est dit sur-le-champ : ce qui est du s'empile,
    // et tout part au tic suivant, quand tout ce qui devait s'ajouter s'est
    // ajoute.
    // =====================================================================
    // PLUS TARD : le meme travail, plus loin dans l'horloge.
    //
    // Sept endroits du moteur differaient un travail, et tous les sept
    // repetaient les trois memes lignes -- retenir le guid, retrouver le
    // joueur a l'echeance, se taire s'il est parti. Le differeur le fait une
    // fois, et les delais se nomment.
    // =====================================================================
    constexpr Milliseconds TOUR_SUIVANT{ 1 };     // le coeur finit ce qu'il fait
    constexpr Milliseconds APRES_COUP{ 500 };     // le demi-tour d'horloge du revers

    // CE QUE SEUL LE CLIENT PEUT DIRE, annonce ici : la definition est plus
    // bas, avec les infobulles de potion qu'elle sert d'abord, mais des lignes
    // qui viennent avant s'en servent aussi.
    void TellClient(Player* player, char const* prefix, std::string const& message);

    template <typename F>
    void PlusTard(Player* player, Milliseconds delai, F travail)
    {
        if (!player)
            return;
        ObjectGuid const who = player->GetGUID();
        player->m_Events.AddEventAtOffset([who, travail]()
        {
            if (Player* const p = ObjectAccessor::FindPlayer(who))
                travail(p);
        }, delai);
    }

    // =====================================================================
    // LES MESURES : d'ou vient le chiffre qu'une ligne verse.
    //
    // LE COEUR NE TRANSPORTE JAMAIS LE MONTANT DU COUP DECLENCHEUR jusqu'au
    // sort qu'il lance : ni l'aura 43, ni l'aura 231 -- qui passe le montant de
    // l'AURA, non celui du coup -- ni l'effet 142, dont la valeur est ecrite
    // dans le DBC. C'est pour cela que ces huit actions restent au module.
    //
    // Nommer la source une fois evite qu'elle soit relue de plusieurs facons :
    // la puissance des sorts l'etait en six endroits.
    // =====================================================================
    enum class Mesure : uint8
    {
        Coup,                // le coup qui vient de tomber, que le coeur tait
        PuissanceDesSorts,
        PuissanceDAttaque,
        ViesMaxDuLanceur,
    };

    uint32 Mesurer(Mesure quoi, Player* player, uint32 coup)
    {
        switch (quoi)
        {
            case Mesure::Coup:
                return coup;
            case Mesure::PuissanceDesSorts:
                return uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)));
            case Mesure::PuissanceDAttaque:
                return uint32(player->GetTotalAttackPowerValue(BASE_ATTACK));
            case Mesure::ViesMaxDuLanceur:
                return player->GetMaxHealth();
        }
        return 0;
    }

    // LA SOMME ARRIVE PLUS TARD. Le coeur annonce l'objet vendu d'un cote et
    // le mouvement d'argent de l'autre : la ligne attend donc entre les deux.
    // L'attente porte son heure et ne vaut qu'un tour d'horloge -- sans quoi
    // une vente qui n'a rien rapporte majorerait le prochain gain d'argent,
    // quel qu'il soit.
    constexpr uint32 ATTENTE_DE_LA_SOMME_MS = 200;

    void AttendreLaSomme(uint32& depuis)
    {
        depuis = uint32(GameTime::GetGameTimeMS().count());
    }

    bool SommeAttendue(uint32& depuis)
    {
        if (!depuis)
            return false;
        bool const a_temps =
            uint32(GameTime::GetGameTimeMS().count()) - depuis <= ATTENTE_DE_LA_SOMME_MS;
        depuis = 0;                      // l'attente ne vaut qu'une fois
        return a_temps;
    }

    // Une aura nee dans la seconde du coup que l'on compte : le coup l'a posee
    // lui-meme. L'heure d'une aura est fixee a sa creation et un renouvellement
    // ne la deplace pas.
    bool AuraTouteFraiche(AuraEffect const* eff)
    {
        Aura const* aura = eff->GetBase();
        return aura && aura->GetApplyTime() >= GameTime::GetGameTime().count();
    }

    // =====================================================================
    // LE VOCABULAIRE DES ETATS : un mot, un sens, un seul endroit.
    //
    // Trois familles les lisaient chacune a sa facon, et « charme » y voulait
    // deja dire deux choses. Chaque mot nomme son SUJET : le joueur pour ce
    // qu'il porte -- son arme, son groupe, son or, l'heure -- et le sujet pour
    // ce qui se voit sur un corps : sa vie, son etourdissement, ses flammes.
    //
    // Les etats QUI DURENT (`still`, `mounted`, `walking`, `running`) ne sont
    // pas ici : chacun a sa propre remise a zero, que la ligne tient.
    // =====================================================================
    bool EtatTenu(std::string const& mot, int32 n, int32 m, Player* player, Unit* sujet,
                  Unit* vis_a_vis)
    {
        if (!player || !sujet)
            return false;
        // CE QUE LE JOUEUR PORTE, ou l'heure qu'il est.
        if (mot == "shield") return HasShield(player);
        if (mot == "twohand") return HasTwoHand(player);
        if (mot == "dualwield") return DualWields(player);
        // `stacks:<sort>:<n>` : LE JOUEUR PORTE CETTE AURA A TANT DE CUMULS.
        // C'est ainsi qu'un niveau lit le compte qu'un autre tient -- « A 5
        // cumuls : ... ». L'aura est le seul temoin, et le coeur la porte.
        if (mot == "stacks")
        {
            Aura const* const porte = n ? player->GetAura(uint32(n), player->GetGUID()) : nullptr;
            return porte && int32(porte->GetStackAmount()) >= std::max(1, m);
        }
        // `aura:<sort>` : LE JOUEUR PORTE CETTE AURA-LA. C'est ainsi qu'une
        // ligne lit la PHASE qu'une autre ligne de la meme carte tient : la
        // maree haute, le Soleil. Rien de partage entre les scripts -- l'aura
        // est le seul temoin, et le coeur la porte.
        if (mot == "aura") return n && player->HasAura(uint32(n));
        // UN OBJET HERITAGE EQUIPE, un seul suffit : le jeu les range sous
        // leur propre qualite.
        if (mot == "heirloom")
        {
            for (uint8 place = EQUIPMENT_SLOT_START; place < EQUIPMENT_SLOT_END; ++place)
                if (Item const* piece = player->GetItemByPos(INVENTORY_SLOT_BAG_0, place))
                    if (piece->GetTemplate() && piece->GetTemplate()->Quality == ITEM_QUALITY_HEIRLOOM)
                        return true;
            return false;
        }
        if (mot == "unarmed") return Unarmed(player);
        if (mot == "solo") return !player->GetGroup();
        if (mot == "rested") return player->HasPlayerFlag(PLAYER_FLAGS_RESTING);
        if (mot == "water") return player->IsInWater();
        if (mot == "indoors") return !player->IsOutdoors();
        if (mot == "outdoors") return player->IsOutdoors();
        if (mot == "gold_above") return player->GetMoney() > uint32(n);
        if (mot == "night") return IsNight();
        if (mot == "day") { int h = LocalHour(); return h >= 6 && h < 21; }
        if (mot == "dawn_dusk") { int h = LocalHour(); return (h >= 5 && h < 7) || (h >= 19 && h < 21); }
        if (mot == "hour") { int h = LocalHour(); return h >= n && h < m; }
        if (mot == "combat") return player->IsInCombat();
        if (mot == "nocombat") return !player->IsInCombat();
        // CE QUI SE VOIT SUR UN CORPS -- celui du sujet.
        if (mot == "hp_below") return sujet->GetHealthPct() < float(n);
        if (mot == "hp_above") return sujet->GetHealthPct() > float(n);
        if (mot == "full_hp") return sujet->GetHealth() >= sujet->GetMaxHealth();
        if (mot == "mana_below") return sujet->GetPowerPct(POWER_MANA) < float(n);
        if (mot == "humanoid") return sujet->GetCreatureType() == CREATURE_TYPE_HUMANOID;
        // SEUL : L'ADVERSAIRE N'A AUCUN AUTRE ENNEMI AUTOUR DE LUI. Ce n'est
        // pas « je suis seul a le frapper » : un joueur solo remplissait alors
        // la condition en permanence, au milieu d'un camp entier (releve en jeu
        // le 2026-09-20, carte 83). Le sujet est la cible quand on FRAPPE ;
        // quand on SUBIT, l'adversaire est le vis-a-vis -- le joueur, lui,
        // n'est jamais « seul » au sens de la carte.
        if (mot == "alone")
        {
            Unit* const adversaire = (sujet == player && vis_a_vis) ? vis_a_vis : sujet;
            return UnContreUn(player, adversaire);
        }
        if (mot == "range_over") return player->GetDistance(sujet) > float(n);
        // DANS LE DOS : le coup vient de derriere, hors du demi-cercle que le
        // sujet a devant lui -- le meme compas que l'evenement `dmg_taken_back`.
        if (mot == "back") return vis_a_vis && !sujet->HasInArc(float(M_PI), vis_a_vis);
        // TOUTE IMMOBILISATION -- etourdissement, renversement (un
        // etourdissement lui aussi) et enracinement -- mais jamais un simple
        // ralentissement.
        if (mot == "stunned")
            return sujet->HasUnitState(UNIT_STATE_STUNNED) || sujet->HasUnitState(UNIT_STATE_ROOT)
                || sujet->HasAuraType(SPELL_AURA_MOD_STUN) || sujet->HasAuraType(SPELL_AURA_MOD_ROOT);
        if (mot == "controlled")
            return sujet->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_ROOT
                                       | UNIT_STATE_FLEEING | UNIT_STATE_CONFUSED);
        // L'ESPRIT QU'ON LUI PREND : la peur ou le charme, rien d'autre. On lit
        // les AURAS autant que les etats -- un charme se pose par des chemins
        // ou l'etat ne suit pas toujours.
        if (mot == "charmed")
            return sujet->HasUnitState(UNIT_STATE_FLEEING | UNIT_STATE_CHARMED)
                || sujet->HasAuraType(SPELL_AURA_MOD_FEAR)
                || sujet->HasAuraType(SPELL_AURA_MOD_CHARM)
                || sujet->HasAuraType(SPELL_AURA_MOD_POSSESS);
        if (mot == "slowed")
        {
            for (AuraEffect const* eff : sujet->GetAuraEffectsByType(SPELL_AURA_MOD_DECREASE_SPEED))
                if (!AuraTouteFraiche(eff))
                    return true;
            return sujet->HasUnitState(UNIT_STATE_ROOT);
        }
        if (mot == "burning")
        {
            for (AuraEffect const* eff : sujet->GetAuraEffectsByType(SPELL_AURA_PERIODIC_DAMAGE))
            {
                if (!(eff->GetSpellInfo()->GetSchoolMask() & SPELL_SCHOOL_MASK_FIRE))
                    continue;
                // Un sort pose son aura avant que ses degats ne soient comptes :
                // une brulure nee de ce coup-ci ne se paie pas elle-meme. Une
                // posee plus tot, si -- meme quand ce coup la renouvelle.
                if (AuraTouteFraiche(eff))
                    continue;
                return true;
            }
            return false;
        }
        return false;
    }

    // REGLER UNE AURA DEJA POSEE au chiffre voulu, sans la retirer ni la
    // reposer. `AuraEffect::ChangeAmount` depile l'effet, change le montant et
    // le rempile : le joueur ne voit ni clignotement dans sa barre de
    // bienfaits, ni ligne de journal, et le serveur cesse d'envoyer deux
    // paquets d'aura par seconde et par carte.
    //
    // Rend FAUX quand l'aura n'est pas la : il faut alors la poser.
    bool ReglerAura(Player* player, uint32 spellId, int32 const* veut, uint8 masque)
    {
        Aura* const aura = player->GetAura(spellId, player->GetGUID());
        if (!aura)
            return false;
        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            if (masque & uint8(1 << i))
                if (AuraEffect* const eff = aura->GetEffect(i))
                    if (eff->GetAmount() != veut[i])
                        eff->ChangeAmount(veut[i]);
        return true;
    }

    // CE QUE LE LIEU DONNE : un tirage dans la reserve de l'age ou se trouve
    // le joueur -- 0 le vieux monde, 1 l'Outreterre, 2 le Norfendre et au-dela.
    // Les identifiants sont en base (`mod_stellar_tarot_loot_pool`) : une gemme
    // de plus, un coffre d'une autre extension, et rien a recompiler.
    uint32 DuLieu(Player* player, char const* reserve)
    {
        MapEntry const* const carte = player->GetMap() ? player->GetMap()->GetEntry() : nullptr;
        uint32 const age = carte ? uint32(carte->expansionID) : 0u;
        std::vector<uint32> const& liste = sStellarTarotMgr->LootPool(reserve, age);
        return liste.empty() ? 0u : liste[urand(0, uint32(liste.size() - 1))];
    }

    // LA PART D'UNE MESURE : le chiffre qu'une ligne verse vraiment.
    uint32 Part(Mesure quoi, int32 pct, Player* player, uint32 coup = 0)
    {
        return PctOf(Mesurer(quoi, player, coup), pct);
    }

    struct Owed
    {
        uint32 card = 0;
        uint32 said = 0;
        uint64 copper = 0;
        bool money = false;
    };
    std::map<ObjectGuid, std::vector<Owed>> gOwed;

    // La carte d'un sort de niveau : 903000 + 4 x carte + (niveau - 1).
    uint32 CardOfSpell(uint32 spellId)
    {
        return spellId > 903000 ? (spellId - 903000) / 4 : 0;
    }

    void FlushOwed(ObjectGuid who)
    {
        auto it = gOwed.find(who);
        if (it == gOwed.end())
            return;
        std::vector<Owed> const due = std::move(it->second);
        gOwed.erase(it);
        Player* player = ObjectAccessor::FindPlayer(who);
        if (!player || !player->GetSession())
            return;
        ChatHandler handler(player->GetSession());
        for (Owed const& owed : due)
        {
            std::string const what = owed.money
                ? handler.PGetParseModuleString(STELLAR_TAROT_MODULE, owed.said,
                      uint32(owed.copper / GOLD), uint32((owed.copper % GOLD) / SILVER),
                      uint32(owed.copper % SILVER))
                : handler.PGetParseModuleString(STELLAR_TAROT_MODULE, owed.said);
            handler.PSendModuleSysMessage(STELLAR_TAROT_MODULE, STELLAR_TAROT_STR_FROM_CARD,
                                          sStellarTarotMgr->CardName(owed.card), what);
        }
    }

    // Ce qu'une ligne doit dire : ajoute a ce que sa carte dit deja du meme
    // souffle, ou pose une phrase de plus.
    void Owe(Player* player, uint32 spellId, uint32 said, uint64 copper, bool money)
    {
        if (!player->GetSession() || !said || (money && !copper))
            return;
        uint32 const card = CardOfSpell(spellId);
        std::vector<Owed>& due = gOwed[player->GetGUID()];
        bool const first = due.empty();
        for (Owed& owed : due)
            if (owed.card == card && owed.said == said)
            {
                owed.copper += copper;
                return;
            }
        Owed owed;
        owed.card = card;
        owed.said = said;
        owed.copper = copper;
        owed.money = money;
        due.push_back(owed);
        if (first)
            PlusTard(player, TOUR_SUIVANT, [](Player* p) { FlushOwed(p->GetGUID()); });
    }

    void Energize(Player* player, Unit* target, uint32 amount, uint32 spellId)
    {
        if (!target || !amount)
            return;
        if (spellId)
            player->EnergizeBySpell(target, spellId, amount, POWER_MANA);
        else
            target->ModifyPower(POWER_MANA, int32(amount));
    }
    // Health the player gives up: never below 1, logged as damage.
    void Bleed(Player* player, uint32 amount, uint32 spellId)
    {
        int32 const dmg = std::min<int32>(int32(amount), int32(player->GetHealth()) - 1);
        if (dmg <= 0)
            return;
        SpellInfo const* info = Info(spellId);
        StellarTarotEffects::HoldFor(player->GetGUID());
        Unit::DealDamage(player, player, uint32(dmg), nullptr, SELF_DAMAGE, SPELL_SCHOOL_MASK_SHADOW, info, false);
        StellarTarotEffects::ReleaseFor(player->GetGUID());
        if (info)
            player->SendSpellNonMeleeDamageLog(player, info, uint32(dmg), SPELL_SCHOOL_MASK_SHADOW, 0, 0, false, 0);
    }

    // A control or a shield of the module on `target`, for `sec` seconds,
    // with `bp` as the amount when the spell takes one.
    void Put(Player* player, Unit* target, uint32 spellId, int32 sec, int32 const* bp = nullptr)
    {
        if (!target || !target->IsAlive())
            return;
        if (bp)
        {
            // Le montant d'une aura déjà là ne se recalcule pas : on l'enlève
            // pour que la nouvelle pose remplace vraiment l'ancienne.
            target->RemoveAurasDueToSpell(spellId, player->GetGUID());
            player->CastCustomSpell(target, spellId, bp, nullptr, nullptr, true);
        }
        else
            player->AddAura(spellId, target);
        if (sec <= 0)
            return;                       // la duree du sort fait foi : permanente
        if (Aura* aura = target->GetAura(spellId, player->GetGUID()))
        {
            aura->SetMaxDuration(sec * 1000);
            aura->SetDuration(sec * 1000);
        }
    }

    // The group members (the player included) within `range`.
    std::vector<Player*> GroupAround(Player* player, float range)
    {
        std::vector<Player*> out;
        if (Group* group = player->GetGroup())
        {
            for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
                if (Player* member = ref->GetSource())
                    if (member->IsAlive() && member->IsInMap(player) && player->GetDistance(member) <= range)
                        out.push_back(member);
        }
        else
            out.push_back(player);
        return out;
    }

    // Every equipped item gains `points` of durability.
    void Mend(Player* player, uint32 points)
    {
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            uint32 const max = item->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
            uint32 const cur = item->GetUInt32Value(ITEM_FIELD_DURABILITY);
            if (!max || cur >= max)
                continue;
            item->SetUInt32Value(ITEM_FIELD_DURABILITY, std::min(max, cur + points));
            item->SetState(ITEM_CHANGED, player);
            if (!cur)
                player->_ApplyItemMods(item, slot, true);
        }
    }

    // One equipped piece, the most worn of them, mended by that many points.
    void MendOne(Player* player, uint32 points)
    {
        Item* worst = nullptr;
        uint32 slotOf = 0, lost = 0;
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;
            uint32 const max = item->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
            uint32 const cur = item->GetUInt32Value(ITEM_FIELD_DURABILITY);
            if (!max || cur >= max)
                continue;
            if (max - cur > lost)
            {
                lost = max - cur;
                worst = item;
                slotOf = slot;
            }
        }
        if (!worst)
            return;
        uint32 const max = worst->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
        uint32 const cur = worst->GetUInt32Value(ITEM_FIELD_DURABILITY);
        worst->SetUInt32Value(ITEM_FIELD_DURABILITY, std::min(max, cur + points));
        worst->SetState(ITEM_CHANGED, player);
        if (!cur)
            player->_ApplyItemMods(worst, uint8(slotOf), true);
    }

    // The player pays: health (never below 1), mana, or a control on himself.
    struct Reader;
    // Le revers, tel que n'importe quelle famille peut le lire et le subir.
    struct Drawback
    {
        std::string kind;
        // LE SORT DE LA MARQUE, quand le revers en pose une : le client calcule
        // son $s1 depuis SON dbc et non depuis ce que le script passe au
        // lancement. Deux cartes qui retirent des parts d'armure differentes
        // ne peuvent donc pas partager un sort sans que l'une des deux mente.
        int32 n = 0, n2 = 0, chance = 100, spell = 0;
        // Les cumuls que la PLAIE porte d'elle-meme, quand le bienfait n'en a
        // pas a lui preter (un soin, par exemple). 0 : elle suit le bienfait.
        int32 stacks = 0;
        [[nodiscard]] bool Some() const { return !kind.empty(); }
};

    // ===================== LE REVERS D'UNE LIGNE =====================
    //
    // Tout le tag Madness est bati ainsi : « un bienfait MAIS son revers ».
    // Le revers s'ecrit en queue de n'importe quelle ligne, « but:<quoi>:<n>
    // [:<n2>][:chance:<c>] », et le joueur le subit lui-meme :
    //
    //   hp:<pct> / mana:<pct>          il paie de sa sante ou de son mana,
    //                                  d'un coup
    //   hp_each:<pct>                  le meme coup, MULTIPLIE par le nombre
    //                                  de cumuls du bienfait
    //   hp_stack:<pct>:<sec>:<sort>    il paie SUR LA DUREE, sous une plaie a
    //                                  lui qui porte autant de cumuls que le
    //                                  bienfait : la part annoncee PAR CUMUL,
    //                                  en tout, etalee sur les battements
    //   stun|silence|sleep|disorient|root:<sec>   il se met hors jeu un instant
    //   taken:<pct>:<sec>              il encaisse plus, un moment
    //   burn:<pct>:<sec>               il perd des PV par tics
    //   self_hit:<pct>                 le coup se retourne contre lui
    //
    // « cost: » reste accepte pour dire la meme chose : c'est le mot d'avant.
    void Cost(Player* player, std::string const& kind, int32 n, int32 n2 = 0, uint32 spellId = 0,
              uint32 markSpell = 0, int32 stacks = 1)
    {
        stacks = std::max(1, stacks);
        if (kind == "hp")
            Bleed(player, PctOf(player->GetMaxHealth(), n), STELLAR_TAROT_SPELL_PRICE);
        // LA DURABILITE DE TOUT CE QUI EST PORTE : le coeur sait l'oter, piece
        // par piece, et prevenir le client.
        else if (kind == "durability")
        {
            for (uint8 place = EQUIPMENT_SLOT_START; place < EQUIPMENT_SLOT_END; ++place)
                if (Item* piece = player->GetItemByPos(INVENTORY_SLOT_BAG_0, place))
                {
                    uint32 const max = piece->GetUInt32Value(ITEM_FIELD_MAXDURABILITY);
                    if (!max)
                        continue;
                    uint32 const perd = PctOf(max, n);
                    if (perd)
                        player->DurabilityPointsLoss(piece, int32(perd));
                }
        }
        // TOMBER A UN POINT DE VIE : ce que la carte prend, elle le prend tout.
        else if (kind == "to_one")
        {
            if (player->GetHealth() > 1)
                Bleed(player, uint32(player->GetHealth() - 1), STELLAR_TAROT_SPELL_PRICE);
        }
        // LE COUP QUI S'EMPILE : le meme coup que `hp`, multiplie par le
        // nombre de cumuls que le bienfait porte.
        else if (kind == "hp_each")
            Bleed(player, PctOf(player->GetMaxHealth(), n) * uint32(stacks), STELLAR_TAROT_SPELL_PRICE);
        // LA PLAIE QUI S'EMPILE : une plaie sur le joueur, qui vit aussi
        // longtemps que le bienfait et porte AUTANT DE CUMULS QUE LUI. Elle bat
        // toutes les deux secondes et coute EN TOUT la part annoncee par
        // cumul : le battement vaut donc cette part divisee par le nombre de
        // battements, et le coeur la multiplie par les cumuls. Le de du sort
        // ajoute le dernier point, on le retire.
        else if (kind == "hp_stack")
        {
            uint32 const mal = markSpell ? markSpell : STELLAR_TAROT_SPELL_PRICE;
            int32 const battements = std::max(1, n2 / 2);
            int32 const parTic = std::max<int32>(1, int32(PctOf(player->GetMaxHealth(), n)) / battements);
            Aura* plaie = player->GetAura(mal, player->GetGUID());
            if (!plaie)
            {
                player->CastCustomSpell(player, mal, &parTic, nullptr, nullptr, true);
                plaie = player->GetAura(mal, player->GetGUID());
            }
            if (plaie)
            {
                // AUTANT DE CUMULS QUE LE BIENFAIT, ni plus ni moins.
                if (int32(plaie->GetStackAmount()) != stacks)
                    plaie->SetStackAmount(uint8(std::min<int32>(stacks, int32(plaie->GetSpellInfo()->StackAmount ? plaie->GetSpellInfo()->StackAmount : 1))));
                if (n2)
                {
                    plaie->SetMaxDuration(n2 * 1000);
                    plaie->SetDuration(n2 * 1000);
                }
            }
        }
        else if (kind == "mana")
            player->ModifyPower(POWER_MANA, -int32(PctOf(player->GetMaxPower(POWER_MANA), n)));
        else if (kind == "disorient") Put(player, player, STELLAR_TAROT_SPELL_DISORIENT, n);
        else if (kind == "stun") Put(player, player, STELLAR_TAROT_SPELL_STUN, n);
        else if (kind == "silence") Put(player, player, STELLAR_TAROT_SPELL_SILENCE, n);
        else if (kind == "sleep") Put(player, player, STELLAR_TAROT_SPELL_SLEEP, n);
        else if (kind == "root") Put(player, player, STELLAR_TAROT_SPELL_ROOT, n);
        // Encaisser davantage, un moment : l'aura « a decouvert ».
        else if (kind == "taken")
        {
            int32 const more = n;
            uint32 const sort = markSpell ? markSpell : STELLAR_TAROT_SPELL_TAKEN_MORE;
            Put(player, player, sort, n2, &more);
            // LA PLAIE QUI S'EMPILE : elle monte d'un cumul par passage,
            // jusqu'au plafond que la ligne lui donne.
            if (stacks > 1)
                if (Aura* posee = player->GetAura(sort, player->GetGUID()))
                    if (int32(posee->GetStackAmount()) < stacks)
                        posee->ModStackAmount(1);
        }
        // L'ARMURE QUI CEDE, un moment : le revers a sa propre duree, celle
        // que le classeur lui donne, et non celle du bienfait.
        else if (kind == "armor")
        {
            int32 const less = -n;
            Put(player, player, markSpell ? markSpell : STELLAR_TAROT_SPELL_ARMOR_DOWN, n2, &less);
        }
        // Bruler de sa propre flamme : l'aura de brulure des cartes, sur soi.
        else if (kind == "burn")
        {
            int32 const perTick = int32(PctOf(player->GetMaxHealth(), n));
            Put(player, player, STELLAR_TAROT_SPELL_BURN, n2, &perTick);
        }
        // LE MEME MAL, MAIS A LA SECONDE, et sous un debuff a lui : le sort
        // nomme bat toutes les secondes et son infobulle dit la part. Sans sort
        // nomme, la brulure commune du module -- qui bat toutes les 2 sec.
        else if (kind == "burn_s")
        {
            // Le de du sort ajoute le dernier point : on le retire d'abord pour
            // que le tic vaille tout juste la part demandee.
            int32 const perTick = int32(PctOf(player->GetMaxHealth(), n));
            Put(player, player, markSpell ? markSpell : STELLAR_TAROT_SPELL_BURN, n2, &perTick);
        }
    }
    bool CostKind(std::string const& k)
    {
        return k == "hp" || k == "hp_each" || k == "hp_stack" || k == "mana" || k == "disorient"
            || k == "stun" || k == "silence" || k == "sleep" || k == "root" || k == "taken"
            || k == "burn" || k == "burn_s" || k == "self_hit" || k == "armor"
            // La durabilite de tout ce qui est porte, et le point de vie qui
            // reste quand la carte a tout pris.
            || k == "durability" || k == "to_one";
    }
    // Les revers qui demandent DEUX chiffres (une valeur et une duree).
    bool CostPair(std::string const& k)
    {
        return k == "taken" || k == "burn" || k == "burn_s" || k == "armor" || k == "hp_stack";
    }

    // LES REVERS QUI COUPENT L'ACTION. Eux seuls attendent un demi-tour
    // d'horloge : sans cela l'etourdissement tombe avant meme que le joueur
    // ait vu le coup qu'il vient de porter. Un revers qui ne fait que peser --
    // l'armure, les degats subis, la vie, le mana -- se pose AVEC le bienfait,
    // sinon les deux auras d'une meme ligne n'apparaissent pas ensemble.
    bool CostInterrupts(std::string const& k)
    {
        return k == "stun" || k == "disorient" || k == "silence" || k == "sleep" || k == "root";
    }

    // LES REVERS QUI POSENT UNE MARQUE : leur infobulle dit LEUR chiffre, donc
    // chacun a son sort. Une seule liste, les deux lectures ayant diverge.
    bool CostMarks(std::string const& k)
    {
        return k == "armor" || k == "taken" || k == "burn_s" || k == "hp_stack";
    }

    // UNE CLAUSE DE REVERS, lue d'un seul endroit :
    // « but:<quoi>:<n>[:<n2>][:<sort de la marque>] ».
    template <typename R>
    bool ReadDrawbackClause(R& r, Drawback& but, std::string& error)
    {
        but.kind = r.Word();
        if (!CostKind(but.kind))
            return (error = "unknown drawback \"" + but.kind + "\"", false);
        // `to_one` ne porte aucun chiffre : il prend tout ce qui depasse un
        // point de vie, et rien ne se mesure la.
        if (but.kind == "to_one")
            but.n = 1;
        else if (!r.Int(1, 100000, but.n))
            return (error = but.kind + " expects a figure", false);
        if (CostPair(but.kind) && !r.Int(1, 3600, but.n2))
            return (error = but.kind + " expects the figure then the seconds", false);
        if (CostMarks(but.kind))
            r.OptInt(902000, 903999, but.spell);
        // `stacks:<k>` : LA PLAIE S'EMPILE D'ELLE-MEME. Le cas ordinaire est
        // qu'elle suive les cumuls du bienfait ; quand celui-ci n'en a pas --
        // un soin, par exemple -- la ligne dit les siens.
        if (!r.End() && r.Peek() == "stacks")
        {
            r.Word();
            if (!r.Int(1, 100, but.stacks))
                return (error = "stacks expects how many", false);
        }
        return true;
    }

    // « but:<quoi>:<n>[:<n2>][:chance:<c>] » en queue d'une ligne, quelle que
    // soit sa famille. Lit ce qui reste et dit si tout etait comprehensible.
    template <typename R>
    bool ReadDrawback(R& r, Drawback& but, std::string& error)
    {
        while (!r.End())
        {
            std::string const word = r.Word();
            if (word == "but" || word == "cost")
            {
                if (!ReadDrawbackClause(r, but, error))
                    return false;
                continue;
            }
            if (word == "chance" && r.Int(1, 100, but.chance))
                continue;
            return (error = "after the figures, only but:<kind>:<n> or chance:<n> may follow", false);
        }
        return true;
    }

    // LE REVERS, PAYE. La chance, quand la ligne en declare une pour lui, a
    // deja ete tiree par l'appelant -- une ligne a evenement la tire sur
    // l'EVENEMENT, non sur le bienfait.
    //
    // CE QUI COUPE SE PAIE APRES COUP. Un demi-tour d'horloge separe le
    // bienfait de sa contrepartie : le coup part, le chiffre s'affiche, le
    // geste se joue, PUIS le joueur en paie le prix. Un etourdissement
    // immediat tombe dans la meme image que le coup -- le client remplace
    // l'animation de l'attaque par celle de l'etourdissement, et la carte
    // semble punir sans avoir rien donne.
    void PayDrawback(Player* player, Drawback const& but, uint32 spellId, uint32 lastAmount,
                     int32 stacks = 1)
    {
        if (!but.Some() || !player)
            return;
        StellarTarotEffects::CompteRevers(player, spellId);
        if (!CostInterrupts(but.kind))
        {
            // Ce qui ne coupe rien tombe tout de suite, avec le bienfait.
            if (but.kind == "self_hit")
                Hurt(player, player, PctOf(lastAmount, but.n), SPELL_SCHOOL_MASK_NORMAL,
                     STELLAR_TAROT_SPELL_PRICE);
            else
                // LES REVERS QUI COMPTENT LES CUMULS lisent celui du bienfait,
                // retenu a la pose.
                // LES CUMULS DE LA PLAIE : les siens quand elle en a, ceux du
                // bienfait sinon.
                Cost(player, but.kind, but.n, but.n2, spellId, uint32(but.spell),
                     but.stacks ? but.stacks : stacks);
            return;
        }
        std::string const kind = but.kind;
        int32 const n = but.n, n2 = but.n2, mark = but.spell;
        uint32 const sort = spellId;
        PlusTard(player, APRES_COUP, [kind, n, n2, sort, mark](Player* p)
        {
            Cost(p, kind, n, n2, sort, uint32(mark));
        });
    }

    // LE REVERS, TIRE PUIS PAYE.
    void SufferDrawback(Player* player, Drawback const& but, uint32 spellId, uint32 lastAmount)
    {
        if (!but.Some() || !player)
            return;
        if (but.chance < 100 && int32(urand(1, 100)) > but.chance)
            return;
        PayDrawback(player, but, spellId, lastAmount);
    }

    // UN VERSEMENT SOUS CONDITION, a chaque battement. Les PV et le mana n'y
    // passent plus : le COEUR les verse lui-meme, par une aura permanente que
    // l'etat porte (auras 20 et 21, leur periode dans le sort). Ne reste que la
    // durabilite, que l'effet 111 sait bien reparer mais en le journalisant,
    // quand l'ecriture directe du module est muette.
    void SmallAction(Player* player, std::string const& action, int32 n, uint32 spellId = 0)
    {
        if (action == "repair") Mend(player, uint32(n));
        // `hurt` : une part des PV MAX, arrachee a chaque battement. Elle ne
        // tue pas -- le joueur ne descend jamais sous un point de vie.
        else if (action == "hurt") Bleed(player, PctOf(player->GetMaxHealth(), n), spellId);
    }
    bool SmallKind(std::string const& a) { return a == "repair" || a == "hurt"; }

    // -- aura helpers ----------------------------------------------------------

    // ================== UNE PART DES SCORES QUE LE JOUEUR PORTE ==================
    //
    // L'aura nomme un score par effet (MOD_RATING, son masque disant lequel) ;
    // on y ecrit cette part de ce que le joueur porte deja. L'aura est retiree
    // AVANT la lecture : sans cela elle compterait sa propre part.
    int32 FirstRating(int32 mask)
    {
        for (int32 cr = 0; cr < MAX_COMBAT_RATING; ++cr)
            if (mask & (1 << cr))
                return cr;
        return -1;
    }

    // Pose l'aura du niveau en y ecrivant, effet par effet, la part demandee
    // des scores du joueur. Rend false si le sort ne nomme aucun score.
    bool LayRatingShare(Player* player, uint32 spellId, std::vector<int32> const& parts, int32 seconds,
                        int32 cumuls = 1)
    {
        SpellInfo const* const info = sSpellMgr->GetSpellInfo(spellId);
        if (!info || !player)
            return false;
        // LES CUMULS SURVIVENT A LA MESURE. L'aura part pour que sa propre
        // part ne se compte pas dans le score lu ; sans ce rappel, chaque pose
        // la faisait repartir a UN cumul et la ligne ne montait jamais.
        int32 deja = 0;
        if (Aura const* ancienne = player->GetAura(spellId, player->GetGUID()))
            deja = int32(ancienne->GetStackAmount());
        player->RemoveAurasDueToSpell(spellId);          // sa part ne compte pas
        int32 bp[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
        bool porte[MAX_SPELL_EFFECTS] = { false, false, false };
        bool nomme = false;
        size_t compte = 0;
        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
        {
            if (info->Effects[i].ApplyAuraName != SPELL_AURA_MOD_RATING)
                continue;
            int32 const cr = FirstRating(info->Effects[i].MiscValue);
            if (cr < 0)
                continue;
            // UNE PART PAR SCORE NOMME, dans l'ordre ou le sort les nomme ;
            // la derniere vaut pour ceux qui suivent.
            int32 const part = parts.empty() ? 0
                             : parts[std::min<size_t>(compte, parts.size() - 1)];
            ++compte;
            nomme = porte[i] = true;
            int32 const own = std::max<int32>(0, int32(player->GetUInt32Value(
                uint16(PLAYER_FIELD_COMBAT_RATING_1) + uint16(cr))));
            // LA VALEUR FINALE, ET RIEN DE MOINS. `CastCustomSpell` ne prend pas
            // un chiffre de DBC : `Spell::SetSpellValue` (Spell.cpp:8556) range
            // `CalcBaseValue(valeur)`, qui retranche le de lui-meme et le
            // rendra a `CalcValue`. Retrancher le point ici le retranchait deux
            // fois -- et une part qui ne vaut qu'un point disparaissait tout
            // entiere (1 % de 60 en penetration d'armure, carte 82 niveau 3).
            bp[i] = int32(std::llround(double(own) * part / 100.0));
        }
        if (!nomme)
            return false;
        // CE QUI N'EST PAS UN SCORE GARDE LE CHIFFRE DU DBC : on ne passe de
        // valeur que pour les effets qu'on remplit.
        player->CastCustomSpell(player, spellId, porte[0] ? &bp[0] : nullptr,
                                porte[1] ? &bp[1] : nullptr, porte[2] ? &bp[2] : nullptr, true);
        if (Aura* laid = player->GetAura(spellId, player->GetGUID()))
        {
            // Le cumul d'avant, et un de plus, sans depasser le plafond de la
            // ligne : le coeur multiplie lui-meme la part par les cumuls.
            if (cumuls > 1)
            {
                uint8 const veut = uint8(std::min<int32>(deja + 1, cumuls));
                if (veut > 1)
                    laid->SetStackAmount(veut);
            }
            if (seconds)
            {
                laid->SetMaxDuration(seconds * 1000);
                laid->SetDuration(seconds * 1000);
            }
        }
        return true;
    }

    void ApplyOwned(Player* player, uint32 spellId)
    {
        if (spellId && !player->HasAura(spellId))
            player->AddAura(spellId, player);
    }
    void RemoveOwned(Player* player, uint32 spellId)
    {
        if (spellId)
            player->RemoveAurasDueToSpell(spellId);
    }

    bool SimpleState(Player const* player, std::string const& state)
    {
        if (state == "rested") return player->HasPlayerFlag(PLAYER_FLAGS_RESTING);
        if (state == "combat") return player->IsInCombat();
        if (state == "nocombat") return !player->IsInCombat();
        if (state == "solo") return !player->GetGroup();
        if (state == "night") return IsNight();
        if (state == "day") { int const h = LocalHour(); return h >= 6 && h < 21; }
        if (state == "water") return player->IsInWater();
        return false;
    }

    // =========================================================================
    // cond:<state>[:n]
    // =========================================================================
    class Cond : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _state = r.Word();
            static char const* const noArg[] = { "shield", "twohand", "dualwield", "unarmed", "solo", "night", "day",
                                                 "dawn_dusk", "combat", "nocombat", "rested", "water", "charmed",
                                                 "heirloom" };
            bool ok = false;
            for (char const* s : noArg)
                if (_state == s)
                    ok = true;
            if (ok)
                ; // nothing expected before the optional trailers below
            else if (_state == "still" || _state == "mounted" || _state == "walking" || _state == "running")
                ok = r.Int(1, 3600, _n) || (error = _state + " expects the seconds", false);
            else if (_state == "hp_below" || _state == "hp_above" || _state == "mana_below")
                ok = r.Int(1, 100, _n) || (error = _state + " expects a percentage", false);
            else if (_state == "aura")
                ok = r.Int(902000, 903999, _n) || (error = "aura expects a spell of the module", false);
            else if (_state == "gold_above")
                ok = r.Int(1, 2000000000, _n) || (error = "gold_above expects an amount of copper", false);
            else if (_state == "hour")
                ok = r.Int(0, 23, _n) && r.Int(0, 24, _m) || (error = "hour expects from and to", false);
            else
            {
                error = "unknown state \"" + _state + "\"";
                return false;
            }
            if (!ok)
                return false;
            // Optional: "stacks:<k>" -- one stack per period of the state
            // (still:5:stacks:5 = a stack every 5 s of standing still, up to 5);
            // or "tick:<sec>:<action>:<n>" -- while the state holds, every sec
            // seconds, the action (heal, mana, heal_both, repair) with n.
            while (!r.End())
            {
                std::string const word = r.Word();
                if (word == "stacks" && r.Int(2, 100, _stacks))
                    continue;
                // `grow:<k>` : CHAQUE BATTEMENT AJOUTE UN CUMUL a l'aura du
                // niveau, jusqu'a k. « chaque tic +2% degats. 10 cumuls ».
                if (word == "grow" && r.Int(2, 100, _monte))
                    continue;
                // and:<etat> : DEUX etats a la fois, « la nuit ET hors combat ».
                // Seuls les etats sans chiffre s'y ajoutent.
                if (word == "and")
                {
                    _and = r.Word();
                    static char const* const both[] = { "night", "day", "combat", "nocombat", "solo",
                                                        "rested", "water", "indoors", "outdoors" };
                    bool ok2 = false;
                    for (char const* e : both)
                        if (_and == e) ok2 = true;
                    if (!ok2)
                    {
                        error = "unknown second state \"" + _and + "\"";
                        return false;
                    }
                    continue;
                }
                if (word == "tick" && r.Int(1, 3600, _tickEvery))
                {
                    _tickAction = r.Word();
                    if (SmallKind(_tickAction) && r.Int(1, 100000, _tickN))
                        continue;
                }
                // rating:<pct>[:<pct>...] -- une part par score nomme, relue
                // tant que l'etat tient. Une part negative en retire.
                if (word == "rating" && r.Int(-1000, 1000, _ratingPct))
                {
                    _ratingParts.push_back(_ratingPct);
                    int32 autre = 0;
                    while (r.OptInt(-1000, 1000, autre))
                        _ratingParts.push_back(autre);
                    continue;
                }
                // hitroll:<quoi> -- CE QUE LE DE DU COUP BLANC NE DONNE PLUS
                // tant que l'etat tient. Le meme vocabulaire que la famille.
                if (word == "hitroll")
                {
                    _hitroll = r.Word();
                    if (_hitroll.empty()) { error = "hitroll expects a word"; return false; }
                    continue;
                }
                // sp:<pct> -- UNE PART DE LA PUISSANCE DES SORTS du joueur,
                // relue tant que l'etat tient : le DBC ne porte pas ce
                // chiffre-la, le module l'y met a la pose. Le meme chemin que
                // chez `proc`, dont c'est deja la garniture.
                if (word == "sp" && r.Int(1, 1000, _spPct))
                    continue;
                error = "after the state, only stacks:<k>, tick:<sec>:<action>:<n>, "
                        "sp:<pct> or rating:<pct> may follow";
                return false;
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _stillSince = 0; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); }
        void OnTick(Player* player) override
        {
            Check(player);
            if (_tickEvery && player->HasAura(_spellId) && ++_ticked >= uint32(_tickEvery))
            {
                _ticked = 0;
                SmallAction(player, _tickAction, _tickN, _spellId);
                // L'AURA QUI MONTE AVEC LES BATTEMENTS.
                if (_monte)
                {
                    ApplyOwned(player, _spellId);
                    if (Aura* aura = player->GetAura(_spellId, player->GetGUID()))
                        if (int32(aura->GetStackAmount()) < _monte)
                            aura->ModStackAmount(1);
                }
            }
        }
        void OnEnterCombat(Player* player) override { Check(player); }
        void OnLeaveCombat(Player* player) override { Check(player); }
        // UN COUP ENCAISSE COUPE LA COURSE : le compte repart de zero et le
        // bienfait tombe aussitot, sans attendre le battement suivant.
        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& /*damage*/, bool /*spell*/,
                           uint32 /*school*/, uint32 /*spellId*/) override
        {
            if (_state != "running" || !player)
                return;
            _stillSince = 0;
            RemoveOwned(player, _spellId);
        }
        // LE DE DU COUP BLANC, tant que l'etat tient.
        void OnMeleeRoll(Player* player, Unit* /*autre*/, bool mien, int32& /*crit*/,
                         int32& /*miss*/, int32& dodge, int32& parry, int32& block) override
        {
            if (_hitroll.empty() || !player || !Holds(player))
                return;
            if (_hitroll == "noblock")
            {
                if (mien)
                    block = 0;
                return;
            }
            if (mien)
                return;
            if (_hitroll == "nododge")
                dodge = 0;
            else if (_hitroll == "noparry")
                parry = 0;
        }

    private:
        // L'etat de la ligne, et le second quand elle en nomme un : les deux
        // doivent tenir ensemble.
        bool Holds(Player* player)
        {
            if (!_and.empty())
            {
                std::string const first = _state;
                int32 const n = _n;
                _state = _and; _n = 0;
                bool const second = HoldsOne(player);
                _state = first; _n = n;
                if (!second)
                    return false;
            }
            return HoldsOne(player);
        }
        bool HoldsOne(Player* player)
        {
            // LES ETATS QUI DURENT restent ici : chacun a sa propre remise a
            // zero, que le vocabulaire ne saurait dire. Tous les autres mots
            // s'y lisent d'un seul endroit.
            if (_state == "mounted")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                if (!player->IsMounted()) { _stillSince = 0; return false; }
                if (!_stillSince) _stillSince = now;
                return now - _stillSince >= uint32(_n);
            }
            // MARCHER, c'est-a-dire bouger hors de tout combat, et depuis assez
            // longtemps. La position est relevee a chaque tic : un joueur arrete
            // ou pris dans un combat repart de zero.
            if (_state == "walking")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                float const x = player->GetPositionX(), y = player->GetPositionY();
                bool const moved = std::fabs(x - _x) > 0.1f || std::fabs(y - _y) > 0.1f;
                _x = x; _y = y;
                if (player->IsInCombat() || !moved)
                {
                    _stillSince = 0;
                    return false;
                }
                if (!_stillSince)
                    _stillSince = now;
                return now - _stillSince >= uint32(_n);
            }
            // COURIR SANS S'ARRETER ET SANS ETRE TOUCHE. La course doit etre
            // CONTINUE : s'arreter remet le compte a zero, tout comme un coup
            // encaisse (OnDamageTaken), et le bienfait tombe entier dans les
            // deux cas. Le combat n'y change rien tant qu'aucun coup ne porte,
            // et le tic d'un effet periodique n'est pas un coup : le coeur
            // l'annonce par un autre chemin.
            if (_state == "running")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                float const x = player->GetPositionX(), y = player->GetPositionY();
                bool const moved = std::fabs(x - _x) > 0.1f || std::fabs(y - _y) > 0.1f;
                _x = x; _y = y;
                if (!moved)
                {
                    _stillSince = 0;
                    return false;
                }
                if (!_stillSince)
                    _stillSince = now;
                return now - _stillSince >= uint32(_n);
            }
            if (_state == "still")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                float const x = player->GetPositionX(), y = player->GetPositionY();
                if (!_stillSince || std::fabs(x - _x) > 0.1f || std::fabs(y - _y) > 0.1f)
                {
                    _stillSince = now; _x = x; _y = y;
                }
                return now - _stillSince >= uint32(_n);
            }
            return EtatTenu(_state, _n, _m, player, player, nullptr);
        }
        void Check(Player* player)
        {
            if (!Holds(player))
            {
                RemoveOwned(player, _spellId);
                return;
            }
            // UNE PART DES SCORES : relue a chaque battement, l'aura etant
            // reposee quand le chiffre bouge.
            if (_ratingPct)
            {
                LayRatingShare(player, _spellId, _ratingParts, 0);
                return;
            }
            // UNE PART DE LA PUISSANCE DES SORTS, de meme : l'aura est retiree
            // d'abord, pour qu'elle ne se nourrisse pas d'elle-meme. Les effets
            // que le DBC porte deja a leur chiffre -- le revers d'une ligne,
            // par exemple -- ne sont pas ecrases : seuls les deux premiers
            // (degats et soins) recoivent la part.
            if (_spPct)
            {
                int32 const own = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC));
                int32 const bp = int32(std::llround(double(own) * _spPct / 100.0));
                if (Aura const* deja = player->GetAura(_spellId, player->GetGUID()))
                    if (AuraEffect const* premier = deja->GetEffect(0))
                        if (premier->GetAmount() == bp)
                            return;             // rien n'a bouge
                RemoveOwned(player, _spellId);
                SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
                int32 veut[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                {
                    if (!info)
                        continue;
                    bool const part = info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE
                                   || info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_HEALING_DONE;
                    veut[i] = part ? bp : info->Effects[i].CalcValue(player);
                }
                player->CastCustomSpell(player, _spellId, &veut[0], &veut[1], &veut[2], true);
                return;
            }
            ApplyOwned(player, _spellId);
            if (_stacks > 1 && _n > 0)
            {
                // One stack per period held, from the first at the threshold.
                uint32 const now = uint32(GameTime::GetGameTime().count());
                uint32 const held = _stillSince ? now - _stillSince : 0;
                int32 const want = std::min<int32>(_stacks, std::max<int32>(1, int32(held / uint32(_n))));
                if (Aura* aura = player->GetAura(_spellId))
                    if (int32(aura->GetStackAmount()) != want)
                        aura->SetStackAmount(uint8(want));
            }
        }
        std::string _state, _and, _tickAction, _hitroll;
        int32 _n = 0, _m = 0, _stacks = 1, _tickEvery = 0, _tickN = 0, _ratingPct = 0, _spPct = 0;
        int32 _monte = 0;           // les cumuls que les battements ajoutent
        std::vector<int32> _ratingParts;
        uint32 _ticked = 0;
        uint32 _stillSince = 0;
        float _x = 0, _y = 0;
    };

    // =========================================================================
    // proc:<event>:<chance>:<icd>:<action>[:<params>][:trigger:<spell>][:cost:<kind>:<n>]
    // =========================================================================
    // LE SORT D'UNE FIOLE : declare ici, la ou le proc en a besoin ; ce que
    // « potion » veut dire est dit plus bas, aupres des autres fioles.
    bool EstUnePotion(Spell* spell);

    // UN SORT DE METIER QUI CREE UN OBJET : ce que le classeur appelle
    // « objet fabrique ». Conjurer du pain n'en est pas -- la competence doit
    // etre un METIER, primaire ou secondaire, et le coeur le dit lui-meme.
    bool EstUneFabrication(SpellInfo const* info)
    {
        if (!info || (!info->HasEffect(SPELL_EFFECT_CREATE_ITEM) && !info->HasEffect(SPELL_EFFECT_CREATE_ITEM_2)))
            return false;
        SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(info->Id);
        for (auto it = bornes.first; it != bornes.second; ++it)
            if (SkillLineEntry const* ligne = sSkillLineStore.LookupEntry(it->second->SkillLine))
                if (ligne->categoryId == SKILL_CATEGORY_PROFESSION
                    || ligne->categoryId == SKILL_CATEGORY_SECONDARY)
                    return true;
        return false;
    }

    class Proc : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _event = r.Word();
            static char const* const plain[] = { "kill", "kill_boss", "kill_elite", "kill_humanoid", "hit", "hit_weapon", "hit_melee",
                                                 "enter_instance", "dmg_taken_back",
                                                 "hit_spell", "hit_ranged", "dmg_taken", "dmg_taken_phys", "dmg_taken_magic", "spell_cast",
                                                 "spell_cast_dmg", "spell_cast_heal", "spell_cast_timed",
                                                 "school_change", "school_same", "spell_repeat", "craft", "potion", "pet_death",
                                                 "spell_cast_periodic", "enter_capital",
                                                 "hits_taken_row", "played", "loot_grey", "ally_death", "hit_far", "run", "spell_many",
                                                 "ally_reached",
                                                 "tool",
                                                 "hour_strike",
                                                 "spell_crit_fire", "wand",
                                                 "heal", "heal_ally", "heal_full", "enter_combat", "leave_combat", "levelup", "resurrect",
                                                 "zone", "quest", "loot_gold", "vendor_buy", "repair",
                                                 "flight_end", "loot_creature", "loot_humanoid", "vendor_sell",
                                                 "auction_post", "auction_won",
                                                 "jump", "jump_combat", "death", "pet_hit",
                                                 "crit", "spell_crit", "heal_crit", "dodge", "parry", "block", "crit_taken", "miss",
                                                 "fever" };
            bool known = false;
            for (char const* e : plain)
                if (_event == e) known = true;
            if (_event == "dismount")
            {
                known = true;
                if (!r.Int(1, 86400, _eventN)) { error = "dismount expects the seconds"; return false; }
            }
            // `hits_taken_row:<n>` : n coups SUBIS d'affilee sans en rendre.
            // `played:<sec>` : toutes les sec secondes passees EN JEU.
            if (_event == "hits_taken_row" || _event == "played" || _event == "ally_death"
                || _event == "hit_far" || _event == "run" || _event == "spell_many")
            {
                if (!r.Int(1, 86400, _eventN))
                { error = _event + " expects its count"; return false; }
            }
            // `ally_reached:<m>:<sec>` : un allie qui etait a plus de m metres
            // et qu'on a rejoint en moins de sec secondes.
            if (_event == "ally_reached")
            {
                known = true;
                if (!r.Int(1, 200, _eventN) || !r.Int(1, 60, _eventM))
                { error = "ally_reached expects the metres then the seconds"; return false; }
            }
            if (_event == "spin")
            {
                known = true;
                if (!r.Int(1, 100, _eventN)) { error = "spin expects how many turns"; return false; }
                // Le sens, quand la carte en demande un : a gauche l'orientation
                // monte, a droite elle descend.
                if (r.Peek() == "left" || r.Peek() == "right")
                    _spinWay = r.Word() == "left" ? 1 : -1;
            }
            if (_event == "ally_low")
            {
                known = true;
                if (!r.Int(1, 100, _eventN) || !r.Int(1, 99, _eventM))
                {
                    error = "ally_low expects the yards then the share of health";
                    return false;
                }
            }
            if (_event == "spell_cast_row")
            {
                known = true;
                if (!r.Int(2, 100, _eventN) || !r.Int(1, 3600, _eventM))
                {
                    error = "spell_cast_row expects the number of spells then the seconds that break the run";
                    return false;
                }
            }
            if (_event == "tick" || _event == "every" || _event == "hp_below" || _event == "mana_below"
                || _event == "spell_cast_school" || _event == "hit_spell_school"
                || _event == "death_near" || _event == "spell_cast_id"
                || _event == "no_spend" || _event == "nocombat")
            {
                known = true;
                if (!r.Int(1, 86400, _eventN)) { error = _event + " expects a number"; return false; }
            }
            if (!known) { error = "unknown event \"" + _event + "\""; return false; }
            // LA CHANCE SE LIT EN POUR-CENT ET SE GARDE EN POUR MILLE : « 2.5 »
            // est la plus fine que la ligne sache dire, et « 10 » vaut ce qu'il
            // a toujours valu.
            if (!r.Mille(0, 1000, _chance) || !r.Int(0, 86400, _icd)) { error = "expects the chance then the cooldown"; return false; }
            _action = r.Word();
            bool ok = true;
            std::string const& A = _action;
            if (A == "cost_next")
            {
                if (!r.Int(1, 100, _a)) { error = "cost_next expects the percentage"; return false; }
            }
            else if (A == "burn")
            {
                if (!r.Int(1, 3600, _a) || !r.Int(1, 1000, _b)) { error = "burn expects the seconds then the share"; return false; }
            }
            // `next_crit[:<combien>]` : le compte des sorts promis vit dans le
            // DBC (ProcCharges) ; la ligne le dit pour que le generateur l'y
            // mette, et le moteur n'en fait rien de plus.
            else if (A == "next_crit")
            {
                r.OptInt(1, 10, _a);
                ok = true;
            }
            else if (A == "none" || A == "restore" || A == "recast" || A == "repair_all" || A == "next_sure"
                     || A == "next_instant" || A == "next_all" || A == "next_quick"
                     || A == "next_sharp"
                     || A == "extra_shot" || A == "extra_copy" || A == "free_repair" || A == "crate"
                     || A == "craft_copy" || A == "craft_refund" || A == "reset_one_cooldown"
                     || A == "reset_all_cooldowns"
                     || A == "grey_item" || A == "gem")
                ok = true;
            else if (A == "repair_one" || A == "refund" || A == "refund_amount" || A == "resurrect"
                     || A == "reflect" || A == "cast_next")
                ok = r.Int(1, 100, _a);
            else if (A == "mana_pm")
                ok = r.Int(1, 1000, _a);
            else if (A == "leech_pet")
                ok = r.Int(1, 100, _a);
            else if (A == "aura" || A == "aura_target" || A == "aura_pet")
                ok = r.Int(0, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "aura_group")
                ok = r.Int(1, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "heal_other" || A == "heal" || A == "mana" || A == "heal_both" || A == "leech" || A == "mirror"
                     || A == "copper_per_damage"
                     || A == "free_next" || A == "cooldowns" || A == "reset_cooldowns" || A == "repair" || A == "gold_mult"
                     || A == "immune_snare" || A == "root" || A == "stun" || A == "disorient" || A == "fear" || A == "sleep"
                     || A == "silence" || A == "knockback" || A == "pull")
                ok = r.Int(1, 100000, _a);
            else if (A == "reset_long_cooldowns")
            {
                if (!r.Int(1, 86400, _a)) { error = "reset_long_cooldowns expects the seconds"; return false; }
                r.OptInt(1, 100, _b);
            }
            else if (A == "sleep_area" || A == "stun_area" || A == "fear_area")
            {
                if (!r.Int(1, 60, _a) || !r.Int(1, 100, _b))
                { error = A + " expects the seconds then the radius"; return false; }
            }
            // `gold_slice:<tranche>:<or>:<plafond>` : tant d'or par tranche de
            // tant d'or possede, jamais au-dela du plafond. Tout en PIECES D'OR.
            else if (A == "gold_slice")
            {
                if (!r.Int(1, 1000000, _a) || !r.Int(1, 1000000, _b) || !r.Int(1, 1000000, _c))
                { error = "gold_slice expects the slice, the gold and the cap"; return false; }
            }
            else if (A == "invisible")
            {
                if (!r.Int(1, 60, _a)) { error = "invisible expects the seconds"; return false; }
                // `still` : et le joueur ne peut rien faire pendant ce temps --
                // « invisible, intangible, aucune action ».
                if (!r.End() && r.Peek() == "still")
                {
                    r.Word();
                    _b = 1;
                }
            }
            // `to_gold:<facteur>` : l'objet est change en or, tant de fois son
            // prix de vente.
            // `ignore_armor:<pct>` : le coup porte comme si la cible avait
            // d'autant moins d'armure. On ne triche pas sur la formule -- c'est
            // CELLE DU COEUR qu'on rejoue, avec une armure allegee, et l'on
            // ajoute la difference.
            else if (A == "ignore_armor")
            {
                if (!r.Int(1, 100, _a)) { error = "ignore_armor expects the percentage"; return false; }
            }
            // `lucky_event:<sec>:<cuivre par niveau>` : PILE OU FACE. Ou bien
            // la bourse s'arrondit, ou bien l'aura du niveau se pose pour le
            // temps dit -- « evenement chanceux, or ou +10% statistiques ».
            else if (A == "lucky_event")
            {
                if (!r.Int(1, 86400, _a) || !r.Int(1, 1000000, _b))
                { error = "lucky_event expects the seconds then the copper per level"; return false; }
            }
            // `spread_dots:<m>` : ce que le joueur avait pose sur le mort passe
            // sur un autre ennemi, a portee.
            else if (A == "spread_dots")
            {
                if (!r.Int(1, 100, _a)) { error = "spread_dots expects the radius"; return false; }
            }
            // `wild_splash:<pct>:<m>` : une cible au hasard alentour -- amie ou
            // non -- prend cette part du coup.
            else if (A == "wild_splash")
            {
                if (!r.Int(1, 1000, _a) || !r.Int(1, 100, _b))
                { error = "wild_splash expects the share then the radius"; return false; }
            }
            else if (A == "to_gold")
            {
                if (!r.Int(1, 1000, _a)) { error = "to_gold expects the factor"; return false; }
            }
            else if (A == "craft_skill" || A == "extra_attack")
            {
                if (!r.Int(1, 10, _a)) { error = A + " expects its count"; return false; }
            }
            else if (A == "loot_item")
                ok = r.Int(902000, 902999, _a);
            else if (A == "gold_level" || A == "silver_level" || A == "gold" || A == "loot_gold_level")
                ok = r.Int(1, 100000000, _a);
            else if (A == "loot_gold_rand" || A == "loot_gold_boss")
                ok = r.Int(0, 100000, _a) && r.Int(0, 100000, _b);
            // Les deux bouts de l'echelle, en CUIVRE : ce que laisse un monstre
            // de niveau 1, et ce que laisse un monstre du palier haut.
            else if (A == "loot_gold_scale")
                ok = r.Int(1, 2000000000, _a) && r.Int(1, 2000000000, _b);
            else if (A == "summon")
                ok = r.Int(902000, 903999, _a) && r.Int(1, 3600, _b);
            else if (A == "shield_self" || A == "shield_target" || A == "shield_other"
                     || A == "splash" || A == "cleave" || A == "explode"
                     || A == "heal_group" || A == "heal_ally_amount" || A == "heal_pet" || A == "bleed" || A == "blink")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b);
            else if (A == "bleed_hit")
                ok = r.Int(1, 3600, _a) && r.Int(1, 100, _b) && r.Int(902000, 903999, _c);
            else if (A == "turn" || A == "turn_ally")
                ok = r.Int(1, 3600, _a) && (r.OptInt(1, 100, _b) || true);
            else if (A == "shield_ally" || A == "shield_group" || A == "damage_sp" || A == "damage_ap" || A == "extra"
                     || A == "explode_sp" || A == "explode_ap" || A == "hp_dmg")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b) && (r.OptInt(0, 10000, _c) || true);
            else
            {
                error = "unknown action \"" + A + "\"";
                return false;
            }
            if (!ok) { error = A + ": bad parameters"; return false; }
            // Trailers, in any order: trigger:<spell>, but:<kind>:<n>[:<n2>],
            // chance:<n> (the drawback's own), say:<string>, night:<n>, onlynight.
            while (!r.End())
            {
                std::string const word = r.Word();
                if (word == "trigger" && r.Int(int32(STELLAR_TAROT_TRIGGER_FIRST), int32(STELLAR_TAROT_TRIGGER_LAST), _trigger))
                    continue;
                // CE QUE LE COEUR TIENT : `core:chance`, `core:icd`. La ligne de
                // `spell_proc` porte alors la chance et la recharge, et cette
                // ligne-ci cesse de les tirer -- sans quoi le filtre serait
                // applique deux fois.
                if (word == "core")
                {
                    while (!r.End() && (r.Peek() == "chance" || r.Peek() == "icd"))
                    {
                        if (r.Word() == "chance")
                            _coreChance = true;
                        else
                            _coreIcd = true;
                    }
                    continue;
                }
                // then:<chiffre>:<sec> -- CE QUI VIENT APRES : quand l'aura du
                // niveau tombe, elle est reposee a cet autre chiffre, pour ce
                // temps-la. Une suite, pas une boucle : ce qui revient, c'est
                // l'evenement, pas la sequence.
                if (word == "then" && r.Int(-1000, 1000, _thenPct) && r.Int(1, 3600, _thenSec))
                {
                    // Un sort propre a la seconde phase, s'il en a un : la
                    // premiere est un bienfait, la seconde une plaie, et un
                    // meme sort ne peut pas etre les deux.
                    r.OptInt(902000, 903999, _thenSpell);
                    continue;
                }
                // count:<sort> : l'aura qui COMPTE la serie, un cumul par
                // evenement, retiree des que la ligne paie ou que la serie tombe.
                if (word == "count" && r.Int(902000, 903999, _countSpell))
                    continue;
                // sign:<sort> : l'aura qui DIT que la ligne est armee, posee des
                // que la condition tient, retiree quand la ligne paie.
                if (word == "sign" && r.Int(902000, 903999, _signSpell))
                    continue;
                // debuff:<sort> : LE REVERS EN AURA A LUI, pose a cote du
                // bienfait -- meme duree, memes cumuls -- mais range parmi les
                // plaies et portant SON texte.
                if (word == "debuff" && r.Int(902000, 903999, _debuffSpell))
                    continue;
                // sp:<pct> : l'aura que l'action pose porte une puissance des
                // sorts lue sur celle du joueur, comme chez « cond ».
                if (word == "sp" && r.Int(1, 1000, _spPct))
                    continue;
                // heal:<pct> : LE SOIN QUI ACCOMPAGNE L'ACTION. Une ligne ne
                // porte qu'une action, et certaines cartes en promettent deux
                // d'un coup -- « rend 10% PV ET +20% vitesse de course ». Le
                // soin se donne AVANT l'action, comme le texte le dit.
                if (word == "heal" && r.Int(1, 100, _healPct))
                    continue;
                // only:<etat>[:<n>] : LA LIGNE NE PART QUE SOUS CET ETAT. Le
                // meme vocabulaire que « cond », lu au meme endroit : « Seul,
                // sortie de combat », « Si 2 armes equipees : ... ».
                if (word == "only")
                {
                    _only = r.Word();
                    if (_only.empty()) { error = "only expects a state"; return false; }
                    r.OptInt(1, 2000000000, _onlyN);
                    // Un second chiffre, quand l'etat en demande deux :
                    // « only:stacks:<sort>:<combien> ».
                    r.OptInt(1, 2000000000, _onlyM);
                    continue;
                }
                // deadline:<sec> : L'ECHEANCE. Chaque fois que la ligne part,
                // le compte repart ; s'il arrive au bout EN COMBAT sans que
                // rien ne soit reparti, le joueur tombe a un point de vie.
                if (word == "deadline" && r.Int(1, 3600, _echeance))
                    continue;
                // reset : TOUS LES TEMPS DE RECHARGE remis a zero avant
                // l'action. Une ligne ne porte qu'une action, et certaines
                // cartes en promettent deux d'un coup.
                if (word == "reset")
                {
                    _reset = true;
                    continue;
                }
                // restore : PV ET MANA REMIS A PLEIN avant l'action. Une
                // ligne ne porte qu'une action, et certaines cartes en
                // promettent deux -- « PV et mana restaures, +5% vitesse de
                // course, 5 min ».
                if (word == "restore")
                {
                    _restore = true;
                    continue;
                }
                // spend:<sort>[:<sort>...] : CE QUE LA LIGNE DEPENSE en
                // payant. Les auras nommees -- celles qu'un AUTRE niveau de la
                // meme carte empile -- sont retirees quand la ligne part.
                // « le prochain sort consomme les 5 cumuls ».
                if (word == "spend")
                {
                    int32 sort = 0;
                    while (r.OptInt(902000, 903999, sort))
                        _depense.push_back(uint32(sort));
                    if (_depense.empty()) { error = "spend expects at least one spell"; return false; }
                    continue;
                }
                // ally_hit:<pct>:<m> : LE COUP TOUCHE AUSSI UN ALLIE, pour
                // cette part. C'est une garniture et non une action : la ligne
                // garde la sienne pour ce qu'elle fait a la CIBLE.
                if (word == "ally_hit" && r.Int(1, 1000, _coupAllie) && r.Int(1, 100, _coupAllieM))
                    continue;
                // heal_dealt:<pct> : TANT QUE L'AURA DE LA LIGNE TIENT, ce
                // que le joueur inflige le soigne d'autant. C'est ainsi qu'une
                // promesse « +300% degats et vous soigne du meme montant » se
                // tient : l'aura porte les degats, la garniture le soin.
                if (word == "heal_dealt" && r.Int(1, 1000, _soinDuCoup))
                    continue;
                // low:<pct> : LA LIGNE NE PART QUE BLESSE. « Degats subis SOUS
                // 20% PV » -- l'evenement est le meme, la garde s'ajoute.
                if (word == "low" && r.Int(1, 100, _low))
                    continue;
                // rating:<pct>[:<pct>...] : une part par score nomme.
                if (word == "rating" && r.Int(-1000, 1000, _ratingPct))
                {
                    _ratingParts.push_back(_ratingPct);
                    int32 autre = 0;
                    while (r.OptInt(-1000, 1000, autre))
                        _ratingParts.push_back(autre);
                    continue;
                }
                // say:<chaine> : la phrase que CETTE ligne dit, a la place de
                // celle que son action dirait d'elle-meme.
                if (word == "say" && r.Int(1, 999, _say))
                    continue;
                // emote:<geste> : le personnage le joue quand la ligne tombe.
                if (word == "emote" && r.Int(1, 600, _emote))
                    continue;
                // LE REVERS : « but: » aujourd'hui, « cost: » hier -- le meme.
                if (word == "but" || word == "cost")
                {
                    if (!ReadDrawbackClause(r, _but, error))
                        return false;
                    continue;
                }
                // La chance du revers : sans elle, il tombe a chaque fois.
                if (word == "chance" && r.Int(1, 100, _but.chance))
                    continue;
                if (word == "night" && r.Int(1, 100000, _nightA))
                    continue;
                // LA NUIT RESSERRE LE RYTHME : la cadence qu'elle impose, en
                // secondes, a la place de celle du jour.
                if (word == "night_every" && r.Int(1, 86400, _nightEvery))
                    continue;
                // onlydark : la nuit OU en interieur -- ce que la carte
                // appelle « dans le noir ».
                if (word == "onlydark")
                {
                    _onlyDark = true;
                    continue;
                }
                if (word == "onlynight")
                {
                    _onlyNight = true;
                    continue;
                }
                error = "after the action, only trigger, but, chance, say, night or onlynight may follow";
                return false;
            }
            // SANS SON AURA, une ligne a marqueur ne partirait jamais : c'est
            // l'aura qui la designe quand le coeur lance le marqueur.
            if (FromProcSystem(_event) && !_trigger)
            {
                error = "this event comes from the core's proc system: the line must name its own "
                        "trigger aura -- trigger:<id>";
                return false;
            }
            return true;
        }
        // LES EVENEMENTS QUE LE SYSTEME DE PROCS DU COEUR ANNONCE, chacun par
        // son marqueur (903810 et suivants, dans cet ordre). Une ligne qui les
        // guette porte OBLIGATOIREMENT une aura trigger : c'est elle qui la
        // designe quand le marqueur part.
        static bool FromProcSystem(std::string const& event)
        {
            static char const* const events[] = { "crit", "spell_crit", "heal_crit", "dodge", "parry",
                                                  "block", "crit_taken", "miss", "spell_crit_fire" };
            for (char const* w : events)
                if (event == w)
                    return true;
            return false;
        }
        // LE COEUR A CONSOMME LA PROMESSE. Il a retire l'aura de l'etat au
        // premier coup qui repondait au masque -- un critique pour `next_crit`,
        // un coup qui porte pour `next_sure` -- et c'est maintenant, et
        // seulement maintenant, que le prix est du.
        void OnPromiseSpent(Player* player) override
        {
            if (!State())
                return;
            if (_but.Some() && _but.chance >= 100)
                Suffer(player);
        }
        // LE COEUR A FAIT PARTIR NOTRE AURA : la ligne n'a qu'a jouer.
        void OnTriggerProc(Player* player, Unit* other, uint32 amount) override
        {
            Fire(player, other, amount);
        }
        [[nodiscard]] uint32 Trigger() const override { return uint32(_trigger); }
        // CE QUE LA LIGNE PROMET, pour l'instrument de mesure.
        bool Promise(std::string& event, int32& chance, int32& icd,
                     bool& coreChance, bool& coreIcd) const override
        {
            event = _event;
            chance = _chance;
            icd = _icd;
            coreChance = _coreChance;
            coreIcd = _coreIcd;
            return true;
        }
        // A state the level's spell shows while it lasts: the module does not
        // apply that spell itself.
        bool State() const
        {
            return _action == "next_crit" || _action == "next_sure" || _action == "next_instant"
                || _action == "free_next" || _action == "cost_next";
        }
        // `aura_pet` compris : l'aura va sur la BETE, jamais sur le joueur --
        // sans cette declaration le cadre la posait aussi sur le maitre.
        bool OwnsAura() const override
        {
            return _action == "aura" || _action == "aura_target" || _action == "aura_group"
                || _action == "aura_pet" || State();
        }
        void Apply(Player* player) override
        {
            _last = 0; _wasBelow = false; _elapsed = 0; _row = 0; _idleSince = 0;
            if (_trigger)
                ApplyOwned(player, uint32(_trigger));
        }
        void Remove(Player* player) override
        {
            if (_action == "aura" || State()) RemoveOwned(player, _spellId);
            if (_action == "aura_pet")
                if (Pet* pet = player->GetPet())
                    pet->RemoveAurasDueToSpell(_spellId, player->GetGUID());
            if (_debuffSpell) RemoveOwned(player, uint32(_debuffSpell));
            if (_countSpell) RemoveOwned(player, uint32(_countSpell));
            if (_signSpell) RemoveOwned(player, uint32(_signSpell));
            if (_thenSpell) RemoveOwned(player, uint32(_thenSpell));
            if (_trigger) RemoveOwned(player, uint32(_trigger));
        }

        // UNE DEPENSE : le compte des secondes repart de zero.
        void OnSpend(Player* /*player*/) override
        {
            if (_event == "no_spend")
                _elapsed = 0;
        }

        // UN TOUR COMPLET SUR SOI-MEME. Le serveur ne voit de la rotation que
        // ce que les paquets de mouvement lui annoncent : on additionne ce qui
        // separe deux annonces, dans un sens comme dans l'autre, et le tour est
        // plein a 360 degres. Un coup de souris violent tient en peu de paquets
        // et compte donc tout autant qu'une rotation lente.
        // LE TIC DE LA FIEVRE : la carte le reconnait au sort, celui que la
        // famille `fever` a inscrit en se chargeant.
        void OnPeriodicTick(Player* player, Unit* /*other*/, uint32& /*amount*/, bool heal,
                            uint32 spellId) override
        {
            if (_event != "fever" || heal || !spellId)
                return;
            if (gFeverSpells.count(spellId))
                Fire(player, nullptr, 0);
        }

        // LE FAMILIER A FRAPPE : la ligne du maitre y repond, le coup lui etant
        // rapporte tel quel -- de quoi en rendre une part.
        void OnPetDamage(Player* player, Unit* victim, uint32& damage) override
        {
            if (_event == "pet_hit" && damage)
                Fire(player, victim, damage);
        }

        void OnFacing(Player* player, float x, float y, float orientation, uint32 moveFlags) override
        {
            if (_event != "spin")
                return;
            // LE TOUR SE FAIT SUR PLACE : un pas de cote et le compte repart.
            if (_lastFacing >= 0.0f)
            {
                float const dx = x - _lastX, dy = y - _lastY;
                if (dx * dx + dy * dy > 0.25f)          // un demi-pas suffit
                    _turned = 0.0f;
            }
            _lastX = x;
            _lastY = y;
            if (_lastFacing < 0.0f)
            {
                _lastFacing = orientation;
                return;
            }
            float ecart = orientation - _lastFacing;
            _lastFacing = orientation;
            while (ecart > float(M_PI)) ecart -= 2.0f * float(M_PI);
            while (ecart < -float(M_PI)) ecart += 2.0f * float(M_PI);
            // AU CLAVIER, L'ECART NE DIT RIEN. Le client n'annonce son orientation
            // qu'au moment ou la touche s'enfonce et quand elle se relache : entre
            // les deux le personnage a tourne de plusieurs tours, et l'ecart ne
            // garde que le reste. Mais le paquet dit AUSSI que le joueur TOURNE, et
            // le coeur connait sa vitesse de rotation : on compte alors cette
            // vitesse par le temps ecoule, ce qui est exact. A la souris, aucun
            // drapeau de rotation n'est leve et l'ecart, lui, suffit.
            //
            // Le paquet du relachement ne porte plus le drapeau : c'est l'etat
            // PRECEDENT qui dit ce qui s'est passe pendant le temps ecoule.
            uint32 const maintenant = uint32(GameTime::GetGameTimeMS().count());
            uint32 const passe = _lastMs ? maintenant - _lastMs : 0;
            int32 const sens = (moveFlags & MOVEMENTFLAG_LEFT) ? 1 : (moveFlags & MOVEMENTFLAG_RIGHT) ? -1 : 0;
            if (_wasTurning && passe && passe < 60000)
            {
                if (!_spinWay || _spinWay == _wasTurning)
                    _turned += player->GetSpeed(MOVE_TURN_RATE) * float(passe) / 1000.0f;
            }
            // A la souris, le signe de l'ecart dit le sens. Ce qui tourne du
            // mauvais cote ne compte pas -- il n'efface rien non plus.
            else if (!_spinWay || (ecart > 0.0f) == (_spinWay > 0))
                _turned += std::fabs(ecart);
            _wasTurning = sens;
            _lastMs = maintenant;
            if (_turned < float(_eventN) * 2.0f * float(M_PI))
                return;
            _turned = 0.0f;
            Fire(player, nullptr, 0);
        }

        // TANT QUE LA TOUCHE TIENT, le client n'annonce plus rien : le compte
        // avance ici, une fois par seconde, pour que le tour se voie sans
        // attendre que le joueur lache la touche.
        void Turning(Player* player)
        {
            if (_event != "spin" || !_wasTurning)
                return;
            uint32 const maintenant = uint32(GameTime::GetGameTimeMS().count());
            uint32 const passe = _lastMs ? maintenant - _lastMs : 0;
            _lastMs = maintenant;
            if (!passe || passe >= 60000)
                return;
            if (_spinWay && _spinWay != _wasTurning)
                return;
            _turned += player->GetSpeed(MOVE_TURN_RATE) * float(passe) / 1000.0f;
            if (_turned < float(_eventN) * 2.0f * float(M_PI))
                return;
            _turned = 0.0f;
            Fire(player, nullptr, 0);
        }

        void OnTick(Player* player) override
        {
            Turning(player);
            if (_event == "tick")
            {
                if (!player->IsInCombat()) { _elapsed = 0; return; }
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            else if (_event == "every")
            {
                // LA CADENCE DE LA NUIT, quand la ligne en declare une.
                uint32 const chaque = (_nightEvery && IsNight()) ? uint32(_nightEvery)
                                                                 : uint32(_eventN);
                if (++_elapsed >= chaque) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            // UN ALLIE EN DANGER : on regarde alentour a chaque seconde. Le
            // delai de la ligne fait le reste -- sans lui, la sentinelle
            // repondrait a chaque battement tant que l'allie reste bas.
            else if (_event == "ally_low")
            {
                std::list<Unit*> autour;
                Acore::AnyFriendlyUnitInObjectRangeCheck check(player, player, float(_eventN));
                Acore::UnitListSearcher<Acore::AnyFriendlyUnitInObjectRangeCheck> searcher(player, autour, check);
                Cell::VisitObjects(player, searcher, float(_eventN));
                for (Unit* ami : autour)
                {
                    if (!ami || ami == player || !ami->IsAlive())
                        continue;
                    if (ami->GetHealthPct() >= float(_eventM))
                        continue;
                    Fire(player, ami, 0);
                    break;
                }
            }
            // LE TEMPS DE PAIX : les secondes hors combat se comptent ici. Le
            // combat les efface et rearme la ligne ; une meme paix ne donne donc
            // son bienfait qu'une fois, si longue soit-elle.
            else if (_event == "nocombat")
            {
                if (player->IsInCombat())
                {
                    _elapsed = 0;
                    _peaceSpent = false;
                }
                else if (!_peaceSpent && ++_elapsed >= uint32(_eventN))
                {
                    _elapsed = 0;
                    _peaceSpent = true;
                    Fire(player, nullptr, 0);
                }
            }
            // LES SECONDES SANS DEPENSE : elles se comptent ici, et la moindre
            // piece versee a un marchand ou a l'hotel des ventes les efface.
            else if (_event == "no_spend")
            {
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            // LA SERIE SE ROMPT QUAND LE JOUEUR CESSE D'INCANTER : tant qu'un
            // sort est en cours, le temps ne court pas ; une fois assez de
            // secondes passees sans rien lancer, le compte tombe a zero.
            else if (_event == "spell_cast_row")
            {
                if (!_row)
                    return;
                uint32 const now = uint32(GameTime::GetGameTime().count());
                if (player->IsNonMeleeSpellCast(false))
                    _idleSince = 0;
                else if (!_idleSince)
                    _idleSince = now;
                else if (now - _idleSince >= uint32(_eventM))
                {
                    _row = 0;
                    _idleSince = 0;
                    if (_countSpell)
                        RemoveOwned(player, uint32(_countSpell));
                }
            }
            else if (_event == "hp_below" || _event == "mana_below")
            {
                float const pct = _event == "hp_below" ? player->GetHealthPct() : player->GetPowerPct(POWER_MANA);
                bool const below = pct < float(_eventN);
                if (below && !_wasBelow)
                    Fire(player, player->GetVictim(), 0);
                _wasBelow = below;
            }
            // COURIR SANS S'ARRETER ET SANS ETRE TOUCHE. La course doit etre
            // CONTINUE : s'arreter remet le compte a zero, tout comme un coup
            // encaisse (voir OnDamageTaken). La ligne ne part qu'une fois par
            // course : le compte repart apres qu'elle a paye.
            else if (_event == "run")
            {
                float const x = player->GetPositionX(), y = player->GetPositionY();
                bool const bouge = std::fabs(x - _courseX) > 0.1f || std::fabs(y - _courseY) > 0.1f;
                _courseX = x; _courseY = y;
                if (!bouge)
                {
                    _course = 0;
                    return;
                }
                if (++_course >= uint32(_eventN))
                {
                    _course = 0;
                    Fire(player, nullptr, 0);
                }
            }
            // L'ALLIE QU'ON REJOINT : on retient depuis quand chacun etait
            // LOIN ; celui qu'on retrouve a portee assez vite paie la ligne.
            else if (_event == "ally_reached")
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                for (Player* ami : GroupAround(player, 200.0f))
                {
                    if (!ami || ami == player)
                        continue;
                    ObjectGuid const qui = ami->GetGUID();
                    float const d = player->GetDistance(ami);
                    if (d > float(_eventN))
                    {
                        _loin[qui] = now;
                        continue;
                    }
                    auto const it = _loin.find(qui);
                    if (it == _loin.end())
                        continue;
                    bool const vite = now - it->second <= uint32(_eventM);
                    _loin.erase(it);
                    if (vite)
                        Fire(player, ami, ami->GetMaxHealth());
                }
            }
            // L'ECHEANCE QUI TUE : en combat seulement, et remise a zero par
            // chaque depart de la ligne. Hors combat, rien ne court.
            if (_echeance)
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                if (!player->IsInCombat())
                    _depuisEcheance = now;
                else if (!_depuisEcheance)
                    _depuisEcheance = now;
                else if (now - _depuisEcheance >= uint32(_echeance))
                {
                    _depuisEcheance = now;
                    if (player->GetHealth() > 1)
                        Bleed(player, uint32(player->GetHealth() - 1), _spellId);
                }
            }
            // TOUTES LES N SECONDES PASSEES EN JEU : le compte ne court que
            // tant que le joueur est la, et repart a zero a chaque paiement.
            else if (_event == "played")
            {
                if (++_secondesDeJeu >= uint32(_eventN))
                {
                    _secondesDeJeu = 0;
                    Fire(player, nullptr, 0);
                }
            }
            // L'HEURE PLEINE : le serveur ne sonne pas les heures, la ligne
            // regarde donc l'horloge a chaque tic. La premiere lecture ne
            // sonne rien -- on ne sait pas encore d'ou l'on vient.
            else if (_event == "hour_strike")
            {
                int const heure = LocalHour();
                if (_heureVue >= 0 && heure != _heureVue)
                    Fire(player, nullptr, 0);
                _heureVue = heure;
            }
            // LE FAMILIER EST MORT : le coeur ne previent personne, la ligne
            // regarde donc elle-meme, une fois par seconde. Un maitre qui
            // range sa bete ne la perd pas : seule une bete MORTE compte.
            else if (_event == "pet_death")
            {
                Pet* const bete = player->GetPet();
                bool const vivante = bete && bete->IsAlive();
                if (_avaitBete && !vivante)
                    Fire(player, nullptr, 0);
                _avaitBete = vivante;
            }
            // The end of a flight: the core tells no one when a taxi sets its
            // passenger down, so the card watches -- once a second is enough
            // for something that lasts minutes.
            else if (_event == "flight_end")
            {
                bool const flying = player->IsInFlight();
                if (_wasFlying && !flying)
                    Fire(player, nullptr, 0);
                _wasFlying = flying;
            }
            // DESCENDRE DE MONTURE APRES UN VRAI TRAJET : les secondes en selle
            // se comptent ici, le coeur n'annoncant rien ; un trajet trop court
            // ne vaut rien et le compte repart de zero a chaque descente.
            else if (_event == "dismount")
            {
                bool const mounted = player->IsMounted();
                if (mounted)
                {
                    ++_elapsed;
                    // LE SIGNE : des que le trajet est assez long, le joueur voit
                    // qu'il touchera son du en descendant.
                    if (_signSpell && _elapsed == uint32(_eventN))
                        ApplyOwned(player, uint32(_signSpell));
                }
                else if (_wasMounted)
                {
                    if (_signSpell)
                        RemoveOwned(player, uint32(_signSpell));
                    if (_elapsed >= uint32(_eventN))
                        Fire(player, nullptr, 0);
                    _elapsed = 0;
                }
                _wasMounted = mounted;
            }
        }
        void OnCreatureKill(Player* player, Creature* killed) override
        {
            if (_event == "kill" || (_event == "kill_boss" && IsBoss(killed)) || (_event == "kill_elite" && IsElite(killed))
                || (_event == "kill_humanoid" && killed && killed->GetCreatureType() == CREATURE_TYPE_HUMANOID))
                Fire(player, killed, killed ? killed->GetMaxHealth() : 0);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 school,
                           uint32 spellId) override
        {
            // LE COUP DU REFLET : il vaut la part promise de l'original, et il
            // ne se reflete pas lui-meme.
            if (_mirrorSpell && spellId == _mirrorSpell)
            {
                if (_mirrorAmount)
                    damage = _mirrorAmount;
                _mirrorSpell = 0;
                _mirrorAmount = 0;
                return;
            }
            // COMBIEN DE MONDE UN SORT A TOUCHE : le coeur ne le dit pas. On
            // compte les coups que LE MEME sort porte a des victimes
            // DIFFERENTES ; un nouveau sort, ou une seconde qui passe, remet
            // le compte a zero.
            if (_event == "spell_many" && spell && spellId && victim)
            {
                uint32 const now = uint32(GameTime::GetGameTimeMS().count());
                if (spellId != _sortTouche || now - _depuisTouche > 500)
                {
                    _sortTouche = spellId;
                    _depuisTouche = now;
                    _touches.clear();
                    _ditTouche = false;
                }
                _touches.insert(victim->GetGUID());
                if (!_ditTouche && int32(_touches.size()) >= _eventN)
                {
                    _ditTouche = true;
                    Fire(player, victim, damage);
                }
            }
            // UN COUP PORTE DE LOIN : la distance au moment ou il tombe.
            if (_event == "hit_far" && victim && player->GetDistance(victim) > float(_eventN))
                Fire(player, victim, damage);
            // LA PROMESSE QUI SOIGNE : tant que l'aura de la ligne tient, ce
            // que le joueur inflige le soigne d'autant.
            if (_soinDuCoup && damage && _spellId && player->HasAura(uint32(_spellId)))
                Heal(player, player, PctOf(damage, _soinDuCoup), _spellId);
            // RENDRE UN COUP rompt la serie des coups subis.
            _coupsSubis = 0;
            if (spellId)
                _lastSpellId = spellId;
            // L'ECOLE DU COUP : une ligne qui double les degats sans nommer
            // d'ecole doit rendre la meme monnaie -- du feu pour du feu.
            if (school)
                _lastSchool = school;
            // Kept for the markers, which the core fires just after the blow.
            if (victim && damage)
            {
                _lastVictim = victim->GetGUID();
                _lastAmount = damage;
            }
            if (_event == "hit" || (_event == "hit_spell" && spell))
                Fire(player, victim, damage);
            // L'IMPACT D'UN SORT D'UNE ECOLE NOMMEE. Le coup a porte, et c'est
            // l'ECOLE DU COUP qui compte, non celle du sort qu'on a voulu : un
            // sort qui rate, qui est resiste ou qui n'inflige rien ne passe pas
            // par ici. Ce qui se donne ici se gagne sur le coup.
            else if (_event == "hit_spell_school" && spell && (school & uint32(_eventN)))
                Fire(player, victim, damage);
            // LE CORPS A CORPS NOMME : l'attaque automatique et la competence
            // dont la classe de degats est celle d'une arme de melee. Un sort
            // ne compte pas -- c'est `hit_spell`, et `hit_weapon` vaut pour les
            // deux armes a la fois.
            else if (_event == "hit_melee")
            {
                bool melee = !spell;
                if (spell)
                    if (SpellInfo const* const info = Info(spellId))
                        melee = info->DmgClass == SPELL_DAMAGE_CLASS_MELEE;
                if (melee)
                    Fire(player, victim, damage);
            }
            // UN COUP DE TRAIT : le coeur range un sort par sa CLASSE DE DEGATS,
            // et c'est elle qui dit le tir -- le trait ordinaire comme la fleche
            // que porte un sort de chasseur.
            else if (_event == "hit_ranged")
            {
                SpellInfo const* const info = Info(spellId);
                if (info && info->DmgClass == SPELL_DAMAGE_CLASS_RANGED)
                    Fire(player, victim, damage);
            }
            // L'ARME ET LE GESTE, MAIS PAS LE SORT : une attaque automatique,
            // ou une competence dont la classe de degats est celle d'une arme
            // (melee ou distance). Un sort de magie ne compte pas.
            else if (_event == "hit_weapon")
            {
                bool weapon = !spell;
                if (spell)
                    if (SpellInfo const* const info = Info(spellId))
                        weapon = info->DmgClass == SPELL_DAMAGE_CLASS_MELEE
                              || info->DmgClass == SPELL_DAMAGE_CLASS_RANGED;
                if (weapon)
                    Fire(player, victim, damage);
            }
            // A wand shot -- the wand's own, and the second shot a card grants,
            // which is a shot like any other: it gives back mana, it feeds
            // every other line the card has. The ONE line it does not feed is
            // the line that granted it, or the two would answer each other
            // without end. Nothing is counted or timed: the shot says what it
            // is by its identifier.
            else if (_event == "wand" && spell && IsWandBlow(player, spellId))
            {
                if (spellId == STELLAR_TAROT_SPELL_WAND_SHOT && _action == "extra_shot")
                    return;
                Fire(player, victim, damage);
            }
        }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool spell, uint32 /*school*/,
                           uint32 spellId) override
        {
            // LE SORT QU'ON VIENT DE SUBIR : « le reflechir » n'a pas d'autre
            // source, le coeur ne le gardant nulle part.
            if (spell && spellId)
                _sortSubi = spellId;
            // UN COUP ENCAISSE ROMPT LA COURSE.
            _course = 0;
            // LES COUPS SUBIS D'AFFILEE SANS EN RENDRE : en rendre un remet le
            // compte a zero (voir OnDamageDealt).
            if (_event == "hits_taken_row")
            {
                if (++_coupsSubis >= uint32(_eventN))
                {
                    _coupsSubis = 0;
                    Fire(player, attacker, damage);
                }
            }
            if (_event == "dmg_taken" || (_event == "dmg_taken_phys" && !spell) || (_event == "dmg_taken_magic" && spell))
                Fire(player, attacker, damage);
            // DANS LE DOS : l'assaillant n'est pas dans le demi-cercle que le
            // joueur a devant lui.
            else if (_event == "dmg_taken_back" && attacker && !player->HasInArc(float(M_PI), attacker))
                Fire(player, attacker, damage);
        }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            if (_event == "heal" || (_event == "heal_ally" && target != player))
                Fire(player, target, gain);
            // A PLEINE VIE : l'allie n'a rien a recevoir du soin, et la carte
            // lui donne autre chose. Le coeur appelle ce crochet AVANT que la
            // vie ne monte : ce qu'on lit ici est bien l'etat d'avant.
            else if (_event == "heal_full" && target && target != player && target->IsFullHealth())
                Fire(player, target, gain);
        }
        // A spell the player casts himself -- or a MARKER the core's proc
        // system casts for him: the event it stands for. A free cast granted
        // earlier is refunded here.
        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (spell->IsTriggered())
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            bool fires = _event == "spell_cast";
            // spell_cast_id:<sort> : CE sort-la, nomme par son identifiant.
            if (_event == "spell_cast_id")
                fires = int32(info->Id) == _eventN;
            if (_event == "spell_cast_school")
                fires = (info->GetSchoolMask() & uint32(_eventN)) != 0;
            else if (_event == "spell_cast_dmg")
                fires = !info->IsPositive();
            else if (_event == "spell_cast_heal")
                fires = info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                        || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH);
            // UN SORT QUI DEMANDE UNE INCANTATION, telle que le lanceur la
            // subit : hate et modificateurs comptes. Un sort rendu instantane
            // par le module ne compte donc plus pour un sort a incantation --
            // rien ne s'enchaine tout seul.
            else if (_event == "spell_cast_timed")
                fires = info->CalcCastTime(player, spell) > 0;
            // CINQ SORTS D'AFFILEE : chaque sort avance la serie et c'est le
            // dernier qui paie ; le compte repart aussitot de zero. Ce qui
            // rompt la serie, c'est le temps sans rien incanter -- voir OnTick.
            else if (_event == "spell_cast_row")
            {
                _idleSince = 0;
                fires = ++_row >= _eventN;
                if (fires)
                    _row = 0;
                // LE COMPTE SOUS LES YEUX DU JOUEUR : un cumul par sort, et
                // l'aura s'efface au dernier -- c'est la recompense qui parle.
                if (_countSpell)
                {
                    if (fires)
                        RemoveOwned(player, uint32(_countSpell));
                    else
                    {
                        ApplyOwned(player, uint32(_countSpell));
                        if (Aura* tally = player->GetAura(uint32(_countSpell), player->GetGUID()))
                            tally->SetStackAmount(uint8(_row));
                    }
                }
            }
            // CHANGER D'ECOLE, ou rester dans la meme : on retient l'ecole du
            // sort precedent, et c'est la comparaison qui fait partir la ligne.
            // Le TOUT PREMIER sort n'est ni un changement ni une repetition :
            // il n'y a rien avant lui.
            else if (_event == "school_change" || _event == "school_same")
            {
                uint32 const ecole = uint32(info->GetSchoolMask());
                bool const meme = _ecoleIncantee != 0 && (_ecoleIncantee & ecole) != 0;
                fires = _event == "school_same" ? meme : (_ecoleIncantee != 0 && !meme);
                _ecoleIncantee = ecole;
            }
            // LE MEME SORT RELANCE : le precedent portait deja ce numero.
            else if (_event == "spell_repeat")
            {
                fires = _sortIncante == info->Id;
                _sortIncante = info->Id;
            }
            // UN SORT QUI BAT : il pose un effet periodique -- poison, flamme,
            // regain. Le coeur le dit dans le sort lui-meme.
            else if (_event == "spell_cast_periodic")
            {
                fires = false;
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS && !fires; ++i)
                    fires = info->Effects[i].Effect == SPELL_EFFECT_APPLY_AURA
                         && info->Effects[i].Amplitude > 0;
            }
            // UNE POTION BUE : le sort vient d'une fiole que le joueur avale.
            else if (_event == "potion")
                fires = EstUnePotion(spell);
            // UN OBJET FABRIQUE : un sort qui cree un objet ET qui releve d'un
            // METIER. Le sort porte tout ce qu'il faut -- ce qui sort, et ce
            // qu'il consomme -- et le coeur prend les composants APRES la
            // ligne : ce qu'on rend se rend donc au tour suivant.
            else if (_event == "craft")
                fires = EstUneFabrication(info);
            if (fires)
            {
                _lastCast = spell;
                Fire(player, spell->m_targets.GetUnitTarget(), 0);
                _lastCast = nullptr;
            }
        }
        // L'HOTEL DES VENTES : deux moments qui portent une somme, et c'est
        // elle que l'action rembourse.
        void OnAuctionPosted(Player* player, uint32 deposit) override
        {
            if (_event == "auction_post" && deposit)
                Fire(player, nullptr, deposit);
        }
        void OnAuctionWon(Player* player, uint32 price) override
        {
            if (_event == "auction_won" && price)
                Fire(player, nullptr, price);
        }
        // UN OBJET GRIS QUI ENTRE DANS LES SACS. Le montant que la ligne
        // recevra est le PRIX DE VENTE de ce qui vient d'arriver, pile par
        // pile : c'est sur lui que la pierre de l'alchimiste compte.
        void OnItemGained(Player* player, Item* item, uint32 count) override
        {
            if (_event != "loot_grey" || !item)
                return;
            ItemTemplate const* const modele = item->GetTemplate();
            if (!modele || modele->Quality != ITEM_QUALITY_POOR || !modele->SellPrice)
                return;
            uint32 const combien = std::max<uint32>(1, count);
            uint64 const valeur = uint64(modele->SellPrice) * combien;
            // CHANGE EN OR : l'objet s'en va, et sa valeur -- multipliee --
            // entre dans la bourse. L'action se joue ICI, la ou l'objet est
            // encore sous la main ; `Fire` ne le porterait pas jusqu'a elle.
            if (_action == "to_gold")
            {
                if (!Ready(player))
                    return;
                uint32 const entry = modele->ItemId;
                uint64 const du = std::min<uint64>(valeur * uint64(_a), 2000000000ULL);
                PlusTard(player, TOUR_SUIVANT, [entry, combien, du](Player* p)
                {
                    p->DestroyItemCount(entry, combien, true);
                    p->ModifyMoney(int32(du));
                });
                Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_LUCKY, du, true);
                Pay(player);
                return;
            }
            Fire(player, nullptr, uint32(std::min<uint64>(valeur, 2000000000ULL)));
        }
        void OnJump(Player* player) override
        {
            if (_event == "jump" || (_event == "jump_combat" && player->IsInCombat()))
                Fire(player, nullptr, 0);
        }
        // FRANCHIR LE SEUIL D'UNE INSTANCE : le coeur ne dit que « la carte a
        // change », c'est a nous de reconnaitre un donjon ou un raid.
        void OnMapChanged(Player* player) override
        {
            if (_event == "enter_instance" && player->GetMap() && player->GetMap()->IsDungeon())
                Fire(player, nullptr, 0);
        }
        void OnDeath(Player* player) override { if (_event == "death") Fire(player, nullptr, 0); }
        [[nodiscard]] uint32 Watches() const override
        {
            if (_event == "death_near" || _event == "ally_death") return GUET_MORT_ALENTOUR;
            if (_event == "spin") return GUET_ROTATION;
            if (_event == "jump" || _event == "jump_combat") return GUET_SAUT;
            return 0;
        }
        // UNE MORT AUX ALENTOURS, de la main de n'importe qui : la ligne dit
        // sa portee, et c'est ici qu'on la mesure.
        // UN ALLIE QUI TOMBE, a portee. Le module cherche lui-meme : le coeur
        // ne previent que le tueur.
        void OnAllyDeath(Player* player, Player* mort) override
        {
            if (_event != "ally_death" || !mort || player->GetDistance(mort) > float(_eventN))
                return;
            Fire(player, mort, mort->GetMaxHealth());
        }
        void OnNearbyDeath(Player* player, Unit* died) override
        {
            if (_event != "death_near" || !died || player->GetDistance(died) > float(_eventN))
                return;
            Fire(player, died, died->GetMaxHealth());
        }
        void OnEnterCombat(Player* player) override { if (_event == "enter_combat") Fire(player, player->GetVictim(), 0); }
        void OnLeaveCombat(Player* player) override { if (_event == "leave_combat") Fire(player, nullptr, 0); }
        void OnLevelUp(Player* player) override { if (_event == "levelup") Fire(player, nullptr, 0); }
        void OnResurrect(Player* player) override { if (_event == "resurrect") Fire(player, nullptr, 0); }
        void OnZone(Player* player, uint32 zone, uint32 area) override
        {
            if (_event == "zone")
            {
                Fire(player, nullptr, 0);
                return;
            }
            // UNE CAPITALE : le coeur le dit dans la table des zones
            // (AREA_FLAG_CAPITAL). Entrer, c'est n'y avoir pas ete au coup
            // d'avant -- une zone et ses quartiers valent pour une seule.
            if (_event != "enter_capital")
                return;
            bool const dedans = EstUneCapitale(area) || EstUneCapitale(zone);
            if (dedans && !_enCapitale)
                Fire(player, nullptr, 0);
            _enCapitale = dedans;
        }
        void OnQuestComplete(Player* player, Quest const* /*quest*/) override { if (_event == "quest") Fire(player, nullptr, 0); }
        // The gold of a loot, before it is taken: gold_mult multiplies it.
        void OnLootMoney(Player* player, uint32& copper) override
        {
            if (_event != "loot_gold" || _action != "gold_mult" || !Ready(player))
                return;
            copper = uint32(std::min<uint64>(uint64(copper) * uint64(_a), 2000000000ULL));
            // The figure the card multiplied by says which sentence it is:
            // twice as much is luck and shows the sum, more than that is a
            // jackpot and speaks of the purse itself.
            if (_say)
                Owe(player, _spellId, uint32(_say), copper, true);
            else if (_a > 2)
                Owe(player, _spellId, STELLAR_TAROT_STR_JACKPOT, 0, false);
            else
                Owe(player, _spellId, STELLAR_TAROT_STR_LUCKY, copper, true);
            Pay(player);
        }
        // The loot of a creature, as it is being filled: the crate is LAID IN
        // THE CORPSE, like anything else the beast carried -- the player loots
        // it himself. Putting it straight in the bags would skip the loot
        // window, and the card would give what the creature never held.
        void OnCreatureLoot(Player* player, Loot* loot) override
        {
            if (!loot || (_event != "loot_creature" && _event != "loot_humanoid"))
                return;
            // `loot_humanoid` : le meme moment, mais le cadavre doit etre celui
            // d'un humanoide. Le coeur porte le type dans le gabarit.
            if (_event == "loot_humanoid")
            {
                Unit* const source = ObjectAccessor::GetUnit(*player, loot->sourceWorldObjectGUID);
                Creature* const bete = source ? source->ToCreature() : nullptr;
                if (!bete || bete->GetCreatureType() != CREATURE_TYPE_HUMANOID)
                    return;
            }
            if (_action == "crate")
            {
                if (!Ready(player))
                    return;
                loot->AddItem(LootStoreItem(STELLAR_TAROT_ITEM_CRATE, 0, 100.0f, false,
                                            LOOT_MODE_DEFAULT, 0, 1, 1));
                Pay(player);
            }
            // UN COFFRE D'OR SUR LE CADAVRE : de _a a _b pieces d'or, plus une
            // monnaie de poche tiree au hasard -- 0 a 99 pieces d'argent et
            // autant de cuivre, pour que le chiffre n'ait jamais l'air rond.
            // `loot_gold_boss` ne repond qu'aux boss : le coeur dit lequel
            // (`Creature::isWorldBoss`, et le rang du gabarit).
            else if (_action == "loot_gold_rand" || _action == "loot_gold_boss")
            {
                if (_action == "loot_gold_boss")
                {
                    Unit* const source = ObjectAccessor::GetUnit(*player, loot->sourceWorldObjectGUID);
                    Creature* const bete = source ? source->ToCreature() : nullptr;
                    if (!bete || !IsBoss(bete))
                        return;
                }
                if (!Ready(player))
                    return;
                loot->gold += urand(uint32(_a), uint32(_b)) * 10000 + urand(0, 99) * 100 + urand(0, 99);
                Pay(player);
            }
            // UNE BOURSE DANS UN CADAVRE QUI N'EN PORTAIT PAS. La ligne ne
            // touche jamais a l'or que le monstre avait deja : elle ne remplit
            // qu'une bourse VIDE -- c'est ce que disent « laisse de l'or plus
            // souvent » et « laisse toujours de l'or ».
            //
            // LE MONTANT SUIT LE NIVEAU DU MORT, en droite ligne d'un bout a
            // l'autre de l'echelle, et le hasard l'ecarte de 15 % au plus. Un
            // BOSS est compte au palier haut, quel que soit son niveau.
            else if (_action == "loot_gold_scale")
            {
                if (loot->gold)
                    return;
                Unit* const source = ObjectAccessor::GetUnit(*player, loot->sourceWorldObjectGUID);
                Creature* const bete = source ? source->ToCreature() : nullptr;
                uint32 niveau = bete ? bete->GetLevel() : player->GetLevel();
                if (bete && IsBoss(bete))
                    niveau = PALIER_HAUT;
                niveau = std::min<uint32>(std::max<uint32>(niveau, 1), PALIER_HAUT);
                if (!Ready(player))
                    return;
                double const part = double(niveau - 1) / double(PALIER_HAUT - 1);
                double const droit = double(_a) + (double(_b) - double(_a)) * part;
                int32 const ecart = int32(urand(0, 30)) - 15;          // -15 % a +15 %
                loot->gold += uint32(std::max<int64>(1, std::llround(droit * (100 + ecart) / 100.0)));
                Pay(player);
            }
            // DE L'OR DANS LE CADAVRE : le coeur porte la bourse du butin, et
            // le joueur la ramasse avec le reste. Rien de plus qu'un chiffre
            // ajoute la ou le monde met le sien.
            else if (_action == "loot_gold_level")
            {
                if (!Ready(player))
                    return;
                loot->gold += uint32(_a) * player->GetLevel();
                Pay(player);
            }
            // UN OBJET NOMME, pose dans le cadavre : c'est la carte qui dit
            // lequel, et le joueur le ramasse avec le reste.
            else if (_action == "loot_item")
            {
                if (!Ready(player))
                    return;
                loot->AddItem(LootStoreItem(uint32(_a), 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
                Pay(player);
            }
            // Une babiole de plus sur le cadavre : une piece grise de l'age du
            // joueur, prise dans ce que le monde laisse tomber.
            else if (_action == "grey_item")
            {
                uint32 const trinket = StellarTarotLoot::GreyItemFor(player->GetLevel());
                if (!trinket || !Ready(player))
                    return;
                loot->AddItem(LootStoreItem(trinket, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
                Pay(player);
            }
            // UNE GEMME RARE, celle que le lieu appelle : le diamant d'Azeroth
            // sur le vieux monde, une gemme epique brute de l'Outreterre ou du
            // Norfendre quand la carte du lieu leur appartient.
            else if (_action == "gem")
            {
                uint32 const gemme = DuLieu(player, "gem");
                if (!gemme || !Ready(player))
                    return;
                loot->AddItem(LootStoreItem(gemme, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
                Pay(player);
            }
        }

        // A purchase: one more of what was just bought, for nothing. The bags
        // are asked BEFORE the chance is rolled -- a purchase that has nowhere
        // to go must not spend the card's luck.
        void OnVendorBuy(Player* player, Item* item, uint32 count, uint32 paid) override
        {
            if (_event != "vendor_buy" || !item || !count)
                return;
            // Une part de ce que le joueur a VRAIMENT paye revient dans sa
            // bourse : la remise de reputation et celles des autres cartes sont
            // deja comptees dans cette somme.
            if (_action == "refund")
            {
                if (!paid || !Ready(player))
                    return;
                if (uint32 const back = uint32(std::min<uint64>(uint64(paid) * uint64(_a) / 100, 2000000000ULL)))
                {
                    player->ModifyMoney(int32(back));
                    Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_REBATE, back, true);
                }
                Pay(player);
                return;
            }
            if (_action != "extra_copy")
                return;
            uint32 const entry = item->GetEntry();
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, count) != EQUIP_ERR_OK)
                return;
            if (!Ready(player))
                return;
            if (Item* copy = player->StoreNewItem(dest, entry, true, item->GetItemRandomPropertyId()))
            {
                player->SendNewItem(copy, count, true, false);
                // L'EXEMPLAIRE EST DANS LES SACS, ET LE JOUEUR DOIT LE SAVOIR :
                // rien ne distingue ce qu'il a paye de ce que la carte ajoute.
                // L'objet se nomme cote client, qui seul a sa langue, sa
                // couleur de qualite et son lien.
                TellClient(player, "StellarTarotExtraCopy",
                           std::to_string(SpellId()) + ":" + std::to_string(entry));
            }
            Pay(player);
        }
        // A repair the player is about to pay for: it costs nothing.
        //
        // A discount of zero is NOT enough: the core floors the price of every
        // item at one copper -- its own guard against a free artifact
        // (Player::DurabilityRepair, "fix for ITEM_QUALITY_ARTIFACT"). So the
        // card does the repairing itself, for nothing, and the core then finds
        // nothing worn to charge for.
        void OnRepairDiscount(Player* player, ObjectGuid itemGuid, float& /*discountMod*/) override
        {
            if (_event != "repair" || _action != "free_repair" || !Ready(player))
                return;
            if (itemGuid)
            {
                if (Item* item = player->GetItemByGuid(itemGuid))
                    player->DurabilityRepair(item->GetPos(), false, 0.0f, false);
            }
            else
                player->DurabilityRepairAll(false, 0.0f, false);
            Pay(player);
            // LE FORGERON N'A RIEN PRIS, ET LE JOUEUR DOIT L'APPRENDRE : le
            // coeur ne trouve plus rien a facturer, donc rien ne le lui dirait.
            // La carte se nomme elle-meme, dans la langue du client.
            TellClient(player, "StellarTarotFreeRepair", std::to_string(SpellId()));
        }
        // Une vente : le marchand paie le double. L'objet est nomme quand il
        // part, la somme n'arrive qu'ensuite -- la ligne s'arme ici et agit sur
        // le mouvement d'argent qui suit.
        void OnSellItem(Player* player, Item* item) override
        {
            if (_event == "vendor_sell" && _action == "gold_mult" && Ready(player))
            {
                // L'OBJET SE NOMME ICI, ET NULLE PART AILLEURS : quand la somme
                // arrive, il a deja quitte les sacs. On retient son numero.
                _venduEntry = item ? item->GetEntry() : 0;
                AttendreLaSomme(_selling);
            }
        }
        void OnMoneyChanged(Player* player, int32& amount) override
        {
            if (!SommeAttendue(_selling) || amount <= 0)
                return;
            amount = int32(std::min<int64>(int64(amount) * int64(_a), 2000000000LL));
            // LE MARCHAND A PAYE DOUBLE, ET LE JOUEUR DOIT LE SAVOIR : rien ne
            // distingue une bonne affaire d'une vente ordinaire. Le client
            // nomme l'objet par son lien, dans sa langue.
            if (_venduEntry)
                TellClient(player, "StellarTarotKeenBuyer",
                           std::to_string(SpellId()) + ":" + std::to_string(_venduEntry));
            _venduEntry = 0;
            Pay(player);
        }

    private:
        // The chance and the cooldown, without firing.
        bool Ready(Player* player)
        {
            // Un mort ne declenche plus rien -- SAUF ce qui s'adresse justement
            // a sa mort : l'evenement `death` arrive alors qu'il est a terre,
            // et c'est tout l'objet d'une ligne qui le releve.
            if (!player->IsAlive() && _event != "death" && _action != "restore")
                return false;
            if (_onlyDark && !IsNight() && player->IsOutdoors())
                return false;
            // LA GARDE DE SANTE : la ligne dort tant que le joueur va bien.
            if (_low && player->GetHealthPct() >= float(_low))
                return false;
            // L'ETAT QUE LA LIGNE EXIGE, s'il y en a un.
            if (!_only.empty() && !EtatTenu(_only, _onlyN, _onlyM, player, player, nullptr))
                return false;
            if (_onlyNight && !IsNight())
                return false;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            // UNE SEQUENCE A LA FOIS : sans cela les deux phases d'une carte mal
            // reglee se marcheraient dessus.
            if (_seqUntil && now < _seqUntil)
                return false;
            // LA RECHARGE ET LE DE : seulement ce que le coeur ne tient pas.
            // `spell_proc` porte l'autre moitie, et l'appliquer ici aussi
            // reviendrait a filtrer deux fois.
            //
            // LA RECHARGE SE COMPTE EN MILLISECONDES. En secondes entieres, le
            // compte se faisait sur un battement d'une seconde et l'attente
            // reelle tombait n'importe ou dans [icd-1, icd[ : mesure a 9,5 sec
            // pour une recharge de 10 sur la carte 58. Le coeur, lui, donne
            // l'ICD exact ; ce que le module garde doit valoir autant.
            uint32 const nowMs = uint32(GameTime::GetGameTimeMS().count());
            if (!_coreIcd && _icd && _last && nowMs - _last < uint32(_icd) * 1000)
                return false;
            if (!_coreChance && _chance < 1000 && int32(urand(1, 1000)) > _chance)
                return false;
            _last = nowMs;
            return true;
        }
        // Le revers paye AVEC le bienfait : seulement quand aucune chance propre
        // ne lui a ete donnee, sinon il s'est deja joue sur l'evenement.
        void Pay(Player* player)
        {
            if (!_but.Some() || _but.chance < 100)
                return;
            // UN ETAT N'A ENCORE RIEN DONNE quand il se pose : il promet. Son
            // prix attend le coup qu'il rend critique, ou la depense qu'il rend
            // gratuite -- Spend() le paie alors. Une attaque ratee de plus ne
            // coute donc rien au joueur.
            if (State())
                return;
            Suffer(player);
        }
        // LE REVERS SE PAIE APRES COUP. Un demi-tour d'horloge separe le
        // bienfait de sa contrepartie : le coup part, le chiffre s'affiche, le
        // geste se joue, PUIS le joueur en paie le prix. Un revers immediat
        // tombe dans la meme image que le coup -- le client remplace l'anima-
        // tion de l'attaque par celle de l'etourdissement, et la carte semble
        // punir sans avoir rien donne.
        void Suffer(Player* player)
        {
            // LA CHANCE A DEJA ETE TIREE, ici ou sur l'evenement : il ne reste
            // qu'a payer. Le sort du prix est celui du module, non celui du
            // niveau -- c'est lui qui porte l'infobulle du coup recu.
            Drawback paye = _but;
            paye.chance = 100;
            PayDrawback(player, paye, _spellId, _lastAmount, _lastStacks);
        }
        void Fire(Player* player, Unit* other, uint32 amount)
        {
            // UN REVERS A CHANCE PROPRE se tire sur l'evenement lui-meme : la
            // carte promet deux choses independantes (« peut doubler les
            // degats MAIS peut vous toucher »), pas une contrepartie payee
            // seulement quand le bienfait tombe.
            if (_but.chance < 100 && _but.Some())
            {
                _lastAmount = amount ? amount : _lastAmount;
                if (int32(urand(1, 100)) <= _but.chance)
                    Suffer(player);
            }
            if (!Ready(player))
                return;
            // L'INSTRUMENT DE MESURE : un depart de plus pour cette ligne.
            StellarTarotEffects::CompteDepart(player, _spellId, other);
            // LE SOIN QUI ACCOMPAGNE : il tombe avant l'action, dans l'ordre
            // ou la carte l'annonce.
            // UN ALLIE PREND SA PART DU COUP : la ligne le dit en garniture, et
            // sa propre action reste pour la cible.
            if (_coupAllie && amount)
            {
                std::list<Player*> amis;
                Acore::AnyPlayerInObjectRangeCheck check(player, float(_coupAllieM));
                Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck> searcher(player, amis, check);
                Cell::VisitObjects(player, searcher, float(_coupAllieM));
                std::vector<Player*> bons;
                for (Player* ami : amis)
                    if (ami && ami != player && ami->IsAlive())
                        bons.push_back(ami);
                if (!bons.empty())
                    Hurt(player, bons[urand(0, uint32(bons.size()) - 1)],
                         Part(Mesure::Coup, _coupAllie, player, amount), 1, _spellId);
            }
            // CE QUE LA LIGNE DEPENSE : les cumuls qu'un autre niveau tenait
            // s'en vont, puisqu'ils viennent d'etre employes.
            for (uint32 sort : _depense)
                player->RemoveAurasDueToSpell(sort);
            // L'ECHEANCE REPART : la ligne vient de payer.
            if (_echeance)
                _depuisEcheance = uint32(GameTime::GetGameTime().count());
            // TOUS LES TEMPS DE RECHARGE REMIS A ZERO, avant l'action.
            if (_reset)
            {
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->RemoveSpellCooldown(spellId, true);
            }
            // PV ET MANA REMIS A PLEIN, avant tout le reste : le coeur les
            // porte lui-meme, et le joueur voit sa barre se remplir.
            if (_restore)
            {
                player->SetFullHealth();
                player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
            }
            if (_healPct)
                Heal(player, player, PctOf(player->GetMaxHealth(), _healPct), _spellId);
            // The night figure stands in for the action's own while it lasts.
            int32 const day = _a;
            if (_nightA && IsNight())
                _a = _nightA;
            Do(player, other, amount);
            _a = day;
            Pay(player);
        }
        void Do(Player* player, Unit* other, uint32 amount)
        {
            if (_emote)
                player->HandleEmoteCommand(uint32(_emote));
            std::string const& A = _action;
            if (A == "none")
                return;
            if (A == "aura" || A == "aura_target")
            {
                // UNE PART DE LA PUISSANCE DES SORTS : l'aura porte le chiffre
                // lu au moment ou elle se pose, la sienne retiree d'abord pour
                // qu'elle ne se nourrisse pas d'elle-meme.
                // UNE PART DES SCORES : meme chemin que la puissance des
                // sorts, mais score par score.
                if (_ratingPct && A == "aura" && LayRatingShare(player, _spellId, _ratingParts, _a, _b))
                    return;
                if (_spPct && A == "aura")
                {
                    RemoveOwned(player, _spellId);
                    int32 const own = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC));
                    int32 const bp = int32(std::llround(double(own) * _spPct / 100.0));
                    player->CastCustomSpell(player, _spellId, &bp, &bp, &bp, true);
                    if (Aura* laid = player->GetAura(_spellId, player->GetGUID()))
                    {
                        laid->SetMaxDuration(_a * 1000);
                        laid->SetDuration(_a * 1000);
                    }
                    return;
                }
                Unit* who = A == "aura" ? player : other;
                if (!who || !who->IsAlive())
                    return;
                Aura* aura = who->GetAura(_spellId, player->GetGUID());
                if (!aura)
                    aura = player->AddAura(_spellId, who);
                else if (_b > 1 && aura->GetStackAmount() < uint8(_b))
                    aura->ModStackAmount(1);
                // LE PRIX SUIT LE BIENFAIT : son revers lira ce compte-la, et
                // non le sien. Sans cela, changer de cible ferait repartir le
                // bienfait a un cumul pendant que le prix continuait de monter.
                _lastStacks = aura ? int32(aura->GetStackAmount()) : 1;
                if (aura && _a)
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
                // Le revers en aura a lui : il monte et tombe avec le bienfait.
                if (_debuffSpell && A == "aura")
                {
                    uint32 const mal = uint32(_debuffSpell);
                    Aura* plaie = player->GetAura(mal, player->GetGUID());
                    if (!plaie)
                        plaie = player->AddAura(mal, player);
                    else if (_b > 1 && plaie->GetStackAmount() < uint8(_b))
                        plaie->ModStackAmount(1);
                    if (plaie && _a)
                    {
                        plaie->SetMaxDuration(_a * 1000);
                        plaie->SetDuration(_a * 1000);
                    }
                }
                // CE QUI VIENT APRES. La carte peut etre retiree entre-temps :
                // la seconde phase se jouera alors jusqu'a son terme, au plus
                // quelques secondes.
                if (_thenSec && A == "aura")
                {
                    _seqUntil = uint32(GameTime::GetGameTime().count()) + uint32(_a + _thenSec);
                    uint32 const spell = _thenSpell ? uint32(_thenSpell) : _spellId;
                    uint32 const first = _spellId;
                    int32 const pct = _thenPct, sec = _thenSec;
                    PlusTard(player, Seconds(_a), [spell, first, pct, sec](Player* p)
                    {
                        p->RemoveAurasDueToSpell(first, p->GetGUID());
                        p->RemoveAurasDueToSpell(spell, p->GetGUID());
                        int32 const bp = pct;           // entier : le coeur retranche le de lui-meme
                        p->CastCustomSpell(p, spell, &bp, &bp, &bp, true);
                        if (Aura* second = p->GetAura(spell, p->GetGUID()))
                        {
                            second->SetMaxDuration(sec * 1000);
                            second->SetDuration(sec * 1000);
                        }
                    });
                }
            }
            else if (A == "aura_group")
            {
                for (Player* member : GroupAround(player, float(_b)))
                    if (Aura* aura = player->AddAura(_spellId, member))
                    {
                        aura->SetMaxDuration(_a * 1000);
                        aura->SetDuration(_a * 1000);
                    }
            }
            else if (A == "heal") Heal(player, player, PctOf(player->GetMaxHealth(), _a), _spellId);
            else if (A == "mana") Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _a), _spellId);
            else if (A == "heal_both")
            {
                Heal(player, player, PctOf(player->GetMaxHealth(), _a), _spellId);
                Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _a), _spellId);
            }
            else if (A == "restore")
            {
                player->SetHealth(player->GetMaxHealth());
                player->SetPower(POWER_MANA, player->GetMaxPower(POWER_MANA));
            }
            else if (A == "leech") Heal(player, player, Part(Mesure::Coup, _a, player, amount), _spellId);
            // LE SORT SE RELANCE, pour une part de ce qu'il vient d'infliger :
            // le sort lui-meme repart -- ses images, son ecole, son journal --
            // et son coup sera ramene a cette part-la.
            else if (A == "mirror")
            {
                if (!other || !_lastSpellId || !amount)
                    return;
                _mirrorSpell = _lastSpellId;
                _mirrorAmount = std::max<uint32>(1, PctOf(amount, _a));
                player->CastSpell(other, _lastSpellId, true);
            }
            // LE SORT SUBI, RENVOYE A SON LANCEUR : c'est le sort lui-meme qui
            // repart -- ses images, son ecole, son journal -- au nom du joueur.
            else if (A == "reflect")
            {
                if (!other || !_sortSubi)
                    return;
                if (_a < 100)
                {
                    _mirrorSpell = _sortSubi;
                    _mirrorAmount = std::max<uint32>(1, PctOf(amount, _a));
                }
                player->CastSpell(other, _sortSubi, true);
            }
            else if (A == "heal_group")
            {
                for (Player* member : GroupAround(player, float(_b)))
                    Heal(player, member, PctOf(member->GetMaxHealth(), _a), _spellId);
            }
            // CELUI QUE L'EVENEMENT NOMME, soigne d'une part de SES PROPRES PV
            // max -- la jumelle de `heal_group`, pour un seul. L'allie en
            // danger (`ally_low`) est celui-la.
            else if (A == "heal_other")
            {
                if (other && other->IsAlive())
                    Heal(player, other, PctOf(other->GetMaxHealth(), _a), _spellId);
            }
            else if (A == "heal_ally_amount")
            {
                // The most injured group member in range, the healed one left out.
                Player* pick = nullptr;
                for (Player* member : GroupAround(player, float(_b)))
                    if (member != other && (!pick || member->GetHealthPct() < pick->GetHealthPct()))
                        pick = member;
                if (pick)
                    Heal(player, pick, Part(Mesure::Coup, _a, player, amount), _spellId);
            }
            // LE FAMILIER SOIGNE PAR LE COUP DE SON MAITRE : une part de ce
            // qui vient d'etre inflige, jamais moins d'un point.
            else if (A == "leech_pet")
            {
                Pet* pet = player->GetPet();
                if (!pet || !pet->IsAlive() || !amount)
                    return;
                Heal(player, pet, std::max<uint32>(1, Part(Mesure::Coup, _a, player, amount)), _spellId);
                return;
            }
            // L'AURA POSEE SUR LE FAMILIER : le maitre la lance, donc un chiffre
            // ecrit par niveau suit le niveau DU MAITRE.
            else if (A == "aura_pet")
            {
                Pet* pet = player->GetPet();
                if (!pet || !pet->IsAlive())
                    return;
                Aura* aura = pet->GetAura(_spellId, player->GetGUID());
                if (!aura)
                    aura = player->AddAura(_spellId, pet);
                else if (_b > 1 && aura->GetStackAmount() < uint8(_b))
                    aura->ModStackAmount(1);
                if (aura && _a)
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
                return;
            }
            else if (A == "heal_pet")
            {
                if (Pet* pet = player->GetPet())
                    Heal(player, pet, PctOf(pet->GetMaxHealth(), _a), _spellId);
                Heal(player, player, PctOf(player->GetMaxHealth(), _b), _spellId);
            }
            else if (A == "gold_level" || A == "silver_level" || A == "gold")
            {
                // `gold` : un montant fixe, en cuivre. Les deux autres le
                // multiplient par le niveau du joueur.
                uint64 const copper = A == "gold" ? uint64(_a)
                                    : uint64(_a) * (A == "silver_level" ? 100 : 1) * player->GetLevel();
                player->ModifyMoney(int32(copper));
                Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_BINGO, copper, true);
            }
            else if (A == "copper_per_damage") player->ModifyMoney(int32(std::min<uint64>(uint64(amount) * uint64(_a), 100000000ULL)));
            else if (A == "shield_self" || A == "shield_target" || A == "shield_other")
            {
                // `shield_other` : CELUI QUE L'EVENEMENT NOMME, protege d'une
                // part de SES PROPRES points de vie -- la jumelle de
                // `heal_other`. `shield_target` compte sur le MONTANT du coup.
                Unit* const who = A == "shield_self" ? player : other;
                if (!who)
                    return;
                int32 const bp = int32(A == "shield_self" ? PctOf(player->GetMaxHealth(), _a)
                                     : A == "shield_other" ? PctOf(who->GetMaxHealth(), _a)
                                                           : PctOf(amount, _a));
                if (bp > 0)
                    Put(player, who, STELLAR_TAROT_SPELL_SHIELD, _b ? _b : 15, &bp);
            }
            else if (A == "shield_ally" || A == "shield_group")
            {
                int32 const sec = _c ? _c : 15;
                if (A == "shield_group")
                {
                    for (Player* member : GroupAround(player, float(_b)))
                    {
                        int32 const bp = int32(PctOf(member->GetMaxHealth(), _a));
                        Put(player, member, STELLAR_TAROT_SPELL_SHIELD, sec, &bp);
                    }
                }
                else
                {
                    Player* pick = nullptr;
                    for (Player* member : GroupAround(player, float(_b)))
                        if (member != player && (!pick || member->GetHealthPct() < pick->GetHealthPct()))
                            pick = member;
                    if (pick)
                    {
                        int32 const bp = int32(PctOf(pick->GetMaxHealth(), _a));
                        Put(player, pick, STELLAR_TAROT_SPELL_SHIELD, sec, &bp);
                    }
                }
            }
            else if (A == "extra")
                Hurt(player, other, Part(Mesure::Coup, _a, player, amount),
                     uint32(_b ? _b : (_lastSchool ? _lastSchool : uint32(SPELL_SCHOOL_MASK_NORMAL))), _spellId);
            else if (A == "damage_sp" || A == "damage_ap")
            {
                Mesure const source = A == "damage_sp" ? Mesure::PuissanceDesSorts
                                                       : Mesure::PuissanceDAttaque;
                Hurt(player, other, Part(source, _a, player), uint32(_b), _spellId);
            }
            // CE QUE LE LANCEUR PORTE EN LUI : la cible encaisse une part des
            // points de vie maximum du joueur, dans l'ecole nommee (32, l'ombre,
            // a defaut).
            else if (A == "hp_dmg")
            {
                if (!other)
                    return;
                Hurt(player, other, Part(Mesure::ViesMaxDuLanceur, _a, player), uint32(_b ? _b : 32), _spellId);
            }
            else if (A == "splash" || A == "explode" || A == "explode_sp" || A == "explode_ap")
            {
                if (!other)
                    return;
                // `explode` mesure les points de vie maximum de la victime :
                // c'est le chiffre que l'evenement `kill` a deja porte jusqu'ici.
                uint32 const dmg = A == "explode_sp" ? Part(Mesure::PuissanceDesSorts, _a, player)
                                 : A == "explode_ap" ? Part(Mesure::PuissanceDAttaque, _a, player)
                                                     : Part(Mesure::Coup, _a, player, amount);
                uint32 const school = A == "explode_sp" ? uint32(_c ? _c : 64) : 1;
                if (A == "explode" && other->IsCreature() && IsBoss(other->ToCreature()))
                    return;
                player->CastSpell(player, school == 1 ? STELLAR_TAROT_SPELL_VISUAL_PHYS : STELLAR_TAROT_SPELL_VISUAL_MAGIC, true);
                // SANS CADAVRE, C'EST LE JOUEUR QUI EXPLOSE : un evenement
                // comme « mana sous 10% » ne nomme personne.
                Unit* const centre = other ? other : player;
                for (Unit* unit : HostilesAround(player, centre, float(_b), centre))
                    Hurt(player, unit, dmg, school, _spellId);
            }
            else if (A == "cleave")
            {
                for (Unit* unit : HostilesAround(player, player, float(_b), other))
                    if (player->HasInArc(float(M_PI), unit))
                        Hurt(player, unit, PctOf(amount, _a), 1, _spellId);
            }
            // UN GARDIEN QUI VIENT AU SECOURS : le coeur l'invoque et le
            // reprend a l'heure dite ; son IA fait le reste.
            else if (A == "summon")
            {
                player->SummonCreature(uint32(_a), *player, TEMPSUMMON_TIMED_DESPAWN,
                                       uint32(_b) * 1000);
            }
            else if (A == "root") Put(player, other, STELLAR_TAROT_SPELL_ROOT, _a);
            else if (A == "stun") Put(player, other, STELLAR_TAROT_SPELL_STUN, _a);
            else if (A == "disorient") Put(player, other, STELLAR_TAROT_SPELL_DISORIENT, _a);
            // RETOURNER LA CIBLE CONTRE LES SIENS. Rien ne la charme et rien
            // ne l'egare : la MENACE fait le travail. L'allie le plus proche
            // passe en tete de sa liste, les deux s'empoignent, et au temps
            // dit la carte lache prise -- la menace de l'allie retombe et la
            // cible revient au joueur. Une marque visible dit sur qui la
            // carte a pris. Sans allie a portee, rien ne se passe : une bete
            // seule n'a personne a frapper.
            else if (A == "turn" || A == "turn_ally")
            {
                if (!other || !other->IsCreature() || !other->IsAlive())
                    return;
                Creature* const turned = other->ToCreature();
                Unit* ally = nullptr;
                float best = 0.0f;
                for (Unit* u : HostilesAround(player, turned, float(_b ? _b : 15), turned))
                    if (u && u->IsAlive() && u->IsCreature())
                    {
                        float const d = turned->GetDistance(u);
                        if (!ally || d < best) { ally = u; best = d; }
                    }
                if (!ally)
                    return;
                Put(player, turned, STELLAR_TAROT_SPELL_TURNED, _a);
                // LA FACTION FAIT CE QUE LA MENACE NE PEUT PAS. On ne pose pas
                // de menace sur un allie : ThreatManager comme Unit::Attack
                // demandent d'abord une cible VALIDE, et deux betes du meme
                // camp n'en sont pas l'une pour l'autre -- la menace est jetee
                // sans un mot.
                //
                // La bete passe donc dans « Hates Everything » (modele 2189,
                // faction 1145) : ourMask 8, friendMask 0, enemyMask 15 --
                // amie de personne, hostile a tout. Les siens deviennent des
                // cibles valides des deux cotes, ET LE JOUEUR GARDE LA SIENNE :
                // la faire passer du cote du joueur l'aurait mise hors de sa
                // portee. Le temps dit, elle retrouve sa faction et le joueur.
                // `turn` la met contre TOUT LE MONDE -- le joueur garde sa prise
                // sur elle ; `turn_ally` en fait un allie le temps dit, et elle
                // est alors hors de sa portee comme un compagnon l'est.
                turned->SetFaction(A == "turn_ally" ? player->GetFaction() : FACTION_HATES_EVERYTHING);
                turned->AddThreat(ally, 1000000.0f);
                if (turned->AI())
                    turned->AI()->AttackStart(ally);
                if (ally->ToCreature()->AI())
                    ally->ToCreature()->AI()->AttackStart(turned);
                ObjectGuid const beast = turned->GetGUID();
                PlusTard(player, Seconds(_a), [beast](Player* p)
                {
                    Unit* const u = ObjectAccessor::GetUnit(*p, beast);
                    if (!u || !u->IsCreature())
                        return;
                    u->RestoreFaction();
                    u->GetThreatMgr().ClearAllThreat();
                    if (u->IsAlive() && u->ToCreature()->AI())
                        u->ToCreature()->AI()->AttackStart(p);
                });
            }
            else if (A == "fear") Put(player, other, STELLAR_TAROT_SPELL_FEAR, _a);
            else if (A == "sleep") Put(player, other, STELLAR_TAROT_SPELL_SLEEP, _a);
            // LE MEME SORT, MAIS SUR TOUT CE QUI EST AUTOUR : le centre est
            // celui que l'evenement nomme, ou le joueur a defaut.
            else if (A == "sleep_area" || A == "stun_area" || A == "fear_area")
            {
                WorldObject* const centre = other ? static_cast<WorldObject*>(other) : player;
                uint32 const sort = A == "sleep_area" ? STELLAR_TAROT_SPELL_SLEEP
                                  : (A == "stun_area" ? STELLAR_TAROT_SPELL_STUN
                                                      : STELLAR_TAROT_SPELL_FEAR);
                for (Unit* unit : HostilesAround(player, centre, float(_b), nullptr))
                    if (unit && unit->IsAlive())
                        Put(player, unit, sort, _a);
            }
            else if (A == "silence") Put(player, other, STELLAR_TAROT_SPELL_SILENCE, _a);
            else if (A == "immune_snare") Put(player, player, STELLAR_TAROT_SPELL_IMMUNE_SNARE, _a);
            else if (A == "bleed")
            {
                int32 const perTick = int32(PctOf(uint32(player->GetTotalAttackPowerValue(BASE_ATTACK)), _b));
                if (perTick > 0)
                    Put(player, other, STELLAR_TAROT_SPELL_BLEED, _a, &perTick);
            }
            // LA PLAIE QUE LE COUP OUVRE : sa part se mesure sur le coup meme,
            // et le sort nomme en dit le chiffre.
            else if (A == "bleed_hit")
            {
                if (!other || !amount)
                    return;
                int32 const perTick = std::max<int32>(1, int32(PctOf(amount, _b)));
                Put(player, other, uint32(_c), _a, &perTick);
            }
            else if (A == "burn")
            {
                // A share of the blow, spread over the ticks of two seconds.
                // La part vaut pour CHAQUE tic, et jamais moins d'un point.
                int32 const perTick = std::max(1, int32(PctOf(amount, _b)));
                Put(player, other, STELLAR_TAROT_SPELL_BURN, _a, &perTick);
            }
            // ATTIRER VERS LA CIBLE ce qui l'entoure : le coeur deplace les
            // creatures lui-meme, et le client suit.
            else if (A == "pull")
            {
                Unit* const centre = other ? other : player;
                for (Unit* unit : HostilesAround(player, centre, float(_a), centre))
                    if (unit && unit->IsAlive() && unit->IsCreature())
                        unit->GetMotionMaster()->MoveJump(*centre, 12.0f, 6.0f);
            }
            else if (A == "knockback")
            {
                if (other && other->IsAlive())
                    other->KnockbackFrom(player->GetPositionX(), player->GetPositionY(), float(_a) * 2.0f, 5.0f);
            }
            else if (A == "blink")
            {
                // _b: 0 backwards, 1 a random direction
                float const angle = _b ? frand(0.0f, float(2 * M_PI)) : float(M_PI);
                Position pos = player->GetNearPosition(float(_a), angle);
                player->NearTeleportTo(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(), player->GetOrientation());
            }
            // LES PROMESSES DE COUT ET D'INCANTATION : l'aura porte le
            // modificateur (108), le DBC porte ses charges et sa duree, et
            // c'est le COEUR qui la depense -- Player::RemoveSpellMods, a la
            // fin du lancement, et seulement si le sort a vraiment employe le
            // modificateur. Un sort deja gratuit ou deja instantane ne la
            // consomme donc plus.
            // LA PROMESSE DE COUT ARRIVE AU TOUR SUIVANT. Le coeur peut encore
            // evaluer des procs du sort qui l'arme apres le crochet qui la pose
            // (Spell.cpp:3825, puis 4003 pour la phase de lancement) : posee
            // sur-le-champ, l'aura risquerait d'etre devoree par ce sort meme,
            // puisqu'il est de la bonne ecole. Un tour d'horloge plus tard, il
            // est clos et la promesse attend le suivant.
            else if (A == "cost_next")
            {
                uint32 const promesse = _spellId;
                PlusTard(player, TOUR_SUIVANT, [promesse](Player* p) { Put(p, p, promesse, 0); });
            }
            // `cast_next` est la meme promesse que `next_instant`, mais pour une
            // PART du temps d'incantation : l'aura du niveau porte le
            // modificateur (108, SPELLMOD_CASTING_TIME) et le coeur la depense
            // au premier sort qui l'emploie.
            else if (A == "free_next" || A == "next_instant" || A == "cast_next"
                     || A == "next_all" || A == "next_quick" || A == "next_sharp")
                Put(player, player, _spellId, 0);
            // LA PROMESSE EST TOUTE DANS L'AURA : +100 % de critique (aura 290)
            // pour `next_crit`, 500 points d'expertise (aura 240) pour
            // `next_sure` -- de quoi passer l'esquive ET la parade sous zero,
            // que le coeur lit dans le coup blanc comme dans la competence. Le
            // module ne decide plus d'aucune issue.
            else if (A == "next_crit")
            {
                // L'ETAT TIENT JUSQU'A CE QU'IL SERVE : il promet le prochain
                // coup, pas les vingt prochaines secondes. Une attaque ratee de
                // plus ne le consomme pas -- rien n'a ete donne, rien n'est du.
                // Il est arme par un NON-IMPACT (attaque ratee, esquive,
                // pirouette) : rien ne peut le devorer a l'instant ou il se
                // pose, et il n'a donc pas besoin d'attendre.
                Put(player, player, _spellId, 0);
            }
            // LA PROMESSE DE COUP ATTEND LE COUP SUIVANT. Celle-la est armee
            // PAR un impact, et c'est un impact qui la consomme : posee
            // sur-le-champ, elle tombait dans la ronde de procs du coup meme --
            // le coeur la voyait naitre et mourir dans la meme image, et elle
            // n'a jamais promis le coup SUIVANT. Un tour d'horloge plus tard,
            // ce coup est clos. Meme remede que `cost_next`, et pour la meme
            // raison.
            else if (A == "next_sure")
            {
                uint32 const promesse = _spellId;
                PlusTard(player, TOUR_SUIVANT, [promesse](Player* p) { Put(p, p, promesse, 0); });
            }
            // CE QUE L'ETABLI VIENT DE RENDRE, une fois de plus. L'objet est
            // celui du sort lui-meme : rien n'est invente. On attend le tour
            // suivant, le coeur n'ayant pas encore range le premier exemplaire.
            else if (A == "craft_copy")
            {
                SpellInfo const* const recette = _lastCast ? _lastCast->GetSpellInfo() : nullptr;
                if (recette)
                    for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                        if ((recette->Effects[i].Effect == SPELL_EFFECT_CREATE_ITEM
                             || recette->Effects[i].Effect == SPELL_EFFECT_CREATE_ITEM_2)
                            && recette->Effects[i].ItemType)
                        {
                            uint32 const quoi = recette->Effects[i].ItemType;
                            uint32 const combien = std::max<uint32>(1, uint32(recette->Effects[i].CalcValue(player)));
                            PlusTard(player, TOUR_SUIVANT, [quoi, combien](Player* p) { p->AddItem(quoi, combien); });
                        }
            }
            // LES COMPOSANTS RENDUS : le coeur les prend au bout de la ligne,
            // et on les remet dans les sacs juste apres. La recette ne change
            // pas -- le joueur les ravale, simplement.
            else if (A == "craft_refund")
            {
                SpellInfo const* const recette = _lastCast ? _lastCast->GetSpellInfo() : nullptr;
                if (recette)
                    for (uint8 i = 0; i < MAX_SPELL_REAGENTS; ++i)
                        if (recette->Reagent[i] > 0 && recette->ReagentCount[i] > 0)
                        {
                            uint32 const quoi = uint32(recette->Reagent[i]);
                            uint32 const combien = uint32(recette->ReagentCount[i]);
                            PlusTard(player, TOUR_SUIVANT, [quoi, combien](Player* p) { p->AddItem(quoi, combien); });
                        }
            }
            // UN POINT DE COMPETENCE DE PLUS : c'est le coeur qui le donne, par
            // sa propre montee de metier, a chance certaine.
            else if (A == "craft_skill")
            {
                SpellInfo const* const recette = _lastCast ? _lastCast->GetSpellInfo() : nullptr;
                if (recette)
                {
                    SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(recette->Id);
                    for (auto it = bornes.first; it != bornes.second; ++it)
                        if (uint16 const metier = uint16(it->second->SkillLine))
                            if (player->HasSkill(metier))
                            {
                                for (int32 n = 0; n < std::max(1, _a); ++n)
                                    player->UpdateSkillPro(metier, 10000, 1);
                                break;
                            }
                }
            }
            // LA COMPETENCE OU LE SORT, RELANCE : le coeur le relance
            // TRIGGERED -- donc sans incantation, sans cout et sans recharge.
            // Un lancement en cours le nomme ; a defaut, c'est le dernier sort
            // qui a porte. Un coup d'arme blanc n'en nomme aucun : rien ne se
            // relance, et c'est ce que le texte dit.
            else if (A == "recast")
            {
                uint32 const quoi = (_lastCast && _lastCast->GetSpellInfo())
                                  ? _lastCast->GetSpellInfo()->Id : _lastSpellId;
                if (quoi)
                    player->CastSpell(other ? other : player, quoi, true);
            }
            // UNE PART DE LA SOMME QUE L'EVENEMENT PORTE, rendue au joueur :
            // le depot d'une enchere, le prix d'une enchere remportee.
            else if (A == "refund_amount")
            {
                if (!amount)
                    return;
                uint32 const rendu = uint32(std::min<uint64>(uint64(amount) * uint64(_a) / 100,
                                                            2000000000ULL));
                if (!rendu)
                    return;
                player->ModifyMoney(int32(rendu));
                Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_REBATE, rendu, true);
            }
            // PILE OU FACE : l'or, ou l'aura du niveau.
            else if (A == "lucky_event")
            {
                if (urand(0, 1) == 0)
                {
                    uint64 const du = uint64(_b) * player->GetLevel();
                    player->ModifyMoney(int32(std::min<uint64>(du, 2000000000ULL)));
                    Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_LUCKY, du, true);
                }
                else if (Aura* aura = player->AddAura(uint32(_spellId), player))
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
                }
            }
            // CE QUE LE MORT PORTAIT PASSE A UN AUTRE : les auras PERIODIQUES
            // que le joueur avait posees sur lui, et elles seules, avec ce
            // qu'il leur restait a vivre.
            else if (A == "spread_dots")
            {
                if (!other)
                    return;
                Unit* suivant = nullptr;
                for (Unit* unit : HostilesAround(player, other, float(_a), other))
                    if (unit && unit->IsAlive())
                    {
                        suivant = unit;
                        break;
                    }
                if (!suivant)
                    return;
                struct Reprise { uint32 sort; int32 duree; uint8 cumuls; };
                std::vector<Reprise> reprises;
                for (auto const& [id, aura] : other->GetOwnedAuras())
                {
                    if (!aura || aura->GetCasterGUID() != player->GetGUID())
                        continue;
                    SpellInfo const* const info = aura->GetSpellInfo();
                    bool bat = false;
                    for (uint8 i = 0; i < MAX_SPELL_EFFECTS && !bat; ++i)
                        bat = info && info->Effects[i].Amplitude > 0;
                    if (!bat || aura->GetDuration() <= 0)
                        continue;
                    reprises.push_back({ id, aura->GetDuration(), aura->GetStackAmount() });
                }
                for (Reprise const& r : reprises)
                    if (Aura* posee = player->AddAura(r.sort, suivant))
                    {
                        posee->SetDuration(r.duree);
                        if (r.cumuls > 1)
                            posee->SetStackAmount(r.cumuls);
                    }
            }
            // UNE CIBLE AU HASARD ALENTOUR, amie ou non : le coup part de
            // travers, et c'est ce que la carte promet.
            else if (A == "wild_splash")
            {
                std::list<Unit*> autour;
                Acore::AnyUnitInObjectRangeCheck check(player, float(_b));
                Acore::UnitListSearcher<Acore::AnyUnitInObjectRangeCheck> searcher(player, autour, check);
                Cell::VisitObjects(player, searcher, float(_b));
                std::vector<Unit*> bons;
                for (Unit* unit : autour)
                    if (unit && unit != player && unit != other && unit->IsAlive()
                        && !unit->IsTotem() && unit->IsVisible())
                        bons.push_back(unit);
                if (bons.empty())
                    return;
                Hurt(player, bons[urand(0, uint32(bons.size()) - 1)],
                     Part(Mesure::Coup, _a, player, amount), 1, _spellId);
            }
            // L'ARMURE IGNOREE : la formule du coeur, rejouee avec une armure
            // allegee. La difference s'ajoute au coup -- rien n'est invente.
            else if (A == "ignore_armor")
            {
                if (!other || !amount)
                    return;
                uint32 const entier = Unit::CalcArmorReducedDamage(player, other, amount, nullptr);
                if (!entier || entier >= amount)
                    return;
                // Ce que l'armure a mange, et la part qu'on lui reprend.
                uint32 const mange = amount - entier;
                Hurt(player, other, PctOf(mange, _a), 1, _spellId);
            }
            // TANT D'OR PAR TRANCHE D'OR POSSEDE : la bourse se lit au moment
            // ou la ligne paie, et le plafond la borne.
            else if (A == "gold_slice")
            {
                uint64 const tranches = player->GetMoney() / (uint64(_a) * 10000);
                uint64 const du = std::min<uint64>(tranches * uint64(_b), uint64(_c)) * 10000;
                if (!du)
                    return;
                player->ModifyMoney(int32(std::min<uint64>(du, 2000000000ULL)));
                Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_LUCKY, du, true);
            }
            // DISPARAITRE : l'invisibilite du coeur, posee sur le joueur pour
            // le temps dit.
            else if (A == "invisible")
            {
                Put(player, player, STELLAR_TAROT_SPELL_INVISIBLE, _a);
                if (_b)
                    Put(player, player, STELLAR_TAROT_SPELL_STUN, _a);
            }
            // UNE ATTAQUE DE PLUS, celle du coeur : il la porte lui-meme au
            // prochain tour d'horloge, avec l'arme que le joueur tient.
            else if (A == "extra_attack")
                player->AddExtraAttacks(uint32(std::max(1, _a)));
            // TOUT CE QUI RECHARGE, remis a zero d'un coup.
            else if (A == "reset_all_cooldowns")
            {
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->RemoveSpellCooldown(spellId, true);
            }
            // LES LONGUES RECHARGES : celles dont le temps TOTAL depasse le
            // seuil dit. Chacune tente sa chance a part, quand la ligne en
            // donne une.
            else if (A == "reset_long_cooldowns")
            {
                uint32 const now = GameTime::GetGameTimeMS().count();
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                {
                    if (cd.end <= now)
                        continue;
                    SpellInfo const* const info = sSpellMgr->GetSpellInfo(spellId);
                    uint32 const total = info ? std::max(info->RecoveryTime, info->CategoryRecoveryTime) : 0;
                    if (total < uint32(_a) * 1000)
                        continue;
                    if (_b && int32(urand(1, 100)) > _b)
                        continue;
                    ids.push_back(spellId);
                }
                for (uint32 spellId : ids)
                    player->RemoveSpellCooldown(spellId, true);
            }
            // UN TEMPS DE RECHARGE AU HASARD, remis a zero : on ne prend que
            // ceux qui courent vraiment, et un seul d'entre eux.
            else if (A == "reset_one_cooldown")
            {
                uint32 const now = GameTime::GetGameTimeMS().count();
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    if (cd.end > now)
                        ids.push_back(spellId);
                if (!ids.empty())
                    player->RemoveSpellCooldown(ids[urand(0, uint32(ids.size()) - 1)], true);
            }
            else if (A == "cooldowns")
            {
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->ModifySpellCooldown(spellId, -_a * 1000);
            }
            else if (A == "reset_cooldowns")
            {
                uint32 const now = GameTime::GetGameTimeMS().count();
                std::vector<uint32> ids;
                for (auto const& [spellId, cd] : player->GetSpellCooldownMap())
                    if (cd.end > now && cd.end - now <= uint32(_a) * 1000)
                        ids.push_back(spellId);
                for (uint32 spellId : ids)
                    player->RemoveSpellCooldown(spellId, true);
            }
            else if (A == "repair") Mend(player, uint32(_a));
            else if (A == "repair_one") MendOne(player, uint32(_a));
            // Se relever la ou l'on est tombe : au tic suivant, la mort du
            // joueur etant encore en cours de traitement.
            else if (A == "resurrect")
            {
                int32 const share = _a;
                PlusTard(player, TOUR_SUIVANT, [share](Player* p)
                {
                    if (p->IsAlive())
                        return;
                    p->ResurrectPlayer(0.0f);
                    p->SetHealth(std::max<uint32>(1, PctOf(p->GetMaxHealth(), share)));
                    p->SetPower(POWER_MANA, 0);
                    p->SpawnCorpseBones();
                });
            }
            else if (A == "repair_all") player->DurabilityRepairAll(false, 0.0f, false);
            // Mana in thousandths: half a percent is a figure the workbook writes.
            else if (A == "mana_pm")
                Energize(player, player, uint32(std::llround(double(player->GetMaxPower(POWER_MANA)) * _a / 1000.0)), _spellId);
            // A second shot: the module's own copy of the wand's shot, fired
            // FROM THE BLOW ITSELF -- the shot leaves as the first one lands,
            // not a tick later. The core weighs it like the wand's own shot --
            // the same weapon damage, the same range, the same roll -- and a
            // wand must still be held for it to go off. Nothing here can loop:
            // the copy is not an auto-repeat spell, so the event never sees it.
            else if (A == "extra_shot")
            {
                if (!other || !other->IsAlive())
                    return;
                player->CastSpell(other, STELLAR_TAROT_SPELL_WAND_SHOT, true);
            }
        }
        std::string _event, _action;
        Drawback _but;
        float _lastFacing = -1.0f, _turned = 0.0f, _lastX = 0.0f, _lastY = 0.0f;
        uint32 _lastMs = 0;
        int32 _wasTurning = 0;      // le sens tenu au dernier paquet : 1 gauche, -1 droite
        int32 _spinWay = 0;         // le sens que la carte demande, 0 : les deux
        // Le nombre de cumuls que le bienfait porte apres ce declenchement :
        // ce que les revers « par cumul » multiplient.
        int32 _lastStacks = 1;
        // CE QUE LE COEUR TIENT POUR CETTE LIGNE : le de, la recharge, ou les
        // deux. La garniture `core:` le dit, le generateur l'ecrit.
        bool _coreChance = false, _coreIcd = false;
        int32 _eventN = 0, _eventM = 0, _row = 0, _spPct = 0, _ratingPct = 0, _countSpell = 0, _signSpell = 0;
        int32 _healPct = 0;             // le soin qui accompagne l'action
        int32 _low = 0;                 // la ligne ne part que sous ce seuil de PV
        std::string _only;              // l'etat que la ligne exige, s'il y en a un
        bool _restore = false;          // PV et mana remis a plein avant l'action
        bool _reset = false;            // les recharges remises a zero avant l'action
        int32 _echeance = 0;            // l'echeance, en secondes, avant de tomber a 1 PV
        int32 _soinDuCoup = 0;          // ce que le coup soigne tant que l'aura tient
        int32 _coupAllie = 0, _coupAllieM = 0;   // la part qu'un allie prend, et la portee
        uint32 _depuisEcheance = 0;     // quand le compte a redemarre
        std::map<ObjectGuid, uint32> _loin;   // depuis quand chaque allie etait loin
        std::vector<uint32> _depense;   // les auras que la ligne consomme en payant
        int32 _onlyN = 0;               // le chiffre de cet etat, quand il en demande un
        int32 _onlyM = 0;               // son second chiffre, quand il en demande deux
        std::vector<int32> _ratingParts;
        int32 _debuffSpell = 0;
        uint32 _lastSpellId = 0, _mirrorSpell = 0, _mirrorAmount = 0;
        bool _peaceSpent = false;
        uint32 _idleSince = 0;
        // _chance est EN POUR MILLE (25 = 2,5 %) ; la ligne, elle, l'ecrit en
        // pour-cent. Tout ce qui la lit ou l'annonce compte en pour mille.
        int32 _chance = 1000, _icd = 0, _a = 0, _b = 0, _c = 0, _trigger = 0, _nightEvery = 0;
        // L'ECOLE et le NUMERO du sort PRECEDEMMENT INCANTE : « changement
        // d'ecole », « sorts de meme ecole » et « meme sort relance » ne se
        // lisent que la. A ne pas confondre avec `_lastSchool` et
        // `_lastSpellId`, qui sont ceux du dernier COUP porte.
        uint32 _ecoleIncantee = 0, _sortIncante = 0;
        uint32 _sortSubi = 0;           // le dernier sort SUBI, pour le reflet
        bool _avaitBete = false;        // le familier etait vivant au tour d'avant
        int _heureVue = -1;             // l'heure lue au tour d'avant, -1 avant la premiere
        bool _enCapitale = false;       // le joueur etait deja en capitale
        uint32 _coupsSubis = 0;         // les coups subis d'affilee, sans en rendre
        uint32 _secondesDeJeu = 0;      // les secondes passees en jeu depuis le dernier du
        uint32 _course = 0;             // les secondes de course sans etre touche
        float _courseX = 0.0f, _courseY = 0.0f;
        // LE COMPTE DES CIBLES D'UN SORT : lesquelles, pour quel sort, et
        // depuis quand -- le coeur ne tient rien de tout cela.
        std::set<ObjectGuid> _touches;
        uint32 _sortTouche = 0, _depuisTouche = 0;
        bool _ditTouche = false;
        uint32 _venduEntry = 0;          // l'objet vendu, retenu jusqu'a l'arrivee de l'argent
        int32 _nightA = 0, _say = 0, _emote = 0, _thenPct = 0, _thenSec = 0, _thenSpell = 0;
        uint32 _seqUntil = 0;
        bool _onlyNight = false, _onlyDark = false;
        ObjectGuid _lastVictim;
        uint32 _lastAmount = 0;
        uint32 _last = 0, _elapsed = 0, _lastSchool = 0;
        bool _wasBelow = false, _wasFlying = false;
        uint32 _selling = 0;             // l'heure ou la somme est attendue
        bool _wasMounted = false;
        Spell* _lastCast = nullptr;
    };

    // =========================================================================
    // dmgmod:<condition>[:<n>]:<pct>[:<ecole>]  ·  wandmod:<chance>:<pct>[:hp_below:<n>]
    // takenmod:<condition>:<pct>[:<ecole>]      ·  tickmod:<chance>:<pct>[:onlynight]
    //     UN CHIFFRE MAJORE SOUS CONDITION. Quatre mots du classeur pour une
    //     seule mecanique : un pourcentage, une condition, parfois une ecole,
    //     parfois une chance, appliques au chiffre qui passe -- les degats
    //     donnes, ceux d'une baguette, ceux qu'on subit, le tic d'un effet
    //     periodique.
    //
    //     LE SUJET DE LA CONDITION est celui dont la carte parle : en donnant,
    //     la victime (« cible etourdie », « cible en flammes ») ; en subissant,
    //     le joueur (« seul », « dans le dos »).
    //
    //     CE QUE LE COEUR NE SAIT PAS DIRE. Il majore des degats par ECOLE
    //     (aura 79), par TYPE DE CREATURE (auras 59 et 168) ou par ETAT
    //     D'AURA (aura 303). Etourdie, ralentie, en flammes, seule, de dos,
    //     controlee, charmee, a distance, au-dessus d'un seuil : aucune de ces
    //     trois clefs ne les dit. « Sous 20 % de vie », en revanche, EST un
    //     etat d'aura du coeur : cette condition-la est ecrite en aura par le
    //     generateur et ne passe plus par ici.
    // =========================================================================
    class NumberMod : public StellarTarotScript
    {
    public:
        enum class Sense { Done, Wand, Taken, Tick };
        explicit NumberMod(Sense sense) : _sense(sense) { }

        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            switch (_sense)
            {
                case Sense::Done:
                {
                    _cond = r.Word();
                    if (!Accepte(_cond, DONE))
                        return (error = "unknown target condition \"" + _cond + "\"", false);
                    if (AvecNombre(_cond) && !r.Int(1, 100, _n))
                        return (error = _cond + " expects a number", false);
                    if (!r.Int(-100, 100000, _pct))
                        return (error = "expects the percentage", false);
                    // l'école, facultative : 0 ou absente, toutes les écoles
                    r.OptInt(0, 127, _school);
                    return r.End()
                        || (error = "after the percentage, only the school may follow", false);
                }
                case Sense::Wand:
                {
                    if (!r.Int(1, 100, _chance) || !r.Int(-100, 100000, _pct))
                        return (error = "expects the chance then the percentage", false);
                    if (!r.End())
                    {
                        if (r.Word() != "hp_below")
                            return (error = "after the percentage, only hp_below may follow", false);
                        _cond = "hp_below";
                        if (!r.Int(1, 100, _n))
                            return (error = "hp_below expects a number", false);
                    }
                    return r.End() || (error = "too many parameters", false);
                }
                case Sense::Taken:
                {
                    _cond = r.Word();
                    if (!Accepte(_cond, TAKEN))
                        return (error = "unknown condition \"" + _cond + "\"", false);
                    if (!r.Int(-100, 1000, _pct))
                        return (error = "expects the percentage", false);
                    r.OptInt(0, 127, _school);
                    return r.End()
                        || (error = "after the percentage, only the school may follow", false);
                }
                case Sense::Tick:
                {
                    if (!r.Int(1, 100, _chance) || !r.Int(1, 1000, _pct))
                        return (error = "expects the chance then the percentage", false);
                    if (!r.End())
                    {
                        if (r.Word() != "onlynight" || !r.End())
                            return (error = "after the percentage, only onlynight may follow", false);
                        _cond = "onlynight";
                    }
                    return true;
                }
            }
            return false;
        }

        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 school,
                           uint32 spellId) override
        {
            if (_sense == Sense::Done)
            {
                if (_school && !(school & uint32(_school)))
                    return;
                if (victim && Meets(player, victim, player))
                    Raise(damage);
                return;
            }
            if (_sense != Sense::Wand)
                return;
            if (!spell || !victim || !damage || !IsWandBlow(player, spellId))
                return;
            if (!Meets(player, victim, player) || !Tire())
                return;
            Raise(damage);
        }

        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool /*spell*/,
                           uint32 school, uint32 /*spellId*/) override
        {
            if (_sense != Sense::Taken)
                return;
            if (_school && !(school & uint32(_school)))
                return;
            if (Meets(player, player, attacker))
                Raise(damage);
        }

        // LE TIC QUE LE JOUEUR SUBIT : la meme reduction que sur un coup. Sans
        // cela « -5% degats subis » laissait passer les poisons, les brulures
        // et les zones au sol a plein -- la carte promettait plus qu'elle ne
        // tenait (releve en jeu le 2026-09-20, carte 83).
        // CE QUE CETTE LIGNE FAIT A L'INSTANT. Elle ne pose aucune aura : sans
        // cette phrase, rien au monde ne montre au joueur qu'un « -5% degats
        // subis » est en force ou non.
        bool DitSonEtat(Player* player, Unit* cible, std::string& out) override
        {
            char const* sens = _sense == Sense::Done ? "degats infliges"
                             : _sense == Sense::Taken ? "degats subis"
                             : _sense == Sense::Wand ? "degats de baguette"
                             : "tics";
            // Le sujet de la condition : la cible quand on frappe, le joueur
            // quand on subit -- le meme partage qu'au moment du coup.
            bool tient;
            if (_sense == Sense::Taken)
                tient = Meets(player, player, cible);
            else
                tient = cible && Meets(player, cible, player);
            out = std::string(sens) + " " + (_pct > 0 ? "+" : "") + std::to_string(_pct) + "%";
            if (!_cond.empty())
                out += " si " + _cond + " : " + (tient ? "OUI" : "non");
            else
                tient = true;
            if (_school)
                out += " (ecole " + std::to_string(_school) + ")";
            if (_chance != 100)
                out += " (" + std::to_string(_chance) + "% de chance)";
            out += tient ? " |ACTIF" : " |dormant";
            return true;
        }

        void OnPeriodicTaken(Player* player, Unit* attacker, uint32& amount, uint32 spellId) override
        {
            if (_sense != Sense::Taken || !amount || !player)
                return;
            if (_school)
            {
                SpellInfo const* const info = sSpellMgr->GetSpellInfo(spellId);
                if (!info || !(uint32(info->GetSchoolMask()) & uint32(_school)))
                    return;
            }
            if (Meets(player, player, attacker))
                Raise(amount);
        }

        void OnPeriodicTick(Player* player, Unit* other, uint32& amount, bool heal,
                            uint32 spellId) override
        {
            if (_sense != Sense::Tick || !amount || !player)
                return;
            if (_cond == "onlynight" && !IsNight())
                return;
            if (!Tire())
                return;
            // UN TIC DE PLUS, ET NON UN GROS TIC. Le meme montant tombe une
            // SECONDE FOIS, sous le meme sort : le joueur voit un second
            // chiffre et une seconde ligne au journal, ce que la carte promet.
            // Amplifier le tic donnait le meme total, mais invisible.
            uint32 const part = PctOf(amount, _pct);
            if (!part)
                return;
            // AU NOM DE LA CARTE : le journal dit « La Lune (niveau 4) », non le
            // sort qui tiquait. L'ECOLE, elle, reste celle de ce sort -- un
            // poison d'ombre rend bien un tic d'ombre.
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(spellId);
            if (heal)
                Heal(player, other ? other : player, part, _spellId);
            else if (other)
                Hurt(player, other, part,
                     info ? info->GetSchoolMask() : uint32(SPELL_SCHOOL_MASK_NORMAL), _spellId);
        }

    private:
        // LE VOCABULAIRE DES CONDITIONS, en un seul endroit : le mot, le
        // nombre qu'il attend, et les sens qui l'acceptent.
        static constexpr uint8 DONE = 1, WAND = 2, TAKEN = 4;
        struct Mot { char const* mot; bool nombre; uint8 sens; };

        static Mot const* Vocabulaire()
        {
            static Mot const mots[] = {
                { "stunned",    false, DONE },
                { "alone",      false, DONE | TAKEN },
                { "full_hp",    false, DONE },
                { "humanoid",   false, DONE },
                { "slowed",     false, DONE },
                { "burning",    false, DONE },
                { "hp_above",   true,  DONE },
                { "hp_below",   true,  DONE | WAND },
                { "range_over", true,  DONE },
                { "back",       false, TAKEN },
                { "controlled", false, TAKEN },
                { "charmed",    false, TAKEN },
                { nullptr,      false, 0 },
            };
            return mots;
        }

        static bool Accepte(std::string const& mot, uint8 sens)
        {
            for (Mot const* m = Vocabulaire(); m->mot; ++m)
                if (mot == m->mot)
                    return (m->sens & sens) != 0;
            return false;
        }

        static bool AvecNombre(std::string const& mot)
        {
            for (Mot const* m = Vocabulaire(); m->mot; ++m)
                if (mot == m->mot)
                    return m->nombre;
            return false;
        }

        bool Tire() const
        {
            return _chance >= 100 || int32(urand(1, 100)) <= _chance;
        }

        // LE CHIFFRE MAJORE. Le tic, lui, ne passe plus par ici : il ne se
        // majore pas, il tombe une seconde fois.
        void Raise(uint32& number) const
        {
            number = uint32(std::llround(double(number) * (100 + _pct) / 100.0));
        }

        // LE SUJET est celui dont la carte parle ; le VIS-A-VIS, l'autre.
        bool Meets(Player* player, Unit* sujet, Unit* vis_a_vis) const
        {
            if (_cond.empty())
                return true;
            return EtatTenu(_cond, _n, 0, player, sujet, vis_a_vis);
        }

        Sense const _sense;
        std::string _cond;
        int32 _n = 0, _pct = 0, _school = 0, _chance = 100;
    };

    // =========================================================================
    // gempct:<pct>
    //     CE QUE LES GEMMES DONNENT, et autant de plus. Les statistiques que les
    //     gemmes serties dans l'equipement donnent au joueur sont additionnees,
    //     et il en recoit ce pourcentage en plus, pose comme le coeur pose
    //     celles d'un objet -- sa fiche l'affiche donc. Le pouvoir particulier
    //     d'une meta-gemme n'est pas une statistique : il ne compte pas. Le
    //     total se relit a chaque battement, si bien que changer une piece ou
    //     sertir une gemme se voit dans la seconde.
    // =========================================================================
    // =========================================================================
    // randstat:<main|second>:<hausse>[:<baisse>]
    //     UNE STATISTIQUE TIREE AU SORT, et une autre a la baisse quand la
    //     ligne en demande une. Le tirage se fait quand la carte PREND EFFET --
    //     a la connexion, ou a la pose -- et tient jusqu'a ce qu'elle parte.
    //     Le chiffre est une part de ce que le joueur PORTE DEJA, comme
    //     `ratingpct`.
    //
    //     PAS D'AURA, ET C'EST FORCE : le `EffectMiscValue` d'un sort dit
    //     QUELLE statistique il majore, et il est ecrit dans le DBC. Aucun sort
    //     ne peut dire « une statistique quelconque ». Le module emprunte donc
    //     le chemin de `gempct` : `Poser`, celui-la meme que le coeur emploie
    //     pour les statistiques d'un objet.
    // =========================================================================
    class RandStat : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            std::string const famille = r.Word();
            if (famille != "main" && famille != "second" && famille != "speed")
                return (error = "randstat expects main, second or speed", false);
            _secondaires = (famille == "second");
            _vitesse = (famille == "speed");
            if (!r.Int(1, 1000, _haut))
                return (error = "randstat expects the percentage", false);
            // LA COURSE OU LA HATE : la course n'est pas une statistique
            // d'objet, le coeur ne la connait que par une aura. La ligne nomme
            // donc le sort qui la porte, et le module y met le chiffre.
            if (_vitesse && !r.Int(902000, 903999, _sortVitesse))
                return (error = "randstat speed expects its spell", false);
            r.OptInt(1, 1000, _bas);
            // UN NIVEAU PLUS HAUT RELEVE LES CHIFFRES : « les bonus passent a
            // 12% ». Il ne porte aucun script ; c'est celui-ci qui LIT SON
            // AURA pour savoir s'il doit compter plus grand -- le chemin meme
            // que suit la fievre de la carte 52.
            while (!r.End())
            {
                std::string const mot = r.Word();
                if (mot == "up" && r.Int(902000, 903999, _sortHaut) && r.Int(1, 1000, _hautPlus))
                    continue;
                if (mot == "down" && r.Int(902000, 903999, _sortBas) && r.Int(1, 1000, _basPlus))
                    continue;
                // `pulse:<sec>` : EN COMBAT, le tirage recommence tous les tant
                // de secondes. Hors combat, rien ne tient.
                if (mot == "pulse" && r.Int(1, 3600, _cadence))
                    continue;
                // `every:<sec>` : le meme tirage qui revient, mais SANS que le
                // combat y soit pour quelque chose -- « Connexion : une
                // statistique au hasard, 6 h ».
                if (mot == "every" && r.Int(1, 86400, _cadence))
                {
                    _horsCombat = true;
                    continue;
                }
                // `hold:<sec>` : ce que le tirage tient, apres quoi il tombe.
                if (mot == "hold" && r.Int(1, 3600, _tenue))
                    continue;
                // `then:<pct>:<sec>` : LA MEME statistique se retourne, ce
                // chiffre-la, ce temps-la. Le signe est dans le chiffre.
                if (mot == "then" && r.Int(-1000, 1000, _apres) && r.Int(1, 3600, _apresSec))
                    continue;
                return (error = "randstat: unknown trailer \"" + mot + "\"", false);
            }
            return true;
        }

        void Apply(Player* player) override
        {
            Rendre(player);
            Tirer(player);
            Regler(player);
        }
        void Remove(Player* player) override
        {
            Rendre(player);
            if (_sortVitesse)
                RemoveOwned(player, uint32(_sortVitesse));
            _posee = 0;
        }
        // LE NIVEAU DU HAUT PEUT ARRIVER APRES : les auras de la carte se
        // posent dans leur ordre. On relit a chaque battement, et le chiffre
        // se corrige dans la seconde.
        void OnTick(Player* player) override
        {
            // LE TIRAGE QUI REVIENT : hors combat, rien ne tient ; en combat,
            // il recommence a la cadence dite, tient son temps, et se retourne
            // ensuite si la ligne le demande.
            if (_cadence)
            {
                uint32 const now = uint32(GameTime::GetGameTime().count());
                if (!_horsCombat && !player->IsInCombat())
                {
                    if (_depuis)
                    {
                        Rendre(player);
                        _depuis = 0;
                        _retourne = false;
                    }
                    return;
                }
                if (!_depuis || now - _depuis >= uint32(_cadence))
                {
                    _depuis = now;
                    _retourne = false;
                    Rendre(player);
                    Tirer(player);
                }
                else
                {
                    uint32 const ecoule = now - _depuis;
                    // Le temps de tenue passe : la ligne se retourne, ou tombe.
                    if (_tenue && ecoule >= uint32(_tenue))
                    {
                        bool const encore = _apres
                            && ecoule < uint32(_tenue) + uint32(_apresSec);
                        if (encore != _retourne)
                        {
                            _retourne = encore;
                            Rendre(player);
                        }
                        if (!encore && !_apres)
                        {
                            Rendre(player);
                            return;
                        }
                        if (!encore)
                            return;
                    }
                }
            }
            Regler(player);
        }

    private:
        struct Choix { uint32 mod; uint32 index; };

        int32 _cadence = 0;         // le tirage recommence tous les tant de secondes
        int32 _tenue = 0;           // ce qu'il tient
        int32 _apres = 0;           // ce que la meme statistique prend ensuite
        int32 _apresSec = 0;        // et pour combien de temps
        uint32 _depuis = 0;         // l'heure du dernier tirage
        bool _retourne = false;     // la ligne en est a sa seconde moitie
        bool _horsCombat = false;   // le tirage revient meme hors combat

        void Rendre(Player* player)
        {
            for (auto const& [mod, val] : _donne)
                Poser(player, mod, val, false);
            _donne.clear();
        }

        int32 Valeur(Player* player, Choix const& c) const
        {
            return _secondaires
                 ? int32(player->GetUInt32Value(uint16(PLAYER_FIELD_COMBAT_RATING_1) + uint16(c.index)))
                 : int32(player->GetStat(Stats(c.index)));
        }

        // LES CHIFFRES DU MOMENT : ceux de la ligne, ou ceux qu'un niveau plus
        // haut impose quand son aura est la.
        void Regler(Player* player)
        {
            int32 const haut = (_sortHaut && player->HasAura(uint32(_sortHaut))) ? _hautPlus : _haut;
            // LA COURSE TIREE : une aura a elle, dont le module fixe le
            // chiffre a la pose -- le DBC n'en porte aucun.
            if (_vitesse && _courseTiree)
            {
                if (_posee != haut)
                {
                    RemoveOwned(player, uint32(_sortVitesse));
                    int32 const bp = haut;
                    Put(player, player, uint32(_sortVitesse), 0, &bp);
                    _posee = haut;
                }
                return;
            }
            if (_choix.empty())
                return;
            int32 const bas  = (_sortBas  && player->HasAura(uint32(_sortBas)))  ? _basPlus  : _bas;
            std::map<uint32, int32> veut;
            for (size_t i = 0; i < _choix.size(); ++i)
            {
                // LA MEME STATISTIQUE, RETOURNEE : passe le temps de tenue,
                // c'est le chiffre d'apres qui vaut, pour la premiere.
                int32 const pct = (i == 0) ? (_retourne ? _apres : haut) : -bas;
                int32 const val = int32(std::lround(double(Valeur(player, _choix[i])) * pct / 100.0));
                if (val)
                    veut[_choix[i].mod] = val;
            }
            if (veut == _donne)
                return;
            for (auto const& [mod, val] : _donne)
                Poser(player, mod, val, false);
            _donne = veut;
            for (auto const& [mod, val] : _donne)
                Poser(player, mod, val, true);
        }

        void Tirer(Player* player)
        {
            static Choix const PRINCIPALES[] = {
                { ITEM_MOD_STRENGTH, STAT_STRENGTH }, { ITEM_MOD_AGILITY, STAT_AGILITY },
                { ITEM_MOD_STAMINA, STAT_STAMINA }, { ITEM_MOD_INTELLECT, STAT_INTELLECT },
                { ITEM_MOD_SPIRIT, STAT_SPIRIT },
            };
            static Choix const SECONDAIRES[] = {
                { ITEM_MOD_CRIT_MELEE_RATING, CR_CRIT_MELEE },
                { ITEM_MOD_HASTE_MELEE_RATING, CR_HASTE_MELEE },
                { ITEM_MOD_HIT_MELEE_RATING, CR_HIT_MELEE },
                { ITEM_MOD_DODGE_RATING, CR_DODGE },
                { ITEM_MOD_PARRY_RATING, CR_PARRY },
                { ITEM_MOD_EXPERTISE_RATING, CR_EXPERTISE },
                { ITEM_MOD_ARMOR_PENETRATION_RATING, CR_ARMOR_PENETRATION },
            };
            if (_vitesse)
            {
                // Pile la course, face la hate. Le choix tient tant que la
                // carte est la ; seul son chiffre suit le niveau.
                _choix.clear();
                _courseTiree = (urand(0, 1) == 0);
                if (!_courseTiree)
                    _choix.push_back({ ITEM_MOD_HASTE_RATING, CR_HASTE_MELEE });
                return;
            }
            Choix const* const liste = _secondaires ? SECONDAIRES : PRINCIPALES;
            uint32 const combien = _secondaires ? 7u : 5u;
            // LE TIRAGE NE SE FAIT QU'UNE FOIS : les statistiques choisies
            // tiennent tant que la carte est la ; seuls leurs CHIFFRES suivent
            // le niveau.
            _choix.clear();
            uint32 const haut = urand(0, combien - 1);
            _choix.push_back(liste[haut]);
            if (!_bas)
                return;
            // UNE AUTRE, jamais la meme : le classeur dit « une autre ».
            uint32 bas = urand(0, combien - 2);
            if (bas >= haut)
                ++bas;
            _choix.push_back(liste[bas]);
        }

        bool _secondaires = false;
        int32 _haut = 0, _bas = 0;
        int32 _sortHaut = 0, _hautPlus = 0, _sortBas = 0, _basPlus = 0;
        bool _vitesse = false, _courseTiree = false;
        int32 _sortVitesse = 0, _posee = 0;
        std::vector<Choix> _choix;      // la hausse d'abord, la baisse ensuite
        std::map<uint32, int32> _donne;
    };

    // =========================================================================
    // goldstat:<pct>:<tranche en cuivre>:<plafond>
    //     CE QUE LA BOURSE DONNE : un pourcentage des statistiques principales
    //     par tranche d'or possede, plafonne. Relu a chaque battement -- la
    //     bourse change a tout moment, et le chiffre suit.
    //
    //     PAS D'AURA, pour la meme raison que `randstat` : le chiffre depend
    //     de ce que le joueur porte a l'instant, et le DBC ne sait pas le dire.
    //     Meme `Poser` que `gempct`, celui du coeur pour les objets.
    // =========================================================================
    class GoldStat : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.Int(1, 2000000000, _tranche) && r.Int(1, 1000, _plafond)
                    && r.End())
                || (error = "goldstat expects the percentage, the slice and the cap", false);
        }
        void Apply(Player* player) override { Regler(player); }
        void Remove(Player* player) override { Rendre(player); }
        void OnTick(Player* player) override { Regler(player); }

    private:
        void Rendre(Player* player)
        {
            for (auto const& [mod, val] : _donne)
                Poser(player, mod, val, false);
            _donne.clear();
        }

        void Regler(Player* player)
        {
            uint32 const tranches = uint32(player->GetMoney() / uint32(_tranche));
            int32 const pct = std::min<int32>(_plafond, int32(tranches) * _pct);
            std::map<uint32, int32> veut;
            if (pct > 0)
            {
                static std::pair<uint32, uint32> const PRINCIPALES[] = {
                    { ITEM_MOD_STRENGTH, STAT_STRENGTH }, { ITEM_MOD_AGILITY, STAT_AGILITY },
                    { ITEM_MOD_STAMINA, STAT_STAMINA }, { ITEM_MOD_INTELLECT, STAT_INTELLECT },
                    { ITEM_MOD_SPIRIT, STAT_SPIRIT },
                };
                for (auto const& [mod, stat] : PRINCIPALES)
                {
                    int32 const val = int32(std::lround(double(player->GetStat(Stats(stat))) * pct / 100.0));
                    if (val)
                        veut[mod] = val;
                }
            }
            if (veut == _donne)
                return;
            Rendre(player);
            _donne = veut;
            for (auto const& [mod, val] : _donne)
                Poser(player, mod, val, true);
        }

        int32 _pct = 0, _tranche = 0, _plafond = 0;
        std::map<uint32, int32> _donne;
    };

    // =========================================================================
    // cheatdeath:<secondes d'invulnerabilite>:<icd>
    //     LE COUP QUI DEVAIT TUER NE TUE PAS. Le joueur reste a 1 PV, et rien
    //     ne l'atteint pendant les secondes qui suivent.
    //
    //     AVANT LA MORT, PAS APRES : le module n'est pas ici pour relever un
    //     cadavre -- `resurrect` fait cela ailleurs. Il RABOTE le coup, dans
    //     les crochets ou le coeur laisse encore changer le chiffre
    //     (`ModifyMeleeDamage`, `ModifySpellDamageTaken`,
    //     `ModifyPeriodicDamageAurasTick`). Un coup de 40 000 sur 12 000 PV
    //     devient un coup de 11 999.
    //
    //     CE QUE LE COEUR NE PEUT PAS DIRE : des degats qu'un script infligerait
    //     directement par `Unit::DealDamage` ne passent par aucun de ces trois
    //     crochets, et cette carte ne les verra pas.
    // =========================================================================
    class CheatDeath : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 60, _immunite) || !r.Int(1, 86400, _icd))
                return (error = "cheatdeath expects the seconds then the cooldown", false);
            // `then:<sort>:<sec>` : CE QU'IL EN COUTE une fois le plancher
            // passe -- « puis ralenti de 50%, 10 sec ». Le sort porte le
            // chiffre ; la ligne ne dit que sa duree.
            if (!r.End())
            {
                if (r.Word() != "then")
                    return (error = "after the cooldown, only then:<spell>:<sec> may follow", false);
                if (!r.Int(902000, 903999, _apres) || !r.Int(1, 3600, _apresSec))
                    return (error = "then expects its spell then the seconds", false);
            }
            return r.End() || (error = "too many parameters", false);
        }

        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& damage, bool /*spell*/,
                           uint32 /*school*/, uint32 /*spellId*/) override
        {
            Raboter(player, damage);
        }
        // LE PLANCHER CESSE : c'est alors que le prix se paie.
        void OnTick(Player* player) override
        {
            if (!_apres || !_arme || !player)
                return;
            if (uint32(GameTime::GetGameTime().count()) < _arme + uint32(_immunite))
                return;
            _arme = 0;
            Put(player, player, uint32(_apres), _apresSec);
        }
        void OnPeriodicTaken(Player* player, Unit* /*attacker*/, uint32& amount, uint32 /*spellId*/) override
        {
            Raboter(player, amount);
        }

    private:
        void Raboter(Player* player, uint32& degats)
        {
            if (!player || !degats)
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            // LES SECONDES DE REPIT : rien ne passe, quoi qu'il arrive.
            if (now < _invulnerableJusqua)
            {
                degats = 0;
                return;
            }
            uint32 const pv = player->GetHealth();
            if (degats < pv)
                return;                        // ce coup-la ne tuait pas
            if (_dernier && now - _dernier < uint32(_icd))
                return;                        // la carte a deja servi
            _dernier = now;
            // LE PLANCHER VIENT DE PRENDRE : le prix se paiera a sa fin.
            _arme = now;
            _invulnerableJusqua = now + uint32(_immunite);
            degats = pv - 1;                   // il en reste un
        }

        int32 _immunite = 0, _icd = 0, _apres = 0, _apresSec = 0;
        uint32 _arme = 0;           // l'heure ou le plancher a pris
        uint32 _dernier = 0, _invulnerableJusqua = 0;
    };

    class GemPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }
        void Apply(Player* player) override { Recompute(player); }
        void Remove(Player* player) override { Give(player, false); _donne.clear(); }
        void OnTick(Player* player) override { Recompute(player); }

    private:
        void Recompute(Player* player)
        {
            std::map<uint32, int32> veut;
            static uint8 const chatons[] = { SOCK_ENCHANTMENT_SLOT, SOCK_ENCHANTMENT_SLOT_2,
                                             SOCK_ENCHANTMENT_SLOT_3, PRISMATIC_ENCHANTMENT_SLOT };
            for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            {
                Item const* const piece = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
                if (!piece)
                    continue;
                for (uint8 chaton : chatons)
                {
                    uint32 const id = piece->GetEnchantmentId(EnchantmentSlot(chaton));
                    if (!id)
                        continue;
                    SpellItemEnchantmentEntry const* const gemme = sSpellItemEnchantmentStore.LookupEntry(id);
                    if (!gemme)
                        continue;
                    for (uint8 k = 0; k < MAX_ITEM_ENCHANTMENT_EFFECTS; ++k)
                        if (gemme->type[k] == ITEM_ENCHANTMENT_TYPE_STAT && gemme->amount[k])
                            veut[gemme->spellid[k]] += int32(gemme->amount[k]);
                }
            }
            std::map<uint32, int32> part;
            for (auto const& [stat, total] : veut)
            {
                int32 const donne = int32(std::llround(double(total) * _pct / 100.0));
                if (donne > 0)
                    part[stat] = donne;
            }
            if (part == _donne)
                return;
            Give(player, false);
            _donne = part;
            Give(player, true);
        }
        void Give(Player* player, bool apply)
        {
            for (auto const& [stat, val] : _donne)
                Poser(player, stat, val, apply);
        }
        // LE MEME CHEMIN QUE LE COEUR pour les statistiques d'un objet : la
        // fiche du joueur compte ce qui passe par la.
        int32 _pct = 0;
        std::map<uint32, int32> _donne;
    };

    // =========================================================================
    // convoy:<sec>:<cumuls>:<portee>
    //     LA COLONNE EN MARCHE. Tant que le porteur avance, l'aura du niveau se
    //     pose sur lui et sur les siens a portee -- seul, elle n'est que pour
    //     lui -- et gagne un cumul toutes les <sec> secondes, jusqu'a <cumuls>.
    //     Qu'il s'arrete et tout tombe, pour lui comme pour eux. L'aura ne vit
    //     que quelques secondes et se renouvelle a chaque battement : celui qui
    //     quitte la colonne la perd de lui-meme.
    // =========================================================================
    class Convoy : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 3600, _every) && r.Int(2, 100, _stacks) && r.Int(1, 300, _yards) && r.End())
                || (error = "expects the seconds a stack, the stacks then the yards", false);
        }
        [[nodiscard]] bool OwnsAura() const override { return true; }
        void Apply(Player* player) override
        {
            _moving = 0;
            _x = player->GetPositionX();
            _y = player->GetPositionY();
        }
        void Remove(Player* player) override { Clear(player); }
        void OnTick(Player* player) override
        {
            float const x = player->GetPositionX(), y = player->GetPositionY();
            // EN SELLE ET EN MARCHE : descendre vaut arret, de son plein gre ou non.
            bool const moving = player->IsMounted()
                && (std::fabs(x - _x) > 0.1f || std::fabs(y - _y) > 0.1f);
            _x = x; _y = y;
            if (!moving)
            {
                if (_moving)
                    Clear(player);
                _moving = 0;
                return;
            }
            ++_moving;
            int32 const want = std::min<int32>(_stacks, int32(_moving / uint32(_every)));
            if (want <= 0)
                return;
            // L'aura n'a pas de duree : elle tient jusqu'a ce qu'on la retire.
            // Ceux qui sortent de la colonne la perdent au battement suivant.
            std::vector<ObjectGuid> tenus;
            for (Player* member : GroupAround(player, float(_yards)))
            {
                Put(player, member, _spellId, 0);
                if (Aura* aura = member->GetAura(_spellId, player->GetGUID()))
                    aura->SetStackAmount(uint8(want));
                tenus.push_back(member->GetGUID());
            }
            for (ObjectGuid const& guid : _portee)
                if (std::find(tenus.begin(), tenus.end(), guid) == tenus.end())
                    if (Player* parti = ObjectAccessor::FindPlayer(guid))
                        parti->RemoveAurasDueToSpell(_spellId, player->GetGUID());
            _portee = tenus;
        }
        // UN COUP ENCAISSE ROMPT LA COLONNE -- un tic de poison ou de saignement
        // arrive par un autre chemin et n'y touche pas.
        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& /*damage*/, bool /*spell*/,
                           uint32 /*school*/, uint32 /*spellId*/) override
        {
            if (!_moving)
                return;
            _moving = 0;
            Clear(player);
        }

    private:
        void Clear(Player* player)
        {
            for (ObjectGuid const& guid : _portee)
                if (Player* member = ObjectAccessor::FindPlayer(guid))
                    member->RemoveAurasDueToSpell(_spellId, player->GetGUID());
            _portee.clear();
            player->RemoveAurasDueToSpell(_spellId, player->GetGUID());
        }
        int32 _every = 0, _stacks = 0, _yards = 0;
        uint32 _moving = 0;
        float _x = 0, _y = 0;
        std::vector<ObjectGuid> _portee;
    };

    // =========================================================================
    // seal:<sec>:<pct>:<sort>
    //     LE SCEAU. Un sort du joueur qui frappe une cible sans sceau y pose le
    //     sien, pour tant de secondes ; chacun des siens qui la frappe ensuite y
    //     ajoute un cumul -- le sceau ne repond qu'a la main qui l'a pose -- et
    //     le n-ieme coup frappe de tant de pour cent de plus et brise le sceau.
    //     Chaque coup remet la duree a plein.
    // =========================================================================
    class Seal : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 3600, _sec) && r.Int(1, 1000, _pct) && r.Int(2, 100, _n)
                    && r.Int(902000, 903999, _mark) && r.End())
                || (error = "expects the seconds, the percentage, the number of strikes then the mark spell", false);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 /*school*/,
                           uint32 spellId) override
        {
            if (!spell || !victim || !damage || spellId == uint32(_mark))
                return;
            Aura* const mark = victim->GetAura(uint32(_mark), player->GetGUID());
            int32 const borne = mark ? int32(mark->GetStackAmount()) : 0;
            // CE COUP-CI EST-IL LE DERNIER ? Alors il frappe plus fort et le
            // sceau eclate ; sinon il ajoute son cumul et rend sa duree pleine.
            if (borne + 1 >= _n)
            {
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
                victim->RemoveAurasDueToSpell(uint32(_mark), player->GetGUID());
                return;
            }
            if (!mark)
            {
                Put(player, victim, uint32(_mark), _sec);
                return;
            }
            mark->SetStackAmount(uint8(borne + 1));
            mark->SetMaxDuration(_sec * 1000);
            mark->SetDuration(_sec * 1000);
        }

    private:
        int32 _sec = 0, _pct = 0, _n = 0, _mark = 0;
    };

    // =========================================================================
    // sp_pct:<pct>  -- the level's spell: MOD_DAMAGE_DONE (magic) + MOD_HEALING_DONE
    // =========================================================================
    class SpellPowerPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 1000, _pct))
                return (error = "expects the percentage", false);
            // night:<pct> -- the percentage the night takes over with
            if (!r.End())
            {
                if (r.Word() != "night" || !r.Int(1, 1000, _night) || !r.End())
                    return (error = "after the percentage, only night:<pct> may follow", false);
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _applied = 0; Recompute(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _applied = 0; }
        void OnTick(Player* player) override { Recompute(player); }
    private:
        void Recompute(Player* player)
        {
            int32 const pct = (_night && IsNight()) ? _night : _pct;
            int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
            int32 const bonus = int32(std::llround(double(current) * pct / 100.0));
            if (bonus == _applied && player->HasAura(_spellId))
                return;
            _applied = bonus;
            // LE CHIFFRE VA AUX EFFETS QUI PORTENT LA PUISSANCE DES SORTS, ou
            // qu'ils soient dans le sort : le niveau peut en porter un autre
            // -- un modificateur de cout, par exemple -- qui garde la valeur
            // que le generateur lui a ecrite. Et cet autre effet a de bonnes
            // raisons d'occuper le premier rang : le client ne lit droit le
            // masque de classe d'un modificateur que la.
            int32 const bp = bonus;             // whole: the core takes the die side out itself
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            int32 veut[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            uint8 masque = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (info && (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE
                          || info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_HEALING_DONE))
                {
                    veut[i] = bonus;
                    masque |= uint8(1 << i);
                }
            if (ReglerAura(player, _spellId, veut, masque))
                return;
            RemoveOwned(player, _spellId);
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (masque & uint8(1 << i))
                    p[i] = &bp;
            player->CastCustomSpell(player, _spellId, p[0], p[1], p[2], true);
        }
        int32 _pct = 0, _night = 0, _applied = 0;
    };

    // =========================================================================
    // schoolsp:<pct>:<ecole>[:<pct>:<ecole>...]
    //     UNE PART DE LA PUISSANCE DES SORTS, ECOLE PAR ECOLE. Le niveau porte
    //     un effet MOD_DAMAGE_DONE par ecole nommee et chacun recoit sa part de
    //     la puissance des sorts du joueur -- celle qu'on lui a deja versee
    //     retiree d'abord, pour qu'elle ne se nourrisse pas d'elle-meme --
    //     recalculee chaque seconde. La FICHE DE PERSONNAGE la montre alors dans
    //     les degats bonus de l'ecole, ce qu'un pourcentage de degats infliges
    //     ne fait jamais. Une part negative retranche.
    // =========================================================================
    class SchoolSpellPower : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            while (!r.End())
            {
                int32 pct = 0, school = 0;
                if (!r.Int(-1000, 1000, pct) || !pct || !r.Int(1, 127, school))
                    return (error = "expects pairs of percentage and school", false);
                _parts.push_back(Part{ pct, school });
            }
            return !_parts.empty() || (error = "expects a percentage and a school", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _applied = 0; Recompute(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _applied = 0; }
        void OnTick(Player* player) override { Recompute(player); }

    private:
        struct Part { int32 pct; int32 school; };

        void Recompute(Player* player)
        {
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            if (!info)
                return;
            int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
            int32 amounts[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            int32 total = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (info->Effects[i].ApplyAuraName != SPELL_AURA_MOD_DAMAGE_DONE)
                    continue;
                for (Part const& part : _parts)
                    if (part.school == info->Effects[i].MiscValue)
                    {
                        amounts[i] = int32(std::llround(double(current) * part.pct / 100.0));
                        total += amounts[i];
                        break;
                    }
            }
            if (total == _applied && player->HasAura(_spellId))
                return;
            _applied = total;
            uint8 masque = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (amounts[i])
                    masque |= uint8(1 << i);
            if (ReglerAura(player, _spellId, amounts, masque))
                return;
            RemoveOwned(player, _spellId);
            int32 bp[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (amounts[i])
                {
                    bp[i] = amounts[i];          // entier : le coeur retranche le de lui-meme
                    p[i] = &bp[i];
                }
            player->CastCustomSpell(player, _spellId, p[0], p[1], p[2], true);
        }

        std::vector<Part> _parts;
        int32 _applied = 0;
    };
    class SecondaryPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 1000, _pct))
                return (error = "expects the percentage", false);
            while (!r.End())
            {
                int32 id = 0;
                if (!r.Int(902000, 903999, id))
                    return (error = "after the percentage, only companion spells", false);
                _more.push_back(uint32(id));
            }
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override
        {
            _applied = 0;
            Recompute(player);
            for (uint32 id : _more)
                ApplyOwned(player, id);
        }
        void Remove(Player* player) override
        {
            RemoveOwned(player, _spellId);
            for (uint32 id : _more)
                RemoveOwned(player, id);
            _applied = 0;
        }
        void OnTick(Player* player) override { Recompute(player); }

    private:
        // La puissance des sorts se recalcule, le reste vient du DBC.
        void Recompute(Player* player)
        {
            int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
            int32 const bonus = int32(std::llround(double(current) * _pct / 100.0));
            if (bonus == _applied && player->HasAura(_spellId))
                return;
            _applied = bonus;
            int32 const bp = bonus;
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            int32 veut[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            uint8 masque = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (info && (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE
                          || info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_HEALING_DONE))
                {
                    veut[i] = bonus;
                    masque |= uint8(1 << i);
                }
            if (ReglerAura(player, _spellId, veut, masque))
                return;
            RemoveOwned(player, _spellId);
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (masque & uint8(1 << i))
                    p[i] = &bp;
            player->CastCustomSpell(player, _spellId, p[0], p[1], p[2], true);
        }
        int32 _pct = 0, _applied = 0;
        std::vector<uint32> _more;
    };

    // =========================================================================
    // ratingpct:<pct>
    //     UN SCORE, en part de lui-meme. Le niveau lit le score que le joueur
    //     porte deja -- celui que sa fiche affiche --, en prend le pourcentage
    //     et le lui rend en points. Les scores touches sont ceux que le sort
    //     nomme : chaque effet MOD_RATING dit par son masque de quel score il
    //     parle. Le calcul se refait a chaque battement, l'equipement ayant pu
    //     changer entre-temps.
    // =========================================================================
    class RatingPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            int32 part = 0;
            if (!r.Int(-1000, 1000, part))
                return (error = "expects the percentage", false);
            _parts.push_back(part);
            while (r.OptInt(-1000, 1000, part))
                _parts.push_back(part);
            if (!r.End())
                return (error = "expects one percentage per rating and nothing more", false);
            _pct = _parts[0];
            return true;
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { Forget(); Recompute(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); Forget(); }
        void OnTick(Player* player) override { Recompute(player); }

    private:
        void Forget()
        {
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                _applied[i] = 0;
        }

        // Le premier score que le masque nomme : c'est celui-la qu'on lit.
        static int32 FirstRating(int32 mask)
        {
            for (int32 cr = 0; cr < MAX_COMBAT_RATING; ++cr)
                if (mask & (1 << cr))
                    return cr;
            return -1;
        }

        void Recompute(Player* player)
        {
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            if (!info)
                return;
            bool const worn = player->HasAura(_spellId);
            bool change = !worn;
            size_t compte = 0;
            int32 want[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (info->Effects[i].ApplyAuraName != SPELL_AURA_MOD_RATING)
                    continue;
                int32 const cr = FirstRating(info->Effects[i].MiscValue);
                if (cr < 0)
                    continue;
                // LA FICHE COMPTE DEJA CE QUE LE NIVEAU A DONNE : on le retire
                // avant d'en prendre la part, sinon le score s'enfle tout seul.
                int32 const mine = worn ? _applied[i] : 0;
                int32 const own = std::max(0, int32(player->GetUInt32Value(uint16(PLAYER_FIELD_COMBAT_RATING_1) + uint16(cr))) - mine);
                // UNE PART PAR SCORE NOMME, dans l'ordre ou le sort les nomme.
                int32 const part = _parts[std::min<size_t>(compte, _parts.size() - 1)];
                ++compte;
                want[i] = int32(std::llround(double(own) * part / 100.0));
                if (want[i] != _applied[i])
                    change = true;
            }
            if (!change)
                return;
            uint8 masque = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                _applied[i] = want[i];
                if (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_RATING)
                    masque |= uint8(1 << i);
            }
            if (ReglerAura(player, _spellId, want, masque))
                return;
            RemoveOwned(player, _spellId);
            int32 bp[MAX_SPELL_EFFECTS];
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                bp[i] = want[i];            // whole: the core takes the die side out itself
                if (masque & uint8(1 << i))
                    p[i] = &bp[i];
            }
            player->CastCustomSpell(player, _spellId, p[0], p[1], p[2], true);
        }
        int32 _pct = 0;
        std::vector<int32> _parts;
        int32 _applied[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
    };

    // =========================================================================
    // stat:<day>:<night>
    //     The level's aura, at the figure the hour calls for: every effect of
    //     the spell is given that figure, recast when the hour changes it.
    // =========================================================================
    class NightStat : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(-1000, 1000, _day) && r.Int(-1000, 1000, _night) && r.End())
                || (error = "expects the figure by day then by night", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _has = false; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _has = false; }
        void OnTick(Player* player) override { Check(player); }

    private:
        void Check(Player* player)
        {
            int32 const want = IsNight() ? _night : _day;
            if (_has && want == _applied && player->HasAura(_spellId))
                return;
            _applied = want;
            _has = true;
            int32 const veut[MAX_SPELL_EFFECTS] = { want, want, want };
            if (ReglerAura(player, _spellId, veut, 0x7))
                return;
            RemoveOwned(player, _spellId);
            // One short: the spell's die side adds the last point, the way the
            // generator writes every figure.
            int32 const bp = want;
            player->CastCustomSpell(player, _spellId, &bp, &bp, &bp, true);
        }
        int32 _day = 0, _night = 0, _applied = 0;
        bool _has = false;
    };

    // =========================================================================
    // statcond:<state>[:<n>]:<hors>:<sous>
    //     The level's aura, at one figure while a state holds and another the
    //     rest of the time; every effect of the spell gets that figure, recast
    //     when the state turns. `stat` does the same for the hour; this one
    //     reads a state -- hp_below:<pct> and its kin.
    // =========================================================================
    class StateStat : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _state = r.Word();
            if (_state == "hp_below" || _state == "hp_above" || _state == "mana_below")
            {
                if (!r.Int(1, 100, _n))
                    return (error = _state + " expects a percentage", false);
            }
            else if (_state != "combat" && _state != "nocombat" && _state != "solo"
                     && _state != "night" && _state != "day")
                return (error = "unknown state \"" + _state + "\"", false);
            return (r.Int(-1000, 1000, _out) && r.Int(-1000, 1000, _in) && r.End())
                || (error = "expects the figure outside the state then inside it", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { _has = false; Check(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _has = false; }
        void OnTick(Player* player) override { Check(player); }

    private:
        bool Holds(Player* player) const
        {
            if (_state == "hp_below") return player->GetHealthPct() < float(_n);
            if (_state == "hp_above") return player->GetHealthPct() > float(_n);
            if (_state == "mana_below") return player->GetPowerPct(POWER_MANA) < float(_n);
            if (_state == "combat") return player->IsInCombat();
            if (_state == "nocombat") return !player->IsInCombat();
            if (_state == "solo") return !player->GetGroup();
            if (_state == "night") return IsNight();
            if (_state == "day") { int const h = LocalHour(); return h >= 6 && h < 21; }
            return false;
        }
        void Check(Player* player)
        {
            int32 const want = Holds(player) ? _in : _out;
            if (_has && want == _applied && player->HasAura(_spellId))
                return;
            _applied = want;
            _has = true;
            int32 const veut[MAX_SPELL_EFFECTS] = { want, want, want };
            if (ReglerAura(player, _spellId, veut, 0x7))
                return;
            RemoveOwned(player, _spellId);
            int32 const bp = want;           // whole: the core takes the die side out itself
            player->CastCustomSpell(player, _spellId, &bp, &bp, &bp, true);
        }
        std::string _state;
        int32 _n = 0, _out = 0, _in = 0, _applied = 0;
        bool _has = false;
    };

    // =========================================================================
    // costmod:heal_low:<hp percent>:<discount percent>
    // =========================================================================
    class CostMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _kind = r.Word();
            if (_kind == "heal_self")
                return (r.Int(1, 100, _pct) && r.End())
                    || (error = "heal_self expects the discount", false);
            if (_kind != "heal_low")
            {
                error = "unknown kind \"" + _kind + "\"";
                return false;
            }
            return (r.Int(1, 100, _hp) && r.Int(1, 100, _pct) && r.End())
                || (error = "expects the share of health then the discount", false);
        }
        void OnSpellCast(Player* player, Spell* spell) override
        {
            SpellInfo const* const info = spell->GetSpellInfo();
            if (spell->IsTriggered() || info->PowerType != POWER_MANA)
                return;
            // UN SOIN QUI DURE EST UN SOIN : un sort qui pose un soin periodique
            // compte comme celui qui rend tout d'un coup.
            if (!(info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                  || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH)
                  || info->HasAura(SPELL_AURA_PERIODIC_HEAL) || info->HasAura(SPELL_AURA_OBS_MOD_HEALTH)))
                return;
            // UN SOIN SANS CIBLE se donne a soi-meme : le client n'envoie alors
            // aucune cible, et le coeur la resout plus tard.
            Unit* const target = spell->m_targets.GetUnitTarget() ? spell->m_targets.GetUnitTarget() : player;
            // heal_self : le soin qu'on se donne A SOI, et nul autre.
            // heal_low : la cible sous sa part de vie, dite par le vocabulaire
            // commun des etats.
            if (_kind == "heal_self" ? target != player
                                     : !EtatTenu("hp_below", _hp, 0, player, target, nullptr))
                return;
            int32 const back = int32(PctOf(uint32(std::max(0, spell->GetPowerCost())), _pct));
            if (back <= 0)
                return;
            // LA RISTOURNE SE VOIT : rendue par le sort du niveau, elle passe
            // par le journal du client et monte dans le texte defilant, au lieu
            // d'arriver en silence.
            uint32 const spellId = _spellId;
            PlusTard(player, TOUR_SUIVANT, [back, spellId](Player* p)
            {
                Energize(p, p, uint32(back), spellId);
            });
        }

    private:
        std::string _kind;
        int32 _hp = 0, _pct = 0;
    };

    // =========================================================================
    // drink:<pct>
    //     CE QU'UNE BOISSON REND, releve d'autant. Le mana qu'une boisson verse
    //     a chaque tic se lit au moment ou l'aura se pose et s'y remet plus
    //     haut. La nourriture, elle, rend de la vie : elle n'est pas touchee.
    // =========================================================================
    class Drink : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            // Le plafond est large a dessein : un essai a besoin d'un chiffre
            // enorme pour que l'oeil tranche sans chronometre.
            return (r.Int(1, 100000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }
        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override
        {
            if (!aura || target != player)
                return;
            // UNE BOISSON SE RECONNAIT A SA FORME : le premier effet regenere,
            // le second est un dummy periodique qui porte le chiffre. Au premier
            // tic, le coeur recopie ce chiffre dans la regeneration -- c'est donc
            // le dummy qu'il faut relever, et lui seul.
            AuraEffect* const regen = aura->GetEffect(0);
            AuraEffect* const verse = aura->GetEffect(1);
            if (!regen || !verse || regen->GetAuraType() != SPELL_AURA_MOD_POWER_REGEN
                || verse->GetAuraType() != SPELL_AURA_PERIODIC_DUMMY)
                return;
            int32 const amount = verse->GetAmount();
            if (amount <= 0)
                return;
            int32 const releve = amount + int32(PctOf(uint32(amount), _pct));
            verse->SetAmount(releve);
            // Le coeur recopie ce chiffre dans la regeneration au premier tic ;
            // on l'y met tout de suite, pour que la premiere gorgee compte deja.
            regen->ChangeAmount(releve);
        }

    private:
        int32 _pct = 0;
    };

    // CE QUE LA CARTE A CHANGE, DIT AU CLIENT. Le client ecrit l'infobulle d'un
    // buff depuis son propre Spell.dbc : il n'y lit que les chiffres de la
    // potion, le serveur ne lui envoyant d'une aura que son identifiant, ses
    // drapeaux, ses cumuls et sa duree. L'addon du module corrige donc
    // l'infobulle lui-meme, a condition qu'on lui porte les montants -- un
    // message d'addon, chuchote au joueur, exactement comme AIO en envoie.
    // LE PAQUET VIT AILLEURS : `StellarTarotEffects::TellAddon`, dont le bloc
    // de mesure se sert aussi. Un seul endroit fabrique ce message.
    void TellClient(Player* player, char const* prefix, std::string const& message)
    {
        StellarTarotEffects::TellAddon(player, prefix, message);
    }

    // =========================================================================
    // fever:<part>:<part aggravee>:<quatre sorts>:<sort du niveau qui aggrave>:
    //       <sort du niveau qui accelere>
    //     LA FIEVRE, UN NIVEAU QUE LES AUTRES MODIFIENT. Tant que le joueur est
    //     EN COMBAT, il porte un debuff a lui qui lui prend cette part de ses PV
    //     max a chaque battement -- une part EXACTE : les sorts portent les
    //     attributs qui tiennent hors du compte la puissance du lanceur et la
    //     resistance de la cible. Quatre sorts sont nommes, un par couple de
    //     part et de battement, et la ligne pose celui que la carte appelle : la
    //     part aggravee tant que le niveau qui aggrave est pose, le battement
    //     rapide tant que celui qui accelere l'est. Hors combat, la fievre tombe.
    // =========================================================================
    class Fever : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _pct) || !r.Int(1, 100, _pctMore))
                return (error = "expects the share, then the worsened share", false);
            for (uint8 i = 0; i < 4; ++i)
            {
                int32 id = 0;
                if (!r.Int(902000, 903999, id))
                    return (error = "expects four fever spells", false);
                _spells[i] = uint32(id);
                gFeverSpells.insert(uint32(id));
            }
            int32 aggrave = 0, accelere = 0;
            if (!r.Int(902000, 903999, aggrave) || !r.Int(902000, 903999, accelere))
                return (error = "expects the spells of the levels that change the fever", false);
            _worse = uint32(aggrave);
            _faster = uint32(accelere);
            return r.End() || (error = "after the spells, nothing else", false);
        }
        void Apply(Player* player) override { Hold(player); }
        void Remove(Player* player) override { Drop(player, 0); }
        void OnTick(Player* player) override { Hold(player); }

    private:
        void Drop(Player* player, uint32 keep)
        {
            for (uint32 spell : _spells)
                if (spell && spell != keep)
                    RemoveOwned(player, spell);
        }

        void Hold(Player* player)
        {
            if (!player->IsInCombat())
            {
                Drop(player, 0);
                return;
            }
            bool const fort = _worse && player->HasAura(_worse);
            bool const vite = _faster && player->HasAura(_faster);
            uint32 const voulu = _spells[(fort ? 1 : 0) + (vite ? 2 : 0)];
            Drop(player, voulu);
            int32 const parTic = int32(PctOf(player->GetMaxHealth(), fort ? _pctMore : _pct));
            if (Aura* deja = player->GetAura(voulu, player->GetGUID()))
            {
                // Les PV max ont pu changer : le chiffre suit.
                if (AuraEffect* eff = deja->GetEffect(0))
                    if (eff->GetAmount() != parTic)
                        eff->ChangeAmount(parTic);
                return;
            }
            int32 const bp = parTic;            // entier : le coeur retranche le de lui-meme
            Put(player, player, voulu, 0, &bp);
        }

        uint32 _spells[4] = { 0, 0, 0, 0 };   // 0 base, 1 aggravee, 2 rapide, 3 les deux
        uint32 _worse = 0, _faster = 0;
        int32 _pct = 0, _pctMore = 0;
    };
    // L'objet qui a servi a lancer le sort, quand il y en a un : c'est par lui
    // qu'une fiole se reconnait, le sort seul ne disant pas d'ou il vient.
    ItemTemplate const* CastItemOf(Spell* spell)
    {
        return spell && spell->m_CastItem ? spell->m_CastItem->GetTemplate() : nullptr;
    }

    bool IsPotionItem(ItemTemplate const* proto)
    {
        return proto && proto->Class == ITEM_CLASS_CONSUMABLE && proto->SubClass == ITEM_SUBCLASS_POTION;
    }

    bool EstUnePotion(Spell* spell)
    {
        return IsPotionItem(CastItemOf(spell));
    }

    // UN REPAS : le jeu range la nourriture et la boisson sous la meme sorte.
    bool IsFoodItem(ItemTemplate const* proto)
    {
        return proto && proto->Class == ITEM_CLASS_CONSUMABLE && proto->SubClass == ITEM_SUBCLASS_FOOD;
    }

    // UN ELIXIR OU UN FLACON : l'OBJET le dit, et lui seul -- le sort d'un
    // elixir ne se distingue en rien de celui d'une potion.
    bool IsElixirItem(ItemTemplate const* proto)
    {
        return proto && proto->Class == ITEM_CLASS_CONSUMABLE
            && (proto->SubClass == ITEM_SUBCLASS_ELIXIR || proto->SubClass == ITEM_SUBCLASS_FLASK);
    }

    // =========================================================================
    // potion:<pct>
    //     CE QU'UNE POTION DONNE, et autant de plus. Le crochet du sort se pose
    //     AVANT que les effets ne tombent : les chiffres lus sont donc ceux de
    //     la potion elle-meme, jamais le tirage qu'elle fera -- personne ne le
    //     connait a cet instant, pas meme la pierre de l'alchimiste du coeur,
    //     qui compte de la meme facon.
    // =========================================================================
    class PotionPower : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (!player || !IsPotionItem(CastItemOf(spell)))
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            if (!info)
                return;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                int32 const value = info->Effects[i].CalcValue(player);
                if (value <= 0)
                    continue;
                uint32 const part = PctOf(uint32(value), _pct);
                if (!part)
                    continue;
                if (info->Effects[i].Effect == SPELL_EFFECT_HEAL)
                    Heal(player, player, part, _spellId);
                else if (info->Effects[i].Effect == SPELL_EFFECT_ENERGIZE
                         && info->Effects[i].MiscValue == int32(POWER_MANA))
                    Energize(player, player, part, _spellId);
            }
        }

        // LES POTIONS QUI NE SOIGNENT PAS : celles qui posent une aura -- une
        // statistique, une hate, une armure. Le coeur a deja applique l'effet
        // quand il previent, d'ou ChangeAmount, qui le repose au bon chiffre.
        //
        // La part se prend sur le chiffre PROPRE de la potion, jamais sur celui
        // qu'une autre ligne aurait deja releve : deux niveaux d'une meme carte
        // s'AJOUTENT ainsi au lieu de se multiplier.
        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override
        {
            if (!player || !aura || target != player)
                return;
            if (!IsPotionItem(sObjectMgr->GetItemTemplate(aura->GetCastItemEntry())))
                return;
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info)
                return;
            // « <chiffre de la potion>&<chiffre applique> », une paire par
            // effet : de quoi remplacer dans l'infobulle le nombre que le
            // client y lit par celui que le serveur applique vraiment.
            std::string dit;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                AuraEffect* const eff = aura->GetEffect(i);
                if (!eff)
                    continue;
                int32 const propre = info->Effects[i].CalcValue(player);
                if (propre <= 0)
                    continue;
                int32 const part = int32(PctOf(uint32(propre), _pct));
                if (!part)
                    continue;
                int32 const releve = eff->GetAmount() + part;
                eff->ChangeAmount(releve);
                dit += "|" + std::to_string(propre) + "&" + std::to_string(releve);
            }
            // Les deux niveaux d'une meme carte parlent chacun leur tour, dans
            // l'ordre : le dernier message porte le total, et c'est celui-la que
            // l'addon garde.
            if (!dit.empty())
                TellClient(player, "StellarTarotPotion", std::to_string(aura->GetId()) + dit);
        }

    private:
        int32 _pct = 0;
    };

    // =========================================================================
    // potion_keep:<chance>
    //     LA FIOLE QUI NE SE VIDE PAS. Le coeur reprendra son exemplaire une
    //     fois le sort lance ; la carte en remet un dans les sacs au moment ou
    //     la fiole se leve, et la pile ne bouge pas. Un sac plein ne depense
    //     pas la chance : la place est demandee avant le tirage.
    // =========================================================================
    class PotionKeep : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            // `food` : le meme geste, mais pour un repas. Sans le mot, une fiole.
            if (!r.End())
            {
                if (r.Word() != "food")
                    return (error = "after the chance, only food may follow", false);
                _food = true;
            }
            return r.End() || (error = "too many parameters", false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            ItemTemplate const* const proto = CastItemOf(spell);
            if (!player || !proto)
                return;
            if (!(_food ? IsFoodItem(proto) : IsPotionItem(proto)))
                return;
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, proto->ItemId, 1) != EQUIP_ERR_OK)
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            if (Item* rendue = player->StoreNewItem(dest, proto->ItemId, true))
                player->SendNewItem(rendue, 1, true, false);
        }

    private:
        int32 _chance = 0;
        bool _food = false;
    };

    // =========================================================================
    // potionplus:<quoi>[:<n>[:<sec>]]
    //     CE QU'UNE FIOLE DONNE EN PLUS, au moment ou le joueur l'avale.
    //       opposite:<pct> la RESSOURCE OPPOSEE : une potion de soin rend en
    //                      plus cette part de la ressource du joueur, une
    //                      potion de mana cette part de ses PV.
    //       cooldown:<pct> le temps de recharge de la fiole, raccourci d'autant
    //       other          l'effet d'une AUTRE fiole du sac, tiree au hasard
    //       over:<pct>:<sec> la meme part de l'effet, mais rendue sur la duree
    // =========================================================================
    class PotionPlus : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _what = r.Word();
            if (_what == "other")
                return r.End() || (error = "other takes nothing", false);
            if (_what == "opposite" || _what == "cooldown" || _what == "over")
            {
                if (!r.Int(1, 100, _pct))
                    return (error = _what + " expects its percentage", false);
                if (_what == "over" && !r.Int(1, 3600, _sec))
                    return (error = "over expects the seconds", false);
                return r.End() || (error = "too many parameters", false);
            }
            return (error = "unknown potionplus " + _what, false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            ItemTemplate const* const proto = CastItemOf(spell);
            if (!player || !IsPotionItem(proto))
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            if (!info)
                return;
            if (_what == "cooldown")
            {
                // La recharge de la fiole : c'est la CATEGORIE qui la porte, et
                // le coeur la raccourcit comme n'importe quelle autre.
                uint32 const sort = info->Id;
                int32 const part = _pct;
                PlusTard(player, TOUR_SUIVANT, [sort, part](Player* p)
                {
                    if (SpellInfo const* fiole = sSpellMgr->GetSpellInfo(sort))
                    {
                        int32 const duree = int32(fiole->RecoveryTime ? fiole->RecoveryTime
                                                                     : fiole->CategoryRecoveryTime);
                        if (duree > 0)
                            p->ModifySpellCooldown(sort, -duree * part / 100);
                    }
                });
                return;
            }
            // UNE AUTRE FIOLE DU SAC : son effet, sans qu'elle soit bue. On ne
            // prend que ce que le joueur porte vraiment, et jamais celle-ci.
            if (_what == "other")
            {
                std::vector<uint32> fioles;
                for (uint8 sac = INVENTORY_SLOT_ITEM_START; sac < INVENTORY_SLOT_ITEM_END; ++sac)
                    if (Item const* porte = player->GetItemByPos(INVENTORY_SLOT_BAG_0, sac))
                        if (IsPotionItem(porte->GetTemplate()) && porte->GetEntry() != proto->ItemId)
                            for (uint8 i = 0; i < MAX_ITEM_PROTO_SPELLS; ++i)
                                if (porte->GetTemplate()->Spells[i].SpellId > 0
                                    && porte->GetTemplate()->Spells[i].SpellTrigger == ITEM_SPELLTRIGGER_ON_USE)
                                    fioles.push_back(uint32(porte->GetTemplate()->Spells[i].SpellId));
                if (fioles.empty())
                    return;
                uint32 const tiree = fioles[urand(0, uint32(fioles.size()) - 1)];
                PlusTard(player, TOUR_SUIVANT, [tiree](Player* p) { p->CastSpell(p, tiree, true); });
                return;
            }
            // LA RESSOURCE OPPOSEE, et la meme part rendue sur la duree : dans
            // les deux cas, on lit ce que la fiole PROMET, effet par effet.
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                int32 const valeur = info->Effects[i].CalcValue(player);
                if (valeur <= 0)
                    continue;
                uint32 const part = PctOf(uint32(valeur), _pct);
                if (!part)
                    continue;
                bool const soigne = info->Effects[i].Effect == SPELL_EFFECT_HEAL;
                bool const abreuve = info->Effects[i].Effect == SPELL_EFFECT_ENERGIZE;
                if (!soigne && !abreuve)
                    continue;
                if (_what == "opposite")
                {
                    if (soigne)
                        Energize(player, player, part, _spellId);
                    else
                        Heal(player, player, part, _spellId);
                }
                // `over` : la meme part, mais versee par tranches d'une seconde.
                else if (_what == "over")
                    Verser(player, part, _sec, soigne);
            }
        }

    private:
        // LA PART VERSEE SUR LA DUREE : une tranche par seconde, chacune
        // annoncee comme le reste de ce que le module rend.
        void Verser(Player* player, uint32 total, int32 secondes, bool soins)
        {
            uint32 const tranche = std::max<uint32>(1, total / uint32(std::max(1, secondes)));
            uint32 const sort = _spellId;
            for (int32 n = 1; n <= secondes; ++n)
                PlusTard(player, Milliseconds(n * 1000), [tranche, sort, soins](Player* p)
                {
                    if (soins)
                        Heal(p, p, tranche, sort);
                    else
                        Energize(p, p, tranche, sort);
                });
        }

        std::string _what;
        int32 _pct = 0, _sec = 0;
    };

    // =========================================================================
    // deathkeep
    //     LES FIOLES TRAVERSENT LA MORT. Le coeur enleve toutes les auras d'un
    //     mort ; la ligne releve celles qui viennent d'un ELIXIR ou d'un FLACON
    //     juste avant, avec ce qu'il leur restait a vivre, et les repose quand
    //     le joueur se releve. Rien n'est prolonge : ce qui restait, reste.
    // =========================================================================
    class DeathKeep : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            return Reader(params).End() || (error = "takes no parameter", false);
        }

        void OnDeath(Player* player) override
        {
            _gardees.clear();
            if (!player)
                return;
            for (auto const& [id, aura] : player->GetOwnedAuras())
            {
                if (!aura || aura->GetDuration() <= 0)
                    continue;
                if (!IsElixirItem(sObjectMgr->GetItemTemplate(aura->GetCastItemEntry())))
                    continue;
                _gardees.push_back({ id, aura->GetDuration(), aura->GetStackAmount() });
            }
        }

        void OnResurrect(Player* player) override
        {
            if (!player)
                return;
            for (Fiole const& f : _gardees)
                if (Aura* remise = player->AddAura(f.spell, player))
                {
                    remise->SetDuration(f.duree);
                    if (f.cumuls > 1)
                        remise->SetStackAmount(f.cumuls);
                }
            _gardees.clear();
        }

    private:
        struct Fiole
        {
            uint32 spell = 0;
            int32 duree = 0;
            uint8 cumuls = 1;
        };
        std::vector<Fiole> _gardees;
    };

    // =========================================================================
    // elixirlong:<pct> · dotlong:<ecole>:<tics> · stunlong:<sec> · shoutlong:<facteur>
    //     ALLONGER UNE AURA. Quatre lignes du classeur disaient la meme chose
    //     de quatre facons : un elixir tient plus longtemps, un poison d'une
    //     ecole gagne des tics, un etourdissement gagne des secondes, un cri
    //     dure plusieurs fois plus. Une seule mecanique, quatre criteres.
    //
    //     CE QUE LE COEUR NE SAIT PAS DIRE. Il allonge une aura de deux
    //     manieres : SPELLMOD_DURATION (auras 107/108), qui choisit les sorts
    //     par FAMILLE et masque de classe, et MECHANIC_DURATION_MOD (232/234),
    //     qui s'applique a la CIBLE pour une mecanique -- donc pour raccourcir
    //     ce qu'on subit. Ni « un elixir », ni « l'ecole de givre », ni « un
    //     nom qui contient Shout », ni « un etourdissement que JE pose » ne
    //     s'expriment ainsi : les CRITERES restent au module.
    //
    //     CE QUE LE COEUR REPREND : le MOMENT. Aura::CalcMaxDuration appelle
    //     OnCalcMaxDuration (SpellAuras.cpp:807) avant que l'aura n'existe. La
    //     duree est donc juste du premier paquet, au lieu d'etre corrigee
    //     apres la pose. Le revers, lui, attend la pose : un prix ne se paie
    //     pas au milieu de la construction d'une aura.
    // =========================================================================
    // =========================================================================
    // breakfree:<chance>:<icd>
    //     BRISER LE CONTROLE QU'ON SUBIT. Une aura qui porte la mecanique de
    //     l'etourdissement ou de l'enracinement vient de se poser sur le
    //     joueur : un tirage, et elle s'en va.
    //
    //     CE QUE FAIT LE COEUR : il nomme la mecanique de chaque effet
    //     (`SpellInfo::GetAllEffectsMechanicMask`) et il retire l'aura. Le
    //     module ne fait que tirer le de et attendre UN TOUR D'HORLOGE --
    //     defaire l'aura depuis le crochet qui annonce sa pose reviendrait a la
    //     retirer pendant que le coeur la range encore.
    //
    //     AUCUN CROCHET NEUF : le relais de `UNITHOOK_ON_AURA_APPLY`, que le
    //     module tenait deja pour celui qui LANCE, sert ici a celui qui SUBIT.
    // =========================================================================
    class BreakFree : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            r.OptInt(0, 3600, _icd);
            return r.End() || (error = "too many parameters", false);
        }

        void OnAuraTaken(Player* player, Unit* /*caster*/, Aura* aura) override
        {
            if (!player || !aura)
                return;
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info)
                return;
            uint64 const controle = (uint64(1) << MECHANIC_STUN) | (uint64(1) << MECHANIC_ROOT);
            if (!(info->GetAllEffectsMechanicMask() & controle))
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _last && now - _last < uint32(_icd))
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            _last = now;
            uint32 const sort = aura->GetId();
            PlusTard(player, TOUR_SUIVANT, [sort](Player* p) { p->RemoveAurasDueToSpell(sort); });
        }

    private:
        int32 _chance = 100, _icd = 0;
        uint32 _last = 0;
    };

    class Longer : public StellarTarotScript
    {
    public:
        // LES DEUX DERNIERES SONT DES DUREES QUE LE JOUEUR SUBIT OU SAVOURE :
        // la maladie de resurrection, qu'on raccourcit, et le "Bien nourri",
        // qu'on allonge. Toutes deux se reconnaissent a leur sort, que le jeu
        // nomme et ne change jamais.
        enum class Kind { Elixir, Dot, Stun, Cry, Sickness, Food };
        explicit Longer(Kind kind) : _kind(kind) { }

        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            switch (_kind)
            {
                case Kind::Elixir:
                    return (r.Int(1, 1000, _a) && r.End())
                        || (error = "expects the percentage", false);
                case Kind::Dot:
                    return (r.Int(1, 127, _school) && r.Int(1, 20, _a) && r.End())
                        || (error = "expects the school then the number of ticks", false);
                case Kind::Stun:
                    // EN DIXIEMES DE SECONDE : une carte allonge de « 0,5 sec »
                    // (92 N1) aussi bien que de deux (23 N3). En secondes
                    // entieres, la demi-seconde ne s'ecrivait pas du tout.
                    if (!r.Int(1, 600, _a))
                        return (error = "expects the tenths of a second", false);
                    return ReadDrawback(r, _but, error);
                case Kind::Cry:
                    if (!r.Int(2, 100, _a))
                        return (error = "expects the factor", false);
                    return ReadDrawback(r, _but, error);
                case Kind::Sickness:
                    return (r.Int(1, 100, _a) && r.End())
                        || (error = "expects the percentage taken off", false);
                case Kind::Food:
                    return (r.Int(1, 3600, _a) && r.End())
                        || (error = "expects the seconds added", false);
            }
            return false;
        }

        // LE COEUR CALCULE LA DUREE : l'allongement se decide ici, avant que
        // l'aura n'existe, et non plus apres sa pose.
        void OnCalcAuraDuration(Player* player, Aura const* aura, int32& duration) override
        {
            if (Fits(player, aura, duration))
                duration = Stretched(aura, duration);
        }

        // LE REVERS SE PAIE APRES COUP, l'aura posee.
        void OnAuraApplied(Player* player, Unit* /*target*/, Aura* aura) override
        {
            if (_but.Some() && aura && Fits(player, aura, aura->GetMaxDuration()))
                SufferDrawback(player, _but, _spellId, 0);
        }

    private:
        // L'AURA REPOND-ELLE AU CRITERE de la ligne ?
        bool Fits(Player* player, Aura const* aura, int32 duration) const
        {
            if (!aura || duration <= 0)
                return false;
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info)
                return false;
            switch (_kind)
            {
                case Kind::Elixir:
                {
                    // L'aura dit de quel objet elle vient : un elixir, ni une
                    // potion, ni un flacon -- et sur le joueur lui-meme.
                    if (aura->GetOwner() != player)
                        return false;
                    ItemTemplate const* const proto =
                        sObjectMgr->GetItemTemplate(aura->GetCastItemEntry());
                    return proto && proto->Class == ITEM_CLASS_CONSUMABLE
                        && proto->SubClass == ITEM_SUBCLASS_ELIXIR;
                }
                case Kind::Dot:
                    return (info->GetSchoolMask() & uint32(_school))
                        && info->HasAura(SPELL_AURA_PERIODIC_DAMAGE);
                case Kind::Stun:
                {
                    if (aura->GetOwner() == player)
                        return false;
                    if (info->HasAura(SPELL_AURA_MOD_STUN) || info->Mechanic == MECHANIC_STUN)
                        return true;
                    for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                        if (info->Effects[i].Mechanic == MECHANIC_STUN)
                            return true;
                    return false;
                }
                // LA MALADIE DE RESURRECTION ET LE "BIEN NOURRI" : deux sorts
                // que le jeu nomme une fois pour toutes, 15007 et 19705. Rien
                // a deviner, ils se reconnaissent a leur numero.
                case Kind::Sickness:
                    return aura->GetOwner() == player && info->Id == 15007;
                case Kind::Food:
                    return aura->GetOwner() == player && info->Id == 19705;
                case Kind::Cry:
                {
                    // Un cri se reconnait a son nom ANGLAIS -- l'index 0 du
                    // DBC, quelle que soit la langue du client : le coeur ne
                    // range ces sorts sous aucune famille qui les reunisse.
                    if (!info->SpellName[0])
                        return false;
                    std::string const name = info->SpellName[0];
                    static char const* const cries[] = { "Shout", "Howl", "Scream", "Roar" };
                    for (char const* w : cries)
                        if (name.find(w) != std::string::npos)
                            return true;
                    return false;
                }
            }
            return false;
        }

        // DE COMBIEN ELLE S'ALLONGE.
        int32 Stretched(Aura const* aura, int32 duration) const
        {
            switch (_kind)
            {
                case Kind::Elixir:
                    return duration + int32(PctOf(uint32(duration), _a));
                case Kind::Dot:
                {
                    // UN TIC DE PLUS VAUT SA PERIODE, sans quoi le temps donne
                    // n'achete rien : deux secondes ajoutees a une periode de
                    // trois ne font pas un tic. La periode se lit dans le DBC
                    // du sort -- les effets de l'aura n'existent pas encore.
                    SpellInfo const* const info = aura->GetSpellInfo();
                    int32 period = 0;
                    for (uint8 i = 0; i < MAX_SPELL_EFFECTS && !period; ++i)
                        if (info->Effects[i].ApplyAuraName == SPELL_AURA_PERIODIC_DAMAGE
                            && info->Effects[i].Amplitude > 0)
                            period = int32(info->Effects[i].Amplitude);
                    return period > 0 ? duration + period * _a : duration;
                }
                case Kind::Stun:
                    return duration + _a * 100;   // des dixiemes
                case Kind::Sickness:
                    return duration - int32(PctOf(uint32(duration), _a));
                case Kind::Food:
                    return duration + _a * 1000;
                case Kind::Cry:
                    return duration * _a;
            }
            return duration;
        }

        Kind const _kind;
        int32 _a = 0, _school = 0;
        Drawback _but;
    };

    // =========================================================================
    // petaura:<sort>
    //     UNE AURA QUI VIT SUR LA BETE, et non sur le maitre. Le sort du niveau
    //     reste au joueur -- c'est lui qui porte le revers, quand la carte en
    //     donne un -- et ce sort-ci, un compagnon, est pose sur le familier.
    //     La bete change, meurt, revient : la ligne la retrouve a chaque tic.
    // =========================================================================
    class AuraDeBete : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(902000, 903999, _sort))
                return (error = "expects the companion spell", false);
            // `all` : toute la maisonnee -- la bete, les gardiens, les totems.
            if (!r.End())
            {
                if (r.Word() != "all")
                    return (error = "after the spell, only all may follow", false);
                _tous = true;
            }
            return r.End() || (error = "too many parameters", false);
        }
        void Apply(Player* player) override { Poser(player); }
        void Remove(Player* player) override
        {
            if (!player)
                return;
            for (Unit* serviteur : Maisonnee(player))
                serviteur->RemoveAurasDueToSpell(uint32(_sort));
        }
        void OnTick(Player* player) override { Poser(player); }

    private:
        // CE QUE LE JOUEUR MENE : sa bete seule, ou tout ce qu'il controle.
        std::vector<Unit*> Maisonnee(Player* player) const
        {
            std::vector<Unit*> gens;
            if (!_tous)
            {
                if (Pet* bete = player->GetPet())
                    gens.push_back(bete);
                return gens;
            }
            for (Unit* mene : player->m_Controlled)
                if (mene)
                    gens.push_back(mene);
            return gens;
        }

        void Poser(Player* player)
        {
            if (!player)
                return;
            for (Unit* serviteur : Maisonnee(player))
                if (serviteur->IsAlive() && !serviteur->HasAura(uint32(_sort), player->GetGUID()))
                    player->AddAura(uint32(_sort), serviteur);
        }

        int32 _sort = 0;
        bool _tous = false;
    };

    // =========================================================================
    // cdcut:<pct>
    //     LES TEMPS DE RECHARGE, RACCOURCIS D'AUTANT. Aucune aura du coeur ne
    //     sait le faire en POUR-CENT sans nommer une famille de sorts : l'aura
    //     196 est un nombre de secondes, et le modificateur 108/SPELLMOD_COOLDOWN
    //     demande un masque de classe. La ligne s'en remet donc a la methode du
    //     coeur -- ModifySpellCooldown -- appliquee au sort qui vient d'etre
    //     lance, une fois que le coeur a pose sa recharge.
    // =========================================================================
    class CooldownCut : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 99, _pct) && r.End())
                || (error = "expects the percentage", false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (!player || !spell || spell->IsTriggered())
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            if (!info)
                return;
            uint32 const sort = info->Id;
            int32 const part = _pct;
            PlusTard(player, TOUR_SUIVANT, [sort, part](Player* p)
            {
                uint32 const now = GameTime::GetGameTimeMS().count();
                auto const it = p->GetSpellCooldownMap().find(sort);
                if (it == p->GetSpellCooldownMap().end() || it->second.end <= now)
                    return;
                int32 const reste = int32(it->second.end - now);
                p->ModifySpellCooldown(sort, -reste * part / 100);
            });
        }

    private:
        int32 _pct = 0;
    };

    // =========================================================================
    // petshare:<pct>
    //     LA BETE PORTE SA PART DES COUPS. Ce que le maitre subit est reduit de
    //     cette part, et la meme part tombe sur le familier. Sans bete vivante,
    //     rien ne change : le maitre prend tout.
    // =========================================================================
    class PetShare : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 99, _pct) && r.End())
                || (error = "expects the percentage", false);
        }

        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& damage, bool /*spell*/,
                           uint32 school, uint32 /*spellId*/) override
        {
            if (!player || !damage)
                return;
            Pet* const bete = player->GetPet();
            if (!bete || !bete->IsAlive())
                return;
            uint32 const part = PctOf(damage, _pct);
            if (!part)
                return;
            damage -= part;
            Hurt(player, bete, part, school ? school : uint32(SPELL_SCHOOL_MASK_NORMAL), _spellId);
        }

    private:
        int32 _pct = 0;
    };

    // =========================================================================
    // heirloompct:<pct>
    //     UNE PART DES STATISTIQUES QUE PORTENT LES OBJETS HERITAGE. Le chiffre
    //     d'un heritage MONTE AVEC LE NIVEAU du porteur : aucune aura du DBC ne
    //     peut le dire, il se relit donc a chaque tic, comme la part des gemmes.
    //     Le meme chemin que le coeur pour les statistiques d'un objet, afin que
    //     la fiche du personnage compte ce qui passe par la.
    // =========================================================================
    class HeirloomPct : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }
        void Apply(Player* player) override { Recompute(player); }
        void Remove(Player* player) override { Give(player, false); _donne.clear(); }
        void OnTick(Player* player) override { Recompute(player); }

    private:
        void Recompute(Player* player)
        {
            std::map<uint32, int32> veut;
            for (uint8 place = EQUIPMENT_SLOT_START; place < EQUIPMENT_SLOT_END; ++place)
            {
                Item const* const piece = player->GetItemByPos(INVENTORY_SLOT_BAG_0, place);
                if (!piece)
                    continue;
                ItemTemplate const* const modele = piece->GetTemplate();
                if (!modele || modele->Quality != ITEM_QUALITY_HEIRLOOM)
                    continue;
                // CE QUE L'OBJET PORTE AU NIVEAU DU JOUEUR. Un heritage ne
                // porte pas ses chiffres dans son gabarit : ils sortent des
                // memes tables que le coeur lit (Player::_ApplyItemBonuses) --
                // ScalingStatDistribution pour le partage entre statistiques,
                // ScalingStatValues pour l'echelle du niveau.
                ScalingStatDistributionEntry const* const partage =
                    modele->ScalingStatDistribution
                        ? sScalingStatDistributionStore.LookupEntry(modele->ScalingStatDistribution)
                        : nullptr;
                uint32 niveau = player->GetLevel();
                if (partage && niveau > partage->MaxLevel)
                    niveau = partage->MaxLevel;
                ScalingStatValuesEntry const* const echelle =
                    modele->ScalingStatValue ? sScalingStatValuesStore.LookupEntry(niveau) : nullptr;
                for (uint8 k = 0; k < MAX_ITEM_PROTO_STATS; ++k)
                {
                    uint32 quoi = 0;
                    int32 montant = 0;
                    if (echelle && partage)
                    {
                        if (partage->StatMod[k] < 0)
                            continue;
                        quoi = uint32(partage->StatMod[k]);
                        montant = (echelle->getssdMultiplier(modele->ScalingStatValue)
                                   * partage->Modifier[k]) / 10000;
                    }
                    else
                    {
                        if (k >= modele->StatsCount)
                            continue;
                        quoi = modele->ItemStat[k].ItemStatType;
                        montant = modele->ItemStat[k].ItemStatValue;
                    }
                    if (montant > 0)
                        veut[quoi] += montant;
                }
            }
            std::map<uint32, int32> part;
            for (auto const& [stat, total] : veut)
            {
                int32 const donne = int32(std::llround(double(total) * _pct / 100.0));
                if (donne > 0)
                    part[stat] = donne;
            }
            if (part == _donne)
                return;
            Give(player, false);
            _donne = part;
            Give(player, true);
        }
        void Give(Player* player, bool apply)
        {
            for (auto const& [stat, val] : _donne)
                Poser(player, stat, val, apply);
        }

        int32 _pct = 0;
        std::map<uint32, int32> _donne;
    };

    // =========================================================================
    // LE META-EFFET D'UNE CARTE A DEUX ETATS
    //
    // phase:<cadence>:<groupe>:<sortHaut>:<sortBas>[:mana:<pct>][:heal:<pct>]
    //       [:both:<toutes>:<duree>][:high:<sous-script>][:low:<sous-script>]
    //
    //     UNE CARTE, DEUX ETATS, UNE SEULE HORLOGE. La maree monte et descend,
    //     le Soleil cede a la Lune : c'est la CARTE qui bat, non le niveau.
    //     Tous les niveaux d'une meme carte portent le meme `groupe` -- son
    //     numero -- et lisent la meme horloge : ils changent donc d'etat
    //     ensemble, quel que soit l'ordre ou ils s'appliquent.
    //
    //     CE QU'UN NIVEAU APPORTE A CHAQUE ETAT :
    //       <sortHaut> / <sortBas>  une aura par etat, posee tant qu'il tient
    //                               (0 quand ce niveau n'en donne pas)
    //       high:<sous-script>      ce que le niveau FAIT dans l'etat haut
    //       low:<sous-script>       ce qu'il fait dans l'etat bas
    //     Un sous-script est un script entier -- « proc:spell_cast:5:0:free_next »
    //     -- et le conteneur lui repasse tout ce que le coeur annonce, tant que
    //     son etat tient. Rien n'est reecrit : c'est le meme moteur.
    //
    //     LA CADENCE : un nombre de secondes, ou le mot `night` -- l'etat haut
    //     est alors la NUIT, et l'etat bas le jour.
    //
    //     `mana:` / `heal:` : a chaque CHANGEMENT, cette part est rendue.
    //     `both:<toutes>:<duree>` : toutes les `toutes` secondes, les DEUX
    //     auras se posent ensemble pour `duree` secondes, a deux cumuls --
    //     l'eclipse.
    // =========================================================================

    // L'HORLOGE D'UNE CARTE, par joueur : le premier niveau qui bat la met a
    // l'heure, tous les autres la lisent. Sans elle, deux niveaux poses a une
    // seconde d'intervalle battraient a contretemps.
    struct Horloge
    {
        uint32 depuis = 0;          // le debut du cycle, en secondes de jeu
        bool haute = true;
        uint32 eclipseJusqua = 0;   // tant que les deux auras tiennent ensemble
        uint32 eclipseDepuis = 0;   // la derniere eclipse
    };

    std::map<std::pair<uint32, int32>, Horloge>& Horloges()
    {
        static std::map<std::pair<uint32, int32>, Horloge> horloges;
        return horloges;
    }

    class Phase : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            // LA CADENCE : des secondes, ou la nuit.
            if (r.Peek() == "night")
            {
                r.Word();
                _nuit = true;
            }
            else if (!r.Int(1, 3600, _sec))
                return (error = "phase expects the seconds, or night", false);
            if (!r.Int(1, 1000, _groupe))
                return (error = "phase expects the card it belongs to", false);
            if (!r.Int(0, 903999, _haut) || !r.Int(0, 903999, _bas))
                return (error = "phase expects its two spells (0 for none)", false);
            while (!r.End())
            {
                std::string const mot = r.Word();
                if (mot == "mana" && r.Int(1, 100, _mana))
                    continue;
                if (mot == "heal" && r.Int(1, 100, _heal))
                    continue;
                if (mot == "both" && r.Int(1, 86400, _eclipseChaque) && r.Int(1, 3600, _eclipseDuree))
                    continue;
                // LE SOUS-SCRIPT D'UN ETAT : tout ce qui suit lui appartient,
                // jusqu'au mot de l'autre etat.
                if (mot == "high" || mot == "low")
                {
                    StellarTarotScriptSpec sous;
                    bool premier = true;
                    while (!r.End() && r.Peek() != "high" && r.Peek() != "low")
                    {
                        std::string const part = r.Word();
                        if (premier)
                            sous.name = part;
                        else
                            sous.params.push_back(part);
                        premier = false;
                    }
                    if (sous.name.empty())
                        return (error = mot + " expects a script", false);
                    sous.text = sous.name;
                    std::string pourquoi;
                    std::unique_ptr<StellarTarotScript> fait =
                        StellarTarotScripts::Create(sous, pourquoi);
                    if (!fait)
                        return (error = mot + ": " + pourquoi, false);
                    (mot == "high" ? _sousHaut : _sousBas) = std::move(fait);
                    continue;
                }
                return (error = "phase: unknown word \"" + mot + "\"", false);
            }
            return true;
        }

        // LE SORT DU NIVEAU est aussi celui des sous-scripts : ce qu'ils posent
        // et ce qu'ils annoncent porte le nom de la ligne.
        void Apply(Player* player) override
        {
            if (_sousHaut) { _sousHaut->SetSpell(SpellId()); _sousHaut->Apply(player); }
            if (_sousBas)  { _sousBas->SetSpell(SpellId());  _sousBas->Apply(player); }
        }

        void Remove(Player* player) override
        {
            if (_sousHaut) _sousHaut->Remove(player);
            if (_sousBas)  _sousBas->Remove(player);
            Effacer(player);
        }

        [[nodiscard]] bool OwnsAura() const override
        {
            return (_sousHaut && _sousHaut->OwnsAura()) || (_sousBas && _sousBas->OwnsAura());
        }

        [[nodiscard]] uint32 Watches() const override
        {
            uint32 masque = 0;
            if (_sousHaut) masque |= _sousHaut->Watches();
            if (_sousBas)  masque |= _sousBas->Watches();
            return masque;
        }

        // LE MARQUEUR DE L'ETAT COURANT, et lui seul : une ligne qui ne tient
        // pas ne doit pas repondre au systeme de procs du coeur.
        [[nodiscard]] uint32 Trigger() const override
        {
            StellarTarotScript const* s = _haute ? _sousHaut.get() : _sousBas.get();
            return s ? s->Trigger() : 0;
        }

        void OnLeaveCombat(Player* player) override
        {
            if (!_nuit)
                Effacer(player);
            if (StellarTarotScript* s = Courant())
                s->OnLeaveCombat(player);
        }

        void OnTick(Player* player) override
        {
            if (!player)
                return;
            Battre(player);
            if (_sousHaut) _sousHaut->OnTick(player);
            if (_sousBas)  _sousBas->OnTick(player);
        }

        bool Promise(std::string& event, int32& chance, int32& icd, bool& coreChance, bool& coreIcd) const override { StellarTarotScript const* s = Courant(); return s && s->Promise(event, chance, icd, coreChance, coreIcd); }
        void OnCreatureKill(Player* player, Creature* killed) override { if (StellarTarotScript* s = Courant()) s->OnCreatureKill(player, killed); }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 school, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnDamageDealt(player, victim, damage, spell, school, spellId); }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool spell, uint32 school, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnDamageTaken(player, attacker, damage, spell, school, spellId); }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override { if (StellarTarotScript* s = Courant()) s->OnHealDone(player, target, gain); }
        void OnSpellCast(Player* player, Spell* spell) override { if (StellarTarotScript* s = Courant()) s->OnSpellCast(player, spell); }
        void OnTriggerProc(Player* player, Unit* other, uint32 amount) override { if (StellarTarotScript* s = Courant()) s->OnTriggerProc(player, other, amount); }
        void OnCalcAuraDuration(Player* player, Aura const* aura, int32& duration) override { if (StellarTarotScript* s = Courant()) s->OnCalcAuraDuration(player, aura, duration); }
        void OnPromiseSpent(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnPromiseSpent(player); }
        void OnEnterCombat(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnEnterCombat(player); }
        void OnLevelUp(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnLevelUp(player); }
        void OnDeath(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnDeath(player); }
        void OnNearbyDeath(Player* player, Unit* died) override { if (StellarTarotScript* s = Courant()) s->OnNearbyDeath(player, died); }
        void OnJump(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnJump(player); }
        void OnResurrect(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnResurrect(player); }
        void OnZone(Player* player, uint32 zone, uint32 area) override { if (StellarTarotScript* s = Courant()) s->OnZone(player, zone, area); }
        void OnMapChanged(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnMapChanged(player); }
        void OnQuestComplete(Player* player, Quest const* quest) override { if (StellarTarotScript* s = Courant()) s->OnQuestComplete(player, quest); }
        void OnLootMoney(Player* player, uint32& copper) override { if (StellarTarotScript* s = Courant()) s->OnLootMoney(player, copper); }
        void OnGiveXP(Player* player, uint32& amount, uint8 source) override { if (StellarTarotScript* s = Courant()) s->OnGiveXP(player, amount, source); }
        void OnGiveReputation(Player* player, float& amount, uint8 source) override { if (StellarTarotScript* s = Courant()) s->OnGiveReputation(player, amount, source); }
        void OnRepairDiscount(Player* player, ObjectGuid itemGuid, float& discountMod) override { if (StellarTarotScript* s = Courant()) s->OnRepairDiscount(player, itemGuid, discountMod); }
        void OnVendorDiscount(Player const* player, float& discount) override { if (StellarTarotScript* s = Courant()) s->OnVendorDiscount(player, discount); }
        void OnMoneyChanged(Player* player, int32& amount) override { if (StellarTarotScript* s = Courant()) s->OnMoneyChanged(player, amount); }
        void OnSellItem(Player* player, Item* item) override { if (StellarTarotScript* s = Courant()) s->OnSellItem(player, item); }
        void OnCreatureLoot(Player* player, Loot* loot) override { if (StellarTarotScript* s = Courant()) s->OnCreatureLoot(player, loot); }
        void OnProspect(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnProspect(player, loot, tab, store); }
        void OnSpend(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnSpend(player); }
        void OnAuctionPosted(Player* player, uint32 deposit) override { if (StellarTarotScript* s = Courant()) s->OnAuctionPosted(player, deposit); }
        void OnAuctionSold(Player* player, uint32& profit) override { if (StellarTarotScript* s = Courant()) s->OnAuctionSold(player, profit); }
        void OnAuctionWon(Player* player, uint32 price) override { if (StellarTarotScript* s = Courant()) s->OnAuctionWon(player, price); }
        void OnFacing(Player* player, float x, float y, float orientation, uint32 moveFlags) override { if (StellarTarotScript* s = Courant()) s->OnFacing(player, x, y, orientation, moveFlags); }
        void OnPetDamage(Player* player, Unit* victim, uint32& damage) override { if (StellarTarotScript* s = Courant()) s->OnPetDamage(player, victim, damage); }
        void OnFishing(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnFishing(player, loot, tab, store); }
        void OnSkinning(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnSkinning(player, loot, tab, store); }
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnObjectLoot(player, loot, tab, store); }
        void OnItemRoll(Player const* player, uint32 itemId, float& chance) override { if (StellarTarotScript* s = Courant()) s->OnItemRoll(player, itemId, chance); }
        void OnVendorBuy(Player* player, Item* item, uint32 count, uint32 paid) override { if (StellarTarotScript* s = Courant()) s->OnVendorBuy(player, item, count, paid); }
        void OnAuraRemoved(Player* player, Aura const* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraRemoved(player, aura); }
        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraApplied(player, target, aura); }
        void OnAuraTaken(Player* player, Unit* caster, Aura* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraTaken(player, caster, aura); }
        void OnPeriodicTick(Player* player, Unit* other, uint32& amount, bool heal, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnPeriodicTick(player, other, amount, heal, spellId); }
        void OnPeriodicTaken(Player* player, Unit* attacker, uint32& amount, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnPeriodicTaken(player, attacker, amount, spellId); }
        bool DitSonEtat(Player* player, Unit* cible, std::string& out) override { StellarTarotScript* s = Courant(); return s && s->DitSonEtat(player, cible, out); }

    private:
        // LE SOUS-SCRIPT DE L'ETAT COURANT, ou rien.
        StellarTarotScript* Courant()
        {
            return _haute ? _sousHaut.get() : _sousBas.get();
        }
        StellarTarotScript const* Courant() const
        {
            return _haute ? _sousHaut.get() : _sousBas.get();
        }

        // L'HORLOGE DE LA CARTE, mise a l'heure par le premier qui la lit.
        void Battre(Player* player)
        {
            // LA NUIT N'A PAS DE CADENCE : c'est le monde qui tranche.
            if (_nuit)
            {
                Poser(player, IsNight());
                return;
            }
            if (!player->IsInCombat())
            {
                Effacer(player);
                return;
            }
            uint32 const now = uint32(GameTime::GetGameTime().count());
            Horloge& h = Horloges()[{ player->GetGUID().GetCounter(), _groupe }];
            if (!h.depuis)
            {
                h.depuis = now;
                h.haute = true;
            }
            else
                h.haute = ((now - h.depuis) / uint32(_sec)) % 2 == 0;
            // L'ECLIPSE : les deux etats a la fois, et deux fois plus forts.
            if (_eclipseChaque)
            {
                if (!h.eclipseDepuis || now - h.eclipseDepuis >= uint32(_eclipseChaque))
                {
                    h.eclipseDepuis = now;
                    h.eclipseJusqua = now + uint32(_eclipseDuree);
                }
                if (now < h.eclipseJusqua)
                {
                    PoserLesDeux(player);
                    return;
                }
            }
            bool const change = h.haute != _haute || !_pose;
            Poser(player, h.haute);
            if (!change || !_pose)
                return;
            if (_mana)
                Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _mana), SpellId());
            if (_heal)
                Heal(player, player, PctOf(player->GetMaxHealth(), _heal), SpellId());
        }

        void Poser(Player* player, bool haute)
        {
            uint32 const veut = uint32(haute ? _haut : _bas);
            uint32 const autre = uint32(haute ? _bas : _haut);
            if (autre)
                player->RemoveAurasDueToSpell(autre);
            if (veut && !player->HasAura(veut))
                player->AddAura(veut, player);
            _haute = haute;
            _pose = true;
        }

        // L'ECLIPSE : les deux auras ensemble, a deux cumuls -- « les deux
        // bonus s'appliquent et sont doubles ».
        void PoserLesDeux(Player* player)
        {
            for (uint32 sort : { uint32(_haut), uint32(_bas) })
            {
                if (!sort)
                    continue;
                Aura* aura = player->GetAura(sort, player->GetGUID());
                if (!aura)
                    aura = player->AddAura(sort, player);
                if (aura && aura->GetStackAmount() < 2)
                    aura->SetStackAmount(2);
            }
            _pose = true;
        }

        void Effacer(Player* player)
        {
            if (!player)
                return;
            if (_haut) player->RemoveAurasDueToSpell(uint32(_haut));
            if (_bas)  player->RemoveAurasDueToSpell(uint32(_bas));
            Horloges().erase({ player->GetGUID().GetCounter(), _groupe });
            _haute = true;
            _pose = false;
        }

        int32 _sec = 0, _groupe = 0, _haut = 0, _bas = 0, _mana = 0, _heal = 0;
        int32 _eclipseChaque = 0, _eclipseDuree = 0;
        bool _nuit = false;
        bool _haute = true;
        bool _pose = false;
        std::unique_ptr<StellarTarotScript> _sousHaut, _sousBas;
    };

    // =========================================================================
    // LE META-EFFET D'UNE CARTE QUI S'ACHARNE
    //
    // focus:<groupe>:<max>:<sort>[:perstack][:from:<seuil>][:rating:<pct>]
    //       [:others:<pct>][:stun:<sec>][:high:<sous-script>]
    //
    //     UNE CARTE, UNE CIBLE, UN COMPTE. Frapper deux fois de suite le meme
    //     adversaire fait monter le compte ; en changer le remet a zero. Le
    //     compte appartient a la CARTE -- tous ses niveaux portent le meme
    //     `groupe`, son numero -- et chacun ne dit que ce qu'il en tire :
    //       <sort>          l'aura que ce niveau pose tant que la cible tient
    //                       (0 quand il n'en pose pas)
    //       perstack        ses cumuls suivent le compte ; sinon elle reste a un
    //       from:<seuil>    elle n'est posee qu'a partir de ce compte
    //       rating:<pct>    son chiffre est une PART du score que l'aura nomme,
    //                       relue a la pose -- le DBC ne la porte pas
    //       others:<pct>    ce que le joueur inflige AUX AUTRES cibles est
    //                       modifie d'autant, tant que le compte tient
    //       stun:<sec>      changer de cible etourdit le joueur
    //       high:<sous>     un sous-script entier, actif a partir du seuil
    // =========================================================================

    // LA CIBLE ET LE COMPTE D'UNE CARTE, par joueur.
    struct Acharnement
    {
        ObjectGuid cible;
        int32 cumuls = 0;
    };

    std::map<std::pair<uint32, int32>, Acharnement>& Acharnements()
    {
        static std::map<std::pair<uint32, int32>, Acharnement> tout;
        return tout;
    }

    class Focus : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 1000, _groupe) || !r.Int(1, 100, _max))
                return (error = "focus expects the card and the ceiling", false);
            // `self` : l'aura du niveau lui-meme -- le cas ordinaire. Un chiffre
            // nomme un autre sort ; 0, aucun.
            if (r.Peek() == "self")
            {
                r.Word();
                _sien = true;
            }
            else if (!r.Int(0, 903999, _sort))
                return (error = "focus expects self, a spell, or 0", false);
            while (!r.End())
            {
                std::string const mot = r.Word();
                if (mot == "perstack") { _parCumul = true; continue; }
                if (mot == "from" && r.Int(1, 100, _seuil)) continue;
                if (mot == "rating" && r.Int(-1000, 1000, _rating)) continue;
                if (mot == "others" && r.Int(-1000, 1000, _autres)) continue;
                if (mot == "stun" && r.Int(1, 60, _stun)) continue;
                if (mot == "high")
                {
                    StellarTarotScriptSpec sous;
                    bool premier = true;
                    while (!r.End())
                    {
                        std::string const part = r.Word();
                        if (premier) sous.name = part;
                        else sous.params.push_back(part);
                        premier = false;
                    }
                    if (sous.name.empty())
                        return (error = "high expects a script", false);
                    sous.text = sous.name;
                    std::string pourquoi;
                    _sous = StellarTarotScripts::Create(sous, pourquoi);
                    if (!_sous)
                        return (error = "high: " + pourquoi, false);
                    continue;
                }
                return (error = "focus: unknown word \"" + mot + "\"", false);
            }
            return true;
        }

        [[nodiscard]] bool OwnsAura() const override { return true; }

        [[nodiscard]] uint32 Watches() const override { return _sous ? _sous->Watches() : 0u; }

        [[nodiscard]] uint32 Trigger() const override
        {
            return (_sous && _atteint) ? _sous->Trigger() : 0u;
        }

        void Apply(Player* player) override
        {
            if (_sous) { _sous->SetSpell(SpellId()); _sous->Apply(player); }
        }

        void Remove(Player* player) override
        {
            if (_sous) _sous->Remove(player);
            if (Sort()) RemoveOwned(player, Sort());
            if (player)
                Acharnements().erase({ player->GetGUID().GetCounter(), _groupe });
            _atteint = false;
        }

        // LE COUP QUI COMPTE : la cible d'avant, ou une autre. C'est ici que le
        // compte monte, retombe, et que le prix du changement se paie.
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell,
                           uint32 school, uint32 spellId) override
        {
            if (!player || !victim || !victim->IsAlive())
                return;
            Acharnement& a = Acharnements()[{ player->GetGUID().GetCounter(), _groupe }];
            ObjectGuid const qui = victim->GetGUID();
            bool const change = a.cible && a.cible != qui;
            // CE QUE LE JOUEUR INFLIGE AUX AUTRES, tant que le compte tient.
            if (_autres && change && a.cumuls >= std::max(1, _seuil))
                damage = uint32(std::max<int64>(0, std::llround(double(damage) * (100 + _autres) / 100.0)));
            if (change)
            {
                a.cumuls = 0;
                if (_stun)
                    Put(player, player, STELLAR_TAROT_SPELL_STUN, _stun);
            }
            if (a.cible != qui)
                a.cumuls = 0;
            a.cible = qui;
            if (a.cumuls < _max)
                ++a.cumuls;
            Poser(player, a.cumuls);
            if (_sous && _atteint)
                _sous->OnDamageDealt(player, victim, damage, spell, school, spellId);
        }

        // UNE CIBLE MORTE N'EST PLUS UNE CIBLE : le compte tombe avec elle.
        void OnCreatureKill(Player* player, Creature* killed) override
        {
            if (player && killed)
            {
                Acharnement& a = Acharnements()[{ player->GetGUID().GetCounter(), _groupe }];
                if (a.cible == killed->GetGUID())
                {
                    a.cible.Clear();
                    a.cumuls = 0;
                    Poser(player, 0);
                }
            }
            if (_sous && _atteint)
                _sous->OnCreatureKill(player, killed);
        }

        bool Promise(std::string& event, int32& chance, int32& icd, bool& coreChance, bool& coreIcd) const override { StellarTarotScript const* s = Courant(); return s && s->Promise(event, chance, icd, coreChance, coreIcd); }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool spell, uint32 school, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnDamageTaken(player, attacker, damage, spell, school, spellId); }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override { if (StellarTarotScript* s = Courant()) s->OnHealDone(player, target, gain); }
        void OnSpellCast(Player* player, Spell* spell) override { if (StellarTarotScript* s = Courant()) s->OnSpellCast(player, spell); }
        void OnTriggerProc(Player* player, Unit* other, uint32 amount) override { if (StellarTarotScript* s = Courant()) s->OnTriggerProc(player, other, amount); }
        void OnCalcAuraDuration(Player* player, Aura const* aura, int32& duration) override { if (StellarTarotScript* s = Courant()) s->OnCalcAuraDuration(player, aura, duration); }
        void OnPromiseSpent(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnPromiseSpent(player); }
        void OnEnterCombat(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnEnterCombat(player); }
        void OnLevelUp(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnLevelUp(player); }
        void OnDeath(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnDeath(player); }
        void OnNearbyDeath(Player* player, Unit* died) override { if (StellarTarotScript* s = Courant()) s->OnNearbyDeath(player, died); }
        void OnJump(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnJump(player); }
        void OnResurrect(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnResurrect(player); }
        void OnZone(Player* player, uint32 zone, uint32 area) override { if (StellarTarotScript* s = Courant()) s->OnZone(player, zone, area); }
        void OnMapChanged(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnMapChanged(player); }
        void OnQuestComplete(Player* player, Quest const* quest) override { if (StellarTarotScript* s = Courant()) s->OnQuestComplete(player, quest); }
        void OnLootMoney(Player* player, uint32& copper) override { if (StellarTarotScript* s = Courant()) s->OnLootMoney(player, copper); }
        void OnGiveXP(Player* player, uint32& amount, uint8 source) override { if (StellarTarotScript* s = Courant()) s->OnGiveXP(player, amount, source); }
        void OnGiveReputation(Player* player, float& amount, uint8 source) override { if (StellarTarotScript* s = Courant()) s->OnGiveReputation(player, amount, source); }
        void OnRepairDiscount(Player* player, ObjectGuid itemGuid, float& discountMod) override { if (StellarTarotScript* s = Courant()) s->OnRepairDiscount(player, itemGuid, discountMod); }
        void OnVendorDiscount(Player const* player, float& discount) override { if (StellarTarotScript* s = Courant()) s->OnVendorDiscount(player, discount); }
        void OnMoneyChanged(Player* player, int32& amount) override { if (StellarTarotScript* s = Courant()) s->OnMoneyChanged(player, amount); }
        void OnSellItem(Player* player, Item* item) override { if (StellarTarotScript* s = Courant()) s->OnSellItem(player, item); }
        void OnCreatureLoot(Player* player, Loot* loot) override { if (StellarTarotScript* s = Courant()) s->OnCreatureLoot(player, loot); }
        void OnProspect(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnProspect(player, loot, tab, store); }
        void OnSpend(Player* player) override { if (StellarTarotScript* s = Courant()) s->OnSpend(player); }
        void OnAuctionPosted(Player* player, uint32 deposit) override { if (StellarTarotScript* s = Courant()) s->OnAuctionPosted(player, deposit); }
        void OnAuctionSold(Player* player, uint32& profit) override { if (StellarTarotScript* s = Courant()) s->OnAuctionSold(player, profit); }
        void OnAuctionWon(Player* player, uint32 price) override { if (StellarTarotScript* s = Courant()) s->OnAuctionWon(player, price); }
        void OnFacing(Player* player, float x, float y, float orientation, uint32 moveFlags) override { if (StellarTarotScript* s = Courant()) s->OnFacing(player, x, y, orientation, moveFlags); }
        void OnPetDamage(Player* player, Unit* victim, uint32& damage) override { if (StellarTarotScript* s = Courant()) s->OnPetDamage(player, victim, damage); }
        void OnFishing(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnFishing(player, loot, tab, store); }
        void OnSkinning(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnSkinning(player, loot, tab, store); }
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override { if (StellarTarotScript* s = Courant()) s->OnObjectLoot(player, loot, tab, store); }
        void OnItemRoll(Player const* player, uint32 itemId, float& chance) override { if (StellarTarotScript* s = Courant()) s->OnItemRoll(player, itemId, chance); }
        void OnVendorBuy(Player* player, Item* item, uint32 count, uint32 paid) override { if (StellarTarotScript* s = Courant()) s->OnVendorBuy(player, item, count, paid); }
        void OnAuraRemoved(Player* player, Aura const* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraRemoved(player, aura); }
        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraApplied(player, target, aura); }
        void OnAuraTaken(Player* player, Unit* caster, Aura* aura) override { if (StellarTarotScript* s = Courant()) s->OnAuraTaken(player, caster, aura); }
        void OnPeriodicTick(Player* player, Unit* other, uint32& amount, bool heal, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnPeriodicTick(player, other, amount, heal, spellId); }
        void OnPeriodicTaken(Player* player, Unit* attacker, uint32& amount, uint32 spellId) override { if (StellarTarotScript* s = Courant()) s->OnPeriodicTaken(player, attacker, amount, spellId); }
        bool DitSonEtat(Player* player, Unit* cible, std::string& out) override { StellarTarotScript* s = Courant(); return s && s->DitSonEtat(player, cible, out); }

    private:
        StellarTarotScript* Courant() { return _atteint ? _sous.get() : nullptr; }
        StellarTarotScript const* Courant() const { return _atteint ? _sous.get() : nullptr; }

        void Poser(Player* player, int32 cumuls)
        {
            _atteint = cumuls >= std::max(1, _seuil);
            uint32 const sort = Sort();
            if (!sort)
                return;
            if (!_atteint)
            {
                RemoveOwned(player, sort);
                return;
            }
            int32 const veut = _parCumul ? cumuls : 1;
            // UNE PART DU SCORE : le DBC ne la porte pas, le module l'y met.
            if (_rating)
            {
                LayRatingShare(player, sort, { _rating }, 0, veut);
                return;
            }
            Aura* aura = player->GetAura(sort, player->GetGUID());
            if (!aura)
                aura = player->AddAura(sort, player);
            if (aura && int32(aura->GetStackAmount()) != veut)
                aura->SetStackAmount(uint8(std::max(1, veut)));
        }

        // L'AURA DU NIVEAU : `_sien` la designe, et `Sort()` la rend.
        [[nodiscard]] uint32 Sort() const { return _sien ? SpellId() : uint32(_sort); }

        int32 _groupe = 0, _max = 1, _sort = 0, _seuil = 1, _rating = 0, _autres = 0, _stun = 0;
        bool _sien = false;
        bool _parCumul = false;
        bool _atteint = false;
        std::unique_ptr<StellarTarotScript> _sous;
    };

    // =========================================================================
    // L'OBJET QU'UNE CARTE DONNE, ET LA VOIE QU'ON CHOISIT
    //
    // cardtool:<groupe>:<objet>:<A1>:<A2>:<A3>[:gives][:stacks:<n>][:onchange:<sec>]
    //
    //     LA CARTE MET UN JETON DANS LES SACS ; s'en servir change de voie, et
    //     la voie tourne : premiere, deuxieme, troisieme, puis de nouveau la
    //     premiere. La voie appartient a la CARTE -- tous ses niveaux portent
    //     le meme `groupe` -- et chacun ne dit que ce qu'il en tire :
    //       <A1> <A2> <A3>  l'aura de ce niveau pour chaque voie (0 : aucune)
    //       gives           CE niveau donne le jeton et fait tourner la voie ;
    //                       les autres ne font que suivre
    //       stacks:<n>      la voie choisie est posee a n cumuls -- c'est ainsi
    //                       qu'un niveau « double » le chiffre d'un autre
    //       onchange:<sec>  a chaque changement de voie, l'aura du NIVEAU est
    //                       posee pour ce temps-la
    // =========================================================================

    // LA VOIE D'UNE CARTE, par joueur : laquelle, a combien de cumuls, et le
    // compteur de changements -- c'est lui que les autres niveaux guettent.
    struct Voie
    {
        int32 laquelle = 0;         // 0, 1 ou 2
        int32 cumuls = 1;
        uint32 tour = 0;            // avance a chaque changement
    };

    std::map<std::pair<uint32, int32>, Voie>& Voies()
    {
        static std::map<std::pair<uint32, int32>, Voie> toutes;
        return toutes;
    }

    class CardTool : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 1000, _groupe) || !r.Int(0, 902999, _objet))
                return (error = "cardtool expects the card and its item", false);
            for (int32& sort : _voies)
                if (!r.Int(0, 903999, sort))
                    return (error = "cardtool expects three spells (0 for none)", false);
            while (!r.End())
            {
                std::string const mot = r.Word();
                if (mot == "gives") { _donne = true; continue; }
                // `on_use:<sous-script>` : CE QUE L'USAGE DU JETON DECLENCHE.
                // Tout ce qui suit appartient au sous-script -- une ligne
                // entiere du moteur, avec sa chance, sa recharge et son prix.
                if (mot == "on_use")
                {
                    StellarTarotScriptSpec sous;
                    bool premier = true;
                    while (!r.End())
                    {
                        std::string const part = r.Word();
                        if (premier) sous.name = part;
                        else sous.params.push_back(part);
                        premier = false;
                    }
                    if (sous.name.empty())
                        return (error = "on_use expects a script", false);
                    sous.text = sous.name;
                    std::string pourquoi;
                    _usage = StellarTarotScripts::Create(sous, pourquoi);
                    if (!_usage)
                        return (error = "on_use: " + pourquoi, false);
                    continue;
                }
                if (mot == "stacks" && r.Int(1, 10, _cumuls)) continue;
                if (mot == "onchange" && r.Int(1, 3600, _surChangement)) continue;
                return (error = "cardtool: unknown word \"" + mot + "\"", false);
            }
            return true;
        }

        [[nodiscard]] bool OwnsAura() const override { return true; }

        [[nodiscard]] uint32 Watches() const override { return _usage ? _usage->Watches() : 0u; }

        void Apply(Player* player) override
        {
            if (!player)
                return;
            if (_usage) { _usage->SetSpell(SpellId()); _usage->Apply(player); }
            Voie& v = Voies()[{ player->GetGUID().GetCounter(), _groupe }];
            v.cumuls = std::max(v.cumuls, _cumuls);
            if (_donne && _objet && !player->HasItemCount(uint32(_objet), 1, true))
            {
                ItemPosCountVec ou;
                if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, ou, uint32(_objet), 1) == EQUIP_ERR_OK)
                    if (Item* jeton = player->StoreNewItem(ou, uint32(_objet), true))
                        player->SendNewItem(jeton, 1, true, false);
            }
            _vu = v.tour;
            Poser(player, v);
        }

        void Remove(Player* player) override
        {
            if (!player)
                return;
            if (_usage)
                _usage->Remove(player);
            for (int32 sort : _voies)
                if (sort)
                    RemoveOwned(player, uint32(sort));
            if (_surChangement)
                RemoveOwned(player, SpellId());
            if (_donne)
            {
                if (_objet)
                    player->DestroyItemCount(uint32(_objet), 1, true);
                Voies().erase({ player->GetGUID().GetCounter(), _groupe });
            }
        }

        // LE JETON QU'ON EMPLOIE : c'est le niveau qui l'a donne qui fait
        // tourner la voie ; les autres la lisent.
        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (!player || !_objet)
                return;
            ItemTemplate const* const quoi = CastItemOf(spell);
            if (!quoi || quoi->ItemId != uint32(_objet))
                return;
            // CE QUE L'USAGE DECLENCHE : la ligne du sous-script joue, avec sa
            // chance, sa recharge et son prix -- le conteneur ne fait que lui
            // dire que le moment est venu.
            if (_usage)
                _usage->OnTriggerProc(player, player->GetVictim(), 0);
            Voie& v = Voies()[{ player->GetGUID().GetCounter(), _groupe }];
            // UNE VOIE A SUIVRE : seulement si la carte en a une. Un jeton qui
            // ne fait qu'agir n'a pas de voie a tourner.
            bool const aUneVoie = _voies[0] || _voies[1] || _voies[2];
            if (_donne && aUneVoie)
            {
                // HORS COMBAT SEULEMENT : le texte de la carte le dit.
                if (player->IsInCombat())
                    return;
                v.laquelle = (v.laquelle + 1) % 3;
                ++v.tour;
            }
            Suivre(player, v);
        }

        void OnTick(Player* player) override
        {
            if (!player)
                return;
            Suivre(player, Voies()[{ player->GetGUID().GetCounter(), _groupe }]);
        }

    private:
        // LA VOIE A TOURNE : ce niveau repose la sienne, et paie ce qu'il doit
        // au changement.
        void Suivre(Player* player, Voie& v)
        {
            if (v.tour == _vu)
                return;
            _vu = v.tour;
            Poser(player, v);
            if (_surChangement && SpellId())
            {
                RemoveOwned(player, SpellId());
                if (Aura* aura = player->AddAura(SpellId(), player))
                {
                    aura->SetMaxDuration(_surChangement * 1000);
                    aura->SetDuration(_surChangement * 1000);
                }
            }
        }

        void Poser(Player* player, Voie const& v)
        {
            for (int32 i = 0; i < 3; ++i)
            {
                if (!_voies[i])
                    continue;
                if (i != v.laquelle)
                {
                    RemoveOwned(player, uint32(_voies[i]));
                    continue;
                }
                Aura* aura = player->GetAura(uint32(_voies[i]), player->GetGUID());
                if (!aura)
                    aura = player->AddAura(uint32(_voies[i]), player);
                if (aura && int32(aura->GetStackAmount()) != v.cumuls)
                    aura->SetStackAmount(uint8(std::max(1, v.cumuls)));
            }
        }

        int32 _groupe = 0, _objet = 0, _cumuls = 1, _surChangement = 0;
        int32 _voies[3] = { 0, 0, 0 };
        bool _donne = false;
        uint32 _vu = 0;
        std::unique_ptr<StellarTarotScript> _usage;   // ce que l'usage declenche
    };

    // =========================================================================
    // stacklong:<sec>:<sort>[:<sort>...]
    //     LES CUMULS DURENT PLUS LONGTEMPS. Un niveau superieur ne POSE rien :
    //     il rallonge ce qu'un niveau inferieur a pose -- et une duree ne
    //     s'additionne pas, elle se REMPLACE. Le coeur demande au module la
    //     duree maximale de chaque aura qu'il calcule (OnCalcAuraDuration) :
    //     la ligne repond pour les sorts qu'elle nomme, et pour eux seuls.
    // =========================================================================
    class StackLonger : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 3600, _sec))
                return (error = "stacklong expects the seconds", false);
            while (!r.End())
            {
                int32 sort = 0;
                if (!r.Int(902000, 903999, sort))
                    return (error = "after the seconds, only spells of the module", false);
                _sorts.push_back(uint32(sort));
            }
            return !_sorts.empty() || (error = "stacklong expects at least one spell", false);
        }

        void OnCalcAuraDuration(Player* /*player*/, Aura const* aura, int32& duration) override
        {
            if (!aura)
                return;
            for (uint32 sort : _sorts)
                if (aura->GetId() == sort)
                {
                    duration = _sec * 1000;
                    return;
                }
        }

    private:
        int32 _sec = 0;
        std::vector<uint32> _sorts;
    };

    // =========================================================================
    // healmod:<soi>:<autres>
    //     LE SOIN, SELON QUI LE DONNE. Aucune aura du coeur ne fait cette
    //     difference : MOD_HEALING_DONE suit le soigneur, MOD_HEALING_RECEIVED
    //     ne regarde pas qui soigne. La ligne lit donc les deux montants la ou
    //     ils tombent -- celui que le joueur se rend a lui-meme, et celui que
    //     les AUTRES lui rendent.
    //       <soi>    ce que le joueur se rend, modifie d'autant
    //       <autres> ce que les autres lui rendent, modifie d'autant
    //                (-100 : ils ne peuvent plus le soigner du tout)
    // =========================================================================
    class HealMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(-100, 1000, _soi) || !r.Int(-100, 1000, _autres))
                return (error = "healmod expects both percentages", false);
            return r.End() || (error = "too many parameters", false);
        }

        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            if (!_soi || !gain || target != player)
                return;
            gain = uint32(std::max<int64>(0, std::llround(double(gain) * (100 + _soi) / 100.0)));
        }

        void OnHealTaken(Player* player, Unit* healer, uint32& gain) override
        {
            if (!_autres || !gain || !healer || healer == player)
                return;
            gain = uint32(std::max<int64>(0, std::llround(double(gain) * (100 + _autres) / 100.0)));
        }

    private:
        int32 _soi = 0, _autres = 0;
    };

    // =========================================================================
    // hitroll:<quoi>[:only:<etat>[:<n>]]
    //     CE QUE LE DE DU COUP BLANC NE PEUT PLUS DONNER. Le coeur demande au
    //     module les cinq chances avant de jeter le de
    //     (`OnBeforeRollMeleeOutcomeAgainst`) : c'est le seul endroit ou une
    //     carte peut fermer une issue. Aucune aura ne le sait dire -- l'aura
    //     248 ne touche que l'esquive, et les attributs de sort sont statiques
    //     et partages par tous ceux qui les lancent.
    //       noblock   vos attaques ne peuvent plus etre bloquees
    //       nododge   vous n'esquivez plus
    //       noparry   vous ne parez plus
    //       firstmiss la PREMIERE attaque d'un ennemi donne vous rate
    //     `only:<etat>` : seulement tant que cet etat tient.
    // =========================================================================
    class HitRoll : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _quoi = r.Word();
            static char const* const mots[] = { "noblock", "nododge", "noparry", "firstmiss" };
            bool connu = false;
            for (char const* m : mots)
                if (_quoi == m) connu = true;
            if (!connu)
                return (error = "unknown hitroll " + _quoi, false);
            if (!r.End())
            {
                if (r.Word() != "only")
                    return (error = "after the word, only only:<state> may follow", false);
                _etat = r.Word();
                r.OptInt(1, 3600, _etatN);
            }
            return r.End() || (error = "too many parameters", false);
        }

        void Remove(Player* /*player*/) override { _deja.clear(); }

        void OnMeleeRoll(Player* player, Unit* autre, bool mien, int32& /*crit*/, int32& miss,
                         int32& dodge, int32& parry, int32& block) override
        {
            if (!player)
                return;
            if (!_etat.empty() && !EtatTenu(_etat, _etatN, 0, player, player, nullptr))
                return;
            // `noblock` parle des coups QUE LE JOUEUR PORTE ; les trois autres
            // de ceux QU'IL SUBIT.
            if (_quoi == "noblock")
            {
                if (mien)
                    block = 0;
                return;
            }
            if (mien)
                return;
            if (_quoi == "nododge")
                dodge = 0;
            else if (_quoi == "noparry")
                parry = 0;
            // LA PREMIERE ATTAQUE D'UN ENNEMI DONNE, et elle seule : on retient
            // ceux qui ont deja frappe. La liste meurt avec la ligne.
            else if (_quoi == "firstmiss" && autre)
            {
                if (_deja.insert(autre->GetGUID()).second)
                    miss = 10000;
            }
        }

    private:
        std::string _quoi, _etat;
        int32 _etatN = 0;
        std::set<ObjectGuid> _deja;
    };

    // =========================================================================
    // pertag:<tag>:<pour_mille>[:linked][:tick:<sec>:<quoi>]
    //     PAR CARTE D'UN TAG POSEE SUR LE PLATEAU. Le chiffre est en POUR
    //     MILLE : le classeur dit « +0,5% », qui ne tient pas dans un entier.
    //       <tag>     le numero du tag (Physical, Magic, Wealth, ...)
    //       linked    on ne compte que les cartes RACCORDEES -- celles dont au
    //                 moins un bord s'accorde a une voisine
    //       tick:<sec>:<quoi>  au lieu d'une aura, un versement periodique :
    //                 `mana` ou `heal`, cette part par carte comptee
    //     Sans `tick`, l'aura du niveau est posee a autant de cumuls que de
    //     cartes comptees ; son chiffre est celui du DBC, par cumul.
    // =========================================================================
    class PerTag : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _tag) || !r.Int(1, 10000, _pourMille))
                return (error = "pertag expects the tag then the per-mille figure", false);
            while (!r.End())
            {
                std::string const mot = r.Word();
                if (mot == "linked") { _raccordees = true; continue; }
                // `sp` : le chiffre est une part de la PUISSANCE DES SORTS du
                // joueur, que le DBC ne peut pas porter -- le module l'y met,
                // et il la relit a chaque battement.
                if (mot == "sp") { _sp = true; continue; }
                if (mot == "tick" && r.Int(1, 3600, _cadence))
                {
                    _quoi = r.Word();
                    if (_quoi != "mana" && _quoi != "heal")
                        return (error = "tick expects mana or heal", false);
                    continue;
                }
                return (error = "pertag: unknown word \"" + mot + "\"", false);
            }
            return true;
        }

        [[nodiscard]] bool OwnsAura() const override { return true; }

        void Apply(Player* player) override { Regler(player); }
        void Remove(Player* player) override { RemoveOwned(player, SpellId()); _compte = 0; }
        void OnTick(Player* player) override
        {
            Regler(player);
            if (!_cadence || !_compte)
                return;
            // EN COMBAT SEULEMENT, comme le dit la carte, et au rythme donne.
            if (!player->IsInCombat())
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_dernier && now - _dernier < uint32(_cadence))
                return;
            _dernier = now;
            uint32 const total = uint32(_pourMille) * uint32(_compte);
            if (_quoi == "mana")
                Energize(player, player, PourMille(player->GetMaxPower(POWER_MANA), total), SpellId());
            else
                Heal(player, player, PourMille(player->GetMaxHealth(), total), SpellId());
        }

    private:
        static uint32 PourMille(uint32 total, uint32 part)
        {
            return uint32(std::llround(double(total) * part / 1000.0));
        }

        // CE QUE LE PLATEAU PORTE : les cartes du tag, posees, et raccordees
        // quand la ligne le demande.
        int32 Compter(Player* player) const
        {
            int32 combien = 0;
            StellarTarotLayout const layout = StellarTarotLayouts::Load(player);
            for (StellarTarotActivation const& a : StellarTarotLayouts::Activations(layout))
            {
                StellarTarotCard const* const carte = sStellarTarotMgr->Card(a.placement.cardId);
                if (!carte || int32(carte->tagId) != _tag)
                    continue;
                if (_raccordees)
                {
                    bool accordee = false;
                    for (bool bord : a.matched)
                        if (bord) accordee = true;
                    if (!accordee)
                        continue;
                }
                ++combien;
            }
            return combien;
        }

        void Regler(Player* player)
        {
            int32 const combien = Compter(player);
            // LA PUISSANCE DES SORTS BOUGE d'elle-meme : le compte des cartes
            // ne suffit pas a dire que rien n'a change.
            if (combien == _compte && !(_sp && !player->HasAura(SpellId())))
                return;
            _compte = combien;
            RemoveOwned(player, SpellId());
            // Un versement periodique ne pose aucune aura : le compte suffit.
            if (_cadence || !_compte)
                return;
            // UNE PART DE LA PUISSANCE DES SORTS : le chiffre entier est calcule
            // ici -- la part, multipliee par le nombre de cartes comptees -- et
            // l'aura le porte d'un seul tenant.
            if (_sp)
            {
                int32 const propre = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC));
                int32 const bp = int32(std::llround(double(propre) * _pourMille * _compte / 1000.0));
                if (bp <= 0)
                    return;
                player->CastCustomSpell(player, SpellId(), &bp, &bp, &bp, true);
                return;
            }
            if (Aura* aura = player->AddAura(SpellId(), player))
                if (_compte > 1)
                    aura->SetStackAmount(uint8(std::min(_compte, 100)));
        }

        int32 _tag = 0, _pourMille = 0, _cadence = 0, _compte = 0;
        bool _raccordees = false;
        bool _sp = false;
        std::string _quoi;
        uint32 _dernier = 0;
    };

    // =========================================================================
    // lockpick:<sort>
    //     LES SERRURES S'OUVRENT SANS CLE. Le module n'ouvre rien lui-meme :
    //     il APPREND au joueur un sort qui porte SPELL_EFFECT_OPEN_LOCK, et
    //     c'est le coeur qui fait le reste -- `Spell::CanOpenLock` le trouve
    //     dans les sorts connus, lit sa valeur et ouvre. Le sort est repris
    //     quand la carte s'en va.
    // =========================================================================
    class LockPick : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(902000, 903999, _sort) && r.End())
                || (error = "lockpick expects its spell", false);
        }
        void Apply(Player* player) override
        {
            if (player && !player->HasSpell(uint32(_sort)))
                player->learnSpell(uint32(_sort), false);
        }
        void Remove(Player* player) override
        {
            if (player && player->HasSpell(uint32(_sort)))
                player->removeSpell(uint32(_sort), SPEC_MASK_ALL, false);
        }

    private:
        int32 _sort = 0;
    };

    // =========================================================================
    // bridge:<pct>:<sec>:<chance>[:<sort>]
    //     LE PONT. Un soin porte a un allie peut le LIER au soigneur : tant que
    //     le lien tient, cette part de ce que l'allie encaisse passe sur le
    //     soigneur, et l'allie d'autant moins. Le coeur ne dit a personne ce
    //     qu'un autre subit : le module le porte aux veilleurs du groupe.
    // =========================================================================
    class Bridge : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _pct) || !r.Int(1, 3600, _sec) || !r.Int(1, 100, _chance))
                return (error = "bridge expects the share, the seconds and the chance", false);
            r.OptInt(902000, 903999, _marque);
            return r.End() || (error = "too many parameters", false);
        }

        [[nodiscard]] uint32 Watches() const override { return GUET_ALLIE_FRAPPE; }

        void Remove(Player* player) override { Delier(player); }

        // UN SOIN PORTE A UN ALLIE : la chance dit s'il est lie.
        void OnHealDone(Player* player, Unit* target, uint32& /*gain*/) override
        {
            if (!player || !target || target == player || !target->IsPlayer())
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            Delier(player);
            _lie = target->GetGUID();
            _jusqua = uint32(GameTime::GetGameTime().count()) + uint32(_sec);
            if (_marque)
                player->AddAura(uint32(_marque), target);
        }

        void OnTick(Player* player) override
        {
            if (_lie && uint32(GameTime::GetGameTime().count()) >= _jusqua)
                Delier(player);
        }

        // CE QUE L'ALLIE LIE ENCAISSE : la part dite passe sur le soigneur.
        void OnAllyDamaged(Player* player, Player* allie, uint32& damage) override
        {
            if (!_lie || !allie || allie->GetGUID() != _lie || !damage)
                return;
            uint32 const part = PctOf(damage, _pct);
            if (!part)
                return;
            damage -= part;
            Bleed(player, part, SpellId());
        }

    private:
        void Delier(Player* player)
        {
            if (_marque && _lie && player)
                if (Unit* qui = ObjectAccessor::GetUnit(*player, _lie))
                    qui->RemoveAurasDueToSpell(uint32(_marque));
            _lie.Clear();
            _jusqua = 0;
        }

        int32 _pct = 0, _sec = 0, _chance = 100, _marque = 0;
        ObjectGuid _lie;
        uint32 _jusqua = 0;
    };

    // =========================================================================
    // featherfall:<m>
    //     UNE CHUTE QUI S'ADOUCIT. Le coeur ne previent d'aucune chute avant
    //     l'atterrissage : la ligne guette la descente elle-meme et pose la
    //     descente lente du jeu des que le joueur est tombe d'assez haut.
    // =========================================================================
    class FeatherFall : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 200, _metres) && r.End())
                || (error = "featherfall expects the metres", false);
        }

        void Remove(Player* player) override
        {
            if (player)
                player->RemoveAurasDueToSpell(SLOW_FALL);
            _haut = 0.0f;
        }

        void OnTick(Player* player) override
        {
            if (!player)
                return;
            float const z = player->GetPositionZ();
            if (!player->IsFalling())
            {
                // Pose a terre : la descente lente n'a plus lieu d'etre.
                if (_haut != 0.0f)
                {
                    player->RemoveAurasDueToSpell(SLOW_FALL);
                    _haut = 0.0f;
                }
                return;
            }
            if (_haut == 0.0f)
            {
                _haut = z;
                return;
            }
            if (_haut - z >= float(_metres) && !player->HasAura(SLOW_FALL))
                player->AddAura(SLOW_FALL, player);
        }

    private:
        static constexpr uint32 SLOW_FALL = 130;    // « Descente lente », le sort du jeu
        int32 _metres = 0;
        float _haut = 0.0f;
    };

    // =========================================================================
    // targetres:<pct>
    //     IGNORER UNE PART DES RESISTANCES DE LA CIBLE. L'aura 168
    //     (MOD_TARGET_RESISTANCE) porte un nombre de points, non un
    //     pourcentage : le module lit la resistance de la cible du moment et
    //     ecrit la part demandee dans l'aura, a chaque battement. Sans cible,
    //     rien n'est ecrit -- il n'y a rien a ignorer.
    // =========================================================================
    class TargetRes : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 100, _pct) && r.End())
                || (error = "targetres expects the percentage", false);
        }
        [[nodiscard]] bool OwnsAura() const override { return true; }
        void Remove(Player* player) override { RemoveOwned(player, SpellId()); _pose = -1; }

        void OnTick(Player* player) override
        {
            Unit* const cible = player ? player->GetVictim() : nullptr;
            // LA RESISTANCE MAGIQUE DE LA CIBLE : le coeur les tient ecole par
            // ecole ; on prend la plus basse, celle qui vaut pour l'ombre comme
            // pour le feu, et l'on en ignore la part dite.
            int32 veut = 0;
            if (cible)
            {
                int32 plus_basse = -1;
                for (uint8 ecole = SPELL_SCHOOL_HOLY; ecole < MAX_SPELL_SCHOOL; ++ecole)
                {
                    int32 const r = cible->GetResistance(SpellSchools(ecole));
                    if (plus_basse < 0 || r < plus_basse)
                        plus_basse = r;
                }
                veut = -int32(std::llround(double(std::max(0, plus_basse)) * _pct / 100.0));
            }
            if (veut == _pose)
                return;
            _pose = veut;
            RemoveOwned(player, SpellId());
            if (!veut)
                return;
            int32 bp = veut;
            player->CastCustomSpell(player, SpellId(), &bp, &bp, &bp, true);
        }

    private:
        int32 _pct = 0;
        int32 _pose = -1;
    };

    // =========================================================================
    // areacost:<pct>
    //     LES SORTS DE ZONE COUTENT MOINS. Aucune aura ne sait dire « de
    //     zone » : le modificateur 108 choisit par famille de sorts, et le
    //     coeur n'a pas de masque pour l'etendue. Le module rend donc la part
    //     du cout, au moment ou le sort part, et seulement s'il frappe une
    //     zone -- ce que le sort dit lui-meme (`IsTargetingArea`).
    // =========================================================================
    class AreaCost : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 100, _pct) && r.End())
                || (error = "areacost expects the percentage", false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (!player || !spell || spell->IsTriggered())
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            if (!info || !info->IsTargetingArea() || info->PowerType != POWER_MANA)
                return;
            int32 const cout = info->CalcPowerCost(player, info->GetSchoolMask());
            uint32 const rendu = uint32(std::llround(double(std::max(0, cout)) * _pct / 100.0));
            if (rendu)
                Energize(player, player, rendu, SpellId());
        }

    private:
        int32 _pct = 0;
    };

    // =========================================================================
    // cackle:<critiques>:<ratees>
    //     LE RIRE DU FOU : il promet, puis il trahit. Les prochaines attaques
    //     sont critiques a coup sur, et celles d'apres ratent a coup sur. Rien
    //     de tout cela n'est une aura : c'est le DE DU COUP BLANC, que le coeur
    //     demande au module avant de le jeter.
    // =========================================================================
    class Cackle : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 20, _critiques) || !r.Int(0, 20, _ratees))
                return (error = "cackle expects how many crits then how many misses", false);
            if (!r.Int(1, 100, _chance))
                return (error = "cackle expects the chance", false);
            r.OptInt(0, 86400, _icd);
            return r.End() || (error = "too many parameters", false);
        }

        void Remove(Player* /*player*/) override { _reste = 0; _rate = 0; }

        // UN CRITIQUE ARME LE RIRE, si la chance et la recharge le veulent.
        void OnMeleeRoll(Player* /*player*/, Unit* /*autre*/, bool mien, int32& crit,
                         int32& miss, int32& /*dodge*/, int32& /*parry*/, int32& /*block*/) override
        {
            if (!mien)
                return;
            if (_reste)
            {
                --_reste;
                crit = 10000;
                if (!_reste)
                    _rate = _ratees;
                return;
            }
            if (_rate)
            {
                --_rate;
                miss = 10000;
            }
        }

        void OnTriggerProc(Player* /*player*/, Unit* /*other*/, uint32 /*amount*/) override { Armer(); }

    private:
        void Armer()
        {
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _dernier && now - _dernier < uint32(_icd))
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            _dernier = now;
            _reste = _critiques;
            _rate = 0;
        }

        int32 _critiques = 0, _ratees = 0, _chance = 100, _icd = 0;
        int32 _reste = 0, _rate = 0;
        uint32 _dernier = 0;
    };

    // =========================================================================
    // heallow:<seuil>:<pct>
    //     UN SOIN SUR UNE CIBLE AU PLUS BAS, majore d'autant. Aucune aura du
    //     coeur ne regarde la vie de la CIBLE d'un soin : le module lit le
    //     montant au moment ou il tombe, et rien d'autre.
    // =========================================================================
    class HealLow : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 100, _seuil) && r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the threshold then the percentage", false);
        }

        void OnHealDone(Player* /*player*/, Unit* target, uint32& gain) override
        {
            if (!target || !gain || target->GetHealthPct() >= float(_seuil))
                return;
            gain = uint32(std::llround(double(gain) * (100 + _pct) / 100.0));
        }

    private:
        int32 _seuil = 0, _pct = 0;
    };

    // =========================================================================
    // ward:<quoi>:<pct>
    //     LES BOUCLIERS DU JOUEUR, ceux qui absorbent.
    //       more:<pct>   ce qu'ils absorbent, majore d'autant. Le coeur a deja
    //                    pose le chiffre quand il previent : on le repose.
    //       broken:<pct> le bouclier ROMPU -- absorbe jusqu'au bout -- rend
    //                    cette part du mana du joueur.
    // =========================================================================
    class Ward : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _what = r.Word();
            if (_what != "more" && _what != "broken")
                return (error = "ward expects more or broken", false);
            if (!r.Int(1, 1000, _pct))
                return (error = "expects the percentage", false);
            return r.End() || (error = "too many parameters", false);
        }

        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override
        {
            if (_what != "more" || !player || !aura || target != player)
                return;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                AuraEffect* effet = aura->GetEffect(i);
                if (!effet || effet->GetAuraType() != SPELL_AURA_SCHOOL_ABSORB)
                    continue;
                int32 const pose = effet->GetAmount();
                if (pose <= 0)
                    continue;
                effet->ChangeAmount(pose + int32(std::llround(double(pose) * _pct / 100.0)));
            }
        }

        // UN BOUCLIER QUI S'EN VA : rompu quand il ne lui restait plus rien.
        // Celui qui expire en ayant encore de quoi absorber n'est pas rompu.
        void OnAuraRemoved(Player* player, Aura const* aura) override
        {
            if (_what != "broken" || !player || !aura)
                return;
            bool absorbe = false;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (AuraEffect const* effet = aura->GetEffect(i))
                    if (effet->GetAuraType() == SPELL_AURA_SCHOOL_ABSORB)
                    {
                        absorbe = true;
                        if (effet->GetAmount() > 0)
                            return;                 // il lui restait de quoi tenir
                    }
            if (!absorbe)
                return;
            Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), _pct), _spellId);
        }

    private:
        std::string _what;
        int32 _pct = 0;
    };

    // =========================================================================
    // roll:<quoi>:<facteur>:<chance_haute>:<chance_basse>[:<revers>]
    //     LE DE DU FOU. A chaque coup porte, sort lance ou soin rendu -- selon
    //     `quoi` (dmg, heal, both) -- deux des sont jetes dans cet ordre : le
    //     premier multiplie le montant par `facteur`, le second le fait tomber.
    //     Ce que « tomber » veut dire tient au revers :
    //       (rien)     le montant est nul
    //       hurt       le soin devient une blessure du meme montant sur la cible
    //       self:<pct> la part dite du coup revient au joueur
    //     Les deux des ne peuvent pas gagner ensemble : le premier consulte
    //     decide, et le second n'est jete que s'il a perdu.
    // =========================================================================
    class DeDuFou : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            std::string const quoi = r.Word();
            if (quoi == "dmg")        _degats = true;
            else if (quoi == "heal")  _soins = true;
            else if (quoi == "both")  _degats = _soins = true;
            else                      return (error = "roll expects dmg, heal or both", false);
            if (!r.Int(2, 10, _facteur) || !r.Int(1, 100, _haute) || !r.Int(0, 100, _basse))
                return (error = "roll expects the factor then the two chances", false);
            if (!r.End())
            {
                _revers = r.Word();
                if (_revers == "self")
                {
                    if (!r.Int(1, 100, _part))
                        return (error = "self expects its percentage", false);
                }
                else if (_revers != "hurt")
                    return (error = "unknown backlash " + _revers, false);
            }
            return r.End() || (error = "too many parameters", false);
        }

        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool /*spell*/,
                           uint32 school, uint32 /*spellId*/) override
        {
            if (!_degats || !damage || !player)
                return;
            if (int32(urand(1, 100)) <= _haute)
            {
                damage *= uint32(_facteur);
                return;
            }
            if (!_basse || int32(urand(1, 100)) > _basse)
                return;
            // Le revers du coup : soit il ne porte pas, soit il revient.
            if (_revers == "self")
            {
                uint32 const retour = uint32(std::llround(double(damage) * _part / 100.0));
                (void)victim;
                (void)school;
                Bleed(player, retour, _spellId);
            }
            else
                damage = 0;
        }

        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            if (!_soins || !gain || !player)
                return;
            if (int32(urand(1, 100)) <= _haute)
            {
                gain *= uint32(_facteur);
                return;
            }
            if (!_basse || int32(urand(1, 100)) > _basse)
                return;
            // « blesser la cible du montant » : le soin se retourne, et c'est
            // bien la cible du soin qui le prend.
            if (_revers == "hurt" && target)
            {
                uint32 const mal = gain;
                gain = 0;
                if (target == player)
                    Bleed(player, mal, _spellId);
                else
                    Hurt(player, target, mal, SPELL_SCHOOL_MASK_SHADOW, _spellId);
            }
            else
                gain = 0;
        }

    private:
        bool _degats = false, _soins = false;
        int32 _facteur = 2, _haute = 0, _basse = 0, _part = 0;
        std::string _revers;
    };

    // =========================================================================
    // lootchance:<qualite>:<pct>
    //     LA CHANCE D'UNE LIGNE DE TABLE, majoree pour les objets d'une
    //     qualite donnee. Le coeur tire chaque ligne de chaque table avec sa
    //     propre chance ; la carte la multiplie, elle n'ajoute aucun objet et
    //     ne touche a aucune table.
    //       rare      : qualite 3
    //       epic      : qualite 4
    //       rare_epic : les deux
    //     La chance reste bornee a 100 : au-dela, le coeur la lirait comme une
    //     certitude et la ligne tomberait a coup sur.
    // =========================================================================
    class LootChance : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            std::string const quoi = r.Word();
            if (quoi == "rare")            _du = 3, _au = 3;
            else if (quoi == "epic")       _du = 4, _au = 4;
            else if (quoi == "rare_epic")  _du = 3, _au = 4;
            else                           return (error = "unknown quality \"" + quoi + "\"", false);
            if (!r.Int(1, 1000, _pct))
                return (error = "expects the percentage", false);
            return r.End() || (error = "too many parameters", false);
        }
        [[nodiscard]] uint32 Watches() const override { return GUET_DE_DE_BUTIN; }

        void OnItemRoll(Player const* /*player*/, uint32 itemId, float& chance) override
        {
            if (chance <= 0.0f || chance >= 100.0f)
                return;                 // deja certaine, ou jamais : rien a majorer
            ItemTemplate const* modele = sObjectMgr->GetItemTemplate(itemId);
            if (!modele || modele->Quality < uint32(_du) || modele->Quality > uint32(_au))
                return;
            chance = std::min(100.0f, chance * float(100 + _pct) / 100.0f);
        }

    private:
        int32 _du = 0, _au = 0, _pct = 0;
    };

    // =========================================================================
    // chest_extra:<n>
    //     UN COFFRE REND DAVANTAGE : sa table est tiree n fois de plus, au
    //     moment meme ou le butin se compose. On ne choisit pas les objets --
    //     ils viennent de la table du coffre, avec ses propres chances.
    // =========================================================================
    class ChestExtra : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 10, _times))
                return (error = "expects how many more draws", false);
            // UNE CHANCE, quand la carte en donne une : « peut contenir un
            // objet supplementaire (10% de chance) ». Sans elle, a coup sur.
            r.OptInt(1, 100, _chance);
            // UNE RECHARGE, quand la carte en pose une : le tirage de plus ne
            // revient pas avant ce delai, quoi que le joueur ouvre.
            r.OptInt(0, 86400, _icd);
            return r.End() || (error = "too many parameters", false);
        }
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override
        {
            if (!loot || !tab || !store)
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _last && now - _last < uint32(_icd))
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            _last = now;
            for (int32 i = 0; i < _times; ++i)
                tab->Process(*loot, *store, LOOT_MODE_DEFAULT, player);
        }
    private:
        int32 _times = 0;
        int32 _chance = 100;
        int32 _icd = 0;
        uint32 _last = 0;
    };

    // =========================================================================
    // loot_gear:<qualite>:<chance>[:<icd>]
    //     UNE PIECE D'EQUIPEMENT DE PLUS dans un butin qu'on vient d'ouvrir,
    //     rare ou epique, a la mesure du joueur. Elle est prise dans ce que le
    //     monde fait DEJA tomber -- aucune table n'est inventee -- et elle
    //     rejoint le butin comme n'importe quelle ligne de sa table.
    // =========================================================================
    class LootGear : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            std::string const quoi = r.Word();
            if (quoi == "rare")       _quality = ITEM_QUALITY_RARE;
            else if (quoi == "epic")  _quality = ITEM_QUALITY_EPIC;
            else                      return (error = "unknown quality " + quoi, false);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            r.OptInt(0, 86400, _icd);
            return r.End() || (error = "too many parameters", false);
        }

        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* /*tab*/, LootStore const* /*store*/) override
        {
            if (!player || !loot)
                return;
            uint32 const now = uint32(GameTime::GetGameTime().count());
            if (_icd && _last && now - _last < uint32(_icd))
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            uint32 const piece = StellarTarotLoot::GearFor(uint8(_quality), player->GetLevel());
            if (!piece)
                return;
            _last = now;
            loot->AddItem(LootStoreItem(piece, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
        }

    private:
        int32 _quality = 0, _chance = 100, _icd = 0;
        uint32 _last = 0;
    };

    // =========================================================================
    // loot_double:<qualite>:<chance>
    //     CE QUI VIENT DE TOMBER, EN DOUBLE. Chaque objet de cette qualite ou
    //     mieux deja pose dans le butin peut y etre remis une fois. On ne
    //     choisit rien : c'est le butin du joueur, deux fois.
    // =========================================================================
    class LootDouble : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            std::string const quoi = r.Word();
            if (quoi == "rare")       _least = ITEM_QUALITY_RARE;
            else if (quoi == "epic")  _least = ITEM_QUALITY_EPIC;
            else                      return (error = "unknown quality " + quoi, false);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            return r.End() || (error = "too many parameters", false);
        }

        void OnCreatureLoot(Player* player, Loot* loot) override { Double(player, loot); }
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* /*tab*/, LootStore const* /*store*/) override
        {
            Double(player, loot);
        }

    private:
        void Double(Player* player, Loot* loot)
        {
            if (!player || !loot)
                return;
            // Ce qui est DEJA dans le butin, et rien de ce qu'on y ajoute : la
            // liste est arretee avant la premiere copie.
            std::vector<uint32> copies;
            for (LootItem const& item : loot->items)
            {
                ItemTemplate const* modele = sObjectMgr->GetItemTemplate(item.itemid);
                if (!modele || int32(modele->Quality) < _least)
                    continue;
                if (int32(urand(1, 100)) > _chance)
                    continue;
                copies.push_back(item.itemid);
            }
            for (uint32 entry : copies)
                loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
        }

        int32 _least = 0, _chance = 100;
    };

    // =========================================================================
    // boss_extra:<chance>[:<combien>]
    //     UN BOSS REND DAVANTAGE : sa propre table est tiree une fois de plus
    //     au moment ou son cadavre se remplit. Rien n'en sort qui ne pouvait
    //     pas en sortir.
    // =========================================================================
    class BossExtra : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            r.OptInt(1, 10, _times);
            return r.End() || (error = "too many parameters", false);
        }

        void OnCreatureLoot(Player* player, Loot* loot) override
        {
            if (!player || !loot || !loot->sourceWorldObjectGUID.IsCreature())
                return;
            Creature* mort = ObjectAccessor::GetCreature(*player, loot->sourceWorldObjectGUID);
            if (!mort)
                return;
            CreatureTemplate const* modele = mort->GetCreatureTemplate();
            if (!modele || (!mort->isWorldBoss() && modele->rank != CREATURE_ELITE_WORLDBOSS
                            && !(mort->GetMap() && mort->GetMap()->IsDungeon() && modele->rank == CREATURE_ELITE_ELITE)))
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            LootTemplate const* tab = LootTemplates_Creature.GetLootFor(modele->lootid);
            if (!tab)
                return;
            for (int32 i = 0; i < _times; ++i)
                tab->Process(*loot, LootTemplates_Creature, LOOT_MODE_DEFAULT, player);
        }

    private:
        int32 _chance = 100, _times = 1;
    };

    // =========================================================================
    // harvest:<quoi>:<chance>
    //     LA RECOLTE, au moment ou le butin du noeud ou du cadavre se compose.
    //       herb_extra   : la table du noeud d'HERBES, tiree une fois de plus
    //       herb_other   : une autre herbe de l'age du joueur, en plus
    //       skin_extra   : la table du DEPEÇAGE, tiree une fois de plus
    //       node_plus    : une unite de plus sur chaque pile du noeud
    //       node_respawn : le noeud repousse sur-le-champ
    //     « Noeud de recolte » vaut pour les deux serrures -- l'herboristerie
    //     et le minage -- et pour elles seules : un coffre n'est pas un noeud.
    // =========================================================================
    class Harvest : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _what = r.Word();
            static char const* const kinds[] = { "herb_extra", "herb_other", "skin_extra",
                                                 "node_plus", "node_respawn" };
            bool known = false;
            for (char const* k : kinds)
                if (_what == k) known = true;
            if (!known)
                return (error = "unknown harvest " + _what, false);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            return r.End() || (error = "too many parameters", false);
        }

        void OnSkinning(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override
        {
            if (_what != "skin_extra" || !player || !loot || !tab || !store)
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            tab->Process(*loot, *store, LOOT_MODE_DEFAULT, player);
        }

        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override
        {
            if (_what == "skin_extra" || !player || !loot)
                return;
            GameObject* const noeud = ObjectAccessor::GetGameObject(*player, loot->sourceWorldObjectGUID);
            int32 const serrure = SerrureDe(noeud);
            bool const herbe = serrure == LOCKTYPE_HERBALISM;
            bool const recolte = herbe || serrure == LOCKTYPE_MINING;
            if (_what == "herb_extra" || _what == "herb_other")
            {
                if (!herbe)
                    return;
            }
            else if (!recolte)
                return;
            if (int32(urand(1, 100)) > _chance)
                return;
            if (_what == "herb_extra")
            {
                if (tab && store)
                    tab->Process(*loot, *store, LOOT_MODE_DEFAULT, player);
            }
            // UNE AUTRE PLANTE, de l'age du joueur : elle vient de ce que les
            // noeuds du monde donnent deja, et de rien d'autre.
            else if (_what == "herb_other")
            {
                if (uint32 const plante = StellarTarotLoot::HerbFor(player->GetLevel()))
                    loot->AddItem(LootStoreItem(plante, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
            }
            // UNE UNITE DE PLUS sur chaque pile que le noeud vient de donner.
            else if (_what == "node_plus")
            {
                for (LootItem& item : loot->items)
                {
                    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
                    uint32 const pile = proto && proto->GetMaxStackSize() ? proto->GetMaxStackSize() : 1;
                    item.count = uint8(std::min<uint32>(uint32(item.count) + 1, pile));
                }
            }
            // LE NOEUD REPOUSSE : c'est le coeur qui le fait revenir, au tour
            // suivant -- celui-ci est encore en train d'etre depouille.
            else if (_what == "node_respawn" && noeud)
            {
                ObjectGuid const qui = noeud->GetGUID();
                PlusTard(player, TOUR_SUIVANT, [qui](Player* p)
                {
                    if (GameObject* go = ObjectAccessor::GetGameObject(*p, qui))
                    {
                        go->SetLootState(GO_READY);
                        go->SetRespawnTime(1);
                    }
                });
            }
        }

    private:
        // LA SERRURE D'UN OBJET DU DECOR : ce que le coeur demande pour
        // l'ouvrir. -1 quand il n'y en a pas.
        static int32 SerrureDe(GameObject const* go)
        {
            if (!go || !go->GetGOInfo())
                return -1;
            LockEntry const* const lock = sLockStore.LookupEntry(go->GetGOInfo()->GetLockId());
            if (!lock)
                return -1;
            for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
                if (lock->Type[i] == LOCK_KEY_SKILL
                    && (lock->Index[i] == LOCKTYPE_HERBALISM || lock->Index[i] == LOCKTYPE_MINING))
                    return int32(lock->Index[i]);
            return -1;
        }

        std::string _what;
        int32 _chance = 100;
    };

    // =========================================================================
    // prospect:<chance>
    //     PROSPECTER PAIE DEUX FOIS. Avec cette chance, la table du minerai est
    //     tiree une fois de plus au moment ou le butin de la prospection se
    //     compose : la gemme de surplus est donc toujours une gemme que ce
    //     minerai-la pouvait donner.
    // =========================================================================
    class Prospect : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            if (r.End())
                return true;
            return (r.Int(1, 10, _least) && r.Int(_least, 10, _most) && r.End())
                || (error = "after the chance, the least and the most draws", false);
        }
        void OnProspect(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override
        {
            if (!loot || !tab || !store)
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            int32 const fois = _most > _least ? int32(urand(uint32(_least), uint32(_most))) : _least;
            for (int32 i = 0; i < fois; ++i)
                tab->Process(*loot, *store, LOOT_MODE_DEFAULT, player);
        }

    private:
        int32 _chance = 0, _least = 1, _most = 1;
    };

    // =========================================================================
    // ore:<chance>:<quoi>
    //     CE QUE LA PIERRE REND, avec cette chance :
    //       double : le minerai qu'un FILON vient de donner est mis en double --
    //                le meme minerai, deux fois. Un coffre n'est pas un filon :
    //                la serrure est lue, et elle doit demander le minage.
    //       bar    : une barre de plus, celle qui vient d'etre fondue.
    //       keep   : le minerai que la fonte met au feu est remis dans les sacs
    //                au moment ou elle part, et la pile ne bouge pas.
    // =========================================================================
    class Ore : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            _what = r.Word();
            if (_what != "double" && _what != "bar" && _what != "keep")
                return (error = "expects double, bar or keep", false);
            return r.End() || (error = "nothing follows what the line gives", false);
        }

        // LE FILON : ce qu'il vient de donner, mis en double.
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* /*tab*/,
                          LootStore const* /*store*/) override
        {
            if (_what != "double" || !player || !loot || !IsVein(player, loot))
                return;
            bool aucun = true;
            for (LootItem const& item : loot->items)
                if (IsOre(item.itemid))
                {
                    aucun = false;
                    break;
                }
            if (aucun || (_chance < 100 && int32(urand(1, 100)) > _chance))
                return;
            for (LootItem& item : loot->items)
            {
                if (!IsOre(item.itemid))
                    continue;
                ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
                uint32 const pile = proto && proto->GetMaxStackSize() ? proto->GetMaxStackSize() : 1;
                item.count = uint8(std::min<uint32>(uint32(item.count) * 2, pile));
            }
        }

        // LE MINERAI QUI NE PART PAS AU FEU : le coeur prendra les composants
        // une fois le sort lance ; la carte les remet dans les sacs avant, et la
        // pile ne bouge pas.
        void OnSpellCast(Player* player, Spell* spell) override
        {
            if ((_what != "keep" && _what != "bar") || !player || !spell)
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            if (!info || !Smelts(info))
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            // UNE BARRE DE PLUS : celle-la meme que la fonte va donner.
            if (_what == "bar")
            {
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                {
                    uint32 const entry = info->Effects[i].ItemType;
                    if (info->Effects[i].Effect != SPELL_EFFECT_CREATE_ITEM || !entry)
                        continue;
                    ItemPosCountVec dest;
                    if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, 1) != EQUIP_ERR_OK)
                        continue;
                    if (Item* more = player->StoreNewItem(dest, entry, true))
                        player->SendNewItem(more, 1, true, false);
                    break;
                }
                return;
            }
            for (uint8 i = 0; i < MAX_SPELL_REAGENTS; ++i)
            {
                if (info->Reagent[i] <= 0 || !info->ReagentCount[i])
                    continue;
                uint32 const entry = uint32(info->Reagent[i]);
                uint32 const combien = uint32(info->ReagentCount[i]);
                ItemPosCountVec dest;
                if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, combien) != EQUIP_ERR_OK)
                    continue;
                if (Item* back = player->StoreNewItem(dest, entry, true))
                    player->SendNewItem(back, combien, true, false);
            }
        }

    private:
        // Un minerai, une pierre, une barre : la meme famille d'objets.
        static bool IsOreProto(ItemTemplate const* proto)
        {
            return proto && proto->Class == ITEM_CLASS_TRADE_GOODS
                && proto->SubClass == ITEM_SUBCLASS_METAL_STONE;
        }
        static bool IsOre(uint32 entry)
        {
            return IsOreProto(sObjectMgr->GetItemTemplate(entry));
        }
        // UN FILON, ET NON UN COFFRE : la serrure de l'objet du decor demande la
        // competence de minage.
        static bool IsVein(Player* player, Loot const* loot)
        {
            GameObject const* const go = ObjectAccessor::GetGameObject(*player, loot->sourceWorldObjectGUID);
            if (!go || !go->GetGOInfo())
                return false;
            LockEntry const* const lock = sLockStore.LookupEntry(go->GetGOInfo()->GetLockId());
            if (!lock)
                return false;
            for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
                if (lock->Type[i] == LOCK_KEY_SKILL && lock->Index[i] == LOCKTYPE_MINING)
                    return true;
            return false;
        }
        // UNE FONTE, et non une fabrication quelconque : le sort appartient au
        // METIER DE MINAGE et cree un objet. Le metier tranche la ou la sorte de
        // l'objet ne suffit pas -- une barre et un minerai sont du meme bois
        // pour le jeu, seul le metier les separe.
        static bool Smelts(SpellInfo const* info)
        {
            if (!info->HasEffect(SPELL_EFFECT_CREATE_ITEM))
                return false;
            SkillLineAbilityMapBounds const bounds = sSpellMgr->GetSkillLineAbilityMapBounds(info->Id);
            for (auto it = bounds.first; it != bounds.second; ++it)
                if (it->second->SkillLine == SKILL_MINING)
                    return true;
            return false;
        }

        int32 _chance = 0;
        std::string _what;
    };

    // =========================================================================
    // fish:<chance>:<quoi>
    //     CE QUE LA LIGNE REMONTE DE L'EAU, au moment ou le butin de la peche
    //     se compose, avec cette chance :
    //       double : la prise est mise en double exemplaire -- le meme objet,
    //                deux fois. Ce qui n'est pas un poisson est laisse tel
    //                quel, et la chance n'est jouee que s'il y a un poisson :
    //                un bouchon qui ne ramene qu'un crane ne depense rien.
    //       chest  : un des contenants que la peche donne deja d'elle-meme,
    //                celui que le lieu appelle.
    //       pearl  : une perle, choisie de meme par le lieu.
    // =========================================================================
    class Fish : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance))
                return (error = "expects the chance", false);
            _what = r.Word();
            if (_what != "double" && _what != "chest" && _what != "pearl")
                return (error = "expects double, chest or pearl", false);
            return r.End() || (error = "nothing follows what the line gives", false);
        }

        void OnFishing(Player* player, Loot* loot, LootTemplate const* /*tab*/,
                       LootStore const* /*store*/) override
        {
            if (!player || !loot)
                return;
            if (_what == "double")
            {
                bool aucun = true;
                for (LootItem const& item : loot->items)
                    if (IsFish(item.itemid))
                    {
                        aucun = false;
                        break;
                    }
                if (aucun || (_chance < 100 && int32(urand(1, 100)) > _chance))
                    return;
                for (LootItem& item : loot->items)
                {
                    if (!IsFish(item.itemid))
                        continue;
                    ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item.itemid);
                    uint32 const pile = proto && proto->GetMaxStackSize() ? proto->GetMaxStackSize() : 1;
                    item.count = uint8(std::min<uint32>(uint32(item.count) * 2, pile));
                }
                return;
            }
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            if (uint32 const entry = DuLieu(player, _what == "chest" ? "chest" : "pearl"))
                loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
        }

    private:
        // UN POISSON, au sens du jeu : la viande que la peche remonte (les
        // poissons bruts), tout ce qui nourrit un familier au regime poisson
        // (les prises deja cuisinees que l'eau rend parfois), et les quelques
        // poissons que l'alchimie emploie, que le coeur range ailleurs.
        static bool IsFish(uint32 entry)
        {
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
            if (!proto)
                return false;
            if (proto->Class == ITEM_CLASS_TRADE_GOODS && proto->SubClass == ITEM_SUBCLASS_MEAT)
                return true;
            if (proto->FoodType == FOOD_TYPE_FISH)
                return true;
            static uint32 const autres[] = { 6358, 6359, 13422, 13757, 40199, 6522, 6299 };
            for (uint32 id : autres)
                if (id == entry)
                    return true;
            return false;
        }

        static constexpr uint32 FOOD_TYPE_FISH = 2;   // le regime poisson des familiers

        int32 _chance = 0;
        std::string _what;
    };
    // =========================================================================
    // hearthcd:<pct>
    //     La PIERRE DE FOYER revient plus vite : sa recharge est ecourtee de
    //     cette part. Le compte se fait sur la recharge D'ORIGINE, jamais sur
    //     ce qui reste : deux niveaux a -25 et -50 % font ainsi -75 %, et non
    //     les -62,5 % d'un enchainement.
    //     La coupe attend le tic suivant : le coeur pose la recharge APRES le
    //     lancement, et l'ecourter avant ne servirait a rien.
    // =========================================================================
    class HearthCooldown : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 99, _pct) && r.End())
                || (error = "expects the percentage", false);
        }
        void OnSpellCast(Player* player, Spell* spell) override
        {
            if (!spell || !spell->GetSpellInfo() || spell->GetSpellInfo()->Id != HEARTHSTONE)
                return;
            // LA RECHARGE DE LA PIERRE N'EST PAS LA OU ON LA CHERCHE : le sort
            // 8690 a RecoveryTime = 0 et porte ses trente minutes dans
            // CategoryRecoveryTime (categorie 1176).
            SpellInfo const* const info = spell->GetSpellInfo();
            int32 const base = int32(info->RecoveryTime ? info->RecoveryTime : info->CategoryRecoveryTime);
            if (base <= 0)
                return;
            int32 const cut = base * _pct / 100;
            PlusTard(player, TOUR_SUIVANT, [cut](Player* p)
            {
                p->ModifySpellCooldown(HEARTHSTONE, -cut);
            });
        }
    private:
        static constexpr uint32 HEARTHSTONE = 8690;
        int32 _pct = 0;
    };

    // =========================================================================
    // econ:<kind>:<pct>
    // =========================================================================
    // =========================================================================
    // xpkin:<pct>
    //     LES SIENS, DEJA AU PLAFOND. Chaque personnage du COMPTE parvenu au
    //     niveau maximum vaut cette part d'experience de plus, et l'aura du
    //     niveau montre le compte dans ses cumuls -- un cumul par personnage.
    //     Le compte se lit dans la base des personnages quand la carte se pose
    //     et a chaque niveau gagne : un des siens qui atteint le plafond
    //     ailleurs sera compte au prochain des deux.
    // =========================================================================
    class XpKin : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }
        bool OwnsAura() const override { return true; }
        void Apply(Player* player) override { Read(player); Show(player); }
        void Remove(Player* player) override { RemoveOwned(player, _spellId); _kin = 0; }
        void OnLevelUp(Player* player) override { Read(player); Show(player); }

        // LE COMPTE EST DANS L'AURA : le sort du niveau porte MOD_XP_PCT a la
        // part PAR CUMUL, et le coeur la multiplie par les cumuls que le module
        // y met. Ne reste ici que ce que l'aura ne couvre pas -- la decouverte
        // et le champ de bataille.
        void OnGiveXP(Player* player, uint32& amount, uint8 source) override
        {
            if (!_kin || !amount || !player || (source != XPSOURCE_EXPLORE && source != XPSOURCE_BATTLEGROUND))
                return;
            amount = uint32(std::llround(double(amount) * (100 + int32(_kin) * _pct) / 100.0));
        }

    private:
        void Read(Player* player)
        {
            _kin = 0;
            if (!player || !player->GetSession())
                return;
            QueryResult result = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM characters WHERE account = {} AND level = {}",
                player->GetSession()->GetAccountId(), sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
            if (result)
                _kin = (*result)[0].Get<uint64>();
        }

        void Show(Player* player)
        {
            RemoveOwned(player, _spellId);
            if (!_kin)
                return;                     // personne au plafond : rien a montrer
            if (Aura* aura = player->AddAura(_spellId, player))
                if (_kin > 1)
                    aura->SetStackAmount(uint8(std::min<uint64>(_kin, 10)));
        }

        uint64 _kin = 0;
        int32 _pct = 0;
    };

    class Econ : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _kind = r.Word();
            // `xp_other` : l'experience que l'AURA NE COUVRE PAS -- la
            // decouverte et le champ de bataille. Les auras 200 et 291 portent
            // le reste, et une ligne qui les a gardees n'y ajoute rien.
            static char const* const kinds[] = { "gold_loot", "xp", "xp_other", "xp_explore", "rep",
                                                 "quest_gold", "quest_gold_daily", "repair", "ah_sell",
                                                 "rep_quest",
                                                 "vendor_buy", "vendor_sell", "vendor_sell_grey", "vendor_sell_good" };
            bool known = false;
            for (char const* k : kinds)
                if (_kind == k) known = true;
            if (!known) { error = "unknown kind \"" + _kind + "\""; return false; }
            if (!r.Int(-100, 10000, _pct))
                return (error = "expects the percentage", false);
            // D'AUTRES MONNAIES, quand la carte en promet plusieurs d'un coup :
            // « and:<genre>:<part> », autant de fois qu'il le faut. Elles n'ont
            // ni palier ni plafond -- ceux-ci restent au premier genre, qui
            // seul les porte.
            while (!r.End() && r.Peek() == "and")
            {
                r.Word();
                std::string const autre = r.Word();
                bool ok2 = false;
                for (char const* k : kinds)
                    if (autre == k) ok2 = true;
                if (!ok2) { error = "unknown second kind \"" + autre + "\""; return false; }
                int32 part = 0;
                if (!r.Int(-100, 10000, part))
                    return (error = "the second kind expects its percentage", false);
                _autres.emplace_back(autre, part);
            }
            // Two shapes may follow. « per_gold:<gold>:cap:<pct> » : the figure
            // counts once per slice of that many gold pieces the player owns,
            // never beyond the cap. Then a state, as before.
            if (!r.End() && r.Peek() == "per_gold")
            {
                r.Word();
                if (!r.Int(1, 1000000, _perGold) || r.Word() != "cap" || !r.Int(1, 10000, _cap))
                    return (error = "per_gold expects <gold>:cap:<pct>", false);
            }
            if (!r.End())
            {
                _state = r.Word();
                static char const* const states[] = { "rested", "combat", "nocombat", "solo", "night", "day", "water" };
                bool good = false;
                for (char const* st : states)
                    if (_state == st) good = true;
                if (!good) { error = "unknown state \"" + _state + "\""; return false; }
            }
            return r.End() || (error = "after the state, nothing else", false);
        }
        // Every line below asks the same question first: is the state, if the
        // line named one, holding right now?
        bool On(Player const* player) const { return _state.empty() || SimpleState(player, _state); }

        // La ligne couvre-t-elle ce genre, et pour quelle part ?
        bool Has(char const* k) const
        {
            if (_kind == k)
                return true;
            for (auto const& [genre, part] : _autres)
                if (genre == k)
                    return true;
            return false;
        }
        int32 PctOf(Player const* player, char const* k) const
        {
            if (_kind == k) return Pct(player);
            for (auto const& [genre, part] : _autres)
                if (genre == k)
                    return part;
            return 0;
        }

        // Le pourcentage en vigueur : celui de la ligne, ou celui que la bourse
        // du joueur lui vaut, jamais au-dela du plafond.
        int32 Pct(Player const* player) const
        {
            if (!_perGold)
                return _pct;
            uint32 const slices = uint32(player->GetMoney() / (uint64(_perGold) * 10000));
            int32 const scaled = _pct * int32(slices);
            return _pct < 0 ? std::max(scaled, -_cap) : std::min(scaled, _cap);
        }

        void OnLootMoney(Player* player, uint32& copper) override
        {
            if (Has("gold_loot") && On(player))
                copper = uint32(std::llround(double(copper) * (100 + PctOf(player, "gold_loot")) / 100.0));
        }
        // `xp` couvre TOUTE l'experience -- c'est ce qui reste aux lignes qu'une
        // aura ne peut pas porter : celles qui nomment un etat ou deux genres.
        // `xp_other` ne couvre que ce que l'aura laisse : la decouverte et le
        // champ de bataille.
        void OnGiveXP(Player* player, uint32& amount, uint8 source) override
        {
            bool const reste = source == XPSOURCE_EXPLORE || source == XPSOURCE_BATTLEGROUND;
            if (Has("xp") && On(player))
                amount = uint32(std::llround(double(amount) * (100 + PctOf(player, "xp")) / 100.0));
            else if (reste && Has("xp_other") && On(player))
                amount = uint32(std::llround(double(amount) * (100 + PctOf(player, "xp_other")) / 100.0));
            // `xp_explore` ne couvre QUE la decouverte : ce que le joueur
            // gagne en mettant le pied quelque part, et rien d'autre.
            if (source == XPSOURCE_EXPLORE && Has("xp_explore") && On(player))
                amount = uint32(std::llround(double(amount) * (100 + PctOf(player, "xp_explore")) / 100.0));
        }
        void OnGiveReputation(Player* player, float& amount, uint8 source) override
        {
            if (Has("rep") && On(player))
                amount = amount * float(100 + PctOf(player, "rep")) / 100.0f;
            // `rep_quest` : la reputation que RENDENT LES QUETES, et elle
            // seule -- journalieres, hebdomadaires et repetables comprises.
            bool const quete = source == REPUTATION_SOURCE_QUEST
                            || source == REPUTATION_SOURCE_DAILY_QUEST
                            || source == REPUTATION_SOURCE_WEEKLY_QUEST
                            || source == REPUTATION_SOURCE_MONTHLY_QUEST
                            || source == REPUTATION_SOURCE_REPEATABLE_QUEST;
            if (quete && Has("rep_quest") && On(player))
                amount = amount * float(100 + PctOf(player, "rep_quest")) / 100.0f;
        }
        void OnQuestComplete(Player* player, Quest const* quest) override
        {
            // `quest_gold_daily` ne repond qu'aux quetes journalieres ; le
            // coeur dit lui-meme lesquelles.
            bool const journaliere = quest && quest->IsDaily();
            if ((Has("quest_gold") || (journaliere && Has("quest_gold_daily"))) && quest)
            {
                // CE QUE LA QUETE PAIE VRAIMENT, compte comme le coeur le
                // compte (Player::RewardQuest) : l'argent de la recompense,
                // AJUSTE AU NIVEAU du joueur, et -- au niveau maximum, ou l'or
                // remplace l'experience -- la somme prevue pour ce cas. Sans
                // cette seconde part, le bonus portait sur la moitie de ce que
                // le joueur recevait.
                int32 money = 0;
                if (player->GetLevel() >= sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL))
                    money += quest->GetRewMoneyMaxLevel();
                money += quest->GetRewOrReqMoney(player->GetLevel());
                if (money > 0)
                {
                    int32 const part = Has("quest_gold") ? Pct(player)
                                                         : PctOf(player, "quest_gold_daily");
                    int32 const extra = int32(std::llround(double(money) * part / 100.0));
                    player->ModifyMoney(extra);
                    if (extra > 0)
                        Owe(player, SpellId(), STELLAR_TAROT_STR_QUEST_GOLD, uint64(extra), true);
                }
            }
        }
        // LE GAIN D'UNE VENTE A L'HOTEL, avant qu'il ne parte au courrier.
        void OnAuctionSold(Player* player, uint32& profit) override
        {
            if (Has("ah_sell") && On(player) && profit)
                profit = uint32(std::llround(double(profit) * (100 + PctOf(player, "ah_sell")) / 100.0));
        }
        void OnRepairDiscount(Player* player, ObjectGuid /*itemGuid*/, float& discountMod) override
        {
            if (Has("repair") && On(player))
                discountMod *= float(100 + PctOf(player, "repair")) / 100.0f;                  // pct is negative for a rebate
        }
        void OnVendorDiscount(Player const* player, float& discount) override
        {
            if (Has("vendor_buy") && On(player)) discount *= float(100 + PctOf(player, "vendor_buy")) / 100.0f;
        }
        // The item is named here, and nowhere else: what the vendor pays comes
        // later, as a plain change of money. A grey line waits for a POOR item.
        void OnSellItem(Player* /*player*/, Item* item) override
        {
            if (_kind == "vendor_sell")
                AttendreLaSomme(_selling);
            else if (_kind == "vendor_sell_grey" && item && item->GetTemplate()
                     && item->GetTemplate()->Quality == ITEM_QUALITY_POOR)
                AttendreLaSomme(_selling);
            else if (_kind == "vendor_sell_good" && item && item->GetTemplate()
                     && item->GetTemplate()->Quality >= ITEM_QUALITY_UNCOMMON)
                AttendreLaSomme(_selling);
        }
        void OnMoneyChanged(Player* player, int32& amount) override
        {
            if (_kind != "vendor_sell" && _kind != "vendor_sell_grey"
                && _kind != "vendor_sell_good")
                return;
            if (SommeAttendue(_selling) && amount > 0)
            {
                int32 const sans_la_carte = amount;
                amount = int32(std::llround(double(amount) * (100 + Pct(player)) / 100.0));
                // LE BENEFICE, PORTE AU CLIENT. La fermeture de la fenetre du
                // marchand n'existe pas cote serveur -- le client 3.3.5
                // n'envoie rien en la fermant -- donc le module ne peut pas
                // attendre ce moment pour parler. Il dit ce que CETTE vente a
                // rapporte en plus ; l'addon additionne et annonce le total a
                // `MERCHANT_CLOSED`, quand le joueur repart.
                if (amount > sans_la_carte)
                    TellClient(player, "StellarTarotProfit",
                               std::to_string(SpellId()) + ":"
                               + std::to_string(amount - sans_la_carte));
            }
        }
    private:
        std::string _kind, _state;
        // LES AUTRES MONNAIES de la meme ligne : « +20% or, +20% experience et
        // +20% reputation gagnes » en tient trois.
        std::vector<std::pair<std::string, int32>> _autres;
        int32 _pct = 0, _perGold = 0, _cap = 0;
        uint32 _selling = 0;             // l'heure ou la somme est attendue
    };
}

void StellarTarotScripts::RegisterEngine()
{
    Register("cond", [] { return std::make_unique<Cond>(); });
    Register("proc", [] { return std::make_unique<Proc>(); });
    Register("dmgmod", [] { return std::make_unique<NumberMod>(NumberMod::Sense::Done); });
    Register("wandmod", [] { return std::make_unique<NumberMod>(NumberMod::Sense::Wand); });
    Register("takenmod", [] { return std::make_unique<NumberMod>(NumberMod::Sense::Taken); });
    Register("sp_pct", [] { return std::make_unique<SpellPowerPct>(); });
    Register("schoolsp", [] { return std::make_unique<SchoolSpellPower>(); });
    Register("seal", [] { return std::make_unique<Seal>(); });
    Register("convoy", [] { return std::make_unique<Convoy>(); });
    Register("gempct", [] { return std::make_unique<GemPct>(); });
    Register("cheatdeath", [] { return std::make_unique<CheatDeath>(); });
    Register("goldstat", [] { return std::make_unique<GoldStat>(); });
    Register("randstat", [] { return std::make_unique<RandStat>(); });
    Register("stat", [] { return std::make_unique<NightStat>(); });
    Register("costmod", [] { return std::make_unique<CostMod>(); });
    Register("drink", [] { return std::make_unique<Drink>(); });
    Register("fever", [] { return std::make_unique<Fever>(); });
    Register("potion", [] { return std::make_unique<PotionPower>(); });
    Register("potion_keep", [] { return std::make_unique<PotionKeep>(); });
    Register("potionplus", [] { return std::make_unique<PotionPlus>(); });
    Register("deathkeep", [] { return std::make_unique<DeathKeep>(); });
    Register("elixirlong", [] { return std::make_unique<Longer>(Longer::Kind::Elixir); });
    Register("statcond", [] { return std::make_unique<StateStat>(); });
    Register("secondpct", [] { return std::make_unique<SecondaryPct>(); });
    Register("ratingpct", [] { return std::make_unique<RatingPct>(); });
    Register("shoutlong", [] { return std::make_unique<Longer>(Longer::Kind::Cry); });
    Register("hearthcd", [] { return std::make_unique<HearthCooldown>(); });
    Register("chest_extra", [] { return std::make_unique<ChestExtra>(); });
    Register("roll", [] { return std::make_unique<DeDuFou>(); });
    Register("ward", [] { return std::make_unique<Ward>(); });
    Register("heallow", [] { return std::make_unique<HealLow>(); });
    Register("targetres", [] { return std::make_unique<TargetRes>(); });
    Register("areacost", [] { return std::make_unique<AreaCost>(); });
    Register("cackle", [] { return std::make_unique<Cackle>(); });
    Register("bridge", [] { return std::make_unique<Bridge>(); });
    Register("featherfall", [] { return std::make_unique<FeatherFall>(); });
    Register("lockpick", [] { return std::make_unique<LockPick>(); });
    Register("pertag", [] { return std::make_unique<PerTag>(); });
    Register("hitroll", [] { return std::make_unique<HitRoll>(); });
    Register("healmod", [] { return std::make_unique<HealMod>(); });
    Register("stacklong", [] { return std::make_unique<StackLonger>(); });
    Register("cardtool", [] { return std::make_unique<CardTool>(); });
    Register("focus", [] { return std::make_unique<Focus>(); });
    Register("phase", [] { return std::make_unique<Phase>(); });
    Register("heirloompct", [] { return std::make_unique<HeirloomPct>(); });
    Register("petaura", [] { return std::make_unique<AuraDeBete>(); });
    Register("cdcut", [] { return std::make_unique<CooldownCut>(); });
    Register("petshare", [] { return std::make_unique<PetShare>(); });
    Register("lootchance", [] { return std::make_unique<LootChance>(); });
    Register("loot_gear", [] { return std::make_unique<LootGear>(); });
    Register("loot_double", [] { return std::make_unique<LootDouble>(); });
    Register("boss_extra", [] { return std::make_unique<BossExtra>(); });
    Register("harvest", [] { return std::make_unique<Harvest>(); });
    Register("prospect", [] { return std::make_unique<Prospect>(); });
    Register("fish", [] { return std::make_unique<Fish>(); });
    Register("ore", [] { return std::make_unique<Ore>(); });
    Register("tickmod", [] { return std::make_unique<NumberMod>(NumberMod::Sense::Tick); });
    Register("dotlong", [] { return std::make_unique<Longer>(Longer::Kind::Dot); });
    Register("stunlong", [] { return std::make_unique<Longer>(Longer::Kind::Stun); });
    Register("breakfree", [] { return std::make_unique<BreakFree>(); });
    Register("sicknessless", [] { return std::make_unique<Longer>(Longer::Kind::Sickness); });
    Register("foodlong", [] { return std::make_unique<Longer>(Longer::Kind::Food); });
    Register("econ", [] { return std::make_unique<Econ>(); });
    Register("xpkin", [] { return std::make_unique<XpKin>(); });
}

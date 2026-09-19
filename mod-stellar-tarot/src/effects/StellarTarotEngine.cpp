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
#include "Creature.h"
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
        {
            ObjectGuid const who = player->GetGUID();
            player->m_Events.AddEventAtOffset([who]() { FlushOwed(who); }, Milliseconds(1));
        }
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
            int32 const parTic = std::max<int32>(1, int32(PctOf(player->GetMaxHealth(), n)) / battements) - 1;
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
            Put(player, player, markSpell ? markSpell : STELLAR_TAROT_SPELL_TAKEN_MORE, n2, &more);
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
            int32 const perTick = int32(PctOf(player->GetMaxHealth(), n)) - 1;
            Put(player, player, markSpell ? markSpell : STELLAR_TAROT_SPELL_BURN, n2, &perTick);
        }
    }
    bool CostKind(std::string const& k)
    {
        return k == "hp" || k == "hp_each" || k == "hp_stack" || k == "mana" || k == "disorient"
            || k == "stun" || k == "silence" || k == "sleep" || k == "root" || k == "taken"
            || k == "burn" || k == "burn_s" || k == "self_hit" || k == "armor";
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
                but.kind = r.Word();
                if (!CostKind(but.kind))
                    return (error = "unknown drawback \"" + but.kind + "\"", false);
                if (!r.Int(1, 100000, but.n))
                    return (error = but.kind + " expects a figure", false);
                if (CostPair(but.kind) && !r.Int(1, 3600, but.n2))
                    return (error = but.kind + " expects the figure then the seconds", false);
                if (but.kind == "armor" || but.kind == "taken" || but.kind == "burn_s")
                    r.OptInt(902000, 903999, but.spell);
                continue;
            }
            if (word == "chance" && r.Int(1, 100, but.chance))
                continue;
            return (error = "after the figures, only but:<kind>:<n> or chance:<n> may follow", false);
        }
        return true;
    }

    void SufferDrawback(Player* player, Drawback const& but, uint32 spellId, uint32 lastAmount)
    {
        if (!but.Some() || !player)
            return;
        if (but.chance < 100 && int32(urand(1, 100)) > but.chance)
            return;
        if (but.kind == "self_hit")
        {
            Hurt(player, player, PctOf(lastAmount, but.n), SPELL_SCHOOL_MASK_NORMAL, spellId);
            return;
        }
        Cost(player, but.kind, but.n, but.n2, spellId, uint32(but.spell));
    }

    // UN VERSEMENT SOUS CONDITION, a chaque battement. Les PV et le mana n'y
    // passent plus : le COEUR les verse lui-meme, par une aura permanente que
    // l'etat porte (auras 20 et 21, leur periode dans le sort). Ne reste que la
    // durabilite, que l'effet 111 sait bien reparer mais en le journalisant,
    // quand l'ecriture directe du module est muette.
    void SmallAction(Player* player, std::string const& action, int32 n, uint32 /*spellId*/ = 0)
    {
        if (action == "repair") Mend(player, uint32(n));
    }
    bool SmallKind(std::string const& a) { return a == "repair"; }

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
    bool LayRatingShare(Player* player, uint32 spellId, std::vector<int32> const& parts, int32 seconds)
    {
        SpellInfo const* const info = sSpellMgr->GetSpellInfo(spellId);
        if (!info || !player)
            return false;
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
            // La face du de ajoute le dernier point, comme partout ailleurs.
            bp[i] = int32(std::llround(double(own) * part / 100.0)) - 1;
        }
        if (!nomme)
            return false;
        // CE QUI N'EST PAS UN SCORE GARDE LE CHIFFRE DU DBC : on ne passe de
        // valeur que pour les effets qu'on remplit.
        player->CastCustomSpell(player, spellId, porte[0] ? &bp[0] : nullptr,
                                porte[1] ? &bp[1] : nullptr, porte[2] ? &bp[2] : nullptr, true);
        if (seconds)
            if (Aura* laid = player->GetAura(spellId, player->GetGUID()))
            {
                laid->SetMaxDuration(seconds * 1000);
                laid->SetDuration(seconds * 1000);
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
                                                 "dawn_dusk", "combat", "nocombat", "rested", "water", "charmed" };
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
                error = "after the state, only stacks:<k>, tick:<sec>:<action>:<n> or rating:<pct> may follow";
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
            if (_state == "shield") return HasShield(player);
            if (_state == "twohand") return HasTwoHand(player);
            if (_state == "dualwield") return DualWields(player);
            if (_state == "unarmed") return Unarmed(player);
            if (_state == "solo") return !player->GetGroup();
            if (_state == "night") return IsNight();
            if (_state == "day") { int h = LocalHour(); return h >= 6 && h < 21; }
            if (_state == "dawn_dusk") { int h = LocalHour(); return (h >= 5 && h < 7) || (h >= 19 && h < 21); }
            if (_state == "combat") return player->IsInCombat();
            if (_state == "nocombat") return !player->IsInCombat();
            if (_state == "rested") return player->HasPlayerFlag(PLAYER_FLAGS_RESTING);
            if (_state == "water") return player->IsInWater();
            if (_state == "indoors") return !player->IsOutdoors();
            if (_state == "outdoors") return player->IsOutdoors();
            // L'ESPRIT QU'ON LUI PREND : la peur ou le charme, rien d'autre.
            // On lit les AURAS autant que les etats : un charme se pose par des
            // chemins ou l'etat ne suit pas toujours.
            if (_state == "charmed")
                return player->HasUnitState(UNIT_STATE_FLEEING | UNIT_STATE_CHARMED)
                    || player->HasAuraType(SPELL_AURA_MOD_FEAR)
                    || player->HasAuraType(SPELL_AURA_MOD_CHARM)
                    || player->HasAuraType(SPELL_AURA_MOD_POSSESS);
            if (_state == "hp_below") return player->GetHealthPct() < float(_n);
            if (_state == "hp_above") return player->GetHealthPct() > float(_n);
            if (_state == "mana_below") return player->GetPowerPct(POWER_MANA) < float(_n);
            if (_state == "gold_above") return player->GetMoney() > uint32(_n);
            if (_state == "hour") { int h = LocalHour(); return h >= _n && h < _m; }
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
            return false;
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
        std::string _state, _and, _tickAction;
        int32 _n = 0, _m = 0, _stacks = 1, _tickEvery = 0, _tickN = 0, _ratingPct = 0;
        std::vector<int32> _ratingParts;
        uint32 _ticked = 0;
        uint32 _stillSince = 0;
        float _x = 0, _y = 0;
    };

    // =========================================================================
    // proc:<event>:<chance>:<icd>:<action>[:<params>][:trigger:<spell>][:cost:<kind>:<n>]
    // =========================================================================
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
                                                 "spell_crit_fire", "wand",
                                                 "heal", "heal_ally", "heal_full", "enter_combat", "leave_combat", "levelup", "resurrect",
                                                 "zone", "quest", "loot_gold", "vendor_buy", "repair",
                                                 "flight_end", "loot_creature", "vendor_sell",
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
                || _event == "spell_cast_school" || _event == "death_near" || _event == "spell_cast_id"
                || _event == "no_spend" || _event == "nocombat")
            {
                known = true;
                if (!r.Int(1, 86400, _eventN)) { error = _event + " expects a number"; return false; }
            }
            if (!known) { error = "unknown event \"" + _event + "\""; return false; }
            if (!r.Int(0, 100, _chance) || !r.Int(0, 86400, _icd)) { error = "expects the chance then the cooldown"; return false; }
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
            else if (A == "none" || A == "restore" || A == "recast" || A == "repair_all" || A == "next_crit" || A == "next_sure"
                     || A == "next_instant"
                     || A == "extra_shot" || A == "extra_copy" || A == "free_repair" || A == "crate"
                     || A == "grey_item" || A == "gem")
                ok = true;
            else if (A == "repair_one" || A == "refund" || A == "resurrect")
                ok = r.Int(1, 100, _a);
            else if (A == "mana_pm")
                ok = r.Int(1, 1000, _a);
            else if (A == "leech_pet")
                ok = r.Int(1, 100, _a);
            else if (A == "aura" || A == "aura_target" || A == "aura_pet")
                ok = r.Int(0, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "aura_group")
                ok = r.Int(1, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "heal" || A == "mana" || A == "heal_both" || A == "leech" || A == "mirror"
                     || A == "copper_per_damage"
                     || A == "free_next" || A == "cooldowns" || A == "reset_cooldowns" || A == "repair" || A == "gold_mult"
                     || A == "immune_snare" || A == "root" || A == "stun" || A == "disorient" || A == "fear" || A == "sleep"
                     || A == "silence" || A == "knockback")
                ok = r.Int(1, 100000, _a);
            else if (A == "gold_level" || A == "silver_level")
                ok = r.Int(1, 100000000, _a);
            else if (A == "shield_self" || A == "shield_target" || A == "splash" || A == "cleave" || A == "explode"
                     || A == "heal_group" || A == "heal_ally_amount" || A == "heal_pet" || A == "bleed" || A == "blink")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b);
            else if (A == "bleed_hit")
                ok = r.Int(1, 3600, _a) && r.Int(1, 100, _b) && r.Int(902000, 903999, _c);
            else if (A == "turn" || A == "turn_ally")
                ok = r.Int(1, 3600, _a) && (r.OptInt(1, 100, _b) || true);
            else if (A == "shield_ally" || A == "shield_group" || A == "damage_sp" || A == "damage_ap" || A == "extra"
                     || A == "explode_sp" || A == "hp_dmg")
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
                    _costKind = r.Word();
                    if (!CostKind(_costKind))
                    {
                        error = "unknown drawback \"" + _costKind + "\"";
                        return false;
                    }
                    if (!r.Int(1, 100000, _costN))
                    {
                        error = _costKind + " expects a figure";
                        return false;
                    }
                    if (CostPair(_costKind) && !r.Int(1, 3600, _costN2))
                    {
                        error = _costKind + " expects the figure then the seconds";
                        return false;
                    }
                    // Le sort de la marque, quand le revers en pose une.
                    if (_costKind == "armor" || _costKind == "taken" || _costKind == "burn_s"
                        || _costKind == "hp_stack")
                        r.OptInt(902000, 903999, _costSpell);
                    continue;
                }
                // La chance du revers : sans elle, il tombe a chaque fois.
                if (word == "chance" && r.Int(1, 100, _costChance))
                    continue;
                if (word == "night" && r.Int(1, 100000, _nightA))
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
            _last = 0; _wasBelow = false; _elapsed = 0; _freeLeft = 0; _nextCrit = false; _nextSure = false;
            _armedAt = 0; _row = 0; _idleSince = 0;
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
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
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
            // UN SORT OU UNE COMPETENCE QUI PORTE consomme l'etat : son aura
            // donne cent pour cent de critique a TOUT (aura 290), le coup est
            // donc bien le critique promis. Un sort qui rate n'inflige rien et
            // ne passe pas ici : l'etat tient, et rien n'est du. La passe
            // d'armes ordinaire, elle, se regle dans OnMeleeRoll.
            if (spell && (_nextCrit || _nextSure) && player->HasAura(_spellId)
                && _armedAt != uint32(GameTime::GetGameTimeMS().count()))
                Spend(player);
            if (_event == "hit" || (_event == "hit_spell" && spell))
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
                           uint32 /*spellId*/) override
        {
            if (_event == "dmg_taken" || (_event == "dmg_taken_phys" && !spell) || (_event == "dmg_taken_magic" && spell))
                Fire(player, attacker, damage);
            // DANS LE DOS : l'assaillant n'est pas dans le demi-cercle que le
            // joueur a devant lui.
            else if (_event == "dmg_taken_back" && attacker && !player->HasInArc(float(M_PI), attacker))
                Fire(player, attacker, damage);
        }
        void OnHealDone(Player* player, Unit* target, uint32& gain) override
        {
            // LE SOIN QUI VIENT DE PARTIR, dans son propre souvenir : le
            // marqueur du critique de soin arrive juste apres et ne sait rien
            // de lui-meme -- ni sur qui le soin est alle, ni de combien. Le
            // montant est celui du SORT, non ce qu'il a rendu : une cible a
            // pleine vie donne donc un bouclier plein.
            if (target)
                _lastHealed = target->GetGUID();
            _lastHealAmount = gain;
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
            uint32 const id = spell->GetSpellInfo()->Id;
            if (id >= STELLAR_TAROT_MARKER_FIRST && id <= STELLAR_TAROT_MARKER_LAST)
            {
                // LE MARQUEUR EST-IL LE MIEN ? Dix marqueurs servent vingt-cinq
                // lignes : le nom de l'evenement ne suffit pas a les distinguer,
                // et deux cartes qui guettent le meme evenement feraient evaluer
                // chaque ligne deux fois. Le coeur attache au lancement l'AURA
                // qui l'a demande (AuraEffect::HandleProcTriggerSpellAuraProc
                // passe `this` a CastSpell) : c'est elle qui nomme la ligne.
                SpellInfo const* const par = spell->GetTriggeredByAuraSpellInfo();
                if (!par || int32(par->Id) != _trigger)
                    return;
                // LE MARQUEUR VIENT JUSTE APRES CE QUI L'A FAIT PARTIR, et il
                // ne dit rien de lui-meme : sa cible implicite est le lanceur.
                // Un marqueur de SOIN prend donc le soigne et le montant du
                // soin ; tout autre prend l'unite frappee et le coup porte.
                bool const duSoin = _event == "heal_crit";
                uint32 const combien = duSoin ? _lastHealAmount : _lastAmount;
                // LE COEUR A DEJA CHOISI L'UNITE : il lance le marqueur SUR
                // elle -- le soigne, l'unite frappee, l'assaillant -- comme
                // « Guerison ancestrale » du chaman pose sa reduction de degats
                // sur la cible du soin critique. La cible du marqueur fait donc
                // foi ; le souvenir du module n'est qu'un repli, pour le jour
                // ou elle aurait disparu.
                Unit* vise = spell->m_targets.GetUnitTarget();
                if (!vise)
                {
                    ObjectGuid const qui = duSoin ? _lastHealed : _lastVictim;
                    vise = qui ? ObjectAccessor::GetUnit(*player, qui) : nullptr;
                }
                Fire(player, vise, combien);
                return;
            }
            if (spell->IsTriggered())
                return;
            SpellInfo const* const info = spell->GetSpellInfo();
            // The free cast: the state's own aura takes the cost away (-100%),
            // so the spell is already free; the state goes when it is used.
            if (_action == "free_next" && _freeLeft > 0)
            {
                if (!player->HasAura(_spellId))
                    _freeLeft = 0;                               // the state ran out
                else if (info->ManaCost > 0 || info->ManaCostPercentage > 0)
                {
                    if (--_freeLeft <= 0)
                    {
                        _freeLeft = 0;
                        Spend(player);
                    }
                }
            }
            // The next spell at a lower cost: the state goes when it is used.
            if (_action == "cost_next" && player->HasAura(_spellId)
                && (info->ManaCost > 0 || info->ManaCostPercentage > 0))
                Spend(player);
            // Le sort instantane que l'etat vient d'offrir : son temps d'incan-
            // tation a deja ete lu par Spell::prepare, l'etat a servi.
            if (_action == "next_instant" && player->HasAura(_spellId)
                && _armedAt != uint32(GameTime::GetGameTimeMS().count()))
                Spend(player);
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
            if (fires)
            {
                _lastCast = spell;
                Fire(player, spell->m_targets.GetUnitTarget(), 0);
                _lastCast = nullptr;
            }
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
        // UNE MORT AUX ALENTOURS, de la main de n'importe qui : la ligne dit
        // sa portee, et c'est ici qu'on la mesure.
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
        void OnZone(Player* player, uint32 /*zone*/, uint32 /*area*/) override { if (_event == "zone") Fire(player, nullptr, 0); }
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
            if (_event != "loot_creature" || !loot)
                return;
            if (_action == "crate")
            {
                if (!Ready(player))
                    return;
                loot->AddItem(LootStoreItem(STELLAR_TAROT_ITEM_CRATE, 0, 100.0f, false,
                                            LOOT_MODE_DEFAULT, 0, 1, 1));
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
                static uint32 const outreterre[] = { 32227, 32228, 32229, 32230, 32231, 32249 };
                static uint32 const norfendre[] = { 36919, 36922, 36925, 36928, 36931, 36934 };
                MapEntry const* const carte = player->GetMap() ? player->GetMap()->GetEntry() : nullptr;
                uint32 const ere = carte ? carte->expansionID : 0;
                uint32 const gemme = ere == 1 ? outreterre[urand(0, 5)]
                                   : ere >= 2 ? norfendre[urand(0, 5)]
                                              : 12800;
                if (!Ready(player))
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
                player->SendNewItem(copy, count, true, false);
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
        }
        // Une vente : le marchand paie le double. L'objet est nomme quand il
        // part, la somme n'arrive qu'ensuite -- la ligne s'arme ici et agit sur
        // le mouvement d'argent qui suit.
        void OnSellItem(Player* player, Item* /*item*/) override
        {
            if (_event == "vendor_sell" && _action == "gold_mult" && Ready(player))
                _selling = true;
        }
        void OnMoneyChanged(Player* player, int32& amount) override
        {
            if (!_selling || amount <= 0)
                return;
            amount = int32(std::min<int64>(int64(amount) * int64(_a), 2000000000LL));
            _selling = false;
            Pay(player);
        }
        void OnMeleeRoll(Player* player, Unit* /*victim*/, int32& crit, int32& miss, int32& dodge, int32& parry, int32& block) override
        {
            if (!_nextCrit && !_nextSure)
                return;
            // Unit::CalculateMeleeDamage hands the damage to the scripts BEFORE
            // it rolls the swing's outcome: a state a hit has just armed would
            // be spent by that very swing, the aura gone before it is seen. It
            // waits for the next swing -- a later world tick.
            if (_armedAt == uint32(GameTime::GetGameTimeMS().count()))
                return;
            bool const held = player->HasAura(_spellId);         // the state ran out with its aura
            // The chances are in hundredths of a percent (RollMeleeOutcomeAgainst).
            if (!held)                                       // l'aura n'est plus la
            {
                _nextCrit = false; _nextSure = false;
                return;
            }
            if (_nextCrit) { crit = 10000; miss = 0; }
            if (_nextSure) { dodge = 0; parry = 0; block = 0; miss = 0; }
            Spend(player);
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
            if (!_coreChance && _chance < 100 && int32(urand(1, 100)) > _chance)
                return false;
            _last = nowMs;
            return true;
        }
        // Le revers paye AVEC le bienfait : seulement quand aucune chance propre
        // ne lui a ete donnee, sinon il s'est deja joue sur l'evenement.
        void Pay(Player* player)
        {
            if (_costKind.empty() || _costChance < 100)
                return;
            // UN ETAT N'A ENCORE RIEN DONNE quand il se pose : il promet. Son
            // prix attend le coup qu'il rend critique, ou la depense qu'il rend
            // gratuite -- Spend() le paie alors. Une attaque ratee de plus ne
            // coute donc rien au joueur.
            if (State())
                return;
            Suffer(player);
        }
        // L'etat vient de servir : il s'efface et son prix tombe.
        void Spend(Player* player)
        {
            _nextCrit = false; _nextSure = false;
            RemoveOwned(player, _spellId);
            if (!_costKind.empty() && _costChance >= 100)
                Suffer(player);
        }
        // LE REVERS SE PAIE APRES COUP. Un demi-tour d'horloge separe le
        // bienfait de sa contrepartie : le coup part, le chiffre s'affiche, le
        // geste se joue, PUIS le joueur en paie le prix. Un revers immediat
        // tombe dans la meme image que le coup -- le client remplace l'anima-
        // tion de l'attaque par celle de l'etourdissement, et la carte semble
        // punir sans avoir rien donne.
        static constexpr uint32 REVERS_DELAI_MS = 500;
        void Suffer(Player* player)
        {
            // Ce qui ne coupe rien tombe tout de suite, avec le bienfait.
            if (!CostInterrupts(_costKind))
            {
                StellarTarotEffects::CompteRevers(player, _spellId);
                if (_costKind == "self_hit")
                    Hurt(player, player, PctOf(_lastAmount, _costN), SPELL_SCHOOL_MASK_NORMAL,
                         STELLAR_TAROT_SPELL_PRICE);
                else
                    // LES REVERS QUI COMPTENT LES CUMULS lisent celui du
                    // bienfait, retenu a la pose.
                    Cost(player, _costKind, _costN, _costN2, _spellId, uint32(_costSpell),
                         _lastStacks);
                return;
            }
            ObjectGuid const who = player->GetGUID();
            std::string const kind = _costKind;
            int32 const n = _costN, n2 = _costN2, spell = int32(_spellId), mark = _costSpell;
            uint32 const amount = _lastAmount;
            player->m_Events.AddEventAtOffset([who, kind, n, n2, spell, mark, amount]()
            {
                Player* const p = ObjectAccessor::FindPlayer(who);
                if (!p)
                    return;
                if (kind == "self_hit")
                {
                    Hurt(p, p, PctOf(amount, n), SPELL_SCHOOL_MASK_NORMAL, STELLAR_TAROT_SPELL_PRICE);
                    return;
                }
                Cost(p, kind, n, n2, uint32(spell), uint32(mark));
            }, Milliseconds(REVERS_DELAI_MS));
        }
        void Fire(Player* player, Unit* other, uint32 amount)
        {
            // UN REVERS A CHANCE PROPRE se tire sur l'evenement lui-meme : la
            // carte promet deux choses independantes (« peut doubler les
            // degats MAIS peut vous toucher »), pas une contrepartie payee
            // seulement quand le bienfait tombe.
            if (_costChance < 100 && !_costKind.empty())
            {
                _lastAmount = amount ? amount : _lastAmount;
                if (int32(urand(1, 100)) <= _costChance)
                    Suffer(player);
            }
            if (!Ready(player))
                return;
            // L'INSTRUMENT DE MESURE : un depart de plus pour cette ligne.
            StellarTarotEffects::CompteDepart(player, _spellId);
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
                if (_ratingPct && A == "aura" && LayRatingShare(player, _spellId, _ratingParts, _a))
                    return;
                if (_spPct && A == "aura")
                {
                    RemoveOwned(player, _spellId);
                    int32 const own = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC));
                    int32 const bp = int32(std::llround(double(own) * _spPct / 100.0)) - 1;
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
                    ObjectGuid const me = player->GetGUID();
                    uint32 const spell = _thenSpell ? uint32(_thenSpell) : _spellId;
                    uint32 const first = _spellId;
                    int32 const pct = _thenPct, sec = _thenSec;
                    player->m_Events.AddEventAtOffset([me, spell, first, pct, sec]()
                    {
                        Player* const p = ObjectAccessor::FindPlayer(me);
                        if (!p)
                            return;
                        p->RemoveAurasDueToSpell(first, p->GetGUID());
                        p->RemoveAurasDueToSpell(spell, p->GetGUID());
                        int32 const bp = pct - 1;       // le de du sort ajoute le dernier point
                        p->CastCustomSpell(p, spell, &bp, &bp, &bp, true);
                        if (Aura* second = p->GetAura(spell, p->GetGUID()))
                        {
                            second->SetMaxDuration(sec * 1000);
                            second->SetDuration(sec * 1000);
                        }
                    }, Seconds(_a));
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
            else if (A == "leech") Heal(player, player, PctOf(amount, _a), _spellId);
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
            else if (A == "heal_group")
            {
                for (Player* member : GroupAround(player, float(_b)))
                    Heal(player, member, PctOf(member->GetMaxHealth(), _a), _spellId);
            }
            else if (A == "heal_ally_amount")
            {
                // The most injured group member in range, the healed one left out.
                Player* pick = nullptr;
                for (Player* member : GroupAround(player, float(_b)))
                    if (member != other && (!pick || member->GetHealthPct() < pick->GetHealthPct()))
                        pick = member;
                if (pick)
                    Heal(player, pick, PctOf(amount, _a), _spellId);
            }
            // LE FAMILIER SOIGNE PAR LE COUP DE SON MAITRE : une part de ce
            // qui vient d'etre inflige, jamais moins d'un point.
            else if (A == "leech_pet")
            {
                Pet* pet = player->GetPet();
                if (!pet || !pet->IsAlive() || !amount)
                    return;
                Heal(player, pet, std::max<uint32>(1, PctOf(amount, _a)), _spellId);
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
            else if (A == "gold_level" || A == "silver_level")
            {
                uint64 const copper = uint64(_a) * (A == "silver_level" ? 100 : 1) * player->GetLevel();
                player->ModifyMoney(int32(copper));
                Owe(player, _spellId, _say ? uint32(_say) : STELLAR_TAROT_STR_BINGO, copper, true);
            }
            else if (A == "copper_per_damage") player->ModifyMoney(int32(std::min<uint64>(uint64(amount) * uint64(_a), 100000000ULL)));
            else if (A == "shield_self" || A == "shield_target")
            {
                int32 const bp = int32(A == "shield_self" ? PctOf(player->GetMaxHealth(), _a) : PctOf(amount, _a));
                Unit* who = A == "shield_self" ? player : other;
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
                Hurt(player, other, PctOf(amount, _a),
                     uint32(_b ? _b : (_lastSchool ? _lastSchool : uint32(SPELL_SCHOOL_MASK_NORMAL))), _spellId);
            else if (A == "damage_sp" || A == "damage_ap")
            {
                uint32 const base = A == "damage_sp" ? uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)))
                                                     : uint32(player->GetTotalAttackPowerValue(BASE_ATTACK));
                Hurt(player, other, PctOf(base, _a), uint32(_b), _spellId);
            }
            // CE QUE LE LANCEUR PORTE EN LUI : la cible encaisse une part des
            // points de vie maximum du joueur, dans l'ecole nommee (32, l'ombre,
            // a defaut).
            else if (A == "hp_dmg")
            {
                if (!other)
                    return;
                Hurt(player, other, PctOf(player->GetMaxHealth(), _a), uint32(_b ? _b : 32), _spellId);
            }
            else if (A == "splash" || A == "explode" || A == "explode_sp")
            {
                if (!other)
                    return;
                uint32 dmg = 0;
                if (A == "splash") dmg = PctOf(amount, _a);
                else if (A == "explode") dmg = PctOf(amount, _a);           // amount = the victim's max health on a kill
                else dmg = PctOf(uint32(std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC))), _a);
                uint32 const school = A == "explode_sp" ? uint32(_c ? _c : 64) : 1;
                if (A == "explode" && other->IsCreature() && IsBoss(other->ToCreature()))
                    return;
                player->CastSpell(player, school == 1 ? STELLAR_TAROT_SPELL_VISUAL_PHYS : STELLAR_TAROT_SPELL_VISUAL_MAGIC, true);
                for (Unit* unit : HostilesAround(player, other, float(_b), other))
                    Hurt(player, unit, dmg, school, _spellId);
            }
            else if (A == "cleave")
            {
                for (Unit* unit : HostilesAround(player, player, float(_b), other))
                    if (player->HasInArc(float(M_PI), unit))
                        Hurt(player, unit, PctOf(amount, _a), 1, _spellId);
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
                ObjectGuid const who = player->GetGUID(), beast = turned->GetGUID();
                player->m_Events.AddEventAtOffset([who, beast]()
                {
                    Player* const p = ObjectAccessor::FindPlayer(who);
                    if (!p)
                        return;
                    Unit* const u = ObjectAccessor::GetUnit(*p, beast);
                    if (!u || !u->IsCreature())
                        return;
                    u->RestoreFaction();
                    u->GetThreatMgr().ClearAllThreat();
                    if (u->IsAlive() && u->ToCreature()->AI())
                        u->ToCreature()->AI()->AttackStart(p);
                }, Seconds(_a));
            }
            else if (A == "fear") Put(player, other, STELLAR_TAROT_SPELL_FEAR, _a);
            else if (A == "sleep") Put(player, other, STELLAR_TAROT_SPELL_SLEEP, _a);
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
            else if (A == "free_next") { _freeLeft = _a; Put(player, player, _spellId, 20); }
            else if (A == "cost_next") Put(player, player, _spellId, 20);
            // LE PROCHAIN SORT PART SANS DELAI : l'aura porte le modificateur
            // de temps d'incantation, elle tient jusqu'a ce qu'un sort la
            // depense -- et le revers tombe alors, donc APRES le sort.
            else if (A == "next_instant")
            {
                _armedAt = uint32(GameTime::GetGameTimeMS().count());
                Put(player, player, _spellId, 0);
            }
            else if (A == "next_crit" || A == "next_sure")
            {
                if (A == "next_crit") _nextCrit = true; else _nextSure = true;
                _armedAt = uint32(GameTime::GetGameTimeMS().count());
                // L'ETAT TIENT JUSQU'A CE QU'IL SERVE : il promet le prochain
                // coup, pas les vingt prochaines secondes. Une attaque ratee de
                // plus ne le consomme pas -- rien n'a ete donne, rien n'est du.
                Put(player, player, _spellId, 0);
            }
            else if (A == "recast")
            {
                if (_lastCast && _lastCast->GetSpellInfo())
                    player->CastSpell(other ? other : player, _lastCast->GetSpellInfo()->Id, true);
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
                ObjectGuid const who = player->GetGUID();
                int32 const share = _a;
                player->m_Events.AddEventAtOffset([who, share]()
                {
                    Player* p = ObjectAccessor::FindPlayer(who);
                    if (!p || p->IsAlive())
                        return;
                    p->ResurrectPlayer(0.0f);
                    p->SetHealth(std::max<uint32>(1, PctOf(p->GetMaxHealth(), share)));
                    p->SetPower(POWER_MANA, 0);
                    p->SpawnCorpseBones();
                }, Milliseconds(1));
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
        std::string _event, _action, _costKind;
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
        std::vector<int32> _ratingParts;
        int32 _debuffSpell = 0;
        uint32 _lastSpellId = 0, _mirrorSpell = 0, _mirrorAmount = 0;
        bool _peaceSpent = false;
        uint32 _idleSince = 0;
        int32 _chance = 100, _icd = 0, _a = 0, _b = 0, _c = 0, _trigger = 0, _costN = 0, _freeLeft = 0;
        int32 _costN2 = 0, _costChance = 100, _costSpell = 0;
        int32 _nightA = 0, _say = 0, _emote = 0, _thenPct = 0, _thenSec = 0, _thenSpell = 0;
        uint32 _seqUntil = 0;
        bool _onlyNight = false, _onlyDark = false;
        ObjectGuid _lastVictim;
        uint32 _lastAmount = 0;
        // LE SOIN A SON PROPRE SOUVENIR : le soigne et le montant du sort. Sans
        // cela, le marqueur d'un critique de soin lisait celui d'un coup porte.
        ObjectGuid _lastHealed;
        uint32 _lastHealAmount = 0;
        uint32 _last = 0, _elapsed = 0, _armedAt = 0, _lastSchool = 0;
        bool _wasBelow = false, _nextCrit = false, _nextSure = false, _wasFlying = false, _selling = false;
        bool _wasMounted = false;
        Spell* _lastCast = nullptr;
    };

    // =========================================================================
    // dmgmod:<target condition>[:n]:<pct>
    // =========================================================================
    class DmgMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _cond = r.Word();
            static char const* const plain[] = { "stunned", "alone", "full_hp", "humanoid", "slowed", "burning" };
            bool known = false;
            for (char const* c : plain)
                if (_cond == c) known = true;
            if (_cond == "hp_above" || _cond == "hp_below" || _cond == "range_over")
            {
                known = true;
                if (!r.Int(1, 100, _n)) { error = _cond + " expects a number"; return false; }
            }
            if (!known) { error = "unknown target condition \"" + _cond + "\""; return false; }
            if (!r.Int(-100, 100000, _pct))
                return (error = "expects the percentage", false);
            // l'école, facultative : 0 ou absente, toutes les écoles
            r.OptInt(0, 127, _school);
            return r.End() || (error = "after the percentage, only the school may follow", false);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool /*spell*/, uint32 school,
                           uint32 spellId) override
        {
            if (_school && !(school & uint32(_school)))
                return;
            if (victim && Meets(player, victim, spellId))
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        int32 _school = 0;

        // An aura born within the second of the blow being counted: the blow
        // laid it itself. The hour of an aura is fixed at its creation and a
        // renewal does not move it.
        static bool JustLaid(AuraEffect const* eff)
        {
            Aura const* aura = eff->GetBase();
            return aura && aura->GetApplyTime() >= GameTime::GetGameTime().count();
        }

        bool Meets(Player* player, Unit* v, uint32 /*spellId*/ = 0)
        {
            // « Cible étourdie » : toute immobilisation -- étourdissement,
            // renversement (un étourdissement lui aussi) et enracinement --
            // mais jamais un simple ralentissement.
            if (_cond == "stunned")
                return v->HasUnitState(UNIT_STATE_STUNNED) || v->HasUnitState(UNIT_STATE_ROOT)
                    || v->HasAuraType(SPELL_AURA_MOD_STUN) || v->HasAuraType(SPELL_AURA_MOD_ROOT);
            if (_cond == "alone") return v->getAttackers().size() <= 1;
            if (_cond == "full_hp") return v->GetHealth() >= v->GetMaxHealth();
            if (_cond == "hp_above") return v->GetHealthPct() > float(_n);
            if (_cond == "hp_below") return v->GetHealthPct() < float(_n);
            if (_cond == "humanoid") return v->GetCreatureType() == CREATURE_TYPE_HUMANOID;
            if (_cond == "range_over") return player->GetDistance(v) > float(_n);
            if (_cond == "slowed")
            {
                for (AuraEffect const* eff : v->GetAuraEffectsByType(SPELL_AURA_MOD_DECREASE_SPEED))
                    if (!JustLaid(eff))
                        return true;
                return v->HasUnitState(UNIT_STATE_ROOT);
            }
            if (_cond == "burning")
            {
                for (AuraEffect const* eff : v->GetAuraEffectsByType(SPELL_AURA_PERIODIC_DAMAGE))
                {
                    if (!(eff->GetSpellInfo()->GetSchoolMask() & SPELL_SCHOOL_MASK_FIRE))
                        continue;
                    // A spell lays its aura before its damage is counted, so a
                    // burn born of this very blow does not pay for itself. One
                    // laid earlier does, even when this blow renews it.
                    if (JustLaid(eff))
                        continue;
                    return true;
                }
                return false;
            }
            return false;
        }
        std::string _cond;
        int32 _n = 0, _pct = 0;
    };

    // =========================================================================
    // wandmod:<chance>:<pct>[:hp_below:<n>]
    //
    // What a wand shot is worth: the shot itself, not the target's state --
    // dmgmod reads the target, this one reads the blow.
    // =========================================================================
    class WandMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance) || !r.Int(-100, 100000, _pct))
                return (error = "expects the chance then the percentage", false);
            if (!r.End())
            {
                if (r.Word() != "hp_below")
                    return (error = "after the percentage, only hp_below may follow", false);
                if (!r.Int(1, 100, _hpBelow))
                    return (error = "hp_below expects a number", false);
            }
            return r.End() || (error = "too many parameters", false);
        }
        void OnDamageDealt(Player* player, Unit* victim, uint32& damage, bool spell, uint32 /*school*/,
                           uint32 spellId) override
        {
            if (!spell || !victim || !damage || !IsWandBlow(player, spellId))
                return;
            if (_hpBelow && victim->GetHealthPct() >= float(_hpBelow))
                return;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return;
            damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        int32 _chance = 100, _pct = 0, _hpBelow = 0;
    };
    // =========================================================================
    // takenmod:<condition>:<pct>
    // =========================================================================
    class TakenMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _cond = r.Word();
            if (_cond != "alone" && _cond != "controlled" && _cond != "charmed" && _cond != "back")
            { error = "unknown condition \"" + _cond + "\""; return false; }
            if (!r.Int(-100, 1000, _pct))
                return (error = "expects the percentage", false);
            r.OptInt(0, 127, _school);
            return r.End() || (error = "after the percentage, only the school may follow", false);
        }
        void OnDamageTaken(Player* player, Unit* attacker, uint32& damage, bool /*spell*/, uint32 school,
                           uint32 /*spellId*/) override
        {
            if (_school && !(school & uint32(_school)))
                return;
            bool meets = false;
            if (_cond == "alone") meets = player->getAttackers().size() <= 1;
            // DANS LE DOS : le coup vient de derriere, hors du demi-cercle que
            // le joueur a devant lui -- le meme compas que l'evenement
            // `dmg_taken_back`.
            if (_cond == "back") meets = attacker && !player->HasInArc(float(M_PI), attacker);
            if (_cond == "controlled") meets = player->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_ROOT | UNIT_STATE_FLEEING | UNIT_STATE_CONFUSED);
            // La peur et le charme, et rien d'autre : l'esprit qu'on lui prend.
            if (_cond == "charmed") meets = player->HasUnitState(UNIT_STATE_FLEEING | UNIT_STATE_CHARMED);
            if (meets)
                damage = uint32(std::llround(double(damage) * (100 + _pct) / 100.0));
        }
    private:
        std::string _cond;
        int32 _pct = 0, _school = 0;
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
            RemoveOwned(player, _spellId);
            _applied = bonus;
            // LE CHIFFRE VA AUX EFFETS QUI PORTENT LA PUISSANCE DES SORTS, ou
            // qu'ils soient dans le sort : le niveau peut en porter un autre
            // -- un modificateur de cout, par exemple -- qui garde la valeur
            // que le generateur lui a ecrite. Et cet autre effet a de bonnes
            // raisons d'occuper le premier rang : le client ne lit droit le
            // masque de classe d'un modificateur que la.
            int32 const bp = bonus - 1;         // the spell's die side adds the last point
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (info && (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE
                          || info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_HEALING_DONE))
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
            RemoveOwned(player, _spellId);
            _applied = total;
            int32 bp[MAX_SPELL_EFFECTS] = { 0, 0, 0 };
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (amounts[i])
                {
                    bp[i] = amounts[i] - 1;      // le de du sort ajoute le dernier point
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
            RemoveOwned(player, _spellId);
            _applied = bonus;
            int32 const bp = bonus - 1;
            SpellInfo const* const info = sSpellMgr->GetSpellInfo(_spellId);
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (info && (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE
                          || info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_HEALING_DONE))
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
            RemoveOwned(player, _spellId);
            int32 bp[MAX_SPELL_EFFECTS];
            int32 const* p[MAX_SPELL_EFFECTS] = { nullptr, nullptr, nullptr };
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            {
                _applied[i] = want[i];
                bp[i] = want[i] - 1;        // the spell's die side adds the last point
                if (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_RATING)
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
            RemoveOwned(player, _spellId);
            _applied = want;
            _has = true;
            // One short: the spell's die side adds the last point, the way the
            // generator writes every figure.
            int32 const bp = want - 1;
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
            RemoveOwned(player, _spellId);
            _applied = want;
            _has = true;
            int32 const bp = want - 1;       // the spell's die side adds the last point
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
            if (_kind == "heal_self" ? target != player : target->GetHealthPct() > float(_hp))
                return;
            int32 const back = int32(PctOf(uint32(std::max(0, spell->GetPowerCost())), _pct));
            if (back <= 0)
                return;
            // LA RISTOURNE SE VOIT : rendue par le sort du niveau, elle passe
            // par le journal du client et monte dans le texte defilant, au lieu
            // d'arriver en silence.
            ObjectGuid const guid = player->GetGUID();
            uint32 const spellId = _spellId;
            player->m_Events.AddEventAtOffset([guid, back, spellId]()
            {
                if (Player* p = ObjectAccessor::FindPlayer(guid))
                    p->EnergizeBySpell(p, spellId, back, POWER_MANA);
            }, Milliseconds(1));
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
    void TellClient(Player* player, char const* prefix, std::string const& message)
    {
        if (!player || !player->GetSession())
            return;
        std::string const full = std::string(prefix) + "\t" + message;
        WorldPacket data(SMSG_MESSAGECHAT, 100);
        data << uint8(CHAT_MSG_WHISPER);
        data << int32(LANG_ADDON);
        data << player->GetGUID();
        data << uint32(0);
        data << player->GetGUID();
        data << uint32(full.length() + 1);
        data << full;
        data << uint8(0);
        player->GetSession()->SendPacket(&data);
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
            int32 const bp = parTic - 1;        // le de du sort ajoute le dernier point
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
            return (r.Int(1, 100, _chance) && r.End())
                || (error = "expects the chance", false);
        }

        void OnSpellCast(Player* player, Spell* spell) override
        {
            ItemTemplate const* const proto = CastItemOf(spell);
            if (!player || !IsPotionItem(proto))
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
    };

    // =========================================================================
    // elixirlong:<pct>
    //     LES ELIXIRS TIENNENT PLUS LONGTEMPS. L'aura dit elle-meme de quel
    //     objet elle vient : il suffit de regarder si c'est un elixir -- ni une
    //     potion, ni un flacon -- et de lui donner sa part de temps en plus,
    //     au moment ou elle se pose.
    // =========================================================================
    class ElixirLong : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 1000, _pct) && r.End())
                || (error = "expects the percentage", false);
        }

        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override
        {
            if (!aura || target != player)
                return;
            ItemTemplate const* const proto = sObjectMgr->GetItemTemplate(aura->GetCastItemEntry());
            if (!proto || proto->Class != ITEM_CLASS_CONSUMABLE || proto->SubClass != ITEM_SUBCLASS_ELIXIR)
                return;
            int32 const duree = aura->GetMaxDuration();
            if (duree <= 0)
                return;
            int32 const plus = int32(PctOf(uint32(duree), _pct));
            if (!plus)
                return;
            aura->SetMaxDuration(duree + plus);
            aura->SetDuration(aura->GetDuration() + plus);
        }

    private:
        int32 _pct = 0;
    };

    // =========================================================================
    // dotlong:<school>:<ticks>
    //     A periodic effect of that school, laid by the player, lasts that many
    //     TICKS longer -- its own period, so the extra time always pays: two
    //     seconds added to a three-second period would buy nothing. Caught as
    //     the aura is applied.
    // =========================================================================
    class DotLong : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 127, _school) && r.Int(1, 20, _ticks) && r.End())
                || (error = "expects the school then the number of ticks", false);
        }
        // A spell with a travel time lays its aura long after the cast is
        // announced: the moment the aura appears is the one to catch.
        void OnAuraApplied(Player* /*player*/, Unit* /*target*/, Aura* aura) override
        {
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info || !(info->GetSchoolMask() & uint32(_school)))
                return;
            if (!info->HasAura(SPELL_AURA_PERIODIC_DAMAGE) || aura->GetMaxDuration() <= 0)
                return;
            // The period of the effect itself: a tick more means that much more.
            int32 period = 0;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (AuraEffect const* eff = aura->GetEffect(i))
                    if (eff->GetAuraType() == SPELL_AURA_PERIODIC_DAMAGE && eff->GetAmplitude() > 0)
                    {
                        period = eff->GetAmplitude();
                        break;
                    }
            if (period <= 0)
                return;
            int32 const more = period * _ticks;
            aura->SetMaxDuration(aura->GetMaxDuration() + more);
            aura->SetDuration(aura->GetDuration() + more);
        }

    private:
        int32 _school = 0, _ticks = 0;
    };

    // =========================================================================
    // stunlong:<sec>
    //     Les ETOURDISSEMENTS que le joueur inflige durent ce nombre de
    //     secondes de plus. Pris au moment ou l'aura se pose, comme dotlong :
    //     un sort a projectile etourdit longtemps apres avoir ete lance.
    // =========================================================================
    class StunLong : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 60, _sec))
                return (error = "expects the seconds", false);
            return ReadDrawback(r, _but, error);
        }
        void OnAuraApplied(Player* player, Unit* target, Aura* aura) override
        {
            if (!target || target == player || aura->GetMaxDuration() <= 0)
                return;
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info)
                return;
            bool stun = info->HasAura(SPELL_AURA_MOD_STUN);
            if (!stun)
                for (uint8 i = 0; i < MAX_SPELL_EFFECTS && !stun; ++i)
                    stun = info->Effects[i].Mechanic == MECHANIC_STUN;
            if (!stun && info->Mechanic != MECHANIC_STUN)
                return;
            int32 const more = _sec * 1000;
            aura->SetMaxDuration(aura->GetMaxDuration() + more);
            aura->SetDuration(aura->GetDuration() + more);
            SufferDrawback(player, _but, _spellId, 0);
        }
    private:
        int32 _sec = 0;
        Drawback _but;
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
            return (r.Int(1, 10, _times) && r.End())
                || (error = "expects how many more draws", false);
        }
        void OnObjectLoot(Player* player, Loot* loot, LootTemplate const* tab, LootStore const* store) override
        {
            if (!loot || !tab || !store)
                return;
            for (int32 i = 0; i < _times; ++i)
                tab->Process(*loot, *store, LOOT_MODE_DEFAULT, player);
        }
    private:
        int32 _times = 0;
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
            if (uint32 const entry = _what == "chest" ? ChestFor(player) : PearlFor(player))
                loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
        }

    private:
        // L'age du lieu : l'extension a laquelle la carte du monde appartient.
        static uint32 Age(Player* player)
        {
            MapEntry const* const carte = player->GetMap() ? player->GetMap()->GetEntry() : nullptr;
            return carte ? uint32(carte->expansionID) : 0u;
        }
        // LE COFFRE QUE LA PECHE DONNE D'ELLE-MEME : la caisse detrempee sur le
        // vieux monde, la caisse curieuse en Outreterre, la caisse renforcee en
        // Norfendre. Aucune n'est verrouillee : le joueur l'ouvre sans clef.
        static uint32 ChestFor(Player* player)
        {
            uint32 const age = Age(player);
            return age == 1 ? 27513u : age >= 2 ? 44475u : 6352u;
        }
        // LA PERLE QUE LE LIEU APPELLE, comme la gemme du cadavre : les quatre
        // du vieux monde, la jaggale ou celle d'ombre en Outreterre, celle de
        // la mer du Nord en Norfendre.
        static uint32 PearlFor(Player* player)
        {
            static uint32 const vieux[] = { 5498, 5500, 7971, 13926 };
            static uint32 const outreterre[] = { 24478, 24479 };
            uint32 const age = Age(player);
            return age == 1 ? outreterre[urand(0, 1)]
                 : age >= 2 ? 36783u
                            : vieux[urand(0, 3)];
        }
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
            ObjectGuid const who = player->GetGUID();
            player->m_Events.AddEventAtOffset([who, cut]()
            {
                if (Player* const p = ObjectAccessor::FindPlayer(who))
                    p->ModifySpellCooldown(HEARTHSTONE, -cut);
            }, Milliseconds(1));
        }
    private:
        static constexpr uint32 HEARTHSTONE = 8690;
        int32 _pct = 0;
    };

    // =========================================================================
    // shoutlong:<facteur>
    //     LES CRIS du joueur durent ce nombre de fois plus longtemps. Un cri
    //     se reconnait a son nom anglais -- Shout, Howl, Scream, Roar : le
    //     coeur ne range ces sorts sous aucune famille qui les reunisse, et
    //     la carte parle bien de « cris et hurlements ». Le nom lu est celui
    //     de l'index 0 du DBC, l'anglais, quelle que soit la langue du client.
    // =========================================================================
    class ShoutLong : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(2, 100, _factor))
                return (error = "expects the factor", false);
            return ReadDrawback(r, _but, error);
        }
        void OnAuraApplied(Player* player, Unit* /*target*/, Aura* aura) override
        {
            if (!aura || aura->GetMaxDuration() <= 0)
                return;
            SpellInfo const* const info = aura->GetSpellInfo();
            if (!info || !info->SpellName[0])
                return;
            std::string const name = info->SpellName[0];
            static char const* const cries[] = { "Shout", "Howl", "Scream", "Roar" };
            bool cry = false;
            for (char const* w : cries)
                if (name.find(w) != std::string::npos)
                    cry = true;
            if (!cry)
                return;
            int32 const want = aura->GetMaxDuration() * _factor;
            aura->SetMaxDuration(want);
            aura->SetDuration(want);
            SufferDrawback(player, _but, _spellId, 0);
        }
    private:
        int32 _factor = 0;
        Drawback _but;
    };

    // =========================================================================
    // tickmod:<chance>:<pct>
    // =========================================================================
    class TickMod : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            if (!r.Int(1, 100, _chance) || !r.Int(1, 1000, _pct))
                return (error = "expects the chance then the percentage", false);
            if (!r.End())
            {
                if (r.Word() != "onlynight" || !r.End())
                    return (error = "after the percentage, only onlynight may follow", false);
                _onlyNight = true;
            }
            return true;
        }
        void OnPeriodicTick(Player* /*player*/, Unit* /*other*/, uint32& amount, bool /*heal*/,
                            uint32 /*spellId*/) override
        {
            if (!amount || (_onlyNight && !IsNight()) || int32(urand(1, 100)) > _chance)
                return;
            amount += PctOf(amount, _pct);
        }

    private:
        int32 _chance = 0, _pct = 0;
        bool _onlyNight = false;
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
            static char const* const kinds[] = { "gold_loot", "xp", "xp_other", "rep", "quest_gold", "repair",
                                                 "vendor_buy", "vendor_sell", "vendor_sell_grey", "vendor_sell_good" };
            bool known = false;
            for (char const* k : kinds)
                if (_kind == k) known = true;
            if (!known) { error = "unknown kind \"" + _kind + "\""; return false; }
            if (!r.Int(-100, 10000, _pct))
                return (error = "expects the percentage", false);
            // UNE SECONDE MONNAIE, quand la carte en promet deux d'un coup :
            // « and:<genre>:<part> ». Elle n'a ni palier ni plafond -- ceux-ci
            // restent au premier genre, qui seul les porte.
            if (!r.End() && r.Peek() == "and")
            {
                r.Word();
                _kind2 = r.Word();
                bool ok2 = false;
                for (char const* k : kinds)
                    if (_kind2 == k) ok2 = true;
                if (!ok2) { error = "unknown second kind \"" + _kind2 + "\""; return false; }
                if (!r.Int(-100, 10000, _pct2))
                    return (error = "the second kind expects its percentage", false);
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
        bool Has(char const* k) const { return _kind == k || _kind2 == k; }
        int32 PctOf(Player const* player, char const* k) const
        {
            if (_kind == k) return Pct(player);
            return _kind2 == k ? _pct2 : 0;
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
        }
        void OnGiveReputation(Player* player, float& amount) override
        {
            if (Has("rep") && On(player)) amount = amount * float(100 + PctOf(player, "rep")) / 100.0f;
        }
        void OnQuestComplete(Player* player, Quest const* quest) override
        {
            if (Has("quest_gold") && quest)
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
                    int32 const extra = int32(std::llround(double(money) * Pct(player) / 100.0));
                    player->ModifyMoney(extra);
                    if (extra > 0)
                        Owe(player, SpellId(), STELLAR_TAROT_STR_QUEST_GOLD, uint64(extra), true);
                }
            }
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
                _selling = true;
            else if (_kind == "vendor_sell_grey" && item && item->GetTemplate()
                     && item->GetTemplate()->Quality == ITEM_QUALITY_POOR)
                _selling = true;
            else if (_kind == "vendor_sell_good" && item && item->GetTemplate()
                     && item->GetTemplate()->Quality >= ITEM_QUALITY_UNCOMMON)
                _selling = true;
        }
        void OnMoneyChanged(Player* player, int32& amount) override
        {
            if ((_kind == "vendor_sell" || _kind == "vendor_sell_grey" || _kind == "vendor_sell_good")
                && _selling && amount > 0)
            {
                amount = int32(std::llround(double(amount) * (100 + Pct(player)) / 100.0));
                _selling = false;
            }
        }
    private:
        std::string _kind, _kind2, _state;
        int32 _pct = 0, _pct2 = 0, _perGold = 0, _cap = 0;
        bool _selling = false;
    };
}

void StellarTarotScripts::RegisterEngine()
{
    Register("cond", [] { return std::make_unique<Cond>(); });
    Register("proc", [] { return std::make_unique<Proc>(); });
    Register("dmgmod", [] { return std::make_unique<DmgMod>(); });
    Register("wandmod", [] { return std::make_unique<WandMod>(); });
    Register("takenmod", [] { return std::make_unique<TakenMod>(); });
    Register("sp_pct", [] { return std::make_unique<SpellPowerPct>(); });
    Register("schoolsp", [] { return std::make_unique<SchoolSpellPower>(); });
    Register("seal", [] { return std::make_unique<Seal>(); });
    Register("convoy", [] { return std::make_unique<Convoy>(); });
    Register("gempct", [] { return std::make_unique<GemPct>(); });
    Register("stat", [] { return std::make_unique<NightStat>(); });
    Register("costmod", [] { return std::make_unique<CostMod>(); });
    Register("drink", [] { return std::make_unique<Drink>(); });
    Register("fever", [] { return std::make_unique<Fever>(); });
    Register("potion", [] { return std::make_unique<PotionPower>(); });
    Register("potion_keep", [] { return std::make_unique<PotionKeep>(); });
    Register("elixirlong", [] { return std::make_unique<ElixirLong>(); });
    Register("statcond", [] { return std::make_unique<StateStat>(); });
    Register("secondpct", [] { return std::make_unique<SecondaryPct>(); });
    Register("ratingpct", [] { return std::make_unique<RatingPct>(); });
    Register("shoutlong", [] { return std::make_unique<ShoutLong>(); });
    Register("hearthcd", [] { return std::make_unique<HearthCooldown>(); });
    Register("chest_extra", [] { return std::make_unique<ChestExtra>(); });
    Register("prospect", [] { return std::make_unique<Prospect>(); });
    Register("fish", [] { return std::make_unique<Fish>(); });
    Register("ore", [] { return std::make_unique<Ore>(); });
    Register("tickmod", [] { return std::make_unique<TickMod>(); });
    Register("dotlong", [] { return std::make_unique<DotLong>(); });
    Register("stunlong", [] { return std::make_unique<StunLong>(); });
    Register("econ", [] { return std::make_unique<Econ>(); });
    Register("xpkin", [] { return std::make_unique<XpKin>(); });
}

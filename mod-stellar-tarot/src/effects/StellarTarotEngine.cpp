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
 *       mounted:<sec>,
 *       hp_below:<pct>, hp_above:<pct>, mana_below:<pct>, gold_above:<copper>,
 *       hour:<from>:<to>. Then, optionally, stacks:<k>: a stack per period of
 *       the state, up to k (still:5:stacks:5); tick:<sec>:<action>:<n>: that
 *       small action while the state holds; sp:<pct>: the aura carries a spell
 *       power read as a percentage of the player's current one.
 *
 *   proc:<event>:<chance>:<icd>:<action>[:<params>]
 *       On the event, with that chance (percent) and no more often than the
 *       internal cooldown (seconds), the action. Events: kill, kill_boss,
 *       kill_elite, kill_humanoid, hit, hit_melee, hit_spell, dmg_taken,
 *       spell_cast_school:<school mask> (a spell of that school),
 *       dmg_taken_phys, dmg_taken_magic, spell_cast, heal, heal_ally,
 *       enter_combat, leave_combat, levelup, resurrect, zone, quest, hourly,
 *       death_near:<yards> (a creature dies within that many yards, whoever
 *       killed it -- the core tells only the killer, the module finds the
 *       witnesses), enter_instance (the player steps into a dungeon or a raid),
 *       spell_cast_tp (he casts something that carries him away -- a hearth, a
 *       teleport; a portal another opened is not his cast), dmg_taken_back (a
 *       blow from behind), tick:<sec> (in combat), every:<sec>, hp_below:<pct> (when crossed),
 *       mana_below:<pct>, wand (a wand shot lands -- a second shot a card
 *       granted included, except for the line that granted it), vendor_buy
 *       (something bought from a vendor), repair (a repair about to be paid),
 *       flight_end (a taxi has just set the player down; watched every second,
 *       the core announcing nothing), loot_creature (a creature's loot is being
 *       filled -- what a card adds goes in the corpse, not in the bags),
 *       vendor_sell (something sold to a vendor: the sum follows).
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
 *       other unit of a hit or kill event), mana_pm:<thousandths of max mana>,
 *       extra_shot (a second shot of the wand -- the module's own copy of Shoot,
 *       three times as fast, set apart by its identifier so that a granted shot
 *       never grants another), extra_copy (one more of what was just bought,
 *       for nothing), free_repair (the repair costs nothing), crate (the
 *       module's crate of goods, laid in the corpse; what it holds is drawn
 *       when it is opened -- see StellarTarotLoot::FillCrate), grey_item (one
 *       more grey trinket in the corpse), gold_mult:<n> on vendor_sell (the
 *       vendor pays that many times).
 *       THE STATES -- next_crit, next_sure, next_instant, free_next, cost_next
 *       -- promise the NEXT blow or the next cast. Their aura holds until it is
 *       spent, not for a while; what the line costs (`but:`) is paid at that
 *       moment and not before, so a promise that is never kept costs nothing.
 *       Then, optionally, trigger:<spell>:
 *       the passive aura the core's proc system fires the event through (the
 *       events crit, spell_crit, heal_crit, dodge, parry, block, crit_taken,
 *       miss come that way, as MARKER spells the core casts). Then also
 *       then:<figure>:<sec>[:<spell>] (WHAT COMES AFTER: when the level's aura
 *       falls, that other aura -- its own spell, so that a boon may be followed
 *       by a bane -- is laid at that figure for that long -- a sequence, not a
 *       loop; what comes back is the event, not the sequence, and the line will
 *       not re-arm while one is running),
 *       say:<string> (the line says THAT sentence of the module's own texts
 *       instead of the one its action would say), emote:<gesture> (the player
 *       plays it when the line falls -- 11 is a laugh), cost:<kind>:<n> (health,
 *       mana or a control on the player),
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
 *       charmed -- the mind taken from him, and nothing else).
 *
 *   sp_pct:<pct>[:night:<pct>]
 *       The level's spell carries a flat spell power (damage and healing)
 *       recomputed every second as pct of the player's current spell power.
 *       A night percentage takes over between 21:00 and 06:00.
 *
 *   secondpct:<pct>[:<spell>...]
 *       The SECONDARY statistics, in percent -- haste, crit, hit, attack power,
 *       spell power, block, parry. Eight auras are needed and a spell carries
 *       three, so the level lays its own spell and the companions the generator
 *       made for it.
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
 *       A heal on a target under that share of health costs that much less
 *       mana. The core takes the cost AFTER this hook, so the share comes back
 *       on the next update; the figure the client shows does not move.
 *
 *   chest_extra:<n>
 *       A chest gives more: its own table is drawn n times over, as the loot
 *       is being composed. The card chooses nothing -- the chest does.
 *
 *   lockpick:<value>
 *       The player is lent the LOCKPICKING skill at that value while the card
 *       is laid -- the core asks for the skill itself, not for an aura -- and
 *       a rogue is given his own back, untouched, when it goes.
 *
 *   hearthcd:<pct>
 *       The hearthstone comes back sooner: its cooldown is cut by that share
 *       of its ORIGINAL length, so two levels at -25 and -50 make -75.
 *
 *   shoutlong:<factor>
 *       The player's CRIES -- Shout, Howl, Scream, Roar by their English name --
 *       last that many times longer.
 *
 *   stunlong:<sec>
 *       The stuns the player lays last that many seconds longer.
 *
 *   tickmod:<chance>:<pct>[:onlynight]
 *       With that chance, one tick of one of the player's periodic effects --
 *       damage or healing -- counts for pct percent more (100: one tick more).
 *       onlynight: nothing by day.
 *
 *   econ:<kind>:<pct>[:and:<kind>:<pct>][:<state>]
 *       gold_loot, xp, rep, quest_gold, repair (cost), vendor_buy (price),
 *       vendor_sell (price), vendor_sell_grey (POOR items alone),
 *       vendor_sell_good (UNCOMMON items and better).
 *       A state at the end -- rested, combat, nocombat, solo, night, day,
 *       water -- and the line counts only while it holds.
 *
 * Schools: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane.
 */

#include "StellarTarotScript.h"
#include "StellarTarotLoot.h"
#include "Creature.h"
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
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "Pet.h"
#include "SpellMgr.h"
#include "ObjectAccessor.h"
#include "Chat.h"
#include "Log.h"
#include "StellarTarotStrings.h"
#include <algorithm>
#include <map>
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
    bool gInsideDamage = false;

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

    bool gInsideHeal = false;

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
        if (!victim || !victim->IsAlive() || !damage || gInsideDamage)
            return;
        gInsideDamage = true;
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
        gInsideDamage = false;
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
        bool const was = gInsideHeal;
        gInsideHeal = true;
        HealInfo healInfo(player, target, amount, info, SPELL_SCHOOL_MASK_HOLY);
        player->HealBySpell(healInfo);
        gInsideHeal = was;
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
        gInsideDamage = true;
        Unit::DealDamage(player, player, uint32(dmg), nullptr, SELF_DAMAGE, SPELL_SCHOOL_MASK_SHADOW, info, false);
        gInsideDamage = false;
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
    //   hp:<pct> / mana:<pct>          il paie de sa sante ou de son mana
    //   stun|silence|sleep|disorient|root:<sec>   il se met hors jeu un instant
    //   taken:<pct>:<sec>              il encaisse plus, un moment
    //   burn:<pct>:<sec>               il perd des PV par tics
    //   self_hit:<pct>                 le coup se retourne contre lui
    //
    // « cost: » reste accepte pour dire la meme chose : c'est le mot d'avant.
    void Cost(Player* player, std::string const& kind, int32 n, int32 n2 = 0, uint32 spellId = 0,
              uint32 markSpell = 0)
    {
        if (kind == "hp")
            Bleed(player, PctOf(player->GetMaxHealth(), n), STELLAR_TAROT_SPELL_PRICE);
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
    }
    bool CostKind(std::string const& k)
    {
        return k == "hp" || k == "mana" || k == "disorient" || k == "stun" || k == "silence"
            || k == "sleep" || k == "root" || k == "taken" || k == "burn" || k == "self_hit"
            || k == "armor";
    }
    // Les revers qui demandent DEUX chiffres (une valeur et une duree).
    bool CostPair(std::string const& k) { return k == "taken" || k == "burn" || k == "armor"; }

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
                if (but.kind == "armor" || but.kind == "taken")
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

    // A periodic action under a state (Cond) or on a timer: what and how much.
    void SmallAction(Player* player, std::string const& action, int32 n, uint32 spellId = 0)
    {
        if (action == "heal") Heal(player, player, PctOf(player->GetMaxHealth(), n), spellId);
        else if (action == "mana") Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), n), spellId);
        else if (action == "heal_both")
        {
            Heal(player, player, PctOf(player->GetMaxHealth(), n), spellId);
            Energize(player, player, PctOf(player->GetMaxPower(POWER_MANA), n), spellId);
        }
        else if (action == "repair") Mend(player, uint32(n));
    }
    bool SmallKind(std::string const& a) { return a == "heal" || a == "mana" || a == "heal_both" || a == "repair"; }

    // -- aura helpers ----------------------------------------------------------

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
            else if (_state == "still" || _state == "mounted" || _state == "walking")
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
                // sp:<pct> -- the aura's figure is a percentage of the spell
                // power the player has, recomputed while the state holds.
                if (word == "sp" && r.Int(1, 1000, _spPct))
                    continue;
                error = "after the state, only stacks:<k>, tick:<sec>:<action>:<n> or sp:<pct> may follow";
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
                _applied = 0;
                return;
            }
            if (_spPct)
            {
                // A figure read from the player's own spell power: the aura is
                // cast again whenever that figure moves.
                int32 const current = std::max(0, player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)) - _applied;
                int32 const bonus = int32(std::llround(double(current) * _spPct / 100.0));
                if (bonus != _applied || !player->HasAura(_spellId))
                {
                    RemoveOwned(player, _spellId);
                    _applied = bonus;
                    // The aura is there while the state holds, even at nothing:
                    // a character with no spell power still sees the condition
                    // met. The figure passed is one short, the spell's die side
                    // adding the last point (as the generator writes them).
                    int32 const bp = bonus - 1;
                    player->CastCustomSpell(player, _spellId, &bp, &bp, nullptr, true);
                }
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
        int32 _n = 0, _m = 0, _stacks = 1, _tickEvery = 0, _tickN = 0, _spPct = 0, _applied = 0;
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
                                                 "enter_instance", "spell_cast_tp", "dmg_taken_back",
                                                 "hit_spell", "dmg_taken", "dmg_taken_phys", "dmg_taken_magic", "spell_cast",
                                                 "spell_cast_dmg", "spell_cast_heal",
                                                 "spell_crit_fire", "wand",
                                                 "heal", "heal_ally", "enter_combat", "leave_combat", "levelup", "resurrect",
                                                 "zone", "quest", "hourly", "loot_gold", "vendor_buy", "repair",
                                                 "flight_end", "loot_creature", "vendor_sell",
                                                 "jump_combat", "death",
                                                 "crit", "spell_crit", "heal_crit", "dodge", "parry", "block", "crit_taken", "miss" };
            bool known = false;
            for (char const* e : plain)
                if (_event == e) known = true;
            if (_event == "tick" || _event == "every" || _event == "hp_below" || _event == "mana_below"
                || _event == "spell_cast_school" || _event == "death_near" || _event == "spell_cast_id")
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
                     || A == "grey_item")
                ok = true;
            else if (A == "repair_one" || A == "refund" || A == "resurrect")
                ok = r.Int(1, 100, _a);
            else if (A == "mana_pm")
                ok = r.Int(1, 1000, _a);
            else if (A == "aura" || A == "aura_target")
                ok = r.Int(0, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "aura_group")
                ok = r.Int(1, 86400, _a) && r.Int(1, 100, _b);
            else if (A == "heal" || A == "mana" || A == "heal_both" || A == "leech" || A == "reflect" || A == "copper_per_damage"
                     || A == "free_next" || A == "cooldowns" || A == "reset_cooldowns" || A == "repair" || A == "gold_mult"
                     || A == "immune_snare" || A == "root" || A == "stun" || A == "disorient" || A == "fear" || A == "sleep"
                     || A == "silence" || A == "knockback")
                ok = r.Int(1, 100000, _a);
            else if (A == "gold_level" || A == "silver_level")
                ok = r.Int(1, 100000000, _a);
            else if (A == "shield_self" || A == "shield_target" || A == "splash" || A == "cleave" || A == "explode"
                     || A == "heal_group" || A == "heal_ally_amount" || A == "heal_pet" || A == "bleed" || A == "blink")
                ok = r.Int(1, 10000, _a) && r.Int(0, 10000, _b);
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
                    if (_costKind == "armor" || _costKind == "taken")
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
            return true;
        }
        // A state the level's spell shows while it lasts: the module does not
        // apply that spell itself.
        bool State() const
        {
            return _action == "next_crit" || _action == "next_sure" || _action == "next_instant"
                || _action == "free_next" || _action == "cost_next";
        }
        bool OwnsAura() const override { return _action == "aura" || _action == "aura_target" || _action == "aura_group" || State(); }
        void Apply(Player* player) override
        {
            _last = 0; _wasBelow = false; _elapsed = 0; _freeLeft = 0; _nextCrit = false; _nextSure = false;
            _armedAt = 0;
            if (_trigger)
                ApplyOwned(player, uint32(_trigger));
        }
        void Remove(Player* player) override
        {
            if (_action == "aura" || State()) RemoveOwned(player, _spellId);
            if (_thenSpell) RemoveOwned(player, uint32(_thenSpell));
            if (_trigger) RemoveOwned(player, uint32(_trigger));
        }

        void OnTick(Player* player) override
        {
            if (_event == "tick")
            {
                if (!player->IsInCombat()) { _elapsed = 0; return; }
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            else if (_event == "every")
            {
                if (++_elapsed >= uint32(_eventN)) { _elapsed = 0; Fire(player, nullptr, 0); }
            }
            else if (_event == "hp_below" || _event == "mana_below")
            {
                float const pct = _event == "hp_below" ? player->GetHealthPct() : player->GetPowerPct(POWER_MANA);
                bool const below = pct < float(_eventN);
                if (below && !_wasBelow)
                    Fire(player, player->GetVictim(), 0);
                _wasBelow = below;
            }
            else if (_event == "hourly")
            {
                if (++_elapsed >= 3600) { _elapsed = 0; Fire(player, nullptr, 0); }
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
            if (_event == "hit" || (_event == "hit_melee" && !spell) || (_event == "hit_spell" && spell))
                Fire(player, victim, damage);
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
            if (gInsideHeal)
                return;
            if (_event == "heal" || (_event == "heal_ally" && target != player))
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
                static char const* const markers[] = { "crit", "spell_crit", "heal_crit", "dodge", "parry", "block",
                                                      "crit_taken", "miss", "spell_crit_fire", "" };
                if (_event == markers[id - STELLAR_TAROT_MARKER_FIRST])
                {
                    // The marker comes right after the blow that fired it: the
                    // unit struck and the figure struck for are the ones the
                    // damage hook has just seen.
                    Unit* struck = _lastVictim ? ObjectAccessor::GetUnit(*player, _lastVictim) : nullptr;
                    Fire(player, struck ? struck : spell->m_targets.GetUnitTarget(), _lastAmount);
                }
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
            // UN SORT QUI EMPORTE : la pierre de foyer, un rappel, un voyage.
            // Un portail ouvert par un autre n'est pas un lancement du joueur
            // et ne passe donc pas par ici.
            else if (_event == "spell_cast_tp")
                fires = info->HasEffect(SPELL_EFFECT_TELEPORT_UNITS);
            if (_event == "spell_cast_school")
                fires = (info->GetSchoolMask() & uint32(_eventN)) != 0;
            else if (_event == "spell_cast_dmg")
                fires = !info->IsPositive();
            else if (_event == "spell_cast_heal")
                fires = info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                        || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH);
            if (fires)
            {
                _lastCast = spell;
                Fire(player, spell->m_targets.GetUnitTarget(), 0);
                _lastCast = nullptr;
            }
        }
        void OnJump(Player* player) override
        {
            if (_event == "jump_combat" && player->IsInCombat())
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
            if (_icd && _last && now - _last < uint32(_icd))
                return false;
            if (_chance < 100 && int32(urand(1, 100)) > _chance)
                return false;
            _last = now;
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
                if (_costKind == "self_hit")
                    Hurt(player, player, PctOf(_lastAmount, _costN), SPELL_SCHOOL_MASK_NORMAL,
                         STELLAR_TAROT_SPELL_PRICE);
                else
                    Cost(player, _costKind, _costN, _costN2, _spellId, uint32(_costSpell));
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
                Unit* who = A == "aura" ? player : other;
                if (!who || !who->IsAlive())
                    return;
                Aura* aura = who->GetAura(_spellId, player->GetGUID());
                if (!aura)
                    aura = player->AddAura(_spellId, who);
                else if (_b > 1 && aura->GetStackAmount() < uint8(_b))
                    aura->ModStackAmount(1);
                if (aura && _a)
                {
                    aura->SetMaxDuration(_a * 1000);
                    aura->SetDuration(_a * 1000);
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
            else if (A == "reflect") Hurt(player, other, PctOf(amount, _a), 1, _spellId);
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
        int32 _eventN = 0, _chance = 100, _icd = 0, _a = 0, _b = 0, _c = 0, _trigger = 0, _costN = 0, _freeLeft = 0;
        int32 _costN2 = 0, _costChance = 100, _costSpell = 0;
        int32 _nightA = 0, _say = 0, _emote = 0, _thenPct = 0, _thenSec = 0, _thenSpell = 0;
        uint32 _seqUntil = 0;
        bool _onlyNight = false, _onlyDark = false;
        ObjectGuid _lastVictim;
        uint32 _lastAmount = 0;
        uint32 _last = 0, _elapsed = 0, _armedAt = 0, _lastSchool = 0;
        bool _wasBelow = false, _nextCrit = false, _nextSure = false, _wasFlying = false, _selling = false;
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
            if (_cond != "alone" && _cond != "controlled" && _cond != "charmed")
            { error = "unknown condition \"" + _cond + "\""; return false; }
            if (!r.Int(-100, 1000, _pct))
                return (error = "expects the percentage", false);
            r.OptInt(0, 127, _school);
            return r.End() || (error = "after the percentage, only the school may follow", false);
        }
        void OnDamageTaken(Player* player, Unit* /*attacker*/, uint32& damage, bool /*spell*/, uint32 school,
                           uint32 /*spellId*/) override
        {
            if (_school && !(school & uint32(_school)))
                return;
            bool meets = false;
            if (_cond == "alone") meets = player->getAttackers().size() <= 1;
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
    // secondpct:<pct>[:<sort>...]
    //     LES STATISTIQUES SECONDAIRES, en pourcentage. Huit auras sont
    //     necessaires -- la hate en demande deux, le toucher deux -- et un sort
    //     n'en porte que trois : le niveau pose le sien et les sorts compagnons
    //     que le generateur lui a fabriques. La puissance des sorts, qui n'a
    //     aucune aura de pourcentage, est calculee ici comme le fait sp_pct.
    // =========================================================================
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
            if (!(info->HasEffect(SPELL_EFFECT_HEAL) || info->HasEffect(SPELL_EFFECT_HEAL_PCT)
                  || info->HasEffect(SPELL_EFFECT_HEAL_MAX_HEALTH)))
                return;
            Unit* const target = spell->m_targets.GetUnitTarget();
            if (!target || target->GetHealthPct() > float(_hp))
                return;
            int32 const back = int32(PctOf(uint32(std::max(0, spell->GetPowerCost())), _pct));
            if (back <= 0)
                return;
            ObjectGuid const guid = player->GetGUID();
            player->m_Events.AddEventAtOffset([guid, back]()
            {
                if (Player* p = ObjectAccessor::FindPlayer(guid))
                    p->ModifyPower(POWER_MANA, back);
            }, Milliseconds(1));
        }

    private:
        std::string _kind;
        int32 _hp = 0, _pct = 0;
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
    // lockpick:<valeur>
    //     LES SERRURES CEDENT. Le coeur demande une COMPETENCE de crochetage
    //     (Spell::CanOpenLock, LOCK_KEY_SKILL) : une aura n'y peut rien, il
    //     faut que le joueur la possede. La carte la lui prete le temps qu'elle
    //     est posee, et la lui reprend en s'en allant -- en rendant a un voleur
    //     la sienne, telle qu'elle etait.
    // =========================================================================
    class LockPick : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            return (r.Int(1, 450, _value) && r.End())
                || (error = "expects the skill value", false);
        }
        void Apply(Player* player) override
        {
            _had = player->HasSkill(SKILL_LOCKPICKING);
            _was = _had ? player->GetPureSkillValue(SKILL_LOCKPICKING) : uint16(0);
            _wasMax = _had ? player->GetPureMaxSkillValue(SKILL_LOCKPICKING) : uint16(0);
            if (!_had || _was < uint16(_value))
                player->SetSkill(SKILL_LOCKPICKING, 0, uint16(_value), uint16(_value));
        }
        void Remove(Player* player) override
        {
            if (_had)
                player->SetSkill(SKILL_LOCKPICKING, 0, _was, _wasMax);
            else
                player->SetSkill(SKILL_LOCKPICKING, 0, 0, 0);
        }
    private:
        int32 _value = 0;
        uint16 _was = 0, _wasMax = 0;
        bool _had = false;
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
        void OnPeriodicTick(Player* /*player*/, Unit* /*other*/, uint32& amount, bool /*heal*/) override
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
    class Econ : public StellarTarotScript
    {
    public:
        bool Parse(std::vector<std::string> const& params, std::string& error) override
        {
            Reader r(params);
            _kind = r.Word();
            static char const* const kinds[] = { "gold_loot", "xp", "rep", "quest_gold", "repair", "vendor_buy",
                                                 "vendor_sell", "vendor_sell_grey", "vendor_sell_good" };
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
        void OnGiveXP(Player* player, uint32& amount) override
        {
            if (Has("xp") && On(player)) amount = uint32(std::llround(double(amount) * (100 + PctOf(player, "xp")) / 100.0));
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
    Register("stat", [] { return std::make_unique<NightStat>(); });
    Register("costmod", [] { return std::make_unique<CostMod>(); });
    Register("statcond", [] { return std::make_unique<StateStat>(); });
    Register("secondpct", [] { return std::make_unique<SecondaryPct>(); });
    Register("shoutlong", [] { return std::make_unique<ShoutLong>(); });
    Register("hearthcd", [] { return std::make_unique<HearthCooldown>(); });
    Register("lockpick", [] { return std::make_unique<LockPick>(); });
    Register("chest_extra", [] { return std::make_unique<ChestExtra>(); });
    Register("tickmod", [] { return std::make_unique<TickMod>(); });
    Register("dotlong", [] { return std::make_unique<DotLong>(); });
    Register("stunlong", [] { return std::make_unique<StunLong>(); });
    Register("econ", [] { return std::make_unique<Econ>(); });
}

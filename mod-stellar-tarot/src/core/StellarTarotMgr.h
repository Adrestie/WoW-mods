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
 * mod-stellar-tarot — the catalogue: cards, boards and tags.
 *
 * In-memory definition, loaded from the world database before the world
 * opens and reloadable with .tarot reload. Everything the module knows about
 * a card or a board is data: the four edges, the numbers around a board, the
 * spell and the script of each activation level, the tags. Nothing here is a
 * setting.
 *
 * A card is known by its number N, a board by its number B. The ITEM the
 * player loots follows from that number and nothing else -- card N is item
 * CARD_ITEM_BASE + N, board B is item BOARD_ITEM_BASE + B -- so no row of the
 * catalogue stores an item entry: moving the base moves every item with it,
 * and the installer rewrites these two constants when it has to.
 *
 * A CARD THAT CANNOT BE PLAYED IS REFUSED AT LOAD: a level with neither a
 * spell nor a script, a spell the server does not have, a script the module
 * does not know or a parameter it cannot read. The refusal is logged, listed
 * by .tarot info, and the card is not in the catalogue -- it cannot be laid.
 */

#ifndef MOD_STELLAR_TAROT_MGR_H_
#define MOD_STELLAR_TAROT_MGR_H_

#include "Define.h"
#include <array>
#include <map>
#include <set>
#include <string>
#include <vector>

// THE IDENTIFIERS THE MODULE ALLOCATES. One block, 902000..903999, one number
// per asset. They are not settings: adapting them to a server that already
// uses the block is the installer's job, and these constants are what its
// shift rewrites.
constexpr uint32 STELLAR_TAROT_CARD_ITEM_BASE  = 902000;   // card N  -> item 902000 + N
constexpr uint32 STELLAR_TAROT_BOARD_ITEM_BASE = 902500;   // board B -> item 902500 + B
constexpr uint32 STELLAR_TAROT_CARD_MAX  = 499;            // 902001..902499
constexpr uint32 STELLAR_TAROT_BOARD_MAX = 99;             // 902501..902599
// THE BANNER: the one aura the player sees while any effect of the board is in
// force. The effects' own auras are hidden from the aura bar; this one says
// that something is, and points at the window.
constexpr uint32 STELLAR_TAROT_BANNER_SPELL = 903002;
// THE ENGINE'S OWN SPELLS, at the top of the block: three controls it puts on
// a target, eight markers the core's proc system casts to signal an event,
// and the passive trigger auras the generator allocates from 903820 up.
constexpr uint32 STELLAR_TAROT_SPELL_ROOT   = 903800;
constexpr uint32 STELLAR_TAROT_SPELL_STUN   = 903801;
constexpr uint32 STELLAR_TAROT_SPELL_BLEED  = 903802;
constexpr uint32 STELLAR_TAROT_SPELL_SHIELD = 903803;
constexpr uint32 STELLAR_TAROT_SPELL_DISORIENT = 903804;
constexpr uint32 STELLAR_TAROT_SPELL_FEAR   = 903805;
constexpr uint32 STELLAR_TAROT_SPELL_SLEEP  = 903806;
constexpr uint32 STELLAR_TAROT_SPELL_SILENCE = 903807;
constexpr uint32 STELLAR_TAROT_SPELL_IMMUNE_SNARE = 903808;
constexpr uint32 STELLAR_TAROT_SPELL_IMMUNE_CONTROL = 903809;
// DISPARAITRE : l'invisibilite que le coeur porte, pour le temps qu'une
// ligne lui donne.
constexpr uint32 STELLAR_TAROT_SPELL_INVISIBLE = 903810;
constexpr uint32 STELLAR_TAROT_SPELL_BURN = 903795;              // fire, over time
constexpr uint32 STELLAR_TAROT_SPELL_TAKEN_MORE = 903798;        // a drawback: the player takes more damage
constexpr uint32 STELLAR_TAROT_SPELL_WAND_SHOT = 903794;         // the second shot a card grants, a wand's own
// LE PRIX A PAYER : the health a drawback takes is taken under THIS name, and
// not under the level's. The level may then keep quiet -- its aura is hidden --
// without carrying off the scrolling text of the price with it.
constexpr uint32 STELLAR_TAROT_SPELL_PRICE = 903799;             // a drawback: what it costs in health
// RETOURNE : the mark a creature wears while a card has it strike its own.
// It carries no mechanic -- the threat does the work -- it only lets the
// player see on whom the card has taken hold.
constexpr uint32 STELLAR_TAROT_SPELL_TURNED = 903792;
// ARMURE BRISEE : a drawback that takes a share of the player's armour for a
// while. It has its own spell so that it may outlast -- or fall short of --
// the boon the level's aura carries, the two having their own durations.
constexpr uint32 STELLAR_TAROT_SPELL_ARMOR_DOWN = 903793;
// LES CREATURES DU MODULE. Un espace d'identifiants A PART de celui des objets
// et des sorts : une creature 902650 ne croise ni l'objet ni le sort qui
// portent ce numero. Le coeur les clone de gabarits natifs, faction amie, et
// leur donne l'IA de gardien du module.
constexpr uint32 STELLAR_TAROT_NPC_BOAR   = 902650;   // le sanglier de la carte 139
constexpr uint32 STELLAR_TAROT_NPC_DOUBLE = 902651;   // le double de la carte 74
constexpr uint32 STELLAR_TAROT_ITEM_CRATE = 902600;              // the crate of goods a card lays in a corpse
constexpr uint32 STELLAR_TAROT_SPELL_VISUAL_MAGIC = 903796;      // an explosion's animation, arcane
constexpr uint32 STELLAR_TAROT_SPELL_VISUAL_PHYS  = 903797;      // an explosion's animation, physical
constexpr uint32 STELLAR_TAROT_MARKER_FIRST = 903810;   // crit, spell_crit, heal_crit, dodge, parry, block, crit_taken, miss
constexpr uint32 STELLAR_TAROT_MARKER_LAST  = 903819;
constexpr uint32 STELLAR_TAROT_TRIGGER_FIRST = 903820;
constexpr uint32 STELLAR_TAROT_TRIGGER_LAST  = 903999;
// THE SECOND RESERVE. The block's lower half carries the ITEMS -- cards up to
// 902499, boards up to 902599, the crate at 902600 -- and nothing else. What
// is left of it, from 902700 up, is a second reserve of SPELLS: an item number
// and a spell number are two separate lists, and no number here is shared. The
// generator fills the upper reserve first and spills into this one, so no
// spell already laid ever changes its number.
// LES TEMOINS DE MESURE : une aura par evenement du systeme de procs, a chance
// 100 et sans recharge, lancant le MEME marqueur que l'evenement. Le module les
// pose le temps d'une mesure (`.tarot check`) pour compter les OCCASIONS -- ce
// que le coeur lui cache depuis qu'il filtre lui-meme la chance et l'ICD.
constexpr uint32 STELLAR_TAROT_WITNESS_FIRST = 902700;
constexpr uint32 STELLAR_TAROT_WITNESS_LAST  = 902708;
constexpr uint32 STELLAR_TAROT_SPELL_LOW_FIRST = 902710;
constexpr uint32 STELLAR_TAROT_SPELL_LOW_LAST  = 902999;

// A card has four edges and four activation levels; a board has 2 to 4 rows
// and 2 to 4 columns; every number on an edge or around a board is 1 to 9.
constexpr uint8 STELLAR_TAROT_EDGES    = 4;
constexpr uint8 STELLAR_TAROT_LEVELS   = 4;
constexpr uint8 STELLAR_TAROT_MIN_SIDE = 2;
constexpr uint8 STELLAR_TAROT_MAX_SIDE = 4;
constexpr uint8 STELLAR_TAROT_MIN_NUMBER = 1;
constexpr uint8 STELLAR_TAROT_MAX_NUMBER = 9;

// The edges of a card, in the order the catalogue stores them.
enum StellarTarotEdge : uint8
{
    STELLAR_TAROT_EDGE_TOP    = 0,
    STELLAR_TAROT_EDGE_RIGHT  = 1,
    STELLAR_TAROT_EDGE_BOTTOM = 2,
    STELLAR_TAROT_EDGE_LEFT   = 3
};

// The two axes a board's numbers run along, and the two sides of each.
enum StellarTarotAxis : uint8
{
    STELLAR_TAROT_AXIS_ROW    = 0,   // two numbers per row: left and right
    STELLAR_TAROT_AXIS_COLUMN = 1    // two numbers per column: top and bottom
};

enum StellarTarotSide : uint8
{
    STELLAR_TAROT_SIDE_FIRST  = 0,   // a row's left, a column's top
    STELLAR_TAROT_SIDE_SECOND = 1    // a row's right, a column's bottom
};

// A script named by a card: its registered name and its parameters, as
// written in the column -- `gold_on_kill:500` is name "gold_on_kill" with
// one parameter "500". Empty name = no script at that level.
struct StellarTarotScriptSpec
{
    std::string name;
    std::vector<std::string> params;
    std::string text;                   // the column as written, for the interface
    [[nodiscard]] bool Empty() const { return name.empty(); }
};

// What a card does at one activation level: an aura, a script, or both.
struct StellarTarotEffect
{
    uint32 spellId = 0;
    StellarTarotScriptSpec script;
};

struct StellarTarotCard
{
    uint32 id = 0;
    std::string name;                                                  // English, of reference
    std::array<uint8, STELLAR_TAROT_EDGES> edges = { 0, 0, 0, 0 };     // top, right, bottom, left
    uint32 tagId = 0;                                                  // the one tag: the deck tab it sits under
    bool cumulative = false;                                           // level L grants 1..L, or L alone
    std::string art;                                                   // texture path, client side
    std::array<StellarTarotEffect, STELLAR_TAROT_LEVELS> effects;      // [0] = level 1 .. [3] = level 4
};

struct StellarTarotBoard
{
    uint32 id = 0;
    uint8 rows = 0;
    uint8 cols = 0;
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> rowLeft   = { 0, 0, 0, 0 };   // [i] faces the left edge of row i's first card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> rowRight  = { 0, 0, 0, 0 };   // [i] faces the right edge of row i's last card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> colTop    = { 0, 0, 0, 0 };   // [j] faces the top edge of column j's first card
    std::array<uint8, STELLAR_TAROT_MAX_SIDE> colBottom = { 0, 0, 0, 0 };   // [j] faces the bottom edge of column j's last card
    std::string art;
};

struct StellarTarotTag
{
    uint32 id = 0;
    std::string name;
};

class StellarTarotMgr
{
public:
    static StellarTarotMgr* instance();

    // Reloads the whole catalogue from the world database. Called at startup
    // (before the world opens) and by .tarot reload.
    void Load();

    [[nodiscard]] bool Enabled() const { return _enabled; }
    // L'instrument de mesure est-il allume ? (StellarTarot.Check)
    [[nodiscard]] bool Checking() const { return _check; }

    [[nodiscard]] std::map<uint32, StellarTarotCard> const& Cards() const { return _cards; }
    [[nodiscard]] std::map<uint32, StellarTarotBoard> const& Boards() const { return _boards; }
    [[nodiscard]] std::map<uint32, StellarTarotTag> const& Tags() const { return _tags; }
    // The cards refused at load, with the reason: card id -> why.
    [[nodiscard]] std::map<uint32, std::string> const& Refused() const { return _refused; }
    // Every spell any card names, at any level: what a login purges before
    // applying the layout, so that nothing the core saved survives a change.
    [[nodiscard]] std::set<uint32> const& EffectSpells() const { return _effectSpells; }
    // CE QUE LE LIEU DONNE : la liste de l'age demande, ou celle de l'age 0
    // quand cet age-la n'en a pas. Vide si la reserve n'existe pas.
    [[nodiscard]] std::vector<uint32> const& LootPool(std::string const& pool, uint32 age) const;

    [[nodiscard]] StellarTarotCard const* Card(uint32 cardId) const;
    [[nodiscard]] StellarTarotBoard const* Board(uint32 boardId) const;
    [[nodiscard]] StellarTarotTag const* Tag(uint32 tagId) const;

    // The item behind a card or a board, and back. nullptr when the entry is
    // neither.
    static constexpr uint32 ItemForCard(uint32 cardId) { return STELLAR_TAROT_CARD_ITEM_BASE + cardId; }
    static constexpr uint32 ItemForBoard(uint32 boardId) { return STELLAR_TAROT_BOARD_ITEM_BASE + boardId; }
    [[nodiscard]] StellarTarotCard const* CardForItem(uint32 itemEntry) const;
    [[nodiscard]] StellarTarotBoard const* BoardForItem(uint32 itemEntry) const;

    // The name a player reads: the item's, in English. The catalogue's own
    // name is the reference the author wrote; the item's is what shows.
    [[nodiscard]] std::string CardName(uint32 cardId) const;
    [[nodiscard]] std::string BoardName(uint32 boardId) const;

private:
    bool _enabled = true;
    bool _check = false;
    std::map<uint32, StellarTarotCard> _cards;
    std::map<uint32, StellarTarotBoard> _boards;
    std::map<uint32, StellarTarotTag> _tags;
    std::map<uint32, std::string> _refused;
    // reserve -> age -> les objets qu'elle donne
    std::map<std::string, std::map<uint32, std::vector<uint32>>> _lootPools;
    std::set<uint32> _effectSpells;
};

#define sStellarTarotMgr StellarTarotMgr::instance()

#endif

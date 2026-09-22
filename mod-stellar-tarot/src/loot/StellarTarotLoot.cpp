/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "StellarTarotLoot.h"

#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Field.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "QueryResult.h"
#include "Random.h"
#include "SharedDefines.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StellarTarotBinder.h"
#include "StellarTarotMgr.h"
#include "WorldSession.h"

#include <unordered_set>

#include <fmt/format.h>
#include <vector>

namespace
{
    // CE QU'UNE CAISSE CONTIENT : la table de butin d'un COFFRET, choisi dans
    // la liste que l'auteur a arretee -- un coffret par tranche de niveau, du
    // bronze au titane. C'est leur table que la caisse joue, telle quelle,
    // avec les chances du jeu.
    uint32 const CRATE_BOXES[3][8] =
    {
        // l'ancien monde
        { 4633,     // Heavy Bronze Lockbox
          4634,     // Iron Lockbox
          4636,     // Strong Iron Lockbox
          4637,     // Steel Lockbox
          4638,     // Reinforced Steel Lockbox
          5758,     // Mithril Lockbox
          5759,     // Thorium Lockbox
          5760 },   // Eternium Lockbox
        { 31952, 0, 0, 0, 0, 0, 0, 0 },     // Outreterre : coffret en khorium
        { 43622,    // Norfendre : coffret en acier de Givre
          43624,    // coffret en titane
          0, 0, 0, 0, 0, 0 },
    };
    bool fillingCrate = false;          // une caisse qui se remplit ne se remplit pas elle-meme

    // LES OBJETS GRIS que le monde fait tomber, ranges par age : de quoi
    // ajouter une babiole a un cadavre. Le niveau d'objet les date proprement
    // (<= 55 l'ancien monde, 56-69 l'Outreterre, au-dela Norfendre).
    std::vector<uint32> junk[3];

    // LA RESERVE D'EQUIPEMENT, par qualite : rare (indice 0) et epique
    // (indice 1). On n'y met que des ARMES et des ARMURES que le monde fait
    // deja tomber -- pas un objet de quete, pas une piece liee a une carte, pas
    // une recette. Chaque entree garde le niveau requis et le niveau d'objet :
    // une carte qui promet « un objet de votre niveau » choisit dedans.
    struct Gear
    {
        uint32 entry = 0;
        uint16 itemLevel = 0;
        uint16 required = 0;
    };
    std::vector<Gear> gear[2];

    // LES HERBES que le monde fait pousser, rangees par age comme les
    // babioles : de quoi rendre « une autre plante de la meme extension ».
    std::vector<uint32> herbs[3];

    uint8 CrateAgeOf(uint8 level)
    {
        if (level <= 57) return 0;
        if (level <= 67) return 1;
        return 2;
    }

    std::vector<StellarTarotSource> sources;
    bool enabled = true;
    float rate = 100.0f;
    bool knownMayDrop = true;

    // What a creature's loot says of itself, read once per loot.
    struct Facts
    {
        uint32 entry = 0;
        uint32 level = 0;
        bool boss = false;
        bool elite = false;
        int8 expansion = -1;
        bool dungeon = false;
        bool raid = false;
        bool heroic = false;
    };

    Facts Read(Creature* creature)
    {
        Facts f;
        f.entry = creature->GetEntry();
        f.level = creature->GetLevel();
        uint32 const rank = creature->GetCreatureTemplate()->rank;
        f.boss = creature->IsDungeonBoss() || creature->isWorldBoss() || rank == CREATURE_ELITE_WORLDBOSS;
        f.elite = !f.boss && (rank == CREATURE_ELITE_ELITE || rank == CREATURE_ELITE_RAREELITE);
        if (Map* map = creature->GetMap())
        {
            f.raid = map->IsRaid();
            f.dungeon = map->IsDungeon() && !f.raid;
            f.heroic = map->IsHeroic();
            if (MapEntry const* entry = map->GetEntry())
                f.expansion = int8(entry->Expansion());
        }
        return f;
    }

    bool Matches(StellarTarotSource const& s, Facts const& f)
    {
        if (s.creatureEntry && s.creatureEntry != f.entry)
            return false;
        if (s.expansion >= 0 && s.expansion != f.expansion)
            return false;
        if (s.place == "world" && (f.dungeon || f.raid))
            return false;
        if (s.place == "dungeon" && !f.dungeon)
            return false;
        if (s.place == "raid" && !f.raid)
            return false;
        if (s.heroic >= 0 && (s.heroic == 1) != f.heroic)
            return false;
        if (s.rank == "boss" && !f.boss)
            return false;
        if (s.rank == "elite" && !f.elite)
            return false;
        if (s.rank == "normal" && (f.boss || f.elite))
            return false;
        if (s.minLevel && f.level < s.minLevel)
            return false;
        if (s.maxLevel && f.level > s.maxLevel)
            return false;
        return true;
    }

    // The item that drops: the one named, or one drawn uniformly from the
    // catalogue -- from what the account does not know yet, when a known
    // card may not drop again. 0 when nothing can.
    uint32 Resolve(StellarTarotSource const& s, uint32 accountId)
    {
        if (s.targetId)
        {
            if (!knownMayDrop)
            {
                bool const known = s.board ? StellarTarotBinder::KnowsBoard(accountId, s.targetId)
                                           : StellarTarotBinder::KnowsCard(accountId, s.targetId);
                if (known)
                    return 0;
            }
            return s.board ? StellarTarotMgr::ItemForBoard(s.targetId) : StellarTarotMgr::ItemForCard(s.targetId);
        }
        std::vector<uint32> pool;
        if (s.board)
        {
            for (auto const& [id, board] : sStellarTarotMgr->Boards())
                if (knownMayDrop || !StellarTarotBinder::KnowsBoard(accountId, id))
                    pool.push_back(StellarTarotMgr::ItemForBoard(id));
        }
        else
        {
            for (auto const& [id, card] : sStellarTarotMgr->Cards())
                if (knownMayDrop || !StellarTarotBinder::KnowsCard(accountId, id))
                    pool.push_back(StellarTarotMgr::ItemForCard(id));
        }
        if (pool.empty())
            return 0;
        return pool[urand(0, uint32(pool.size()) - 1)];
    }

    // Into the loot window, one item per draw so that a random source may
    // yield different cards. The window is capped: beyond it Loot::AddItem
    // gives up silently, so it is said here instead.
    void Place(Loot* loot, StellarTarotSource const& s, uint32 accountId)
    {
        for (uint8 i = 0; i < s.quantity; ++i)
        {
            uint32 const entry = Resolve(s, accountId);
            if (!entry)
            {
                LOG_DEBUG("module", "StellarTarot loot: source {} won its roll but nothing could be drawn.", s.id);
                return;
            }
            if (loot->items.size() >= MAX_NR_LOOT_ITEMS)
            {
                LOG_DEBUG("module", "StellarTarot loot: loot full, {} not added (source {}).", entry, s.id);
                return;
            }
            loot->AddItem(LootStoreItem(entry, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
            LOG_DEBUG("module", "StellarTarot loot: {} added (source {}).", entry, s.id);
        }
    }

    bool OneOf(std::string const& value, std::initializer_list<char const*> allowed)
    {
        for (char const* a : allowed)
            if (value == a)
                return true;
        return false;
    }
}

void StellarTarotLoot::Load()
{
    sources.clear();
    enabled = sConfigMgr->GetOption<bool>("StellarTarot.Loot.Enabled", true);
    rate = sConfigMgr->GetOption<float>("StellarTarot.Loot.Rate", 100.0f);
    knownMayDrop = sConfigMgr->GetOption<bool>("StellarTarot.Loot.Known", true);
    if (rate < 0.0f)
        rate = 0.0f;

    uint32 refused = 0;
    if (QueryResult result = WorldDatabase.Query(
        "SELECT source_id, origin, what, target_id, creature_entry, expansion, place, heroic, creature_rank, "
        "min_level, max_level, chance, quantity, comment FROM mod_stellar_tarot_source ORDER BY source_id"))
    {
        do
        {
            Field* f = result->Fetch();
            StellarTarotSource s;
            s.id = f[0].Get<uint32>();
            s.origin = f[1].Get<std::string>();
            std::string const what = f[2].Get<std::string>();
            s.board = what == "board";
            s.targetId = f[3].Get<uint32>();
            s.creatureEntry = f[4].Get<uint32>();
            s.expansion = f[5].Get<int8>();
            s.place = f[6].Get<std::string>();
            s.heroic = f[7].Get<int8>();
            s.rank = f[8].Get<std::string>();
            s.minLevel = f[9].Get<uint32>();
            s.maxLevel = f[10].Get<uint32>();
            s.chance = f[11].Get<float>();
            s.quantity = f[12].Get<uint8>();
            s.comment = f[13].Get<std::string>();

            std::string why;
            if (s.origin != "creature")
                why = "origin must be 'creature'";
            else if (!OneOf(what, { "card", "board" }))
                why = "what must be 'card' or 'board'";
            else if (s.targetId && !s.board && !sStellarTarotMgr->Card(s.targetId))
                why = fmt::format("card {} is not in the catalogue", s.targetId);
            else if (s.targetId && s.board && !sStellarTarotMgr->Board(s.targetId))
                why = fmt::format("board {} is not in the catalogue", s.targetId);
            else if (s.expansion < -1 || s.expansion > 2)
                why = "expansion must be -1, 0, 1 or 2";
            else if (!OneOf(s.place, { "", "world", "dungeon", "raid" }))
                why = "place must be empty, 'world', 'dungeon' or 'raid'";
            else if (s.heroic < -1 || s.heroic > 1)
                why = "heroic must be -1, 0 or 1";
            else if (!OneOf(s.rank, { "", "normal", "elite", "boss" }))
                why = "creature_rank must be empty, 'normal', 'elite' or 'boss'";
            else if (s.maxLevel && s.minLevel > s.maxLevel)
                why = "min_level is above max_level";
            else if (s.chance <= 0.0f || s.chance > 100.0f)
                why = "chance must be in ]0, 100]";
            else if (s.quantity == 0)
                why = "quantity must be at least 1";

            if (!why.empty())
            {
                LOG_ERROR("module", "StellarTarot: loot source {} ignored: {}.", s.id, why);
                ++refused;
                continue;
            }
            sources.push_back(std::move(s));
        } while (result->NextRow());
    }
    LOG_INFO("module", "StellarTarot: {} loot source(s) loaded, {} refused; loot {}, rate {} %, known items {}.",
             sources.size(), refused, enabled ? "on" : "off", rate, knownMayDrop ? "may drop" : "never drop");
    // La reserve de babioles : tout objet GRIS qu'une creature laisse.
    for (auto& age : junk)
        age.clear();
    if (QueryResult greys = WorldDatabase.Query(
        "SELECT i.entry, i.ItemLevel FROM item_template i WHERE i.Quality = 0 AND i.bonding = 0 "
        "AND i.startquest = 0 AND i.map = 0 AND i.area = 0 AND (i.Flags & 4) = 0 "
        "AND i.entry IN (SELECT DISTINCT Item FROM creature_loot_template)"))
    {
        do
        {
            Field* g = greys->Fetch();
            uint32 const entry = g[0].Get<uint32>();
            uint32 const itemLevel = g[1].Get<uint32>();
            junk[itemLevel <= 55 ? 0 : (itemLevel <= 69 ? 1 : 2)].push_back(entry);
        } while (greys->NextRow());
    }
    LOG_INFO("module", "StellarTarot: {} / {} / {} grey item(s) a card may add to a corpse.",
             junk[0].size(), junk[1].size(), junk[2].size());

    // CE QUE LE MONDE FAIT TOMBER, une bonne fois : les numeros d'objet que les
    // tables des creatures et celles des objets du decor nomment. Demander
    // cette liste EN SOUS-REQUETE coutait plus d'une minute par appel -- la
    // base la relisait pour chaque objet du catalogue. Lue une fois et tenue
    // ici, elle ne coute plus rien.
    std::unordered_set<uint32> tombe;
    for (char const* table : { "creature_loot_template", "gameobject_loot_template" })
        if (QueryResult lignes = WorldDatabase.Query("SELECT DISTINCT Item FROM {}", table))
            do
            {
                tombe.insert((*lignes)[0].Get<uint32>());
            } while (lignes->NextRow());

    // L'EQUIPEMENT RARE ET EPIQUE que le monde donne deja : armes et armures,
    // les deux qualites d'un seul coup, triees en memoire.
    for (auto& q : gear)
        q.clear();
    if (QueryResult pieces = WorldDatabase.Query(
        "SELECT entry, ItemLevel, RequiredLevel, Quality FROM item_template "
        "WHERE Quality IN (3, 4) AND class IN (2, 4) AND startquest = 0 AND map = 0 "
        "AND area = 0 AND (Flags & 4) = 0 AND ItemLevel > 0"))
    {
        do
        {
            Field* g = pieces->Fetch();
            Gear piece;
            piece.entry = g[0].Get<uint32>();
            if (!tombe.count(piece.entry))
                continue;
            piece.itemLevel = uint16(g[1].Get<uint32>());
            piece.required = uint16(g[2].Get<uint32>());
            gear[g[3].Get<uint32>() - ITEM_QUALITY_RARE].push_back(piece);
        } while (pieces->NextRow());
    }
    LOG_INFO("module", "StellarTarot: {} rare and {} epic piece(s) a card may hand out.",
             gear[0].size(), gear[1].size());

    // LES HERBES : ce que les noeuds du decor donnent vraiment, date par le
    // niveau d'objet comme le reste.
    for (auto& age : herbs)
        age.clear();
    if (QueryResult plantes = WorldDatabase.Query(
        "SELECT entry, ItemLevel FROM item_template WHERE class = 7 AND subclass = 9"))
    {
        do
        {
            Field* h = plantes->Fetch();
            uint32 const entry = h[0].Get<uint32>();
            if (!tombe.count(entry))
                continue;
            uint32 const itemLevel = h[1].Get<uint32>();
            herbs[itemLevel <= 55 ? 0 : (itemLevel <= 69 ? 1 : 2)].push_back(entry);
        } while (plantes->NextRow());
    }
    LOG_INFO("module", "StellarTarot: {} / {} / {} herb(s) a card may hand out.",
             herbs[0].size(), herbs[1].size(), herbs[2].size());
}

std::vector<StellarTarotSource> const& StellarTarotLoot::Sources() { return sources; }
bool StellarTarotLoot::Enabled() { return enabled; }
float StellarTarotLoot::Rate() { return rate; }
bool StellarTarotLoot::KnownMayDrop() { return knownMayDrop; }

void StellarTarotLoot::Fill(Loot* loot, LootStore const& store, Player* player)
{
    // This fires on EVERY loot the server fills: the cheap tests come first.
    if (&store != &LootTemplates_Creature)
        return;
    if (!enabled || sources.empty() || !player || !loot || !sStellarTarotMgr->Enabled())
        return;
    if (!loot->sourceWorldObjectGUID.IsCreature())
        return;
    Creature* creature = ObjectAccessor::GetCreature(*player, loot->sourceWorldObjectGUID);
    if (!creature)
        return;

    Facts const facts = Read(creature);
    uint32 const accountId = player->GetSession()->GetAccountId();
    for (StellarTarotSource const& s : sources)
    {
        if (!Matches(s, facts))
            continue;
        if (!roll_chance_f(s.chance * rate / 100.0f))
            continue;
        Place(loot, s, accountId);
    }
}

std::string StellarTarotLoot::Describe(StellarTarotSource const& s)
{
    std::string what;
    if (s.targetId)
        what = s.board ? fmt::format("board {} \"{}\"", s.targetId, sStellarTarotMgr->BoardName(s.targetId))
                       : fmt::format("card {} \"{}\"", s.targetId, sStellarTarotMgr->CardName(s.targetId));
    else
        what = s.board ? "a board drawn at random" : "a card drawn at random";

    std::string from = "creature";
    from += s.creatureEntry ? fmt::format(" {}", s.creatureEntry) : std::string(" (any)");
    if (s.expansion >= 0)
        from += fmt::format(", expansion {}", s.expansion);
    if (!s.place.empty())
        from += ", " + s.place;
    if (s.heroic >= 0)
        from += s.heroic ? ", heroic" : ", non-heroic";
    if (!s.rank.empty())
        from += ", " + s.rank;
    if (s.minLevel || s.maxLevel)
        from += fmt::format(", level {}-{}", s.minLevel, s.maxLevel ? std::to_string(s.maxLevel) : std::string("max"));

    std::string line = fmt::format("{} x{} at {}% from {}", what, s.quantity, s.chance, from);
    if (!s.comment.empty())
        line += " -- " + s.comment;
    return line;
}

// The crate of goods, opened: the module plays the loot table of one of the
// LOCKBOXES the author named for that expansion -- the game's own table, with
// the game's own chances -- and lays a purse on top of it.
void StellarTarotLoot::FillCrate(Player* player, Loot* loot)
{
    if (!player || !loot || fillingCrate)
        return;
    uint8 const age = CrateAgeOf(player->GetLevel());
    uint32 boxes[8] = { 0 };
    uint8 count = 0;
    for (uint32 box : CRATE_BOXES[age])
        if (box)
            boxes[count++] = box;
    if (!count)
        return;
    uint32 const chosen = boxes[urand(0, count - 1)];
    fillingCrate = true;                // la table jouee ne doit pas rappeler ceci
    loot->clear();
    loot->FillLoot(chosen, LootTemplates_Item, player, true, true);
    fillingCrate = false;
    // Les pieces au fond de la caisse, a la mesure de l'extension : de 5 pa a
    // 1 po pour l'ancien monde, de 2 a 5 po pour l'Outreterre, de 5 a 10 po
    // pour Norfendre.
    static uint32 const purse[3][2] = { { 500, 10000 }, { 20000, 50000 }, { 50000, 100000 } };
    loot->gold = urand(purse[age][0], purse[age][1]);
}

// UNE PIECE D'EQUIPEMENT de la qualite demandee, a la mesure du joueur : son
// niveau requis ne doit pas le depasser, et son niveau d'objet doit tenir dans
// une fenetre autour du sien. La fenetre s'ouvre jusqu'a ce que quelque chose
// y tienne ; 0 quand la reserve est vide.
uint32 StellarTarotLoot::GearFor(uint8 quality, uint8 level)
{
    if (quality != ITEM_QUALITY_RARE && quality != ITEM_QUALITY_EPIC)
        return 0;
    std::vector<Gear> const& reserve = gear[quality - ITEM_QUALITY_RARE];
    if (reserve.empty())
        return 0;
    std::vector<uint32> good;
    for (uint16 window = 10; window <= 60 && good.empty(); window += 10)
        for (Gear const& piece : reserve)
            if (piece.required <= level && piece.itemLevel + window >= level
                && piece.itemLevel <= level + window)
                good.push_back(piece.entry);
    // Rien dans aucune fenetre : ce que le joueur peut porter de plus haut.
    if (good.empty())
    {
        uint16 best = 0;
        for (Gear const& piece : reserve)
            if (piece.required <= level && piece.itemLevel > best)
                best = piece.itemLevel;
        for (Gear const& piece : reserve)
            if (piece.required <= level && piece.itemLevel == best)
                good.push_back(piece.entry);
    }
    return good.empty() ? 0 : good[urand(0, uint32(good.size()) - 1)];
}

// UNE HERBE de l'age du joueur, 0 quand la reserve est vide.
uint32 StellarTarotLoot::HerbFor(uint8 level)
{
    std::vector<uint32> const& age = herbs[CrateAgeOf(level)];
    return age.empty() ? 0 : age[urand(0, uint32(age.size()) - 1)];
}

// One grey trinket of the player's own age, 0 when the reserve is empty.
uint32 StellarTarotLoot::GreyItemFor(uint8 level)
{
    std::vector<uint32> const& age = junk[CrateAgeOf(level)];
    return age.empty() ? 0 : age[urand(0, uint32(age.size()) - 1)];
}

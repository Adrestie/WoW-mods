/*
 * mod-papota-spherier — etat de spherier des personnages (jalon 2).
 *
 * Persistance en ecriture immediate : chaque mutation (gain de points,
 * activation, remise a zero) part en base dans la foulee — une activation est
 * un evenement rare, la simplicite prime. L'etat en memoire ne vit qu'entre
 * la connexion et la deconnexion.
 */

#include "SpherierPlayerMgr.h"
#include "SpherierMgr.h"
#include "SpherierStrings.h"

#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Field.h"
#include "Group.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "Opcodes.h"
#include "SpellMgr.h"
#include "QueryResult.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>

// Les bots de mod-playerbots n'ont pas de spherier : on ne charge rien pour
// eux. Sans le module (MOD_PLAYERBOTS absent), tout joueur est un vrai joueur.
#if defined(MOD_PLAYERBOTS)
#include "Playerbots.h"
static bool EstUnBot(Player* player) { return GET_PLAYERBOT_AI(player) != nullptr; }
#else
static bool EstUnBot(Player* /*player*/) { return false; }
#endif

SpherierPlayerMgr* SpherierPlayerMgr::instance()
{
    static SpherierPlayerMgr instance;
    return &instance;
}

// LE COMPTE D'UN JOUEUR. Sans session — un cas qui n'arrive pas en pratique
// mais que le coeur autorise — on rend zero, ce qui donne un compte sans
// Spherite plutot qu'un plantage.
static uint32 CompteDe(Player const* player)
{
    WorldSession const* session = player ? player->GetSession() : nullptr;
    return session ? session->GetAccountId() : 0;
}

void SpherierPlayerMgr::Charger(Player* player)
{
    if (!player || EstUnBot(player))
        return;

    uint32 const guid = player->GetGUID().GetCounter();
    SpherierEtatJoueur etat;


    // DEUX SOURCES DEPUIS LE 2026-09-04 : ce qui est GAGNE appartient au
    // COMPTE — un boss tue sur un personnage credite tous les autres, et un
    // personnage cree demain nait avec la totalite. Ce qui est DEPENSE reste
    // propre au personnage : chacun a sa grille et ses achats.
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT earned, prismes FROM account_sphere_points WHERE account_id = {}",
        CompteDe(player)))
    {
        etat.earned  = result->Fetch()[0].Get<uint32>();
        etat.prismes = result->Fetch()[1].Get<uint32>();
    }

    if (QueryResult result = CharacterDatabase.Query(
        "SELECT spent FROM character_sphere_points WHERE guid = {}", guid))
    {
        etat.spent = result->Fetch()[0].Get<uint32>();
    }

    if (QueryResult result = CharacterDatabase.Query(
        "SELECT node_id, content_entry, content_upgrade, oublie FROM character_sphere_node WHERE guid = {}", guid))
    {
        do
        {
            Field* f = result->Fetch();
            etat.actives[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
            if (f[3].Get<uint8>())
                etat.oublies.insert(f[0].Get<uint32>());
        } while (result->NextRow());
    }

    // UN SORT ARRIVE APRES L'ACHAT (2026-09-06) : l'emplacement de sort achete
    // alors que la classe n'y avait rien s'est vu affecter un sort depuis ; il
    // l'apprend sans repayer. Seul l'oubli a l'epingle exige un nouvel achat.
    for (auto& [nodeId, contenu] : etat.actives)
    {
        SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
        if (!def || def->kind != SPHERIER_SORT || contenu.first || etat.oublies.count(nodeId))
            continue;
        uint32 const sort = sSpherierMgr->SortDe(*def, player->getClass());
        if (!sort)
            continue;
        contenu.first = sort;
        CharacterDatabase.DirectExecute(
            "UPDATE character_sphere_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
            sort, guid, nodeId);
    }

    // LE CONTENU DES NOEUDS A PIERRES APPARTIENT AU COMPTE (2026-09-06) : la
    // ligne de compte prime, sinon la pierre d'origine. La ligne du personnage
    // ne fait plus foi pour eux — elle reste vraie pour les slots et les sorts.
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT node_id, content_entry, content_upgrade FROM account_sphere_node WHERE account_id = {}",
        CompteDe(player)))
    {
        do
        {
            Field* f = result->Fetch();
            etat.contenuCompte[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
        } while (result->NextRow());
    }
    for (auto& [nodeId, contenu] : etat.actives)
    {
        SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
        if (!def || def->kind != SPHERIER_NOEUD)
            continue;
        auto compte = etat.contenuCompte.find(nodeId);
        if (compte != etat.contenuCompte.end())
            contenu = compte->second;
        else
            contenu = { def->defaultStoneEntry, uint8(0) };
    }

    _etats[player->GetGUID()] = std::move(etat);

    // Les modificateurs de statistiques ne survivent pas a une deconnexion :
    // on repose le bloc a chaque connexion.
    _blocs.erase(player->GetGUID());
    Recalculer(player);
}

void SpherierPlayerMgr::Decharger(Player* player)
{
    if (!player)
        return;
    _etats.erase(player->GetGUID());
    _blocs.erase(player->GetGUID());
}

SpherierEtatJoueur* SpherierPlayerMgr::Etat(Player* player)
{
    if (!player)
        return nullptr;
    auto it = _etats.find(player->GetGUID());
    return it != _etats.end() ? &it->second : nullptr;
}

SpherierActivation SpherierPlayerMgr::Activer(Player* player, uint32 nodeId)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return SpherierActivation::EtatAbsent;

    SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
    if (!def)
        return SpherierActivation::EmplacementInconnu;
    // LA CLASSE 0 EST LA GRILLE COMMUNE (2026-09-05) : elle est a tout le monde.
    if (def->classId && def->classId != player->getClass())
        return SpherierActivation::MauvaiseClasse;

    // Le sort d'un emplacement de sort est celui de LA CLASSE DU JOUEUR
    // (grille commune, 2026-09-05) ; l'entree memorisee est ce sort-la.
    uint32 const sort = (def->kind == SPHERIER_SORT) ? sSpherierMgr->SortDe(*def, player->getClass()) : 0;
    // Sans sort pour sa classe, l'emplacement n'existe pas pour ce joueur —
    // l'interface ne le montre pas, il ne s'achete pas non plus.
    if (def->kind == SPHERIER_SORT && !sort)
        return SpherierActivation::MauvaiseClasse;

    if (auto deja = etat->actives.find(nodeId); deja != etat->actives.end())
    {
        // Un emplacement de sort vide par l'epingle se rallume d'un nouveau
        // clic, au COUT HABITUEL d'un emplacement (arbitrage du 2026-08-24) : le
        // sort fait partie de la grille, seul l'apprentissage a ete perdu. Sans
        // ce chemin, l'oubli serait definitif — l'emplacement etant deja actif,
        // il n'y avait plus aucune reprise possible.
        if (def->kind == SPHERIER_SORT && !deja->second.first && sort)
        {
            uint32 const guid = player->GetGUID().GetCounter();

            // Pas oublie : le sort est arrive apres l'achat, il s'apprend sans
            // repayer (le cas que la connexion regle d'ordinaire).
            if (!etat->oublies.count(nodeId))
            {
                deja->second.first = sort;
                CharacterDatabase.DirectExecute(
                    "UPDATE character_sphere_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
                    sort, guid, nodeId);
                Recalculer(player);
                return SpherierActivation::Ok;
            }

            uint32 const prix = sSpherierMgr->CoutActivation(uint32(etat->actives.size()));
            if (etat->Disponibles() < prix)
                return SpherierActivation::PointsInsuffisants;

            etat->spent += prix;
            deja->second.first = sort;
            etat->oublies.erase(nodeId);

            auto trans = CharacterDatabase.BeginTransaction();
            trans->Append("UPDATE character_sphere_node SET content_entry = {}, oublie = 0 WHERE guid = {} AND node_id = {}",
                sort, guid, nodeId);
            trans->Append("REPLACE INTO account_sphere_points (account_id, earned, prismes) VALUES ({}, {}, {})",
                CompteDe(player), etat->earned, etat->prismes);
            trans->Append("REPLACE INTO character_sphere_points (guid, spent) VALUES ({}, {})",
                guid, etat->spent);
            CharacterDatabase.DirectCommitTransaction(trans);

            Recalculer(player);
            return SpherierActivation::Ok;
        }
        return SpherierActivation::DejaActif;
    }

    // Accessible : point de depart de la classe, ou voisin d'un emplacement actif.
    // Le depart est TOUJOURS celui de la classe du joueur : sur la grille
    // commune, dix classes partagent les emplacements mais chacune a le sien.
    bool accessible = (sSpherierMgr->Depart(player->getClass()) == nodeId);
    if (!accessible)
        for (uint32 voisin : def->voisins)
            if (etat->actives.count(voisin))
            {
                accessible = true;
                break;
            }
    if (!accessible)
        return SpherierActivation::NonAdjacent;

    uint32 const cout = sSpherierMgr->CoutActivation(uint32(etat->actives.size()));
    if (etat->Disponibles() < cout)
        return SpherierActivation::PointsInsuffisants;

    // Activer un noeud applique sa pierre pre-allouee (rien pour un noeud
    // vide) ; un slot reste vide ; un emplacement de sort enregistre son sort
    // — l'apprentissage effectif viendra avec l'application des effets.
    uint32 contenu = 0;
    if (def->kind == SPHERIER_NOEUD)
    {
        // Le compte a peut-etre deja garni ou vide ce noeud : c'est cela
        // que le personnage recoit, pas la pierre d'origine.
        auto compte = etat->contenuCompte.find(nodeId);
        contenu = (compte != etat->contenuCompte.end()) ? compte->second.first : def->defaultStoneEntry;
    }
    else if (def->kind == SPHERIER_SORT)
        contenu = sort;

    etat->spent += cout;
    etat->actives[nodeId] = { contenu, 0 };

    // Synchrone, comme SauverPoints : l'interface relit la base aussitot.
    uint32 const guid = player->GetGUID().GetCounter();
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("REPLACE INTO character_sphere_node (guid, node_id, content_entry, content_upgrade) "
        "VALUES ({}, {}, {}, 0)", guid, nodeId, contenu);
    trans->Append("REPLACE INTO account_sphere_points (account_id, earned, prismes) VALUES ({}, {}, {})",
        CompteDe(player), etat->earned, etat->prismes);
    trans->Append("REPLACE INTO character_sphere_points (guid, spent) VALUES ({}, {})",
        guid, etat->spent);
    CharacterDatabase.DirectCommitTransaction(trans);

    // Un noeud applique sa pierre pre-allouee sur-le-champ ; un emplacement de
    // sort apprend le sien.
    Recalculer(player);
    return SpherierActivation::Ok;
}

// Ecriture immediate ET synchrone du compteur, commune aux mutations de
// points. Synchrone a dessein : l'interface joueur (Lua) relit la base juste
// apres un achat via RunCommand — une ecriture asynchrone lui montrerait
// l'etat d'avant. Ces mutations sont rares, le cout est negligeable.
static void SauverPoints(Player* player, SpherierEtatJoueur const& etat)
{
    CharacterDatabase.DirectExecute(
        "REPLACE INTO account_sphere_points (account_id, earned, prismes) VALUES ({}, {}, {})",
        CompteDe(player), etat.earned, etat.prismes);
    CharacterDatabase.DirectExecute(
        "REPLACE INTO character_sphere_points (guid, spent) VALUES ({}, {})",
        player->GetGUID().GetCounter(), etat.spent);
}

bool SpherierPlayerMgr::AjouterPoints(Player* player, uint32 montant)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat || !montant)
        return false;

    etat->earned += montant;
    SauverPoints(player, *etat);

    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHERIER_MODULE, SPHERIER_STR_GAIN_JOUEUR, montant);
    return true;
}

uint32 SpherierPlayerMgr::Majorer(Player* player, uint32 montant)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return montant;
    // NEXUS PRISMATIQUE (2026-09-06) : chaque prisme absorbe par le compte
    // majore les gains de 25 %, sans plafond — +25 % au premier, +50 % au
    // deuxieme, et ainsi de suite.
    uint64 const majore = uint64(montant) * (100ull + 25ull * etat->prismes) / 100ull;
    return uint32(std::min<uint64>(majore, 0xFFFFFFFFull));
}

bool SpherierPlayerMgr::Gagner(Player* player, uint32 montant)
{
    if (!Etat(player) || !montant)
        return false;
    return AjouterPoints(player, Majorer(player, montant));
}

bool SpherierPlayerMgr::AbsorberPrisme(Player* player)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return false;
    ++etat->prismes;
    SauverPoints(player, *etat);
    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHERIER_MODULE, SPHERIER_STR_PRISME,
        etat->prismes, 25 * etat->prismes);
    return true;
}

bool SpherierPlayerMgr::RetirerPoints(Player* player, uint32 montant, uint32& retire)
{
    retire = 0;
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return false;

    retire = std::min(montant, etat->Disponibles());
    if (retire)
    {
        etat->earned -= retire;
        SauverPoints(player, *etat);
        ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHERIER_MODULE, SPHERIER_STR_PERTE_JOUEUR, retire);
    }
    return true;
}

bool SpherierPlayerMgr::FixerPoints(Player* player, uint32 disponibles)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return false;

    etat->earned = etat->spent + disponibles;
    SauverPoints(player, *etat);

    ChatHandler(player->GetSession()).PSendModuleSysMessage(SPHERIER_MODULE, SPHERIER_STR_FIXE_JOUEUR, disponibles);
    return true;
}

void SpherierPlayerMgr::CrediterBoss(Player* tueur, Creature* crea)
{
    if (!tueur || !crea)
        return;

    // Garde-fou de performance : ce hook part sur CHAQUE creature tuee par les
    // 2500 bots. Deux tests de drapeaux ecartent tout ce qui n'est pas un boss.
    bool const bossDonjon = crea->IsDungeonBoss();
    bool const bossMonde  = crea->isWorldBoss();
    if (!bossDonjon && !bossMonde)
        return;

    Map* map = crea->FindMap();
    if (!map)
        return;

    // LE CREDIT SE LIT PAR CARTE ET DIFFICULTE (2026-09-06) : la valeur d'une
    // instance est carte x 10 + rang de difficulte (1 = 10 N / normal,
    // 2 = 25 N / heroique, 3 = 10 HM, 4 = 25 HM). On cherche la ligne exacte,
    // puis « toute difficulte » (carte x 10), puis le defaut du type. Un boss
    // de monde hors instance a son propre type, cherche par entree de creature.
    char const* type;
    uint32 points = 0;
    if (map->IsDungeon())
    {
        type = map->IsRaid() ? "boss_raid" : "boss_donjon";
        points = sSpherierMgr->PointsPourInstance(type, map);
    }
    else if (bossMonde)
    {
        type = "boss_monde";
        points = sSpherierMgr->PointsPourSource(type, crea->GetEntry());
    }
    else
        return;

    if (!points)
        return;

    // Tout le groupe present dans la meme carte est credite — lecon du M+ : le
    // coup fatal appartient souvent a un autre membre, voire a un familier. Les
    // bots sont ecartes naturellement : AjouterPoints exige un etat charge.
    if (Group* groupe = tueur->GetGroup())
    {
        for (GroupReference* ref = groupe->GetFirstMember(); ref; ref = ref->next())
        {
            Player* membre = ref->GetSource();
            if (membre && membre->FindMap() == map)
                Gagner(membre, points);
        }
    }
    else
        Gagner(tueur, points);
}

bool SpherierPlayerMgr::CrediterSource(Player* player, std::string const& type, uint32 valeur)
{
    uint32 const points = sSpherierMgr->PointsPourSource(type, valeur);
    if (!points)
        return false;
    return Gagner(player, points);
}

bool SpherierPlayerMgr::CrediterInstance(Player* player, std::string const& type, Map const* map)
{
    uint32 const points = sSpherierMgr->PointsPourInstance(type, map);
    if (!points)
        return false;
    return Gagner(player, points);
}

// ---------------------------------------------------------------------------
// Application des statistiques (jalon 3)
// ---------------------------------------------------------------------------
// Le catalogue des 16 statistiques est projete ici sur les API du coeur. C'est
// la SEULE correspondance codee en dur du module — les montants, eux, viennent
// tous de papota_sphere_stone. Aucune aura, aucun DBC : des modificateurs
// directs, qu'on pose et retire nous-memes. Ils ne survivent pas a une
// deconnexion, d'ou le recalcul a chaque connexion.
static void AppliquerStat(Player* p, uint8 stat, int32 v, bool poser)
{
    if (!v)
        return;

    switch (stat)
    {
        case 1:  p->HandleStatFlatModifier(UNIT_MOD_STAT_STAMINA,   TOTAL_VALUE, float(v), poser); break;
        case 2:  p->HandleStatFlatModifier(UNIT_MOD_STAT_INTELLECT, TOTAL_VALUE, float(v), poser); break;
        case 3:  p->HandleStatFlatModifier(UNIT_MOD_STAT_SPIRIT,    TOTAL_VALUE, float(v), poser); break;
        case 4:  p->HandleStatFlatModifier(UNIT_MOD_STAT_AGILITY,   TOTAL_VALUE, float(v), poser); break;
        case 5:  p->HandleStatFlatModifier(UNIT_MOD_STAT_STRENGTH,  TOTAL_VALUE, float(v), poser); break;
        case 6:  p->ApplyRatingMod(CR_PARRY, v, poser); break;
        case 7:  p->ApplyRatingMod(CR_BLOCK, v, poser); break;
        case 8:  p->ApplyRatingMod(CR_DODGE, v, poser); break;
        // Hate, critique et toucher couvrent les trois ecoles : une seule
        // statistique de sphèrier, trois notes de combat.
        case 9:
            p->ApplyRatingMod(CR_HASTE_MELEE,  v, poser);
            p->ApplyRatingMod(CR_HASTE_RANGED, v, poser);
            p->ApplyRatingMod(CR_HASTE_SPELL,  v, poser);
            break;
        case 10:
            p->ApplyRatingMod(CR_CRIT_MELEE,  v, poser);
            p->ApplyRatingMod(CR_CRIT_RANGED, v, poser);
            p->ApplyRatingMod(CR_CRIT_SPELL,  v, poser);
            break;
        case 11:
            p->ApplyRatingMod(CR_HIT_MELEE,  v, poser);
            p->ApplyRatingMod(CR_HIT_RANGED, v, poser);
            p->ApplyRatingMod(CR_HIT_SPELL,  v, poser);
            break;
        case 12: p->ApplySpellPowerBonus(v, poser); break;
        case 13: p->HandleStatFlatModifier(UNIT_MOD_ATTACK_POWER, TOTAL_VALUE, float(v), poser); break;
        case 14: p->ApplyRatingMod(CR_ARMOR_PENETRATION, v, poser); break;
        case 15: p->ApplyRatingMod(CR_EXPERTISE, v, poser); break;
        case 16: p->ApplySpellHealingBonus(v, poser); break;
        default: break;
    }
}

// Les rangs supplementaires accordes par les runes, pour un joueur donne.
//
// Regle du §6 : les runes s'additionnent, et le joueur CONNAIT tous les rangs —
// deux runes de Pourfendre donnent les rangs 11 ET 12. Mais un rang custom
// n'existe que tant que le joueur connait le dernier rang de Blizzard dont il
// est la suite : un talent oublie desactive ses runes sur-le-champ, sans les
// perdre. C'est ce que verifie HasSpell sur le rang de base.
namespace
{
    // Nos rangs vivent au-dessus de cette borne ; en deca, c'est du Blizzard.
    constexpr uint32 SPHERIER_RANG_CUSTOM_MIN = 8500000;

    // Le dernier rang de Blizzard d'une famille, en remontant la chaine depuis
    // n'importe lequel des notres. Sert quand la DERNIERE rune d'une famille
    // vient d'etre retiree : il n'y a plus rien en main pour retrouver le rang
    // auquel le joueur doit revenir.
    uint32 DernierRangBlizzard(uint32 spellId)
    {
        while (spellId >= SPHERIER_RANG_CUSTOM_MIN)
        {
            uint32 const precedent = sSpellMgr->GetPrevSpellInChain(spellId);
            if (!precedent)
                return 0;
            spellId = precedent;
        }
        return spellId;
    }
}

void SpherierPlayerMgr::SynchroniserRunes(Player* player, SpherierEtatJoueur const& etat)
{
    // Combien de runes de chaque famille sont serties.
    std::unordered_map<uint32, uint8> comptes;
    for (auto const& [nodeId, contenu] : etat.actives)
    {
        if (!contenu.first)
            continue;
        if (sSpherierMgr->Rune(contenu.first))
            ++comptes[contenu.first];
    }

    // `sommets` retient, par famille, le rang le plus haut que le joueur doit
    // VOIR : le dernier des notres qu'il conserve, ou le dernier rang de
    // Blizzard quand il ne lui reste aucune rune.
    std::unordered_set<uint32> aConnaitre;
    std::unordered_map<uint32, uint32> sommets;

    for (auto const& [itemEntry, nombre] : comptes)
    {
        SpherierRune const* rune = sSpherierMgr->Rune(itemEntry);
        if (!rune || !rune->firstSpellId)
            continue;

        // Le rang de Blizzard doit etre connu, sinon la rune reste inerte.
        uint32 const rangBase = sSpellMgr->GetSpellWithRank(rune->firstSpellId, rune->baseRank, true);
        if (!rangBase || !player->HasSpell(rangBase))
            continue;

        uint32 sommet = rangBase;
        uint8 const accordes = std::min<uint8>(nombre, SpherierMgr::RUNES_PAR_SORT);
        for (uint8 i = 1; i <= accordes; ++i)
            if (uint32 spellId = sSpellMgr->GetSpellWithRank(rune->firstSpellId,
                                                             rune->baseRank + i, true))
            {
                aConnaitre.insert(spellId);
                sommet = spellId;
            }
        sommets[rune->firstSpellId] = sommet;
    }

    auto& poses = _rangs[player->GetGUID()];

    // Le sommet PRECEDENT, famille par famille : c'est l'identifiant que le
    // client affiche en ce moment, et donc celui qu'il faudra lui dire de
    // remplacer si l'on redescend.
    std::unordered_map<uint32, uint32> anciens;
    for (uint32 spellId : poses)
    {
        uint32 const bliz = DernierRangBlizzard(spellId);
        if (!bliz)
            continue;
        uint32 const premier = sSpellMgr->GetFirstSpellInChain(bliz);
        uint32& ancien = anciens[premier];
        if (spellId > ancien)
            ancien = spellId;
    }

    // Une famille dont la DERNIERE rune vient d'etre retiree ne figure plus
    // dans `comptes` : son sommet redevient le rang de Blizzard, qu'on
    // retrouve en remontant la chaine depuis le rang que l'on s'apprete a
    // retirer.
    for (uint32 spellId : poses)
    {
        if (aConnaitre.count(spellId))
            continue;
        uint32 const bliz = DernierRangBlizzard(spellId);
        if (!bliz)
            continue;
        uint32 const premier = sSpellMgr->GetFirstSpellInChain(bliz);
        if (!sommets.count(premier))
            sommets[premier] = bliz;
    }

    // LE CLIENT NE DEVINE PAS QU'UN RANG REDESCEND. Apprendre un rang
    // superieur lui est annonce par SMSG_SUPERCEDED_SPELL — « ce sort devient
    // celui-la » — et rien n'existe dans l'autre sens : le grimoire restait sur
    // son ancien affichage, les degats du rang du bas sous l'etiquette du rang
    // du haut, jusqu'a un /reload. On lui envoie le meme paquet a l'envers, et
    // AVANT le retrait : apres, il ne connaitrait plus l'identifiant a
    // remplacer. C'est aussi ce qui fait suivre le bouton de barre d'action.
    for (auto const& [premier, sommet] : sommets)
    {
        auto const ancien = anciens.find(premier);
        if (ancien == anciens.end() || !sommet || ancien->second <= sommet)
            continue;   // on monte, ou rien ne bouge : addSpell s'en charge

        WorldPacket data(SMSG_SUPERCEDED_SPELL, 8);
        data << uint32(ancien->second);
        data << uint32(sommet);
        player->SendDirectMessage(&data);
    }

    // Ce que le joueur doit connaitre, et rien de plus : on retire d'abord ce
    // qui n'a plus lieu d'etre — c'est le retrait « par le haut » de la pile,
    // qui tombe naturellement puisqu'on repart de l'ensemble voulu.
    for (uint32 spellId : poses)
        if (!aConnaitre.count(spellId) && player->HasSpell(spellId))
            player->removeSpell(spellId, SPEC_MASK_ALL, false);

    for (uint32 spellId : aConnaitre)
        if (!player->HasSpell(spellId))
            player->learnSpell(spellId);

    // RENDRE LA MAIN AU RANG PRECEDENT. Apprendre un rang superieur DESACTIVE
    // les rangs inferieurs (Player::addSpell : Active = false et
    // SMSG_SUPERCEDED_SPELL) et Player::removeSpell ne fait jamais l'inverse,
    // il le dit en toutes lettres : « can't be replaced by previous rank ».
    // Retirer une rune laissait donc le joueur SANS AUCUN rang, et pour de
    // bon, SendInitialSpells sautant les sorts inactifs.
    // On ne peut pas passer par addSpell, qui refuse de toucher a un sort deja
    // connu du bon spec ; ni par removeSpell + learnSpell, qui emporterait au
    // passage les sorts EXIGEANT celui-la (spell_required) sans les rendre.
    // On rallume donc le drapeau a la main.
    PlayerSpellMap& sorts = player->GetSpellMap();
    for (auto const& [premier, sommet] : sommets)
    {
        if (!sommet)
            continue;
        auto it = sorts.find(sommet);
        if (it == sorts.end() || !it->second)
            continue;
        if (it->second->Active || it->second->State == PLAYERSPELL_REMOVED)
            continue;

        it->second->Active = true;
        if (it->second->State != PLAYERSPELL_NEW && it->second->State != PLAYERSPELL_TEMPORARY)
            it->second->State = PLAYERSPELL_CHANGED;
        // Ceinture et bretelles apres le remplacement annonce plus haut : si le
        // client l'avait ignore, ce paquet-ci remet quand meme le sort dans son
        // grimoire. Il est sans effet quand il le connait deja.
        player->SendLearnPacket(sommet, true);
    }

    poses = std::move(aConnaitre);
}

// Depuis les crochets de talent : l'etat est deja charge, rien d'autre a faire
// que de remettre les rangs d'aplomb.
void SpherierPlayerMgr::SynchroniserRunes(Player* player)
{
    if (SpherierEtatJoueur* etat = Etat(player))
        SynchroniserRunes(player, *etat);
}

void SpherierPlayerMgr::Recalculer(Player* player)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return;

    SpherierBloc neuf{};
    for (auto const& [nodeId, contenu] : etat->actives)
    {
        SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
        if (!def || !contenu.first)
            continue;

        if (def->kind == SPHERIER_SORT)
        {
            // Un emplacement de sort n'apporte pas de statistique : il apprend
            // son sort. On n'enleve jamais ici — c'est l'epingle qui fait
            // oublier, explicitement.
            if (!player->HasSpell(contenu.first))
                player->learnSpell(contenu.first);
            continue;
        }

        if (SpherierPierre const* pierre = sSpherierMgr->Pierre(contenu.first))
            if (pierre->statId >= 1 && pierre->statId <= SPHERIER_NB_STATS)
                neuf[pierre->statId] += pierre->amount;
    }

    // Les runes de STATISTIQUE majorent ce que la grille vient de donner :
    // elles s'appliquent donc APRES la somme des pierres, et jamais sur une
    // valeur brute. Elles se cumulent, plafonnees comme les runes de rang.
    uint8 nbParStat[SPHERIER_NB_STATS + 1] = {};
    uint32 pctParStat[SPHERIER_NB_STATS + 1] = {};
    for (auto const& [nodeId, contenu] : etat->actives)
    {
        if (!contenu.first)
            continue;
        SpherierRuneStat const* rs = sSpherierMgr->RuneStat(contenu.first);
        if (!rs || rs->statId < 1 || rs->statId > SPHERIER_NB_STATS)
            continue;
        if (nbParStat[rs->statId] >= SpherierMgr::RUNES_PAR_SORT)
            continue;
        ++nbParStat[rs->statId];
        pctParStat[rs->statId] += rs->percent;
    }
    for (uint8 st = 1; st <= SPHERIER_NB_STATS; ++st)
        if (pctParStat[st] && neuf[st])
            neuf[st] += int32(int64(neuf[st]) * pctParStat[st] / 100);

    SynchroniserRunes(player, *etat);

    // Retrait de l'ancien bloc, pose du nouveau : jamais d'incrementiel.
    auto it = _blocs.find(player->GetGUID());
    if (it != _blocs.end())
        for (uint8 s = 1; s <= SPHERIER_NB_STATS; ++s)
            AppliquerStat(player, s, it->second[s], false);

    for (uint8 s = 1; s <= SPHERIER_NB_STATS; ++s)
        AppliquerStat(player, s, neuf[s], true);

    _blocs[player->GetGUID()] = neuf;
    player->UpdateAllStats();
}

SpherierBloc const* SpherierPlayerMgr::Bloc(Player* player) const
{
    if (!player)
        return nullptr;
    auto it = _blocs.find(player->GetGUID());
    return it != _blocs.end() ? &it->second : nullptr;
}

SpherierSertissage SpherierPlayerMgr::Sertir(Player* player, uint32 nodeId, uint32 itemEntry)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return SpherierSertissage::EtatAbsent;

    SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
    if (!def)
        return SpherierSertissage::EmplacementInconnu;

    auto actif = etat->actives.find(nodeId);
    if (actif == etat->actives.end())
        return SpherierSertissage::PasActif;
    if (actif->second.first)
        return SpherierSertissage::DejaOccupe;

    // Un noeud n'accepte que des pierres, un slot que des runes ; un
    // emplacement de sort ne se sertit pas.
    // Un slot accepte les DEUX sortes de rune : celles qui donnent un rang, et
    // celles qui majorent une statistique.
    SpherierRune const* rune = sSpherierMgr->Rune(itemEntry);
    SpherierRuneStat const* runeStat = sSpherierMgr->RuneStat(itemEntry);
    bool const pierre = sSpherierMgr->Pierre(itemEntry) != nullptr;
    if (def->kind == SPHERIER_NOEUD && !pierre)
        return SpherierSertissage::MauvaisType;
    if (def->kind == SPHERIER_SLOT && !rune && !runeStat)
        return SpherierSertissage::MauvaisType;
    if (def->kind != SPHERIER_NOEUD && def->kind != SPHERIER_SLOT)
        return SpherierSertissage::MauvaisType;

    // Une rune de RANG appartient a une classe : elle se loote sans condition,
    // mais ne se sertit que dans le spherier de la sienne. Les runes de
    // statistique n'ont pas cette attache, elles majorent ce que la grille
    // donne quelle que soit la classe.
    if (rune && rune->classId && rune->classId != player->getClass())
        return SpherierSertissage::MauvaiseClasse;

    // Trois runes identiques au plus dans toute la grille : au-dela, le
    // quatrieme rang n'existe pas et la rune serait perdue pour rien. Meme
    // plafond pour les runes de statistique, par la meme regle.
    if (rune || runeStat)
    {
        uint8 deja = 0;
        for (auto const& [autre, contenu] : etat->actives)
            if (contenu.first == itemEntry)
                ++deja;
        if (deja >= SpherierMgr::RUNES_PAR_SORT)
            return SpherierSertissage::TropDeRunes;
    }

    if (!player->HasItemCount(itemEntry, 1))
        return SpherierSertissage::ObjetAbsent;

    player->DestroyItemCount(itemEntry, 1, true);
    actif->second.first = itemEntry;

    CharacterDatabase.DirectExecute(
        "UPDATE character_sphere_node SET content_entry = {} WHERE guid = {} AND node_id = {}",
        itemEntry, player->GetGUID().GetCounter(), nodeId);
    // Une pierre dans un noeud vaut pour tout le compte.
    if (def->kind == SPHERIER_NOEUD)
    {
        etat->contenuCompte[nodeId] = { itemEntry, uint8(0) };
        CharacterDatabase.DirectExecute(
            "REPLACE INTO account_sphere_node (account_id, node_id, content_entry, content_upgrade) "
            "VALUES ({}, {}, {}, 0)", CompteDe(player), nodeId, itemEntry);
    }

    Recalculer(player);
    return SpherierSertissage::Ok;
}

SpherierSertissage SpherierPlayerMgr::Epingler(Player* player, uint32 nodeId, bool consommerEpingle)
{
    SpherierEtatJoueur* etat = Etat(player);
    if (!etat)
        return SpherierSertissage::EtatAbsent;

    SpherierEmplacement const* def = sSpherierMgr->Emplacement(nodeId);
    if (!def)
        return SpherierSertissage::EmplacementInconnu;

    auto actif = etat->actives.find(nodeId);
    if (actif == etat->actives.end())
        return SpherierSertissage::PasActif;
    if (!actif->second.first)
        return SpherierSertissage::DejaOccupe;    // deja vide : rien a effacer

    uint32 const epingle = sSpherierMgr->EpingleEntry();
    if (consommerEpingle)
    {
        if (!epingle || !player->HasItemCount(epingle, 1))
            return SpherierSertissage::ObjetAbsent;
        player->DestroyItemCount(epingle, 1, true);
    }

    // Sur un emplacement de sort, le sort est oublie mais reste dans la
    // grille : l'emplacement demeure actif et pourra etre reappris.
    if (def->kind == SPHERIER_SORT)
    {
        player->removeSpell(actif->second.first, SPEC_MASK_ALL, false);
        etat->oublies.insert(nodeId);       // un nouvel achat le rapprendra
    }

    actif->second.first = 0;
    actif->second.second = 0;

    CharacterDatabase.DirectExecute(
        "UPDATE character_sphere_node SET content_entry = 0, content_upgrade = 0, oublie = {} "
        "WHERE guid = {} AND node_id = {}", (def->kind == SPHERIER_SORT) ? 1 : 0,
        player->GetGUID().GetCounter(), nodeId);
    // Un noeud vide a l'epingle l'est pour tout le compte.
    if (def->kind == SPHERIER_NOEUD)
    {
        etat->contenuCompte[nodeId] = { 0, uint8(0) };
        CharacterDatabase.DirectExecute(
            "REPLACE INTO account_sphere_node (account_id, node_id, content_entry, content_upgrade) "
            "VALUES ({}, {}, 0, 0)", CompteDe(player), nodeId);
    }

    Recalculer(player);
    return SpherierSertissage::Ok;
}

void SpherierPlayerMgr::Reinitialiser(Player* player)
{
    if (!player)
        return;

    uint32 const guid = player->GetGUID().GetCounter();
    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("DELETE FROM character_sphere_node WHERE guid = {}", guid);
    // LA SPHERITE DU COMPTE SURVIT : on n'efface que ce que CE personnage a
    // depense. Effacer la ligne de compte ici ruinerait tous ses autres
    // personnages pour la remise a zero d'un seul.
    trans->Append("DELETE FROM character_sphere_points WHERE guid = {}", guid);
    CharacterDatabase.DirectCommitTransaction(trans);

    auto it = _etats.find(player->GetGUID());
    if (it != _etats.end())
    {
        uint32 const gagne = it->second.earned;   // au compte, pas au personnage
        auto contenuCompte = std::move(it->second.contenuCompte);   // au compte aussi
        it->second = SpherierEtatJoueur();
        it->second.earned = gagne;
        it->second.contenuCompte = std::move(contenuCompte);
    }

    // Recalcul sur un etat vide : retire tout ce que le sphèrier avait pose.
    Recalculer(player);
}

// TOUT LE COMPTE, d'un coup : la Spherite gagnee et les grilles de TOUS ses
// personnages, connectes ou non.
//
// TROIS EFFACEMENTS ET PAS DEUX. `Reinitialiser` ne touche qu'un personnage et
// laisse expres la Spherite du compte — ici on la veut aussi. Les jointures sur
// `characters` sont ce qui atteint les personnages hors ligne : leur etat ne
// vit qu'en base, personne ne le tient en memoire.
//
// L'ETAT EN MEMOIRE n'est remis a zero que pour le joueur passe : un compte n'a
// qu'une session, ses autres personnages reliront la base a leur prochaine
// connexion.
uint32 SpherierPlayerMgr::EffacerCompte(Player* player)
{
    if (!player)
        return 0;

    uint32 const compte = CompteDe(player);
    if (!compte)
        return 0;

    uint32 nombre = 0;
    if (QueryResult result = CharacterDatabase.Query(
        "SELECT COUNT(*) FROM characters WHERE account = {}", compte))
    {
        nombre = result->Fetch()[0].Get<uint32>();
    }

    auto trans = CharacterDatabase.BeginTransaction();
    trans->Append("DELETE n FROM character_sphere_node n "
        "JOIN characters c ON c.guid = n.guid WHERE c.account = {}", compte);
    trans->Append("DELETE p FROM character_sphere_points p "
        "JOIN characters c ON c.guid = p.guid WHERE c.account = {}", compte);
    trans->Append("DELETE FROM account_sphere_points WHERE account_id = {}", compte);
    trans->Append("DELETE FROM account_sphere_node WHERE account_id = {}", compte);
    CharacterDatabase.DirectCommitTransaction(trans);

    auto it = _etats.find(player->GetGUID());
    if (it != _etats.end())
        it->second = SpherierEtatJoueur();   // gagne compris, cette fois

    Recalculer(player);
    return nombre;
}

/*
 * mod-papota-spherier — chargement et controle de la definition.
 */

#include "SpherierMgr.h"
#include "DatabaseEnv.h"
#include "Field.h"
#include "Log.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "QueryResult.h"

#include <deque>
#include <vector>
#include <unordered_set>

SpherierMgr* SpherierMgr::instance()
{
    static SpherierMgr instance;
    return &instance;
}

void SpherierMgr::Charger()
{
    _emplacements.clear();
    _departs.clear();
    _bareme.clear();
    _pointsObjets.clear();
    _pointsSources.clear();
    _pierres.clear();
    _runes.clear();
    _runesStat.clear();
    _reglages.clear();
    _sortsClasse.clear();
    _nbLiaisons = 0;

    if (QueryResult result = WorldDatabase.Query(
        "SELECT node_id, class_id, kind, grid_x, grid_y, icon, name, default_stone_entry, spell_id FROM papota_sphere_node"))
    {
        do
        {
            Field* f = result->Fetch();
            SpherierEmplacement e;
            e.nodeId            = f[0].Get<uint32>();
            e.classId           = f[1].Get<uint8>();
            e.kind              = f[2].Get<uint8>();
            e.gridX             = f[3].Get<float>();
            e.gridY             = f[4].Get<float>();
            e.icon              = f[5].Get<std::string>();
            e.name              = f[6].Get<std::string>();
            e.defaultStoneEntry = f[7].Get<uint32>();
            e.spellId           = f[8].Get<uint32>();
            _emplacements[e.nodeId] = std::move(e);
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT class_id, node_a, node_b FROM papota_sphere_edge"))
    {
        do
        {
            Field* f = result->Fetch();
            uint8 classId = f[0].Get<uint8>();
            uint32 a = f[1].Get<uint32>();
            uint32 b = f[2].Get<uint32>();

            auto itA = _emplacements.find(a);
            auto itB = _emplacements.find(b);
            if (a == b || itA == _emplacements.end() || itB == _emplacements.end()
                || itA->second.classId != classId || itB->second.classId != classId)
            {
                LOG_WARN("module", "Spherier : liaison invalide ignoree (classe {}, {} - {}).", classId, a, b);
                continue;
            }

            itA->second.voisins.push_back(b);
            itB->second.voisins.push_back(a);
            ++_nbLiaisons;
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT class_id, node_id FROM papota_sphere_start"))
    {
        do
        {
            Field* f = result->Fetch();
            _departs[f[0].Get<uint8>()] = f[1].Get<uint32>();
        } while (result->NextRow());
    }

    // SORTS PAR CLASSE (2026-09-05) : la grille commune place ses emplacements
    // de sort a des positions fixes ; chaque classe y apprend le sien.
    if (QueryResult result = WorldDatabase.Query("SELECT node_id, class_id, spell_id FROM papota_sphere_node_spell"))
    {
        do
        {
            Field* f = result->Fetch();
            _sortsClasse[{ f[0].Get<uint32>(), f[1].Get<uint8>() }] = f[2].Get<uint32>();
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT activated_min, cost FROM papota_sphere_cost"))
    {
        do
        {
            Field* f = result->Fetch();
            _bareme[f[0].Get<uint32>()] = f[1].Get<uint32>();
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT item_entry, points FROM papota_sphere_item"))
    {
        do
        {
            Field* f = result->Fetch();
            _pointsObjets[f[0].Get<uint32>()] = f[1].Get<uint32>();
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT source_type, source_value, points FROM papota_sphere_point_source"))
    {
        do
        {
            Field* f = result->Fetch();
            _pointsSources[{ f[0].Get<std::string>(), f[1].Get<uint32>() }] = f[2].Get<uint32>();
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT item_entry, stat_id, amount FROM papota_sphere_stone"))
    {
        do
        {
            Field* f = result->Fetch();
            SpherierPierre p;
            p.statId = f[1].Get<uint8>();
            p.amount = f[2].Get<int32>();
            // Pierre-objet ou pierre de noeud : le gabarit d'objet tranche.
            p.objet  = sObjectMgr->GetItemTemplate(f[0].Get<uint32>()) != nullptr;
            _pierres[f[0].Get<uint32>()] = p;
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query(
        "SELECT item_entry, first_spell_id, base_rank, class_id FROM papota_sphere_rune"))
    {
        do
        {
            Field* f = result->Fetch();
            SpherierRune r;
            r.firstSpellId = f[1].Get<uint32>();
            r.baseRank = f[2].Get<uint8>();
            r.classId = f[3].Get<uint8>();
            _runes[f[0].Get<uint32>()] = r;
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query(
        "SELECT item_entry, stat_id, percent FROM papota_sphere_stat_rune"))
    {
        do
        {
            Field* f = result->Fetch();
            SpherierRuneStat r;
            r.statId = f[1].Get<uint8>();
            r.percent = f[2].Get<uint16>();
            _runesStat[f[0].Get<uint32>()] = r;
        } while (result->NextRow());
    }

    if (QueryResult result = WorldDatabase.Query("SELECT cle, valeur FROM papota_sphere_config"))
    {
        do
        {
            Field* f = result->Fetch();
            _reglages[f[0].Get<std::string>()] = f[1].Get<uint32>();
        } while (result->NextRow());
    }

    uint32 noeuds = 0, slots = 0, sorts = 0;
    for (auto const& [id, e] : _emplacements)
    {
        if (e.kind == SPHERIER_NOEUD)      ++noeuds;
        else if (e.kind == SPHERIER_SLOT)  ++slots;
        else if (e.kind == SPHERIER_SORT)  ++sorts;
    }

    LOG_INFO("module", "Spherier : {} emplacements ({} noeuds, {} slots, {} sorts), {} liaisons, {} depart(s), "
        "{} tranche(s) de cout, {} pierre(s), {} rune(s) de rang, {} rune(s) de "
        "statistique, {} objet(s) de points, {} source(s) d'accroche.",
        _emplacements.size(), noeuds, slots, sorts, _nbLiaisons, _departs.size(),
        _bareme.size(), _pierres.size(), _runes.size(), _runesStat.size(),
        _pointsObjets.size(), _pointsSources.size());

    Verifier();
}

void SpherierMgr::Verifier() const
{
    // Classes presentes dans la grille.
    std::unordered_set<uint8> classes;
    for (auto const& [id, e] : _emplacements)
    {
        classes.insert(e.classId);

        // Un noeud vide est legal (revision du 2026-08-23) ; en revanche un
        // slot ne porte jamais de pierre, et un emplacement de sort sans sort
        // est un trou de contenu.
        if (e.kind == SPHERIER_SLOT && e.defaultStoneEntry)
            LOG_WARN("module", "Spherier : le slot {} (classe {}) porte une pierre pre-allouee.", id, e.classId);
        else if (e.kind == SPHERIER_SORT)
        {
            // Sans sort pour une classe, l'emplacement est simplement invisible
            // pour elle (2026-09-05). Sans sort pour PERSONNE, il n'existe pour
            // personne : cela merite un mot.
            bool utile = e.spellId != 0;
            for (auto const& [classId, nodeId] : _departs)
                if (SortDe(e, classId))
                    utile = true;
            if (!utile)
                LOG_WARN("module", "Spherier : l'emplacement de sort {} n'a de sort pour aucune classe.", id);
        }
    }

    // LA GRILLE COMMUNE (classe 0) : ses emplacements sont a tout le monde, et
    // ses departs sont ceux des classes — un par classe, poses dessus. Un depart
    // peut donc viser un emplacement de sa classe OU de la classe 0.
    bool const commune = classes.count(0) > 0;
    for (auto const& [classId, nodeId] : _departs)
    {
        auto it = _emplacements.find(nodeId);
        if (it == _emplacements.end()
            || (it->second.classId != classId && it->second.classId != 0))
            LOG_WARN("module", "Spherier : le depart de la classe {} pointe sur l'emplacement inconnu {}.", classId, nodeId);
    }

    // Connexite : tout emplacement d'une classe doit etre atteignable depuis son
    // depart — le defaut le plus facile a laisser passer en editant une grille.
    // Pour la grille commune, on verifie depuis CHAQUE depart de classe que
    // tous les emplacements de la classe 0 sont atteints.
    std::vector<std::pair<uint8, uint8>> aVerifier;   // (classe du depart, classe des emplacements)
    for (uint8 classId : classes)
        if (classId != 0)
            aVerifier.emplace_back(classId, classId);
    if (commune)
        for (auto const& [classId, nodeId] : _departs)
            aVerifier.emplace_back(classId, 0);

    for (auto const& [classeDepart, classeGrille] : aVerifier)
    {
        auto itDepart = _departs.find(classeDepart);
        if (itDepart == _departs.end())
        {
            LOG_WARN("module", "Spherier : la classe {} a des emplacements mais pas de depart.", classeDepart);
            continue;
        }
        if (!_emplacements.count(itDepart->second))
            continue;   // deja signale ci-dessus
        uint8 const classId = classeGrille;

        // VISIBILITE PAR CLASSE (2026-09-05) : un emplacement de sort sans
        // sort pour la classe n'existe pas pour elle, ni ses liaisons. Le
        // parcours ne le traverse pas et ne le compte pas.
        auto cache = [&](uint32 nodeId)
        {
            SpherierEmplacement const& e = _emplacements.at(nodeId);
            return e.kind == SPHERIER_SORT && !SortDe(e, classeDepart);
        };
        if (cache(itDepart->second))
        {
            LOG_WARN("module", "Spherier : le depart de la classe {} ({}) est un emplacement de sort sans sort pour elle.",
                classeDepart, itDepart->second);
            continue;
        }

        std::unordered_set<uint32> vus;
        std::deque<uint32> file { itDepart->second };
        vus.insert(itDepart->second);
        while (!file.empty())
        {
            uint32 courant = file.front();
            file.pop_front();
            for (uint32 voisin : _emplacements.at(courant).voisins)
                if (!cache(voisin) && vus.insert(voisin).second)
                    file.push_back(voisin);
        }

        uint32 total = 0;
        for (auto const& [id, e] : _emplacements)
            if (e.classId == classId && !cache(id))
                ++total;

        if (vus.size() < total)
            LOG_WARN("module", "Spherier : classe {} (depart de la classe {}) — {} emplacement(s) sur {} non relie(s) au depart.",
                classId, classeDepart, total - vus.size(), total);
    }
}

SpherierEmplacement const* SpherierMgr::Emplacement(uint32 nodeId) const
{
    auto it = _emplacements.find(nodeId);
    return it != _emplacements.end() ? &it->second : nullptr;
}

uint32 SpherierMgr::SortDe(SpherierEmplacement const& e, uint8 classId) const
{
    auto it = _sortsClasse.find({ e.nodeId, classId });
    if (it != _sortsClasse.end() && it->second)
        return it->second;
    return e.spellId;
}

uint32 SpherierMgr::Depart(uint8 classId) const
{
    auto it = _departs.find(classId);
    return it != _departs.end() ? it->second : 0;
}

uint32 SpherierMgr::CoutActivation(uint32 dejaActives) const
{
    // La tranche applicable est la derniere dont le seuil est atteint.
    uint32 cout = 0;
    for (auto const& [seuil, prix] : _bareme)
    {
        if (seuil > dejaActives)
            break;
        cout = prix;
    }
    return cout;
}

uint32 SpherierMgr::PointsPourObjet(uint32 itemEntry) const
{
    auto it = _pointsObjets.find(itemEntry);
    return it != _pointsObjets.end() ? it->second : 0;
}

SpherierPierre const* SpherierMgr::Pierre(uint32 itemEntry) const
{
    auto it = _pierres.find(itemEntry);
    return it != _pierres.end() ? &it->second : nullptr;
}

SpherierRuneStat const* SpherierMgr::RuneStat(uint32 itemEntry) const
{
    auto it = _runesStat.find(itemEntry);
    return it != _runesStat.end() ? &it->second : nullptr;
}

SpherierRune const* SpherierMgr::Rune(uint32 itemEntry) const
{
    auto it = _runes.find(itemEntry);
    return it != _runes.end() ? &it->second : nullptr;
}

uint32 SpherierMgr::Reglage(std::string const& cle) const
{
    auto it = _reglages.find(cle);
    return it != _reglages.end() ? it->second : 0;
}

uint32 SpherierMgr::PointsPourSource(std::string const& type, uint32 valeur) const
{
    auto it = _pointsSources.find({ type, valeur });
    if (it == _pointsSources.end() && valeur)
        it = _pointsSources.find({ type, 0 });
    return it != _pointsSources.end() ? it->second : 0;
}

uint32 SpherierMgr::PointsPourSourceExact(std::string const& type, uint32 valeur) const
{
    auto it = _pointsSources.find({ type, valeur });
    return it != _pointsSources.end() ? it->second : 0;
}

uint32 SpherierMgr::PointsPourInstance(std::string const& type, Map const* map) const
{
    if (!map)
        return PointsPourSourceExact(type, 0);
    uint32 const difficulte = uint32(map->GetDifficulty());
    uint32 const carte = map->GetId() * 10;
    uint32 points = PointsPourSourceExact(type, carte + difficulte + 1);
    if (!points)
        points = PointsPourSourceExact(type, carte);
    if (!points && !map->IsRaid() && map->GetEntry())
        points = PointsPourSourceExact(type, map->GetEntry()->Expansion() * 3 + difficulte + 1);
    if (!points)
        points = PointsPourSourceExact(type, 0);
    return points;
}

/*
 * mod-papota-spherier — systeme de talents custom « sphérier » du serveur Papota.
 *
 * Jalon 1 : definition en memoire, chargee depuis la base world et rechargeable
 * par .spherier reload. Aucun effet de jeu. Document de reference :
 * D:\Serveur WoW\SPHERIER_CONCEPTION.md — le vocabulaire (noeud, slot, pierre,
 * rune, sphere) et le modele de donnees viennent de la.
 *
 * Principe directeur : aucune valeur chiffree dans le code, tout vit dans les
 * tables papota_sphere_* et se recharge a chaud.
 */

#ifndef MOD_PAPOTA_SPHERIER_MGR_H_
#define MOD_PAPOTA_SPHERIER_MGR_H_

#include "Define.h"
#include <map>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

enum SpherierEmplacementType : uint8
{
    SPHERIER_NOEUD = 0,     // emplacement a pierres — pre-rempli, ou vide (revision 2026-08-23)
    SPHERIER_SLOT  = 1,     // vide a la creation, n'accepte que des runes
    SPHERIER_SORT  = 2      // porte un sort custom inedit, fixe dans la grille
};

struct SpherierEmplacement
{
    uint32 nodeId = 0;
    uint8  classId = 0;
    uint8  kind = SPHERIER_NOEUD;
    float  gridX = 0.0f;
    float  gridY = 0.0f;
    std::string icon;
    std::string name;
    uint32 defaultStoneEntry = 0;       // NOEUD uniquement, 0 = noeud vide
    uint32 spellId = 0;                 // SORT uniquement
    std::vector<uint32> voisins;        // adjacence, remplie par papota_sphere_edge
};

// Effet chiffre d'une pierre : rang dans le catalogue des 16 statistiques, et
// montant. Les deux vivent en base (papota_sphere_stone), jamais dans le code.
struct SpherierPierre
{
    uint8 statId = 0;
    int32 amount = 0;
    // Vrai pour une pierre-OBJET (item_template existe) : ce que le joueur
    // loote, sertit, fusionne. Faux pour une PIERRE DE NOEUD (2026-09-05),
    // entree que seuls les emplacements pre-alloues portent — l'etabli ne
    // doit jamais en produire une.
    bool objet = false;
};

// Ce qu'une rune de rang ameliore. `baseRank` est le nombre de rangs de
// BLIZZARD : la premiere rune sertie donne le rang baseRank + 1, la deuxieme le
// suivant, la troisieme le dernier. Les rangs customs eux-memes sont retrouves
// par la chaine spell_ranks, jamais recalcules.
struct SpherierRune
{
    uint32 firstSpellId = 0;
    uint8  baseRank = 0;
    // Seule cette classe peut la SERTIR. Elle se loote en revanche sans
    // condition — c'est l'etabli qui la rendra utile (§6).
    uint8  classId = 0;
};

// Ce qu'une rune de STATISTIQUE majore. Elle ne donne pas de points : elle
// augmente d'un pourcentage ce que la GRILLE accorde deja dans cette
// statistique. Le pourcentage vit en base (papota_sphere_stat_rune), jamais
// dans le code, et se cumule jusqu'a RUNES_PAR_SORT.
struct SpherierRuneStat
{
    uint8  statId = 0;
    uint16 percent = 0;
};

class Map;

class SpherierMgr
{
public:
    static SpherierMgr* instance();

    // Recharge l'integralite de la definition depuis la base world.
    // Appele au demarrage (avant l'ouverture du monde) et par .spherier reload.
    void Charger();

    [[nodiscard]] SpherierEmplacement const* Emplacement(uint32 nodeId) const;
    [[nodiscard]] uint32 Depart(uint8 classId) const;               // 0 si aucun
    // SORTS PAR CLASSE (2026-09-05) : sur la grille commune, un emplacement de
    // sort apprend a chaque classe LE SIEN (papota_sphere_node_spell) ; le
    // spell_id de l'emplacement reste le repli « toutes classes ». 0 si rien.
    [[nodiscard]] uint32 SortDe(SpherierEmplacement const& e, uint8 classId) const;
    [[nodiscard]] uint32 CoutActivation(uint32 dejaActives) const;  // 0 si bareme vide
    [[nodiscard]] uint32 PointsPourObjet(uint32 itemEntry) const;   // 0 si inconnu
    // Cherche (type, valeur) puis retombe sur (type, 0), le defaut du type.
    [[nodiscard]] uint32 PointsPourSource(std::string const& type, uint32 valeur) const;
    // (type, valeur) SANS repli : 0 si la ligne n'existe pas.
    [[nodiscard]] uint32 PointsPourSourceExact(std::string const& type, uint32 valeur) const;
    // Le bareme d'une INSTANCE (2026-09-06) : (type, carte x 10 + difficulte + 1)
    // exacte, puis (type, carte x 10) toute difficulte, puis — donjons — le
    // palier d'extension (valeur < 10 : extension x 3 + difficulte + 1 :
    // 1 vanilla, 4 BC, 5 BC heroique, 7 WotLK, 8 WotLK heroique), puis (type, 0).
    [[nodiscard]] uint32 PointsPourInstance(std::string const& type, Map const* map) const;
    // Effet d'une pierre, nullptr si l'entree n'en est pas une.
    [[nodiscard]] SpherierPierre const* Pierre(uint32 itemEntry) const;
    // Sort ameliore par une rune, nullptr si l'entree n'en est pas une.
    [[nodiscard]] SpherierRune const* Rune(uint32 itemEntry) const;
    // Statistique majoree par une rune, nullptr si l'entree n'en est pas une.
    [[nodiscard]] SpherierRuneStat const* RuneStat(uint32 itemEntry) const;
    // Nombre maximal de runes identiques dans une meme grille (§6).
    static constexpr uint8 RUNES_PAR_SORT = 3;
    [[nodiscard]] uint32 Reglage(std::string const& cle) const;     // 0 si absent
    [[nodiscard]] uint32 EpingleEntry() const { return Reglage("epingle_entry"); }

    [[nodiscard]] std::unordered_map<uint32, SpherierEmplacement> const& Emplacements() const { return _emplacements; }
    [[nodiscard]] std::map<uint8, uint32> const& Departs() const { return _departs; }
    [[nodiscard]] std::map<std::pair<uint32, uint8>, uint32> const& SortsClasse() const { return _sortsClasse; }
    [[nodiscard]] std::map<uint32, uint32> const& Bareme() const { return _bareme; }
    [[nodiscard]] std::unordered_map<uint32, uint32> const& PointsObjets() const { return _pointsObjets; }
    [[nodiscard]] std::map<std::pair<std::string, uint32>, uint32> const& PointsSources() const { return _pointsSources; }
    [[nodiscard]] uint32 NbLiaisons() const { return _nbLiaisons; }
    // L'etabli a besoin des catalogues ENTIERS : il cherche « la pierre de la
    // meme statistique dont le montant est juste au-dessus », ou tire une rune
    // au hasard parmi toutes.
    [[nodiscard]] std::unordered_map<uint32, SpherierPierre> const& Pierres() const { return _pierres; }
    [[nodiscard]] std::unordered_map<uint32, SpherierRune> const& Runes() const { return _runes; }
    [[nodiscard]] std::unordered_map<uint32, SpherierRuneStat> const& RunesStat() const { return _runesStat; }

private:
    SpherierMgr() = default;

    // Controles d'integrite apres chargement : departs, coherence noeud/pierre,
    // morceaux non relies au depart. Signale en LOG_WARN, ne bloque jamais.
    void Verifier() const;

    std::unordered_map<uint32, SpherierEmplacement> _emplacements;
    std::map<uint8, uint32> _departs;                               // class_id -> node_id
    std::map<std::pair<uint32, uint8>, uint32> _sortsClasse;        // (node_id, class_id) -> spell_id
    std::map<uint32, uint32> _bareme;                               // activated_min -> cout
    std::unordered_map<uint32, uint32> _pointsObjets;               // item_entry -> points
    std::map<std::pair<std::string, uint32>, uint32> _pointsSources;
    std::unordered_map<uint32, SpherierPierre> _pierres;            // item_entry -> effet
    std::unordered_map<uint32, SpherierRune> _runes;                // item_entry -> sort
    std::unordered_map<uint32, SpherierRuneStat> _runesStat;        // item_entry -> statistique
    std::map<std::string, uint32> _reglages;
    uint32 _nbLiaisons = 0;
};

#define sSpherierMgr SpherierMgr::instance()

#endif

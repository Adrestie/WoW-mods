/*
 * mod-papota-spherier — etat de spherier des personnages (jalon 2).
 *
 * Regles (SPHERIER_CONCEPTION.md §2) : activation de proche en proche depuis le
 * point de depart de la classe ; prix tire du bareme papota_sphere_cost selon
 * le nombre d'emplacements deja actives ; activer un noeud applique sa pierre
 * pre-allouee (l'application des effets viendra au jalon 3), activer un slot ne
 * produit rien tant qu'aucune rune n'y est sertie.
 *
 * Les playerbots n'ont aucun etat : ils sont ecartes a la connexion et ne
 * gagnent jamais de points (2500 bots — lecon mod-learn-spells).
 */

#ifndef MOD_PAPOTA_SPHERIER_PLAYER_MGR_H_
#define MOD_PAPOTA_SPHERIER_PLAYER_MGR_H_

#include "Define.h"
#include "ObjectGuid.h"
#include <array>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

class Creature;
class Map;
class Player;

struct SpherierEtatJoueur
{
    uint32 earned = 0;
    uint32 spent = 0;
    // NEXUS PRISMATIQUES absorbes par le COMPTE (2026-09-06) : chacun majore
    // de 25 % tous les gains de Spherite, sans plafond.
    uint32 prismes = 0;
    // node_id -> { entree de l'objet applique (pierre du noeud, 0 pour un slot
    // vide), niveau d'amelioration (runes, jalon 5) }
    std::unordered_map<uint32, std::pair<uint32, uint8>> actives;
    // CONTENU DES NOEUDS A PIERRES AU COMPTE (2026-09-06) : ce qu'un personnage
    // du compte y a mis, ou vide (0), vaut pour tous. node_id -> { entree,
    // amelioration } ; absent = pierre d'origine du noeud. Les slots et les
    // emplacements de sort restent propres au personnage.
    std::unordered_map<uint32, std::pair<uint32, uint8>> contenuCompte;
    // Emplacements de sort dont le sort a ete OUBLIE a l'epingle (2026-09-06) :
    // ceux-la exigent un nouvel achat. Un emplacement de sort a 0 qui n'y est
    // pas a ete achete avant que la classe y ait un sort : il l'apprend
    // sans repayer des qu'il existe.
    std::unordered_set<uint32> oublies;

    [[nodiscard]] uint32 Disponibles() const { return earned > spent ? earned - spent : 0; }
};

enum class SpherierActivation : uint8
{
    Ok,
    EtatAbsent,             // etat non charge : bot, ou hors ligne
    EmplacementInconnu,
    MauvaiseClasse,
    DejaActif,
    NonAdjacent,
    PointsInsuffisants
};

enum class SpherierSertissage : uint8
{
    Ok,
    EtatAbsent,
    EmplacementInconnu,
    PasActif,               // l'emplacement n'a pas encore ete achete
    DejaOccupe,
    MauvaisType,            // pierre dans un slot, rune dans un noeud...
    ObjetAbsent,            // le joueur n'a pas l'objet en sac
    TropDeRunes,            // trois runes identiques deja serties
    MauvaiseClasse          // rune de rang d'une autre classe
};

// Bloc de statistiques agrege : index = rang dans le catalogue des 16
// statistiques (1..16), la case 0 restant inutilisee.
constexpr uint8 SPHERIER_NB_STATS = 16;
using SpherierBloc = std::array<int32, SPHERIER_NB_STATS + 1>;

class SpherierPlayerMgr
{
public:
    static SpherierPlayerMgr* instance();

    void Charger(Player* player);       // connexion (les bots sont ecartes)
    void Decharger(Player* player);     // deconnexion

    [[nodiscard]] SpherierEtatJoueur* Etat(Player* player);

    SpherierActivation Activer(Player* player, uint32 nodeId);
    bool AjouterPoints(Player* player, uint32 montant);     // faux si etat absent
    // Un GAIN de Spherite (butin, boss, donjon, M+, Nexus) : majore par les
    // prismes du compte, puis AjouterPoints. Les outils GM ajoutent brut.
    bool Gagner(Player* player, uint32 montant);
    // Le montant qu'un gain vaudra une fois majore par les prismes du compte.
    [[nodiscard]] uint32 Majorer(Player* player, uint32 montant);
    // Un Nexus prismatique absorbe : un prisme de plus au compte.
    bool AbsorberPrisme(Player* player);
    // Retire jusqu'a `montant` points disponibles (plafonne, jamais negatif) ;
    // `retire` recoit le montant reellement debite. Faux si etat absent.
    bool RetirerPoints(Player* player, uint32 montant, uint32& retire);
    // Fixe les points DISPONIBLES a `disponibles` (earned = spent + N).
    bool FixerPoints(Player* player, uint32 disponibles);
    void CrediterBoss(Player* tueur, Creature* crea);       // groupe entier, meme carte
    // Credite le bareme d'une accroche (papota_sphere_point_source, avec repli
    // sur la valeur 0 du type). Faux si bareme absent ou etat absent. C'est le
    // point d'entree des autres systemes : mod-dungeon-clear en direct, le M+
    // Lua via la commande console `.spherier points source`.
    bool CrediterSource(Player* player, std::string const& type, uint32 valeur);
    // Le bareme d'une INSTANCE par carte, difficulte et palier d'extension
    // (SpherierMgr::PointsPourInstance) : fin de donjon (mod-dungeon-clear).
    bool CrediterInstance(Player* player, std::string const& type, Map const* map);
    void Reinitialiser(Player* player);                     // outil GM : remise a zero
    // Le COMPTE entier : Spherite gagnee effacee et toutes les grilles de
    // tous ses personnages remises a zero. Rend le nombre de personnages
    // touches.
    uint32 EffacerCompte(Player* player);

    // --- jalon 3 : les effets ---------------------------------------------
    // Recalcul TOTAL, jamais incrementiel : on resomme tous les emplacements
    // actifs, on retire le bloc precedent, on pose le nouveau. Appele a la
    // connexion, a chaque activation, sertissage et usage d'epingle.
    void Recalculer(Player* player);
    [[nodiscard]] SpherierBloc const* Bloc(Player* player) const;

    // Rangs supplementaires des runes. Appele par Recalculer, et par les
    // crochets de talent : un talent perdu doit desactiver ses runes SANS que
    // le joueur ait a ouvrir quoi que ce soit.
    void SynchroniserRunes(Player* player, SpherierEtatJoueur const& etat);
    void SynchroniserRunes(Player* player);         // depuis l'etat charge

    SpherierSertissage Sertir(Player* player, uint32 nodeId, uint32 itemEntry);
    // Vide l'emplacement : la pierre ou la rune est DETRUITE. Sur un
    // emplacement de sort, le sort est oublie mais reste dans la grille.
    SpherierSertissage Epingler(Player* player, uint32 nodeId, bool consommerEpingle = true);

private:
    SpherierPlayerMgr() = default;

    std::unordered_map<ObjectGuid, SpherierEtatJoueur> _etats;
    // Dernier bloc POSE sur chaque joueur : c'est lui qu'on retire avant de
    // reappliquer, sans quoi les bonus s'empileraient a chaque recalcul.
    std::unordered_map<ObjectGuid, SpherierBloc> _blocs;
    // Rangs customs actuellement appris au titre des runes, par joueur : c'est
    // eux qu'on retire quand une rune cesse de s'appliquer.
    std::unordered_map<ObjectGuid, std::unordered_set<uint32>> _rangs;
};

#define sSpherierPlayerMgr SpherierPlayerMgr::instance()

#endif

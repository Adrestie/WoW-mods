/*
 * mod-papota-spherier — distribution des objets du sphèrier dans le butin.
 *
 * Le principe (decision du 2026-08-24) : AUCUNE ligne n'est ajoutee aux tables
 * de butin de la base. Les objets sont injectes a la volee dans le butin en
 * cours de remplissage, et les tranches qui disent ou et a quel taux vivent
 * dans le CODE du serveur — ni en base, ni en Lua : rien de ce qui decide d'un
 * butin ne doit etre lisible ou modifiable ailleurs que dans le binaire.
 *
 * C'est la seule entorse assumee au §3 du document de conception (« rien de
 * chiffre dans le code ») : elle est deliberee et son prix est connu, un
 * reequilibrage demande une recompilation.
 *
 * Le point d'accroche est MiscScript::OnAfterLootTemplateProcess, appele par
 * Loot::FillLoot juste apres le traitement de la table et AVANT l'attribution
 * des droits de groupe et des seuils de qualite : un objet ajoute la est
 * indiscernable d'un objet venu de la table.
 */

#ifndef MOD_PAPOTA_SPHERIER_LOOT_H_
#define MOD_PAPOTA_SPHERIER_LOOT_H_

#include "Define.h"

class Creature;
class GameObject;
class Loot;
class LootStore;
class Player;

// Ce qu'un objet de jeu est pour nous. Le magasin « objets de jeu » couvre en
// realite trois choses tres differentes, qu'il faut separer.
enum SpherierGenreGob : uint8
{
    SPHERIER_GOB_AUTRE = 0,
    SPHERIER_GOB_RECOLTE,               // filon ou plante : verrou de metier
    SPHERIER_GOB_BANC_PECHE,            // banc de poissons
    SPHERIER_GOB_COFFRE                 // coffre au tresor
};

// Ce que la source du butin dit d'elle-meme. Tous les champs ne sont pas
// renseignes pour toutes les sources : un banc de poissons n'a pas de niveau,
// un filon n'a pas de rang. Les tranches ne lisent que ce qui les concerne.
struct SpherierSourceButin
{
    Player*     joueur      = nullptr;
    Creature*   creature    = nullptr;  // monstre tue, ou bete depecee
    GameObject* gob         = nullptr;  // filon, plante, banc, coffre

    uint32 niveau     = 0;              // niveau reel de la creature
    uint8  rang       = 0;              // CreatureEliteType
    bool   boss       = false;          // boss de donjon ou de plein monde
    uint32 carte      = 0;
    uint32 zone       = 0;
    uint32 extension  = 0;              // Map.dbc : 0 Vanilla, 1 BC, 2 Wrath
    bool   donjon     = false;
    bool   raid       = false;
    bool   heroique   = false;

    uint8  genre      = SPHERIER_GOB_AUTRE;
    uint32 metier     = 0;              // LOCKTYPE_HERBALISM ou LOCKTYPE_MINING
    uint32 competence = 0;              // competence exigee ; 0 = aucune exigence
};

// Appelee pour CHAQUE butin rempli, quelle que soit sa nature. Elle filtre
// elle-meme sur le magasin (creature, peche, recolte, depecage) et ne fait
// rien pour les autres.
void SpherierRemplirButin(Loot* loot, LootStore const& store, Player* joueur);

#endif

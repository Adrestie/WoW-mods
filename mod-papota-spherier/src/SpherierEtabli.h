/*
 * mod-papota-spherier — l'etabli et ses trois recettes (§9, revision du
 * 2026-08-27).
 *
 *   Fusion de pierres    3 pierres identiques        -> 1 pierre, qualite au-dessus
 *   Relance de pierre    2 pierres de meme qualite   -> 1 pierre, meme qualite, autre effet
 *   Refonte de runes     3 runes quelconques         -> 1 rune tiree dans tout le catalogue
 *
 * Une rune ne s'ameliore PAS : elle se refond. C'est la raison d'etre de
 * l'etabli enoncee au §6 — une rune de druide trouvee par un guerrier finit par
 * devenir utile.
 *
 * AUCUN CHIFFRE ICI. La qualite d'une pierre ne se lit pas dans son identifiant
 * mais dans son MONTANT : le catalogue donne le meme montant a toutes les
 * pierres d'une qualite, si bien que « meme qualite » se dit « meme montant » et
 * « qualite au-dessus » se dit « le montant juste au-dessus, a effet egal ».
 * Rien n'est deduit d'une formule sur les entrees.
 */

#ifndef MOD_PAPOTA_SPHERIER_ETABLI_H_
#define MOD_PAPOTA_SPHERIER_ETABLI_H_

#include "Define.h"
#include <vector>

class Player;

enum class SpherierEtabliResultat : uint8
{
    Ok,
    PasUnePierre,           // une des entrees n'est pas une pierre
    PasUneRune,             // une des entrees n'est pas une rune
    EffetsDifferents,       // fusion : il faut trois fois la MEME pierre
    QualitesDifferentes,    // relance : les deux pierres n'ont pas la meme qualite
    QualiteMaximale,        // rien au-dessus de la derniere qualite
    RienATirer,             // aucun resultat possible dans le catalogue
    ObjetAbsent,            // le joueur n'a pas les objets en sac
    SacPlein
};

namespace SpherierEtabli
{
    // Les trois recettes. `produit` recoit l'entree fabriquee quand tout va bien.
    SpherierEtabliResultat Fusionner(Player* player, uint32 entree, uint32& produit);
    SpherierEtabliResultat RelancerPierre(Player* player, uint32 a, uint32 b, uint32& produit);
    SpherierEtabliResultat RefondreRunes(Player* player, uint32 a, uint32 b, uint32 c,
                                         uint32& produit);
}

#endif

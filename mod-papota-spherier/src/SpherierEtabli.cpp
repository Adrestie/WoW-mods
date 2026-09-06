#include "SpherierEtabli.h"
#include "SpherierMgr.h"

#include "Item.h"
#include "ItemTemplate.h"
#include "Player.h"
#include "Random.h"

#include <algorithm>

namespace
{
    // Le joueur porte-t-il vraiment ce qu'il vient de poser sur l'etabli ?
    // Les entrees peuvent se repeter — trois fois la meme pierre pour une
    // fusion —, d'ou le comptage par entree plutot qu'un test un a un.
    bool PorteTout(Player* player, std::vector<uint32> const& entrees)
    {
        for (uint32 e : entrees)
        {
            uint32 combien = uint32(std::count(entrees.begin(), entrees.end(), e));
            if (!player->HasItemCount(e, combien))
                return false;
        }
        return true;
    }

    // Consomme les entrees puis rend le produit. L'ordre compte : on verifie la
    // place AVANT de detruire quoi que ce soit, sans quoi un sac plein ferait
    // disparaitre les composants sans rien donner en echange.
    SpherierEtabliResultat Echanger(Player* player, std::vector<uint32> const& entrees,
                                    uint32 produit)
    {
        if (!PorteTout(player, entrees))
            return SpherierEtabliResultat::ObjetAbsent;

        ItemPosCountVec dest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, produit, 1) != EQUIP_ERR_OK)
            return SpherierEtabliResultat::SacPlein;

        for (uint32 e : entrees)
            player->DestroyItemCount(e, 1, true);

        player->AddItem(produit, 1);
        return SpherierEtabliResultat::Ok;
    }

    // Un tirage uniforme dans une liste de candidats.
    uint32 TirerAuSort(std::vector<uint32> const& candidats)
    {
        if (candidats.empty())
            return 0;
        return candidats[urand(0, uint32(candidats.size()) - 1)];
    }
}

namespace SpherierEtabli
{

SpherierEtabliResultat Fusionner(Player* player, uint32 entree, uint32& produit)
{
    SpherierPierre const* pierre = sSpherierMgr->Pierre(entree);
    if (!pierre)
        return SpherierEtabliResultat::PasUnePierre;

    // « Qualite superieure, meme effet » se lit dans les donnees : la pierre de
    // la meme statistique dont le montant est le plus petit au-dessus du notre.
    uint32 meilleure = 0;
    int32 montantMeilleur = 0;
    for (auto const& [autreEntree, autre] : sSpherierMgr->Pierres())
    {
        // Jamais une pierre de noeud : elle n'est pas un objet, on ne
        // pourrait pas la remettre au joueur.
        if (!autre.objet || autre.statId != pierre->statId || autre.amount <= pierre->amount)
            continue;
        if (!meilleure || autre.amount < montantMeilleur)
        {
            meilleure = autreEntree;
            montantMeilleur = autre.amount;
        }
    }
    if (!meilleure)
        return SpherierEtabliResultat::QualiteMaximale;

    produit = meilleure;
    return Echanger(player, { entree, entree, entree }, produit);
}

SpherierEtabliResultat RelancerPierre(Player* player, uint32 a, uint32 b, uint32& produit)
{
    SpherierPierre const* pa = sSpherierMgr->Pierre(a);
    SpherierPierre const* pb = sSpherierMgr->Pierre(b);
    if (!pa || !pb)
        return SpherierEtabliResultat::PasUnePierre;

    // Toutes les pierres d'une meme qualite portent le meme montant : c'est ce
    // qui permet de comparer deux qualites sans jamais lire un identifiant.
    if (pa->amount != pb->amount)
        return SpherierEtabliResultat::QualitesDifferentes;

    std::vector<uint32> candidats;
    for (auto const& [entree, autre] : sSpherierMgr->Pierres())
        if (autre.objet && autre.amount == pa->amount
            && autre.statId != pa->statId && autre.statId != pb->statId)
            candidats.push_back(entree);

    produit = TirerAuSort(candidats);
    if (!produit)
        return SpherierEtabliResultat::RienATirer;

    return Echanger(player, { a, b }, produit);
}

SpherierEtabliResultat RefondreRunes(Player* player, uint32 a, uint32 b, uint32 c,
                                     uint32& produit)
{
    // Les deux sortes de rune se refondent ensemble et se tirent ensemble :
    // l'etabli est justement la pour se debarrasser de ce qui ne sert pas.
    for (uint32 e : { a, b, c })
        if (!sSpherierMgr->Rune(e) && !sSpherierMgr->RuneStat(e))
            return SpherierEtabliResultat::PasUneRune;

    std::vector<uint32> candidats;
    for (auto const& [entree, _] : sSpherierMgr->Runes())
        candidats.push_back(entree);
    for (auto const& [entree, _] : sSpherierMgr->RunesStat())
        candidats.push_back(entree);

    produit = TirerAuSort(candidats);
    if (!produit)
        return SpherierEtabliResultat::RienATirer;

    return Echanger(player, { a, b, c }, produit);
}

}   // namespace SpherierEtabli

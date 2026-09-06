/*
 * mod-papota-spherier — commandes GM.
 *
 * .spherier info               (SEC_GAMEMASTER)     etat de la definition chargee
 * .spherier reload             (SEC_ADMINISTRATOR)  recharge les tables papota_sphere_*
 * .spherier status [joueur]    (SEC_GAMEMASTER)     points et activations du joueur
 * .spherier points add N [joueur]     (SEC_ADMINISTRATOR)  credite N points
 * .spherier points remove N [joueur]  (SEC_ADMINISTRATOR)  debite N points (plafonne)
 * .spherier points set N [joueur]     (SEC_ADMINISTRATOR)  fixe les points DISPONIBLES a N
 * .spherier activate <node_id> (SEC_GAMEMASTER)     achete l'emplacement, regles du jeu
 * .spherier reset [joueur]     (SEC_ADMINISTRATOR)  remise a zero complete du personnage
 * .spherier show               (SEC_PLAYER)         interface du spherier (jalon 4)
 * .spherier editor             (SEC_ADMINISTRATOR)  editeur de disposition
 *
 * .spherier sans argument affiche la liste des sous-commandes (comportement
 * natif du coeur pour une commande parente, filtree par niveau). show et
 * editor sont INTERCEPTES par le Lua (lua_scripts\Spherier\) avant d'arriver
 * ici : leurs handlers C++ ne sont que des replis si ALE n'est pas charge,
 * leur presence dans la table sert la liste et documente les niveaux requis.
 *
 * Tous les textes viennent de module_string (anglais + frFR selon la locale
 * du client) — voir SpherierStrings.h. Aucun texte en dur ici.
 */

#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "SpherierMgr.h"
#include "SpherierPlayerMgr.h"
#include "SpherierEtabli.h"
#include "SpherierStrings.h"

#include <array>
#include <map>

using namespace Acore::ChatCommands;

class spherier_commandscript : public CommandScript
{
public:
    spherier_commandscript() : CommandScript("spherier_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable pointsTable =
        {
            { "add",    HandlePointsAddCommand,    SEC_ADMINISTRATOR, Console::Yes },
            { "remove", HandlePointsRemoveCommand, SEC_ADMINISTRATOR, Console::Yes },
            { "set",    HandlePointsSetCommand,    SEC_ADMINISTRATOR, Console::Yes },
            // Interface interne pour les scripts Lua (RunCommand) : credite le
            // bareme d'une accroche. Console seulement, invisible en jeu.
            { "source", HandlePointsSourceCommand, SEC_CONSOLE,       Console::Yes },
        };

        static ChatCommandTable spherierTable =
        {
            { "info",     HandleInfoCommand,     SEC_GAMEMASTER,    Console::Yes },
            { "reload",   HandleReloadCommand,   SEC_ADMINISTRATOR, Console::Yes },
            { "status",   HandleStatusCommand,   SEC_GAMEMASTER,    Console::Yes },
            { "points",   pointsTable },
            // SEC_PLAYER : c'est le chemin d'achat de l'interface joueur (via
            // RunCommand) — toutes les regles du jeu sont appliquees dedans.
            { "activate", HandleActivateCommand, SEC_PLAYER,        Console::No  },
            { "reset",    HandleResetCommand,    SEC_ADMINISTRATOR, Console::Yes },
            { "wipeall",  HandleWipeAllCommand,  SEC_ADMINISTRATOR, Console::Yes },
            { "show",     HandleShowCommand,     SEC_PLAYER,        Console::No  },
            { "editor",   HandleEditorCommand,   SEC_ADMINISTRATOR, Console::No  },
            // Sertissage : chemin d'achat de l'interface, donc niveau joueur.
            { "socket",   HandleSocketCommand,   SEC_PLAYER,        Console::No  },
            { "unsocket", HandleUnsocketCommand, SEC_PLAYER,        Console::No  },
            // L'etabli : c'est l'interface qui les emprunte, comme pour le
            // sertissage — les regles restent ici.
            { "fusion",   HandleFusionCommand,   SEC_PLAYER,        Console::No  },
            { "relance",  HandleRelanceCommand,  SEC_PLAYER,        Console::No  },
            { "refonte",  HandleRefonteCommand,  SEC_PLAYER,        Console::No  },
            { "stats",    HandleStatsCommand,    SEC_GAMEMASTER,    Console::Yes },
        };

        static ChatCommandTable commandTable =
        {
            { "spherier", spherierTable },
        };

        return commandTable;
    }

    template<typename... Args>
    static void Dire(ChatHandler* handler, uint32 id, Args&&... args)
    {
        handler->PSendModuleSysMessage(SPHERIER_MODULE, id, std::forward<Args>(args)...);
    }

    // Erreur ou operation impossible : le texte rouge standard au centre de
    // l'ecran (SMSG_NOTIFICATION), comme les refus de Blizzard. La console
    // n'a pas d'ecran : repli sur le message systeme.
    template<typename... Args>
    static void DireErreur(ChatHandler* handler, uint32 id, Args&&... args)
    {
        if (handler->GetSession())
            handler->SendNotification("{}",
                handler->PGetParseModuleString(SPHERIER_MODULE, id, std::forward<Args>(args)...));
        else
            handler->PSendModuleSysMessage(SPHERIER_MODULE, id, std::forward<Args>(args)...);
    }

    static bool HandleInfoCommand(ChatHandler* handler)
    {
        auto const& emplacements = sSpherierMgr->Emplacements();

        // [0] = noeuds, [1] = slots, [2] = sorts
        std::map<uint8, std::array<uint32, 3>> parClasse;
        for (auto const& [id, e] : emplacements)
            ++parClasse[e.classId][e.kind <= SPHERIER_SORT ? e.kind : SPHERIER_NOEUD];

        Dire(handler, SPHERIER_STR_INFO_ENTETE,
            emplacements.size(), sSpherierMgr->NbLiaisons(), parClasse.size());

        for (auto const& [classId, compte] : parClasse)
            Dire(handler, SPHERIER_STR_INFO_CLASSE,
                classId, compte[0], compte[1], compte[2], sSpherierMgr->Depart(classId));

        Dire(handler, SPHERIER_STR_INFO_BAREME, sSpherierMgr->Bareme().size());
        for (auto const& [seuil, cout] : sSpherierMgr->Bareme())
            Dire(handler, SPHERIER_STR_INFO_TRANCHE, seuil, cout);

        Dire(handler, SPHERIER_STR_INFO_OBJETS,
            sSpherierMgr->PointsObjets().size(), sSpherierMgr->PointsSources().size());
        for (auto const& [cle, points] : sSpherierMgr->PointsSources())
            Dire(handler, SPHERIER_STR_INFO_SOURCE, cle.first, cle.second, points);

        return true;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        sSpherierMgr->Charger();
        Dire(handler, SPHERIER_STR_RELOAD_OK,
            sSpherierMgr->Emplacements().size(), sSpherierMgr->NbLiaisons());
        return true;
    }

    // Cible d'une commande : le joueur nomme, sinon la cible, sinon soi-meme.
    // Renvoie nullptr apres avoir affiche l'erreur.
    static Player* CibleConnectee(ChatHandler* handler, Optional<PlayerIdentifier>& cible)
    {
        if (!cible)
            cible = PlayerIdentifier::FromTargetOrSelf(handler);
        if (!cible || !cible->IsConnected())
        {
            Dire(handler, SPHERIER_STR_JOUEUR_INTROUVABLE);
            return nullptr;
        }
        return cible->GetConnectedPlayer();
    }

    static bool HandleStatusCommand(ChatHandler* handler, Optional<PlayerIdentifier> cible)
    {
        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        SpherierEtatJoueur* etat = sSpherierPlayerMgr->Etat(joueur);
        if (!etat)
        {
            Dire(handler, SPHERIER_STR_ETAT_ABSENT_DE, joueur->GetName());
            return true;
        }

        uint32 total = 0;
        for (auto const& [id, e] : sSpherierMgr->Emplacements())
            if (e.classId == joueur->getClass())
                ++total;

        Dire(handler, SPHERIER_STR_STATUS_POINTS,
            joueur->GetName(), etat->Disponibles(), etat->earned, etat->spent);
        Dire(handler, SPHERIER_STR_STATUS_ACTIFS,
            etat->actives.size(), total, joueur->getClass(),
            sSpherierMgr->CoutActivation(uint32(etat->actives.size())));
        Dire(handler, SPHERIER_STR_STATUS_PRISMES, etat->prismes, 25 * etat->prismes);
        return true;
    }

    // Sans montant, chaque sous-commande de points affiche sa propre aide.
    static void AidePoints(ChatHandler* handler, char const* nom, uint32 idEffet)
    {
        Dire(handler, SPHERIER_STR_POINTS_USAGE, nom);
        Dire(handler, idEffet);
        Dire(handler, SPHERIER_STR_POINTS_CIBLE);
    }

    static bool HandlePointsAddCommand(ChatHandler* handler, Optional<uint32> montant, Optional<PlayerIdentifier> cible)
    {
        if (!montant || !*montant)
        {
            AidePoints(handler, "add", SPHERIER_STR_POINTS_AIDE_ADD);
            return true;
        }

        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        if (!sSpherierPlayerMgr->AjouterPoints(joueur, *montant))
        {
            Dire(handler, SPHERIER_STR_ETAT_ABSENT_DE, joueur->GetName());
            return true;
        }

        SpherierEtatJoueur* etat = sSpherierPlayerMgr->Etat(joueur);
        Dire(handler, SPHERIER_STR_POINTS_CREDITE,
            joueur->GetName(), *montant, etat ? etat->Disponibles() : 0);
        return true;
    }

    static bool HandlePointsRemoveCommand(ChatHandler* handler, Optional<uint32> montant, Optional<PlayerIdentifier> cible)
    {
        if (!montant || !*montant)
        {
            AidePoints(handler, "remove", SPHERIER_STR_POINTS_AIDE_REMOVE);
            return true;
        }

        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        uint32 retire = 0;
        if (!sSpherierPlayerMgr->RetirerPoints(joueur, *montant, retire))
        {
            Dire(handler, SPHERIER_STR_ETAT_ABSENT_DE, joueur->GetName());
            return true;
        }

        SpherierEtatJoueur* etat = sSpherierPlayerMgr->Etat(joueur);
        Dire(handler, SPHERIER_STR_POINTS_DEBITE,
            joueur->GetName(), retire, *montant, etat ? etat->Disponibles() : 0);
        return true;
    }

    static bool HandlePointsSetCommand(ChatHandler* handler, Optional<uint32> montant, Optional<PlayerIdentifier> cible)
    {
        if (!montant)
        {
            AidePoints(handler, "set", SPHERIER_STR_POINTS_AIDE_SET);
            return true;
        }

        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        if (!sSpherierPlayerMgr->FixerPoints(joueur, *montant))
        {
            Dire(handler, SPHERIER_STR_ETAT_ABSENT_DE, joueur->GetName());
            return true;
        }

        Dire(handler, SPHERIER_STR_POINTS_FIXES, joueur->GetName(), *montant);
        return true;
    }

    static bool HandlePointsSourceCommand(ChatHandler* handler, std::string type, uint32 valeur, Optional<PlayerIdentifier> cible)
    {
        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        uint32 const points = sSpherierMgr->PointsPourSource(type, valeur);
        if (!points)
        {
            Dire(handler, SPHERIER_STR_SOURCE_INCONNUE, type, valeur);
            return true;
        }

        // Une SOURCE de contenu (le M+ passe par ici) : majoree par les prismes
        // du compte comme tout gain — seuls points add / set restent bruts.
        SpherierEtatJoueur* etat = sSpherierPlayerMgr->Etat(joueur);
        uint32 const credite = sSpherierPlayerMgr->Majorer(joueur, points);
        if (!sSpherierPlayerMgr->Gagner(joueur, points))
        {
            Dire(handler, SPHERIER_STR_ETAT_ABSENT_DE, joueur->GetName());
            return true;
        }

        Dire(handler, SPHERIER_STR_POINTS_CREDITE,
            joueur->GetName(), credite, etat ? etat->Disponibles() : 0);
        return true;
    }

    static bool HandleActivateCommand(ChatHandler* handler, uint32 nodeId)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        switch (sSpherierPlayerMgr->Activer(joueur, nodeId))
        {
            case SpherierActivation::Ok:
            {
                SpherierEtatJoueur* etat = sSpherierPlayerMgr->Etat(joueur);
                Dire(handler, SPHERIER_STR_ACTIVE_OK,
                    nodeId, etat ? etat->actives.size() : 0, etat ? etat->Disponibles() : 0);
                break;
            }
            case SpherierActivation::EtatAbsent:
                DireErreur(handler, SPHERIER_STR_ETAT_ABSENT_SOI);
                break;
            case SpherierActivation::EmplacementInconnu:
                DireErreur(handler, SPHERIER_STR_ACT_INCONNU, nodeId);
                break;
            case SpherierActivation::MauvaiseClasse:
                DireErreur(handler, SPHERIER_STR_ACT_CLASSE, nodeId);
                break;
            case SpherierActivation::DejaActif:
                DireErreur(handler, SPHERIER_STR_ACT_DEJA, nodeId);
                break;
            case SpherierActivation::NonAdjacent:
                DireErreur(handler, SPHERIER_STR_ACT_NON_ADJACENT, nodeId);
                break;
            case SpherierActivation::PointsInsuffisants:
                // Ni le cout, ni ce que le joueur possede : le refus dit
                // seulement qu'il n'a pas de quoi (demande du 2026-08-26).
                DireErreur(handler, SPHERIER_STR_ACT_INSUFFISANT);
                break;
        }
        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler, Optional<PlayerIdentifier> cible)
    {
        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        sSpherierPlayerMgr->Reinitialiser(joueur);
        Dire(handler, SPHERIER_STR_RESET_OK, joueur->GetName());
        return true;
    }

    // TOUT LE COMPTE de la cible : Spherite gagnee effacee et grilles de tous
    // ses personnages remises a zero, connectes ou non. Sans argument, c'est le
    // compte du lanceur.
    //
    // IRREVERSIBLE et bien plus large que `reset`, qui ne prend qu'un
    // personnage et laisse la Spherite du compte intacte.
    static bool HandleWipeAllCommand(ChatHandler* handler, Optional<PlayerIdentifier> cible)
    {
        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        uint32 const nombre = sSpherierPlayerMgr->EffacerCompte(joueur);
        Dire(handler, SPHERIER_STR_WIPEALL_OK, joueur->GetName(), nombre);
        return true;
    }

    // Rend compte d'un sertissage ou d'un usage d'epingle. Les refus passent en
    // texte rouge, comme tous les refus du module.
    static void DireResultatSertissage(ChatHandler* handler, SpherierSertissage r,
        uint32 nodeId, uint32 idSucces, uint32 arg1, uint32 arg2)
    {
        switch (r)
        {
            case SpherierSertissage::Ok:
                Dire(handler, idSucces, arg1, arg2);
                break;
            case SpherierSertissage::EtatAbsent:
                DireErreur(handler, SPHERIER_STR_ETAT_ABSENT_SOI);
                break;
            case SpherierSertissage::EmplacementInconnu:
                DireErreur(handler, SPHERIER_STR_ACT_INCONNU, nodeId);
                break;
            case SpherierSertissage::PasActif:
                DireErreur(handler, SPHERIER_STR_SERT_PAS_ACTIF, nodeId);
                break;
            case SpherierSertissage::DejaOccupe:
                DireErreur(handler, idSucces == SPHERIER_STR_SERTI
                    ? SPHERIER_STR_SERT_OCCUPE : SPHERIER_STR_SERT_VIDE, nodeId);
                break;
            case SpherierSertissage::MauvaisType:
                DireErreur(handler, SPHERIER_STR_SERT_MAUVAIS_TYPE, nodeId);
                break;
            case SpherierSertissage::ObjetAbsent:
                DireErreur(handler, SPHERIER_STR_SERT_OBJET_ABSENT);
                break;
            case SpherierSertissage::MauvaiseClasse:
                DireErreur(handler, SPHERIER_STR_SERT_CLASSE);
                break;
            case SpherierSertissage::TropDeRunes:
                DireErreur(handler, SPHERIER_STR_SERT_TROP_RUNES);
                break;
        }
    }

    // Un seul endroit pour dire ce qu'un etabli a repondu, les trois recettes
    // partageant le meme jeu de refus.
    static void DireResultatEtabli(ChatHandler* handler, SpherierEtabliResultat r,
                                   uint32 produit)
    {
        switch (r)
        {
            case SpherierEtabliResultat::Ok:
                Dire(handler, SPHERIER_STR_ETABLI_OK, produit);
                break;
            case SpherierEtabliResultat::PasUnePierre:
                DireErreur(handler, SPHERIER_STR_ETABLI_PAS_PIERRE);
                break;
            case SpherierEtabliResultat::PasUneRune:
                DireErreur(handler, SPHERIER_STR_ETABLI_PAS_RUNE);
                break;
            case SpherierEtabliResultat::EffetsDifferents:
                DireErreur(handler, SPHERIER_STR_ETABLI_EFFETS);
                break;
            case SpherierEtabliResultat::QualitesDifferentes:
                DireErreur(handler, SPHERIER_STR_ETABLI_QUALITES);
                break;
            case SpherierEtabliResultat::QualiteMaximale:
                DireErreur(handler, SPHERIER_STR_ETABLI_QUALITE_MAX);
                break;
            case SpherierEtabliResultat::RienATirer:
                DireErreur(handler, SPHERIER_STR_ETABLI_RIEN);
                break;
            case SpherierEtabliResultat::ObjetAbsent:
                DireErreur(handler, SPHERIER_STR_ETABLI_ABSENT);
                break;
            case SpherierEtabliResultat::SacPlein:
                DireErreur(handler, SPHERIER_STR_ETABLI_SAC_PLEIN);
                break;
        }
    }

    // Fusion : trois fois la MEME pierre, d'ou un seul argument.
    static bool HandleFusionCommand(ChatHandler* handler, uint32 entree)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        uint32 produit = 0;
        DireResultatEtabli(handler,
            SpherierEtabli::Fusionner(joueur, entree, produit), produit);
        return true;
    }

    static bool HandleRelanceCommand(ChatHandler* handler, uint32 a, uint32 b)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        uint32 produit = 0;
        DireResultatEtabli(handler,
            SpherierEtabli::RelancerPierre(joueur, a, b, produit), produit);
        return true;
    }

    static bool HandleRefonteCommand(ChatHandler* handler, uint32 a, uint32 b, uint32 c)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        uint32 produit = 0;
        DireResultatEtabli(handler,
            SpherierEtabli::RefondreRunes(joueur, a, b, c, produit), produit);
        return true;
    }

    static bool HandleSocketCommand(ChatHandler* handler, uint32 nodeId, uint32 itemEntry)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        DireResultatSertissage(handler,
            sSpherierPlayerMgr->Sertir(joueur, nodeId, itemEntry),
            nodeId, SPHERIER_STR_SERTI, itemEntry, nodeId);
        return true;
    }

    static bool HandleUnsocketCommand(ChatHandler* handler, uint32 nodeId)
    {
        Player* joueur = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!joueur)
            return true;

        DireResultatSertissage(handler,
            sSpherierPlayerMgr->Epingler(joueur, nodeId),
            nodeId, SPHERIER_STR_EPINGLE, nodeId, 0);
        return true;
    }

    static bool HandleStatsCommand(ChatHandler* handler, Optional<PlayerIdentifier> cible)
    {
        Player* joueur = CibleConnectee(handler, cible);
        if (!joueur)
            return true;

        SpherierBloc const* bloc = sSpherierPlayerMgr->Bloc(joueur);
        bool quelqueChose = false;
        if (bloc)
            for (uint8 s = 1; s <= SPHERIER_NB_STATS; ++s)
                if ((*bloc)[s])
                {
                    if (!quelqueChose)
                    {
                        Dire(handler, SPHERIER_STR_STATS_ENTETE, joueur->GetName());
                        quelqueChose = true;
                    }
                    Dire(handler, SPHERIER_STR_STATS_LIGNE, s, (*bloc)[s]);
                }

        if (!quelqueChose)
            Dire(handler, SPHERIER_STR_STATS_VIDE);
        return true;
    }

    // Replis : en temps normal le Lua intercepte show et editor avant le coeur.
    static bool HandleShowCommand(ChatHandler* handler)
    {
        Dire(handler, SPHERIER_STR_SHOW_REPLI);
        return true;
    }

    static bool HandleEditorCommand(ChatHandler* handler)
    {
        Dire(handler, SPHERIER_STR_EDITOR_REPLI);
        return true;
    }
};

void AddSC_spherier_commands()
{
    new spherier_commandscript();
}

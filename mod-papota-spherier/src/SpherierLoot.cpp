/*
 * mod-papota-spherier — les tranches de butin.
 *
 * Tout ce qui decide « ou tombe quoi, en quelle quantite et a quel taux » est
 * ICI, en dur. Voir SpherierLoot.h pour le pourquoi.
 *
 * Source : butin_spherier.xlsx, rempli puis revise par l'utilisateur le
 * 2026-08-26. Ce fichier en est la transcription fidele et fait foi a
 * l'execution ; le classeur garde la trace de l'arbitrage. Attention,
 * outils_spherier\gen_tableau_butin.py ne regenere qu'un gabarit VIDE : le
 * relancer ecrase la saisie.
 *
 * DEUX REGLES, a ne pas confondre :
 *
 *  1. PREMIER CAS QUI CONVIENT L'EMPORTE. Les cas sont ordonnes du plus precis
 *     au plus general ; un boss d'Icecrown est aussi un boss de raid, c'est le
 *     premier cas qui le prend, et lui seul.
 *
 *  2. TOUTES LES LIGNES DU CAS RETENU SONT JOUEES, chacune avec son propre
 *     tirage. Un boss de raid rend donc un Nexus ET une pierre : ce sont deux
 *     tirages independants, pas une alternative.
 *
 * Une ligne est elle-meme une SUITE DE TENTATIVES jouees dans l'ordre, la
 * premiere gagnante l'emportant. C'est ainsi que s'ecrivent les replis, y
 * compris en chaine.
 */

#include "SpherierLoot.h"

#include "Creature.h"
#include "DBCStores.h"
#include "Formulas.h"
#include "GameObject.h"
#include "Log.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "Random.h"
#include "SharedDefines.h"
#include "SpherierMgr.h"

#include <iterator>

namespace
{
    // --- objets, tels que les engendre outils_spherier\gen_objets_spherier.py
    constexpr uint32 NEXUS_APPAUVRI  = 803200;
    constexpr uint32 NEXUS_VACILLANT = 803201;
    constexpr uint32 NEXUS_LUMINEUX  = 803202;
    constexpr uint32 NEXUS_IRRADIANT = 803203;
    constexpr uint32 NEXUS_SOLAIRE   = 803204;
    constexpr uint32 NEXUS_PRISME    = 803205;   // artefact : +25 % de gains au compte

    // Pierres : entree = 803100 + (stat - 1) * 5 + (qualite - 1), 16 statistiques.
    constexpr uint32 PIERRE_BASE  = 803100;
    constexpr uint32 PIERRE_STATS = 16;

    // Les runes n'existent pas encore (jalon 5). Les lignes qui en demandent
    // sont ecrites et resteront muettes jusqu'a leur creation — mieux vaut les
    // voir dans la table que les avoir oubliees.
    constexpr uint32 OBJET_RUNE = 0xFFFFFFFEu;

    constexpr uint32 CARTE_ICECROWN    = 631;
    constexpr uint32 GOB_SARONITE_PURE = 195036;    // meme verrou que le titane

    // Ce qu'une ligne fait tomber : une entree precise, ou une pierre dont la
    // statistique est tiree au hasard parmi les seize.
    struct Objet
    {
        uint32 entree;
        uint8  qualite;
    };

    constexpr Objet Nexus(uint32 e) { return { e, 0 }; }
    constexpr Objet Pierre(uint8 q) { return { 0, q }; }
    constexpr Objet Rune()          { return { OBJET_RUNE, 0 }; }
    constexpr Objet Rien()          { return { 0, 0 }; }

    struct Tentative
    {
        Objet objet;
        uint8 quantite;
        float chance;                   // en pourcent
    };

    constexpr Tentative T(Objet o, uint8 q, float c) { return { o, q, c }; }
    constexpr Tentative Fin()                        { return { Rien(), 0, 0.0f }; }

    // Une ligne : jusqu'a trois tentatives jouees dans l'ordre, on s'arrete au
    // premier tirage gagnant. Une tentative de chance nulle termine la chaine.
    constexpr size_t MAX_TENTATIVES = 3;

    struct Ligne
    {
        Tentative tentatives[MAX_TENTATIVES];
    };

    struct Cas
    {
        char const*  nom;
        bool (*convient)(SpherierSourceButin const&);
        Ligne const* lignes;
        size_t       nombre;
    };

    // ==================================================================
    // MONSTRES
    // ==================================================================
    Ligne const M_ICC_BOSS[] =
    {
        { { T(Nexus(NEXUS_PRISME), 1, 2.0f),      Fin(), Fin() } },   // 2 %, tout boss de raid WotLK
        { { T(Nexus(NEXUS_SOLAIRE), 1, 25.0f),
            T(Nexus(NEXUS_IRRADIANT), 1, 100.0f), Fin() } },
        { { T(Pierre(5), 1, 25.0f),
            T(Pierre(4), 2, 50.0f),
            T(Pierre(4), 1, 100.0f) } },
        { { T(Rune(), 1, 33.0f), Fin(), Fin() } },
    };

    Ligne const M_RAID_WRATH_BOSS[] =
    {
        { { T(Nexus(NEXUS_PRISME), 1, 2.0f),      Fin(), Fin() } },   // 2 %, tout boss de raid WotLK
        { { T(Nexus(NEXUS_IRRADIANT), 1, 100.0f), Fin(), Fin() } },
        { { T(Pierre(4), 1, 100.0f),              Fin(), Fin() } },
        { { T(Rune(), 1, 10.0f),                  Fin(), Fin() } },
    };

    Ligne const M_RAID_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 1, 2.0f), Fin(), Fin() } },
        { { T(Pierre(4), 1, 2.0f),             Fin(), Fin() } },
        { { T(Rune(), 1, 2.0f),                Fin(), Fin() } },
    };

    Ligne const M_HERO_BOSS[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 1, 25.0f), Fin(), Fin() } },
        { { T(Pierre(3), 1, 25.0f),             Fin(), Fin() } },
    };

    // MONSTRES DE DONJON, PAS LES BOSS : Nexus divise par deux le 2026-09-04.
    // Le trash se tue par centaines, le boss une fois par visite ; c'est le
    // premier qui faisait le gros du butin. Les PIERRES ne bougent pas, la
    // demande ne portait que sur les Nexus.
    Ligne const M_HERO[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 1, 3.0f), Fin(), Fin() } },
        { { T(Pierre(3), 1, 6.0f),             Fin(), Fin() } },
    };

    Ligne const M_DONJON_WRATH_BOSS[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 2, 20.0f), Fin(), Fin() } },
        { { T(Pierre(3), 1, 15.0f),             Fin(), Fin() } },
    };

    Ligne const M_DONJON_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 1, 2.0f), Fin(), Fin() } },
        { { T(Pierre(2), 1, 4.0f),             Fin(), Fin() } },
    };

    Ligne const M_MONDE_WRATH[] =
    {
        { { T(Nexus(NEXUS_LUMINEUX), 1, 3.0f), Fin(), Fin() } },
        { { T(Pierre(2), 1, 3.0f),             Fin(), Fin() } },
    };

    Ligne const M_RAID_BC_BOSS[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 2, 7.0f), Fin(), Fin() } },
        { { T(Pierre(2), 1, 15.0f),             Fin(), Fin() } },
    };

    Ligne const M_RAID_BC[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 1, 5.0f), Fin(), Fin() } },
        { { T(Pierre(2), 1, 5.0f),              Fin(), Fin() } },
    };

    // LE DONJON DE BC NE FAISAIT QU'UN SEUL CAS pour ses boss et son trash.
    // Diviser ce cas-la aurait emporte les boss avec, ce qui n'etait pas
    // demande : on le coupe en deux, le boss gardant son taux d'origine.
    Ligne const M_DONJON_BC_BOSS[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 1, 5.0f), Fin(), Fin() } },
        { { T(Pierre(1), 1, 5.0f),              Fin(), Fin() } },
    };

    Ligne const M_DONJON_BC[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 1, 2.5f), Fin(), Fin() } },
        { { T(Pierre(1), 1, 5.0f),              Fin(), Fin() } },
    };

    Ligne const M_MONDE_BC[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 1, 3.0f), Fin(), Fin() } },
        { { T(Pierre(1), 1, 3.0f),              Fin(), Fin() } },
    };

    Ligne const M_RAID_VANILLA_BOSS[] =
    {
        { { T(Nexus(NEXUS_VACILLANT), 2, 7.0f), Fin(), Fin() } },
    };

    Ligne const M_RAID_VANILLA[] =
    {
        { { T(Nexus(NEXUS_APPAUVRI), 1, 5.0f), Fin(), Fin() } },
    };

    Ligne const M_DONJON_VANILLA_BOSS[] =
    {
        { { T(Nexus(NEXUS_APPAUVRI), 1, 5.0f), Fin(), Fin() } },
    };

    Ligne const M_DONJON_VANILLA[] =
    {
        { { T(Nexus(NEXUS_APPAUVRI), 1, 2.5f), Fin(), Fin() } },
    };

    Ligne const M_MONDE_VANILLA[] =
    {
        { { T(Nexus(NEXUS_APPAUVRI), 1, 3.0f), Fin(), Fin() } },
    };

    // Le donjon se reconnait par « instance qui n'est pas un raid » : IsDungeon
    // du coeur couvre les deux.
    Cas const CAS_MONSTRE[] =
    {
        { "Boss de raid Icecrown", [](SpherierSourceButin const& s)
          { return s.boss && s.carte == CARTE_ICECROWN; },
          M_ICC_BOSS, std::size(M_ICC_BOSS) },

        { "Boss de raids Wrath sauf Icecrown", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.raid && s.boss; },
          M_RAID_WRATH_BOSS, std::size(M_RAID_WRATH_BOSS) },

        { "Monstres de raids Wrath (Icecrown comprise)", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.raid; },
          M_RAID_WRATH, std::size(M_RAID_WRATH) },

        { "Boss de donjons heroiques Wrath", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.donjon && !s.raid && s.heroique && s.boss; },
          M_HERO_BOSS, std::size(M_HERO_BOSS) },

        { "Monstres de donjons heroiques Wrath", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.donjon && !s.raid && s.heroique; },
          M_HERO, std::size(M_HERO) },

        { "Boss de donjons Wrath", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.donjon && !s.raid && s.boss; },
          M_DONJON_WRATH_BOSS, std::size(M_DONJON_WRATH_BOSS) },

        { "Monstres de donjons Wrath", [](SpherierSourceButin const& s)
          { return s.extension == 2 && s.donjon && !s.raid; },
          M_DONJON_WRATH, std::size(M_DONJON_WRATH) },

        { "Monstres normaux Wrath", [](SpherierSourceButin const& s)
          { return s.extension == 2; },
          M_MONDE_WRATH, std::size(M_MONDE_WRATH) },

        { "Boss de raids Burning Crusade", [](SpherierSourceButin const& s)
          { return s.extension == 1 && s.raid && s.boss; },
          M_RAID_BC_BOSS, std::size(M_RAID_BC_BOSS) },

        { "Monstres de raids Burning Crusade", [](SpherierSourceButin const& s)
          { return s.extension == 1 && s.raid; },
          M_RAID_BC, std::size(M_RAID_BC) },

        { "Boss de donjons Burning Crusade", [](SpherierSourceButin const& s)
          { return s.extension == 1 && s.donjon && !s.raid && s.boss; },
          M_DONJON_BC_BOSS, std::size(M_DONJON_BC_BOSS) },

        { "Monstres de donjons Burning Crusade", [](SpherierSourceButin const& s)
          { return s.extension == 1 && s.donjon && !s.raid; },
          M_DONJON_BC, std::size(M_DONJON_BC) },

        { "Monstres normaux Burning Crusade", [](SpherierSourceButin const& s)
          { return s.extension == 1; },
          M_MONDE_BC, std::size(M_MONDE_BC) },

        { "Boss de raids Vanilla", [](SpherierSourceButin const& s)
          { return s.raid && s.boss; },
          M_RAID_VANILLA_BOSS, std::size(M_RAID_VANILLA_BOSS) },

        { "Monstres de raids Vanilla", [](SpherierSourceButin const& s)
          { return s.raid; },
          M_RAID_VANILLA, std::size(M_RAID_VANILLA) },

        { "Boss de donjons Vanilla", [](SpherierSourceButin const& s)
          { return s.donjon && s.boss; },
          M_DONJON_VANILLA_BOSS, std::size(M_DONJON_VANILLA_BOSS) },

        { "Monstres de donjons Vanilla", [](SpherierSourceButin const& s)
          { return s.donjon; },
          M_DONJON_VANILLA, std::size(M_DONJON_VANILLA) },

        { "Monstres normaux Vanilla", [](SpherierSourceButin const& /*s*/)
          { return true; },
          M_MONDE_VANILLA, std::size(M_MONDE_VANILLA) },
    };

    // ==================================================================
    // RECOLTE
    //
    // Un type de filon ou de plante se reconnait au couple (competence exigee,
    // extension de la carte) : la competence seule ne suffit pas, le cobalt de
    // Wrath et la riche adamantite de BC exigeant tous deux 350.
    // ==================================================================
    Ligne const R_APPAUVRI_3[]  = { { { T(Nexus(NEXUS_APPAUVRI),  1,  3.0f), Fin(), Fin() } } };
    Ligne const R_VACILLANT_3[] = { { { T(Nexus(NEXUS_VACILLANT), 1,  3.0f), Fin(), Fin() } } };
    Ligne const R_LUMINEUX_3[]  = { { { T(Nexus(NEXUS_LUMINEUX),  1,  3.0f), Fin(), Fin() } } };
    Ligne const R_LUMINEUX_5[]  = { { { T(Nexus(NEXUS_LUMINEUX),  1,  5.0f), Fin(), Fin() } } };
    Ligne const R_LUMINEUX_7[]  = { { { T(Nexus(NEXUS_LUMINEUX),  1,  7.0f), Fin(), Fin() } } };
    Ligne const R_LUMINEUX_8[]  = { { { T(Nexus(NEXUS_LUMINEUX),  1,  8.0f), Fin(), Fin() } } };
    Ligne const R_IRRADIANT_10[] = { { { T(Nexus(NEXUS_IRRADIANT), 1, 10.0f), Fin(), Fin() } } };

    // Filon de titane : a defaut d'irradiant, un lumineux a 10 %.
    Ligne const R_TITANE[] =
    {
        { { T(Nexus(NEXUS_IRRADIANT), 1, 3.0f),
            T(Nexus(NEXUS_LUMINEUX), 1, 10.0f), Fin() } },
    };

    bool EstMinage(SpherierSourceButin const& s) { return s.metier == LOCKTYPE_MINING; }
    bool EstHerbo(SpherierSourceButin const& s)  { return s.metier == LOCKTYPE_HERBALISM; }

    Cas const CAS_RECOLTE[] =
    {
        // --- minage ---------------------------------------------------
        // Le gisement de saronite pure partage le verrou du titane : seule son
        // entree les separe. Il ne donne rien (« NA » au classeur).
        { "Gisement de saronite pure", [](SpherierSourceButin const& s)
          { return s.gob && s.gob->GetEntry() == GOB_SARONITE_PURE; },
          nullptr, 0 },

        { "Filon de titane", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence == 450; },
          R_TITANE, std::size(R_TITANE) },

        { "Riche gisement de saronite", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence == 425; },
          R_LUMINEUX_8, std::size(R_LUMINEUX_8) },

        { "Gisement de saronite", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence == 400; },
          R_LUMINEUX_7, std::size(R_LUMINEUX_7) },

        { "Riche gisement de cobalt", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence == 375 && s.extension == 2; },
          R_LUMINEUX_5, std::size(R_LUMINEUX_5) },

        { "Gisement de cobalt", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence == 350 && s.extension == 2; },
          R_LUMINEUX_3, std::size(R_LUMINEUX_3) },

        { "Minerais de Burning Crusade", [](SpherierSourceButin const& s)
          { return EstMinage(s) && s.competence >= 275; },
          R_VACILLANT_3, std::size(R_VACILLANT_3) },

        { "Minerais de Vanilla", EstMinage,
          R_APPAUVRI_3, std::size(R_APPAUVRI_3) },

        // --- herboristerie --------------------------------------------
        { "Lotus de givre", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 450 && s.extension == 2; },
          R_IRRADIANT_10, std::size(R_IRRADIANT_10) },

        { "Givrepine", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 435; },
          R_LUMINEUX_7, std::size(R_LUMINEUX_7) },

        { "Fleau-de-liche", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 425; },
          R_LUMINEUX_7, std::size(R_LUMINEUX_7) },

        { "Langue-de-vipere", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 400 && s.extension == 2; },
          R_LUMINEUX_5, std::size(R_LUMINEUX_5) },

        { "Rose de Talandra", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 385; },
          R_LUMINEUX_5, std::size(R_LUMINEUX_5) },

        { "Lis-tigre", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 375 && s.extension == 2; },
          R_LUMINEUX_5, std::size(R_LUMINEUX_5) },

        { "Epine-de-feu", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 360; },
          R_LUMINEUX_3, std::size(R_LUMINEUX_3) },

        { "Trefle-d'or", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 350 && s.extension == 2; },
          R_LUMINEUX_3, std::size(R_LUMINEUX_3) },

        { "Herbe gelee", [](SpherierSourceButin const& s)
          { return EstHerbo(s) && s.competence == 300 && s.extension == 2; },
          R_LUMINEUX_3, std::size(R_LUMINEUX_3) },

        // Le lotus noir (300, Vanilla) et la gangrehete (300, BC) partagent leur
        // exigence : c'est la carte qui les separe.
        { "Plantes de Burning Crusade", [](SpherierSourceButin const& s)
          { return EstHerbo(s)
                   && (s.competence > 300 || (s.competence == 300 && s.extension == 1)); },
          R_VACILLANT_3, std::size(R_VACILLANT_3) },

        { "Plantes de Vanilla", EstHerbo,
          R_APPAUVRI_3, std::size(R_APPAUVRI_3) },
    };

    // ==================================================================
    // DEPECAGE
    // ==================================================================
    Ligne const D_80[] = { { { T(Nexus(NEXUS_IRRADIANT), 1, 7.0f), Fin(), Fin() } } };
    Ligne const D_71[] = { { { T(Nexus(NEXUS_LUMINEUX),  1, 3.0f), Fin(), Fin() } } };
    Ligne const D_61[] = { { { T(Nexus(NEXUS_VACILLANT), 1, 3.0f), Fin(), Fin() } } };
    Ligne const D_1[]  = { { { T(Nexus(NEXUS_APPAUVRI),  1, 3.0f), Fin(), Fin() } } };

    Cas const CAS_DEPECAGE[] =
    {
        { "Depecage 80-83", [](SpherierSourceButin const& s) { return s.niveau >= 80; },
          D_80, std::size(D_80) },
        { "Depecage 71-79", [](SpherierSourceButin const& s) { return s.niveau >= 71; },
          D_71, std::size(D_71) },
        { "Depecage 61-70", [](SpherierSourceButin const& s) { return s.niveau >= 61; },
          D_61, std::size(D_61) },
        { "Depecage 1-60", [](SpherierSourceButin const& /*s*/) { return true; },
          D_1, std::size(D_1) },
    };

    // ==================================================================
    // COFFRES
    // ==================================================================
    Ligne const C_RAID[]   = { { { T(Nexus(NEXUS_VACILLANT), 2, 10.0f), Fin(), Fin() } } };
    Ligne const C_HERO[]   = { { { T(Nexus(NEXUS_APPAUVRI),  5, 10.0f), Fin(), Fin() } } };
    Ligne const C_DONJON[] = { { { T(Nexus(NEXUS_APPAUVRI),  3, 10.0f), Fin(), Fin() } } };
    Ligne const C_MONDE[]  = { { { T(Nexus(NEXUS_APPAUVRI),  1, 10.0f), Fin(), Fin() } } };

    Cas const CAS_COFFRE[] =
    {
        { "Coffre de raid", [](SpherierSourceButin const& s) { return s.raid; },
          C_RAID, std::size(C_RAID) },
        { "Coffre de donjon heroique", [](SpherierSourceButin const& s)
          { return s.donjon && s.heroique; }, C_HERO, std::size(C_HERO) },
        { "Coffre de donjon", [](SpherierSourceButin const& s) { return s.donjon; },
          C_DONJON, std::size(C_DONJON) },
        { "Coffre du monde", [](SpherierSourceButin const& /*s*/) { return true; },
          C_MONDE, std::size(C_MONDE) },
    };

    // ------------------------------------------------------------------
    // Mecanique
    // ------------------------------------------------------------------

    // Pierre au hasard parmi les 16 statistiques, dans la qualite demandee.
    uint32 PierreAleatoire(uint8 qualite)
    {
        if (!qualite || qualite > 5)
            return 0;
        uint32 const stat = urand(1, PIERRE_STATS);
        return PIERRE_BASE + (stat - 1) * 5 + (qualite - 1);
    }

    // UNE RUNE AU HASARD parmi les 154, TOUTES CLASSES CONFONDUES (arbitrage
    // du 2026-09-04). Un guerrier peut donc ramasser une rune de druide : elle
    // ne lui sert a rien, mais elle s'echange.
    //
    // Le catalogue vit dans SpherierMgr et se recharge (.spherier reload) : on
    // le parcourt a chaque tirage plutot que d'en garder une copie qui
    // vieillirait en silence. Cent cinquante-quatre entrees ne coutent rien.
    uint32 RuneAleatoire()
    {
        auto const& runes = sSpherierMgr->Runes();
        if (runes.empty())
            return 0;
        auto it = runes.begin();
        std::advance(it, urand(0, uint32(runes.size()) - 1));
        return it->first;
    }

    // Entree reelle d'un objet, ou 0 s'il n'y a rien a poser.
    uint32 Resoudre(Objet const& objet)
    {
        if (objet.entree == OBJET_RUNE)
            return RuneAleatoire();
        return objet.entree ? objet.entree : PierreAleatoire(objet.qualite);
    }

    // Une quantite d'objet PRECIS donne une pile ; une quantite de PIERRE donne
    // autant de tirages distincts, chacun sur sa propre statistique — deux
    // pierres identiques n'auraient aucun interet.
    void Poser(Loot* loot, Objet const& objet, uint8 quantite, char const* cas)
    {
        if (!quantite)
            return;

        bool const aleatoire = (objet.entree == 0);
        uint8 const tirages  = aleatoire ? quantite : 1;
        uint8 const parPile  = aleatoire ? 1 : quantite;

        for (uint8 t = 0; t < tirages; ++t)
        {
            uint32 const entree = Resoudre(objet);
            if (!entree)
                return;

            // La fenetre de butin est plafonnee : au-dela, Loot::AddItem
            // abandonne en silence. On le dit plutot que de le laisser passer
            // pour un tirage malheureux.
            if (loot->items.size() >= MAX_NR_LOOT_ITEMS)
            {
                LOG_DEBUG("module", "Spherier : butin plein, {} non ajoute ({}).", entree, cas);
                return;
            }

            loot->AddItem(LootStoreItem(entree, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0,
                                        parPile, parPile));

            // De quoi savoir ce qui a produit un objet : sans cela, on ne peut
            // pas distinguer un tirage heureux d'une tranche mal ecrite.
            // Se lit avec « Logger.module=5,Console Server » dans worldserver.conf.
            LOG_DEBUG("module", "Spherier butin : {} x{} — cas « {} ».",
                      entree, parPile, cas);
        }
    }

    // Retient le premier cas qui convient, puis joue TOUTES ses lignes ; chaque
    // ligne s'arrete a sa premiere tentative gagnante.
    // UN MONSTRE GRIS RAPPORTE CINQ FOIS MOINS (arbitrage du 2026-09-04). Les
    // paliers de Nexus suivent l'extension de la CARTE, jamais la difficulte
    // reelle : sans ce frein, un joueur de 80 traverse seul Molten Core et y
    // recolte au meme rythme qu'en raid de son niveau. On ne ferme pas la
    // porte, on la retrecit — le vieux contenu reste jouable, il cesse d'etre
    // une ferme.
    //
    // LE GRIS EST LA NOTION DU JEU LUI-MEME (Acore::XP::GetGrayLevel), celle
    // qui coupe deja l'experience : au-dela du niveau 59 elle vaut `niveau - 9`,
    // soit 71 et moins pour un joueur de 80. Les 45 boss de raid Vanilla (63) y
    // tombent, les 58 boss de BC (73) non.
    //
    // TROIS BOSS DE KARAZHAN sont de niveau 70 — Echo de Medivh, Neantesprit,
    // Terestian Alombre — et tombent donc dans le frein quand Attumen, au meme
    // endroit, n'y tombe pas. L'irregularite est CONNUE ET ACCEPTEE (arbitrage
    // du 2026-09-04) : ne pas la "corriger" par megarde en croyant a un oubli.
    //
    // RESERVE AUX BOSS (arbitrage du 2026-09-04). C'est le contenu de raid
    // ancien qu'on freine, pas le monde ordinaire : depecer une bete grise, ou
    // tuer un monstre de passage, ne regarde pas cette regle. Un filon ou une
    // plante n'a de toute facon pas de niveau.
    constexpr float GRIS_DIVISEUR = 5.0f;

    float FacteurDeNiveau(SpherierSourceButin const& source)
    {
        if (!source.creature || !source.joueur || !source.boss)
            return 1.0f;
        if (source.niveau > Acore::XP::GetGrayLevel(source.joueur->GetLevel()))
            return 1.0f;
        return 1.0f / GRIS_DIVISEUR;
    }

    void Appliquer(Loot* loot, SpherierSourceButin const& source,
                   Cas const* cas, size_t nombre)
    {
        float const facteur = FacteurDeNiveau(source);
        for (size_t i = 0; i < nombre; ++i)
        {
            if (!cas[i].convient(source))
                continue;

            for (size_t j = 0; j < cas[i].nombre; ++j)
                for (Tentative const& t : cas[i].lignes[j].tentatives)
                {
                    if (t.chance <= 0.0f)
                        break;          // fin de la chaine de replis
                    // Le facteur porte sur le TIRAGE, pas sur la fin de chaine
                    // ci-dessus : une tentative reduite reste une tentative, et
                    // c'est toujours la chance ECRITE qui dit ou la chaine
                    // s'arrete.
                    if (roll_chance_f(t.chance * facteur))
                    {
                        Poser(loot, t.objet, t.quantite, cas[i].nom);
                        break;
                    }
                }
            return;                     // un seul cas, jamais deux
        }
    }

    // Le butin d'un objet du sac (prospection, broyage, desenchantement...) n'a
    // pas d'objet du monde pour source : sourceWorldObjectGUID reste vide, et
    // il n'y a rien a discriminer. Ces butins ne nous concernent pas.
    Creature* CreatureSource(Loot* loot, Player* joueur)
    {
        if (!loot->sourceWorldObjectGUID.IsCreature())
            return nullptr;
        return ObjectAccessor::GetCreature(*joueur, loot->sourceWorldObjectGUID);
    }

    GameObject* GobSource(Loot* loot, Player* joueur)
    {
        if (!loot->sourceWorldObjectGUID.IsGameObject())
            return nullptr;
        return ObjectAccessor::GetGameObject(*joueur, loot->sourceWorldObjectGUID);
    }

    // L'extension vient de la CARTE (Map.dbc), pas de la creature : c'est elle
    // qui dit qu'un donjon est de Vanilla, de BC ou de Wrath, quels que soient
    // les modeles reutilises par ses occupants.
    void RenseignerCarte(SpherierSourceButin& s, Map* carte)
    {
        if (!carte)
            return;

        s.donjon   = carte->IsDungeon();
        s.raid     = carte->IsRaid();
        s.heroique = carte->IsHeroic();

        if (MapEntry const* entree = carte->GetEntry())
            s.extension = entree->Expansion();
    }

    void RenseignerCreature(SpherierSourceButin& s, Creature* crea)
    {
        s.creature = crea;
        s.niveau   = crea->GetLevel();
        s.rang     = crea->GetCreatureTemplate()->rank;
        s.boss     = crea->IsDungeonBoss() || crea->isWorldBoss()
                     || s.rang == CREATURE_ELITE_WORLDBOSS;
        s.carte    = crea->GetMapId();
        s.zone     = crea->GetZoneId();

        RenseignerCarte(s, crea->GetMap());
    }

    // Ce qu'un objet de jeu est pour nous, et — si c'est une recolte — le metier
    // et la competence exigee. Celle-ci vit dans le verrou (Lock.dbc), pas dans
    // l'entree ni dans la zone.
    //
    // ATTENTION : une competence de ZERO est legitime et frequente. Le cuivre
    // et les herbes de depart exigent le metier sans exiger de niveau — verifie
    // dans Lock.dbc (verrous 38 et 29). Confondre « aucune exigence » avec
    // « ce n'est pas une recolte » ferait disparaitre tout le contenu de depart.
    void RenseignerGob(SpherierSourceButin& s, GameObject* gob)
    {
        s.gob   = gob;
        s.carte = gob->GetMapId();
        s.zone  = gob->GetZoneId();
        RenseignerCarte(s, gob->GetMap());

        GameObjectTemplate const* modele = gob->GetGOInfo();
        if (modele->type == GAMEOBJECT_TYPE_FISHINGHOLE)
        {
            s.genre = SPHERIER_GOB_BANC_PECHE;
            return;
        }

        if (uint32 lockId = modele->GetLockId())
            if (LockEntry const* verrou = sLockStore.LookupEntry(lockId))
                for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
                    if (verrou->Type[i] == LOCK_KEY_SKILL
                        && (verrou->Index[i] == LOCKTYPE_HERBALISM
                            || verrou->Index[i] == LOCKTYPE_MINING))
                    {
                        s.genre      = SPHERIER_GOB_RECOLTE;
                        s.metier     = verrou->Index[i];
                        s.competence = verrou->Skill[i];
                        return;
                    }

        if (modele->type == GAMEOBJECT_TYPE_CHEST)
            s.genre = SPHERIER_GOB_COFFRE;
    }
}

void SpherierRemplirButin(Loot* loot, LootStore const& store, Player* joueur)
{
    // Garde-fou de performance : ce crochet part sur CHAQUE butin rempli du
    // serveur, y compris ceux des 2500 bots. Le test de magasin d'abord, il
    // ecarte tout le reste sans rien lire. LootTemplates_Fishing n'est
    // volontairement PAS de la partie : la peche ne donne rien.
    bool const monstre  = (&store == &LootTemplates_Creature);
    bool const objetJeu = (&store == &LootTemplates_Gameobject);
    bool const depecage = (&store == &LootTemplates_Skinning);

    if (!monstre && !objetJeu && !depecage)
        return;
    if (!joueur || !loot)
        return;

    SpherierSourceButin source;
    source.joueur = joueur;

    if (monstre || depecage)
    {
        Creature* crea = CreatureSource(loot, joueur);
        if (!crea)
            return;
        RenseignerCreature(source, crea);

        if (monstre)
            Appliquer(loot, source, CAS_MONSTRE, std::size(CAS_MONSTRE));
        else
            Appliquer(loot, source, CAS_DEPECAGE, std::size(CAS_DEPECAGE));
        return;
    }

    GameObject* gob = GobSource(loot, joueur);
    if (!gob)
        return;

    RenseignerGob(source, gob);

    // Le magasin des objets de jeu couvre trois choses distinctes. Les bancs de
    // peche ne donnent rien par decision.
    if (source.genre == SPHERIER_GOB_RECOLTE)
        Appliquer(loot, source, CAS_RECOLTE, std::size(CAS_RECOLTE));
    else if (source.genre == SPHERIER_GOB_COFFRE)
        Appliquer(loot, source, CAS_COFFRE, std::size(CAS_COFFRE));
}

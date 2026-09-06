/*
 * Les sorts de classe du spherier.
 *
 * QUINZE SCRIPTS SEULEMENT, la ou il en fallait trente et un : l'effet 27,
 * PERSISTENT_AREA_AURA, existe en 3.3.5 — c'est lui qui fait la Consecration et
 * la Pluie de feu. Il pose au point vise un objet dynamique qui applique une
 * aura periodique a qui s'y trouve, et cela couvrait a lui seul toutes nos zones
 * au sol : jugement, barriere, singularite, brulures, plume angelique. Trois
 * auras suffisent a les distinguer — 87 pour les degats subis, 53 pour le drain
 * qui soigne le lanceur, 3 pour la brulure. Un cone de degats, un soin en cone,
 * une canalisation periodique s'ecrivent de meme entierement dans le DBC.
 *
 * Ce qui reste ici est ce qu'aucun champ ne sait dire : lire une ressource,
 * tirer au sort, mesurer une distance, invoquer, compter les incantations.
 *
 * LA REGLE DE DIRECTION, d'abord, parce qu'elle est commune a tous les
 * deplacements lineaires : un bond part dans la direction ou le personnage VA
 * s'il bouge, et devant lui s'il est immobile.
 */

#include "CellImpl.h"
#include "Chat.h"
#include "CombatManager.h"
#include "Containers.h"
#include "Creature.h"
#include "GameObject.h"
#include "GameObjectAI.h"
#include "GameTime.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "ObjectAccessor.h"
#include "CombatAI.h"
#include "Pet.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "MoveSplineInit.h"
#include "MovementTypedefs.h"
#include "Player.h"
#include "ScriptedCreature.h"
#include "TemporarySummon.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellAuraEffects.h"
#include "SpellMgr.h"
#include "SpellScript.h"

namespace
{
    // --- le bond -----------------------------------------------------------
    constexpr uint32 BOURRASQUE = 8600060;   // le bond du chaman
    constexpr float BOURRASQUE_FACTEUR = 1.5f;  // 30 m : le double du bond
                                                // ordinaire, moins un quart
                                                // (2026-09-02)
    constexpr float BOURRASQUE_VITESSE = 1.2f;  // +20 % (2026-09-02)
    constexpr float BOND_DISTANCE = 20.0f;
    constexpr float BOND_VITESSE = 22.0f;
    constexpr float BOND_HAUTEUR = 9.0f;
    // Le Bond heroique CIBLE a ses propres reglages (2026-08-30 : parabole
    // et vitesse augmentees a la demande de l'utilisateur) — Bourrasque et
    // Miroitement gardent les valeurs directionnelles ci-dessus.
    // La DUREE pilote la vitesse (2026-08-30) : 0,15 s a bout portant,
    // 0,75 s a portee maximale, lineaire entre les deux. Les vitesses fixes
    // (32 puis 45) etaient de toute facon ecretees en silence a 28 m/s par
    // le plafond des splines (MoveSplineInit::Launch : max(28, course x4)
    // hors vol, miroir du client) — d'ou le « trop lente » persistant.
    constexpr float BOND_H_DUREE_MIN = 0.15f;
    constexpr float BOND_H_DUREE_MAX = 0.75f;
    constexpr float BOND_H_PORTEE = 35.0f;
    constexpr float BOND_H_PARABOLE = 14.0f;
    // Habillage retroporte (2026-08-30, gen_visuel_guerrier) : l'etat de
    // charge pendant le vol, l'impact (effet + son dans le kit) au sol.
    constexpr uint32 BOND_H_KIT_VOL = 30026;    // cfx_warrior_charge_state
    constexpr uint32 BOND_H_KIT_IMPACT = 30027; // cfx_warrior_heroicleap_cast02

    // L'HABILLAGE VIENT DU SORT (2026-09-03). Le bond a deux temps — le vol
    // et l'impact — et l'impact doit tomber a l'atterrissage, ce qu'aucun
    // champ de Spell.dbc ne sait dater : le script reste donc le seul a
    // pouvoir l'envoyer. Ce qu'il ne decide plus, c'est QUOI envoyer : le
    // champ SpellVisual du sort le dit, et a zero le bond part nu. C'est
    // ainsi que le Bond de l'ours (8610016) est muet sans toucher au Bond
    // heroique du guerrier (8600000), qui porte le meme code.
    //
    // La table est ici parce que le serveur ne charge pas les colonnes de
    // kits de SpellVisual.dbc — DBCStructure.h les laisse commentees, seuls
    // HasMissile et MissileModel en sont lus.
    struct HabillageBond
    {
        uint32 visuel, vol, impact;
    };
    constexpr HabillageBond BOND_H_HABILLAGES[] = { { 30028, 30026, 30027 } };
    // Les animations vivent DANS les kits (Ready2H au vol, Special2H fondu
    // dans l'impact — option 1 arretee le 2026-08-30) : les caler pour finir
    // a l'impact est impossible, toutes les frappes font 900-1500 ms (mesure
    // M2) contre 750 ms de vol maximal, et aucun canal de 3.3.5 ne module la
    // vitesse d'une animation.

    // --- le dash fumee (ex-grappin) ----------------------------------------
    // DESIGN « DASH FUMEE » (pivots utilisateur des 2026-08-29/30, le grappin
    // est abandonne). Sequence en 7 temps, tous orchestres ici : 1 reticule
    // au sol (DBC) ; 2 dummy INVISIBLE au point vise ; 3 fumee sur le
    // joueur ; 4 le personnage devient invisible et intouchable ; 5 il se
    // TELEPORTE derriere le dummy — copie de Pas de l'ombre (DASH_PAS),
    // demandee en remplacement de la charge : MoveCharge subissait le
    // plafond de spline (4x la course, serveur ET client) et l'acquittement
    // d'allure (piege SetSpeedRate/SetSpeed, archive en memoire de projet) ;
    // 6 fumee sur le dummy ; 7 reapparition.
    constexpr uint32 DASH_DUMMY = 803804;       // clone trigger, display 802102
    constexpr uint32 DASH_FUMEE_KIT = 404;      // kit de lancer de Disparition
    constexpr uint32 DASH_INVISIBLE = 802102;   // display opacite 0 (tous)
    constexpr uint32 DASH_PAS = 8600039;        // copie du coeur de Pas de
                                                // l'ombre (36563), declenchee
    // Entre la teleportation et la reapparition : le temps que le client
    // integre la nouvelle position avant de re-montrer le personnage.
    constexpr uint32 DASH_MARGE = 100;

    // --- creatures invoquees ----------------------------------------------
    // TOUTES A NOUS. L'audit a montre que les empruntees etaient des ennemis :
    // la goule 26125 est faction 14 — hostile a tous — avec le script des pets
    // de chevalier, le garde funeste 11859 est un demon en SmartAI. Nos clones
    // (803801+) reprennent leurs modeles et leurs chiffres, sans leur passe ;
    // leur IA propre leur donne la faction de l'invocateur et la cible de
    // son maitre. (L'IA commune d'origine, npc_papota_invocation, a ete
    // RETIREE le 2026-09-03 : plus aucune creature ne la portait — le
    // serveur s'en plaignait au demarrage — et elle gardait le defaut de
    // prise de cible corrige ce jour-la, ou AttackStart designe une victime
    // sans entrer en combat.)
    constexpr uint32 SEDUCTION = 6358;   // la Seduction NATIVE de la succube
    constexpr uint32 GHOULE = 803801;
    constexpr uint32 GARDE_FUNESTE = 803802;
    constexpr uint32 TOTEM = 803803;
    // (Le PNJ Gardien des anciens rois — 803800, modele de Terenas — a ete
    // RETIRE le 2026-08-30 a la demande de l'utilisateur : le sort 8600012
    // ne garde que sa reduction de degats, portee par le DBC seul.)
    constexpr uint32 DESTRIER_ASPECT = 14584;   // l'apparence du destrier de paladin

    constexpr uint32 CHAINE_ECLAIRS = 49271; // Chaine d'eclairs, rang MAX —
                                         // le rang 1 frappait comme un niveau 6

    // --- le mage (salve du 2026-08-30) -------------------------------------
    constexpr float MIROIT_DISTANCE = 40.0f;    // copie de Transfert : 40 m
    // Le Miroitement EN DEUX TEMPS (2026-08-31) : le premier lancer pose la
    // marque et RETIRE la recharge que le coeur vient d'appliquer (elle est
    // envoyee AVANT les effets, Spell::cast) ; le retour la laisse tomber
    // naturellement ; l'expiration du temoin la pose a la main.
    constexpr uint32 MIROIT_MARQUE = 803810;    // display 802107, rune au sol
    constexpr uint32 MIROIT_TEMOIN = 8600058;   // l'aura de 5 s
    constexpr uint32 MIROIT_FENETRE = 5000;     // ms — la fenetre de retour
    constexpr uint32 MIROIT_RECHARGE = 20000;   // ms — miroir du DBC
    constexpr uint32 MIROITEMENT = 8600070;
    constexpr uint32 ORBE_CREATURE = 803806;    // l'orbe visible (802103)
    constexpr int32 ORBE_DEGATS = 750;          // miroir du $s1 du DBC
    constexpr float ORBE_PORTEE = 30.0f;        // course de l'orbe (2026-08-30)
    constexpr float ORBE_VITESSE = 16.0f;       // m/s — vitesse d'origine
                                                // RETABLIE (2026-08-30), le
                                                // frein sur cible reste
    constexpr float ORBE_VITESSE_LENTE = 1.0f;  // le frein DRASTIQUE quand une
                                                // cible est dans le rayon
    constexpr float ORBE_RAYON = 3.0f;          // rayon de frappe
    constexpr uint32 ORBE_KIT_IMPACT = 30033;   // le son d'impact exporte
    constexpr uint32 ORBE_TIC = 250;            // ms — cadence du balayage
                                                // (frein reactif) ; les
                                                // DEGATS tombent toutes les
                                                // 1000 ms (accumulateur)
    // Le cycle d'animations (2026-08-30) : Stand fond PARFAITEMENT dans Hold
    // (constate en jeu — la pause de naissance est retiree, depart immediat) ;
    // Hold boucle EN VOL (sequence retaguee Run dans le modele,
    // gen_visuel_mage) ; Decay (333 ms) part a l'arrivee via l'emote custom.
    constexpr uint32 ORBE_DECAY = 333;          // ms — la duree de Decay
    constexpr uint32 ORBE_EMOTE_DECAY = 990001; // Emotes.dbc custom (anim 159)
    // (Le RETROPORT du Meteore — trois creatures 803807-09, coutures, sons
    // 990108-10, kits 30034-36, emote d'etat 990002 — a ete RETIRE le
    // 2026-08-31 : le sort 8600072 est revenu a sa forme DBC d'origine.
    // Les donnees injectees restent dormantes dans patch-z/Data\dbc.)

    /*
     * L'angle de deplacement, RELATIF a l'orientation du personnage.
     *
     * Le client envoie un masque de touches en plus de l'orientation. Les
     * combinaisons opposees s'annulent — avant et arriere ensemble ne deplacent
     * pas —, ce qui ramene au regard, et c'est le comportement voulu.
     */
    float AngleDeplacement(Unit const* unite)
    {
        uint32 const f = unite->GetUnitMovementFlags();
        int const avantArriere = ((f & MOVEMENTFLAG_FORWARD) ? 1 : 0)
                               - ((f & MOVEMENTFLAG_BACKWARD) ? 1 : 0);
        int const gaucheDroite = ((f & MOVEMENTFLAG_STRAFE_LEFT) ? 1 : 0)
                               - ((f & MOVEMENTFLAG_STRAFE_RIGHT) ? 1 : 0);

        if (avantArriere == 0 && gaucheDroite == 0)
            return 0.0f;                              // immobile : droit devant
        if (avantArriere == 0)
            return gaucheDroite > 0 ? float(M_PI) / 2.0f : -float(M_PI) / 2.0f;
        if (gaucheDroite == 0)
            return avantArriere > 0 ? 0.0f : float(M_PI);
        float const base = avantArriere > 0 ? 0.0f : float(M_PI);
        float const cote = float(M_PI) / 4.0f * float(gaucheDroite);
        return avantArriere > 0 ? base + cote : base - cote;
    }

    /*
     * Bondir dans une direction, pour un JOUEUR.
     *
     * MotionMaster::MoveJumpTo refuse les joueurs, et son commentaire dit
     * pourquoi : « this function may make players fall below map ». Il passe par
     * GetClosePoint, qui ne teste pas la geometrie. On passe donc par
     * MovePositionToFirstCollision — qui AJOUTE elle-meme l'orientation, d'ou
     * l'angle relatif et jamais l'absolu — puis MoveJump.
     */
    void BondirVers(Unit* unite, float angleRelatif, float distance,
                    bool garderCap = false, float vitesse = BOND_VITESSE,
                    float hauteur = BOND_HAUTEUR)
    {
        Position destination = unite->GetPosition();
        unite->MovePositionToFirstCollision(destination, distance, angleRelatif);
        if (!garderCap)
        {
            unite->GetMotionMaster()->MoveJump(destination, vitesse,
                                               hauteur);
            return;
        }
        // LE SAUT QUI NE FAIT PAS TOURNER (2026-09-02) : sans consigne de
        // cap, la spline oriente l'unite le long de son trajet — le
        // personnage pivotait donc vers sa destination. MoveJump n'offre pas
        // de le lui dire ; on batit la spline soi-meme et on lui impose le
        // cap ACTUEL. Le reste reprend MoveJump mot pour mot, apogee
        // comprise.
        float const moitie = hauteur / float(Movement::gravity);
        float const apogee =
            -Movement::computeFallElevation(moitie, false, -hauteur);
        Movement::MoveSplineInit init(unite);
        init.MoveTo(destination.GetPositionX(), destination.GetPositionY(),
                    destination.GetPositionZ());
        init.SetParabolic(apogee, 0.0f);
        init.SetVelocity(vitesse);
        init.SetFacing(unite->GetOrientation());
        init.Launch();
    }

    // =======================================================================
    // Bond heroique — le saut vise un point (refonte du 2026-08-30)
    // =======================================================================
    // Le bond directionnel du guerrier devient un saut CIBLE : reticule au
    // sol, 20 m. Le trajet est refait depuis le lanceur par
    // MovePositionToFirstCollision — pas de saut a travers les murs — puis
    // MoveJump (parabole NON NULLE, l'acquis : sans elle le client fait
    // courir au sol).
    // LE BOND DU GUERRIER, en fonction libre : la Charge sauvage du druide
    // en forme d'ours doit le rejouer a l'identique, et deux copies
    // divergeraient au premier reglage.
    void KitsDuBond(uint32 visuel, uint32& vol, uint32& impact)
    {
        vol = impact = 0;
        for (HabillageBond const& h : BOND_H_HABILLAGES)
            if (h.visuel == visuel)
            {
                vol = h.vol;
                impact = h.impact;
                return;
            }
    }

    void BondHeroique(Unit* lanceur, WorldLocation const* but, uint32 visuel)
    {
        if (!lanceur || !but)
            return;
        // DIRECTEMENT au point du sort (2026-08-30) : le recalcul par
        // MovePositionToFirstCollision, herite du grappin, pouvait
        // s'arreter au premier relief du terrain — le reticule du
        // client a deja valide la destination.
        float dist = lanceur->GetExactDist(but);
        float duree = BOND_H_DUREE_MIN
            + (BOND_H_DUREE_MAX - BOND_H_DUREE_MIN)
            * std::min(dist / BOND_H_PORTEE, 1.0f);
        float vitesse = dist / std::max(duree, 0.001f);

        // Au-dela du plafond des splines, la course est FORCEE juste
        // assez haut (paquet client compris — l'acquis SetSpeed du
        // dash : le brut SetSpeedRate laissait le client a 28 etirer
        // les splines), puis recalculee a l'atterrissage depuis les
        // auras. 46,7 m/s a portee max : plafond requis ~1,67x.
        bool debride = vitesse > std::max(28.0f,
            lanceur->GetSpeed(MOVE_RUN) * 4.0f);
        if (debride)
            lanceur->SetSpeed(MOVE_RUN,
                vitesse / (4.0f * baseMoveSpeed[MOVE_RUN]), true);

        lanceur->GetMotionMaster()->MoveJump(*but, vitesse,
                                             BOND_H_PARABOLE);
        if (Player* joueur = lanceur->ToPlayer())
            sScriptMgr->AnticheatSetUnderACKmount(joueur);

        // La pose (arme levee au vol, coup a l'impact) vit dans les
        // ANIMATIONS des kits 30026/30027 (Ready2H 27 / Attack2H 18,
        // gen_visuel_guerrier) : l'etat d'emote READY2H tente d'abord ne
        // primait pas sur l'anim de saut du client (2026-08-30).

        // L'habillage (2026-08-30) : l'etat de charge au depart, et
        // l'impact a l'echeance de la duree REELLE de la spline que
        // MoveJump vient de poser — le joueur touche terre a cet
        // instant, l'effet et son son (dans le kit) partent de lui.
        // L'arme DEGAINEE pendant le saut (2026-08-30) : le lancement
        // basculait l'etat de fourreau et rangeait l'arme — la garde
        // Ready2H jouait a vide.
        uint32 kitVol = 0, kitImpact = 0;
        KitsDuBond(visuel, kitVol, kitImpact);
        if (kitVol)
        {
            lanceur->SetSheath(SHEATH_STATE_MELEE);
            lanceur->SendPlaySpellVisual(kitVol);
        }
        // L'evenement part MEME SANS KIT : c'est lui qui rend sa vitesse
        // normale au joueur debride, l'habillage n'est qu'un passager.
        ObjectGuid guid = lanceur->GetGUID();
        int32 vol = lanceur->movespline->Duration();
        lanceur->m_Events.AddEventAtOffset([guid, debride, kitImpact]()
        {
            if (Player* j = ObjectAccessor::FindPlayer(guid))
            {
                if (kitImpact)
                    j->SendPlaySpellVisual(kitImpact);
                if (debride)
                    j->UpdateSpeed(MOVE_RUN, true);
            }
        }, Milliseconds(vol));
    }

    class spell_papota_bond_heroique : public SpellScript
    {
        PrepareSpellScript(spell_papota_bond_heroique);

        void Bondir(SpellEffIndex /*index*/)
        {
            BondHeroique(GetCaster(), GetExplTargetDest(),
                         GetSpellInfo()->SpellVisual[0]);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_papota_bond_heroique::Bondir,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // (Fureur d'Odyn n'a PAS de script : son cone au sol vit dans le kit de
    // lancer, champ 14 « effet monde » — le mecanisme natif de l'Onde de
    // choc, releve 10703/9854 du 2026-08-30. La tentative par dummy-socle,
    // jamais rendue a l'ecran, est retiree.)

    // =======================================================================
    // Miroitement — la copie de Transfert, dans la direction des touches
    // =======================================================================
    // Refonte du 2026-08-30 : plus un saut mais une TELEPORTATION (copie de
    // Transfert), 40 m, arretee au premier obstacle, direction du
    // deplacement conservee (AngleDeplacement, angle RELATIF —
    // MovePositionToFirstCollision ajoute l'orientation elle-meme).
    // La marque POSEE PAR CE JOUEUR (les marques d'autrui sont ignorees).
    Creature* MiroitementMarque(Player* joueur)
    {
        std::list<Creature*> marques;
        joueur->GetCreatureListWithEntryInGrid(marques, MIROIT_MARQUE,
                                               MIROIT_DISTANCE * 3.0f);
        for (Creature* marque : marques)
            if (TempSummon* invoquee = marque->ToTempSummon())
                if (invoquee->GetSummonerGUID() == joueur->GetGUID())
                    return marque;
        return nullptr;
    }

    class spell_papota_miroitement : public SpellScript
    {
        PrepareSpellScript(spell_papota_miroitement);

        void Transferer(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;
            Player* joueur = lanceur->ToPlayer();

            // TEMPS B — le retour : le temoin est encore la. La marque est
            // effacee, le temoin retire A LA MAIN (mode « annule », qui ne
            // declenche pas la recharge de l'expiration) ; la recharge de
            // ce lancer-ci, elle, suit son cours.
            if (joueur && joueur->HasAura(MIROIT_TEMOIN))
            {
                if (Creature* marque = MiroitementMarque(joueur))
                {
                    joueur->NearTeleportTo(marque->GetPositionX(),
                                           marque->GetPositionY(),
                                           marque->GetPositionZ(),
                                           joueur->GetOrientation());
                    marque->DespawnOrUnsummon();
                }
                joueur->RemoveAurasDueToSpell(MIROIT_TEMOIN);
                return;
            }

            // TEMPS A — l'aller : la marque reste au point de depart, le
            // mage file dans la direction des touches, et la recharge est
            // RETIREE (le coeur l'a posee avant les effets).
            if (joueur)
                joueur->SummonCreature(MIROIT_MARQUE, *joueur,
                    TEMPSUMMON_TIMED_DESPAWN, MIROIT_FENETRE + 500);
            Position destination = lanceur->GetPosition();
            lanceur->MovePositionToFirstCollision(destination, MIROIT_DISTANCE,
                                                  AngleDeplacement(lanceur));
            lanceur->NearTeleportTo(destination.GetPositionX(),
                                    destination.GetPositionY(),
                                    destination.GetPositionZ(),
                                    lanceur->GetOrientation());
            if (joueur)
            {
                joueur->CastSpell(joueur, MIROIT_TEMOIN, true);
                joueur->RemoveSpellCooldown(MIROITEMENT, true);
            }
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_miroitement::Transferer,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // Le temoin : a son EXPIRATION seulement (pas quand le retour le
    // retire), la marque tombe et la recharge part — le retour n'est plus
    // possible, le prochain lancer sera un aller.
    class spell_papota_miroitement_temoin : public AuraScript
    {
        PrepareAuraScript(spell_papota_miroitement_temoin);

        void Expirer(AuraEffect const* /*effet*/,
                     AuraEffectHandleModes /*mode*/)
        {
            if (GetTargetApplication()->GetRemoveMode()
                != AURA_REMOVE_BY_EXPIRE)
                return;
            Player* joueur = GetTarget()->ToPlayer();
            if (!joueur)
                return;
            if (Creature* marque = MiroitementMarque(joueur))
                marque->DespawnOrUnsummon();
            joueur->AddSpellCooldown(MIROITEMENT, 0, MIROIT_RECHARGE, true);
            // Le paquet au client (2026-08-31, « n'affiche pas son CD ») :
            // le drapeau needSendToClient d'AddSpellCooldown ne fait que
            // MARQUER l'entree — il n'envoie rien. Sans ce paquet, le
            // serveur refuse le sort mais l'icone reste allumee.
            WorldPacket paquet(SMSG_SPELL_COOLDOWN, 8 + 1 + 4 + 4);
            paquet << joueur->GetGUID();
            paquet << uint8(SPELL_COOLDOWN_FLAG_NONE);
            paquet << uint32(MIROITEMENT);
            paquet << uint32(MIROIT_RECHARGE);
            joueur->SendDirectMessage(&paquet);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_papota_miroitement_temoin::Expirer, EFFECT_0,
                SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Bourrasque — le bond directionnel
    // =======================================================================
    class spell_papota_bond_directionnel : public SpellScript
    {
        PrepareSpellScript(spell_papota_bond_directionnel);

        void Bondir(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;
            // La Bourrasque du chaman NE FAIT PAS PIVOTER le personnage
            // (2026-09-02) : le vent le pousse, il ne se retourne pas. Et il
            // porte DEUX FOIS PLUS LOIN qu'un bond ordinaire.
            bool const bourrasque = m_scriptSpellId == BOURRASQUE;
            float const distance = bourrasque
                ? BOND_DISTANCE * BOURRASQUE_FACTEUR : BOND_DISTANCE;
            float const vitesse = bourrasque
                ? BOND_VITESSE * BOURRASQUE_VITESSE : BOND_VITESSE;
            BondirVers(lanceur, AngleDeplacement(lanceur), distance,
                       bourrasque, vitesse);
        }

        void Register() override
        {
            // DUMMY, et non JUMP_DEST (corrige le 2026-08-30, « ne fait
            // rien » constate en jeu) : l'EffectJumpDest PAR DEFAUT du coeur
            // s'executait APRES le crochet et re-sautait SUR PLACE (la
            // destination du sort est le lanceur), ecrasant le saut
            // directionnel du script. Le DUMMY n'a aucun comportement par
            // defaut — le patron du Shunpo. Les DBC des trois sorts lies
            // (8600000/60/70) portent E_DUMMY en face.
            OnEffectLaunch += SpellEffectFn(spell_papota_bond_directionnel::Bondir,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Orbe des arcanes — le vrai orbe voyageur (refonte du 2026-08-30)
    // =======================================================================
    // Le sort invoque une creature habillee du modele de l'orbe (802103,
    // gen_visuel_mage) qui file droit devant sur 40 m ; son IA frappe chaque
    // ennemi croise UNE fois — livraison EXPLICITE (patron des Frappes
    // fauchantes : affichage garanti, pas de double mitigation) au nom du
    // sort 8600071, avec le son d'impact exporte (kit 30033) sur la victime.
    class spell_papota_orbe_arcanes : public SpellScript
    {
        PrepareSpellScript(spell_papota_orbe_arcanes);

        void Envoyer(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;
            // Filet de securite LARGE : le frein sur cible etire le vol —
            // la vraie fin est l'arrivee (Decay puis despawn, l'IA).
            lanceur->SummonCreature(ORBE_CREATURE, *lanceur,
                TEMPSUMMON_TIMED_DESPAWN, 30000);
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_orbe_arcanes::Envoyer,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    struct npc_papota_orbe_arcanes : public ScriptedAI
    {
        npc_papota_orbe_arcanes(Creature* c) : ScriptedAI(c)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void IsSummonedBy(WorldObject* invocateur) override
        {
            if (invocateur)
                proprietaire = invocateur->GetGUID();
            // Depart IMMEDIAT (Stand fond dans Hold). Tout droit, SANS
            // suivre le relief (generatePath false) : un orbe file en
            // ligne, arrete au premier obstacle. La destination est figee
            // ICI : les changements d'allure (frein) reposent le MovePoint
            // vers le MEME point.
            destination = me->GetPosition();
            me->MovePositionToFirstCollision(destination, ORBE_PORTEE, 0.0f);
            me->SetWalk(false);
            Avancer(ORBE_VITESSE);
        }

        void Avancer(float vitesse)
        {
            me->GetMotionMaster()->MovePoint(1, destination,
                FORCED_MOVEMENT_NONE, vitesse, false);
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            // L'inform peut REFEU au retrait du generateur pendant le
            // despawn — Decay jouait deux fois (constate le 2026-08-30) :
            // la garde le limite a UNE.
            if (type != POINT_MOTION_TYPE || id != 1 || decayJoue)
                return;
            decayJoue = true;
            me->HandleEmoteCommand(ORBE_EMOTE_DECAY);
            me->DespawnOrUnsummon(Milliseconds(ORBE_DECAY));
        }

        void UpdateAI(uint32 diff) override
        {
            if (decayJoue)
                return;
            minuterie += diff;
            if (minuterie < ORBE_TIC)
                return;
            attente += minuterie;
            minuterie = 0;
            Unit* mage = ObjectAccessor::GetUnit(*me, proprietaire);
            if (!mage)
            {
                me->DespawnOrUnsummon();
                return;
            }
            std::list<Unit*> proches;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(me, mage,
                                                             ORBE_RAYON);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chercheur(me, proches, verif);
            Cell::VisitObjects(me, chercheur, ORBE_RAYON);

            // Le frein drastique, reactif (toutes les ORBE_TIC ms) : tant
            // qu'une cible est dans le rayon, l'orbe rampe ; il repart des
            // qu'il est seul.
            bool freine = !proches.empty();
            if (freine != auRalenti)
            {
                auRalenti = freine;
                Avancer(freine ? ORBE_VITESSE_LENTE : ORBE_VITESSE);
            }

            // Les degats, eux, tombent TOUTES LES SECONDES sur ce qui est
            // dans le rayon (plus de « une frappe par ennemi », refonte du
            // 2026-08-30).
            if (attente < 1000)
                return;
            attente = 0;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(8600071);
            if (!info)
                return;
            for (Unit* victime : proches)
            {
                // Le CRITIQUE (2026-08-31) : le patron du coeur
                // (Spell::DoAllEffectOnTarget) — chance portee puis subie,
                // tirage, et CalculateSpellDamageTaken qui applique le
                // bonus critique, la resistance et l'absorption. Le sort
                // 8600071 porte classe_degats=1 (magie) : sans lui, la
                // chance resterait a zero quoi qu'on tire.
                // skipEffectCheck = VRAI : sans lui la chance est rendue a
                // ZERO (constate en jeu le 2026-08-31) — SpellInfo::
                // ComputeIsCritCapable ne declare « capable de critique »
                // qu'un sort portant un effet de degats ou de soin, et le
                // notre n'a qu'un DUMMY (les degats viennent de l'IA).
                float chance = mage->SpellDoneCritChance(victime, info,
                    SPELL_SCHOOL_MASK_ARCANE, BASE_ATTACK, true);
                chance = victime->SpellTakenCritChance(mage, info,
                    SPELL_SCHOOL_MASK_ARCANE, chance, BASE_ATTACK, true);
                bool critique = roll_chance_f(std::max(0.0f, chance));

                SpellNonMeleeDamage frappe(mage, victime, info,
                                           SPELL_SCHOOL_MASK_ARCANE);
                mage->CalculateSpellDamageTaken(&frappe, ORBE_DEGATS, info,
                                                BASE_ATTACK, critique);
                Unit::DealDamageMods(frappe.target, frappe.damage,
                                     &frappe.absorb);
                mage->SendSpellNonMeleeDamageLog(&frappe);
                mage->DealSpellDamage(&frappe, true);
                victime->SendPlaySpellVisual(ORBE_KIT_IMPACT);
            }
        }

        Position destination;
        ObjectGuid proprietaire;
        bool auRalenti = false;
        bool decayJoue = false;
        uint32 minuterie = 0;
        uint32 attente = 0;
    };

    // (Le cout scripte du Meteore — 15 % du mana MAXIMUM — a ete retire le
    // 2026-08-31 : le cout doit s'AFFICHER dans l'infobulle comme celui de
    // n'importe quel sort, ce que seul un ManaCost fixe permet. Le sort
    // porte donc 905 points en DBC. Rappel de l'acquis : ManaCostPct est un
    // pourcentage du mana de BASE, jamais du total.)

    // =======================================================================
    // Rayon de givre — la canalisation qui monte en puissance
    // =======================================================================
    // Remplace la Pluie de cometes (2026-08-30). Les degats du tic valent
    // base x numero du tic : 100, 200, 300... sur les 5 s de canalisation.
    class spell_papota_rayon_givre : public AuraScript
    {
        PrepareAuraScript(spell_papota_rayon_givre);

        void Croitre(AuraEffect* effet)
        {
            effet->SetAmount((effet->GetBaseAmount() + 1)
                             * int32(effet->GetTickNumber()));
        }

        void Register() override
        {
            OnEffectUpdatePeriodic += AuraEffectUpdatePeriodicFn(
                spell_papota_rayon_givre::Croitre, EFFECT_0,
                SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Dash fumee — disparaitre ici, reapparaitre au point vise
    // =======================================================================
    // Seul des cinq deplacements a ne PAS suivre la regle de direction : on
    // vise un point. Le sort porte une cible au sol, le client montre son
    // cercle de visee. L'effet est un DUMMY a destination : aucun
    // comportement par defaut, et sans champ Speed, OnEffectHit part au clic.
    // Baptise « Shunpo » par l'utilisateur le 2026-08-30.
    // LA TRANSLATION DU VOLEUR, en fonction libre : la Charge sauvage du
    // druide en forme de felin la rejoue a l'identique.
    void TranslationVoleur(Unit* lanceur, WorldLocation const* but)
    {
        if (!lanceur || !but)
            return;
        // 2. le dummy invisible au point vise — il ne vit que le dash.
        // Son ORIENTATION est celle du lanceur au clic : la destination
        // d'une teleportation porte l'orientation de la CIBLE, c'est
        // donc elle qui decide du regard a l'atterrissage (exigence du
        // 2026-08-30 : garder l'orientation de lancement).
        Position ou(but->GetPositionX(), but->GetPositionY(),
                    but->GetPositionZ(), lanceur->GetOrientation());
        Creature* dummy = lanceur->SummonCreature(DASH_DUMMY, ou,
            TEMPSUMMON_TIMED_DESPAWN, DASH_MARGE + 1500);
        if (!dummy)
            return;

        // 3. la fumee, 4. l'invisibilite et l'intouchabilite : TOUT DE
        // SUITE, dans le meme lot de paquets — le personnage disparait
        // sur place. « Comme s'il n'etait plus sur la carte » (exigence
        // du 2026-08-29) : inciblable et ignore par les sorts — zones
        // comprises — des joueurs ET des PNJ. Le combat en cours n'est
        // volontairement PAS coupe : un vrai retrait de carte ferait
        // evade/reset les mobs.
        lanceur->SendPlaySpellVisual(DASH_FUMEE_KIT);
        lanceur->SetDisplayId(DASH_INVISIBLE);
        lanceur->SetUnitFlag(UnitFlags(UNIT_FLAG_NOT_SELECTABLE
            | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));

        // 5. la teleportation : la copie de Pas de l'ombre, lancee en
        // declenche sur le dummy — le coeur pose le joueur derriere lui,
        // instantanement, sans spline ni plafond ni acquittement.
        lanceur->CastSpell(dummy, DASH_PAS, true);

        // 6. la fumee sur le dummy et 7. la reapparition : DASH_MARGE
        // plus tard, le temps que le client ait integre la teleportation.
        ObjectGuid guidJoueur = lanceur->GetGUID();
        ObjectGuid guidDummy = dummy->GetGUID();
        lanceur->m_Events.AddEventAtOffset([guidJoueur, guidDummy]()
        {
            Player* j = ObjectAccessor::FindPlayer(guidJoueur);
            if (!j)
                return;
            if (Creature* d = ObjectAccessor::GetCreature(*j, guidDummy))
                d->SendPlaySpellVisual(DASH_FUMEE_KIT);
            j->RestoreDisplayId();
            j->RemoveUnitFlag(UnitFlags(UNIT_FLAG_NOT_SELECTABLE
                | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        }, Milliseconds(DASH_MARGE));
    }

    class spell_papota_shunpo : public SpellScript
    {
        PrepareSpellScript(spell_papota_shunpo);

        void Foncer(SpellEffIndex /*index*/)
        {
            TranslationVoleur(GetCaster(), GetExplTargetDest());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_shunpo::Foncer,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Destrier divin — l'apparence d'une monture, sans en etre une
    // =======================================================================
    // Poser l'aura 78 en faisait une VRAIE monture, avec tout ce que cela
    // entraine. Le sort voulu est un bonus de vitesse ; seule l'apparence
    // manquait. `Unit::Mount` pose l'apparence directement, sans passer par
    // l'aura : le joueur est en selle a l'ecran et reste a pied pour le coeur.
    class spell_papota_destrier_divin : public AuraScript
    {
        PrepareAuraScript(spell_papota_destrier_divin);

        // On ecrit le champ d'apparence A LA MAIN plutot que d'appeler
        // `Unit::Mount`, qui pose aussi UNIT_FLAG_MOUNT. Ce drapeau fait basculer
        // le personnage en vitesse MONTEE, et l'aura de vitesse au sol cesse
        // alors de s'appliquer : le joueur avait le destrier et plus le bonus.
        void Monter(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            if (Unit* cible = GetTarget())
                cible->SetUInt32Value(UNIT_FIELD_MOUNTDISPLAYID, DESTRIER_ASPECT);
        }

        void Descendre(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            if (Unit* cible = GetTarget())
                cible->SetUInt32Value(UNIT_FIELD_MOUNTDISPLAYID, 0);
        }

        void Register() override
        {
            OnEffectApply += AuraEffectApplyFn(spell_papota_destrier_divin::Monter,
                                               EFFECT_0, SPELL_AURA_MOD_INCREASE_SPEED,
                                               AURA_EFFECT_HANDLE_REAL);
            OnEffectRemove += AuraEffectRemoveFn(spell_papota_destrier_divin::Descendre,
                                                 EFFECT_0, SPELL_AURA_MOD_INCREASE_SPEED,
                                                 AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Barriere de bouclier — l'absorption se paie en rage
    // =======================================================================
    // Le montant d'une absorption ne se corrige PAS par SetHitDamage — la
    // premiere version le faisait, et la rage se vidait pour un bouclier
    // inchange. Le montant d'une aura se decide dans DoEffectCalcAmount ; la
    // rage se vide ensuite, a l'application, une fois le calcul rendu.
    class spell_papota_barriere_bouclier : public AuraScript
    {
        PrepareAuraScript(spell_papota_barriere_bouclier);

        void Calculer(AuraEffect const* /*effet*/, int32& montant, bool& /*fixe*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;
            // 1 point d'absorption par point de RAGE AFFICHEE (arithmetique
            // de l'utilisateur, 2026-08-30 : 100 rage -> +100). Le bogue
            // corrige ici : GetPower(POWER_RAGE) rend des DIXIEMES (100
            // affiches = 1000), l'ancien x6 valait donc x60 par point
            // affiche — 7500 constates au lieu de 900.
            float blocage = 0.0f;
            if (Player* joueur = lanceur->ToPlayer())
                blocage = float(joueur->GetShieldBlockValue());
            // La rage comptee est celle qu'on AVAIT au lancement : le cout
            // du sort (ManaCost 200 = 20 rage, memes unites internes que
            // GetPower) est debite AVANT le calcul de l'aura — les 887 au
            // lieu de 900 constates le 2026-08-30 etaient 80 restants x le
            // facteur de blocage. On le reintegre.
            int32 rage = lanceur->GetPower(POWER_RAGE)
                + int32(GetSpellInfo()->ManaCost);
            // L'EQUATION arretee par l'utilisateur (2026-08-30, troisieme
            // forme — elle remplace les ratios additifs du meme jour) :
            //   montant = base + (rage / 100) x (blocage x 5 + armure x 0,075)
            // (ratio de blocage 7 -> 5 le 2026-08-30). Cas de controle
            // fournis pour la forme x7 : blocage 435, armure 40000 ->
            // 6845 a 100 rage, 3822 a 50 rage (troncature entiere). La
            // decomposition est GARDEE en membres : l'annonce du chat la
            // detaille, et la calculer deux fois finirait par diverger.
            scoreBlocage = int32(blocage);
            partBlocage = int32(5.0f * blocage);
            armure = int32(lanceur->GetArmor());
            partArmure = int32(0.075f * float(armure));
            ragePct = rage / 10;    // dixiemes internes -> points affiches
            majoration = int32(float(partBlocage + partArmure)
                               * float(ragePct) / 100.0f);
            montant += majoration;
        }

        void Vider(AuraEffect const* effet, AuraEffectHandleModes /*mode*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;
            lanceur->SetPower(POWER_RAGE, 0);
            // Le montant EXACT dans le chat (demande du 2026-08-30) : les
            // infobulles de 3.3.5 sont calculees par le CLIENT depuis son
            // DBC — un montant dynamique ne peut pas s'y afficher. La
            // convention du module : les gains s'annoncent dans le chat.
            if (Player* joueur = lanceur->ToPlayer())
            {
                // Formatage fmt (« {} ») : le PSendSysMessage de ce coeur ne
                // parle PAS printf — un %d y reste litteral (constate en jeu
                // le 2026-08-30). Le DETAIL des points (demande du meme
                // jour) suit l'equation — la base est le RELIQUAT du total,
                // la somme affichee boucle donc toujours.
                int32 base = effet->GetAmount() - majoration;
                ChatHandler(joueur->GetSession()).PSendSysMessage(
                    "Bouclier Spartiate : {} points de degats absorbes "
                    "({} de base + {} de majoration = ({} de blocage "
                    "({} x 5) + {} d'armure ({} x 0.075)) x {}% de rage).",
                    effet->GetAmount(), base, majoration,
                    partBlocage, scoreBlocage, partArmure, armure, ragePct);
            }
        }

        int32 ragePct = 0;
        int32 scoreBlocage = 0;
        int32 partBlocage = 0;
        int32 armure = 0;
        int32 partArmure = 0;
        int32 majoration = 0;

        void Register() override
        {
            DoEffectCalcAmount += AuraEffectCalcAmountFn(spell_papota_barriere_bouclier::Calculer,
                                                         EFFECT_0, SPELL_AURA_SCHOOL_ABSORB);
            AfterEffectApply += AuraEffectApplyFn(spell_papota_barriere_bouclier::Vider,
                                                  EFFECT_0, SPELL_AURA_SCHOOL_ABSORB,
                                                  AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Frappes fauchantes — chaque coup en fauche un second
    // =======================================================================
    // Choix utilisateur du 2026-08-30 (remplace Fracasse-colosse, « pas
    // fun »), avec sa variante : sans cible secondaire a portee, la cible
    // unique est frappee DEUX fois. Le proc vient du DBC (ProcTypeMask
    // melee, autos + techniques) ; le script recoit les degats REELS du
    // coup (ProcEventInfo) et les rejoue par la frappe fauchee (8600055,
    // jamais apprise) sur un second ennemi proche de la victime — ou sur la
    // victime elle-meme. Garde anti-recursion : la frappe fauchee ne
    // fauche jamais.
    constexpr uint32 FRAPPE_FAUCHEE = 8600055;
    constexpr float FAUCHAGE_PORTEE = 8.0f;

    class spell_papota_frappes_fauchantes : public AuraScript
    {
        PrepareAuraScript(spell_papota_frappes_fauchantes);

        void Faucher(AuraEffect const* /*effet*/, ProcEventInfo& infos)
        {
            Unit* guerrier = GetTarget();
            DamageInfo* coup = infos.GetDamageInfo();
            if (!guerrier || !coup || !coup->GetDamage())
                return;
            if (infos.GetSpellInfo()
                && infos.GetSpellInfo()->Id == FRAPPE_FAUCHEE)
                return;
            Unit* victime = coup->GetVictim();
            if (!victime)
                return;

            Unit* seconde = nullptr;
            std::list<Unit*> proches;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(victime, guerrier,
                                                             FAUCHAGE_PORTEE);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chercheur(victime, proches, verif);
            // Ce coeur expose Cell::VisitObjects (pas VisitAllObjects).
            Cell::VisitObjects(victime, chercheur, FAUCHAGE_PORTEE);
            for (Unit* u : proches)
                if (u != victime && guerrier->IsValidAttackTarget(u))
                {
                    seconde = u;
                    break;
                }

            // Livraison EXPLICITE (2026-08-30) : le CastCustomSpell en sort
            // de degats n'affichait RIEN au joueur (constate en jeu) et
            // remitigeait l'echo par l'armure — double mitigation. Ici, le
            // paquet de log est envoye soi-meme et le montant est EXACTEMENT
            // celui du coup d'origine, deja mitige une fois.
            SpellInfo const* info = sSpellMgr->GetSpellInfo(FRAPPE_FAUCHEE);
            if (!info)
                return;
            Unit* cible = seconde ? seconde : victime;
            SpellNonMeleeDamage frappe(guerrier, cible, info,
                                       SPELL_SCHOOL_MASK_NORMAL);
            frappe.damage = coup->GetDamage();
            guerrier->SendSpellNonMeleeDamageLog(&frappe);
            guerrier->DealSpellDamage(&frappe, false);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_papota_frappes_fauchantes::Faucher,
                                             EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // =======================================================================
    // Marche spectrale — deux portes, et le pas de l'une a l'autre
    // =======================================================================
    // Refonte du 2026-09-01 : une PAIRE de portes posee d'UN SEUL LANCER,
    // qui tiennent 45 s chacune. Un clic droit sur l'une transporte a
    // l'autre : la porte franchie s'efface, celle d'en face gagne 45 s de
    // plus. Un lancer pose DEUX portes si aucune n'est debout, UNE SEULE
    // sinon.
    //
    // POURQUOI « ICI ET LA-BAS » : le client de 3.3.5 n'ouvre son reticule
    // que sur une pression de touche, et rien dans le protocole ne permet au
    // serveur de lui en commander un second. Un lancer ne peut donc designer
    // qu'UNE position ; l'autre porte se dresse aux pieds du chevalier.
    constexpr uint32 PORTE_OBJET = 803820;   // les deux portes, memes objets
    constexpr uint32 PORTE_VIE = 45;         // s — SummonGameObject compte
                                             // en secondes, pas en ms
    constexpr float PORTE_FOUILLE = 100.0f;  // m — de quoi retrouver la paire

    // Qui VOIT et qui FRANCHIT une porte : le chevalier et LES SIENS
    // (2026-09-01). « Son groupe, pas son raid » : en groupe ordinaire tout
    // le monde est du meme sous-groupe et passe ; en raid, seul son
    // sous-groupe a lui — les autres raiders restent dehors.
    bool PorteDuMemeGroupe(Player const* joueur, ObjectGuid chevalier)
    {
        if (!joueur || !chevalier)
            return false;
        if (joueur->GetGUID() == chevalier)
            return true;
        Group const* groupe = joueur->GetGroup();
        if (!groupe || !groupe->IsMember(chevalier))
            return false;
        return groupe->SameSubGroup(joueur->GetGUID(), chevalier);
    }

    // L'IA de la porte tient le nom de son chevalier — et NON le champ
    // « proprietaire » de l'objet. Un objet QUI A UN PROPRIETAIRE est
    // toujours visible pour qui lui est ami (GameObject::IsAlwaysVisibleFor,
    // consulte AVANT tout crochet) : garder ce champ rendrait le filtre de
    // visibilite inoperant pour les allies. Le lien passe donc par le canal
    // prevu a cet usage, SetGUID/GetGUID.
    struct go_papota_porte_ia : public GameObjectAI
    {
        explicit go_papota_porte_ia(GameObject* go) : GameObjectAI(go) { }

        void SetGUID(ObjectGuid const& guid, int32 /*id*/) override
        {
            _chevalier = guid;
        }

        ObjectGuid GetGUID(int32 /*id*/) const override { return _chevalier; }

        // Hors du groupe, la porte n'existe pas : le coeur consulte ce
        // crochet a chaque mise a jour de visibilite. Tant que la porte
        // n'est pas marquee, personne ne la voit — c'est ce qui evite
        // qu'elle apparaisse a tous le temps d'un battement.
        bool CanBeSeen(Player const* regardeur) override
        {
            return PorteDuMemeGroupe(regardeur, _chevalier);
        }

        bool GossipHello(Player* joueur, bool reportUse) override;

    private:
        ObjectGuid _chevalier;
    };

    // Les portes d'UN chevalier donne. Le coeur ne tient pas de liste
    // accessible des objets qu'un joueur a poses : on fouille la grille
    // autour d'un point de repere et on garde les siennes.
    void PortesDe(WorldObject* autour, ObjectGuid chevalier,
                  std::list<GameObject*>& portes)
    {
        autour->GetGameObjectListWithEntryInGrid(portes, PORTE_OBJET,
                                                 PORTE_FOUILLE);
        portes.remove_if([chevalier](GameObject* porte)
        {
            return !porte || !porte->AI()
                || porte->AI()->GetGUID(0) != chevalier;
        });
    }

    // LE PASSAGE : franchir une porte transporte a l'autre ; celle qu'on
    // franchit s'efface, celle d'arrivee gagne 45 s sur ce qu'il lui reste.
    bool go_papota_porte_ia::GossipHello(Player* joueur, bool /*reportUse*/)
    {
        // Rendre « traite » dans tous les cas : sans cela le coeur
        // enchainerait sur le sort inscrit dans le gabarit.
        if (!PorteDuMemeGroupe(joueur, _chevalier))
            return true;

        std::list<GameObject*> portes;
        PortesDe(me, _chevalier, portes);
        GameObject* autre = nullptr;
        for (GameObject* candidate : portes)
            if (candidate != me)
            {
                autre = candidate;
                break;
            }
        if (!autre)
            return true;      // une porte seule ne mene nulle part

        time_t const reste = autre->GetRespawnTime()
            - GameTime::GetGameTime().count();
        autre->SetRespawnTime(int32(std::max<time_t>(0, reste) + PORTE_VIE));
        joueur->NearTeleportTo(autre->GetPositionX(), autre->GetPositionY(),
                               autre->GetPositionZ(), joueur->GetOrientation());
        // Delete() n'efface pas sur-le-champ : l'objet part a la liste de
        // retrait du monde, on peut donc s'en defaire d'ici.
        me->Delete();
        return true;
    }

    // Une porte posee. Le champ « proprietaire » est LACHE aussitot (voir
    // plus haut), le lien passant par l'IA ; la visibilite est rafraichie
    // dans la foulee, le marquage venant apres l'entree dans le monde.
    void PortePoser(Player* dk, float x, float y, float z)
    {
        GameObject* porte = dk->SummonGameObject(PORTE_OBJET, x, y, z,
            dk->GetOrientation(), 0.0f, 0.0f, 0.0f, 0.0f, PORTE_VIE);
        if (!porte)
            return;
        dk->RemoveGameObject(porte, false);
        if (porte->AI())
            porte->AI()->SetGUID(dk->GetGUID(), 0);
        porte->UpdateObjectVisibility(true);
    }

    class spell_papota_porte : public SpellScript
    {
        PrepareSpellScript(spell_papota_porte);

        void Poser(SpellEffIndex /*index*/)
        {
            Player* dk = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            WorldLocation const* but = GetExplTargetDest();
            if (!dk || !but)
                return;

            // Ce qui est deja debout decide du compte : aucune porte, et le
            // chevalier en pose DEUX — celle-ci et une a ses pieds ; une au
            // moins, et celle du reticule est la seule (2026-09-01).
            std::list<GameObject*> debout;
            PortesDe(dk, dk->GetGUID(), debout);

            PortePoser(dk, but->GetPositionX(), but->GetPositionY(),
                       but->GetPositionZ());
            if (!debout.empty())
                return;
            PortePoser(dk, dk->GetPositionX(), dk->GetPositionY(),
                       dk->GetPositionZ());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_porte::Poser,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // Le gabarit de la porte ne porte plus que cette IA : c'est elle qui
    // filtre la vue et traite le clic.
    class go_papota_porte : public GameObjectScript
    {
    public:
        go_papota_porte() : GameObjectScript("go_papota_porte") { }

        GameObjectAI* GetAI(GameObject* porte) const override
        {
            return new go_papota_porte_ia(porte);
        }
    };

    // =======================================================================
    // Ruee ardente — la vitesse se paie en fraction de la vie
    // =======================================================================
    // Des degats fixes etaient negligeables a haut niveau et mortels a bas
    // niveau. La ruee prend 2 % des PV max par seconde et s'eteint d'elle-meme
    // sous 10 % : elle ne tue jamais son porteur.
    // LA BASCULE : relancer la ruee l'annule. Le SpellScript intercepte le
    // lancement, retire l'aura si elle est la et interrompt le sort sans
    // message d'erreur — ni cout ni temps de recharge, la ruee n'en a pas.
    constexpr uint32 RUEE_ARDENTE = 8600080;
    // ---------------------------------------------------------------------
    // Cataclysme (8600083) — refonte du 2026-09-03
    // ---------------------------------------------------------------------
    // Le DBC porte tout ce qu'il peut : les degats, le +10 % de degats sur 12 s,
    // le fragment d'ame en reactif, et l'aura a deux charges qui rend le Feu de
    // l'ame et le Trait du Chaos instantanes (un ADD_PCT_MODIFIER cible sur la
    // famille du demoniste, que le coeur consomme tout seul).
    //
    // Restent deux choses hors de sa portee : propager l'IMMOLATION au meilleur
    // rang que le demoniste connaisse — il faut lire son grimoire —, et poser
    // l'aura de charges, qui n'est pas un effet du sort mais un sort a part.
    constexpr uint32 CATACLYSME_HATE = 8610012;
    constexpr uint32 IMMOLATION_MASQUE = 0x4;   // famille demoniste, mot 0

    // Meme procede que AscendanceMeilleurRang et DesespoirMeilleurRang : le
    // rang le plus haut que le joueur porte ACTIVEMENT, et non un rang fixe
    // qui deviendrait faux a chaque rune de progression.
    uint32 CataclysmeMeilleurRang(Player* demoniste, uint8 mot, uint32 masque)
    {
        uint32 meilleur = 0;
        uint32 niveauMeilleur = 0;
        for (auto const& paire : demoniste->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_WARLOCK)
                continue;
            if (!(info->SpellFamilyFlags[mot] & masque))
                continue;
            uint32 niveau = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!meilleur || niveau > niveauMeilleur)
            {
                meilleur = info->Id;
                niveauMeilleur = niveau;
            }
        }
        return meilleur;
    }

    class spell_papota_cataclysme : public SpellScript
    {
        PrepareSpellScript(spell_papota_cataclysme);

        void Fendre(SpellEffIndex index)
        {
            Player* demoniste = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            Unit* cible = GetHitUnit();
            if (!demoniste || !cible)
                return;

            // L'IMMOLATION autour de la CIBLE, pas autour du demoniste : le
            // rayon est celui du troisieme effet, celui qui porte ce script.
            uint32 const immolation = CataclysmeMeilleurRang(
                demoniste, 0, IMMOLATION_MASQUE);
            if (immolation)
            {
                float const rayon =
                    GetSpellInfo()->Effects[index].CalcRadius(demoniste);
                std::list<Unit*> proies;
                Acore::AnyUnfriendlyUnitInObjectRangeCheck test(cible, demoniste,
                                                                rayon);
                Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                    chercheur(cible, proies, test);
                // Ce coeur expose Cell::VisitObjects (pas VisitAllObjects).
                Cell::VisitObjects(cible, chercheur, rayon);
                for (Unit* proie : proies)
                    if (proie->IsAlive() && demoniste->IsValidAttackTarget(proie))
                        demoniste->CastSpell(proie, immolation, true);
            }

            // Les deux incantations instantanees : une aura a CHARGES, que le
            // coeur decompte lui-meme a chaque Feu de l'ame ou Trait du Chaos.
            demoniste->CastSpell(demoniste, CATACLYSME_HATE, true);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_papota_cataclysme::Fendre,
                                               EFFECT_2, SPELL_EFFECT_DUMMY);
        }
    };

    // PLUS DE PLANCHER (2026-09-03) : la ruee brule jusqu'au bout. Elle ne
    // s'arrete que devant la mort, et refuse de partir a 16 % ou moins.
    constexpr uint32 RUEE_SEUIL_LANCEMENT = 16;  // % des PV max : il en faut PLUS

    class spell_papota_ruee_ardente : public SpellScript
    {
        PrepareSpellScript(spell_papota_ruee_ardente);

        SpellCastResult Basculer()
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return SPELL_CAST_OK;
            // Deja active : on l'eteint, sans message ni cout.
            if (lanceur->HasAura(RUEE_ARDENTE, lanceur->GetGUID()))
            {
                lanceur->RemoveAurasDueToSpell(RUEE_ARDENTE);
                return SPELL_FAILED_DONT_REPORT;
            }
            // Trop bas pour partir : il faut PLUS de 16 % des PV max, donc
            // 16 % pile est refuse (« ne peut pas etre lance si le joueur a
            // 16 % ou moins »).
            if (lanceur->GetHealthPct() <= float(RUEE_SEUIL_LANCEMENT))
            {
                SetCustomCastResultMessage(SPELL_CUSTOM_ERROR_NOT_ENOUGH_HEALTH);
                return SPELL_FAILED_CUSTOM_ERROR;
            }
            return SPELL_CAST_OK;
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_papota_ruee_ardente::Basculer);
        }
    };

    class spell_papota_ruee_ardente_aura : public AuraScript
    {
        PrepareAuraScript(spell_papota_ruee_ardente_aura);

        void Bruler(AuraEffect const* effet)
        {
            PreventDefaultAction();
            Unit* cible = GetTarget();
            if (!cible)
                return;
            // SEULE LA MORT ARRETE LA RUEE (2026-09-03) : on regarde ce que le
            // battement FERAIT, et on ne s'arrete que s'il tuerait. Le plancher
            // a 10 % a ete retire — il stoppait la ruee des 25 % des PV max
            // (10 % de plancher + 15 % de morsure), bien trop tot.
            //
            // Comparaison directe, sans soustraction : « vie <= morsure » dit
            // que le battement amenerait a zero ou en dessous. L'ecrire
            // « vie - morsure <= 0 » deborderait par le bas en uint32 et
            // laisserait passer le coup fatal.
            uint32 const morsure = cible->CountPctFromMaxHealth(effet->GetAmount());
            if (cible->GetHealth() <= morsure)
            {
                Remove();
                return;
            }
            Unit::DealDamage(cible, cible, morsure, nullptr, SPELL_DIRECT_DAMAGE,
                             SPELL_SCHOOL_MASK_FIRE, GetSpellInfo(), false);
        }

        void Register() override
        {
            // FACTICE : voir sorts_classes.py — une aura de degats sur soi
            // serait forcement un malus, donc non annulable au clic droit.
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_papota_ruee_ardente_aura::Bruler,
                                                     EFFECT_1, SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Fleau des rois — la lame mord d'autant plus que la cible est empoisonnee
    // =======================================================================
    // L'infobulle promet une aggravation PAR POISON, pas par temps ecoule : la
    // premiere version majorait d'un dixieme a chaque battement, ce qui n'est
    // pas la meme chose et ne recompensait pas le meme jeu. Le Fleau des rois
    // paie le travail deja fait sur la cible, non la patience.
    //
    // `CallScriptEffectPeriodicHandlers` est appele AVANT le calcul des degats
    // du battement : ecrire le montant ici agit donc des ce battement-ci.
    class spell_papota_fleau_des_rois : public AuraScript
    {
        PrepareAuraScript(spell_papota_fleau_des_rois);

        // On compte les auras dont le type de dissipation est le poison — ce
        // que le client appelle « poison » dans ses propres infobulles — plutot
        // qu'une liste de sorts qu'il faudrait tenir a jour a chaque ajout.
        uint32 CompterPoisons(Unit const* cible) const
        {
            uint32 combien = 0;
            for (auto const& paire : cible->GetAppliedAuras())
            {
                Aura const* aura = paire.second->GetBase();
                if (!aura || aura->GetSpellInfo()->Id == GetSpellInfo()->Id)
                    continue;               // la lame ne se compte pas elle-meme
                if (aura->GetSpellInfo()->Dispel == DISPEL_POISON)
                    ++combien;
            }
            return combien;
        }

        void Aggraver(AuraEffect const* effet)
        {
            Unit const* cible = GetTarget();
            if (!cible)
                return;

            // La valeur de base se relit dans le sort. L'ecraser sans la relire
            // ferait cumuler l'aggravation sur elle-meme, et le poison
            // s'emballerait battement apres battement.
            int32 const base = GetSpellInfo()->Effects[EFFECT_1].CalcValue(GetCaster());
            uint32 const poisons = CompterPoisons(cible);
            int32 const montant = base + int32(base) * int32(poisons) / 4;

            if (AuraEffect* modifiable = const_cast<AuraEffect*>(effet))
                modifiable->SetAmount(montant);
        }

        void Register() override
        {
            // EFFECT_1, et non EFFECT_0 : le premier effet porte la frappe
            // initiale, le second le poison. Une liaison qui ne correspond pas
            // au DBC n'est pas une erreur de compilation — le coeur la refuse au
            // demarrage et le crochet ne s'execute jamais.
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_papota_fleau_des_rois::Aggraver,
                                                     EFFECT_1, SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Coup de des — les points de combo decident du tirage
    // =======================================================================
    // Une seule aura a piles ne disait rien de ce qu'elle apportait : on tire
    // parmi CINQ auras distinctes, chacune nommee et decrite. REFONTE du
    // 2026-08-30 : le sort DEPENSE les points de combo (1 a 5, en plus de
    // l'energie) et leur mise remplace le hasard du NOMBRE — 1 pt = 1
    // bienfait, 3 pts = 2, 5 pts = 3, duree de base 15 s ; les mises PAIRES
    // (2 pts = 1 bienfait, 4 pts = 2) DOUBLENT la duree (30 s). Seul le
    // CHOIX des bienfaits reste tire au sort. Les points de combo de 3.3.5
    // vivent sur la cible du voleur : le DBC reste un sort de soi, le script
    // les lit et les efface (CheckCast en exige au moins un).
    constexpr uint32 BIENFAITS[] = { 8600034, 8600035, 8600036, 8600037, 8600038 };
    constexpr int32 DES_DUREE_BASE = 15000;

    class spell_papota_coup_de_des : public SpellScript
    {
        PrepareSpellScript(spell_papota_coup_de_des);

        SpellCastResult Verifier()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur || !joueur->GetComboPoints())
                return SPELL_FAILED_NO_COMBO_POINTS;
            return SPELL_CAST_OK;
        }

        void Lancer()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur)
                return;

            uint8 const points = std::min<uint8>(joueur->GetComboPoints(), 5);
            if (!points)
                return;
            joueur->ClearComboPoints();

            uint32 const combien = (points + 1) / 2;         // 1,1,2,2,3
            int32 const duree = (points == 2 || points == 4)
                ? DES_DUREE_BASE * 2 : DES_DUREE_BASE;

            // On retire d'abord les bienfaits du tirage precedent : sans cela
            // les jets s'empileraient et le sort deviendrait un cumul, non un pari.
            for (uint32 id : BIENFAITS)
                joueur->RemoveAurasDueToSpell(id);

            std::vector<uint32> panier(std::begin(BIENFAITS), std::end(BIENFAITS));
            for (uint32 k = 0; k < combien && !panier.empty(); ++k)
            {
                uint32 const tire = urand(0, uint32(panier.size()) - 1);
                joueur->CastSpell(joueur, panier[tire], true);
                // La duree vient de la MISE, pas du DBC (15 s au DBC) : les
                // mises paires la doublent.
                if (Aura* aura = joueur->GetAura(panier[tire]))
                {
                    aura->SetMaxDuration(duree);
                    aura->SetDuration(duree);
                }
                panier.erase(panier.begin() + tire);   // jamais deux fois le meme
            }
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_papota_coup_de_des::Verifier);
            AfterCast += SpellCastFn(spell_papota_coup_de_des::Lancer);
        }
    };

    // =======================================================================
    // Halo — l'anneau s'ouvre, puis se referme
    // =======================================================================
    // Deux temps, autour de la POSITION DU LANCEUR AU MOMENT DU LANCER : le
    // pretre peut s'en aller ensuite, l'anneau reste ou il est ne. Chaque
    // temps est une creature habillee d'un des deux modeles rétroportes —
    // 803814 s'ouvre (cfx_priest_halo_cast02), 803815 se referme
    // (cfx_priest_halo_cast) — et une ONDE, c'est-a-dire les deux sorts
    // auxiliaires lances par le pretre au point d'ancrage. Deux sorts parce
    // qu'un sort n'a qu'un visuel : les ennemis doivent recevoir l'impact de
    // degats sacres, les allies celui du soin.
    constexpr uint32 HALO_ANNEAU_OUVRE = 803814;
    constexpr uint32 HALO_ANNEAU_FERME = 803815;
    constexpr uint32 HALO_ONDE_DEGATS = 8600044;
    constexpr uint32 HALO_ONDE_SOINS = 8600045;
    constexpr uint32 HALO_SECOND_TEMPS = 3000;   // ms — « apres 3 secondes »
    // Le Stand des deux modeles porte 3334 ms dans le fichier, mais en jeu
    // l'anneau avait fini sa course une seconde plus tot et repartait pour
    // une deuxieme lecture avant de disparaitre (constate le 2026-09-01) :
    // la vie d'un anneau est coupee d'autant. C'est aussi la duree sur
    // laquelle l'onde progresse — l'effet SUIT l'anneau.
    constexpr uint32 HALO_VIE = 2334;
    constexpr float HALO_RAYON = 30.0f;
    constexpr uint32 HALO_TIC = 33;              // ms — 30 fois par seconde

    // Un temps du halo : l'anneau parait. C'est SON IA qui fait passer
    // l'onde, au rythme ou il s'ouvre ou se referme. En fonction libre,
    // AddEventAtOffset exigeant une lambda rvalue (piege deja rencontre).
    void HaloTemps(ObjectGuid guidPretre, Position ou, uint32 anneau)
    {
        Player* pretre = ObjectAccessor::FindPlayer(guidPretre);
        if (!pretre || !pretre->IsInWorld())
            return;
        pretre->SummonCreature(anneau, ou, TEMPSUMMON_TIMED_DESPAWN, HALO_VIE);
    }

    class spell_papota_halo : public SpellScript
    {
        PrepareSpellScript(spell_papota_halo);

        void Deployer(SpellEffIndex /*index*/)
        {
            Player* pretre = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!pretre)
                return;
            // L'ANCRE : la position du pretre a cet instant, figee par
            // valeur. Tout ce qui suit s'y rapporte, ou qu'il aille.
            Position ou = pretre->GetPosition();
            ObjectGuid guid = pretre->GetGUID();
            HaloTemps(guid, ou, HALO_ANNEAU_OUVRE);
            pretre->m_Events.AddEventAtOffset([guid, ou]()
            {
                HaloTemps(guid, ou, HALO_ANNEAU_FERME);
            }, Milliseconds(HALO_SECOND_TEMPS));
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_halo::Deployer,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // L'anneau porte l'onde AVEC LUI (2026-09-01) : plus de zone frappee
    // d'un bloc, mais un front qui part du centre et gagne le bord quand
    // l'anneau s'ouvre, qui part du bord et revient au centre quand il se
    // referme. Chacun n'est touche qu'une fois par passage, a l'instant ou
    // le front l'atteint. C'est le pretre qui lance l'onde : les degats et
    // les soins lui reviennent, et les touches recoivent l'impact sacre du
    // sort auxiliaire — coup pour les ennemis, soin pour les allies.
    struct npc_papota_halo : public ScriptedAI
    {
        npc_papota_halo(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
            _ouvre = me->GetEntry() == HALO_ANNEAU_OUVRE;
        }

        void IsSummonedBy(WorldObject* invocateur) override
        {
            if (invocateur)
                _pretre = invocateur->GetGUID();
        }

        void UpdateAI(uint32 diff) override
        {
            _age += diff;
            _guet += diff;
            if (_guet < HALO_TIC)
                return;
            _guet = 0;
            Player* pretre = ObjectAccessor::FindPlayer(_pretre);
            if (!pretre)
                return;

            float const part = std::min(1.0f, float(_age) / float(HALO_VIE));
            float const front = _ouvre ? HALO_RAYON * part
                                       : HALO_RAYON * (1.0f - part);

            std::list<Unit*> ennemis;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(me, pretre,
                                                               HALO_RAYON);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chasse(me, ennemis, hostile);
            Cell::VisitObjects(me, chasse, HALO_RAYON);
            for (Unit* cible : ennemis)
                Toucher(pretre, cible, front, HALO_ONDE_DEGATS);

            std::list<Player*> allies;
            Acore::AnyPlayerInObjectRangeCheck amical(me, HALO_RAYON);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                cueille(me, allies, amical);
            Cell::VisitObjects(me, cueille, HALO_RAYON);
            for (Player* allie : allies)
                if (pretre->IsFriendlyTo(allie))
                    Toucher(pretre, allie, front, HALO_ONDE_SOINS);
        }

    private:
        void Toucher(Player* pretre, Unit* cible, float front, uint32 onde)
        {
            if (!cible->IsAlive() || _touches.count(cible->GetGUID()))
                return;
            float const d = me->GetDistance2d(cible);
            // Le front n'emporte que ce qu'il vient d'atteindre : ce qui est
            // devant lui quand il s'ouvre, derriere lui quand il revient.
            if (_ouvre ? d > front : d < front)
                return;
            _touches.insert(cible->GetGUID());
            // Le montant est celui du DBC, sans retouche : le dosage par la
            // distance du premier jet (creux au contact et au bord, plein a
            // mi-course) est RETIRE le 2026-09-01 — au centre il ramenait le
            // soin annonce a un quart, « le tooltip indique 700 et je ne
            // recois que 242 ».
            pretre->CastSpell(cible, onde, true);
        }

        ObjectGuid _pretre;
        GuidSet _touches;
        bool _ouvre = true;
        uint32 _age = 0;
        uint32 _guet = 0;
    };

    // =======================================================================
    // Apocalypse — les plaies eclatent, les morts se levent
    // =======================================================================
    // Refonte du 2026-09-02 : UNE GOULE PAR ENNEMI dans les 8 m autour de la
    // cible, deux au minimum, chacune levee AUX PIEDS de sa proie (les deux
    // du minimum sous la cible elle-meme). Elles vivent 16 s, frappent le
    // plus proche d'elles et majorent leurs coups de 12,5 % par maladie du
    // chevalier sur la victime.
    constexpr uint32 APOCALYPSE_VIE = 19000;     // ms (16 + 3, 2026-09-02)
    constexpr float APOCALYPSE_RAYON = 8.0f;     // m — autour de la cible
    constexpr uint32 APOCALYPSE_MINIMUM = 2;     // goules, quoi qu'il arrive
    constexpr uint32 APOCALYPSE_ECLABOUSSURE = 50;  // % du coup, aux voisins
    // La LEVEE : un sort porteur de visuel, lance par le chevalier sur
    // chaque goule. Son visuel 30054 ne porte que l'impact natif de
    // Reanimation morbide (kit 7775 : « Impact: Shadowbolt » et son 743).
    // Le paquet brut envoye a la creature ne rendait RIEN — le client n'a
    // pas encore la creature au tick de l'invocation (2026-09-02).
    constexpr uint32 APOCALYPSE_LEVEE = 8600048;
    // La goule S'EXTIRPE DU SOL : anim 127 « Birth », relevee dans
    // Creature\NorthrendGhoul (4166 ms) — ses os descendent a -2,23 yards
    // puis remontent, c'est bien la sortie de terre. « EmergeGround » (131),
    // essayee d'abord, ne bouge le modele que de 18 cm.
    //
    // (Coupee un temps le 2026-09-02 pour un diagnostic d'ombre, puis
    // RENDUE : l'artefact ne touche pas l'ombre des goules mais celle des
    // PNJ voisins, qui s'etire vers elles — une animation de goule n'y peut
    // rien.)
    constexpr uint32 GOULE_EMOTE_EMERGE = 990004;   // 0 pour la recouper
    constexpr uint32 GOULE_EMERGE_MS = 4166;
    // La marge du Shunpo : ni emote ni sort ne portent sur une creature que
    // le client n'a pas encore recue — c'est ce qui laissait les goules
    // « invoquees sans animations » (2026-09-02).
    constexpr uint32 GOULE_MARGE = 300;
    // Le bonus par maladie du chevalier sur la victime, en centiemes.
    constexpr uint32 GOULE_BONUS_MALADIE = 125;  // +12,5 %
    constexpr float GOULE_HATE = 25.0f;          // % — elles frappent d'autant
                                                 // plus vite (2026-09-02)
    constexpr uint32 GOULE_TIC = 500;            // ms — le guet du ciblage

    // Les maladies que LE CHEVALIER a posees sur une victime. Comptees par
    // type de dissipation, pas par liste de sorts : toute maladie compte.
    //
    // TROIS AU PLUS : Fievre de givre, Peste de sang et Peste d'ebene. (Le
    // filtre « degats periodiques », essaye le 2026-09-02 pour ecarter la
    // Peste d'ebene, est retire — elle compte bel et bien.)
    //
    // Ce qu'il faut ecarter, ce sont les auras TECHNIQUES. Le coupable
    // releve le 2026-09-02 : le sort 65142, « Crypt Fever -
    // SPELL_AURA_LINKED », que ce coeur ajoute lui-meme a la table des
    // sorts — la charge utile que la Fievre cadaverique accroche a ses
    // victimes pour majorer les degats de maladie. Il porte le meme type de
    // dissipation et la meme mecanique que les vraies maladies, mais AUCUNE
    // ICONE : c'est la marque des auras que le joueur ne voit pas, et le
    // discriminant retenu.
    uint32 MaladiesDe(Unit const* chevalier, Unit const* victime)
    {
        if (!chevalier || !victime)
            return 0;
        uint32 maladies = 0;
        for (auto const& paire : victime->GetAppliedAuras())
        {
            Aura const* aura = paire.second->GetBase();
            if (!aura || aura->GetCasterGUID() != chevalier->GetGUID()
                || aura->GetSpellInfo()->Dispel != DISPEL_DISEASE
                || !aura->GetSpellInfo()->SpellIconID)
                continue;
            ++maladies;
        }
        return maladies;
    }

    // (Le passage a la creature native 26125, demande puis annule le
    // 2026-09-02, est retire : la goule reste notre clone 803801, avec son
    // ScriptName et donc son IA sans greffe.)

    class spell_papota_apocalypse : public SpellScript
    {
        PrepareSpellScript(spell_papota_apocalypse);

        // Chaque maladie que LE LANCEUR a posee majore les degats de moitie :
        // la lame paie le travail deja fait, comme le Fleau des rois avec ses
        // poisons. L'ECLABOUSSURE (2026-09-02) : la moitie du coup aux
        // ennemis a 8 m de la cible, majoree pour chacun d'eux de 12,5 % par
        // maladie du chevalier SUR LUI.
        void Eclater(SpellEffIndex /*index*/)
        {
            Unit* dk = GetCaster();
            Unit* cible = GetHitUnit();
            if (!dk || !cible)
                return;
            int32 const plein = GetHitDamage();
            uint32 const maladies = MaladiesDe(dk, cible);
            SetHitDamage(plein + plein * int32(maladies) / 2);

            SpellInfo const* info = GetSpellInfo();
            if (!info)
                return;
            std::list<Unit*> proches;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(cible, dk,
                                                               APOCALYPSE_RAYON);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chasse(cible, proches, hostile);
            Cell::VisitObjects(cible, chasse, APOCALYPSE_RAYON);
            for (Unit* voisin : proches)
            {
                if (voisin == cible || !voisin->IsAlive()
                    || !dk->IsValidAttackTarget(voisin))
                    continue;
                // Livraison EXPLICITE, le patron des Frappes fauchantes : un
                // CastCustomSpell n'afficherait rien au joueur et
                // remitigerait le montant une seconde fois.
                uint32 const chez_lui = MaladiesDe(dk, voisin);
                int32 montant = plein * int32(APOCALYPSE_ECLABOUSSURE) / 100;
                montant += montant * int32(chez_lui)
                    * int32(GOULE_BONUS_MALADIE) / 1000;
                SpellNonMeleeDamage eclat(dk, voisin, info,
                                          SPELL_SCHOOL_MASK_SHADOW);
                eclat.damage = uint32(std::max(1, montant));
                dk->SendSpellNonMeleeDamageLog(&eclat);
                dk->DealSpellDamage(&eclat, false);
            }
        }

        void Lever()
        {
            Unit* lanceur = GetCaster();
            Unit* cible = GetExplTargetUnit();
            if (!lanceur || !cible)
                return;

            // Une goule par ennemi de la zone, levee A SES PIEDS.
            std::list<Unit*> proies;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(cible, lanceur,
                                                               APOCALYPSE_RAYON);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chasse(cible, proies, hostile);
            Cell::VisitObjects(cible, chasse, APOCALYPSE_RAYON);

            uint32 levees = 0;
            for (Unit* proie : proies)
            {
                if (!proie->IsAlive())
                    continue;
                LeverGoule(lanceur, proie->GetPosition());
                ++levees;
            }
            // Le plancher : deux goules au moins, sous la cible du sort.
            for (; levees < APOCALYPSE_MINIMUM; ++levees)
            {
                Position ou = cible->GetPosition();
                cible->MovePositionToFirstCollision(ou, 3.0f,
                                                    float(levees) * float(M_PI));
                LeverGoule(lanceur, ou);
            }
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_papota_apocalypse::Eclater,
                                               EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
            AfterCast += SpellCastFn(spell_papota_apocalypse::Lever);
        }

    private:
        static void LeverGoule(Unit* lanceur, Position const& ou)
        {
            Creature* goule = lanceur->SummonCreature(GHOULE, ou,
                TEMPSUMMON_TIMED_DESPAWN, APOCALYPSE_VIE);
            if (!goule)
                return;
            // Le visuel de Reanimation morbide, joue SUR la goule par le
            // sort auxiliaire — et RETARDE comme l'emote : lance au tick
            // meme de l'invocation, le client n'a pas encore la creature et
            // ne rend rien.
            ObjectGuid guid = goule->GetGUID();
            ObjectGuid guidDk = lanceur->GetGUID();
            lanceur->m_Events.AddEventAtOffset([guid, guidDk]()
            {
                Player* dk = ObjectAccessor::FindPlayer(guidDk);
                if (!dk || !dk->IsInWorld())
                    return;
                if (Creature* c = ObjectAccessor::GetCreature(*dk, guid))
                    dk->CastSpell(c, APOCALYPSE_LEVEE, true);
            }, Milliseconds(GOULE_MARGE));
        }
    };

    // La goule d'Apocalypse : elle mord LE PLUS PROCHE d'elle, et non la
    // cible de son maitre — elle est levee au pied de sa proie. Le patron
    // reste celui de la meute du chasseur : niveau et camp du maitre,
    // proprietaire pose (sans quoi le client n'affiche pas ses degats en
    // texte flottant), et DoMeleeAttackIfReady a chaque tick — SANS CET
    // APPEL UNE CREATURE NE FRAPPE JAMAIS.
    struct npc_papota_goule : public ScriptedAI
    {
        npc_papota_goule(Creature* creature) : ScriptedAI(creature) { }

        void JustEngagedWith(Unit* /*qui*/) override { }
        void MoveInLineOfSight(Unit* /*qui*/) override { }

        void InitializeAI() override
        {
            ScriptedAI::InitializeAI();
            Unit* maitre = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!maitre)
                return;
            me->SetFaction(maitre->GetFaction());
            me->SetLevel(maitre->GetLevel());
            me->SetOwnerGUID(maitre->GetGUID());
            me->SetCreatorGUID(maitre->GetGUID());
            me->SetReactState(REACT_AGGRESSIVE);
            // 25 % de hate (2026-09-02) : le canal prevu pour cela, qui
            // divise le temps d'attaque au lieu de le reecrire — le gabarit
            // garde donc sa cadence de reference.
            me->ApplyAttackTimePercentMod(BASE_ATTACK, GOULE_HATE, true);
            // Elle sort du sol avant de mordre. La marge du Shunpo : une
            // emote jouee au tick meme de l'invocation est jetee, le client
            // n'ayant pas encore la creature.
            if (!GOULE_EMOTE_EMERGE)
                return;
            // La file d'evenements appartient a la creature : elle meurt
            // avec elle, la capture est donc sure.
            Creature* moi = me;
            me->m_Events.AddEventAtOffset([moi]()
            {
                moi->HandleEmoteCommand(GOULE_EMOTE_EMERGE);
            }, Milliseconds(GOULE_MARGE));
            _emerge = GOULE_MARGE + GOULE_EMERGE_MS;
        }

        // Le bonus par maladie : +12,5 % par maladie que LE CHEVALIER a
        // posee sur la victime, applique a chaque coup porte.
        void DamageDealt(Unit* victime, uint32& degats,
                         DamageEffectType /*type*/,
                         SpellSchoolMask /*ecole*/) override
        {
            Unit* maitre = ObjectAccessor::GetUnit(*me, me->GetOwnerGUID());
            uint32 const maladies = MaladiesDe(maitre, victime);
            if (maladies)
                degats += degats * maladies * GOULE_BONUS_MALADIE / 1000;
        }

        void UpdateAI(uint32 diff) override
        {
            // Tant qu'elle s'extirpe du sol, elle ne bouge ni ne frappe :
            // sans cela le deplacement couperait l'animation aussitot.
            if (_emerge)
            {
                _emerge = _emerge > diff ? _emerge - diff : 0;
                return;
            }
            _guet += diff;
            if (_guet >= GOULE_TIC && !UpdateVictim())
            {
                _guet = 0;
                Unit* maitre = ObjectAccessor::GetUnit(*me, me->GetOwnerGUID());
                if (maitre)
                {
                    // LE PLUS PROCHE : la goule mord ce qu'elle a sous le
                    // nez, chacune la sienne.
                    std::list<Unit*> proies;
                    Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(me,
                        maitre, APOCALYPSE_RAYON * 2.0f);
                    Acore::UnitListSearcher<
                        Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                        chasse(me, proies, hostile);
                    Cell::VisitObjects(me, chasse, APOCALYPSE_RAYON * 2.0f);

                    Unit* meilleure = nullptr;
                    float plus_proche = 0.0f;
                    for (Unit* proie : proies)
                    {
                        if (!proie->IsAlive() || !me->CanCreatureAttack(proie))
                            continue;
                        float const d = me->GetDistance(proie);
                        if (!meilleure || d < plus_proche)
                        {
                            meilleure = proie;
                            plus_proche = d;
                        }
                    }
                    if (meilleure)
                        me->EngageWithTarget(meilleure);
                }
            }
            if (!UpdateVictim())
                return;
            DoMeleeAttackIfReady();
        }

    private:
        uint32 _guet = GOULE_TIC;
        uint32 _emerge = 0;      // ms restantes de la sortie de terre
    };


    // =======================================================================
    // Tempete d'os — un bienfait qui tourne autour du chevalier
    // =======================================================================
    // Refonte du 2026-09-02 : l'aura vit sur LE CHEVALIER et non plus sur
    // chaque ennemi. Elle bat chaque seconde ; a chaque battement, la
    // tempete lacere les ennemis a 8 m et rend au porteur une fraction de
    // ses points de vie maximum. Les deux montants viennent du DBC :
    // l'effet 0 porte les degats, l'effet 1 le pourcentage de vie.
    constexpr float TEMPETE_RAYON = 5.0f;   // 8 -> 5 m (2026-09-02)

    class spell_papota_tempete_os : public AuraScript
    {
        PrepareAuraScript(spell_papota_tempete_os);

        void Tourner(AuraEffect const* effet)
        {
            Unit* dk = GetTarget();
            if (!dk || !dk->IsAlive())
                return;
            SpellInfo const* info = GetSpellInfo();
            if (!info)
                return;

            // Les degats, livres EXPLICITEMENT : le journal est envoye
            // soi-meme, sans quoi le joueur ne verrait rien defiler.
            std::list<Unit*> proies;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(dk, dk,
                                                               TEMPETE_RAYON);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chasse(dk, proies, hostile);
            Cell::VisitObjects(dk, chasse, TEMPETE_RAYON);
            uint32 laceres = 0;
            for (Unit* proie : proies)
            {
                if (!proie->IsAlive() || !dk->IsValidAttackTarget(proie))
                    continue;
                SpellNonMeleeDamage coup(dk, proie, info,
                                         SPELL_SCHOOL_MASK_SHADOW);
                coup.damage = uint32(std::max(1, effet->GetAmount()));
                dk->SendSpellNonMeleeDamageLog(&coup);
                dk->DealSpellDamage(&coup, false);
                ++laceres;
            }

            // Le soin : une fraction des PV MAXIMUM PAR ENNEMI PRIS DANS LA
            // TEMPETE (2026-09-02) — plus il y a de monde autour, plus elle
            // le remet sur pied. Aucun ennemi, aucun soin.
            int32 part = 0;
            if (AuraEffect const* second = GetEffect(EFFECT_1))
                part = second->GetAmount();
            if (part <= 0 || !laceres)
                return;
            uint32 const soin =
                uint32(dk->GetMaxHealth() * uint32(part) * laceres / 100);
            if (!soin)
                return;
            HealInfo bienfait(dk, dk, soin, info, SPELL_SCHOOL_MASK_SHADOW);
            dk->HealBySpell(bienfait);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_papota_tempete_os::Tourner, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Souffle de Sindragosa — il dure tant que la puissance runique dure
    // =======================================================================
    // La refonte de l'audit : la premiere version posait l'aura sur CHAQUE
    // ennemi du cone, et le drain se payait par battement de chaque cible —
    // trois ennemis, triple facture. L'aura vit desormais sur le lanceur : un
    // seul compteur, un cone declenche par seconde (sort 8600054, porte par le
    // DBC), et l'extinction souffle la canalisation entiere.
    class spell_papota_souffle_sindragosa : public AuraScript
    {
        PrepareAuraScript(spell_papota_souffle_sindragosa);

        void Consommer(AuraEffect const* /*effet*/)
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return;

            constexpr uint32 COUT = 150;        // en dixiemes, soit 15 points
            if (lanceur->GetPower(POWER_RUNIC_POWER) < COUT)
            {
                PreventDefaultAction();          // pas de morsure gratuite
                Remove();
                return;
            }
            lanceur->ModifyPower(POWER_RUNIC_POWER, -int32(COUT));
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_papota_souffle_sindragosa::Consommer,
                                                     EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
        }
    };

    // =======================================================================
    // Seisme — le sol tremble, et par moments on tombe
    // =======================================================================
    // La zone du DBC frappe seule, chaque seconde ; le script n'ajoute qu'une
    // chose : une chance, a chaque coup porte, de jeter la victime a la
    // renverse. La chute est le sort 8600068 — une seconde d'etourdissement
    // de mecanique « assomme », celle qui couche au lieu de figer.
    constexpr uint32 SEISME_CHUTE = 8600068;
    constexpr uint32 SEISME_CHANCE = 10;     // % par battement et par victime

    class spell_papota_seisme : public AuraScript
    {
        PrepareAuraScript(spell_papota_seisme);

        void Trembler(AuraEffect const* /*effet*/)
        {
            Unit* chaman = GetCaster();
            Unit* victime = GetTarget();
            if (!chaman || !victime || !victime->IsAlive())
                return;
            if (!roll_chance_i(SEISME_CHANCE))
                return;
            // Deja par terre : on ne la recouche pas, le decompte
            // repartirait a chaque battement et clouerait la victime au sol.
            if (victime->HasAura(SEISME_CHUTE))
                return;
            chaman->CastSpell(victime, SEISME_CHUTE, true);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_papota_seisme::Trembler, EFFECT_0,
                SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Ascendance — la foudre bondit d'elle-meme
    // =======================================================================
    // Refonte du 2026-09-02. Le chaman PREND LA FORME d'un ascendant le
    // temps du bienfait, et la reprend a la fin ou a l'annulation. Au
    // lancement, cinq ennemis DEVANT LUI a 36 m recoivent Horion de feu puis
    // une Explosion de lave — au meilleur rang qu'il connaisse, lu dans son
    // grimoire plutot que code en dur (patron du Desespoir du pretre).
    constexpr float ASCENDANCE_PORTEE = 36.0f;
    constexpr uint32 ASCENDANCE_CIBLES = 5;
    constexpr uint32 HORION_MASQUE = 0x10000000;   // mot 0 — Flame Shock
    constexpr uint32 LAVE_MASQUE = 0x1000;         // mot 1 — Lava Burst
    // Les apparences de l'ascendant, une par couleur : le chaman en prend une
    // AU HASARD a chaque lancement. Elles partagent le meme CreatureModelData
    // (802120) et ne different que par leurs trois textures remplaçables.
    // Toute entree ajoutee ici doit exister dans VARIANTES_ASCENDANT de
    // gen_visuel_chaman.py, qui pose les lignes de CreatureDisplayInfo dans
    // patch-z ET dans les DBC serveur.
    constexpr uint32 ASCENDANCE_FORMES[] = { 802120, 802121, 802122 };

    uint32 AscendanceMeilleurRang(Player* chaman, uint8 mot, uint32 masque)
    {
        uint32 meilleur = 0;
        uint32 niveauMeilleur = 0;
        for (auto const& paire : chaman->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_SHAMAN)
                continue;
            if (!(info->SpellFamilyFlags[mot] & masque))
                continue;
            uint32 niveau = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!meilleur || niveau > niveauMeilleur)
            {
                meilleur = info->Id;
                niveauMeilleur = niveau;
            }
        }
        return meilleur;
    }

    class spell_papota_ascendance : public AuraScript
    {
        PrepareAuraScript(spell_papota_ascendance);

        void Monter(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            Player* chaman = GetTarget() ? GetTarget()->ToPlayer() : nullptr;
            if (!chaman)
                return;
            // LA FORME : une apparence tiree au sort parmi celles posees.
            chaman->SetDisplayId(Acore::Containers::SelectRandomContainerElement(
                ASCENDANCE_FORMES));

            uint32 const horion = AscendanceMeilleurRang(chaman, 0,
                                                         HORION_MASQUE);
            uint32 const lave = AscendanceMeilleurRang(chaman, 1, LAVE_MASQUE);
            if (!horion && !lave)
                return;

            // CINQ ENNEMIS DEVANT LUI : le demi-cercle avant, les plus
            // proches d'abord.
            std::list<Unit*> proies;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(chaman, chaman,
                                                               ASCENDANCE_PORTEE);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chasse(chaman, proies, hostile);
            Cell::VisitObjects(chaman, chasse, ASCENDANCE_PORTEE);
            proies.remove_if([chaman](Unit* u)
            {
                return !u || !u->IsAlive() || !chaman->IsValidAttackTarget(u)
                    || !chaman->HasInArc(float(M_PI), u);
            });
            proies.sort(Acore::ObjectDistanceOrderPred(chaman));
            if (proies.size() > ASCENDANCE_CIBLES)
                proies.resize(ASCENDANCE_CIBLES);

            for (Unit* proie : proies)
            {
                if (horion)
                    chaman->CastSpell(proie, horion, true);
                if (lave)
                    chaman->CastSpell(proie, lave, true);
            }
        }

        void Redescendre(AuraEffect const* /*effet*/,
                         AuraEffectHandleModes /*mode*/)
        {
            // A l'expiration COMME a l'annulation : le chaman reprend sa
            // silhouette.
            if (Unit* cible = GetTarget())
                cible->RestoreDisplayId();
        }

        void Register() override
        {
            AfterEffectApply += AuraEffectApplyFn(
                spell_papota_ascendance::Monter, EFFECT_0,
                SPELL_AURA_MOD_DAMAGE_PERCENT_DONE, AURA_EFFECT_HANDLE_REAL);
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_papota_ascendance::Redescendre, EFFECT_0,
                SPELL_AURA_MOD_DAMAGE_PERCENT_DONE, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Totem de lien d'esprit — il ne soigne pas, il REDISTRIBUE
    // =======================================================================
    // Refonte du 2026-09-03. Toute la logique est ici : le DBC ne porte qu'une
    // aura FACTICE qui bat une fois par seconde. A chaque battement, autour du
    // TOTEM (pas du lanceur) et dans le groupe ou le raid seulement :
    //
    // La MARQUE (8600064) porte tout ce qui se voit : elle dit qui est dans
    // le lien, soigne 2 % des PV max par battement et retire 3 % aux degats
    // subis. Le chaman la porte comme les autres — l'aura du sort, elle, est
    // masquee de la barre de bienfaits, pour qu'il n'y ait qu'une icone.
    //
    //   1. mediane des POURCENTAGES de vie des membres vivants a portee.
    //      C est la sante RELATIVE qui trie, pas les PV absolus (decision du
    //      2026-09-03) : sinon un tank blesse a 60 % financerait des lanceurs
    //      a 90 %, seulement parce que sa barre est plus grande ;
    //   2. ceux AU-DESSUS versent 10 % de leurs PV actuels dans un pool, sans
    //      jamais descendre sous 10 % de leurs PV max ;
    //   3. ceux EN DESSOUS se partagent le pool au prorata de leurs PV
    //      manquants — ils peuvent depasser la mediane, jusqu'a leur maximum ;
    //   4. on ne preleve que ce qui est NECESSAIRE : si l'offre depasse la
    //      demande, les donneurs versent moins, sinon on detruirait des PV.
    //
    // Les PV sont poses DIRECTEMENT : ni soin ni degats, donc pas de surcharge,
    // pas de bouclier, pas de menace, pas de mise en combat, aucun proc.
    constexpr float LIEN_RAYON = 7.0f;    // 7 m (revision du 2026-09-03)
    constexpr uint32 LIEN_DUREE = 16000;  // 16 s (revision du 2026-09-03)
    constexpr uint32 LIEN_PART = 10;      // % des PV ACTUELS verses par battement
    constexpr uint32 LIEN_PLANCHER = 10;  // % des PV MAX sous lesquels on ne prend rien
    constexpr uint32 LIEN_VISUEL = 8600069;  // le porteur de l effet, pose sur le totem
    // 8600064 : le bloc du chaman va de 60 a 69, 70 appartient deja au
    // Miroitement du mage (86000CS : C = classe, S = emplacement).
    constexpr uint32 LIEN_MARQUE = 8600064;  // la marque des membres a portee

    // Repartit `total` au prorata des `poids`, SANS perte ni creation : le
    // reliquat des divisions entieres est rendu au fil de l'eau, de sorte que
    // la somme des parts vaut exactement `total`.
    std::vector<uint64> LienRepartit(uint64 total, std::vector<uint64> const& poids)
    {
        std::vector<uint64> parts(poids.size(), 0);
        uint64 somme = 0;
        for (uint64 w : poids)
            somme += w;
        if (!somme || !total)
            return parts;
        uint64 rendu = 0;
        for (size_t i = 0; i < poids.size(); ++i)
        {
            parts[i] = total * poids[i] / somme;
            rendu += parts[i];
        }
        for (size_t i = 0; i < parts.size() && rendu < total; ++i)
            if (poids[i])
            {
                ++parts[i];
                ++rendu;
            }
        return parts;
    }

    class spell_papota_lien_esprit : public AuraScript
    {
        PrepareAuraScript(spell_papota_lien_esprit);

        ObjectGuid _totem;
        // Ceux qui portent la marque. La marque etant PERMANENTE, rien ne la
        // retire d'elle-meme : on tient la liste pour la reprendre a coup sur,
        // y compris a quelqu'un qui aurait quitte le groupe en cours de route.
        GuidSet _marques;

        void Poser(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            Unit* chaman = GetTarget();
            if (!chaman)
                return;
            if (TempSummon* totem = chaman->SummonCreature(
                    TOTEM, chaman->GetPosition(), TEMPSUMMON_TIMED_DESPAWN,
                    LIEN_DUREE))
            {
                _totem = totem->GetGUID();
                // L EFFET EST SUR LE TOTEM, pas sur le chaman : une aura
                // porteuse, qui ne fait rien d autre que tenir le visuel
                // pendant les 16 secondes et suivre la creature.
                totem->CastSpell(totem, LIEN_VISUEL, true);
            }
        }

        void Retirer(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            // A l'expiration COMME a l'annulation : le totem s'en va, et
            // plus personne ne porte la marque.
            Unit* chaman = GetTarget();
            if (!chaman)
                return;
            if (Creature* totem = ObjectAccessor::GetCreature(*chaman, _totem))
                totem->DespawnOrUnsummon();
            for (ObjectGuid guid : _marques)
                if (Unit* marque = ObjectAccessor::GetUnit(*chaman, guid))
                    marque->RemoveAurasDueToSpell(LIEN_MARQUE,
                                                  chaman->GetGUID());
            _marques.clear();
        }

        void Battre(AuraEffect const* /*effet*/)
        {
            Unit* chaman = GetTarget();
            if (!chaman)
                return;
            Creature* totem = ObjectAccessor::GetCreature(*chaman, _totem);
            if (!totem || !totem->IsInWorld())
                return;
            Player* joueur = chaman->ToPlayer();
            if (!joueur)
                return;

            // 1. LE CERCLE : le chaman et, s il en a un, son groupe ou son
            //    raid — vivants, dans le rayon du TOTEM. SEUL COMPTE AUSSI :
            //    sans groupe, seul dans un groupe ou seul dans un raid, le
            //    chaman est marque et profite du soin et de la reduction de
            //    degats. Il n y a simplement rien a redistribuer a un.
            std::vector<Player*> candidats;
            if (Group* groupe = joueur->GetGroup())
                for (GroupReference* it = groupe->GetFirstMember(); it; it = it->next())
                {
                    if (Player* membre = it->GetSource())
                        candidats.push_back(membre);
                }
            else
                candidats.push_back(joueur);

            std::vector<Player*> membres;
            GuidSet dedans;
            {
                for (Player* membre : candidats)
                {
                    if (!membre || !membre->GetMaxHealth())
                        continue;
                    // LA MARQUE suit le cercle a chaque battement : posee des
                    // qu on entre dans les 10 metres, retiree des qu on en
                    // sort ou qu on meurt. C est le seul signe visible que
                    // l on est dans le lien.
                    if (membre->IsAlive() && membre->IsInMap(totem)
                        && membre->IsWithinDistInMap(totem, LIEN_RAYON))
                    {
                        membres.push_back(membre);
                        if (!membre->HasAura(LIEN_MARQUE, chaman->GetGUID()))
                            chaman->CastSpell(membre, LIEN_MARQUE, true);
                        dedans.insert(membre->GetGUID());
                    }
                }
            }

            // CEUX QUI SONT SORTIS : on parcourt la liste de la fois d'avant,
            // pas le groupe — quelqu'un qui a quitte le raid en cours de route
            // ne serait plus parcouru et garderait la marque a jamais.
            for (ObjectGuid guid : _marques)
                if (!dedans.count(guid))
                    if (Unit* parti = ObjectAccessor::GetUnit(*chaman, guid))
                        parti->RemoveAurasDueToSpell(LIEN_MARQUE,
                                                     chaman->GetGUID());
            _marques = dedans;

            // A UN, la marque est deja posee : on s arrete avant la
            // redistribution, qui n aurait aucun sens.
            if (membres.size() < 2)
                return;

            // 2. LA MEDIANE des POURCENTAGES de vie — la sante RELATIVE.
            //    Nombre pair : moyenne des deux valeurs centrales. En millieme
            //    pour garder de la finesse en arithmetique entiere.
            std::vector<uint64> parts;
            parts.reserve(membres.size());
            for (Player* m : membres)
                parts.push_back(uint64(m->GetHealth()) * 1000 / m->GetMaxHealth());
            std::sort(parts.begin(), parts.end());
            size_t const milieu = parts.size() / 2;
            uint64 const mediane = (parts.size() % 2)
                ? parts[milieu]
                : (parts[milieu - 1] + parts[milieu]) / 2;

            // 3. DONNEURS et RECEVEURS.
            std::vector<Player*> donneurs, receveurs;
            std::vector<uint64> capacites, manques;
            uint64 offre = 0, demande = 0;
            for (Player* m : membres)
            {
                uint64 const actuel = m->GetHealth();
                uint64 const maxi = m->GetMaxHealth();
                uint64 const part = actuel * 1000 / maxi;
                if (part > mediane)
                {
                    uint64 const plancher = maxi * LIEN_PLANCHER / 100;
                    if (actuel <= plancher)
                        continue;                       // deja sous son plancher
                    uint64 don = actuel * LIEN_PART / 100;
                    if (actuel - don < plancher)        // le don s arrete au plancher
                        don = actuel - plancher;
                    if (!don)
                        continue;
                    donneurs.push_back(m);
                    capacites.push_back(don);
                    offre += don;
                }
                else if (part < mediane && actuel < maxi)
                {
                    receveurs.push_back(m);
                    manques.push_back(maxi - actuel);
                    demande += maxi - actuel;
                }
            }
            if (!offre || !demande)
                return;

            // 4. LE TRANSFERT : ce qui est necessaire, et rien de plus.
            uint64 const transfert = std::min(offre, demande);
            std::vector<uint64> const pris = LienRepartit(transfert, capacites);
            std::vector<uint64> const recus = LienRepartit(transfert, manques);

            // Les sommes sont en uint64 pour ne pas deborder sur un raid de
            // 40, mais les PV eux-memes tiennent dans un uint32 : on y revient
            // explicitement au moment de les poser.
            for (size_t i = 0; i < donneurs.size(); ++i)
                if (pris[i])
                    donneurs[i]->SetHealth(
                        uint32(uint64(donneurs[i]->GetHealth()) - pris[i]));
            for (size_t i = 0; i < receveurs.size(); ++i)
                if (recus[i])
                {
                    uint64 const vise = uint64(receveurs[i]->GetHealth()) + recus[i];
                    uint64 const maxi = uint64(receveurs[i]->GetMaxHealth());
                    receveurs[i]->SetHealth(uint32(std::min(vise, maxi)));
                }
        }

        void Register() override
        {
            AfterEffectApply += AuraEffectApplyFn(
                spell_papota_lien_esprit::Poser, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_papota_lien_esprit::Retirer, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_papota_lien_esprit::Battre, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Invocation de tyran demoniaque
    // =======================================================================
    // ---------------------------------------------------------------------
    // Le tyran demoniaque (8600082) — refonte du 2026-09-03
    // ---------------------------------------------------------------------
    // TRENTE SECONDES, et un modele a lui (802130, gen_visuel_demoniste). Il
    // brule tout ce qui l'entoure — l'aura de zone 8610008, batie comme
    // l'Immolation de l'Infernal — et CHACUNE DE SES ATTAQUES renforce les
    // demons du demoniste.
    //
    // POURQUOI UNE AURA SUR LE DEMONISTE plutot qu'un simple lancer : il faut
    // un endroit ou faire le menage. Les bonus doivent tomber quand le tyran
    // MEURT autant que quand il DISPARAIT, et un CreatureAI n'offre pas de
    // point d'accroche fiable au despawn. L'aura de 30 s du sort sert des
    // deux : son retrait renvoie le tyran ET reprend tous les bonus, et l'IA
    // du tyran retire cette aura en mourant. Un seul chemin pour les deux cas.
    constexpr uint32 TYRAN = 8600082;
    // LA HATE DU TYRAN (2026-09-03) remplace la zone de feu qu'il portait :
    // le canal prevu pour cela, qui DIVISE le temps d'attaque au lieu de le
    // reecrire — le gabarit garde donc sa cadence de reference.
    constexpr float TYRAN_HATE = 15.0f;         // %
    constexpr uint32 TYRAN_DIABLOTIN = 8610000;
    constexpr uint32 TYRAN_CHASSEUR = 8610001;
    constexpr uint32 TYRAN_SUCCUBE = 8610002;
    constexpr uint32 TYRAN_MARCHEUR = 8610003;
    constexpr uint32 TYRAN_ASSERVI = 8610004;
    constexpr uint32 TYRAN_CHAINES = 8610005;   // demons de Xer'thul, cumulable
    constexpr uint32 TYRAN_BRISEES = 8610006;   // demons de Xer'thul, fixe
    constexpr uint32 TYRAN_TAILLE = 8610007;
    constexpr uint32 TYRAN_GARDE = 8610008;       // gangregarde : degats, fixe
    constexpr uint32 TYRAN_GARDE_HATE = 8610009;  // gangregarde : hate, cumulable
    // LE DEMONISTE LUI-MEME, sous Metamorphose. Ces deux-la ne vont pas sur un
    // demon mais sur le maitre : le menage doit donc les reprendre a part.
    constexpr uint32 TYRAN_META_CUMUL = 8610010;  // hate + critique, cumulables
    constexpr uint32 TYRAN_META_FIXE = 8610011;   // vitesse + mana, fixes
    constexpr uint32 METAMORPHOSE = 47241;        // la forme demoniaque NATIVE

    // Tout ce que le tyran peut avoir pose, pour le menage final.
    constexpr uint32 TYRAN_BONUS[] = {
        TYRAN_DIABLOTIN, TYRAN_CHASSEUR, TYRAN_SUCCUBE, TYRAN_MARCHEUR,
        TYRAN_ASSERVI, TYRAN_CHAINES, TYRAN_BRISEES, TYRAN_TAILLE,
        TYRAN_GARDE, TYRAN_GARDE_HATE
    };

    // Ce que le tyran pose sur LE DEMONISTE, et non sur ses demons.
    constexpr uint32 TYRAN_BONUS_MAITRE[] = { TYRAN_META_CUMUL, TYRAN_META_FIXE };

    // Les familiers classiques du demoniste, par entree de creature.
    constexpr uint32 DEMON_DIABLOTIN = 416;
    constexpr uint32 DEMON_CHASSEUR = 417;
    constexpr uint32 DEMON_MARCHEUR = 1860;
    constexpr uint32 DEMON_SUCCUBE = 1863;
    constexpr uint32 DEMON_GANGREGARDE = 17252;
    // Les cinq gardiens de « Xer'thul, Maitre des Chaines » (mod-papota-spells).
    constexpr uint32 DEMON_XERTHUL_PREMIER = 808000;
    constexpr uint32 DEMON_XERTHUL_DERNIER = 808004;

    constexpr uint32 TYRAN_PART_BOUCLIER = 50;   // % des PV max du demon
    // DEUX VISUELS D'INSTANT, joues sur la CIBLE frappee et non sur le demon :
    // une aura ne sait viser que son porteur, d'ou le paquet direct
    // (SMSG_PLAY_SPELL_VISUAL), qui prend l'unite comme source. Ce sont des
    // SpellVisualKit NATIFS, jamais modifies.
    constexpr uint32 KIT_MORSURE_OMBRE = 117;   // Shadow_ImpactDD_Low_Chest
    constexpr uint32 KIT_SEDUCTION = 2650;      // Seduction_State_Head

    // Les demons du demoniste : son familier, ses gardiens, ses asservis.
    static void RassembleDemons(Unit* maitre, std::vector<Unit*>& demons)
    {
        if (!maitre)
            return;
        for (Unit* controle : maitre->m_Controlled)
            if (controle && controle->IsAlive())
                demons.push_back(controle);
    }

    // Le bonus PROPRE au demon, ou 0 s'il n'en merite aucun.
    static uint32 BonusDuDemon(Unit* demon, Unit* maitre)
    {
        Creature* creature = demon ? demon->ToCreature() : nullptr;
        if (!creature)
            return 0;
        uint32 const entree = creature->GetEntry();
        if (entree >= DEMON_XERTHUL_PREMIER && entree <= DEMON_XERTHUL_DERNIER)
            return TYRAN_CHAINES;
        switch (entree)
        {
            case DEMON_DIABLOTIN: return TYRAN_DIABLOTIN;
            case DEMON_CHASSEUR:  return TYRAN_CHASSEUR;
            case DEMON_MARCHEUR:  return TYRAN_MARCHEUR;
            case DEMON_SUCCUBE:   return TYRAN_SUCCUBE;
            // Le CUMULABLE fait office de bonus principal, comme pour les
            // demons de Xer'thul : le fixe est pose a cote, une seule fois.
            case DEMON_GANGREGARDE: return TYRAN_GARDE_HATE;
            default: break;
        }
        // Un demon ASSERVI n'a pas d'entree a nous : il se reconnait a ce
        // qu'il est charme par le demoniste, et non simplement possede.
        if (maitre && demon->GetCharmerGUID() == maitre->GetGUID())
            return TYRAN_ASSERVI;
        return 0;
    }

    // Reprend tous les bonus a tous les demons — le tyran s'en va.
    static void ReprendLesBonus(Unit* maitre)
    {
        if (!maitre)
            return;
        for (uint32 bonus : TYRAN_BONUS_MAITRE)
            maitre->RemoveAurasDueToSpell(bonus);
        std::vector<Unit*> demons;
        RassembleDemons(maitre, demons);
        for (Unit* demon : demons)
            for (uint32 bonus : TYRAN_BONUS)
                demon->RemoveAurasDueToSpell(bonus);
    }

    class spell_papota_tyran : public AuraScript
    {
        PrepareAuraScript(spell_papota_tyran);

        // L'INVOCATION N'EST PLUS ICI : le DBC s'en charge (effet 1 du sort,
        // SummonProperties 1161). Ne reste que le MENAGE, porte par l'aura
        // du second effet.
        void Renvoyer(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
        {
            Unit* lanceur = GetCaster();
            // Quel que soit le chemin : fin des 30 s, mort du tyran (son IA
            // retire alors cette aura) ou mort du demoniste.
            ReprendLesBonus(lanceur);
            if (!lanceur)
                return;
            // Le gardien pose par le DBC figure parmi les unites controlees :
            // on n'a donc pas a retenir son GUID.
            std::vector<Unit*> a_renvoyer;
            for (Unit* controle : lanceur->m_Controlled)
                if (controle && controle->GetEntry() == GARDE_FUNESTE)
                    a_renvoyer.push_back(controle);
            for (Unit* tyran : a_renvoyer)
                if (Creature* creature = tyran->ToCreature())
                    creature->DespawnOrUnsummon();
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectApplyFn(spell_papota_tyran::Renvoyer,
                                                   EFFECT_1, SPELL_AURA_DUMMY,
                                                   AURA_EFFECT_HANDLE_REAL);
        }
    };

    // La brulure de mana du chasseur corrompu. Elle est faite ICI et non par
    // un sort declenche, faute d'un dixieme identifiant dans la plage.
    class spell_papota_tyran_chasseur : public AuraScript
    {
        PrepareAuraScript(spell_papota_tyran_chasseur);

        void Bruler(AuraEffect const* effet, ProcEventInfo& infos)
        {
            PreventDefaultAction();
            Unit* cible = infos.GetActionTarget();
            if (!cible || cible->getPowerType() != POWER_MANA)
                return;
            // Ce coeur n'a pas de CountPctFromMaxPower : on calcule.
            uint32 const perte = CalculatePct(cible->GetMaxPower(POWER_MANA),
                                              effet->GetAmount());
            if (!perte)
                return;
            cible->ModifyPower(POWER_MANA, -int32(std::min<uint32>(
                perte, cible->GetPower(POWER_MANA))));
            // L'ombre qui s'abat sur la cible drainee.
            cible->SendPlaySpellVisual(KIT_MORSURE_OMBRE);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_papota_tyran_chasseur::Bruler,
                                             EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
        }
    };

    // Le charme de la succube : 5 % par attaque, vers la Seduction NATIVE.
    class spell_papota_tyran_succube : public AuraScript
    {
        PrepareAuraScript(spell_papota_tyran_succube);

        void Charmer(AuraEffect const* effet, ProcEventInfo& infos)
        {
            PreventDefaultAction();
            Unit* cible = infos.GetActionTarget();
            Unit* demon = GetTarget();
            // Le tirage est fait ICI : la ProcChance du DBC est a 101 pour
            // tous les sorts du chantier (gen_sorts_classes), donc inutile
            // pour porter un pourcentage propre a ce bonus.
            if (!cible || !demon || !roll_chance_i(effet->GetAmount()))
                return;
            demon->CastSpell(cible, SEDUCTION, true);
            // Le charme se voit meme si la cible y resiste : c'est le
            // DECLENCHEMENT qu'on annonce, pas son resultat.
            cible->SendPlaySpellVisual(KIT_SEDUCTION);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_papota_tyran_succube::Charmer,
                                             EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
        }
    };

    // CALQUEE SUR LA GOULE DE REANIMATION MORBIDE (npc_pet_dk_ghoul, creature
    // 26125), la reference nommee : un gardien qui combat aux cotes de son
    // maitre sans etre commandable. Elle derive de CombatAI — pas de PetAI,
    // qui donnerait une barre de familier et des ordres — et se contente de
    // retenir la cible du maitre au moment de l'invocation.
    //
    // Le DBC fait le reste : SummonProperties 61, categorie 1 type 2, un
    // Guardian SIMPLE. Guardian::InitStats lui donne maitre, faction et
    // niveau ; CombatAI lui donne l'agression et la poursuite. Ne reste ici
    // que ce qu'aucun des deux ne sait dire.
    struct npc_papota_tyran : public CombatAI
    {
        npc_papota_tyran(Creature* creature) : CombatAI(creature) { }

        ObjectGuid _cible;

        void InitializeAI() override
        {
            CombatAI::InitializeAI();
            // La hate : le canal qui DIVISE le temps d'attaque, sans reecrire
            // la cadence de reference du gabarit.
            me->ApplyAttackTimePercentMod(BASE_ATTACK, TYRAN_HATE, true);
        }

        // La cible du demoniste AU MOMENT DE L'INVOCATION, retenue puis
        // attaquee au premier tour — le procede exact de la goule du DK.
        void IsSummonedBy(WorldObject* invocateur) override
        {
            if (invocateur && invocateur->IsPlayer())
                if (Unit* victime = invocateur->ToPlayer()->GetVictim())
                    _cible = victime->GetGUID();
        }

        void UpdateAI(uint32 diff) override
        {
            if (!_cible.IsEmpty())
            {
                if (Unit* cible = ObjectAccessor::GetUnit(*me, _cible))
                    if (cible->IsAlive() && me->IsValidAttackTarget(cible))
                        AttackStart(cible);
                _cible.Clear();
            }
            CombatAI::UpdateAI(diff);
        }

        // CHAQUE ATTAQUE renforce les demons. On ne retient que les coups
        // DIRECTS : les battements des flammes passent aussi par ici, et
        // renforceraient les demons deux fois par seconde.
        void DamageDealt(Unit* /*victime*/, uint32& /*degats*/,
                         DamageEffectType type,
                         SpellSchoolMask /*ecole*/) override
        {
            if (type != DIRECT_DAMAGE)
                return;
            Unit* maitre = me->GetOwner();
            if (!maitre)
                return;

            std::vector<Unit*> demons;
            RassembleDemons(maitre, demons);
            for (Unit* demon : demons)
            {
                uint32 const bonus = BonusDuDemon(demon, maitre);
                if (!bonus)
                    continue;

                // CUMULABLE : on relance, le cumul monte d'un cran.
                // NON CUMULABLE : on ne relance PAS si l'aura est deja la —
                // sinon « non cumulable » deviendrait « renouvele a chaque
                // coup », ce qui rendrait par exemple le bouclier du marcheur
                // du vide perpetuellement plein.
                SpellInfo const* infos = sSpellMgr->GetSpellInfo(bonus);
                bool const cumulable = infos && infos->StackAmount > 1;
                if (cumulable || !demon->HasAura(bonus, me->GetGUID()))
                {
                    me->CastSpell(demon, bonus, true);
                    if (bonus == TYRAN_MARCHEUR)
                    {
                        // LE MONTANT DU BOUCLIER, regle sur l'aura une fois
                        // posee. CastCustomSpell aurait du suffire — le coeur
                        // s'en sert ainsi — mais en jeu le bouclier valait 0 a
                        // 1 point, soit exactement ce que donne le DBC seul
                        // (base 0 + un de 1) : la valeur custom n'arrivait pas.
                        // Ecrire le montant sur l'effet ne laisse aucun doute.
                        if (Aura* aura = demon->GetAura(TYRAN_MARCHEUR, me->GetGUID()))
                            if (AuraEffect* bouclier = aura->GetEffect(EFFECT_1))
                                bouclier->SetAmount(int32(
                                    demon->CountPctFromMaxHealth(TYRAN_PART_BOUCLIER)));
                    }
                }

                // Deux demons ont un SECOND bonus, fixe celui-la : il vit a
                // part parce qu'il ne doit PAS suivre les cumuls du premier.
                if (bonus == TYRAN_CHAINES
                    && !demon->HasAura(TYRAN_BRISEES, me->GetGUID()))
                    me->CastSpell(demon, TYRAN_BRISEES, true);
                if (bonus == TYRAN_GARDE_HATE
                    && !demon->HasAura(TYRAN_GARDE, me->GetGUID()))
                    me->CastSpell(demon, TYRAN_GARDE, true);

                // Et la taille, pour tout demon renforce.
                if (!demon->HasAura(TYRAN_TAILLE, me->GetGUID()))
                    me->CastSpell(demon, TYRAN_TAILLE, true);
            }

            // LE DEMONISTE SOUS METAMORPHOSE. On reverifie a chaque coup, et
            // non une fois a l'invocation : la forme peut etre endossee APRES
            // l'arrivee du tyran, et elle compte alors ; si elle s'acheve
            // avant lui, les bonus tombent aussitot.
            if (maitre->HasAura(METAMORPHOSE))
            {
                me->CastSpell(maitre, TYRAN_META_CUMUL, true);
                if (!maitre->HasAura(TYRAN_META_FIXE, me->GetGUID()))
                    me->CastSpell(maitre, TYRAN_META_FIXE, true);
            }
            else
                for (uint32 bonus : TYRAN_BONUS_MAITRE)
                    maitre->RemoveAurasDueToSpell(bonus);
        }

        void JustDied(Unit* tueur) override
        {
            CombatAI::JustDied(tueur);
            // On ne fait pas le menage ici : on retire l'aura du demoniste,
            // et c'est ELLE qui reprend les bonus. Un seul chemin, donc pas
            // de moitie de menage si l'un des deux cas est oublie.
            if (Unit* maitre = me->GetOwner())
                maitre->RemoveAurasDueToSpell(TYRAN);
            // Le corps ne traine pas, comme celui de la goule du DK.
            if (me->IsGuardian() || me->IsSummon())
                me->ToTempSummon()->UnSummon();
        }

    };

    // =======================================================================
    // Ruee sauvage — toute l'ecurie surgit
    // =======================================================================
    constexpr uint32 RUEE_DUREE = 30000;         // ms — miroir du DBC (D_30S,
                                                 // porté de 12 à 30 s le
                                                 // 2026-08-31)
    constexpr float RUEE_RAYON = 4.0f;           // l'anneau autour de la proie
    constexpr uint32 RUEE_FRENESIE = 8600095;    // l'aura de proc posée sur
                                                 // les betes : chaque coup
                                                 // declenche le saignement
                                                 // 8600094 (cumulable)
    // LA BETE DE MEUTE (2026-08-31) : NOTRE creature, portant l'IA
    // npc_papota_meute, calquee sur le patron eprouve du module (goule 803801). Deux tentatives ont echoue avant : invoquer
    // l'entree du familier donnait des betes au gabarit sauvage dont l'IA
    // n'appelle jamais DoMeleeAttackIfReady, donc AUCUNE attaque, ni par
    // AttackStart ni par Unit::Attack. Cette IA attaque la cible du maitre et
    // REPREND LA SIENNE des que la proie tombe : la surveillance maison,
    // devenue inutile, est retiree.
    constexpr uint32 RUEE_BETE = 803811;
    constexpr float RUEE_DIVISEUR = 2.5f;        // degats d'arme des betes :
                                                 // 1/5 des ceux du familier
                                                 // le 2026-08-31, puis
                                                 // DOUBLES le meme jour
    class spell_papota_ruee_sauvage : public SpellScript
    {
        PrepareSpellScript(spell_papota_ruee_sauvage);

        // Sans bete sortie, le sort est REFUSE au lancement (2026-08-31) :
        // il ne partait qu'en pure perte, recharge comprise.
        SpellCastResult Verifier()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur || !joueur->GetPet())
                return SPELL_FAILED_NO_PET;
            return SPELL_CAST_OK;
        }

        void Deferler()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur)
                return;

            Pet* familier = joueur->GetPet();
            if (!familier)
                return;                          // sans bete, rien a appeler

            // La proie : la cible du sort d'abord, celle du chasseur ensuite,
            // celle de la bete en dernier — « les invocations ne font rien »
            // venait de la seule GetVictim(), vide hors combat (2026-08-31).
            Unit* proie = GetExplTargetUnit();
            if (!proie || !joueur->IsValidAttackTarget(proie))
                proie = joueur->GetVictim();
            if (!proie)
                proie = familier->GetVictim();

            // Elles surgissent AUTOUR DE LA PROIE (2026-08-31) ; a defaut de
            // proie, autour du chasseur.
            WorldObject* pivot = proie ? static_cast<WorldObject*>(proie)
                                       : static_cast<WorldObject*>(joueur);
            for (uint8 i = 0; i < 3; ++i)
            {
                Position pos = pivot->GetPosition();
                pivot->MovePositionToFirstCollision(pos, RUEE_RAYON,
                                                    float(i) * 2.0f * float(M_PI) / 3.0f);
                // NOTRE bete (803811, IA npc_papota_meute) — pas
                // l'entree du familier : c'est l'IA qui fait frapper.
                Creature* copie = joueur->SummonCreature(RUEE_BETE, pos,
                    TEMPSUMMON_TIMED_DESPAWN, RUEE_DUREE);
                if (!copie)
                    continue;
                // Tout le reste — faction, niveau, apparence et chiffres du
                // familier, frenesie, ciblage, retour au chasseur — vit dans
                // l'IA npc_papota_meute, calquee sur le piege a serpents.
                if (proie && copie->IsAIEnabled)
                    copie->AI()->AttackStart(proie);
            }
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_papota_ruee_sauvage::Verifier);
            AfterCast += SpellCastFn(spell_papota_ruee_sauvage::Deferler);
        }
    };

    // =======================================================================
    // Tirs consecutifs — le personnage tire a chaque salve
    // =======================================================================
    // Trois canaux essayes : l'attribut d'arme a distance seul (anime le
    // LANCEMENT, donc une fois), l'emote a chaque tic (ignoree pendant une
    // canalisation : plus rien du tout), et le sort DECLENCHE (le missile
    // part, le personnage reste statique — un cast declenche ne rejoue pas
    // l'animation). Reste le canal des KITS, prouve sur le bond heroique et
    // la Marque : un kit nu ne portant QUE l'animation, envoye a chaque tic
    // et choisi selon l'arme portee.
    constexpr uint32 TIR_KIT_ARC = 30040;      // AttackBow 46
    constexpr uint32 TIR_KIT_FUSIL = 30041;    // AttackRifle 49
    constexpr uint32 TIR_KIT_JET = 30042;      // AttackThrown 107

    // Les TRAITS FICHES (2026-08-31) : chaque salve empile le debuff porte
    // par le tir 8600096 ; a son EXPIRATION SEULEMENT, les traits detonent
    // dans 8 m pour un montant proportionnel au nombre de cumuls.
    constexpr uint32 TIR_DETONATION = 8600098;
    // LE CANAL TIRE SIX SALVES : trois secondes, un tic toutes les cinq
    // centiemes. C'est donc six piles au plus sur la cible.
    constexpr int32 TIR_SALVES = 6;

    class spell_papota_traits_fiches : public AuraScript
    {
        PrepareAuraScript(spell_papota_traits_fiches);

        void Detoner(AuraEffect const* /*effet*/,
                     AuraEffectHandleModes /*mode*/)
        {
            // A l'expiration seule : une cible qui meurt ou qu'on purge ne
            // fait pas sauter la charge (patron du temoin du Miroitement).
            if (GetTargetApplication()->GetRemoveMode()
                != AURA_REMOVE_BY_EXPIRE)
                return;
            Unit* chasseur = GetCaster();
            Unit* cible = GetTarget();
            if (!chasseur || !cible)
                return;
            // LE MONTANT VIENT DU DBC de la detonation, la ou le bareme
            // d'equilibrage l'ecrit : le script ne fait que le repartir sur
            // les piles reellement posees. Un nombre en dur ici echapperait
            // a l'equilibrage — c'etait le cas jusqu'au 2026-09-04.
            int32 plein = 0;
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(TIR_DETONATION))
                plein = info->Effects[EFFECT_0].CalcValue();
            int32 degats = plein * int32(GetStackAmount()) / TIR_SALVES;
            chasseur->CastCustomSpell(cible, TIR_DETONATION, &degats, nullptr,
                                      nullptr, true);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_papota_traits_fiches::Detoner, EFFECT_1,
                SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        }
    };

    class spell_papota_tirs_consecutifs : public AuraScript
    {
        PrepareAuraScript(spell_papota_tirs_consecutifs);

        void Tirer(AuraEffect const* /*effet*/)
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur)
                return;
            uint32 kit = TIR_KIT_ARC;
            if (Item* arme = joueur->GetWeaponForAttack(RANGED_ATTACK))
                switch (arme->GetTemplate()->SubClass)
                {
                    case ITEM_SUBCLASS_WEAPON_GUN:
                        kit = TIR_KIT_FUSIL;
                        break;
                    case ITEM_SUBCLASS_WEAPON_THROWN:
                        kit = TIR_KIT_JET;
                        break;
                    default:            // arc et arbalete
                        break;
                }
            joueur->SendPlaySpellVisual(kit);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_papota_tirs_consecutifs::Tirer, EFFECT_0,
                SPELL_AURA_PERIODIC_TRIGGER_SPELL);
        }
    };

    // =======================================================================
    // Charge sauvage — le bond change avec la forme
    // =======================================================================
    // =======================================================================
    // Charge sauvage (8600090) — refonte du 2026-09-03
    // =======================================================================
    // UN SEUL BOUTON, six comportements selon la forme, empruntes aux sorts
    // de deplacement des autres classes :
    //
    //   aucune (humaine)  sprint de 3 s, +50 % de vitesse (aura 8610013)
    //   ours              le bond du guerrier, vers le point vise
    //   felin             la teleportation du voleur, vers le point vise
    //   voyage            un bond vers le point vise
    //   arbre de vie      teleportation sur l'allie le plus proche du point
    //   selenien          retour a l'etoile la plus recente
    //
    // Le sort est VISE AU SOL pour toutes les formes : l'ours et le felin se
    // visent chez leurs proprietaires, et un reticule ne peut pas etre
    // conditionnel. Le sprint et le retour a l'etoile ignorent donc le point.
    constexpr uint32 CHARGE_SAUVAGE = 8600090;
    // Les cinq sorts de forme, accordes avec le sort du spherier : un noeud
    // n'en enseigne qu'un, et le bloc numerique du druide est plein.
    constexpr uint32 CHARGE_FORMES[] = { 8610016, 8610017, 8610018,
                                         8610019, 8610020 };
    constexpr uint32 CHARGE_SILLAGE = 8610014;        // l'aura qui seme
    // LES TROIS COULEURS, dans l'ordre du RANG depuis la fin du sillage :
    // l'etoile la plus recente est verte, celle du milieu jaune, la plus
    // ancienne rouge. L'indice dans ce tableau EST le rang, ce qui rend la
    // repeinte immediate a chaque changement.
    //
    // Ce sont des APPARENCES DE CREATURE, pas des auras. Les deux premiers
    // essais posaient le modele par une aura a kit d'etat et rien ne
    // s'affichait : la creature-etoile portait l'apparence 802102, c'est-a-
    // dire InvisibleStalker — le client n'avait aucun corps sur quoi
    // accrocher le kit. La creature EST desormais l'etoile.
    constexpr uint32 CHARGE_ETOILE_APPARENCES[3] = { 802105, 802104, 802103 };
    constexpr uint32 CHARGE_ETOILE_COMPTE = 8610024;  // le compteur, visible

    // LA MARQUE DE DEPART : posee la ou le druide etait, avant qu'il ne
    // parte, et qui s'efface au bout de deux secondes.
    constexpr uint32 CHARGE_DEPART_CREATURE = 803817;
    constexpr uint32 CHARGE_DEPART_DUREE = 2000;      // ms
    constexpr uint32 CHARGE_ETOILE_CREATURE = 803816;
    constexpr float CHARGE_ARBRE_PORTEE = 40.0f;      // pour l'allie
    constexpr float CHARGE_ETOILE_ECART = 20.0f;      // entre deux etoiles
    // L'ELAN DU VOYAGEUR (2026-09-03) va DEUX FOIS plus loin et deux fois
    // plus vite que le bond commun, sa parabole montant de moitie en plus.
    constexpr float VOYAGE_DISTANCE = BOND_DISTANCE * 2.0f;
    constexpr float VOYAGE_VITESSE = BOND_VITESSE * 2.0f;
    constexpr float VOYAGE_HAUTEUR = BOND_HAUTEUR * 1.5f;
    constexpr uint32 CHARGE_ETOILES_MAX = 3;

    // LE SILLAGE : par joueur, les etoiles de la plus ancienne a la plus
    // recente. Elles ne s'effacent pas avec le temps — seul le retour du
    // druide, ou l'arrivee d'une quatrieme, en reprend une. La liste vit en
    // memoire : un sillage ne survit pas a un redemarrage, ce qui est sans
    // consequence puisque les creatures non plus.
    std::unordered_map<ObjectGuid, std::deque<ObjectGuid>> g_etoiles;

    Creature* EtoileDe(Unit* ou, ObjectGuid guid)
    {
        return guid ? ObjectAccessor::GetCreature(*ou, guid) : nullptr;
    }

    // Reprend une etoile : la creature s'en va, la liste l'oublie.
    void RepliEtoile(Unit* ou, std::deque<ObjectGuid>& sillage, bool derniere)
    {
        while (!sillage.empty())
        {
            ObjectGuid guid = derniere ? sillage.back() : sillage.front();
            if (derniere)
                sillage.pop_back();
            else
                sillage.pop_front();
            if (Creature* etoile = EtoileDe(ou, guid))
            {
                etoile->DespawnOrUnsummon();
                return;
            }
            // Creature disparue autrement (changement de carte) : on passe a
            // la suivante plutot que de rendre un sillage muet.
        }
    }

    // LA REPEINTE : chaque etoile prend l'apparence de son rang. On ne la
    // repose pas si elle l'a deja — sans quoi le modele repartirait de son
    // premier temps d'animation a chaque battement du sillage.
    void RepeintSillage(Unit* ou, std::deque<ObjectGuid> const& sillage)
    {
        for (size_t i = 0; i < sillage.size(); ++i)
        {
            Creature* etoile = EtoileDe(ou, sillage[sillage.size() - 1 - i]);
            if (!etoile)
                continue;
            uint32 voulue = CHARGE_ETOILE_APPARENCES[i < 3 ? i : 2];
            if (etoile->GetDisplayId() != voulue)
                etoile->SetDisplayId(voulue);
        }
    }

    // LE COMPTEUR : une pile par etoile posee, sur le druide. Il disparait
    // quand il n'en reste aucune.
    void MajCompteur(Player* joueur, size_t nombre)
    {
        if (!joueur)
            return;
        if (!nombre)
        {
            joueur->RemoveAurasDueToSpell(CHARGE_ETOILE_COMPTE);
            return;
        }
        if (!joueur->HasAura(CHARGE_ETOILE_COMPTE))
            joueur->CastSpell(joueur, CHARGE_ETOILE_COMPTE, true);
        if (Aura* aura = joueur->GetAura(CHARGE_ETOILE_COMPTE))
            aura->SetStackAmount(uint8(nombre));
    }

    // TOUT LE SILLAGE REPRIS d'un coup. Le druide quitte la forme ou se
    // deconnecte : il ne doit rien rester sur le terrain, ni compteur au
    // dessus de sa tete.
    void EffaceSillage(Player* joueur)
    {
        auto it = g_etoiles.find(joueur->GetGUID());
        if (it != g_etoiles.end())
        {
            for (ObjectGuid guid : it->second)
                if (Creature* etoile = ObjectAccessor::GetCreature(*joueur,
                                                                   guid))
                    etoile->DespawnOrUnsummon();
            g_etoiles.erase(it);
        }
        joueur->RemoveAurasDueToSpell(CHARGE_ETOILE_COMPTE);
    }

    // Ce qui suit TOUTE modification du sillage : les couleurs et le compte.
    void SillageChange(Player* joueur, std::deque<ObjectGuid> const& sillage)
    {
        RepeintSillage(joueur, sillage);
        MajCompteur(joueur, sillage.size());
    }

    // L'ALLIE VISE, et la teleportation sur lui : la forme d'arbre est la
    // seule des six a prendre une unite pour cible, le sort la lui donne.
    void VersAllie(Unit* lanceur, Unit* allie)
    {
        Player* joueur = lanceur ? lanceur->ToPlayer() : nullptr;
        if (!joueur || !allie || !allie->IsAlive())
            return;
        joueur->NearTeleportTo(allie->GetPositionX(), allie->GetPositionY(),
                               allie->GetPositionZ(), joueur->GetOrientation());
    }

    // LE RETOUR : a l'etoile la plus recente, qui est alors reprise. Le
    // lancer suivant remonte donc a la precedente, « de plus en plus loin ».
    void RetourEtoile(Unit* lanceur)
    {
        Player* joueur = lanceur ? lanceur->ToPlayer() : nullptr;
        auto it = joueur ? g_etoiles.find(joueur->GetGUID()) : g_etoiles.end();
        if (it == g_etoiles.end())
            return;
        Creature* etoile = nullptr;
        while (!it->second.empty() && !etoile)
        {
            etoile = EtoileDe(joueur, it->second.back());
            if (!etoile)
                it->second.pop_back();
        }
        if (!etoile)
            return;
        // LA MARQUE DE DEPART est posee AVANT le depart, a l'endroit que le
        // druide quitte. Sa creature porte deja la bonne apparence et son
        // minuteur d'invocation la reprend au bout de deux secondes : rien
        // a chronometrer ici.
        joueur->SummonCreature(CHARGE_DEPART_CREATURE, *joueur,
                               TEMPSUMMON_TIMED_DESPAWN,
                               CHARGE_DEPART_DUREE);

        joueur->NearTeleportTo(etoile->GetPositionX(), etoile->GetPositionY(),
                               etoile->GetPositionZ(), joueur->GetOrientation());
        it->second.pop_back();
        etoile->DespawnOrUnsummon();
        SillageChange(joueur, it->second);
    }

    // LA PETITE FOULEE (8600090) rend d'abord la forme humaine. Le DBC savait
    // REFUSER le lancement sous forme — l'attribut SPELL_ATTR0_NOT_SHAPESHIFTED
    // que le sort portait jusqu'ici — mais pas detransformer. L'attribut est
    // donc retire et c'est le script qui rend la forme, avant que l'aura de
    // vitesse ne se pose.
    class spell_papota_petite_foulee : public SpellScript
    {
        PrepareSpellScript(spell_papota_petite_foulee);

        void Rendre()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (joueur && joueur->GetShapeshiftForm() != FORM_NONE)
                joueur->RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT);
        }

        void Register() override
        {
            BeforeCast += SpellCastFn(spell_papota_petite_foulee::Rendre);
        }
    };

    // L'OURS : le bond du guerrier, a l'identique.
    class spell_papota_charge_ours : public SpellScript
    {
        PrepareSpellScript(spell_papota_charge_ours);

        void Bondir(SpellEffIndex /*index*/)
        {
            BondHeroique(GetCaster(), GetExplTargetDest(),
                         GetSpellInfo()->SpellVisual[0]);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_papota_charge_ours::Bondir,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // LE FELIN : la translation du voleur.
    class spell_papota_charge_felin : public SpellScript
    {
        PrepareSpellScript(spell_papota_charge_felin);

        void Filer(SpellEffIndex /*index*/)
        {
            TranslationVoleur(GetCaster(), GetExplTargetDest());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_charge_felin::Filer,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // LA FORME DE VOYAGE : le bond directionnel, la regle commune du chantier.
    class spell_papota_charge_voyage : public SpellScript
    {
        PrepareSpellScript(spell_papota_charge_voyage);

        void Bondir(SpellEffIndex /*index*/)
        {
            if (Unit* lanceur = GetCaster())
                BondirVers(lanceur, AngleDeplacement(lanceur),
                           VOYAGE_DISTANCE, false, VOYAGE_VITESSE,
                           VOYAGE_HAUTEUR);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_papota_charge_voyage::Bondir,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // L'ARBRE DE VIE : la teleportation sur l'allie vise.
    class spell_papota_charge_arbre : public SpellScript
    {
        PrepareSpellScript(spell_papota_charge_arbre);

        void Rejoindre(SpellEffIndex /*index*/)
        {
            VersAllie(GetCaster(), GetHitUnit());
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_papota_charge_arbre::Rejoindre,
                                               EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // LE SELENIEN : le retour a l'etoile. Sans recharge, mais refuse s'il n'y
    // en a aucune — le refus tombe AVANT le cout et le temps d'incantation.
    class spell_papota_charge_selenien : public SpellScript
    {
        PrepareSpellScript(spell_papota_charge_selenien);

        SpellCastResult Verifier()
        {
            Unit* lanceur = GetCaster();
            if (!lanceur)
                return SPELL_CAST_OK;
            auto it = g_etoiles.find(lanceur->GetGUID());
            if (it != g_etoiles.end() && !it->second.empty())
                return SPELL_CAST_OK;
            SetCustomCastResultMessage(SPELL_CUSTOM_ERROR_NO_VALID_TARGETS);
            return SPELL_FAILED_CUSTOM_ERROR;
        }

        void Revenir(SpellEffIndex /*index*/)
        {
            RetourEtoile(GetCaster());
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_papota_charge_selenien::Verifier);
            OnEffectLaunch += SpellEffectFn(spell_papota_charge_selenien::Revenir,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // LE SILLAGE D'ETOILES (8610014). Une aura PERMANENTE et SANS ICONE, posee
    // sur tout druide qui connait la Charge sauvage : elle bat toutes les cinq
    // secondes et ne fait rien tant qu'il n'est pas selenien. C'est ce qui
    // evite d'avoir a guetter les changements de forme, qui n'ont pas de
    // point d'accroche commode.
    class spell_papota_etoiles : public AuraScript
    {
        PrepareAuraScript(spell_papota_etoiles);

        void Semer(AuraEffect const* /*effet*/)
        {
            PreventDefaultAction();
            Player* joueur = GetTarget() ? GetTarget()->ToPlayer() : nullptr;
            if (!joueur)
                return;

            // HORS FORME DE SELENIEN, plus d'etoiles. C'est l'aura de la
            // forme elle-meme qui les reprend a l'instant ou elle tombe
            // (spell_papota_forme_selenien) ; ce battement n'est qu'un filet
            // de securite, pour le cas ou un chemin nous echapperait.
            if (joueur->GetShapeshiftForm() != FORM_MOONKIN)
            {
                auto it = g_etoiles.find(joueur->GetGUID());
                if (it != g_etoiles.end() && !it->second.empty())
                    EffaceSillage(joueur);
                return;
            }
            if (!joueur->IsAlive())
                return;

            auto& sillage = g_etoiles[joueur->GetGUID()];

            // LA REGLE DES DIX METRES : trop pres de la derniere, aucune
            // etoile ne parait — et elle paraitra des qu'il s'en sera
            // eloigne, puisqu'on reessaie a chaque battement.
            while (!sillage.empty() && !EtoileDe(joueur, sillage.back()))
                sillage.pop_back();
            if (!sillage.empty())
                if (Creature* derniere = EtoileDe(joueur, sillage.back()))
                    if (joueur->GetExactDist(derniere) < CHARGE_ETOILE_ECART)
                        return;

            Creature* etoile = joueur->SummonCreature(CHARGE_ETOILE_CREATURE,
                *joueur, TEMPSUMMON_MANUAL_DESPAWN);
            if (!etoile)
                return;
            sillage.push_back(etoile->GetGUID());

            // LA QUATRIEME chasse la plus ancienne.
            while (sillage.size() > CHARGE_ETOILES_MAX)
                RepliEtoile(joueur, sillage, false);

            // La lueur lunaire est posee par la repeinte, en kit d'ETAT :
            // elle tient tant que l'aura tient, et l'aura est permanente.
            SillageChange(joueur, sillage);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_papota_etoiles::Semer,
                                                     EFFECT_0,
                                                     SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // LA FORME QUITTEE EFFACE LE SILLAGE, a l'instant meme. Le battement de
    // 8610014 ne suffisait pas : il ne passe que toutes les cinq secondes, et
    // l'infobulle promet que les etoiles s'en vont DES que le druide n'est
    // plus selenien. On s'accroche donc a l'aura de la forme elle-meme — le
    // sort natif 24858, dont l'effet 0 porte SPELL_AURA_MOD_SHAPESHIFT vers
    // la forme 31 (releve du 2026-09-04). L'accroche vit dans le SQL du
    // module, le generateur ne nommant que nos propres sorts.
    class spell_papota_forme_selenien : public AuraScript
    {
        PrepareAuraScript(spell_papota_forme_selenien);

        void Quitter(AuraEffect const* /*effet*/,
                     AuraEffectHandleModes /*mode*/)
        {
            if (Player* joueur = GetTarget() ? GetTarget()->ToPlayer()
                                             : nullptr)
                EffaceSillage(joueur);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_papota_forme_selenien::Quitter, EFFECT_0,
                SPELL_AURA_MOD_SHAPESHIFT, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Frenesie farouche — cinq paliers selon les points de combo
    // =======================================================================
    // Le DBC ne sait pas se brancher sur les points de combo : le sort ne
    // porte que son effet de degats, et tout le palier vit ici. Les points
    // sont CONSOMMES, comme pour tout coup de finition.
    constexpr uint32 FRENESIE_PLAIE = 8610026;
    constexpr uint32 FRENESIE_HATE = 8610027;
    constexpr uint32 FRENESIE_CRITIQUE = 8610028;

    struct FrenesiePalier
    {
        int32 coup, saignee, hate;
        uint32 energie;
        bool critique;
    };
    constexpr FrenesiePalier FRENESIE_PALIERS[5] =
    {
        {  700,   0,  0,  0, false },
        {  800, 120,  0,  0, false },
        { 1000, 160,  5,  0, false },
        { 1100, 200,  7, 10, false },
        { 1200, 240, 10, 15, true  },
    };

    class spell_papota_frenesie : public SpellScript
    {
        PrepareSpellScript(spell_papota_frenesie);

        uint8 _points = 0;

        SpellCastResult Verifier()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur || !joueur->GetComboPoints())
                return SPELL_FAILED_NO_COMBO_POINTS;
            return SPELL_CAST_OK;
        }

        // On RELEVE les points avant le lancement et on ne les reprend qu'a
        // la fin : les vider tout de suite priverait l'effet de son palier.
        void Compter()
        {
            if (Player* joueur = GetCaster() ? GetCaster()->ToPlayer()
                                             : nullptr)
                _points = std::min<uint8>(joueur->GetComboPoints(), 5);
        }

        void Frapper(SpellEffIndex /*index*/)
        {
            if (!_points)
                return;
            FrenesiePalier const& palier = FRENESIE_PALIERS[_points - 1];
            SetHitDamage(palier.coup);

            Unit* lanceur = GetCaster();
            Unit* cible = GetHitUnit();
            if (lanceur && cible && palier.saignee)
            {
                int32 saignee = palier.saignee;
                lanceur->CastCustomSpell(cible, FRENESIE_PLAIE, &saignee,
                                         nullptr, nullptr, true);
            }
        }

        void Recompenser()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur || !_points)
                return;
            FrenesiePalier const& palier = FRENESIE_PALIERS[_points - 1];
            if (palier.hate)
            {
                int32 hate = palier.hate;
                joueur->CastCustomSpell(joueur, FRENESIE_HATE, &hate,
                                        nullptr, nullptr, true);
            }
            if (palier.energie)
                joueur->EnergizeBySpell(joueur, GetSpellInfo()->Id,
                                        palier.energie, POWER_ENERGY);
            if (palier.critique)
                joueur->CastSpell(joueur, FRENESIE_CRITIQUE, true);
            joueur->ClearComboPoints();
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_papota_frenesie::Verifier);
            BeforeCast += SpellCastFn(spell_papota_frenesie::Compter);
            OnEffectHitTarget += SpellEffectFn(spell_papota_frenesie::Frapper,
                                               EFFECT_0,
                                               SPELL_EFFECT_SCHOOL_DAMAGE);
            AfterCast += SpellCastFn(spell_papota_frenesie::Recompenser);
        }
    };

    // =======================================================================
    // Solstice et Équinoxe — la jauge celeste
    // =======================================================================
    // REFONTE DU 2026-09-04, sur le modele de l'Eclipse de Cataclysm. La
    // Pleine lune et son cycle a trois phases ont laisse place a une jauge de
    // SEPT CRANS, de la lune (-3) au soleil (+3), le centre a zero : SIX
    // lancers d'une limite a l'autre, un cran par sort.
    //
    //   * un sort de degats magiques d'ARCANES pousse d'UN cran vers la
    //     LUNE ; un sort de NATURE, d'UN cran vers le SOLEIL — meme pas des
    //     deux cotes depuis le 2026-09-04 ;
    //   * atteindre un bout donne six secondes de bienfait — et c'est
    //     l'ecole OPPOSEE a celle qui a pousse qui est recompensee, ce qui
    //     oblige a faire le va-et-vient ;
    //   * UN BOUT ATTEINT VERROUILLE SON COTE : tant que l'autre n'est pas
    //     touche, les sorts qui pousseraient vers lui ne font plus rien du
    //     tout — ni deplacement, ni pile gagnee ou perdue ;
    //   * CHAQUE LIMITE ATTEINTE ouvre cinq secondes pour lancer le sort
    //     (2026-09-04 : c'etait auparavant le passage par le centre).
    //
    // La jauge vit dans DEUX auras — lunaire et solaire, une a trois piles
    // chacune. Au centre, le joueur n'en porte aucune.
    //
    // ELLES DOIVENT RESTER VISIBLES. Marquees SPELL_ATTR1_NO_AURA_ICON le
    // 2026-09-04 pour desencombrer la barre de bienfaits, elles ont cesse
    // d'etre rendues par UnitBuff cote client et le curseur s'est fige au
    // centre. Le masquage a ete repris.
    constexpr uint32 SOLSTICE = 8600092;
    constexpr uint32 SOLSTICE_SOLEIL = 8610029;    // le bout du soleil
    constexpr uint32 SOLSTICE_LUNE = 8610030;      // le bout de la lune
    constexpr uint32 SOLSTICE_FENETRE = 8610031;   // cinq secondes pour agir
    constexpr uint32 SOLSTICE_USE_SOLEIL = 8610034; // le soleil est epuise
    constexpr uint32 SOLSTICE_USE_LUNE = 8610035;   // la lune est epuisee
    constexpr uint32 SOLSTICE_JAUGE_LUNE = 8610032;   // 1 a 6 vers la lune
    constexpr uint32 SOLSTICE_JAUGE_SOLEIL = 8610033; // 1 a 6 vers le soleil
    constexpr int8 SOLSTICE_BOUT = 3;              // crans par moitie
    constexpr int8 SOLSTICE_PAS = 1;              // un cran par sort

    struct JaugeCeleste
    {
        int8 curseur = 0;    // -3 lune ... 0 centre ... +3 soleil
        int8 dernier = 0;    // le dernier bout atteint : -1, 0 ou +1
    };
    std::unordered_map<ObjectGuid, JaugeCeleste> g_jauges;

    class papota_solstice_joueur : public PlayerScript
    {
    public:
        papota_solstice_joueur() : PlayerScript("papota_solstice_joueur",
            {
                PLAYERHOOK_ON_SPELL_CAST,
                PLAYERHOOK_ON_PLAYER_JUST_DIED,
                PLAYERHOOK_ON_LOGIN,
                PLAYERHOOK_ON_LOGOUT
            }) { }

        void OnPlayerLogin(Player* joueur) override { Poser(joueur); }

        // LA JAUGE NE SURVIT NI A LA MORT NI A LA DECONNEXION, mais elle
        // traverse le hors-combat sans broncher.
        void OnPlayerJustDied(Player* joueur) override { Vider(joueur); }
        void OnPlayerLogout(Player* joueur) override { Vider(joueur); }

        void OnPlayerSpellCast(Player* joueur, Spell* sort,
                               bool /*skipCheck*/) override
        {
            if (!joueur || !sort || !Concerne(joueur))
                return;
            SpellInfo const* info = sort->GetSpellInfo();
            if (!info || info->Id == SOLSTICE)
            {
                // LE SORT LUI-MEME NE POUSSE PAS le curseur, mais il consomme
                // sa fenetre : le DBC sait l'exiger, pas la reprendre.
                if (info && info->Id == SOLSTICE)
                    joueur->RemoveAurasDueToSpell(SOLSTICE_FENETRE);
                return;
            }
            if (info->DmgClass != SPELL_DAMAGE_CLASS_MAGIC || !FaitDesDegats(info))
                return;

            // L'ecole decide du sens. Un sort a deux ecoles (rare) compte pour
            // celle qui vient en premier ; aucune n'est comptee deux fois.
            if (info->SchoolMask & SPELL_SCHOOL_MASK_ARCANE)
                Bouger(joueur, -SOLSTICE_PAS);          // vers la lune
            else if (info->SchoolMask & SPELL_SCHOOL_MASK_NATURE)
                Bouger(joueur, SOLSTICE_PAS);           // vers le soleil
        }

    private:
        // La jauge n'existe que pour un selenien qui connait le sort : c'est
        // la forme d'equilibre, et le sort ne se lance que la.
        static bool Concerne(Player* joueur)
        {
            return joueur->getClass() == CLASS_DRUID
                && joueur->HasSpell(SOLSTICE)
                && joueur->GetShapeshiftForm() == FORM_MOONKIN;
        }

        static bool FaitDesDegats(SpellInfo const* info)
        {
            for (uint8 i = EFFECT_0; i < MAX_SPELL_EFFECTS; ++i)
            {
                if (info->Effects[i].Effect == SPELL_EFFECT_SCHOOL_DAMAGE)
                    return true;
                if (info->Effects[i].ApplyAuraName == SPELL_AURA_PERIODIC_DAMAGE)
                    return true;
            }
            return false;
        }

        static void Poser(Player* joueur)
        {
            if (!joueur || joueur->getClass() != CLASS_DRUID)
                return;
            // LA JAUGE REPART DE ZERO A LA CONNEXION, AURAS COMPRISES. Le
            // coeur SAUVE les auras avant d'appeler le crochet de deconnexion
            // qui les retire (WorldSession::LogoutPlayer : SaveToDB puis
            // OnPlayerLogout) : un astre epuise avant de se deconnecter
            // revenait avec sa fleche, alors que la jauge en memoire
            // repartait du centre (2026-09-06). spell_custom_attr les marque
            // desormais « jamais sauvees » ; ceci ratisse ce qui l'a ete avant.
            joueur->RemoveAurasDueToSpell(SOLSTICE_SOLEIL);
            joueur->RemoveAurasDueToSpell(SOLSTICE_LUNE);
            joueur->RemoveAurasDueToSpell(SOLSTICE_FENETRE);
            joueur->RemoveAurasDueToSpell(SOLSTICE_USE_SOLEIL);
            joueur->RemoveAurasDueToSpell(SOLSTICE_USE_LUNE);
            if (joueur->HasSpell(SOLSTICE))
                Ecrire(joueur, g_jauges[joueur->GetGUID()].curseur);
        }

        static void Vider(Player* joueur)
        {
            g_jauges.erase(joueur->GetGUID());
            joueur->RemoveAurasDueToSpell(SOLSTICE_JAUGE_LUNE);
            joueur->RemoveAurasDueToSpell(SOLSTICE_JAUGE_SOLEIL);
            joueur->RemoveAurasDueToSpell(SOLSTICE_FENETRE);
            joueur->RemoveAurasDueToSpell(SOLSTICE_USE_SOLEIL);
            joueur->RemoveAurasDueToSpell(SOLSTICE_USE_LUNE);
        }

        // LA PILE PORTE LE CRAN, de une a six, dans celle des deux auras qui
        // correspond au cote ou se trouve le curseur. Au centre, aucune.
        // C'est par la que la barre du client apprend ou en est le joueur.
        static void Ecrire(Player* joueur, int8 curseur)
        {
            uint8 const crans = uint8(curseur < 0 ? -curseur : curseur);
            uint32 const voulue = curseur < 0 ? SOLSTICE_JAUGE_LUNE
                                              : SOLSTICE_JAUGE_SOLEIL;
            if (!crans || voulue != SOLSTICE_JAUGE_LUNE)
                joueur->RemoveAurasDueToSpell(SOLSTICE_JAUGE_LUNE);
            if (!crans || voulue != SOLSTICE_JAUGE_SOLEIL)
                joueur->RemoveAurasDueToSpell(SOLSTICE_JAUGE_SOLEIL);
            if (!crans)
                return;
            if (!joueur->HasAura(voulue))
                joueur->CastSpell(joueur, voulue, true);
            if (Aura* aura = joueur->GetAura(voulue))
                aura->SetStackAmount(crans);
        }

        // LE VERROU, DIT AU CLIENT : l'astre epuise porte son aura tant que
        // l'autre n'est pas atteint. C'est elle que la barre lit pour
        // eteindre le bon cote — elle ne saurait pas le deduire seule.
        static void Verrouiller(Player* joueur, int8 cote)
        {
            joueur->RemoveAurasDueToSpell(cote > 0 ? SOLSTICE_USE_LUNE
                                                   : SOLSTICE_USE_SOLEIL);
            uint32 const aura = cote > 0 ? SOLSTICE_USE_SOLEIL
                                         : SOLSTICE_USE_LUNE;
            if (!joueur->HasAura(aura))
                joueur->CastSpell(joueur, aura, true);
        }

        // LA FENETRE : cinq secondes pour lancer le sort, ouvertes a CHAQUE
        // limite atteinte. Elle ne se cumule pas — la reposer remet
        // simplement les cinq secondes.
        static void Ouvrir(Player* joueur)
        {
            joueur->RemoveAurasDueToSpell(SOLSTICE_FENETRE);
            joueur->CastSpell(joueur, SOLSTICE_FENETRE, true);
        }

        static void Bouger(Player* joueur, int8 pas)
        {
            JaugeCeleste& jauge = g_jauges[joueur->GetGUID()];

            // LE VERROU DE DIRECTION : un bout atteint ferme son cote. On ne
            // repart que vers l'autre, et un sort qui pousserait a rebours
            // n'a plus aucun effet sur la jauge.
            if ((jauge.dernier > 0 && pas > 0)
                || (jauge.dernier < 0 && pas < 0))
                return;

            int8 const avant = jauge.curseur;
            int8 apres = int8(jauge.curseur + pas);
            if (apres > SOLSTICE_BOUT)
                apres = SOLSTICE_BOUT;
            else if (apres < -SOLSTICE_BOUT)
                apres = -SOLSTICE_BOUT;
            if (apres == avant)
                return;                     // deja au bout, rien ne bouge
            jauge.curseur = apres;

            // Le verrou ci-dessus garantit qu'on ne peut pas revenir sur un
            // bout sans avoir touche l'autre : arriver ici, c'est donc
            // toujours une PREMIERE fois.
            if (apres == SOLSTICE_BOUT)
            {
                joueur->CastSpell(joueur, SOLSTICE_SOLEIL, true);
                jauge.dernier = 1;
                Verrouiller(joueur, 1);
                Ouvrir(joueur);
            }
            else if (apres == -SOLSTICE_BOUT)
            {
                joueur->CastSpell(joueur, SOLSTICE_LUNE, true);
                jauge.dernier = -1;
                Verrouiller(joueur, -1);
                Ouvrir(joueur);
            }
            Ecrire(joueur, apres);
        }
    };

    // =======================================================================
    // Floraison — tous les soins en cours durent plus longtemps
    // =======================================================================
    // LA ZONE DE SOINS, posee aux pieds de la cible.
    constexpr uint32 FLORAISON_ZONE = 8610036;

    class spell_papota_floraison : public SpellScript
    {
        PrepareSpellScript(spell_papota_floraison);

        void Refleurir(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            Unit* cible = GetHitUnit();
            if (!lanceur || !cible)
                return;

            // REMISE A NEUF, et non plus rallonge : chaque soin sur la duree
            // repart a son maximum. SANS FILTRE DE LANCEUR (2026-09-04) —
            // ceux de « Liora, Berceuse des Racines » viennent de l'arme et
            // etaient laisses de cote par l'ancienne garde.
            for (auto const& paire : cible->GetAppliedAuras())
            {
                Aura* aura = paire.second->GetBase();
                if (!aura || !aura->GetSpellInfo())
                    continue;
                if (!aura->GetSpellInfo()->HasAura(SPELL_AURA_PERIODIC_HEAL))
                    continue;
                if (aura->GetMaxDuration() <= 0)
                    continue;               // une aura permanente n'a rien a
                                            // reprendre
                aura->SetDuration(aura->GetMaxDuration(), true);
            }

            // LA FLORAISON s'ouvre la ou la cible se tient. On passe par des
            // coordonnees plutot que par la cible : l'objet dynamique reste
            // au sol, il ne suit pas celui qu'on a soigne.
            lanceur->CastSpell(cible->GetPositionX(), cible->GetPositionY(),
                               cible->GetPositionZ(), FLORAISON_ZONE, true);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(
                spell_papota_floraison::Refleurir, EFFECT_0,
                SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Mot de l'ombre : desespoir — les deux malefices, d'un coup, a la ronde
    // =======================================================================
    // Aucun degat direct : le sort POSE le Mot de l'ombre : Douleur et le
    // Toucher vampirique sur tout ennemi a 10 m, AU MEILLEUR RANG QUE LE
    // PRETRE CONNAISSE — on lit son grimoire plutot que de coder les rangs
    // en dur, pour qu'un pretre de niveau 40 pose ceux de son niveau. Les
    // deux sorts se reconnaissent a la famille 6 et a leur masque (releve du
    // 2026-09-01 : Douleur = mot 0 bit 0x8000 ; Toucher = mot 1 bit 0x400).
    constexpr uint32 SWP_MASQUE = 0x8000;        // premier mot
    constexpr uint32 TOUCHER_MASQUE = 0x400;     // deuxieme mot

    uint32 DesespoirMeilleurRang(Player* pretre, uint8 mot, uint32 masque)
    {
        uint32 meilleur = 0;
        uint32 niveauMeilleur = 0;
        for (auto const& paire : pretre->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_PRIEST)
                continue;
            if (!(info->SpellFamilyFlags[mot] & masque))
                continue;
            uint32 niveau = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!meilleur || niveau > niveauMeilleur)
            {
                meilleur = info->Id;
                niveauMeilleur = niveau;
            }
        }
        return meilleur;
    }

    class spell_papota_desespoir : public SpellScript
    {
        PrepareSpellScript(spell_papota_desespoir);

        void Affliger(SpellEffIndex /*index*/)
        {
            Player* pretre = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            Unit* victime = GetHitUnit();
            if (!pretre || !victime)
                return;
            if (!_cherche)
            {
                _cherche = true;
                _douleur = DesespoirMeilleurRang(pretre, 0, SWP_MASQUE);
                _toucher = DesespoirMeilleurRang(pretre, 1, TOUCHER_MASQUE);
            }
            if (_douleur)
                pretre->CastSpell(victime, _douleur, true);
            if (_toucher)
                pretre->CastSpell(victime, _toucher, true);
        }

        void Register() override
        {
            // EFFECT_1 : l'effet 0 porte desormais les degats de zone, le
            // factice qui declenche les malefices est passe en second
            // (2026-09-01).
            OnEffectHitTarget += SpellEffectFn(
                spell_papota_desespoir::Affliger, EFFECT_1,
                SPELL_EFFECT_DUMMY);
        }

        bool _cherche = false;
        uint32 _douleur = 0;
        uint32 _toucher = 0;
    };

    // =======================================================================
    // Mot de pouvoir : Barriere — une reserve commune sous un dome
    // =======================================================================
    // 25 000 points d'absorption PARTAGES par tous les allies presents : le
    // dome (creature 803813) tient la reserve, chaque protege porte l'aura
    // 8600059 dont l'absorption puise dedans. Le pot commun est le principe
    // du Bouclier anti-magie, ici etendu a tous les degats et a tout le
    // groupe. Le dome LANCE lui-meme la protection : l'AuraScript retrouve
    // ainsi la reserve par son lanceur.
    constexpr uint32 BARRIERE_CREATURE = 803813;
    constexpr uint32 BARRIERE_PROTECTION = 8600059;
    constexpr uint32 BARRIERE_KIT_SON = 30045;
    // LE DOME SE RESSERRE (2026-09-01) : de 15 m a 7,5 m — la moitie —
    // atteinte a BARRIERE_RETRAIT et tenue les trois dernieres secondes ; le
    // modele suit, par l'echelle de l'objet. Plus de reserve absorbee : les
    // abrites subissent simplement moins de degats physiques (aura DBC).
    constexpr float BARRIERE_RAYON = 8.0f;       // 15 -> 9 -> 8 m (2026-09-01)
    constexpr float BARRIERE_RAYON_FIN = 4.0f;   // la moitie, comme avant
    constexpr uint32 BARRIERE_RETRAIT = 7000;    // ms — 3 s avant la fin
    // ECHELLE NATIVE (2026-09-01, demande) : le dome est pris tel quel, sans
    // remise a l'echelle. La boite englobante de ses sommets donne 11,63 m
    // de rayon, mais elle inclut ce qui deborde du dome visible — sa
    // coupole utile fait bien les 9 m de la zone.
    constexpr float BARRIERE_ECHELLE = 1.0f;
    constexpr uint32 BARRIERE_VIE = 10000;       // ms — miroir du DBC
    constexpr uint32 BARRIERE_TIC = 33;          // ms — 30 fois par seconde
                                                 // (demande du 2026-09-01) :
                                                 // entrees, sorties ET
                                                 // resserrement. La cadence
                                                 // REELLE reste bornee par
                                                 // le pas de la boucle du
                                                 // monde, qui appelle
                                                 // UpdateAI.
    constexpr uint32 BARRIERE_MARGE = 150;       // ms avant le son : le
                                                 // client n'a pas encore
                                                 // cree le dome (Shunpo)
    // LE SON EST UNE TRANCHE DE 2 s (fichier tronque, fondu en fin), rejouee
    // par l'IA tant que le dome vit : joue d'un bloc, il debordait bien
    // apres la disparition — « couper le son une fois que le bouclier a
    // disparu » (2026-09-01). La coupure suit donc le dome a 2 s pres.
    constexpr uint32 BARRIERE_SON_DUREE = 2000;
    constexpr uint32 BARRIERE_EMOTE_BIRTH = 990003;   // Emotes.dbc custom
    constexpr uint32 BARRIERE_EMOTE_DECAY = 990001;   // (anim 159, partagee)
    constexpr uint32 BARRIERE_DECAY_MS = 1000;   // la sequence Decay du dome

    // Le bourdon du dome, en fonction libre : AddEventAtOffset veut une
    // lambda RVALUE, une lambda nommee reutilisee ne compile pas.
    void BarriereBourdon(ObjectGuid guidDome, ObjectGuid guidPretre)
    {
        Player* pretre = ObjectAccessor::FindPlayer(guidPretre);
        if (!pretre)
            return;
        if (Creature* dome = ObjectAccessor::GetCreature(*pretre, guidDome))
            dome->SendPlaySpellVisual(BARRIERE_KIT_SON);
    }

    struct npc_papota_barriere : public ScriptedAI
    {
        npc_papota_barriere(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void IsSummonedBy(WorldObject* invocateur) override
        {
            if (invocateur)
                _pretre = invocateur->GetGUID();
            // (Intro et outro RETIREES le 2026-09-01 : le dome n'entre ni ne
            // sort en animation, il se contente de son Stand. Les emotes
            // Birth 990003 et Decay 990001 restent posees, dormantes.)
            me->SetObjectScale(BARRIERE_ECHELLE);   // il couvre les 15 m
            // Le bourdon, une fois le dome connu du client (le piege du
            // Shunpo : un kit envoye au tick du summon est jete), puis
            // RELANCE a 8,2 s — le fichier ne couvre pas les 10 s.
            ObjectGuid guidDome = me->GetGUID();
            ObjectGuid guidPretre = _pretre;
            me->m_Events.AddEventAtOffset([guidDome, guidPretre]()
            {
                BarriereBourdon(guidDome, guidPretre);
            }, Milliseconds(BARRIERE_MARGE));
            _bourdon = BARRIERE_MARGE + BARRIERE_SON_DUREE;
        }

        void UpdateAI(uint32 diff) override
        {
            // Le bourdon, tranche par tranche : il s'arrete avec le dome.
            _age += diff;
            if (_bourdon && _age >= _bourdon)
            {
                _bourdon = _age + BARRIERE_SON_DUREE;
                me->SendPlaySpellVisual(BARRIERE_KIT_SON);
            }

            _guet += diff;
            if (_guet < BARRIERE_TIC)
                return;
            _guet = 0;
            Unit* pretre = ObjectAccessor::GetUnit(*me, _pretre);

            // LA FIN : le dome s'efface, les abrites perdent l'indicateur.
            // Il n'existe aucun hook de disparition dans CreatureAI — sans
            // ce nettoyage, l'aura PERMANENTE restait a vie (constate le
            // 2026-09-01).
            if (_age + BARRIERE_TIC >= BARRIERE_VIE)
            {
                for (ObjectGuid guid : _proteges)
                    if (Player* parti = ObjectAccessor::FindPlayer(guid))
                        parti->RemoveAura(BARRIERE_PROTECTION, me->GetGUID());
                _proteges.clear();
                return;
            }
            if (!pretre)
                return;

            // Le resserrement : lineaire jusqu'a BARRIERE_RETRAIT, puis
            // tenu a la moitie. Le modele suit l'abri AU METRE PRES.
            float part = _age >= BARRIERE_RETRAIT
                ? 1.0f : float(_age) / float(BARRIERE_RETRAIT);
            float rayon = BARRIERE_RAYON
                + (BARRIERE_RAYON_FIN - BARRIERE_RAYON) * part;
            float echelle = BARRIERE_ECHELLE * rayon / BARRIERE_RAYON;
            // Seuil fin : a 30 pas par seconde sur 7 s, chaque pas ne vaut
            // que ~0,002 d'echelle — un seuil plus large gommerait un pas
            // sur deux.
            if (std::fabs(me->GetObjectScale() - echelle) > 0.001f)
                me->SetObjectScale(echelle);

            // Les allies SOUS le dome recoivent la protection ; ceux qui en
            // sortent la perdent (l'aura porte la meme duree que le dome,
            // on la retire donc a la main).
            std::list<Player*> proches;
            Acore::AnyPlayerInObjectRangeCheck verif(me, rayon);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                chercheur(me, proches, verif);
            Cell::VisitObjects(me, chercheur, rayon);

            GuidSet dedans;
            for (Player* allie : proches)
            {
                if (!allie->IsAlive() || !pretre->IsFriendlyTo(allie))
                    continue;
                dedans.insert(allie->GetGUID());
                if (!allie->HasAura(BARRIERE_PROTECTION, me->GetGUID()))
                    me->CastSpell(allie, BARRIERE_PROTECTION, true);
            }
            for (ObjectGuid guid : _proteges)
                if (!dedans.count(guid))
                    if (Player* parti = ObjectAccessor::FindPlayer(guid))
                        parti->RemoveAura(BARRIERE_PROTECTION, me->GetGUID());
            _proteges = dedans;
        }

    private:
        ObjectGuid _pretre;
        GuidSet _proteges;
        uint32 _guet = 0;
        uint32 _age = 0;
        uint32 _bourdon = 0;     // prochaine tranche de son (0 = aucune)
    };

    class spell_papota_barriere_zone : public SpellScript
    {
        PrepareSpellScript(spell_papota_barriere_zone);

        void Dresser(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            WorldLocation const* but = GetExplTargetDest();
            if (!lanceur || !but)
                return;
            Position ou(but->GetPositionX(), but->GetPositionY(),
                        but->GetPositionZ(), lanceur->GetOrientation());
            lanceur->SummonCreature(BARRIERE_CREATURE, ou,
                                    TEMPSUMMON_TIMED_DESPAWN, BARRIERE_VIE);
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_barriere_zone::Dresser,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // (L'AuraScript d'absorption a ete retire le 2026-09-01 : la protection
    // n'est plus une reserve puisee mais une reduction en pourcentage des
    // degats physiques, portee par le DBC seul.)

    // =======================================================================
    // Plume angelique — posee au sol, cueillie au passage
    // =======================================================================
    constexpr uint32 PLUME_CREATURE = 803812;    // display 802108
    constexpr uint32 PLUME_BIENFAIT = 8600097;   // +40 % de vitesse, 6 s
    constexpr uint32 PLUME_VIE = 6000;           // ms au sol
    constexpr float PLUME_RAYON = 2.0f;          // le pas qui la cueille
    constexpr uint32 PLUME_TIC = 200;            // ms — cadence du guet
    constexpr uint32 PLUME_SORT = 8600040;
    constexpr uint32 PLUME_RESERVE = 8600099;    // l'aura a piles des charges
    constexpr uint8 PLUME_CHARGES = 3;
    constexpr uint32 PLUME_RECHARGE = 20000;     // ms — par charge

    // LES CHARGES A LA MANIERE MODERNE (2026-08-31) : chaque plume posee
    // programme SON PROPRE retour 20 s plus tard, au lieu d'un rechargement
    // groupe. L'aura de reserve compte les plumes RESTANTES et n'existe que
    // tant qu'il en manque ; a zero, le sort passe en recharge classique —
    // levee des qu'une plume revient.
    void PlumeRendreCharge(ObjectGuid guidJoueur)
    {
        Player* joueur = ObjectAccessor::FindPlayer(guidJoueur);
        if (!joueur)
            return;
        Aura* reserve = joueur->GetAura(PLUME_RESERVE);
        if (!reserve)
        {
            // Reserve vide : la plume qui revient rouvre la reserve a une,
            // et rend le sort disponible sur-le-champ.
            joueur->CastSpell(joueur, PLUME_RESERVE, true);
            if ((reserve = joueur->GetAura(PLUME_RESERVE)))
                reserve->SetStackAmount(1);
            joueur->RemoveSpellCooldown(PLUME_SORT, true);
            return;
        }
        uint8 restant = reserve->GetStackAmount();
        if (restant + 1 >= PLUME_CHARGES)
            joueur->RemoveAura(PLUME_RESERVE);   // reserve pleine : plus rien
        else                                     // a afficher
            reserve->SetStackAmount(restant + 1);
    }

    class spell_papota_plume : public SpellScript
    {
        PrepareSpellScript(spell_papota_plume);

        void Poser(SpellEffIndex /*index*/)
        {
            Unit* lanceur = GetCaster();
            WorldLocation const* but = GetExplTargetDest();
            if (!lanceur || !but)
                return;
            // INSTANTANEMENT au point vise, et pour six secondes.
            Position ou(but->GetPositionX(), but->GetPositionY(),
                        but->GetPositionZ(), lanceur->GetOrientation());
            lanceur->SummonCreature(PLUME_CREATURE, ou,
                                    TEMPSUMMON_TIMED_DESPAWN, PLUME_VIE);
        }

        // Une plume consommee : la reserve descend d'un cran et CETTE
        // plume-la programme son retour. Tant qu'il en reste, la recharge
        // que le coeur vient de poser (avant les effets, acquis du
        // Miroitement) est annulee.
        void Charges()
        {
            Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!joueur)
                return;

            Aura* reserve = joueur->GetAura(PLUME_RESERVE);
            uint8 restantes;
            if (!reserve)
            {
                // Reserve pleine (elle n'existe pas quand rien ne manque).
                restantes = PLUME_CHARGES - 1;
                joueur->CastSpell(joueur, PLUME_RESERVE, true);
                if ((reserve = joueur->GetAura(PLUME_RESERVE)))
                    reserve->SetStackAmount(restantes);
            }
            else
            {
                restantes = reserve->GetStackAmount() - 1;
                if (restantes)
                    reserve->SetStackAmount(restantes);
                else
                    joueur->RemoveAura(PLUME_RESERVE);
            }

            if (restantes)
                joueur->RemoveSpellCooldown(PLUME_SORT, true);

            // Le retour de CETTE plume, 20 s plus tard.
            ObjectGuid guid = joueur->GetGUID();
            joueur->m_Events.AddEventAtOffset([guid]()
            {
                PlumeRendreCharge(guid);
            }, Milliseconds(PLUME_RECHARGE));
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_papota_plume::Poser,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
            AfterCast += SpellCastFn(spell_papota_plume::Charges);
        }
    };

    struct npc_papota_plume : public ScriptedAI
    {
        npc_papota_plume(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void UpdateAI(uint32 diff) override
        {
            if (_cueillie)
                return;
            _guet += diff;
            if (_guet < PLUME_TIC)
                return;
            _guet = 0;
            Unit* pretre = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!pretre)
                return;
            // Le premier ALLIE qui pose le pied dessus l'emporte.
            std::list<Player*> passants;
            Acore::AnyPlayerInObjectRangeCheck verif(me, PLUME_RAYON);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                chercheur(me, passants, verif);
            Cell::VisitObjects(me, chercheur, PLUME_RAYON);
            for (Player* passant : passants)
            {
                if (!passant->IsAlive() || !pretre->IsFriendlyTo(passant))
                    continue;
                pretre->CastSpell(passant, PLUME_BIENFAIT, true);
                _cueillie = true;
                me->DespawnOrUnsummon();
                return;
            }
        }

    private:
        bool _cueillie = false;
        uint32 _guet = 0;
    };

    // =======================================================================
    // Bete de meute — l'IA calquee sur le PIEGE A SERPENTS natif
    // =======================================================================
    // Patron : npc_pet_hunter_snake_trap (scripts/Pet/pet_hunter.cpp). Ce
    // qu'il apporte et que nos tentatives precedentes n'avaient pas :
    //   - le CIBLAGE par les combats du maitre (GetCombatManager), pas par
    //     sa seule victime courante — vide hors combat ;
    //   - EngageWithTarget + FixateTarget, qui accrochent vraiment ;
    //   - UpdateVictim() + DoMeleeAttackIfReady() a chaque tick : SANS CET
    //     APPEL UNE CREATURE NE FRAPPE JAMAIS, quoi qu'on lui demande ;
    //   - le poison passif pose sur SOI a l'apparition (SPELL_HUNTER_DEADLY_
    //     POISON_PASSIVE) — exactement notre frenesie.
    // S'y ajoute, a la demande : l'apparence et les chiffres du familier, et
    // le RETOUR AU CHASSEUR quand il n'y a plus rien a mordre.
    // LE SILLAGE SE POSE TOUT SEUL. L'aura 8610014 est permanente et sans
    // icone : on la donne a tout druide qui connait la Charge sauvage, et
    // elle ne fait rien tant qu'il n'est pas selenien. C'est ce qui evite
    // d'avoir a guetter les changements de forme, qui n'offrent pas de point
    // d'accroche commode — le meme raisonnement que pour les flammes du
    // tyran, ou le DBC portait ce que le code n'avait pas a porter.
    class papota_sillage_joueur : public PlayerScript
    {
    public:
        papota_sillage_joueur() : PlayerScript("papota_sillage_joueur",
            {
                PLAYERHOOK_ON_LOGIN,
                PLAYERHOOK_ON_LOGOUT,
                PLAYERHOOK_ON_LEARN_SPELL,
                PLAYERHOOK_ON_FORGOT_SPELL
            }) { }

        void OnPlayerLogin(Player* joueur) override { Poser(joueur); }

        void OnPlayerLearnSpell(Player* joueur, uint32 /*id*/) override
        {
            Poser(joueur);
        }

        // L'OUBLI COMPTE AUTANT QUE L'APPRENTISSAGE. Sans ce crochet, retirer
        // le noeud du spherier laissait les CINQ sorts de forme au grimoire
        // jusqu'a la prochaine connexion — un druide degrisant gardait le
        // Retour stellaire et le Bond de l'ours, gratuits.
        //
        // LE FILTRE SUR L'IDENTIFIANT N'EST PAS UN CONFORT : `Poser` retire
        // lui-meme des sorts, et `Player::removeSpell` appelle ce crochet a la
        // fin. Reagir a n'importe quel oubli nous ferait rentrer cinq fois
        // dans notre propre appel. Seul le noeud change quelque chose de toute
        // facon — c'est lui, et lui seul, que `Poser` interroge.
        void OnPlayerForgotSpell(Player* joueur, uint32 id) override
        {
            if (id == CHARGE_SAUVAGE)
                Poser(joueur);
        }

        void OnPlayerLogout(Player* joueur) override
        {
            // Le sillage ne survit pas a la deconnexion, les creatures non
            // plus : on ne laisse pas d'etoiles orphelines sur la carte.
            EffaceSillage(joueur);
        }

    private:
        static void Poser(Player* joueur)
        {
            if (!joueur || joueur->getClass() != CLASS_DRUID)
                return;
            bool const connait = joueur->HasSpell(CHARGE_SAUVAGE);

            // LES CINQ SORTS DE FORME suivent celui du spherier : appris
            // avec lui, repris avec lui. Le spherier ne recense que ce
            // qu'il a lui-meme accorde, il n'y touchera donc pas.
            for (uint32 sort : CHARGE_FORMES)
            {
                if (connait && !joueur->HasSpell(sort))
                    joueur->learnSpell(sort);
                else if (!connait && joueur->HasSpell(sort))
                    joueur->removeSpell(sort, SPEC_MASK_ALL, false);
            }

            if (connait && !joueur->HasAura(CHARGE_SILLAGE))
                joueur->CastSpell(joueur, CHARGE_SILLAGE, true);
            else if (!connait)
            {
                joueur->RemoveAurasDueToSpell(CHARGE_SILLAGE);
                // ET LES ETOILES DEJA POSEES avec. Retirer la seule aura
                // arretait la semence sans ramasser la recolte : les creatures
                // restaient sur la carte jusqu'a la deconnexion, alors que le
                // druide n'avait plus le sort pour y retourner.
                EffaceSillage(joueur);
            }
        }
    };

    struct npc_papota_meute : public ScriptedAI
    {
        npc_papota_meute(Creature* creature) : ScriptedAI(creature) { }

        void JustEngagedWith(Unit* /*qui*/) override { }
        void MoveInLineOfSight(Unit* /*qui*/) override { }

        void InitializeAI() override
        {
            ScriptedAI::InitializeAI();
            Unit* maitre = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!maitre)
                return;
            me->SetFaction(maitre->GetFaction());
            me->SetLevel(maitre->GetLevel());
            // LE PROPRIETAIRE (2026-08-31) : sans lui, le client ne
            // reconnait pas la bete comme etant au joueur et n'affiche PAS
            // ses degats en texte flottant. C'est ce que les serpents du
            // piege ont nativement (leur script interroge me->GetOwner()).
            me->SetOwnerGUID(maitre->GetGUID());
            me->SetCreatorGUID(maitre->GetGUID());
            // L'apparence et les chiffres de la bete du chasseur.
            if (Player* joueur = maitre->ToPlayer())
                if (Pet* familier = joueur->GetPet())
                {
                    me->SetDisplayId(familier->GetDisplayId());
                    me->SetMaxHealth(familier->GetMaxHealth());
                    me->SetHealth(familier->GetMaxHealth());
                    // Degats DIVISES PAR CINQ (demande du 2026-08-31 : trois
                    // betes au plein rendement du familier assommaient tout).
                    for (WeaponDamageRange borne : {MINDAMAGE, MAXDAMAGE})
                        me->SetBaseWeaponDamage(BASE_ATTACK, borne,
                            familier->GetWeaponDamageRange(BASE_ATTACK, borne)
                            / RUEE_DIVISEUR);
                    me->UpdateDamagePhysical(BASE_ATTACK);
                }
            // Les coups poseront le saignement cumulable.
            DoCast(me, RUEE_FRENESIE, true);
            me->SetReactState(REACT_AGGRESSIVE);
        }

        void UpdateAI(uint32 diff) override
        {
            Unit* maitre = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;

            // Le ciblage du piege a serpents : tout ce avec quoi le maitre
            // est en combat, une proie fixee au hasard.
            if (maitre && !me->GetThreatMgr().GetFixateTarget())
            {
                std::vector<Unit*> proies;
                auto retenir = [this, &proies, maitre](CombatReference* ref)
                {
                    Unit* ennemi = ref->GetOther(maitre);
                    if (ennemi && me->CanCreatureAttack(ennemi))
                        proies.push_back(ennemi);
                };
                for (auto const& [guid, ref] :
                     maitre->GetCombatManager().GetPvPCombatRefs())
                    retenir(ref);
                if (proies.empty())
                    for (auto const& [guid, ref] :
                         maitre->GetCombatManager().GetPvECombatRefs())
                        retenir(ref);
                for (Unit* proie : proies)
                    me->EngageWithTarget(proie);
                if (!proies.empty())
                    me->GetThreatMgr().FixateTarget(
                        Acore::Containers::SelectRandomContainerElement(proies));
            }

            if (!UpdateVictim())
            {
                // Plus rien a mordre : la meute revient au chasseur.
                if (maitre && _retour > diff)
                    _retour -= diff;
                else if (maitre)
                {
                    _retour = 1000;
                    if (me->GetDistance(maitre) > 8.0f)
                        me->GetMotionMaster()->MoveFollow(maitre, 3.0f,
                            float(rand_norm()) * 2.0f * float(M_PI));
                }
                return;
            }
            DoMeleeAttackIfReady();
        }

    private:
        uint32 _retour = 0;
    };

    // =======================================================================
    // Rage du Dormeur — le renvoi soigne
    // =======================================================================
    // LE RENVOI LUI-MEME EST NATIF : l'aura 15 (DAMAGE_SHIELD) est reglee par
    // le coeur dans Unit::DealMeleeDamage, exactement comme les Epines. Ce
    // script ne fait QUE la part qui n'existe nulle part en 3.3.5 — rendre au
    // druide une fraction de ce qu'il vient de renvoyer.
    //
    // LA FRACTION VIT DANS LE TROISIEME EFFET, un dummy, et non en dur ici :
    // elle reste ainsi dans la table de verite, a portee de l'equilibrage,
    // comme le renvoi lui-meme. Le dummy ne sert qu'a cela et a porter le
    // crochet de proc — le coeur ne declenche rien sur une aura de renvoi.
    class spell_papota_rage_dormeur : public AuraScript
    {
        PrepareAuraScript(spell_papota_rage_dormeur);

        void Boire(AuraEffect const* /*effet*/, ProcEventInfo& /*infos*/)
        {
            Unit* druide = GetTarget();
            if (!druide)
                return;

            AuraEffect const* renvoi = GetEffect(EFFECT_1);
            AuraEffect const* part = GetEffect(EFFECT_2);
            if (!renvoi || !part)
                return;

            int32 const montant = renvoi->GetAmount() * part->GetAmount() / 100;
            if (montant <= 0)
                return;

            HealInfo bienfait(druide, druide, uint32(montant), GetSpellInfo(),
                              SPELL_SCHOOL_MASK_NATURE);
            druide->HealBySpell(bienfait);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_papota_rage_dormeur::Boire,
                                             EFFECT_2, SPELL_AURA_DUMMY);
        }
    };

}

void AddSC_spherier_sorts()
{
    RegisterSpellScript(spell_papota_bond_directionnel);
    RegisterSpellScript(spell_papota_bond_heroique);
    RegisterSpellScript(spell_papota_shunpo);
    RegisterSpellScript(spell_papota_barriere_bouclier);
    RegisterSpellScript(spell_papota_frappes_fauchantes);
    RegisterSpellScript(spell_papota_miroitement);
    RegisterSpellScript(spell_papota_miroitement_temoin);
    RegisterSpellScript(spell_papota_orbe_arcanes);
    RegisterCreatureAI(npc_papota_orbe_arcanes);
    RegisterSpellScript(spell_papota_rayon_givre);
    RegisterSpellScript(spell_papota_fleau_des_rois);
    RegisterSpellScript(spell_papota_coup_de_des);
    RegisterSpellScript(spell_papota_halo);
    RegisterCreatureAI(npc_papota_halo);
    RegisterSpellScript(spell_papota_apocalypse);
    RegisterCreatureAI(npc_papota_goule);
    RegisterSpellScript(spell_papota_destrier_divin);
    RegisterSpellScript(spell_papota_porte);
    new go_papota_porte();
    RegisterSpellScript(spell_papota_cataclysme);
    RegisterSpellAndAuraScriptPair(spell_papota_ruee_ardente,
                                   spell_papota_ruee_ardente_aura);
    RegisterCreatureAI(npc_papota_meute);
    RegisterSpellScript(spell_papota_desespoir);
    RegisterSpellScript(spell_papota_barriere_zone);
    RegisterCreatureAI(npc_papota_barriere);
    RegisterSpellScript(spell_papota_plume);
    RegisterCreatureAI(npc_papota_plume);
    RegisterSpellScript(spell_papota_tempete_os);
    RegisterSpellScript(spell_papota_souffle_sindragosa);
    RegisterSpellScript(spell_papota_seisme);
    RegisterSpellScript(spell_papota_ascendance);
    RegisterSpellScript(spell_papota_lien_esprit);
    RegisterSpellScript(spell_papota_tyran);
    RegisterSpellScript(spell_papota_tyran_chasseur);
    RegisterSpellScript(spell_papota_tyran_succube);
    RegisterCreatureAI(npc_papota_tyran);
    RegisterSpellScript(spell_papota_ruee_sauvage);
    RegisterSpellScript(spell_papota_tirs_consecutifs);
    RegisterSpellScript(spell_papota_traits_fiches);
    RegisterSpellScript(spell_papota_petite_foulee);
    RegisterSpellScript(spell_papota_charge_ours);
    RegisterSpellScript(spell_papota_charge_felin);
    RegisterSpellScript(spell_papota_charge_voyage);
    RegisterSpellScript(spell_papota_charge_arbre);
    RegisterSpellScript(spell_papota_charge_selenien);
    RegisterSpellScript(spell_papota_etoiles);
    RegisterSpellScript(spell_papota_forme_selenien);
    RegisterSpellScript(spell_papota_frenesie);
    new papota_sillage_joueur();
    new papota_solstice_joueur();
    RegisterSpellScript(spell_papota_floraison);
    RegisterSpellScript(spell_papota_rage_dormeur);
}

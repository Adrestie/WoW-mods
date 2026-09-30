/*
 * Sorts customs du serveur Papota.
 *
 * ---------------------------------------------------------------------------
 * spell_nairun_appel_des_anciens — sort 84320, objet 84003
 *   « Nairun, Souffle des Anciens »
 *
 * Chaque soin direct declenche UN sort parmi trois, tire une seule fois :
 *   38 %  Chaine de soins des Anciens (84321, copie de Chain Heal a 5 cibles)
 *   57 %  Vague de soins des Anciens (84322, copie de Healing Wave rang 14)
 *    5 %  Protection des Anciens (84323), immunite aux degats de 3 s sur le
 *         raid dans 50 yards, avec un cooldown propre de 30 s
 *
 * Si la protection sort alors que son cooldown court, le proc n'est pas perdu :
 * on retire dans 1..95, ce qui repartit ses 5 % entre les deux soins en gardant
 * leur rapport 38 : 57. Chaque soin direct declenche donc toujours un sort.
 *
 * Le tirage pondere n'est pas exprimable en DBC : trois auras de proc a 38, 57
 * et 5 % tireraient independamment, donc parfois zero sort et parfois trois.
 * D'ou ce script.
 *
 * Boucle : les trois sorts sont lances en mode declenche, et 84320 ne porte
 * pas SPELL_ATTR3_CAN_PROC_FROM_PROCS. La protection du coeur
 * (SpellAuras.cpp:2152) empeche donc les soins gratuits d'en declencher
 * d'autres. Ne pas remettre cet attribut : le proc etant a 100 %, la reaction
 * en chaine serait immediate et sans fin.
 * ---------------------------------------------------------------------------
 *
 * Note, si l'elevation d'un joueur revient un jour sur la table : SetHover ne
 * convient pas, il repose sur Relocate() alors que le client fait autorite sur
 * sa propre position. Le motif de Blizzard (Gravity Lapse de Kael'thas) est en
 * deux temps : SPELL_EFFECT_KNOCK_BACK avec EffectMiscValue = 0 et
 * EffectBasePoints = vitesse verticale x 10 (~139 pour 5 yards, cf.
 * SpellEffects.cpp:5011), puis SPELL_AURA_FLY pendant la duree de l'effet.
 */

#include "Cell.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "Common.h"
#include "Group.h"
#include "Player.h"
#include "CreatureScript.h"
#include "ScriptedCreature.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellScript.h"

// doit suivre GridNotifiers.h et CellImpl.h
#include "GridNotifiersImpl.h"
enum NairunSpells
{
    SPELL_CHAINE_DES_ANCIENS = 84321,
    SPELL_VAGUE_DE_SOINS     = 84322,  // copie custom de Healing Wave rang 14
    SPELL_PROTECTION_ANCIENS = 84323,
    SPELL_PROTECTION_RECHARGE = 84324   // debuff de recharge, 30 s (DBC)
};

// La recharge n est plus un cooldown interne mais un debuff visible, le
// marqueur SPELL_*_RECHARGE : le script ne se declenche que s il est absent
// et le pose au declenchement. Duree restante du debuff et delai avant le
// prochain declenchement sont donc une seule et meme valeur, y compris
// apres une mort (SPELL_ATTR3_ALLOW_AURA_WHILE_DEAD) ou une reconnexion
// (les auras sont sauvegardees avec leur duree restante). La duree vit dans
// le DBC du marqueur. Meme montage pour Liora et Salvation.
static constexpr float  PORTEE_DE_SOIN         = 40.0f;

class spell_nairun_appel_des_anciens : public AuraScript
{
    PrepareAuraScript(spell_nairun_appel_des_anciens);

    // Allie vivant le plus bas en vie a portee, porteur inclus.
    Unit* AllieLePlusBas(Player* porteur) const
    {
        Unit* choisi = porteur;
        float minPct = porteur->GetHealthPct();

        if (Group* groupe = porteur->GetGroup())
        {
            for (GroupReference* ref = groupe->GetFirstMember(); ref; ref = ref->next())
            {
                Player* membre = ref->GetSource();
                if (!membre || membre == porteur || !membre->IsAlive())
                    continue;
                if (!porteur->IsWithinDistInMap(membre, PORTEE_DE_SOIN))
                    continue;
                if (membre->GetHealthPct() < minPct)
                {
                    minPct = membre->GetHealthPct();
                    choisi = membre;
                }
            }
        }
        return choisi;
    }

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& /*eventInfo*/)
    {
        PreventDefaultAction();

        Player* porteur = GetTarget()->ToPlayer();
        if (!porteur)
            return;

        uint32 tirage = urand(1, 100);

        if (tirage > 95 && !porteur->HasAura(SPELL_PROTECTION_RECHARGE))
        {
            // Cible = le porteur : le sort se propage au raid par son type de
            // cible TARGET_UNIT_CASTER_AREA_RAID, dans 50 yards.
            porteur->CastSpell(porteur, SPELL_PROTECTION_ANCIENS, true);
            porteur->CastSpell(porteur, SPELL_PROTECTION_RECHARGE, true);
            return;
        }

        // Protection sortie mais en cooldown : nouveau tirage dans la seule plage
        // des soins, leur rapport 38 : 57 reste donc intact.
        if (tirage > 95)
            tirage = urand(1, 95);

        porteur->CastSpell(AllieLePlusBas(porteur),
            tirage <= 38 ? SPELL_CHAINE_DES_ANCIENS : SPELL_VAGUE_DE_SOINS, true);
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_nairun_appel_des_anciens::HandleProc,
                            EFFECT_0, SPELL_AURA_DUMMY);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_kelrah_etreinte_des_esprits — sort 84340, objet 84004
 *   « Kelrah, Harmonie des Elements »
 *
 * L aura est permanente tant que le bouclier est equipe. Elle porte deux
 * effets periodiques independants, entierement decrits en DBC :
 *
 *   effet 0, toutes les 1 s : 84341, soin de zone sur le raid dans 40 yd
 *   effet 1, toutes les 3 s : 84342, dissipe un poison et une maladie
 *
 * Le script ne sert qu a une chose que le DBC ne sait pas exprimer : ne rien
 * declencher hors combat. Les deux minuteurs continuent de tourner, on se
 * contente de supprimer l action, ils restent donc alignes — une purification
 * pour trois soins.
 *
 * Boucle : 84341 porte SPELL_ATTR3_SUPPRESS_CASTER_PROCS. Sans lui, chaque
 * tick declencherait « Appel des Anciens » de Nairun (84003) si les deux
 * objets sont portes ensemble, puisque le soin est de classe magique et
 * positif. Ce ne serait pas infini, mais cela doublerait le soin en silence.
 * ---------------------------------------------------------------------------
 */

class spell_kelrah_etreinte_des_esprits : public AuraScript
{
    PrepareAuraScript(spell_kelrah_etreinte_des_esprits);

    void HandlePeriodic(AuraEffect const* /*aurEff*/)
    {
        Unit* porteur = GetTarget();
        if (!porteur || !porteur->IsInCombat())
            PreventDefaultAction();
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_kelrah_etreinte_des_esprits::HandlePeriodic,
                                EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_kelrah_etreinte_des_esprits::HandlePeriodic,
                                EFFECT_1, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_crocs_ecorchement — sort 84943, objet 84034
 *   « Crocs-de-Sang l'Ecorcheur »
 *
 * L Ecorchement (84942) porte TargetAuraState = 2, il echoue donc de lui-meme
 * au-dessus de 20 % de vie. Mais Aura::TriggerProcOnEvent ajoute le cooldown du
 * proc des qu il se declenche, sans regarder si le sort lance a abouti : sans ce
 * garde-fou, chaque coup porte sur une cible en pleine sante consommerait les
 * 12 s d ICD pour rien.
 * ---------------------------------------------------------------------------
 */

class spell_crocs_ecorchement : public AuraScript
{
    PrepareAuraScript(spell_crocs_ecorchement);

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        Unit* cible = eventInfo.GetProcTarget();
        return cible && cible->IsAlive() && cible->GetHealthPct() < 20.0f;
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_crocs_ecorchement::CheckProc);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_liora_appel_des_racines — sort 84543, objet 84014
 *   « Liora, Berceuse des Racines »
 *
 * Veilleur permanent, un battement toutes les 3 s. Lance la resurrection de
 * masse de Blizzard (72429) quand le porteur est en combat et que plus de la
 * moitie de son groupe est morte. Le cooldown de 10 minutes est pose a la main :
 * 72429 porte bien un RecoveryTime de 600000, mais un lancement declenche
 * l ignore.
 * ---------------------------------------------------------------------------
 */

enum LioraSpells
{
    SPELL_SEVE_DE_LIORA         = 84541,
    SPELL_VIGUEUR_DE_LIORA      = 84542,
    SPELL_RESURRECTION_DE_MASSE = 72429,
    SPELL_RACINES_RECHARGE      = 84544  // debuff de recharge, 10 min (DBC)
};

/*
 * spell_liora_seve — sort 84540
 *
 * Chaque tick de soin periodique depose la Seve sur l unite soignee. Tous les
 * dix cumuls de Seve, celle-ci gagne un cumul de Vigueur : 200 cumuls de Seve
 * donnent donc 20 cumuls de Vigueur, soit +20 % de soins recus au plafond.
 *
 * Le rapport n est pas tenu par un compteur mais recalcule a chaque fois depuis
 * le nombre de cumuls reellement presents. Si la Seve expire, retombe ou est
 * dissipee, la Vigueur suit sans deriver.
 *
 * Le detour par le C++ est impose par le DBC : EffectBasePoints est un entier,
 * les 0,01 % par cumul demandes au depart arrondissaient a zero. Deux auras de
 * cadences differentes donnent le meme resultat avec des entiers.
 */
class spell_liora_seve : public AuraScript
{
    PrepareAuraScript(spell_liora_seve);

    // Sans ce garde-fou, la Seve se redepose elle-meme : chacun de ses ticks est
    // un soin periodique du porteur, donc un PROC_FLAG_DONE_PERIODIC de plus.
    //
    // SPELL_ATTR3_SUPPRESS_CASTER_PROCS ne suffit pas : le coeur ne le consulte
    // qu au lancement (Spell.cpp:2650). Le chemin des ticks
    // (SpellAuraEffects.cpp:6705) pose le drapeau sans regarder les attributs.
    bool CheckProc(ProcEventInfo& eventInfo)
    {
        SpellInfo const* source = eventInfo.GetSpellInfo();
        return source
            && source->Id != SPELL_SEVE_DE_LIORA
            && source->Id != SPELL_VIGUEUR_DE_LIORA;
    }

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();

        Unit* porteur = GetTarget();
        Unit* soigne = eventInfo.GetProcTarget();
        if (!porteur || !soigne || !soigne->IsAlive())
            return;

        porteur->CastSpell(soigne, SPELL_SEVE_DE_LIORA, true);

        Aura* seve = soigne->GetAura(SPELL_SEVE_DE_LIORA, porteur->GetGUID());
        if (!seve)
            return;

        uint8 const voulu = uint8(seve->GetStackAmount() / 10);
        if (!voulu)
            return;

        porteur->CastSpell(soigne, SPELL_VIGUEUR_DE_LIORA, true);
        if (Aura* vigueur = soigne->GetAura(SPELL_VIGUEUR_DE_LIORA, porteur->GetGUID()))
            if (vigueur->GetStackAmount() != voulu)
                vigueur->SetStackAmount(voulu);
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_liora_seve::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_liora_seve::HandleProc,
                            EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

class spell_liora_appel_des_racines : public AuraScript
{
    PrepareAuraScript(spell_liora_appel_des_racines);

    void HandlePeriodic(AuraEffect const* /*aurEff*/)
    {
        PreventDefaultAction();

        Player* porteur = GetTarget()->ToPlayer();
        if (!porteur || !porteur->IsInCombat())
            return;

        // voir Nairun : le debuff de recharge est la seule source de verite
        if (porteur->HasAura(SPELL_RACINES_RECHARGE))
            return;

        Group* groupe = porteur->GetGroup();
        if (!groupe)
            return;

        uint32 presents = 0;
        uint32 morts = 0;
        for (GroupReference* ref = groupe->GetFirstMember(); ref; ref = ref->next())
        {
            Player* membre = ref->GetSource();
            if (!membre || membre->GetMapId() != porteur->GetMapId())
                continue;
            ++presents;
            if (!membre->IsAlive())
                ++morts;
        }

        // « plus de la moitie » au sens strict
        if (presents < 2 || morts * 2 <= presents)
            return;

        porteur->CastSpell(porteur, SPELL_RESURRECTION_DE_MASSE, true);
        porteur->CastSpell(porteur, SPELL_RACINES_RECHARGE, true);
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_liora_appel_des_racines::HandlePeriodic,
                                EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_elundor_cycle_celeste — sort 84520, objet 84013
 *   « Elun'dor, Voix des Cieux Silencieux »
 *
 * Aura permanente cadencee a 350 ms. Elle alterne deux buffs de 25 s et lance
 * un sort a la cadence propre a chaque phase :
 *
 *   Zenith lunaire (84521) : eclat lunaire (84522) toutes les 1,5 s
 *   Zenith solaire (84524) : rayon de soleil (84523) toutes les 0,35 s
 *
 * Pourquoi en C++ : chaque buff occupe deja ses trois effets DBC (deux bonus
 * plus rien de libre), il ne restait aucun slot pour porter a la fois le relais
 * d alternance et le lanceur periodique.
 *
 * Les deux sorts lances portent SPELL_ATTR3_SUPPRESS_CASTER_PROCS : ils ne
 * peuvent donc pas declencher la Plenitude (84527), dont le proc reagit aux
 * sorts directs. Sans cela, le rayon solaire la relancerait trois fois par
 * seconde.
 *
 * Le rayon de soleil emploie le visuel 20003, construit pour l occasion : le
 * modele de la colonne de lumiere y est monte sur l emplacement Base plutot
 * que WorldEffect. Monte en WorldEffect, comme chez Blizzard, il exigeait que
 * le sort porte une destination — donc un ciblage a la cible designee, et une
 * selection faite ici. Monte en Base, il s accroche a l unite touchee, ce qui
 * rend le cone DBC suffisant.
 * ---------------------------------------------------------------------------
 */

enum ElundorSpells
{
    SPELL_ZENITH_LUNAIRE  = 84521,
    SPELL_ZENITH_SOLAIRE  = 84524,
    SPELL_ECLAT_LUNAIRE   = 84522,
    SPELL_RAYON_DE_SOLEIL = 84523
};

static constexpr uint32 DUREE_PHASE_MS   = 25 * IN_MILLISECONDS;
static constexpr uint32 CADENCE_LUNAIRE  = 1500;
static constexpr uint32 CADENCE_SOLAIRE  = 300;

class spell_elundor_cycle_celeste : public AuraScript
{
    PrepareAuraScript(spell_elundor_cycle_celeste);

    uint32 _phase = DUREE_PHASE_MS;   // force la bascule des le premier battement
    uint32 _depuisLancer = 0;
    bool   _solaire = true;           // la premiere bascule donnera donc le lunaire

    void HandlePeriodic(AuraEffect const* aurEff)
    {
        PreventDefaultAction();

        Player* porteur = GetTarget()->ToPlayer();
        if (!porteur)
            return;

        uint32 const pas = uint32(std::max<int32>(aurEff->GetAmplitude(), 1));
        _phase += pas;
        _depuisLancer += pas;

        if (_phase >= DUREE_PHASE_MS)
        {
            _phase = 0;
            _solaire = !_solaire;
            _depuisLancer = 0;
        }

        // Le pilote survit a la mort du porteur (ALLOW_AURA_WHILE_DEAD) et son
        // horloge continue de tourner, mais un cadavre ne lance rien.
        if (!porteur->IsAlive())
            return;

        // On ne se contente pas de poser le buff a la bascule : on verifie qu il
        // est bien la. Le buff, lui, ne survit pas a la mort — sans ce rattrapage
        // le porteur ressuscite resterait nu jusqu a 25 s. Couvre aussi la
        // dissipation.
        uint32 const attendu = _solaire ? SPELL_ZENITH_SOLAIRE : SPELL_ZENITH_LUNAIRE;
        if (!porteur->HasAura(attendu))
        {
            porteur->RemoveAurasDueToSpell(_solaire ? SPELL_ZENITH_LUNAIRE : SPELL_ZENITH_SOLAIRE);
            porteur->CastSpell(porteur, attendu, true);
        }

        uint32 const cadence = _solaire ? CADENCE_SOLAIRE : CADENCE_LUNAIRE;
        if (_depuisLancer < cadence)
            return;
        // On retranche au lieu de remettre a zero : le pilote bat toutes les
        // 175 ms, et une cadence qui n en est pas un multiple deriverait sinon
        // a chaque lancer.
        _depuisLancer -= cadence;

        // Hors combat, la cadence de 0,35 s ferait de l arme un aimant a packs :
        // le cone part du joueur et toucherait tout ce qu il croise en chemin.
        if (!porteur->IsInCombat())
            return;

        // Les deux sorts sont des copies de Moonfire, structure pour structure :
        // meme cone de 40 yards en DBC (cible 104), meme forme de visuel, seul le
        // modele d impact change. Le coeur fait donc toute la selection, et le
        // script se contente de lancer — aucune recherche cote serveur.
        //
        // La version precedente du rayon etait batie sur Sunbeam : son impact
        // tombait aussi sur le lanceur, sans qu on ait pu trouver ce qui l en
        // distinguait. Repartir de la structure qui ne le fait pas etait plus sur
        // que de continuer a chercher.
        porteur->CastSpell(static_cast<Unit*>(nullptr),
                           _solaire ? SPELL_RAYON_DE_SOLEIL : SPELL_ECLAT_LUNAIRE, true);
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_elundor_cycle_celeste::HandlePeriodic,
                                EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_tharnok_ronces_de_givre — sort 84561, objet 84015
 *   « Tharnok, Echine du Monde »
 *
 * SPELL_AURA_DAMAGE_SHIELD ne repond qu aux coups de melee : Unit.cpp:1029
 * exige DmgClass == SPELL_DAMAGE_CLASS_MELEE, et Unit.cpp:2130 se trouve dans
 * le chemin des attaques au corps a corps. Un lanceur de sorts ne passe par
 * aucun des deux, les Ronces restaient donc muettes face a lui.
 *
 * L effet 1 de l aura couvre desormais les coups non-melee. Le montant n est
 * pas fixe : on relit celui de l effet 0, donc la meme valeur exactement que la
 * branche de melee, cumuls compris — AuraEffect::CalculateAmount la multiplie
 * deja par le nombre de cumuls (SpellAuraEffects.cpp:580).
 * ---------------------------------------------------------------------------
 */

enum TharnokSpells
{
    SPELL_RONCES_RENVOI = 84562
};

class spell_tharnok_ronces_de_givre : public AuraScript
{
    PrepareAuraScript(spell_tharnok_ronces_de_givre);

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();

        Unit* porteur = GetTarget();
        Unit* assaillant = eventInfo.GetActor();
        if (!porteur || !assaillant || assaillant == porteur || !assaillant->IsAlive())
            return;

        AuraEffect const* bouclier = GetAura()->GetEffect(EFFECT_0);
        if (!bouclier)
            return;

        int32 degats = std::max<int32>(0, bouclier->GetAmount());
        if (!degats)
            return;

        porteur->CastCustomSpell(assaillant, SPELL_RONCES_RENVOI, &degats,
                                 nullptr, nullptr, true);
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_tharnok_ronces_de_givre::HandleProc,
                            EFFECT_1, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

/*
 * ---------------------------------------------------------------------------
 * Xer'Thul, Maitre des Chaines — objet 84008
 *
 * spell_xerthul_nuee_demoniaque (84427) : chaque tick des deux afflictions
 * custom a une chance d arracher un demon au Vide. Le tirage et l ICD de 1,5 s
 * sont dans spell_proc ; le script ne fait que deux choses que la base ne sait
 * pas exprimer — n accepter que nos deux DoT, et choisir un demon au hasard
 * parmi cinq.
 *
 * npc_xerthul_demon : les cinq gabarits (84200 a 84204) partagent cette IA.
 * Ce sont des gardiens (SummonProperties 61), donc deja non controlables, lies
 * au lanceur, et leurs degats sont credites au proprietaire. Restent a regler
 * ici les points de vie, calques sur ceux du demoniste, et la prise de cible.
 * ---------------------------------------------------------------------------
 */

enum XerthulSpells
{
    SPELL_CORRUPTION_XERTHUL = 84424,
    SPELL_IMMOLATION_XERTHUL = 84425
};

static constexpr uint32 XERTHUL_DEMONS[] = { 84428, 84429, 84430, 84431, 84432 };
static constexpr float  XERTHUL_PART_PV  = 0.15f;

class spell_xerthul_nuee_demoniaque : public AuraScript
{
    PrepareAuraScript(spell_xerthul_nuee_demoniaque);

    // Les ProcFlags ne savent pas distinguer nos deux afflictions des autres
    // degats periodiques du demoniste : ses propres Corruption et Immolation
    // declencheraient sinon la nuee tout autant.
    bool CheckProc(ProcEventInfo& eventInfo)
    {
        SpellInfo const* source = eventInfo.GetSpellInfo();
        return source && (source->Id == SPELL_CORRUPTION_XERTHUL
                       || source->Id == SPELL_IMMOLATION_XERTHUL);
    }

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& /*eventInfo*/)
    {
        PreventDefaultAction();

        if (Unit* porteur = GetTarget())
            porteur->CastSpell(porteur, XERTHUL_DEMONS[urand(0, 4)], true);
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_xerthul_nuee_demoniaque::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_xerthul_nuee_demoniaque::HandleProc,
                            EFFECT_0, SPELL_AURA_DUMMY);
    }
};

struct npc_xerthul_demon : public ScriptedAI
{
    npc_xerthul_demon(Creature* c) : ScriptedAI(c) { }

    void InitializeAI() override
    {
        ScriptedAI::InitializeAI();

        Unit* maitre = me->GetCharmerOrOwner();
        if (!maitre)
            return;

        // Les gardiens tirent leurs statistiques de leur niveau, pas de celles
        // de leur invocateur : on recale donc les points de vie a la main.
        uint32 const pv = std::max<uint32>(1, uint32(maitre->GetMaxHealth() * XERTHUL_PART_PV));
        me->SetMaxHealth(pv);
        me->SetHealth(pv);

        // Degats sentinelles, a calibrer.
        me->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, 1234.0f);
        me->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, 1234.0f);
        me->UpdateDamagePhysical(BASE_ATTACK);

        // Il prend la cible du demoniste, ou a defaut celle qu il vise.
        Unit* cible = maitre->GetVictim();
        if (!cible)
            if (Player* joueur = maitre->ToPlayer())
                cible = joueur->GetSelectedUnit();

        if (cible && cible->IsAlive() && maitre->IsValidAttackTarget(cible))
            AttackStart(cible);
    }

    // Si le demoniste change de cible, le demon suit.
    void OwnerAttacked(Unit* cible) override
    {
        if (!cible || (me->GetVictim() && me->GetVictim()->IsAlive()))
            return;

        AttackStart(cible);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_vindictus_bouclier_seraphin — sort 84681, objet 84021
 *
 * Trois boucliers vengeurs sur les trois ennemis les plus proches dans 30 m.
 * Le DBC ne sait pas exprimer « les N plus proches » : ses ciblages de zone
 * tirent au hasard. Le script les designe donc, et chaque bouclier rebondit
 * ensuite tout seul cinq fois — la chaine et sa portee sont en base.
 * ---------------------------------------------------------------------------
 */

enum VindictusSpells
{
    SPELL_BOUCLIER_SERAPHIN = 84680
};

static constexpr float VINDICTUS_PORTEE = 30.0f;

class spell_vindictus_bouclier_seraphin : public AuraScript
{
    PrepareAuraScript(spell_vindictus_bouclier_seraphin);

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& /*eventInfo*/)
    {
        PreventDefaultAction();

        Unit* porteur = GetTarget();
        if (!porteur)
            return;

        std::list<Unit*> cibles;
        Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(porteur, porteur, VINDICTUS_PORTEE);
        Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> chercheur(porteur, cibles, verif);
        Cell::VisitObjects(porteur, chercheur, VINDICTUS_PORTEE);

        cibles.remove_if([porteur](Unit* u)
        {
            return !u || !u->IsAlive() || !porteur->IsValidAttackTarget(u);
        });

        if (cibles.empty())
            return;

        cibles.sort(Acore::ObjectDistanceOrderPred(porteur));

        uint8 lances = 0;
        for (Unit* cible : cibles)
        {
            if (lances++ >= 3)
                break;
            porteur->CastSpell(cible, SPELL_BOUCLIER_SERAPHIN, true);
        }
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_vindictus_bouclier_seraphin::HandleProc,
                            EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

/*
 * ---------------------------------------------------------------------------
 * spell_salvation_egide — sort 84700, objet 84022
 *
 * Veilleur permanent, un battement par seconde. Quand le groupe entier tombe
 * sous 40 % de ses points de vie, il protege tout le monde pendant 15 s et
 * cloue le porteur sur place, inarretable.
 *
 * Le seuil porte sur le total du groupe, pas sur chaque membre pris a part :
 * c est la somme des points de vie courants rapportee a la somme des maximums.
 * Elle est recalculee a chaque battement, donc une arrivee ou un depart est
 * pris en compte immediatement.
 * ---------------------------------------------------------------------------
 */

enum SalvationSpells
{
    SPELL_EGIDE_PROTECTION   = 84701,   // invulnerabilite totale, tout le raid
    SPELL_EGIDE_IMMOBILISE   = 84702,   // le porteur, agenouille et inarretable
    SPELL_EGIDE_RECHARGE     = 84703    // debuff de recharge, 10 min (DBC)
};

static constexpr uint32 SALVATION_SEUIL_PCT = 40;

class spell_salvation_egide : public AuraScript
{
    PrepareAuraScript(spell_salvation_egide);

    void HandlePeriodic(AuraEffect const* /*aurEff*/)
    {
        PreventDefaultAction();

        Player* porteur = GetTarget()->ToPlayer();
        if (!porteur || !porteur->IsInCombat() || !porteur->IsAlive())
            return;

        // voir Nairun : le debuff de recharge est la seule source de verite
        if (porteur->HasAura(SPELL_EGIDE_RECHARGE))
            return;

        uint64 vie = 0;
        uint64 vieMax = 0;

        if (Group* groupe = porteur->GetGroup())
        {
            for (GroupReference* ref = groupe->GetFirstMember(); ref; ref = ref->next())
            {
                Player* membre = ref->GetSource();
                if (!membre || !membre->IsAlive() || membre->GetMapId() != porteur->GetMapId())
                    continue;
                vie    += membre->GetHealth();
                vieMax += membre->GetMaxHealth();
            }
        }
        else
        {
            vie    = porteur->GetHealth();
            vieMax = porteur->GetMaxHealth();
        }

        if (!vieMax || vie * 100 >= vieMax * SALVATION_SEUIL_PCT)
            return;

        porteur->CastSpell(porteur, SPELL_EGIDE_PROTECTION, true);
        porteur->CastSpell(porteur, SPELL_EGIDE_IMMOBILISE, true);
        porteur->CastSpell(porteur, SPELL_EGIDE_RECHARGE, true);
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_salvation_egide::HandlePeriodic,
                                EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
    }
};

enum SolarethSpells
{
    SPELL_SOLARETH_SOIN    = 84721,  // effet 1, soin a cible unique, porte le visuel
    SPELL_SOLARETH_ZONE    = 84722,  // effet 2, soin de zone 8 yd, sans visuel
    SPELL_GUIDE_DE_LUMIERE = 53563     // Guide de lumiere, aura portee par sa cible
};

// portee de propagation du Guide de lumiere en 3.3.5
static constexpr float SOLARETH_PORTEE_GUIDE = 60.0f;

// 84720 - Souffle de Solareth, aura porteuse
//
// Chaque soin direct du paladin declenche une salve complete — effet 1 sur la
// cible soignee, puis effet 2 autour d elle — et une seconde salve identique
// centree sur le porteur du Guide de lumiere. Les deux se superposent quand le
// paladin soigne directement ce porteur, qui recoit alors tout en double.
//
// Solareth relaie lui-meme vers le porteur du guide, sans passer par le guide
// de Blizzard. Deux raisons : celui-ci refuse de repercuter un soin deja lance
// sur son porteur (spell_paladin.cpp:2229), ce qui supprimerait le doublement
// voulu ; et l y faire entrer aurait demande de passer nos soins en famille
// paladin, les exposant aux talents et glyphes visant Lumiere sacree.
//
// Le porteur du guide est cherche dans le groupe plutot que dans la grille : le
// sort 53563 ne vise qu un membre du raid (cible 57), la liste est donc
// exhaustive, et ce declenchement a lieu a chaque soin, sans temps de recharge.
//
// Aucune des quatre salves ne peut relancer le cycle : toutes passent aurEff,
// donc se rattachent a cette aura, ce que le premier garde-fou de
// GetProcEffectMask refuse sans condition (SpellAuras.cpp:2147). Elles sont en
// outre declenchees, et la ligne spell_proc de 84720 ne porte pas
// PROC_ATTR_TRIGGERED_CAN_PROC (SpellAuras.cpp:2158).
class spell_solareth_souffle : public AuraScript
{
    PrepareAuraScript(spell_solareth_souffle);

    static void Salve(Unit* lanceur, Unit* centre, AuraEffect const* aurEff)
    {
        lanceur->CastSpell(centre, SPELL_SOLARETH_SOIN, true, nullptr, aurEff);
        lanceur->CastSpell(centre, SPELL_SOLARETH_ZONE, true, nullptr, aurEff);
    }

    static Unit* TrouveGuide(Unit* lanceur)
    {
        if (lanceur->HasAura(SPELL_GUIDE_DE_LUMIERE, lanceur->GetGUID()))
            return lanceur;

        Player* joueur = lanceur->ToPlayer();
        if (!joueur)
            return nullptr;

        Group* groupe = joueur->GetGroup();
        if (!groupe)
            return nullptr;

        for (GroupReference* ref = groupe->GetFirstMember(); ref; ref = ref->next())
        {
            Player* membre = ref->GetSource();
            if (!membre || !membre->IsAlive() || membre == joueur)
                continue;
            if (!membre->IsInMap(joueur) || !membre->IsWithinDistInMap(joueur, SOLARETH_PORTEE_GUIDE))
                continue;
            if (membre->HasAura(SPELL_GUIDE_DE_LUMIERE, joueur->GetGUID()))
                return membre;
        }
        return nullptr;
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();

        Unit* lanceur = GetTarget();
        Unit* cible = eventInfo.GetProcTarget();
        if (!lanceur || !cible)
            return;

        Salve(lanceur, cible, aurEff);

        if (Unit* guide = TrouveGuide(lanceur))
            Salve(lanceur, guide, aurEff);
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_solareth_souffle::HandleProc,
                            EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

// 84722 - Souffle de Solareth, effet de zone
// La cible qui sert de centre est retiree de la selection : elle vient de
// recevoir l effet 1, la zone ne concerne que les allies autour d elle.
class spell_solareth_zone : public SpellScript
{
    PrepareSpellScript(spell_solareth_zone);

    void FiltreCibles(std::list<WorldObject*>& cibles)
    {
        if (Unit* centre = GetExplTargetUnit())
            cibles.remove(centre);
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(
            spell_solareth_zone::FiltreCibles, EFFECT_0, TARGET_UNIT_DEST_AREA_ALLY);
    }
};

void SC_AddPapotaSpellScripts()
{
    RegisterSpellScript(spell_nairun_appel_des_anciens);
    RegisterSpellScript(spell_kelrah_etreinte_des_esprits);
    RegisterSpellScript(spell_crocs_ecorchement);
    RegisterSpellScript(spell_liora_seve);
    RegisterSpellScript(spell_liora_appel_des_racines);
    RegisterSpellScript(spell_elundor_cycle_celeste);
    RegisterSpellScript(spell_tharnok_ronces_de_givre);
    RegisterSpellScript(spell_xerthul_nuee_demoniaque);
    RegisterSpellScript(spell_vindictus_bouclier_seraphin);
    RegisterSpellScript(spell_salvation_egide);
    RegisterSpellScript(spell_solareth_souffle);
    RegisterSpellScript(spell_solareth_zone);
    RegisterCreatureAI(npc_xerthul_demon);
}

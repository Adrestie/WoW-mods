/*
 * mod-papota-spherier — scripts monde.
 *
 * La definition est chargee avant l'ouverture du monde, comme les autres
 * donnees custom (motif mod-item-upgrade). Le rechargement a chaud passe par
 * .spherier reload, pas par .reload config : rien ne vit dans un .conf.
 */

#include "EventProcessor.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "SpherierLoot.h"
#include "SpherierMgr.h"
#include "SpherierPlayerMgr.h"

class SpherierWorldScript : public WorldScript
{
public:
    SpherierWorldScript() : WorldScript("SpherierWorldScript",
        {
            WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED
        }) { }

    void OnBeforeWorldInitialized() override
    {
        sSpherierMgr->Charger();
    }
};

class SpherierPlayerScript : public PlayerScript
{
public:
    SpherierPlayerScript() : PlayerScript("SpherierPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN,
            PLAYERHOOK_ON_LOGOUT,
            PLAYERHOOK_ON_CREATURE_KILL,
            PLAYERHOOK_ON_CREATURE_KILLED_BY_PET,
            // Les rangs accordes par les runes suivent les talents en direct.
            PLAYERHOOK_ON_TALENTS_RESET,
            PLAYERHOOK_ON_AFTER_SPEC_SLOT_CHANGED,
            PLAYERHOOK_ON_LEARN_SPELL
        }) { }

    void OnPlayerLogin(Player* player) override
    {
        sSpherierPlayerMgr->Charger(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        sSpherierPlayerMgr->Decharger(player);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        sSpherierPlayerMgr->CrediterBoss(killer, killed);
    }

    // Un familier ou un totem qui porte le coup fatal ne declenche pas le hook
    // precedent (lecon du comptage M+).
    void OnPlayerCreatureKilledByPet(Player* petOwner, Creature* killed) override
    {
        sSpherierPlayerMgr->CrediterBoss(petOwner, killed);
    }

    // --- suivi des talents -------------------------------------------------
    // Un sort de talent perdu doit desactiver ses runes SUR-LE-CHAMP, sans que
    // le joueur ait a ouvrir la moindre interface.
    //
    // Deux precautions, verifiees dans le coeur :
    //
    //  - OnPlayerTalentsReset part AVANT la remise a zero. Recalculer ici
    //    verrait encore l'ancien etat : on differe d'un tour de boucle.
    //  - OnPlayerLearnSpell part une fois PAR SORT, soit une rafale entiere
    //    lors d'un repec. Le meme report sert de dedoublonnage : plusieurs
    //    demandes dans le meme tour n'en font qu'une.
    void OnPlayerTalentsReset(Player* player, bool /*noCost*/) override
    {
        ReporterSynchronisation(player);
    }

    void OnPlayerAfterSpecSlotChanged(Player* player, uint8 /*newSlot*/) override
    {
        ReporterSynchronisation(player);
    }

    void OnPlayerLearnSpell(Player* player, uint32 /*spellId*/) override
    {
        ReporterSynchronisation(player);
    }

private:
    // Une seule synchronisation par tour de boucle et par joueur.
    class SynchroniserEvent : public BasicEvent
    {
    public:
        explicit SynchroniserEvent(Player* joueur) : _guid(joueur->GetGUID()) { }

        bool Execute(uint64 /*time*/, uint32 /*diff*/) override
        {
            if (Player* joueur = ObjectAccessor::FindPlayer(_guid))
                sSpherierPlayerMgr->SynchroniserRunes(joueur);
            return true;
        }

    private:
        ObjectGuid _guid;
    };

    void ReporterSynchronisation(Player* player)
    {
        if (!player || !sSpherierPlayerMgr->Etat(player))
            return;
        player->m_Events.AddEventAtOffset(new SynchroniserEvent(player), 1ms);
    }
};

// Sphere consommee : le clic droit lance le sort de l'objet, exactement comme
// pour n'importe quel consommable, et l'objet part avec sa charge. Le sort ne
// fait rien par lui-meme — c'est ce script qui credite les points, et le
// NOMBRE de points est porte par le sort (EffectBasePoints), donc lu ici par
// GetEffectValue(). Une seule valeur : le client l'affiche par $s1 dans
// l'infobulle, le serveur l'applique. Rattachement par spell_script_names.
class spell_spherier_sphere : public SpellScript
{
    PrepareSpellScript(spell_spherier_sphere);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (!joueur)
            return;

        int32 const points = GetEffectValue();
        if (points > 0)
            sSpherierPlayerMgr->Gagner(joueur, uint32(points));
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_spherier_sphere::HandleDummy,
                                 EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// Le NEXUS PRISMATIQUE (2026-09-06) : un prisme de plus au compte, et tous les
// gains de Spherite montent de 25 % — sans plafond.
class spell_spherier_prisme : public SpellScript
{
    PrepareSpellScript(spell_spherier_prisme);

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* joueur = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (joueur)
            sSpherierPlayerMgr->AbsorberPrisme(joueur);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_spherier_prisme::HandleDummy,
                                 EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// Injection des objets du sphèrier dans le butin. Le crochet part sur CHAQUE
// butin rempli du serveur : le tri se fait dans SpherierRemplirButin, dès le
// magasin, avant toute lecture.
class SpherierLootScript : public MiscScript
{
public:
    SpherierLootScript() : MiscScript("SpherierLootScript",
        {
            MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS
        }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/,
        LootStore const& store, Player* lootOwner, bool /*personal*/,
        bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        SpherierRemplirButin(loot, store, lootOwner);
    }
};

void AddSC_spherier_scripts()
{
    new SpherierWorldScript();
    new SpherierPlayerScript();
    new SpherierLootScript();
    RegisterSpellScript(spell_spherier_sphere);
    RegisterSpellScript(spell_spherier_prisme);
}

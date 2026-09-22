/*
 * This file is part of mod-stellar-tarot.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * mod-stellar-tarot — LE GARDIEN QU'UNE CARTE FAIT VENIR.
 *
 * Deux cartes appellent une creature a leur secours : le sanglier de La Harde
 * (139 niveau 4) et le double du Miroir (74 niveau 2). Les deux se comportent
 * en GARDIENS -- ils appartiennent au joueur, prennent sa faction et son
 * niveau, frappent ce qu'ils voient et disparaissent d'eux-memes.
 *
 * CE QUE LE COEUR FAIT TOUT SEUL : l'invocation et sa duree
 * (`SummonCreature` + `TEMPSUMMON_TIMED_DESPAWN`), la propriete
 * (`SetOwnerGUID`, `SetCreatorGUID`), la menace (`ThreatManager::AddThreat`).
 * Le module ne fait que dire les chiffres -- niveau, PV, cadence -- et choisir
 * qui provoquer.
 *
 * CE QUI LES SEPARE :
 *   le sanglier  PV du maitre x3, provoque tout ce qui est a portee TOUTES LES
 *                CINQ SECONDES, les boss exceptes ;
 *   le double    le visage et l'equipement du maitre, et il ne provoque
 *                QU'UNE FOIS, a son arrivee.
 */

#include "Creature.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "StellarTarotMgr.h"
#include "TemporarySummon.h"
#include "ThreatManager.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"

namespace
{
    constexpr float GARDIEN_PORTEE = 10.0f;      // metres
    constexpr uint32 GARDIEN_CADENCE = 5000;     // millisecondes entre deux cris

    // LA PROVOCATION : le coeur porte la menace, on lui en donne beaucoup. Un
    // BOSS n'est jamais provoque -- la carte le dit, et de toute facon le coeur
    // le refuserait.
    void Provoquer(Creature* gardien, float portee)
    {
        if (!gardien)
            return;
        std::list<Unit*> autour;
        Acore::AnyUnfriendlyUnitInObjectRangeCheck check(gardien, gardien, portee);
        Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> searcher(gardien, autour, check);
        Cell::VisitObjects(gardien, searcher, portee);
        for (Unit* ennemi : autour)
        {
            if (!ennemi || !ennemi->IsAlive())
                continue;
            Creature* const bete = ennemi->ToCreature();
            if (bete && (bete->isWorldBoss() || bete->IsDungeonBoss()))
                continue;
            ennemi->GetThreatMgr().AddThreat(gardien, 1000000.0f, nullptr, true, true);
            if (bete && bete->AI())
                bete->AI()->AttackStart(gardien);
        }
    }
}

struct npc_stellar_tarot_guardian : public ScriptedAI
{
    npc_stellar_tarot_guardian(Creature* creature) : ScriptedAI(creature) { }

    void InitializeAI() override
    {
        ScriptedAI::InitializeAI();
        Unit* const maitre = me->ToTempSummon() ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
        if (!maitre)
            return;
        me->SetFaction(maitre->GetFaction());
        me->SetLevel(maitre->GetLevel());
        me->SetOwnerGUID(maitre->GetGUID());
        me->SetCreatorGUID(maitre->GetGUID());
        me->SetReactState(REACT_AGGRESSIVE);
        if (me->GetEntry() == STELLAR_TAROT_NPC_BOAR)
        {
            // TROIS FOIS LES PV DU MAITRE : la carte le dit ainsi.
            me->SetMaxHealth(maitre->GetMaxHealth() * 3);
            me->SetFullHealth();
            _cadence = GARDIEN_CADENCE;
        }
        else if (me->GetEntry() == STELLAR_TAROT_NPC_DOUBLE)
        {
            // LE MEME VISAGE ET LE MEME HARNOIS : un double, non un etranger.
            me->SetDisplayId(maitre->GetDisplayId());
            me->SetMaxHealth(maitre->GetMaxHealth());
            me->SetFullHealth();
            if (Player* const joueur = maitre->ToPlayer())
                for (uint8 slot = 0; slot < 3; ++slot)
                    me->SetUInt32Value(UNIT_VIRTUAL_ITEM_SLOT_ID + slot,
                                       joueur->GetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + slot * 2));
            _cadence = 0;               // il ne crie qu'une fois
        }
        Provoquer(me, GARDIEN_PORTEE);
        _depuis = 0;
    }

    void UpdateAI(uint32 diff) override
    {
        // LE CRI QUI REVIENT : seul le sanglier en a un.
        if (_cadence)
        {
            _depuis += diff;
            if (_depuis >= _cadence)
            {
                _depuis = 0;
                Provoquer(me, GARDIEN_PORTEE);
            }
        }
        // SANS CET APPEL UNE CREATURE NE FRAPPE JAMAIS.
        if (UpdateVictim())
            DoMeleeAttackIfReady();
    }

private:
    uint32 _cadence = 0;
    uint32 _depuis = 0;
};

void AddSC_stellar_tarot_guardian()
{
    RegisterCreatureAI(npc_stellar_tarot_guardian);
}

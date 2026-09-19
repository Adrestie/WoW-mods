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
 * LE PROC DU COEUR, RENDU A LA LIGNE QUI L'ATTEND.
 *
 * Le systeme de procs du coeur ne sait lancer qu'un SORT quand une aura part.
 * Le module s'en servait pour se prevenir lui-meme : l'aura lancait un sort
 * vide -- un MARQUEUR -- que le module reconnaissait au vol. Un aller-retour de
 * sa fabrication, dix sorts de reserve, et quatre memoires tenues a la main
 * pour retrouver l'unite et le montant que le marqueur ne portait pas.
 *
 * Le coeur a pourtant son propre moyen de faire tourner du code sur un proc :
 * l'`AuraScript` et son `OnEffectProc`. Mesure faite en jeu (carte 91 N1, dix
 * occasions, sept departs, sept appels) :
 *
 *   - le script n'est appele que sur les procs ACCEPTES : la chance et la
 *     recharge de `spell_proc` filtrent avant lui ;
 *   - `eventInfo.GetActor()` et `GetActionTarget()` donnent les deux unites ;
 *   - `GetDamageInfo()` et `GetHealInfo()` donnent le montant ;
 *   - `GetHitMask()` dit meme s'il s'agissait d'un critique.
 *
 * Tout ce que le marqueur reconstituait, le coeur le donne. Le marqueur n'a
 * donc plus lieu d'etre : une aura trigger par ligne, un nom de script, et la
 * ligne est prevenue par le coeur lui-meme.
 *
 * L'AURA NOMME LA LIGNE : `GetId()` est le `trigger:` que la ligne declare. Une
 * aura de TEMOIN (902700-902708), posee par l'instrument de mesure, ne reveille
 * aucune ligne : elle ne sert qu'a compter les occasions.
 */

#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "StellarTarotEffects.h"
#include "StellarTarotMgr.h"
#include "Unit.h"

class spell_stellar_tarot_line : public AuraScript
{
    PrepareAuraScript(spell_stellar_tarot_line);

    void HandleProc(ProcEventInfo& eventInfo)
    {
        Unit* const owner = GetUnitOwner();
        Player* const player = owner ? owner->ToPlayer() : nullptr;
        if (!player)
            return;
        // L'AUTRE UNITE : celle que le joueur a touchee quand il agit, celle
        // qui l'a frappe quand il subit. Le coeur nomme l'acteur et l'unite de
        // l'action ; le joueur est l'un des deux.
        Unit* autre = eventInfo.GetActor() == player ? eventInfo.GetActionTarget()
                                                     : eventInfo.GetActor();
        uint32 montant = 0;
        if (DamageInfo* const degats = eventInfo.GetDamageInfo())
            montant = degats->GetDamage();
        else if (HealInfo* const soin = eventInfo.GetHealInfo())
            montant = soin->GetHeal();
        StellarTarotEffects::OnProc(player, GetId(), autre, montant);
    }

    void Register() override
    {
        // LE CROCHET SE PREND SUR L'AURA, non sur un de ses effets : l'aura
        // d'une ligne ne porte qu'une aura factice, mais celle d'un ETAT porte
        // un effet reel (+100 % de critique, 500 points d'expertise), et
        // `OnEffectProc` aurait refuse de s'y lier. `OnProc` est appele pour
        // toute aura qui part, avant la boucle de ses effets.
        OnProc += AuraProcFn(spell_stellar_tarot_line::HandleProc);
    }
};

void AddSC_stellar_tarot_proc()
{
    RegisterSpellScript(spell_stellar_tarot_line);
}

/*
 * This file is part of mod-spheregrid.
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
 * The custom class spells of the sphere grid.
 *
 * FIFTEEN SCRIPTS ONLY, where thirty-one seemed needed: effect 27,
 * PERSISTENT_AREA_AURA, exists in 3.3.5 — it is what makes Consecration and
 * Rain of Fire. It drops a dynamic object at the target point that applies a
 * periodic aura to whoever stands there, and that alone covered every ground
 * area of ours: judgement, barrier, singularity, burns, angelic feather. Three
 * auras are enough to tell them apart — 87 for damage taken, 53 for the drain
 * that heals the caster, 3 for the burn. A damage cone, a cone heal and a
 * periodic channel are likewise written entirely in the DBC.
 *
 * What is left here is what no field can express: reading a resource, drawing
 * lots, measuring a distance, summoning, counting casts.
 *
 * THE DIRECTION RULE first, because every linear movement shares it: a leap goes
 * where the character IS GOING if he moves, and straight ahead if he stands
 * still.
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
    // --- the leap ----------------------------------------------------------
    constexpr uint32 GUST = 8600060;   // the shaman's leap
    constexpr float GUST_FACTOR = 1.5f;  // 30 m: twice the ordinary leap,
                                                // less a quarter
    constexpr float GUST_SPEED = 1.2f;  // +20 %
    constexpr float LEAP_DISTANCE = 20.0f;
    constexpr float LEAP_SPEED = 22.0f;
    constexpr float LEAP_HEIGHT = 9.0f;
    // The TARGETED heroic leap has settings of its own — the directional leaps
    // keep the values above.
    // THE DURATION DRIVES THE SPEED: 0.15 s at point blank, 0.75 s at maximum
    // range, linear in between. Fixed speeds were silently clipped to 28 m/s by
    // the spline cap (MoveSplineInit::Launch: max(28, run speed x 4) outside
    // flight, mirroring the client) — hence a leap that always felt too slow.
    constexpr float LEAP_H_DURATION_MIN = 0.15f;
    constexpr float LEAP_H_DURATION_MAX = 0.75f;
    constexpr float LEAP_H_RANGE = 35.0f;
    constexpr float LEAP_H_APEX = 14.0f;
    // THE DRESSING COMES FROM THE SPELL. The leap has two moments — the flight
    // and the impact — and the impact must fall on landing, which no field of
    // Spell.dbc can date: the script is therefore the only one able to send it.
    // What it no longer decides is WHAT to send: the SpellVisual field of the
    // spell says so, and at zero the leap goes bare. That is how one leap can be
    // silent without touching another that shares the very same code.
    //
    // The table is here because the server does not load the kit columns of
    // SpellVisual.dbc — DBCStructure.h leaves them commented out, only HasMissile
    // and MissileModel are read.
    struct LeapDressing
    {
        uint32 visual, flight, impact;
    };
    constexpr LeapDressing LEAP_H_DRESSINGS[] = { { 30028, 30026, 30027 } };
    // The animations live INSIDE the kits (a ready stance during the flight, a
    // special attack folded into the impact): timing them to end on the impact is
    // impossible, every strike lasts 900-1500 ms (measured in the M2) against
    // 750 ms of flight at most, and no channel of 3.3.5 modulates the speed of an
    // animation.

    // --- the smoke dash ----------------------------------------------------
    // A seven-step sequence, all of it orchestrated here: 1 a ground reticle
    // (DBC); 2 an INVISIBLE dummy at the target point; 3 smoke on the player;
    // 4 the character turns invisible and untargetable; 5 he TELEPORTS onto the
    // dummy — a copy of the rogue teleport, which replaced a charge: MoveCharge
    // suffered the spline cap (four times the run speed, server AND client) and
    // the speed acknowledgement; 6 smoke on the dummy; 7 he reappears.
    constexpr uint32 DASH_DUMMY = 803804;       // clone trigger, display 802102
    constexpr uint32 DASH_SMOKE_KIT = 404;      // the Vanish cast kit
    constexpr uint32 DASH_INVISIBLE = 802102;   // a display at opacity 0 (every race)
    constexpr uint32 DASH_STEP = 8600039;        // a copy of the heart of the
                                                // shadow step (36563), a
                                                // triggered cast
    // Between the teleport and the reappearance: the time for the client to take
    // the new position in before the character is shown again.
    constexpr uint32 DASH_MARGIN = 100;

    // --- summoned creatures ------------------------------------------------
    // ALL OF THEM OURS. The borrowed ones turned out to be enemies: a ghoul of
    // the world is faction 14 — hostile to everyone — carrying the death knight
    // pet script, and a guard is a demon on SmartAI. Our clones take their models
    // and their figures without their past; their own AI gives them the faction
    // of the summoner and the target of his master.
    constexpr uint32 SEDUCTION = 6358;   // the succubus's NATIVE Seduction
    constexpr uint32 GHOUL = 803801;
    constexpr uint32 GUARD_DEATH = 803802;
    constexpr uint32 TOTEM = 803803;

    constexpr uint32 STEED_ASPECT = 14584;   // the paladin charger's look

    constexpr uint32 CHAIN_LIGHTNING = 49271; // Chain Lightning, MAX rank --
                                         // rank 1 hit like a level 6

    // --- the mage ----------------------------------------------------------
    constexpr float SHIMMER_DISTANCE = 40.0f;    // a copy of Blink: 40 m
    // Shimmer works IN TWO STEPS: the first cast places the marker and REMOVES
    // the cooldown the core has just applied (it is sent BEFORE the effects, see
    // Spell::cast); the return leaves it to fall naturally; the expiry of the
    // marker applies it by hand.
    constexpr uint32 SHIMMER_MARKER = 803810;    // display 802107, a rune on the ground
    constexpr uint32 SHIMMER_WITNESS = 8600058;   // the 5 s aura
    constexpr uint32 SHIMMER_WINDOW = 5000;     // ms -- the window to return in
    constexpr uint32 SHIMMER_COOLDOWN = 20000;   // ms -- a mirror of the DBC
    constexpr uint32 SHIMMER = 8600070;
    constexpr uint32 ORB_CREATURE = 803806;    // the visible orb (display 802158)
    constexpr int32 ORB_DAMAGE = 750;          // a mirror of the DBC's $s1
    constexpr float ORB_RANGE = 30.0f;        // how far the orb runs
    constexpr float ORB_SPEED = 16.0f;       // m/s — speed d'origine
                                                // RESTORED, the
                                                // brake on the target stays
    constexpr float ORB_SPEED_SLOW = 1.0f;  // the DRASTIC brake once a
                                                // target is within the radius
    constexpr float ORB_RADIUS = 3.0f;          // the radius it strikes in
    constexpr uint32 ORB_KIT_IMPACT = 30033;   // the exported impact sound
    constexpr uint32 ORB_TICK = 250;            // ms -- the sweep's pace
                                                // (a reactive brake); the
                                                // DAMAGE lands every
                                                // 1000 ms (accumulator)
    // The animation cycle: the stand pose blends PERFECTLY into the hold one (the
    // birth pause is removed, the orb leaves at once); hold loops IN FLIGHT (the
    // sequence is retagged as a run in the model); decay (333 ms) fires on
    // arrival through a custom emote.
    constexpr uint32 ORB_DECAY = 333;          // ms -- how long Decay lasts
    constexpr uint32 ORB_EMOTE_DECAY = 990001; // Emotes.dbc custom (anim 159)


    /*
     * The movement angle, RELATIVE to the character's orientation.
     *
     * The client sends a mask of the keys held on top of the orientation.
     * Opposite combinations cancel out — forward and backward together move
     * nothing — which falls back on where he looks, and that is the wanted
     * behaviour.
     */
    float MovementAngle(Unit const* unit)
    {
        uint32 const f = unit->GetUnitMovementFlags();
        int const forwardBack = ((f & MOVEMENTFLAG_FORWARD) ? 1 : 0)
                               - ((f & MOVEMENTFLAG_BACKWARD) ? 1 : 0);
        int const leftRight = ((f & MOVEMENTFLAG_STRAFE_LEFT) ? 1 : 0)
                               - ((f & MOVEMENTFLAG_STRAFE_RIGHT) ? 1 : 0);

        if (forwardBack == 0 && leftRight == 0)
            return 0.0f;                              // standing still: straight ahead
        if (forwardBack == 0)
            return leftRight > 0 ? float(M_PI) / 2.0f : -float(M_PI) / 2.0f;
        if (leftRight == 0)
            return forwardBack > 0 ? 0.0f : float(M_PI);
        float const base = forwardBack > 0 ? 0.0f : float(M_PI);
        float const side = float(M_PI) / 4.0f * float(leftRight);
        return forwardBack > 0 ? base + side : base - side;
    }

    /*
     * Leap in a direction, for a PLAYER.
     *
     * MotionMaster::MoveJumpTo refuses players, and its own comment says why:
     * "this function may make players fall below map". It goes through
     * GetClosePoint, which does not test the geometry. So we go through
     * MovePositionToFirstCollision — which ADDS the orientation itself, hence a
     * relative angle and never an absolute one — then MoveJump.
     */
    void LeapTowards(Unit* unit, float relativeAngle, float distance,
                    bool keepCap = false, float speed = LEAP_SPEED,
                    float height = LEAP_HEIGHT)
    {
        Position destination = unit->GetPosition();
        unit->MovePositionToFirstCollision(destination, distance, relativeAngle);
        if (!keepCap)
        {
            unit->GetMotionMaster()->MoveJump(destination, speed,
                                               height);
            return;
        }
        // THE JUMP THAT DOES NOT TURN THE CHARACTER: with no heading given,
        // the spline orients the unit along its path — the character used to
        // pivot towards his destination. MoveJump offers no way to say
        // otherwise; so the spline is built by hand and given the CURRENT
        // heading. The rest follows MoveJump word for word, apex included.
        float const moitie = height / float(Movement::gravity);
        float const apogee =
            -Movement::computeFallElevation(moitie, false, -height);
        Movement::MoveSplineInit init(unit);
        init.MoveTo(destination.GetPositionX(), destination.GetPositionY(),
                    destination.GetPositionZ());
        init.SetParabolic(apogee, 0.0f);
        init.SetVelocity(speed);
        init.SetFacing(unit->GetOrientation());
        init.Launch();
    }

    // =======================================================================
    // Heroic leap — the jump aims at a point
    // =======================================================================
    // A targeted jump: a ground reticle, 20 m. The path is rebuilt from the
    // caster by MovePositionToFirstCollision — no jumping through walls — then
    // MoveJump (with a NON-ZERO apex: without it the client makes the character
    // run along the ground).
    // A FREE FUNCTION on purpose: another class spell has to replay it exactly,
    // and two copies would drift apart at the first adjustment.
    void LeapKits(uint32 visual, uint32& flight, uint32& impact)
    {
        flight = impact = 0;
        for (LeapDressing const& h : LEAP_H_DRESSINGS)
            if (h.visual == visual)
            {
                flight = h.flight;
                impact = h.impact;
                return;
            }
    }

    void HeroicLeap(Unit* caster, WorldLocation const* goal, uint32 visual)
    {
        if (!caster || !goal)
            return;
        // STRAIGHT to the spell's point: recomputing it through
        // MovePositionToFirstCollision could stop at the first fold of the
        // ground — and the client reticle has already validated the
        // destination.
        float dist = caster->GetExactDist(goal);
        float duration = LEAP_H_DURATION_MIN
            + (LEAP_H_DURATION_MAX - LEAP_H_DURATION_MIN)
            * std::min(dist / LEAP_H_RANGE, 1.0f);
        float speed = dist / std::max(duration, 0.001f);

        // Beyond the spline cap, the run speed is FORCED just high enough
        // (client packet included — a raw SetSpeedRate would leave the client
        // at 28 and stretch the splines), then recomputed on landing from the
        // auras. At maximum range the flight needs about 1.67 times the cap.
        bool unbridled = speed > std::max(28.0f,
            caster->GetSpeed(MOVE_RUN) * 4.0f);
        if (unbridled)
            caster->SetSpeed(MOVE_RUN,
                speed / (4.0f * baseMoveSpeed[MOVE_RUN]), true);

        caster->GetMotionMaster()->MoveJump(*goal, speed,
                                             LEAP_H_APEX);
        if (Player* player = caster->ToPlayer())
            sScriptMgr->AnticheatSetUnderACKmount(player);

        // The pose (weapon raised in flight, a strike on impact) lives in the
        // ANIMATIONS of the two kits: an emote state, tried first, does not win
        // over the client's own jump animation.

        // The dressing: the charge state at the start, and the impact at the
        // end of the REAL duration of the spline MoveJump has just laid down —
        // the player touches the ground at that instant, and the effect and its
        // sound (inside the kit) come from him.
        // The weapon stays DRAWN during the jump: casting used to toggle the
        // sheath state and put it away, leaving the ready stance playing on
        // empty hands.
        uint32 flightKit = 0, kitImpact = 0;
        LeapKits(visual, flightKit, kitImpact);
        if (flightKit)
        {
            caster->SetSheath(SHEATH_STATE_MELEE);
            caster->SendPlaySpellVisual(flightKit);
        }
        // The event fires EVEN WITHOUT A KIT: it is what gives the unleashed
        // player his normal speed back, the dressing is only a passenger.
        ObjectGuid guid = caster->GetGUID();
        int32 flight = caster->movespline->Duration();
        caster->m_Events.AddEventAtOffset([guid, unbridled, kitImpact]()
        {
            if (Player* j = ObjectAccessor::FindPlayer(guid))
            {
                if (kitImpact)
                    j->SendPlaySpellVisual(kitImpact);
                if (unbridled)
                    j->UpdateSpeed(MOVE_RUN, true);
            }
        }, Milliseconds(flight));
    }

    class spell_spheregrid_heroic_leap : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_heroic_leap);

        void Leap(SpellEffIndex /*index*/)
        {
            HeroicLeap(GetCaster(), GetExplTargetDest(),
                         GetSpellInfo()->SpellVisual[0]);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_spheregrid_heroic_leap::Leap,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };



    // =======================================================================
    // Shimmer — a teleport, in the direction of the keys
    // =======================================================================
    // Not a jump goal a TELEPORT, 40 m, stopped at the first obstacle, keeping
    // the direction of the movement (a RELATIVE angle —
    // MovePositionToFirstCollision adds the orientation itself).
    // The marker is the one PLACED BY THIS PLAYER (other people's are ignored).
    Creature* ShimmerMarkerOf(Player* player)
    {
        std::list<Creature*> marques;
        player->GetCreatureListWithEntryInGrid(marques, SHIMMER_MARKER,
                                               SHIMMER_DISTANCE * 3.0f);
        for (Creature* marker : marques)
            if (TempSummon* invoquee = marker->ToTempSummon())
                if (invoquee->GetSummonerGUID() == player->GetGUID())
                    return marker;
        return nullptr;
    }

    class spell_spheregrid_shimmer : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_shimmer);

        void Blink(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;
            Player* player = caster->ToPlayer();

            // STEP B — the return: the marker is still there. It is erased
            // and the witness aura removed BY HAND (in the "cancelled" mode,
            // which does not trigger the expiry cooldown); the cooldown of this
            // very cast runs its own course.
            if (player && player->HasAura(SHIMMER_WITNESS))
            {
                if (Creature* marker = ShimmerMarkerOf(player))
                {
                    player->NearTeleportTo(marker->GetPositionX(),
                                           marker->GetPositionY(),
                                           marker->GetPositionZ(),
                                           player->GetOrientation());
                    marker->DespawnOrUnsummon();
                }
                player->RemoveAurasDueToSpell(SHIMMER_WITNESS);
                return;
            }

            // STEP A — the outward trip: the marker stays at the starting
            // point, the mage darts off in the direction of the keys, and the
            // cooldown is REMOVED (the core applied it before the effects).
            if (player)
                player->SummonCreature(SHIMMER_MARKER, *player,
                    TEMPSUMMON_TIMED_DESPAWN, SHIMMER_WINDOW + 500);
            Position destination = caster->GetPosition();
            caster->MovePositionToFirstCollision(destination, SHIMMER_DISTANCE,
                                                  MovementAngle(caster));
            caster->NearTeleportTo(destination.GetPositionX(),
                                    destination.GetPositionY(),
                                    destination.GetPositionZ(),
                                    caster->GetOrientation());
            if (player)
            {
                player->CastSpell(player, SHIMMER_WITNESS, true);
                player->RemoveSpellCooldown(SHIMMER, true);
            }
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_shimmer::Blink,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // The witness aura: on its EXPIRY only (not when the return removes it),
    // the marker falls and the cooldown starts — the return is no longer
    // possible, the next cast will be an outward one.
    class spell_spheregrid_shimmer_marker : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_shimmer_marker);

        void Expire(AuraEffect const* /*effect*/,
                     AuraEffectHandleModes /*mode*/)
        {
            if (GetTargetApplication()->GetRemoveMode()
                != AURA_REMOVE_BY_EXPIRE)
                return;
            Player* player = GetTarget()->ToPlayer();
            if (!player)
                return;
            if (Creature* marker = ShimmerMarkerOf(player))
                marker->DespawnOrUnsummon();
            player->AddSpellCooldown(SHIMMER, 0, SHIMMER_COOLDOWN, true);
            // The packet to the client: the needSendToClient flag of
            // AddSpellCooldown only MARKS the entry, it sends nothing. Without
            // this packet the server refuses the spell while the icon stays
            // lit.
            WorldPacket paquet(SMSG_SPELL_COOLDOWN, 8 + 1 + 4 + 4);
            paquet << player->GetGUID();
            paquet << uint8(SPELL_COOLDOWN_FLAG_NONE);
            paquet << uint32(SHIMMER);
            paquet << uint32(SHIMMER_COOLDOWN);
            player->SendDirectMessage(&paquet);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_spheregrid_shimmer_marker::Expire, EFFECT_0,
                SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // The shaman leap — directional
    // =======================================================================
    class spell_spheregrid_directional_leap : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_directional_leap);

        void Leap(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;
            // This leap DOES NOT TURN the character: the wind pushes him, he
            // does not turn round. And it carries TWICE AS FAR as an ordinary
            // leap.
            bool const gust = m_scriptSpellId == GUST;
            float const distance = gust
                ? LEAP_DISTANCE * GUST_FACTOR : LEAP_DISTANCE;
            float const speed = gust
                ? LEAP_SPEED * GUST_SPEED : LEAP_SPEED;
            LeapTowards(caster, MovementAngle(caster), distance,
                       gust, speed);
        }

        void Register() override
        {
            // DUMMY, and not JUMP_DEST: the core's DEFAULT EffectJumpDest ran
            // AFTER the hook and jumped ON THE SPOT again (the spell
            // destination being the caster), overwriting the script's
            // directional jump. DUMMY has no default behaviour at all. The DBC
            // of the three related spells carries E_DUMMY opposite.
            OnEffectLaunch += SpellEffectFn(spell_spheregrid_directional_leap::Leap,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Arcane orb — a real travelling orb
    // =======================================================================
    // The spell summons a creature dressed in the orb model that flies straight
    // ahead for 40 m; its AI hits each enemy it crosses ONCE, with an EXPLICIT
    // delivery (guaranteed display, no double mitigation) in the name of the
    // spell, with the exported impact sound played on the victim.
    class spell_spheregrid_arcane_orb : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_arcane_orb);

        void Send(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;
            // A WIDE safety net: the brake on a target stretches the flight —
            // the real end is the arrival (decay then despawn, in the AI).
            caster->SummonCreature(ORB_CREATURE, *caster,
                TEMPSUMMON_TIMED_DESPAWN, 30000);
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_arcane_orb::Send,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    struct npc_spheregrid_arcane_orb : public ScriptedAI
    {
        npc_spheregrid_arcane_orb(Creature* c) : ScriptedAI(c)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (summoner)
                owner = summoner->GetGUID();
            // HERE: the speed changes (the brake) reissue the MovePoint
            // towards the SAME point.
            destination = me->GetPosition();
            me->MovePositionToFirstCollision(destination, ORB_RANGE, 0.0f);
            me->SetWalk(false);
            MoveForward(ORB_SPEED);
        }

        void MoveForward(float speed)
        {
            me->GetMotionMaster()->MovePoint(1, destination,
                FORCED_MOVEMENT_NONE, speed, false);
        }

        void MovementInform(uint32 type, uint32 id) override
        {
            // The inform can FIRE AGAIN when the generator is removed during
            // the despawn — decay used to play twice: the guard limits it to
            // ONE.
            if (type != POINT_MOTION_TYPE || id != 1 || decayPlayed)
                return;
            decayPlayed = true;
            me->HandleEmoteCommand(ORB_EMOTE_DECAY);
            me->DespawnOrUnsummon(Milliseconds(ORB_DECAY));
        }

        void UpdateAI(uint32 diff) override
        {
            if (decayPlayed)
                return;
            timer += diff;
            if (timer < ORB_TICK)
                return;
            waited += timer;
            timer = 0;
            Unit* mage = ObjectAccessor::GetUnit(*me, owner);
            if (!mage)
            {
                me->DespawnOrUnsummon();
                return;
            }
            std::list<Unit*> nearby;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(me, mage,
                                                             ORB_RADIUS);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chercheur(me, nearby, verif);
            Cell::VisitObjects(me, chercheur, ORB_RADIUS);

            // The drastic brake, reactive (every ORB_TICK ms): as long as a
            // target is within the radius the orb crawls; it sets off again as
            // soon as it is alone.
            bool braked = !nearby.empty();
            if (braked != slowed)
            {
                slowed = braked;
                MoveForward(braked ? ORB_SPEED_SLOW : ORB_SPEED);
            }

            // The damage, on the other hand, lands EVERY SECOND on whatever
            // is within the radius — no longer one hit per enemy.
            if (waited < 1000)
                return;
            waited = 0;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(8600071);
            if (!info)
                return;
            for (Unit* victim : nearby)
            {
                // THE CRITICAL STRIKE: the core's own pattern
                // (Spell::DoAllEffectOnTarget) — chance dealt then taken, a
                // roll, and CalculateSpellDamageTaken applying the critical
                // bonus, the resistance and the absorption. The spell carries
                // damage class 1 (magic): without it the chance would stay at
                // zero whatever is rolled.
                // skipEffectCheck = TRUE: without it the chance comes back
                // ZERO — SpellInfo::ComputeIsCritCapable only declares a spell
                // "able to crit" when it carries a damage or heal effect, and
                // ours carries a DUMMY only (the damage comes from the AI).
                float chance = mage->SpellDoneCritChance(victim, info,
                    SPELL_SCHOOL_MASK_ARCANE, BASE_ATTACK, true);
                chance = victim->SpellTakenCritChance(mage, info,
                    SPELL_SCHOOL_MASK_ARCANE, chance, BASE_ATTACK, true);
                bool crit = roll_chance_f(std::max(0.0f, chance));

                SpellNonMeleeDamage strike(mage, victim, info,
                                           SPELL_SCHOOL_MASK_ARCANE);
                mage->CalculateSpellDamageTaken(&strike, ORB_DAMAGE, info,
                                                BASE_ATTACK, crit);
                Unit::DealDamageMods(strike.target, strike.damage,
                                     &strike.absorb);
                mage->SendSpellNonMeleeDamageLog(&strike);
                mage->DealSpellDamage(&strike, true);
                victim->SendPlaySpellVisual(ORB_KIT_IMPACT);
            }
        }

        Position destination;
        ObjectGuid owner;
        bool slowed = false;
        bool decayPlayed = false;
        uint32 timer = 0;
        uint32 waited = 0;
    };



    // =======================================================================
    // Ray of frost — the channel that builds up
    // =======================================================================
    // The tick damage is base x the tick number: 100, 200, 300... over the
    // seconds of the channel.
    class spell_spheregrid_ray_of_frost : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_ray_of_frost);

        void Grow(AuraEffect* effect)
        {
            effect->SetAmount((effect->GetBaseAmount() + 1)
                             * int32(effect->GetTickNumber()));
        }

        void Register() override
        {
            OnEffectUpdatePeriodic += AuraEffectUpdatePeriodicFn(
                spell_spheregrid_ray_of_frost::Grow, EFFECT_0,
                SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Smoke dash — vanish here, reappear at the target point
    // =======================================================================
    // The only one of the movements that does NOT follow the direction rule: it
    // aims at a point. The spell carries a ground target, the client shows its
    // aiming circle. The effect is a DUMMY at the destination: no default
    // behaviour, and with no Speed field OnEffectHit fires on the click.
    // A FREE FUNCTION on purpose: a druid form spell replays it exactly.
    void RogueTranslation(Unit* caster, WorldLocation const* goal)
    {
        if (!caster || !goal)
            return;
        // 2. the invisible dummy at the target point — it lives no longer
        // than the dash. Its ORIENTATION is the caster's at the moment of the
        // click: the destination of a teleport carries the orientation of the
        // TARGET, so it is the dummy that decides where the player looks on
        // landing.
        Position where(goal->GetPositionX(), goal->GetPositionY(),
                    goal->GetPositionZ(), caster->GetOrientation());
        Creature* dummy = caster->SummonCreature(DASH_DUMMY, where,
            TEMPSUMMON_TIMED_DESPAWN, DASH_MARGIN + 1500);
        if (!dummy)
            return;

        // 3. the smoke, 4. invisibility and untargetability: AT ONCE, in the
        // same batch of packets — the character vanishes on the spot. "As
        // though he were no longer on the map": untargetable and ignored by
        // spells, ground areas included, of players AND creatures alike. The
        // fight in progress is deliberately NOT broken off: a real removal from
        // the map would make the mobs evade and reset.
        caster->SendPlaySpellVisual(DASH_SMOKE_KIT);
        caster->SetDisplayId(DASH_INVISIBLE);
        caster->SetUnitFlag(UnitFlags(UNIT_FLAG_NOT_SELECTABLE
            | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));

        // 5. the teleport: the copy of the rogue shadow step, cast triggered
        // on the dummy — the core puts the player behind it, instantly, with no
        // spline, no cap and no acknowledgement.
        caster->CastSpell(dummy, DASH_STEP, true);

        // 6. the smoke on the dummy and 7. the reappearance: DASH_MARGIN
        // later, once the client has taken the teleport in.
        ObjectGuid playerGuid = caster->GetGUID();
        ObjectGuid guidDummy = dummy->GetGUID();
        caster->m_Events.AddEventAtOffset([playerGuid, guidDummy]()
        {
            Player* j = ObjectAccessor::FindPlayer(playerGuid);
            if (!j)
                return;
            if (Creature* d = ObjectAccessor::GetCreature(*j, guidDummy))
                d->SendPlaySpellVisual(DASH_SMOKE_KIT);
            j->RestoreDisplayId();
            j->RemoveUnitFlag(UnitFlags(UNIT_FLAG_NOT_SELECTABLE
                | UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC));
        }, Milliseconds(DASH_MARGIN));
    }

    class spell_spheregrid_shunpo : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_shunpo);

        void Rush(SpellEffIndex /*index*/)
        {
            RogueTranslation(GetCaster(), GetExplTargetDest());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_shunpo::Rush,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Divine steed — the look of a mount without being one
    // =======================================================================
    // Applying the mount aura made it a REAL mount, with everything that
    // entails. The spell wanted is a speed bonus; only the look was missing.
    // `Unit::Mount` sets the display directly, without going through the aura:
    // the player is in the saddle on screen and stays on foot for the core.
    class spell_spheregrid_divine_steed : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_divine_steed);

        // The display field is written BY HAND rather than by calling
        // `Unit::Mount`, which also sets UNIT_FLAG_MOUNT. That flag switches the
        // character to MOUNTED speed, and the ground speed aura then stops
        // applying: the player had the steed and no longer the bonus.
        void GoUp(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            if (Unit* target = GetTarget())
                target->SetUInt32Value(UNIT_FIELD_MOUNTDISPLAYID, STEED_ASPECT);
        }

        void GoDown(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            if (Unit* target = GetTarget())
                target->SetUInt32Value(UNIT_FIELD_MOUNTDISPLAYID, 0);
        }

        void Register() override
        {
            OnEffectApply += AuraEffectApplyFn(spell_spheregrid_divine_steed::GoUp,
                                               EFFECT_0, SPELL_AURA_MOD_INCREASE_SPEED,
                                               AURA_EFFECT_HANDLE_REAL);
            OnEffectRemove += AuraEffectRemoveFn(spell_spheregrid_divine_steed::GoDown,
                                                 EFFECT_0, SPELL_AURA_MOD_INCREASE_SPEED,
                                                 AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Shield barrier — the absorption is paid in rage
    // =======================================================================
    // The amount of an absorption is NOT corrected through SetHitDamage — the
    // first version did that, and the rage emptied for an unchanged shield. The
    // amount of an aura is decided in DoEffectCalcAmount; the rage is spent
    // afterwards, on application, once the calculation is done.
    class spell_spheregrid_spartan_shield : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_spartan_shield);

        void Compute(AuraEffect const* /*effect*/, int32& amount, bool& /*fixe*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;
            // One point of absorption per point of DISPLAYED rage. The bug
            // fixed here: GetPower(POWER_RAGE) returns TENTHS (100 displayed =
            // 1000), so an old factor of six was really sixty per displayed
            // point.
            float block = 0.0f;
            if (Player* player = caster->ToPlayer())
                block = float(player->GetShieldBlockValue());
            // The rage counted is the one HELD AT THE CAST: the cost of the
            // spell (ManaCost 200 = 20 rage, the same internal units as
            // GetPower) is debited BEFORE the aura is computed. It is added
            // back in.
            int32 rage = caster->GetPower(POWER_RAGE)
                + int32(GetSpellInfo()->ManaCost);
            // THE EQUATION:
            //   amount = base + (rage / 100) x (block x 5 + armour x 0.075)
            int32 const blockShare = int32(5.0f * block);
            int32 const armourShare = int32(0.075f * float(caster->GetArmor()));
            int32 const ragePct = rage / 10;   // internal tenths -> points shown
            amount += int32(float(blockShare + armourShare)
                            * float(ragePct) / 100.0f);
        }

        // THE RAGE GOES, ALL OF IT. Nothing is said in the chat: the amount is
        // in the aura, the player sees his shield, and a line of arithmetic at
        // every cast belonged to the workbench, not to the game.
        void Empty(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            if (Unit* caster = GetCaster())
                caster->SetPower(POWER_RAGE, 0);
        }

        void Register() override
        {
            DoEffectCalcAmount += AuraEffectCalcAmountFn(spell_spheregrid_spartan_shield::Compute,
                                                         EFFECT_0, SPELL_AURA_SCHOOL_ABSORB);
            AfterEffectApply += AuraEffectApplyFn(spell_spheregrid_spartan_shield::Empty,
                                                  EFFECT_0, SPELL_AURA_SCHOOL_ABSORB,
                                                  AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Sweeping strikes — every blow sweeps a second one
    // =======================================================================
    // With its variant: with no secondary target in range, the single target is
    // struck TWICE. The proc comes from the DBC (a melee ProcTypeMask, autos and
    // abilities); the script receives the REAL damage of the blow
    // (ProcEventInfo) and replays it through the sweeping strike (a spell never
    // learned) on a second enemy near the victim — or on the victim herself.
    // Anti-recursion guard: the sweeping strike never sweeps.
    constexpr uint32 STRIKE_SWEEPING = 8600055;
    constexpr float SWEEP_RANGE = 8.0f;

    class spell_spheregrid_sweeping_strikes : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_sweeping_strikes);

        void Reap(AuraEffect const* /*effect*/, ProcEventInfo& infos)
        {
            Unit* guerrier = GetTarget();
            DamageInfo* blow = infos.GetDamageInfo();
            if (!guerrier || !blow || !blow->GetDamage())
                return;
            if (infos.GetSpellInfo()
                && infos.GetSpellInfo()->Id == STRIKE_SWEEPING)
                return;
            Unit* victim = blow->GetVictim();
            if (!victim)
                return;

            Unit* seconde = nullptr;
            std::list<Unit*> nearby;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck verif(victim, guerrier,
                                                             SWEEP_RANGE);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                chercheur(victim, nearby, verif);
            // This core exposes Cell::VisitObjects (not VisitAllObjects).
            Cell::VisitObjects(victim, chercheur, SWEEP_RANGE);
            for (Unit* u : nearby)
                if (u != victim && guerrier->IsValidAttackTarget(u))
                {
                    seconde = u;
                    break;
                }

            // EXPLICIT delivery: a CastCustomSpell as a damage spell showed
            // the player NOTHING and mitigated the echo through the armour a
            // second time. Here the log packet is sent by hand and the amount
            // is EXACTLY the one of the original blow, already mitigated
            // once.
            SpellInfo const* info = sSpellMgr->GetSpellInfo(STRIKE_SWEEPING);
            if (!info)
                return;
            Unit* target = seconde ? seconde : victim;
            SpellNonMeleeDamage strike(guerrier, target, info,
                                       SPELL_SCHOOL_MASK_NORMAL);
            strike.damage = blow->GetDamage();
            guerrier->SendSpellNonMeleeDamageLog(&strike);
            guerrier->DealSpellDamage(&strike, false);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_spheregrid_sweeping_strikes::Reap,
                                             EFFECT_0, SPELL_AURA_DUMMY);
        }
    };

    // =======================================================================
    // Spectral walk — two gates, and the step from one to the other
    // =======================================================================
    // A PAIR of gates laid down in a SINGLE cast, each standing for a while. A
    // right click on one carries the caster to the other: the gate walked
    // through fades, the one opposite gains extra time. A cast raises TWO gates
    // when none stands, a SINGLE one otherwise.
    //
    // WHY "HERE AND THERE": the 3.3.5 client only opens its reticle on a key
    // press, and nothing in the protocol lets the server ask it for a second
    // one. A cast can therefore designate only ONE position; the other gate
    // rises at the caster's feet.
    constexpr uint32 GATE_ITEM = 803820;   // both gates, the same object
    constexpr uint32 GATE_LIFE = 45;         // s -- SummonGameObject counts
                                             // in seconds, not in ms
    constexpr float GATE_LOOT = 100.0f;  // m -- enough to find the pair again

    // Who SEES and who WALKS THROUGH a gate: the caster and HIS OWN. "His
    // group, not his raid": in an ordinary group everyone is in the same
    // subgroup and passes; in a raid, only his own subgroup — the other raiders
    // stay outside.
    bool GateOfSameGroup(Player const* player, ObjectGuid knight)
    {
        if (!player || !knight)
            return false;
        if (player->GetGUID() == knight)
            return true;
        Group const* group = player->GetGroup();
        if (!group || !group->IsMember(knight))
            return false;
        return group->SameSubGroup(player->GetGUID(), knight);
    }

    // The gate AI holds the name of its caster — and NOT the "owner" field of
    // the object. An object THAT HAS AN OWNER is always visible to anyone
    // friendly to it (GameObject::IsAlwaysVisibleFor, consulted BEFORE any
    // hook): keeping that field would make the visibility filter useless for
    // allies. The link therefore goes through the channel meant for it,
    // SetGUID/GetGUID.
    struct go_spheregrid_gate_ai : public GameObjectAI
    {
        explicit go_spheregrid_gate_ai(GameObject* go) : GameObjectAI(go) { }

        void SetGUID(ObjectGuid const& guid, int32 /*id*/) override
        {
            _knight = guid;
        }

        ObjectGuid GetGUID(int32 /*id*/) const override { return _knight; }

        // Outside the group, the gate does not exist: the core consults this
        // hook at every visibility update. As long as the gate is not marked,
        // nobody sees it — which is what keeps it from appearing to everyone
        // for the space of a heartbeat.
        bool CanBeSeen(Player const* regardeur) override
        {
            return GateOfSameGroup(regardeur, _knight);
        }

        bool GossipHello(Player* player, bool reportUse) override;

    private:
        ObjectGuid _knight;
    };

    // The gates of ONE given caster. The core keeps no reachable list of the
    // objects a player has placed: the grid is searched around a landmark and
    // his own are kept.
    void GatesOf(WorldObject* autour, ObjectGuid knight,
                  std::list<GameObject*>& gates)
    {
        autour->GetGameObjectListWithEntryInGrid(gates, GATE_ITEM,
                                                 GATE_LOOT);
        gates.remove_if([knight](GameObject* gate)
        {
            return !gate || !gate->AI()
                || gate->AI()->GetGUID(0) != knight;
        });
    }

    // THE CROSSING: walking through a gate carries the player to the other;
    // the one walked through fades, the one arrived at gains extra time.
    bool go_spheregrid_gate_ai::GossipHello(Player* player, bool /*reportUse*/)
    {
        // Return "handled" in every case: without that, the core would go on
        // to the spell written in the template.
        if (!GateOfSameGroup(player, _knight))
            return true;

        std::list<GameObject*> gates;
        GatesOf(me, _knight, gates);
        GameObject* other = nullptr;
        for (GameObject* candidate : gates)
            if (candidate != me)
            {
                other = candidate;
                break;
            }
        if (!other)
            return true;      // a lone gate leads nowhere

        time_t const left = other->GetRespawnTime()
            - GameTime::GetGameTime().count();
        other->SetRespawnTime(int32(std::max<time_t>(0, left) + GATE_LIFE));
        player->NearTeleportTo(other->GetPositionX(), other->GetPositionY(),
                               other->GetPositionZ(), player->GetOrientation());
        // Delete() does not erase on the spot: the object goes to the world
        // removal list, so it can be let go from here.
        me->Delete();
        return true;
    }

    // A gate placed. The "owner" field is DROPPED at once (see above), the
    // link going through the AI; visibility is refreshed straight after, the
    // marking coming after the entry into the world.
    void PlaceGate(Player* dk, float x, float y, float z)
    {
        GameObject* gate = dk->SummonGameObject(GATE_ITEM, x, y, z,
            dk->GetOrientation(), 0.0f, 0.0f, 0.0f, 0.0f, GATE_LIFE);
        if (!gate)
            return;
        dk->RemoveGameObject(gate, false);
        if (gate->AI())
            gate->AI()->SetGUID(dk->GetGUID(), 0);
        gate->UpdateObjectVisibility(true);
    }

    class spell_spheregrid_gate : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_gate);

        void Apply(SpellEffIndex /*index*/)
        {
            Player* dk = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            WorldLocation const* goal = GetExplTargetDest();
            if (!dk || !goal)
                return;

            // What already stands decides the count: no gate at all, and the
            // caster raises TWO — this one and one at his feet; at least one,
            // and the reticle gate is the only one.
            std::list<GameObject*> debout;
            GatesOf(dk, dk->GetGUID(), debout);

            PlaceGate(dk, goal->GetPositionX(), goal->GetPositionY(),
                       goal->GetPositionZ());
            if (!debout.empty())
                return;
            PlaceGate(dk, dk->GetPositionX(), dk->GetPositionY(),
                       dk->GetPositionZ());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_gate::Apply,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // The gate template now carries this AI alone: it is what filters the view
    // and handles the click.
    class go_spheregrid_gate : public GameObjectScript
    {
    public:
        go_spheregrid_gate() : GameObjectScript("go_spheregrid_gate") { }

        GameObjectAI* GetAI(GameObject* gate) const override
        {
            return new go_spheregrid_gate_ai(gate);
        }
    };

    // =======================================================================
    // Burning rush — speed is paid in a fraction of the life
    // =======================================================================
    // Fixed damage was negligible at high level and lethal at low level. The
    // rush takes a percentage of the maximum health per second and puts itself
    // out below a floor: it never kills its bearer.
    // THE TOGGLE: casting the rush again cancels it. The SpellScript intercepts
    // the cast, removes the aura when it is there and interrupts the spell with
    // no error message — no cost and no cooldown, the rush has neither.
    constexpr uint32 RUSH_BURNING = 8600080;
    // ---------------------------------------------------------------------
    // Cataclysm
    // ---------------------------------------------------------------------
    // The DBC carries all it can: the damage, the damage increase over time, the
    // reactive soul shard, and the two-charge aura that makes two spells
    // instant (an ADD_PCT_MODIFIER aimed at the warlock family, which the core
    // consumes on its own).
    //
    // Two things stay out of its reach: spreading the damage-over-time at the
    // best rank the warlock knows — his spell book has to be read — and applying
    // the charge aura, which is not an effect of the spell goal a spell of its
    // own.
    constexpr uint32 CATACLYSM_HASTE = 8610012;
    constexpr uint32 IMMOLATION_MASK = 0x4;   // famille warlock, word 0

    // The same method as the other "best rank" helpers: the highest rank the
    // player ACTIVELY carries, and not a fixed rank that would go wrong at every
    // progression rune.
    uint32 CataclysmBestRank(Player* warlock, uint8 word, uint32 mask)
    {
        uint32 best = 0;
        uint32 bestLevel = 0;
        for (auto const& paire : warlock->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_WARLOCK)
                continue;
            if (!(info->SpellFamilyFlags[word] & mask))
                continue;
            uint32 level = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!best || level > bestLevel)
            {
                best = info->Id;
                bestLevel = level;
            }
        }
        return best;
    }

    class spell_spheregrid_cataclysm : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_cataclysm);

        void Cleave(SpellEffIndex index)
        {
            Player* warlock = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            Unit* target = GetHitUnit();
            if (!warlock || !target)
                return;

            // The damage-over-time spreads around the TARGET, not around the
            // caster: the radius is the one of the third effect, the one that
            // carries this script.
            uint32 const immolation = CataclysmBestRank(
                warlock, 0, IMMOLATION_MASK);
            if (immolation)
            {
                float const radius =
                    GetSpellInfo()->Effects[index].CalcRadius(warlock);
                std::list<Unit*> preys;
                Acore::AnyUnfriendlyUnitInObjectRangeCheck test(target, warlock,
                                                                radius);
                Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                    chercheur(target, preys, test);
                // This core exposes Cell::VisitObjects (not VisitAllObjects).
                Cell::VisitObjects(target, chercheur, radius);
                for (Unit* prey : preys)
                    if (prey->IsAlive() && warlock->IsValidAttackTarget(prey))
                        warlock->CastSpell(prey, immolation, true);
            }

            // The two instant casts: an aura with CHARGES, which the core
            // counts down itself at each of the two spells.
            warlock->CastSpell(warlock, CATACLYSM_HASTE, true);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_spheregrid_cataclysm::Cleave,
                                               EFFECT_2, SPELL_EFFECT_DUMMY);
        }
    };

    // NO FLOOR ANY MORE: the rush burns to the end. It stops only before
    // death, and refuses to start at the threshold or below.
    constexpr uint32 RUSH_THRESHOLD_CAST = 16;  // % of max health: MORE than that is needed

    class spell_spheregrid_burning_rush : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_burning_rush);

        SpellCastResult Toggle()
        {
            Unit* caster = GetCaster();
            if (!caster)
                return SPELL_CAST_OK;
            // Already active: it is put out, with no message and no cost.
            if (caster->HasAura(RUSH_BURNING, caster->GetGUID()))
            {
                caster->RemoveAurasDueToSpell(RUSH_BURNING);
                return SPELL_FAILED_DONT_REPORT;
            }
            // Too low to start: it takes MORE than the threshold of maximum
            // health, so exactly the threshold is refused.
            if (caster->GetHealthPct() <= float(RUSH_THRESHOLD_CAST))
            {
                SetCustomCastResultMessage(SPELL_CUSTOM_ERROR_NOT_ENOUGH_HEALTH);
                return SPELL_FAILED_CUSTOM_ERROR;
            }
            return SPELL_CAST_OK;
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_spheregrid_burning_rush::Toggle);
        }
    };

    class spell_spheregrid_burning_rush_aura : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_burning_rush_aura);

        void Burn(AuraEffect const* effect)
        {
            PreventDefaultAction();
            Unit* target = GetTarget();
            if (!target)
                return;
            // ONLY DEATH STOPS THE RUSH: we look at what the tick WOULD do,
            // and stop only if it would kill. A floor was removed — it stopped
            // the rush at a quarter of the maximum health, far too early.
            //
            // A direct comparison, with no subtraction: "life <= bite" says the
            // tick would bring it to zero or below. Writing it "life - bite <= 0"
            // would underflow in uint32 and let the killing blow through.
            uint32 const bite = target->CountPctFromMaxHealth(effect->GetAmount());
            if (target->GetHealth() <= bite)
            {
                Remove();
                return;
            }
            Unit::DealDamage(target, target, bite, nullptr, SPELL_DIRECT_DAMAGE,
                             SPELL_SCHOOL_MASK_FIRE, GetSpellInfo(), false);
        }

        void Register() override
        {
            // A DUMMY: a self-damage aura would necessarily be a debuff, and
            // therefore impossible to cancel with a right click.
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_spheregrid_burning_rush_aura::Burn,
                                                     EFFECT_1, SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Bane of kings — the blade bites deeper the more the target is poisoned
    // =======================================================================
    // The tooltip promises an increase PER POISON, not per elapsed time: the
    // first version raised it by a tenth at every tick, which is not the same
    // thing and did not reward the same play. The spell pays for the work
    // already done on the target, not for patience.
    //
    // `CallScriptEffectPeriodicHandlers` is called BEFORE the tick damage is
    // computed: writing the amount here therefore acts on this very tick.
    class spell_spheregrid_bane_of_kings : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_bane_of_kings);

        // We count the auras whose dispel type is poison — what the client
        // itself calls "poison" in its own tooltips — rather than a list of
        // spells that would have to be maintained at every addition.
        uint32 CountPoisons(Unit const* target) const
        {
            uint32 howMany = 0;
            for (auto const& paire : target->GetAppliedAuras())
            {
                Aura const* aura = paire.second->GetBase();
                if (!aura || aura->GetSpellInfo()->Id == GetSpellInfo()->Id)
                    continue;               // the blade does not count itself
                if (aura->GetSpellInfo()->Dispel == DISPEL_POISON)
                    ++howMany;
            }
            return howMany;
        }

        void Worsen(AuraEffect const* effect)
        {
            Unit const* target = GetTarget();
            if (!target)
                return;

            // The base value is read back from the spell. Overwriting it
            // without reading it again would compound the increase on itself,
            // and the poison would run away tick after tick.
            int32 const base = GetSpellInfo()->Effects[EFFECT_1].CalcValue(GetCaster());
            uint32 const poisons = CountPoisons(target);
            int32 const amount = base + int32(base) * int32(poisons) / 4;

            if (AuraEffect* modifiable = const_cast<AuraEffect*>(effect))
                modifiable->SetAmount(amount);
        }

        void Register() override
        {
            // EFFECT_1, and not EFFECT_0: the first effect carries the initial
            // strike, the second the poison. A binding that does not match the
            // DBC is not a compilation error — the core refuses it at startup
            // and the hook never runs.
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_spheregrid_bane_of_kings::Worsen,
                                                     EFFECT_1, SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Roll the bones — the combo points decide the draw
    // =======================================================================
    // A single stacking aura said nothing of what it brought: the draw is made
    // among FIVE distinct auras, each named and described. The spell SPENDS the
    // combo points (1 to 5, on top of the energy) and the stake replaces the
    // randomness of the NUMBER — 1 point = 1 buff, 3 points = 2, 5 points = 3,
    // at the base duration; EVEN stakes (2 points = 1 buff, 4 points = 2)
    // DOUBLE that duration. Only the CHOICE of the buffs is still drawn. In
    // 3.3.5 the combo points live on the rogue's target: the DBC stays a spell
    // on self, the script reads them and clears them (CheckCast demands at
    // least one).
    constexpr uint32 BUFFS[] = { 8600034, 8600035, 8600036, 8600037, 8600038 };
    constexpr int32 DICE_DURATION_BASE = 15000;

    class spell_spheregrid_roll_the_bones : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_roll_the_bones);

        SpellCastResult CheckCast()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player || !player->GetComboPoints())
                return SPELL_FAILED_NO_COMBO_POINTS;
            return SPELL_CAST_OK;
        }

        void Launch()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player)
                return;

            uint8 const points = std::min<uint8>(player->GetComboPoints(), 5);
            if (!points)
                return;
            player->ClearComboPoints();

            uint32 const howMany = (points + 1) / 2;         // 1,1,2,2,3
            int32 const duration = (points == 2 || points == 4)
                ? DICE_DURATION_BASE * 2 : DICE_DURATION_BASE;

            // The buffs of the previous draw are removed first: without that
            // the rolls would stack and the spell would become an accumulation,
            // not a wager.
            for (uint32 id : BUFFS)
                player->RemoveAurasDueToSpell(id);

            std::vector<uint32> basket(std::begin(BUFFS), std::end(BUFFS));
            for (uint32 k = 0; k < howMany && !basket.empty(); ++k)
            {
                uint32 const drawn = urand(0, uint32(basket.size()) - 1);
                uint32 const chosen = basket[drawn];
                player->CastSpell(player, chosen, true);
                // The duration comes from the STAKE, not from the DBC: even
                // stakes double it.
                if (Aura* aura = player->GetAura(chosen))
                {
                    aura->SetMaxDuration(duration);
                    aura->SetDuration(duration);
                }
                basket.erase(basket.begin() + drawn);   // never the same one twice
            }
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_spheregrid_roll_the_bones::CheckCast);
            AfterCast += SpellCastFn(spell_spheregrid_roll_the_bones::Launch);
        }
    };

    // =======================================================================
    // Halo — the ring opens, then closes again
    // =======================================================================
    // Two beats, around the POSITION OF THE CASTER AT THE MOMENT OF THE CAST:
    // the priest may walk away afterwards, the ring stays where it was born.
    // Each beat is a creature dressed in one of the two backported models — one
    // opens, the other closes — and a WAVE, that is the two auxiliary spells
    // cast by the priest at the anchor point. Two spells because a spell has
    // only one visual: enemies must receive the holy damage impact, allies the
    // healing one.
    // La forme d'Ombre du jeu. Un sort sacre l'annule : Halo en est un.
    constexpr uint32 SHADOWFORM = 15473;
    constexpr uint32 HALO_RING_OPEN = 803814;
    constexpr uint32 HALO_RING_CLOSED = 803815;
    constexpr uint32 HALO_WAVE_DAMAGE = 8600044;
    constexpr uint32 HALO_WAVE_HEAL = 8600045;
    constexpr uint32 HALO_SECOND_BEAT = 3000;   // ms - the second beat
    // The stand animation of both models carries 3334 ms in the file, goal in
    // game the ring had finished its course a second earlier and set off for a
    // second reading before vanishing: the life of a ring is cut short by that
    // much. It is also the span over which the wave travels — the effect FOLLOWS
    // the ring.
    constexpr uint32 HALO_LIFE = 2334;
    constexpr float HALO_RADIUS = 30.0f;
    constexpr uint32 HALO_TICK = 33;              // ms -- thirty times a second

    // One beat of the halo: the ring appears. It is ITS AI that carries the
    // wave along, at the rate it opens or closes. A free function, since
    // AddEventAtOffset demands an rvalue lambda.
    void HaloBeat(ObjectGuid guidPriest, Position where, uint32 ring)
    {
        Player* priest = ObjectAccessor::FindPlayer(guidPriest);
        if (!priest || !priest->IsInWorld())
            return;
        priest->SummonCreature(ring, where, TEMPSUMMON_TIMED_DESPAWN, HALO_LIFE);
    }

    class spell_spheregrid_halo : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_halo);

        // THE SHADOW FALLS. A holy spell takes a priest out of Shadowform, and
        // Halo is one. It goes at the CAST, not at the hit: the form must drop
        // the moment the priest presses the button, not once the ring has
        // opened.
        void LeaveShadow()
        {
            if (Unit* priest = GetCaster())
                priest->RemoveAurasDueToSpell(SHADOWFORM);
        }

        void Deploy(SpellEffIndex /*index*/)
        {
            Player* priest = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!priest)
                return;
            // THE ANCHOR: the priest's position at that instant, frozen by
            // value. Everything that follows refers to it, wherever he goes.
            Position where = priest->GetPosition();
            ObjectGuid guid = priest->GetGUID();
            HaloBeat(guid, where, HALO_RING_OPEN);
            priest->m_Events.AddEventAtOffset([guid, where]()
            {
                HaloBeat(guid, where, HALO_RING_CLOSED);
            }, Milliseconds(HALO_SECOND_BEAT));
        }

        void Register() override
        {
            OnCast += SpellCastFn(spell_spheregrid_halo::LeaveShadow);
            OnEffectHit += SpellEffectFn(spell_spheregrid_halo::Deploy,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // The ring carries the wave WITH IT: no longer an area struck in one
    // block, goal a front that leaves the centre and reaches the edge as the ring
    // opens, then leaves the edge and returns to the centre as it closes. Each
    // target is touched once per pass, at the instant the front reaches it. The
    // priest is the one casting the wave: the damage and the healing come back
    // to him, and those touched receive the holy impact of the auxiliary spell —
    // a blow for enemies, a heal for allies.
    struct npc_spheregrid_halo : public ScriptedAI
    {
        npc_spheregrid_halo(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
            _opens = me->GetEntry() == HALO_RING_OPEN;
        }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (summoner)
                _priest = summoner->GetGUID();
        }

        void UpdateAI(uint32 diff) override
        {
            _age += diff;
            _watch += diff;
            if (_watch < HALO_TICK)
                return;
            _watch = 0;
            Player* priest = ObjectAccessor::FindPlayer(_priest);
            if (!priest)
                return;

            float const progress = std::min(1.0f, float(_age) / float(HALO_LIFE));
            float const front = _opens ? HALO_RADIUS * progress
                                       : HALO_RADIUS * (1.0f - progress);

            std::list<Unit*> enemies;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(me, priest,
                                                               HALO_RADIUS);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                hunt(me, enemies, hostile);
            Cell::VisitObjects(me, hunt, HALO_RADIUS);
            for (Unit* target : enemies)
                Hit(priest, target, front, HALO_WAVE_DAMAGE);

            std::list<Player*> allies;
            Acore::AnyPlayerInObjectRangeCheck friendly(me, HALO_RADIUS);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                gather(me, allies, friendly);
            Cell::VisitObjects(me, gather, HALO_RADIUS);
            for (Player* ally : allies)
                if (priest->IsFriendlyTo(ally))
                    Hit(priest, ally, front, HALO_WAVE_HEAL);
        }

    private:
        void Hit(Player* priest, Unit* target, float front, uint32 wave)
        {
            if (!target->IsAlive() || _touches.count(target->GetGUID()))
                return;
            float const d = me->GetDistance2d(target);
            // The front only takes what it has just reached: what lies ahead
            // of it as it opens, behind it as it comes back.
            if (_opens ? d > front : d < front)
                return;
            _touches.insert(target->GetGUID());
            // The amount is the DBC one, untouched: scaling it by distance
            // (weak at contact and at the edge, full at mid-course) was REMOVED
            // — at the centre it brought the announced heal down to a quarter of
            // what the tooltip promised.
            priest->CastSpell(target, wave, true);
        }

        ObjectGuid _priest;
        GuidSet _touches;
        bool _opens = true;
        uint32 _age = 0;
        uint32 _watch = 0;
    };

    // =======================================================================
    // Apocalypse — the wounds burst, the dead rise
    // =======================================================================
    // ONE GHOUL PER ENEMY within the radius around the target, two at least,
    // each raised AT THE FEET of its prey (the two of the minimum under the
    // target itself). They live a few seconds, strike whoever is nearest to them
    // and raise their blows by a percentage per disease of the death knight on
    // the victim.
    constexpr uint32 APOCALYPSE_LIFE = 19000;     // ms, the emerge time included
    constexpr float APOCALYPSE_RADIUS = 8.0f;     // m -- around the target
    constexpr uint32 APOCALYPSE_MINIMUM = 2;     // ghouls, whatever happens
    constexpr uint32 APOCALYPSE_SPLASH = 50;  // % of the blow, to the neighbours
    // THE RAISING: a spell carrying a visual, cast by the death knight on each
    // ghoul. Its visual only carries the native impact of a raise-dead spell.
    // The raw packet sent to the creature showed NOTHING — the client does not
    // have the creature yet at the tick of the summon.
    constexpr uint32 APOCALYPSE_RAISE = 8600048;
    // The ghoul TEARS ITSELF OUT OF THE GROUND: the birth animation, found in
    // the ghoul model — its bones go down more than two yards then come back up,
    // which really is a rise from the earth. An "emerge from ground" animation,
    // tried first, moves the model by a few inches only.
    constexpr uint32 GHOUL_EMOTE_EMERGE = 990004;   // 0 to cut it off
    constexpr uint32 GHOUL_EMERGE_MS = 4166;
    // The dash margin: neither an emote nor a spell bears on a creature the
    // client has not received yet — that is what left the ghouls "summoned
    // without animations".
    constexpr uint32 GHOUL_MARGIN = 300;
    // The bonus per disease of the death knight on the victim, in hundredths.
    constexpr uint32 GHOUL_BONUS_DISEASE = 125;  // +12,5 %
    constexpr float GHOUL_HASTE = 25.0f;          // % -- they strike that much faster
                                                 // faster
    constexpr uint32 GHOUL_TICK = 500;            // ms -- the targeting watch

    // The diseases THE DEATH KNIGHT has applied to a victim. Counted by dispel
    // type, not by a list of spells: every disease counts.
    //
    // THREE AT MOST, the standard ones. A "periodic damage" filter, tried to
    // exclude one of them, was removed — it does count.
    //
    // What must be excluded are the TECHNICAL auras. The culprit found: a linked
    // aura that this core adds to the spell table itself — the payload one of
    // the talents attaches to its victims to raise disease damage. It carries the
    // same dispel type and the same mechanic as the real diseases, goal NO ICON:
    // that is the mark of the auras the player never sees, and the discriminant
    // kept.
    uint32 DiseasesOf(Unit const* knight, Unit const* victim)
    {
        if (!knight || !victim)
            return 0;
        uint32 diseases = 0;
        for (auto const& paire : victim->GetAppliedAuras())
        {
            Aura const* aura = paire.second->GetBase();
            if (!aura || aura->GetCasterGUID() != knight->GetGUID()
                || aura->GetSpellInfo()->Dispel != DISPEL_DISEASE
                || !aura->GetSpellInfo()->SpellIconID)
                continue;
            ++diseases;
        }
        return diseases;
    }



    class spell_spheregrid_apocalypse : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_apocalypse);

        // Each disease THE CASTER has applied raises the damage by half: the
        // blade pays for the work already done, like the poison-scaling spell.
        // THE SPLASH: half the blow to the enemies around the target, raised for
        // each of them by the same percentage per disease of the death knight ON
        // HIM.
        void Burst(SpellEffIndex /*index*/)
        {
            Unit* dk = GetCaster();
            Unit* target = GetHitUnit();
            if (!dk || !target)
                return;
            int32 const full = GetHitDamage();
            uint32 const diseases = DiseasesOf(dk, target);
            SetHitDamage(full + full * int32(diseases) / 2);

            SpellInfo const* info = GetSpellInfo();
            if (!info)
                return;
            std::list<Unit*> nearby;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(target, dk,
                                                               APOCALYPSE_RADIUS);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                hunt(target, nearby, hostile);
            Cell::VisitObjects(target, hunt, APOCALYPSE_RADIUS);
            for (Unit* neighbour : nearby)
            {
                if (neighbour == target || !neighbour->IsAlive()
                    || !dk->IsValidAttackTarget(neighbour))
                    continue;
                // EXPLICIT delivery, the sweeping strikes pattern: a
                // CastCustomSpell would show the player nothing and mitigate the
                // amount a second time.
                uint32 const chez_lui = DiseasesOf(dk, neighbour);
                int32 amount = full * int32(APOCALYPSE_SPLASH) / 100;
                amount += amount * int32(chez_lui)
                    * int32(GHOUL_BONUS_DISEASE) / 1000;
                SpellNonMeleeDamage eclat(dk, neighbour, info,
                                          SPELL_SCHOOL_MASK_SHADOW);
                eclat.damage = uint32(std::max(1, amount));
                dk->SendSpellNonMeleeDamageLog(&eclat);
                dk->DealSpellDamage(&eclat, false);
            }
        }

        void Raise()
        {
            Unit* caster = GetCaster();
            Unit* target = GetExplTargetUnit();
            if (!caster || !target)
                return;

            // One ghoul per enemy in the area, raised AT ITS FEET.
            std::list<Unit*> preys;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(target, caster,
                                                               APOCALYPSE_RADIUS);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                hunt(target, preys, hostile);
            Cell::VisitObjects(target, hunt, APOCALYPSE_RADIUS);

            uint32 raised = 0;
            for (Unit* prey : preys)
            {
                if (!prey->IsAlive())
                    continue;
                RaiseGhoul(caster, prey->GetPosition());
                ++raised;
            }
            // The floor: two ghouls at least, under the spell's target.
            for (; raised < APOCALYPSE_MINIMUM; ++raised)
            {
                Position where = target->GetPosition();
                target->MovePositionToFirstCollision(where, 3.0f,
                                                    float(raised) * float(M_PI));
                RaiseGhoul(caster, where);
            }
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_spheregrid_apocalypse::Burst,
                                               EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
            AfterCast += SpellCastFn(spell_spheregrid_apocalypse::Raise);
        }

    private:
        static void RaiseGhoul(Unit* caster, Position const& where)
        {
            Creature* ghoul = caster->SummonCreature(GHOUL, where,
                TEMPSUMMON_TIMED_DESPAWN, APOCALYPSE_LIFE);
            if (!ghoul)
                return;
            // The raise-dead visual, played ON the ghoul by the auxiliary
            // spell — and DELAYED like the emote: cast at the very tick of the
            // summon, the client does not have the creature yet and shows
            // nothing.
            ObjectGuid guid = ghoul->GetGUID();
            ObjectGuid guidDk = caster->GetGUID();
            caster->m_Events.AddEventAtOffset([guid, guidDk]()
            {
                Player* dk = ObjectAccessor::FindPlayer(guidDk);
                if (!dk || !dk->IsInWorld())
                    return;
                if (Creature* c = ObjectAccessor::GetCreature(*dk, guid))
                    dk->CastSpell(c, APOCALYPSE_RAISE, true);
            }, Milliseconds(GHOUL_MARGIN));
        }
    };

    // The apocalypse ghoul bites WHOEVER IS NEAREST to it, and not its
    // master's target — it is raised at the feet of its prey. The pattern is the
    // hunter pack one: the level and the faction of the master, an owner set
    // (without which the client does not show its damage in floating text), and
    // DoMeleeAttackIfReady at every tick — WITHOUT THAT CALL A CREATURE NEVER
    // STRIKES.
    struct npc_spheregrid_ghoul : public ScriptedAI
    {
        npc_spheregrid_ghoul(Creature* creature) : ScriptedAI(creature) { }

        void JustEngagedWith(Unit* /*who*/) override { }
        void MoveInLineOfSight(Unit* /*who*/) override { }

        void InitializeAI() override
        {
            ScriptedAI::InitializeAI();
            Unit* master = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!master)
                return;
            me->SetFaction(master->GetFaction());
            me->SetLevel(master->GetLevel());
            me->SetOwnerGUID(master->GetGUID());
            me->SetCreatorGUID(master->GetGUID());
            me->SetReactState(REACT_AGGRESSIVE);
            // The haste: the channel meant for it, which divides the attack
            // time instead of rewriting it — so the template keeps its reference
            // cadence.
            me->ApplyAttackTimePercentMod(BASE_ATTACK, GHOUL_HASTE, true);
            // It comes out of the ground before biting. The dash margin
            // again: an emote played at the very tick of the summon is thrown
            // away, the client not having the creature yet.
            if (!GHOUL_EMOTE_EMERGE)
                return;
            // The event queue belongs to the creature: it dies with it, so
            // the capture is safe.
            Creature* moi = me;
            me->m_Events.AddEventAtOffset([moi]()
            {
                moi->HandleEmoteCommand(GHOUL_EMOTE_EMERGE);
            }, Milliseconds(GHOUL_MARGIN));
            _emerge = GHOUL_MARGIN + GHOUL_EMERGE_MS;
        }

        // The bonus per disease: a percentage per disease THE DEATH KNIGHT has
        // applied to the victim, added to every blow struck.
        void DamageDealt(Unit* victim, uint32& damage,
                         DamageEffectType /*type*/,
                         SpellSchoolMask /*school*/) override
        {
            Unit* master = ObjectAccessor::GetUnit(*me, me->GetOwnerGUID());
            uint32 const diseases = DiseasesOf(master, victim);
            if (diseases)
                damage += damage * diseases * GHOUL_BONUS_DISEASE / 1000;
        }

        void UpdateAI(uint32 diff) override
        {
            // While it tears itself out of the ground it neither moves nor
            // strikes: without that, the movement would cut the animation
            // short.
            if (_emerge)
            {
                _emerge = _emerge > diff ? _emerge - diff : 0;
                return;
            }
            _watch += diff;
            if (_watch >= GHOUL_TICK && !UpdateVictim())
            {
                _watch = 0;
                Unit* master = ObjectAccessor::GetUnit(*me, me->GetOwnerGUID());
                if (master)
                {
                    // THE NEAREST: the ghoul bites what is right in front of
                    // it, each one its own.
                    std::list<Unit*> preys;
                    Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(me,
                        master, APOCALYPSE_RADIUS * 2.0f);
                    Acore::UnitListSearcher<
                        Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                        hunt(me, preys, hostile);
                    Cell::VisitObjects(me, hunt, APOCALYPSE_RADIUS * 2.0f);

                    Unit* closest = nullptr;
                    float nearest = 0.0f;
                    for (Unit* prey : preys)
                    {
                        if (!prey->IsAlive() || !me->CanCreatureAttack(prey))
                            continue;
                        float const d = me->GetDistance(prey);
                        if (!closest || d < nearest)
                        {
                            closest = prey;
                            nearest = d;
                        }
                    }
                    if (closest)
                        me->EngageWithTarget(closest);
                }
            }
            if (!UpdateVictim())
                return;
            DoMeleeAttackIfReady();
        }

    private:
        uint32 _watch = GHOUL_TICK;
        uint32 _emerge = 0;      // ms left of the climb out of the ground
    };


    // =======================================================================
    // Bone storm — a buff that whirls around the death knight
    // =======================================================================
    // The aura lives on THE DEATH KNIGHT, not on each enemy. It ticks every
    // second; at each tick the storm tears at the enemies around him and gives
    // the bearer back a fraction of his maximum health. Both amounts come from
    // the DBC: effect 0 carries the damage, effect 1 the health percentage.
    constexpr float STORM_RADIUS = 5.0f;   // 8 -> 5 m

    class spell_spheregrid_bone_storm : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_bone_storm);

        void Turn(AuraEffect const* effect)
        {
            Unit* dk = GetTarget();
            if (!dk || !dk->IsAlive())
                return;
            SpellInfo const* info = GetSpellInfo();
            if (!info)
                return;

            // The damage, delivered EXPLICITLY: the log is sent by hand,
            // without which the player would see nothing scroll by.
            std::list<Unit*> preys;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(dk, dk,
                                                               STORM_RADIUS);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                hunt(dk, preys, hostile);
            Cell::VisitObjects(dk, hunt, STORM_RADIUS);
            uint32 torn = 0;
            for (Unit* prey : preys)
            {
                if (!prey->IsAlive() || !dk->IsValidAttackTarget(prey))
                    continue;
                SpellNonMeleeDamage blow(dk, prey, info,
                                         SPELL_SCHOOL_MASK_SHADOW);
                blow.damage = uint32(std::max(1, effect->GetAmount()));
                dk->SendSpellNonMeleeDamageLog(&blow);
                dk->DealSpellDamage(&blow, false);
                ++torn;
            }

            // The heal: a fraction of the MAXIMUM HEALTH PER ENEMY CAUGHT IN
            // THE STORM — the more of them around, the more it puts him back on
            // his feet. No enemy, no heal.
            int32 progress = 0;
            if (AuraEffect const* second = GetEffect(EFFECT_1))
                progress = second->GetAmount();
            if (progress <= 0 || !torn)
                return;
            uint32 const heal =
                uint32(dk->GetMaxHealth() * uint32(progress) * torn / 100);
            if (!heal)
                return;
            HealInfo buff(dk, dk, heal, info, SPELL_SCHOOL_MASK_SHADOW);
            dk->HealBySpell(buff);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_spheregrid_bone_storm::Turn, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Sindragosa's breath — it lasts as long as the runic power lasts
    // =======================================================================
    // The first version applied the aura to EVERY enemy in the cone, and the
    // drain was paid at each tick of each target — three enemies, triple the
    // bill. The aura now lives on the caster: a single counter, one cone
    // triggered per second (carried by the DBC), and running out blows the whole
    // channel away.
    class spell_spheregrid_sindragosa_breath : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_sindragosa_breath);

        void Consume(AuraEffect const* /*effect*/)
        {
            Unit* caster = GetCaster();
            if (!caster)
                return;

            constexpr uint32 COST = 150;        // en dixiemes, soit 15 points
            if (caster->GetPower(POWER_RUNIC_POWER) < COST)
            {
                PreventDefaultAction();          // no free bite
                Remove();
                return;
            }
            caster->ModifyPower(POWER_RUNIC_POWER, -int32(COST));
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_spheregrid_sindragosa_breath::Consume,
                                                     EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL);
        }
    };

    // =======================================================================
    // Earthquake — the ground shakes, and now and then one falls
    // =======================================================================
    // The DBC area strikes on its own, every second; the script adds one thing
    // only: a chance, at each blow struck, of knocking the victim off her feet.
    // The fall is a one-second stun of the "knocked out" mechanic, the one that
    // lays down instead of freezing.
    constexpr uint32 EARTHQUAKE_FALL = 8600068;
    constexpr uint32 EARTHQUAKE_CHANCE = 10;     // % per beat and per victim

    class spell_spheregrid_earthquake : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_earthquake);

        void Shake(AuraEffect const* /*effect*/)
        {
            Unit* shaman = GetCaster();
            Unit* victim = GetTarget();
            if (!shaman || !victim || !victim->IsAlive())
                return;
            if (!roll_chance_i(EARTHQUAKE_CHANCE))
                return;
            // Already down: she is not knocked down again, the countdown
            // would restart at every tick and pin the victim to the ground.
            if (victim->HasAura(EARTHQUAKE_FALL))
                return;
            shaman->CastSpell(victim, EARTHQUAKE_FALL, true);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_spheregrid_earthquake::Shake, EFFECT_0,
                SPELL_AURA_PERIODIC_DAMAGE);
        }
    };

    // =======================================================================
    // Ascendance — the lightning leaps of its own accord
    // =======================================================================
    // The shaman TAKES THE SHAPE of an ascendant for the time of the buff, and
    // takes his own back at the end or on cancellation. On casting, five enemies
    // IN FRONT OF HIM receive a shock then a lava burst — at the best rank he
    // knows, read from his spell book rather than hardcoded.
    constexpr float ASCENDANCE_RANGE = 36.0f;
    constexpr uint32 ASCENDANCE_TARGETS = 5;
    constexpr uint32 SHOCK_MASK = 0x10000000;   // word 0 — Flame Shock
    constexpr uint32 LAVA_MASK = 0x1000;         // word 1 — Lava Burst
    // The ascendant displays, one per colour: the shaman takes one AT RANDOM
    // at every cast. They share the same CreatureModelData and differ only by
    // their three replaceable textures. Any entry added here must exist in the
    // generator that writes the CreatureDisplayInfo rows, both in the client
    // patch and in the server DBC.
    constexpr uint32 ASCENDANCE_FORMS[] = { 802120, 802121, 802122 };
    constexpr uint32 ASCENDANCE = 8600062;
    // WHAT A CAST GRANTS UNDER ASCENDANCE: two stacking buffs of the module's
    // own, one per school -- a Fire spell feeds the critical one, a Nature
    // spell the haste one, 3 % a stack -- both taken away with the ascendance.
    constexpr uint32 ASCENDANCE_FIRE_STACK = 8610038;
    constexpr uint32 ASCENDANCE_NATURE_STACK = 8610039;

    uint32 AscendanceBestRank(Player* shaman, uint8 word, uint32 mask)
    {
        uint32 best = 0;
        uint32 bestLevel = 0;
        for (auto const& paire : shaman->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_SHAMAN)
                continue;
            if (!(info->SpellFamilyFlags[word] & mask))
                continue;
            uint32 level = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!best || level > bestLevel)
            {
                best = info->Id;
                bestLevel = level;
            }
        }
        return best;
    }

    class spell_spheregrid_ascendance : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_ascendance);

        void GoUp(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            Player* shaman = GetTarget() ? GetTarget()->ToPlayer() : nullptr;
            if (!shaman)
                return;
            // THE SHAPE: a display drawn at random among those laid down.
            shaman->SetDisplayId(Acore::Containers::SelectRandomContainerElement(
                ASCENDANCE_FORMS));

            uint32 const shock = AscendanceBestRank(shaman, 0,
                                                         SHOCK_MASK);
            uint32 const lava = AscendanceBestRank(shaman, 1, LAVA_MASK);
            if (!shock && !lava)
                return;

            // FIVE ENEMIES IN FRONT OF HIM: the forward half-circle, the
            // nearest first.
            std::list<Unit*> preys;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck hostile(shaman, shaman,
                                                               ASCENDANCE_RANGE);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck>
                hunt(shaman, preys, hostile);
            Cell::VisitObjects(shaman, hunt, ASCENDANCE_RANGE);
            preys.remove_if([shaman](Unit* u)
            {
                return !u || !u->IsAlive() || !shaman->IsValidAttackTarget(u)
                    || !shaman->HasInArc(float(M_PI), u);
            });
            preys.sort(Acore::ObjectDistanceOrderPred(shaman));
            if (preys.size() > ASCENDANCE_TARGETS)
                preys.resize(ASCENDANCE_TARGETS);

            for (Unit* prey : preys)
            {
                if (shock)
                    shaman->CastSpell(prey, shock, true);
                if (lava)
                    shaman->CastSpell(prey, lava, true);
            }
        }

        void ComeBackDown(AuraEffect const* /*effect*/,
                         AuraEffectHandleModes /*mode*/)
        {
            // On expiry AS WELL AS on cancellation: the shaman takes his own
            // silhouette back.
            //
            // THE TWO STACKS STAY. Each lasts eight seconds of its own and
            // fades on its own time; taking them away with the ascendance
            // robbed the shaman of what his last casts had just earned him.
            if (Unit* target = GetTarget())
                target->RestoreDisplayId();
        }

        void Register() override
        {
            AfterEffectApply += AuraEffectApplyFn(
                spell_spheregrid_ascendance::GoUp, EFFECT_0,
                SPELL_AURA_MOD_DAMAGE_PERCENT_DONE, AURA_EFFECT_HANDLE_REAL);
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_spheregrid_ascendance::ComeBackDown, EFFECT_0,
                SPELL_AURA_MOD_DAMAGE_PERCENT_DONE, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // EVERY SPELL THE SHAMAN CASTS UNDER ASCENDANCE feeds one of the stacks.
    // Only what he casts himself counts: the shocks and lava bursts the
    // ascendance throws on its own are triggered, and so are the stacks.
    class spheregrid_ascendance_watch : public AllSpellScript
    {
    public:
        spheregrid_ascendance_watch() : AllSpellScript("spheregrid_ascendance_watch") { }

        void OnSpellCast(Spell* spell, Unit* caster, SpellInfo const* info,
                         bool /*skipCheck*/) override
        {
            if (!spell || !caster || !info || !caster->IsPlayer()
                || spell->IsTriggered() || !caster->HasAura(ASCENDANCE))
                return;
            uint32 const schools = info->GetSchoolMask();
            if (schools & SPELL_SCHOOL_MASK_FIRE)
                caster->CastSpell(caster, ASCENDANCE_FIRE_STACK, true);
            if (schools & SPELL_SCHOOL_MASK_NATURE)
                caster->CastSpell(caster, ASCENDANCE_NATURE_STACK, true);
        }
    };

    // =======================================================================
    // Spirit link totem — it does not heal, it REDISTRIBUTES
    // =======================================================================
    // All the logic is here: the DBC only carries a DUMMY aura ticking once a
    // second. At every tick, around the TOTEM (not the caster) and within the
    // group or the raid only:
    //
    // The MARKER carries everything visible: it says who is in the link, heals a
    // percentage of the maximum health per tick and takes a percentage off the
    // damage taken. The shaman wears it like the others — the spell aura itself
    // is hidden from the buff bar, so that there is only one icon.
    //
    //   1. the median of the life PERCENTAGES of the living members in range.
    //      RELATIVE health is what sorts, not absolute points: otherwise a
    //      wounded tank at 60 % would fund casters at 90 %, only because his bar
    //      is bigger;
    //   2. those ABOVE pour a share of their current health into a pool, never
    //      going below a floor of their maximum;
    //   3. those BELOW share the pool in proportion to their missing health —
    //      they may go past the median, up to their own maximum;
    //   4. only what is NEEDED is taken: should the supply exceed the demand,
    //      the givers pour less, otherwise health would be destroyed.
    //
    // The health is set DIRECTLY: neither a heal nor damage, so no overhealing,
    // no shield, no threat, no entering combat, no proc at all.
    constexpr float LINK_RADIUS = 7.0f;    // around the totem
    constexpr uint32 LINK_DURATION = 16000;  // ms
    constexpr uint32 LINK_SHARE = 10;      // % of CURRENT health poured per beat
    constexpr uint32 LINK_FLOOR = 10;  // % of MAX health below which nothing is taken
    constexpr uint32 LINK_VISUAL = 8600069;  // carries the effect, laid on the totem
    // The shaman block of spell ids runs from 60 to 69; 70 already belongs to
    // the mage.
    constexpr uint32 LINK_MARKER = 8600064;  // marks the members within range

    // Shares `total` in proportion to the `weights`, WITHOUT loss or creation:
    // the remainder of the integer divisions is handed out along the way, so that
    // the sum of the shares is exactly `total`.
    std::vector<uint64> LinkShareOut(uint64 total, std::vector<uint64> const& weights)
    {
        std::vector<uint64> shares(weights.size(), 0);
        uint64 sum = 0;
        for (uint64 w : weights)
            sum += w;
        if (!sum || !total)
            return shares;
        uint64 given = 0;
        for (size_t i = 0; i < weights.size(); ++i)
        {
            shares[i] = total * weights[i] / sum;
            given += shares[i];
        }
        for (size_t i = 0; i < shares.size() && given < total; ++i)
            if (weights[i])
            {
                ++shares[i];
                ++given;
            }
        return shares;
    }

    class spell_spheregrid_spirit_link : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_spirit_link);

        ObjectGuid _totem;
        // Those carrying the marker. The marker being PERMANENT, nothing
        // removes it by itself: the list is kept so as to take it back for
        // certain, including from someone who left the group along the way.
        GuidSet _marques;

        void Apply(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            Unit* shaman = GetTarget();
            if (!shaman)
                return;
            if (TempSummon* totem = shaman->SummonCreature(
                    TOTEM, shaman->GetPosition(), TEMPSUMMON_TIMED_DESPAWN,
                    LINK_DURATION))
            {
                _totem = totem->GetGUID();
                // THE EFFECT IS ON THE TOTEM, not on the shaman: a carrier
                // aura, which does nothing goal hold the visual for the duration
                // and follow the creature.
                totem->CastSpell(totem, LINK_VISUAL, true);
            }
        }

        void Remove(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            // On expiry AS WELL AS on cancellation: the totem goes, and nobody
            // carries the marker any more.
            Unit* shaman = GetTarget();
            if (!shaman)
                return;
            if (Creature* totem = ObjectAccessor::GetCreature(*shaman, _totem))
                totem->DespawnOrUnsummon();
            for (ObjectGuid guid : _marques)
                if (Unit* marker = ObjectAccessor::GetUnit(*shaman, guid))
                    marker->RemoveAurasDueToSpell(LINK_MARKER,
                                                  shaman->GetGUID());
            _marques.clear();
        }

        void Beat(AuraEffect const* /*effect*/)
        {
            Unit* shaman = GetTarget();
            if (!shaman)
                return;
            Creature* totem = ObjectAccessor::GetCreature(*shaman, _totem);
            if (!totem || !totem->IsInWorld())
                return;
            Player* player = shaman->ToPlayer();
            if (!player)
                return;

            // 1. THE CIRCLE: the shaman and, if he has one, his group or his
            //    raid — alive, within the radius of the TOTEM. ALONE COUNTS TOO:
            //    with no group, alone in a group or alone in a raid, the shaman
            //    is marked and enjoys the heal and the damage reduction. There
            //    is simply nothing to redistribute among one.
            std::vector<Player*> candidats;
            if (Group* group = player->GetGroup())
                for (GroupReference* it = group->GetFirstMember(); it; it = it->next())
                {
                    if (Player* membre = it->GetSource())
                        candidats.push_back(membre);
                }
            else
                candidats.push_back(player);

            std::vector<Player*> members;
            GuidSet dedans;
            {
                for (Player* membre : candidats)
                {
                    if (!membre || !membre->GetMaxHealth())
                        continue;
                    // THE MARKER follows the circle at every tick: applied as
                    // soon as one steps inside the radius, removed as soon as one
                    // steps out or dies. It is the only visible sign of being in
                    // the link.
                    if (membre->IsAlive() && membre->IsInMap(totem)
                        && membre->IsWithinDistInMap(totem, LINK_RADIUS))
                    {
                        members.push_back(membre);
                        if (!membre->HasAura(LINK_MARKER, shaman->GetGUID()))
                            shaman->CastSpell(membre, LINK_MARKER, true);
                        dedans.insert(membre->GetGUID());
                    }
                }
            }

            // THOSE WHO LEFT: the list of the previous tick is walked, not the
            // group — someone who left the raid along the way would no longer be
            // walked and would keep the marker for ever.
            for (ObjectGuid guid : _marques)
                if (!dedans.count(guid))
                    if (Unit* parti = ObjectAccessor::GetUnit(*shaman, guid))
                        parti->RemoveAurasDueToSpell(LINK_MARKER,
                                                     shaman->GetGUID());
            _marques = dedans;

            // At one, the marker is already applied: we stop before the
            // redistribution, which would make no sense.
            if (members.size() < 2)
                return;

            // 2. THE MEDIAN of the life PERCENTAGES — RELATIVE health. With an
            //    even number: the mean of the two middle values. In thousandths,
            //    to keep some precision in integer arithmetic.
            std::vector<uint64> shares;
            shares.reserve(members.size());
            for (Player* m : members)
                shares.push_back(uint64(m->GetHealth()) * 1000 / m->GetMaxHealth());
            std::sort(shares.begin(), shares.end());
            size_t const middle = shares.size() / 2;
            uint64 const median = (shares.size() % 2)
                ? shares[middle]
                : (shares[middle - 1] + shares[middle]) / 2;

            // 3. GIVERS and RECEIVERS.
            std::vector<Player*> givers, receveurs;
            std::vector<uint64> capacites, manques;
            uint64 supply = 0, demand = 0;
            for (Player* m : members)
            {
                uint64 const current = m->GetHealth();
                uint64 const highest = m->GetMaxHealth();
                uint64 const progress = current * 1000 / highest;
                if (progress > median)
                {
                    uint64 const floor = highest * LINK_FLOOR / 100;
                    if (current <= floor)
                        continue;                       // already below its floor
                    uint64 gift = current * LINK_SHARE / 100;
                    if (current - gift < floor)        // the gift stops at the floor
                        gift = current - floor;
                    if (!gift)
                        continue;
                    givers.push_back(m);
                    capacites.push_back(gift);
                    supply += gift;
                }
                else if (progress < median && current < highest)
                {
                    receveurs.push_back(m);
                    manques.push_back(highest - current);
                    demand += highest - current;
                }
            }
            if (!supply || !demand)
                return;

            // 4. THE TRANSFER: what is needed, and nothing more.
            uint64 const transfer = std::min(supply, demand);
            std::vector<uint64> const pris = LinkShareOut(transfer, capacites);
            std::vector<uint64> const recus = LinkShareOut(transfer, manques);

            // The sums are in uint64 so as not to overflow on a full raid, goal
            // the health itself fits in a uint32: it is converted back
            // explicitly when applied.
            for (size_t i = 0; i < givers.size(); ++i)
                if (pris[i])
                    givers[i]->SetHealth(
                        uint32(uint64(givers[i]->GetHealth()) - pris[i]));
            for (size_t i = 0; i < receveurs.size(); ++i)
                if (recus[i])
                {
                    uint64 const vise = uint64(receveurs[i]->GetHealth()) + recus[i];
                    uint64 const highest = uint64(receveurs[i]->GetMaxHealth());
                    receveurs[i]->SetHealth(uint32(std::min(vise, highest)));
                }
        }

        void Register() override
        {
            AfterEffectApply += AuraEffectApplyFn(
                spell_spheregrid_spirit_link::Apply, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_spheregrid_spirit_link::Remove, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_spheregrid_spirit_link::Beat, EFFECT_0,
                SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // =======================================================================
    // Demonic tyrant
    // =======================================================================
    // Thirty seconds, and a model of its own. It burns everything around it — a
    // ground aura built like the infernal's immolation — and EVERY ONE OF ITS
    // ATTACKS strengthens the warlock's demons.
    //
    // WHY AN AURA ON THE WARLOCK rather than a plain cast: there has to be a
    // place to clean up. The bonuses must fall when the tyrant DIES as much as
    // when it VANISHES, and a CreatureAI offers no reliable hook on despawn. The
    // aura of the spell serves both: removing it sends the tyrant away AND takes
    // every bonus back, and the tyrant AI removes that aura when it dies. A
    // single path for both cases.
    constexpr uint32 TYRANT = 8600082;
    // THE TYRANT'S HASTE replaces the fire area it used to carry: the channel
    // meant for it, which DIVIDES the attack time instead of rewriting it — so
    // the template keeps its reference cadence.
    constexpr float TYRANT_HASTE = 15.0f;         // %
    constexpr uint32 TYRANT_IMP = 8610000;
    constexpr uint32 TYRANT_HUNTER = 8610001;
    constexpr uint32 TYRANT_SUCCUBUS = 8610002;
    constexpr uint32 TYRANT_WALKER = 8610003;
    constexpr uint32 TYRANT_ENSLAVED = 8610004;
    constexpr uint32 TYRANT_CHAINS = 8610005;   // Xer'thul's demons, stacking
    constexpr uint32 TYRANT_BROKEN = 8610006;   // Xer'thul's demons, fixed
    constexpr uint32 TYRANT_SIZE = 8610007;
    constexpr uint32 TYRANT_GUARD = 8610008;       // felguard: damage, fixed
    constexpr uint32 TYRANT_GUARD_HASTE = 8610009;  // felguard: haste, stacking
    // THE WARLOCK HIMSELF, in metamorphosis. These two do not go on a demon goal
    // on the master: the clean-up must therefore take them back separately.
    constexpr uint32 TYRANT_META_STACK = 8610010;  // haste + crit, cumulables
    constexpr uint32 TYRANT_META_FIXED = 8610011;   // speed + mana, fixes
    constexpr uint32 METAMORPHOSIS = 47241;        // the NATIVE demonic form

    // Everything the tyrant may have applied, for the final clean-up.
    constexpr uint32 TYRANT_BONUS[] = {
        TYRANT_IMP, TYRANT_HUNTER, TYRANT_SUCCUBUS, TYRANT_WALKER,
        TYRANT_ENSLAVED, TYRANT_CHAINS, TYRANT_BROKEN, TYRANT_SIZE,
        TYRANT_GUARD, TYRANT_GUARD_HASTE
    };

    // What the tyrant applies to THE WARLOCK, and not to his demons.
    constexpr uint32 TYRANT_BONUS_MASTER[] = { TYRANT_META_STACK, TYRANT_META_FIXED };

    // The warlock's classic pets, by creature entry.
    constexpr uint32 DEMON_IMP = 416;
    constexpr uint32 DEMON_HUNTER = 417;
    constexpr uint32 DEMON_WALKER = 1860;
    constexpr uint32 DEMON_SUCCUBUS = 1863;
    constexpr uint32 DEMON_FELGUARD = 17252;
    // The five guardians of a custom summoning spell of the module.
    constexpr uint32 DEMON_XERTHUL_FIRST = 808000;
    constexpr uint32 DEMON_XERTHUL_LAST = 808004;

    constexpr uint32 TYRANT_SHARE_SHIELD = 50;   // % of the demon's max health
    // TWO INSTANT VISUALS, played on the TARGET struck and not on the demon: an
    // aura can only aim at its bearer, hence the direct packet
    // (SMSG_PLAY_SPELL_VISUAL), which takes the unit as its source. These are
    // NATIVE SpellVisualKits, never modified.
    constexpr uint32 KIT_BITE_SHADOW = 117;   // Shadow_ImpactDD_Low_Chest
    constexpr uint32 KIT_SEDUCTION = 2650;      // Seduction_State_Head

    // The warlock's demons: his pet, his guardians, his enslaved ones.
    static void GatherDemons(Unit* master, std::vector<Unit*>& demons)
    {
        if (!master)
            return;
        for (Unit* controle : master->m_Controlled)
            if (controle && controle->IsAlive())
                demons.push_back(controle);
    }

    // The bonus specific to the demon, or 0 when it deserves none.
    static uint32 DemonBonus(Unit* demon, Unit* master)
    {
        Creature* creature = demon ? demon->ToCreature() : nullptr;
        if (!creature)
            return 0;
        uint32 const entry = creature->GetEntry();
        if (entry >= DEMON_XERTHUL_FIRST && entry <= DEMON_XERTHUL_LAST)
            return TYRANT_CHAINS;
        switch (entry)
        {
            case DEMON_IMP: return TYRANT_IMP;
            case DEMON_HUNTER:  return TYRANT_HUNTER;
            case DEMON_WALKER:  return TYRANT_WALKER;
            case DEMON_SUCCUBUS:   return TYRANT_SUCCUBUS;
            // The STACKING one acts as the main bonus, as for the guardians:
            // the fixed one is applied beside it, once only.
            case DEMON_FELGUARD: return TYRANT_GUARD_HASTE;
            default: break;
        }
        // An ENSLAVED demon has no entry of ours: it is recognised by being
        // charmed by the warlock, and not merely possessed.
        if (master && demon->GetCharmerGUID() == master->GetGUID())
            return TYRANT_ENSLAVED;
        return 0;
    }

    // Takes every bonus back from every demon — the tyrant is leaving.
    static void TakeBackBonuses(Unit* master)
    {
        if (!master)
            return;
        for (uint32 bonus : TYRANT_BONUS_MASTER)
            master->RemoveAurasDueToSpell(bonus);
        std::vector<Unit*> demons;
        GatherDemons(master, demons);
        for (Unit* demon : demons)
            for (uint32 bonus : TYRANT_BONUS)
                demon->RemoveAurasDueToSpell(bonus);
    }

    class spell_spheregrid_tyrant : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_tyrant);

        // THE SUMMONING IS NO LONGER HERE: the DBC takes care of it (the
        // second effect of the spell). Only the CLEAN-UP is left, carried by the
        // aura of the other effect.
        void SendBack(AuraEffect const* /*effect*/, AuraEffectHandleModes /*mode*/)
        {
            Unit* caster = GetCaster();
            // Whatever the path: the end of the duration, the death of the
            // tyrant (its AI then removes this aura) or the death of the
            // warlock.
            TakeBackBonuses(caster);
            if (!caster)
                return;
            // The guardian summoned by the DBC is among the controlled units:
            // there is therefore no need to remember its GUID.
            std::vector<Unit*> a_renvoyer;
            for (Unit* controle : caster->m_Controlled)
                if (controle && controle->GetEntry() == GUARD_DEATH)
                    a_renvoyer.push_back(controle);
            for (Unit* tyrant : a_renvoyer)
                if (Creature* creature = tyrant->ToCreature())
                    creature->DespawnOrUnsummon();
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectApplyFn(spell_spheregrid_tyrant::SendBack,
                                                   EFFECT_1, SPELL_AURA_DUMMY,
                                                   AURA_EFFECT_HANDLE_REAL);
        }
    };

    // The mana burn of the corrupted hunter. It is done HERE and not by a
    // triggered spell, for want of a tenth id in the range.
    class spell_spheregrid_tyrantt_hunter : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_tyrantt_hunter);

        void Burn(AuraEffect const* effect, ProcEventInfo& infos)
        {
            PreventDefaultAction();
            Unit* target = infos.GetActionTarget();
            if (!target || target->getPowerType() != POWER_MANA)
                return;
            // This core has no CountPctFromMaxPower: we compute it.
            uint32 const perte = CalculatePct(target->GetMaxPower(POWER_MANA),
                                              effect->GetAmount());
            if (!perte)
                return;
            target->ModifyPower(POWER_MANA, -int32(std::min<uint32>(
                perte, target->GetPower(POWER_MANA))));
            // The shadow falling on the drained target.
            target->SendPlaySpellVisual(KIT_BITE_SHADOW);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_spheregrid_tyrantt_hunter::Burn,
                                             EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
        }
    };

    // The succubus charm: a chance per attack, towards the NATIVE seduction.
    class spell_spheregrid_tyrantt_succubus : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_tyrantt_succubus);

        void Charm(AuraEffect const* effect, ProcEventInfo& infos)
        {
            PreventDefaultAction();
            Unit* target = infos.GetActionTarget();
            Unit* demon = GetTarget();
            // The roll is made HERE: the DBC ProcChance is at 101 for every
            // spell of the module, and is therefore of no use to carry a
            // percentage of its own.
            if (!target || !demon || !roll_chance_i(effect->GetAmount()))
                return;
            demon->CastSpell(target, SEDUCTION, true);
            // The charm shows even when the target resists it: what is
            // announced is the TRIGGER, not its outcome.
            target->SendPlaySpellVisual(KIT_SEDUCTION);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_spheregrid_tyrantt_succubus::Charm,
                                             EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
        }
    };

    // MODELLED ON THE DEATH KNIGHT GHOUL, the named reference: a guardian that
    // fights beside its master without being commandable. It derives from
    // CombatAI — not PetAI, which would give a pet bar and orders — and merely
    // remembers the master's target at the moment of the summon.
    //
    // The DBC does the rest: a SIMPLE guardian through its SummonProperties.
    // Guardian::InitStats gives it master, faction and level; CombatAI gives it
    // aggression and pursuit. All that is left here is what neither of them can
    // say.
    struct npc_spheregrid_tyrant : public CombatAI
    {
        npc_spheregrid_tyrant(Creature* creature) : CombatAI(creature) { }

        ObjectGuid _target;

        void InitializeAI() override
        {
            CombatAI::InitializeAI();
            // The haste: the channel that DIVIDES the attack time, without
            // rewriting the reference cadence of the template.
            me->ApplyAttackTimePercentMod(BASE_ATTACK, TYRANT_HASTE, true);
        }

        // The warlock's target AT THE MOMENT OF THE SUMMON, remembered then
        // attacked on the first turn — the exact procedure of the death knight
        // ghoul.
        void IsSummonedBy(WorldObject* summoner) override
        {
            if (summoner && summoner->IsPlayer())
                if (Unit* victim = summoner->ToPlayer()->GetVictim())
                    _target = victim->GetGUID();
        }

        void UpdateAI(uint32 diff) override
        {
            if (!_target.IsEmpty())
            {
                if (Unit* target = ObjectAccessor::GetUnit(*me, _target))
                    if (target->IsAlive() && me->IsValidAttackTarget(target))
                        AttackStart(target);
                _target.Clear();
            }
            CombatAI::UpdateAI(diff);
        }

        // EVERY ATTACK strengthens the demons. Only DIRECT blows are kept: the
        // ticks of the flames come through here as well, and would strengthen the
        // demons twice a second.
        void DamageDealt(Unit* /*victim*/, uint32& /*damage*/,
                         DamageEffectType type,
                         SpellSchoolMask /*school*/) override
        {
            if (type != DIRECT_DAMAGE)
                return;
            Unit* master = me->GetOwner();
            if (!master)
                return;

            std::vector<Unit*> demons;
            GatherDemons(master, demons);
            for (Unit* demon : demons)
            {
                uint32 const bonus = DemonBonus(demon, master);
                if (!bonus)
                    continue;

                // STACKING: it is recast, the stack goes up by one.
                // NON-STACKING: it is NOT recast when the aura is already there
                // — otherwise "non-stacking" would become "renewed at every
                // blow", which would for instance keep one shield perpetually
                // full.
                SpellInfo const* infos = sSpellMgr->GetSpellInfo(bonus);
                bool const cumulable = infos && infos->StackAmount > 1;
                if (cumulable || !demon->HasAura(bonus, me->GetGUID()))
                {
                    me->CastSpell(demon, bonus, true);
                    if (bonus == TYRANT_WALKER)
                    {
                        // THE SHIELD AMOUNT, set on the aura once applied.
                        // CastCustomSpell should have been enough — the core
                        // uses it that way — goal in game the shield was worth
                        // next to nothing, exactly what the DBC alone gives:
                        // the custom value was not arriving. Writing the amount
                        // on the effect leaves no doubt.
                        if (Aura* aura = demon->GetAura(TYRANT_WALKER, me->GetGUID()))
                            if (AuraEffect* shield = aura->GetEffect(EFFECT_1))
                                shield->SetAmount(int32(
                                    demon->CountPctFromMaxHealth(TYRANT_SHARE_SHIELD)));
                    }
                }

                // Two demons have a SECOND bonus, a fixed one: it lives apart
                // because it must NOT follow the stacks of the first.
                if (bonus == TYRANT_CHAINS
                    && !demon->HasAura(TYRANT_BROKEN, me->GetGUID()))
                    me->CastSpell(demon, TYRANT_BROKEN, true);
                if (bonus == TYRANT_GUARD_HASTE
                    && !demon->HasAura(TYRANT_GUARD, me->GetGUID()))
                    me->CastSpell(demon, TYRANT_GUARD, true);

                // And the size, for every strengthened demon.
                if (!demon->HasAura(TYRANT_SIZE, me->GetGUID()))
                    me->CastSpell(demon, TYRANT_SIZE, true);
            }

            // THE WARLOCK IN METAMORPHOSIS. It is checked again at every blow,
            // and not once at the summon: the shape may be taken AFTER the
            // tyrant arrives, and then it counts; should it end before him, the
            // bonuses fall at once.
            if (master->HasAura(METAMORPHOSIS))
            {
                me->CastSpell(master, TYRANT_META_STACK, true);
                if (!master->HasAura(TYRANT_META_FIXED, me->GetGUID()))
                    me->CastSpell(master, TYRANT_META_FIXED, true);
            }
            else
                for (uint32 bonus : TYRANT_BONUS_MASTER)
                    master->RemoveAurasDueToSpell(bonus);
        }

        void JustDied(Unit* tueur) override
        {
            CombatAI::JustDied(tueur);
            // The clean-up is not done here: the aura is removed from the
            // warlock, and IT is what takes the bonuses back. A single path, so
            // no half clean-up should either case be forgotten.
            if (Unit* master = me->GetOwner())
                master->RemoveAurasDueToSpell(TYRANT);
            // The body does not linger, like the death knight ghoul's.
            if (me->IsGuardian() || me->IsSummon())
                me->ToTempSummon()->UnSummon();
        }

    };

    // =======================================================================
    // Wild rush — the whole pack bursts out
    // =======================================================================
    constexpr uint32 RUSH_DURATION = 30000;         // ms -- a mirror of the DBC (D_30S,
                                                 // the duration of the pack)
    constexpr float RUSH_RADIUS = 4.0f;           // the ring around the prey
    constexpr uint32 RUSH_FRENZY = 8600095;    // the proc aura applied to
                                                 // the beasts: every blow
                                                 // triggers the stacking
                                                 // bleed
    // THE PACK BEAST: OUR creature, carrying the pack AI, modelled on the proven
    // pattern of the module. Two attempts failed before: summoning the pet entry
    // gave beasts on the wild template whose AI never calls
    // DoMeleeAttackIfReady, hence NO attack at all, neither through AttackStart
    // nor through Unit::Attack. This AI attacks the master's target and TAKES ITS
    // OWN BACK as soon as the prey falls.
    constexpr uint32 RUSH_BEAST = 803811;
    constexpr float RUSH_DIVISOR = 2.5f;        // the beasts' weapon damage:
                                                 // a fraction of the pet's
    class spell_spheregrid_wild_rush : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_wild_rush);

        // With no beast out, the spell is REFUSED at the cast: it went off for
        // nothing, cooldown included.
        SpellCastResult CheckCast()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player || !player->GetPet())
                return SPELL_FAILED_NO_PET;
            return SPELL_CAST_OK;
        }

        void Surge()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player)
                return;

            Pet* familier = player->GetPet();
            if (!familier)
                return;                          // with no beast, nothing to call

            // The prey: the spell's target first, the hunter's next, the
            // beast's last — "the summons do nothing" came from using GetVictim()
            // alone, which is empty outside combat.
            Unit* prey = GetExplTargetUnit();
            if (!prey || !player->IsValidAttackTarget(prey))
                prey = player->GetVictim();
            if (!prey)
                prey = familier->GetVictim();

            // They burst out AROUND THE PREY; failing a prey, around the
            // hunter.
            WorldObject* pivot = prey ? static_cast<WorldObject*>(prey)
                                       : static_cast<WorldObject*>(player);
            for (uint8 i = 0; i < 3; ++i)
            {
                Position pos = pivot->GetPosition();
                pivot->MovePositionToFirstCollision(pos, RUSH_RADIUS,
                                                    float(i) * 2.0f * float(M_PI) / 3.0f);
                // OUR beast, with its own AI — not the pet entry: the AI is
                // what makes it strike.
                Creature* copie = player->SummonCreature(RUSH_BEAST, pos,
                    TEMPSUMMON_TIMED_DESPAWN, RUSH_DURATION);
                if (!copie)
                    continue;
                // All the rest — faction, level, display and figures of the
                // pet, frenzy, targeting, return to the hunter — lives in the
                // pack AI, modelled on the snake trap.
                if (prey && copie->IsAIEnabled)
                    copie->AI()->AttackStart(prey);
            }
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_spheregrid_wild_rush::CheckCast);
            AfterCast += SpellCastFn(spell_spheregrid_wild_rush::Surge);
        }
    };

    // =======================================================================
    // Consecutive shots — the character shoots at every volley
    // =======================================================================
    // Three channels were tried: the ranged weapon attribute alone (it animates
    // the CAST, so once), an emote at every tick (ignored during a channel:
    // nothing at all), and a TRIGGERED spell (the missile flies, the character
    // stays still — a triggered cast does not replay the animation). What is left
    // is the KIT channel, proven on the heroic leap: a bare kit carrying ONLY the
    // animation, sent at every tick and chosen according to the weapon held.
    constexpr uint32 SHOT_KIT_BOW = 30040;      // AttackBow 46
    constexpr uint32 SHOT_KIT_GUN = 30041;    // AttackRifle 49
    constexpr uint32 SHOT_KIT_THROW = 30042;      // AttackThrown 107

    // The EMBEDDED BOLTS: every volley stacks the debuff carried by the shot;
    // on its EXPIRY ONLY, the bolts detonate around the target for an amount
    // proportional to the number of stacks.
    constexpr uint32 SHOT_DETONATION = 8600098;
    // THE CHANNEL FIRES SIX VOLLEYS over three seconds. So six stacks at most
    // on the target.
    constexpr int32 SHOT_VOLLEYS = 6;

    class spell_spheregrid_embedded_bolts : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_embedded_bolts);

        void Detonate(AuraEffect const* /*effect*/,
                     AuraEffectHandleModes /*mode*/)
        {
            // On expiry alone: a target that dies or is dispelled does not set
            // the charge off (the shimmer marker pattern).
            if (GetTargetApplication()->GetRemoveMode()
                != AURA_REMOVE_BY_EXPIRE)
                return;
            Unit* hunter = GetCaster();
            Unit* target = GetTarget();
            if (!hunter || !target)
                return;
            // THE AMOUNT COMES FROM THE DBC of the detonation, where the
            // balancing writes it: the script only spreads it over the stacks
            // actually applied. A number hardcoded here would escape the
            // balancing.
            int32 full = 0;
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(SHOT_DETONATION))
                full = info->Effects[EFFECT_0].CalcValue();
            int32 damage = full * int32(GetStackAmount()) / SHOT_VOLLEYS;
            hunter->CastCustomSpell(target, SHOT_DETONATION, &damage, nullptr,
                                      nullptr, true);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_spheregrid_embedded_bolts::Detonate, EFFECT_1,
                SPELL_AURA_DUMMY, AURA_EFFECT_HANDLE_REAL);
        }
    };

    class spell_spheregrid_consecutive_shots : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_consecutive_shots);

        void Draw(AuraEffect const* /*effect*/)
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player)
                return;
            uint32 kit = SHOT_KIT_BOW;
            if (Item* arme = player->GetWeaponForAttack(RANGED_ATTACK))
                switch (arme->GetTemplate()->SubClass)
                {
                    case ITEM_SUBCLASS_WEAPON_GUN:
                        kit = SHOT_KIT_GUN;
                        break;
                    case ITEM_SUBCLASS_WEAPON_THROWN:
                        kit = SHOT_KIT_THROW;
                        break;
                    default:            // bow and crossbow
                        break;
                }
            player->SendPlaySpellVisual(kit);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(
                spell_spheregrid_consecutive_shots::Draw, EFFECT_0,
                SPELL_AURA_PERIODIC_TRIGGER_SPELL);
        }
    };

    // =======================================================================
    // Wild charge — the leap changes with the form
    // =======================================================================
    // ONE BUTTON, six behaviours according to the form, borrowed from the
    // movement spells of the other classes:
    //
    //   none (humanoid)  a short sprint
    //   bear             the warrior leap, towards the target point
    //   cat              the rogue teleport, towards the target point
    //   travel           a leap towards the target point
    //   tree of life     a teleport onto the ally nearest the point
    //   moonkin          a return to the most recent star
    //
    // The spell is GROUND-TARGETED for every form: bear and cat are aimed at
    // theirs, and a reticle cannot be conditional. The sprint and the return to
    // a star therefore ignore the point.
    constexpr uint32 CHARGE_WILD = 8600090;
    // The five form spells, tuned with the grid spell: a node only teaches one,
    // and the numeric block of the class is full.
    constexpr uint32 CHARGE_FORMS[] = { 8610016, 8610017, 8610018,
                                         8610019, 8610020 };
    constexpr uint32 CHARGE_TRAIL = 8610014;        // l'aura who seme
    // THE THREE COLOURS, in order of RANK from the end of the trail: the most
    // recent star is green, the middle one yellow, the oldest red. The index in
    // this table IS the rank, which makes the repaint immediate at every change.
    //
    // These are CREATURE DISPLAYS, not auras. The first two attempts set the
    // model through an aura with a state kit and nothing showed: the star
    // creature wore the invisible stalker display — the client had no body to
    // hang the kit on. The creature IS the star now.
    constexpr uint32 CHARGE_STAR_DISPLAYS[3] = { 802105, 802104, 802103 };
    constexpr uint32 CHARGE_STAR_COUNT = 8610024;  // the counter, visible

    // THE START MARKER: laid down where the druid stood, before he left, and
    // fading after a couple of seconds.
    constexpr uint32 CHARGE_START_CREATURE = 803817;
    constexpr uint32 CHARGE_START_DURATION = 2000;      // ms
    constexpr uint32 CHARGE_STAR_CREATURE = 803816;
    constexpr float CHARGE_TREE_RANGE = 40.0f;      // for the ally
    constexpr float CHARGE_STAR_SPACING = 20.0f;      // between two stars
    // THE TRAVELLER'S DASH goes TWICE as far and twice as fast as the common
    // leap, its apex rising by half as much again.
    constexpr float TRAVEL_DISTANCE = LEAP_DISTANCE * 2.0f;
    constexpr float TRAVEL_SPEED = LEAP_SPEED * 2.0f;
    constexpr float TRAVEL_HEIGHT = LEAP_HEIGHT * 1.5f;
    constexpr uint32 CHARGE_STARS_MAX = 3;

    // THE TRAIL: per player, the stars from the oldest to the most recent. They
    // do not fade with time — only the druid's return, or the arrival of a
    // fourth, takes one back. The list lives in memory: a trail does not survive
    // a restart, which is of no consequence since the creatures do not either.
    std::unordered_map<ObjectGuid, std::deque<ObjectGuid>> g_stars;

    Creature* StarOf(Unit* where, ObjectGuid guid)
    {
        return guid ? ObjectAccessor::GetCreature(*where, guid) : nullptr;
    }

    // Takes one star back: the creature goes, the list forgets it.
    void FoldStar(Unit* where, std::deque<ObjectGuid>& trail, bool latest)
    {
        while (!trail.empty())
        {
            ObjectGuid guid = latest ? trail.back() : trail.front();
            if (latest)
                trail.pop_back();
            else
                trail.pop_front();
            if (Creature* star = StarOf(where, guid))
            {
                star->DespawnOrUnsummon();
                return;
            }
            // A creature gone otherwise (a map change): we move on to the next
            // rather than return a silent trail.
        }
    }

    // THE REPAINT: each star takes the display of its rank. It is not applied
    // again when it already has it — otherwise the model would start over from
    // its first animation frame at every beat of the trail.
    void RepaintTrail(Unit* where, std::deque<ObjectGuid> const& trail)
    {
        for (size_t i = 0; i < trail.size(); ++i)
        {
            Creature* star = StarOf(where, trail[trail.size() - 1 - i]);
            if (!star)
                continue;
            uint32 wanted = CHARGE_STAR_DISPLAYS[i < 3 ? i : 2];
            if (star->GetDisplayId() != wanted)
                star->SetDisplayId(wanted);
        }
    }

    // THE COUNTER: one stack per star laid down, on the druid. It disappears
    // when none is left.
    void UpdateCounter(Player* player, size_t count)
    {
        if (!player)
            return;
        if (!count)
        {
            player->RemoveAurasDueToSpell(CHARGE_STAR_COUNT);
            return;
        }
        if (!player->HasAura(CHARGE_STAR_COUNT))
            player->CastSpell(player, CHARGE_STAR_COUNT, true);
        if (Aura* aura = player->GetAura(CHARGE_STAR_COUNT))
            aura->SetStackAmount(uint8(count));
    }

    // THE WHOLE TRAIL TAKEN BACK at once. The druid leaves the form or logs
    // out: nothing must be left on the ground, nor any counter above his head.
    void ClearTrail(Player* player)
    {
        auto it = g_stars.find(player->GetGUID());
        if (it != g_stars.end())
        {
            for (ObjectGuid guid : it->second)
                if (Creature* star = ObjectAccessor::GetCreature(*player,
                                                                   guid))
                    star->DespawnOrUnsummon();
            g_stars.erase(it);
        }
        player->RemoveAurasDueToSpell(CHARGE_STAR_COUNT);
    }

    // What follows EVERY change to the trail: the colours and the count.
    void TrailChanged(Player* player, std::deque<ObjectGuid> const& trail)
    {
        RepaintTrail(player, trail);
        UpdateCounter(player, trail.size());
    }

    // THE TARGETED ALLY, and the teleport onto him: the tree form is the only
    // one of the six to take a unit for a target, and the spell gives it one.
    void TowardsAlly(Unit* caster, Unit* ally)
    {
        Player* player = caster ? caster->ToPlayer() : nullptr;
        if (!player || !ally || !ally->IsAlive())
            return;
        player->NearTeleportTo(ally->GetPositionX(), ally->GetPositionY(),
                               ally->GetPositionZ(), player->GetOrientation());
    }

    // THE RETURN: to the most recent star, which is then taken back. The next
    // cast therefore goes back to the previous one, further and further away.
    void StarReturn(Unit* caster)
    {
        Player* player = caster ? caster->ToPlayer() : nullptr;
        auto it = player ? g_stars.find(player->GetGUID()) : g_stars.end();
        if (it == g_stars.end())
            return;
        Creature* star = nullptr;
        while (!it->second.empty() && !star)
        {
            star = StarOf(player, it->second.back());
            if (!star)
                it->second.pop_back();
        }
        if (!star)
            return;
        // THE START MARKER is laid down BEFORE the departure, at the spot the
        // druid leaves. Its creature already carries the right display and its
        // summon timer takes it back after a couple of seconds: nothing to time
        // here.
        player->SummonCreature(CHARGE_START_CREATURE, *player,
                               TEMPSUMMON_TIMED_DESPAWN,
                               CHARGE_START_DURATION);

        player->NearTeleportTo(star->GetPositionX(), star->GetPositionY(),
                               star->GetPositionZ(), player->GetOrientation());
        it->second.pop_back();
        star->DespawnOrUnsummon();
        TrailChanged(player, it->second);
    }

    // THE SHORT STRIDE gives the humanoid form back first. The DBC could REFUSE
    // the cast while shapeshifted — the attribute the spell carried until now —
    // goal not shift out of the form. The attribute is therefore removed and the
    // script is what gives the form back, before the speed aura is applied.
    class spell_spheregrid_short_stride : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_short_stride);

        void GiveBack()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (player && player->GetShapeshiftForm() != FORM_NONE)
                player->RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT);
        }

        void Register() override
        {
            BeforeCast += SpellCastFn(spell_spheregrid_short_stride::GiveBack);
        }
    };

    // THE BEAR: the warrior leap, identical.
    class spell_spheregrid_bear_charge : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_bear_charge);

        void Leap(SpellEffIndex /*index*/)
        {
            HeroicLeap(GetCaster(), GetExplTargetDest(),
                         GetSpellInfo()->SpellVisual[0]);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_spheregrid_bear_charge::Leap,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // THE CAT: the rogue teleport.
    class spell_spheregrid_cat_charge : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_cat_charge);

        void Fly(SpellEffIndex /*index*/)
        {
            RogueTranslation(GetCaster(), GetExplTargetDest());
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_cat_charge::Fly,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // THE TRAVEL FORM: the directional leap, the common rule of the module.
    class spell_spheregrid_travel_charge : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_travel_charge);

        void Leap(SpellEffIndex /*index*/)
        {
            if (Unit* caster = GetCaster())
                LeapTowards(caster, MovementAngle(caster),
                           TRAVEL_DISTANCE, false, TRAVEL_SPEED,
                           TRAVEL_HEIGHT);
        }

        void Register() override
        {
            OnEffectLaunch += SpellEffectFn(spell_spheregrid_travel_charge::Leap,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // THE TREE OF LIFE: the teleport onto the targeted ally.
    class spell_spheregrid_tree_charge : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_tree_charge);

        void Join(SpellEffIndex /*index*/)
        {
            TowardsAlly(GetCaster(), GetHitUnit());
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_spheregrid_tree_charge::Join,
                                               EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // THE MOONKIN: the return to a star. No cooldown, goal refused when there is
    // none — the refusal falls BEFORE the cost and the cast time.
    class spell_spheregrid_moonkin_charge : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_moonkin_charge);

        SpellCastResult CheckCast()
        {
            Unit* caster = GetCaster();
            if (!caster)
                return SPELL_CAST_OK;
            auto it = g_stars.find(caster->GetGUID());
            if (it != g_stars.end() && !it->second.empty())
                return SPELL_CAST_OK;
            SetCustomCastResultMessage(SPELL_CUSTOM_ERROR_NO_VALID_TARGETS);
            return SPELL_FAILED_CUSTOM_ERROR;
        }

        void ComeBack(SpellEffIndex /*index*/)
        {
            StarReturn(GetCaster());
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_spheregrid_moonkin_charge::CheckCast);
            OnEffectLaunch += SpellEffectFn(spell_spheregrid_moonkin_charge::ComeBack,
                                            EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };

    // THE STAR TRAIL. A PERMANENT aura WITHOUT AN ICON, applied to every druid
    // who knows the spell: it ticks every few seconds and does nothing until he
    // is a moonkin. That is what saves having to watch for form changes, which
    // have no convenient hook.
    class spell_spheregrid_stars : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_stars);

        void Sow(AuraEffect const* /*effect*/)
        {
            PreventDefaultAction();
            Player* player = GetTarget() ? GetTarget()->ToPlayer() : nullptr;
            if (!player)
                return;

            // OUT OF THE MOONKIN FORM, no more stars. It is the aura of the
            // form itself that takes them back the instant it falls; this tick
            // is only a safety net, for a path that might escape us.
            if (player->GetShapeshiftForm() != FORM_MOONKIN)
            {
                auto it = g_stars.find(player->GetGUID());
                if (it != g_stars.end() && !it->second.empty())
                    ClearTrail(player);
                return;
            }
            if (!player->IsAlive())
                return;

            auto& trail = g_stars[player->GetGUID()];

            // THE MINIMUM DISTANCE RULE: too close to the last one and no star
            // appears — and it will appear as soon as he has moved away, since
            // we try again at every tick.
            while (!trail.empty() && !StarOf(player, trail.back()))
                trail.pop_back();
            if (!trail.empty())
                if (Creature* latest = StarOf(player, trail.back()))
                    if (player->GetExactDist(latest) < CHARGE_STAR_SPACING)
                        return;

            Creature* star = player->SummonCreature(CHARGE_STAR_CREATURE,
                *player, TEMPSUMMON_MANUAL_DESPAWN);
            if (!star)
                return;
            trail.push_back(star->GetGUID());

            // THE FOURTH one drives the oldest away.
            while (trail.size() > CHARGE_STARS_MAX)
                FoldStar(player, trail, false);

            // The moonlight glow is applied by the repaint, as a STATE kit: it
            // holds as long as the aura holds, and the aura is permanent.
            TrailChanged(player, trail);
        }

        void Register() override
        {
            OnEffectPeriodic += AuraEffectPeriodicFn(spell_spheregrid_stars::Sow,
                                                     EFFECT_0,
                                                     SPELL_AURA_PERIODIC_DUMMY);
        }
    };

    // LEAVING THE FORM ERASES THE TRAIL, that very instant. The tick of the
    // trail aura was not enough: it only comes round every few seconds, and the
    // tooltip promises that the stars go AS SOON AS the druid stops being a
    // moonkin. So we hook onto the aura of the form itself — the native spell
    // whose first effect carries SPELL_AURA_MOD_SHAPESHIFT towards that form. The
    // binding lives in the module SQL, the generator naming only our own
    // spells.
    class spell_spheregrid_moonkin_form : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_moonkin_form);

        void Leave(AuraEffect const* /*effect*/,
                     AuraEffectHandleModes /*mode*/)
        {
            if (Player* player = GetTarget() ? GetTarget()->ToPlayer()
                                             : nullptr)
                ClearTrail(player);
        }

        void Register() override
        {
            AfterEffectRemove += AuraEffectRemoveFn(
                spell_spheregrid_moonkin_form::Leave, EFFECT_0,
                SPELL_AURA_MOD_SHAPESHIFT, AURA_EFFECT_HANDLE_REAL);
        }
    };

    // =======================================================================
    // Feral frenzy — five tiers according to the combo points
    // =======================================================================
    // The DBC cannot hook onto combo points: the spell carries its damage effect
    // only, and the whole tiering lives here. The points are CONSUMED, as for any
    // finishing move.
    constexpr uint32 FRENZY_WOUND = 8610026;
    constexpr uint32 FRENZY_HASTE = 8610027;
    constexpr uint32 FRENZY_CRIT = 8610028;

    struct FrenzyTier
    {
        int32 blow, bleed, haste;
        uint32 energy;
        bool crit;
    };
    constexpr FrenzyTier FRENZY_TIERS[5] =
    {
        {  700,   0,  0,  0, false },
        {  800, 120,  0,  0, false },
        { 1000, 160,  5,  0, false },
        { 1100, 200,  7, 10, false },
        { 1200, 240, 10, 15, true  },
    };

    class spell_spheregrid_frenzy : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_frenzy);

        uint8 _points = 0;

        SpellCastResult CheckCast()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player || !player->GetComboPoints())
                return SPELL_FAILED_NO_COMBO_POINTS;
            return SPELL_CAST_OK;
        }

        // The points are READ before the cast and only taken at the end:
        // emptying them at once would rob the effect of its tier.
        void Count()
        {
            if (Player* player = GetCaster() ? GetCaster()->ToPlayer()
                                             : nullptr)
                _points = std::min<uint8>(player->GetComboPoints(), 5);
        }

        void Strike(SpellEffIndex /*index*/)
        {
            if (!_points)
                return;
            FrenzyTier const& palier = FRENZY_TIERS[_points - 1];
            SetHitDamage(palier.blow);

            Unit* caster = GetCaster();
            Unit* target = GetHitUnit();
            if (caster && target && palier.bleed)
            {
                int32 bleed = palier.bleed;
                caster->CastCustomSpell(target, FRENZY_WOUND, &bleed,
                                         nullptr, nullptr, true);
            }
        }

        void Reward()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player || !_points)
                return;
            FrenzyTier const& palier = FRENZY_TIERS[_points - 1];
            if (palier.haste)
            {
                int32 haste = palier.haste;
                player->CastCustomSpell(player, FRENZY_HASTE, &haste,
                                        nullptr, nullptr, true);
            }
            if (palier.energy)
                player->EnergizeBySpell(player, GetSpellInfo()->Id,
                                        palier.energy, POWER_ENERGY);
            if (palier.crit)
                player->CastSpell(player, FRENZY_CRIT, true);
            player->ClearComboPoints();
        }

        void Register() override
        {
            OnCheckCast += SpellCheckCastFn(spell_spheregrid_frenzy::CheckCast);
            BeforeCast += SpellCastFn(spell_spheregrid_frenzy::Count);
            OnEffectHitTarget += SpellEffectFn(spell_spheregrid_frenzy::Strike,
                                               EFFECT_0,
                                               SPELL_EFFECT_SCHOOL_DAMAGE);
            AfterCast += SpellCastFn(spell_spheregrid_frenzy::Reward);
        }
    };

    // =======================================================================
    // Solstice and equinox — the celestial gauge
    // =======================================================================
    // A gauge of SEVEN NOTCHES, from the moon (-3) to the sun (+3), the centre at
    // zero: SIX casts from one limit to the other, one notch per spell.
    //
    //   * an arcane damage spell pushes ONE notch towards the MOON; a nature one,
    //     ONE notch towards the SUN;
    //   * reaching either end grants a few seconds of buff — and it is the school
    //     OPPOSITE to the one that pushed which is rewarded, forcing the back and
    //     forth;
    //   * AN END REACHED LOCKS ITS SIDE: until the other one is touched, the
    //     spells that would push towards it do nothing at all — no movement, no
    //     stack gained or lost;
    //   * EVERY LIMIT REACHED opens a short window to cast the spell.
    //
    // The gauge lives in TWO auras — lunar and solar, one of three stacks each.
    // At the centre, the player carries neither.
    //
    // THEY MUST STAY VISIBLE. Marked SPELL_ATTR1_NO_AURA_ICON to unclutter the
    // buff bar, they stopped being returned by UnitBuff on the client side and
    // the cursor froze at the centre. The hiding was reverted.
    constexpr uint32 SOLSTICE = 8600092;
    constexpr uint32 SOLSTICE_SUN = 8610029;    // the sun's end
    constexpr uint32 SOLSTICE_MOON = 8610030;      // the moon's end
    constexpr uint32 SOLSTICE_WINDOW = 8610031;   // five seconds to act
    constexpr uint32 SOLSTICE_USE_SUN = 8610034; // the sun is spent
    constexpr uint32 SOLSTICE_USE_MOON = 8610035;   // the moon is spent
    constexpr uint32 SOLSTICE_GAUGE_MOON = 8610032;   // 1 to 6 towards the moon
    constexpr uint32 SOLSTICE_GAUGE_SUN = 8610033; // 1 to 6 towards the sun
    constexpr int8 SOLSTICE_END = 3;              // notches on either half
    constexpr int8 SOLSTICE_STEP = 1;              // one notch per spell

    struct CelestialGauge
    {
        int8 cursor = 0;    // -3 lune ... 0 centre ... +3 soleil
        int8 last = 0;    // the last end reached: -1, 0 or +1
    };
    std::unordered_map<ObjectGuid, CelestialGauge> g_gauges;

    class spheregrid_solstice_player : public PlayerScript
    {
    public:
        spheregrid_solstice_player() : PlayerScript("spheregrid_solstice_player",
            {
                PLAYERHOOK_ON_SPELL_CAST,
                PLAYERHOOK_ON_PLAYER_JUST_DIED,
                PLAYERHOOK_ON_LOGIN,
                PLAYERHOOK_ON_LOGOUT
            }) { }

        void OnPlayerLogin(Player* player) override { Apply(player); }

        // THE GAUGE SURVIVES NEITHER DEATH NOR LOGOUT, goal it crosses the end
        // of a fight without flinching.
        void OnPlayerJustDied(Player* player) override { Empty(player); }
        void OnPlayerLogout(Player* player) override { Empty(player); }

        void OnPlayerSpellCast(Player* player, Spell* spell,
                               bool /*skipCheck*/) override
        {
            if (!player || !spell || !Concerns(player))
                return;
            SpellInfo const* info = spell->GetSpellInfo();
            if (!info || info->Id == SOLSTICE)
            {
                // THE SPELL ITSELF DOES NOT PUSH the cursor, goal it consumes
                // its window: the DBC can demand it, not take it back.
                if (info && info->Id == SOLSTICE)
                    player->RemoveAurasDueToSpell(SOLSTICE_WINDOW);
                return;
            }
            if (info->DmgClass != SPELL_DAMAGE_CLASS_MAGIC || !DealsDamage(info))
                return;

            // The school decides the direction. A spell with two schools (a
            // rare thing) counts for the first one; none is counted twice.
            if (info->SchoolMask & SPELL_SCHOOL_MASK_ARCANE)
                Move(player, -SOLSTICE_STEP);          // towards the moon
            else if (info->SchoolMask & SPELL_SCHOOL_MASK_NATURE)
                Move(player, SOLSTICE_STEP);           // towards the sun
        }

    private:
        // The gauge only exists for a moonkin who knows the spell: it is the
        // balance form, and the spell is only cast there.
        static bool Concerns(Player* player)
        {
            return player->getClass() == CLASS_DRUID
                && player->HasSpell(SOLSTICE)
                && player->GetShapeshiftForm() == FORM_MOONKIN;
        }

        static bool DealsDamage(SpellInfo const* info)
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

        static void Apply(Player* player)
        {
            if (!player || player->getClass() != CLASS_DRUID)
                return;
            // THE GAUGE STARTS AGAIN FROM ZERO AT LOGIN, AURAS INCLUDED. The
            // core SAVES the auras before calling the logout hook that removes
            // them (WorldSession::LogoutPlayer: SaveToDB then OnPlayerLogout): a
            // star spent before logging out came back with its arrow, while the
            // gauge in memory started again from the centre. spell_custom_attr
            // now marks them as never saved; this sweeps up what was saved
            // before.
            player->RemoveAurasDueToSpell(SOLSTICE_SUN);
            player->RemoveAurasDueToSpell(SOLSTICE_MOON);
            player->RemoveAurasDueToSpell(SOLSTICE_WINDOW);
            player->RemoveAurasDueToSpell(SOLSTICE_USE_SUN);
            player->RemoveAurasDueToSpell(SOLSTICE_USE_MOON);
            if (player->HasSpell(SOLSTICE))
                Write(player, g_gauges[player->GetGUID()].cursor);
        }

        static void Empty(Player* player)
        {
            g_gauges.erase(player->GetGUID());
            player->RemoveAurasDueToSpell(SOLSTICE_GAUGE_MOON);
            player->RemoveAurasDueToSpell(SOLSTICE_GAUGE_SUN);
            player->RemoveAurasDueToSpell(SOLSTICE_WINDOW);
            player->RemoveAurasDueToSpell(SOLSTICE_USE_SUN);
            player->RemoveAurasDueToSpell(SOLSTICE_USE_MOON);
        }

        // THE STACK CARRIES THE NOTCH, from one to six, in whichever of the two
        // auras matches the side the cursor is on. At the centre, neither. That
        // is how the client bar learns where the player stands.
        static void Write(Player* player, int8 cursor)
        {
            uint8 const crans = uint8(cursor < 0 ? -cursor : cursor);
            uint32 const wanted = cursor < 0 ? SOLSTICE_GAUGE_MOON
                                              : SOLSTICE_GAUGE_SUN;
            if (!crans || wanted != SOLSTICE_GAUGE_MOON)
                player->RemoveAurasDueToSpell(SOLSTICE_GAUGE_MOON);
            if (!crans || wanted != SOLSTICE_GAUGE_SUN)
                player->RemoveAurasDueToSpell(SOLSTICE_GAUGE_SUN);
            if (!crans)
                return;
            if (!player->HasAura(wanted))
                player->CastSpell(player, wanted, true);
            if (Aura* aura = player->GetAura(wanted))
                aura->SetStackAmount(crans);
        }

        // THE LOCK, TOLD TO THE CLIENT: the spent star carries its aura until
        // the other one is reached. That is what the bar reads to dim the right
        // side — it could not work it out on its own.
        static void Lock(Player* player, int8 side)
        {
            player->RemoveAurasDueToSpell(side > 0 ? SOLSTICE_USE_MOON
                                                   : SOLSTICE_USE_SUN);
            uint32 const aura = side > 0 ? SOLSTICE_USE_SUN
                                         : SOLSTICE_USE_MOON;
            if (!player->HasAura(aura))
                player->CastSpell(player, aura, true);
        }

        // THE WINDOW: a few seconds to cast the spell, opened at EVERY limit
        // reached. It does not stack — applying it again simply restarts it.
        static void Open(Player* player)
        {
            player->RemoveAurasDueToSpell(SOLSTICE_WINDOW);
            player->CastSpell(player, SOLSTICE_WINDOW, true);
        }

        static void Move(Player* player, int8 step)
        {
            CelestialGauge& gauge = g_gauges[player->GetGUID()];

            // THE DIRECTION LOCK: an end reached closes its side. One can only
            // go back towards the other, and a spell that would push backwards
            // has no effect at all on the gauge.
            if ((gauge.last > 0 && step > 0)
                || (gauge.last < 0 && step < 0))
                return;

            int8 const before = gauge.cursor;
            int8 after = int8(gauge.cursor + step);
            if (after > SOLSTICE_END)
                after = SOLSTICE_END;
            else if (after < -SOLSTICE_END)
                after = -SOLSTICE_END;
            if (after == before)
                return;                     // already at the end, nothing moves
            gauge.cursor = after;

            // The lock above guarantees that one cannot come back to an end
            // without having touched the other: arriving here is therefore
            // always a FIRST time.
            if (after == SOLSTICE_END)
            {
                player->CastSpell(player, SOLSTICE_SUN, true);
                gauge.last = 1;
                Lock(player, 1);
                Open(player);
            }
            else if (after == -SOLSTICE_END)
            {
                player->CastSpell(player, SOLSTICE_MOON, true);
                gauge.last = -1;
                Lock(player, -1);
                Open(player);
            }
            Write(player, after);
        }
    };

    // =======================================================================
    // Bloom — every heal in progress lasts longer
    // =======================================================================
    // THE HEALING AREA, laid at the feet of the target.
    constexpr uint32 BLOOM_ZONE = 8610036;

    class spell_spheregrid_bloom : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_bloom);

        void BloomAgain(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            Unit* target = GetHitUnit();
            if (!caster || !target)
                return;

            // MADE NEW AGAIN, no longer extended: every heal over time starts
            // again at its maximum. WITH NO CASTER FILTER — heals that come from
            // a weapon were left out by the old guard.
            for (auto const& paire : target->GetAppliedAuras())
            {
                Aura* aura = paire.second->GetBase();
                if (!aura || !aura->GetSpellInfo())
                    continue;
                if (!aura->GetSpellInfo()->HasAura(SPELL_AURA_PERIODIC_HEAL))
                    continue;
                if (aura->GetMaxDuration() <= 0)
                    continue;               // a permanent aura has nothing
                                            // to take back
                aura->SetDuration(aura->GetMaxDuration(), true);
            }

            // THE BLOOM opens where the target stands. Coordinates are used
            // rather than the target: the dynamic object stays on the ground, it
            // does not follow whoever was healed.
            caster->CastSpell(target->GetPositionX(), target->GetPositionY(),
                               target->GetPositionZ(), BLOOM_ZONE, true);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(
                spell_spheregrid_bloom::BloomAgain, EFFECT_0,
                SPELL_EFFECT_DUMMY);
        }
    };

    // =======================================================================
    // Word of shadow: despair — both curses at once, all around
    // =======================================================================
    // No direct damage: the spell APPLIES the two shadow damage-over-time spells
    // to every enemy within the radius, AT THE BEST RANK THE PRIEST KNOWS — his
    // spell book is read rather than the ranks hardcoded, so that a priest of
    // level 40 applies the ones of his level. The two spells are recognised by
    // their family and their mask.
    constexpr uint32 SWP_MASK = 0x8000;        // firstRank word
    constexpr uint32 HIT_MASK = 0x400;     // deuxieme word

    uint32 DespairBestRank(Player* priest, uint8 word, uint32 mask)
    {
        uint32 best = 0;
        uint32 bestLevel = 0;
        for (auto const& paire : priest->GetSpellMap())
        {
            if (paire.second->State == PLAYERSPELL_REMOVED
                || !paire.second->Active)
                continue;
            SpellInfo const* info = sSpellMgr->GetSpellInfo(paire.first);
            if (!info || info->SpellFamilyName != SPELLFAMILY_PRIEST)
                continue;
            if (!(info->SpellFamilyFlags[word] & mask))
                continue;
            uint32 level = info->SpellLevel ? info->SpellLevel
                                             : info->BaseLevel;
            if (!best || level > bestLevel)
            {
                best = info->Id;
                bestLevel = level;
            }
        }
        return best;
    }

    class spell_spheregrid_despair : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_despair);

        void Afflict(SpellEffIndex /*index*/)
        {
            Player* priest = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            Unit* victim = GetHitUnit();
            if (!priest || !victim)
                return;
            if (!_seeking)
            {
                _seeking = true;
                _pain = DespairBestRank(priest, 0, SWP_MASK);
                _hit = DespairBestRank(priest, 1, HIT_MASK);
            }
            if (_pain)
                priest->CastSpell(victim, _pain, true);
            if (_hit)
                priest->CastSpell(victim, _hit, true);
        }

        void Register() override
        {
            // EFFECT_1: effect 0 now carries the area damage, the dummy that
            // triggers the curses moved to second place.
            OnEffectHitTarget += SpellEffectFn(
                spell_spheregrid_despair::Afflict, EFFECT_1,
                SPELL_EFFECT_DUMMY);
        }

        bool _seeking = false;
        uint32 _pain = 0;
        uint32 _hit = 0;
    };

    // =======================================================================
    // Power word: barrier — a shared pool under a dome
    // =======================================================================
    // A pool of absorption SHARED by every ally present: the dome holds the
    // reserve, each protected ally carries an aura whose absorption draws from
    // it. The common pot is the principle of the anti-magic shield, extended here
    // to all damage and to the whole group. The dome CASTS the protection itself:
    // the AuraScript thus finds the reserve through its caster.
    constexpr uint32 BARRIER_CREATURE = 803813;
    constexpr uint32 BARRIER_PROTECTION = 8600059;
    constexpr uint32 BARRIER_KIT_SOUND = 30045;
    // THE DOME TIGHTENS: from its full radius down to half, reached at the
    // removal mark and held for the last seconds; the model follows, through the
    // object scale. No reserve is absorbed any more: those sheltered simply take
    // less physical damage (a DBC aura).
    constexpr float BARRIER_RADIUS = 8.0f;       // 15 -> 9 -> 8 m
    constexpr float BARRIER_RADIUS_END = 4.0f;   // half of it, as before
    constexpr uint32 BARRIER_REMOVAL = 7000;    // ms -- 3 s before the end
    // NATIVE SCALE: the dome is taken as it is, with no rescaling. The bounding
    // box of its vertices gives a larger radius, goal it includes what juts out of
    // the visible dome — its useful cupola really does match the area.
    constexpr float BARRIER_SCALE = 1.0f;
    constexpr uint32 BARRIER_LIFE = 10000;       // ms -- a mirror of the DBC
    constexpr uint32 BARRIER_TICK = 33;          // ms -- thirty times a second
                                                 // entries, exits AND the
                                                 // tightening. The REAL cadence
                                                 // stays bounded by the step of
                                                 // the world loop, which calls
                                                 // UpdateAI.
    constexpr uint32 BARRIER_MARGIN = 150;       // ms before the sound: the
                                                 // client does not have the
                                                 // dome yet
    // THE SOUND IS A TWO-SECOND SLICE (a truncated file, faded at the end),
    // replayed by the AI as long as the dome lives: played in one block, it ran
    // well past the disappearance. The cut therefore follows the dome to within
    // two seconds.
    constexpr uint32 BARRIER_SOUND_DURATION = 2000;
    constexpr uint32 BARRIER_EMOTE_BIRTH = 990003;   // Emotes.dbc custom
    constexpr uint32 BARRIER_EMOTE_DECAY = 990001;   // (anim 159, partagee)
    constexpr uint32 BARRIER_DECAY_MS = 1000;   // the dome's Decay sequence

    // The dome hum, as a free function: AddEventAtOffset wants an RVALUE
    // lambda, a named lambda reused does not compile.
    void BarrierHum(ObjectGuid guidDome, ObjectGuid guidPriest)
    {
        Player* priest = ObjectAccessor::FindPlayer(guidPriest);
        if (!priest)
            return;
        if (Creature* dome = ObjectAccessor::GetCreature(*priest, guidDome))
            dome->SendPlaySpellVisual(BARRIER_KIT_SOUND);
    }

    struct npc_spheregrid_barrier : public ScriptedAI
    {
        npc_spheregrid_barrier(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void IsSummonedBy(WorldObject* summoner) override
        {
            if (summoner)
                _priest = summoner->GetGUID();

            me->SetObjectScale(BARRIER_SCALE);   // it covers the 15 m
            // The hum, once the dome is known to the client (the dash trap: a
            // kit sent at the tick of the summon is thrown away), then RESTARTED
            // before the file runs out.
            ObjectGuid guidDome = me->GetGUID();
            ObjectGuid guidPriest = _priest;
            me->m_Events.AddEventAtOffset([guidDome, guidPriest]()
            {
                BarrierHum(guidDome, guidPriest);
            }, Milliseconds(BARRIER_MARGIN));
            _hum = BARRIER_MARGIN + BARRIER_SOUND_DURATION;
        }

        void UpdateAI(uint32 diff) override
        {
            // The hum, slice by slice: it stops with the dome.
            _age += diff;
            if (_hum && _age >= _hum)
            {
                _hum = _age + BARRIER_SOUND_DURATION;
                me->SendPlaySpellVisual(BARRIER_KIT_SOUND);
            }

            _watch += diff;
            if (_watch < BARRIER_TICK)
                return;
            _watch = 0;
            Unit* priest = ObjectAccessor::GetUnit(*me, _priest);

            // THE END: the dome fades, those sheltered lose the marker. There
            // is no disappearance hook in CreatureAI — without this clean-up, the
            // PERMANENT aura stayed for life.
            if (_age + BARRIER_TICK >= BARRIER_LIFE)
            {
                for (ObjectGuid guid : _proteges)
                    if (Player* parti = ObjectAccessor::FindPlayer(guid))
                        parti->RemoveAura(BARRIER_PROTECTION, me->GetGUID());
                _proteges.clear();
                return;
            }
            if (!priest)
                return;

            // The tightening: linear down to the removal mark, then held at
            // half. The model follows the shelter TO THE METRE.
            float progress = _age >= BARRIER_REMOVAL
                ? 1.0f : float(_age) / float(BARRIER_REMOVAL);
            float radius = BARRIER_RADIUS
                + (BARRIER_RADIUS_END - BARRIER_RADIUS) * progress;
            float scale = BARRIER_SCALE * radius / BARRIER_RADIUS;
            // A fine threshold: at thirty steps a second over seven seconds,
            // each step is worth about 0.002 of scale — a wider threshold would
            // rub out every other step.
            if (std::fabs(me->GetObjectScale() - scale) > 0.001f)
                me->SetObjectScale(scale);

            // The allies UNDER the dome receive the protection; those who step
            // out lose it (the aura carries the same duration as the dome, so it
            // is removed by hand).
            std::list<Player*> nearby;
            Acore::AnyPlayerInObjectRangeCheck verif(me, radius);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                chercheur(me, nearby, verif);
            Cell::VisitObjects(me, chercheur, radius);

            GuidSet dedans;
            for (Player* ally : nearby)
            {
                if (!ally->IsAlive() || !priest->IsFriendlyTo(ally))
                    continue;
                dedans.insert(ally->GetGUID());
                if (!ally->HasAura(BARRIER_PROTECTION, me->GetGUID()))
                    me->CastSpell(ally, BARRIER_PROTECTION, true);
            }
            for (ObjectGuid guid : _proteges)
                if (!dedans.count(guid))
                    if (Player* parti = ObjectAccessor::FindPlayer(guid))
                        parti->RemoveAura(BARRIER_PROTECTION, me->GetGUID());
            _proteges = dedans;
        }

    private:
        ObjectGuid _priest;
        GuidSet _proteges;
        uint32 _watch = 0;
        uint32 _age = 0;
        uint32 _hum = 0;     // the next slice of sound (0 = none)
    };

    class spell_spheregrid_barrier_zone : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_barrier_zone);

        void SetUp(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            WorldLocation const* goal = GetExplTargetDest();
            if (!caster || !goal)
                return;
            Position where(goal->GetPositionX(), goal->GetPositionY(),
                        goal->GetPositionZ(), caster->GetOrientation());
            caster->SummonCreature(BARRIER_CREATURE, where,
                                    TEMPSUMMON_TIMED_DESPAWN, BARRIER_LIFE);
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_barrier_zone::SetUp,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
        }
    };



    // =======================================================================
    // Angelic feather — laid on the ground, picked up in passing
    // =======================================================================
    constexpr uint32 FEATHER_CREATURE = 803812;    // display 802108
    constexpr uint32 FEATHER_BUFF = 8600097;   // the speed it gives, and for how long,
                                               // are the buff's own: see its row
    constexpr uint32 FEATHER_LIFE = 6000;           // ms au sol
    constexpr float FEATHER_RADIUS = 2.0f;          // the step that picks it up
    constexpr uint32 FEATHER_TICK = 200;            // ms -- the watch's pace
    constexpr uint32 FEATHER_SPELL = 8600040;
    constexpr uint32 FEATHER_RESERVE = 8600099;    // the aura that holds the charges
    constexpr uint8 FEATHER_CHARGES = 3;
    constexpr uint32 FEATHER_COOLDOWN = 20000;     // ms -- per charge

    // CHARGES THE MODERN WAY: every feather laid down schedules ITS OWN return
    // later, instead of a grouped cooldown. The reserve aura counts the
    // feathers LEFT, and it is ALWAYS ON THE PRIEST -- three when none is
    // missing, zero when none is left. It used to be removed at both ends,
    // which took the count away exactly when it was worth reading.
    //
    // AN AURA AT ZERO STACKS IS LEGAL. Aura::SetStackAmount writes the number
    // down and tells the client; only ModStackAmount removes at zero, and it
    // is not used here.
    // THE AURA IS PLACED, NOT CAST. Unit::AddAura builds it and hands it
    // back; casting it meant reading it again afterwards, and a reading that
    // came back empty left the count at the one a fresh aura carries -- which
    // is what the database showed, stackCount = 1 where three were meant.
    void SetFeatherReserve(Player* player, uint8 left)
    {
        if (!player)
            return;
        Aura* reserve = player->GetAura(FEATHER_RESERVE);
        if (!reserve)
            reserve = player->AddAura(FEATHER_RESERVE, player);
        if (reserve)
            reserve->SetStackAmount(left);
    }

    void ReturnFeatherCharge(ObjectGuid playerGuid)
    {
        Player* player = ObjectAccessor::FindPlayer(playerGuid);
        if (!player)
            return;
        Aura const* reserve = player->GetAura(FEATHER_RESERVE);
        uint8 const left = reserve ? reserve->GetStackAmount() : 0;
        SetFeatherReserve(player, left + 1 >= FEATHER_CHARGES
                                  ? FEATHER_CHARGES : uint8(left + 1));
        // A feather is back: the spell is available whatever the cooldown said.
        player->RemoveSpellCooldown(FEATHER_SPELL, true);
    }

    class spell_spheregrid_feather : public SpellScript
    {
        PrepareSpellScript(spell_spheregrid_feather);

        void Apply(SpellEffIndex /*index*/)
        {
            Unit* caster = GetCaster();
            WorldLocation const* goal = GetExplTargetDest();
            if (!caster || !goal)
                return;
            // INSTANTLY at the target point, and for a few seconds.
            Position where(goal->GetPositionX(), goal->GetPositionY(),
                        goal->GetPositionZ(), caster->GetOrientation());
            caster->SummonCreature(FEATHER_CREATURE, where,
                                    TEMPSUMMON_TIMED_DESPAWN, FEATHER_LIFE);
        }

        // A feather consumed: the reserve goes down by one and THAT feather
        // schedules its return. As long as some are left, the cooldown the core
        // has just applied (before the effects) is cancelled.
        void Charges()
        {
            Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
            if (!player)
                return;

            Aura const* reserve = player->GetAura(FEATHER_RESERVE);
            // No aura at all means a full reserve: a priest who has never cast
            // it since the module was installed.
            uint8 const before = reserve ? reserve->GetStackAmount()
                                         : FEATHER_CHARGES;
            uint8 const left = before ? uint8(before - 1) : uint8(0);
            SetFeatherReserve(player, left);

            if (left)
                player->RemoveSpellCooldown(FEATHER_SPELL, true);

            // The return of THAT feather, later on.
            ObjectGuid guid = player->GetGUID();
            player->m_Events.AddEventAtOffset([guid]()
            {
                ReturnFeatherCharge(guid);
            }, Milliseconds(FEATHER_COOLDOWN));
        }

        void Register() override
        {
            OnEffectHit += SpellEffectFn(spell_spheregrid_feather::Apply,
                                         EFFECT_0, SPELL_EFFECT_DUMMY);
            AfterCast += SpellCastFn(spell_spheregrid_feather::Charges);
        }
    };

    struct npc_spheregrid_feather : public ScriptedAI
    {
        npc_spheregrid_feather(Creature* creature) : ScriptedAI(creature)
        {
            me->SetReactState(REACT_PASSIVE);
        }

        void UpdateAI(uint32 diff) override
        {
            if (_picked)
                return;
            _watch += diff;
            if (_watch < FEATHER_TICK)
                return;
            _watch = 0;
            Unit* priest = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!priest)
                return;
            // The first ALLY to set foot on it takes it.
            std::list<Player*> passants;
            Acore::AnyPlayerInObjectRangeCheck verif(me, FEATHER_RADIUS);
            Acore::PlayerListSearcher<Acore::AnyPlayerInObjectRangeCheck>
                chercheur(me, passants, verif);
            Cell::VisitObjects(me, chercheur, FEATHER_RADIUS);
            for (Player* passant : passants)
            {
                if (!passant->IsAlive() || !priest->IsFriendlyTo(passant))
                    continue;
                priest->CastSpell(passant, FEATHER_BUFF, true);
                _picked = true;
                me->DespawnOrUnsummon();
                return;
            }
        }

    private:
        bool _picked = false;
        uint32 _watch = 0;
    };

    // =======================================================================
    // Pack beast — the AI modelled on the native SNAKE TRAP
    // =======================================================================
    // The pattern: npc_pet_hunter_snake_trap (scripts/Pet/pet_hunter.cpp). What
    // it brings and our previous attempts lacked:
    //   - TARGETING through the master's combats (GetCombatManager), not through
    //     his current victim alone — empty outside combat;
    //   - EngageWithTarget + FixateTarget, which really do latch on;
    //   - UpdateVictim() + DoMeleeAttackIfReady() at every tick: WITHOUT THAT
    //     CALL A CREATURE NEVER STRIKES, whatever it is told to do;
    //   - the passive poison applied to ITSELF on appearing — exactly our
    //     frenzy.
    // Added to it: the display and the figures of the pet, and the RETURN TO THE
    // HUNTER when there is nothing left to bite.
    // THE RESERVE IS SHOWN FROM THE START. A priest who knows the feather and
    // has never cast it holds three of them: without this the aura appeared
    // only after the first cast, and "three" was never seen.
    class spheregrid_feather_player : public PlayerScript
    {
    public:
        spheregrid_feather_player() : PlayerScript("spheregrid_feather_player",
            {
                PLAYERHOOK_ON_LOGIN,
                PLAYERHOOK_ON_LEARN_SPELL
            }) { }

        // A LOGIN FILLS THE RESERVE, whatever the database gave back. A
        // feather returns through an event posted on the player, and those do
        // not outlive a session: a priest who logged out with none would be
        // left with none for ever, and his count would not even show. Full is
        // the only state that is both true and reachable -- and the count is
        // written again in every case, because an aura restored from the
        // database comes back with the stack it was saved with.
        void OnPlayerLogin(Player* player) override
        {
            if (player && player->HasSpell(FEATHER_SPELL))
                SetFeatherReserve(player, FEATHER_CHARGES);
        }

        // THE WRITE WAITS ONE TURN. The hook fires from INSIDE
        // Player::addSpell, while the spell book is still being changed, and
        // an aura placed at that moment did not survive the rest of the
        // learning: the priest saw no reserve until his next login. Posted on
        // the player, the same way a spent feather posts its return, it lands
        // on the next world update -- learning over, spell in the book, client
        // told.
        void OnPlayerLearnSpell(Player* player, uint32 id) override
        {
            if (!player || id != FEATHER_SPELL)
                return;
            ObjectGuid const guid = player->GetGUID();
            player->m_Events.AddEventAtOffset([guid]()
            {
                Player* who = ObjectAccessor::FindPlayer(guid);
                if (who && who->HasSpell(FEATHER_SPELL))
                    SetFeatherReserve(who, FEATHER_CHARGES);
            }, Milliseconds(1));
        }
    };

    class spheregrid_starfall_player : public PlayerScript
    {
    public:
        spheregrid_starfall_player() : PlayerScript("spheregrid_starfall_player",
            {
                PLAYERHOOK_ON_LOGIN,
                PLAYERHOOK_ON_LOGOUT,
                PLAYERHOOK_ON_LEARN_SPELL,
                PLAYERHOOK_ON_FORGOT_SPELL
            }) { }

        void OnPlayerLogin(Player* player) override { Apply(player); }

        void OnPlayerLearnSpell(Player* player, uint32 /*id*/) override
        {
            Apply(player);
        }

        // FORGETTING COUNTS AS MUCH AS LEARNING. Without this hook, removing
        // the grid cell left the FIVE form spells in the spell book until the
        // next login — a druid who had given the cell back kept them, for free.
        //
        // THE FILTER ON THE ID IS NOT A COMFORT: `Apply` removes spells itself,
        // and `Player::removeSpell` calls this hook at the end. Reacting to any
        // forgetting would take us five times into our own call. Only the grid
        // spell changes anything anyway — and it is the only one `Apply` asks
        // about.
        void OnPlayerForgotSpell(Player* player, uint32 id) override
        {
            if (id == CHARGE_WILD)
                Apply(player);
        }

        void OnPlayerLogout(Player* player) override
        {
            // The trail does not survive a logout, and neither do the
            // creatures: no orphan stars are left on the map.
            ClearTrail(player);
        }

    private:
        static void Apply(Player* player)
        {
            if (!player || player->getClass() != CLASS_DRUID)
                return;
            bool const connait = player->HasSpell(CHARGE_WILD);

            // THE FIVE FORM SPELLS follow the grid one: learned with it, taken
            // back with it. The grid only records what it granted itself, so it
            // will not touch them.
            for (uint32 spell : CHARGE_FORMS)
            {
                if (connait && !player->HasSpell(spell))
                    player->learnSpell(spell);
                else if (!connait && player->HasSpell(spell))
                    player->removeSpell(spell, SPEC_MASK_ALL, false);
            }

            if (connait && !player->HasAura(CHARGE_TRAIL))
                player->CastSpell(player, CHARGE_TRAIL, true);
            else if (!connait)
            {
                player->RemoveAurasDueToSpell(CHARGE_TRAIL);
                // AND THE STARS ALREADY LAID DOWN with them. Removing the aura
                // alone stopped the sowing without gathering the harvest: the
                // creatures stayed on the map until logout, while the druid no
                // longer had the spell to go back to them.
                ClearTrail(player);
            }
        }
    };

    struct npc_spheregrid_pack : public ScriptedAI
    {
        npc_spheregrid_pack(Creature* creature) : ScriptedAI(creature) { }

        void JustEngagedWith(Unit* /*who*/) override { }
        void MoveInLineOfSight(Unit* /*who*/) override { }

        void InitializeAI() override
        {
            ScriptedAI::InitializeAI();
            Unit* master = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;
            if (!master)
                return;
            me->SetFaction(master->GetFaction());
            me->SetLevel(master->GetLevel());
            // THE OWNER: without it, the client does not recognise the beast as
            // the player's and does NOT show its damage in floating text. That is
            // what the trap snakes have natively (their script asks
            // me->GetOwner()).
            me->SetOwnerGUID(master->GetGUID());
            me->SetCreatorGUID(master->GetGUID());
            // The display and the figures of the hunter's pet.
            if (Player* player = master->ToPlayer())
                if (Pet* familier = player->GetPet())
                {
                    me->SetDisplayId(familier->GetDisplayId());
                    me->SetMaxHealth(familier->GetMaxHealth());
                    me->SetHealth(familier->GetMaxHealth());
                    // Damage cut to a fraction: three beasts at the pet's full
                    // output flattened everything.
                    for (WeaponDamageRange borne : {MINDAMAGE, MAXDAMAGE})
                        me->SetBaseWeaponDamage(BASE_ATTACK, borne,
                            familier->GetWeaponDamageRange(BASE_ATTACK, borne)
                            / RUSH_DIVISOR);
                    me->UpdateDamagePhysical(BASE_ATTACK);
                }
            // The blows will apply the stacking bleed.
            DoCast(me, RUSH_FRENZY, true);
            me->SetReactState(REACT_AGGRESSIVE);
        }

        void UpdateAI(uint32 diff) override
        {
            Unit* master = me->ToTempSummon()
                ? me->ToTempSummon()->GetSummonerUnit() : nullptr;

            // The snake trap targeting: everything the master is in combat
            // with, one prey fixated at random.
            if (master && !me->GetThreatMgr().GetFixateTarget())
            {
                std::vector<Unit*> preys;
                auto keep = [this, &preys, master](CombatReference* ref)
                {
                    Unit* enemy = ref->GetOther(master);
                    if (enemy && me->CanCreatureAttack(enemy))
                        preys.push_back(enemy);
                };
                for (auto const& [guid, ref] :
                     master->GetCombatManager().GetPvPCombatRefs())
                    keep(ref);
                if (preys.empty())
                    for (auto const& [guid, ref] :
                         master->GetCombatManager().GetPvECombatRefs())
                        keep(ref);
                for (Unit* prey : preys)
                    me->EngageWithTarget(prey);
                if (!preys.empty())
                    me->GetThreatMgr().FixateTarget(
                        Acore::Containers::SelectRandomContainerElement(preys));
            }

            if (!UpdateVictim())
            {
                // Nothing left to bite: the pack returns to the hunter.
                if (master && _back > diff)
                    _back -= diff;
                else if (master)
                {
                    _back = 1000;
                    if (me->GetDistance(master) > 8.0f)
                        me->GetMotionMaster()->MoveFollow(master, 3.0f,
                            float(rand_norm()) * 2.0f * float(M_PI));
                }
                return;
            }
            DoMeleeAttackIfReady();
        }

    private:
        uint32 _back = 0;
    };

    // =======================================================================
    // Rage of the Sleeper — the reflection heals
    // =======================================================================
    // THE REFLECTION ITSELF IS NATIVE: the damage shield aura is handled by the
    // core in Unit::DealMeleeDamage, exactly like thorns. This script does ONLY
    // the part that exists nowhere in 3.3.5 — giving the druid back a fraction of
    // what he has just reflected.
    //
    // THE FRACTION LIVES IN THE THIRD EFFECT, a dummy, and not hardcoded here: it
    // thus stays in the truth table, within reach of the balancing, like the
    // reflection itself. The dummy serves only that, and carries the proc hook —
    // the core triggers nothing on a reflection aura.
    class spell_spheregrid_sleeper_rage : public AuraScript
    {
        PrepareAuraScript(spell_spheregrid_sleeper_rage);

        void Drink(AuraEffect const* /*effect*/, ProcEventInfo& /*infos*/)
        {
            Unit* druid = GetTarget();
            if (!druid)
                return;

            AuraEffect const* bounce = GetEffect(EFFECT_1);
            AuraEffect const* progress = GetEffect(EFFECT_2);
            if (!bounce || !progress)
                return;

            int32 const amount = bounce->GetAmount() * progress->GetAmount() / 100;
            if (amount <= 0)
                return;

            HealInfo buff(druid, druid, uint32(amount), GetSpellInfo(),
                              SPELL_SCHOOL_MASK_NATURE);
            druid->HealBySpell(buff);
        }

        void Register() override
        {
            OnEffectProc += AuraEffectProcFn(spell_spheregrid_sleeper_rage::Drink,
                                             EFFECT_2, SPELL_AURA_DUMMY);
        }
    };

}

void AddSC_spheregrid_spells()
{
    RegisterSpellScript(spell_spheregrid_directional_leap);
    RegisterSpellScript(spell_spheregrid_heroic_leap);
    RegisterSpellScript(spell_spheregrid_shunpo);
    RegisterSpellScript(spell_spheregrid_spartan_shield);
    RegisterSpellScript(spell_spheregrid_sweeping_strikes);
    RegisterSpellScript(spell_spheregrid_shimmer);
    RegisterSpellScript(spell_spheregrid_shimmer_marker);
    RegisterSpellScript(spell_spheregrid_arcane_orb);
    RegisterCreatureAI(npc_spheregrid_arcane_orb);
    RegisterSpellScript(spell_spheregrid_ray_of_frost);
    RegisterSpellScript(spell_spheregrid_bane_of_kings);
    RegisterSpellScript(spell_spheregrid_roll_the_bones);
    RegisterSpellScript(spell_spheregrid_halo);
    RegisterCreatureAI(npc_spheregrid_halo);
    RegisterSpellScript(spell_spheregrid_apocalypse);
    RegisterCreatureAI(npc_spheregrid_ghoul);
    RegisterSpellScript(spell_spheregrid_divine_steed);
    RegisterSpellScript(spell_spheregrid_gate);
    new go_spheregrid_gate();
    RegisterSpellScript(spell_spheregrid_cataclysm);
    RegisterSpellAndAuraScriptPair(spell_spheregrid_burning_rush,
                                   spell_spheregrid_burning_rush_aura);
    RegisterCreatureAI(npc_spheregrid_pack);
    RegisterSpellScript(spell_spheregrid_despair);
    RegisterSpellScript(spell_spheregrid_barrier_zone);
    RegisterCreatureAI(npc_spheregrid_barrier);
    RegisterSpellScript(spell_spheregrid_feather);
    RegisterCreatureAI(npc_spheregrid_feather);
    RegisterSpellScript(spell_spheregrid_bone_storm);
    RegisterSpellScript(spell_spheregrid_sindragosa_breath);
    RegisterSpellScript(spell_spheregrid_earthquake);
    RegisterSpellScript(spell_spheregrid_ascendance);
    new spheregrid_ascendance_watch();
    RegisterSpellScript(spell_spheregrid_spirit_link);
    RegisterSpellScript(spell_spheregrid_tyrant);
    RegisterSpellScript(spell_spheregrid_tyrantt_hunter);
    RegisterSpellScript(spell_spheregrid_tyrantt_succubus);
    RegisterCreatureAI(npc_spheregrid_tyrant);
    RegisterSpellScript(spell_spheregrid_wild_rush);
    RegisterSpellScript(spell_spheregrid_consecutive_shots);
    RegisterSpellScript(spell_spheregrid_embedded_bolts);
    RegisterSpellScript(spell_spheregrid_short_stride);
    RegisterSpellScript(spell_spheregrid_bear_charge);
    RegisterSpellScript(spell_spheregrid_cat_charge);
    RegisterSpellScript(spell_spheregrid_travel_charge);
    RegisterSpellScript(spell_spheregrid_tree_charge);
    RegisterSpellScript(spell_spheregrid_moonkin_charge);
    RegisterSpellScript(spell_spheregrid_stars);
    RegisterSpellScript(spell_spheregrid_moonkin_form);
    RegisterSpellScript(spell_spheregrid_frenzy);
    new spheregrid_feather_player();
    new spheregrid_starfall_player();
    new spheregrid_solstice_player();
    RegisterSpellScript(spell_spheregrid_bloom);
    RegisterSpellScript(spell_spheregrid_sleeper_rage);
}

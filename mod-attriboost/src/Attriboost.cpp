#include "Attriboost.h"

#include "Chat.h"
#include "Config.h"
#include "Spell.h"

#include <AI/ScriptedAI/ScriptedGossip.h>

void AttriboostPlayerScript::OnPlayerLogin(Player* player)
{
    if (!player)
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        return;
    }

    auto attributes = LoadAttriboostsForPlayer(player);
    if (!attributes)
    {
        return;
    }

    ApplyAttributes(player, attributes);
}

void AttriboostPlayerScript::OnPlayerLogout(Player* player)
{
    if (!player)
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        return;
    }

    SaveAttriboostsForPlayer(player);
}

void AttriboostPlayerScript::OnPlayerCompleteQuest(Player* player, Quest const* quest)
{
    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        return;
    }

    if (!player)
    {
        return;
    }

    switch (quest->GetQuestId())
    {
    case ATTR_QUEST:
        AddAttributePoint(player);
        break;

    case TALENT_QUEST:
        AddTalentPoint(player);
        break;
    }

    if (quest->GetQuestId() != ATTR_QUEST &&
        quest->GetQuestId() != TALENT_QUEST)
    {
        return;
    }

    SaveAttriboostsForPlayer(player);
}

void AddAttributePoint(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        LOG_INFO("module", "Failed to get attriboosts for player '{}' with guid '{}'. !!!REPORT THIS!!!", player->GetName(), player->GetGUID().GetRawValue());
        return;
    }

    attributes->Unallocated += 3;
}

void AddTalentPoint(Player* player)
{
    player->RewardExtraBonusTalentPoints(1);
    player->InitTalentForLevel();
}

void AttriboostPlayerScript::OnPlayerLeaveCombat(Player* player)
{
    if (!player)
    {
        return;
    }

    // This hook is called when removing the player from the world (like shutdown),
    // even when you are not in combat.
    if (player->IsDuringRemoveFromWorld() || !player->IsInWorld())
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.DisablePvP", false))
    {
        return;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    ApplyAttributes(player, attributes);
}

uint32 AttriboostPlayerScript::GetRandomAttributeForClass(Player* player)
{
    switch (player->getClass())
    {
    case CLASS_DEATH_KNIGHT:
    case CLASS_WARRIOR:
    case CLASS_ROGUE:
        switch (urand(0, 4))
        {
        case 0:
            return ATTR_SPELL_STAMINA;
        case 1:
            return ATTR_SPELL_AGILITY;
        case 2:
            return ATTR_SPELL_STRENGTH;
        case 3:
            return ATTR_SPELL_CRITICAL_STRIKE_DAMAGE;
        case 4:
            return ATTR_SPELL_ALL_RESISTS;
        }

    case CLASS_WARLOCK:
    case CLASS_PRIEST:
    case CLASS_MAGE:
        switch (urand(0, 6))
        {
        case 0:
            return ATTR_SPELL_STAMINA;
        case 1:
            return ATTR_SPELL_INTELLECT;
        case 2:
            return ATTR_SPELL_SPIRIT;
        case 3:
            return ATTR_SPELL_SPELL_POWER;
        case 4:
            return ATTR_SPELL_CRITICAL_STRIKE_DAMAGE;
        case 5:
            return ATTR_SPELL_PENETRATION;
        case 6:
            return ATTR_SPELL_ALL_RESISTS;
        }

    case CLASS_SHAMAN:
    case CLASS_HUNTER:
    case CLASS_PALADIN:
    case CLASS_DRUID:
        switch (urand(0, 6))
        {
        case 0:
            return ATTR_SPELL_STAMINA;
        case 1:
            return ATTR_SPELL_STRENGTH;
        case 2:
            return ATTR_SPELL_AGILITY;
        case 3:
            return ATTR_SPELL_INTELLECT;
        case 4:
            return ATTR_SPELL_SPIRIT;
        case 5:
            return ATTR_SPELL_CRITICAL_STRIKE_DAMAGE;
        case 6:
            return ATTR_SPELL_ALL_RESISTS;
        }
    }

    return 0;
}

std::string AttriboostPlayerScript::GetAttributeName(uint32 attribute)
{
    switch (attribute)
    {
    case ATTR_SPELL_STAMINA:
        return "Stamina";

    case ATTR_SPELL_STRENGTH:
        return "Strength";

    case ATTR_SPELL_AGILITY:
        return "Agility";

    case ATTR_SPELL_INTELLECT:
        return "Intellect";

    case ATTR_SPELL_SPIRIT:
        return "Spirit";

    case ATTR_SPELL_SPELL_POWER:
        return "Spell Power";

    case ATTR_SPELL_CRITICAL_STRIKE_DAMAGE:
        return "Critical Strike Damage";

    case ATTR_SPELL_ALL_RESISTS:
        return "All Resistances";

    case ATTR_SPELL_PENETRATION:
        return "Spell Penetration";

    case ATTR_SPELL_HEALING_POWER:
        return "Healing Power";
    }
   


    return std::string();
}

Attriboosts* GetAttriboosts(Player* player)
{
    auto guid = player->GetGUID().GetRawValue();

    auto attri = attriboostsMap.find(guid);
    if (attri == attriboostsMap.end())
    {
        Attriboosts attriboosts;

        attriboosts.Unallocated = 0;

        attriboosts.Stamina = 0;
        attriboosts.Strength = 0;
        attriboosts.Agility = 0;
        attriboosts.Intellect = 0;
        attriboosts.Spirit = 0;
        attriboosts.SpellPower = 0;
        attriboosts.CriticalStrikeDamage = 0;
        attriboosts.AllResists = 0;
        attriboosts.SpellPenetration = 0;
        attriboosts.HealingPower = 0;

        attriboosts.Settings = ATTR_SETTING_PROMPT;

        auto result = attriboostsMap.emplace(guid, attriboosts);
        attri = result.first;
    }

    return &attri->second;
}

void ClearAttriboosts()
{
    attriboostsMap.clear();
}

void LoadAttriboosts()
{
    auto qResult = CharacterDatabase.Query("SELECT * FROM attriboost_attributes");

    if (!qResult)
    {
        LOG_ERROR("module", "Failed to load from 'attriboost_attributes' table.");
        return;
    }

    LOG_INFO("module", "Loading player attriboosts from 'attriboost_attributes'..");

    int count = 0;

    do
    {
        auto fields = qResult->Fetch();

        uint64 guid = fields[0].Get<uint64>();

        Attriboosts attriboosts;

        attriboosts.Unallocated = fields[1].Get<uint32>();

        attriboosts.Stamina = fields[2].Get<uint32>();
        attriboosts.Strength = fields[3].Get<uint32>();
        attriboosts.Agility = fields[4].Get<uint32>();
        attriboosts.Intellect = fields[5].Get<uint32>();
        attriboosts.Spirit = fields[6].Get<uint32>();
        attriboosts.SpellPower = fields[7].Get<uint32>();
        attriboosts.CriticalStrikeDamage = fields[8].Get<uint32>();
        attriboosts.AllResists = fields[9].Get<uint32>();
        attriboosts.SpellPenetration = fields[10].Get<uint32>();
        attriboosts.HealingPower = fields[11].Get<uint32>();

        attriboosts.Settings = fields[12].Get<uint32>();

        attriboostsMap.emplace(guid, attriboosts);

        count++;
    } while (qResult->NextRow());

    LOG_INFO("module", "Loaded '{}' player attriboosts.", count);
}

Attriboosts* LoadAttriboostsForPlayer(Player* player)
{
    if (!player)
    {
        return nullptr;
    }

    auto guid = player->GetGUID().GetRawValue();
    auto qResult = CharacterDatabase.Query("SELECT * FROM attriboost_attributes WHERE guid = {}", guid);

    if (!qResult)
    {
        return nullptr;
    }

    auto fields = qResult->Fetch();

    Attriboosts newAttributes;

    newAttributes.Unallocated = fields[1].Get<uint32>();

    newAttributes.Stamina = fields[2].Get<uint32>();
    newAttributes.Strength = fields[3].Get<uint32>();
    newAttributes.Agility = fields[4].Get<uint32>();
    newAttributes.Intellect = fields[5].Get<uint32>();
    newAttributes.Spirit = fields[6].Get<uint32>();
    newAttributes.SpellPower = fields[7].Get<uint32>();
    newAttributes.CriticalStrikeDamage = fields[8].Get<uint32>();
    newAttributes.AllResists = fields[9].Get<uint32>();
    newAttributes.SpellPenetration = fields[10].Get<uint32>();
    newAttributes.HealingPower = fields[11].Get<uint32>();

    newAttributes.Settings = fields[12].Get<uint32>();

    auto attributes = attriboostsMap.find(guid);

    if (attributes == attriboostsMap.end())
    {
        attriboostsMap.emplace(guid, newAttributes);
    }
    else
    {
        attributes->second = newAttributes;
    }

    return &attributes->second;
}

void SaveAttriboosts()
{
    for (auto it = attriboostsMap.begin(); it != attriboostsMap.end(); ++it)
    {
        auto guid = it->first;

        auto unallocated = it->second.Unallocated;

        auto stamina = it->second.Stamina;
        auto strength = it->second.Strength;
        auto agility = it->second.Agility;
        auto intellect = it->second.Intellect;
        auto spirit = it->second.Spirit;
        auto spellPower = it->second.SpellPower;
        auto criticalStrikeDamage = it->second.CriticalStrikeDamage;
        auto allResists = it->second.AllResists;
        auto spellPenetration = it->second.SpellPenetration;
        auto healingPower = it->second.HealingPower;

        auto settings = it->second.Settings;

        CharacterDatabase.Execute("INSERT INTO `attriboost_attributes` (guid, unallocated, stamina, strength, agility, intellect, spirit, spellpower, criticalstrikedamage, allresists, spellpenetration, healingpower, settings) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}) ON DUPLICATE KEY UPDATE unallocated={}, stamina={}, strength={}, agility={}, intellect={}, spirit={}, spellpower={}, criticalstrikedamage={}, allresists={}, spellpenetration={}, healingpower={},settings={}",
            guid,
            unallocated, stamina, strength, agility, intellect, spirit, spellPower, criticalStrikeDamage, allResists, spellPenetration, healingPower, settings,
            unallocated, stamina, strength, agility, intellect, spirit, spellPower, criticalStrikeDamage, allResists, spellPenetration, healingPower, settings);
    }
}

void SaveAttriboostsForPlayer(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    auto guid = player->GetGUID().GetRawValue();

    auto unallocated = attributes->Unallocated;

    auto stamina = attributes->Stamina;
    auto strength = attributes->Strength;
    auto agility = attributes->Agility;
    auto intellect = attributes->Intellect;
    auto spirit = attributes->Spirit;
    auto spellPower = attributes->SpellPower;
    auto criticalStrikeDamage = attributes->CriticalStrikeDamage;
    auto allResists = attributes->AllResists;
    auto spellPenetration = attributes->SpellPenetration;
    auto healingPower = attributes->HealingPower;

    auto settings = attributes->Settings;

    CharacterDatabase.Execute("INSERT INTO `attriboost_attributes` (guid, unallocated, stamina, strength, agility, intellect, spirit, spellpower, criticalstrikedamage, allresists, spellpenetration, healingpower, settings) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}) ON DUPLICATE KEY UPDATE unallocated={}, stamina={}, strength={}, agility={}, intellect={}, spirit={}, spellpower={}, criticalstrikedamage={}, allresists={}, spellpenetration={}, healingpower={},settings={}",
        guid,
        unallocated, stamina, strength, agility, intellect, spirit, spellPower, criticalStrikeDamage, allResists, spellPenetration, healingPower, settings,
        unallocated, stamina, strength, agility, intellect, spirit, spellPower, criticalStrikeDamage, allResists, spellPenetration, healingPower, settings);
}

void SaveAttriboostsForPlayerDirect(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    auto guid = player->GetGUID().GetRawValue();
    auto a = *attributes;

    CharacterDatabase.DirectExecute("INSERT INTO `attriboost_attributes` (guid, unallocated, stamina, strength, agility, intellect, spirit, spellpower, criticalstrikedamage, allresists, spellpenetration, healingpower, settings) VALUES ({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}) ON DUPLICATE KEY UPDATE unallocated={}, stamina={}, strength={}, agility={}, intellect={}, spirit={}, spellpower={}, criticalstrikedamage={}, allresists={}, spellpenetration={}, healingpower={},settings={}",
        guid,
        a.Unallocated, a.Stamina, a.Strength, a.Agility, a.Intellect, a.Spirit, a.SpellPower, a.CriticalStrikeDamage, a.AllResists, a.SpellPenetration, a.HealingPower, a.Settings,
        a.Unallocated, a.Stamina, a.Strength, a.Agility, a.Intellect, a.Spirit, a.SpellPower, a.CriticalStrikeDamage, a.AllResists, a.SpellPenetration, a.HealingPower, a.Settings);
}

void ApplyAttributes(Player* player, Attriboosts* attributes)
{
    if (player->IsAlive() == false)
    {
        return;
    }

    if (attributes->Stamina > 0)
    {
        auto stamina = player->GetAura(ATTR_SPELL_STAMINA);
        if (!stamina)
        {
            stamina = player->AddAura(ATTR_SPELL_STAMINA, player);
        }
        stamina->SetStackAmount(attributes->Stamina);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_STAMINA))
        {
            player->RemoveAura(ATTR_SPELL_STAMINA);
        }
    }

    if (attributes->Strength > 0)
    {
        auto strength = player->GetAura(ATTR_SPELL_STRENGTH);
        if (!strength)
        {
            strength = player->AddAura(ATTR_SPELL_STRENGTH, player);
        }
        strength->SetStackAmount(attributes->Strength);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_STRENGTH))
        {
            player->RemoveAura(ATTR_SPELL_STRENGTH);
        }
    }

    if (attributes->Agility > 0)
    {
        auto agility = player->GetAura(ATTR_SPELL_AGILITY);
        if (!agility)
        {
            agility = player->AddAura(ATTR_SPELL_AGILITY, player);
        }
        agility->SetStackAmount(attributes->Agility);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_AGILITY))
        {
            player->RemoveAura(ATTR_SPELL_AGILITY);
        }
    }

    if (attributes->Intellect > 0)
    {
        auto intellect = player->GetAura(ATTR_SPELL_INTELLECT);
        if (!intellect)
        {
            intellect = player->AddAura(ATTR_SPELL_INTELLECT, player);
        }
        intellect->SetStackAmount(attributes->Intellect);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_INTELLECT))
        {
            player->RemoveAura(ATTR_SPELL_INTELLECT);
        }
    }

    if (attributes->Spirit > 0)
    {
        auto spirit = player->GetAura(ATTR_SPELL_SPIRIT);
        if (!spirit)
        {
            spirit = player->AddAura(ATTR_SPELL_SPIRIT, player);
        }
        spirit->SetStackAmount(attributes->Spirit);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_SPIRIT))
        {
            player->RemoveAura(ATTR_SPELL_SPIRIT);
        }
    }

    if (attributes->SpellPower > 0)
    {
        auto spellPower = player->GetAura(ATTR_SPELL_SPELL_POWER);
        if (!spellPower)
        {
            spellPower = player->AddAura(ATTR_SPELL_SPELL_POWER, player);
        }
        spellPower->SetStackAmount(attributes->SpellPower);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_SPELL_POWER))
        {
            player->RemoveAura(ATTR_SPELL_SPELL_POWER);
        }
    }

    if (attributes->CriticalStrikeDamage > 0)
    {
        auto criticalStrikeDamage = player->GetAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE);
        if (!criticalStrikeDamage)
        {
            criticalStrikeDamage = player->AddAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE, player);
        }
        criticalStrikeDamage->SetStackAmount(attributes->CriticalStrikeDamage);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE))
        {
            player->RemoveAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE);
        }
    }

    if (attributes->AllResists > 0)
    {
        auto allResists = player->GetAura(ATTR_SPELL_ALL_RESISTS);
        if (!allResists)
        {
            allResists = player->AddAura(ATTR_SPELL_ALL_RESISTS, player);
        }
        allResists->SetStackAmount(attributes->AllResists);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_ALL_RESISTS))
        {
            player->RemoveAura(ATTR_SPELL_ALL_RESISTS);
        }
    }

    if (attributes->SpellPenetration > 0)
    {
        auto spellPenetration = player->GetAura(ATTR_SPELL_PENETRATION);
        if (!spellPenetration)
        {
            spellPenetration = player->AddAura(ATTR_SPELL_PENETRATION, player);
        }
        spellPenetration->SetStackAmount(attributes->SpellPenetration);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_PENETRATION))
        {
            player->RemoveAura(ATTR_SPELL_PENETRATION);
        }
    }

    if (attributes->HealingPower > 0)
    {
        auto healingPower = player->GetAura(ATTR_SPELL_HEALING_POWER);
        if (!healingPower)
        {
            healingPower = player->AddAura(ATTR_SPELL_HEALING_POWER, player);
        }
        healingPower->SetStackAmount(attributes->HealingPower);
    }
    else
    {
        if (player->GetAura(ATTR_SPELL_HEALING_POWER))
        {
            player->RemoveAura(ATTR_SPELL_HEALING_POWER);
        }
    }

}

void DisableAttributes(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    if (player->GetAura(ATTR_SPELL_STAMINA))
    {
        player->RemoveAura(ATTR_SPELL_STAMINA);
    }

    if (player->GetAura(ATTR_SPELL_STRENGTH))
    {
        player->RemoveAura(ATTR_SPELL_STRENGTH);
    }

    if (player->GetAura(ATTR_SPELL_AGILITY))
    {
        player->RemoveAura(ATTR_SPELL_AGILITY);
    }

    if (player->GetAura(ATTR_SPELL_INTELLECT))
    {
        player->RemoveAura(ATTR_SPELL_INTELLECT);
    }

    if (player->GetAura(ATTR_SPELL_SPIRIT))
    {
        player->RemoveAura(ATTR_SPELL_SPIRIT);
    }

    if (player->GetAura(ATTR_SPELL_SPELL_POWER))
    {
        player->RemoveAura(ATTR_SPELL_SPELL_POWER);
    }

    if (player->GetAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE))
    {
        player->RemoveAura(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE);
    }

    if (player->GetAura(ATTR_SPELL_ALL_RESISTS))
    {
        player->RemoveAura(ATTR_SPELL_ALL_RESISTS);
    }

    if (player->GetAura(ATTR_SPELL_PENETRATION))
    {
        player->RemoveAura(ATTR_SPELL_PENETRATION);
    }

    if (player->GetAura(ATTR_SPELL_HEALING_POWER))
    {
        player->RemoveAura(ATTR_SPELL_HEALING_POWER);
    }
}

bool TryAddAttribute(Attriboosts* attributes, uint32 attribute)
{
    bool alreadyMaxValue = false;

    if (attribute == ATTR_SPELL_STAMINA)
    {
        if (!IsAttributeAtMax(attribute, attributes->Stamina))
        {
            attributes->Stamina += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_STRENGTH)
    {
        if (!IsAttributeAtMax(attribute, attributes->Strength))
        {
            attributes->Strength += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_AGILITY)
    {
        if (!IsAttributeAtMax(attribute, attributes->Agility))
        {
            attributes->Agility += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_INTELLECT)
    {
        if (!IsAttributeAtMax(attribute, attributes->Intellect))
        {
            attributes->Intellect += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_SPIRIT)
    {
        if (!IsAttributeAtMax(attribute, attributes->Spirit))
        {
            attributes->Spirit += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_SPELL_POWER)
    {
        if (!IsAttributeAtMax(attribute, attributes->SpellPower))
        {
            attributes->SpellPower += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_CRITICAL_STRIKE_DAMAGE)
    {
        if (!IsAttributeAtMax(attribute, attributes->CriticalStrikeDamage))
        {
            attributes->CriticalStrikeDamage += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_ALL_RESISTS)
    {
        if (!IsAttributeAtMax(attribute, attributes->AllResists))
        {
            attributes->AllResists += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_PENETRATION)
    {
        if (!IsAttributeAtMax(attribute, attributes->SpellPenetration))
        {
            attributes->SpellPenetration += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }
    else if (attribute == ATTR_SPELL_HEALING_POWER)
    {
        if (!IsAttributeAtMax(attribute, attributes->HealingPower))
        {
            attributes->HealingPower += 1;
        }
        else
        {
            alreadyMaxValue = true;
        }
    }

    if (alreadyMaxValue)
    {
        return false;
    }

    attributes->Unallocated -= 1;
    return true;
}

void ResetAttributes(Attriboosts* attributes)
{
    attributes->Unallocated += GetTotalAttributes(attributes);

    attributes->Stamina = 0;
    attributes->Strength = 0;
    attributes->Agility = 0;
    attributes->Intellect = 0;
    attributes->Spirit = 0;
    attributes->SpellPower = 0;
    attributes->CriticalStrikeDamage = 0;
    attributes->AllResists = 0;
    attributes->SpellPenetration = 0;
    attributes->HealingPower = 0;
}

bool HasAttributesToSpend(Player* player)
{
    if (!player)
    {
        return false;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return false;
    }

    return attributes->Unallocated > 0;
}

bool HasAttributes(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return false;
    }

    return GetTotalAttributes(attributes) > 0;
}

bool IsAttributeAtMax(uint32 attribute, uint32 value)
{
    switch (attribute)
    {
    case ATTR_SPELL_STAMINA:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.Stamina", 100);

    case ATTR_SPELL_STRENGTH:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.Strength", 100);

    case ATTR_SPELL_AGILITY:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.Agility", 100);

    case ATTR_SPELL_INTELLECT:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.Intellect", 100);

    case ATTR_SPELL_SPIRIT:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.Spirit", 100);

    case ATTR_SPELL_SPELL_POWER:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.SpellPower", 100);

    case ATTR_SPELL_CRITICAL_STRIKE_DAMAGE:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.CriticalStrikeDamage", 100);

    case ATTR_SPELL_ALL_RESISTS:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.AllResists", 100);

    case ATTR_SPELL_PENETRATION:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.SpellPenetration", 100);

    case ATTR_SPELL_HEALING_POWER:
        return value >= sConfigMgr->GetOption<uint32>("Attriboost.Max.HealingPower", 100);
    }

    return true;
}

uint32 GetAttributesToSpend(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return 0;
    }

    return attributes->Unallocated;
}

uint32 GetTotalAttributes(Attriboosts* attributes)
{
    return attributes->Stamina + attributes->Strength + attributes->Agility + attributes->Intellect + attributes->Spirit + attributes->SpellPower + attributes->CriticalStrikeDamage + attributes->AllResists + attributes->SpellPenetration + attributes->HealingPower;
}

uint32 GetTotalAttributes(Player* player)
{
    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return 0;
    }

    return GetTotalAttributes(attributes);
}

uint32 GetResetCost()
{
    return sConfigMgr->GetOption<uint32>("Attriboost.ResetCost", 2500000);
}

bool HasSetting(Player* player, uint32 setting)
{
    if (!player)
    {
        return false;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return false;
    }

    return (attributes->Settings & setting) == setting;
}
void ToggleSetting(Player* player, uint32 setting)
{
    if (!player)
    {
        return;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    if (HasSetting(player, setting))
    {
        attributes->Settings -= setting;
    }
    else
    {
        attributes->Settings += setting;
    }
}

void AttriboostWorldScript::OnAfterConfigLoad(bool reload)
{
    if (reload)
    {
        SaveAttriboosts();
        ClearAttriboosts();
    }

    LoadAttriboosts();
}

bool AttriboostCreatureScript::OnGossipHello(Player* player, Creature* creature)
{
    ClearGossipMenuFor(player);

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        SendGossipMenuFor(player, ATTR_NPC_TEXT_DISABLED, creature);

        return true;
    }

    player->PrepareQuestMenu(creature->GetGUID());

    AddGossipItemFor(player, GOSSIP_ICON_DOT, "|TInterface\\GossipFrame\\TrainerGossipIcon:16|t Allouer des points", GOSSIP_SENDER_MAIN, ATTR_GOSSIP_ALLOCATE);
    AddGossipItemFor(player, GOSSIP_ICON_DOT, "|TInterface\\GossipFrame\\HealerGossipIcon:16|t Options", GOSSIP_SENDER_MAIN, ATTR_GOSSIP_SETTINGS);

    SendGossipMenuFor(player, ATTR_NPC_TEXT_GENERIC, creature);

    return true;
}

bool AttriboostCreatureScript::OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action)
{
    if (action == ATTR_GOSSIP_ALLOCATE)
    {
        SendAllocateMenu(player, creature);
        return true;
    }

    if (action == ATTR_GOSSIP_ALLOCATE_RETURN)
    {
        OnGossipHello(player, creature);
        return true;
    }

    if (action == ATTR_GOSSIP_SETTINGS)
    {
        SendSettingsMenu(player, creature);
        return true;
    }

    if (action == ATTR_GOSSIP_SETTINGS_PROMPT)
    {
        ToggleSetting(player, ATTR_SETTING_PROMPT);
        SendSettingsMenu(player, creature);
        return true;
    }

    if (action == ATTR_GOSSIP_SETTINGS_RETURN)
    {
        OnGossipHello(player, creature);
        return true;
    }

    if (action == ATTR_GOSSIP_ALLOCATE_RESET)
    {
        HandleAttributeAllocation(player, action, true);
        SendAllocateMenu(player, creature);
        return true;
    }

    if (action > 5000)
    {
        HandleAttributeAllocation(player, action, false);
        SendAllocateMenu(player, creature);
        return true;
    }

    return true;
}

void SendAllocateMenu(Player* player, Creature* creature)
{
    ClearGossipMenuFor(player);

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        CloseGossipMenuFor(player);
        return;
    }

    player->PrepareQuestMenu(creature->GetGUID());

    AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("|TInterface\\GossipFrame\\TrainerGossipIcon:16|t |cffFF0000{} |rPoint(s) disponible(s).", GetAttributesToSpend(player)), GOSSIP_SENDER_MAIN, 0);

    std::string optStamina = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Endurance ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_STAMINA, attributes->Stamina) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->Stamina, sConfigMgr->GetOption<uint32>("Attriboost.Max.Stamina", 100)),
        IsAttributeAtMax(ATTR_SPELL_STAMINA, attributes->Stamina) ? "|cffFF0000(MAXED)|r" : "");

    std::string optStrength = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Force ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_STRENGTH, attributes->Strength) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->Strength, sConfigMgr->GetOption<uint32>("Attriboost.Max.Strength", 100)),
        IsAttributeAtMax(ATTR_SPELL_STRENGTH, attributes->Strength) ? "|cffFF0000(MAXED)|r" : "");

    std::string optAgility = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Agilité ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_AGILITY, attributes->Agility) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->Agility, sConfigMgr->GetOption<uint32>("Attriboost.Max.Agility", 100)),
        IsAttributeAtMax(ATTR_SPELL_AGILITY, attributes->Agility) ? "|cffFF0000(MAXED)|r" : "");

    std::string optIntellect = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Intelligence ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_INTELLECT, attributes->Intellect) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->Intellect, sConfigMgr->GetOption<uint32>("Attriboost.Max.Intellect", 100)),
        IsAttributeAtMax(ATTR_SPELL_INTELLECT, attributes->Intellect) ? "|cffFF0000(MAXED)|r" : "");

    std::string optSpirit = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Esprit ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_SPIRIT, attributes->Spirit) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->Spirit, sConfigMgr->GetOption<uint32>("Attriboost.Max.Spirit", 100)),
        IsAttributeAtMax(ATTR_SPELL_SPIRIT, attributes->Spirit) ? "|cffFF0000(MAXED)|r" : "");

    std::string optSpellPower = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Dégâts des sorts ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_SPELL_POWER, attributes->SpellPower) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->SpellPower, sConfigMgr->GetOption<uint32>("Attriboost.Max.SpellPower", 100)),
        IsAttributeAtMax(ATTR_SPELL_SPELL_POWER, attributes->SpellPower) ? "|cffFF0000(MAXED)|r" : "");

    std::string optCriticalStrikeDamage = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Dégats des coups critiques ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE, attributes->CriticalStrikeDamage) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->CriticalStrikeDamage, sConfigMgr->GetOption<uint32>("Attriboost.Max.CriticalStrikeDamage", 100)),
        IsAttributeAtMax(ATTR_SPELL_CRITICAL_STRIKE_DAMAGE, attributes->CriticalStrikeDamage) ? "|cffFF0000(MAXED)|r" : "");

    std::string optAllResists = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Toutes les résistances ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_ALL_RESISTS, attributes->AllResists) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->AllResists, sConfigMgr->GetOption<uint32>("Attriboost.Max.AllResists", 100)),
        IsAttributeAtMax(ATTR_SPELL_ALL_RESISTS, attributes->AllResists) ? "|cffFF0000(MAXED)|r" : "");

    std::string optSpellPenetration = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Pénétration des sorts ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_PENETRATION, attributes->SpellPenetration) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->SpellPenetration, sConfigMgr->GetOption<uint32>("Attriboost.Max.SpellPenetration", 100)),
        IsAttributeAtMax(ATTR_SPELL_PENETRATION, attributes->SpellPenetration) ? "|cffFF0000(MAXED)|r" : "");

    std::string optHealingPower = Acore::StringFormat("|TInterface\\MINIMAP\\UI-Minimap-ZoomInButton-Up:16|t {}Puissance des soins ({}) {}",
        IsAttributeAtMax(ATTR_SPELL_HEALING_POWER, attributes->HealingPower) ? "|cff777777" : "|cff000000",
        Acore::StringFormat("{}/{}", attributes->HealingPower, sConfigMgr->GetOption<uint32>("Attriboost.Max.HealingPower", 100)),
        IsAttributeAtMax(ATTR_SPELL_HEALING_POWER, attributes->HealingPower) ? "|cffFF0000(MAXED)|r" : "");

    if (HasSetting(player, ATTR_SETTING_PROMPT))
    {
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optStamina, GOSSIP_SENDER_MAIN, ATTR_SPELL_STAMINA);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optStrength, GOSSIP_SENDER_MAIN, ATTR_SPELL_STRENGTH);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optAgility, GOSSIP_SENDER_MAIN, ATTR_SPELL_AGILITY);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optIntellect, GOSSIP_SENDER_MAIN, ATTR_SPELL_INTELLECT);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpirit, GOSSIP_SENDER_MAIN, ATTR_SPELL_SPIRIT);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpellPower, GOSSIP_SENDER_MAIN, ATTR_SPELL_SPELL_POWER);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optCriticalStrikeDamage, GOSSIP_SENDER_MAIN, ATTR_SPELL_CRITICAL_STRIKE_DAMAGE);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optAllResists, GOSSIP_SENDER_MAIN, ATTR_SPELL_ALL_RESISTS);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpellPenetration, GOSSIP_SENDER_MAIN, ATTR_SPELL_PENETRATION);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optHealingPower, GOSSIP_SENDER_MAIN, ATTR_SPELL_HEALING_POWER);
    }
    else
    {
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optStamina, GOSSIP_SENDER_MAIN, ATTR_SPELL_STAMINA);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optStrength, GOSSIP_SENDER_MAIN, ATTR_SPELL_STRENGTH);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optAgility, GOSSIP_SENDER_MAIN, ATTR_SPELL_AGILITY);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optIntellect, GOSSIP_SENDER_MAIN, ATTR_SPELL_INTELLECT);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpirit, GOSSIP_SENDER_MAIN, ATTR_SPELL_SPIRIT);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpellPower, GOSSIP_SENDER_MAIN, ATTR_SPELL_SPELL_POWER);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optCriticalStrikeDamage, GOSSIP_SENDER_MAIN, ATTR_SPELL_CRITICAL_STRIKE_DAMAGE);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optAllResists, GOSSIP_SENDER_MAIN, ATTR_SPELL_ALL_RESISTS);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optSpellPenetration, GOSSIP_SENDER_MAIN, ATTR_SPELL_PENETRATION);
        AddGossipItemFor(player, GOSSIP_ICON_DOT, optHealingPower, GOSSIP_SENDER_MAIN, ATTR_SPELL_HEALING_POWER);
    }

    if (HasAttributes(player))
    {
        uint32 resetCost = GetResetCost();
        AddGossipItemFor(player, GOSSIP_ICON_DOT, "|TInterface\\GossipFrame\\UnlearnGossipIcon:16|t Réinitialiser les attributs", GOSSIP_SENDER_MAIN, ATTR_GOSSIP_ALLOCATE_RESET, "Voulez-vous réinitialiser les attributs et récupérer vos points ?", resetCost, false);
    }

    AddGossipItemFor(player, GOSSIP_ICON_DOT, "|TInterface\\MONEYFRAME\\Arrow-Left-Down:16|t Retour", GOSSIP_SENDER_MAIN, ATTR_GOSSIP_ALLOCATE_RETURN);

    if (HasAttributesToSpend(player))
    {
        SendGossipMenuFor(player, ATTR_NPC_TEXT_HAS_ATTRIBUTES, creature);
    }
    else
    {
        SendGossipMenuFor(player, ATTR_NPC_TEXT_GENERIC, creature);
    }
}

void SendSettingsMenu(Player* player, Creature* creature)
{
    ClearGossipMenuFor(player);

    player->PrepareQuestMenu(creature->GetGUID());

    auto hasPromptSetting = HasSetting(player, ATTR_SETTING_PROMPT);
    AddGossipItemFor(player, GOSSIP_ICON_DOT, Acore::StringFormat("|TInterface\\GossipFrame\\HealerGossipIcon:16|t Prompt 'Êtes-vous certain ?': {}", hasPromptSetting ? "|cff00FF00Enabled|r" : "|cffFF0000Disabled"), GOSSIP_SENDER_MAIN, ATTR_GOSSIP_SETTINGS_PROMPT);

    AddGossipItemFor(player, GOSSIP_ICON_DOT, "|TInterface\\MONEYFRAME\\Arrow-Left-Down:16|t Retour", GOSSIP_SENDER_MAIN, ATTR_GOSSIP_SETTINGS_RETURN);

    SendGossipMenuFor(player, ATTR_NPC_TEXT_GENERIC, creature);
}

void AttriboostCreatureScript::HandleAttributeAllocation(Player* player, uint32 attribute, bool reset)
{
    if (!player)
    {
        return;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return;
    }

    if (reset)
    {
        auto cost = GetResetCost();
        if (player->HasEnoughMoney(cost))
        {
            player->SetMoney(player->GetMoney() - cost);
            ResetAttributes(attributes);
        }
    }
    else
    {
        if (attributes->Unallocated < 1)
        {
            ChatHandler(player->GetSession()).SendSysMessage("Vous n'avez pas de points à dépenser.");
            return;
        }

        auto result = TryAddAttribute(attributes, attribute);
        if (!result)
        {
            ChatHandler(player->GetSession()).SendSysMessage("Cet attribut ne peut pas être amélioré d'avantage.");
            return;
        }
    }

    ApplyAttributes(player, attributes);
    SaveAttriboosts();
}

void AttriboostWorldScript::OnShutdownInitiate(ShutdownExitCode /*code*/, ShutdownMask /*mask*/)
{
    SaveAttriboosts();
}

void AttriboostUnitScript::OnDamage(Unit* attacker, Unit* victim, uint32& /*damage*/)
{
    if (!attacker || !victim)
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        return;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.DisablePvP", false))
    {
        return;
    }

    auto p1 = attacker->ToPlayer();
    auto p2 = victim->ToPlayer();

    if (!p1 || !p2)
    {
        return;
    }

    //DisableAttributes(p1);
    //DisableAttributes(p2);
}

// ---------------------------------------------------------------------------
// Commandes joueur
// ---------------------------------------------------------------------------
using namespace Acore::ChatCommands;

static Player* JoueurDeCommande(ChatHandler* handler)
{
    if (!handler->GetSession())
    {
        return nullptr;
    }

    if (!sConfigMgr->GetOption<bool>("Attriboost.Enable", false))
    {
        handler->SendSysMessage("Le système d'attributs est désactivé.");
        return nullptr;
    }

    return handler->GetSession()->GetPlayer();
}

static uint32 AttributDepuisNom(std::string const& nom)
{
    if (nom == "stamina")     return ATTR_SPELL_STAMINA;
    if (nom == "strength")    return ATTR_SPELL_STRENGTH;
    if (nom == "agility")     return ATTR_SPELL_AGILITY;
    if (nom == "intellect")   return ATTR_SPELL_INTELLECT;
    if (nom == "spirit")      return ATTR_SPELL_SPIRIT;
    if (nom == "spellpower")  return ATTR_SPELL_SPELL_POWER;
    if (nom == "critdamage")  return ATTR_SPELL_CRITICAL_STRIKE_DAMAGE;
    if (nom == "resists")     return ATTR_SPELL_ALL_RESISTS;
    if (nom == "penetration") return ATTR_SPELL_PENETRATION;
    if (nom == "healing")     return ATTR_SPELL_HEALING_POWER;
    return 0;
}

ChatCommandTable AttriboostCommandScript::GetCommands() const
{
    static ChatCommandTable attriboostTable =
    {
        { "exchange", HandleExchangeCommand, SEC_PLAYER, Console::No },
        { "talents",  HandleTalentsCommand,  SEC_PLAYER, Console::No },
        { "allocate", HandleAllocateCommand, SEC_PLAYER, Console::No },
        { "reset",    HandleResetCommand,    SEC_PLAYER, Console::No },
    };

    static ChatCommandTable commandTable =
    {
        { "attriboost", attriboostTable },
    };

    return commandTable;
}

// .attriboost exchange N : N Livres de connaissance -> 3N points d'attribut.
bool AttriboostCommandScript::HandleExchangeCommand(ChatHandler* handler, uint32 count)
{
    Player* player = JoueurDeCommande(handler);
    if (!player)
    {
        return true;
    }

    if (count < 1 || count > 200)
    {
        handler->SendSysMessage("Nombre de livres invalide.");
        return true;
    }

    if (player->GetItemCount(ATTR_ITEM) < count)
    {
        handler->SendSysMessage("Vous n'avez pas assez de Livres de connaissance.");
        return true;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return true;
    }

    player->DestroyItemCount(ATTR_ITEM, count, true);
    attributes->Unallocated += ATTR_POINTS_PER_BOOK * count;
    SaveAttriboostsForPlayerDirect(player);

    handler->PSendSysMessage("Vous obtenez {} point(s) d'attribut.", ATTR_POINTS_PER_BOOK * count);
    return true;
}

// .attriboost talents N : N Livres des talents -> N points de talent.
bool AttriboostCommandScript::HandleTalentsCommand(ChatHandler* handler, uint32 count)
{
    Player* player = JoueurDeCommande(handler);
    if (!player)
    {
        return true;
    }

    if (count < 1 || count > 200)
    {
        handler->SendSysMessage("Nombre de livres invalide.");
        return true;
    }

    if (player->GetItemCount(TALENT_ITEM) < count)
    {
        handler->SendSysMessage("Vous n'avez pas assez de Livres des talents.");
        return true;
    }

    player->DestroyItemCount(TALENT_ITEM, count, true);
    player->RewardExtraBonusTalentPoints(count);
    player->InitTalentForLevel();

    handler->PSendSysMessage("Vous obtenez {} point(s) de talent.", count);
    return true;
}

// .attriboost allocate <stat> N : N points disponibles -> la statistique.
bool AttriboostCommandScript::HandleAllocateCommand(ChatHandler* handler, std::string stat, uint32 count)
{
    Player* player = JoueurDeCommande(handler);
    if (!player)
    {
        return true;
    }

    uint32 attribute = AttributDepuisNom(stat);
    if (!attribute)
    {
        handler->SendSysMessage("Statistique inconnue.");
        return true;
    }

    if (count < 1 || count > 250)
    {
        handler->SendSysMessage("Nombre de points invalide.");
        return true;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return true;
    }

    if (attributes->Unallocated < count)
    {
        handler->SendSysMessage("Vous n'avez pas assez de points disponibles.");
        return true;
    }

    uint32 fait = 0;
    for (; fait < count; ++fait)
    {
        if (!TryAddAttribute(attributes, attribute))
        {
            break;
        }
    }

    if (fait == 0)
    {
        handler->SendSysMessage("Cet attribut est déjà au maximum.");
        return true;
    }

    ApplyAttributes(player, attributes);
    SaveAttriboostsForPlayerDirect(player);

    if (fait < count)
    {
        handler->PSendSysMessage("{} point(s) attribué(s) : le maximum est atteint.", fait);
    }

    return true;
}

// .attriboost reset : tout a zero contre Attriboost.ResetCost.
bool AttriboostCommandScript::HandleResetCommand(ChatHandler* handler)
{
    Player* player = JoueurDeCommande(handler);
    if (!player)
    {
        return true;
    }

    auto attributes = GetAttriboosts(player);
    if (!attributes)
    {
        return true;
    }

    if (GetTotalAttributes(attributes) == 0)
    {
        handler->SendSysMessage("Aucun point à réinitialiser.");
        return true;
    }

    uint32 cost = GetResetCost();
    if (!player->HasEnoughMoney(cost))
    {
        handler->SendSysMessage("Vous n'avez pas assez d'argent.");
        return true;
    }

    player->SetMoney(player->GetMoney() - cost);
    ResetAttributes(attributes);
    ApplyAttributes(player, attributes);
    SaveAttriboostsForPlayerDirect(player);

    handler->SendSysMessage("Attributs réinitialisés.");
    return true;
}

void SC_AddAttriboostScripts()
{
    new AttriboostWorldScript();
    new AttriboostPlayerScript();
    new AttriboostCreatureScript();
    new AttriboostUnitScript();
    new AttriboostCommandScript();
}

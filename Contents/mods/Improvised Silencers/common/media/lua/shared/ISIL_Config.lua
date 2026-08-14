ISILSilencerConfig = ISILSilencerConfig or {}

local sandboxModule = "ImprovisedSilencers"
local minDurability = 1
local infiniteDurability = 10001
local durabilityCurrentKey = "ISILCurrentDurability"
local durabilityMaxKey = "ISILMaxDurability"
local durabilityFullTypeKey = "ISILDurabilityFullType"

local suppressors = {
    ["Base.Silencer"] = {
        soundOption = "SilencerSoundReduction",
        rangeOption = "SilencerRangeReduction",
        durabilityOption = "SilencerDurability",
        soundReduction = 80.0,
        rangeReduction = 0.8,
        durability = 300,
        tags = "base:hasmetal;base:showcondition",
        swingSound = "SilencedShot",
    },
    ["Base.MetalPipeSilencer"] = {
        soundOption = "MetalPipeSilencerSoundReduction",
        rangeOption = "MetalPipeSilencerRangeReduction",
        durabilityOption = "MetalPipeSilencerDurability",
        soundReduction = 60.0,
        rangeReduction = 1.0,
        durability = 200,
        tags = "base:hasmetal;base:showcondition",
        swingSound = "CraftedSuppressedShot",
    },
    ["Base.TorchSilencer"] = {
        soundOption = "TorchSilencerSoundReduction",
        rangeOption = "TorchSilencerRangeReduction",
        durabilityOption = "TorchSilencerDurability",
        soundReduction = 40.0,
        rangeReduction = 2.0,
        durability = 100,
        tags = "base:hasmetal;base:showcondition",
        swingSound = "CraftedSuppressedShot",
    },
    ["Base.WaterBottleSilencer"] = {
        soundOption = "WaterBottleSilencerSoundReduction",
        rangeOption = "WaterBottleSilencerRangeReduction",
        durabilityOption = "WaterBottleSilencerDurability",
        soundReduction = 20.0,
        rangeReduction = 2.0,
        durability = 50,
        tags = "base:showcondition",
        swingSound = "CraftedSuppressedShot",
    },
}

local function clamp(value, min, max)
    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

local function getSandboxOptions()
    if SandboxVars and SandboxVars[sandboxModule] then
        return SandboxVars[sandboxModule]
    end

    return nil
end

local function getSandboxNumber(optionName, defaultValue, min, max)
    local sandboxOptions = getSandboxOptions()
    local value = sandboxOptions and tonumber(sandboxOptions[optionName]) or nil

    if value == nil then
        value = defaultValue
    end

    return clamp(value, min, max)
end

local function getSandboxBoolean(optionName, defaultValue)
    local sandboxOptions = getSandboxOptions()
    local value = nil

    if sandboxOptions then
        value = sandboxOptions[optionName]
    end

    if value == nil then
        return defaultValue
    end

    if value == true or value == "true" or value == 1 or value == "1" then
        return true
    end

    if value == false or value == "false" or value == 0 or value == "0" then
        return false
    end

    return defaultValue
end

function ISILSilencerConfig.keepBrokenSilencers()
    return getSandboxBoolean("KeepBrokenSilencers", true)
end

function ISILSilencerConfig.getEffect(fullType)
    local suppressor = suppressors[fullType]

    if not suppressor then
        return nil
    end

    local soundReduction = getSandboxNumber(suppressor.soundOption, suppressor.soundReduction, 0.0, 100.0)
    local soundMultiplier = (100.0 - soundReduction) / 100.0
    local rangeReduction = getSandboxNumber(suppressor.rangeOption, suppressor.rangeReduction, 0.0, 100.0)

    return {
        soundRadius = soundMultiplier,
        soundVolume = soundMultiplier,
        maxRangeModifier = -rangeReduction,
        swingSound = suppressor.swingSound,
    }
end

function ISILSilencerConfig.getDurability(fullType)
    local suppressor = suppressors[fullType]

    if not suppressor then
        return nil
    end

    return math.floor(getSandboxNumber(suppressor.durabilityOption, suppressor.durability, minDurability, infiniteDurability) + 0.5)
end

function ISILSilencerConfig.isInfiniteDurability(fullType)
    local durability = ISILSilencerConfig.getDurability(fullType)

    return durability ~= nil and durability >= infiniteDurability
end

function ISILSilencerConfig.getEffects()
    local effects = {}

    for fullType, _ in pairs(suppressors) do
        effects[fullType] = ISILSilencerConfig.getEffect(fullType)
    end

    return effects
end

function ISILSilencerConfig.isSuppressor(fullType)
    return suppressors[fullType] ~= nil
end

function ISILSilencerConfig.applyRangeModifiers()
    local scriptManager = getScriptManager and getScriptManager() or ScriptManager and ScriptManager.instance or nil

    if not scriptManager then
        return
    end

    for fullType, _ in pairs(suppressors) do
        local scriptItem = scriptManager:getItem(fullType)
        local effect = ISILSilencerConfig.getEffect(fullType)

        if scriptItem and effect then
            scriptItem:DoParam("MaxRangeModifier = " .. tostring(effect.maxRangeModifier))
        end
    end
end

function ISILSilencerConfig.applyDurabilityModifiers()
    local scriptManager = getScriptManager and getScriptManager() or ScriptManager and ScriptManager.instance or nil

    if not scriptManager then
        return
    end

    for fullType, suppressor in pairs(suppressors) do
        local scriptItem = scriptManager:getItem(fullType)
        local durability = ISILSilencerConfig.getDurability(fullType)

        if scriptItem and durability then
            scriptItem:DoParam("ConditionMax = " .. tostring(durability))
            scriptItem:DoParam("ConditionLowerChanceOneIn = 1")
            scriptItem:DoParam("UseDelta = " .. tostring(1 / durability))
            scriptItem:DoParam("UseWhileEquipped = false")
            scriptItem:DoParam("Tags = " .. suppressor.tags)
        end
    end
end

function ISILSilencerConfig.syncItemConditionDisplay(item)
    if not item or not item.getFullType or not ISILSilencerConfig.isSuppressor(item:getFullType()) then
        return
    end

    local fullType = item:getFullType()
    local durability = ISILSilencerConfig.getDurability(fullType)
    if not durability then
        return
    end

    if item.setUseDelta then
        item:setUseDelta(1 / durability)
    end

    if item.setUsedDelta then
        local modData = item.getModData and item:getModData() or nil
        local condition = modData and tonumber(modData[durabilityCurrentKey]) or nil
        if condition == nil then
            condition = item.getCondition and item:getCondition() or durability
        end
        item:setUsedDelta(clamp(condition / durability, 0, 1))
    end
end

function ISILSilencerConfig.applyItemDurability(item)
    if not item or not ISILSilencerConfig.isSuppressor(item:getFullType()) then
        return
    end

    local fullType = item:getFullType()
    local durability = ISILSilencerConfig.getDurability(fullType)
    if not durability then
        return
    end

    local modData = item.getModData and item:getModData() or nil
    local previousCurrent = modData and tonumber(modData[durabilityCurrentKey]) or nil
    local previousMax = modData and tonumber(modData[durabilityMaxKey]) or nil
    local previousFullType = modData and modData[durabilityFullTypeKey] or nil
    local currentCondition = item.getCondition and item:getCondition() or durability
    local currentMax = item.getConditionMax and item:getConditionMax() or durability

    if modData and (previousCurrent == nil or previousMax == nil or previousFullType ~= fullType) then
        if ISILSilencerConfig.isInfiniteDurability(fullType) then
            previousCurrent = durability
        elseif currentCondition <= 0 then
            previousCurrent = 0
        elseif currentCondition >= currentMax then
            previousCurrent = durability
        else
            previousCurrent = math.floor(clamp(currentCondition / currentMax, 0, 1) * durability + 0.5)
        end
    elseif previousMax and previousMax > 0 and previousMax ~= durability and not ISILSilencerConfig.isInfiniteDurability(fullType) then
        previousCurrent = math.floor(clamp(previousCurrent / previousMax, 0, 1) * durability + 0.5)
    end

    if modData then
        modData[durabilityCurrentKey] = clamp(previousCurrent or durability, 0, durability)
        modData[durabilityMaxKey] = durability
        modData[durabilityFullTypeKey] = fullType
    end

    if item.setConditionMax then
        item:setConditionMax(durability)
    end

    if item.setCondition then
        local displayCondition = modData and tonumber(modData[durabilityCurrentKey]) or currentCondition
        if ISILSilencerConfig.isInfiniteDurability(fullType) then
            item:setCondition(durability)
        elseif displayCondition <= 0 then
            item:setCondition(0)
        elseif item.getConditionMax then
            item:setCondition(math.max(1, math.floor(clamp(displayCondition / durability, 0, 1) * item:getConditionMax() + 0.5)))
        elseif displayCondition > currentMax then
            item:setCondition(currentMax)
        end
    end

    ISILSilencerConfig.syncItemConditionDisplay(item)
end

function ISILSilencerConfig.getItemDurability(item)
    if not item or not item.getFullType or not ISILSilencerConfig.isSuppressor(item:getFullType()) then
        return nil
    end

    ISILSilencerConfig.applyItemDurability(item)

    local modData = item.getModData and item:getModData() or nil
    if modData and modData[durabilityCurrentKey] ~= nil then
        return tonumber(modData[durabilityCurrentKey]) or 0
    end

    return item.getCondition and item:getCondition() or ISILSilencerConfig.getDurability(item:getFullType())
end

function ISILSilencerConfig.setItemDurability(item, value)
    if not item or not item.getFullType or not ISILSilencerConfig.isSuppressor(item:getFullType()) then
        return
    end

    local fullType = item:getFullType()
    local durability = ISILSilencerConfig.getDurability(fullType)
    if not durability then
        return
    end

    local modData = item.getModData and item:getModData() or nil
    local newValue = clamp(math.floor((tonumber(value) or 0) + 0.5), 0, durability)

    if modData then
        modData[durabilityCurrentKey] = newValue
        modData[durabilityMaxKey] = durability
        modData[durabilityFullTypeKey] = fullType
    end

    if item.setConditionMax then
        item:setConditionMax(durability)
    end

    if item.setCondition then
        if ISILSilencerConfig.isInfiniteDurability(fullType) then
            item:setCondition(durability)
        elseif newValue <= 0 then
            item:setCondition(0)
        elseif item.getConditionMax then
            item:setCondition(math.max(1, math.floor(clamp(newValue / durability, 0, 1) * item:getConditionMax() + 0.5)))
        else
            item:setCondition(newValue)
        end
    end

    ISILSilencerConfig.syncItemConditionDisplay(item)
end

function ISILSilencerConfig.getItemMaxDurability(item)
    if not item or not item.getFullType or not ISILSilencerConfig.isSuppressor(item:getFullType()) then
        return nil
    end

    ISILSilencerConfig.applyItemDurability(item)

    local modData = item.getModData and item:getModData() or nil
    if modData and modData[durabilityMaxKey] ~= nil then
        return tonumber(modData[durabilityMaxKey]) or ISILSilencerConfig.getDurability(item:getFullType())
    end

    return ISILSilencerConfig.getDurability(item:getFullType())
end

ISILSilencerConfig.suppressors = suppressors

ISILSilencerConfig.applyRangeModifiers()
ISILSilencerConfig.applyDurabilityModifiers()

return ISILSilencerConfig
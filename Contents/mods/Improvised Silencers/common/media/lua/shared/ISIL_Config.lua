ISILSilencerConfig = ISILSilencerConfig or {}

local sandboxModule = "ImprovisedSilencers"

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

    return math.floor(getSandboxNumber(suppressor.durabilityOption, suppressor.durability, 0.0, 10000.0) + 0.5)
end

function ISILSilencerConfig.isInfiniteDurability(fullType)
    local durability = ISILSilencerConfig.getDurability(fullType)

    return durability ~= nil and durability <= 0
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
            if durability > 0 then
                scriptItem:DoParam("ConditionMax = " .. tostring(durability))
                scriptItem:DoParam("ConditionLowerChanceOneIn = 1")
                scriptItem:DoParam("UseDelta = " .. tostring(1 / durability))
            else
                scriptItem:DoParam("ConditionMax = " .. tostring(suppressor.durability))
                scriptItem:DoParam("UseDelta = 0")
            end
            scriptItem:DoParam("UseWhileEquipped = false")
            scriptItem:DoParam("Tags = " .. suppressor.tags)
        end
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

    if durability <= 0 then
        local defaultDurability = suppressors[fullType].durability

        if item.setConditionMax then
            item:setConditionMax(defaultDurability)
        end

        if item.setCondition then
            item:setCondition(defaultDurability)
        end

        return
    end

    local currentCondition = item.getCondition and item:getCondition() or durability
    local currentMax = item.getConditionMax and item:getConditionMax() or durability

    if item.setConditionMax then
        item:setConditionMax(durability)
    end

    if item.setCondition then
        if currentCondition <= 0 then
            item:setCondition(0)
        elseif currentCondition >= currentMax then
            item:setCondition(durability)
        elseif currentCondition > durability then
            item:setCondition(durability)
        end
    end

end

ISILSilencerConfig.suppressors = suppressors

ISILSilencerConfig.applyRangeModifiers()
ISILSilencerConfig.applyDurabilityModifiers()

return ISILSilencerConfig
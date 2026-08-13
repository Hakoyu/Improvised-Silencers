ISILSilencerConfig = ISILSilencerConfig or {}

local sandboxModule = "ImprovisedSilencers"

local suppressors = {
    ["Base.Silencer"] = {
        soundOption = "SilencerSoundReduction",
        rangeOption = "SilencerRangeReduction",
        soundReduction = 80.0,
        rangeReduction = 0.8,
        swingSound = "SilencedShot",
    },
    ["Base.MetalPipeSilencer"] = {
        soundOption = "MetalPipeSilencerSoundReduction",
        rangeOption = "MetalPipeSilencerRangeReduction",
        soundReduction = 60.0,
        rangeReduction = 1.0,
        swingSound = "CraftedSuppressedShot",
    },
    ["Base.TorchSilencer"] = {
        soundOption = "TorchSilencerSoundReduction",
        rangeOption = "TorchSilencerRangeReduction",
        soundReduction = 40.0,
        rangeReduction = 2.0,
        swingSound = "CraftedSuppressedShot",
    },
    ["Base.WaterBottleSilencer"] = {
        soundOption = "WaterBottleSilencerSoundReduction",
        rangeOption = "WaterBottleSilencerRangeReduction",
        soundReduction = 20.0,
        rangeReduction = 2.0,
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

ISILSilencerConfig.suppressors = suppressors

ISILSilencerConfig.applyRangeModifiers()

return ISILSilencerConfig
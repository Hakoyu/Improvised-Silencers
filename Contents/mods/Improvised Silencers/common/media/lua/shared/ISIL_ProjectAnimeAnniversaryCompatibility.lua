-- Optional Project Anime Anniversary compatibility for Build 42.
--
-- Project Anime Anniversary defines its own Canon-slot suppressors for some of
-- its firearms.  This patch adds the Improvised Silencers parts to its firearms
-- without editing the Workshop mod directly.

if not getActivatedMods():contains("ProjectAnimeAnniversaryStable") then
    return
end

local ISIL_PAA_MODEL_PARTS = {
    pistol = {
        "ModelWeaponPart = Base.PA_SuppressorSmall Base.Silencer muzzle muzzle",
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencer muzzle muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencer muzzle muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencer muzzle muzzle",
    },
    shotgun = {
        "ModelWeaponPart = Base.PA_SuppressorLarge Base.SilencerBig muzzle muzzle",
        "ModelWeaponPart = Base.Silencer Base.SilencerBig muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerBig muzzle muzzle",
    },
    rifle = {
        "ModelWeaponPart = Base.PA_SuppressorSmall Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.PA_SuppressorLarge Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencerRifle muzzle muzzle",
    },
}

local ISIL_PAA_WEAPONS = {
    -- Project Anime Anniversary firearms with muzzle attachment points.
    { fullType = "Base.PA_SMGC01s", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_PistolC01p", family = "pistol", allowImprovised = true },
    { fullType = "Base.PA_AssaultrifleC01r", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_SMGC01sLilies", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_ShotgunCSPhantom", family = "shotgun", allowImprovised = false },
    { fullType = "Base.PA_RifleCSStalker", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_CarbineH02c", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_PlasmaMachineGunH04m", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_PlasmaPistolH04p", family = "pistol", allowImprovised = true },
    { fullType = "Base.PA_RailgunH02r", family = "rifle", allowImprovised = true },
    { fullType = "Base.PA_RevolverCSMini", family = "pistol", allowImprovised = true },
}

local function ISIL_PAA_createItem(fullType)
    local ok, item = pcall(instanceItem, fullType)
    return ok and item or nil
end

local function ISIL_PAA_appendMountOn(attachmentFullType, weaponTypes)
    local scriptItem = getScriptManager():getItem(attachmentFullType)
    local attachment = ISIL_PAA_createItem(attachmentFullType)

    if not scriptItem or not attachment or not instanceof(attachment, "WeaponPart") then
        return false
    end

    local combined = {}
    local seen = {}
    local currentMountOn = attachment:getMountOn()

    if currentMountOn then
        for i = 0, currentMountOn:size() - 1 do
            local fullType = currentMountOn:get(i)

            if fullType and not seen[fullType] then
                seen[fullType] = true
                table.insert(combined, fullType)
            end
        end
    end

    for _, fullType in ipairs(weaponTypes) do
        if not seen[fullType] then
            seen[fullType] = true
            table.insert(combined, fullType)
        end
    end

    scriptItem:DoParam("MountOn = " .. table.concat(combined, ";"))
    return true
end

local function ISIL_PAA_addModels(weaponTypes)
    for _, weaponData in ipairs(weaponTypes) do
        local scriptItem = getScriptManager():getItem(weaponData.fullType)
        local weapon = ISIL_PAA_createItem(weaponData.fullType)

        if scriptItem and weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged() then
            for _, parameter in ipairs(ISIL_PAA_MODEL_PARTS[weaponData.family]) do
                scriptItem:DoParam(parameter)
            end
        end
    end
end

local paaWeapons = {}
local paaNonShotguns = {}

for _, weaponData in ipairs(ISIL_PAA_WEAPONS) do
    local scriptItem = getScriptManager():getItem(weaponData.fullType)
    local weapon = ISIL_PAA_createItem(weaponData.fullType)

    if scriptItem and weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged() then
        table.insert(paaWeapons, weaponData.fullType)

        if weaponData.allowImprovised then
            table.insert(paaNonShotguns, weaponData.fullType)
        end
    end
end

if #paaWeapons > 0 then
    ISIL_PAA_appendMountOn("Base.PA_SuppressorSmall", paaNonShotguns)
    ISIL_PAA_appendMountOn("Base.PA_SuppressorLarge", paaWeapons)
    ISIL_PAA_appendMountOn("Base.Silencer", paaWeapons)
    ISIL_PAA_appendMountOn("Base.MetalPipeSilencer", paaWeapons)
    ISIL_PAA_appendMountOn("Base.TorchSilencer", paaNonShotguns)
    ISIL_PAA_appendMountOn("Base.WaterBottleSilencer", paaNonShotguns)

    ISIL_PAA_addModels(ISIL_PAA_WEAPONS)
    print("[Improvised Silencers] Added Project Anime Anniversary compatibility for " .. #paaWeapons .. " weapons.")
end
-- Optional Vanilla Firearms Expansion [CLASSIC] compatibility for Build 42.

if not getActivatedMods():contains("VFExpansion1") then
    return
end

local configLoaded = pcall(require, "Config/VFE_ConfigData")

if not configLoaded or not VFExpansion or not VFExpansion.WEAPONS
    or not VFExpansion.WEAPONS.VFE then
    print("[Improvised Silencers] WARN: Vanilla Firearms Expansion weapon data could not be loaded.")
    return
end

local ISIL_VFE_EXCLUDED = {
    -- These weapons already have an integral suppressor.
    MP5SD = true,
    MK2SD = true,
    MK23SOCOM = true,
    ShotgunSilent = true,
    CAR15D = true,
    CAR15DFolded = true,

    -- These special weapon states are not suitable for a muzzle attachment.
    AssaultRifleMasterkey = true,
    AssaultRifleMasterkeyShotgun = true,
    M60MMG = true,
    M60MMG_Bipod = true,
}

local ISIL_VFE_MODEL_PARTS = {
    pistol = {
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencer muzzle muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencer muzzle muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencer muzzle muzzle",
    },
    shotgun = {
        "ModelWeaponPart = Base.Silencer Base.SilencerBig muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerBig muzzle muzzle",
    },
    rifle = {
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencerRifle muzzle muzzle",
    },
}

local function ISIL_VFE_createItem(fullType)
    local ok, item = pcall(instanceItem, fullType)
    return ok and item or nil
end

local function ISIL_VFE_appendMountOn(attachmentFullType, weaponTypes)
    local scriptItem = getScriptManager():getItem(attachmentFullType)
    local attachment = ISIL_VFE_createItem(attachmentFullType)

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

local function ISIL_VFE_modelFamily(itemId, weapon)
    local weaponClass = VFExpansion.WEAPON_CLASS and VFExpansion.WEAPON_CLASS[itemId]

    if weaponClass == "shotgun" or weaponClass == "autoshotgun" then
        return "shotgun"
    end

    if weaponClass == "pistol" or weaponClass == "smg" then
        return "pistol"
    end

    local reloadType = string.lower(tostring(weapon:getWeaponReloadType() or ""))
    local ammoType = string.lower(tostring(weapon:getAmmoType() or ""))

    if reloadType == "handgun" or reloadType == "revolver" then
        return "pistol"
    end

    if string.find(reloadType, "shotgun", 1, true)
        or string.find(ammoType, "shotgun_shells", 1, true) then
        return "shotgun"
    end

    return "rifle"
end

local vfeWeapons = {}
local vfeNonShotguns = {}
local familyCounts = { pistol = 0, shotgun = 0, rifle = 0 }
ISILVFEWeaponTypes = ISILVFEWeaponTypes or {}

for _, itemId in ipairs(VFExpansion.WEAPONS.VFE) do
    if not ISIL_VFE_EXCLUDED[itemId] then
        local fullType = "Base." .. itemId
        local scriptItem = getScriptManager():getItem(fullType)
        local weapon = ISIL_VFE_createItem(fullType)

        if scriptItem and weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged() then
            local modelFamily = ISIL_VFE_modelFamily(itemId, weapon)

            for _, parameter in ipairs(ISIL_VFE_MODEL_PARTS[modelFamily]) do
                scriptItem:DoParam(parameter)
            end

            table.insert(vfeWeapons, fullType)
            ISILVFEWeaponTypes[fullType] = true
            familyCounts[modelFamily] = familyCounts[modelFamily] + 1

            if modelFamily ~= "shotgun" then
                table.insert(vfeNonShotguns, fullType)
            end
        end
    end
end

if #vfeWeapons > 0 then
    ISIL_VFE_appendMountOn("Base.Silencer", vfeWeapons)
    ISIL_VFE_appendMountOn("Base.MetalPipeSilencer", vfeWeapons)
    ISIL_VFE_appendMountOn("Base.TorchSilencer", vfeNonShotguns)
    ISIL_VFE_appendMountOn("Base.WaterBottleSilencer", vfeNonShotguns)

    print("[Improvised Silencers] Added Vanilla Firearms Expansion compatibility for "
        .. #vfeWeapons .. " weapons (" .. familyCounts.pistol .. " pistol/SMG, "
        .. familyCounts.shotgun .. " shotgun, " .. familyCounts.rifle .. " rifle/carbine).")
end

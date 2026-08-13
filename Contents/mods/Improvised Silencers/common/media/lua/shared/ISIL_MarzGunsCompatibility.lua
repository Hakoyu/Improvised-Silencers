-- Automatic Guns of Marz compatibility for Build 42.
--
-- Guns of Marz already declares which weapons accept parts in the Canon
-- (muzzle) slot. Reusing those lists keeps this patch compatible with future
-- GoM updates without hard-coding every weapon ID here. GoM shotguns use a
-- model-level muzzle attachment instead, so they are discovered separately.

local ISIL_MARZ_MODULE = "MarzGuns"

local ISIL_MODEL_PARTS = {
    pistol = {
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle canon muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencer canon muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencer canon muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencer canon muzzle",
    },
    shotgun = {
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle muzzle muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerRifle muzzle muzzle",
    },
    rifle = {
        "ModelWeaponPart = Base.Silencer Base.SilencerRifle canon muzzle",
        "ModelWeaponPart = Base.MetalPipeSilencer Base.MetalPipeSilencerRifle canon muzzle",
        "ModelWeaponPart = Base.TorchSilencer Base.TorchSilencerRifle canon muzzle",
        "ModelWeaponPart = Base.WaterBottleSilencer Base.WaterBottleSilencerRifle canon muzzle",
    },
}

local function ISIL_createItem(fullType)
    local ok, item = pcall(function()
        return instanceItem(fullType)
    end)

    if ok then
        return item
    end

    return nil
end

local function ISIL_registerGunworksStats()
    local okCSA, customStats = pcall(require, "WeaponSystems/Utils/CustomStatsAttachments")
    local okSF, statsFactory = pcall(require, "WeaponSystems/Utils/StatsFactory")

    if not okCSA or not okSF or not customStats or not statsFactory then
        print("[Improvised Silencers] WARN: Gunworks stats integration could not be loaded.")
        return false
    end

    customStats.RegisterRestoreStats({
        "SoundRadius",
        "SoundVolume",
        "SwingSound",
        "MuzzleFlashModelKey",
    })

    customStats.RegisterMultipleParts({
        ["Base.Silencer"] = {
            statsFactory.Multiply("SoundRadius", 0.20),
            statsFactory.Multiply("SoundVolume", 0.30),
            statsFactory.Set("SwingSound", "SilencedShot"),
            statsFactory.Set("MuzzleFlashModelKey", nil),
        },
        ["Base.MetalPipeSilencer"] = {
            statsFactory.Multiply("SoundRadius", 0.40),
            statsFactory.Multiply("SoundVolume", 0.50),
            statsFactory.Set("SwingSound", "CraftedSuppressedShot"),
            statsFactory.Set("MuzzleFlashModelKey", nil),
        },
        ["Base.TorchSilencer"] = {
            statsFactory.Multiply("SoundRadius", 0.60),
            statsFactory.Multiply("SoundVolume", 0.70),
            statsFactory.Set("SwingSound", "CraftedSuppressedShot"),
            statsFactory.Set("MuzzleFlashModelKey", nil),
        },
        ["Base.WaterBottleSilencer"] = {
            statsFactory.Multiply("SoundRadius", 0.80),
            statsFactory.Multiply("SoundVolume", 0.80),
            statsFactory.Set("SwingSound", "CraftedSuppressedShot"),
            statsFactory.Set("MuzzleFlashModelKey", nil),
        },
    })

    return true
end

local function ISIL_getMarzMuzzleWeapons()
    local result = {}
    local seen = {}
    local scriptManager = getScriptManager()
    local allItems = scriptManager and scriptManager:getAllItems() or nil

    if not allItems then
        return result
    end

    -- Read every GoM Canon part rather than relying on suppressor names. This
    -- includes weapons supported by suppressors, compensators and muzzle brakes.
    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)

        if scriptItem and scriptItem:getModuleName() == ISIL_MARZ_MODULE then
            local part = ISIL_createItem(scriptItem:getFullName())

            if part and instanceof(part, "WeaponPart") and part:getPartType() == "Canon" then
                local mountOn = part:getMountOn()

                if mountOn then
                    for mountIndex = 0, mountOn:size() - 1 do
                        local weaponFullType = mountOn:get(mountIndex)

                        if weaponFullType and not seen[weaponFullType] then
                            local weapon = ISIL_createItem(weaponFullType)

                            if weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged() then
                                seen[weaponFullType] = true
                                table.insert(result, weaponFullType)
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(result)
    return result
end

local function ISIL_appendMountOn(attachmentFullType, weaponTypes)
    local scriptItem = getScriptManager():getItem(attachmentFullType)
    local attachment = ISIL_createItem(attachmentFullType)

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

local function ISIL_getModelFamily(weapon)
    local reloadType = string.lower(tostring(weapon:getWeaponReloadType() or ""))
    local ammoType = string.lower(tostring(weapon:getAmmoType() or ""))

    if reloadType == "handgun" or reloadType == "revolver" then
        return "pistol"
    end

    if string.find(reloadType, "shotgun", 1, true)
        or string.find(ammoType, "shell_12g", 1, true) then
        return "shotgun"
    end

    return "rifle"
end

local function ISIL_addMarzShotguns(weaponTypes)
    local seen = {}

    for _, fullType in ipairs(weaponTypes) do
        seen[fullType] = true
    end

    local scriptManager = getScriptManager()
    local allItems = scriptManager and scriptManager:getAllItems() or nil

    if not allItems then
        return 0
    end

    local added = 0

    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)

        if scriptItem and scriptItem:getModuleName() == ISIL_MARZ_MODULE then
            local fullType = scriptItem:getFullName()

            if fullType and not seen[fullType] then
                local weapon = ISIL_createItem(fullType)
                local ammoType = weapon and string.lower(tostring(weapon:getAmmoType() or "")) or ""

                if weapon and instanceof(weapon, "HandWeapon") and weapon:isRanged()
                    and string.find(ammoType, "shell_12g", 1, true) then
                    seen[fullType] = true
                    table.insert(weaponTypes, fullType)
                    added = added + 1
                end
            end
        end
    end

    table.sort(weaponTypes)
    return added
end

local function ISIL_addMarzModels(weaponTypes)
    for _, fullType in ipairs(weaponTypes) do
        local scriptItem = getScriptManager():getItem(fullType)
        local weapon = ISIL_createItem(fullType)

        if scriptItem and weapon then
            local modelFamily = ISIL_getModelFamily(weapon)

            for _, parameter in ipairs(ISIL_MODEL_PARTS[modelFamily]) do
                scriptItem:DoParam(parameter)
            end
        end
    end
end

local marzWeapons = ISIL_getMarzMuzzleWeapons()
local marzShotgunsAdded = ISIL_addMarzShotguns(marzWeapons)

if #marzWeapons > 0 then
    ISIL_registerGunworksStats()

    local marzNonShotguns = {}

    for _, weaponFullType in ipairs(marzWeapons) do
        local weapon = ISIL_createItem(weaponFullType)

        if weapon and ISIL_getModelFamily(weapon) ~= "shotgun" then
            table.insert(marzNonShotguns, weaponFullType)
        end
    end

    ISIL_appendMountOn("Base.Silencer", marzWeapons)
    ISIL_appendMountOn("Base.MetalPipeSilencer", marzWeapons)
    ISIL_appendMountOn("Base.TorchSilencer", marzNonShotguns)
    ISIL_appendMountOn("Base.WaterBottleSilencer", marzNonShotguns)

    ISIL_addMarzModels(marzWeapons)
    print("[Improvised Silencers] Added Guns of Marz compatibility for " .. #marzWeapons
        .. " weapons (including " .. marzShotgunsAdded .. " separately detected shotguns).")
end

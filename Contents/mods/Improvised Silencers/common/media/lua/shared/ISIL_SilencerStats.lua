require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"
require "ISIL_Config"

ISILSilencerStats = ISILSilencerStats or {}

local appliedStateKey = "ISILSuppressorStatsApplied"

local function getWorkingSuppressor(weapon)
    if not weapon then
        return nil
    end

    local canon = weapon:getWeaponPart("Canon")
    if not canon or not ISILSilencerConfig.getEffect(canon:getFullType()) then
        return nil
    end

    if canon.getCondition and canon:getCondition() <= 0 then
        return nil
    end

    return canon
end

local function makeUnsuppressedCopy(weapon)
    local copy = instanceItem(weapon:getFullType())
    if not copy or not instanceof(copy, "HandWeapon") then
        return nil
    end

    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part and not ISILSilencerConfig.isSuppressor(part:getFullType()) then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    if copy.canAttachWeaponPart == nil or copy:canAttachWeaponPart(partCopy) then
                        copy:attachWeaponPart(partCopy)
                    end
                end
            end
        end
    end

    return copy
end

function ISILSilencerStats.apply(weapon, forceRestore)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    local canon = weapon:getWeaponPart("Canon")
    if canon then
        ISILSilencerConfig.applyItemDurability(canon)
    end
    local isOurSuppressor = canon and ISILSilencerConfig.isSuppressor(canon:getFullType())
    local effect = isOurSuppressor and ISILSilencerConfig.getEffect(canon:getFullType()) or nil
    if effect and canon.getCondition and canon:getCondition() <= 0 then
        effect = nil
    end
    local modData = weapon:getModData()
    local wasApplied = modData and modData[appliedStateKey] == true

    -- Other mods may use the Canon slot and apply their own custom statistics.
    -- Never overwrite those values. This is especially important for native
    -- Guns of Marz suppressors, whose effects are managed by Gunworks.
    if canon and not isOurSuppressor then
        if modData then
            modData[appliedStateKey] = nil
        end
        return
    end

    -- Do not rebuild unrelated ranged weapons on equip. Only restore a weapon
    -- that was previously modified by this mod, or when one of our suppressors
    -- has just been removed.
    if not effect and not wasApplied and not forceRestore then
        return
    end

    local baseWeapon = makeUnsuppressedCopy(weapon)
    if not baseWeapon then
        return
    end

    local preserveWeaponSound = ISILVFEWeaponTypes and ISILVFEWeaponTypes[weapon:getFullType()]

    weapon:setSoundRadius(baseWeapon:getSoundRadius())
    weapon:setSoundVolume(baseWeapon:getSoundVolume())
    weapon:setMaxRange(baseWeapon:getMaxRange())
    weapon:setSwingSound(baseWeapon:getSwingSound())
    weapon:setMuzzleFlashModelKey(baseWeapon:getMuzzleFlashModelKey())

    if effect then
        weapon:setSoundRadius(baseWeapon:getSoundRadius() * effect.soundRadius)
        weapon:setSoundVolume(baseWeapon:getSoundVolume() * effect.soundVolume)
        weapon:setMaxRange(math.max(0.0, baseWeapon:getMaxRange() + effect.maxRangeModifier))
        if not preserveWeaponSound then
            weapon:setSwingSound(effect.swingSound)
        end
        weapon:setMuzzleFlashModelKey(nil)
        if modData then
            modData[appliedStateKey] = true
        end
    elseif modData then
        modData[appliedStateKey] = nil
    end
end

-- Build 42 may refresh the equipped weapon instance back to its script defaults
-- after the upgrade/equip hooks have already run.  When that happens the custom
-- SwingSound can remain noticeable to the player, but the SoundRadius used by
-- the world sound / zombie attraction system is no longer reduced.  Keep the
-- live equipped instance in sync from the script defaults, like the working B42
-- suppressor implementation in Project Anime Anniversary.
function ISILSilencerStats.applyLiveSound(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    local scriptItem = weapon:getScriptItem()
    if not scriptItem then
        return
    end

    local canon = weapon:getWeaponPart("Canon")
    if canon then
        ISILSilencerConfig.applyItemDurability(canon)
    end
    local isOurSuppressor = canon and ISILSilencerConfig.isSuppressor(canon:getFullType())
    local effect = isOurSuppressor and ISILSilencerConfig.getEffect(canon:getFullType()) or nil
    if effect and canon.getCondition and canon:getCondition() <= 0 then
        effect = nil
    end
    local modData = weapon:getModData()
    local wasApplied = modData and modData[appliedStateKey] == true

    -- Do not touch other Canon attachments handled by other mods.
    if canon and not isOurSuppressor then
        return
    end

    local soundRadius = scriptItem:getSoundRadius()
    local soundVolume = scriptItem:getSoundVolume()
    local swingSound = scriptItem:getSwingSound()
    local preserveWeaponSound = ISILVFEWeaponTypes and ISILVFEWeaponTypes[weapon:getFullType()]

    if effect then
        weapon:setSoundRadius(soundRadius * effect.soundRadius)
        weapon:setSoundVolume(soundVolume * effect.soundVolume)
        if not preserveWeaponSound then
            weapon:setSwingSound(effect.swingSound)
        end
        weapon:setMuzzleFlashModelKey(nil)
        if modData then
            modData[appliedStateKey] = true
        end
    elseif wasApplied then
        weapon:setSoundRadius(soundRadius)
        weapon:setSoundVolume(soundVolume)
        weapon:setSwingSound(swingSound)
        if modData then
            modData[appliedStateKey] = nil
        end
    end
end

local function reEquipWeapon(character, weapon)
    if not character or not weapon then
        return
    end

    character:setPrimaryHandItem(weapon)
    character:setSecondaryHandItem(weapon:isTwoHandWeapon() and weapon or nil)
    character:resetEquippedHandsModels()
end

local originalUpgradeComplete = ISUpgradeWeapon.complete
function ISUpgradeWeapon:complete()
    ISILSilencerConfig.applyRangeModifiers()
    local isOurSuppressor = self.part and ISILSilencerConfig.isSuppressor(self.part:getFullType())
    local result = originalUpgradeComplete(self)
    ISILSilencerStats.apply(self.weapon)
    if self.character and self.weapon then
        if syncHandWeaponFields then
            syncHandWeaponFields(self.character, self.weapon)
        end
    end
    if isOurSuppressor then
        reEquipWeapon(self.character, self.weapon)
    end
    return result
end

local originalRemoveComplete = ISRemoveWeaponUpgrade.complete
function ISRemoveWeaponUpgrade:complete()
    local removedPart = self.weapon and self.partType and self.weapon:getWeaponPart(self.partType) or nil
    local isOurSuppressor = removedPart and ISILSilencerConfig.isSuppressor(removedPart:getFullType())
    local result = originalRemoveComplete(self)
    ISILSilencerStats.apply(self.weapon, isOurSuppressor)
    if self.character and self.weapon then
        if syncHandWeaponFields then
            syncHandWeaponFields(self.character, self.weapon)
        end
    end
    if isOurSuppressor then
        reEquipWeapon(self.character, self.weapon)
    end
    return result
end

local function onEquipPrimary(character, item)
    ISILSilencerStats.apply(item)
end

function ISILSilencerStats.getWorkingSuppressor(weapon)
    return getWorkingSuppressor(weapon)
end

local function onGameStart()
    local player = getPlayer()
    if player then
        ISILSilencerStats.apply(player:getPrimaryHandItem())
    end
end

Events.OnEquipPrimary.Add(onEquipPrimary)
Events.OnGameStart.Add(onGameStart)

require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"
require "ISIL_Config"

ISILSilencerStats = ISILSilencerStats or {}

local appliedStateKey = "ISILSuppressorStatsApplied"

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
    local effect = canon and ISILSilencerConfig.getEffect(canon:getFullType()) or nil
    local modData = weapon:getModData()
    local wasApplied = modData and modData[appliedStateKey] == true

    -- Other mods may use the Canon slot and apply their own custom statistics.
    -- Never overwrite those values. This is especially important for native
    -- Guns of Marz suppressors, whose effects are managed by Gunworks.
    if canon and not effect then
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
        syncHandWeaponFields(self.character, self.weapon)
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
        syncHandWeaponFields(self.character, self.weapon)
    end
    if isOurSuppressor then
        reEquipWeapon(self.character, self.weapon)
    end
    return result
end

local function onEquipPrimary(character, item)
    ISILSilencerStats.apply(item)
end

local function onGameStart()
    local player = getPlayer()
    if player then
        ISILSilencerStats.apply(player:getPrimaryHandItem())
    end
end

Events.OnEquipPrimary.Add(onEquipPrimary)
Events.OnGameStart.Add(onGameStart)

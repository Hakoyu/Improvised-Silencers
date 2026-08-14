require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"
require "ISIL_SilencerStats"
require "ISIL_Config"

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

local function onGameStart()
    local player = getPlayer()
    if player then
        ISILSilencerStats.apply(player:getPrimaryHandItem())
    end
end

Events.OnEquipPrimary.Add(onEquipPrimary)
Events.OnGameStart.Add(onGameStart)
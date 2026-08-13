require "ISIL_SilencerStats"
require "ISIL_Config"

local brokenSound = "Damaged"

local function playBrokenSound(character)
    if character and character.playSound then
        character:playSound(brokenSound)
    elseif getSoundManager then
        getSoundManager():PlayWorldSound(brokenSound, false, 0, 0, 0, 10, 1.0, true)
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

local function removeBrokenSuppressor(character, weapon, suppressor)
    if not weapon or not suppressor then
        return false
    end

    if weapon.detachWeaponPart then
        weapon:detachWeaponPart(suppressor)
    elseif weapon.setWeaponPart then
        weapon:setWeaponPart("Canon", nil)
    else
        return false
    end

    ISILSilencerStats.apply(weapon, true)

    if character then
        if syncHandWeaponFields then
            syncHandWeaponFields(character, weapon)
        end

        reEquipWeapon(character, weapon)
    end

    return true
end

local function damageSuppressor(character, weapon)
    local suppressor = ISILSilencerStats.getWorkingSuppressor(weapon)
    if not suppressor or not suppressor.getCondition or not suppressor.setCondition then
        return
    end

    ISILSilencerConfig.applyItemDurability(suppressor)

    if ISILSilencerConfig.isInfiniteDurability(suppressor:getFullType()) then
        return
    end

    local condition = suppressor:getCondition()
    if condition <= 0 then
        return
    end

    suppressor:setCondition(math.max(0, condition - 1))

    if suppressor:getCondition() <= 0 then
        playBrokenSound(character)

        if not ISILSilencerConfig.keepBrokenSilencers() and removeBrokenSuppressor(character, weapon, suppressor) then
            return
        end

        ISILSilencerStats.apply(weapon, true)
    end
end

local function onWeaponSwing(character, weapon)
    if not character or not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    damageSuppressor(character, weapon)
end

Events.OnWeaponSwing.Add(onWeaponSwing)
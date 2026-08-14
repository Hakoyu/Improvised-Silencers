require "ISIL_SilencerStats"
require "ISIL_Config"

local brokenSound = "Damaged"
local commandModule = "ImprovisedSilencers"
local damageSuppressorCommand = "DamageSuppressor"
local suppressorBrokenCommand = "SuppressorBroken"
local lastBrokenSoundTime = 0
local brokenSoundCooldownMs = 750

local function playBrokenSound(character)
    -- Match the sound playback style used by Harks Horde Night Revamp's
    -- RoundChange sound. In multiplayer, character:playSound() can be
    -- unreliable for this client-only feedback sound, while PlaySound() plays
    -- directly for the local client.
    if getSoundManager then
        getSoundManager():PlaySound(brokenSound, false, 0)
    elseif character and character.playSound then
        character:playSound(brokenSound)
    end
end

local function getNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end

    return os.time() * 1000
end

local function playBrokenSoundOnce(character)
    local now = getNowMs()
    if now - lastBrokenSoundTime < brokenSoundCooldownMs then
        return
    end

    lastBrokenSoundTime = now
    playBrokenSound(character)
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

local function hasLoadedRoundToFire(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return false
    end

    -- OnWeaponSwing is also fired by empty trigger pulls.  Only spend silencer
    -- durability when the gun can actually fire a live round.
    if weapon.isJammed and weapon:isJammed() then
        return false
    end

    if weapon.haveChamber and weapon:haveChamber() then
        if not weapon.isRoundChambered or not weapon:isRoundChambered() then
            return false
        end

        if weapon.isSpentRoundChambered and weapon:isSpentRoundChambered() then
            return false
        end

        return true
    end

    if weapon.getCurrentAmmoCount then
        local ammoPerShot = weapon.getAmmoPerShoot and weapon:getAmmoPerShoot() or 1
        if ammoPerShot < 1 then
            ammoPerShot = 1
        end

        return weapon:getCurrentAmmoCount() >= ammoPerShot
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

    local condition = ISILSilencerConfig.getItemDurability(suppressor) or suppressor:getCondition()
    if condition <= 0 then
        return
    end

    ISILSilencerConfig.setItemDurability(suppressor, math.max(0, condition - 1))

    if (ISILSilencerConfig.getItemDurability(suppressor) or suppressor:getCondition()) <= 0 then
        playBrokenSoundOnce(character)

        if not ISILSilencerConfig.keepBrokenSilencers() and removeBrokenSuppressor(character, weapon, suppressor) then
            return
        end

        ISILSilencerStats.apply(weapon, true)
    end
end

local function requestServerDamageSuppressor(character, weapon)
    if not isClient or not isClient() then
        return
    end

    if not character or not weapon then
        return
    end

    if character.isLocalPlayer and not character:isLocalPlayer() then
        return
    end

    local suppressor = ISILSilencerStats.getWorkingSuppressor(weapon)
    if not suppressor or not suppressor.getFullType then
        return
    end

    sendClientCommand(character, commandModule, damageSuppressorCommand, {
        weaponFullType = weapon:getFullType(),
        suppressorFullType = suppressor:getFullType(),
    })
end

local function onWeaponSwing(character, weapon)
    if not character or not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    if not hasLoadedRoundToFire(weapon) then
        return
    end

    requestServerDamageSuppressor(character, weapon)
    damageSuppressor(character, weapon)
end

local function onServerCommand(module, command, args)
    if module ~= commandModule or command ~= suppressorBrokenCommand then
        return
    end

    local player = getSpecificPlayer(0) or getPlayer()
    playBrokenSoundOnce(player)
end

Events.OnWeaponSwing.Add(onWeaponSwing)
Events.OnServerCommand.Add(onServerCommand)
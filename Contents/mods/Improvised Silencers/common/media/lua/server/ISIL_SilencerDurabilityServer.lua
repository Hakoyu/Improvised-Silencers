require "ISIL_SilencerStats"
require "ISIL_Config"

local commandModule = "ImprovisedSilencers"
local damageSuppressorCommand = "DamageSuppressor"
local suppressorBrokenCommand = "SuppressorBroken"

local function syncItem(item)
    if not item then
        return
    end

    if item.transmitModData then
        item:transmitModData()
    end

    if item.transmitCompleteItemToClients then
        item:transmitCompleteItemToClients()
    elseif item.transmitUpdatedItemToClients then
        item:transmitUpdatedItemToClients()
    end
end

local function syncWeapon(playerObj, weapon)
    syncItem(weapon)

    if playerObj and weapon and syncHandWeaponFields then
        syncHandWeaponFields(playerObj, weapon)
    end
end

local function removeBrokenSuppressor(playerObj, weapon, suppressor)
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
    syncItem(suppressor)
    syncWeapon(playerObj, weapon)

    return true
end

local function hasLoadedRoundToFire(weapon)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return false
    end

    -- Client OnWeaponSwing can be raised by an empty trigger pull; keep the
    -- server authoritative and refuse to damage the suppressor unless a live
    -- round is actually ready to fire.
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

local function damageSuppressorOnServer(playerObj, args)
    if not playerObj then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    if not hasLoadedRoundToFire(weapon) then
        return
    end

    if args and args.weaponFullType and weapon:getFullType() ~= args.weaponFullType then
        return
    end

    local suppressor = ISILSilencerStats.getWorkingSuppressor(weapon)
    if not suppressor or not suppressor.getCondition or not suppressor.setCondition or not suppressor.getFullType then
        return
    end

    if args and args.suppressorFullType and suppressor:getFullType() ~= args.suppressorFullType then
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
    local newCondition = ISILSilencerConfig.getItemDurability(suppressor) or suppressor:getCondition()

    if newCondition <= 0 then
        sendServerCommand(playerObj, commandModule, suppressorBrokenCommand, {
            suppressorFullType = suppressor:getFullType(),
        })

        if not ISILSilencerConfig.keepBrokenSilencers() and removeBrokenSuppressor(playerObj, weapon, suppressor) then
            return
        end

        ISILSilencerStats.apply(weapon, true)
    end

    syncItem(suppressor)
    syncWeapon(playerObj, weapon)
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= commandModule or command ~= damageSuppressorCommand then
        return
    end

    damageSuppressorOnServer(playerObj, args or {})
end

Events.OnClientCommand.Add(onClientCommand)
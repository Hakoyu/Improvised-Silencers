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

local function damageSuppressorOnServer(playerObj, args)
    if not playerObj then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
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
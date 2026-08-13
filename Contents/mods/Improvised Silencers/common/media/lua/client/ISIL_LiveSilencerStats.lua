require "ISIL_SilencerStats"
require "ISIL_Config"

local updateTicks = 0
local updateInterval = 120

local syncInventoryDurability
local syncItemDurability

local function syncWeaponPartDurability(weapon)
    if not weapon or not weapon.getWeaponPart then
        return
    end

    local canon = weapon:getWeaponPart("Canon")
    if canon then
        syncItemDurability(canon)
    end
end

syncItemDurability = function(item)
    if not item then
        return
    end

    if item.getFullType and ISILSilencerConfig.isSuppressor(item:getFullType()) then
        ISILSilencerConfig.applyItemDurability(item)
    end

    syncWeaponPartDurability(item)

    if item.getInventory then
        syncInventoryDurability(item:getInventory())
    end
end

syncInventoryDurability = function(inventory)
    if not inventory or not inventory.getItems then
        return
    end

    local items = inventory:getItems()
    if not items then
        return
    end

    for i = 0, items:size() - 1 do
        syncItemDurability(items:get(i))
    end
end

local function syncPlayerSilencerDurability(player)
    if not player then
        return
    end

    syncItemDurability(player:getPrimaryHandItem())
    syncItemDurability(player:getSecondaryHandItem())

    if player.getInventory then
        syncInventoryDurability(player:getInventory())
    end
end

local function onPlayerUpdate(player)
    if not player then
        return
    end

    ISILSilencerStats.applyLiveSound(player:getPrimaryHandItem())

    updateTicks = updateTicks + 1
    if updateTicks >= updateInterval then
        updateTicks = 0
        syncPlayerSilencerDurability(player)
    end
end

local function onGameStart()
    ISILSilencerConfig.applyRangeModifiers()
    ISILSilencerConfig.applyDurabilityModifiers()

    local player = getSpecificPlayer(0) or getPlayer()
    if player then
        syncPlayerSilencerDurability(player)
        ISILSilencerStats.applyLiveSound(player:getPrimaryHandItem())
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnGameStart.Add(onGameStart)
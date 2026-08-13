require "ISIL_SilencerStats"
require "ISIL_Config"

local function damageSuppressor(weapon)
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
        ISILSilencerStats.apply(weapon, true)
    end
end

local function onWeaponSwing(character, weapon)
    if not character or not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    damageSuppressor(weapon)
end

Events.OnWeaponSwing.Add(onWeaponSwing)
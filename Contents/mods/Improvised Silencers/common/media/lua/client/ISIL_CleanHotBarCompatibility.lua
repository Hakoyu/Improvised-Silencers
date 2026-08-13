require "ISIL_Config"

local ISILCleanHotBarCompatibility = ISILCleanHotBarCompatibility or {}

local barBackground = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_BG_Right.png"),
}

local barFillTex = {
    Left = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Left.png"),
    Middle = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Middle.png"),
    Right = getTexture("media/ui/CleanHotBar/CleanHotbar_Bar_Fill_Right.png"),
}

local function getAttachedSilencer(item)
    if not item or not instanceof(item, "HandWeapon") or not item.getWeaponPart then
        return nil
    end

    local canon = item:getWeaponPart("Canon")
    if not canon or not canon.getFullType or not ISILSilencerConfig.isSuppressor(canon:getFullType()) then
        return nil
    end

    return canon
end

local function getSilencerConditionInfo(item)
    local silencer = getAttachedSilencer(item)
    if not silencer or not silencer.getCondition or not silencer.getConditionMax then
        return nil
    end

    ISILSilencerConfig.applyItemDurability(silencer)

    local condition = silencer:getCondition()
    local maxCondition = silencer:getConditionMax()
    if not condition or not maxCondition or maxCondition <= 0 then
        return nil
    end

    local ratio = math.max(0, math.min(1, condition / maxCondition))
    local r, g, b, a = 0.3, 0.7, 0.3, 0.85
    if ratio <= 1 / 3 then
        r, g, b, a = 0.8, 0.3, 0.3, 0.95
    elseif ratio <= 2 / 3 then
        r, g, b, a = 0.9, 0.8, 0.3, 0.9
    end

    return ratio, r, g, b, a
end

local function getAmmoBackgroundHeight()
    local config = CHBConfig and CHBConfig.getConfig and CHBConfig.getConfig() or {}
    local ammoTextScale = config.ammoTextScale or 0.8
    local baseHeight = 30

    if CHBCommonUnit and CHBCommonUnit.getTextureSize then
        local _, textureHeight = CHBCommonUnit.getTextureSize()
        baseHeight = textureHeight or baseHeight
    end

    local effectiveScale = ammoTextScale * (CHBCommonUnit and CHBCommonUnit.DEFAULT_SCALE_FACTOR or 0.65)
    local scaledHeight = baseHeight * effectiveScale
    local padding = 4

    return math.ceil(scaledHeight + padding * 2)
end

local function drawSilencerConditionBar(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    if not hotbar or not item or not slotX or not slotY or not slotWidth or not slotHeight then
        return
    end

    if not CHBCommonUnit or not CHBCommonUnit.drawThreeSliceBar or not CHBCommonUnit.drawThreeSliceBarFill then
        return
    end

    if not barBackground.Left or not barBackground.Middle or not barBackground.Right then
        return
    end

    if not barFillTex.Left or not barFillTex.Middle or not barFillTex.Right then
        return
    end

    local ratio, r, g, b, a = getSilencerConditionInfo(item)
    if not ratio then
        return
    end

    local config = CHBConfig and CHBConfig.getConfig and CHBConfig.getConfig() or {}
    local statusBarScale = config.statusBarHeightScale or 1.0
    local minBarHeight = math.max(3, math.floor(slotHeight / 12))
    local maxBarHeight = math.max(minBarHeight, math.floor(slotHeight / 6))
    local scaleFactor = (statusBarScale - 1.0) / 2.0
    local barHeight = math.floor(minBarHeight + (maxBarHeight - minBarHeight) * scaleFactor)
    barHeight = math.max(3, barHeight)

    local ammoBgHeight = getAmmoBackgroundHeight()
    local barMargin = 2
    local barInset = math.max(3, math.floor(slotWidth * 0.08))
    local barX = slotX + barInset
    local barY = math.floor(slotY - ammoBgHeight - barMargin - barHeight)
    local barWidth = math.max(1, slotWidth - barInset * 2)

    CHBCommonUnit.drawThreeSliceBar(hotbar, barX, barY, barWidth, barHeight, barBackground.Left, barBackground.Middle, barBackground.Right, 0.65, 0.35, 0.35, 0.35)
    CHBCommonUnit.drawThreeSliceBarFill(hotbar, barX, barY, barWidth, barHeight, ratio, barFillTex.Left, barFillTex.Middle, barFillTex.Right, a, r, g, b)
end

function ISILCleanHotBarCompatibility.patch()
    if ISILCleanHotBarCompatibility.patched then
        return
    end

    if not CleanHotbarWeaponState or not CleanHotbarWeaponState.renderWeaponState then
        return
    end

    if not CHBCommonUnit or not CHBConfig then
        return
    end

    local originalRenderWeaponState = CleanHotbarWeaponState.renderWeaponState
    CleanHotbarWeaponState.renderWeaponState = function(hotbar, item, slotX, slotY, slotWidth, slotHeight)
        originalRenderWeaponState(hotbar, item, slotX, slotY, slotWidth, slotHeight)
        drawSilencerConditionBar(hotbar, item, slotX, slotY, slotWidth, slotHeight)
    end

    ISILCleanHotBarCompatibility.patched = true
end

Events.OnGameStart.Add(ISILCleanHotBarCompatibility.patch)
Events.OnCreatePlayer.Add(ISILCleanHotBarCompatibility.patch)
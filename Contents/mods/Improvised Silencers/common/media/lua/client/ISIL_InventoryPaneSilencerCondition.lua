require "ISUI/ISInventoryPane"
require "ISIL_Config"

local originalDrawItemDetails = ISInventoryPane.drawItemDetails

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

local function getConditionText(item)
    if not item or not item.getCondition or not item.getConditionMax then
        return nil
    end

    local condition = ISILSilencerConfig.getItemDurability and ISILSilencerConfig.getItemDurability(item) or item:getCondition()
    local maxCondition = ISILSilencerConfig.getItemMaxDurability and ISILSilencerConfig.getItemMaxDurability(item) or item:getConditionMax()
    return getText("IGUI_ISIL_Silencer") .. ": " .. tostring(condition) .. "/" .. tostring(maxCondition)
end

local function drawSilencerCondition(self, item, y, xoff, yoff)
    local silencer = getAttachedSilencer(item)
    local conditionText = getConditionText(silencer)
    if not silencer or not conditionText then
        return
    end

    local top = self.headerHgt + y * self.itemHgt + yoff
    local text = getText("IGUI_invpanel_Condition") .. ":"
    local textWid = getTextManager():MeasureStringX(self.font, text)
    local weaponBarX = 40 + math.max(120, 30 + textWid + 20) + xoff
    local weaponBarW = self:getProgressBarWidth()
    local gap = 8
    local iconSize = math.max(12, math.min(18, self.itemHgt - 4))
    local iconX = weaponBarX + weaponBarW + gap
    local iconY = top + (self.itemHgt - iconSize) / 2
    local silencerTextX = iconX + iconSize + 5
    local silencerTextY = top + (self.itemHgt - getTextManager():getFontHeight(self.font)) / 2
    local silencerTextW = getTextManager():MeasureStringX(self.font, conditionText)
    local rightPadding = 8

    if self.width and silencerTextX + silencerTextW > self.width - rightPadding then
        return
    end

    local tex = silencer.getTex and silencer:getTex() or nil
    if tex then
        self:drawTextureScaled(tex, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    end

    self:drawText(conditionText, silencerTextX, silencerTextY, 0.8, 0.8, 0.8, 1, self.font)
end

function ISInventoryPane:drawItemDetails(item, y, xoff, yoff, red)
    originalDrawItemDetails(self, item, y, xoff, yoff, red)

    if item and instanceof(item, "HandWeapon") then
        drawSilencerCondition(self, item, y, xoff, yoff)
    end
end

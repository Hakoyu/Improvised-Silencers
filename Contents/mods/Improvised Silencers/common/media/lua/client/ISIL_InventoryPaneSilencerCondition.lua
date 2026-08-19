require "ISUI/ISToolTipInv"
require "ISIL_Config"

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

local function getConditionTooltipLine(item)
    if not item or not item.getCondition or not item.getConditionMax then
        return nil, nil
    end

    local condition = ISILSilencerConfig.getItemDurability and ISILSilencerConfig.getItemDurability(item) or item:getCondition()
    local maxCondition = ISILSilencerConfig.getItemMaxDurability and ISILSilencerConfig.getItemMaxDurability(item) or item:getConditionMax()
    local name = item.getDisplayName and item:getDisplayName() or getText("IGUI_ISIL_Silencer")

    return tostring(name) .. ":", tostring(condition) .. "/" .. tostring(maxCondition)
end

local function installSilencerConditionTooltipHook()
    if ISToolTipInv.ISIL_SilencerConditionTooltipHooked then
        return
    end

    ISToolTipInv.ISIL_SilencerConditionTooltipHooked = true
    local previousRender = ISToolTipInv.render

    function ISToolTipInv:render(...)
        local silencer = getAttachedSilencer(self.item)
        local conditionLabel, conditionValue = getConditionTooltipLine(silencer)
        if not silencer or not conditionLabel or not conditionValue or not self.tooltip then
            return previousRender(self, ...)
        end

        local font = UIFont[getCore():getOptionTooltipFont()]
        local textManager = getTextManager()
        local lineSpacing = self.tooltip:getLineSpacing()
        local paddingX = 7
        local labelWidth = textManager:MeasureStringX(font, conditionLabel)
        local valueWidth = textManager:MeasureStringX(font, conditionValue)
        local requiredWidth = labelWidth + valueWidth + paddingX * 3
        local baseTooltipHeight = nil
        local tooltipWidth = nil

        local originalSetHeight = self.setHeight
        local originalSetWidth = self.setWidth
        local originalDrawRectBorder = self.drawRectBorder

        self.setHeight = function(panel, height, ...)
            baseTooltipHeight = height
            return originalSetHeight(panel, height + lineSpacing, ...)
        end

        self.setWidth = function(panel, width, ...)
            tooltipWidth = math.max(width, requiredWidth)
            return originalSetWidth(panel, tooltipWidth, ...)
        end

        self.drawRectBorder = function(panel, ...)
            local drawHeight = baseTooltipHeight or math.max(0, (panel.height or 0) - lineSpacing)
            local drawWidth = tooltipWidth or math.max(panel.width or 0, requiredWidth)

            self.tooltip:DrawText(font, conditionLabel, paddingX, drawHeight - 3, 0.95, 0.95, 0.75, 1)
            self.tooltip:DrawText(font, conditionValue, drawWidth - valueWidth - paddingX, drawHeight - 3, 1, 1, 1, 1)

            return originalDrawRectBorder(panel, ...)
        end

        local success, result = pcall(previousRender, self, ...)

        self.setHeight = originalSetHeight
        self.setWidth = originalSetWidth
        self.drawRectBorder = originalDrawRectBorder

        if not success then
            error(result)
        end

        return result
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(installSilencerConditionTooltipHook)
else
    installSilencerConditionTooltipHook()
end

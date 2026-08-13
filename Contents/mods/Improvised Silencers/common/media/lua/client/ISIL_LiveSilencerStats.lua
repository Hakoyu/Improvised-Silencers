require "ISIL_SilencerStats"

local function onPlayerUpdate(player)
    if not player then
        return
    end

    ISILSilencerStats.applyLiveSound(player:getPrimaryHandItem())
end

local function onGameStart()
    local player = getSpecificPlayer(0) or getPlayer()
    if player then
        ISILSilencerStats.applyLiveSound(player:getPrimaryHandItem())
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnGameStart.Add(onGameStart)
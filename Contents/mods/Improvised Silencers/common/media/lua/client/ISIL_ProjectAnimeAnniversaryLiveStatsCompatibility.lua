-- Project Anime Anniversary runs its own OnPlayerUpdate suppressor handler and
-- restores weapon sound stats when the Canon part is not one of its suppressors.
-- Re-apply Improvised Silencers stats after that handler so our suppressors keep
-- working on PAA firearms.

if not getActivatedMods():contains("ProjectAnimeAnniversaryStable") then
    return
end

require "ISIL_SilencerStats"

local function ISIL_PAA_onPlayerUpdate(player)
    if not player then
        return
    end

    ISILSilencerStats.applyLiveSound(player:getPrimaryHandItem())
end

local registered = false
local function ISIL_PAA_registerLiveStatsCompatibility()
    if registered then
        return
    end

    registered = true
    Events.OnPlayerUpdate.Add(ISIL_PAA_onPlayerUpdate)
end

Events.OnGameStart.Add(ISIL_PAA_registerLiveStatsCompatibility)

print("[Improvised Silencers] Project Anime Anniversary live-stat compatibility loaded.")
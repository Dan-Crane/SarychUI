local _, shared = ...
local AddonName = "RaidFrameSorter"
local AddonVars = shared.RaidFrameSorter
local Addon = LibStub("AceAddon-3.0"):GetAddon(AddonName)
local util = AddonVars.util

local constants = AddonVars.constants
local DESC = constants.DESC
local ASC = constants.ASC
local NONE = constants.NONE

local globals = AddonVars.globals

--the following are globally defined in teh blizzard interface code
local CompactRaidFrameManager = globals.CompactRaidFrameManager
local CompactRaidFrameContainer_SetFlowSortFunction = globals.CompactRaidFrameContainer_SetFlowSortFunction
local CompactRaidFrameManager_GetSetting = globals.CompactRaidFrameManager_GetSetting
local CompactRaidFrameManager_SetSetting = globals.CompactRaidFrameManager_SetSetting

--wow api
local InCombatLockdown = globals.InCombatLockdown
local UnitExists = globals.UnitExists
local UnitIsUnit = globals.UnitIsUnit
--local IsInGroup = globals.IsInGroup

local sortFunctions = {}

sortFunctions[DESC] = function(t1, t2)
    if not UnitExists(t1) then
        return false;
    elseif not UnitExists(t2) then
        return true
    elseif UnitIsUnit(t1, 'player') then
        return true;
    elseif UnitIsUnit(t2, 'player') then
        return false;
    else
        return t1 < t2;
    end
end

sortFunctions[ASC] = function(t1, t2)
    if not UnitExists(t1) then
        return false;
    elseif not UnitExists(t2) then
        return true
    elseif UnitIsUnit(t1, 'player') then
        return false;
    elseif UnitIsUnit(t2, 'player') then
        return true;
    else
        return t1 > t2;
    end
end

function Addon:ApplySort()
    if (not InCombatLockdown()) then
        local sortFunc = sortFunctions[Addon.db.profile.sortOrder]
        if sortFunc then
            local manager = CompactRaidFrameManager;
            CompactRaidFrameContainer_SetFlowSortFunction(manager.container, sortFunc);
        else
            local sortMode = CompactRaidFrameManager_GetSetting("SortMode")
            CompactRaidFrameManager_SetSetting('SortMode', sortMode)
        end
    end
end

local _, shared = ...
shared.RaidFrameSorter = shared.RaidFrameSorter or {}
local AddonName = "RaidFrameSorter"
local AddonVars = shared.RaidFrameSorter

AddonVars.globals = {
    --the following are globally defined in teh blizzard interface code
    CompactRaidFrameManager = CompactRaidFrameManager or {},
    CompactRaidFrameContainer_SetFlowSortFunction = CompactRaidFrameContainer_SetFlowSortFunction or
        function(container, func) end,
    CompactRaidFrameManager_GetSetting = CompactRaidFrameManager_GetSetting or function(setting) end,
    CompactRaidFrameManager_SetSetting = CompactRaidFrameManager_SetSetting or function(setting, value) end,
    CompactUnitFrameProfilesGeneralOptionsFrameKeepGroupsTogether = CompactUnitFrameProfilesGeneralOptionsFrameKeepGroupsTogether
        or {},
    InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory or {},
    -- wow API
    InCombatLockdown = InCombatLockdown or function() end,
    UnitExists = UnitExists or function(unit) end,
    UnitIsUnit = UnitIsUnit or function(unit) end,
    IsInGroup = IsInGroup or function() end,
    SlashCmdList = SlashCmdList or {}

}

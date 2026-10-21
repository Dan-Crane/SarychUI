local _, shared = ...
local AddonName = "RaidFrameSorter"
local AddonVars = shared.RaidFrameSorter
local Addon = LibStub("AceAddon-3.0"):GetAddon(AddonName)

local constants = AddonVars.constants
local DESC = constants.DESC
local ASC = constants.ASC
local NONE = constants.NONE

local globals = AddonVars.globals
local CompactRaidFrameManager_GetSetting = globals.CompactRaidFrameManager_GetSetting
local CompactUnitFrameProfilesGeneralOptionsFrameKeepGroupsTogether = globals.CompactUnitFrameProfilesGeneralOptionsFrameKeepGroupsTogether
local InterfaceOptionsFrame_OpenToCategory = globals.InterfaceOptionsFrame_OpenToCategory

local defaults = {
    profile = {
        sortOrder = DESC
    }
}

local function isGroupTogether()
    return CompactRaidFrameManager_GetSetting("KeepGroupsTogether")
end

local function unsetGroupTogether()
    -- for w/e reason this is only saving if we go through the options widget
    CompactUnitFrameProfilesGeneralOptionsFrameKeepGroupsTogether:Click()
end

function Addon:SetupOptions()
    self.db = LibStub("AceDB-3.0"):New(AddonName .. "DB", defaults, true)

    self.options = {
        name = AddonName,
        descStyle = "inline",
        type = "group",
        plugins = {},
        childGroups = "tab",
        args = {
            sort = {
                order = 1,
                type = "select",
                name = 'Raid Sort Order',
                desc = 'player at top = desc, player at bottom = asc',
                get = function(info) return Addon.db.profile.sortOrder end,
                set = function(info, value) Addon.db.profile.sortOrder = value; Addon:ApplySort() end,
                values = {
                    [DESC] = 'Descending',
                    [ASC] = 'Ascending',
                    [NONE] = 'None'
                }
            },
            groupTogetherWarning = {
                order = 2,
                type = 'description',
                name = 'Sorting only works if "Keep Groups Together" is disabled, click this button to disable that setting.',
                hidden = function()
                    return not isGroupTogether()
                end
            },
            fixSetting = {
                type = 'execute',
                func = function()
                    unsetGroupTogether()
                end,
                name = 'Unset Group Together',
                hidden = function()
                    return not isGroupTogether()
                end
            },
            openBlizzSettings = {
                type = 'execute',
                func = function()
                    InterfaceOptionsFrame_OpenToCategory('Raid Profiles')
                end,
                name = 'Open Blizz Raid Frame Settings'
            },
        }
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, self.options)
    if not SarychUI then
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName, AddonName)
    end
end

function Addon:RegisterInterfaceOptions()
    if self._suiBlizRegistered then
        return
    end
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName, AddonName)
    self._suiBlizRegistered = true
end

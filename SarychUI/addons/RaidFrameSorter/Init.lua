local _, shared = ...
local AddonName = "RaidFrameSorter"
local AddonVars = shared.RaidFrameSorter
local Addon = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0")
_G[AddonName] = Addon

local globals = AddonVars.globals
local InterfaceOptionsFrame_OpenToCategory = globals.InterfaceOptionsFrame_OpenToCategory
local SlashCmdList = globals.SlashCmdList

function Addon:OnInitialize()
    self:SetupOptions()
    hooksecurefunc("CompactUnitFrameProfiles_ActivateRaidProfile", function()
        if Addon:IsEnabled() then
            Addon:ApplySort()
        end
    end)
    if SarychUI then
        self:SetEnabledState(false)
    end
end

function Addon:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "ApplySort")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "ApplySort")
    self:ApplySort()
end

function Addon:OnDisable()
    self:UnregisterAllEvents()
    if self.db and self.db.profile then
        local saved = self.db.profile.sortOrder
        self.db.profile.sortOrder = AddonVars.constants.NONE
        self:ApplySort()
        self.db.profile.sortOrder = saved
    end
end

_G["SLASH_" .. AddonName .. "1"] = '/rfs'

SlashCmdList[AddonName] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(AddonName)
    InterfaceOptionsFrame_OpenToCategory(AddonName)
end

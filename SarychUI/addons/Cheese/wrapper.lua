-- Cheese Wrapper for SarychUI
-- Manages loading and enabling/disabling of Cheese addon

local ADDON_NAME = "Cheese"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Неизвестен",
	version = "1.0",
	enabled = false,
	loaded = false,
}

-- Global enabled state
CheeseEnabled = CheeseEnabled ~= false

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return CheeseEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function RegisterNativeOptions()
	local panel = _G.InterfaceOptionsCheesePanel
	local categories = _G.INTERFACEOPTIONS_ADDONCATEGORIES
	if not panel or not categories or not _G.InterfaceOptions_AddCategory then return end
	for _, category in ipairs(categories) do
		if category == panel then return end
	end
	InterfaceOptions_AddCategory(panel)
	if CheeseOptions_Refresh then CheeseOptions_Refresh(panel) end
end

local function UnregisterNativeOptions()
	local panel = _G.InterfaceOptionsCheesePanel
	local categories = _G.INTERFACEOPTIONS_ADDONCATEGORIES
	if not panel or not categories then return end
	for index, category in ipairs(categories) do
		if category == panel then
			table.remove(categories, index)
			if _G.InterfaceOptionsFramePanelContainer
				and InterfaceOptionsFramePanelContainer.displayedPanel == panel then
				panel:Hide()
				InterfaceOptionsFramePanelContainer.displayedPanel = nil
			end
			if _G.InterfaceOptionsFrameAddOns and InterfaceOptionsFrameAddOns.selection == panel then
				if _G.OptionsList_ClearSelection then
					OptionsList_ClearSelection(InterfaceOptionsFrameAddOns, InterfaceOptionsFrameAddOns.buttons)
				end
				InterfaceOptionsFrameAddOns.selection = nil
			end
			if _G.InterfaceAddOnsList_Update then InterfaceAddOnsList_Update() end
			return
		end
	end
end

function wrapper:IsRuntimeEnabled()
	return self.enabled
end

function wrapper:SetRuntimeEnabled(enable)
	enable = enable and true or false
	if enable then
		self:Enable()
	else
		self:Disable()
	end
	return true
end

function wrapper:Initialize()
	self.enabled = GetRuntimeEnabledFromDB()
	self.loaded = true
	CheeseEnabled = self.enabled
	if CheeseSpellActivationOverlayFrame then
		local config = SarychUI.db.profile.addons[ADDON_NAME] or {}
		CheeseSpellActivationOverlayFrame:SetAlpha(config.spellAlertOpacity or 1)
	end
	if not self.enabled then
		self:Disable()
	else
		RegisterNativeOptions()
	end
end

-- Enable the addon
function wrapper:Enable()
	self.enabled = true
	self.loaded = true
	CheeseEnabled = true
	SetRuntimeEnabledInDB(true)
	local config = SarychUI.db.profile.addons[ADDON_NAME] or {}
	if CheeseSpellActivationOverlayFrame then
		CheeseSpellActivationOverlayFrame:SetAlpha(config.spellAlertOpacity or 1)
	end
	if Cheese_RefreshActionMappings then
		Cheese_RefreshActionMappings()
	end
	if Cheese_RefreshAuras then
		Cheese_RefreshAuras()
	end
	if CheeseActionButton_RefreshAll then
		CheeseActionButton_RefreshAll()
	end
	RegisterNativeOptions()
end

-- Disable the addon
function wrapper:Disable()
	self.enabled = false
	CheeseEnabled = false
	SetRuntimeEnabledInDB(false)
	if Cheese_ClearRuntime then
		Cheese_ClearRuntime()
	end
	if CheeseSpellActivationOverlayFrame then
		CheeseSpellActivationOverlay_HideAllOverlays(CheeseSpellActivationOverlayFrame)
	end
	if CheeseActionButton_RefreshAll then
		CheeseActionButton_RefreshAll()
	end
	UnregisterNativeOptions()
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "Cheese",
		order = 4,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Cheese",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			showSpellAlerts = {
				type = "toggle",
				name = "Показывать оповещения заклинаний",
				order = 2,
				hidden = function() return not wrapper:IsRuntimeEnabled() end,
				get = function()
					return SarychUI.db.profile.addons.Cheese.showSpellAlerts ~= false
				end,
				set = function(_, value)
					SarychUI.db.profile.addons.Cheese.showSpellAlerts = value and true or false
					if not value and CheeseSpellActivationOverlayFrame then
						CheeseSpellActivationOverlay_HideAllOverlays(CheeseSpellActivationOverlayFrame)
					elseif value and Cheese_RefreshSpellOverlays then
						Cheese_RefreshSpellOverlays()
					end
					if _G.InterfaceOptionsCheesePanel and CheeseOptions_Refresh then
						CheeseOptions_Refresh(InterfaceOptionsCheesePanel)
					end
				end,
			},
			spellAlertOpacity = {
				type = "range",
				name = "Прозрачность оповещений",
				min = 0.1, max = 1, step = 0.05,
				order = 3,
				hidden = function() return not wrapper:IsRuntimeEnabled() end,
				disabled = function() return SarychUI.db.profile.addons.Cheese.showSpellAlerts == false end,
				get = function()
					return SarychUI.db.profile.addons.Cheese.spellAlertOpacity or 1
				end,
				set = function(_, value)
					SarychUI.db.profile.addons.Cheese.spellAlertOpacity = value
					if CheeseSpellActivationOverlayFrame then
						CheeseSpellActivationOverlayFrame:SetAlpha(value)
					end
					if _G.InterfaceOptionsCheesePanel and CheeseOptions_Refresh then
						CheeseOptions_Refresh(InterfaceOptionsCheesePanel)
					end
				end,
			},
			description = {
				type = "description",
				name = "Визуальные алерты активации заклинаний (Cataclysm Visual Alerts).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 4,
				width = "full",
			},
		},
	}
end

-- Auto-register when SarychUI is available
local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		return true
	end
	return false
end

-- Try to register immediately
if not RegisterWrapper() then
	-- Register after SarychUI loads
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" and addonName == "SarychUI" then
			if RegisterWrapper() then
				self:UnregisterEvent("ADDON_LOADED")
			end
		elseif event == "PLAYER_LOGIN" then
			if RegisterWrapper() then
				self:UnregisterEvent("PLAYER_LOGIN")
			end
		end
	end)
end

return wrapper

